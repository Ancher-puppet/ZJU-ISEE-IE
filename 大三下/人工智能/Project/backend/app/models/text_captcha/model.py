"""
CRNN 模型定义 — CNN + BiLSTM + CTC

网络结构：
  输入: [B, 1, 60, 160]  灰度验证码图片
    ↓
  CNN 特征提取器: 5层卷积 + 池化，逐步压缩空间维度
    ↓
  Reshape: [B, C, H', W'] → [W', B, C]  转为序列
    ↓
  BiLSTM: 双向 LSTM 序列建模，捕获字符间上下文
    ↓
  FC: 全连接层输出每个时间步的字符概率分布 [W', B, num_classes]
    ↓
  CTC Loss: 无需对齐，自动学习字符位置映射

维度推导（默认配置）：
  输入:  [B, 1, 60, 160]
  Conv1: [B, 32, 60, 160]  → Pool: [B, 32, 30, 80]
  Conv2: [B, 64, 30, 80]   → Pool: [B, 64, 15, 40]
  Conv3: [B, 128, 15, 40]  → Pool: [B, 128, 7, 20]
  Conv4: [B, 256, 7, 20]   → Pool: [B, 256, 3, 10]
  Conv5: [B, 256, 3, 10]   → AdaptiveAvgPool: [B, 256, 1, 10]  (高度→1，宽度保留)
  Reshape: [10, B, 256]     (10个时间步，每个256维特征)
  BiLSTM: [10, B, 512]      (双向 256*2)
  FC:     [10, B, 63]       (62字符 + 1 blank，含大小写字母和数字)
"""

import torch
import torch.nn as nn
import torch.nn.functional as F

from . import config


class CNNFeatureExtractor(nn.Module):
    """
    CNN 特征提取器。

    使用多层卷积+BN+ReLU+池化，将输入图像压缩为
    高度为1的特征序列（宽度方向保留时间信息）。
    """

    def __init__(self, in_channels: int = 1):
        super().__init__()

        channels = config.CNN_CHANNELS  # [1, 32, 64, 128, 256, 256]
        k = config.CNN_KERNEL_SIZE

        self.features = nn.Sequential(
            # Block 1: [B, 1, 60, 160] → [B, 32, 30, 80]
            nn.Conv2d(channels[0], channels[1], kernel_size=k, padding=1),
            nn.BatchNorm2d(channels[1]),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),

            # Block 2: [B, 32, 30, 80] → [B, 64, 15, 40]
            nn.Conv2d(channels[1], channels[2], kernel_size=k, padding=1),
            nn.BatchNorm2d(channels[2]),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),

            # Block 3: [B, 64, 15, 40] → [B, 128, 7, 20]
            nn.Conv2d(channels[2], channels[3], kernel_size=k, padding=1),
            nn.BatchNorm2d(channels[3]),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),

            # Block 4: [B, 128, 7, 20] → [B, 256, 3, 10]
            nn.Conv2d(channels[3], channels[4], kernel_size=k, padding=1),
            nn.BatchNorm2d(channels[4]),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),

            # Block 5: [B, 256, 3, 10] → [B, 256, 1, 10]
            nn.Conv2d(channels[4], channels[5], kernel_size=k, padding=1),
            nn.BatchNorm2d(channels[5]),
            nn.ReLU(inplace=True),
            nn.AdaptiveAvgPool2d((1, None)),  # 高度→1，宽度保留(10)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: [B, 1, H, W]
        Returns:
            [B, C, 1, W'] → squeezed to [B, C, W']
        """
        out = self.features(x)          # [B, C, 1, W']
        out = out.squeeze(2)            # [B, C, W']
        return out


class BidirectionalLSTM(nn.Module):
    """双向 LSTM + 全连接输出层。"""

    def __init__(
        self,
        input_size: int,
        hidden_size: int,
        output_size: int,
        num_layers: int = 2,
        dropout: float = 0.1,
    ):
        super().__init__()

        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            bidirectional=True,
            dropout=dropout if num_layers > 1 else 0,
            batch_first=False,  # 输入格式: [seq_len, batch, features]
        )

        # 双向 LSTM 输出维度是 hidden_size * 2
        self.fc = nn.Linear(hidden_size * 2, output_size)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: [W', B, input_size]
        Returns:
            [W', B, output_size]
        """
        recurrent, _ = self.lstm(x)     # [W', B, hidden*2]
        output = self.fc(recurrent)     # [W', B, output_size]
        return output


class CRNN(nn.Module):
    """
    CRNN (Convolutional Recurrent Neural Network) for CAPTCHA recognition.

    结构: CNN → Reshape → BiLSTM → FC → CTC
    """

    def __init__(
        self,
        num_classes: int = config.NUM_CLASSES,
        rnn_hidden: int = config.RNN_HIDDEN_SIZE,
        rnn_layers: int = config.RNN_NUM_LAYERS,
        rnn_dropout: float = config.RNN_DROPOUT,
    ):
        super().__init__()

        self.num_classes = num_classes

        # CNN 特征提取
        self.cnn = CNNFeatureExtractor(in_channels=config.IMAGE_CHANNELS)

        # 计算 CNN 输出的特征维度
        # 通过一次前向传播推导
        self._feature_dim = None
        self._seq_length = None

        # BiLSTM 序列建模
        # 先用 placeholder，首次 forward 时自动调整
        self.rnn = None
        self.rnn_hidden_size = config.RNN_HIDDEN_SIZE
        self.rnn_num_layers = config.RNN_NUM_LAYERS
        self.rnn_dropout = config.RNN_DROPOUT

        # 全连接输出（放在 __init__ 中，维度在首次 forward 确定）
        self.fc_out = None

        # 初始化权重
        self._initialize_weights()

    def _initialize_weights(self):
        """Kaiming 初始化卷积层权重。"""
        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode="fan_out", nonlinearity="relu")
                if m.bias is not None:
                    nn.init.zeros_(m.bias)
            elif isinstance(m, nn.BatchNorm2d):
                nn.init.ones_(m.weight)
                nn.init.zeros_(m.bias)

    def _build_rnn(self, feature_dim: int, device: torch.device):
        """首次 forward 时构建 RNN 和 FC 层（需要知道 feature_dim）。"""
        self.rnn = BidirectionalLSTM(
            input_size=feature_dim,
            hidden_size=self.rnn_hidden_size,
            output_size=config.NUM_CLASSES,
            num_layers=self.rnn_num_layers,
            dropout=self.rnn_dropout,
        ).to(device)
        self._feature_dim = feature_dim

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: [B, 1, H, W] 输入图像

        Returns:
            [W', B, num_classes] 每个时间步的字符概率分布（log_softmax）
        """
        # CNN 特征提取
        conv_out = self.features(x)         # [B, C, 1, W']
        conv_out = conv_out.squeeze(2)      # [B, C, W']

        # 转换维度: [B, C, W'] → [W', B, C]（LSTM 期望 [seq, batch, feat]）
        conv_out = conv_out.permute(2, 0, 1)  # [W', B, C]

        # 首次 forward 时动态构建 RNN
        if self.rnn is None:
            self._build_rnn(conv_out.size(2), x.device)

        # BiLSTM 序列建模
        rnn_out = self.rnn(conv_out)        # [W', B, num_classes]

        # Log Softmax（CTC loss 要求 log 概率）
        output = F.log_softmax(rnn_out, dim=2)

        return output

    def features(self, x: torch.Tensor) -> torch.Tensor:
        """暴露 CNN 特征提取，用于可视化。"""
        return self.cnn(x)

    @property
    def cnn(self):
        """CNN 特征提取器。"""
        if not hasattr(self, "_cnn"):
            self._cnn = self._build_cnn()
        return self._cnn

    def _build_cnn(self):
        """构建 CNN 模块。"""
        return self._get_cnn_module()

    def __getattr__(self, name):
        # 代理对 cnn 的访问
        if name == "cnn":
            return super().__getattribute__("features_module")
        return super().__getattr__(name)


# 重写 CRNN，更清晰的版本
class CRNN(nn.Module):
    """
    CRNN (Convolutional Recurrent Neural Network) for CAPTCHA Recognition.

    Architecture:
        Input [B, 1, 60, 160]
          ↓
        CNN Feature Extractor → [B, C, 1, W']
          ↓ (squeeze + permute)
        [W', B, C]
          ↓
        Bidirectional LSTM → [W', B, hidden*2]
          ↓
        Linear → [W', B, num_classes]
          ↓
        Log Softmax → [W', B, num_classes]
          ↓
        CTC Decode → text string
    """

    def __init__(self):
        super().__init__()

        # ─── CNN 特征提取器 ─────────────────────────────────────────
        channels = config.CNN_CHANNELS  # [1, 32, 64, 128, 256, 256]
        k = config.CNN_KERNEL_SIZE

        self.cnn = nn.Sequential(
            # Block 1: [B, 1, 60, 160] → [B, 32, 30, 80]
            nn.Conv2d(channels[0], channels[1], k, padding=1),
            nn.BatchNorm2d(channels[1]),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            # Block 2: [B, 32, 30, 80] → [B, 64, 15, 40]
            nn.Conv2d(channels[1], channels[2], k, padding=1),
            nn.BatchNorm2d(channels[2]),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            # Block 3: [B, 64, 15, 40] → [B, 128, 7, 20]
            nn.Conv2d(channels[2], channels[3], k, padding=1),
            nn.BatchNorm2d(channels[3]),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            # Block 4: [B, 128, 7, 20] → [B, 256, 3, 10]
            nn.Conv2d(channels[3], channels[4], k, padding=1),
            nn.BatchNorm2d(channels[4]),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),

            # Block 5: [B, 256, 3, 10] → [B, 256, 1, 10]
            nn.Conv2d(channels[4], channels[5], k, padding=1),
            nn.BatchNorm2d(channels[5]),
            nn.ReLU(True),
            nn.AdaptiveAvgPool2d((1, None)),  # 高度→1，宽度保留(10)
        )

        # ─── BiLSTM 序列建模 ────────────────────────────────────────
        # CNN 输出 [B, 256, 1, W'] → squeeze → [B, 256, W'] → permute → [W', B, 256]
        self.rnn = nn.LSTM(
            input_size=channels[-1],        # 256
            hidden_size=config.RNN_HIDDEN_SIZE,
            num_layers=config.RNN_NUM_LAYERS,
            bidirectional=True,
            dropout=config.RNN_DROPOUT if config.RNN_NUM_LAYERS > 1 else 0,
        )

        # [任务3修改] LSTM 输出后添加 Dropout(p=0.2) 防止过拟合
        # 原始实现: LSTM 直接连 FC，无额外正则化
        # 修改后: 在 LSTM 输出和 FC 之间加 Dropout，随机丢弃20%的神经元
        self.dropout = nn.Dropout(p=0.2)

        # ─── 输出全连接层 ───────────────────────────────────────────
        # 双向 LSTM 输出 hidden_size * 2
        self.fc = nn.Linear(config.RNN_HIDDEN_SIZE * 2, config.NUM_CLASSES)

        # 初始化权重
        self._initialize_weights()

    def _initialize_weights(self):
        """He 初始化卷积层，Xavier 初始化全连接层。"""
        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode="fan_out", nonlinearity="relu")
                if m.bias is not None:
                    nn.init.zeros_(m.bias)
            elif isinstance(m, nn.BatchNorm2d):
                nn.init.ones_(m.weight)
                nn.init.zeros_(m.bias)
            elif isinstance(m, nn.Linear):
                nn.init.xavier_uniform_(m.weight)
                if m.bias is not None:
                    nn.init.zeros_(m.bias)
            elif isinstance(m, nn.LSTM):
                for name, param in m.named_parameters():
                    if "weight_ih" in name:
                        nn.init.xavier_uniform_(param)
                    elif "weight_hh" in name:
                        nn.init.orthogonal_(param)
                    elif "bias" in name:
                        nn.init.zeros_(param)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        前向传播。

        Args:
            x: [B, 1, H, W] 输入图像张量

        Returns:
            [T, B, num_classes] 对数概率，T = 序列长度（时间步数）
        """
        # CNN: [B, 1, H, W] → [B, C, 1, W']
        conv = self.cnn(x)

        # Squeeze 高度维度: [B, C, 1, W'] → [B, C, W']
        conv = conv.squeeze(2)

        # Permute 适配 LSTM: [B, C, W'] → [W', B, C]
        conv = conv.permute(2, 0, 1)

        # BiLSTM: [W', B, C] → [W', B, hidden*2]
        rnn_out, _ = self.rnn(conv)

        # [任务3] Dropout 正则化（训练时随机丢弃20%神经元）
        rnn_out = self.dropout(rnn_out)

        # FC: [W', B, hidden*2] → [W', B, num_classes]
        output = self.fc(rnn_out)

        # Log Softmax（CTC 需要 log 概率）
        output = F.log_softmax(output, dim=2)

        return output


def count_parameters(model: nn.Module) -> int:
    """统计模型可训练参数量。"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)


def model_summary(model: nn.Module) -> str:
    """生成模型摘要信息。"""
    total = count_parameters(model)
    lines = [
        "=" * 60,
        "  CRNN Model Summary",
        "=" * 60,
        f"  Input:      [B, 1, {config.IMAGE_HEIGHT}, {config.IMAGE_WIDTH}]",
        f"  CNN:        {config.CNN_CHANNELS}",
        f"  RNN:        BiLSTM hidden={config.RNN_HIDDEN_SIZE}, layers={config.RNN_NUM_LAYERS}",
        f"  Output:     {config.NUM_CLASSES} classes ({len(config.CHARS)} chars + 1 blank)",
        f"  Parameters: {total:,}",
        "=" * 60,
    ]
    return "\n".join(lines)

"""
模型配置 — 推理常量 + 网络架构参数

仅包含模型定义和推理所需常量。训练超参见 training/text_captcha/config.py。
"""

from pathlib import Path

import torch

# ─── 字符集配置 ─────────────────────────────────────────────────────────────
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
NUM_CLASSES = len(CHARS) + 1  # +1 for CTC blank token (index 0) → 63

CHAR_TO_IDX = {char: idx + 1 for idx, char in enumerate(CHARS)}
IDX_TO_CHAR = {idx + 1: char for idx, char in enumerate(CHARS)}
BLANK_IDX = 0  # CTC blank token index

# ─── 验证码参数 ─────────────────────────────────────────────────────────────
CAPTCHA_LENGTH = 4
IMAGE_HEIGHT = 60
IMAGE_WIDTH = 160
IMAGE_CHANNELS = 1  # 灰度图

# ─── 模型架构参数 ───────────────────────────────────────────────────────────
# CNN 特征提取器
CNN_CHANNELS = [1, 32, 64, 128, 256, 256]
CNN_KERNEL_SIZE = 3
CNN_POOL_KERNEL = (2, 2)

# BiLSTM 序列建模
RNN_HIDDEN_SIZE = 256
RNN_NUM_LAYERS = 2
RNN_DROPOUT = 0.1

# 全连接输出层
FC_HIDDEN_SIZE = 512

# ─── 推理参数 ───────────────────────────────────────────────────────────────
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
DEFAULT_CHECKPOINT = Path(__file__).resolve().parent.parent.parent.parent / "models" / "text_captcha" / "best_model.pth"

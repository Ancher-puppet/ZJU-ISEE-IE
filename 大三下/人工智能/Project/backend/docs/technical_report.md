# 文字点选验证码识别系统 — 技术报告

## 一、问题定义

文字点选验证码（Text-Select CAPTCHA）要求用户按照指定顺序依次点击图片中的文字。识别此类验证码需要解决两个子问题：

1. **在哪里点** — 定位图片中所有可点击文字的位置（目标检测）
2. **按什么顺序点** — 确定点击的顺序，通常由验证码底部的提示文字给出（文字匹配 + 顺序推理）

输入为一张验证码图片，输出为按点击顺序排列的边界框坐标列表。

---

## 二、算法设计

系统采用 **YOLO 目标检测 + Siamese 孪生网络** 的两阶段流水线架构。

### 2.1 整体流程

```
输入图片 → [YOLO 检测] → target区域 + char区域
                              │
              char按x坐标排序   │
                  ↓            ↓
            ┌──────────────────────┐
            │  Siamese 特征匹配    │
            │  (chars × targets)  │
            └──────────────────────┘
                    ↓
           贪心匹配 → 点击顺序坐标
```

### 2.2 第一阶段：文字区域检测（YOLOv8）

**目标**：从验证码图片中检测所有文字区域，并区分为两类：
- `target`：待点击的目标文字
- `char`：底部提示文字（用于确定点击顺序）

**模型选型**：采用 **Ultralytics YOLOv8**，在 COCO 预训练权重基础上进行迁移学习。YOLO 作为单阶段检测器，在速度和精度之间取得了良好平衡，适合需要实时响应的验证码识别场景。

**关键设计决策**：
- 仅需 2 个类别（target / char），而非逐字分类，大幅降低标注成本
- 类别定义中将"背景文字"作为 char 类参与决策，而非直接忽略，使得提示文字的检测框可被后续模块复用

**训练配置**：
| 参数 | 值 | 说明 |
|------|-----|------|
| 预训练模型 | yolov8n.pt | 轻量级，适合小数据集 |
| 输入尺寸 | 640×640 | 标准 YOLO 输入 |
| 训练轮数 | 200 | 配合早停（patience=50） |
| 数据增强 | Mosaic 0.5, MixUp 0.2, HSV 扰动 | 提升小样本泛化能力 |
| 优化器 | AdamW | 带权重衰减的自适应优化器 |
| 学习率 | lr0=0.001, lrf=0.01 | cosine 衰减 |

### 2.3 第二阶段：点击顺序确定（Siamese 孪生网络）

**目标**：将检测到的 target 文字与 char 提示文字进行匹配，结合 char 从左到右的空间顺序，确定 target 的点击顺序。

**动机**：验证码中的文字通常经过扭曲、旋转、重叠等变换，直接做 OCR 识别准确率不高。而 Siamese 网络学习的是"这两张图是不是同一个字"的**相似度度量**，避开了开放集文字识别的困难，将问题退化为二分类（同/不同）。

**网络结构**：

```
input1 (crop) → Backbone → embedding1 (256d, L2归一化)
                                                          \
input2 (crop) → Backbone → embedding2 (256d, L2归一化)  → |diff| → FC(256→128→64→1) → sigmoid → 相似概率
```

- **Backbone**：自定义轻量 CNN（4 层卷积 + BatchNorm + MaxPool，参数量约 2MB），或可选 ResNet-18
- **差异计算**：`diff = |e1 - e2|`，而非拼接，减少参数量且对输入顺序不敏感
- **Head**：三层全连接（256→128→64→1）+ Dropout(0.3) 防止过拟合
- **输出**：经 Sigmoid 得到 [0, 1] 相似概率

**为什么用 L2 归一化 + 绝对差**：
- L2 归一化将 embedding 映射到单位超球面，使得相似度判断仅依赖方向而非模长
- 绝对差 `|e1 - e2|` 比拼接 `[e1, e2]` 参数量减半，且天然对输入交换对称

### 2.4 匹配算法

`matchingMode.find_overall_index_fast` 实现贪心全局最优匹配：

```
输入: scores[N][M] — N个chars × M个targets 的相似度矩阵
算法:
  重复 min(N, M) 次:
    1. 找到当前矩阵中的全局最大值 scores[i][j]
    2. 记录配对 (row=i, col=j)
    3. 将第 i 行和第 j 列置为 -∞（每行每列唯一匹配）
  按 row（即 char 顺序）排序 → 输出 target 点击顺序
```

时间复杂度 O(k·N·M)，其中 k = min(N, M)，对于验证码场景（通常 ≤10 个文字）足够高效。

**为什么贪心可行**：对于文字匹配问题，正样本（同字）的相似度通常远高于负样本（不同字），贪心取最大值等价于全局最优。相比匈牙利算法，实现更简洁且在此场景下效果相当。

---

## 三、工程实现

### 3.1 模型部署：ONNX 格式统一

训练框架（PyTorch）与推理框架解耦，统一转换为 **ONNX** 格式：

| 组件 | 训练框架 | 推理格式 | 推理框架 |
|------|---------|---------|---------|
| YOLO 检测 | PyTorch (ultralytics) | best_v3.onnx (~9.4MB) | onnxruntime CPU |
| Siamese 匹配 | PyTorch | pre_model_v7.onnx (~42MB) | onnxruntime CPU |

**ONNX 优势**：
- 跨平台（Windows / Linux / macOS 统一部署）
- 免除推理环境对 PyTorch 的依赖，仅需 `onnxruntime`（~20MB）
- CPU 推理优化，支持在 1核2G 低配服务器运行

### 3.2 推理预处理一致性

训练和推理阶段共享相同的预处理逻辑（`letterbox_image` + 128 填充 + /255 归一化），数据集 `SiamesePairDataset` 中显式复刻了 `ver_onnx.py` 的预处理流程。这确保了训练-推理无分布偏移。

### 3.3 系统架构

```
src/
├── captcha.py          # 主入口 TextSelectCaptcha 类
├── utils/
│   ├── yolo_onnx.py    # YOLO ONNX 推理封装（letterbox + NMS后处理）
│   ├── ver_onnx.py     # Siamese ONNX 推理封装（批量匹配）
│   └── matchingMode.py # 贪心匹配算法 + 图片读取
├── drawing.py          # 检测结果可视化

app/                    # FastAPI Web 服务
├── main.py             # 应用工厂 + 异常处理
├── api/router.py       # 路由注册
├── api/endpoints/dianxuan.py  # 识别 API
├── models/input.py, output.py # Pydantic 数据模型
└── services/operation.py      # 业务逻辑层

train/                  # 训练流程
├── data/prepare_yolo.py     # 标注数据 → YOLO 格式
├── data/prepare_siamese.py  # 字符裁剪 + 配对生成
├── yolo/train.py            # YOLOv8 训练 + ONNX 导出
└── siamese/train.py         # Siamese 训练 + ONNX 导出
```

### 3.4 关键代码片段

**YOLO 坐标还原**（`yolo_onnx.py:118-121`）：ONNX 推理输出是 letterbox 填充后的坐标，需逆变换回原图：
```python
x1 = max(0, (x1 - dw) / scale)
y1 = max(0, (y1 - dh) / scale)
x2 = min(image.shape[1], (x2 - dw) / scale)
y2 = min(image.shape[0], (y2 - dh) / scale)
```

**Siamese 批量推理**（`ver_onnx.py:104-127`）：构建 N×M 的卡氏积输入，一次 ONNX 调用完成所有配对推理，避免 N×M 次独立调用。

---

## 四、数据与训练

### 4.1 数据准备流程

```
原始图片 + LabelMe标注
        ↓
prepare_yolo.py → YOLO 格式 (images/ + labels/, data.yaml)
        ↓
YOLO 训练
        ↓
prepare_siamese.py --mode crop → 自动裁剪所有文字区域
        ↓
人工分组: char_groups.json（相同文字归入同一组）
        ↓
prepare_siamese.py --mode pairs → 正负样本配对 CSV
        ↓
Siamese 训练
```

### 4.2 正负样本构造

- **正样本**：同一 char_groups 组内的任意两张裁剪 → label=1（同字）
- **负样本**：不同组间随机配对 → label=0（不同字）
- **平衡策略**：正负样本 1:1，训练时使用 BCELoss + pos_weight 动态加权

### 4.3 训练特性

- **混合精度训练 (AMP)**：利用 RTX 5060 的 Tensor Core，显存和速度双重优化
- **梯度裁剪**：`max_norm=1.0`，防止训练不稳定
- **学习率调度**：CosineAnnealingLR，平滑衰减
- **早停 (Early Stopping)**：YOLO patience=50，避免过拟合

---

## 五、性能表现

| 指标 | 数值 |
|------|------|
| 推理延迟 | 300~500ms（CPU） |
| 综合准确率 | ~96% |
| 训练数据量 | 约 300 张 |
| YOLO 模型大小 | ~9.4MB (ONNX) |
| Siamese 模型大小 | ~42MB (ONNX) / ~2MB (lite backbone .pth) |
| 最低运行配置 | 1核2G, CPU only |

---

## 六、局限性与改进方向

### 6.1 当前局限

1. **依赖提示文字**：方案假设验证码底部有提示文字（char 类），无法处理无提示文字的"看内容点选"类型验证码
2. **依赖标注**：训练新平台需要 200-300 张标注图片，标注耗时
3. **类别固定**：仅支持两类（target/char），无法处理多级点击或多轮交互场景

### 6.2 潜在改进

- **无提示文字场景**：将 Siamese 匹配替换为 CLIP 等多模态模型，直接从图片语义理解点击对象
- **端到端方案**：考虑用多模态大模型（如 GPT-4V）做 zero-shot 验证码识别，免去标注
- **半自动标注**：用现有模型对新平台做预标注，人工仅需修正，降低标注成本
- **旋转不变性**：在 Siamese 预处理中增加 STN（空间变换网络）以应对大幅旋转的文字

---

## 七、总结

本系统通过将文字点选验证码识别分解为"检测 + 匹配"两个子任务，利用 YOLOv8 的高效检测能力和 Siamese 网络的相似度学习能力，在仅需约 300 张训练数据的条件下，实现了高精度（96%）、低延迟（300-500ms）、低资源消耗（CPU 可运行）的工程化解决方案。其核心价值在于：

1. **问题分解策略**：将复杂的"识别+排序"退化为"检测+匹配"，降低模型学习难度
2. **ONNX 全链路部署**：训练与推理框架解耦，实现跨平台轻量部署
3. **完备的训练工具链**：从数据准备到模型导出的一站式训练流程

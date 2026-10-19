# CapAgent — 多类型验证码智能识别系统

基于深度学习与 Agent 调度的验证码识别系统，支持**文字验证码**（CRNN+CTC）和**文字点选验证码**（YOLO + ArcFace embedding 匹配）的生成与识别。

---

## 系统架构

```
                              ┌─────────────────────┐
                              │    React 前端        │
                              │  (Vite + localhost)  │
                              └────────┬────────────┘
                                       │ HTTP (proxy /api)
                              ┌────────▼────────────┐
                              │   FastAPI 后端        │
                              │   (main.py :8765)    │
                              └────────┬────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
            ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
            │ CaptchaAgent  │  │  Generator   │  │  测试/工具    │
            │ (scheduler)   │  │ (generator)  │  │ (tests/)     │
            └──────┬───────┘  └──────┬───────┘  └──────────────┘
                   │                 │
         ┌─────────┼─────────┐       │
         ▼                   ▼       │
   ┌──────────┐      ┌──────────┐    │
   │Classifier │      │ Recognizer│   │
   │(CNN/Rule) │      │ (dispatch)│   │
   └──────────┘      └────┬─────┘   │
                          │         │
              ┌───────────┼──────────┘
              ▼           ▼
   ┌──────────────┐  ┌──────────────────┐
   │TextCaptcha   │  │ClickCaptcha      │
   │Recognizer    │  │Recognizer        │
   │(CRNN + CTC)  │  │(YOLO + ArcFace)  │
   └──────────────┘  └──────────────────┘
```

## 项目结构

```
AI/
├── README.md
├── requirements.txt
│
├── backend/                          # Python 后端
│   ├── main.py                       # FastAPI 入口 (端口 8765)
│   │
│   ├── app/                          # 核心应用代码
│   │   ├── generator.py              # 验证码图片生成器
│   │   │
│   │   ├── agent/                    # Agent 调度核心
│   │   │   ├── scheduler.py          # CaptchaAgent 编排器
│   │   │   ├── classifier_cnn.py     # ResNet18 二分类器 (文字 vs 点选)
│   │   │   ├── classifier_rule.py    # CV 启发式分类器 (无 GPU 可用)
│   │   │   ├── dataset.py            # 分类数据集 + DataLoader
│   │   │   └── reasoning_logger.py   # 推理步骤记录
│   │   │
│   │   ├── models/                   # 识别器（纯推理 + 网络架构）
│   │   │   ├── text_captcha/         # 文字验证码识别 (CRNN)
│   │   │   │   ├── recognizer.py     # 识别入口
│   │   │   │   ├── model.py          # CRNN 网络定义
│   │   │   │   ├── predict.py        # CaptchaPredictor 推理引擎
│   │   │   │   └── config.py         # 推理常量 + 模型架构参数
│   │   │   │
│   │   │   └── click_captcha/        # 点选验证码识别 (YOLO + ArcFace)
│   │   │       ├── recognizer.py     # 识别入口 (ultralytics YOLO + ArcFace)
│   │   │       └── utils/
│   │   │           ├── arcface_onnx.py   # ArcFace ONNX 推理封装
│   │   │           ├── matchingMode.py   # 相似度矩阵 + 贪婪匹配
│   │   │           └── hint_splitter.py  # 提示字/候选字分流 (3 策略)
│   │   │
│   │   └── utils/                    # 通用工具
│   │       └── augment.py            # 数据增强 (train/val transform)
│   │
│   ├── models/                       # 模型权重（集中管理，不入 git）
│   │   ├── classifier/
│   │   │   └── best_classifier.pth   # ResNet18 二分类器
│   │   ├── text_captcha/
│   │   │   ├── best_model.pth        # CRNN 文字识别
│   │   │   └── last_model.pth
│   │   └── click_captcha/
│   │       ├── yolo/
│   │       │   └── best.pt           # YOLO 文本检测
│   │       └── arcface_backbone.onnx # ArcFace 特征提取 ONNX
│   │
│   ├── training/                     # 训练脚本 + 数据（与推理分离）
│   │   ├── classifier/               # 二分类器训练
│   │   │   ├── train.py              # 训练入口
│   │   │   ├── split_dataset.py      # 数据集划分 (train/val/test)
│   │   │   ├── evaluate.py           # 模型评估 (混淆矩阵 + ROC)
│   │   │   ├── data/                 # 分类器数据 (raw/train/val/test)
│   │   │   └── outputs/              # 评估产物 (figures/logs)
│   │   │
│   │   ├── text_captcha/             # CRNN 文字验证码训练
│   │   │   ├── train.py              # Trainer 类 + 训练入口
│   │   │   ├── train_config.py       # 训练超参数配置
│   │   │   ├── dataset.py            # 合成数据生成 + DataLoader
│   │   │   └── train_script.py       # 备用训练脚本
│   │   │
│   │   ├── click_captcha/            # 点选验证码训练
│   │   │   ├── config.py             # 路径配置 + YOLO 训练超参
│   │   │   ├── yolo/
│   │   │   │   └── train.py          # YOLO 检测训练
│   │   │   └── data/                 # 数据合成与预处理
│   │   │       ├── synthesize.py     # 验证码图片合成器
│   │   │       ├── prepare_yolo.py   # YOLO 标注格式转换
│   │   │       └── backgrounds/      # 背景图片素材
│   │   │
│   │   └── arcface_training/         # ArcFace 汉字分类预训练
│   │       ├── classify_train.py     # 训练入口 (含 ONNX 导出)
│   │       ├── arcface_model.py      # ResNet18 + ArcFaceHead
│   │       ├── classify_dataset.py   # 分类数据集
│   │       ├── _export.py            # ONNX 导出工具
│   │       ├── config.py             # 路径配置
│   │       └── data/
│   │           └── generate_arcface_data.py  # 合成单字训练数据
│   │
│   ├── tests/                        # 测试
│   │   ├── test_agent.py             # Agent 调度测试
│   │   ├── test_classifier.py        # 分类器测试
│   │   └── test_click_captcha.py     # 点选验证码集成测试
│   │
│   └── docs/                         # 文档
│       ├── TRAINING_GUIDE.md
│       ├── technical_report.md
│       └── 文字验证码识别工具.md
│
└── frontend/                         # React 前端 (Vite)
    ├── package.json
    ├── vite.config.js                # proxy /api → localhost:8765
    ├── index.html
    ├── public/
    │   └── bg.jpg                    # 首页背景图
    └── src/
        ├── main.jsx                  # React 入口
        ├── App.jsx                   # 主组件 (路由 + 状态管理)
        ├── App.css                   # 全局样式
        ├── api/
        │   └── mock.js               # API 客户端 (生成 + 识别接口)
        └── components/
            ├── GeneratePanel.jsx     # 验证码生成面板 (难度/背景选项)
            ├── UploadPanel.jsx       # 上传面板
            ├── ResultPanel.jsx       # 识别结果展示
            ├── ReasonPanel.jsx       # 推理过程展示
            └── HistoryPanel.jsx      # 历史记录
```

---

## 端到端流程

### 文字验证码识别

```
上传/生成图片
     │
     ▼
CaptchaAgent 分类
     │
     ├── CNN 分类器 (ResNet18)
     │      └── 判断为文字验证码 (置信度 ≥ 0.8)
     │
     ▼
TextCaptchaRecognizer
     │
     ├── CRNN 模型推理 (CNN + BiLSTM + CTC)
     ├── CTC 解码 → 字符序列
     └── 返回识别结果
```

### 文字点选验证码识别

```
上传/生成图片
     │
     ▼
CaptchaAgent 分类
     │
     ├── CNN 分类器 (ResNet18)
     │      └── 判断为点选验证码 (置信度 ≥ 0.8)
     │
     ▼
ClickCaptchaRecognizer
     │
     ├── Stage 1: YOLO 检测 (ultralytics YOLO)
     │   └── 检测所有文字框
     │
     ├── Stage 2: hint_splitter 分流
     │   ├── edge-strip 策略 (顶部/底部提示栏)
     │   ├── geometric 策略 (几何位置分析)
     │   └── UI container 策略 (容器检测)
     │   └── 输出: 提示字列表 + 候选字列表
     │
     ├── Stage 3: ArcFace 匹配
     │   ├── 提示字 → 256-dim L2 embedding
     │   ├── 候选字 → 256-dim L2 embedding
     │   ├── 余弦相似度矩阵
     │   └── greedy 全局最优匹配 (find_overall_index_fast)
     │
     └── 返回匹配结果 + 点击坐标
```

---

## 快速开始

### 环境要求

- Python 3.10+
- Node.js 18+
- 推荐 GPU (训练需要)，推理可用 CPU

### 安装

```bash
# 1. 后端
cd backend
conda create -n captcha-agent python=3.10
conda activate captcha-agent

# 安装 PyTorch (根据你的 CUDA 版本选择)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# 安装其他依赖
pip install -r requirements.txt
pip install ultralytics  # YOLO 推理引擎

# 2. 前端
cd frontend
npm install
```

### 运行

**后端** (端口 8765)：

```bash
cd backend
conda activate captcha-agent
python main.py
```

**前端** (端口 3000)：

```bash
cd frontend
npm run dev
```

浏览器打开 `http://localhost:3000` 即可使用。

### API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/health` | 健康检查 |
| `POST` | `/api/recognize` | 识别验证码 (multipart/form-data 上传图片) |
| `POST` | `/api/generate/text` | 生成文字验证码 (JSON: `{text}`) |
| `POST` | `/api/generate/click` | 生成点选验证码 (JSON: `{targets, difficulty, use_background}`) |

---

## 点选验证码生成选项

前端生成点选验证码时支持以下选项：

| 选项 | 取值 | 效果 |
|------|------|------|
| **难度** | `简单` / `正常` | 简单：小旋转(0~8°)、少噪点、少干扰线<br>正常：大旋转(25~50°)、多噪点、有描边 |
| **背景** | `图片` / `纯色` | 图片：从 backgrounds/ 随机选取风景图背景<br>纯色：纯色底 + 渐变 + 噪点纹理 |

> 演示时推荐选择「简单 + 纯色」，识别率最高。

---

## 模型训练

系统包含 4 个模型，各自有独立的训练流程。所有训练脚本位于 `backend/training/` 目录下。

### 模型权重统一存放

所有模型训练完成后，最终权重统一存放在 `backend/models/`：

| 模型 | 权重路径 | 格式 |
|------|----------|------|
| 分类器 | `models/classifier/best_classifier.pth` | PyTorch |
| CRNN 文字识别 | `models/text_captcha/best_model.pth` | PyTorch |
| YOLO 检测 | `models/click_captcha/yolo/best.pt` | ultralytics .pt |
| ArcFace 匹配 | `models/click_captcha/arcface_backbone.onnx` | ONNX |

---

### 1. 分类器 — ResNet18 二分类 (文字 vs 点选)

**作用**：判断输入验证码是文字验证码还是点选验证码，路由到对应识别器。

| 属性 | 值 |
|------|-----|
| 架构 | ResNet18 (ImageNet 预训练) → FC(256) → FC(2) |
| 输入 | 224×224 RGB |
| 损失函数 | CrossEntropyLoss |
| 优化器 | Adam (lr=0.001, weight_decay=0.0001) |
| 学习率调度 | StepLR (step=10, gamma=0.1) |
| 权重 | `backend/models/classifier/best_classifier.pth` |

**训练数据**：手动收集的真实验证码截图，按 `click_captcha/` 和 `text_captcha/` 两个子目录存放，使用 `split_dataset.py` 划分为 train/val/test。

```bash
cd backend

# 1. 划分数据集
python training/classifier/split_dataset.py \
    --source training/classifier/data/raw \
    --output training/classifier/data

# 2. 训练
python training/classifier/train.py \
    --epochs 10 --batch_size 32 --lr 0.001 --device auto

# 3. 评估 (生成混淆矩阵 + ROC 曲线)
python training/classifier/evaluate.py \
    --model models/classifier/best_classifier.pth
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--epochs` | 10 | 训练轮数 |
| `--batch_size` | 32 | 批次大小 |
| `--lr` | 0.001 | 学习率 |
| `--dropout` | 0.5 | Dropout 比率 |
| `--device` | auto | 设备 (auto/cpu/cuda:0) |

---

### 2. CRNN — 文字验证码识别

**作用**：识别文字验证码图片中的字符序列 (4 位字母数字)。

| 属性 | 值 |
|------|-----|
| 架构 | CNN(5层 Conv+BN+ReLU) → BiLSTM(2层) → FC → CTC |
| 输入 | 160×60 灰度图 |
| 字典 | 0-9, A-Z, a-z (62 字符 + 1 CTC blank = 63 类) |
| 损失函数 | CTCLoss (blank=0) |
| 优化器 | AdamW (lr=0.001, weight_decay=1e-5) |
| 学习率调度 | CosineAnnealing (eta_min=1e-6) |
| 早停 | patience=3 (验证集 loss 连续不降) |
| 权重 | `backend/models/text_captcha/best_model.pth` |

**训练数据**：使用 `dataset.py` 中的合成器自动生成 160×60 灰度验证码图片 (10000 训练 + 2000 验证 + 1000 测试)。训练产物直接保存到 `backend/models/text_captcha/`。

```bash
cd backend

# 训练
python training/text_captcha/train.py --epochs 50 --batch_size 64 --lr 0.001
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--epochs` | 50 | 训练轮数 |
| `--batch_size` | 64 | 批次大小 |
| `--lr` | 0.001 | 学习率 |
| `--scheduler` | cosine | 学习率调度 (cosine/step/plateau) |

---

### 3. YOLO — 点选验证码文字检测

**作用**：在点选验证码图片中检测所有文字区域的 bounding box。

| 属性 | 值 |
|------|-----|
| 架构 | Ultralytics YOLOv8n (nano) |
| 输入 | 640×640 (自动 letterbox) |
| 类别 | 2 (target: 待点击文字, char: 背景文字) |
| 优化器 | SGD (lr0=0.001, lrf=0.01) |
| 数据增强 | Mosaic(0.5), MixUp(0.2), HSV, 旋转, 平移, 缩放 |
| 早停 | patience=50 |
| 权重 | `backend/models/click_captcha/yolo/best.pt` |

**训练数据**：使用 `synthesize.py` 合成验证码图片，再用 `prepare_yolo.py` 转换为 YOLO 标注格式 (class x_center y_center width height)。

```bash
cd backend/training/click_captcha

# 1. 合成数据 + 准备 YOLO 标注
python data/prepare_yolo.py

# 2. 训练 (best.pt 直接保存到 models/click_captcha/)
python yolo/train.py --epochs 200 --batch 16 --device 0
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--model` | yolov8n.pt | 预训练模型 (n=纳米, s=小) |
| `--epochs` | 200 | 训练轮数 |
| `--batch` | 16 | 批次大小 (8G 显存: 16, 12G: 32) |
| `--imgsz` | 640 | 输入图片尺寸 |
| `--patience` | 50 | 早停耐心值 |
| `--mosaic` | 0.5 | Mosaic 增强概率 |

---

### 4. ArcFace — 汉字分类匹配

**作用**：将 YOLO 检测到的文字区域映射为 256 维 embedding，通过余弦相似度将提示字与候选字匹配。

| 属性 | 值 |
|------|-----|
| 架构 | ResNet18 → 256-dim L2-normalized → ArcFaceHead |
| 输入 | 112×112 RGB |
| 损失函数 | ArcFace Loss (CrossEntropy + angular margin) |
| 优化器 | SGD (lr=0.01, momentum=0.9, weight_decay=5e-4) |
| 学习率调度 | CosineAnnealing |
| Margin warmup | 前 5 轮线性增大 m (0 → 0.35) |
| 推理格式 | ONNX (onnxruntime) |
| 权重 | `backend/models/click_captcha/arcface_backbone.onnx` |

**训练数据**：使用 `generate_arcface_data.py` 通过 ImageDraw 合成单字图片 (约 200 个常用汉字 × 500 张/字 = 10 万张)，按 train/val 划分。

```bash
cd backend/training/arcface_training

# 1. 生成训练数据
python data/generate_arcface_data.py --samples_per_char 500

# 2. 训练 (best_model.pth 保存在 runs/arcface/)
python classify_train.py --device cuda:0 --epochs 80 --batch 256 --m 0.35

# 3. 导出 ONNX 到 backend/models/click_captcha/arcface_backbone.onnx
python _export.py
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--m` | 0.35 | ArcFace margin (弧度)，越大同类越紧凑，建议 0.35~0.5 |
| `--s` | 30.0 | 缩放因子 (固定) |
| `--warmup_epochs` | 5 | margin 预热轮数 (从 0 线性增大到 m) |
| `--lr` | 0.01 | 学习率 (SGD) |
| `--epochs` | 80 | 训练轮数 |
| `--batch` | 256 | 批次大小 |
| `--embedding_dim` | 256 | embedding 维度 |
| `--backbone` | resnet18 | 特征提取网络 |

---

## 配置

训练超参数集中在各模块的配置文件中，可通过命令行参数覆盖：

| 模块 | 配置文件 | 主要参数 |
|------|----------|----------|
| 分类器 | `training/classifier/train_config.py` | epochs=10, batch=32, lr=0.001, dropout=0.5 |
| CRNN 文字识别 | `training/text_captcha/train_config.py` | epochs=50, batch=64, lr=0.001, scheduler=cosine |
| YOLO 检测 | `training/click_captcha/config.py` | epochs=200, batch=16, lr0=0.001, patience=50 |
| ArcFace | `training/arcface_training/config.py` | epochs=80, batch=32, lr=0.01, m=0.35, s=30.0 |

所有训练脚本均支持 `--help` 查看完整参数列表。

---

## 测试

```bash
# 单元测试 (分类器 + Agent)
cd backend
python -m pytest tests/ -v

# 点选验证码端到端测试
python tests/test_click_captcha.py -i <图片路径>
```

---

## 技术栈

| 组件 | 技术 |
|------|------|
| 后端框架 | FastAPI + uvicorn |
| 前端框架 | React 18 + Vite |
| YOLO 检测 | ultralytics YOLOv8 (.pt) |
| ArcFace 推理 | ONNX Runtime |
| 文字识别 | CRNN + CTC (PyTorch) |
| 图像处理 | OpenCV, Pillow |
| 训练框架 | PyTorch, torchvision |

---


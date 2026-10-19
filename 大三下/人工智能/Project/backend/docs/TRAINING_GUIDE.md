# 训练流程指南

## 环境

所有命令在 `Text_select_captcha/` 目录下执行，Python 使用 `D:/anaconda3/envs/captcha_recognition/python.exe`。

```
cd d:\zju\ai_project\captcha_recognition\Text_select_captcha
```

为方便，以下用 `python` 代替完整路径，但运行时请用上面那个路径。

---

## 第一步：环境确认

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -c "import torch; print('CUDA:', torch.cuda.is_available()); from ultralytics import YOLO; print('ultralytics OK')"
```

预期输出：`CUDA: True` + `ultralytics OK`

---

## 第二步：生成训练数据

数据合成器在 `train/data/synthesize.py`，三种难度可选：

```bash
# 生成 500 张 hard 难度（推荐）
D:/anaconda3/envs/captcha_recognition/python.exe train/data/synthesize.py --num 500 --output data/synthetic --difficulty hard --seed 42
```

参数说明：
| 参数 | 含义 | 可选值 |
|------|------|--------|
| `--num` | 图片数量 | 推荐 500 |
| `--difficulty` | 难度 | easy / medium / hard |
| `--output` | 输出目录 | 默认 data/synthetic |

产物：`data/synthetic/images/*.png` + `data/synthetic/labels/*.txt`

---

## 第三步：分割训练/验证集

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -c "
import os, random, shutil
from pathlib import Path

base = Path('data/synthetic')
imgs = sorted((base/'images').glob('*.png'))
random.seed(42); random.shuffle(imgs)

n_val = int(len(imgs) * 0.2)
for split, img_set in [('train', imgs[n_val:]), ('val', imgs[:n_val])]:
    (base/'images'/split).mkdir(parents=True, exist_ok=True)
    (base/'labels'/split).mkdir(parents=True, exist_ok=True)
    for p in img_set:
        shutil.move(str(p), str(base/'images'/split/p.name))
        lbl = base/'labels'/f'{p.stem}.txt'
        if lbl.exists():
            shutil.move(str(lbl), str(base/'labels'/split/f'{p.stem}.txt'))

# 更新 data.yaml
yaml_content = f'path: {base.resolve()}\ntrain: images/train\nval: images/val\nnc: 2\nnames:\n  0: target\n  1: char\n'
print(f'Train: {len(imgs) - n_val}, Val: {n_val}')
(base/'data.yaml').write_text(yaml_content, encoding='utf-8')
print('data.yaml 已更新')
"
```

---

## 第四步：训练 YOLO

使用 `-m` 方式运行，避免 import 问题：

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -m train.yolo.train --data data/synthetic/data.yaml --epochs 200 --batch 16 --device 0 --model yolov8n.pt
```

**首次运行会从 GitHub 下载 yolov8n.pt（~6MB），需要代理。**

参数说明：
| 参数 | 含义 | 建议值 |
|------|------|--------|
| `--model` | 预训练权重 | yolov8n.pt（轻量）/ yolov8s.pt（中等） |
| `--epochs` | 训练轮数 | 200（带早停，不一定跑满） |
| `--batch` | 批次大小 | 16（8G 显存刚好） |
| `--device` | GPU 编号 | 0 |
| `--patience` | 早停耐心 | 50（50轮不涨就停） |

训练产物在 `train/runs/yolo/captcha_yolo/weights/best.pt`。

---

## 第五步：训练 Siamese

### 5.1 用训练好的 YOLO 裁剪字符

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -m train.data.prepare_siamese --mode crop --yolo_weights train/runs/yolo/captcha_yolo/weights/best.pt --image_dir data/synthetic/images/train
```

产物：`train/data/siamese/crops/` 下每张图一个目录，里面有 `target_*.png` 和 `char_*.png`。

### 5.2 生成字符分组

上一步会自动生成 `train/data/siamese/char_groups.json`，打开编辑，把相同文字的裁剪图路径归入同一组。

由于合成数据是程序生成的，字符是确定的，我们可以直接用脚本自动分组：

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -c "
import json
from pathlib import Path
from collections import defaultdict

crops_dir = Path('train/data/siamese/crops')
groups = defaultdict(list)

for d in sorted(crops_dir.iterdir()):
    if not d.is_dir(): continue
    for f in sorted(d.glob('char_*.png')):
        # 同一张图内的 char 是同一组提示栏文字，自动按图片分组
        groups[d.name].append(str(f.relative_to(crops_dir.parent)))
    for f in sorted(d.glob('target_*.png')):
        groups[d.name].append(str(f.relative_to(crops_dir.parent)))

output = {'groups': dict(groups)}
with open('train/data/siamese/char_groups.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)
print(f'已生成 {len(groups)} 个分组')
"
```

### 5.3 生成配对数据

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -m train.data.prepare_siamese --mode pairs
```

产物：`train/data/siamese/train_pairs.csv` + `val_pairs.csv`。

### 5.4 训练 Siamese

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -m train.siamese.train --epochs 100 --batch 64 --backbone lite --device cuda
```

参数说明：
| 参数 | 含义 |
|------|------|
| `--backbone lite` | 轻量 CNN（~2MB），适合小数据 |
| `--backbone resnet18` | ResNet-18（~44MB），需要更多数据 |
| `--embedding_dim 256` | 嵌入向量维度 |

训练产物：`train/runs/siamese/best_model.pth`，同时自动导出 ONNX 到 `model/pre_model_v7.onnx`。

---

## 第六步：验证训练结果

### 6.1 YOLO 检测验证

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -c "
from src.captcha import TextSelectCaptcha
from src.utils.matchingMode import open_image
import os

# 先用旧 Siamese + 新 YOLO 跑，看检测是否改善
cap = TextSelectCaptcha(yolo_path='best_v3.onnx')  # 先别替换，用旧模型
# 后续训练完 Siamese 再用新模型测试
"
```

### 6.2 生成对比报告数据

训练完 YOLO 后，跑一次 cross_domain_analysis 的对照实验：

```bash
D:/anaconda3/envs/captcha_recognition/python.exe -c "
from src.captcha import TextSelectCaptcha
from src.utils.matchingMode import open_image
import os

img_dir = 'data/synthetic_hard/images'
for name in sorted(os.listdir(img_dir))[:10]:
    path = os.path.join(img_dir, name)
    img = open_image(path)
    data = cap.yolo.inference(img)
    targets = [d for d in data if d[5] == 0]
    chars = [d for d in data if d[5] == 1]
    print(f'{name}: target={len(targets)}, char={len(chars)}')
"
```

---

## 快速索引

| 文件 | 作用 |
|------|------|
| `train/data/synthesize.py` | 数据合成器 |
| `train/yolo/train.py` | YOLO 训练脚本 |
| `train/siamese/train.py` | Siamese 训练脚本 |
| `train/data/prepare_siamese.py` | Siamese 数据准备 |
| `data/cross_domain_analysis.txt` | 跨域测试结果 |
| `technical_report.md` | 技术报告 |

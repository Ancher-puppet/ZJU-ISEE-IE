"""
ArcFace 点选验证码识别 - 测试
"""

import sys
import os
import time
import glob
from pathlib import Path

import cv2
import numpy as np

_BACKEND = Path(__file__).resolve().parent.parent  # backend/
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from app.models.click_captcha.utils import hint_splitter, matchingMode, arcface_onnx
from ultralytics import YOLO


def run_test(img: np.ndarray):
    """测试"""
    model_dir = _BACKEND / "models" / "click_captcha"

    print("=" * 60)
    print("1. 加载模型")
    print("=" * 60)
    t0 = time.time()
    
    yolo = YOLO(str(model_dir / "yolo" / "best.pt"), task='detect')
    arcface = arcface_onnx.ArcFaceONNX(str(model_dir / "arcface_backbone.onnx"), device="cpu")
    print(f"   耗时: {time.time() - t0:.2f}s")

    print()
    print("=" * 60)
    print("2. YOLO 检测")
    print("=" * 60)
    
    results = yolo(img, verbose=False)
    boxes = results[0].boxes
    
    data = []
    if boxes is not None and len(boxes) > 0:
        for box in boxes:
            xyxy = box.xyxy[0].cpu().numpy()  
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])
            data.append([xyxy[0], xyxy[1], xyxy[2], xyxy[3], conf, cls_id])
            
    print(f"   检测到 {len(data)} 个框:")
    for i, d in enumerate(data):
        x1, y1, x2, y2, conf, cls = d
        print(f"     [{i}] ({x1:.0f},{y1:.0f})-({x2:.0f},{y2:.0f}) conf={conf:.3f}")

    print()
    print("=" * 60)
    print("3. hint_splitter 分流")
    print("=" * 60)
    hint_idx, cand_idx = hint_splitter.split_hint_candidates(data, img)
    print(f"   hint 索引: {hint_idx}")
    print(f"   candidate 索引: {cand_idx}")

    if not hint_idx or not cand_idx:
        print("   FAIL: hint 或 candidate 为空")
        return

    hint_boxes = [data[i][:4] for i in hint_idx]
    cand_boxes = [data[i][:4] for i in cand_idx]

    print()
    print("=" * 60)
    print("4. 裁剪尺寸")
    print("=" * 60)
    hint_crops = [img[int(b[1]):int(b[3]), int(b[0]):int(b[2])] for b in hint_boxes]
    cand_crops = [img[int(b[1]):int(b[3]), int(b[0]):int(b[2])] for b in cand_boxes]
    for i, c in enumerate(hint_crops):
        print(f"   hint[{i}]: {c.shape}")
    for i, c in enumerate(cand_crops):
        print(f"   cand[{i}]: {c.shape}")

    print()
    print("=" * 60)
    print("5. ArcFace 相似度矩阵")
    print("=" * 60)
    sim = arcface.similarity_matrix(hint_crops, cand_crops)
    print(f"   矩阵形状: {sim.shape}")
    for row in sim:
        print("   ", [f"{v:.3f}" for v in row])

    print()
    print("=" * 60)
    print("6. 匹配结果")
    print("=" * 60)
    pairs = matchingMode.find_overall_index_fast(sim)
    print(f"   匹配对: {pairs}")
    for h, c in pairs:
        print(f"   hint[{h}] -> cand[{c}]  sim={sim[h][c]:.3f}")

    # 可视化
    vis = img.copy()
    for i, box in enumerate(hint_boxes):
        x1, y1, x2, y2 = [int(v) for v in box]
        cv2.rectangle(vis, (x1, y1), (x2, y2), (255, 255, 0), 2)
        cv2.putText(vis, f"H{i}", (x1, y1 - 3), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    for i, box in enumerate(cand_boxes):
        x1, y1, x2, y2 = [int(v) for v in box]
        cv2.rectangle(vis, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(vis, f"C{i}", (x1, y1 - 3), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

    os.makedirs("tests", exist_ok=True)
    cv2.imwrite("tests/test_click_output.png", vis)
    print(f"\n   可视化已保存: tests/test_click_output.png")

    print()
    print("=" * 60)
    if pairs and len(pairs) == len(hint_idx):
        print("PASS")
    elif pairs:
        print(f"WARN: {len(pairs)}/{len(hint_idx)}")
    else:
        print("FAIL")
    print("=" * 60)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--image", "-i", help="测试图片路径")
    args = parser.parse_args()

    if args.image:
        img = cv2.imread(args.image)
        if img is None:
            print(f"无法读取: {args.image}")
            sys.exit(1)
    else:
        # 用已有的合成图
        pattern = str(_BACKEND / "training" / "click_captcha" / "data" / "yolo" / "images" / "train" / "*.png")
        images = sorted(glob.glob(pattern))
        if not images:
            print("未找到图片")
            sys.exit(1)
        img = cv2.imread(images[0])
        print(f"使用图片: {images[0]}")

    run_test(img)
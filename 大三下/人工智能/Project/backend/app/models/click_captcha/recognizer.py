"""文字点选验证码识别器 — YOLO (ultralytics) + 几何/UI 后处理 + ArcFace 匹配"""

from pathlib import Path
from typing import Any, Dict, List, Optional

import cv2
import numpy as np
from ultralytics import YOLO as UltralyticsYOLO

_BACKEND = Path(__file__).resolve().parent.parent.parent.parent

from app.models.click_captcha.utils import arcface_onnx, matchingMode
from app.models.click_captcha.utils.hint_splitter import split_hint_candidates


class ClickCaptchaRecognizer:
    """
    文字点选验证码识别器（ultralytics YOLO + 后处理分流 + ArcFace embedding 匹配）。

    输入：BGR 图像 (H, W, 3) uint8
    输出：{
        "hint_chars": [{"bbox": [...], "text_id": int}, ...],
        "candidates": [{"bbox": [...], "text_id": int}, ...],
        "click_positions": [[cx, cy], ...],
        "confidence": float,
        "visualization": np.ndarray (BGR)
    }
    """

    def __init__(
        self,
        yolo_path: str | None = None,
        arcface_path: str | None = None,
        device: str = "cpu",
    ):
        model_dir = _BACKEND / "models" / "click_captcha"
        if yolo_path is None:
            yolo_path = str(model_dir / "yolo" / "best.pt")
        if arcface_path is None:
            arcface_path = str(model_dir / "arcface_backbone.onnx")

        self.yolo = UltralyticsYOLO(yolo_path)
        self.arcface = arcface_onnx.ArcFaceONNX(arcface_path, device=device)

    # ------------------------------------------------------------------
    def recognize(self, image: np.ndarray, target: Optional[str] = None) -> Dict[str, Any]:
        img = matchingMode.open_image(image)  # BGR

        # ---- Stage 1: YOLO 检测（ultralytics 引擎，自带 Letterbox + NMS） ----
        results = self.yolo(img, conf=0.5, verbose=False)
        data = []
        for box in results[0].boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])
            data.append([int(x1), int(y1), int(x2), int(y2), conf, cls_id])

        if not data:
            return self._empty_result(img)

        # ---- Stage 2: hint / candidate 分流 ----
        hint_indices, candidate_indices = split_hint_candidates(data, img)

        if not hint_indices or not candidate_indices:
            return self._empty_result(img)

        # 提示字排序
        hint_items = [data[i] for i in hint_indices]
        hint_boxes = [item[:4] for item in hint_items]

        hint_centers_y = [(b[1] + b[3]) / 2 for b in hint_boxes]
        hint_centers_x = [(b[0] + b[2]) / 2 for b in hint_boxes]
        if np.std(hint_centers_y) < np.std(hint_centers_x):
            hint_order = sorted(range(len(hint_boxes)), key=lambda i: hint_boxes[i][0])
        else:
            hint_order = sorted(range(len(hint_boxes)), key=lambda i: hint_boxes[i][1])

        hint_boxes_sorted = [hint_boxes[i] for i in hint_order]

        # 候选字
        candidate_items = [data[i] for i in candidate_indices]
        candidate_boxes = [item[:4] for item in candidate_items]

        # ---- Stage 3: ArcFace embedding 匹配 ----
        hint_crops = [
            img[int(b[1]):int(b[3]), int(b[0]):int(b[2])] for b in hint_boxes_sorted
        ]
        candidate_crops = [
            img[int(b[1]):int(b[3]), int(b[0]):int(b[2])] for b in candidate_boxes
        ]

        sim_matrix = self.arcface.similarity_matrix(hint_crops, candidate_crops)
        sorted_pairs = matchingMode.find_overall_index_fast(sim_matrix)

        # ---- Stage 4: 构建输出 ----
        targets = []
        click_positions = []
        for pair_idx, (hint_i, cand_j) in enumerate(sorted_pairs):
            box = candidate_boxes[cand_j]
            x1, y1, x2, y2 = [int(v) for v in box]
            sim_conf = float(
                sim_matrix[hint_i][cand_j]
            ) if hint_i < sim_matrix.shape[0] and cand_j < sim_matrix.shape[1] else 0.0

            targets.append({
                "label": f"目标{pair_idx + 1}",
                "confidence": round(sim_conf, 4),
                "bbox": [x1, y1, x2, y2],
            })
            click_positions.append([(x1 + x2) // 2, (y1 + y2) // 2])

        # 可视化
        vis = img.copy()
        for i, box in enumerate(hint_boxes_sorted):
            x1, y1, x2, y2 = [int(v) for v in box]
            cv2.rectangle(vis, (x1, y1), (x2, y2), (255, 255, 0), 1)
            cv2.putText(vis, f"H{i+1}", (x1, y1 - 3),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 0), 1)

        for i, box in enumerate(candidate_boxes):
            x1, y1, x2, y2 = [int(v) for v in box]
            cv2.rectangle(vis, (x1, y1), (x2, y2), (0, 255, 0), 2)
            for pair_idx, (_, cand_j) in enumerate(sorted_pairs):
                if cand_j == i:
                    cv2.putText(vis, str(pair_idx + 1), (x1, y1 - 5),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
                    break

        all_confidences = [item[4] for item in data]
        avg_yolo_conf = float(np.mean(all_confidences)) if all_confidences else 0.0

        return {
            "hint_chars": [
                {"bbox": [int(v) for v in hint_boxes_sorted[i]],
                 "text_id": i} for i in range(len(hint_boxes_sorted))
            ],
            "candidates": [
                {"bbox": [int(v) for v in candidate_boxes[i]],
                 "text_id": i} for i in range(len(candidate_boxes))
            ],
            "targets": targets,
            "click_positions": click_positions,
            "confidence": round(avg_yolo_conf, 4),
            "visualization": vis,
        }

    # ------------------------------------------------------------------
    @staticmethod
    def _empty_result(img: np.ndarray) -> Dict[str, Any]:
        return {
            "hint_chars": [],
            "candidates": [],
            "targets": [],
            "click_positions": [],
            "confidence": 0.0,
            "visualization": img.copy(),
        }

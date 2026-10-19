import cv2
import numpy as np
from typing import Dict, Any


class RuleBasedClassifier:
    """基于传统 CV 特征的规则分类器，用于快速验证和作为 CNN 的对比基线"""

    def __init__(self, text_threshold: float = 0.6):
        self.text_threshold = text_threshold

    def extract_features(self, image: np.ndarray) -> Dict[str, float]:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        # 特征 1：边缘密度 — 文字验证码边缘更密集
        edges = cv2.Canny(gray, 100, 200)
        edge_density = float(np.sum(edges > 0) / edges.size)

        # 特征 2：颜色丰富度 — 点击验证码颜色更丰富
        color_std = float(np.std(hsv[:, :, 0]))

        # 特征 3：连通域数量 — 文字验证码字符形成多个连通域
        _, binary = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY_INV)
        num_labels, _ = cv2.connectedComponents(binary)

        # 特征 4：纹理复杂度
        laplacian = cv2.Laplacian(gray, cv2.CV_64F)
        texture_complexity = float(np.var(laplacian))

        # 特征 5：亮度均值
        mean_brightness = float(np.mean(gray))

        return {
            "edge_density": edge_density,
            "color_std": color_std,
            "num_components": num_labels,
            "texture_complexity": texture_complexity,
            "mean_brightness": mean_brightness,
        }

    def classify(self, image: np.ndarray) -> Dict[str, Any]:
        features = self.extract_features(image)

        # 启发式规则加权打分
        score = 0.0

        # 文字验证码边缘密集
        if features["edge_density"] > 0.08:
            score += 0.25
        elif features["edge_density"] > 0.05:
            score += 0.15

        # 文字验证码颜色单一
        if features["color_std"] < 40:
            score += 0.25
        elif features["color_std"] < 60:
            score += 0.15

        # 文字验证码连通域多（字符）
        if features["num_components"] > 15:
            score += 0.25
        elif features["num_components"] > 8:
            score += 0.15

        # 文字验证码纹理较简单
        if features["texture_complexity"] < 500:
            score += 0.25
        elif features["texture_complexity"] < 1000:
            score += 0.10

        is_text = score >= self.text_threshold

        return {
            "type": "text" if is_text else "click",
            "confidence": score if is_text else (1.0 - score),
            "features": features,
        }

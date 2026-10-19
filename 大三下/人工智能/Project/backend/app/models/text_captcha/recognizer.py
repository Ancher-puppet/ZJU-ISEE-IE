"""文字验证码识别器 — 基于 NumCog 的 CRNN+CTC 模型"""

from pathlib import Path
from typing import Any, Dict

import numpy as np

# backend/ 目录（4 级往上）
_BACKEND = Path(__file__).resolve().parent.parent.parent.parent

from app.models.text_captcha.predict import CaptchaPredictor


class TextCaptchaRecognizer:
    """文字验证码识别器（CRNN + CTC），对接 NumCog 模块。

    输入：BGR 图像 (H, W, 3) uint8
    输出：{"text": str, "confidence": float [0,1], "char_confidences": list[float]}
    """

    def __init__(self, model_path: str | None = None, device: str = "cpu"):
        if model_path is None:
            model_path = str(
                _BACKEND / "models" / "text_captcha" / "best_model.pth"
            )
        self.predictor = CaptchaPredictor(checkpoint_path=model_path)

    def recognize(self, image: np.ndarray) -> Dict[str, Any]:
        # NumCog 的 load_image 原生支持 numpy array → 自动转 PIL RGB
        result = self.predictor.recognize(image)

        return {
            "text": result["text"],
            "confidence": result["confidence"] / 100.0,  # NumCog 返回 0-100，转为 [0,1]
            "char_confidences": [],
        }

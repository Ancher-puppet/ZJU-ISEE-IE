"""
推理引擎 — 加载训练好的模型进行验证码识别

支持：
  - 单张/批量图片推理
  - CTC 贪心解码
  - 多种输入格式（文件路径、bytes、PIL Image、numpy array）
  - MCP 兼容的函数接口
"""

import io
import time
from pathlib import Path
from typing import Optional, Union

import numpy as np
import torch
from PIL import Image
from torchvision import transforms

from . import config
from .model import CRNN


# ═══════════════════════════════════════════════════════════════════════════
# 从 dataset.py 中提取的推理工具（训练代码在 training/text_captcha/dataset.py）
# ═══════════════════════════════════════════════════════════════════════════


def decode_indices(indices: list[int]) -> str:
    """将 CTC 解码后的索引序列转回文本，去除 blank 和重复字符。"""
    chars = []
    prev = None
    for idx in indices:
        if idx == config.BLANK_IDX:
            prev = None
            continue
        if idx != prev:
            chars.append(config.IDX_TO_CHAR.get(idx, ""))
        prev = idx
    return "".join(chars)


class CaptchaPreprocessor:
    """验证码图像预处理：灰度化 + 归一化 → Tensor"""

    def __init__(self, augment: bool = False):
        self.augment = augment
        pipeline = [
            transforms.Grayscale(num_output_channels=1),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5], std=[0.5]),
        ]
        if augment:
            pipeline.insert(1, transforms.RandomAdjustSharpness(sharpness_factor=2, p=0.3))
            pipeline.insert(1, transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 1.0)))
        self.transform = transforms.Compose(pipeline)

    def __call__(self, image: Image.Image) -> torch.Tensor:
        return self.transform(image)


# ═══════════════════════════════════════════════════════════════════════════
# 模型加载
# ═══════════════════════════════════════════════════════════════════════════


def load_model(
    checkpoint_path: Union[str, Path] = None,
    device: torch.device = None,
) -> CRNN:
    """
    从检查点加载 CRNN 模型。

    Args:
        checkpoint_path: 模型检查点路径，默认使用 best_model.pth
        device: 运行设备

    Returns:
        加载好权重的 CRNN 模型（eval 模式）
    """
    if checkpoint_path is None:
        checkpoint_path = config.DEFAULT_CHECKPOINT
    if device is None:
        device = config.DEVICE

    checkpoint_path = Path(checkpoint_path)
    if not checkpoint_path.exists():
        raise FileNotFoundError(
            f"Model checkpoint not found: {checkpoint_path}\n"
            f"Please train the model first: python -m app.models.text_captcha.train"
        )

    # 创建模型
    model = CRNN()

    # 加载权重
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model = model.to(device)
    model.eval()

    # 执行一次 dummy forward 来初始化动态层（如果有）
    dummy = torch.randn(1, config.IMAGE_CHANNELS, config.IMAGE_HEIGHT, config.IMAGE_WIDTH).to(device)
    with torch.no_grad():
        _ = model(dummy)

    return model


# ═══════════════════════════════════════════════════════════════════════════
# 图像加载工具
# ═══════════════════════════════════════════════════════════════════════════


def load_image(image_input) -> Image.Image:
    """
    从多种输入格式加载为 PIL Image。

    支持: 文件路径(str/Path), bytes, PIL Image, numpy array。
    """
    if isinstance(image_input, Image.Image):
        return image_input

    if isinstance(image_input, (str, Path)):
        path = Path(image_input)
        if not path.exists():
            raise FileNotFoundError(f"Image not found: {path}")
        return Image.open(path).convert("RGB")

    if isinstance(image_input, bytes):
        return Image.open(io.BytesIO(image_input)).convert("RGB")

    if isinstance(image_input, np.ndarray):
        return Image.fromarray(image_input.astype(np.uint8)).convert("RGB")

    raise TypeError(f"Unsupported image type: {type(image_input)}")


def _resize_with_padding(
    image: Image.Image,
    target_w: int,
    target_h: int,
    bg_color: tuple = None,
) -> Image.Image:
    """
    等比缩放 + 背景色填充到目标尺寸。

    保持原始宽高比缩放（不会拉伸变形），
    空余区域用图片的平均背景色填充。

    Args:
        image: 原始 PIL Image
        target_w: 目标宽度
        target_h: 目标高度
        bg_color: 填充颜色，None 时自动取图片四角平均色

    Returns:
        目标尺寸的 PIL Image
    """
    orig_w, orig_h = image.size

    # 计算等比缩放比例（取较小值，确保不超出目标尺寸）
    scale = min(target_w / orig_w, target_h / orig_h)
    new_w = int(orig_w * scale)
    new_h = int(orig_h * scale)

    # 等比缩放
    resized = image.resize((new_w, new_h), Image.BICUBIC)

    # 自动检测背景色（取图片四角像素的平均值）
    if bg_color is None:
        corners = [
            image.getpixel((0, 0)),
            image.getpixel((orig_w - 1, 0)),
            image.getpixel((0, orig_h - 1)),
            image.getpixel((orig_w - 1, orig_h - 1)),
        ]
        # corners 可能是 int（灰度）或 tuple（RGB）
        if isinstance(corners[0], int):
            bg_color = (int(sum(corners) / 4),) * 3
        else:
            bg_color = tuple(int(sum(ch) / 4) for ch in zip(*corners))

    # 创建目标画布，用背景色填充
    canvas = Image.new("RGB", (target_w, target_h), bg_color)

    # 居中粘贴缩放后的图片
    offset_x = (target_w - new_w) // 2
    offset_y = (target_h - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y))

    return canvas


# ═══════════════════════════════════════════════════════════════════════════
# 推理类
# ═══════════════════════════════════════════════════════════════════════════


class CaptchaPredictor:
    """
    验证码识别推理器。

    Usage:
        predictor = CaptchaPredictor("checkpoints/best_model.pth")
        result = predictor.recognize("captcha.png")
        print(result["text"])  # e.g. "A3B7"
    """

    def __init__(
        self,
        checkpoint_path: Union[str, Path] = None,
        device: torch.device = None,
    ):
        self.device = device or config.DEVICE
        self.model = load_model(checkpoint_path, self.device)
        self.preprocessor = CaptchaPreprocessor(augment=False)

    @torch.no_grad()
    def recognize(
        self,
        image_input,
        return_details: bool = False,
    ) -> dict:
        """
        识别验证码图片。

        Args:
            image_input: 图片输入（路径/bytes/PIL/numpy）
            return_details: 是否返回详细信息

        Returns:
            {
                "success": bool,
                "text": str,
                "confidence": float,  # 0-100
                "processing_time_ms": float,
            }
        """
        start = time.time()

        try:
            # 加载图片
            image = load_image(image_input)

            # [修复] 等比缩放 + 填充到模型要求的尺寸
            # 保持原始宽高比，字符不会变形；空余部分用背景色填充
            target_w, target_h = config.IMAGE_WIDTH, config.IMAGE_HEIGHT
            if image.size != (target_w, target_h):
                image = _resize_with_padding(image, target_w, target_h)

            # 预处理
            tensor = self.preprocessor(image).unsqueeze(0).to(self.device)  # [1, 1, H, W]

            # 前向传播
            log_probs = self.model(tensor)  # [T, 1, C]

            # 贪心解码
            max_indices = log_probs.squeeze(1).argmax(dim=1)  # [T]
            indices = max_indices.cpu().tolist()
            text = decode_indices(indices)

            # 计算置信度（取最大概率的几何均值）
            probs = torch.exp(log_probs.squeeze(1))  # [T, C]
            max_probs, _ = probs.max(dim=1)  # [T]
            # 只取非 blank 时间步的置信度
            non_blank_mask = max_indices != config.BLANK_IDX
            if non_blank_mask.any():
                confidence = max_probs[non_blank_mask].mean().item() * 100
            else:
                confidence = 0.0

            elapsed = (time.time() - start) * 1000

            result = {
                "success": len(text) > 0,
                "text": text,
                "confidence": round(confidence, 2),
                "processing_time_ms": round(elapsed, 2),
            }

            if return_details:
                result["all_indices"] = indices
                result["seq_length"] = len(indices)

            return result

        except Exception as e:
            elapsed = (time.time() - start) * 1000
            return {
                "success": False,
                "text": "",
                "confidence": 0,
                "processing_time_ms": round(elapsed, 2),
                "error": str(e),
            }

    @torch.no_grad()
    def recognize_batch(self, image_inputs: list) -> list[dict]:
        """
        批量识别验证码。

        Args:
            image_inputs: 图片输入列表

        Returns:
            结果列表
        """
        results = []
        for img_input in image_inputs:
            result = self.recognize(img_input)
            results.append(result)
        return results


# ═══════════════════════════════════════════════════════════════════════════
# 模块级便捷函数（MCP 接口）
# ═══════════════════════════════════════════════════════════════════════════

_predictor = None


def get_predictor() -> CaptchaPredictor:
    """获取全局预测器实例（懒加载单例）。"""
    global _predictor
    if _predictor is None:
        _predictor = CaptchaPredictor()
    return _predictor


def recognize_captcha(image_path: str) -> str:
    """
    MCP 兼容接口：识别验证码，返回文本字符串。

    Args:
        image_path: 验证码图片路径

    Returns:
        识别出的文本

    Example:
        >>> from app.models.text_captcha.predict import recognize_captcha
        >>> text = recognize_captcha("captcha.png")
        >>> print(text)
        "A3B7"
    """
    predictor = get_predictor()
    result = predictor.recognize(image_path)
    return result["text"]


def recognize_captcha_detailed(image_path: str) -> dict:
    """
    MCP 兼容接口：识别验证码，返回详细结果。
    """
    predictor = get_predictor()
    return predictor.recognize(image_path, return_details=True)


# ═══════════════════════════════════════════════════════════════════════════
# CLI 入口
# ═══════════════════════════════════════════════════════════════════════════


def main():
    import sys

    if len(sys.argv) < 2:
        print("Usage: python -m app.models.text_captcha.predict <image_path> [--json]")
        print("       python -m app.models.text_captcha.predict --test")
        sys.exit(1)

    if sys.argv[1] == "--test":
        from training.text_captcha.dataset import generate_captcha_image

        print("Generating test CAPTCHA and recognizing...\n")
        for i in range(5):
            image, ground_truth = generate_captcha_image(noisy=True)
            predictor = get_predictor()
            result = predictor.recognize(image)
            mark = "[OK]" if result["text"] == ground_truth else "[X]"
            print(
                f"  [{i+1}] GT: {ground_truth:5s} | "
                f"Pred: {result['text']:5s} | "
                f"Conf: {result['confidence']:5.1f}% | "
                f"{result['processing_time_ms']:6.1f}ms | {mark}"
            )
        return

    image_path = sys.argv[1]
    result = recognize_captcha_detailed(image_path)

    if "--json" in sys.argv:
        import json
        print(json.dumps(result, indent=2))
    else:
        if result["success"]:
            print(f"Text:       {result['text']}")
            print(f"Confidence: {result['confidence']:.1f}%")
            print(f"Time:       {result['processing_time_ms']:.1f}ms")
        else:
            print(f"Failed: {result.get('error', 'Unknown error')}")


if __name__ == "__main__":
    main()

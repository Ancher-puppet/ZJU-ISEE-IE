"""验证码风格生成器 — 为文字和点选验证码提供多种随机风格"""

import os
import random
from PIL import Image, ImageFilter, ImageOps, ImageEnhance
import numpy as np

# ---- 文字验证码风格 ----

_TEXT_STYLES = ["normal", "heavy_noise", "warped", "clean"]


def generate_text_styled(text: str) -> Image.Image:
    """随机选一种风格生成文字验证码。

    风格:
        normal     — 默认：浅色背景 + 中等噪点
        heavy_noise — 重噪点：更多干扰线、更强模糊
        warped     — 扭曲增强：更大旋转角 + 波浪扭曲
        clean      — 简洁：无干扰线、低噪点
    """
    from training.text_captcha.dataset import generate_captcha_image

    style = random.choice(_TEXT_STYLES)
    img, _ = generate_captcha_image(text=text, noisy=True)

    if style == "heavy_noise":
        img = _add_heavy_noise(img)
    elif style == "warped":
        img = _add_warp_effect(img)
    elif style == "clean":
        img, _ = generate_captcha_image(text=text, noisy=False)
    # "normal" — 不做额外处理

    return img


def _add_heavy_noise(img: Image.Image) -> Image.Image:
    """在已有图片上叠加更多干扰。"""
    from PIL import ImageDraw
    import random as rnd

    draw = ImageDraw.Draw(img)
    w, h = img.size

    # 额外干扰线
    for _ in range(rnd.randint(2, 4)):
        x1, y1 = rnd.randint(0, w), rnd.randint(0, h)
        x2, y2 = rnd.randint(0, w), rnd.randint(0, h)
        c = rnd.randint(60, 160)
        draw.line([(x1, y1), (x2, y2)], fill=(c, c, c), width=rnd.randint(1, 3))

    # 额外噪点
    for _ in range(rnd.randint(30, 80)):
        x, y = rnd.randint(0, w - 1), rnd.randint(0, h - 1)
        r = rnd.randint(1, 3)
        c = rnd.randint(40, 140)
        draw.ellipse([(x - r, y - r), (x + r, y + r)], fill=(c, c, c))

    # 更强模糊
    img = img.filter(ImageFilter.GaussianBlur(radius=rnd.uniform(0.5, 1.2)))

    return img


def _add_warp_effect(img: Image.Image) -> Image.Image:
    """对图片施加波浪扭曲效果。"""
    arr = np.array(img.convert("RGB"))
    h, w = arr.shape[:2]

    # 水平波浪扭曲
    amplitude = random.uniform(2, 5)
    frequency = random.uniform(0.02, 0.05)
    phase = random.uniform(0, 6.28)

    row_indices = np.arange(h)
    col_indices = np.arange(w)

    # 对每行施加水平偏移
    shifts = (amplitude * np.sin(frequency * col_indices + phase)).astype(int)
    warped = np.zeros_like(arr)

    for y in range(h):
        warped[y] = np.roll(arr[y], shifts[y], axis=0)

    # 边缘填充
    result = Image.fromarray(warped)

    # 轻微模糊软化锯齿
    result = result.filter(ImageFilter.GaussianBlur(radius=0.3))

    return result


# ---- 文字点选验证码风格 ----

def generate_click_styled(
    target_chars: list[str] | None = None,
    difficulty: str = "normal",
    use_background: bool = True,
) -> Image.Image:
    """合成文字点选验证码。

    difficulty: "easy" | "normal"
      - easy:  小旋转、无干扰线/噪点/描边、背景干净 → 适合演示
      - normal: 完整随机干扰 → 训练/生产
    use_background: 是否使用真实风景/图片背景（False 则用纯色+噪点/渐变）
    """
    import random as _rand
    from training.click_captcha.data.synthesize import _synthesize_impl, CHAR_POOL

    if target_chars:
        target_chars = list(target_chars)
    else:
        target_chars = _rand.sample(CHAR_POOL, k=_rand.randint(3, 5))

    num_distractors = _rand.randint(2, 4)
    available = [c for c in CHAR_POOL if c not in target_chars]
    distractor_chars = _rand.sample(available, k=min(num_distractors, len(available)))

    bg_dir = os.path.join(os.path.dirname(__file__), "..", "training", "click_captcha", "data", "backgrounds") if use_background else ""
    img, anns = _synthesize_impl(target_chars, distractor_chars, bg_dir=bg_dir, difficulty=difficulty)
    return img

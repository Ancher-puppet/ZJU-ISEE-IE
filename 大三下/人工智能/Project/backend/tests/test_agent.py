"""
集成测试：验证 Agent 完整流程

用法:
    python tests/agent.py
"""

import sys
import time
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.agent.scheduler import CaptchaAgent


def create_dummy_text_image() -> np.ndarray:
    """创建模拟文字验证码：深色背景 + 白色字符形状"""
    img = np.random.randint(0, 80, (200, 400, 3), dtype=np.uint8)
    font = cv2.FONT_HERSHEY_SIMPLEX
    for i, char in enumerate("A3X9K"):
        x, y = 60 + i * 60, 120
        cv2.putText(img, char, (x, y), font, 1.5, (200, 220, 240), 3)
    for _ in range(15):
        x1, y1 = np.random.randint(0, 400), np.random.randint(0, 200)
        x2, y2 = x1 + np.random.randint(10, 60), y1 + np.random.randint(1, 4)
        cv2.line(img, (x1, y1), (x2, y2), (180, 180, 180), 1)
    return img


def create_dummy_click_image() -> np.ndarray:
    """创建模拟点击验证码：彩色场景图像"""
    img = np.zeros((300, 400, 3), dtype=np.uint8)
    img[:150, :] = [200, 180, 100]
    img[150:, :] = [80, 120, 60]
    for _ in range(3):
        cx, cy = np.random.randint(50, 350), np.random.randint(80, 220)
        cv2.circle(img, (cx, cy), np.random.randint(15, 35),
                   [int(x) for x in np.random.randint(50, 200, 3)], -1)
    return img


def run_tests():
    print("=" * 60)
    print("集成测试: CaptchaAgent 完整流程")
    print("=" * 60)

    # 使用规则分类器模式（不需要训练好的模型）
    agent = CaptchaAgent(use_cnn=False)

    # 测试 1: 自动模式 — 文字验证码
    print("\n[Test 1] 自动模式 + 模拟文字验证码")
    img_text = create_dummy_text_image()
    result = agent.route_and_recognize(img_text, mode="auto")
    print(f"  类型: {result['type']} | 置信度: {result['type_confidence']:.3f}")
    print(f"  结果: {result['result']}")
    print(f"  耗时: {result['processing_time']:.3f}s")
    print(f"  推理步骤数: {len(result['reasoning_steps'])}")
    for s in result["reasoning_steps"]:
        print(f"    Step {s['step']}: {s['action']} — {s['detail']}")

    # 测试 2: 自动模式 — 点击验证码
    print("\n[Test 2] 自动模式 + 模拟点击验证码")
    img_click = create_dummy_click_image()
    result = agent.route_and_recognize(img_click, mode="auto")
    print(f"  类型: {result['type']} | 置信度: {result['type_confidence']:.3f}")
    print(f"  结果: {result['result']}")
    print(f"  耗时: {result['processing_time']:.3f}s")

    # 测试 3: 手动指定模式
    print("\n[Test 3] 手动指定为文字验证码")
    result = agent.route_and_recognize(img_click, mode="text")
    print(f"  类型: {result['type']} (手动指定)")
    print(f"  推理步骤数: {len(result['reasoning_steps'])}")

    # 测试 4: 带 target 的点击验证码
    print("\n[Test 4] 指定 target='traffic light'")
    result = agent.route_and_recognize(img_click, mode="click", target="traffic light")
    print(f"  结果: targets={len(result['result'].get('targets', []))}")
    print(f"  click_positions: {result['result'].get('click_positions', [])}")

    print("\n" + "=" * 60)
    print("全部集成测试通过!")
    print("=" * 60)


if __name__ == "__main__":
    run_tests()

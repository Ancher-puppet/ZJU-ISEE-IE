"""
Hint Bar / Candidate 文字分离器 (v2)
=====================================
三方案结合，从 YOLO 单分类检测结果中分离"提示字"和"候选字"：

方案1 (边缘贴合): 提示栏永远紧贴图片四边之一（最强先验）
方案2 (几何拓扑): 提示字排列整齐（共线、大小一致、间距均匀）
方案3 (UI 容器检测): 提示字背后有纯色矩形背景板

三种方法的结果取并集。
"""

import itertools
from typing import List, Tuple

import cv2
import numpy as np


def split_hint_candidates(
    boxes: List[List[float]],
    image_bgr: np.ndarray,
) -> Tuple[List[int], List[int]]:
    """
    将 YOLO 检测框分为提示字（hint）和候选字（candidate）。
    带有优先级决策与严格的视觉顺序排序。
    """
    n = len(boxes)

    if n == 0:
        return [], []
    if n <= 2:
        return list(range(n)), []

    centers = np.array([[(b[0] + b[2]) / 2, (b[1] + b[3]) / 2] for b in boxes])
    widths = np.array([b[2] - b[0] for b in boxes])
    heights = np.array([b[3] - b[1] for b in boxes])
    h, w = image_bgr.shape[:2]

    # ---- 执行三种召回策略 ----
    edge_hints = _edge_strip_find_hints(boxes, centers, widths, heights, w, h)
    geo_hints = _geometric_find_hints(centers, widths, heights, w, h)
    ui_hints = _ui_container_find_hints(boxes, image_bgr)

    # ==========================================
    # 🌟 核心修改 1: 优先级决策树 (替代危险的并集)
    # ==========================================
    hint_list = []
    
    # 规则 A: 如果 UI 容器和 几何拓扑 找到了完全相同的字，那是 100% 准确的
    if ui_hints and geo_hints and set(ui_hints) == set(geo_hints):
        hint_list = ui_hints
        
    # 规则 B: 优先级 1 - UI容器最可靠 (因为它依赖我们生成的纯色底板物理特征)
    elif ui_hints and 3 <= len(ui_hints) <= 5: 
        hint_list = ui_hints
        
    # 规则 C: 优先级 2 - 边缘贴合 (基于强先验)
    elif edge_hints and 3 <= len(edge_hints) <= 5:
        hint_list = edge_hints
        
    # 规则 D: 优先级 3 - 纯几何计算 (兜底方案)
    elif geo_hints:
        hint_list = geo_hints
        
    # 极端兜底
    else:
        # 如果大家都没找到合适的，拿数量最靠谱的那个
        for candidate in [ui_hints, edge_hints, geo_hints]:
            if 2 <= len(candidate) <= 6:
                hint_list = candidate
                break
                
    if not hint_list:
        return [], list(range(n))

    # ==========================================
    # 🌟 核心修改 2: 严格根据视觉坐标排序 (恢复阅读顺序)
    # ==========================================
    hint_centers = centers[hint_list]
    y_var = np.var(hint_centers[:, 1])
    x_var = np.var(hint_centers[:, 0])
    
    # 如果 Y 坐标方差小于 X 坐标方差，说明字都在同一水平线上（横排）
    is_horizontal = y_var < x_var
    
    if is_horizontal:
        # 按 X 坐标从左到右排序
        hint_list.sort(key=lambda idx: centers[idx][0])
    else:
        # 按 Y 坐标从上到下排序
        hint_list.sort(key=lambda idx: centers[idx][1])

    # 候选字不需要特定顺序，直接用集合差集求出即可
    candidate_indices = sorted(list(set(range(n)) - set(hint_list)))

    return hint_list, candidate_indices


# ================================================================
# 方案 1: 边缘贴合 —— 提示栏永远紧贴图片四边之一
# ================================================================

def _edge_strip_find_hints(
    boxes: List[List[float]],
    centers: np.ndarray,
    widths: np.ndarray,
    heights: np.ndarray,
    img_w: int,
    img_h: int,
) -> List[int]:
    """
    扫描四条边，找紧贴边缘、排列整齐的一组框。
    提示栏位置（来自 synthesize.py）:
      - 水平: top 或 bottom 边缘，靠左/中/右
      - 垂直: left 或 right 边缘，靠上/中/下
    """
    n = len(boxes)
    # 边缘贴近阈值：框边距图边不超过 15px
    edge_threshold = 15

    # 四条候选边: (edge_name, strip_min, strip_max, is_horizontal)
    # strip: 对于水平提示栏，用 Y 坐标框定 strip；垂直则用 X
    candidates = []

    # --- 水平提示栏（贴 top / bottom） ---
    for y_range, edge_name in [((0, edge_threshold + 35), "top"), ((img_h - edge_threshold - 35, img_h), "bottom")]:
        # 收集 Y 坐标落在 strip 内的框
        in_strip = []
        for i in range(n):
            y1, y2 = boxes[i][1], boxes[i][3]
            # 框的至少一半在 strip 内
            box_mid_y = (y1 + y2) / 2
            if y_range[0] <= box_mid_y <= y_range[1]:
                in_strip.append(i)

        if len(in_strip) >= 2:
            # 评分：这些框是否在 X 方向排列整齐
            score = _score_alignment(
                centers[in_strip], widths[in_strip], heights[in_strip], is_horizontal=True
            )
            # 额外加分：靠边缘越近越好
            if edge_name == "top":
                edge_dist = np.mean([boxes[i][1] for i in in_strip])
            else:
                edge_dist = np.mean([img_h - boxes[i][3] for i in in_strip])
            edge_bonus = max(0, 1.0 - edge_dist / 30.0) * 0.3
            candidates.append((in_strip, score + edge_bonus, edge_name))

    # --- 垂直提示栏（贴 left / right） ---
    for x_range, edge_name in [((0, edge_threshold + 35), "left"), ((img_w - edge_threshold - 35, img_w), "right")]:
        in_strip = []
        for i in range(n):
            x1, x2 = boxes[i][0], boxes[i][2]
            box_mid_x = (x1 + x2) / 2
            if x_range[0] <= box_mid_x <= x_range[1]:
                in_strip.append(i)

        if len(in_strip) >= 2:
            score = _score_alignment(
                centers[in_strip], widths[in_strip], heights[in_strip], is_horizontal=False
            )
            if edge_name == "left":
                edge_dist = np.mean([boxes[i][0] for i in in_strip])
            else:
                edge_dist = np.mean([img_w - boxes[i][2] for i in in_strip])
            edge_bonus = max(0, 1.0 - edge_dist / 30.0) * 0.3
            candidates.append((in_strip, score + edge_bonus, edge_name))

    if not candidates:
        return []

    # 取得分最高的一组
    best = max(candidates, key=lambda c: c[1])
    best_group, best_score, best_edge = best

    if best_score > 0.35:
        return best_group
    return []


# ================================================================
# 方案 2: 几何拓扑 —— 找排列最整齐的那组框
# ================================================================

def _geometric_find_hints(
    centers: np.ndarray,
    widths: np.ndarray,
    heights: np.ndarray,
    img_w: int,
    img_h: int,
) -> List[int]:
    n = len(centers)
    if n < 2:
        return list(range(n))

    y_std = float(np.std(centers[:, 1]))
    x_std = float(np.std(centers[:, 0]))
    is_horizontal = y_std < x_std

    if is_horizontal:
        y_median = float(np.median(centers[:, 1]))
        threshold = max(15.0, img_h * 0.05)
        aligned_mask = np.abs(centers[:, 1] - y_median) < threshold
    else:
        x_median = float(np.median(centers[:, 0]))
        threshold = max(15.0, img_w * 0.05)
        aligned_mask = np.abs(centers[:, 0] - x_median) < threshold

    aligned_idx = np.where(aligned_mask)[0]
    if len(aligned_idx) < 2:
        return []

    score = _score_alignment(
        centers[aligned_idx], widths[aligned_idx], heights[aligned_idx], is_horizontal
    )

    if score > 0.5:
        return aligned_idx.tolist()

    best_score = 0.0
    best_group: List[int] = []

    for k in range(len(aligned_idx), 1, -1):
        for combo in itertools.combinations(aligned_idx.tolist(), k):
            combo_list = list(combo)
            s = _score_alignment(
                centers[combo_list],
                widths[combo_list],
                heights[combo_list],
                is_horizontal,
            )
            if s > best_score:
                best_score = s
                best_group = combo_list
        if best_score > 0.5:
            break

    return best_group if best_score > 0.4 else []


def _score_alignment(
    centers: np.ndarray,
    widths: np.ndarray,
    heights: np.ndarray,
    is_horizontal: bool,
) -> float:
    """对一组框的"整齐度"评分 (0~1)。"""
    if len(centers) < 2:
        return 0.0

    w_cv = float(np.std(widths) / (np.mean(widths) + 1e-6))
    h_cv = float(np.std(heights) / (np.mean(heights) + 1e-6))
    size_score = 1.0 - min(1.0, (w_cv + h_cv) / 2)

    if is_horizontal:
        sorted_pos = np.sort(centers[:, 0])
    else:
        sorted_pos = np.sort(centers[:, 1])

    gaps = np.diff(sorted_pos)
    if len(gaps) > 0:
        gap_mean = float(np.mean(gaps))
        gap_cv = float(np.std(gaps) / gap_mean) if gap_mean > 0 else 1.0
    else:
        gap_cv = 1.0

    spacing_score = 1.0 - min(1.0, gap_cv)

    return (size_score + spacing_score) / 2.0


# ================================================================
# 方案 3: UI 容器检测 —— 找浅色矩形提示栏背景
# ================================================================

def _ui_container_find_hints(
    boxes: List[List[float]],
    image_bgr: np.ndarray,
) -> List[int]:
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # 提取浅色区域 (提示栏背景 230-255)
    _, light_mask = cv2.threshold(gray, 195, 255, cv2.THRESH_BINARY)

    # 更大的闭运算核，填平字符间的空隙（字符 ~25px 宽 + 间距 ~10px）
    kernel_size = max(15, min(w, h) // 20)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_size, kernel_size))
    light_mask = cv2.morphologyEx(light_mask, cv2.MORPH_CLOSE, kernel)

    # 再开运算去掉小块噪点
    kernel_small = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    light_mask = cv2.morphologyEx(light_mask, cv2.MORPH_OPEN, kernel_small)

    contours, _ = cv2.findContours(light_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    min_area = (w * h) * 0.008  # 降低到 0.8%
    ui_rects: List[Tuple[int, int, int, int, float]] = []

    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area:
            continue

        rx, ry, rw, rh = cv2.boundingRect(cnt)
        rect_area = rw * rh
        if rect_area == 0:
            continue

        fill_ratio = area / rect_area
        aspect_ratio = max(rw, rh) / (min(rw, rh) + 1e-6)

        # 放宽条件：降低宽高比门槛，降低填充率门槛
        if fill_ratio > 0.5 and aspect_ratio > 1.5:
            # 靠边加分
            edge_dist = min(rx, w - (rx + rw), ry, h - (ry + rh))
            edge_bonus = max(0, 1.0 - edge_dist / 100.0) * 0.4
            score = fill_ratio * min(1.0, aspect_ratio / 6.0) + edge_bonus
            ui_rects.append((rx, ry, rx + rw, ry + rh, score))

    if not ui_rects:
        return []

    # 取得分最高的矩形
    best = max(ui_rects, key=lambda r: r[4])
    bx1, by1, bx2, by2, _ = best

    # 中心落在矩形内的框 = 提示字
    hint_indices = []
    for i, box in enumerate(boxes):
        cx = (box[0] + box[2]) / 2
        cy = (box[1] + box[3]) / 2
        margin = 8
        if bx1 - margin <= cx <= bx2 + margin and by1 - margin <= cy <= by2 + margin:
            hint_indices.append(i)

    return hint_indices

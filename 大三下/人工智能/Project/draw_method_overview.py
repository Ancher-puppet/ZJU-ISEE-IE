"""
Recreate method_overview.png as a code-generated figure.

Run:
  python draw_method_overview.py

Outputs:
  method_overview_outputs/method_overview_recreated.svg
  method_overview_outputs/method_overview_recreated.pdf
  method_overview_outputs/method_overview_recreated.png
"""

from __future__ import annotations

from pathlib import Path
from textwrap import wrap

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyArrowPatch, FancyBboxPatch, Polygon, Rectangle


mpl.rcParams["font.family"] = "DejaVu Sans"
mpl.rcParams["svg.fonttype"] = "none"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42

OUT_DIR = Path("method_overview_outputs")
W, H = 1410, 922

NAVY = "#2f5f8a"
BLUE_EDGE = "#1f5a8f"
BLUE_FILL = "#e8f1fb"
OP_FILL = "#d9e9f6"
GREEN_FILL = "#dceedd"
GREEN_EDGE = "#4e8b52"
TAN_FILL = "#f4eadb"
TAN_EDGE = "#b68b5a"
YELLOW_FILL = "#fff7df"
YELLOW_EDGE = "#f0a500"
GRAY = "#8b8b8b"
LIGHT_PANEL = "#ffffff"
PANEL_EDGE = "#d4d4d4"
INK = "#111111"


def setup():
    fig = plt.figure(figsize=(14.1, 9.22), dpi=120)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(H, 0)
    ax.axis("off")
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    fig.canvas.draw()
    return fig, ax


def wrap_text(text, max_chars):
    out = []
    for line in str(text).splitlines():
        out.extend(wrap(line, max_chars, break_long_words=False, break_on_hyphens=False) or [""])
    return "\n".join(out)


def text_fit(ax, x, y, w, h, text, fs=10, weight="normal", color=INK, z=20):
    fig = ax.figure
    renderer = fig.canvas.get_renderer()
    size = fs
    while size >= 5.5:
        candidate = wrap_text(text, max(7, int(w / (size * 0.58))))
        t = ax.text(
            x + w / 2,
            y + h / 2,
            candidate,
            ha="center",
            va="center",
            fontsize=size,
            weight=weight,
            color=color,
            linespacing=1.16,
            zorder=z,
        )
        fig.canvas.draw()
        bb = t.get_window_extent(renderer=renderer).transformed(ax.transData.inverted())
        if bb.width <= w - 10 and bb.height <= h - 7:
            return t
        t.remove()
        size -= 0.3
    return ax.text(
        x + w / 2,
        y + h / 2,
        wrap_text(text, max(6, int(w / (5.5 * 0.58)))),
        ha="center",
        va="center",
        fontsize=5.5,
        weight=weight,
        color=color,
        linespacing=1.05,
        zorder=z,
        clip_on=True,
    )


def box(ax, x, y, w, h, text, fill=BLUE_FILL, edge=BLUE_EDGE, fs=9.5, weight="normal", radius=6):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle=f"round,pad=0,rounding_size={radius}",
        linewidth=1.4,
        edgecolor=edge,
        facecolor=fill,
        zorder=5,
    )
    ax.add_patch(patch)
    text_fit(ax, x, y, w, h, text, fs=fs, weight=weight)
    return patch


def module(ax, x, y, w, h, text, fs=10):
    return box(ax, x, y, w, h, text, fill=NAVY, edge=NAVY, fs=fs, weight="bold")


def operation_title_box(ax, x, y, w, h, title, body):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0,rounding_size=6",
        linewidth=1.4,
        edgecolor="#4f8cc3",
        facecolor=OP_FILL,
        zorder=5,
    )
    ax.add_patch(patch)
    ax.text(
        x + w / 2,
        y + 23,
        title,
        ha="center",
        va="center",
        fontsize=10.2,
        weight="bold",
        color=INK,
        zorder=21,
    )
    text_fit(ax, x + 10, y + 34, w - 20, h - 40, body, fs=7.2, weight="normal")
    return patch


def arrow(ax, start, end, color=BLUE_EDGE, lw=2.0, ms=16, rad=0):
    ax.add_patch(
        FancyArrowPatch(
            start,
            end,
            arrowstyle="-|>",
            mutation_scale=ms,
            linewidth=lw,
            color=color,
            shrinkA=1,
            shrinkB=1,
            connectionstyle=f"arc3,rad={rad}",
            zorder=4,
        )
    )


def line_arrow(ax, pts, color=GRAY, lw=1.2):
    for a, b in zip(pts[:-2], pts[1:-1]):
        ax.plot([a[0], b[0]], [a[1], b[1]], color=color, linewidth=lw, zorder=3)
    arrow(ax, pts[-2], pts[-1], color=color, lw=lw, ms=12)


def input_3d(ax, x, y, w, h, text):
    ax.add_patch(Polygon([(x + 10, y - 10), (x + w + 10, y - 10), (x + w, y), (x, y)],
                         facecolor="#f4f8fc", edgecolor=BLUE_EDGE, linewidth=1.2, zorder=4))
    ax.add_patch(Polygon([(x + w, y), (x + w + 10, y - 10), (x + w + 10, y + h - 1), (x + w, y + h)],
                         facecolor="#d7e5f4", edgecolor=BLUE_EDGE, linewidth=1.2, zorder=4))
    return box(ax, x, y, w, h, text, fill=BLUE_FILL, edge=BLUE_EDGE, fs=9, radius=0)


def dashed_panel(ax, x, y, w, h, title):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0,rounding_size=24",
        linewidth=1.0,
        linestyle=(0, (6, 4)),
        edgecolor=PANEL_EDGE,
        facecolor="#ffffff",
        zorder=1,
    )
    ax.add_patch(patch)
    ax.text(x + 26, y + 22, title, ha="left", va="center", fontsize=14, weight="bold", zorder=20)


def badge(ax, x, y, text):
    ax.add_patch(FancyBboxPatch((x, y), 36, 24, boxstyle="round,pad=0,rounding_size=8",
                                facecolor="#eda80a", edgecolor="#d69500", linewidth=1.0, zorder=8))
    ax.text(x + 18, y + 12, text, ha="center", va="center", fontsize=8, weight="bold", color="white", zorder=9)


def draw_left(ax):
    box(ax, 20, 20, 500, 31, "Click Captcha Recognition Pipeline", fill="#ffffff", edge="#000000", fs=14, weight="bold", radius=4)

    input_3d(ax, 170, 75, 210, 42, "Input Image\n[H, W, 3]")
    arrow(ax, (275, 117), (275, 142), lw=2.0, ms=18)
    module(ax, 60, 144, 422, 58, "YOLOv8n\nObject Detector", fs=10)
    arrow(ax, (275, 202), (275, 230), lw=2.0, ms=18)
    box(ax, 20, 230, 500, 46, "Detection Boxes     [N, 6]     (x1, y1, x2, y2, conf, cls)", fs=8.8)
    arrow(ax, (275, 276), (275, 304), lw=2.0, ms=18)
    module(ax, 60, 304, 422, 54, "Hint / Candidate Splitter\n3 strategies: Edge - Geometric - UI Container    [see (a)]", fs=8.8)

    box(ax, 40, 400, 200, 48, "Hint Crops\n[N_hint, H, W, 3]", fill=GREEN_FILL, edge=GREEN_EDGE, fs=8.7)
    box(ax, 300, 400, 200, 48, "Candidate Crops\n[N_cand, H, W, 3]", fill=TAN_FILL, edge=TAN_EDGE, fs=8.7)
    line_arrow(ax, [(188, 358), (188, 378), (140, 378), (140, 400)], color=GREEN_EDGE, lw=2.0)
    line_arrow(ax, [(355, 358), (355, 378), (400, 378), (400, 400)], color=TAN_EDGE, lw=2.0)

    line_arrow(ax, [(140, 448), (140, 470), (270, 470), (270, 492)], color=BLUE_EDGE, lw=2.0)
    line_arrow(ax, [(400, 448), (400, 470), (270, 470), (270, 492)], color=BLUE_EDGE, lw=2.0)
    module(ax, 60, 492, 422, 54, "ArcFace Embedding Extractor xN\nResNet18 Backbone + L2 Normalize -> 256-dim     [see (b)]", fs=8.7)
    arrow(ax, (275, 546), (275, 570), lw=2.0, ms=18)
    box(ax, 20, 570, 500, 46, "Hint Embeddings [N_hint, 256]     |     Candidate Embeddings [N_cand, 256]     (L2-norm)", fs=8.4)
    arrow(ax, (275, 616), (275, 650), lw=2.0, ms=18)
    box(ax, 70, 650, 400, 40, "Cosine Similarity     S = H · C^T", fill=OP_FILL, edge=BLUE_EDGE, fs=10, weight="bold")
    arrow(ax, (275, 690), (275, 720), lw=2.0, ms=18)
    box(ax, 20, 720, 500, 40, "Similarity Matrix     [N_hint, N_cand]", fs=8.6)
    arrow(ax, (275, 760), (275, 790), lw=2.0, ms=18)
    module(ax, 60, 790, 422, 40, "Greedy Global Matching", fs=9.6)
    arrow(ax, (275, 830), (275, 860), lw=2.0, ms=18)
    box(ax, 50, 860, 440, 40, "Output: Click Positions     [(cx1, cy1), (cx2, cy2), ...]", fill="#d8f1dc", edge="#0aa43a", fs=9.6, weight="bold")


def draw_splitter_detail(ax):
    dashed_panel(ax, 584, 48, 820, 475, "(a) Hint / Candidate Splitter")
    operation_title_box(
        ax,
        618,
        105,
        236,
        82,
        "Edge Strip",
        "Scan 15px border edges\nGroup tightly-packed boxes\nScore by alignment quality",
    )
    operation_title_box(
        ax,
        878,
        105,
        236,
        82,
        "Geometric",
        "Find nearly-arranged group\nCommon Y/X coordinate\nConsistent size & spacing",
    )
    operation_title_box(
        ax,
        1136,
        105,
        236,
        82,
        "UI Container",
        "Threshold (gray > 195)\nMorphological close + open\nFind light panel contour",
    )
    line_arrow(ax, [(736, 187), (736, 236), (995, 236), (995, 286)], color=GRAY, lw=1.2)
    line_arrow(ax, [(996, 187), (996, 286)], color=GRAY, lw=1.2)
    line_arrow(ax, [(1254, 187), (1254, 236), (995, 236), (995, 286)], color=GRAY, lw=1.2)
    box(ax, 650, 286, 690, 90,
        "Priority Decision Tree\n\nUI ∩ Geometric same set? -> use it     |     UI finds 3-5 boxes? -> use UI     |     Edge finds 3-5 boxes? -> use Edge\nElse -> Geometric     |     Fallback -> largest group (2-6 boxes)",
        fill=YELLOW_FILL, edge=YELLOW_EDGE, fs=7.6, weight="bold")
    line_arrow(ax, [(995, 376), (995, 422), (830, 422), (830, 462)], color=GREEN_EDGE, lw=1.3)
    line_arrow(ax, [(995, 376), (995, 422), (1172, 422), (1172, 462)], color=TAN_EDGE, lw=1.3)
    box(ax, 754, 468, 150, 26, "hint_indices (sorted)", fill=GREEN_FILL, edge=GREEN_EDGE, fs=7.5, weight="bold", radius=4)
    box(ax, 1096, 468, 150, 26, "candidate_indices", fill=TAN_FILL, edge=TAN_EDGE, fs=7.5, weight="bold", radius=4)


def draw_embedding_detail(ax):
    dashed_panel(ax, 584, 570, 820, 165, "(b) ArcFace Embedding Extraction (per crop)")
    badge(ax, 638, 634, "xN")
    box(ax, 618, 640, 116, 72, "Crop Image\n[H', W', 3]", fs=8.6, weight="bold")
    box(ax, 770, 640, 116, 72, "Letterbox\n112×112", fs=8.6, weight="bold")
    module(ax, 936, 640, 116, 72, "ResNet18\nBackbone", fs=8.6)
    box(ax, 1096, 640, 116, 72, "L2\nNormalize", fs=8.8, weight="bold")
    box(ax, 1256, 640, 116, 72, "256-dim\nEmbedding", fs=8.8, weight="bold")
    arrow(ax, (734, 676), (770, 676), lw=1.8)
    arrow(ax, (886, 676), (936, 676), lw=1.8)
    arrow(ax, (1052, 676), (1096, 676), lw=1.8)
    arrow(ax, (1212, 676), (1256, 676), lw=1.8)


def draw_legend(ax):
    box(ax, 584, 785, 820, 115, "", fill="#ffffff", edge=PANEL_EDGE, radius=5)
    ax.text(614, 812, "Legend", fontsize=10.5, weight="bold", ha="left", va="center", zorder=20)
    box(ax, 614, 833, 50, 18, "", fill=BLUE_FILL, edge=BLUE_EDGE, radius=3)
    ax.text(686, 842, "Tensor", fontsize=8.3, va="center", zorder=20)
    module(ax, 815, 830, 52, 20, "", fs=1)
    ax.text(887, 842, "Module", fontsize=8.3, va="center", zorder=20)
    box(ax, 996, 830, 52, 20, "", fill=OP_FILL, edge="#4f8cc3", radius=3)
    ax.text(1068, 842, "Operation", fontsize=8.3, va="center", zorder=20)
    box(ax, 1196, 830, 52, 20, "", fill="#d8f1dc", edge="#0aa43a", radius=3)
    ax.text(1268, 842, "Output", fontsize=8.3, va="center", zorder=20)
    ax.add_patch(FancyArrowPatch((614, 880), (666, 880), arrowstyle="-|>", mutation_scale=18,
                                 linewidth=2.0, color=BLUE_EDGE, shrinkA=0, shrinkB=0, zorder=30))
    ax.text(686, 880, "Main flow", fontsize=8.3, va="center", zorder=20)
    ax.add_patch(FancyArrowPatch((815, 880), (868, 880), arrowstyle="-|>", mutation_scale=14,
                                 linewidth=1.4, color=GRAY, shrinkA=0, shrinkB=0, zorder=30))
    ax.text(887, 880, "Detail flow", fontsize=8.3, va="center", zorder=20)
    badge(ax, 1004, 868, "xN")
    ax.text(1056, 880, "xN badge", fontsize=8.3, va="center", zorder=20)


def main():
    OUT_DIR.mkdir(exist_ok=True)
    fig, ax = setup()
    draw_left(ax)
    draw_splitter_detail(ax)
    draw_embedding_detail(ax)
    draw_legend(ax)
    fig.savefig(OUT_DIR / "method_overview_recreated.svg", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(OUT_DIR / "method_overview_recreated.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(OUT_DIR / "method_overview_recreated.png", bbox_inches="tight", pad_inches=0.08, dpi=220)
    plt.close(fig)
    print(f"Saved method overview files to {OUT_DIR.resolve()}")


if __name__ == "__main__":
    main()

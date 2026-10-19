"""
Clean architecture diagram for the real text-CAPTCHA CRNN.

The figure mirrors:
  backend/app/models/text_captcha/model.py
  backend/app/models/text_captcha/config.py
  backend/app/models/text_captcha/predict.py

Run:
  python draw_network_architecture.py

Outputs:
  network_diagram_outputs/text_captcha_crnn.svg
  network_diagram_outputs/text_captcha_crnn.pdf
  network_diagram_outputs/text_captcha_crnn.png
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

OUT_DIR = Path("network_diagram_outputs")
W, H = 1800, 1180

INK = "#172033"
MUTED = "#607083"
LINE = "#4f6f8c"
PANEL = "#ffffff"
PANEL_EDGE = "#d4dde8"
BLUE = "#2f78b7"
BLUE_LIGHT = "#dceeff"
BLUE_EDGE = "#5f9fdc"
GREEN = "#ddf5e6"
GREEN_EDGE = "#66bd8a"
TEAL = "#d9f2f5"
TEAL_EDGE = "#4aa6b5"
GOLD = "#fff1cc"
GOLD_EDGE = "#d59a2a"
GRAY = "#eef2f6"
GRAY_EDGE = "#aeb9c7"


def setup():
    fig = plt.figure(figsize=(18, 11.8), dpi=120)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(H, 0)
    ax.axis("off")
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    fig.canvas.draw()
    return fig, ax


def wrapped(text, n):
    lines = []
    for line in str(text).splitlines():
        lines.extend(wrap(line, n, break_long_words=False, break_on_hyphens=False) or [""])
    return "\n".join(lines)


def fit_text(ax, x, y, w, h, text, fs=10, color=INK, weight="bold", clip=None, z=20):
    fig = ax.figure
    renderer = fig.canvas.get_renderer()
    size = fs
    while size >= 6.5:
        candidate = wrapped(text, max(7, int(w / (size * 0.58))))
        t = ax.text(
            x + w / 2,
            y + h / 2,
            candidate,
            ha="center",
            va="center",
            fontsize=size,
            color=color,
            weight=weight,
            linespacing=1.12,
            zorder=z,
        )
        fig.canvas.draw()
        bb = t.get_window_extent(renderer=renderer).transformed(ax.transData.inverted())
        if bb.width <= w - 12 and bb.height <= h - 8:
            if clip is not None:
                t.set_clip_path(clip)
            return t
        t.remove()
        size -= 0.35
    t = ax.text(
        x + w / 2,
        y + h / 2,
        wrapped(text, max(6, int(w / (6.5 * 0.58)))),
        ha="center",
        va="center",
        fontsize=6.5,
        color=color,
        weight=weight,
        linespacing=1.04,
        zorder=z,
        clip_on=True,
    )
    if clip is not None:
        t.set_clip_path(clip)
    return t


def panel(ax, x, y, w, h, title):
    ax.add_patch(FancyBboxPatch((x + 6, y + 8), w, h, boxstyle="round,pad=0,rounding_size=8",
                                linewidth=0, facecolor="#1e293b", alpha=0.07, zorder=0))
    patch = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=8",
                           linewidth=1.1, edgecolor=PANEL_EDGE, facecolor=PANEL, zorder=1)
    ax.add_patch(patch)
    ax.text(x + 20, y + 34, title, ha="left", va="center", fontsize=18, weight="bold", color="#173a5f", zorder=30)
    return patch


def title_strip(ax, x, y, w, label, color):
    ax.add_patch(FancyBboxPatch((x, y), w, 36, boxstyle="round,pad=0,rounding_size=8",
                                linewidth=0, facecolor=color, alpha=0.13, zorder=3))
    ax.add_patch(Circle((x + 24, y + 18), 14, facecolor=color, edgecolor="white", linewidth=1.5, zorder=4))
    ax.text(x + 24, y + 18, label[1], ha="center", va="center", fontsize=10, weight="bold", color="white", zorder=5)
    ax.text(x + 48, y + 18, label, ha="left", va="center", fontsize=13, weight="bold", color="#173a5f", zorder=5)


def box(ax, x, y, w, h, text, fill=BLUE_LIGHT, edge=BLUE_EDGE, fs=10, color=INK, radius=8):
    patch = FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0,rounding_size={radius}",
                           linewidth=1.2, edgecolor=edge, facecolor=fill, zorder=8)
    ax.add_patch(patch)
    fit_text(ax, x, y, w, h, text, fs=fs, color=color, clip=patch)
    return patch


def block3d(ax, x, y, w, h, text, fill=GRAY, edge=GRAY_EDGE, fs=10):
    ax.add_patch(Polygon([(x + 12, y - 12), (x + w + 12, y - 12), (x + w, y), (x, y)],
                         closed=True, facecolor="#f8fafc", edgecolor=edge, linewidth=0.9, zorder=6))
    ax.add_patch(Polygon([(x + w, y), (x + w + 12, y - 12), (x + w + 12, y + h - 2), (x + w, y + h)],
                         closed=True, facecolor=edge, edgecolor=edge, alpha=0.24, linewidth=0.9, zorder=6))
    return box(ax, x, y, w, h, text, fill=fill, edge=edge, fs=fs)


def dashed_group(ax, x, y, w, h, title, key, edge, fill):
    patch = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=16",
                           linewidth=2, linestyle=(0, (7, 6)), edgecolor=edge, facecolor=fill, zorder=2)
    ax.add_patch(patch)
    ax.add_patch(Circle((x + 28, y + 28), 17, facecolor=edge, edgecolor="white", linewidth=1.4, zorder=12))
    ax.text(x + 28, y + 28, key, ha="center", va="center", fontsize=11, weight="bold", color="white", zorder=13)
    label_w = min(max(len(title) * 7.5 + 28, 150), w - 70)
    label = FancyBboxPatch((x + 54, y - 15), label_w, 30, boxstyle="round,pad=0,rounding_size=6",
                           linewidth=1, edgecolor=edge, facecolor="white", zorder=11)
    ax.add_patch(label)
    fit_text(ax, x + 54, y - 15, label_w, 30, title, fs=10.2, color="#215984", clip=label, z=13)
    return patch


def arrow(ax, start, end, lw=2.0, color=LINE, rad=0):
    ax.add_patch(FancyArrowPatch(start, end, arrowstyle="-|>", mutation_scale=13, linewidth=lw,
                                 color=color, shrinkA=1, shrinkB=1,
                                 connectionstyle=f"arc3,rad={rad}", zorder=10))


def poly_arrow(ax, pts, lw=1.8, color=LINE):
    for a, b in zip(pts[:-2], pts[1:-1]):
        ax.plot([a[0], b[0]], [a[1], b[1]], color=color, linewidth=lw, solid_capstyle="round", zorder=9)
    arrow(ax, pts[-2], pts[-1], lw=lw, color=color)


def draw_overview(ax):
    panel(ax, 34, 32, 1732, 470, "(a) Text CAPTCHA Recognition Network")

    block3d(ax, 80, 232, 104, 118, "INPUT\n[B,1,60,160]", fs=9.4)
    box(ax, 220, 248, 116, 86, "Preprocess\nGray\nNormalize", fill=GRAY, edge=GRAY_EDGE, fs=8.8)

    dashed_group(ax, 392, 112, 360, 322, "CNN Feature Extractor", "b", BLUE_EDGE, "#f4f9ff")
    convs = [
        ("Conv1", "1 -> 32\n[B,32,30,80]"),
        ("Conv2", "32 -> 64\n[B,64,15,40]"),
        ("Conv3", "64 -> 128\n[B,128,7,20]"),
        ("Conv4", "128 -> 256\n[B,256,3,10]"),
        ("Conv5", "256 -> 256\n[B,256,1,10]"),
    ]
    for i, (name, detail) in enumerate(convs):
        yy = 146 + i * 54
        shade = ["#2f78b7", "#3880bd", "#4b91c8", "#61a4d2", "#79b7dd"][i]
        box(ax, 442, yy, 260, 38, f"{name}\n{detail}", fill=shade, edge=shade, fs=7.8, color="white")
        if i < 4:
            arrow(ax, (572, yy + 38), (572, yy + 54), lw=1.0)

    block3d(ax, 810, 210, 108, 104, "FEATURE\n[B,256,1,10]", fill=GREEN, edge=GREEN_EDGE, fs=9.6)
    block3d(ax, 810, 346, 108, 82, "SEQ\n[10,B,256]", fill=GREEN, edge=GREEN_EDGE, fs=9.8)
    fit_text(ax, 942, 352, 86, 38, "squeeze\npermute", fs=7.7, color=MUTED)

    dashed_group(ax, 1040, 130, 230, 288, "Sequence Modeling", "c", "#7aa0d8", "#f6f8ff")
    box(ax, 1080, 172, 150, 68, "BiLSTM Forward", fill="#a9c4ed", edge="#7aa0d8", fs=9.6)
    box(ax, 1080, 268, 150, 68, "BiLSTM Backward", fill="#e5ebf7", edge="#9fb5d8", fs=9.6)
    box(ax, 1080, 360, 150, 38, "Concat [10,B,512]", fill=GREEN, edge=GREEN_EDGE, fs=8.8)
    arrow(ax, (1155, 240), (1155, 268), lw=1.2)
    arrow(ax, (1155, 336), (1155, 360), lw=1.2)

    box(ax, 1332, 236, 92, 106, "Dropout\np=0.2\n+\nFC\n512->63", fill=GOLD, edge=GOLD_EDGE, fs=8.4)

    dashed_group(ax, 1500, 148, 168, 240, "CTC", "d", TEAL_EDGE, "#f3fbfc")
    box(ax, 1530, 190, 108, 58, "LogSoftmax\n[10,B,63]", fill=TEAL, edge=TEAL_EDGE, fs=8.4)
    box(ax, 1530, 292, 108, 60, "Greedy CTC\nDecode", fill="#b9e4ec", edge=TEAL_EDGE, fs=8.2)
    arrow(ax, (1584, 248), (1584, 292), lw=1.2)
    block3d(ax, 1710, 240, 58, 92, "OUTPUT\n\"A3B7\"", fs=7.8)

    arrow(ax, (184, 291), (220, 291))
    arrow(ax, (336, 291), (392, 291))
    arrow(ax, (752, 291), (810, 262))
    arrow(ax, (864, 314), (864, 346), lw=1.3)
    arrow(ax, (918, 387), (1040, 278))
    arrow(ax, (1270, 278), (1332, 289))
    arrow(ax, (1424, 289), (1500, 270))
    arrow(ax, (1668, 270), (1710, 286))


def draw_cnn_detail(ax):
    panel(ax, 58, 560, 500, 560, "(b) CNN Feature Extractor Detail")
    x, w = 190, 180
    rows = [
        (625, "Input\n[B,C,H,W]", GRAY, GRAY_EDGE, INK),
        (692, "Conv2d\nk=3, p=1", BLUE, BLUE, "white"),
        (759, "BatchNorm2d", GREEN, GREEN_EDGE, INK),
        (826, "ReLU", BLUE, BLUE, "white"),
    ]
    for i, (yy, text, fill, edge, color) in enumerate(rows):
        box(ax, x, yy, w, 42, text, fill=fill, edge=edge, fs=8.5, color=color)
        if i < len(rows) - 1:
            arrow(ax, (x + w / 2, yy + 42), (x + w / 2, rows[i + 1][0]), lw=1.3)

    box(ax, 104, 912, 160, 54, "Blocks 1-4\nMaxPool2d(2,2)", fill=GOLD, edge=GOLD_EDGE, fs=8.2)
    box(ax, 306, 912, 166, 54, "Block 5\nAdaptiveAvgPool2d\n(1, None)", fill=GOLD, edge=GOLD_EDGE, fs=7.8)
    box(ax, x, 1004, w, 42, "Output feature map\nheight compressed to 1", fill=GRAY, edge=GRAY_EDGE, fs=8.2)

    poly_arrow(ax, [(x + w / 2, 868), (x + w / 2, 890), (184, 890), (184, 912)], lw=1.3)
    poly_arrow(ax, [(x + w / 2, 868), (x + w / 2, 890), (389, 890), (389, 912)], lw=1.3)
    poly_arrow(ax, [(184, 966), (184, 986), (x + w / 2, 986), (x + w / 2, 1004)], lw=1.3)
    poly_arrow(ax, [(389, 966), (389, 986), (x + w / 2, 986), (x + w / 2, 1004)], lw=1.3)

    fit_text(
        ax,
        94,
        1072,
        360,
        22,
        "Conv-BN-ReLU is repeated in all 5 CNN stages; only the pooling layer differs.",
        fs=7.5,
        color=MUTED,
    )


def draw_seq_detail(ax):
    panel(ax, 650, 560, 500, 560, "(c) BiLSTM Sequence Modeling")
    fit_text(ax, 748, 640, 300, 30, "Input [10, B, 256] -> Output [10, B, 512]", fs=10, color="#215984")
    xs = [730, 770, 810, 850, 890, 930, 970, 1010, 1050, 1090]
    fit_text(ax, 870, 704, 140, 24, "Forward", fs=9, color=INK)
    for i, x in enumerate(xs):
        block3d(ax, x, 738, 32, 44, f"f{i+1}", fill=BLUE, edge=BLUE, fs=6.8)
        if i < 9:
            arrow(ax, (x + 32, 760), (xs[i + 1], 760), lw=1.0)
    fit_text(ax, 870, 820, 140, 24, "Backward", fs=9, color=INK)
    for i, x in enumerate(xs):
        block3d(ax, x, 856, 32, 44, f"b{i+1}", fill="#9cb9e5", edge="#7aa0d8", fs=6.8)
        if i < 9:
            arrow(ax, (xs[i + 1], 878), (x + 32, 878), lw=1.0)
    box(ax, 742, 1018, 340, 52, "Concat forward + backward -> [10, B, 512]", fill=GREEN, edge=GREEN_EDGE, fs=9.2)
    poly_arrow(ax, [(1122, 782), (1132, 782), (1132, 990), (1010, 1018)], lw=1.3)
    poly_arrow(ax, [(730, 900), (690, 900), (690, 990), (828, 1018)], lw=1.3)


def draw_ctc_detail(ax):
    panel(ax, 1242, 560, 500, 560, "(d) CTC Transcription")
    for i in range(10):
        x = 1290 + i * 36
        block3d(ax, x, 675, 42, 66, "", fill=GRAY, edge=GRAY_EDGE, fs=6.8)
        vals = [16 + i, 28 - i, 20 + (i % 2) * 4]
        cols = [BLUE_EDGE, GREEN_EDGE, GOLD_EDGE]
        for j, val in enumerate(vals):
            ax.add_patch(Rectangle((x + 9 + j * 9, 733 - val), 6, val, facecolor=cols[j], edgecolor="none", zorder=20))
        ax.text(x + 21, 752, f"t{i+1}", ha="center", va="center", fontsize=6.8, weight="bold", color=INK, zorder=21)
        arrow(ax, (x + 21, 762), (x + 21, 782), lw=1.0)
    box(ax, 1300, 782, 330, 48, "LogSoftmax probabilities\nper time step", fill=TEAL, edge=TEAL_EDGE, fs=8.8)
    box(ax, 1336, 888, 258, 70, "Greedy decode\nargmax -> remove blank\ncollapse repeats", fill="#b9e4ec", edge=TEAL_EDGE, fs=8.1)
    arrow(ax, (1465, 830), (1465, 888), lw=1.3)
    box(ax, 1362, 1000, 206, 38, "blank A A blank 3 B B 7 -> A3B7", fill=GRAY, edge=GRAY_EDGE, fs=7.8)
    arrow(ax, (1465, 958), (1465, 1000), lw=1.3)
    fit_text(ax, 1312, 1072, 360, 22, "62 alphanumeric characters + 1 CTC blank = 63 classes", fs=7.5, color=MUTED)


def main():
    OUT_DIR.mkdir(exist_ok=True)
    fig, ax = setup()
    draw_overview(ax)
    draw_cnn_detail(ax)
    draw_seq_detail(ax)
    draw_ctc_detail(ax)
    fig.savefig(OUT_DIR / "text_captcha_crnn.svg", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(OUT_DIR / "text_captcha_crnn.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(OUT_DIR / "text_captcha_crnn.png", bbox_inches="tight", pad_inches=0.08, dpi=220)
    plt.close(fig)
    print(f"Saved diagram files to {OUT_DIR.resolve()}")


if __name__ == "__main__":
    main()

from pathlib import Path

import matplotlib.pyplot as plt
from PIL import Image


def main():
    root = Path("backend/training/arcface_training/data/arcface/train")
    out = Path("report/Template_实验报告/figures/arcface_samples.png")

    image_paths = []
    for class_dir in sorted(root.iterdir()):
        if not class_dir.is_dir():
            continue
        samples = sorted(class_dir.glob("*.png"))
        if samples:
            image_paths.append(samples[min(2, len(samples) - 1)])
        if len(image_paths) >= 12:
            break

    fig, axes = plt.subplots(3, 4, figsize=(8, 6), dpi=140)
    fig.suptitle("ArcFace Character Crop Samples with Augmentation", fontsize=14, fontweight="bold")

    for ax, path in zip(axes.ravel(), image_paths):
        img = Image.open(path).convert("RGB")
        ax.imshow(img)
        ax.set_xticks([])
        ax.set_yticks([])
        for spine in ax.spines.values():
            spine.set_visible(False)

    for ax in axes.ravel()[len(image_paths):]:
        ax.axis("off")

    fig.text(
        0.5,
        0.035,
        "Samples show font variation, rotation, background noise, strokes, and color perturbations.",
        ha="center",
        va="center",
        fontsize=9,
        color="#444444",
    )
    fig.tight_layout(rect=[0.02, 0.06, 0.98, 0.93])
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

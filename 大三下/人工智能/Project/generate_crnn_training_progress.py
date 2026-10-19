from pathlib import Path

import matplotlib.pyplot as plt
import torch


def main():
    ckpt_path = Path("backend/models/text_captcha/best_model.pth")
    out_path = Path("report/Template_实验报告/figures/crnn_training_progress.png")
    ckpt = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    history = ckpt["history"]

    train_loss = history["train_loss"]
    val_loss = history["val_loss"]
    exact_acc = history["val_accuracy"]
    char_acc = history["val_char_accuracy"]
    lr = history["lr"]
    epochs = list(range(1, len(train_loss) + 1))

    best_epoch = ckpt.get("epoch", len(train_loss))
    best_val_loss = ckpt.get("best_val_loss", min(val_loss))
    best_val_acc = ckpt.get("best_val_accuracy", max(exact_acc))

    fig, axes = plt.subplots(2, 2, figsize=(13.5, 9.2), dpi=140)
    fig.suptitle("CRNN Training Progress", fontsize=15, fontweight="bold")

    ax = axes[0, 0]
    ax.plot(epochs, train_loss, color="blue", label="Train Loss", linewidth=1.8)
    ax.plot(epochs, val_loss, color="red", label="Val Loss", linewidth=1.8)
    ax.set_title("Loss Curve")
    ax.set_xlabel("Epoch")
    ax.set_ylabel("CTC Loss")
    ax.grid(alpha=0.25)
    ax.legend()

    ax = axes[0, 1]
    ax.plot(epochs, exact_acc, color="green", label="Exact Match", linewidth=1.8)
    ax.plot(epochs, char_acc, color="magenta", label="Char Accuracy", linewidth=1.8)
    ax.set_title("Validation Accuracy")
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Accuracy")
    ax.set_ylim(0, 1.05)
    ax.grid(alpha=0.25)
    ax.legend(loc="lower right")

    ax = axes[1, 0]
    ax.plot(epochs, lr, color="black", linewidth=1.8)
    ax.set_title("Learning Rate Schedule")
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Learning Rate")
    ax.grid(alpha=0.25)

    ax = axes[1, 1]
    ax.axis("off")
    summary = (
        "Training Summary\n"
        "========================\n"
        f"Total Epochs: {len(epochs)}\n"
        f"Best Epoch:   {best_epoch}\n"
        f"Best Val Loss:{best_val_loss: .4f}\n"
        f"Best Val Acc: {best_val_acc * 100: .2f}%\n"
        f"Final LR:     {lr[-1]: .2e}\n"
        "Device:       cpu"
    )
    ax.text(
        0.1,
        0.78,
        summary,
        va="top",
        ha="left",
        fontsize=11,
        family="monospace",
        bbox=dict(boxstyle="round", facecolor="#fffde8", edgecolor="#777777"),
    )

    fig.tight_layout(rect=[0, 0, 1, 0.96])
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

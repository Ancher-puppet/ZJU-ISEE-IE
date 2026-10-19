from typing import Dict, Any, Optional

import torch
import torch.nn as nn
from torchvision import models


class CaptchaClassifierCNN(nn.Module):
    """基于 ResNet18 的二分类器：文字验证码 vs 点击验证码"""

    def __init__(self, pretrained: Optional[bool] = None, dropout: Optional[float] = None):
        super().__init__()

        if pretrained is None:
            pretrained = True
        if dropout is None:
            dropout = 0.5

        self.backbone = models.resnet18(weights="IMAGENET1K_V1" if pretrained else None)

        in_features = self.backbone.fc.in_features
        self.backbone.fc = nn.Sequential(
            nn.Dropout(dropout),
            nn.Linear(in_features, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout * 0.6),
            nn.Linear(256, 2),
        )

        self.class_names = ["click", "text"]

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)

    @torch.no_grad()
    def predict(self, image_tensor: torch.Tensor) -> Dict[str, Any]:
        """对单张图像张量做预测"""
        self.eval()

        if image_tensor.dim() == 3:
            image_tensor = image_tensor.unsqueeze(0)

        logits = self.forward(image_tensor)
        probs = torch.softmax(logits, dim=1)[0]

        pred_idx = int(torch.argmax(probs).item())
        pred_type = self.class_names[pred_idx]
        confidence = float(probs[pred_idx].item())

        return {
            "type": pred_type,
            "confidence": confidence,
            "probabilities": {
                "click": float(probs[0].item()),
                "text": float(probs[1].item()),
            },
        }

import sys
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.agent.classifier_cnn import CaptchaClassifierCNN
from app.agent.classifier_rule import RuleBasedClassifier


class TestRuleClassifier:
    def setup_method(self):
        self.clf = RuleBasedClassifier()

    def test_feature_keys(self):
        img = np.random.randint(0, 255, (100, 200, 3), dtype=np.uint8)
        feats = self.clf.extract_features(img)
        for k in ["edge_density", "color_std", "num_components", "texture_complexity", "mean_brightness"]:
            assert k in feats, f"缺少特征: {k}"

    def test_classify_output_format(self):
        img = np.random.randint(0, 255, (100, 200, 3), dtype=np.uint8)
        result = self.clf.classify(img)
        assert result["type"] in ("text", "click")
        assert 0 <= result["confidence"] <= 1
        assert "features" in result


class TestCNNClassifier:
    def setup_method(self):
        self.model = CaptchaClassifierCNN(pretrained=False)

    def test_forward_shape(self):
        x = torch.randn(1, 3, 224, 224)
        out = self.model(x)
        assert out.shape == (1, 2)

    def test_forward_batch_shape(self):
        x = torch.randn(4, 3, 224, 224)
        out = self.model(x)
        assert out.shape == (4, 2)

    def test_predict_output_format(self):
        x = torch.randn(1, 3, 224, 224)
        result = self.model.predict(x)
        assert result["type"] in ("text", "click")
        assert 0 <= result["confidence"] <= 1
        assert "probabilities" in result
        assert "click" in result["probabilities"]
        assert "text" in result["probabilities"]
        assert abs(sum(result["probabilities"].values()) - 1.0) < 1e-5

    def test_predict_single_3d_tensor(self):
        x = torch.randn(3, 224, 224)
        result = self.model.predict(x)
        assert result["type"] in ("text", "click")

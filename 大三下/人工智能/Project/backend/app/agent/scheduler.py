import time
from typing import Optional, Dict, Any

import cv2
import numpy as np
import torch
from PIL import Image

from app.agent.classifier_cnn import CaptchaClassifierCNN
from app.agent.classifier_rule import RuleBasedClassifier
from app.agent.reasoning_logger import ReasoningLogger
from app.models.text_captcha.recognizer import TextCaptchaRecognizer
from app.models.click_captcha.recognizer import ClickCaptchaRecognizer
from app.utils.augment import get_val_transform
class CaptchaAgent:
    """
    验证码识别调度 Agent

    核心流程：
        1. 图像分类 → 判断文字/点击验证码
        2. 路由决策 → 高置信度直接路由，低置信度同时调用两个模型
        3. 执行识别 → 调用对应识别器
        4. 整合结果 → 返回统一格式结果 + 推理链路
    """

    def __init__(
        self,
        classifier_path: Optional[str] = None,
        device: Optional[str] = None,
        confidence_threshold: Optional[float] = None,
        use_cnn: bool = True,
    ):
        if device is None:
            device = "auto"
        if confidence_threshold is None:
            confidence_threshold = 0.8

        # 设备
        if device == "auto":
            self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        else:
            self.device = torch.device(device)

        self.use_cnn = use_cnn
        self.confidence_threshold = confidence_threshold

        # 图像预处理
        self.transform = get_val_transform()

        # 加载 CNN 分类器
        self.cnn_classifier: Optional[CaptchaClassifierCNN] = None
        if use_cnn and classifier_path is not None:
            self.cnn_classifier = CaptchaClassifierCNN(pretrained=False)
            checkpoint = torch.load(classifier_path, map_location=self.device)
            state_dict = checkpoint.get("model_state_dict", checkpoint)
            self.cnn_classifier.load_state_dict(state_dict)
            self.cnn_classifier.to(self.device)
            self.cnn_classifier.eval()

        # 规则分类器（始终可用）
        self.rule_classifier = RuleBasedClassifier()

        # Mock 识别器：与成员 3、4 完成后替换为真模型
        self.text_recognizer = TextCaptchaRecognizer()
        self.click_recognizer = ClickCaptchaRecognizer()

    # ------------------------------------------------------------------
    # 图像分类
    # ------------------------------------------------------------------

    def classify_image(self, image: np.ndarray) -> Dict[str, Any]:
        """
        判断图像类型。

        优先使用 CNN 分类器（如果有），否则回退到规则分类器。
        """
        if self.cnn_classifier is not None:
            return self._classify_cnn(image)
        return self._classify_rule(image)

    def _classify_cnn(self, image: np.ndarray) -> Dict[str, Any]:
        pil = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        tensor = self.transform(pil).unsqueeze(0).to(self.device)
        return self.cnn_classifier.predict(tensor)

    def _classify_rule(self, image: np.ndarray) -> Dict[str, Any]:
        return self.rule_classifier.classify(image)

    # ------------------------------------------------------------------
    # 完整识别流程
    # ------------------------------------------------------------------

    def route_and_recognize(
        self,
        image: np.ndarray,
        mode: str = "auto",
        target: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        完整流程：分类 → 路由 → 识别 → 整合

        Args:
            image: BGR 图像 (H, W, 3)
            mode: "auto" | "text" | "click"
            target: 点击验证码的可选目标类别

        Returns:
            {
                "type": "text" | "click",
                "type_confidence": float,
                "result": {...},
                "reasoning_steps": [...],
                "processing_time": float
            }
        """
        logger = ReasoningLogger()
        t_start = time.perf_counter()

        # ---- Step 1: 图像类型判断 ----
        if mode == "auto":
            logger.log("图像类型判断", "开始分析图像特征...")
            type_result = self.classify_image(image)
            captcha_type = type_result["type"]
            type_confidence = type_result["confidence"]
            logger.log(
                "类型判断完成",
                f"{captcha_type} 验证码 (置信度 {type_confidence:.2%})",
            )
        else:
            captcha_type = mode
            type_confidence = 1.0
            logger.log("手动模式", f"用户指定为 {captcha_type} 验证码")

        # ---- Step 2: 路由决策 ----
        result = None

        if type_confidence >= self.confidence_threshold:
            logger.log(
                "路由决策",
                f"置信度 {type_confidence:.2%} >= 阈值 {self.confidence_threshold:.0%}，直接路由到 {captcha_type} 识别器",
            )
            result = self._run_recognizer(captcha_type, image, target, logger)
        else:
            logger.log(
                "路由决策",
                f"置信度 {type_confidence:.2%} < 阈值 {self.confidence_threshold:.0%}，同时调用两个模型进行对比",
            )
            # 同时调用两个模型
            text_result = self._run_recognizer("text", image, target, logger)
            click_result = self._run_recognizer("click", image, target, logger)

            text_conf = text_result.get("confidence", 0.0)
            click_conf = click_result.get("confidence", 0.0)

            logger.log(
                "结果对比",
                f"文字识别置信度: {text_conf:.2%} | 点击识别置信度: {click_conf:.2%}",
            )

            if click_conf >= text_conf:
                captcha_type = "click"
                result = click_result
            else:
                captcha_type = "text"
                result = text_result

            logger.log("结果选择", f"选择 {captcha_type} 识别结果（置信度更高）")

        # ---- Step 3: 整合 ----
        processing_time = time.perf_counter() - t_start

        logger.log(
            "识别完成",
            f"总耗时 {processing_time:.3f}s",
        )

        return {
            "type": captcha_type,
            "type_confidence": type_confidence,
            "result": result,
            "reasoning_steps": logger.get_steps(),
            "processing_time": processing_time,
        }

    # ------------------------------------------------------------------
    # 内部辅助
    # ------------------------------------------------------------------

    def _run_recognizer(
        self,
        captcha_type: str,
        image: np.ndarray,
        target: Optional[str],
        logger: ReasoningLogger,
    ) -> Dict[str, Any]:
        """调用对应识别器并记录"""
        if captcha_type == "text":
            logger.log("调用识别器", "文字验证码识别器 (CRNN)")
            return self.text_recognizer.recognize(image)
        else:
            label = f" (target={target})" if target else ""
            logger.log("调用识别器", f"点击验证码识别器 (YOLOv8){label}")
            return self.click_recognizer.recognize(image, target)

    # ------------------------------------------------------------------
    # 推理展示辅助
    # ------------------------------------------------------------------

    def get_reasoning_log(self) -> list:
        """供外部获取最近一次推理记录（需配合 route_and_recognize 使用）"""
        return []

"""
ArcFace backbone ONNX 推理 — 单张图 → 256-dim embedding → 余弦相似度匹配。
"""

import cv2
import numpy as np
import onnxruntime as ort


def cvtColor(image_np):
    if len(image_np.shape) == 3 and image_np.shape[2] == 3:
        return cv2.cvtColor(image_np, cv2.COLOR_BGR2RGB)
    elif len(image_np.shape) == 3 and image_np.shape[2] == 4:
        bgr = cv2.cvtColor(image_np, cv2.COLOR_BGRA2BGR)
        return cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    else:
        return cv2.cvtColor(image_np, cv2.COLOR_GRAY2RGB)


def letterbox_image(image_np, target_size):
    h, w = target_size
    ih, iw = image_np.shape[:2]
    scale = min(w / iw, h / ih)
    nw = int(iw * scale)
    nh = int(ih * scale)
    resized = cv2.resize(image_np, (nw, nh), interpolation=cv2.INTER_CUBIC)
    new_image = np.full((h, w, 3), 128, dtype=np.uint8)
    dx = (w - nw) // 2
    dy = (h - nh) // 2
    new_image[dy:dy + nh, dx:dx + nw] = resized
    return new_image


def preprocess_image(img: np.ndarray, input_size=(112, 112)) -> np.ndarray:
    """单张图预处理 → [1, 3, H, W] float32"""
    img = cvtColor(img)
    img = letterbox_image(img, input_size)
    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))
    return np.expand_dims(img, axis=0)


class ArcFaceONNX:
    """ArcFace backbone 推理器 — 输入单张图，输出 256-dim L2 embedding。"""

    def __init__(self, onnx_path: str, device: str = 'cpu', input_size=(112, 112)):
        self.input_size = input_size
        providers = ['CPUExecutionProvider']
        if device == 'cuda':
            providers.insert(0, 'CUDAExecutionProvider')
        self.session = ort.InferenceSession(onnx_path, providers=providers)
        self.input_name = self.session.get_inputs()[0].name     # 'input'
        self.output_name = self.session.get_outputs()[0].name   # 'embedding'

    def extract(self, img: np.ndarray) -> np.ndarray:
        """单张图 → embedding [256]"""
        inp = preprocess_image(img, self.input_size)
        emb = self.session.run([self.output_name], {self.input_name: inp})[0]
        return emb[0]  # (256,)

    def extract_batch(self, imgs: list[np.ndarray]) -> np.ndarray:
        """批量 → embeddings [N, 256]"""
        batch = np.concatenate([preprocess_image(img, self.input_size) for img in imgs], axis=0)
        embs = self.session.run([self.output_name], {self.input_name: batch})[0]
        return embs  # [N, 256]

    def similarity_matrix(self, hint_imgs: list[np.ndarray], cand_imgs: list[np.ndarray]) -> np.ndarray:
        """
        计算 hint × candidate 相似度矩阵。
        hint_imgs:  [N] 个提示字裁剪图
        cand_imgs:  [M] 个候选字裁剪图
        返回:        [N × M] 余弦相似度 (L2 embedding 之间直接点积即可，因为已归一化)
        """
        emb_h = self.extract_batch(hint_imgs)   # [N, 256]
        emb_c = self.extract_batch(cand_imgs)   # [M, 256]
        # 点积 = 余弦相似度（embedding 已 L2 归一化）
        sim = np.dot(emb_h, emb_c.T)            # [N, M]
        return sim

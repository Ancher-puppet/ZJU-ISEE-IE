"""FastAPI 后端 — 桥接 React 前端与 CaptchaAgent"""

import base64
import io
import re
import sys
from pathlib import Path

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
from pydantic import BaseModel, Field

# ---- 路径设置：backend/ 加入 sys.path ----
_BACKEND = Path(__file__).resolve().parent          # backend/
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from app.agent.scheduler import CaptchaAgent  # noqa: E402

# ---- 初始化 ----
agent = CaptchaAgent(
    classifier_path=str(_BACKEND / "models" / "classifier" / "best_classifier.pth"),
    use_cnn=True,
)

app = FastAPI(title="CapAgent API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---- 请求模型 ----
class TextGenerateRequest(BaseModel):
    text: str = Field(..., min_length=4, max_length=4, pattern=r"^[0-9A-Za-z]{4}$")


class ClickGenerateRequest(BaseModel):
    targets: list[str] = Field(..., min_length=2, max_length=6)
    difficulty: str = "normal"  # "easy" | "normal"
    use_background: bool = True  # 是否使用真实背景图


# ---- 辅助函数 ----
def _pil_to_base64(img: Image.Image) -> str:
    """将 PIL Image 转为 base64 PNG 字符串。"""
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def _to_pil(image: np.ndarray) -> Image.Image:
    """numpy BGR 数组 → PIL RGB Image。"""
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    return Image.fromarray(rgb)


def _from_pil(img: Image.Image) -> np.ndarray:
    """PIL Image → numpy BGR 数组。"""
    arr = np.array(img.convert("RGB"))
    return cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)


def _format_result(agent_result: dict) -> dict:
    """将 Agent 输出转换为前端期望的格式"""
    captcha_type = agent_result["type"]  # "text" | "click"

    if captcha_type == "text":
        inner = agent_result["result"]
        result_text = inner.get("text", "")
    else:
        positions = agent_result["result"].get("click_positions", [])
        if positions:
            result_text = "点击位置: " + ", ".join(
                f"({x}, {y})" for x, y in positions
            )
        else:
            result_text = "未检测到点击目标"

    response = {
        "type": captcha_type,
        "result": result_text,
        "confidence": round(agent_result["type_confidence"], 4),
        "reasoning": agent_result["reasoning_steps"],
    }

    # 返回可视化图片（base64）
    vis = agent_result["result"].get("visualization")
    if vis is not None:
        _, buf = cv2.imencode(".png", vis)
        response["visualization"] = base64.b64encode(buf).decode("utf-8")

    return response


# ---- 路由 ----
@app.get("/api/health")
async def health():
    return {"status": "ok"}


@app.post("/api/recognize")
async def recognize(file: UploadFile = File(...)):
    """识别验证码"""
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image is None:
            return JSONResponse(
                status_code=400,
                content={"error": "无法解析图像", "code": 400},
            )

        result = agent.route_and_recognize(image, mode="auto")
        return _format_result(result)

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "code": 500},
        )


@app.post("/api/generate/text")
async def generate_text(req: TextGenerateRequest):
    """根据用户输入的 4 位文本生成文字验证码图片（随机风格）。"""
    try:
        from app.generator import generate_text_styled

        img = generate_text_styled(req.text)
        return {
            "image": _pil_to_base64(img),
            "width": img.width,
            "height": img.height,
            "text": req.text,
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"生成失败: {e}", "code": 500},
        )


@app.post("/api/generate/click")
async def generate_click(req: ClickGenerateRequest):
    """根据用户输入的目标字符合成文字点选验证码图片（随机风格）。"""
    try:
        from app.generator import generate_click_styled

        img = generate_click_styled(list(req.targets), difficulty=req.difficulty, use_background=req.use_background)
        return {
            "image": _pil_to_base64(img),
            "width": img.width,
            "height": img.height,
            "targets": req.targets,
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"生成失败: {e}", "code": 500},
        )


# ---- 启动入口 ----
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8765)

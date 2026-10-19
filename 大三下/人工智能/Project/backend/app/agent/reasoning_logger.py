from dataclasses import dataclass, field
from typing import List, Dict, Any
import time


@dataclass
class ReasoningStep:
    step_num: int
    action: str
    detail: str
    timestamp: float = field(default_factory=time.time)


class ReasoningLogger:
    """推理过程记录器，追踪每一步决策"""

    def __init__(self):
        self.steps: List[ReasoningStep] = []
        self._start_time = time.time()

    def log(self, action: str, detail: str):
        step = ReasoningStep(
            step_num=len(self.steps) + 1,
            action=action,
            detail=detail,
        )
        self.steps.append(step)

    def get_steps(self) -> List[Dict[str, Any]]:
        return [
            {"step": s.step_num, "action": s.action, "detail": s.detail}
            for s in self.steps
        ]

    @property
    def total_time(self) -> float:
        return time.time() - self._start_time

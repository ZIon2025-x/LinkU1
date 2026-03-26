"""AI 任务描述优化接口"""
import json
import logging
import re
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from app.services.ai_agent import get_llm_client
from app.deps import get_current_user_secure_async_csrf
from app import models

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


class AIOptimizeRequest(BaseModel):
    title: str
    description: str
    task_type: Optional[str] = None


class AIOptimizeResponse(BaseModel):
    optimized_title: str
    optimized_description: str
    suggested_skills: List[str]


def _extract_json(text: str) -> str:
    """Strip markdown code fences (```json ... ``` or ``` ... ```) from LLM output."""
    m = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    return m.group(1).strip() if m else text.strip()


@router.post("/ai-optimize", response_model=AIOptimizeResponse)
async def ai_optimize_task(
    request: AIOptimizeRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    prompt = f"""优化以下任务信息，使其更清晰专业。

标题：{request.title}
描述：{request.description}
分类：{request.task_type or '未指定'}

返回JSON：
{{"optimized_title":"优化后标题(50字内)","optimized_description":"优化后描述","suggested_skills":["技能1","技能2","技能3"]}}
只返回JSON。"""

    text = ""
    try:
        llm = get_llm_client()
        response = await llm.chat(
            messages=[{"role": "user", "content": prompt}],
            system="任务优化助手，只返回JSON，不要markdown代码块。直接输出结果。",
            model_tier="small",
            max_tokens=1024,
        )
        for block in response.content:
            if hasattr(block, 'text') and block.text:
                text = block.text
                break

        if not text.strip():
            logger.error(
                f"AI optimize: empty content, model={response.model}, "
                f"stop_reason={response.stop_reason}, blocks={len(response.content)}"
            )
            raise HTTPException(status_code=502, detail="ai_optimize_failed")

        text = _extract_json(text)
        data = json.loads(text)
        return AIOptimizeResponse(**data)
    except HTTPException:
        raise
    except Exception as e:
        logger.warning(f"AI optimize failed: {e}, raw text: {text!r:.200}")
        raise HTTPException(status_code=502, detail="ai_optimize_failed")

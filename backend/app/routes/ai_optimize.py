"""AI 任务描述优化接口"""
import json
import logging
import re
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from app.services.ai_llm_client import LLMClient
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
    prompt = f"""你是一个任务发布优化助手。请优化以下任务信息，使其更清晰、专业，更容易吸引合适的人接单。

原标题：{request.title}
原描述：{request.description}
任务分类：{request.task_type or '未指定'}

请返回 JSON 格式：
{{
  "optimized_title": "优化后的标题（50字以内）",
  "optimized_description": "优化后的详细描述",
  "suggested_skills": ["建议的技能标签1", "技能2", "技能3"]
}}
只返回 JSON，不要其他内容。"""

    try:
        llm = LLMClient()
        response = await llm.chat(
            messages=[{"role": "user", "content": prompt}],
            system="你是一个任务发布优化助手，只返回JSON格式的结果，不要用markdown代码块包裹。",
            model_tier="small",
        )
        # Extract text content from response
        text = ""
        for block in response.content:
            if hasattr(block, 'text'):
                text = block.text
                break

        text = _extract_json(text)
        data = json.loads(text)
        return AIOptimizeResponse(**data)
    except Exception as e:
        logger.warning(f"AI optimize failed: {e}, raw text: {text!r:.200}")
        # Fallback: return original content
        return AIOptimizeResponse(
            optimized_title=request.title,
            optimized_description=request.description,
            suggested_skills=[],
        )

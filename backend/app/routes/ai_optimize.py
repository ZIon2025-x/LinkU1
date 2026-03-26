"""AI 任务描述优化接口"""
import json
import logging
import re
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.ai_llm_client import LLMClient
from app.services.ai_agent import build_user_profile_context
from app.deps import get_current_user_secure_async_csrf, get_async_db_dependency
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
    db: AsyncSession = Depends(get_async_db_dependency),
):
    # Build user profile context for personalized optimization
    profile_context = await build_user_profile_context(str(current_user.id), db)

    profile_section = ""
    if profile_context:
        profile_section = f"""

以下是发布者的画像信息，请据此优化描述风格和推荐更贴合的技能标签：
{profile_context}
"""

    prompt = f"""你是一个任务发布优化助手。请优化以下任务信息，使其更清晰、专业，更容易吸引合适的人接单。

原标题：{request.title}
原描述：{request.description}
任务分类：{request.task_type or '未指定'}
{profile_section}
请返回 JSON 格式：
{{
  "optimized_title": "优化后的标题（50字以内）",
  "optimized_description": "优化后的详细描述",
  "suggested_skills": ["建议的技能标签1", "技能2", "技能3"]
}}
只返回 JSON，不要其他内容。"""

    text = ""
    try:
        llm = LLMClient()
        response = await llm.chat(
            messages=[{"role": "user", "content": prompt}],
            system="你是一个任务发布优化助手，只返回JSON格式的结果，不要用markdown代码块包裹。不要思考太多，直接输出结果。",
            model_tier="small",
            max_tokens=4096,
        )
        # Extract text content from response
        for block in response.content:
            if hasattr(block, 'text') and block.text:
                text = block.text
                break

        if not text.strip():
            logger.error(
                f"AI optimize: LLM returned empty content, "
                f"model={response.model}, stop_reason={response.stop_reason}, "
                f"blocks={len(response.content)}, usage={response.usage}"
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

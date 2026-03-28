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
    suggested_category: Optional[str] = None


def _extract_json(text: str) -> str:
    """Strip markdown code fences (```json ... ``` or ``` ... ```) from LLM output."""
    m = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    return m.group(1).strip() if m else text.strip()


# 每个任务分类对应的可选技能标签
CATEGORY_SKILLS = {
    'shopping': ['代购', '比价', '海淘'],
    'tutoring': ['数学', '英语', '编程', '考试辅导', '论文'],
    'translation': ['文件翻译', '口译', '字幕'],
    'design': ['Figma', 'UI设计', 'Photoshop', '海报'],
    'programming': ['Python', 'Flutter', 'React', 'JavaScript'],
    'writing': ['文案', '论文', 'SEO', '公众号'],
    'photography': ['人像', '产品', '风光', '视频'],
    'moving': ['搬家', '打包', '家具拆装'],
    'cleaning': ['日常清洁', '深度清洁', '收纳'],
    'repair': ['水电', '家电', '家具'],
    'pickup_dropoff': ['机场接送', '看房接送', '面试接送'],
    'cooking': ['中餐', '聚会餐饮', '烘焙'],
    'language_help': ['陪同翻译', '电话翻译', '信件代写'],
    'government': ['签证材料', '银行开户', 'GP注册'],
    'pet_care': ['遛狗', '寄养', '美容'],
    'errand': ['取件', '排队', '代办'],
    'accompany': ['看病陪同', '租房陪看', '入学陪同'],
    'digital': ['装系统', '修电脑', '网络设置'],
    'rental_housing': ['找房', '看房', '合同审核'],
    'campus_life': ['代课笔记', '校园导览', '社团活动'],
    'second_hand': ['数码', '教材', '家具', '服饰'],
}


@router.post("/ai-optimize", response_model=AIOptimizeResponse)
async def ai_optimize_task(
    request: AIOptimizeRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    category = request.task_type or '未指定'
    available_skills = CATEGORY_SKILLS.get(category, [])
    skills_hint = f"\n参考技能标签：{', '.join(available_skills)}" if available_skills else ""
    all_categories = ', '.join(CATEGORY_SKILLS.keys()) + ', other'

    prompt = f"""优化以下任务信息，使其更清晰专业。

标题：{request.title}
描述：{request.description}
当前分类：{category}
可选分类：{all_categories}{skills_hint}

返回JSON：
{{"optimized_title":"优化后标题(50字内)","optimized_description":"优化后描述","suggested_skills":["优先从参考标签选，也可自定义，1-3个"],"suggested_category":"根据内容选最合适的分类key"}}
只返回JSON。"""

    text = ""
    try:
        llm = get_llm_client()
        response = await llm.chat(
            messages=[{"role": "user", "content": prompt}],
            system="任务优化助手，只返回JSON，不要markdown代码块。直接输出结果。",
            model_tier="small",
            max_tokens=2048,  # 推理模型的思考 token 也计入总量，需要更大配额
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

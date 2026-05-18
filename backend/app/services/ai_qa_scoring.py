"""AI 限时问答 — 评分算法工具 + AI 评分服务。"""
import json
import logging
from typing import List, Tuple

from anthropic import Anthropic

from app.config import Config

logger = logging.getLogger(__name__)


# ========== 奖金分配算法 (spec §2.1 重写后) ==========
# 无 winners_count cap;所有 hide_in_qa=False 的答主都进分配;
# 按 final_score 比例分;低于 floor_pence (默认 10p) 抹零;差额给第 1 名
def distribute_pool(
    scored_answers: List[Tuple[int, int]],  # [(answer_id, final_score)] 已按分降序
    pool_pence: int,
    floor_pence: int,
) -> List[Tuple[int, int]]:
    """返回 [(answer_id, reward_pence)]，长度 = len(scored_answers)。"""
    if not scored_answers:
        return []
    total_score = sum(s for _, s in scored_answers)
    if total_score == 0:
        return [(aid, 0) for aid, _ in scored_answers]
    raw = [(aid, round(pool_pence * s / total_score)) for aid, s in scored_answers]
    # 抹零：低于 floor_pence 归零
    cleaned = [(aid, amt if amt >= floor_pence else 0) for aid, amt in raw]
    # 误差修正：差额加到第 1 名
    diff = pool_pence - sum(a for _, a in cleaned)
    if cleaned:
        first_aid, first_amt = cleaned[0]
        cleaned[0] = (first_aid, first_amt + diff)
    return cleaned


# ========== AI 评分服务 ==========
SCORING_PROMPT_TEMPLATE = """你是问答评分员。给每条答案打分,只输出 JSON 数组:
[{{"id": <answer_id>, "score": 0-100, "off_topic": bool, "ai_generated": "low|medium|high"}}]

评分维度（按权重）:
- 切题度（核心）: 偏题严重 score ≤ 30 且 off_topic=true
- 真人感: 明显 AI 味重 ai_generated="high",可疑"medium",自然"low"
- 内容质量: 信息量、表达、独特性

题目: {question}

答案列表:
{answers}
"""


def score_answers_batch(
    question_title: str, question_content: str,
    answers: List[dict],  # [{"id": int, "content": str}, ...]
) -> List[dict]:
    """调 Claude Sonnet 4.5 批量打分。返回 [{"id", "score", "off_topic", "ai_generated"}, ...]。"""
    client = Anthropic(api_key=Config.ANTHROPIC_API_KEY)
    prompt = SCORING_PROMPT_TEMPLATE.format(
        question=f"{question_title}\n\n{question_content}",
        answers=json.dumps(answers, ensure_ascii=False),
    )
    # 跟项目通用配置一致 — config.py 默认 claude-sonnet-4-5-20250929,可 env 覆盖
    resp = client.messages.create(
        model=Config.AI_MODEL_LARGE,
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = resp.content[0].text.strip()
    # 容错: 去 ```json fence
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"AI scoring JSON parse failed: {e}, raw={raw[:500]}")
        raise
    return parsed


def score_all_answers(
    question_title: str, question_content: str,
    answers: List[dict],  # [{"id": int, "content": str}, ...]
    batch_size: int = 10,
) -> List[dict]:
    """分批送 AI 评分, 拼成完整结果。"""
    results = []
    for i in range(0, len(answers), batch_size):
        batch = answers[i:i + batch_size]
        batch_result = score_answers_batch(question_title, question_content, batch)
        results.extend(batch_result)
    return results

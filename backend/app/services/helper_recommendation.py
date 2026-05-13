"""Helper recommendation by user intent.

提供 recommend_helpers() 主入口和相关纯计算函数。
被 ai_tools.py 的 recommend_helpers_by_intent 工具调用。

Spec: docs/superpowers/specs/2026-05-12-recommend-helpers-by-intent-design.md
"""

import logging
from typing import Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# 中英城市映射表 — 覆盖主要英国城市 + 北京/上海等中国大城市
# 匹配前都 lower().strip(),所以这里 key 也要小写
_CITY_ALIASES = {
    # 英国
    "伦敦": "london",
    "曼城": "manchester",
    "曼彻斯特": "manchester",
    "爱丁堡": "edinburgh",
    "伯明翰": "birmingham",
    "格拉斯哥": "glasgow",
    "布里斯托": "bristol",
    "谢菲尔德": "sheffield",
    "利兹": "leeds",
    "纽卡斯尔": "newcastle",
    "利物浦": "liverpool",
    "卡迪夫": "cardiff",
    "考文垂": "coventry",
    "诺丁汉": "nottingham",
    "南安普顿": "southampton",
    # 中国大陆
    "北京": "beijing",
    "上海": "shanghai",
    "广州": "guangzhou",
    "深圳": "shenzhen",
    "杭州": "hangzhou",
}

# 已知英文城市白名单(lower) — 不在内的视为未知城市
_KNOWN_CITIES = {
    "london", "manchester", "edinburgh", "birmingham", "glasgow",
    "bristol", "sheffield", "leeds", "newcastle", "liverpool",
    "cardiff", "coventry", "nottingham", "southampton",
    "beijing", "shanghai", "guangzhou", "shenzhen", "hangzhou",
}


def normalize_city(city: Optional[str]) -> Optional[str]:
    """Normalize a city name to canonical lowercase English.

    Returns None for empty input or unknown city (treated as "unknown city" downstream).
    """
    if not city:
        return None
    key = city.strip().lower()
    if not key:
        return None
    # 先查别名映射(中文等)
    if key in _CITY_ALIASES:
        return _CITY_ALIASES[key]
    # 再看是否已知英文
    if key in _KNOWN_CITIES:
        return key
    return None


# 技能交集评分参数:每个匹配的 skill 加 0.05 分,最多算 3 个 (max contribution 0.15)
_MAX_SKILLS_OVERLAP = 3
_SKILLS_OVERLAP_WEIGHT = 0.05

_GEO_TABLE = {
    # (mode, city_state) -> multiplier
    # city_state: 'same' | 'cross' | 'unknown'
    ("offline", "same"):    1.3,
    ("offline", "cross"):   0.4,
    ("offline", "unknown"): 0.6,
    ("both",    "same"):    1.2,
    ("both",    "cross"):   0.7,
    ("both",    "unknown"): 0.9,
    ("online",  "same"):    1.0,
    ("online",  "cross"):   1.0,
    ("online",  "unknown"): 1.0,
}


def _geo_multiplier(
    mode: Optional[str],
    user_city: Optional[str],
    candidate_city: Optional[str],
) -> float:
    """Multiplier based on mode + city alignment.

    mode None 视作 'both'。candidate_city None 视作 unknown。
    """
    m = mode or "both"
    if m == "online":
        return 1.0
    if candidate_city is None or user_city is None:
        # user 或 candidate 任一没城市 → 无法判断对齐 → 走 unknown 档
        # (与 _city_state 语义保持一致)
        state = "unknown"
    elif candidate_city == user_city:
        state = "same"
    else:
        state = "cross"
    return _GEO_TABLE.get((m, state), 1.0)


def _score_candidate(
    source: str,
    avg_rating: Optional[float],
    completed_count: int,
    skills_overlap: int,
    geo_multiplier: float,
) -> float:
    """Compute candidate score 0..1。Caller 保证不要传 task_history 的 skills_overlap > 0。"""
    base = 0.6 if source == "service" else 0.3

    boost = 0.0
    # rating boost
    if avg_rating is not None and avg_rating >= 4.5:
        boost += 0.15
    elif avg_rating is not None and avg_rating >= 4.0:
        boost += 0.10
    # completed_count boost (主要 task_history 用,函数本身不挑)
    if completed_count >= 10:
        boost += 0.10
    elif completed_count >= 3:
        boost += 0.05
    # skills overlap
    boost += min(_MAX_SKILLS_OVERLAP, max(0, skills_overlap)) * _SKILLS_OVERLAP_WEIGHT

    return min(1.0, (base + boost) * geo_multiplier)


# task_type → 中文 label,展示给用户用
# 与 ai_tools.py _VALID_TASK_TYPES 对齐
_TASK_TYPE_LABEL_ZH = {
    "shopping":       "代购",
    "tutoring":       "辅导",
    "translation":    "翻译",
    "design":         "设计",
    "programming":    "编程",
    "writing":        "写作",
    "photography":    "摄影",
    "moving":         "搬家",
    "cleaning":       "清洁",
    "repair":         "维修",
    "pickup_dropoff": "接送",
    "cooking":        "厨艺",
    "language_help":  "语言陪练",
    "government":     "政务办理",
    "pet_care":       "宠物照护",
    "errand":         "跑腿",
    "accompany":      "陪同",
    "digital":        "数码协助",
    "rental_housing": "租房协助",
    "campus_life":    "校园生活",
    "second_hand":    "二手交易",
    "other":          "其他",
}


def _build_match_reason(
    *,
    source: str,
    service_name: Optional[str],
    avg_rating: Optional[float],
    completed_count: int,
    task_type: Optional[str],
    city_state: str,    # 'same' | 'cross' | 'unknown'
    city_display: Optional[str],  # 显示给用户的城市名(原始字符串,不归一化)
) -> str:
    """Build human-readable match reason for a candidate.

    Spec §6.6。
    """
    rating_seg = f",评分 {avg_rating:.1f}" if avg_rating is not None else ""
    if city_state == "same":
        city_seg = f"({city_display})" if city_display else ""
    elif city_state == "cross":
        city_seg = f"({city_display},可线上协调)" if city_display else "(可线上协调)"
    else:
        city_seg = ""

    if source == "service":
        name = service_name or "个人"
        return f"发布了{name}服务{rating_seg}{city_seg}"
    # task_history
    label = _TASK_TYPE_LABEL_ZH.get(task_type or "", task_type or "")
    return f"完成过 {completed_count} 个{label}任务{rating_seg}{city_seg}"


_SERVICE_POOL_SQL = text("""
SELECT u.id, u.name, u.avatar_url, u.avg_rating,
       upref.city as city,
       s.service_name, s.location_type, s.skills
FROM users u
JOIN task_expert_services s
     ON s.owner_type = 'user' AND s.owner_id = u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE s.service_type = 'personal'
  AND s.status = 'active'
  AND u.id != :current_user_id
  AND (
        s.category = :task_type
     OR (
          cardinality(:skills::text[]) > 0
          AND s.skills IS NOT NULL
          AND EXISTS (
                SELECT 1 FROM jsonb_array_elements_text(s.skills) v
                WHERE v = ANY(:skills::text[])
          )
        )
  )
  AND (
        :mode IS NULL OR :mode = 'both'
     OR (:mode = 'offline' AND s.location_type IN ('in_person', 'both'))
     OR (:mode = 'online'  AND s.location_type IN ('online',    'both'))
  )
LIMIT 100
""")


async def _fetch_service_pool(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
    skills: list[str],
    mode: Optional[str],
) -> list[dict]:
    """Fetch service-publisher pool from DB. Returns list of dicts."""
    try:
        exec_result = await db.execute(
            _SERVICE_POOL_SQL,
            {
                "current_user_id": current_user_id,
                "task_type": task_type,
                "skills": skills or [],
                "mode": mode,
            },
        )
        rows = exec_result.all()
    except Exception as e:
        logger.warning("_fetch_service_pool failed: %s", e)
        return []

    out = []
    for r in rows:
        out.append({
            "user_id": r.id,
            "name": r.name,
            "avatar_url": r.avatar_url,
            "avg_rating": float(r.avg_rating) if r.avg_rating is not None else None,
            "city": r.city,
            "service_name": r.service_name,
            "location_type": r.location_type,
            "skills": r.skills or [],
            "source": "service",
        })
    return out


_TASK_HISTORY_POOL_SQL = text("""
SELECT u.id, u.name, u.avatar_url,
       upref.city as city,
       COUNT(t.id) as completed_count,
       AVG(r.rating)::float as avg_rating
FROM users u
JOIN tasks t ON t.taker_id = u.id
LEFT JOIN reviews r ON r.task_id = t.id AND r.user_id != u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE t.status = 'completed'
  AND t.task_type = :task_type
  AND u.id != :current_user_id
GROUP BY u.id, u.name, u.avatar_url, upref.city
HAVING COUNT(t.id) >= 1
LIMIT 100
""")


async def _fetch_task_history_pool(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
) -> list[dict]:
    """Fetch task-completion-history pool. Returns list of dicts."""
    try:
        exec_result = await db.execute(
            _TASK_HISTORY_POOL_SQL,
            {"current_user_id": current_user_id, "task_type": task_type},
        )
        rows = exec_result.all()
    except Exception as e:
        logger.warning("_fetch_task_history_pool failed: %s", e)
        return []

    out = []
    for r in rows:
        out.append({
            "user_id": r.id,
            "name": r.name,
            "avatar_url": r.avatar_url,
            "avg_rating": float(r.avg_rating) if r.avg_rating is not None else None,
            "city": r.city,
            "completed_count": int(r.completed_count or 0),
            "task_type": task_type,
            "source": "task_history",
        })
    return out


_USER_CITY_SQL = text("""
SELECT upref.city
FROM user_profile_preferences upref
WHERE upref.user_id = :user_id
LIMIT 1
""")


async def _get_user_city(db: AsyncSession, user_id: str) -> Optional[str]:
    """Fetch caller's city from preferences. None if not set."""
    try:
        result = await db.execute(_USER_CITY_SQL, {"user_id": user_id})
        row = result.first()
        return row.city if row else None
    except Exception as e:
        logger.warning("_get_user_city failed: %s", e)
        return None


def _city_state(
    user_city_norm: Optional[str],
    candidate_city_norm: Optional[str],
) -> str:
    """Classify city alignment: 'same' | 'cross' | 'unknown'.

    'unknown' 用于 candidate 城市未填(数据缺失)。
    user 城市未填时(也走 unknown) 候选所有人对 user 都是"未知城市"档。
    """
    if candidate_city_norm is None:
        return "unknown"
    if user_city_norm is None:
        return "unknown"
    return "same" if candidate_city_norm == user_city_norm else "cross"


async def recommend_helpers(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
    skills: list[str],
    location: Optional[str],
    mode: Optional[str],
    limit: int = 5,
) -> dict:
    """Main entry: 两池查询 → 合并去重 → 评分 → 排序 → top N.

    Spec §4-§6。

    Returns dict matching the tool output schema (helpers/total/fallback_suggestion)。
    """
    limit = max(1, min(10, limit))

    # 1. 确定 user_city: location 优先, fallback 到 user_profile_preferences.city
    raw_user_city = location or await _get_user_city(db, current_user_id)
    user_city_norm = normalize_city(raw_user_city)

    # 2. 两池查询
    service_pool = await _fetch_service_pool(
        db=db, current_user_id=current_user_id,
        task_type=task_type, skills=skills or [], mode=mode,
    )
    history_pool = await _fetch_task_history_pool(
        db=db, current_user_id=current_user_id, task_type=task_type,
    )

    # 3. 评分 + 合并去重
    scored: dict[str, dict] = {}

    for cand in service_pool:
        cand_city_norm = normalize_city(cand["city"])
        state = _city_state(user_city_norm, cand_city_norm)
        geo_mult = _geo_multiplier(mode, user_city_norm, cand_city_norm)
        skills_overlap = len(set(cand.get("skills") or []) & set(skills or []))
        score = _score_candidate(
            source="service", avg_rating=cand.get("avg_rating"),
            completed_count=0, skills_overlap=skills_overlap, geo_multiplier=geo_mult,
        )
        scored[cand["user_id"]] = {
            **cand, "score": score, "city_state": state,
            "city_display": cand.get("city"),
        }

    for cand in history_pool:
        cand_city_norm = normalize_city(cand["city"])
        state = _city_state(user_city_norm, cand_city_norm)
        geo_mult = _geo_multiplier(mode, user_city_norm, cand_city_norm)
        score = _score_candidate(
            source="task_history", avg_rating=cand.get("avg_rating"),
            completed_count=cand.get("completed_count", 0),
            skills_overlap=0, geo_multiplier=geo_mult,
        )
        uid = cand["user_id"]
        if uid in scored:
            if score > scored[uid]["score"]:
                scored[uid]["score"] = score
            # service source 保留, 不覆盖
        else:
            scored[uid] = {
                **cand, "score": score, "city_state": state,
                "city_display": cand.get("city"),
            }

    # 4. 排序 + top N
    ranked = sorted(scored.values(), key=lambda c: c["score"], reverse=True)[:limit]

    # 5. output
    helpers = []
    for c in ranked:
        helpers.append({
            "user_id": c["user_id"],
            "name": c["name"],
            "avatar_url": c.get("avatar_url"),
            "source": c["source"],
            "match_score": round(c["score"], 3),
            "match_reason": _build_match_reason(
                source=c["source"],
                service_name=c.get("service_name"),
                avg_rating=c.get("avg_rating"),
                completed_count=c.get("completed_count", 0),
                task_type=c.get("task_type"),
                city_state=c["city_state"],
                city_display=c["city_display"],
            ),
            "profile_url": f"/profile/{c['user_id']}",
        })

    # 6. fallback_suggestion
    fallback = None
    if not helpers:
        loc_str = raw_user_city
        if loc_str:
            fallback = f"{loc_str} 暂时还没有合适的人选,建议你发个任务让大家看到"
        else:
            fallback = "还没有匹配的人选,建议你发个任务让大家看到"

    logger.info(
        "recommend_helpers: user=%s task_type=%s mode=%s loc=%s n_results=%d",
        current_user_id, task_type, mode, raw_user_city, len(helpers),
    )

    return {
        "helpers": helpers,
        "total": len(helpers),
        "fallback_suggestion": fallback,
    }

"""Helper recommendation by user intent.

提供 recommend_helpers() 主入口和相关纯计算函数。
被 ai_tools.py 的 recommend_helpers_by_intent 工具调用。

Spec: docs/superpowers/specs/2026-05-12-recommend-helpers-by-intent-design.md
"""

import logging
from typing import Optional

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
        state = "unknown" if candidate_city is None else "cross"
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
    boost += min(3, max(0, skills_overlap)) * 0.05

    return min(1.0, (base + boost) * geo_multiplier)

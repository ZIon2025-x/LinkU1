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

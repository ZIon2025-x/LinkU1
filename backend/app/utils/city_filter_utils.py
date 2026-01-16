"""
城市筛选工具

目标：
- 性能：复用/缓存 pattern 生成，避免各处重复拼接
- 可拓展：集中维护中英文别名映射，后续新增城市/别名只改一处
- 兼容：支持常见地址格式（英文逗号分隔、中文不带逗号、含“市”等）
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import Iterable, List, Optional, Sequence


# 预定义的英国主要城市列表（用于位置筛选）
# 当筛选 "Other" 时，会排除这些城市
UK_MAIN_CITIES: Sequence[str] = [
    "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow",
    "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle",
    "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter",
    "Leicester", "York", "Aberdeen", "Bath", "Dundee",
    "Reading", "St Andrews", "Belfast", "Brighton", "Durham",
    "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick",
    "Cambridge", "Oxford",
]


# 中英文城市名映射表（用于地址筛选时支持中英文互查）
CITY_NAME_MAPPING: dict[str, str] = {
    "London": "伦敦",
    "Edinburgh": "爱丁堡",
    "Manchester": "曼彻斯特",
    "Birmingham": "伯明翰",
    "Glasgow": "格拉斯哥",
    "Bristol": "布里斯托",
    "Sheffield": "谢菲尔德",
    "Leeds": "利兹",
    "Nottingham": "诺丁汉",
    "Newcastle": "纽卡斯尔",
    "Southampton": "南安普顿",
    "Liverpool": "利物浦",
    "Cardiff": "卡迪夫",
    "Coventry": "考文垂",
    "Exeter": "埃克塞特",
    "Leicester": "莱斯特",
    "York": "约克",
    "Aberdeen": "阿伯丁",
    "Bath": "巴斯",
    "Dundee": "邓迪",
    "Reading": "雷丁",
    "St Andrews": "圣安德鲁斯",
    "Belfast": "贝尔法斯特",
    "Brighton": "布莱顿",
    "Durham": "达勒姆",
    "Norwich": "诺里奇",
    "Swansea": "斯旺西",
    "Loughborough": "拉夫堡",
    "Lancaster": "兰开斯特",
    "Warwick": "华威",
    "Cambridge": "剑桥",
    "Oxford": "牛津",
}

CITY_NAME_REVERSE_MAPPING: dict[str, str] = {v: k for k, v in CITY_NAME_MAPPING.items()}
CITY_NAME_MAPPING_LOWER: dict[str, str] = {k.lower(): v for k, v in CITY_NAME_MAPPING.items()}
CITY_NAME_CANONICAL_EN: dict[str, str] = {k.lower(): k for k in CITY_NAME_MAPPING.keys()}


_CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def _has_cjk(text: str) -> bool:
    return bool(_CJK_RE.search(text))


def get_city_name_variants(city_name: Optional[str]) -> list[str]:
    """
    获取城市名的所有变体（英文和中文，英文大小写不敏感）
    例如：输入 "Birmingham" / "birmingham" 返回 ["Birmingham", "伯明翰", ...]
         输入 "伯明翰" 返回 ["Birmingham", "伯明翰"]
    """
    if not city_name:
        return []
    name = city_name.strip()
    if not name:
        return []

    variants: set[str] = {name}

    lower = name.lower()
    if lower in CITY_NAME_MAPPING_LOWER:
        variants.add(CITY_NAME_CANONICAL_EN[lower])  # 规范英文
        variants.add(CITY_NAME_MAPPING_LOWER[lower])  # 中文

    if name in CITY_NAME_REVERSE_MAPPING:
        variants.add(CITY_NAME_REVERSE_MAPPING[name])  # 英文

    return list(variants)


def _dedupe_preserve_order(items: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for it in items:
        if it not in seen:
            out.append(it)
            seen.add(it)
    return out


@lru_cache(maxsize=512)
def _patterns_for_city_input(city_input: str) -> tuple[str, ...]:
    """
    基于用户输入（可能英文/中文/大小写）生成一组 ilike patterns。
    注意：只缓存“字符串 patterns”，不缓存 SQLAlchemy 表达式（避免绑定 column 对象）。
    """
    variants = get_city_name_variants(city_input)
    patterns: list[str] = []

    for v in variants:
        v = (v or "").strip()
        if not v:
            continue

        # 中文地址常见形式：不带逗号/空格（如“英国伯明翰”“伯明翰市”）
        # 这里必须支持包含匹配，否则会漏掉。
        if _has_cjk(v):
            patterns.append(f"%{v}%")
            patterns.append(v)  # 精确匹配也保留
            continue

        # 英文：尽量保持“边界匹配”，避免 Bristol Road 误命中 Bristol
        patterns.extend(
            [
                f"{v}",          # 精确匹配
                f"{v},%",        # "Birmingham, UK"
                f"%, {v}%",      # ", Birmingham, UK"
                f"% {v}",        # "... Birmingham"
                f"% {v} %",      # "... Birmingham ..."
            ]
        )

    patterns = _dedupe_preserve_order(patterns)
    return tuple(patterns)


@lru_cache(maxsize=1)
def _patterns_for_other_exclusion() -> tuple[str, ...]:
    """
    “Other” 排除条件 patterns（英文边界 + 中文包含）。
    """
    patterns: list[str] = []
    for city in UK_MAIN_CITIES:
        patterns.extend(_patterns_for_city_input(city))

    # online 常见写法
    patterns.extend(["%online%", "%线上%"])
    patterns = _dedupe_preserve_order(patterns)
    return tuple(patterns)


def build_city_location_filter(column, city_input: str):
    """
    构造某个城市的 location 过滤表达式（SQLAlchemy）。
    """
    from sqlalchemy import or_

    patterns = _patterns_for_city_input(city_input)
    conditions = [column.ilike(p) for p in patterns]
    return or_(*conditions) if conditions else None


def build_other_exclusion_filter(column):
    """
    构造 “Other” 排除表达式：匹配到任何已知城市 / online 就算“非 Other”。
    使用时应配合 not_(...)。
    """
    from sqlalchemy import or_

    patterns = _patterns_for_other_exclusion()
    conditions = [column.ilike(p) for p in patterns]
    return or_(*conditions) if conditions else None


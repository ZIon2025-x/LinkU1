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


# ============================================================================
# Canonical city resolution
# ============================================================================
#
# resolve_city_canonical(text) 把自由文本 location 规范化为 UK_MAIN_CITIES 中的
# 一个英文名（或 None）。支持：
#   1. 直接城市名（英文边界 / 中文 substring）
#   2. London borough / 著名街区 → "London"
#   3. UK postcode prefix（SW1/E1/B1/M1/L1/...）→ city
#
# 用于 Task / TaskExpertService / Expert 三个表的 city_canonical 列：
# - SQLAlchemy 事件钩子在 insert/update 时自动写入
# - 同城查询走 WHERE city_canonical = $canonical 索引，不再 ILIKE 扫表
# - Backfill 脚本复用此 util 处理历史数据

# London boroughs + 著名街区 → "London"
# 覆盖 33 个正式 borough + 高频街区名
_LONDON_BOROUGHS_RAW = [
    # 32 个 London Boroughs + City of London
    "City of London", "Westminster", "Kensington and Chelsea",
    "Hammersmith and Fulham", "Wandsworth", "Lambeth", "Southwark",
    "Tower Hamlets", "Hackney", "Islington", "Camden", "Brent",
    "Ealing", "Hounslow", "Richmond upon Thames", "Kingston upon Thames",
    "Merton", "Sutton", "Croydon", "Bromley", "Lewisham", "Greenwich",
    "Bexley", "Havering", "Barking and Dagenham", "Redbridge", "Newham",
    "Waltham Forest", "Haringey", "Enfield", "Barnet", "Harrow", "Hillingdon",
    # 高频街区/地名（非正式 borough）
    "Soho", "Chelsea", "Knightsbridge", "Mayfair", "Marylebone",
    "Bloomsbury", "Kings Cross", "Shoreditch", "Brixton", "Notting Hill",
    "Paddington", "Wimbledon", "Wembley", "Stratford", "Canary Wharf",
    "Holborn", "Fitzrovia", "Clapham", "Putney", "Hampstead",
    "Earls Court", "Bayswater", "Pimlico", "Battersea", "Vauxhall",
]

# 借用现有 CHINESE_TO_EN 映射 + borough 映射构建
_BOROUGH_TO_CITY_LOWER: dict[str, str] = {
    b.lower(): "London" for b in _LONDON_BOROUGHS_RAW
}

# UK postcode 区域 → 城市映射（覆盖主要城市的 outward code 前缀）
# 注意：postcode 有重叠/例外，这里取主流情形；少数边缘 case (如 SK Stockport vs Manchester)
# 不强求完美。匹配方式：行首或独立单词的 prefix。
# 参考 https://en.wikipedia.org/wiki/Postcode_areas_in_the_United_Kingdom
_POSTCODE_AREA_TO_CITY: dict[str, str] = {
    # London (E/EC/N/NW/SE/SW/W/WC)
    "E": "London", "EC": "London", "N": "London", "NW": "London",
    "SE": "London", "SW": "London", "W": "London", "WC": "London",
    # Manchester
    "M": "Manchester",
    # Birmingham
    "B": "Birmingham",
    # Liverpool
    "L": "Liverpool",
    # Leeds
    "LS": "Leeds",
    # Sheffield
    "S": "Sheffield",
    # Newcastle
    "NE": "Newcastle",
    # Glasgow
    "G": "Glasgow",
    # Edinburgh
    "EH": "Edinburgh",
    # Cardiff
    "CF": "Cardiff",
    # Bristol
    "BS": "Bristol",
    # Nottingham
    "NG": "Nottingham",
    # Belfast
    "BT": "Belfast",
    # Brighton
    "BN": "Brighton",
    # Cambridge
    "CB": "Cambridge",
    # Oxford
    "OX": "Oxford",
    # Reading
    "RG": "Reading",
    # Southampton
    "SO": "Southampton",
    # York
    "YO": "York",
    # Aberdeen
    "AB": "Aberdeen",
    # Bath
    "BA": "Bath",
    # Coventry
    "CV": "Coventry",
    # Durham
    "DH": "Durham",
    # Exeter
    "EX": "Exeter",
    # Leicester
    "LE": "Leicester",
    # Norwich
    "NR": "Norwich",
    # Swansea
    "SA": "Swansea",
    # Loughborough (LE12) - 已被 LE 覆盖到 Leicester, 但 Loughborough 是独立 city
    # 优先按 borough/直接名匹配，postcode 是兜底
    # Lancaster
    "LA": "Lancaster",
    # Dundee
    "DD": "Dundee",
}

# 按长度倒序匹配（"NW" 优先于 "N"，"EC" 优先于 "E" 等）
_POSTCODE_AREAS_BY_LEN = sorted(
    _POSTCODE_AREA_TO_CITY.keys(), key=lambda k: -len(k)
)

# postcode outward code 正则：开头 1-2 字母 + 1-2 数字 + 可选 1 字母
# 例：SW1A、E1、NW10、M1、B17
_POSTCODE_PATTERN = re.compile(
    r"\b([A-Z]{1,2})\d{1,2}[A-Z]?\b", re.IGNORECASE
)


def _match_postcode_city(text: str) -> Optional[str]:
    """从文本中提取 postcode outward code，返回对应城市名"""
    for m in _POSTCODE_PATTERN.finditer(text):
        prefix = m.group(1).upper()
        # 长前缀优先（NW 先于 N）
        for area in _POSTCODE_AREAS_BY_LEN:
            if prefix == area:
                return _POSTCODE_AREA_TO_CITY[area]
    return None


def _word_boundary_contains(text_lower: str, needle_lower: str) -> bool:
    """英文边界匹配：needle 需作为完整单词出现"""
    if not needle_lower:
        return False
    # 用 \b 边界正则；需 escape 因为 borough 可能含空格
    pattern = r"\b" + re.escape(needle_lower) + r"\b"
    return bool(re.search(pattern, text_lower))


@lru_cache(maxsize=2048)
def resolve_city_canonical(text: Optional[str]) -> Optional[str]:
    """把自由文本 location 规范化为 canonical UK city name.

    优先级（高 → 低）：
      1. UK_MAIN_CITIES 直接命中（英文边界 / 中文 substring / 中英别名）
      2. London borough / 著名街区 → 'London'
      3. UK postcode outward code → city

    返回 canonical 英文名（如 'London'）或 None（无法识别）。

    用 lru_cache 缓存高频字符串结果（事件钩子 + backfill + 查询输入都会调用）。
    """
    if not text:
        return None
    raw = text.strip()
    if not raw:
        return None

    text_lower = raw.lower()

    # 1a. 直接城市名（中英别名表）—— 优先精确单词匹配
    # CITY_NAME_CANONICAL_EN 已包含 32 个英文 canonical name 的小写键
    for city_lower, canonical in CITY_NAME_CANONICAL_EN.items():
        if _word_boundary_contains(text_lower, city_lower):
            return canonical

    # 1b. 中文城市名 substring（中文地址不带空格，无法用 \b 边界）
    if _has_cjk(raw):
        for cn_name, en_name in CITY_NAME_REVERSE_MAPPING.items():
            if cn_name in raw:
                return en_name

    # 2. London borough / 高频街区 → 'London'
    for borough_lower, main_city in _BOROUGH_TO_CITY_LOWER.items():
        if _word_boundary_contains(text_lower, borough_lower):
            return main_city

    # 3. Postcode prefix
    pc_city = _match_postcode_city(raw)
    if pc_city:
        return pc_city

    return None


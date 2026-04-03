"""
搜索关键词双语扩展

将用户搜索词中的已知中英文词汇互相替换，生成多个搜索变体。
例如 "伯明翰中餐" → ["伯明翰中餐", "Birmingham中餐", "伯明翰Chinese food", "Birmingham Chinese food"]
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import List, Tuple

from app.utils.city_filter_utils import (
    CITY_NAME_MAPPING,
    CITY_NAME_REVERSE_MAPPING,
)

# ==================== 常用双语词汇表 ====================
# 格式: 中文 → 英文（自动生成反向映射）
# 覆盖平台高频搜索场景：餐饮、服务、学术、生活

_ZH_EN_TERMS: dict[str, str] = {
    # 餐饮
    "中餐": "Chinese food",
    "中餐馆": "Chinese restaurant",
    "火锅": "hotpot",
    "奶茶": "bubble tea",
    "外卖": "takeaway",
    "烧烤": "BBQ",
    "日料": "Japanese food",
    "韩餐": "Korean food",
    "甜品": "dessert",
    "早茶": "dim sum",
    "串串": "skewers",
    "麻辣烫": "spicy soup",
    "烤鸭": "roast duck",
    "饺子": "dumplings",
    "面条": "noodles",
    "炒饭": "fried rice",
    # 生活服务
    "代购": "purchasing agent",
    "搬家": "moving",
    "接机": "airport pickup",
    "送机": "airport drop-off",
    "家教": "tutor",
    "辅导": "tutoring",
    "翻译": "translation",
    "代写": "ghostwriting",
    "拼车": "carpool",
    "租房": "rental",
    "合租": "flatshare",
    "二手": "second-hand",
    "快递": "delivery",
    "代收": "parcel collection",
    "签证": "visa",
    "保险": "insurance",
    # 学术
    "论文": "essay",
    "作业": "assignment",
    "考试": "exam",
    "雅思": "IELTS",
    "托福": "TOEFL",
    "留学": "study abroad",
    "选课": "course selection",
    "毕业": "graduation",
    # 技能
    "编程": "programming",
    "设计": "design",
    "摄影": "photography",
    "剪辑": "video editing",
    "化妆": "makeup",
    "健身": "fitness",
    "瑜伽": "yoga",
    "钢琴": "piano",
    "吉他": "guitar",
    "绘画": "painting",
    # 其他高频
    "兼职": "part-time job",
    "实习": "internship",
    "志愿者": "volunteer",
    "活动": "event",
    "聚会": "party",
    "旅游": "travel",
    "机票": "flight ticket",
    "酒店": "hotel",
    "民宿": "Airbnb",
    "超市": "supermarket",
    "药店": "pharmacy",
    "医院": "hospital",
    "理发": "haircut",
    "美甲": "nails",
    "宠物": "pet",
    "驾照": "driving licence",
}

# ==================== 构建查找结构 ====================

# 中文 → 英文
_ZH_TO_EN: dict[str, str] = dict(_ZH_EN_TERMS)
# 加入城市名: 中文 → 英文
for _en, _zh in CITY_NAME_MAPPING.items():
    _ZH_TO_EN[_zh] = _en

# 英文 → 中文（小写 key 用于匹配）
_EN_TO_ZH: dict[str, str] = {v.lower(): k for k, v in _ZH_EN_TERMS.items()}
# 加入城市名: 英文 → 中文
for _en, _zh in CITY_NAME_MAPPING.items():
    _EN_TO_ZH[_en.lower()] = _zh

# 按长度降序排列的中文词列表（优先匹配长词）
_ZH_KEYS_BY_LEN: list[str] = sorted(_ZH_TO_EN.keys(), key=len, reverse=True)

# 英文词按长度降序（优先匹配长词组）
_EN_KEYS_BY_LEN: list[str] = sorted(_EN_TO_ZH.keys(), key=len, reverse=True)

_CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def _has_cjk(text: str) -> bool:
    return bool(_CJK_RE.search(text))


def _find_zh_terms(text: str) -> List[Tuple[str, str]]:
    """在文本中查找所有已知中文词，返回 [(中文, 英文), ...]"""
    found: list[Tuple[str, str]] = []
    remaining = text
    for zh in _ZH_KEYS_BY_LEN:
        if zh in remaining:
            found.append((zh, _ZH_TO_EN[zh]))
            remaining = remaining.replace(zh, "", 1)
    return found


def _find_en_terms(text: str) -> List[Tuple[str, str]]:
    """在文本中查找所有已知英文词组，返回 [(英文原文, 中文), ...]"""
    found: list[Tuple[str, str]] = []
    lower = text.lower()
    remaining_lower = lower
    for en_lower in _EN_KEYS_BY_LEN:
        if en_lower in remaining_lower:
            # 找到原文中的实际位置以保留大小写
            idx = remaining_lower.find(en_lower)
            original = text[idx:idx + len(en_lower)]
            found.append((original, _EN_TO_ZH[en_lower]))
            remaining_lower = remaining_lower[:idx] + " " * len(en_lower) + remaining_lower[idx + len(en_lower):]
    return found


def expand_keyword(keyword: str) -> List[str]:
    """
    将搜索关键词扩展为多个双语变体。

    例如:
        "伯明翰中餐" → ["伯明翰中餐", "Birmingham中餐", "伯明翰Chinese food", "Birmingham Chinese food"]
        "Birmingham Chinese food" → ["Birmingham Chinese food", "伯明翰Chinese food", "Birmingham中餐", "伯明翰中餐"]

    返回列表第一项始终是原始关键词，后续为扩展变体。
    如果没有可扩展的词，返回仅包含原始关键词的列表。
    """
    if not keyword or not keyword.strip():
        return [keyword] if keyword else []

    keyword = keyword.strip()
    variants: set[str] = {keyword}

    # 查找中文和英文可替换词
    zh_matches = _find_zh_terms(keyword)
    en_matches = _find_en_terms(keyword)

    if not zh_matches and not en_matches:
        return [keyword]

    # 对每个匹配的词生成替换变体
    # 使用位掩码组合：每个词可以选择原文或翻译
    all_matches: list[Tuple[str, str]] = zh_matches + en_matches

    # 限制组合数量，最多 8 个变体（3 个匹配词 = 2^3 = 8）
    if len(all_matches) > 3:
        all_matches = all_matches[:3]

    count = len(all_matches)
    for mask in range(1, 1 << count):
        variant = keyword
        for i in range(count):
            if mask & (1 << i):
                original, translated = all_matches[i]
                variant = variant.replace(original, translated, 1)
        if variant != keyword:
            variants.add(variant)

    result = [keyword] + [v for v in variants if v != keyword]
    return result


def build_keyword_filter(columns, keyword: str, use_similarity: bool = True, threshold: float = 0.2):
    """
    为多个字段构建双语扩展的关键词过滤条件。

    搜索逻辑：
    1. 先对 keyword 进行分词（jieba + 停用词过滤）
    2. 若分出多个 token，每个 token 单独做双语扩展并生成 OR 条件（多列），各 token 之间用 AND 连接
    3. 若只有一个 token（或分词失败），退化为对整个关键词做双语扩展的 OR 条件

    Args:
        columns: SQLAlchemy column 列表
        keyword: 原始搜索关键词
        use_similarity: 是否使用 pg_trgm similarity（默认 True）
        threshold: similarity 阈值（默认 0.2）

    Returns:
        SQLAlchemy 表达式（多 token 时为 AND，单 token 时为 OR），无有效关键词时返回 None
    """
    from sqlalchemy import or_, and_, func
    from app.utils.tokenizer import tokenize_query

    if not keyword or not keyword.strip():
        return None

    tokens = tokenize_query(keyword)

    # 分词失败或只有一个 token 时，退化为整体关键词扩展（保持向后兼容）
    if len(tokens) <= 1:
        search_term = tokens[0] if tokens else keyword.strip()
        keywords = expand_keyword(search_term)
        conditions = []
        for kw in keywords:
            kw_clean = kw.strip()[:100]
            kw_escaped = kw_clean.replace("%", r"\%").replace("_", r"\_")
            for col in columns:
                conditions.append(col.ilike(f"%{kw_escaped}%"))
                if use_similarity:
                    conditions.append(func.similarity(col, kw_clean) > threshold)
        return or_(*conditions) if conditions else None

    # 多 token：每个 token 生成 OR（多列），各 token 之间 AND 连接
    token_exprs = []
    for token in tokens:
        token_keywords = expand_keyword(token)
        token_conditions = []
        for kw in token_keywords:
            kw_clean = kw.strip()[:100]
            kw_escaped = kw_clean.replace("%", r"\%").replace("_", r"\_")
            for col in columns:
                token_conditions.append(col.ilike(f"%{kw_escaped}%"))
                if use_similarity:
                    token_conditions.append(func.similarity(col, kw_clean) > threshold)
        if token_conditions:
            token_exprs.append(or_(*token_conditions))

    if not token_exprs:
        return None
    return and_(*token_exprs) if len(token_exprs) > 1 else token_exprs[0]


def build_relevance_score(weighted_columns, keyword: str):
    """
    构建基于分词的相关性评分表达式。

    Args:
        weighted_columns: [(column, weight), ...] 列表，如 [(Task.title, 3), (Task.description, 1)]
        keyword: 原始搜索关键词

    Returns:
        SQLAlchemy case 表达式，分值越高越相关
    """
    from sqlalchemy import case, literal
    from app.utils.tokenizer import tokenize_query

    keyword = keyword.strip()
    if not keyword:
        return literal(0)

    tokens = tokenize_query(keyword)
    if not tokens:
        tokens = [keyword.lower()]

    # 对每个词元做双语扩展，生成所有变体的 pattern
    all_patterns = set()
    for token in tokens:
        for variant in expand_keyword(token):
            v = variant.strip()[:100].replace("%", r"\%").replace("_", r"\_")
            all_patterns.add(f"%{v}%")

    # 累加每个 (列, 权重) 对的匹配分
    whens = []
    for col, weight in weighted_columns:
        for pattern in all_patterns:
            whens.append((col.ilike(pattern), weight))

    if not whens:
        return literal(0)

    return case(*whens, else_=0)

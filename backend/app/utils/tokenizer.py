"""
搜索分词模块

提供 tokenize_query：用 jieba 分词并过滤停用词，返回有意义的 token 列表。
与 trending_search.py 共用同一份停用词表和最小长度配置。
"""

from __future__ import annotations

from typing import List

import jieba

# 中英文停用词表
STOP_WORDS = {
    "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都",
    "一", "一个", "上", "也", "很", "到", "说", "要", "去", "你",
    "会", "着", "没有", "看", "好", "自己", "这", "他", "她", "它",
    "们", "那", "被", "从", "把", "让", "用", "为", "什么", "怎么",
    "如何", "哪里", "哪个", "可以", "吗", "呢", "吧", "啊",
    "找", "求", "想", "需要", "推荐", "请问", "有没有", "谁",
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "could", "should", "may", "might", "can", "shall",
    "to", "of", "in", "for", "on", "with", "at", "by", "from",
    "and", "or", "but", "not", "this", "that", "it", "i", "you",
    "he", "she", "we", "they", "me", "him", "her", "us", "them",
    "my", "your", "his", "its", "our", "their", "what", "which",
    "who", "how", "where", "when", "why",
}

# token 最小长度（单字符不纳入）
MIN_TOKEN_LEN = 2


def tokenize_query(query: str) -> List[str]:
    """
    用 jieba 分词并过滤停用词，返回有意义的 token 列表。

    - 中文使用 jieba 精确模式切词
    - 英文统一转小写后按空格拆分（jieba 对英文单词保持整体）
    - 过滤停用词和长度不足 MIN_TOKEN_LEN 的词

    Examples:
        tokenize_query("伯明翰便宜中餐") → ["伯明翰", "便宜", "中餐"]
        tokenize_query("cheap Chinese food Birmingham") → ["cheap", "chinese", "food", "birmingham"]
        tokenize_query("") → []
    """
    if not query or not query.strip():
        return []

    words = jieba.lcut(query.strip().lower())
    tokens = [
        w.strip()
        for w in words
        if w.strip()
        and len(w.strip()) >= MIN_TOKEN_LEN
        and w.strip() not in STOP_WORDS
    ]
    return tokens

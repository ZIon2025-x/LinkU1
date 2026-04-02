"""热搜榜 - 搜索日志记录 & 热搜计算"""

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any

import jieba
from sqlalchemy import select, func, distinct, or_, text
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

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

MIN_TOKEN_LEN = 2


def tokenize_query(query: str) -> List[str]:
    """用 jieba 分词并过滤停用词，返回有意义的 token 列表"""
    words = jieba.lcut(query.strip().lower())
    tokens = [
        w.strip()
        for w in words
        if w.strip()
        and len(w.strip()) >= MIN_TOKEN_LEN
        and w.strip() not in STOP_WORDS
    ]
    return tokens


async def log_search(
    db: AsyncSession,
    raw_query: str,
    user_id: Optional[str] = None,
) -> None:
    """记录一次搜索（异步写入 search_logs）"""
    query = raw_query.strip()
    if not query or len(query) < 2:
        return

    tokens = tokenize_query(query)
    if not tokens:
        return

    log_entry = models.SearchLog(
        user_id=user_id,
        raw_query=query,
        tokens=tokens,
    )
    db.add(log_entry)
    try:
        await db.flush()
    except Exception as e:
        logger.warning(f"Failed to log search: {e}")
        await db.rollback()

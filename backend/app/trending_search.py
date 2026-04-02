"""热搜榜 - 搜索日志记录 & 热搜计算"""

import json
import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any, Set

import jieba
from sqlalchemy import select, func, distinct, or_, text, and_, case, cast, Float
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

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


# ---------------------------------------------------------------------------
# 热搜计算 (同步, 供 TaskScheduler 调用)
# ---------------------------------------------------------------------------

def jaccard_similarity(tokens_a, tokens_b) -> float:
    """计算两组 token 的 Jaccard 相似度: |交集| / |并集|"""
    if not tokens_a or not tokens_b:
        return 0.0
    set_a = set(tokens_a) if not isinstance(tokens_a, set) else tokens_a
    set_b = set(tokens_b) if not isinstance(tokens_b, set) else tokens_b
    intersection = set_a & set_b
    union = set_a | set_b
    return len(intersection) / len(union)


def cluster_queries(
    query_data: List[Dict[str, Any]],
    threshold: float = 0.5,
) -> List[Dict[str, Any]]:
    """
    将相似的搜索词聚类 (Jaccard > threshold)。
    query_data 每项: {"raw_query": str, "tokens": set, "weighted_count": float}
    返回聚类列表，每个聚类取 weighted_count 最高的 raw_query 作为展示词。
    """
    if not query_data:
        return []

    # 按 weighted_count 降序，确保高权重的查询优先成为聚类代表
    sorted_data = sorted(query_data, key=lambda x: x["weighted_count"], reverse=True)
    clusters: List[Dict[str, Any]] = []
    used = [False] * len(sorted_data)

    for i, item in enumerate(sorted_data):
        if used[i]:
            continue
        # 新建聚类，以当前项为代表
        cluster = {
            "keyword": item["raw_query"],
            "tokens": set(item["tokens"]),
            "weighted_count": item["weighted_count"],
        }
        used[i] = True

        for j in range(i + 1, len(sorted_data)):
            if used[j]:
                continue
            sim = jaccard_similarity(cluster["tokens"], sorted_data[j]["tokens"])
            if sim > threshold:
                cluster["weighted_count"] += sorted_data[j]["weighted_count"]
                cluster["tokens"] |= sorted_data[j]["tokens"]
                used[j] = True

        clusters.append(cluster)

    return clusters


def format_heat_display(view_count: int) -> str:
    """格式化热度显示: 2.3w浏览 / 8.6k浏览 / 120浏览"""
    if view_count >= 10000:
        val = view_count / 10000
        formatted = f"{val:.1f}".rstrip("0").rstrip(".")
        return f"{formatted}w浏览"
    elif view_count >= 1000:
        val = view_count / 1000
        formatted = f"{val:.1f}".rstrip("0").rstrip(".")
        return f"{formatted}k浏览"
    else:
        return f"{view_count}浏览"


def compute_trending(db: Session) -> List[Dict[str, Any]]:
    """
    计算热搜榜 Top10（同步函数，由 TaskScheduler with_db 调用）。

    流程:
    1. 查 7 天内搜索日志，按 raw_query 聚合，过滤 ≥3 个不同用户
    2. 按天衰减加权
    3. Jaccard 聚类
    4. 黑名单过滤
    5. 计算浏览量 (forum_posts + tasks 标题匹配)
    6. 与上期 Top10 比较生成 tag
    7. 插入置顶词
    8. 写入 Redis
    9. 清理 30 天前日志
    """
    now = get_utc_time()
    seven_days_ago = now - timedelta(days=7)

    # ------------------------------------------------------------------
    # Step 1 & 2: 查搜索日志, 分天加权
    # ------------------------------------------------------------------
    rows = (
        db.execute(
            select(
                models.SearchLog.raw_query,
                models.SearchLog.tokens,
                models.SearchLog.created_at,
                models.SearchLog.user_id,
            ).where(models.SearchLog.created_at >= seven_days_ago)
        )
        .fetchall()
    )

    if not rows:
        logger.info("compute_trending: 无搜索日志，跳过")
        return []

    # 按 raw_query 聚合，统计不同用户 & 加权计数
    query_agg: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {"tokens": set(), "users": set(), "weighted_count": 0.0}
    )
    for row in rows:
        raw_query = row.raw_query
        tokens = row.tokens if isinstance(row.tokens, (list, set)) else []
        created_at = row.created_at
        user_id = row.user_id or "anonymous"

        # 天数权重: today=7, yesterday=6, ... day7=1
        days_ago = (now - created_at).days
        weight = max(1, 7 - days_ago)

        agg = query_agg[raw_query]
        agg["tokens"].update(tokens)
        agg["users"].add(user_id)
        agg["weighted_count"] += weight

    # 过滤: ≥3 个不同用户
    query_data = [
        {
            "raw_query": rq,
            "tokens": agg["tokens"],
            "weighted_count": agg["weighted_count"],
        }
        for rq, agg in query_agg.items()
        if len(agg["users"]) >= 3
    ]

    if not query_data:
        logger.info("compute_trending: 无满足条件的搜索词 (≥3 users)")
        return []

    # ------------------------------------------------------------------
    # Step 3: 聚类
    # ------------------------------------------------------------------
    clusters = cluster_queries(query_data, threshold=0.5)

    # ------------------------------------------------------------------
    # Step 4: 黑名单过滤
    # ------------------------------------------------------------------
    blacklist_rows = db.execute(
        select(models.TrendingBlacklist.keyword)
    ).fetchall()
    blacklist = {r.keyword.lower() for r in blacklist_rows}

    clusters = [
        c for c in clusters
        if c["keyword"].lower() not in blacklist
    ]

    # ------------------------------------------------------------------
    # Step 5: 计算浏览量 (forum_posts + tasks 标题匹配)
    # ------------------------------------------------------------------
    for cluster in clusters:
        tokens = cluster["tokens"]
        if not tokens:
            cluster["view_count"] = 0
            continue

        # 构建 LIKE 条件: 标题包含任一 token
        like_conditions_forum = []
        like_conditions_task = []
        for token in tokens:
            pattern = f"%{token}%"
            like_conditions_forum.append(
                or_(
                    models.ForumPost.title.ilike(pattern),
                    models.ForumPost.title_zh.ilike(pattern),
                    models.ForumPost.title_en.ilike(pattern),
                )
            )
            like_conditions_task.append(
                or_(
                    models.Task.title.ilike(pattern),
                    models.Task.title_zh.ilike(pattern),
                    models.Task.title_en.ilike(pattern),
                )
            )

        # ForumPost 浏览量
        forum_views = db.execute(
            select(func.coalesce(func.sum(models.ForumPost.view_count), 0)).where(
                and_(
                    models.ForumPost.is_deleted == False,  # noqa: E712
                    or_(*like_conditions_forum),
                )
            )
        ).scalar() or 0

        # Task 浏览量
        task_views = db.execute(
            select(func.coalesce(func.sum(models.Task.view_count), 0)).where(
                or_(*like_conditions_task)
            )
        ).scalar() or 0

        cluster["view_count"] = int(forum_views) + int(task_views)

    # 按 weighted_count 排序
    clusters.sort(key=lambda c: c["weighted_count"], reverse=True)

    # ------------------------------------------------------------------
    # Step 6: 与上期 Top10 比较, 生成 tag
    # ------------------------------------------------------------------
    previous_top10: List[Dict[str, Any]] = []
    try:
        from app.redis_pool import get_client
        redis_client = get_client(decode_responses=True)
        prev_json = redis_client.get("trending:previous")
        if prev_json:
            previous_top10 = json.loads(prev_json)
    except Exception as e:
        logger.warning(f"compute_trending: 读取 Redis previous 失败: {e}")

    prev_keywords = {item["keyword"] for item in previous_top10}
    prev_top3 = {item["keyword"] for item in previous_top10[:3]}
    prev_count_map = {item["keyword"]: item.get("weighted_count", 0) for item in previous_top10}

    for rank, cluster in enumerate(clusters):
        keyword = cluster["keyword"]
        tag = None

        if keyword in prev_top3 and rank < 3:
            tag = "hot"
        elif keyword not in prev_keywords:
            tag = "new"
        elif keyword in prev_count_map:
            old_count = prev_count_map[keyword]
            if old_count > 0 and cluster["weighted_count"] > old_count * 1.5:
                tag = "up"

        cluster["tag"] = tag

    # ------------------------------------------------------------------
    # Step 7: 插入置顶词
    # ------------------------------------------------------------------
    pinned_rows = db.execute(
        select(models.TrendingPinned).where(
            or_(
                models.TrendingPinned.expires_at.is_(None),
                models.TrendingPinned.expires_at > now,
            )
        ).order_by(models.TrendingPinned.sort_order.asc())
    ).scalars().all()

    pinned_items = [
        {
            "keyword": p.keyword,
            "view_count": 0,
            "heat_display": p.display_heat or "",
            "tag": "pinned",
            "weighted_count": 0,
            "is_pinned": True,
        }
        for p in pinned_rows
    ]

    # ------------------------------------------------------------------
    # Step 8: 组装 Top10, 写入 Redis
    # ------------------------------------------------------------------
    # 置顶词占据前面位置，剩余由算法填充
    results: List[Dict[str, Any]] = []
    seen_keywords: Set[str] = set()

    for item in pinned_items:
        if len(results) >= 10:
            break
        if item["keyword"].lower() not in seen_keywords:
            results.append(item)
            seen_keywords.add(item["keyword"].lower())

    for cluster in clusters:
        if len(results) >= 10:
            break
        if cluster["keyword"].lower() in seen_keywords:
            continue
        results.append({
            "keyword": cluster["keyword"],
            "view_count": cluster.get("view_count", 0),
            "heat_display": format_heat_display(cluster.get("view_count", 0)),
            "tag": cluster.get("tag"),
            "weighted_count": cluster["weighted_count"],
            "is_pinned": False,
        })
        seen_keywords.add(cluster["keyword"].lower())

    # 写入 Redis
    try:
        from app.redis_pool import get_client
        redis_client = get_client(decode_responses=True)

        # 保存旧 current → previous
        current_json = redis_client.get("trending:current")
        if current_json:
            redis_client.set("trending:previous", current_json, ex=7200)  # 2h TTL

        # 写入新 current (TTL 70 min)
        redis_client.set(
            "trending:current",
            json.dumps(results, ensure_ascii=False),
            ex=4200,
        )
        logger.info(f"compute_trending: 已更新热搜榜, {len(results)} 条")
    except Exception as e:
        logger.warning(f"compute_trending: 写入 Redis 失败: {e}")

    # ------------------------------------------------------------------
    # Step 9: 清理 30 天前搜索日志
    # ------------------------------------------------------------------
    thirty_days_ago = now - timedelta(days=30)
    try:
        db.execute(
            models.SearchLog.__table__.delete().where(
                models.SearchLog.created_at < thirty_days_ago
            )
        )
        db.commit()
    except Exception as e:
        logger.warning(f"compute_trending: 清理旧日志失败: {e}")
        db.rollback()

    return results

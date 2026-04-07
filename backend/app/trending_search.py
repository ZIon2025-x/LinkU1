"""热搜榜 - 搜索日志记录 & 热搜计算"""

import json
import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any, Set

from sqlalchemy import select, func, distinct, or_, text, and_, case, cast, Float
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time
from app.utils.tokenizer import tokenize_query, STOP_WORDS, MIN_TOKEN_LEN

logger = logging.getLogger(__name__)


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
        # 不 rollback — 避免回滚调用方的事务；expunge 失败的对象即可
        db.expunge(log_entry)


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
        center_tokens = set(item["tokens"])  # 固定聚类中心 tokens
        cluster = {
            "keyword": item["raw_query"],
            "tokens": set(item["tokens"]),
            "weighted_count": item["weighted_count"],
        }
        used[i] = True

        for j in range(i + 1, len(sorted_data)):
            if used[j]:
                continue
            # 只与聚类中心比较，防止 token 集合膨胀导致无关合并
            sim = jaccard_similarity(center_tokens, sorted_data[j]["tokens"])
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


TRENDING_WINDOW_DAYS = 90
LOG_RETENTION_DAYS = 120  # 搜索日志保留天数（≥ 窗口天数 + 缓冲）
TRENDING_TOP_N = 10


def compute_trending(db: Session) -> List[Dict[str, Any]]:
    """
    计算热搜榜 Top10（同步函数，由 TaskScheduler with_db 调用）。

    Sticky 语义：一旦上榜就"挂着"，只有新词权重更高时才会被挤下去。
    - 90 天内的搜索词计算 fresh 权重
    - 已存在于快照但本次未出现在候选中的老词，**冻结**其历史 weighted_count
    - 合并后按 weighted_count 排序取 Top N

    流程:
    1. 查 90 天内搜索日志，按 raw_query 聚合，过滤 ≥3 个不同用户
    2. 按天衰减加权
    3. Jaccard 聚类
    4. 黑名单过滤
    5. 计算浏览量
    6. 合并老快照（冻结权重）
    7. 与上期 Top10 比较生成 tag
    8. 插入置顶词
    9. 写入 trending_snapshot 表 + Redis 缓存
    10. 清理过期日志
    """
    now = get_utc_time()
    window_start = now - timedelta(days=TRENDING_WINDOW_DAYS)

    # ------------------------------------------------------------------
    # Step 1 & 2: SQL 聚合 — 按 raw_query 分组，计算加权值，过滤 ≥3 用户
    # 按天衰减：今天=TRENDING_WINDOW_DAYS，越老权重越低，最低为 1
    # ------------------------------------------------------------------
    day_weight = func.greatest(
        1,
        TRENDING_WINDOW_DAYS - func.extract(
            "day", now - models.SearchLog.created_at
        ).cast(Float),
    )

    agg_query = (
        select(
            models.SearchLog.raw_query,
            func.count(distinct(models.SearchLog.user_id)).label("user_count"),
            func.sum(day_weight).label("weighted_count"),
        )
        .where(models.SearchLog.created_at >= window_start)
        .group_by(models.SearchLog.raw_query)
        .having(func.count(distinct(models.SearchLog.user_id)) >= 3)
    )
    agg_rows = db.execute(agg_query).fetchall()

    if not agg_rows:
        logger.info(
            f"compute_trending: 无满足条件的搜索词 (≥3 users, {TRENDING_WINDOW_DAYS}d window) — "
            "将仅使用老快照 + 置顶词"
        )
        agg_rows = []

    # 只对满足条件的 raw_query 取 tokens（去重后的第一条即可）
    qualified_queries = {row.raw_query for row in agg_rows}
    weighted_map = {row.raw_query: float(row.weighted_count) for row in agg_rows}

    # 批量取 tokens：每个 raw_query 只取一条的 tokens
    token_rows = []
    if qualified_queries:
        token_rows = db.execute(
            select(
                models.SearchLog.raw_query,
                models.SearchLog.tokens,
            )
            .where(models.SearchLog.raw_query.in_(qualified_queries))
            .distinct(models.SearchLog.raw_query)
        ).fetchall()

    token_map: Dict[str, set] = {}
    for row in token_rows:
        rq = row.raw_query
        tokens = row.tokens if isinstance(row.tokens, (list, set)) else []
        if rq not in token_map:
            token_map[rq] = set(tokens)
        else:
            token_map[rq].update(tokens)

    query_data = [
        {
            "raw_query": rq,
            "tokens": token_map.get(rq, set()),
            "weighted_count": weighted_map[rq],
        }
        for rq in qualified_queries
        if token_map.get(rq)
    ]

    if not query_data:
        logger.info("compute_trending: 无有效 token 的新搜索词 — 将仅使用老快照 + 置顶词")

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
        if not any(bw in c["keyword"].lower() for bw in blacklist)
    ]

    # 先按 weighted_count 排序，只对 Top 15 计算浏览量（减少 SQL 查询数）
    clusters.sort(key=lambda c: c["weighted_count"], reverse=True)

    # ------------------------------------------------------------------
    # Step 5: 计算浏览量 (仅 Top 15，多 token AND 匹配标题+内容/描述)
    # ------------------------------------------------------------------
    TOP_N_VIEW_COUNT = 15  # 只查前15，最终取10，留5的余量给黑名单过滤后补位
    for cluster in clusters[:TOP_N_VIEW_COUNT]:
        tokens = cluster["tokens"]
        if not tokens:
            cluster["view_count"] = 0
            continue

        # 构建 LIKE 条件: 每个 token 必须在标题或内容中命中（AND 逻辑）
        # 与实际搜索 build_keyword_filter 保持一致
        def _build_and_filter(columns):
            """为一组字段构建多 token AND 过滤: 每个 token 至少命中一个字段"""
            token_exprs = []
            for token in tokens:
                safe_token = token.replace('%', r'\%').replace('_', r'\_')
                pattern = f"%{safe_token}%"
                token_exprs.append(or_(*[col.ilike(pattern) for col in columns]))
            return and_(*token_exprs) if len(token_exprs) > 1 else token_exprs[0]

        # ForumPost 浏览量（标题 + 内容）
        forum_views = db.execute(
            select(func.coalesce(func.sum(models.ForumPost.view_count), 0)).where(
                and_(
                    models.ForumPost.is_deleted == False,  # noqa: E712
                    _build_and_filter([
                        models.ForumPost.title, models.ForumPost.title_zh, models.ForumPost.title_en,
                        models.ForumPost.content, models.ForumPost.content_zh, models.ForumPost.content_en,
                    ]),
                )
            )
        ).scalar() or 0

        # Task 浏览量（标题 + 描述）
        task_views = db.execute(
            select(func.coalesce(func.sum(models.Task.view_count), 0)).where(
                and_(
                    models.Task.status != "cancelled",
                    _build_and_filter([
                        models.Task.title, models.Task.title_zh, models.Task.title_en,
                        models.Task.description, models.Task.description_zh, models.Task.description_en,
                    ]),
                )
            )
        ).scalar() or 0

        # FleaMarketItem 浏览量（标题 + 描述）
        flea_views = db.execute(
            select(func.coalesce(func.sum(models.FleaMarketItem.view_count), 0)).where(
                and_(
                    models.FleaMarketItem.status != "deleted",
                    models.FleaMarketItem.is_visible == True,  # noqa: E712
                    _build_and_filter([
                        models.FleaMarketItem.title,
                        models.FleaMarketItem.description,
                    ]),
                )
            )
        ).scalar() or 0

        # TaskExpertService 浏览量（名称 + 描述）
        service_views = db.execute(
            select(func.coalesce(func.sum(models.TaskExpertService.view_count), 0)).where(
                and_(
                    models.TaskExpertService.status == "active",
                    _build_and_filter([
                        models.TaskExpertService.service_name, models.TaskExpertService.service_name_en,
                        models.TaskExpertService.description, models.TaskExpertService.description_en,
                        models.TaskExpertService.description_zh,
                    ]),
                )
            )
        ).scalar() or 0

        # CustomLeaderboard 浏览量（名称 + 描述）
        lb_views = db.execute(
            select(func.coalesce(func.sum(models.CustomLeaderboard.view_count), 0)).where(
                and_(
                    models.CustomLeaderboard.status == "active",
                    _build_and_filter([
                        models.CustomLeaderboard.name, models.CustomLeaderboard.name_en, models.CustomLeaderboard.name_zh,
                        models.CustomLeaderboard.description, models.CustomLeaderboard.description_en,
                        models.CustomLeaderboard.description_zh,
                    ]),
                )
            )
        ).scalar() or 0

        # Activity 浏览量（标题 + 描述）
        activity_views = db.execute(
            select(func.coalesce(func.sum(models.Activity.view_count), 0)).where(
                and_(
                    models.Activity.status != "cancelled",
                    _build_and_filter([
                        models.Activity.title, models.Activity.title_zh, models.Activity.title_en,
                        models.Activity.description, models.Activity.description_zh, models.Activity.description_en,
                    ]),
                )
            )
        ).scalar() or 0

        # ForumCategory 浏览量（名称 + 描述）
        category_views = db.execute(
            select(func.coalesce(func.sum(models.ForumCategory.view_count), 0)).where(
                and_(
                    models.ForumCategory.is_visible == True,  # noqa: E712
                    _build_and_filter([
                        models.ForumCategory.name, models.ForumCategory.name_en, models.ForumCategory.name_zh,
                        models.ForumCategory.description, models.ForumCategory.description_en,
                        models.ForumCategory.description_zh,
                    ]),
                )
            )
        ).scalar() or 0

        cluster["view_count"] = (
            int(forum_views) + int(task_views) + int(flea_views)
            + int(service_views) + int(lb_views)
            + int(activity_views) + int(category_views)
        )

    # 超出 Top 15 的 cluster 不查浏览量，设为 0
    for cluster in clusters[TOP_N_VIEW_COUNT:]:
        cluster["view_count"] = 0

    # ------------------------------------------------------------------
    # Step 5.5: 合并老快照 — 冻结权重实现 sticky trending
    #
    # 本次新候选以 fresh 权重胜出；但上次快照里未出现在新候选的老词，
    # 携带 **冻结** 的 weighted_count 注入，保留其在榜位置。
    # ------------------------------------------------------------------
    fresh_keywords_lower = {c["keyword"].lower() for c in clusters}

    snapshot_rows = db.execute(
        select(models.TrendingSnapshot).order_by(models.TrendingSnapshot.rank.asc())
    ).scalars().all()

    frozen_count = 0
    for snap in snapshot_rows:
        if snap.keyword.lower() in fresh_keywords_lower:
            continue  # 本次有新权重，直接覆盖老值
        snap_tokens = snap.tokens if isinstance(snap.tokens, list) else []
        clusters.append({
            "keyword": snap.keyword,
            "tokens": set(snap_tokens),
            "weighted_count": float(snap.weighted_count),
            "view_count": int(snap.view_count),
            "tag": snap.tag,  # 冻结原 tag；Step 6 会跳过已有 tag 的条目
            "_frozen": True,
            "_frozen_heat_display": snap.heat_display or "",
        })
        frozen_count += 1

    if frozen_count:
        logger.info(f"compute_trending: 合并 {frozen_count} 个冻结老词")

    # 合并后按 weighted_count 再次排序
    clusters.sort(key=lambda c: c["weighted_count"], reverse=True)

    # ------------------------------------------------------------------
    # Step 6: 与上期 Top10 比较, 生成 tag (跳过已冻结 tag 的老词)
    # ------------------------------------------------------------------
    from app.redis_pool import get_client
    redis_client = get_client(decode_responses=True)

    previous_top10: List[Dict[str, Any]] = []
    try:
        if redis_client:
            prev_json = redis_client.get("trending:previous")
            if prev_json:
                previous_top10 = json.loads(prev_json)
    except Exception as e:
        logger.warning(f"compute_trending: 读取 Redis previous 失败: {e}")

    prev_keywords = {item["keyword"] for item in previous_top10}
    prev_top3 = {item["keyword"] for item in previous_top10[:3]}
    prev_count_map = {item["keyword"]: item.get("weighted_count", 0) for item in previous_top10}

    for rank, cluster in enumerate(clusters):
        if cluster.get("_frozen"):
            # 老快照词：保留原 tag，不重新评估
            continue

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
            "tag": None,
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
        if len(results) >= TRENDING_TOP_N:
            break
        if cluster["keyword"].lower() in seen_keywords:
            continue
        # 冻结条目使用快照里的 heat_display；新条目按 view_count 格式化
        if cluster.get("_frozen"):
            heat_display = cluster.get("_frozen_heat_display", "") or format_heat_display(
                cluster.get("view_count", 0)
            )
        else:
            heat_display = format_heat_display(cluster.get("view_count", 0))

        results.append({
            "keyword": cluster["keyword"],
            "tokens": sorted(cluster.get("tokens") or []),  # 存回 snapshot 需要
            "view_count": cluster.get("view_count", 0),
            "heat_display": heat_display,
            "tag": cluster.get("tag"),
            "weighted_count": cluster["weighted_count"],
            "is_pinned": False,
        })
        seen_keywords.add(cluster["keyword"].lower())

    # 添加排名号
    for i, item in enumerate(results):
        item["rank"] = i + 1

    # ------------------------------------------------------------------
    # Step 9a: 持久化到 trending_snapshot 表（非置顶词，供下次合并使用）
    # ------------------------------------------------------------------
    try:
        db.execute(models.TrendingSnapshot.__table__.delete())
        snapshot_entries = [
            r for r in results if not r.get("is_pinned")
        ]
        for item in snapshot_entries:
            db.execute(
                models.TrendingSnapshot.__table__.insert().values(
                    rank=item["rank"],
                    keyword=item["keyword"],
                    tokens=item.get("tokens", []),
                    view_count=int(item.get("view_count", 0)),
                    heat_display=item.get("heat_display", ""),
                    tag=item.get("tag"),
                    weighted_count=float(item.get("weighted_count", 0)),
                    updated_at=now,
                )
            )
        db.commit()
        logger.info(
            f"compute_trending: 快照已持久化, {len(snapshot_entries)} 条 (总榜 {len(results)} 条)"
        )
    except Exception as e:
        logger.warning(f"compute_trending: 写入 snapshot 表失败: {e}")
        db.rollback()

    # 构建对外返回/Redis 用的精简结构 (去掉内部 tokens 字段，对前端无用)
    public_results = [
        {k: v for k, v in r.items() if k != "tokens"}
        for r in results
    ]

    # ------------------------------------------------------------------
    # Step 9b: 写入 Redis 缓存 (redis_client 已在 Step 6 获取)
    # ------------------------------------------------------------------
    try:
        if not redis_client:
            logger.warning("compute_trending: Redis 不可用，跳过缓存写入")
        else:
            # 保存旧 current → previous
            current_json = redis_client.get("trending:current")
            if current_json:
                redis_client.set("trending:previous", current_json, ex=14400)  # 4h TTL

            # 写入新 current (TTL 70 min)
            redis_client.set(
                "trending:current",
                json.dumps(public_results, ensure_ascii=False),
                ex=4200,
            )
            redis_client.set("trending:updated_at", now.isoformat(), ex=4200)
            logger.info(f"compute_trending: 已更新热搜榜, {len(public_results)} 条")
    except Exception as e:
        logger.warning(f"compute_trending: 写入 Redis 失败: {e}")

    # ------------------------------------------------------------------
    # Step 10: 清理过期搜索日志 (保留 LOG_RETENTION_DAYS 天)
    # ------------------------------------------------------------------
    retention_cutoff = now - timedelta(days=LOG_RETENTION_DAYS)
    try:
        db.execute(
            models.SearchLog.__table__.delete().where(
                models.SearchLog.created_at < retention_cutoff
            )
        )
        db.commit()
    except Exception as e:
        logger.warning(f"compute_trending: 清理旧日志失败: {e}")
        db.rollback()

    return public_results

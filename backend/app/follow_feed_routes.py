"""
关注 Feed 路由
展示来自已关注用户的内容时间线（Timeline）
"""

import logging
from datetime import timedelta
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_current_user_secure, get_async_db_dependency
from app.discovery_routes import _first_image, _parse_images

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/follow", tags=["关注"])


# ==================== 主接口 ====================


@router.get("/feed")
async def get_follow_feed(
    page: int = Query(1, ge=1, le=50, description="页码"),
    page_size: int = Query(20, ge=1, le=50, description="每页数量"),
    current_user: models.User = Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取关注用户的内容时间线

    按发布时间倒序排列，展示所有已关注用户的最新内容。
    包含：任务、论坛帖子、跳蚤市场商品、达人/个人服务、活动、任务完成记录、竞品评价、服务评价、排行榜。
    """
    # 1. 获取关注的用户 ID（最近关注的 200 个）
    following_result = await db.execute(
        select(models.UserFollow.following_id)
        .where(models.UserFollow.follower_id == current_user.id)
        .order_by(desc(models.UserFollow.created_at))
        .limit(200)
    )
    following_ids = [row[0] for row in following_result.all()]

    if not following_ids:
        return {"items": [], "page": page, "has_more": False}

    offset = (page - 1) * page_size
    fetch_limit = offset + page_size

    # 2. 顺序获取 6 种内容类型（共享 db session，无需 SAVEPOINT）
    all_items: List[dict] = []

    fetch_tasks = [
        ("tasks", _fetch_followed_tasks(db, following_ids, fetch_limit)),
        ("forum_posts", _fetch_followed_forum_posts(db, following_ids, fetch_limit)),
        ("flea_market", _fetch_followed_flea_market(db, following_ids, fetch_limit)),
        ("services", _fetch_followed_services(db, following_ids, fetch_limit)),
        ("activities", _fetch_followed_activities(db, following_ids, fetch_limit)),
        ("completions", _fetch_followed_completions(db, following_ids, fetch_limit)),
        ("competitor_reviews", _fetch_followed_competitor_reviews(db, following_ids, fetch_limit, current_user)),
        ("service_reviews", _fetch_followed_service_reviews(db, following_ids, fetch_limit)),
        ("rankings", _fetch_followed_rankings(db, following_ids, fetch_limit)),
    ]

    for name, coro in fetch_tasks:
        try:
            result_items = await coro
            all_items.extend(result_items)
        except Exception as e:
            logger.warning(f"Failed to fetch followed {name} for follow feed: {e}")

    # 3. 按 created_at 降序排序（纯时间线）
    all_items.sort(
        key=lambda x: x.get("created_at") or "",
        reverse=True,
    )

    # 4. 分页
    page_items = all_items[offset : offset + page_size]

    return {
        "items": page_items,
        "page": page,
        "has_more": len(all_items) > offset + page_size,
    }


# ==================== 数据获取函数 ====================


async def _fetch_followed_tasks(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的任务（30天内）"""
    from sqlalchemy import func
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    app_count = (
        select(func.count(models.TaskApplication.id))
        .where(models.TaskApplication.task_id == models.Task.id)
        .correlate(models.Task)
        .scalar_subquery()
        .label("app_count")
    )

    query = (
        select(
            models.Task.id,
            models.Task.title,
            models.Task.title_zh,
            models.Task.title_en,
            models.Task.description,
            models.Task.description_zh,
            models.Task.description_en,
            models.Task.images,
            models.Task.task_type,
            models.Task.reward,
            models.Task.base_reward,
            models.Task.reward_to_be_quoted,
            models.Task.task_level,
            models.Task.view_count,
            models.Task.poster_id,
            models.Task.created_at,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
            app_count,
        )
        .join(models.User, models.Task.poster_id == models.User.id)
        .where(
            models.Task.poster_id.in_(following_ids),
            models.Task.status == "open",
            models.Task.is_visible == True,
            models.Task.created_at >= cutoff,
        )
        .order_by(desc(models.Task.created_at))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        first_img = _first_image(row.images)
        items.append({
            "feed_type": "task",
            "id": f"task_{row.id}",
            "title": row.title,
            "title_zh": row.title_zh,
            "title_en": row.title_en,
            "description": (row.description or "")[:100],
            "description_zh": (row.description_zh or "")[:100] if row.description_zh else None,
            "description_en": (row.description_en or "")[:100] if row.description_en else None,
            "images": [first_img] if first_img else None,
            "user_id": str(row.poster_id) if row.poster_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": float(row.reward) if row.reward else None,
            "original_price": float(row.base_reward) if row.base_reward else None,
            "discount_percentage": None,
            "currency": "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": row.view_count or 0,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "task_type": row.task_type,
                "reward": float(row.reward) if row.reward else None,
                "base_reward": float(row.base_reward) if row.base_reward else None,
                "reward_to_be_quoted": row.reward_to_be_quoted,
                "task_level": row.task_level,
                "application_count": row.app_count or 0,
            },
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_forum_posts(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的论坛帖子（30天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.ForumPost.id,
            models.ForumPost.title,
            models.ForumPost.content,
            models.ForumPost.images,
            models.ForumPost.like_count,
            models.ForumPost.reply_count,
            models.ForumPost.view_count,
            models.ForumPost.author_id,
            models.ForumPost.created_at,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.User, models.ForumPost.author_id == models.User.id)
        .where(
            models.ForumPost.author_id.in_(following_ids),
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
            models.ForumPost.created_at >= cutoff,
        )
        .order_by(desc(models.ForumPost.created_at))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        post_images = _parse_images(row.images)
        content_preview = (row.content or "")[:100]
        items.append({
            "feed_type": "forum_post",
            "id": f"post_{row.id}",
            "title": row.title,
            "title_zh": None,
            "title_en": None,
            "description": content_preview,
            "description_zh": None,
            "description_en": None,
            "images": post_images if post_images else None,
            "user_id": str(row.author_id) if row.author_id else None,
            "user_name": row.user_name or "匿名用户",
            "user_avatar": row.user_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": row.like_count,
            "comment_count": row.reply_count,
            "view_count": row.view_count or 0,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_flea_market(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的跳蚤市场商品（30天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.FleaMarketItem.id,
            models.FleaMarketItem.title,
            models.FleaMarketItem.description,
            models.FleaMarketItem.price,
            models.FleaMarketItem.currency,
            models.FleaMarketItem.images,
            models.FleaMarketItem.view_count,
            models.FleaMarketItem.seller_id,
            models.FleaMarketItem.created_at,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.User, models.FleaMarketItem.seller_id == models.User.id)
        .where(
            models.FleaMarketItem.seller_id.in_(following_ids),
            models.FleaMarketItem.status == "active",
            models.FleaMarketItem.is_visible == True,
            models.FleaMarketItem.created_at >= cutoff,
        )
        .order_by(desc(models.FleaMarketItem.created_at))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        first_img = _first_image(row.images)
        items.append({
            "feed_type": "product",
            "id": f"product_{row.id}",
            "title": row.title,
            "title_zh": None,
            "title_en": None,
            "description": (row.description or "")[:80],
            "description_zh": None,
            "description_en": None,
            "images": [first_img] if first_img else None,
            "user_id": str(row.seller_id) if row.seller_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": float(row.price) if row.price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": row.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": row.view_count or 0,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_services(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户发布的达人服务（30天内）"""
    from sqlalchemy import func as sa_func
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    # Resolve owner: expert_id takes priority over user_id (avoids duplicate joins)
    owner_col = sa_func.coalesce(
        models.TaskExpertService.expert_id,
        models.TaskExpertService.user_id,
    ).label("owner_id")

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.description,
            models.TaskExpertService.category,
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.expert_id,
            models.TaskExpertService.user_id,
            models.TaskExpertService.created_at,
            owner_col,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(
            models.User,
            sa_func.coalesce(
                models.TaskExpertService.expert_id,
                models.TaskExpertService.user_id,
            ) == models.User.id,
        )
        .where(
            sa_func.coalesce(
                models.TaskExpertService.expert_id,
                models.TaskExpertService.user_id,
            ).in_(following_ids),
            models.TaskExpertService.status == "active",
            models.TaskExpertService.created_at >= cutoff,
        )
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        service_thumb = _first_image(row.service_images)
        owner_id = row.expert_id or row.user_id
        items.append({
            "feed_type": "service",
            "id": f"service_{row.id}",
            "title": row.service_name,
            "title_zh": None,
            "title_en": None,
            "description": (row.description or "")[:80],
            "description_zh": None,
            "description_en": None,
            "images": [service_thumb] if service_thumb else None,
            "user_id": str(owner_id) if owner_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": float(row.base_price) if row.base_price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": row.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {"category": row.category} if row.category else None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_activities(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户创建的活动（30天内，open 状态）"""
    from sqlalchemy import func, or_
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)
    now = get_utc_time()

    participant_count = (
        select(func.count(models.OfficialActivityApplication.id))
        .where(
            models.OfficialActivityApplication.activity_id == models.Activity.id,
            models.OfficialActivityApplication.status.in_(["pending", "won", "attending"]),
        )
        .correlate(models.Activity)
        .scalar_subquery()
        .label("participant_count")
    )

    query = (
        select(
            models.Activity.id,
            models.Activity.title,
            models.Activity.title_zh,
            models.Activity.title_en,
            models.Activity.description,
            models.Activity.description_zh,
            models.Activity.description_en,
            models.Activity.images,
            models.Activity.activity_type,
            models.Activity.location,
            models.Activity.deadline,
            models.Activity.reward_type,
            models.Activity.original_price_per_participant,
            models.Activity.discounted_price_per_participant,
            models.Activity.currency,
            models.Activity.max_participants,
            models.Activity.expert_id,
            models.Activity.created_at,
            participant_count,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.User, models.Activity.expert_id == models.User.id)
        .where(
            models.Activity.expert_id.in_(following_ids),
            models.Activity.status == "open",
            models.Activity.visibility == "public",
            models.Activity.created_at >= cutoff,
            or_(
                models.Activity.deadline > now,
                models.Activity.deadline.is_(None),
            ),
        )
        .order_by(desc(models.Activity.created_at))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        first_img = _first_image(row.images)
        price = float(row.discounted_price_per_participant) if row.discounted_price_per_participant is not None else None
        original_price = float(row.original_price_per_participant) if row.original_price_per_participant is not None else None
        discount_pct = None
        if original_price and price and original_price > 0 and price < original_price:
            discount_pct = round((1 - price / original_price) * 100)

        items.append({
            "feed_type": "activity",
            "id": f"activity_{row.id}",
            "title": row.title,
            "title_zh": row.title_zh,
            "title_en": row.title_en,
            "description": (row.description or "")[:100],
            "description_zh": (row.description_zh or "")[:100] if row.description_zh else None,
            "description_en": (row.description_en or "")[:100] if row.description_en else None,
            "images": [first_img] if first_img else None,
            "user_id": str(row.expert_id) if row.expert_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": price,
            "original_price": original_price,
            "discount_percentage": discount_pct,
            "currency": row.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": {
                "activity_type": row.activity_type,
                "max_participants": row.max_participants,
                "current_participants": row.participant_count or 0,
                "reward_type": row.reward_type,
                "location": row.location,
                "deadline": row.deadline.isoformat() if row.deadline else None,
            },
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_completions(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的任务完成记录（30天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.TaskHistory.id,
            models.TaskHistory.task_id,
            models.TaskHistory.user_id,
            models.TaskHistory.timestamp,
            models.Task.task_type,
            models.Task.title.label("task_title"),
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.Task, models.TaskHistory.task_id == models.Task.id)
        .join(models.User, models.TaskHistory.user_id == models.User.id)
        .where(
            models.TaskHistory.user_id.in_(following_ids),
            models.TaskHistory.action == "completed",
            models.TaskHistory.timestamp >= cutoff,
        )
        .order_by(desc(models.TaskHistory.timestamp))
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        task_type_str = row.task_type or ""
        items.append({
            "feed_type": "completion",
            "id": f"completion_{row.id}",
            "title": f"完成了一个{task_type_str}任务",
            "title_zh": f"完成了一个{task_type_str}任务",
            "title_en": f"Completed a {task_type_str} task",
            "description": row.task_title,
            "description_zh": None,
            "description_en": None,
            "images": None,
            "user_id": str(row.user_id) if row.user_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {"task_type": row.task_type, "task_id": row.task_id},
            "created_at": row.timestamp.isoformat() if row.timestamp else None,
        })
    return items


async def _fetch_followed_competitor_reviews(
    db: AsyncSession, following_ids: List[str], limit: int, current_user=None
) -> list:
    """获取关注用户的竞品评价（30天内有留言的排行榜投票）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.LeaderboardVote.id.label("vote_id"),
            models.LeaderboardVote.user_id,
            models.LeaderboardVote.vote_type,
            models.LeaderboardVote.comment,
            models.LeaderboardVote.like_count,
            models.LeaderboardVote.created_at,
            models.LeaderboardVote.item_id.label("vote_item_id"),
            models.User.name.label("reviewer_name"),
            models.User.avatar.label("reviewer_avatar"),
            models.LeaderboardItem.name.label("item_name"),
            models.LeaderboardItem.images.label("item_images"),
            models.LeaderboardItem.upvotes.label("item_upvotes"),
            models.LeaderboardItem.downvotes.label("item_downvotes"),
            models.CustomLeaderboard.name.label("leaderboard_name"),
        )
        .join(models.User, models.LeaderboardVote.user_id == models.User.id)
        .join(models.LeaderboardItem, models.LeaderboardVote.item_id == models.LeaderboardItem.id)
        .join(models.CustomLeaderboard, models.LeaderboardItem.leaderboard_id == models.CustomLeaderboard.id)
        .where(
            models.LeaderboardVote.user_id.in_(following_ids),
            models.LeaderboardVote.is_anonymous == False,
            models.LeaderboardVote.comment.isnot(None),
            models.LeaderboardVote.comment != "",
            models.LeaderboardItem.status == "approved",
            models.CustomLeaderboard.status == "active",
            models.LeaderboardVote.created_at >= cutoff,
        )
        .order_by(desc(models.LeaderboardVote.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    # 批量查询当前用户对这些条目的投票状态
    user_vote_map = {}
    if current_user and rows:
        item_ids = list({row.vote_item_id for row in rows})
        user_vote_result = await db.execute(
            select(
                models.LeaderboardVote.item_id,
                models.LeaderboardVote.vote_type,
            ).where(
                models.LeaderboardVote.user_id == current_user.id,
                models.LeaderboardVote.item_id.in_(item_ids),
            )
        )
        for vrow in user_vote_result.all():
            user_vote_map[vrow[0]] = vrow[1]

    items = []
    for row in rows:
        reviewer_name = row.reviewer_name or "匿名用户"
        reviewer_avatar = row.reviewer_avatar
        item_thumb = _first_image(row.item_images)

        items.append({
            "feed_type": "competitor_review",
            "id": f"creview_{row.vote_id}",
            "title": None,
            "title_zh": None,
            "title_en": None,
            "description": row.comment,
            "description_zh": None,
            "description_en": None,
            "images": None,
            "user_id": str(row.user_id),
            "user_name": reviewer_name,
            "user_avatar": reviewer_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": row.like_count or 0,
            "comment_count": None,
            "view_count": None,
            "upvote_count": row.item_upvotes or 0,
            "downvote_count": row.item_downvotes or 0,
            "vote_type": row.vote_type,
            "linked_item": None,
            "target_item": {
                "item_type": "competitor",
                "item_id": str(row.vote_item_id),
                "name": row.item_name,
                "subtitle": row.leaderboard_name,
                "thumbnail": item_thumb,
            },
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": user_vote_map.get(row.vote_item_id) if current_user else None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_service_reviews(
    db: AsyncSession, following_ids: List[str], limit: int
) -> list:
    """获取关注用户的达人服务评价（30天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.Review.id,
            models.Review.rating,
            models.Review.comment,
            models.Review.created_at,
            models.Review.user_id,
            models.User.name.label("reviewer_name"),
            models.User.avatar.label("reviewer_avatar"),
            models.Task.expert_service_id,
            models.Task.parent_activity_id,
            models.Task.task_source,
            models.TaskExpertService.service_name,
            models.TaskExpertService.images.label("service_images"),
            models.Activity.title.label("activity_title"),
            getattr(models.Activity, "title_zh", None).label("activity_title_zh"),
            getattr(models.Activity, "title_en", None).label("activity_title_en"),
            models.Activity.original_price_per_participant,
            models.Activity.discounted_price_per_participant,
            models.Activity.discount_percentage,
            models.Activity.currency.label("activity_currency"),
        )
        .join(models.Task, models.Review.task_id == models.Task.id)
        .join(models.User, models.Review.user_id == models.User.id)
        .join(models.TaskExpertService, models.Task.expert_service_id == models.TaskExpertService.id)
        .outerjoin(models.Activity, models.Task.parent_activity_id == models.Activity.id)
        .where(
            models.Review.user_id.in_(following_ids),
            models.Review.is_anonymous != 1,
            models.Task.created_by_expert == True,
            models.Task.status == "completed",
            models.Task.is_visible == True,
            models.Review.comment.isnot(None),
            models.Review.comment != "",
            models.Review.created_at >= cutoff,
        )
        .order_by(desc(models.Review.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()
    items = []
    for row in rows:
        reviewer_name = row.reviewer_name or "匿名用户"
        reviewer_avatar = row.reviewer_avatar

        activity_info = None
        if row.parent_activity_id and row.task_source == "expert_activity":
            activity_info = {
                "activity_id": row.parent_activity_id,
                "activity_title": row.activity_title,
                "activity_title_zh": getattr(row, "activity_title_zh", None),
                "activity_title_en": getattr(row, "activity_title_en", None),
                "original_price": float(row.original_price_per_participant) if row.original_price_per_participant else None,
                "discounted_price": float(row.discounted_price_per_participant) if row.discounted_price_per_participant else None,
                "discount_percentage": float(row.discount_percentage) if row.discount_percentage else None,
                "currency": row.activity_currency or "GBP",
            }

        service_thumb = _first_image(row.service_images)

        items.append({
            "feed_type": "service_review",
            "id": f"sreview_{row.id}",
            "title": None,
            "title_zh": None,
            "title_en": None,
            "description": row.comment,
            "description_zh": None,
            "description_en": None,
            "images": None,
            "user_id": str(row.user_id),
            "user_name": reviewer_name,
            "user_avatar": reviewer_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": float(row.rating) if row.rating else None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": {
                "item_type": "service",
                "item_id": str(row.expert_service_id),
                "name": row.service_name,
                "subtitle": None,
                "thumbnail": service_thumb,
            },
            "activity_info": activity_info,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_rankings(
    db: AsyncSession, following_ids: List[str], limit: int
) -> list:
    """获取关注用户申请的排行榜（30天内，含 TOP 3）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.CustomLeaderboard.id,
            models.CustomLeaderboard.name,
            getattr(models.CustomLeaderboard, "name_zh", None).label("name_zh"),
            getattr(models.CustomLeaderboard, "name_en", None).label("name_en"),
            models.CustomLeaderboard.description,
            getattr(models.CustomLeaderboard, "description_zh", None).label("description_zh"),
            getattr(models.CustomLeaderboard, "description_en", None).label("description_en"),
            models.CustomLeaderboard.cover_image,
            models.CustomLeaderboard.applicant_id,
            models.CustomLeaderboard.created_at,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.User, models.CustomLeaderboard.applicant_id == models.User.id)
        .where(
            models.CustomLeaderboard.applicant_id.in_(following_ids),
            models.CustomLeaderboard.status == "active",
            models.CustomLeaderboard.created_at >= cutoff,
        )
        .order_by(desc(models.CustomLeaderboard.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    if not rows:
        return []

    # 批量获取 TOP 3
    leaderboard_ids = [row.id for row in rows]
    row_num = func.row_number().over(
        partition_by=models.LeaderboardItem.leaderboard_id,
        order_by=desc(models.LeaderboardItem.net_votes),
    ).label("rn")
    sub = (
        select(
            models.LeaderboardItem.leaderboard_id,
            models.LeaderboardItem.name,
            models.LeaderboardItem.images,
            models.LeaderboardItem.net_votes,
            models.LeaderboardItem.upvotes,
            row_num,
        )
        .where(
            models.LeaderboardItem.leaderboard_id.in_(leaderboard_ids),
            models.LeaderboardItem.status == "approved",
        )
        .subquery()
    )
    top3_result = await db.execute(select(sub).where(sub.c.rn <= 3))
    top3_map: dict[int, list] = {}
    for item in top3_result:
        lb_id = item.leaderboard_id
        if lb_id not in top3_map:
            top3_map[lb_id] = []
        top3_map[lb_id].append({
            "name": item.name,
            "image": _first_image(item.images),
            "rating": float(item.net_votes) if item.net_votes else 0,
            "review_count": item.upvotes or 0,
        })

    items = []
    for row in rows:
        top3 = top3_map.get(row.id, [])
        if not top3:
            continue

        name_zh = getattr(row, "name_zh", None)
        name_en = getattr(row, "name_en", None)
        desc_zh = getattr(row, "description_zh", None)
        desc_en = getattr(row, "description_en", None)
        items.append({
            "feed_type": "ranking",
            "id": f"ranking_{row.id}",
            "title": row.name,
            "title_zh": name_zh,
            "title_en": name_en,
            "description": (row.description or "")[:80],
            "description_zh": (desc_zh or "")[:80] if desc_zh else None,
            "description_en": (desc_en or "")[:80] if desc_en else None,
            "images": [row.cover_image] if row.cover_image else None,
            "user_id": str(row.applicant_id) if row.applicant_id else None,
            "user_name": row.user_name,
            "user_avatar": row.user_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {"top3": top3},
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items

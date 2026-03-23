"""
关注 Feed 路由
展示来自已关注用户的内容时间线（Timeline）
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select, desc, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_current_user_secure_async_csrf, get_async_db_dependency
from app.discovery_routes import _first_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/follow", tags=["关注"])


# ==================== 主接口 ====================


@router.get("/feed")
async def get_follow_feed(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=50, description="每页数量"),
    request: Request = None,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取关注用户的内容时间线

    按发布时间倒序排列，展示所有已关注用户的最新内容。
    包含：任务、论坛帖子、跳蚤市场商品、达人服务、任务完成记录。
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

    all_items: List[dict] = []

    fetch_tasks = [
        ("followed tasks", lambda: _fetch_followed_tasks(db, following_ids, fetch_limit)),
        ("followed forum posts", lambda: _fetch_followed_forum_posts(db, following_ids, fetch_limit)),
        ("followed flea market", lambda: _fetch_followed_flea_market(db, following_ids, fetch_limit)),
        ("followed services", lambda: _fetch_followed_services(db, following_ids, fetch_limit)),
        ("followed completions", lambda: _fetch_followed_completions(db, following_ids, fetch_limit)),
    ]

    for name, fetch_fn in fetch_tasks:
        try:
            async with db.begin_nested():
                result_items = await fetch_fn()
                all_items.extend(result_items)
        except Exception as e:
            logger.warning(f"Failed to fetch {name} for follow feed: {e}")

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
        "has_more": len(page_items) == page_size,
    }


# ==================== 数据获取函数 ====================


async def _fetch_followed_tasks(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的任务（30天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

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
        )
        .join(models.User, models.Task.poster_id == models.User.id)
        .where(
            models.Task.poster_id.in_(following_ids),
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
        post_images = _first_image(row.images)
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
            "images": [post_images] if post_images else None,
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
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=30)

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.description,
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.expert_id,
            models.TaskExpertService.user_id,
            models.TaskExpertService.created_at,
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(
            models.User,
            or_(
                models.TaskExpertService.expert_id == models.User.id,
                models.TaskExpertService.user_id == models.User.id,
            ),
        )
        .where(
            or_(
                models.TaskExpertService.expert_id.in_(following_ids),
                models.TaskExpertService.user_id.in_(following_ids),
            ),
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
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_followed_completions(db: AsyncSession, following_ids: List[str], limit: int) -> list:
    """获取关注用户的任务完成记录（7天内）"""
    from app.utils.time_utils import get_utc_time

    cutoff = get_utc_time() - timedelta(days=7)

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

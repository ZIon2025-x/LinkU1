"""
Discovery Feed 路由
聚合多种内容类型（帖子、商品、竞品评论、达人服务评价、排行榜、达人服务）
为首页"发现更多"瀑布流提供统一数据源
"""

import random
import logging
import json
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select, func, or_, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.forum_routes import get_current_user_optional, visible_forums

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/discovery", tags=["发现"])


# ==================== Feed 聚合接口 ====================

@router.get("/feed")
async def get_discovery_feed(
    page: int = Query(1, ge=1, description="页码"),
    limit: int = Query(20, ge=1, le=50, description="每页数量"),
    request: Request = None,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取发现 Feed — 混排多种内容类型
    
    加权随机策略：低频类型（评价、排行榜）权重更高，确保曝光
    同一类型不连续出现超过 2 条
    
    帖子仅展示当前用户可见板块下的（普通板块 + 已认证学校板块）
    """
    # 每种类型获取的数量（多取一些用于混排）
    fetch_limit = limit * 2
    
    # 计算当前用户可见的板块 ID（普通板块 + 学校板块）
    # 与论坛列表的权限逻辑一致
    general_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == "general",
            models.ForumCategory.is_visible == True,
        )
    )
    visible_category_ids = [row[0] for row in general_result.all()]
    
    # 已登录用户额外获取学校板块
    if current_user:
        school_ids = await visible_forums(current_user, db)
        visible_category_ids.extend(school_ids)
    
    all_items = []
    
    # 1. 帖子（仅可见板块）
    try:
        posts = await _fetch_forum_posts(db, fetch_limit, visible_category_ids)
        all_items.extend(posts)
    except Exception as e:
        logger.warning(f"Failed to fetch forum posts for feed: {e}")
    
    # 2. 跳蚤市场商品
    try:
        products = await _fetch_flea_market_items(db, fetch_limit)
        all_items.extend(products)
    except Exception as e:
        logger.warning(f"Failed to fetch flea market items for feed: {e}")
    
    # 3. 竞品评论（来自排行榜投票留言）
    try:
        competitor_reviews = await _fetch_competitor_reviews(db, fetch_limit)
        all_items.extend(competitor_reviews)
    except Exception as e:
        logger.warning(f"Failed to fetch competitor reviews for feed: {e}")
    
    # 4. 达人服务评价
    try:
        service_reviews = await _fetch_service_reviews(db, fetch_limit)
        all_items.extend(service_reviews)
    except Exception as e:
        logger.warning(f"Failed to fetch service reviews for feed: {e}")
    
    # 5. 排行榜
    try:
        rankings = await _fetch_rankings(db, fetch_limit)
        all_items.extend(rankings)
    except Exception as e:
        logger.warning(f"Failed to fetch rankings for feed: {e}")
    
    # 6. 达人服务
    try:
        services = await _fetch_expert_services(db, fetch_limit)
        all_items.extend(services)
    except Exception as e:
        logger.warning(f"Failed to fetch expert services for feed: {e}")
    
    # 加权随机混排
    feed_items = _weighted_shuffle(all_items, limit, page)
    
    return {
        "items": feed_items,
        "page": page,
        "has_more": len(all_items) > page * limit,
    }


# ==================== 辅助：解析 images JSONB ====================

def _parse_images(images_value) -> list:
    """安全解析 images 字段（可能是 JSON 字符串、list 或 None）"""
    if images_value is None:
        return []
    if isinstance(images_value, list):
        return images_value
    if isinstance(images_value, str):
        try:
            parsed = json.loads(images_value)
            if isinstance(parsed, list):
                return parsed
        except (json.JSONDecodeError, TypeError):
            pass
    return []


def _first_image(images_value) -> Optional[str]:
    """获取第一张图片"""
    imgs = _parse_images(images_value)
    return imgs[0] if imgs else None


# ==================== 数据获取函数 ====================

async def _fetch_forum_posts(db: AsyncSession, limit: int, visible_category_ids: List[int] = None) -> list:
    """获取最新帖子（仅用户可见板块：普通板块 + 已认证学校板块）"""
    query = (
        select(
            models.ForumPost.id,
            models.ForumPost.title,
            getattr(models.ForumPost, "title_zh", None).label("title_zh"),
            getattr(models.ForumPost, "title_en", None).label("title_en"),
            models.ForumPost.content,
            getattr(models.ForumPost, "content_zh", None).label("content_zh"),
            getattr(models.ForumPost, "content_en", None).label("content_en"),
            models.ForumPost.images,
            models.ForumPost.linked_item_type,
            models.ForumPost.linked_item_id,
            models.ForumPost.like_count,
            models.ForumPost.reply_count,
            models.ForumPost.view_count,
            models.ForumPost.created_at,
            models.ForumPost.author_id,
            models.User.name.label("author_name"),
            models.User.avatar.label("author_avatar"),
            models.ForumCategory.name.label("category_name"),
            getattr(models.ForumCategory, "name_zh", None).label("category_name_zh"),
            getattr(models.ForumCategory, "name_en", None).label("category_name_en"),
        )
        .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
        .outerjoin(models.User, models.ForumPost.author_id == models.User.id)
        .where(
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
            models.ForumCategory.is_visible == True,
        )
    )
    # 按可见板块 ID 过滤（普通板块 + 当前用户的学校板块）
    if visible_category_ids:
        query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
    else:
        # 兜底：无可见板块时只返回普通板块
        query = query.where(models.ForumCategory.type == "general")
    
    query = query.order_by(desc(models.ForumPost.created_at)).limit(limit)
    result = await db.execute(query)
    items = []
    for row in result:
        content_preview = (row.content or "")[:100]
        title_zh = getattr(row, "title_zh", None)
        title_en = getattr(row, "title_en", None)
        content_zh_raw = getattr(row, "content_zh", None)
        content_en_raw = getattr(row, "content_en", None)
        description_zh = (content_zh_raw.strip()[:100] or None) if content_zh_raw else None
        description_en = (content_en_raw.strip()[:100] or None) if content_en_raw else None

        linked_item = None
        if row.linked_item_type and row.linked_item_id:
            linked_item = await _resolve_linked_item(db, row.linked_item_type, row.linked_item_id)

        post_images = _parse_images(row.images)
        extra = {}
        if row.category_name:
            extra["category_name"] = row.category_name
        if getattr(row, "category_name_zh", None):
            extra["category_name_zh"] = row.category_name_zh
        if getattr(row, "category_name_en", None):
            extra["category_name_en"] = row.category_name_en

        items.append({
            "feed_type": "forum_post",
            "id": f"post_{row.id}",
            "title": row.title,
            "title_zh": title_zh,
            "title_en": title_en,
            "description": content_preview,
            "description_zh": description_zh,
            "description_en": description_en,
            "images": post_images if post_images else None,
            "user_id": str(row.author_id) if row.author_id else None,
            "user_name": row.author_name or "匿名用户",
            "user_avatar": row.author_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": row.like_count,
            "comment_count": row.reply_count,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": linked_item,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "extra_data": extra if extra else None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_flea_market_items(db: AsyncSession, limit: int) -> list:
    """获取跳蚤市场商品
    注意: FleaMarketItem 没有 favorite_count 和 is_deleted 列
    - 收藏数通过子查询获取
    - 删除状态通过 status != 'deleted' 过滤
    """
    # 子查询计算收藏数
    fav_count = (
        select(func.count(models.FleaMarketFavorite.id))
        .where(models.FleaMarketFavorite.item_id == models.FleaMarketItem.id)
        .correlate(models.FleaMarketItem)
        .scalar_subquery()
        .label("fav_count")
    )
    
    query = (
        select(
            models.FleaMarketItem.id,
            models.FleaMarketItem.title,
            models.FleaMarketItem.description,
            models.FleaMarketItem.price,
            models.FleaMarketItem.currency,
            models.FleaMarketItem.images,
            models.FleaMarketItem.view_count,
            models.FleaMarketItem.created_at,
            fav_count,
        )
        .where(
            models.FleaMarketItem.status == "active",
        )
        .order_by(desc(models.FleaMarketItem.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        first_img = _first_image(row.images)
        items.append({
            "feed_type": "product",
            "id": f"product_{row.id}",
            "title": row.title,
            "description": (row.description or "")[:80],
            "images": [first_img] if first_img else None,
            "user_name": None,
            "user_avatar": None,
            "price": float(row.price) if row.price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": row.currency or "GBP",
            "rating": None,
            "like_count": row.fav_count or 0,
            "comment_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_competitor_reviews(db: AsyncSession, limit: int) -> list:
    """获取竞品评论（来自排行榜投票留言）
    注意: 实际模型是 LeaderboardVote（不是 LeaderboardReview）
    - vote_type 可以是 upvote/downvote
    - comment 是投票留言
    - 没有 rating/upvotes/downvotes 字段；用 like_count 代替
    - LeaderboardItem.images 是 Text(JSON)，不是 image_url
    """
    query = (
        select(
            models.LeaderboardVote.id.label("vote_id"),
            models.LeaderboardVote.user_id,
            models.LeaderboardVote.vote_type,
            models.LeaderboardVote.comment,
            models.LeaderboardVote.like_count,
            models.LeaderboardVote.created_at,
            models.LeaderboardVote.is_anonymous,
            models.LeaderboardVote.item_id.label("vote_item_id"),
            models.User.name.label("reviewer_name"),
            models.User.avatar.label("reviewer_avatar"),
            models.LeaderboardItem.id.label("leaderboard_item_id"),
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
            models.LeaderboardVote.comment.isnot(None),
            models.LeaderboardVote.comment != "",
            models.LeaderboardItem.status == "approved",
            models.CustomLeaderboard.status == "active",
        )
        .order_by(desc(models.LeaderboardVote.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        reviewer_name = "匿名用户" if row.is_anonymous else (row.reviewer_name or "匿名用户")
        reviewer_avatar = None if row.is_anonymous else row.reviewer_avatar
        
        item_thumb = _first_image(row.item_images)
        
        items.append({
            "feed_type": "competitor_review",
            "id": f"creview_{row.vote_id}",
            "title": None,
            "description": row.comment,
            "images": None,
            "user_id": None if row.is_anonymous else str(row.user_id),
            "user_name": reviewer_name,
            "user_avatar": reviewer_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": row.like_count or 0,
            "comment_count": None,
            "upvote_count": row.item_upvotes or 0,
            "downvote_count": row.item_downvotes or 0,
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
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_service_reviews(db: AsyncSession, limit: int) -> list:
    """获取达人服务评价（含活动信息）
    注意:
    - Task 用 poster_id / taker_id 而非 created_by / assigned_to
    - TaskExpertService 用 service_name 而非 name，images 而非 cover_image
    - Activity 没有 cover_image，用 images (JSONB)
    """
    query = (
        select(
            models.Review.id,
            models.Review.rating,
            models.Review.comment,
            models.Review.is_anonymous,
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
            models.Task.created_by_expert == True,
            models.Task.status == "completed",
            models.Review.comment.isnot(None),
            models.Review.comment != "",
        )
        .order_by(desc(models.Review.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        is_anon = row.is_anonymous == 1
        reviewer_name = "匿名用户" if is_anon else (row.reviewer_name or "匿名用户")
        reviewer_avatar = None if is_anon else row.reviewer_avatar
        
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
            "description": row.comment,
            "images": None,
            "user_id": None if is_anon else str(row.user_id),
            "user_name": reviewer_name,
            "user_avatar": reviewer_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": float(row.rating) if row.rating else None,
            "like_count": None,
            "comment_count": None,
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
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_rankings(db: AsyncSession, limit: int) -> list:
    """获取热门排行榜（含 TOP 3）
    注意:
    - CustomLeaderboard 没有 is_deleted，用 status == 'active' 过滤
    - LeaderboardItem 没有 image_url/average_rating/review_count/is_deleted
    - 用 net_votes 排序替代 average_rating
    - 用 LeaderboardItem.images 替代 image_url
    - 用 status == 'approved' 过滤替代 is_deleted == False
    """
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
            models.CustomLeaderboard.created_at,
        )
        .where(models.CustomLeaderboard.status == "active")
        .order_by(desc(models.CustomLeaderboard.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        # 获取 TOP 3（按 net_votes 排序）
        top3_query = (
            select(
                models.LeaderboardItem.name,
                models.LeaderboardItem.images,
                models.LeaderboardItem.net_votes,
                models.LeaderboardItem.upvotes,
            )
            .where(
                models.LeaderboardItem.leaderboard_id == row.id,
                models.LeaderboardItem.status == "approved",
            )
            .order_by(desc(models.LeaderboardItem.net_votes))
            .limit(3)
        )
        top3_result = await db.execute(top3_query)
        top3 = [
            {
                "name": item.name,
                "image": _first_image(item.images),
                "rating": float(item.net_votes) if item.net_votes else 0,
                "review_count": item.upvotes or 0,
            }
            for item in top3_result
        ]
        
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
            "user_name": None,
            "user_avatar": None,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "extra_data": {"top3": top3},
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_expert_services(db: AsyncSession, limit: int) -> list:
    """获取达人服务推荐
    注意:
    - TaskExpertService 用 service_name 而非 name
    - TaskExpertService 用 images (JSONB) 而非 cover_image
    - TaskExpertService 用 status == 'active' 而非 is_active == True
    - TaskExpert 用 rating 而非 average_rating
    """
    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.description,
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.created_at,
            models.TaskExpert.id.label("expert_user_id"),
            models.TaskExpert.expert_name.label("expert_display_name"),
            models.TaskExpert.avatar.label("expert_avatar_url"),
            models.TaskExpert.rating.label("expert_rating"),
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar_url"),
        )
        .join(models.TaskExpert, models.TaskExpertService.expert_id == models.TaskExpert.id)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(models.TaskExpertService.status == "active")
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        service_thumb = _first_image(row.service_images)
        # 达人展示名和头像：优先用 TaskExpert 的，否则用 User 的
        expert_name = row.expert_display_name or row.user_name
        expert_avatar = row.expert_avatar_url or row.user_avatar_url

        expert_id_val = str(row.expert_user_id) if row.expert_user_id else None
        items.append({
            "feed_type": "service",
            "id": f"service_{row.id}",
            "title": row.service_name,
            "description": (row.description or "")[:80],
            "images": [service_thumb] if service_thumb else None,
            "user_id": expert_id_val,
            "user_name": expert_name,
            "user_avatar": expert_avatar,
            "expert_id": expert_id_val,
            "price": float(row.base_price) if row.base_price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": row.currency or "GBP",
            "rating": float(row.expert_rating) if row.expert_rating else None,
            "like_count": None,
            "comment_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


# ==================== 辅助函数 ====================

async def _resolve_linked_item(db: AsyncSession, item_type: str, item_id: str) -> Optional[dict]:
    """解析帖子关联的内容，返回简要信息"""
    try:
        if item_type == "service":
            result = await db.execute(
                select(models.TaskExpertService.service_name, models.TaskExpertService.images)
                .where(models.TaskExpertService.id == int(item_id))
            )
            row = result.first()
            if row:
                return {"item_type": "service", "item_id": item_id, "name": row.service_name, "thumbnail": _first_image(row.images)}
        
        elif item_type == "product":
            result = await db.execute(
                select(models.FleaMarketItem.title, models.FleaMarketItem.images)
                .where(models.FleaMarketItem.id == item_id)
            )
            row = result.first()
            if row:
                return {"item_type": "product", "item_id": item_id, "name": row.title, "thumbnail": _first_image(row.images)}
        
        elif item_type == "activity":
            result = await db.execute(
                select(models.Activity.title, models.Activity.images)
                .where(models.Activity.id == int(item_id))
            )
            row = result.first()
            if row:
                return {"item_type": "activity", "item_id": item_id, "name": row.title, "thumbnail": _first_image(row.images)}
        
        elif item_type == "ranking":
            result = await db.execute(
                select(models.CustomLeaderboard.name, models.CustomLeaderboard.cover_image)
                .where(models.CustomLeaderboard.id == int(item_id))
            )
            row = result.first()
            if row:
                return {"item_type": "ranking", "item_id": item_id, "name": row.name, "thumbnail": row.cover_image}
        
        elif item_type == "forum_post":
            result = await db.execute(
                select(models.ForumPost.title)
                .where(models.ForumPost.id == int(item_id))
            )
            row = result.first()
            if row:
                return {"item_type": "forum_post", "item_id": item_id, "name": row.title, "thumbnail": None}
    
    except Exception as e:
        logger.warning(f"Failed to resolve linked item {item_type}/{item_id}: {e}")
    
    return None


def _weighted_shuffle(items: list, limit: int, page: int) -> list:
    """加权随机混排
    
    - 低频类型（service_review, competitor_review, ranking）权重更高
    - 高频类型（forum_post, product）权重较低
    - 同一类型不连续出现超过 2 条
    """
    if not items:
        return []
    
    type_weights = {
        "forum_post": 1.0,
        "product": 1.0,
        "competitor_review": 3.0,
        "service_review": 3.0,
        "ranking": 2.5,
        "service": 1.5,
    }
    
    by_type = {}
    for item in items:
        ft = item["feed_type"]
        if ft not in by_type:
            by_type[ft] = []
        by_type[ft].append(item)
    
    for ft in by_type:
        by_type[ft].sort(key=lambda x: x.get("created_at") or "", reverse=True)
    
    result = []
    consecutive_count = {}
    last_type = None
    
    total_needed = limit * page
    max_iterations = total_needed * 3
    iterations = 0
    
    while len(result) < total_needed and by_type and iterations < max_iterations:
        iterations += 1
        
        available = {}
        for ft, items_list in by_type.items():
            if not items_list:
                continue
            if last_type == ft and consecutive_count.get(ft, 0) >= 2:
                continue
            available[ft] = items_list
        
        if not available:
            consecutive_count = {}
            last_type = None
            continue
        
        types = list(available.keys())
        weights = [type_weights.get(t, 1.0) for t in types]
        total_weight = sum(weights)
        rand = random.random() * total_weight
        cumulative = 0
        chosen_type = types[0]
        for t, w in zip(types, weights):
            cumulative += w
            if rand <= cumulative:
                chosen_type = t
                break
        
        item = available[chosen_type].pop(0)
        result.append(item)
        
        if chosen_type == last_type:
            consecutive_count[chosen_type] = consecutive_count.get(chosen_type, 0) + 1
        else:
            consecutive_count = {chosen_type: 1}
            last_type = chosen_type
        
        if not by_type[chosen_type]:
            del by_type[chosen_type]
    
    start = (page - 1) * limit
    return result[start:start + limit]

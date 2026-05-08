"""
Discovery Feed 路由
聚合多种内容类型（帖子、商品、竞品评论、达人服务评价、排行榜、达人服务）
为首页"发现更多"瀑布流提供统一数据源
"""

import random
import logging
import json
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select, func, or_, and_, desc
from sqlalchemy.orm import aliased
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.forum_routes import get_current_user_optional, visible_forums
from app.cache import cache_response
from app.utils.feed_scoring import (
    compute_score,
    compute_score_with_prefs,
    compute_task_score,
    get_city_variants,
    load_user_personalization_context,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/discovery", tags=["发现"])


# ==================== Feed 聚合接口 ====================

@router.get("/feed")
@cache_response(ttl=120, key_prefix="discovery")
async def get_discovery_feed(
    page: int = Query(1, ge=1, description="页码"),
    limit: int = Query(20, ge=1, le=50, description="每页数量"),
    seed: Optional[int] = Query(None, description="随机种子，保证分页结果一致；首次请求不传则自动生成"),
    latitude: Optional[float] = Query(None, ge=-90, le=90, description="用户当前纬度（GPS）"),
    longitude: Optional[float] = Query(None, ge=-180, le=180, description="用户当前经度（GPS）"),
    city: Optional[str] = Query(None, max_length=100, description="用户当前城市名（GPS反向编码），用于同城内容加权"),
    request: Request = None,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取发现 Feed — 混排多种内容类型

    加权随机策略：低频类型（评价、排行榜）权重更高，确保曝光
    同一类型不连续出现超过 2 条

    帖子仅展示当前用户可见板块下的（普通板块 + 已认证学校板块）

    seed: 客户端首次加载不传，后端自动生成并返回；翻页时传回相同 seed 保证排序一致
    """
    # 每种类型获取的数量（多取一些用于混排）
    fetch_limit = limit * 2
    
    # 计算当前用户可见的板块 ID（普通板块 + 技能板块 + 学校板块）
    # 与论坛列表的权限逻辑一致；达人板块 (type='expert') 走专属入口，不进入发现 Feed
    general_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type.in_(("general", "skill")),
            models.ForumCategory.is_visible == True,
        )
    )
    visible_category_ids = [row[0] for row in general_result.all()]
    
    # 已登录用户额外获取学校板块
    if current_user:
        school_ids = await visible_forums(current_user, db)
        visible_category_ids.extend(school_ids)
    
    all_items = []

    # 推荐引擎独立 session（asyncio.wait_for 超时取消时 greenlet 可能仍在用 connection，隔离避免污染主 session）
    recommendation_scores = None
    user_lat = latitude
    user_lng = longitude
    if current_user:
        user_location = None
        if user_lat is None and getattr(current_user, "residence_city", None):
            user_location = current_user.residence_city
        try:
            import asyncio
            from app.database import AsyncSessionLocal
            async with AsyncSessionLocal() as rec_session:
                recommendation_scores = await asyncio.wait_for(
                    rec_session.run_sync(lambda session: _get_recommendation_scores_sync(
                        session, current_user.id,
                        latitude=user_lat, longitude=user_lng,
                        location=user_location,
                    )),
                    timeout=0.5,
                )
        except Exception as e:
            logger.warning(f"Recommendation engine unavailable: {e}")

    # 用户偏好 / 城市 / 历史兴趣（共享 helper）
    personalization = await load_user_personalization_context(db, current_user, explicit_city=city)
    user_preferred_categories = personalization["user_prefs"]
    user_city = personalization["user_city"]
    user_interest_types = personalization["user_interest_types"]

    # 每个 fetch 用 SAVEPOINT 隔离，单个类型失败不影响其他类型
    fetch_tasks = [
        ("forum posts", lambda: _fetch_forum_posts(db, fetch_limit, visible_category_ids, current_user=current_user)),
        ("flea market items", lambda: _fetch_flea_market_items(db, fetch_limit, current_user=current_user)),
        ("competitor reviews", lambda: _fetch_competitor_reviews(db, fetch_limit, current_user=current_user)),
        ("service reviews", lambda: _fetch_service_reviews(db, fetch_limit, current_user=current_user)),
        ("experts", lambda: _fetch_experts(db, fetch_limit)),
        ("expert services", lambda: _fetch_expert_services(db, fetch_limit)),
        ("tasks", lambda: _fetch_tasks(db, fetch_limit, current_user, recommendation_scores)),
        ("activities", lambda: _fetch_activities(db, fetch_limit, current_user)),
    ]

    for name, fetch_fn in fetch_tasks:
        try:
            async with db.begin_nested():
                result_items = await fetch_fn()
                all_items.extend(result_items)
        except Exception as e:
            logger.warning(f"Failed to fetch {name} for feed: {e}")
    
    # 首次请求自动生成 seed，翻页时复用保证排序一致
    if seed is None:
        seed = random.randint(0, 2**31 - 1)

    # 加权随机混排（确定性 seed）
    feed_items = _weighted_shuffle(all_items, limit, page, seed=seed,
                                    user_preferred_categories=user_preferred_categories,
                                    user_city=user_city,
                                    user_interest_types=user_interest_types)

    # has_more: 返回的条数 == limit 说明可能还有更多；
    # 不足 limit 说明数据已经耗尽
    return {
        "items": feed_items,
        "page": page,
        "has_more": len(feed_items) == limit,
        "seed": seed,
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

async def _fetch_forum_posts(db: AsyncSession, limit: int, visible_category_ids: List[int] = None, current_user=None) -> list:
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
            models.ForumPost.admin_author_id,
            models.User.name.label("author_name"),
            models.User.avatar.label("author_avatar"),
            models.ForumCategory.name.label("category_name"),
            getattr(models.ForumCategory, "name_zh", None).label("category_name_zh"),
            getattr(models.ForumCategory, "name_en", None).label("category_name_en"),
            models.ForumCategory.icon.label("category_icon"),
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
    rows_list = result.all()

    # 批量查询当前用户的帖子点赞状态
    user_liked_post_ids = set()
    if current_user and rows_list:
        post_ids = [row.id for row in rows_list]
        user_like_result = await db.execute(
            select(models.ForumLike.target_id).where(
                models.ForumLike.user_id == current_user.id,
                models.ForumLike.target_type == "post",
                models.ForumLike.target_id.in_(post_ids),
            )
        )
        user_liked_post_ids = {row[0] for row in user_like_result.all()}

    # 批量解析 linked items，避免 N+1 查询
    linked_pairs = [
        (row.linked_item_type, row.linked_item_id)
        for row in rows_list
        if row.linked_item_type and row.linked_item_id
    ]
    linked_items_map = await _batch_resolve_linked_items(db, linked_pairs) if linked_pairs else {}

    items = []
    for row in rows_list:
        content_preview = (row.content or "")[:100]
        title_zh = getattr(row, "title_zh", None)
        title_en = getattr(row, "title_en", None)
        content_zh_raw = getattr(row, "content_zh", None)
        content_en_raw = getattr(row, "content_en", None)
        description_zh = (content_zh_raw.strip()[:100] or None) if content_zh_raw else None
        description_en = (content_en_raw.strip()[:100] or None) if content_en_raw else None

        linked_item = None
        if row.linked_item_type and row.linked_item_id:
            linked_item = linked_items_map.get((row.linked_item_type, str(row.linked_item_id)))

        post_images = _parse_images(row.images)
        extra = {}
        if row.category_name:
            extra["category_name"] = row.category_name
        if getattr(row, "category_name_zh", None):
            extra["category_name_zh"] = row.category_name_zh
        if getattr(row, "category_name_en", None):
            extra["category_name_en"] = row.category_name_en
        if getattr(row, "category_icon", None):
            extra["category_icon"] = row.category_icon

        # 管理员发帖：统一显示为官方账号
        if row.admin_author_id:
            display_user_id = row.admin_author_id
            display_user_name = "Link²Ur"
            display_user_avatar = "/static/logo.png"
        else:
            display_user_id = str(row.author_id) if row.author_id else None
            display_user_name = row.author_name or "匿名用户"
            display_user_avatar = row.author_avatar

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
            "user_id": display_user_id,
            "user_name": display_user_name,
            "user_avatar": display_user_avatar,
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
            "linked_item": linked_item,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": row.id in user_liked_post_ids if current_user else None,
            "user_vote_type": None,
            "extra_data": extra if extra else None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_flea_market_items(db: AsyncSession, limit: int, current_user=None) -> list:
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
            models.FleaMarketItem.is_visible == True,
        )
        .order_by(desc(models.FleaMarketItem.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows_list = result.all()

    # 预取当前用户的收藏状态
    user_favorited_ids = set()
    if current_user and rows_list:
        product_ids = [row.id for row in rows_list]
        user_fav_result = await db.execute(
            select(models.FleaMarketFavorite.item_id).where(
                models.FleaMarketFavorite.user_id == current_user.id,
                models.FleaMarketFavorite.item_id.in_(product_ids)
            )
        )
        user_favorited_ids = {row[0] for row in user_fav_result.all()}

    items = []
    for row in rows_list:
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
            "view_count": row.view_count or 0,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": row.id in user_favorited_ids,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_competitor_reviews(db: AsyncSession, limit: int, current_user=None) -> list:
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
    rows_list = result.all()

    # 批量查询当前用户对这些排行榜条目的投票状态
    user_vote_map = {}  # item_id -> vote_type
    if current_user and rows_list:
        item_ids = list({row.vote_item_id for row in rows_list})
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
    for row in rows_list:
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


async def _fetch_service_reviews(db: AsyncSession, limit: int, current_user=None) -> list:
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
            # P0 #16: 移除 created_by_expert==True 硬过滤 — 个人服务 review 也要进 feed。
            # expert_service_id 已经隐含"基于服务"的语义 (上面 join TaskExpertService)。
            models.Task.status == "completed",
            models.Task.is_visible == True,
            models.Review.comment.isnot(None),
            models.Review.comment != "",
            models.Review.is_deleted.is_(False),  # 顺手过滤软删 review
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
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_experts(db: AsyncSession, limit: int) -> list:
    """获取推荐达人团队（首页发现 Feed 卡片）

    卡片元数据：封面图 cover_image、团队头像、名字、分类、位置、评分、完单数、
    featured_skills、徽章（精选/认证/官方）、营业状态。封面为空时前端按 category 渐变兜底。

    排序由 compute_score_with_prefs 统一处理（同城 × 类别匹配 × 兴趣匹配），
    这里只负责拉取候选集，多取一些让 shuffle 有得挑。
    """
    from app.models_expert import Expert, FeaturedExpertV2
    from app.expert_routes import _compute_is_open_batch

    query = (
        select(Expert, FeaturedExpertV2.is_featured.label("is_featured"))
        .outerjoin(FeaturedExpertV2, FeaturedExpertV2.expert_id == Expert.id)
        .where(Expert.status == "active")
        .order_by(
            # 精选置顶，其次按评分和完单量
            desc(FeaturedExpertV2.is_featured.is_(True)),
            desc(Expert.rating),
            desc(Expert.completed_tasks),
        )
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()
    experts = [row.Expert for row in rows]

    # 批量计算 is_open (business_hours + today's closed_dates)
    is_open_map = await _compute_is_open_batch(db, experts)

    items = []
    for row in rows:
        e = row.Expert
        cover = e.cover_image
        images = [cover] if cover else None

        bio = (e.bio or "")[:100]
        bio_zh = (e.bio_zh or "")[:100] if e.bio_zh else None
        bio_en = (e.bio_en or "")[:100] if e.bio_en else None

        extra = {
            "category": e.category,
            "location": e.location,
            "latitude": float(e.latitude) if e.latitude is not None else None,
            "longitude": float(e.longitude) if e.longitude is not None else None,
            "completed_tasks": int(e.completed_tasks or 0),
            "featured_skills": e.featured_skills or [],
            "featured_skills_en": e.featured_skills_en or [],
            "is_official": bool(e.is_official),
            "official_badge": e.official_badge,
            "is_verified": bool(e.is_verified),
            "is_featured": bool(row.is_featured),
            "user_level": e.user_level,
            "is_open": is_open_map.get(e.id),  # None = 未设置营业时间
            # 默认兜底 reason：精选会覆盖兜底，个性化信号（同城/匹配类别）在 shuffle 阶段再覆盖
            "reason_code": "featured" if row.is_featured else None,
        }

        items.append({
            "feed_type": "expert",
            "id": f"expert_{e.id}",
            "title": e.name,
            "title_zh": e.name_zh,
            "title_en": e.name_en,
            "description": bio,
            "description_zh": bio_zh,
            "description_en": bio_en,
            "images": images,
            "user_id": None,
            "user_name": e.name,
            "user_avatar": e.avatar,
            "expert_id": e.id,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": float(e.rating) if e.rating is not None else None,
            "like_count": None,
            "comment_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": extra,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        })
    return items


async def _fetch_expert_services(db: AsyncSession, limit: int) -> list:
    """获取达人服务 + 个人服务推荐
    注意:
    - TaskExpertService 用 service_name 而非 name
    - TaskExpertService 用 images (JSONB) 而非 cover_image
    - TaskExpertService 用 status == 'active' 而非 is_active == True
    - Expert 用 rating 而非 average_rating
    - service_type='expert' 通过 owner_type='expert' + owner_id JOIN Expert (团队)
    - service_type='personal' 通过 user_id 直接 JOIN User (无 Expert)
    - 返回 JSON key expert_id/user_id 对 expert 服务现填 team_id (Phase A 语义迁移,
      修复现有 /api/experts/{id} 404 bug; 详见 spec §7.5)
    """
    from app.models_expert import Expert

    # 给个人服务 owner 用户起别名，避免与达人团队可能的 User JOIN 冲突（本实现无此 JOIN,保留别名兼容原结构)
    PersonalOwner = aliased(models.User, name="personal_owner")

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_type,
            models.TaskExpertService.service_name,
            models.TaskExpertService.service_name_en,
            models.TaskExpertService.service_name_zh,
            models.TaskExpertService.description,
            models.TaskExpertService.description_en,
            models.TaskExpertService.description_zh,
            models.TaskExpertService.category,
            models.TaskExpertService.location.label("service_location"),
            models.TaskExpertService.images.label("service_images"),
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.user_id.label("personal_owner_id"),
            models.TaskExpertService.created_at,
            Expert.id.label("expert_team_id"),
            Expert.name.label("expert_display_name"),
            Expert.avatar.label("expert_avatar_url"),
            Expert.rating.label("expert_rating"),
            PersonalOwner.name.label("personal_owner_name"),
            PersonalOwner.avatar.label("personal_owner_avatar"),
            PersonalOwner.avg_rating.label("personal_owner_rating"),
        )
        .outerjoin(
            Expert,
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == Expert.id,
            ),
        )
        .outerjoin(PersonalOwner, models.TaskExpertService.user_id == PersonalOwner.id)
        .where(models.TaskExpertService.status == "active")
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    items = []
    for row in result:
        service_thumb = _first_image(row.service_images)
        is_personal = row.service_type == "personal"

        if is_personal:
            display_name = row.personal_owner_name
            display_avatar = row.personal_owner_avatar
            owner_id = str(row.personal_owner_id) if row.personal_owner_id else None
            expert_id_val = None
        else:
            # Expert 服务: team_id 作为 expert_id / user_id JSON 值 (spec §7.5)
            display_name = row.expert_display_name
            display_avatar = row.expert_avatar_url
            owner_id = str(row.expert_team_id) if row.expert_team_id else None
            expert_id_val = owner_id

        items.append({
            "feed_type": "service",
            "id": f"service_{row.id}",
            "title": row.service_name,
            "title_en": row.service_name_en,
            "title_zh": row.service_name_zh,
            "description": (row.description or "")[:80],
            "description_en": (row.description_en or "")[:80] if row.description_en else None,
            "description_zh": (row.description_zh or "")[:80] if row.description_zh else None,
            "images": [service_thumb] if service_thumb else None,
            "user_id": owner_id,
            "user_name": display_name,
            "user_avatar": display_avatar,
            "expert_id": expert_id_val,
            "price": float(row.base_price) if row.base_price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": row.currency or "GBP",
            # P1 D.P1.2: 个人服务 fallback 到 owner.avg_rating, 否则永远 None。
            "rating": (
                float(row.personal_owner_rating) if (is_personal and row.personal_owner_rating)
                else float(row.expert_rating) if row.expert_rating
                else None
            ),
            "like_count": None,
            "comment_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "category": row.category,
                "location": row.service_location,
            } if (row.category or row.service_location) else None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


def _get_recommendation_scores_sync(
    session, user_id: str,
    latitude: float = None, longitude: float = None,
    location: str = None,
) -> dict:
    """Get recommendation scores (SYNC — called via db.run_sync).
    Returns {task_id: (score, reason)} or empty dict.
    """
    try:
        from app.task_recommendation import get_task_recommendations
        recs = get_task_recommendations(
            db=session,
            user_id=user_id,
            limit=50,
            latitude=latitude,
            longitude=longitude,
            location=location,
        )
        return {
            r["task_id"]: (r.get("score", 0), "；".join(r.get("reasons", [])))
            for r in recs
            if "task_id" in r
        }
    except Exception as e:
        logger.debug(f"Failed to get recommendation scores: {e}")
        return {}


async def _fetch_tasks(
    db: AsyncSession, limit: int, current_user=None, recommendation_scores: dict = None
) -> list:
    """获取开放任务 for discovery feed."""
    from app.utils.time_utils import get_utc_time

    now = get_utc_time()

    # Subquery for application count (TaskApplication has no counter on Task)
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
            models.Task.agreed_reward,
            models.Task.reward_to_be_quoted,
            models.Task.location,
            models.Task.deadline,
            models.Task.task_level,
            models.Task.view_count,
            models.Task.poster_id,
            models.Task.created_at,
            app_count,
        )
        .where(
            models.Task.status == "open",
            models.Task.is_visible == True,
            models.Task.deadline > now,
        )
        .order_by(desc(models.Task.created_at))
        .limit(limit)
    )

    # Exclude user's own/applied/completed tasks using sync function via run_sync
    if current_user:
        try:
            from app.recommendation.utils import get_excluded_task_ids
            def _get_excluded(session):
                return get_excluded_task_ids(session, current_user.id)
            excluded = await db.run_sync(_get_excluded)
            if excluded:
                query = query.where(~models.Task.id.in_(excluded))
        except Exception as e:
            logger.debug(f"Failed to get excluded task ids: {e}")
            query = query.where(models.Task.poster_id != current_user.id)

    result = await db.execute(query)
    rows = result.all()

    # Batch-fetch poster user info
    poster_ids = {r.poster_id for r in rows if r.poster_id}
    poster_map = {}
    if poster_ids:
        poster_result = await db.execute(
            select(models.User.id, models.User.name, models.User.avatar)
            .where(models.User.id.in_(list(poster_ids)))
        )
        poster_map = {r.id: r for r in poster_result.all()}

    items = []
    for row in rows:
        poster = poster_map.get(row.poster_id)
        first_img = _first_image(row.images)

        rec_score = None
        rec_reason = None
        if recommendation_scores and row.id in recommendation_scores:
            rec_score, rec_reason = recommendation_scores[row.id]

        # Location obfuscation
        location = row.location
        if location:
            try:
                from app.utils.location_utils import obfuscate_location
                location = obfuscate_location(location)
            except Exception:
                pass

        items.append({
            "feed_type": "task",
            "id": f"task_{row.id}",
            "title": row.title,
            "title_zh": row.title_zh,
            "title_en": row.title_en,
            "description": (row.description or "")[:100],
            "description_zh": (row.description_zh or "")[:100],
            "description_en": (row.description_en or "")[:100],
            "images": [first_img] if first_img else None,
            "user_id": str(row.poster_id) if row.poster_id else None,
            "user_name": poster.name if poster else None,
            "user_avatar": poster.avatar if poster else None,
            "price": float(row.reward) if row.reward else None,
            "original_price": float(row.base_reward) if row.base_reward else None,
            "discount_percentage": None,
            "currency": getattr(row, "currency", None) or "GBP",
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
                "agreed_reward": float(row.agreed_reward) if row.agreed_reward else None,
                "reward_to_be_quoted": row.reward_to_be_quoted,
                "location": location,
                "deadline": row.deadline.isoformat() if row.deadline else None,
                "task_level": row.task_level,
                "application_count": row.app_count or 0,
                "match_score": rec_score,
                "recommendation_reason": rec_reason,
            },
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


async def _fetch_activities(db: AsyncSession, limit: int, current_user=None) -> list:
    """获取开放活动 for discovery feed."""
    from app.utils.time_utils import get_utc_time

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
            models.Activity.task_type,
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
        )
        .where(
            models.Activity.status == "open",
            models.Activity.visibility == "public",
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

    # Batch-fetch organizer info
    organizer_ids = {r.expert_id for r in rows if r.expert_id}
    organizer_map = {}
    if organizer_ids:
        org_result = await db.execute(
            select(models.User.id, models.User.name, models.User.avatar)
            .where(models.User.id.in_(list(organizer_ids)))
        )
        organizer_map = {r.id: r for r in org_result.all()}

    items = []
    for row in rows:
        organizer = organizer_map.get(row.expert_id)
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
            "description_zh": (row.description_zh or "")[:100],
            "description_en": (row.description_en or "")[:100],
            "images": [first_img] if first_img else None,
            "user_id": str(row.expert_id) if row.expert_id else None,
            "user_name": organizer.name if organizer else "Link²Ur",
            "user_avatar": organizer.avatar if organizer else None,
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
            "extra_data": {
                "task_type": row.task_type,
            },
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items


# ==================== 辅助函数 ====================

async def _batch_resolve_linked_items(db: AsyncSession, pairs: list) -> dict:
    """批量解析帖子关联的内容，返回 {(type, id_str): info_dict}

    按类型分组后各执行一次 IN 查询，避免 N+1 问题。
    使用 SAVEPOINT 隔离，单个类型查询失败不影响其他类型。
    """
    result_map = {}

    # 按类型分组
    by_type: dict[str, list[str]] = {}
    for item_type, item_id in pairs:
        by_type.setdefault(item_type, []).append(str(item_id))

    # service
    if "service" in by_type:
        try:
            ids = [int(x) for x in by_type["service"]]
            async with db.begin_nested():
                res = await db.execute(
                    select(models.TaskExpertService.id, models.TaskExpertService.service_name, models.TaskExpertService.images)
                    .where(models.TaskExpertService.id.in_(ids))
                )
                for row in res:
                    result_map[("service", str(row.id))] = {
                        "item_type": "service", "item_id": str(row.id),
                        "name": row.service_name, "thumbnail": _first_image(row.images),
                    }
        except Exception as e:
            logger.warning(f"Failed to batch resolve linked services: {e}")

    # product
    if "product" in by_type:
        try:
            ids = [int(x) for x in by_type["product"]]
            async with db.begin_nested():
                res = await db.execute(
                    select(models.FleaMarketItem.id, models.FleaMarketItem.title, models.FleaMarketItem.images)
                    .where(models.FleaMarketItem.id.in_(ids), models.FleaMarketItem.is_visible == True)
                )
                for row in res:
                    result_map[("product", str(row.id))] = {
                        "item_type": "product", "item_id": str(row.id),
                        "name": row.title, "thumbnail": _first_image(row.images),
                    }
        except Exception as e:
            logger.warning(f"Failed to batch resolve linked products: {e}")

    # activity
    if "activity" in by_type:
        try:
            ids = [int(x) for x in by_type["activity"]]
            async with db.begin_nested():
                res = await db.execute(
                    select(models.Activity.id, models.Activity.title, models.Activity.images)
                    .where(models.Activity.id.in_(ids))
                )
                for row in res:
                    result_map[("activity", str(row.id))] = {
                        "item_type": "activity", "item_id": str(row.id),
                        "name": row.title, "thumbnail": _first_image(row.images),
                    }
        except Exception as e:
            logger.warning(f"Failed to batch resolve linked activities: {e}")

    # ranking
    if "ranking" in by_type:
        try:
            ids = [int(x) for x in by_type["ranking"]]
            async with db.begin_nested():
                res = await db.execute(
                    select(models.CustomLeaderboard.id, models.CustomLeaderboard.name, models.CustomLeaderboard.cover_image)
                    .where(models.CustomLeaderboard.id.in_(ids))
                )
                for row in res:
                    result_map[("ranking", str(row.id))] = {
                        "item_type": "ranking", "item_id": str(row.id),
                        "name": row.name, "thumbnail": row.cover_image,
                    }
        except Exception as e:
            logger.warning(f"Failed to batch resolve linked rankings: {e}")

    # forum_post
    if "forum_post" in by_type:
        try:
            ids = [int(x) for x in by_type["forum_post"]]
            async with db.begin_nested():
                res = await db.execute(
                    select(models.ForumPost.id, models.ForumPost.title)
                    .where(
                        models.ForumPost.id.in_(ids),
                        models.ForumPost.is_deleted == False,
                        models.ForumPost.is_visible == True,
                    )
                )
                for row in res:
                    result_map[("forum_post", str(row.id))] = {
                        "item_type": "forum_post", "item_id": str(row.id),
                        "name": row.title, "thumbnail": None,
                    }
        except Exception as e:
            logger.warning(f"Failed to batch resolve linked forum posts: {e}")

    return result_map


# 评分 helper 已迁至 app.utils.feed_scoring (compute_score / compute_score_with_prefs /
# compute_task_score / get_city_variants / load_user_personalization_context)


def _weighted_shuffle(items: list, limit: int, page: int, seed: int = None,
                      user_preferred_categories: list = None,
                      user_city: str = None,
                      user_interest_types: set = None) -> list:
    """加权随机混排

    - 每种类型内部按热度分数排序（时间衰减 + 互动加权），而非纯时间
    - 低频类型（service_review, competitor_review, ranking）权重更高
    - 高频类型（forum_post, product）权重较低
    - 同一类型不连续出现超过 2 条
    - 使用 seed 保证跨页分页结果一致（同一 seed 排列相同）
    """
    if not items:
        return []

    # 使用固定 seed 的 Random 实例，确保分页结果稳定
    rng = random.Random(seed)

    type_weights = {
        "forum_post": 1.0,
        "product": 1.0,
        "competitor_review": 3.0,
        "service_review": 3.0,
        "expert": 2.5,      # 达人推荐（取代原 ranking）
        "service": 1.5,
        "task": 1.5,       # Tasks: medium frequency
        "activity": 2.0,    # Activities: low frequency, higher weight
    }

    by_type = {}
    for item in items:
        ft = item["feed_type"]
        if ft not in by_type:
            by_type[ft] = []
        by_type[ft].append(item)

    # 按分数排序：task 用推荐引擎，其他用热度+偏好+同城+行为兴趣
    prefs = set(user_preferred_categories or [])
    city_variants = get_city_variants(user_city) if user_city else set()
    # 预计算小写化的兴趣集合，避免每个 item 重复构建
    interests = {t.lower() for t in (user_interest_types or set())}
    for ft in by_type:
        if ft == "task":
            by_type[ft].sort(
                key=lambda item, _p=prefs, _cv=city_variants, _i=interests: compute_task_score(item, _p, _cv, _i),
                reverse=True,
            )
        else:
            by_type[ft].sort(
                key=lambda item, _p=prefs, _cv=city_variants, _i=interests: compute_score_with_prefs(item, _p, _cv, _i),
                reverse=True,
            )

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
        rand = rng.random() * total_weight
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

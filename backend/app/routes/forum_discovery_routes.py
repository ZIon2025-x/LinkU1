"""
论坛-发现 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from datetime import datetime, timezone, timedelta
from typing import Optional
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func, update, desc, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.performance_monitor import measure_api_performance
from app.cache import cache_response

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    assert_forum_visible,
    visible_forums,
    get_post_author_info,
    _post_identity,
    preload_badge_cache,
    _batch_get_post_display_view_counts,
    _batch_get_user_liked_favorited_posts,
    _batch_get_users_by_ids_async,
    _parse_attachments,
    strip_markdown,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ==================== 搜索 API ====================

@router.get("/search", response_model=schemas.ForumSearchResponse)
@measure_api_performance("search_forum_posts")
async def search_posts(
    q: str = Query(..., min_length=1, max_length=100),
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索帖子（使用 pg_trgm 相似度搜索，支持中文）"""

    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )

    # 板块筛选和权限检查
    if category_id:
        # 检查板块可见性（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, category_id, db, raise_exception=True)
        query = query.where(models.ForumPost.category_id == category_id)
    else:
        # 如果没有指定板块，需要过滤掉用户无权限访问的学校板块
        if not is_admin:
            # 获取用户可见的板块ID列表
            visible_category_ids = []

            # 1. 添加所有普通板块
            general_forums_result = await db.execute(
                select(models.ForumCategory.id).where(
                    models.ForumCategory.type == 'general',
                    models.ForumCategory.is_visible == True
                )
            )
            general_ids = [row[0] for row in general_forums_result.all()]
            visible_category_ids.extend(general_ids)

            # 2. 如果用户已登录，添加可见的学校板块
            if current_user:
                school_ids = await visible_forums(current_user, db)
                visible_category_ids.extend(school_ids)

            # 3. 只搜索可见板块的帖子
            if visible_category_ids:
                query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
            else:
                # 如果用户没有任何可见板块（理论上不应该发生），返回空结果
                query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID

    # 搜索条件（双语扩展 + pg_trgm 相似度搜索）
    from app.utils.search_expander import build_keyword_filter
    forum_columns = [
        models.ForumPost.title,
        models.ForumPost.content,
        models.ForumPost.title_en,
        models.ForumPost.title_zh,
        models.ForumPost.content_en,
        models.ForumPost.content_zh,
    ]
    keyword_expr = build_keyword_filter(
        columns=forum_columns,
        keyword=q,
        use_similarity=True,
    )
    if keyword_expr is not None:
        query = query.where(keyword_expr)

    # 按相似度排序（标题相似度优先，然后是内容相似度）
    query = query.order_by(
        func.similarity(models.ForumPost.title, q).desc(),
        func.similarity(models.ForumPost.content, q).desc(),
        models.ForumPost.created_at.desc()  # 相似度相同时按时间倒序
    )

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )

    result = await db.execute(query)
    posts = result.scalars().all()

    post_ids = [p.id for p in posts]
    liked_ids, favorited_ids = await _batch_get_user_liked_favorited_posts(
        db, current_user.id if current_user else "", post_ids
    )
    view_counts = await _batch_get_post_display_view_counts(posts)

    _author_ids = list({p.author_id for p in posts if p.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    from app.services.display_identity import batch_resolve_async
    _identities = [_post_identity(p) for p in posts]
    _identity_map = await batch_resolve_async(db, _identities)

    post_items = []
    for post in posts:
        display_view_count = view_counts.get(post.id, post.view_count or 0)
        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
            author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
            view_count=display_view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            is_visible=post.is_visible,
            is_deleted=post.is_deleted,
            images=post.images,
            attachments=_parse_attachments(post.attachments),
            linked_item_type=post.linked_item_type,
            linked_item_id=post.linked_item_id,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at,
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 通知 API ====================

@router.get("/notifications", response_model=schemas.ForumNotificationListResponse)
async def get_notifications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    is_read: Optional[bool] = Query(None),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取通知列表"""
    query = select(models.ForumNotification).where(
        models.ForumNotification.to_user_id == current_user.id
    )

    if is_read is not None:
        query = query.where(models.ForumNotification.is_read == is_read)

    query = query.order_by(models.ForumNotification.created_at.desc())

    # 注意：总数和未读数会在过滤后重新计算，因为需要过滤学校板块
    # 这里先查询原始数据，实际统计会在过滤后重新计算

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumNotification.from_user)
    )

    result = await db.execute(query)
    notifications = result.scalars().all()

    # 获取用户可见的板块ID列表（用于过滤学校板块的通知）
    visible_category_ids = []
    general_forums_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    general_ids = [row[0] for row in general_forums_result.all()]
    visible_category_ids.extend(general_ids)

    # 添加可见的学校板块
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 过滤通知：只返回用户有权限访问的板块的通知
    # 优化：批量查询所有通知目标的 category_id，避免 N+1 查询问题
    notification_list = []

    if notifications:
        # 分离 post 和 reply 类型的通知
        post_notifications = [n for n in notifications if n.target_type == "post"]
        reply_notifications = [n for n in notifications if n.target_type == "reply"]

        # 批量查询所有 post 的 category_id
        post_category_map = {}
        if post_notifications:
            post_ids = [n.target_id for n in post_notifications]
            post_category_result = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(post_ids))
            )
            post_category_map = {row[0]: row[1] for row in post_category_result.all()}

        # 批量查询所有 reply 的 post_id，然后批量查询 post 的 category_id
        reply_post_map = {}
        reply_category_map = {}
        if reply_notifications:
            reply_ids = [n.target_id for n in reply_notifications]
            reply_post_result = await db.execute(
                select(models.ForumReply.id, models.ForumReply.post_id)
                .where(models.ForumReply.id.in_(reply_ids))
            )
            reply_post_map = {row[0]: row[1] for row in reply_post_result.all()}

            # 批量查询这些 post 的 category_id
            if reply_post_map:
                post_ids_from_replies = list(reply_post_map.values())
                reply_post_category_result = await db.execute(
                    select(models.ForumPost.id, models.ForumPost.category_id)
                    .where(models.ForumPost.id.in_(post_ids_from_replies))
                )
                post_id_to_category = {row[0]: row[1] for row in reply_post_category_result.all()}
                # 构建 reply_id -> category_id 映射
                reply_category_map = {
                    reply_id: post_id_to_category.get(post_id)
                    for reply_id, post_id in reply_post_map.items()
                    if post_id in post_id_to_category
                }

        # 过滤通知
        for n in notifications:
            has_permission = False

            if n.target_type == "post":
                category_id = post_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            elif n.target_type == "reply":
                category_id = reply_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True

            # 只添加有权限访问的通知
            if has_permission:
                # 如果是回复类型的通知，需要添加帖子ID
                post_id = None
                if n.target_type == "reply":
                    post_id = reply_post_map.get(n.target_id)
                elif n.target_type == "post":
                    post_id = n.target_id

                notification_list.append(schemas.ForumNotificationOut(
                    id=n.id,
                    notification_type=n.notification_type,
                    target_type=n.target_type,
                    target_id=n.target_id,
                    post_id=post_id,
                    from_user=schemas.UserInfo(
                        id=n.from_user.id,
                        name=n.from_user.name,
                        avatar=n.from_user.avatar or None
                    ) if n.from_user else None,
                    is_read=n.is_read,
                    created_at=n.created_at
                ))

    # 重新计算总数和未读数（因为过滤了部分通知）
    total = len(notification_list)
    unread_count = sum(1 for n in notification_list if not n.is_read)

    return {
        "notifications": notification_list,
        "total": total,
        "unread_count": unread_count,
        "page": page,
        "page_size": page_size
    }


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """标记通知为已读"""
    result = await db.execute(
        select(models.ForumNotification).where(
            models.ForumNotification.id == notification_id,
            models.ForumNotification.to_user_id == current_user.id
        )
    )
    notification = result.scalar_one_or_none()

    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="通知不存在"
        )

    notification.is_read = True
    await db.commit()

    return {"message": "通知已标记为已读"}


@router.put("/notifications/read-all")
async def mark_all_notifications_read(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    标记论坛通知系统的所有通知为已读

    注意：此端点仅处理论坛通知系统（ForumNotification 模型）。
    主通知系统（Notification 模型）有独立的端点：
    POST /api/notifications/read-all（定义在 routers.py）

    两个通知系统是独立设计的，请勿合并。
    """
    await db.execute(
        update(models.ForumNotification)
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
        .values(is_read=True)
    )
    await db.commit()

    return {"message": "所有通知已标记为已读"}


@router.get("/notifications/unread-count")
async def get_unread_notification_count(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取未读通知数量（只统计用户有权限访问的板块的通知）"""
    # 获取用户可见的板块ID列表
    visible_category_ids = []
    general_forums_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    general_ids = [row[0] for row in general_forums_result.all()]
    visible_category_ids.extend(general_ids)

    # 添加可见的学校板块
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 查询未读通知
    notifications_result = await db.execute(
        select(models.ForumNotification)
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
    )
    notifications = notifications_result.scalars().all()

    # 过滤：只统计用户有权限访问的板块的通知
    # 优化：批量查询所有通知目标的 category_id，避免 N+1 查询问题
    unread_count = 0

    if notifications:
        # 分离 post 和 reply 类型的通知
        post_notifications = [n for n in notifications if n.target_type == "post"]
        reply_notifications = [n for n in notifications if n.target_type == "reply"]

        # 批量查询所有 post 的 category_id
        post_category_map = {}
        if post_notifications:
            post_ids = [n.target_id for n in post_notifications]
            post_category_result = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(post_ids))
            )
            post_category_map = {row[0]: row[1] for row in post_category_result.all()}

        # 批量查询所有 reply 的 post_id，然后批量查询 post 的 category_id
        reply_post_map = {}
        reply_category_map = {}
        if reply_notifications:
            reply_ids = [n.target_id for n in reply_notifications]
            reply_post_result = await db.execute(
                select(models.ForumReply.id, models.ForumReply.post_id)
                .where(models.ForumReply.id.in_(reply_ids))
            )
            reply_post_map = {row[0]: row[1] for row in reply_post_result.all()}

            # 批量查询这些 post 的 category_id
            if reply_post_map:
                post_ids_from_replies = list(reply_post_map.values())
                reply_post_category_result = await db.execute(
                    select(models.ForumPost.id, models.ForumPost.category_id)
                    .where(models.ForumPost.id.in_(post_ids_from_replies))
                )
                post_id_to_category = {row[0]: row[1] for row in reply_post_category_result.all()}
                # 构建 reply_id -> category_id 映射
                reply_category_map = {
                    reply_id: post_id_to_category.get(post_id)
                    for reply_id, post_id in reply_post_map.items()
                    if post_id in post_id_to_category
                }

        # 统计有权限的通知数量
        for n in notifications:
            has_permission = False

            if n.target_type == "post":
                category_id = post_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            elif n.target_type == "reply":
                category_id = reply_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True

            if has_permission:
                unread_count += 1

    return {"unread_count": unread_count}


# ==================== 热门内容 API ====================

@router.get("/hot-posts", response_model=schemas.ForumPostListResponse)
@measure_api_performance("get_hot_posts")
@cache_response(ttl=180, key_prefix="forum_hot_posts")  # 缓存3分钟
async def get_hot_posts(
    category_id: Optional[int] = Query(None, description="板块ID（可选）"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取热门帖子（按热度排序）"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )

    # 板块筛选和权限检查
    if category_id:
        # 检查板块可见性（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, category_id, db, raise_exception=True)
        query = query.where(models.ForumPost.category_id == category_id)
    else:
        # 如果没有指定板块，需要过滤掉用户无权限访问的学校板块
        if not is_admin:
            # 获取用户可见的板块ID列表
            visible_category_ids = []

            # 1. 添加所有普通板块
            general_forums_result = await db.execute(
                select(models.ForumCategory.id).where(
                    models.ForumCategory.type == 'general',
                    models.ForumCategory.is_visible == True
                )
            )
            general_ids = [row[0] for row in general_forums_result.all()]
            visible_category_ids.extend(general_ids)

            # 2. 如果用户已登录，添加可见的学校板块
            if current_user:
                school_ids = await visible_forums(current_user, db)
                visible_category_ids.extend(school_ids)

            # 3. 只搜索可见板块的帖子
            if visible_category_ids:
                query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
            else:
                # 如果用户没有任何可见板块，返回空结果
                query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID

    # 改进的热度算法：综合考虑点赞、收藏、评论和最近活跃度
    # 使用 last_reply_at 作为时间因子（如果存在），否则使用 created_at
    active_time = func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at)
    hours_since_active = func.extract('epoch', func.now() - active_time) / 3600.0

    # 综合热度分数 = (点赞数*权重 + 收藏数*权重 + 评论数*权重 + 浏览量*权重) / 时间衰减因子
    hot_score = (
        models.ForumPost.like_count * 5.0 +      # 点赞权重：5
        models.ForumPost.favorite_count * 4.0 +  # 收藏权重：4（收藏表示深度兴趣）
        models.ForumPost.reply_count * 3.0 +     # 评论权重：3
        models.ForumPost.view_count * 0.1        # 浏览量权重：0.1（较低，因为浏览不代表互动）
    ) / func.pow(
        (hours_since_active / 24.0) + 1.0,  # 以天为单位，+1避免除零
        1.2  # 衰减指数，值越大衰减越快
    )

    # 置顶优先，然后按热度排序
    query = query.order_by(
        models.ForumPost.is_pinned.desc(),  # 置顶帖子优先
        hot_score.desc()  # 最后按热度
    )

    # 限制数量
    query = query.limit(limit)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )

    result = await db.execute(query)
    posts = result.scalars().all()

    post_ids = [p.id for p in posts]
    liked_ids, favorited_ids = await _batch_get_user_liked_favorited_posts(
        db, current_user.id if current_user else "", post_ids
    )
    view_counts = await _batch_get_post_display_view_counts(posts)

    _author_ids = list({p.author_id for p in posts if p.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    from app.services.display_identity import batch_resolve_async
    _identities = [_post_identity(p) for p in posts]
    _identity_map = await batch_resolve_async(db, _identities)

    post_items = []
    for post in posts:
        is_liked = post.id in liked_ids
        is_favorited = post.id in favorited_ids
        display_view_count = view_counts.get(post.id, post.view_count or 0)

        content_preview = strip_markdown(post.content)
        content_preview_en = None
        content_preview_zh = None
        if hasattr(post, 'content_en') and post.content_en:
            content_preview_en = strip_markdown(post.content_en)
        if hasattr(post, 'content_zh') and post.content_zh:
            content_preview_zh = strip_markdown(post.content_zh)

        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))

        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            title_en=getattr(post, 'title_en', None),
            title_zh=getattr(post, 'title_zh', None),
            content_preview=content_preview,
            content_preview_en=content_preview_en,
            content_preview_zh=content_preview_zh,
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
            author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
            view_count=display_view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            is_visible=post.is_visible,
            is_deleted=post.is_deleted,
            images=post.images,
            attachments=_parse_attachments(post.attachments),
            linked_item_type=post.linked_item_type,
            linked_item_id=post.linked_item_id,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at,
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": len(post_items),
        "page": 1,
        "page_size": limit
    }


# ==================== 用户论坛统计 API ====================

@router.get("/users/{user_id}/stats")
@measure_api_performance("get_user_forum_stats")
async def get_user_forum_stats(
    user_id: str,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户论坛统计信息"""
    # 检查权限：只能查看自己的统计或公开统计
    if current_user and current_user.id != user_id:
        # 非本人只能查看公开统计
        pass  # 允许查看公开统计

    # 统计帖子数
    posts_count_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(
            models.ForumPost.author_id == user_id,
            models.ForumPost.is_deleted == False
        )
    )
    posts_count = posts_count_result.scalar() or 0

    # 统计回复数
    replies_count_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(
            models.ForumReply.author_id == user_id,
            models.ForumReply.is_deleted == False
        )
    )
    replies_count = replies_count_result.scalar() or 0

    # 统计获得的点赞数（分别统计帖子和回复的点赞）
    post_likes_result = await db.execute(
        select(func.sum(models.ForumPost.like_count))
        .where(
            models.ForumPost.author_id == user_id,
            models.ForumPost.is_deleted == False
        )
    )
    post_likes = post_likes_result.scalar() or 0

    reply_likes_result = await db.execute(
        select(func.sum(models.ForumReply.like_count))
        .where(
            models.ForumReply.author_id == user_id,
            models.ForumReply.is_deleted == False
        )
    )
    reply_likes = reply_likes_result.scalar() or 0
    likes_received = post_likes + reply_likes

    # 统计收藏数
    favorites_count_result = await db.execute(
        select(func.count(models.ForumFavorite.id))
        .where(models.ForumFavorite.user_id == user_id)
    )
    favorites_count = favorites_count_result.scalar() or 0

    return {
        "user_id": user_id,
        "posts_count": posts_count,
        "replies_count": replies_count,
        "likes_received": likes_received,
        "favorites_count": favorites_count
    }


@router.get("/users/{user_id}/hot-posts", response_model=schemas.ForumPostListResponse)
async def get_user_hot_posts(
    user_id: str,
    limit: int = Query(3, ge=1, le=10, description="返回数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户发布的最热门帖子"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 构建查询：获取指定用户的帖子
    query = select(models.ForumPost).where(
        models.ForumPost.author_id == user_id,
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )

    # 如果不是管理员，需要过滤掉用户无权限访问的学校板块
    if not is_admin:
        # 获取用户可见的板块ID列表
        visible_category_ids = []

        # 1. 添加所有普通板块
        general_forums_result = await db.execute(
            select(models.ForumCategory.id).where(
                models.ForumCategory.type == 'general',
                models.ForumCategory.is_visible == True
            )
        )
        general_ids = [row[0] for row in general_forums_result.all()]
        visible_category_ids.extend(general_ids)

        # 2. 如果用户已登录，添加可见的学校板块
        if current_user:
            school_ids = await visible_forums(current_user, db)
            visible_category_ids.extend(school_ids)

        # 3. 只返回可见板块的帖子
        if visible_category_ids:
            query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
        else:
            # 如果用户没有任何可见板块，返回空结果
            query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID

    # 改进的热度算法：综合考虑点赞、收藏、评论和最近活跃度
    # 使用 last_reply_at 作为时间因子（如果存在），否则使用 created_at
    active_time = func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at)
    hours_since_active = func.extract('epoch', func.now() - active_time) / 3600.0

    # 综合热度分数 = (点赞数*权重 + 收藏数*权重 + 评论数*权重 + 浏览量*权重) / 时间衰减因子
    hot_score = (
        models.ForumPost.like_count * 5.0 +      # 点赞权重：5
        models.ForumPost.favorite_count * 4.0 +  # 收藏权重：4（收藏表示深度兴趣）
        models.ForumPost.reply_count * 3.0 +     # 评论权重：3
        models.ForumPost.view_count * 0.1        # 浏览量权重：0.1（较低，因为浏览不代表互动）
    ) / func.pow(
        (hours_since_active / 24.0) + 1.0,  # 以天为单位，+1避免除零
        1.2  # 衰减指数，值越大衰减越快
    )
    query = query.order_by(hot_score.desc())

    # 限制数量
    query = query.limit(limit)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )

    result = await db.execute(query)
    posts = result.scalars().all()

    post_ids = [p.id for p in posts]
    liked_ids, favorited_ids = await _batch_get_user_liked_favorited_posts(
        db, current_user.id if current_user else "", post_ids
    )
    view_counts = await _batch_get_post_display_view_counts(posts)

    _author_ids = list({p.author_id for p in posts if p.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    from app.services.display_identity import batch_resolve_async
    _identities = [_post_identity(p) for p in posts]
    _identity_map = await batch_resolve_async(db, _identities)

    post_items = []
    for post in posts:
        is_liked = post.id in liked_ids
        is_favorited = post.id in favorited_ids
        display_view_count = view_counts.get(post.id, post.view_count or 0)

        content_preview = strip_markdown(post.content)
        content_preview_en = None
        content_preview_zh = None
        if hasattr(post, 'content_en') and post.content_en:
            content_preview_en = strip_markdown(post.content_en)
        if hasattr(post, 'content_zh') and post.content_zh:
            content_preview_zh = strip_markdown(post.content_zh)

        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))

        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            title_en=getattr(post, 'title_en', None),
            title_zh=getattr(post, 'title_zh', None),
            content_preview=content_preview,
            content_preview_en=content_preview_en,
            content_preview_zh=content_preview_zh,
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
            author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
            view_count=display_view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            is_visible=post.is_visible,
            is_deleted=post.is_deleted,
            images=post.images,
            attachments=_parse_attachments(post.attachments),
            linked_item_type=post.linked_item_type,
            linked_item_id=post.linked_item_id,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at,
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": len(post_items),
        "page": 1,
        "page_size": limit
    }


# ==================== 排行榜 API ====================

@router.get("/leaderboard/posts")
async def get_top_posts_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取发帖排行榜"""
    now = datetime.now(timezone.utc)

    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None

    # 构建查询
    # 只统计普通板块（type='general'）的帖子，确保公平性
    query = select(
        models.ForumPost.author_id,
        func.count(models.ForumPost.id).label("post_count")
    ).join(
        models.ForumCategory,
        models.ForumPost.category_id == models.ForumCategory.id
    ).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True,
        models.ForumCategory.type == 'general'  # 只统计普通板块
    )

    if start_time:
        query = query.where(models.ForumPost.created_at >= start_time)

    query = query.group_by(models.ForumPost.author_id).order_by(func.count(models.ForumPost.id).desc()).limit(limit)

    result = await db.execute(query)
    top_users = result.all()

    user_ids = [uid for uid, _ in top_users if uid]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, post_count in top_users:
        user = user_map.get(user_id)
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "count": post_count,
                "rank": rank
            })
            rank += 1

    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/favorites")
async def get_top_favorites_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取收藏排行榜（统计用户发布的帖子被收藏的总数）"""
    now = datetime.now(timezone.utc)

    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None

    # 构建查询：统计用户发布的帖子被收藏的总数
    # 只统计普通板块（type='general'）的帖子，确保公平性
    query = select(
        models.ForumPost.author_id,
        func.sum(models.ForumPost.favorite_count).label("favorite_count")
    ).join(
        models.ForumCategory,
        models.ForumPost.category_id == models.ForumCategory.id
    ).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True,
        models.ForumCategory.type == 'general'  # 只统计普通板块
    )

    if start_time:
        query = query.where(models.ForumPost.created_at >= start_time)

    query = query.group_by(models.ForumPost.author_id).order_by(func.sum(models.ForumPost.favorite_count).desc()).limit(limit)

    result = await db.execute(query)
    top_users = result.all()

    user_ids = [uid for uid, _ in top_users if uid]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, favorite_count in top_users:
        if user_id:
            user = user_map.get(user_id)
            if user:
                user_list.append({
                    "user": schemas.UserInfo(
                        id=user.id,
                        name=user.name,
                        avatar=user.avatar or None
                    ),
                    "count": favorite_count or 0,
                    "rank": rank
                })
                rank += 1

    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/likes")
async def get_top_likes_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取获赞排行榜（统计用户发布的帖子和回复获得的点赞数）"""
    now = datetime.now(timezone.utc)

    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None

    # 统计帖子获得的点赞数
    post_likes_query = select(
        models.ForumPost.author_id,
        func.sum(models.ForumPost.like_count).label("likes")
    ).where(
        models.ForumPost.is_deleted == False
    )
    if start_time:
        post_likes_query = post_likes_query.where(models.ForumPost.created_at >= start_time)
    post_likes_query = post_likes_query.group_by(models.ForumPost.author_id)

    # 统计回复获得的点赞数
    reply_likes_query = select(
        models.ForumReply.author_id,
        func.sum(models.ForumReply.like_count).label("likes")
    ).where(
        models.ForumReply.is_deleted == False
    )
    if start_time:
        reply_likes_query = reply_likes_query.where(models.ForumReply.created_at >= start_time)
    reply_likes_query = reply_likes_query.group_by(models.ForumReply.author_id)

    # 合并结果（简化处理：分别查询后合并）
    post_result = await db.execute(post_likes_query)
    post_likes_data = {row[0]: row[1] or 0 for row in post_result.all()}

    reply_result = await db.execute(reply_likes_query)
    reply_likes_data = {row[0]: row[1] or 0 for row in reply_result.all()}

    # 合并统计
    total_likes = {}
    for user_id, likes in post_likes_data.items():
        total_likes[user_id] = total_likes.get(user_id, 0) + likes
    for user_id, likes in reply_likes_data.items():
        total_likes[user_id] = total_likes.get(user_id, 0) + likes

    # 排序并取前N名
    sorted_users = sorted(total_likes.items(), key=lambda x: x[1], reverse=True)[:limit]

    user_ids = [uid for uid, _ in sorted_users]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, likes_count in sorted_users:
        user = user_map.get(user_id)
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "count": likes_count,
                "rank": rank
            })
            rank += 1

    return {
        "period": period,
        "users": user_list
    }


# ==================== 关联内容搜索（Discovery Feed） ====================

@router.get("/search-linkable")
async def search_linkable_content(
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    type: str = Query("all", description="内容类型: all/service/expert/activity/product/ranking/forum_post"),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索可关联的公开内容（用于帖子关联功能）

    混合方案：所有公开内容都可搜索，但标注用户是否参与过
    """
    # 获取当前用户（用于判断 is_experienced）
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except Exception:
        pass

    results = []
    from app.utils.search_expander import build_keyword_filter
    limit_per_type = 5

    # 搜索服务（包含达人服务和个人服务）
    if type in ("all", "service"):
        # 服务所有者：个人服务用 user_id，达人服务用 expert_id（与 users.id 同空间）
        owner_user_id_expr = func.coalesce(
            models.TaskExpertService.user_id,
            models.TaskExpertService.expert_id,
        )
        service_query = (
            select(
                models.TaskExpertService.id,
                models.TaskExpertService.service_name,
                models.TaskExpertService.description,
                models.TaskExpertService.images,
                models.TaskExpertService.service_type,
                models.User.name.label("owner_name"),
            )
            .join(models.User, models.User.id == owner_user_id_expr)
            .where(
                models.TaskExpertService.status == "active",
            )
        )
        svc_keyword_expr = build_keyword_filter(
            columns=[
                models.TaskExpertService.service_name,
                models.TaskExpertService.description,
            ],
            keyword=q,
            use_similarity=False,
        )
        if svc_keyword_expr is not None:
            service_query = service_query.where(svc_keyword_expr)
        service_query = (
            service_query
            .limit(limit_per_type)
        )
        service_result = await db.execute(service_query)
        for row in service_result:
            is_experienced = False
            if current_user:
                exp_check = await db.execute(
                    select(func.count(models.Task.id)).where(
                        models.Task.expert_service_id == row.id,
                        or_(models.Task.poster_id == current_user.id, models.Task.taker_id == current_user.id),
                        models.Task.status == "completed",
                    )
                )
                is_experienced = (exp_check.scalar() or 0) > 0
            # 解析 images JSONB 获取第一张图
            svc_images = row.images
            svc_thumb = None
            if svc_images:
                if isinstance(svc_images, list):
                    svc_thumb = svc_images[0] if svc_images else None
                elif isinstance(svc_images, str):
                    try:
                        parsed = json.loads(svc_images)
                        svc_thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            owner_label = "个人" if row.service_type == "personal" else "达人"
            svc_subtitle = f"{owner_label} · {row.owner_name}" if row.owner_name else owner_label
            results.append({
                "item_type": "service",
                "item_id": str(row.id),
                "title": row.service_name,
                "subtitle": svc_subtitle,
                "thumbnail": svc_thumb,
                "is_experienced": is_experienced,
            })

    # 搜索跳蚤市场商品
    if type in ("all", "product"):
        product_query = (
            select(
                models.FleaMarketItem.id,
                models.FleaMarketItem.title,
                models.FleaMarketItem.price,
                models.FleaMarketItem.images,
                models.FleaMarketItem.currency,
            )
            .where(
                models.FleaMarketItem.status == "active",
                models.FleaMarketItem.is_visible == True,
            )
        )
        prod_keyword_expr = build_keyword_filter(
            columns=[
                models.FleaMarketItem.title,
                models.FleaMarketItem.description,
                models.FleaMarketItem.location,
                models.FleaMarketItem.category,
            ],
            keyword=q,
            use_similarity=False,
        )
        if prod_keyword_expr is not None:
            product_query = product_query.where(prod_keyword_expr)
        product_query = product_query.limit(limit_per_type)
        product_result = await db.execute(product_query)
        for row in product_result:
            prod_images = row.images
            first_image = None
            if prod_images:
                if isinstance(prod_images, list):
                    first_image = prod_images[0] if prod_images else None
                elif isinstance(prod_images, str):
                    try:
                        parsed = json.loads(prod_images)
                        first_image = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            is_experienced = False
            if current_user:
                fav_check = await db.execute(
                    select(func.count()).select_from(models.FleaMarketFavorite).where(
                        models.FleaMarketFavorite.item_id == row.id,
                        models.FleaMarketFavorite.user_id == current_user.id,
                    )
                )
                is_experienced = (fav_check.scalar() or 0) > 0
            results.append({
                "item_type": "product",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": f"{row.currency} {row.price:.2f}" if row.price else None,
                "thumbnail": first_image,
                "is_experienced": is_experienced,
            })

        # 搜索活动（含 location，支持按地址/城市搜索）
    if type in ("all", "activity"):
        activity_query = (
            select(
                models.Activity.id,
                models.Activity.title,
                models.Activity.images.label("activity_images"),
                models.User.name.label("expert_name"),
            )
            .join(models.User, models.Activity.expert_id == models.User.id)
            .where(
                models.Activity.status.in_(["published", "registration_open"]),
            )
        )
        act_keyword_expr = build_keyword_filter(
            columns=[
                models.Activity.title,
                models.Activity.description,
                models.Activity.location,
            ],
            keyword=q,
            use_similarity=False,
        )
        if act_keyword_expr is not None:
            activity_query = activity_query.where(act_keyword_expr)
        activity_query = activity_query.limit(limit_per_type)
        activity_result = await db.execute(activity_query)
        for row in activity_result:
            is_experienced = False
            if current_user:
                exp_check = await db.execute(
                    select(func.count(models.Task.id)).where(
                        models.Task.parent_activity_id == row.id,
                        or_(models.Task.poster_id == current_user.id, models.Task.taker_id == current_user.id),
                    )
                )
                is_experienced = (exp_check.scalar() or 0) > 0
            act_images = row.activity_images
            act_thumb = None
            if act_images:
                if isinstance(act_images, list):
                    act_thumb = act_images[0] if act_images else None
                elif isinstance(act_images, str):
                    try:
                        parsed = json.loads(act_images)
                        act_thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            results.append({
                "item_type": "activity",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": row.expert_name,
                "thumbnail": act_thumb,
                "is_experienced": is_experienced,
            })

    # 搜索排行榜
    if type in ("all", "ranking"):
        ranking_query = (
            select(
                models.CustomLeaderboard.id,
                models.CustomLeaderboard.name,
                models.CustomLeaderboard.cover_image,
            )
            .where(
                models.CustomLeaderboard.status == "active",
            )
        )
        rank_keyword_expr = build_keyword_filter(
            columns=[
                models.CustomLeaderboard.name,
                models.CustomLeaderboard.name_en,
                models.CustomLeaderboard.name_zh,
                models.CustomLeaderboard.description,
                models.CustomLeaderboard.description_en,
                models.CustomLeaderboard.description_zh,
            ],
            keyword=q,
            use_similarity=False,
        )
        if rank_keyword_expr is not None:
            ranking_query = ranking_query.where(rank_keyword_expr)
        ranking_query = ranking_query.limit(limit_per_type)
        ranking_result = await db.execute(ranking_query)
        for row in ranking_result:
            results.append({
                "item_type": "ranking",
                "item_id": str(row.id),
                "title": row.name,
                "subtitle": "排行榜",
                "thumbnail": row.cover_image,
                "is_experienced": False,
            })

    # 搜索帖子
    if type in ("all", "forum_post"):
        post_query = (
            select(
                models.ForumPost.id,
                models.ForumPost.title,
            )
            .where(
                models.ForumPost.is_deleted == False,
                models.ForumPost.is_visible == True,
            )
        )
        post_keyword_expr = build_keyword_filter(
            columns=[
                models.ForumPost.title,
                models.ForumPost.title_en,
                models.ForumPost.title_zh,
                models.ForumPost.content,
                models.ForumPost.content_en,
                models.ForumPost.content_zh,
            ],
            keyword=q,
            use_similarity=False,
        )
        if post_keyword_expr is not None:
            post_query = post_query.where(post_keyword_expr)
        post_query = post_query.order_by(desc(models.ForumPost.created_at)).limit(limit_per_type)
        post_result = await db.execute(post_query)
        for row in post_result:
            results.append({
                "item_type": "forum_post",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": "帖子",
                "thumbnail": None,
                "is_experienced": False,
            })

    # 排序：已体验的排前面
    results.sort(key=lambda x: (not x["is_experienced"], x["item_type"]))

    return {"results": results}


@router.get("/linkable-for-user")
async def get_linkable_content_for_user(
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取与当前用户相关的可关联内容（发帖关联时在搜索框下方展示）
    - 未登录返回空列表
    - 已登录：我的服务、我的活动、我收藏的商品、我申请的排行榜等
    """
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except Exception:
        pass
    if not current_user:
        return {"results": []}

    results = []
    limit_per_type = 5

    # 我的服务（达人服务 + 个人服务）
    my_svc_query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.images,
            models.TaskExpertService.service_type,
        )
        .where(
            or_(
                models.TaskExpertService.user_id == current_user.id,
                models.TaskExpertService.expert_id == current_user.id,
            ),
            models.TaskExpertService.status == "active",
        )
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit_per_type)
    )
    for row in (await db.execute(my_svc_query)).all():
        thumb = None
        if row.images:
            if isinstance(row.images, list):
                thumb = row.images[0] if row.images else None
            elif isinstance(row.images, str):
                try:
                    parsed = json.loads(row.images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        my_label = "我的个人服务" if row.service_type == "personal" else "我的达人服务"
        results.append({
            "item_type": "service",
            "item_id": str(row.id),
            "name": row.service_name,
            "title": row.service_name,
            "subtitle": my_label,
            "thumbnail": thumb,
        })

    # 我的活动（我发布的）
    act_query = (
        select(
            models.Activity.id,
            models.Activity.title,
            models.Activity.images.label("activity_images"),
        )
        .where(
            models.Activity.expert_id == current_user.id,
            models.Activity.status.in_(["published", "registration_open"]),
        )
        .order_by(desc(models.Activity.created_at))
        .limit(limit_per_type)
    )
    for row in (await db.execute(act_query)).all():
        thumb = None
        if row.activity_images:
            if isinstance(row.activity_images, list):
                thumb = row.activity_images[0] if row.activity_images else None
            elif isinstance(row.activity_images, str):
                try:
                    parsed = json.loads(row.activity_images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        results.append({
            "item_type": "activity",
            "item_id": str(row.id),
            "name": row.title,
            "title": row.title,
            "subtitle": "我的活动",
            "thumbnail": thumb,
        })

    # 我收藏的跳蚤市场商品
    fav_query = (
        select(
            models.FleaMarketItem.id,
            models.FleaMarketItem.title,
            models.FleaMarketItem.images,
            models.FleaMarketItem.price,
            models.FleaMarketItem.currency,
        )
        .join(models.FleaMarketFavorite, models.FleaMarketFavorite.item_id == models.FleaMarketItem.id)
        .where(
            models.FleaMarketFavorite.user_id == current_user.id,
            models.FleaMarketItem.status == "active",
            models.FleaMarketItem.is_visible == True,
        )
        .limit(limit_per_type)
    )
    for row in (await db.execute(fav_query)).all():
        thumb = None
        if row.images:
            if isinstance(row.images, list):
                thumb = row.images[0] if row.images else None
            elif isinstance(row.images, str):
                try:
                    parsed = json.loads(row.images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        results.append({
            "item_type": "product",
            "item_id": str(row.id),
            "name": row.title,
            "title": row.title,
            "subtitle": f"{row.currency} {row.price:.2f}" if row.price else "收藏",
            "thumbnail": thumb,
        })

    # 我申请的排行榜（已通过）
    lb_query = (
        select(
            models.CustomLeaderboard.id,
            models.CustomLeaderboard.name,
            models.CustomLeaderboard.cover_image,
        )
        .where(
            models.CustomLeaderboard.applicant_id == current_user.id,
            models.CustomLeaderboard.status == "active",
        )
        .limit(limit_per_type)
    )
    for row in (await db.execute(lb_query)).all():
        results.append({
            "item_type": "ranking",
            "item_id": str(row.id),
            "name": row.name,
            "title": row.name,
            "subtitle": "排行榜",
            "thumbnail": row.cover_image,
        })

    return {"results": results}

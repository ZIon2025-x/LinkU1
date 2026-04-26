"""
论坛-我的内容 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from typing import Optional
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    visible_forums,
    preload_badge_cache,
    _parse_attachments,
    strip_markdown,
    get_current_admin_async,
    _post_identity,
    get_post_author_info,
    get_reply_author_info,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/my/category-favorites", response_model=schemas.ForumCategoryFavoriteListResponse)
async def get_my_category_favorites(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我收藏的板块列表"""
    # 查询收藏的板块
    query = (
        select(models.ForumCategory)
        .join(
            models.ForumCategoryFavorite,
            models.ForumCategory.id == models.ForumCategoryFavorite.category_id
        )
        .where(
            models.ForumCategoryFavorite.user_id == current_user.id,
            models.ForumCategory.is_visible == True
        )
        .order_by(models.ForumCategoryFavorite.created_at.desc())
    )

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    categories = result.scalars().all()

    # 检查板块可见性（学校板块需要权限）
    visible_category_ids = await visible_forums(current_user, db)
    general_forums_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    general_ids = [row[0] for row in general_forums_result.all()]
    visible_category_ids.extend(general_ids)

    # 过滤掉用户无权限访问的板块
    visible_categories = [cat for cat in categories if cat.id in visible_category_ids]

    return {
        "categories": [schemas.ForumCategoryOut.model_validate(cat) for cat in visible_categories],
        "total": len(visible_categories),
        "page": page,
        "page_size": page_size
    }


@router.get("/my/posts", response_model=schemas.ForumPostListResponse)
async def get_my_posts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的帖子（支持管理员和普通用户）"""
    # 尝试获取普通用户会话
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 尝试获取管理员会话
    admin_user = None
    try:
        admin_user = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 如果既没有普通用户会话也没有管理员会话，返回401
    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息",
            headers={"X-Error-Code": "UNAUTHORIZED"}
        )

    # 检查是否为管理员
    is_admin_user = admin_user is not None

    # 构建查询：支持普通用户和管理员
    if admin_user:
        # 管理员查看自己的帖子
        query = select(models.ForumPost).where(
            models.ForumPost.admin_author_id == admin_user.id,
            models.ForumPost.is_deleted == False
        )
    else:
        # 普通用户查看自己的帖子
        query = select(models.ForumPost).where(
            models.ForumPost.author_id == current_user.id,
            models.ForumPost.is_deleted == False
        )

    query = query.order_by(models.ForumPost.created_at.desc())

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

    # 转换为列表项格式，并过滤掉用户无权限访问的学校板块
    _author_ids = list({p.author_id for p in posts if p.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    from app.services.display_identity import batch_resolve_async
    _identities = [_post_identity(p) for p in posts]
    _identity_map = await batch_resolve_async(db, _identities)

    post_items = []
    # 获取用户可见的板块ID列表（用于过滤）
    visible_category_ids = None
    # 检查是否为管理员
    is_admin_user = admin_user is not None
    if not is_admin_user:
        visible_category_ids = []
        # 添加所有普通板块
        general_forums_result = await db.execute(
            select(models.ForumCategory.id).where(
                models.ForumCategory.type == 'general',
                models.ForumCategory.is_visible == True
            )
        )
        general_ids = [row[0] for row in general_forums_result.all()]
        visible_category_ids.extend(general_ids)

        # 如果用户已登录，添加可见的学校板块
        if current_user:
            school_ids = await visible_forums(current_user, db)
            visible_category_ids.extend(school_ids)

    for post in posts:
        # 如果不是管理员，过滤掉无权限访问的学校板块
        if not is_admin_user and visible_category_ids is not None:
            if post.category_id not in visible_category_ids:
                continue

        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))

        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
            author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
            view_count=post.view_count,
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

    # 重新计算总数（因为过滤了部分帖子）
    if not is_admin_user and visible_category_ids is not None:
        # 重新查询过滤后的总数
        filtered_query = select(models.ForumPost)
        if admin_user:
            filtered_query = filtered_query.where(
                models.ForumPost.admin_author_id == admin_user.id,
                models.ForumPost.is_deleted == False
            )
        else:
            filtered_query = filtered_query.where(
                models.ForumPost.author_id == current_user.id,
                models.ForumPost.is_deleted == False
            )
        filtered_query = filtered_query.where(models.ForumPost.category_id.in_(visible_category_ids))
        filtered_count_query = select(func.count()).select_from(filtered_query.subquery())
        filtered_total_result = await db.execute(filtered_count_query)
        total = filtered_total_result.scalar() or 0

    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/my/replies", response_model=schemas.ForumReplyListResponse)
async def get_my_replies(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的回复"""
    query = select(models.ForumReply).where(
        models.ForumReply.author_id == current_user.id,
        models.ForumReply.is_deleted == False
    )

    query = query.order_by(models.ForumReply.created_at.desc())

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumReply.post).selectinload(models.ForumPost.category),
        selectinload(models.ForumReply.author),
        selectinload(models.ForumReply.admin_author)
    )

    result = await db.execute(query)
    replies = result.scalars().all()

    # 获取用户可见的板块ID列表（用于过滤学校板块）
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

    # 预加载勋章缓存
    _reply_author_ids = list({r.author_id for r in replies if r.author_id})
    _badge_cache = await preload_badge_cache(db, _reply_author_ids)

    # 转换为输出格式，并过滤掉用户无权限访问的学校板块的回复
    reply_list = []
    for reply in replies:
        # 检查回复所属帖子所属板块是否有权限访问
        if reply.post.category_id not in visible_category_ids:
            continue

        reply_list.append(schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            reply_level=reply.reply_level,
            like_count=reply.like_count,
            is_liked=False,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
            replies=[]
        ))

    return {
        "replies": reply_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/my/favorites", response_model=schemas.ForumFavoriteListResponse)
async def get_my_favorites(
    request: Request,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的收藏"""
    query = select(models.ForumFavorite).where(
        models.ForumFavorite.user_id == current_user.id
    )

    query = query.order_by(models.ForumFavorite.created_at.desc())

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumFavorite.post).selectinload(models.ForumPost.category),
        selectinload(models.ForumFavorite.post).selectinload(models.ForumPost.author),
        selectinload(models.ForumFavorite.post).selectinload(models.ForumPost.admin_author)
    )

    result = await db.execute(query)
    favorites = result.scalars().all()

    # 获取用户可见的板块ID列表（用于过滤学校板块）
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

    # 预加载勋章缓存
    _fav_author_ids = list({f.post.author_id for f in favorites if f.post and f.post.author_id})
    _badge_cache = await preload_badge_cache(db, _fav_author_ids)

    from app.services.display_identity import batch_resolve_async
    _fav_identities = [_post_identity(f.post) for f in favorites if f.post]
    _fav_identity_map = await batch_resolve_async(db, _fav_identities)

    # 转换为输出格式，并过滤掉用户无权限访问的学校板块
    favorite_list = []
    for favorite in favorites:
        post = favorite.post
        # 只返回可见的帖子，且用户有权限访问的板块
        if (post.is_deleted == False and
            post.is_visible == True and
            post.category_id in visible_category_ids):
            _otype, _oid = _post_identity(post)
            _dname, _davatar = _fav_identity_map.get((_otype, _oid), ("", None))
            favorite_list.append(schemas.ForumFavoriteOut(
                id=favorite.id,
                post=schemas.ForumPostListItem(
                    id=post.id,
                    title=post.title,
                    content_preview=strip_markdown(post.content),
                    category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
                    author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
                    view_count=post.view_count,
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
                ),
                created_at=favorite.created_at
            ))

    return {
        "favorites": favorite_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/my/likes")
async def get_my_likes(
    target_type: Optional[str] = Query(None, pattern="^(post|reply)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我赞过的内容"""
    query = select(models.ForumLike).where(
        models.ForumLike.user_id == current_user.id
    )

    if target_type:
        query = query.where(models.ForumLike.target_type == target_type)

    query = query.order_by(models.ForumLike.created_at.desc())

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    likes = result.scalars().all()

    # 批量加载帖子和回复，避免 N+1 查询
    post_ids = [l.target_id for l in likes if l.target_type == "post"]
    reply_ids = [l.target_id for l in likes if l.target_type == "reply"]
    post_map = {}
    reply_map = {}
    if post_ids:
        posts_result = await db.execute(
            select(models.ForumPost)
            .where(models.ForumPost.id.in_(post_ids))
            .where(models.ForumPost.is_deleted == False)
            .where(models.ForumPost.is_visible == True)
            .options(
                selectinload(models.ForumPost.category),
                selectinload(models.ForumPost.author),
                selectinload(models.ForumPost.admin_author)
            )
        )
        post_map = {p.id: p for p in posts_result.scalars().all()}
    if reply_ids:
        replies_result = await db.execute(
            select(models.ForumReply)
            .where(models.ForumReply.id.in_(reply_ids))
            .where(models.ForumReply.is_deleted == False)
            .where(models.ForumReply.is_visible == True)
            .options(
                selectinload(models.ForumReply.post),
                selectinload(models.ForumReply.author)
            )
        )
        reply_map = {r.id: r for r in replies_result.scalars().all()}

    # 预加载勋章缓存（帖子作者 + 回复作者）
    _like_author_ids = list(
        {p.author_id for p in post_map.values() if p.author_id}
        | {r.author_id for r in reply_map.values() if r.author_id}
    )
    _badge_cache = await preload_badge_cache(db, _like_author_ids)

    like_list = []
    for like in likes:
        if like.target_type == "post":
            post = post_map.get(like.target_id)
            if post:
                # 使用统一的作者信息获取函数（支持管理员和普通用户）
                author_info = await get_post_author_info(db, post, request, _badge_cache=_badge_cache)

                like_list.append({
                    "target_type": "post",
                    "post": {
                        "id": post.id,
                        "title": post.title,
                        "content_preview": strip_markdown(post.content),
                        "category": {
                            "id": post.category.id,
                            "name": post.category.name
                        },
                        "author": {
                            "id": author_info.id,
                            "name": author_info.name,
                            "avatar": author_info.avatar or None,
                            "is_admin": author_info.is_admin or False
                        },
                        "view_count": post.view_count,
                        "reply_count": post.reply_count,
                        "like_count": post.like_count,
                        "favorite_count": post.favorite_count,
                        "is_pinned": post.is_pinned,
                        "is_featured": post.is_featured,
                        "is_locked": post.is_locked,
                        "is_visible": post.is_visible,
                        "is_deleted": post.is_deleted,
                        "created_at": post.created_at,
                        "last_reply_at": post.last_reply_at
                    },
                    "created_at": like.created_at
                })
        elif like.target_type == "reply":
            reply = reply_map.get(like.target_id)
            if reply:
                like_list.append({
                    "target_type": "reply",
                    "reply": {
                        "id": reply.id,
                        "content": reply.content,
                        "post": {
                            "id": reply.post.id,
                            "title": reply.post.title
                        },
                        "author": {
                            "id": reply.author.id,
                            "name": reply.author.name,
                            "avatar": reply.author.avatar or None
                        },
                        "like_count": reply.like_count,
                        "created_at": reply.created_at
                    },
                    "created_at": like.created_at
                })

    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }

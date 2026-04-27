"""
论坛-互动 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from typing import List, Optional
import logging

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    assert_forum_visible,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/likes", response_model=schemas.ForumLikeResponse)
async def toggle_like(
    like: schemas.ForumLikeRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """点赞/取消点赞"""
    # 验证目标存在
    if like.target_type == "post":
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == like.target_id)
        )
        target = result.scalar_one_or_none()
        if not target or target.is_deleted or not target.is_visible:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在或已删除"
            )
        # 检查帖子所属板块的可见性（学校板块需要权限）
        await assert_forum_visible(current_user, target.category_id, db, raise_exception=True)
    else:  # reply
        result = await db.execute(
            select(models.ForumReply)
            .options(selectinload(models.ForumReply.post))
            .where(models.ForumReply.id == like.target_id)
        )
        target = result.scalar_one_or_none()
        if not target or target.is_deleted or not target.is_visible:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="回复不存在或已删除"
            )
        # 检查回复所属帖子所属板块的可见性（学校板块需要权限）
        await assert_forum_visible(current_user, target.post.category_id, db, raise_exception=True)

    # 检查是否已点赞
    existing_like = await db.execute(
        select(models.ForumLike).where(
            models.ForumLike.target_type == like.target_type,
            models.ForumLike.target_id == like.target_id,
            models.ForumLike.user_id == current_user.id
        )
    )
    existing = existing_like.scalar_one_or_none()

    if existing:
        # 取消点赞
        await db.delete(existing)
        # 更新点赞数
        if like.target_type == "post":
            target.like_count = max(0, target.like_count - 1)
        else:
            target.like_count = max(0, target.like_count - 1)
        liked = False
    else:
        # 添加点赞
        new_like = models.ForumLike(
            target_type=like.target_type,
            target_id=like.target_id,
            user_id=current_user.id
        )
        db.add(new_like)
        # 更新点赞数
        if like.target_type == "post":
            target.like_count += 1
            # 发送通知给帖子作者（如果点赞者不是作者本人）
            if target.author_id and target.author_id != current_user.id:
                notification = models.ForumNotification(
                    notification_type="like_post",
                    target_type="post",
                    target_id=target.id,
                    from_user_id=current_user.id,
                    to_user_id=target.author_id
                )
                db.add(notification)
        else:
            target.like_count += 1
            # 注意：根据文档，回复点赞不发送通知
        liked = True

    await db.commit()

    return {
        "liked": liked,
        "like_count": target.like_count
    }


@router.get("/posts/{post_id}/likes", response_model=schemas.ForumLikeListResponse)
async def get_post_likes(
    post_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子点赞列表"""
    # 验证帖子存在
    post_result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    post = post_result.scalar_one_or_none()
    if not post or post.is_deleted or not post.is_visible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在或已删除"
        )

    # 查询点赞列表
    query = select(models.ForumLike).where(
        models.ForumLike.target_type == "post",
        models.ForumLike.target_id == post_id
    )

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.order_by(models.ForumLike.created_at.desc())
    query = query.offset(offset).limit(page_size)

    # 加载用户信息
    query = query.options(selectinload(models.ForumLike.user))

    result = await db.execute(query)
    likes = result.scalars().all()

    # 转换为输出格式
    like_list = []
    for like in likes:
        like_list.append(schemas.ForumLikeListItem(
            user=schemas.UserInfo(
                id=like.user.id,
                name=like.user.name,
                avatar=like.user.avatar or None
            ),
            created_at=like.created_at
        ))

    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/replies/{reply_id}/likes", response_model=schemas.ForumLikeListResponse)
async def get_reply_likes(
    reply_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取回复点赞列表"""
    # 验证回复存在
    reply_result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply_id)
    )
    reply = reply_result.scalar_one_or_none()
    if not reply or reply.is_deleted or not reply.is_visible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复不存在或已删除"
        )

    # 查询点赞列表
    query = select(models.ForumLike).where(
        models.ForumLike.target_type == "reply",
        models.ForumLike.target_id == reply_id
    )

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.order_by(models.ForumLike.created_at.desc())
    query = query.offset(offset).limit(page_size)

    # 加载用户信息
    query = query.options(selectinload(models.ForumLike.user))

    result = await db.execute(query)
    likes = result.scalars().all()

    # 转换为输出格式
    like_list = []
    for like in likes:
        like_list.append(schemas.ForumLikeListItem(
            user=schemas.UserInfo(
                id=like.user.id,
                name=like.user.name,
                avatar=like.user.avatar or None
            ),
            created_at=like.created_at
        ))

    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 收藏 API ====================

@router.post("/favorites", response_model=schemas.ForumFavoriteResponse)
async def toggle_favorite(
    favorite: schemas.ForumFavoriteRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """收藏/取消收藏"""
    # 验证帖子存在
    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == favorite.post_id)
    )
    post = result.scalar_one_or_none()

    if not post or post.is_deleted or not post.is_visible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在或已删除"
        )

    # 检查帖子所属板块的可见性（学校板块需要权限）
    await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

    # 检查是否已收藏
    existing_favorite = await db.execute(
        select(models.ForumFavorite).where(
            models.ForumFavorite.post_id == favorite.post_id,
            models.ForumFavorite.user_id == current_user.id
        )
    )
    existing = existing_favorite.scalar_one_or_none()

    if existing:
        # 取消收藏
        await db.delete(existing)
        post.favorite_count = max(0, post.favorite_count - 1)
        favorited = False
    else:
        # 添加收藏
        new_favorite = models.ForumFavorite(
            post_id=favorite.post_id,
            user_id=current_user.id
        )
        db.add(new_favorite)
        post.favorite_count += 1
        favorited = True

    await db.commit()

    return {
        "favorited": favorited,
        "favorite_count": post.favorite_count
    }


# ==================== 板块收藏 API ====================

@router.post("/categories/{category_id}/favorite", response_model=schemas.ForumCategoryFavoriteResponse)
async def toggle_category_favorite(
    category_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """收藏/取消收藏论坛板块"""
    # 验证板块存在
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )

    # 检查板块可见性（学校板块需要权限）
    await assert_forum_visible(current_user, category_id, db, raise_exception=True)

    # 检查是否已收藏
    existing_favorite = await db.execute(
        select(models.ForumCategoryFavorite).where(
            models.ForumCategoryFavorite.category_id == category_id,
            models.ForumCategoryFavorite.user_id == current_user.id
        )
    )
    existing = existing_favorite.scalar_one_or_none()

    if existing:
        # 取消收藏
        await db.delete(existing)
        favorited = False
    else:
        # 添加收藏
        new_favorite = models.ForumCategoryFavorite(
            category_id=category_id,
            user_id=current_user.id
        )
        db.add(new_favorite)
        favorited = True

    await db.commit()

    return {
        "favorited": favorited
    }


@router.get("/categories/{category_id}/favorite/status", response_model=schemas.ForumCategoryFavoriteResponse)
async def get_category_favorite_status(
    category_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块收藏状态"""
    if not current_user:
        return {"favorited": False}

    result = await db.execute(
        select(models.ForumCategoryFavorite).where(
            models.ForumCategoryFavorite.category_id == category_id,
            models.ForumCategoryFavorite.user_id == current_user.id
        )
    )
    existing = result.scalar_one_or_none()

    return {
        "favorited": existing is not None
    }


@router.post("/categories/favorites/batch", response_model=schemas.ForumCategoryFavoriteBatchResponse)
async def get_category_favorites_batch(
    category_ids: List[int] = Body(..., description="板块ID列表"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """批量获取板块收藏状态"""
    if not current_user or not category_ids:
        return {"favorites": {cat_id: False for cat_id in category_ids}}

    result = await db.execute(
        select(models.ForumCategoryFavorite).where(
            models.ForumCategoryFavorite.category_id.in_(category_ids),
            models.ForumCategoryFavorite.user_id == current_user.id
        )
    )
    favorites = result.scalars().all()

    # 构建字典：category_id -> favorited
    favorite_dict = {fav.category_id: True for fav in favorites}
    # 填充未收藏的板块
    for cat_id in category_ids:
        if cat_id not in favorite_dict:
            favorite_dict[cat_id] = False

    return {"favorites": favorite_dict}

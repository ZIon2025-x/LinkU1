"""
关注系统路由
提供关注/取消关注、粉丝列表、关注列表接口
"""

import asyncio
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency, get_current_user_secure_async_csrf
from app.forum_routes import get_current_user_optional
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/users", tags=["关注"])

# ==================== 缓存失效 ====================


async def _invalidate_follow_cache(follower_id: str, following_id: str):
    """失效关注相关缓存"""

    def _do_invalidate():
        try:
            redis_cache.delete(f"follow_count:{follower_id}")
            redis_cache.delete(f"follow_count:{following_id}")
            redis_cache.delete(f"is_following:{follower_id}:{following_id}")
        except Exception:
            pass

    await asyncio.to_thread(_do_invalidate)


# ==================== 速率限制辅助 ====================


async def _check_follow_rate_limit(user_id: str) -> None:
    """检查关注操作速率限制（30次/分钟）"""

    def _do_rate_check():
        try:
            key = f"follow_rate:{user_id}"
            if redis_cache.redis_client is None or not redis_cache.enabled:
                return True  # Redis不可用时放行
            count = redis_cache.redis_client.incr(key)
            if count == 1:
                redis_cache.redis_client.expire(key, 60)
            return count <= 30
        except Exception:
            return True  # Redis异常时放行

    allowed = await asyncio.to_thread(_do_rate_check)
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="操作过于频繁，请稍后再试",
        )


# ==================== 获取粉丝数辅助 ====================


async def _get_followers_count(db: AsyncSession, user_id: str) -> int:
    """获取用户的粉丝数"""
    result = await db.execute(
        select(func.count()).where(models.UserFollow.following_id == user_id)
    )
    return result.scalar() or 0


# ==================== 关注 ====================


@router.post("/{user_id}/follow")
async def follow_user(
    user_id: str,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关注用户"""
    # 不允许关注自己
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="不能关注自己",
        )

    # 检查目标用户是否存在
    target_result = await db.execute(
        select(models.User).where(models.User.id == user_id)
    )
    target_user = target_result.scalar_one_or_none()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )

    # 速率限制
    await _check_follow_rate_limit(current_user.id)

    # 检查是否已关注（幂等）
    existing_result = await db.execute(
        select(models.UserFollow).where(
            models.UserFollow.follower_id == current_user.id,
            models.UserFollow.following_id == user_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if not existing:
        follow = models.UserFollow(
            follower_id=current_user.id,
            following_id=user_id,
        )
        db.add(follow)
        await db.commit()
        await _invalidate_follow_cache(current_user.id, user_id)

    followers_count = await _get_followers_count(db, user_id)
    return {"status": "followed", "followers_count": followers_count}


# ==================== 取消关注 ====================


@router.delete("/{user_id}/follow")
async def unfollow_user(
    user_id: str,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消关注用户"""
    # 速率限制
    await _check_follow_rate_limit(current_user.id)

    # 查找关注关系
    existing_result = await db.execute(
        select(models.UserFollow).where(
            models.UserFollow.follower_id == current_user.id,
            models.UserFollow.following_id == user_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        await _invalidate_follow_cache(current_user.id, user_id)

    followers_count = await _get_followers_count(db, user_id)
    return {"status": "unfollowed", "followers_count": followers_count}


# ==================== 粉丝列表 ====================


@router.get("/{user_id}/followers")
async def get_followers(
    user_id: str,
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的粉丝列表（关注该用户的人）"""
    # 验证目标用户存在
    target_result = await db.execute(
        select(models.User).where(models.User.id == user_id)
    )
    if not target_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )

    # 查询总数
    total_result = await db.execute(
        select(func.count()).where(models.UserFollow.following_id == user_id)
    )
    total = total_result.scalar() or 0

    # 分页查询粉丝
    offset = (page - 1) * page_size
    follows_result = await db.execute(
        select(models.UserFollow)
        .where(models.UserFollow.following_id == user_id)
        .order_by(models.UserFollow.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    follows = follows_result.scalars().all()

    # 收集所有粉丝ID
    follower_ids = [f.follower_id for f in follows]
    followed_at_map = {f.follower_id: f.created_at for f in follows}

    # 查询粉丝用户信息
    users_map: dict = {}
    if follower_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(follower_ids))
        )
        users_map = {u.id: u for u in users_result.scalars().all()}

    # 查询当前用户是否关注这些粉丝（互粉状态）
    is_following_set: set = set()
    if current_user and follower_ids:
        my_follows_result = await db.execute(
            select(models.UserFollow.following_id).where(
                models.UserFollow.follower_id == current_user.id,
                models.UserFollow.following_id.in_(follower_ids),
            )
        )
        is_following_set = set(my_follows_result.scalars().all())

    # 构建返回数据（按原始顺序）
    user_list = []
    for fid in follower_ids:
        u = users_map.get(fid)
        if not u:
            continue
        followed_at = followed_at_map.get(fid)
        user_list.append(
            {
                "id": u.id,
                "name": u.name,
                "avatar": u.avatar or "",
                "bio": u.bio or "",
                "is_following": fid in is_following_set,
                "followed_at": followed_at.isoformat() if followed_at else None,
            }
        )

    return {
        "users": user_list,
        "total": total,
        "page": page,
        "has_more": (offset + len(user_list)) < total,
    }


# ==================== 关注列表 ====================


@router.get("/{user_id}/following")
async def get_following(
    user_id: str,
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的关注列表（该用户关注的人）"""
    # 验证目标用户存在
    target_result = await db.execute(
        select(models.User).where(models.User.id == user_id)
    )
    if not target_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )

    # 查询总数
    total_result = await db.execute(
        select(func.count()).where(models.UserFollow.follower_id == user_id)
    )
    total = total_result.scalar() or 0

    # 分页查询关注
    offset = (page - 1) * page_size
    follows_result = await db.execute(
        select(models.UserFollow)
        .where(models.UserFollow.follower_id == user_id)
        .order_by(models.UserFollow.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    follows = follows_result.scalars().all()

    # 收集所有被关注用户ID
    following_ids = [f.following_id for f in follows]
    followed_at_map = {f.following_id: f.created_at for f in follows}

    # 查询被关注用户信息
    users_map: dict = {}
    if following_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(following_ids))
        )
        users_map = {u.id: u for u in users_result.scalars().all()}

    # 查询当前用户是否关注这些人
    is_following_set: set = set()
    if current_user and following_ids:
        my_follows_result = await db.execute(
            select(models.UserFollow.following_id).where(
                models.UserFollow.follower_id == current_user.id,
                models.UserFollow.following_id.in_(following_ids),
            )
        )
        is_following_set = set(my_follows_result.scalars().all())

    # 构建返回数据（按原始顺序）
    user_list = []
    for fid in following_ids:
        u = users_map.get(fid)
        if not u:
            continue
        followed_at = followed_at_map.get(fid)
        user_list.append(
            {
                "id": u.id,
                "name": u.name,
                "avatar": u.avatar or "",
                "bio": u.bio or "",
                "is_following": fid in is_following_set,
                "followed_at": followed_at.isoformat() if followed_at else None,
            }
        )

    return {
        "users": user_list,
        "total": total,
        "page": page,
        "has_more": (offset + len(user_list)) < total,
    }

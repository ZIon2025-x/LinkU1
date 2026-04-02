"""热搜榜 API 路由"""

import json
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.database import get_async_db
from app.redis_pool import get_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/trending", tags=["热搜榜"])


# ==================== 公开接口 ====================

@router.get("/searches", response_model=schemas.TrendingSearchResponse)
async def get_trending_searches():
    """获取热搜榜 Top10（公开，读 Redis 缓存）"""
    redis_client = get_client(decode_responses=True)
    if not redis_client:
        return schemas.TrendingSearchResponse(items=[], updated_at=None)

    data = redis_client.get("trending:current")
    updated_at = redis_client.get("trending:updated_at")

    if not data:
        return schemas.TrendingSearchResponse(items=[], updated_at=updated_at)

    items_raw = json.loads(data)
    items = [
        schemas.TrendingSearchItem(
            rank=item["rank"],
            keyword=item["keyword"],
            heat_display=item["heat_display"],
            tag=item.get("tag"),
        )
        for item in items_raw
    ]

    return schemas.TrendingSearchResponse(items=items, updated_at=updated_at)


# ==================== 管理员接口 ====================

async def _get_admin(request: Request, db: AsyncSession):
    """获取当前管理员"""
    from app.forum_routes import get_current_admin_async
    return await get_current_admin_async(request, db)


@router.get("/admin/blacklist", response_model=List[schemas.TrendingBlacklistItem])
async def list_blacklist(
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """查看所有黑名单词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingBlacklist).order_by(models.TrendingBlacklist.created_at.desc())
    )
    return result.scalars().all()


@router.post("/admin/blacklist", response_model=schemas.TrendingBlacklistItem, status_code=201)
async def add_blacklist(
    body: schemas.TrendingBlacklistCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """添加黑名单词"""
    admin = await _get_admin(request, db)
    existing = await db.execute(
        select(models.TrendingBlacklist).where(
            models.TrendingBlacklist.keyword == body.keyword
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Keyword already in blacklist")

    entry = models.TrendingBlacklist(keyword=body.keyword, created_by=admin.id)
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/admin/blacklist/{item_id}", status_code=204)
async def remove_blacklist(
    item_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """删除黑名单词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingBlacklist).where(models.TrendingBlacklist.id == item_id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Not found")
    await db.delete(entry)
    await db.commit()


@router.get("/admin/pinned", response_model=List[schemas.TrendingPinnedItem])
async def list_pinned(
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """查看所有置顶词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingPinned).order_by(models.TrendingPinned.sort_order)
    )
    return result.scalars().all()


@router.post("/admin/pinned", response_model=schemas.TrendingPinnedItem, status_code=201)
async def add_pinned(
    body: schemas.TrendingPinnedCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """添加置顶词"""
    admin = await _get_admin(request, db)
    entry = models.TrendingPinned(
        keyword=body.keyword,
        display_heat=body.display_heat,
        sort_order=body.sort_order,
        created_by=admin.id,
        expires_at=body.expires_at,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/admin/pinned/{item_id}", status_code=204)
async def remove_pinned(
    item_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """删除置顶词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingPinned).where(models.TrendingPinned.id == item_id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Not found")
    await db.delete(entry)
    await db.commit()

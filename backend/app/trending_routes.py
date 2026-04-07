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
async def get_trending_searches(db: AsyncSession = Depends(get_async_db)):
    """
    获取热搜榜 Top10（公开）。
    优先读 Redis 缓存；miss 时回落到 trending_snapshot 表，保证永不为空。
    """
    redis_client = get_client(decode_responses=True)
    updated_at = None
    items_raw = None

    if redis_client:
        try:
            data = redis_client.get("trending:current")
            updated_at = redis_client.get("trending:updated_at")
            if data:
                items_raw = json.loads(data)
        except (json.JSONDecodeError, TypeError) as e:
            logger.warning(f"trending cache data corrupted: {e}")

    # Redis miss → 回落到 DB 快照表
    if not items_raw:
        result = await db.execute(
            select(models.TrendingSnapshot).order_by(models.TrendingSnapshot.rank.asc())
        )
        snapshot_rows = result.scalars().all()
        items_raw = [
            {
                "rank": row.rank,
                "keyword": row.keyword,
                "heat_display": row.heat_display,
                "view_count": row.view_count,
                "tag": row.tag,
            }
            for row in snapshot_rows
        ]
        if snapshot_rows:
            updated_at = snapshot_rows[0].updated_at.isoformat() if snapshot_rows[0].updated_at else None

    try:
        items = [
            schemas.TrendingSearchItem(
                rank=item["rank"],
                keyword=item["keyword"],
                heat_display=item["heat_display"],
                view_count=item.get("view_count", 0),
                tag=item.get("tag"),
            )
            for item in items_raw
        ]
    except (KeyError, TypeError) as e:
        logger.warning(f"trending data malformed: {e}")
        items = []

    return schemas.TrendingSearchResponse(items=items, updated_at=updated_at)


# ==================== 搜索日志 ====================

class _LogSearchBody(schemas.BaseModel):
    query: str = schemas.Field(..., min_length=2, max_length=200)


@router.post("/log-search", status_code=204)
async def log_search_endpoint(
    body: _LogSearchBody,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """记录搜索行为（供前端统一调用，不依赖具体搜索模块）"""
    from app.trending_search import log_search
    from app.forum_routes import get_current_user_optional
    user = await get_current_user_optional(request, db)
    try:
        await log_search(db=db, raw_query=body.query, user_id=user.id if user else None)
        await db.commit()
    except Exception as e:
        logger.debug(f"log-search failed: {e}")
        await db.rollback()


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


@router.delete("/admin/snapshot", status_code=204)
async def clear_trending_snapshot(
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    """
    清空热搜榜快照（管理员手动重置用）。
    同时清除 Redis 的 trending:current / trending:previous / trending:updated_at，
    下一次 compute_trending (每小时) 会重新从搜索日志 + 置顶词开始累积。
    """
    await _get_admin(request, db)

    # 清空快照表
    await db.execute(models.TrendingSnapshot.__table__.delete())
    await db.commit()

    # 清除 Redis 缓存
    redis_client = get_client(decode_responses=True)
    if redis_client:
        try:
            redis_client.delete("trending:current", "trending:previous", "trending:updated_at")
        except Exception as e:
            logger.warning(f"clear_trending_snapshot: Redis 清除失败: {e}")

    logger.info("热搜榜快照已被管理员清空")

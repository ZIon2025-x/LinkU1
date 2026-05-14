"""活动评价公开端点

跟 service_review_routes.py 同样套路：Review 表没有直接 activity_id 字段,
通过 Task.parent_activity_id 反查 task_ids,再 Review.task_id IN (...) 聚合。

只读、公开,无需认证。
"""
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency

logger = logging.getLogger(__name__)

activity_review_router = APIRouter(
    prefix="/api/activities",
    tags=["activity-reviews"],
)


async def _activity_task_ids(db: AsyncSession, activity_id: int) -> list[int]:
    """活动 → 所有底层 Task ID 列表(multi_participant_tasks 等)"""
    result = await db.execute(
        select(models.Task.id).where(
            models.Task.parent_activity_id == activity_id,
        )
    )
    return [row[0] for row in result.all() if row[0] is not None]


@activity_review_router.get("/{activity_id}/reviews")
async def get_activity_reviews(
    activity_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """活动评价列表(按 Task.parent_activity_id 反查)"""
    task_ids = await _activity_task_ids(db, activity_id)
    if not task_ids:
        return {"items": [], "total": 0, "page": page, "page_size": page_size}

    count_result = await db.execute(
        select(func.count(models.Review.id)).where(
            models.Review.task_id.in_(task_ids),
            models.Review.is_deleted.is_(False),
        )
    )
    total = count_result.scalar() or 0

    reviews_result = await db.execute(
        select(models.Review)
        .where(
            models.Review.task_id.in_(task_ids),
            models.Review.is_deleted.is_(False),
        )
        .order_by(models.Review.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    reviews = reviews_result.scalars().all()

    reviewer_ids = list({r.user_id for r in reviews if r.user_id})
    users_map: dict[str, models.User] = {}
    if reviewer_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(reviewer_ids))
        )
        for u in users_result.scalars().all():
            users_map[u.id] = u

    items = []
    for r in reviews:
        reviewer = users_map.get(r.user_id)
        is_anon = bool(getattr(r, "is_anonymous", False))
        # 匿名评价不暴露 reviewer 身份(与 service_review_routes 同款)
        if is_anon:
            reviewer_id = None
            reviewer_name = ""
            reviewer_avatar = None
        else:
            reviewer_id = r.user_id
            reviewer_name = reviewer.name if reviewer else "Unknown"
            reviewer_avatar = reviewer.avatar if reviewer else None
        items.append({
            "id": r.id,
            "task_id": r.task_id,
            "reviewer_id": reviewer_id,
            "reviewer_name": reviewer_name,
            "reviewer_avatar": reviewer_avatar,
            "is_anonymous": is_anon,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "reply_content": r.reply_content,
            "reply_at": r.reply_at.isoformat() if r.reply_at else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}


@activity_review_router.get("/{activity_id}/reviews/summary")
async def get_activity_review_summary(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """活动评价汇总(平均分 + 总数)"""
    task_ids = await _activity_task_ids(db, activity_id)
    if not task_ids:
        return {"average_rating": 0, "total_reviews": 0}

    result = await db.execute(
        select(
            func.avg(models.Review.rating),
            func.count(models.Review.id),
        ).where(
            models.Review.task_id.in_(task_ids),
            models.Review.is_deleted.is_(False),
        )
    )
    row = result.one()
    avg_rating = float(row[0]) if row[0] else 0
    total_reviews = row[1] or 0

    return {
        "average_rating": round(avg_rating, 1),
        "total_reviews": total_reviews,
    }

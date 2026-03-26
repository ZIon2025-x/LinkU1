import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models
from app.async_routers import get_current_user_secure_async_csrf
from app.deps import get_async_db_dependency

logger = logging.getLogger(__name__)

service_review_router = APIRouter(
    prefix="/api/services",
    tags=["service-reviews"],
)


@service_review_router.get("/{service_id}/reviews")
async def get_service_reviews(
    service_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Get reviews for a service by looking up tasks created from service applications."""
    # Find all task_ids created from this service's applications
    app_result = await db.execute(
        select(models.ServiceApplication.task_id).where(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.task_id.isnot(None),
            models.ServiceApplication.status == "approved",
        )
    )
    task_ids = [row[0] for row in app_result.all() if row[0] is not None]

    if not task_ids:
        return {"items": [], "total": 0, "page": page, "page_size": page_size}

    # Count total reviews
    count_result = await db.execute(
        select(func.count(models.Review.id)).where(
            models.Review.task_id.in_(task_ids)
        )
    )
    total = count_result.scalar() or 0

    # Fetch reviews with pagination
    reviews_result = await db.execute(
        select(models.Review)
        .where(models.Review.task_id.in_(task_ids))
        .order_by(models.Review.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    reviews = reviews_result.scalars().all()

    # Batch load reviewer info
    reviewer_ids = list({r.user_id for r in reviews if r.user_id})
    users_map = {}
    if reviewer_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(reviewer_ids))
        )
        for u in users_result.scalars().all():
            users_map[u.id] = u

    items = []
    for r in reviews:
        reviewer = users_map.get(r.user_id)
        items.append({
            "id": r.id,
            "task_id": r.task_id,
            "reviewer_id": r.user_id,
            "reviewer_name": reviewer.name if reviewer else "Unknown",
            "reviewer_avatar": reviewer.avatar_url if reviewer else None,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}


@service_review_router.get("/{service_id}/reviews/summary")
async def get_service_review_summary(
    service_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Get review summary (average rating, count) for a service."""
    app_result = await db.execute(
        select(models.ServiceApplication.task_id).where(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.task_id.isnot(None),
            models.ServiceApplication.status == "approved",
        )
    )
    task_ids = [row[0] for row in app_result.all() if row[0] is not None]

    if not task_ids:
        return {"average_rating": 0, "total_reviews": 0}

    result = await db.execute(
        select(
            func.avg(models.Review.rating),
            func.count(models.Review.id),
        ).where(models.Review.task_id.in_(task_ids))
    )
    row = result.one()
    avg_rating = float(row[0]) if row[0] else 0
    total_reviews = row[1] or 0

    return {
        "average_rating": round(avg_rating, 1),
        "total_reviews": total_reviews,
    }

"""套餐评价公开端点

Review 表已有 package_id 字段(直接关联 user_service_packages),所以套餐 review
查询比活动/服务简单 - 不需要反查 task_ids。

只读、公开,无需认证。注意:
  - 创建评价的 endpoint(POST /api/my/packages/{id}/review)在别处实现
  - 这里只提供"读"
"""
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency

logger = logging.getLogger(__name__)

package_review_router = APIRouter(
    prefix="/api/packages",
    tags=["package-reviews"],
)


@package_review_router.get("/{package_id}/reviews")
async def get_package_reviews(
    package_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """套餐评价列表(直接走 Review.package_id 索引)"""
    count_result = await db.execute(
        select(func.count(models.Review.id)).where(
            models.Review.package_id == package_id,
            models.Review.is_deleted.is_(False),
        )
    )
    total = count_result.scalar() or 0

    if total == 0:
        return {"items": [], "total": 0, "page": page, "page_size": page_size}

    reviews_result = await db.execute(
        select(models.Review)
        .where(
            models.Review.package_id == package_id,
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
            "package_id": r.package_id,
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


@package_review_router.get("/{package_id}/reviews/summary")
async def get_package_review_summary(
    package_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """套餐评价汇总(平均分 + 总数)"""
    result = await db.execute(
        select(
            func.avg(models.Review.rating),
            func.count(models.Review.id),
        ).where(
            models.Review.package_id == package_id,
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

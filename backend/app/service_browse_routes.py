from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, case, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency

service_browse_router = APIRouter(
    prefix="/api/services",
    tags=["service-browse"],
)


@service_browse_router.get("/browse")
async def browse_services(
    type: str = Query("all", pattern="^(all|expert|personal)$"),
    q: str = Query(None, max_length=100),
    sort: str = Query("recommended", pattern="^(recommended|newest|price_asc|price_desc)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    base_filter = select(models.TaskExpertService).where(
        models.TaskExpertService.status == "active",
    )

    # Type filter
    if type == "expert":
        base_filter = base_filter.where(models.TaskExpertService.service_type == "expert")
    elif type == "personal":
        base_filter = base_filter.where(models.TaskExpertService.service_type == "personal")

    # Text search
    if q:
        search = f"%{q}%"
        base_filter = base_filter.where(
            or_(
                models.TaskExpertService.service_name.ilike(search),
                models.TaskExpertService.description.ilike(search),
            )
        )

    # Count total before pagination
    count_query = select(func.count()).select_from(base_filter.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Sort
    query = base_filter
    if sort == "recommended":
        query = query.order_by(
            case(
                (models.TaskExpertService.service_type == "expert", 0),
                else_=1,
            ),
            models.TaskExpertService.created_at.desc(),
        )
    elif sort == "newest":
        query = query.order_by(models.TaskExpertService.created_at.desc())
    elif sort == "price_asc":
        query = query.order_by(models.TaskExpertService.base_price.asc())
    elif sort == "price_desc":
        query = query.order_by(models.TaskExpertService.base_price.desc())

    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    services = result.scalars().all()

    # Batch-load owner user info (avoid N+1)
    owner_ids = list({s.owner_user_id for s in services if s.owner_user_id})
    owners_map = {}
    if owner_ids:
        owners_result = await db.execute(
            select(models.User).where(models.User.id.in_(owner_ids))
        )
        for u in owners_result.scalars().all():
            owners_map[u.id] = u

    items = []
    for s in services:
        owner = owners_map.get(s.owner_user_id)
        items.append({
            "id": s.id,
            "service_name": s.service_name,
            "description": s.description,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency or "GBP",
            "pricing_type": s.pricing_type or "fixed",
            "service_type": s.service_type or "expert",
            "is_expert_verified": s.service_type == "expert",
            "status": s.status,
            "images": s.images or [],
            "owner_id": s.owner_user_id or "",
            "owner_name": owner.name if owner else "Unknown",
            "owner_avatar": owner.avatar if owner else None,
            "owner_rating": float(owner.avg_rating) if owner and owner.avg_rating else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}

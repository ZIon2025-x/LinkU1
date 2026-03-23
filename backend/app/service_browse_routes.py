from fastapi import APIRouter, Depends, HTTPException, Query
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
    sort: str = Query("recommended", pattern="^(recommended|newest|price_asc|price_desc|nearby)$"),
    lat: float = Query(None),
    lng: float = Query(None),
    radius: int = Query(25, ge=5, le=100),
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
    elif sort == "nearby":
        if lat is None or lng is None:
            raise HTTPException(status_code=400, detail="lat and lng required for nearby sort")
        query = query.where(
            models.TaskExpertService.location_type.in_(["in_person", "both"]),
            models.TaskExpertService.latitude.isnot(None),
            models.TaskExpertService.longitude.isnot(None),
        )
        from sqlalchemy import func as sa_func
        radius_deg = radius / 111.0
        lat_diff = models.TaskExpertService.latitude - lat
        lng_diff = (models.TaskExpertService.longitude - lng) * sa_func.cos(sa_func.radians(lat))
        distance_sq = lat_diff * lat_diff + lng_diff * lng_diff
        query = query.where(distance_sq <= radius_deg * radius_deg)
        query = query.order_by(distance_sq.asc())

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
        item = {
            "id": s.id,
            "service_name": s.service_name,
            "description": s.description,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency or "GBP",
            "pricing_type": s.pricing_type or "fixed",
            "location_type": s.location_type or "online",
            "location": s.location,
            "service_type": s.service_type or "expert",
            "is_expert_verified": s.service_type == "expert",
            "status": s.status,
            "images": s.images or [],
            "owner_id": s.owner_user_id or "",
            "owner_name": owner.name if owner else "Unknown",
            "owner_avatar": owner.avatar if owner else None,
            "owner_rating": float(owner.avg_rating) if owner and owner.avg_rating else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        if sort == "nearby" and lat is not None and lng is not None and s.latitude and s.longitude:
            from math import radians, cos, sqrt
            lat_d = float(s.latitude) - lat
            lng_d = (float(s.longitude) - lng) * cos(radians(lat))
            dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
            item["distance_km"] = round(dist_km, 1)
        items.append(item)

    return {"items": items, "total": total, "page": page, "page_size": page_size}

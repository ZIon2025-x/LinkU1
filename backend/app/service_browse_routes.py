from math import radians, cos, sqrt

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, case, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.models_expert import Expert

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
    radius: int = Query(25, ge=1, le=100),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    S = models.TaskExpertService  # alias for readability

    base_filter = select(S).where(S.status == "active")

    # Type filter
    if type == "expert":
        base_filter = base_filter.where(S.service_type == "expert")
    elif type == "personal":
        base_filter = base_filter.where(S.service_type == "personal")

    # Text search (bilingual keyword expansion)
    if q:
        from app.utils.search_expander import build_keyword_filter
        keyword_expr = build_keyword_filter(
            columns=[S.service_name, S.service_name_en, S.service_name_zh,
                     S.description, S.description_en, S.description_zh],
            keyword=q,
            use_similarity=False,
        )
        if keyword_expr is not None:
            base_filter = base_filter.where(keyword_expr)

    # Apply filters (including nearby) before counting
    query = base_filter
    distance_sq = None  # will be set if sort == "nearby"

    if sort == "nearby":
        if lat is None or lng is None:
            raise HTTPException(status_code=400, detail="lat and lng required for nearby sort")

        # LEFT JOIN experts to get fallback lat/lng for services that inherit team address
        query = query.outerjoin(Expert, S.expert_id == Expert.id)

        # Effective coordinates: service's own ?? expert team's
        effective_lat = func.coalesce(S.latitude, Expert.latitude)
        effective_lng = func.coalesce(S.longitude, Expert.longitude)

        # Only in_person/both services that have coordinates (own or inherited)
        query = query.where(
            S.location_type.in_(["in_person", "both"]),
            effective_lat.isnot(None),
            effective_lng.isnot(None),
        )

        # Bounding box + distance filter
        radius_deg = radius / 111.0
        lat_diff = effective_lat - lat
        lng_diff = (effective_lng - lng) * func.cos(func.radians(lat))
        distance_sq = lat_diff * lat_diff + lng_diff * lng_diff
        query = query.where(distance_sq <= radius_deg * radius_deg)

    # Count total after all filters (including nearby) but before pagination
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Sort / Order
    if sort == "recommended":
        query = query.order_by(
            case((S.service_type == "expert", 0), else_=1),
            S.created_at.desc(),
        )
    elif sort == "newest":
        query = query.order_by(S.created_at.desc())
    elif sort == "price_asc":
        query = query.order_by(S.base_price.asc())
    elif sort == "price_desc":
        query = query.order_by(S.base_price.desc())
    elif sort == "nearby":
        query = query.order_by(distance_sq.asc())

    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    services = result.scalars().all()

    # Batch-load owner user info (avoid N+1)
    owner_ids = set()
    for s in services:
        if s.owner_user_id:
            owner_ids.add(s.owner_user_id)
        elif s.expert_id:
            owner_ids.add(s.expert_id)
    owners_map = {}
    if owner_ids:
        owners_result = await db.execute(
            select(models.User).where(models.User.id.in_(list(owner_ids)))
        )
        for u in owners_result.scalars().all():
            owners_map[u.id] = u

    # Batch-load expert teams for location fallback (spec: effective = service ?? expert)
    expert_ids = {s.expert_id for s in services if s.expert_id}
    experts_map = {}
    if expert_ids:
        experts_result = await db.execute(
            select(Expert).where(Expert.id.in_(list(expert_ids)))
        )
        for e in experts_result.scalars().all():
            experts_map[e.id] = e

    items = []
    for s in services:
        effective_owner_id = s.owner_user_id or s.expert_id or ""
        owner = owners_map.get(effective_owner_id)

        # Fallback to expert team values when service's own values are null
        expert = experts_map.get(s.expert_id) if s.expert_id else None
        eff_lat = float(s.latitude) if s.latitude else (float(expert.latitude) if expert and expert.latitude else None)
        eff_lng = float(s.longitude) if s.longitude else (float(expert.longitude) if expert and expert.longitude else None)
        eff_radius = s.service_radius_km if s.service_radius_km is not None else (expert.service_radius_km if expert else None)

        item = {
            "id": s.id,
            "service_name": s.service_name,
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            "description": s.description,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency or "GBP",
            "pricing_type": s.pricing_type or "fixed",
            "location_type": s.location_type or "online",
            "location": s.location,
            "service_type": s.service_type or "expert",
            "is_expert_verified": s.service_type == "expert",
            "status": s.status,
            "images": s.images or [],
            "skills": s.skills or [],
            "owner_id": effective_owner_id,
            "owner_name": owner.name if owner else "Unknown",
            "owner_avatar": owner.avatar if owner else None,
            "owner_rating": float(owner.avg_rating) if owner and owner.avg_rating else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "service_radius_km": eff_radius,
        }
        if lat is not None and lng is not None and eff_lat is not None and eff_lng is not None:
            lat_d = eff_lat - lat
            lng_d = (eff_lng - lng) * cos(radians(lat))
            dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
            item["distance_km"] = round(dist_km, 1)
            if eff_radius is None or eff_radius == 0 or s.location_type == "online":
                item["within_service_area"] = True
            else:
                item["within_service_area"] = dist_km <= eff_radius
        items.append(item)

    return {"items": items, "total": total, "page": page, "page_size": page_size}

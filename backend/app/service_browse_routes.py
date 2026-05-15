from math import radians, cos, sqrt, sin, atan2
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, or_, select, case, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.async_routers import get_current_user_secure_async_csrf
from app.deps import get_async_db_dependency
from app.models_expert import Expert
from app.forum_routes import get_current_user_optional
from app.utils.feed_scoring import (
    compute_score_with_prefs,
    load_user_personalization_context,
)

service_browse_router = APIRouter(
    prefix="/api/services",
    tags=["service-browse"],
)

# recommended 排序时,在 Python 层个性化打分前先按时间倒序拉取的最大候选数
# 超出此值的服务会被截断（避免无界扫描）。当前规模下 500 足够。
_RECOMMEND_CANDIDATE_CAP = 500


@service_browse_router.get("/browse")
async def browse_services(
    type: str = Query("all", pattern="^(all|expert|personal)$"),
    q: str = Query(None, max_length=100),
    sort: str = Query("recommended", pattern="^(recommended|newest|price_asc|price_desc|nearby)$"),
    lat: float = Query(None),
    lng: float = Query(None),
    radius: int = Query(25, ge=1, le=100),
    city: Optional[str] = Query(None, max_length=100, description="同城模式：传入城市名时按城市名过滤（in_person/both 服务），覆盖 radius/lat/lng"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
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

    # Apply filters (including nearby/city) before counting
    query = base_filter
    distance_sq = None  # will be set if sort == "nearby" 且非同城模式

    if city:
        # 同城模式：按 city_canonical 索引等值匹配，不依赖 GPS。优先级高于 radius/lat/lng。
        # 输入 city 先 canonicalize（Camden → London），命中已知城市走索引，
        # 罕见/未知城市回退 ILIKE 兼容（与 build_city_location_filter 同语义）。
        from app.utils.city_filter_utils import (
            build_city_location_filter,
            resolve_city_canonical,
        )

        query = query.outerjoin(Expert, or_(
            and_(S.owner_type == 'expert', S.owner_id == Expert.id),
            and_(S.owner_type.is_(None), S.expert_id == Expert.id),
        ))
        # 仅 in_person/both 服务参与地理筛（online 服务不属于"同城"语义）
        query = query.where(S.location_type.in_(["in_person", "both"]))

        canonical = resolve_city_canonical(city)
        if canonical:
            # service.city_canonical 优先，回退 expert.city_canonical（达人服务继承团队地址）
            query = query.where(or_(
                S.city_canonical == canonical,
                Expert.city_canonical == canonical,
            ))
        else:
            s_filter = build_city_location_filter(S.location, city)
            e_filter = build_city_location_filter(Expert.location, city)
            if s_filter is not None and e_filter is not None:
                query = query.where(or_(s_filter, e_filter))
            elif s_filter is not None:
                query = query.where(s_filter)
            elif e_filter is not None:
                query = query.where(e_filter)
    elif sort == "nearby":
        if lat is None or lng is None:
            raise HTTPException(status_code=400, detail="lat and lng required for nearby sort")

        # LEFT JOIN experts to get fallback lat/lng for services that inherit team address
        # 兼容旧数据: owner_type=NULL 时回退到 legacy expert_id
        query = query.outerjoin(Expert, or_(
            and_(S.owner_type == 'expert', S.owner_id == Expert.id),
            and_(S.owner_type.is_(None), S.expert_id == Expert.id),
        ))

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

    # 已登录 + recommended → 走 Python 端个性化打分（共享 feed_scoring）
    # 匿名或其他排序模式 → 沿用 SQL 层排序+分页（高效，无个性化）
    use_python_recommend = sort == "recommended" and current_user is not None

    # 已登录时, outerjoin ServiceFavorite 让"收藏置顶"作为最高优先级 ORDER BY。
    # count_query 已在 line 96 snapshot, 所以加 join 不影响 total。
    favorited_first = None
    if current_user is not None:
        SF = models.ServiceFavorite
        query = query.outerjoin(SF, and_(
            SF.service_id == S.id,
            SF.user_id == current_user.id,
        ))
        favorited_first = case((SF.id.isnot(None), 0), else_=1)

    if use_python_recommend:
        # 用 created_at DESC + 达人优先做候选筛选，限制总量后在 Python 层重排
        order_clauses = [
            case((S.service_type == "expert", 0), else_=1),
            S.created_at.desc(),
        ]
        if favorited_first is not None:
            order_clauses.insert(0, favorited_first)
        query = query.order_by(*order_clauses).limit(_RECOMMEND_CANDIDATE_CAP)
    else:
        order_clauses = []
        if favorited_first is not None:
            order_clauses.append(favorited_first)
        if sort == "recommended":
            order_clauses.extend([
                case((S.service_type == "expert", 0), else_=1),
                S.created_at.desc(),
            ])
        elif sort == "newest":
            order_clauses.append(S.created_at.desc())
        elif sort == "price_asc":
            # P1 D.P1.3: 议价 (base_price=NULL) 排末尾, 不让它们堆到最低价位置误导用户
            order_clauses.append(S.base_price.is_(None))
            order_clauses.append(S.base_price.asc())
        elif sort == "price_desc":
            order_clauses.append(S.base_price.is_(None))
            order_clauses.append(S.base_price.desc())
        elif sort == "nearby":
            if distance_sq is not None:
                order_clauses.append(distance_sq.asc())
            else:
                # 同城模式接管了 nearby（distance_sq 未计算），改按最新排
                order_clauses.append(S.created_at.desc())

        query = query.order_by(*order_clauses)

        offset = (page - 1) * page_size
        query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    services = result.scalars().all()

    service_ids = [s.id for s in services]

    # Batch-load 服务维度的 (review_count, avg_rating).
    # Review 表绑 task_id, 通过 Task.expert_service_id 反查到服务维度。
    # 一次 SQL 同时拿 count + avg, 避免两次 round trip。
    service_stats_map: dict[int, tuple[int, float | None]] = {}
    if service_ids:
        stats_rows = await db.execute(
            select(
                models.Task.expert_service_id,
                func.count(models.Review.id),
                func.avg(models.Review.rating),
            )
            .join(models.Review, models.Review.task_id == models.Task.id)
            .where(
                models.Task.expert_service_id.in_(service_ids),
                models.Task.status == "completed",
                models.Review.is_deleted.is_(False),
            )
            .group_by(models.Task.expert_service_id)
        )
        for row in stats_rows.all():
            sid, cnt, avg = row[0], row[1], row[2]
            service_stats_map[sid] = (
                int(cnt or 0),
                float(avg) if avg is not None else None,
            )

    # Batch-load 当前用户已收藏的 service_ids (匿名时跳过)
    favorited_set: set[int] = set()
    if current_user is not None and service_ids:
        fav_rows = await db.execute(
            select(models.ServiceFavorite.service_id).where(
                models.ServiceFavorite.user_id == current_user.id,
                models.ServiceFavorite.service_id.in_(service_ids),
            )
        )
        favorited_set = {row[0] for row in fav_rows.all()}

    # Batch-load owner user info for personal services (avoid N+1)
    user_owner_ids = {s.owner_id for s in services if s.owner_type == 'user' and s.owner_id}
    owners_map = {}
    if user_owner_ids:
        owners_result = await db.execute(
            select(models.User).where(models.User.id.in_(list(user_owner_ids)))
        )
        for u in owners_result.scalars().all():
            owners_map[u.id] = u

    # Batch-load expert teams for owner info + location fallback
    # 兼容旧数据: owner_type=NULL 时回退到 legacy expert_id
    expert_owner_ids = set()
    for s in services:
        if s.owner_type == 'expert' and s.owner_id:
            expert_owner_ids.add(s.owner_id)
        elif s.owner_type is None and s.expert_id:
            expert_owner_ids.add(s.expert_id)
    experts_map = {}
    if expert_owner_ids:
        experts_result = await db.execute(
            select(Expert).where(Expert.id.in_(list(expert_owner_ids)))
        )
        for e in experts_result.scalars().all():
            experts_map[e.id] = e

    items = []
    for s in services:
        # Resolve owner info: personal → User, expert → Expert team
        # 兼容旧数据: owner_type=NULL 时用 expert_id 查找
        _expert_key = s.owner_id if s.owner_type == 'expert' else (s.expert_id if s.owner_type is None else None)
        expert = experts_map.get(_expert_key) if _expert_key else None
        if s.owner_type == 'user' and s.owner_id:
            owner = owners_map.get(s.owner_id)
            owner_resolved = owner is not None
            owner_name = owner.name if owner else "Unknown"
            owner_avatar = owner.avatar if owner else None
            owner_rating = float(owner.avg_rating) if owner and owner.avg_rating else None
        elif expert:
            owner_resolved = True
            owner_name = expert.name or "Unknown"
            owner_avatar = expert.avatar
            owner_rating = float(expert.rating) if expert.rating else None
        else:
            owner_resolved = False
            owner_name = "Unknown"
            owner_avatar = None
            owner_rating = None

        # Fallback to expert team values when service's own values are null
        eff_lat = float(s.latitude) if s.latitude else (float(expert.latitude) if expert and expert.latitude else None)
        eff_lng = float(s.longitude) if s.longitude else (float(expert.longitude) if expert and expert.longitude else None)
        eff_radius = s.service_radius_km if s.service_radius_km is not None else (expert.service_radius_km if expert else None)

        item = {
            "id": s.id,
            "service_name": s.service_name,
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            # Flutter 端用 name/name_zh/name_en 读取，加别名兼容
            "name": s.service_name,
            "name_en": s.service_name_en,
            "name_zh": s.service_name_zh,
            "description": s.description,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
            "base_price": float(s.base_price) if s.base_price else 0,
            "package_price": float(s.package_price) if s.package_price else None,
            "price": float(s.package_price or s.base_price) if (s.package_price or s.base_price) else 0,
            "currency": s.currency or "GBP",
            "pricing_type": s.pricing_type or "fixed",
            "location_type": s.location_type or "online",
            "location": s.location,
            "service_type": s.service_type or "expert",
            "is_expert_verified": s.service_type == "expert",
            "status": s.status,
            "images": s.images or [],
            "skills": s.skills or [],
            "owner_type": s.owner_type or "user",
            "owner_id": s.owner_id or "",
            "owner_name": owner_name,
            "owner_avatar": owner_avatar,
            "owner_rating": owner_rating,
            # Display identity fields (Task 3)
            "display_name": owner_name if owner_resolved else "",
            "display_avatar": owner_avatar if owner_resolved else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "service_radius_km": eff_radius,
            "package_type": s.package_type,
            "total_sessions": s.total_sessions,
            "linked_service_id": s.linked_service_id,
            "review_count": service_stats_map.get(s.id, (0, None))[0],
            "service_rating": service_stats_map.get(s.id, (0, None))[1],
            "is_favorited": s.id in favorited_set,
        }
        if lat is not None and lng is not None and eff_lat is not None and eff_lng is not None:
            # Haversine formula — consistent with task distance calculation
            dlat = radians(eff_lat - lat)
            dlng = radians(eff_lng - lng)
            a = sin(dlat / 2) ** 2 + cos(radians(lat)) * cos(radians(eff_lat)) * sin(dlng / 2) ** 2
            dist_km = 6371.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
            item["distance_km"] = round(dist_km, 1)
            if eff_radius is None or eff_radius == 0 or s.location_type == "online":
                item["within_service_area"] = True
            else:
                item["within_service_area"] = dist_km <= eff_radius
        items.append(item)

    # 已登录 + recommended: Python 端个性化打分排序 + 分页
    if use_python_recommend and items:
        ctx = await load_user_personalization_context(db, current_user)
        prefs = set(ctx["user_prefs"])
        cv = ctx["city_variants"]
        interests = ctx["user_interest_types"]

        # services 与 items 长度/顺序一致，zip 取 SQLA 对象的 category 字段
        for it, s in zip(items, services):
            score_view = {
                "feed_type": "service",
                "title": it.get("service_name") or "",
                "description": it.get("description") or "",
                "rating": it.get("owner_rating"),
                "view_count": 0,
                "created_at": it.get("created_at"),
                "extra_data": {
                    "category": s.category,
                    "location": it.get("location"),
                },
            }
            it["_score"] = compute_score_with_prefs(score_view, prefs, cv, interests)
            # 命中"同城"时回传 reason_code，前端可显示同城标签
            rc = score_view["extra_data"].get("reason_code")
            if rc:
                it["reason_code"] = rc

        # 收藏置顶 + _score DESC (元组排序: False < True, 已收藏在前用 not is_favorited)
        items.sort(key=lambda it: (not it.get("is_favorited", False), -it.get("_score", 0)))
        for it in items:
            it.pop("_score", None)

        # 候选被截断时，total 也要 cap 住，避免客户端按 total/page_size 翻到空页
        if total > _RECOMMEND_CANDIDATE_CAP:
            total = _RECOMMEND_CANDIDATE_CAP

        offset = (page - 1) * page_size
        items = items[offset:offset + page_size]

    return {"items": items, "total": total, "page": page, "page_size": page_size}


# ==================== POST /api/services/{service_id}/favorite ====================

@service_browse_router.post("/{service_id}/favorite")
async def toggle_service_favorite(
    service_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """切换服务收藏状态。返回新的 is_favorited + favorite_count。"""
    service = await db.get(models.TaskExpertService, service_id)
    if service is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在"
        )

    SF = models.ServiceFavorite
    existing = await db.execute(
        select(SF).where(
            SF.user_id == current_user.id,
            SF.service_id == service_id,
        )
    )
    existing_row = existing.scalar_one_or_none()

    if existing_row is not None:
        await db.delete(existing_row)
        await db.commit()
        is_favorited = False
    else:
        try:
            db.add(SF(user_id=current_user.id, service_id=service_id))
            await db.commit()
            is_favorited = True
        except IntegrityError:
            # 并发场景: 另一个请求刚好插入了同一行 → 视为已收藏
            await db.rollback()
            is_favorited = True

    fav_count_row = await db.execute(
        select(func.count(SF.id)).where(SF.service_id == service_id)
    )
    favorite_count = int(fav_count_row.scalar() or 0)

    return {
        "is_favorited": is_favorited,
        "favorite_count": favorite_count,
    }

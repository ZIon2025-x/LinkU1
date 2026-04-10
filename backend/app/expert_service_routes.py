"""达人团队服务管理路由"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import Expert, ExpertMember
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_service_router = APIRouter(
    prefix="/api/experts/{expert_id}/services",
    tags=["expert-services"],
)


async def _validate_bundle_service_ids(
    db: AsyncSession,
    expert_id: str,
    bundle_service_ids: Optional[List[int]],
    exclude_service_id: Optional[int] = None,
) -> None:
    """运行时校验 bundle 套餐引用的服务都存在,且同属当前团队、不是 deleted/bundle 自身。"""
    if not bundle_service_ids:
        return
    # 去重
    ids = list(set(bundle_service_ids))
    rows = await db.execute(
        select(models.TaskExpertService.id, models.TaskExpertService.status, models.TaskExpertService.package_type)
        .where(
            and_(
                models.TaskExpertService.id.in_(ids),
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    found = {row.id: (row.status, row.package_type) for row in rows.all()}
    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_service_not_found",
            "message": f"引用的服务不存在或不属于本团队: {missing}",
        })
    bad_status = [i for i, (s, _) in found.items() if s == "deleted"]
    if bad_status:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_service_deleted",
            "message": f"引用的服务已被删除: {bad_status}",
        })
    bad_type = [i for i, (_, pt) in found.items() if pt == "bundle"]
    if bad_type:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_nested",
            "message": f"bundle 套餐不能嵌套引用其他 bundle: {bad_type}",
        })
    if exclude_service_id and exclude_service_id in ids:
        raise HTTPException(status_code=422, detail={
            "error_code": "bundle_self_reference",
            "message": "bundle 不能引用自身",
        })


@expert_service_router.get("", response_model=List[dict])
async def list_expert_services(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取达人团队的服务列表（公开）"""
    await _get_expert_or_404(db, expert_id)

    query = select(models.TaskExpertService).where(
        and_(
            models.TaskExpertService.owner_type == "expert",
            models.TaskExpertService.owner_id == expert_id,
        )
    )
    # 只有团队 Owner/Admin 可以看到非 active 服务
    is_team_manager = False
    if current_user:
        from app.models_expert import ExpertMember
        mgr_check = await db.execute(
            select(ExpertMember).where(
                and_(
                    ExpertMember.expert_id == expert_id,
                    ExpertMember.user_id == current_user.id,
                    ExpertMember.status == "active",
                    ExpertMember.role.in_(["owner", "admin"]),
                )
            )
        )
        is_team_manager = mgr_check.scalar_one_or_none() is not None

    if is_team_manager:
        if status_filter:
            query = query.where(models.TaskExpertService.status == status_filter)
        # manager 无 filter 时看全部
    else:
        query = query.where(models.TaskExpertService.status == "active")

    query = query.order_by(
        models.TaskExpertService.display_order.asc(),
        models.TaskExpertService.created_at.desc(),
    ).offset(offset).limit(limit)

    result = await db.execute(query)
    services = result.scalars().all()

    return [
        {
            "id": s.id,
            "service_name": s.service_name,
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            "description": s.description,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency,
            "pricing_type": s.pricing_type,
            "location_type": s.location_type,
            "location": s.location,
            "category": s.category,
            "images": s.images,
            "skills": s.skills,
            "status": s.status,
            "has_time_slots": s.has_time_slots,
            "package_type": s.package_type,
            "total_sessions": s.total_sessions,
            "bundle_service_ids": s.bundle_service_ids,
            "service_radius_km": s.service_radius_km,
            "view_count": s.view_count or 0,
            "application_count": s.application_count or 0,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "owner_type": s.owner_type,
            "owner_id": s.owner_id,
        }
        for s in services
    ]


@expert_service_router.post("", status_code=201)
async def create_expert_service(
    expert_id: str,
    body: schemas.TaskExpertServiceCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建达人服务（Owner/Admin，无需审核）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    if not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing services",
        })

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=422, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team services only support GBP currently",
        })

    # bundle 套餐: 校验引用的服务存在且同属
    if body.package_type == "bundle":
        await _validate_bundle_service_ids(db, expert_id, body.bundle_service_ids)

    data = body.model_dump(exclude_unset=True)
    service = models.TaskExpertService(
        owner_type="expert",
        owner_id=expert_id,
        expert_id=None,
        service_type="expert",
        user_id=None,
        status="active",
        **data,
    )
    # Null out service_radius_km for online services
    if service.location_type == "online":
        service.service_radius_km = None

    db.add(service)
    expert.total_services = (expert.total_services or 0) + 1
    expert.updated_at = get_utc_time()
    await db.commit()
    await db.refresh(service)
    return {"id": service.id, "status": service.status}


@expert_service_router.get("/{service_id}")
async def get_expert_service_detail(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情（公开）"""
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service or service.status == "deleted":
        raise HTTPException(status_code=404, detail="服务不存在")

    service.view_count = (service.view_count or 0) + 1
    await db.commit()

    return {
        "id": service.id,
        "service_name": service.service_name,
        "service_name_en": service.service_name_en,
        "service_name_zh": service.service_name_zh,
        "description": service.description,
        "description_en": service.description_en,
        "description_zh": service.description_zh,
        "base_price": float(service.base_price) if service.base_price else 0,
        "currency": service.currency,
        "pricing_type": service.pricing_type,
        "location_type": service.location_type,
        "location": service.location,
        "latitude": float(service.latitude) if service.latitude else None,
        "longitude": float(service.longitude) if service.longitude else None,
        "category": service.category,
        "images": service.images,
        "skills": service.skills,
        "status": service.status,
        "display_order": service.display_order,
        "has_time_slots": service.has_time_slots,
        "time_slot_duration_minutes": service.time_slot_duration_minutes,
        "participants_per_slot": service.participants_per_slot,
        "weekly_time_slot_config": service.weekly_time_slot_config,
        "package_type": service.package_type,
        "total_sessions": service.total_sessions,
        "bundle_service_ids": service.bundle_service_ids,
        "service_radius_km": service.service_radius_km,
        "view_count": service.view_count or 0,
        "application_count": service.application_count or 0,
        "created_at": service.created_at.isoformat() if service.created_at else None,
        "updated_at": service.updated_at.isoformat() if service.updated_at else None,
        "owner_type": service.owner_type,
        "owner_id": service.owner_id,
    }


@expert_service_router.put("/{service_id}")
async def update_expert_service(
    expert_id: str,
    service_id: int,
    body: schemas.TaskExpertServiceUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人服务（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    update_data = body.model_dump(exclude_unset=True)

    # bundle 套餐: 如果新的 package_type 是 bundle 或 bundle_service_ids 被更新,执行校验
    new_package_type = update_data.get("package_type", service.package_type)
    new_bundle_ids = update_data.get("bundle_service_ids", service.bundle_service_ids)
    if new_package_type == "bundle" and ("bundle_service_ids" in update_data or "package_type" in update_data):
        await _validate_bundle_service_ids(
            db, expert_id, new_bundle_ids, exclude_service_id=service_id
        )

    for field, value in update_data.items():
        if hasattr(service, field):
            setattr(service, field, value)

    # Null out service_radius_km if location_type changed to online
    if service.location_type == "online":
        service.service_radius_km = None

    service.updated_at = get_utc_time()
    await db.commit()
    return {"id": service.id, "status": service.status}


@expert_service_router.delete("/{service_id}")
async def delete_expert_service(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """删除达人服务（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    # 软删除: 保留历史 ServiceApplication / Review / Task 关联,
    # 仅把 status 改为 'deleted',下架展示。
    if service.status == "deleted":
        return {"detail": "服务已删除"}

    # A3: Activity.expert_service_id FK 是 RESTRICT — 若有 active 活动引用此服务,
    # 拒绝删除并提示用户先处理。
    from sqlalchemy import func as _func
    active_act_q = select(_func.count(models.Activity.id)).where(
        and_(
            models.Activity.expert_service_id == service_id,
            models.Activity.status.in_(["open", "in_progress"]),
        )
    )
    active_count = (await db.execute(active_act_q)).scalar() or 0
    if active_count > 0:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "service_has_active_activities",
                "message": f"该服务还有 {active_count} 个进行中的活动,请先取消或完成后再删除",
                "active_activities": active_count,
            },
        )

    # in-flight ServiceApplication 检查 — 防止 buyer 处于"申请中但服务消失"的状态
    active_app_q = select(_func.count(models.ServiceApplication.id)).where(
        and_(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.status.in_(
                ["pending", "consulting", "negotiating", "price_agreed", "approved"]
            ),
        )
    )
    active_app_count = (await db.execute(active_app_q)).scalar() or 0
    if active_app_count > 0:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "service_has_active_applications",
                "message": f"该服务还有 {active_app_count} 个进行中的申请,请先处理后再删除",
                "active_applications": active_app_count,
            },
        )

    was_active = service.status == "active"
    service.status = "deleted"
    service.updated_at = get_utc_time()
    if was_active:
        expert.total_services = max((expert.total_services or 1) - 1, 0)
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "服务已删除"}

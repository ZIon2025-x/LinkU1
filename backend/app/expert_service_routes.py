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

    if status_filter and is_team_manager:
        query = query.where(models.TaskExpertService.status == status_filter)
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
    if not service:
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
    for field, value in update_data.items():
        if hasattr(service, field):
            setattr(service, field, value)
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

    await db.delete(service)
    expert.total_services = max((expert.total_services or 1) - 1, 0)
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "服务已删除"}

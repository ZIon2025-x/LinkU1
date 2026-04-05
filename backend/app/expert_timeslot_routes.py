"""达人服务时间段管理路由"""
import logging
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, delete as sql_delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import Expert
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_timeslot_router = APIRouter(
    prefix="/api/experts/{expert_id}/services/{service_id}/time-slots",
    tags=["expert-time-slots"],
)

# Public time slot router (no expert auth needed)
public_service_router = APIRouter(tags=["public-services"])


async def _get_expert_service(db, expert_id, service_id):
    """Verify service belongs to expert team"""
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
        raise HTTPException(status_code=404, detail="服务不存在或不属于此团队")
    return service


@expert_timeslot_router.get("")
async def list_service_time_slots(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取服务时间段列表（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    await _get_expert_service(db, expert_id, service_id)

    result = await db.execute(
        select(models.ServiceTimeSlot)
        .where(
            and_(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
        .order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    )
    slots = result.scalars().all()
    return [
        {
            "id": s.id,
            "service_id": s.service_id,
            "slot_start_datetime": s.slot_start_datetime.isoformat() if s.slot_start_datetime else None,
            "slot_end_datetime": s.slot_end_datetime.isoformat() if s.slot_end_datetime else None,
            "price_per_participant": float(s.price_per_participant) if s.price_per_participant else None,
            "max_participants": s.max_participants,
            "current_participants": s.current_participants,
            "is_available": s.is_available,
        }
        for s in slots
    ]


@expert_timeslot_router.post("", status_code=201)
async def create_time_slot(
    expert_id: str,
    service_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建时间段（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    service = await _get_expert_service(db, expert_id, service_id)

    slot = models.ServiceTimeSlot(
        service_id=service_id,
        slot_start_datetime=datetime.fromisoformat(body['slot_start_datetime']),
        slot_end_datetime=datetime.fromisoformat(body['slot_end_datetime']),
        price_per_participant=body.get('price_per_participant', service.base_price),
        max_participants=body.get('max_participants', service.participants_per_slot or 1),
        is_available=True,
    )
    db.add(slot)
    await db.commit()
    await db.refresh(slot)
    return {"id": slot.id}


@expert_timeslot_router.put("/{slot_id}")
async def update_time_slot(
    expert_id: str,
    service_id: int,
    slot_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新时间段（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    await _get_expert_service(db, expert_id, service_id)

    result = await db.execute(
        select(models.ServiceTimeSlot).where(
            and_(models.ServiceTimeSlot.id == slot_id, models.ServiceTimeSlot.service_id == service_id)
        )
    )
    slot = result.scalar_one_or_none()
    if not slot:
        raise HTTPException(status_code=404, detail="时间段不存在")

    for field in ['price_per_participant', 'max_participants', 'is_available']:
        if field in body:
            setattr(slot, field, body[field])
    if 'slot_start_datetime' in body:
        slot.slot_start_datetime = datetime.fromisoformat(body['slot_start_datetime'])
    if 'slot_end_datetime' in body:
        slot.slot_end_datetime = datetime.fromisoformat(body['slot_end_datetime'])
    slot.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "已更新"}


@expert_timeslot_router.delete("/by-date")
async def delete_time_slots_by_date(
    expert_id: str,
    service_id: int,
    request: Request,
    slot_date: str = Query(..., description="日期 (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """按日期删除时间段（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    await _get_expert_service(db, expert_id, service_id)

    try:
        from datetime import date, time as dt_time
        from app.utils.time_utils import parse_local_as_utc, LONDON
        date_obj = date.fromisoformat(slot_date)
        day_start = parse_local_as_utc(datetime.combine(date_obj, dt_time.min), LONDON)
        day_end = parse_local_as_utc(datetime.combine(date_obj, dt_time.max), LONDON)
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式无效，请使用 YYYY-MM-DD")

    result = await db.execute(
        select(models.ServiceTimeSlot).where(
            and_(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.slot_start_datetime >= day_start,
                models.ServiceTimeSlot.slot_start_datetime <= day_end,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
    )
    slots = result.scalars().all()
    now = get_utc_time()
    for s in slots:
        s.is_manually_deleted = True
        s.is_available = False
        s.updated_at = now
    await db.commit()
    return {"detail": f"已删除 {len(slots)} 个时间段"}


@expert_timeslot_router.delete("/{slot_id}")
async def delete_time_slot(
    expert_id: str,
    service_id: int,
    slot_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """删除时间段（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    await _get_expert_service(db, expert_id, service_id)

    result = await db.execute(
        select(models.ServiceTimeSlot).where(
            and_(models.ServiceTimeSlot.id == slot_id, models.ServiceTimeSlot.service_id == service_id)
        )
    )
    slot = result.scalar_one_or_none()
    if not slot:
        raise HTTPException(status_code=404, detail="时间段不存在")

    slot.is_manually_deleted = True
    slot.is_available = False
    slot.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "已删除"}


@expert_timeslot_router.post("/batch-create", status_code=201)
async def batch_create_time_slots(
    expert_id: str,
    service_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """批量创建时间段（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
    service = await _get_expert_service(db, expert_id, service_id)

    slots_data = body.get('slots', [])
    if not slots_data:
        raise HTTPException(status_code=400, detail="缺少 slots 数据")

    created_ids = []
    skipped = 0
    for slot_data in slots_data:
        try:
            start_dt = datetime.fromisoformat(slot_data['slot_start_datetime'])
            end_dt = datetime.fromisoformat(slot_data['slot_end_datetime'])
        except (KeyError, ValueError):
            raise HTTPException(status_code=400, detail="时间段数据格式无效")

        # Check for duplicate (unique constraint: service_id + start + end)
        existing = await db.execute(
            select(models.ServiceTimeSlot).where(
                and_(
                    models.ServiceTimeSlot.service_id == service_id,
                    models.ServiceTimeSlot.slot_start_datetime == start_dt,
                    models.ServiceTimeSlot.slot_end_datetime == end_dt,
                    models.ServiceTimeSlot.is_manually_deleted == False,
                )
            )
        )
        if existing.scalar_one_or_none():
            skipped += 1
            continue

        slot = models.ServiceTimeSlot(
            service_id=service_id,
            slot_start_datetime=start_dt,
            slot_end_datetime=end_dt,
            price_per_participant=slot_data.get('price_per_participant', service.base_price),
            max_participants=slot_data.get('max_participants', service.participants_per_slot or 1),
            is_available=True,
        )
        db.add(slot)
        await db.flush()
        created_ids.append(slot.id)

    await db.commit()
    return {"created": len(created_ids), "skipped": skipped, "ids": created_ids}


# ==================== Public service endpoints ====================

@public_service_router.get("/api/services/{service_id}/time-slots")
async def get_public_service_time_slots(
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """公开获取服务时间段"""
    service_result = await db.execute(
        select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    result = await db.execute(
        select(models.ServiceTimeSlot)
        .where(
            and_(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.is_available == True,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
        .order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    )
    slots = result.scalars().all()
    return [
        {
            "id": s.id,
            "service_id": s.service_id,
            "slot_start_datetime": s.slot_start_datetime.isoformat() if s.slot_start_datetime else None,
            "slot_end_datetime": s.slot_end_datetime.isoformat() if s.slot_end_datetime else None,
            "price_per_participant": float(s.price_per_participant) if s.price_per_participant else None,
            "max_participants": s.max_participants,
            "current_participants": s.current_participants,
            "is_available": s.is_available,
        }
        for s in slots
    ]

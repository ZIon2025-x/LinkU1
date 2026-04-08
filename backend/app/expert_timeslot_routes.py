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

@public_service_router.get(
    "/api/services/{service_id}/time-slots",
    response_model=List[schemas.ServiceTimeSlotOut],
)
async def get_public_service_time_slots(
    service_id: int,
    request: Request,
    start_date: Optional[str] = Query(None, description="开始日期，格式：YYYY-MM-DD"),
    end_date: Optional[str] = Query(None, description="结束日期，格式：YYYY-MM-DD"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """公开获取服务时间段（含关门日过滤、user_has_applied 标记、动态参与者计数）

    可选认证：登录用户会标记已申请的时间段。
    """
    service_result = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .where(models.TaskExpertService.status == "active")
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在或未上架")

    if not service.has_time_slots:
        return []

    from datetime import date as dt_date, time as dt_time
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from sqlalchemy.orm import selectinload
    from app.models import Task, TaskParticipant, TaskTimeSlotRelation

    query = (
        select(models.ServiceTimeSlot)
        .where(
            and_(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
        .options(
            selectinload(models.ServiceTimeSlot.activity_relations).selectinload(
                models.ActivityTimeSlotRelation.activity
            ),
            selectinload(models.ServiceTimeSlot.task_relations),
        )
    )

    start_date_obj = None
    end_date_obj = None
    if start_date:
        try:
            start_date_obj = dt_date.fromisoformat(start_date)
            start_local = datetime.combine(start_date_obj, dt_time(0, 0, 0))
            start_utc = parse_local_as_utc(start_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime >= start_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    if end_date:
        try:
            end_date_obj = dt_date.fromisoformat(end_date)
            end_local = datetime.combine(end_date_obj, dt_time(23, 59, 59))
            end_utc = parse_local_as_utc(end_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime <= end_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")

    query = query.order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    result = await db.execute(query)
    time_slots = result.scalars().all()

    # 动态参与者计数（排除已取消任务）
    from sqlalchemy import func as _func
    if time_slots:
        slot_ids = [s.id for s in time_slots]
        rel_q = (
            select(TaskTimeSlotRelation, Task)
            .join(Task, TaskTimeSlotRelation.task_id == Task.id)
            .where(
                TaskTimeSlotRelation.time_slot_id.in_(slot_ids),
                Task.status != "cancelled",
            )
        )
        rel_res = await db.execute(rel_q)
        tasks_by_slot: dict = {}
        for rr in rel_res.all():
            if hasattr(rr, "TaskTimeSlotRelation"):
                sid = rr.TaskTimeSlotRelation.time_slot_id
                t = rr.Task
            else:
                sid = rr[0].time_slot_id
                t = rr[1]
            tasks_by_slot.setdefault(sid, []).append(t)

        multi_task_ids = [t.id for ts in tasks_by_slot.values() for t in ts if t.is_multi_participant]
        participants_count_by_task: dict = {}
        if multi_task_ids:
            pc_q = (
                select(TaskParticipant.task_id, _func.count(TaskParticipant.id).label("count"))
                .where(
                    TaskParticipant.task_id.in_(multi_task_ids),
                    TaskParticipant.status.in_(["accepted", "in_progress", "completed"]),
                )
                .group_by(TaskParticipant.task_id)
            )
            pc_res = await db.execute(pc_q)
            for pr in pc_res:
                participants_count_by_task[pr.task_id] = pr.count

        for slot in time_slots:
            actual = 0
            for t in tasks_by_slot.get(slot.id, []):
                if t.is_multi_participant:
                    actual += participants_count_by_task.get(t.id, 0)
                elif t.status in ("open", "taken", "in_progress"):
                    actual += 1
            slot.current_participants = actual

    # 关门日期过滤
    # service.expert_id 是 legacy 字段（=user_id）；服务可能是 expert 团队拥有，也可能是个人。
    # 我们查 owner_id（团队 ID）下的关门日。
    closed_date_set: set = set()
    if service.owner_type == "expert" and service.owner_id:
        cd_q = select(models.ExpertClosedDate).where(
            models.ExpertClosedDate.expert_id == service.owner_id
        )
        if start_date_obj:
            cd_q = cd_q.where(models.ExpertClosedDate.closed_date >= start_date_obj)
        if end_date_obj:
            cd_q = cd_q.where(models.ExpertClosedDate.closed_date <= end_date_obj)
        cd_res = await db.execute(cd_q)
        closed_date_set = {cd.closed_date for cd in cd_res.scalars().all()}

    filtered_slots = []
    for slot in time_slots:
        slot_date_local = slot.slot_start_datetime.astimezone(LONDON).date()
        if slot_date_local not in closed_date_set:
            filtered_slots.append(slot)

    # 当前用户已申请的时间段
    user_applied_slot_ids: set = set()
    if current_user:
        applied_q = select(models.ServiceApplication.time_slot_id).where(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.applicant_id == current_user.id,
            models.ServiceApplication.time_slot_id.isnot(None),
            models.ServiceApplication.status.in_(
                ["pending", "negotiating", "price_agreed", "approved"]
            ),
        )
        applied_res = await db.execute(applied_q)
        user_applied_slot_ids = {row[0] for row in applied_res.all()}

    out = []
    for slot in filtered_slots:
        slot_out = schemas.ServiceTimeSlotOut.from_orm(slot)
        slot_out.user_has_applied = slot.id in user_applied_slot_ids
        out.append(slot_out)
    return out

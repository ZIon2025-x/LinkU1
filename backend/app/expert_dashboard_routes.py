"""达人面板/统计/关门日期路由"""
import logging
from typing import List, Optional
from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func
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

expert_dashboard_router = APIRouter(
    prefix="/api/experts/{expert_id}",
    tags=["expert-dashboard"],
)


@expert_dashboard_router.get("/dashboard/stats", response_model=schemas.ExpertDashboardStatsOut)
async def get_dashboard_stats(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人面板统计"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id)

    # 服务总数
    total_services_result = await db.execute(
        select(func.count()).select_from(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    total_services = total_services_result.scalar_one()

    # 上架中服务数
    active_services_result = await db.execute(
        select(func.count()).select_from(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.TaskExpertService.status == "active",
            )
        )
    )
    active_services = active_services_result.scalar_one()

    # 申请总数 & 待处理数
    total_apps_result = await db.execute(
        select(func.count()).select_from(models.ServiceApplication).where(
            models.ServiceApplication.new_expert_id == expert_id
        )
    )
    total_applications = total_apps_result.scalar_one()

    pending_apps_result = await db.execute(
        select(func.count()).select_from(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.new_expert_id == expert_id,
                models.ServiceApplication.status.in_(["pending", "negotiating", "consulting"]),
            )
        )
    )
    pending_applications = pending_apps_result.scalar_one()

    # 即将到来的时间段（未过期、未删除）
    now = get_utc_time()
    upcoming_slots_result = await db.execute(
        select(func.count()).select_from(models.ServiceTimeSlot)
        .join(
            models.TaskExpertService,
            models.ServiceTimeSlot.service_id == models.TaskExpertService.id,
        )
        .where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= now,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
    )
    upcoming_time_slots = upcoming_slots_result.scalar_one()

    # 有参与者的未来时间段
    slots_with_participants_result = await db.execute(
        select(func.count()).select_from(models.ServiceTimeSlot)
        .join(
            models.TaskExpertService,
            models.ServiceTimeSlot.service_id == models.TaskExpertService.id,
        )
        .where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= now,
                models.ServiceTimeSlot.current_participants > 0,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
    )
    time_slots_with_participants = slots_with_participants_result.scalar_one()

    # 多人任务统计 — 由该团队成员发起的多人任务
    # NOTE: Task.expert_creator_id 仍 FK 到 users.id（legacy），所以查成员 user_id 列表
    member_ids_result = await db.execute(
        select(ExpertMember.user_id).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.status == "active")
        )
    )
    member_user_ids = [row[0] for row in member_ids_result.all()]

    total_multi_tasks = 0
    in_progress_multi_tasks = 0
    total_participants = 0
    if member_user_ids:
        multi_tasks_result = await db.execute(
            select(func.count()).select_from(models.Task).where(
                and_(
                    models.Task.expert_creator_id.in_(member_user_ids),
                    models.Task.is_multi_participant == True,
                )
            )
        )
        total_multi_tasks = multi_tasks_result.scalar_one()

        in_progress_result = await db.execute(
            select(func.count()).select_from(models.Task).where(
                and_(
                    models.Task.expert_creator_id.in_(member_user_ids),
                    models.Task.is_multi_participant == True,
                    models.Task.status == "in_progress",
                )
            )
        )
        in_progress_multi_tasks = in_progress_result.scalar_one()

        participants_result = await db.execute(
            select(func.count()).select_from(models.TaskParticipant)
            .join(models.Task, models.TaskParticipant.task_id == models.Task.id)
            .where(
                and_(
                    models.Task.expert_creator_id.in_(member_user_ids),
                    models.Task.is_multi_participant == True,
                )
            )
        )
        total_participants = participants_result.scalar_one()

    return {
        "expert_id": expert_id,
        "name": expert.name,
        "rating": float(expert.rating) if expert.rating else 0,
        "total_services": total_services,
        "active_services": active_services,
        "total_applications": total_applications,
        "pending_applications": pending_applications,
        "upcoming_time_slots": upcoming_time_slots,
        "time_slots_with_participants": time_slots_with_participants,
        "total_multi_tasks": total_multi_tasks,
        "in_progress_multi_tasks": in_progress_multi_tasks,
        "total_participants": total_participants,
        "completed_tasks": expert.completed_tasks,
        "completion_rate": expert.completion_rate,
        "member_count": expert.member_count,
    }


@expert_dashboard_router.get("/schedule")
async def get_expert_schedule(
    expert_id: str,
    request: Request,
    start_date: Optional[str] = Query(None, description="开始日期 (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="结束日期 (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人时刻表数据（时间段服务安排）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id)

    from datetime import time as dt_time
    from app.utils.time_utils import parse_local_as_utc, LONDON

    now = get_utc_time()
    if not start_date:
        start_date_obj = now.date()
    else:
        try:
            start_date_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="start_date 格式无效，请使用 YYYY-MM-DD")

    if not end_date:
        end_date_obj = (now + timedelta(days=30)).date()
    else:
        try:
            end_date_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="end_date 格式无效，请使用 YYYY-MM-DD")

    start_datetime = parse_local_as_utc(datetime.combine(start_date_obj, dt_time.min), LONDON)
    end_datetime = parse_local_as_utc(datetime.combine(end_date_obj, dt_time.max), LONDON)

    from sqlalchemy.orm import selectinload
    from app.utils.time_utils import format_iso_utc
    from app.models import Task, TaskParticipant, TaskTimeSlotRelation

    query = (
        select(
            models.ServiceTimeSlot,
            models.TaskExpertService.service_name,
            models.TaskExpertService.id.label("service_id"),
        )
        .join(models.TaskExpertService)
        .where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= start_datetime,
                models.ServiceTimeSlot.slot_start_datetime <= end_datetime,
                models.ServiceTimeSlot.is_manually_deleted == False,
            )
        )
        .options(selectinload(models.ServiceTimeSlot.task_relations))
        .order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    )

    result = await db.execute(query)
    rows = result.all()

    # 实时计算每个时间段的实际参与者数量（排除已取消任务）
    time_slots = [r.ServiceTimeSlot for r in rows]
    tasks_by_slot: dict = {}
    participants_count_by_task: dict = {}
    if time_slots:
        slot_ids = [s.id for s in time_slots]
        rel_q = select(TaskTimeSlotRelation, Task).join(
            Task, TaskTimeSlotRelation.task_id == Task.id
        ).where(
            TaskTimeSlotRelation.time_slot_id.in_(slot_ids),
            Task.status != "cancelled",
        )
        rel_res = await db.execute(rel_q)
        for rel_row in rel_res.all():
            rel = rel_row[0] if not hasattr(rel_row, "TaskTimeSlotRelation") else rel_row.TaskTimeSlotRelation
            t = rel_row[1] if not hasattr(rel_row, "Task") else rel_row.Task
            tasks_by_slot.setdefault(rel.time_slot_id, []).append(t)

        multi_task_ids = [t.id for ts in tasks_by_slot.values() for t in ts if t.is_multi_participant]
        if multi_task_ids:
            pc_q = select(
                TaskParticipant.task_id,
                func.count(TaskParticipant.id).label("count"),
            ).where(
                TaskParticipant.task_id.in_(multi_task_ids),
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"]),
            ).group_by(TaskParticipant.task_id)
            pc_res = await db.execute(pc_q)
            for pr in pc_res:
                participants_count_by_task[pr.task_id] = pr.count

    schedule_items = []
    for row in rows:
        slot = row.ServiceTimeSlot
        actual_participants = 0
        for t in tasks_by_slot.get(slot.id, []):
            if t.is_multi_participant:
                actual_participants += participants_count_by_task.get(t.id, 0)
            elif t.status in ("open", "taken", "in_progress"):
                actual_participants += 1

        slot_start_local = slot.slot_start_datetime.astimezone(LONDON) if slot.slot_start_datetime else None
        slot_end_local = slot.slot_end_datetime.astimezone(LONDON) if slot.slot_end_datetime else None

        schedule_items.append({
            "id": slot.id,
            "slot_id": slot.id,
            "service_id": row.service_id,
            "service_name": row.service_name,
            "slot_start_datetime": format_iso_utc(slot.slot_start_datetime) if slot.slot_start_datetime else None,
            "slot_end_datetime": format_iso_utc(slot.slot_end_datetime) if slot.slot_end_datetime else None,
            "date": slot_start_local.strftime("%Y-%m-%d") if slot_start_local else None,
            "start_time": slot_start_local.strftime("%H:%M") if slot_start_local else None,
            "end_time": slot_end_local.strftime("%H:%M") if slot_end_local else None,
            "current_participants": actual_participants,
            "max_participants": slot.max_participants,
            "is_available": slot.is_available,
            "is_expired": slot.slot_start_datetime < now if slot.slot_start_datetime else False,
        })

    # 多人任务（非固定时间段）— 由该团队成员发起
    member_ids_result = await db.execute(
        select(ExpertMember.user_id).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.status == "active")
        )
    )
    member_user_ids = [r[0] for r in member_ids_result.all()]

    if member_user_ids:
        multi_tasks_q = select(Task).where(
            and_(
                Task.expert_creator_id.in_(member_user_ids),
                Task.is_multi_participant == True,
                Task.is_fixed_time_slot == False,
                Task.status.in_(["open", "in_progress"]),
                Task.deadline >= start_datetime,
                Task.deadline <= end_datetime,
            )
        ).order_by(Task.deadline.asc())
        mt_res = await db.execute(multi_tasks_q)
        multi_tasks = mt_res.scalars().all()

        mt_ids = [t.id for t in multi_tasks]
        task_participants_count: dict = {}
        if mt_ids:
            pc_q = select(
                TaskParticipant.task_id,
                func.count(TaskParticipant.id).label("count"),
            ).where(
                TaskParticipant.task_id.in_(mt_ids),
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"]),
            ).group_by(TaskParticipant.task_id)
            pc_res = await db.execute(pc_q)
            for pr in pc_res:
                task_participants_count[pr.task_id] = pr.count

        for t in multi_tasks:
            if not t.deadline:
                continue
            deadline_local = t.deadline.astimezone(LONDON)
            schedule_items.append({
                "id": f"task_{t.id}",
                "service_id": t.expert_service_id,
                "service_name": t.title,
                "slot_start_datetime": None,
                "slot_end_datetime": None,
                "date": deadline_local.strftime("%Y-%m-%d"),
                "start_time": None,
                "end_time": None,
                "deadline": format_iso_utc(t.deadline),
                "current_participants": task_participants_count.get(t.id, 0),
                "max_participants": t.max_participants,
                "task_status": t.status,
                "is_task": True,
            })

    schedule_items.sort(key=lambda x: (
        x.get("date") or "9999-99-99",
        x.get("start_time") or "99:99",
    ))

    return {
        "items": schedule_items,
        "start_date": start_date_obj.isoformat(),
        "end_date": end_date_obj.isoformat(),
    }


@expert_dashboard_router.post("/closed-dates", status_code=201)
async def create_closed_date(
    expert_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建关门日期（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    closed_date_str = body.get('closed_date')
    if not closed_date_str:
        raise HTTPException(status_code=400, detail="缺少 closed_date")

    try:
        closed_date_obj = date.fromisoformat(closed_date_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="closed_date 格式无效，请使用 YYYY-MM-DD")

    # Check duplicate
    existing = await db.execute(
        select(models.ExpertClosedDate).where(
            and_(
                models.ExpertClosedDate.expert_id == expert_id,
                models.ExpertClosedDate.closed_date == closed_date_obj,
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该日期已设为关门日")

    cd = models.ExpertClosedDate(
        expert_id=expert_id,
        closed_date=closed_date_obj,
        reason=body.get('reason'),
    )
    db.add(cd)
    await db.commit()
    await db.refresh(cd)
    return {"id": cd.id, "closed_date": str(cd.closed_date)}


@expert_dashboard_router.get("/closed-dates")
async def list_closed_dates(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取关门日期列表"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id)

    result = await db.execute(
        select(models.ExpertClosedDate)
        .where(models.ExpertClosedDate.expert_id == expert_id)
        .order_by(models.ExpertClosedDate.closed_date.asc())
    )
    dates = result.scalars().all()
    return [
        {
            "id": d.id,
            "closed_date": str(d.closed_date),
            "reason": d.reason,
        }
        for d in dates
    ]


@expert_dashboard_router.delete("/closed-dates/by-date")
async def delete_closed_date_by_date(
    expert_id: str,
    request: Request,
    target_date: str = Query(..., description="YYYY-MM-DD"),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """按日期删除关门日期（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    try:
        date_obj = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="target_date 格式无效，请使用 YYYY-MM-DD")

    result = await db.execute(
        select(models.ExpertClosedDate).where(
            and_(
                models.ExpertClosedDate.expert_id == expert_id,
                models.ExpertClosedDate.closed_date == date_obj,
            )
        )
    )
    cd = result.scalar_one_or_none()
    if not cd:
        raise HTTPException(status_code=404, detail="该日期未设置为关门日")

    await db.delete(cd)
    await db.commit()
    return {"detail": "已删除"}


@expert_dashboard_router.delete("/closed-dates/{closed_date_id}")
async def delete_closed_date(
    expert_id: str,
    closed_date_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """删除关门日期（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.ExpertClosedDate).where(
            and_(models.ExpertClosedDate.id == closed_date_id, models.ExpertClosedDate.expert_id == expert_id)
        )
    )
    cd = result.scalar_one_or_none()
    if not cd:
        raise HTTPException(status_code=404, detail="关门日期不存在")

    await db.delete(cd)
    await db.commit()
    return {"detail": "已删除"}


@expert_dashboard_router.get("/reviews")
async def get_expert_reviews(
    expert_id: str,
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取达人评价列表（公开）"""
    await _get_expert_or_404(db, expert_id)

    result = await db.execute(
        select(models.Review)
        .where(models.Review.expert_id == expert_id)
        .order_by(models.Review.created_at.desc())
        .offset(offset).limit(limit)
    )
    reviews = result.scalars().all()
    return [
        {
            "id": r.id,
            "rating": r.rating,
            "comment": r.comment,
            "is_anonymous": r.is_anonymous,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "reply_content": r.reply_content,
            "reply_at": r.reply_at.isoformat() if r.reply_at else None,
        }
        for r in reviews
    ]

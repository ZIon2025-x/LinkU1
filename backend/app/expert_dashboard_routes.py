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


@expert_dashboard_router.get("/dashboard/stats")
async def get_dashboard_stats(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人面板统计"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id)

    # 服务数
    service_count_result = await db.execute(
        select(func.count()).select_from(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
                models.TaskExpertService.status == "active",
            )
        )
    )

    return {
        "expert_id": expert_id,
        "name": expert.name,
        "rating": float(expert.rating) if expert.rating else 0,
        "total_services": service_count_result.scalar_one(),
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
        .order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    )

    result = await db.execute(query)
    rows = result.all()

    return [
        {
            "slot_id": row.ServiceTimeSlot.id,
            "service_id": row.service_id,
            "service_name": row.service_name,
            "slot_start_datetime": row.ServiceTimeSlot.slot_start_datetime.isoformat() if row.ServiceTimeSlot.slot_start_datetime else None,
            "slot_end_datetime": row.ServiceTimeSlot.slot_end_datetime.isoformat() if row.ServiceTimeSlot.slot_end_datetime else None,
            "max_participants": row.ServiceTimeSlot.max_participants,
            "current_participants": row.ServiceTimeSlot.current_participants,
            "is_available": row.ServiceTimeSlot.is_available,
        }
        for row in rows
    ]


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

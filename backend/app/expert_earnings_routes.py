"""
Dashboard query endpoints for the team management page.
spec §5

All endpoints require team membership (any active member of the team).
"""
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_async_db_dependency
from app import models
from app.expert_routes import _get_member_or_403
from app.async_routers import get_current_user_secure_async_csrf

router = APIRouter(prefix="/api/experts", tags=["expert-earnings"])


@router.get("/{expert_id}/tasks")
async def list_team_tasks(
    expert_id: str,
    status: Optional[str] = None,
    task_source: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """List all tasks where this expert team is the taker (LEFT JOIN payment_transfers). spec §5.1"""
    # Auth: any active team member can view
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    # Build filter conditions
    conditions = [models.Task.taker_expert_id == expert_id]
    if status:
        statuses = [s.strip() for s in status.split(',')]
        conditions.append(models.Task.status.in_(statuses))
    if task_source:
        conditions.append(models.Task.task_source == task_source)
    if start_date:
        conditions.append(models.Task.created_at >= start_date)
    if end_date:
        conditions.append(models.Task.created_at <= end_date)

    # Count total
    count_q = select(func.count()).select_from(models.Task).where(and_(*conditions))
    total = (await db.execute(count_q)).scalar_one()

    # Main query with LEFT JOIN payment_transfers
    q = (
        select(models.Task, models.PaymentTransfer)
        .join(
            models.PaymentTransfer,
            models.PaymentTransfer.task_id == models.Task.id,
            isouter=True,
        )
        .where(and_(*conditions))
        .order_by(models.Task.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(q)).all()

    items = []
    for task, pt in rows:
        poster = await db.get(models.User, task.poster_id) if task.poster_id else None
        items.append({
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "task_source": task.task_source,
            "poster": {
                "id": poster.id,
                "name": getattr(poster, 'name', None),
                "avatar": getattr(poster, 'avatar', None),
            } if poster else None,
            "gross_amount": str(task.agreed_reward or task.reward or 0),
            "currency": task.currency or 'GBP',
            "transfer": {
                "status": pt.status,
                "net_amount": str(pt.amount),
                "stripe_transfer_id": pt.transfer_id,
                "error_message": pt.last_error,
            } if pt else None,
            "created_at": task.created_at.isoformat() if task.created_at else None,
            "completed_at": task.completed_at.isoformat() if getattr(task, 'completed_at', None) else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}

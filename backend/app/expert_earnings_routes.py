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


@router.get("/{expert_id}/earnings/summary")
async def earnings_summary(
    expert_id: str,
    period: str = Query('all_time', regex='^(all_time|this_month|last_30d|last_90d)$'),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Aggregate team earnings summary. spec §5.2"""
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    from datetime import timedelta
    now = datetime.utcnow()
    if period == 'this_month':
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    elif period == 'last_30d':
        start = now - timedelta(days=30)
    elif period == 'last_90d':
        start = now - timedelta(days=90)
    else:
        start = None

    # Build conditions for the JOIN query
    task_conditions = [models.Task.taker_expert_id == expert_id]
    if start:
        task_conditions.append(models.Task.created_at >= start)

    q = (
        select(
            func.coalesce(func.sum(models.Task.agreed_reward), 0).label('total_gross'),
            func.coalesce(
                func.sum(models.PaymentTransfer.amount).filter(
                    models.PaymentTransfer.status == 'succeeded'
                ),
                0,
            ).label('total_net'),
            func.count(models.PaymentTransfer.id)
                .filter(models.PaymentTransfer.status == 'succeeded')
                .label('succeeded_count'),
            func.count(models.PaymentTransfer.id)
                .filter(models.PaymentTransfer.status.in_(['pending', 'retrying']))
                .label('pending_count'),
            func.count(models.PaymentTransfer.id)
                .filter(models.PaymentTransfer.status == 'failed')
                .label('failed_count'),
            func.coalesce(
                func.sum(models.PaymentTransfer.amount).filter(
                    models.PaymentTransfer.status == 'reversed'
                ),
                0,
            ).label('total_reversed'),
        )
        .select_from(models.Task)
        .join(
            models.PaymentTransfer,
            models.PaymentTransfer.task_id == models.Task.id,
            isouter=True,
        )
        .where(and_(*task_conditions))
    )

    row = (await db.execute(q)).one()
    total_gross = row.total_gross or 0
    total_net = row.total_net or 0
    total_fee = total_gross - total_net  # platform fee = gross - net (excluding reversed)

    return {
        "period": period,
        "currency": "GBP",
        "total_gross": str(total_gross),
        "total_net": str(total_net),
        "total_fee": str(total_fee),
        "total_reversed": str(row.total_reversed or 0),
        "pending_count": int(row.pending_count or 0),
        "failed_count": int(row.failed_count or 0),
        "succeeded_count": int(row.succeeded_count or 0),
        "note": "Actual balance is held in your team's Stripe account. Check the Stripe Dashboard for real-time balance.",
    }


@router.get("/{expert_id}/earnings/transfers")
async def transfer_history(
    expert_id: str,
    status: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Team Stripe Transfer audit history. spec §5.3"""
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    conditions = [models.PaymentTransfer.taker_expert_id == expert_id]
    if status:
        conditions.append(models.PaymentTransfer.status.in_([s.strip() for s in status.split(',')]))
    if start_date:
        conditions.append(models.PaymentTransfer.created_at >= start_date)
    if end_date:
        conditions.append(models.PaymentTransfer.created_at <= end_date)

    total_q = select(func.count()).select_from(models.PaymentTransfer).where(and_(*conditions))
    total = (await db.execute(total_q)).scalar_one()

    q = (
        select(models.PaymentTransfer)
        .where(and_(*conditions))
        .order_by(models.PaymentTransfer.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(q)).scalars().all()

    items = []
    for r in rows:
        task = await db.get(models.Task, r.task_id)
        items.append({
            "id": r.id,
            "task": {"id": r.task_id, "title": task.title if task else None},
            "amount": str(r.amount),
            "currency": r.currency,
            "status": r.status,
            "stripe_transfer_id": r.transfer_id,
            "stripe_reversal_id": r.stripe_reversal_id,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "retry_count": r.retry_count,
            "error_message": r.last_error,
            "reversed_at": r.reversed_at.isoformat() if r.reversed_at else None,
            "reversed_reason": r.reversed_reason,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}

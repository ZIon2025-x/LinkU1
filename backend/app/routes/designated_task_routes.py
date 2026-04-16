"""指定任务请求（accept / reject / withdraw）— 取代原先的伪造 TaskApplication 方案。"""
import logging
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency, get_current_user_secure_async_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

designated_task_router = APIRouter(tags=["designated_task"])


@designated_task_router.post("/tasks/{task_id}/designated/accept")
async def accept_designated_task(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """被指定用户接受任务（仅定价任务）。创建 TaskApplication(pending) 并通知发布者去批准并支付。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许此操作")
    if str(task.taker_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="你不是此任务的被指定用户")
    if getattr(task, "reward_to_be_quoted", False):
        raise HTTPException(status_code=400, detail="待报价任务请先通过咨询议价")

    # Idempotent: if already has an active application, return it
    existing_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == current_user.id,
            )
        )
    )
    existing = existing_q.scalar_one_or_none()
    if existing and existing.status in ("pending", "approved", "price_agreed"):
        return {
            "task_id": task_id,
            "application_id": existing.id,
            "status": existing.status,
            "is_existing": True,
        }

    now = get_utc_time()
    app_row = models.TaskApplication(
        task_id=task_id,
        applicant_id=current_user.id,
        status="pending",
        negotiated_price=Decimal(str(task.reward)) if task.reward is not None else None,
        currency=task.currency or "GBP",
        message="接受指定任务",
        created_at=now,
    )
    db.add(app_row)
    await db.flush()

    try:
        from app.async_crud import AsyncNotificationCRUD

        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=task.poster_id,
            notification_type="designated_task_accepted",
            title="对方已接受任务",
            content=f"「{task.title}」对方已接受，请批准并支付以开始任务",
            title_en="Designated user accepted the task",
            content_en=f'"{task.title}" — the designated user accepted. Approve & pay to start.',
            related_id=str(task_id),
            related_type="task_id",
        )
    except Exception as e:
        logger.warning(f"designated_task_accepted 通知失败: {e}")

    await db.commit()
    await db.refresh(app_row)
    return {
        "task_id": task_id,
        "application_id": app_row.id,
        "status": app_row.status,
        "is_existing": False,
    }


@designated_task_router.post("/tasks/{task_id}/designated/reject")
async def reject_designated_task(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """被指定用户拒绝任务。task 回退为 open，taker_id 清空；该用户相关 application 标 rejected。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许此操作")
    if str(task.taker_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="你不是此任务的被指定用户")

    poster_id = task.poster_id
    task_title = task.title

    task.status = "open"
    task.taker_id = None

    # Mark any consulting/negotiating/pending applications from this user as rejected
    apps_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == current_user.id,
                models.TaskApplication.status.in_(
                    ["consulting", "negotiating", "price_agreed", "pending"]
                ),
            )
        )
    )
    for app_row in apps_q.scalars().all():
        app_row.status = "rejected"

    try:
        from app.async_crud import AsyncNotificationCRUD

        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=poster_id,
            notification_type="designated_task_rejected",
            title="对方已拒绝任务请求",
            content=f"「{task_title}」对方已拒绝，任务已公开发布",
            title_en="Designated user declined the task",
            content_en=f'"{task_title}" — declined. Task is now public.',
            related_id=str(task_id),
            related_type="task_id",
        )
    except Exception as e:
        logger.warning(f"designated_task_rejected 通知失败: {e}")

    await db.commit()
    return {"task_id": task_id, "status": "open"}


@designated_task_router.post("/tasks/{task_id}/designated/withdraw")
async def withdraw_designated_request(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """发布者撤回指定任务请求。task 回退为 open，taker_id 清空；所有相关 application 标 cancelled。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许撤回")
    if str(task.poster_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="只有发布者可以撤回")

    original_taker_id = task.taker_id
    task_title = task.title

    task.status = "open"
    task.taker_id = None

    apps_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.status.in_(
                    ["consulting", "negotiating", "price_agreed", "pending"]
                ),
            )
        )
    )
    for app_row in apps_q.scalars().all():
        app_row.status = "cancelled"

    if original_taker_id:
        try:
            from app.async_crud import AsyncNotificationCRUD

            await AsyncNotificationCRUD.create_notification(
                db=db,
                user_id=original_taker_id,
                notification_type="designated_task_withdrawn",
                title="对方已撤回任务请求",
                content=f"「{task_title}」发布者已撤回任务请求",
                title_en="The task request was withdrawn",
                content_en=f'"{task_title}" — the poster withdrew the request.',
                related_id=str(task_id),
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"designated_task_withdrawn 通知失败: {e}")

    await db.commit()
    return {"task_id": task_id, "status": "open"}

"""拼单路由"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import GroupBuyParticipant
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

group_buy_router = APIRouter(prefix="/api/group-buy", tags=["group-buy"])


@group_buy_router.post("/activities/{activity_id}/join")
async def join_group_buy(
    activity_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """报名拼单活动"""
    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")
    if not activity.is_group_buy:
        raise HTTPException(status_code=400, detail="该活动不是拼单活动")
    if activity.status != "open":
        raise HTTPException(status_code=400, detail="活动未开放")

    # 检查截止日期
    if activity.group_buy_deadline:
        if get_utc_time() > activity.group_buy_deadline:
            raise HTTPException(status_code=400, detail="拼单已截止")

    # 检查是否已报名当前轮次
    existing = await db.execute(
        select(GroupBuyParticipant).where(
            and_(
                GroupBuyParticipant.activity_id == activity_id,
                GroupBuyParticipant.user_id == current_user.id,
                GroupBuyParticipant.round == activity.group_buy_round,
                GroupBuyParticipant.status == "joined",
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="你已报名本轮拼单")

    # 检查是否已成单（当前轮已满，非多轮模式）
    if activity.group_buy_current_count >= (activity.group_buy_min or 1) and not activity.group_buy_multi_round:
        raise HTTPException(status_code=400, detail="本轮拼单已成单")

    # 多轮模式下检查当前轮是否已满
    if activity.group_buy_multi_round and activity.group_buy_current_count >= (activity.group_buy_min or 1):
        raise HTTPException(status_code=400, detail="本轮拼单已满，请等待下一轮")

    # 报名
    participant = GroupBuyParticipant(
        activity_id=activity_id,
        user_id=current_user.id,
        round=activity.group_buy_round,
    )
    db.add(participant)

    activity.group_buy_current_count += 1

    # 检查是否凑够人数
    group_formed = False
    if activity.group_buy_current_count >= (activity.group_buy_min or 1):
        group_formed = True

    await db.commit()

    if group_formed:
        # 异步处理成单逻辑（创建任务等）
        # TODO: 调用成单处理函数
        pass

    return {
        "joined": True,
        "current_count": activity.group_buy_current_count,
        "min_required": activity.group_buy_min,
        "group_formed": group_formed,
    }


@group_buy_router.post("/activities/{activity_id}/cancel")
async def cancel_group_buy(
    activity_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """取消拼单报名"""
    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    # 查找报名记录
    participant_result = await db.execute(
        select(GroupBuyParticipant).where(
            and_(
                GroupBuyParticipant.activity_id == activity_id,
                GroupBuyParticipant.user_id == current_user.id,
                GroupBuyParticipant.round == activity.group_buy_round,
                GroupBuyParticipant.status == "joined",
            )
        )
    )
    participant = participant_result.scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=400, detail="未找到报名记录")

    participant.status = "cancelled"
    participant.cancelled_at = get_utc_time()
    activity.group_buy_current_count = max(activity.group_buy_current_count - 1, 0)
    await db.commit()

    return {"cancelled": True, "current_count": activity.group_buy_current_count}


@group_buy_router.get("/activities/{activity_id}/status")
async def get_group_buy_status(
    activity_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_optional),
):
    """获取拼单状态"""
    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    # 查当前用户是否已报名
    user_joined = False
    if current_user:
        existing = await db.execute(
            select(GroupBuyParticipant).where(
                and_(
                    GroupBuyParticipant.activity_id == activity_id,
                    GroupBuyParticipant.user_id == current_user.id,
                    GroupBuyParticipant.round == activity.group_buy_round,
                    GroupBuyParticipant.status == "joined",
                )
            )
        )
        user_joined = existing.scalar_one_or_none() is not None

    return {
        "is_group_buy": activity.is_group_buy,
        "current_count": activity.group_buy_current_count,
        "min_required": activity.group_buy_min,
        "deadline": activity.group_buy_deadline.isoformat() if activity.group_buy_deadline else None,
        "task_mode": activity.group_buy_task_mode,
        "multi_round": activity.group_buy_multi_round,
        "round": activity.group_buy_round,
        "user_joined": user_joined,
    }

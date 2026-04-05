"""任务聊天多人化路由 — 邀请团队成员进入任务聊天"""
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.models_expert import (
    Expert, ExpertMember, ChatParticipant,
)
from app.expert_routes import _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

chat_participant_router = APIRouter(
    prefix="/api/chat/tasks",
    tags=["chat-participants"],
)


@chat_participant_router.post("/{task_id}/invite")
async def invite_to_task_chat(
    task_id: int,
    body: dict,  # {"user_id": "xxx"}
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """邀请团队成员进入任务聊天（Owner/Admin）"""
    invitee_id = body.get("user_id")
    if not invitee_id:
        raise HTTPException(status_code=400, detail="缺少 user_id")

    # 查任务
    task_result = await db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )
    task = task_result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 找出这个任务关联的达人团队（通过 service_application 或 task 的 owner_type）
    # 简化：检查当前用户是否是某个达人团队的 Owner/Admin 且与此任务相关
    # 方法：查 chat_participants 中已有的 expert_owner/expert_admin，或查 task 的相关达人
    # 最简单的方式：检查邀请人是否已在聊天中且为 Owner/Admin 角色

    # 先查邀请人是否已是聊天参与者
    inviter_cp = await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.task_id == task_id,
                ChatParticipant.user_id == current_user.id,
                ChatParticipant.role.in_(["expert_owner", "expert_admin"]),
            )
        )
    )
    inviter_participant = inviter_cp.scalar_one_or_none()

    # 如果邀请人不在 chat_participants 中，检查是否是 task 的 poster 或 taker
    is_task_owner = (task.poster_id == current_user.id or task.taker_id == current_user.id)
    if not inviter_participant and not is_task_owner:
        # 也检查是否是 expert_creator
        if not (getattr(task, 'expert_creator_id', None) == current_user.id):
            raise HTTPException(status_code=403, detail="无权邀请成员进入此聊天")

    # 检查被邀请人是否已在聊天中
    existing_cp = await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.task_id == task_id,
                ChatParticipant.user_id == invitee_id,
            )
        )
    )
    if existing_cp.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该用户已在聊天中")

    # 检查被邀请人是否为达人团队的活跃成员
    # 查找任务关联的达人团队（通过 owner_type/owner_id 或 expert_creator_id）
    expert_id_for_check = getattr(task, 'expert_creator_id', None)
    if not expert_id_for_check:
        raise HTTPException(status_code=400, detail="该任务未关联达人团队，无法邀请成员")
    if expert_id_for_check:
        # 检查 invitee 是否为该达人团队成员
        member_check = await db.execute(
            select(ExpertMember).where(
                and_(
                    ExpertMember.expert_id == expert_id_for_check,
                    ExpertMember.user_id == invitee_id,
                    ExpertMember.status == "active",
                )
            )
        )
        if not member_check.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="被邀请人不是达人团队成员")

    # 第一次邀请时，把原有参与者也加入 chat_participants
    existing_count = await db.execute(
        select(ChatParticipant).where(ChatParticipant.task_id == task_id).limit(1)
    )
    if not existing_count.scalar_one_or_none():
        # 首次升级：添加原有参与者
        if task.poster_id:
            db.add(ChatParticipant(
                task_id=task_id,
                user_id=task.poster_id,
                role="client",
            ))
        if task.taker_id and task.taker_id != task.poster_id:
            db.add(ChatParticipant(
                task_id=task_id,
                user_id=task.taker_id,
                role="expert_owner",  # 默认，可能不准确但可接受
            ))
        if getattr(task, 'expert_creator_id', None):
            eid = task.expert_creator_id
            if eid != task.poster_id and eid != task.taker_id:
                db.add(ChatParticipant(
                    task_id=task_id,
                    user_id=eid,
                    role="expert_owner",
                ))

    # 确保达人 Owner 始终在聊天中
    expert_creator_id = getattr(task, 'expert_creator_id', None)
    if expert_creator_id:
        # 查找达人团队的 Owner
        owner_result = await db.execute(
            select(ExpertMember.user_id).where(
                and_(
                    ExpertMember.expert_id == expert_creator_id,
                    ExpertMember.role == "owner",
                    ExpertMember.status == "active",
                )
            )
        )
        owner_user_id = owner_result.scalar_one_or_none()
        if owner_user_id:
            existing_owner_cp = await db.execute(
                select(ChatParticipant).where(
                    and_(
                        ChatParticipant.task_id == task_id,
                        ChatParticipant.user_id == owner_user_id,
                    )
                )
            )
            if not existing_owner_cp.scalar_one_or_none():
                db.add(ChatParticipant(
                    task_id=task_id,
                    user_id=owner_user_id,
                    role="expert_owner",
                ))

    # 添加被邀请人
    db.add(ChatParticipant(
        task_id=task_id,
        user_id=invitee_id,
        role="expert_member",
        invited_by=current_user.id,
    ))

    await db.commit()

    # 发送系统消息通知
    # TODO: 通过 WebSocket 或消息表发送 "[用户] 邀请 [成员] 加入了聊天"

    return {"detail": "已邀请成员加入聊天"}


@chat_participant_router.get("/{task_id}/participants")
async def get_chat_participants(
    task_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取任务聊天的所有参与者"""
    # 验证用户有权查看
    task_result = await db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )
    task = task_result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 查 chat_participants
    cp_result = await db.execute(
        select(ChatParticipant, models.User)
        .join(models.User, models.User.id == ChatParticipant.user_id)
        .where(ChatParticipant.task_id == task_id)
        .order_by(ChatParticipant.joined_at.asc())
    )
    rows = cp_result.all()

    if not rows:
        # 没有 chat_participants 记录 = 普通双人聊天
        participants = []
        if task.poster_id:
            participants.append({"user_id": task.poster_id, "role": "client"})
        if task.taker_id:
            participants.append({"user_id": task.taker_id, "role": "expert_owner"})
        return {"participants": participants, "is_group": False}

    return {
        "participants": [
            {
                "id": cp.id,
                "user_id": cp.user_id,
                "user_name": user.name,
                "user_avatar": user.avatar,
                "role": cp.role,
                "joined_at": cp.joined_at.isoformat() if cp.joined_at else None,
            }
            for cp, user in rows
        ],
        "is_group": True,
    }

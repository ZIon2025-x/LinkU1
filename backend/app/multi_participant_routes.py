"""
多人任务相关API路由
包括管理员、任务达人和用户的多人任务操作
"""

from fastapi import APIRouter, Depends, HTTPException, Body, BackgroundTasks, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from typing import List, Optional
from datetime import datetime, time
import uuid

from app.database import get_db
from app.models import (
    Task, TaskParticipant, TaskParticipantReward, TaskAuditLog,
    User, AdminUser, TaskTimeSlotRelation, ServiceTimeSlot,
    Activity, ActivityTimeSlotRelation
)
from app.schemas import (
    MultiParticipantTaskCreate,
    TaskApplyRequest, TaskParticipantOut, TaskParticipantCompleteRequest,
    TaskParticipantExitRequest, TaskRewardDistributeEqualRequest,
    TaskRewardDistributeCustomRequest, TaskParticipantRewardOut,
    ActivityCreate, ActivityOut, ActivityApplyRequest
)
from app.utils.task_id_utils import parse_task_id, format_task_id
from app.deps import get_current_user_secure_sync_csrf
from app.separate_auth_deps import get_current_admin, get_current_user_optional
from app.utils.time_utils import get_utc_time
from app.models import TaskExpertService, TaskExpert

router = APIRouter(prefix="/api", tags=["multi-participant-tasks"])


# ===========================================
# 管理员API：创建官方多人任务
# ===========================================

@router.post("/admin/tasks/multi-participant")
def create_official_multi_participant_task(
    task: MultiParticipantTaskCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员创建官方多人任务
    """
    # 验证 min_participants <= max_participants
    if task.min_participants > task.max_participants:
        raise HTTPException(
            status_code=400,
            detail="min_participants must be <= max_participants"
        )
    
    # 创建任务记录
    db_task = Task(
        title=task.title,
        description=task.description,
        deadline=task.deadline,
        location=task.location,
        task_type=task.task_type,
        reward=task.reward if task.reward_type in ("cash", "both") else 0.0,
        base_reward=task.reward if task.reward_type in ("cash", "both") else 0.0,
        currency=task.currency,
        poster_id=None,  # 官方任务可以设置为系统用户ID
        taker_id=None,  # 发钱任务，taker_id为NULL
        status="open",
        is_public=1 if task.is_public else 0,
        visibility="public" if task.is_public else "private",
        images=task.images,
        points_reward=task.points_reward if task.reward_type in ("points", "both") else 0,
        # 多人任务字段
        is_multi_participant=True,
        is_official_task=True,
        max_participants=task.max_participants,
        min_participants=task.min_participants,
        current_participants=0,
        completion_rule=task.completion_rule,
        reward_distribution=task.reward_distribution,
        reward_type=task.reward_type,
        auto_accept=True,  # 官方任务自动接受
        allow_negotiation=False,  # 多人任务不支持议价
        created_by_admin=True,
        admin_creator_id=current_admin.id,
        created_by_expert=False,
    )
    
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=db_task.id,
        action_type="task_created",
        action_description=f"管理员创建官方多人任务",
        admin_id=current_admin.id,
        new_status="open",
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "id": format_task_id(db_task.id, is_official=True),
        "title": db_task.title,
        "status": db_task.status,
        "max_participants": db_task.max_participants,
        "min_participants": db_task.min_participants,
        "reward_type": db_task.reward_type,
    }


# ===========================================
# 用户API：获取任务参与者列表
# ===========================================

@router.get("/tasks/{task_id}/participants")
def get_task_participants(
    task_id: str,
    request: Request,
    current_user=Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """
    获取任务参与者列表（所有人可见，可选认证）
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    # 获取所有参与者
    participants = db.query(TaskParticipant).filter(
        TaskParticipant.task_id == parsed_task_id
    ).order_by(TaskParticipant.applied_at.asc()).all()
    
    # 获取用户信息
    participant_list = []
    for participant in participants:
        user = db.query(User).filter(User.id == participant.user_id).first()
        participant_data = {
            "id": participant.id,
            "task_id": participant.task_id,
            "user_id": participant.user_id,
            "user_name": user.name if user else "Unknown",
            "user_avatar": user.avatar if user else None,
            "status": participant.status,
            "time_slot_id": participant.time_slot_id,
            "preferred_deadline": participant.preferred_deadline.isoformat() if participant.preferred_deadline else None,
            "is_flexible_time": participant.is_flexible_time,
            "applied_at": participant.applied_at.isoformat() if participant.applied_at else None,
            "accepted_at": participant.accepted_at.isoformat() if participant.accepted_at else None,
            "started_at": participant.started_at.isoformat() if participant.started_at else None,
            "completed_at": participant.completed_at.isoformat() if participant.completed_at else None,
            "exit_requested_at": participant.exit_requested_at.isoformat() if participant.exit_requested_at else None,
            "exit_reason": participant.exit_reason,
            "completion_notes": participant.completion_notes,
        }
        participant_list.append(participant_data)
    
    return {
        "participants": participant_list,
        "total": len(participant_list)
    }


# ===========================================
# 用户API：申请参与活动（新API，使用Activity表）
# ===========================================

@router.post("/activities/{activity_id}/apply")
def apply_to_activity(
    activity_id: int,
    request: ActivityApplyRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    用户申请参与活动
    - 如果活动关联的是非时间段服务：创建新任务，用户是发布人，达人是接收人
    - 如果活动关联的是时间段服务：创建新任务，包含时间段信息，如果是多人任务则在TaskParticipant表中创建记录
    """
    from app.models import TaskExpertService, ServiceTimeSlot
    from datetime import datetime, timezone as tz
    
    # 查询活动
    db_activity = db.query(Activity).filter(Activity.id == activity_id).with_for_update().first()
    if not db_activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # 验证活动状态
    if db_activity.status != "open":
        raise HTTPException(status_code=400, detail="Activity is not accepting applications")
    
    # 查询服务
    service = db.query(TaskExpertService).filter(
        TaskExpertService.id == db_activity.expert_service_id
    ).first()
    
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    # 检查截止日期（非时间段服务）
    if not db_activity.has_time_slots:
        if db_activity.deadline:
            current_time = datetime.now(tz.utc)
            if current_time > db_activity.deadline:
                raise HTTPException(status_code=400, detail="Activity has expired")
    
    # 检查是否已为此活动创建过任务（通过 originating_user_id 判断）
    existing_task = db.query(Task).filter(
        and_(
            Task.parent_activity_id == activity_id,
            Task.originating_user_id == current_user.id,
            Task.status.in_(["open", "taken", "in_progress"])
        )
    ).first()
    
    if existing_task:
        raise HTTPException(
            status_code=400,
            detail="You have already applied to this activity. Please check your tasks."
        )
    
    # 确定价格
    price = float(db_activity.discounted_price_per_participant) if db_activity.discounted_price_per_participant else (
        float(db_activity.original_price_per_participant) if db_activity.original_price_per_participant else 0.0
    )
    
    # 创建新任务
    # 重要：任务方向逻辑
    # - poster_id（发布者）= 付钱的人 = 申请活动的普通用户
    # - taker_id（接收者）= 收钱的人 = 任务达人
    new_task = Task(
        title=db_activity.title,
        description=db_activity.description,
        deadline=request.preferred_deadline if request.preferred_deadline else db_activity.deadline,
        is_flexible=1 if request.is_flexible_time else 0,
        reward=price,
        base_reward=price,
        currency=db_activity.currency,
        location=db_activity.location,
        task_type=db_activity.task_type,
        poster_id=current_user.id,  # 申请者作为发布者（付钱的）
        taker_id=db_activity.expert_id,  # 达人作为接收者（收钱的）
        status="open",
        task_level="expert",
        is_public=1 if db_activity.is_public else 0,
        visibility=db_activity.visibility,
        images=db_activity.images,
        points_reward=db_activity.points_reward,
        # 关联到活动
        parent_activity_id=activity_id,
        # 记录实际申请人
        originating_user_id=current_user.id,
        # 是否是多人任务
        is_multi_participant=request.is_multi_participant,
        max_participants=request.max_participants if request.is_multi_participant else 1,
        min_participants=request.min_participants if request.is_multi_participant else 1,
        current_participants=0,
        completion_rule=db_activity.completion_rule if request.is_multi_participant else "all",
        reward_distribution=db_activity.reward_distribution if request.is_multi_participant else "equal",
        reward_type=db_activity.reward_type,
        auto_accept=False,
        allow_negotiation=False,
        created_by_expert=True,
        expert_creator_id=db_activity.expert_id,
        expert_service_id=db_activity.expert_service_id,
    )
    
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    
    # 如果是多人任务，创建TaskParticipant记录
    if request.is_multi_participant:
        participant = TaskParticipant(
            task_id=new_task.id,
            user_id=current_user.id,
            activity_id=activity_id,  # 冗余字段：关联的活动ID
            status="pending",  # 需要达人审核
            time_slot_id=request.time_slot_id if db_activity.has_time_slots else None,
            preferred_deadline=request.preferred_deadline,
            is_flexible_time=request.is_flexible_time,
            is_expert_task=True,
            is_official_task=False,
            expert_creator_id=db_activity.expert_id,
            applied_at=get_utc_time(),
            idempotency_key=request.idempotency_key,
        )
        db.add(participant)
        db.commit()
        db.refresh(participant)
    
    # 如果是时间段服务，验证时间段
    if db_activity.has_time_slots:
        if not request.time_slot_id:
            raise HTTPException(status_code=400, detail="时间段服务必须选择时间段")
        
        # 验证时间段是否存在且属于该服务（使用行锁防止并发问题）
        time_slot = db.query(ServiceTimeSlot).filter(
            and_(
                ServiceTimeSlot.id == request.time_slot_id,
                ServiceTimeSlot.service_id == service.id,
                ServiceTimeSlot.is_manually_deleted == False
            )
        ).with_for_update().first()
        
        if not time_slot:
            raise HTTPException(status_code=404, detail="时间段不存在或已被删除")
        
        # 验证时间段是否属于当前活动
        activity_relation = db.query(ActivityTimeSlotRelation).filter(
            and_(
                ActivityTimeSlotRelation.time_slot_id == request.time_slot_id,
                ActivityTimeSlotRelation.activity_id == activity_id,
                ActivityTimeSlotRelation.relation_mode == "fixed"
            )
        ).first()
        
        if not activity_relation:
            raise HTTPException(status_code=400, detail="该时间段不属于此活动")
        
        # 检查时间段是否已被其他活动使用（额外验证）
        other_relation = db.query(ActivityTimeSlotRelation).filter(
            and_(
                ActivityTimeSlotRelation.time_slot_id == request.time_slot_id,
                ActivityTimeSlotRelation.relation_mode == "fixed",
                ActivityTimeSlotRelation.activity_id != activity_id  # 排除当前活动
            )
        ).first()
        
        if other_relation:
            raise HTTPException(status_code=400, detail="该时间段已被其他活动使用")
        
        # 检查时间段是否已满（在锁定的情况下检查，防止并发超卖）
        if time_slot.current_participants >= time_slot.max_participants:
            raise HTTPException(status_code=400, detail="该时间段已满")
        
        # 检查时间段是否已过期
        from app.utils.time_utils import get_utc_time
        current_time = get_utc_time()
        if time_slot.slot_start_datetime < current_time:
            raise HTTPException(status_code=400, detail="该时间段已过期")
        
        # 更新时间段的参与者数量（活动申请成功后，在锁定状态下更新）
        time_slot.current_participants += 1
        db.add(time_slot)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=new_task.id,
        action_type="task_created_from_activity",
        action_description=f"用户申请活动 {activity_id}，创建了任务 {new_task.id}",
        user_id=current_user.id,
        new_status="open",
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "task_id": new_task.id,
        "activity_id": activity_id,
        "message": "Task created successfully from activity",
        "task_status": new_task.status,
        "is_multi_participant": request.is_multi_participant,
        "participant_id": participant.id if request.is_multi_participant else None
    }


# ===========================================
# 用户API：申请参与多人任务（保留向后兼容）
# ===========================================

@router.post("/tasks/{task_id}/apply")
def apply_to_multi_participant_task(
    task_id: str,
    request: TaskApplyRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    用户申请参与多人任务（用于官方多人任务，非活动创建的任务）
    """
    parsed_task_id = parse_task_id(task_id)
    
    # 查询任务
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 验证是否为多人任务
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    # 如果任务是从活动创建的，应该使用活动申请API
    if db_task.parent_activity_id:
        raise HTTPException(
            status_code=400,
            detail="This task is created from an activity. Please use /api/activities/{activity_id}/apply instead"
        )
    
    # 验证任务状态
    if db_task.status != "open":
        raise HTTPException(status_code=400, detail="Task is not accepting applications")
    
    # 检查是否已申请
    existing_participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.user_id == current_user.id,
            TaskParticipant.status.in_(["pending", "accepted", "in_progress"])
        )
    ).first()
    
    if existing_participant:
        raise HTTPException(status_code=400, detail="You have already applied to this task")
    
    # 检查是否已满
    if db_task.current_participants >= db_task.max_participants:
        raise HTTPException(status_code=400, detail="Task is full")
    
    # 创建参与者记录
    participant = TaskParticipant(
        task_id=parsed_task_id,
        user_id=current_user.id,
        status="accepted" if db_task.auto_accept else "pending",
        time_slot_id=request.time_slot_id,
        preferred_deadline=request.preferred_deadline,
        is_flexible_time=request.is_flexible_time,
        is_expert_task=db_task.created_by_expert,
        is_official_task=db_task.is_official_task,
        expert_creator_id=db_task.expert_creator_id,
        applied_at=get_utc_time(),
        idempotency_key=request.idempotency_key,
    )
    
    if db_task.auto_accept:
        participant.accepted_at = get_utc_time()
        db_task.current_participants += 1
    
    db.add(participant)
    db.commit()
    db.refresh(participant)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        action_type="participant_applied",
        action_description=f"用户申请参与多人任务 {parsed_task_id}",
        user_id=current_user.id,
        new_status="accepted" if db_task.auto_accept else "pending",
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "participant_id": participant.id,
        "task_id": parsed_task_id,
        "status": participant.status,
        "message": "Application successful" if db_task.auto_accept else "Application submitted, waiting for approval"
    }


# ===========================================
# 管理员API：开始任务
# ===========================================

@router.post("/admin/tasks/{task_id}/start")
def start_multi_participant_task(
    task_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员开始官方多人任务
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    if not db_task.is_official_task:
        raise HTTPException(status_code=403, detail="Only official tasks can be started by admin")
    
    if db_task.status != "open":
        raise HTTPException(status_code=400, detail="Task is not in open status")
    
    # 验证是否达到最小参与人数
    occupying_statuses = ("pending", "accepted", "in_progress", "exit_requested")
    current_count = db.query(func.count(TaskParticipant.id)).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status.in_(occupying_statuses)
        )
    ).scalar()
    
    if current_count < db_task.min_participants:
        raise HTTPException(
            status_code=400,
            detail=f"Task requires at least {db_task.min_participants} participants, currently has {current_count}"
        )
    
    # 更新任务状态
    db_task.status = "in_progress"
    db_task.accepted_at = get_utc_time()
    
    # 更新所有accepted状态的参与者为in_progress
    participants = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status == "accepted"
        )
    ).all()
    
    for participant in participants:
        participant.status = "in_progress"
        participant.started_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        action_type="task_started",
        action_description=f"管理员开始任务",
        admin_id=current_admin.id,
        old_status="open",
        new_status="in_progress",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Task started successfully", "status": "in_progress"}


# ===========================================
# 用户API：提交完成
# ===========================================

@router.post("/tasks/{task_id}/participants/me/complete")
def complete_participant_task(
    task_id: str,
    request: TaskParticipantCompleteRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    参与者提交完成
    """
    parsed_task_id = parse_task_id(task_id)
    
    # 查找参与者记录
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.user_id == current_user.id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "in_progress":
        raise HTTPException(status_code=400, detail="Participant is not in progress")
    
    # 幂等性检查
    if participant.idempotency_key == request.idempotency_key:
        return {
            "id": participant.id,
            "status": participant.status,
            "message": "Already completed"
        }
    
    # 更新状态
    participant.status = "completed"
    participant.completed_at = get_utc_time()
    participant.completion_notes = request.completion_notes
    participant.idempotency_key = request.idempotency_key
    
    # 获取任务信息
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 检查任务完成条件
    if db_task.completion_rule == "all":
        # 检查是否所有in_progress的参与者都完成
        in_progress_count = db.query(func.count(TaskParticipant.id)).filter(
            and_(
                TaskParticipant.task_id == parsed_task_id,
                TaskParticipant.status == "in_progress"
            )
        ).scalar()
        if in_progress_count == 0:
            db_task.status = "completed"
            db_task.completed_at = get_utc_time()
    elif db_task.completion_rule == "min":
        # 检查已完成数量是否 >= min_participants
        completed_count = db.query(func.count(TaskParticipant.id)).filter(
            and_(
                TaskParticipant.task_id == parsed_task_id,
                TaskParticipant.status == "completed"
            )
        ).scalar()
        if completed_count >= db_task.min_participants:
            db_task.status = "completed"
            db_task.completed_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="participant_completed",
        action_description=f"参与者提交完成",
        user_id=current_user.id,
        old_status="in_progress",
        new_status="completed",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Completion submitted successfully", "status": "completed"}


# ===========================================
# 管理员API：分配奖励（平均分配）
# ===========================================

@router.post("/admin/tasks/{task_id}/complete")
def distribute_rewards_equal(
    task_id: str,
    request: TaskRewardDistributeEqualRequest,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员确认完成并平均分配奖励
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    if db_task.status != "completed":
        raise HTTPException(status_code=400, detail="Task is not completed")
    
    # 检查是否已分配过奖励
    existing_rewards = db.query(TaskParticipantReward).filter(
        TaskParticipantReward.task_id == parsed_task_id
    ).first()
    if existing_rewards:
        raise HTTPException(status_code=409, detail="Rewards already distributed")
    
    # 获取所有已完成的参与者
    completed_participants = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status == "completed"
        )
    ).all()
    
    if not completed_participants:
        raise HTTPException(status_code=400, detail="No completed participants")
    
    participant_count = len(completed_participants)
    
    # 计算平均奖励
    reward_per_participant = None
    points_per_participant = None
    
    if db_task.reward_type in ("cash", "both"):
        reward_per_participant = float(db_task.reward) / participant_count
    
    if db_task.reward_type in ("points", "both"):
        points_per_participant = db_task.points_reward // participant_count
    
    # 创建奖励记录
    reward_records = []
    for participant in completed_participants:
        reward = TaskParticipantReward(
            task_id=parsed_task_id,
            participant_id=participant.id,
            user_id=participant.user_id,
            reward_type=db_task.reward_type,
            reward_amount=reward_per_participant if reward_per_participant else None,
            points_amount=points_per_participant if points_per_participant else None,
            currency=db_task.currency,
            payment_status="pending",
            points_status="pending",
            admin_operator_id=current_admin.id,
            idempotency_key=request.idempotency_key,
        )
        reward_records.append(reward)
        db.add(reward)
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        action_type="rewards_distributed",
        action_description=f"管理员分配奖励（平均分配）",
        admin_id=current_admin.id,
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "message": "Rewards distributed successfully",
        "participant_count": participant_count,
        "reward_type": db_task.reward_type
    }


# ===========================================
# 任务达人API：创建达人多人任务
# ===========================================

@router.get("/activities", response_model=List[ActivityOut])
def get_activities(
    expert_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """
    获取活动列表
    """
    from app.models import Task, TaskParticipant
    from sqlalchemy import func
    
    # 加载关联的服务信息（用于获取服务图片）
    from sqlalchemy.orm import joinedload
    query = db.query(Activity).options(joinedload(Activity.service))
    
    if expert_id:
        query = query.filter(Activity.expert_id == expert_id)
    
    if status:
        query = query.filter(Activity.status == status)
    
    activities = query.order_by(Activity.created_at.desc()).offset(offset).limit(limit).all()
    
    # 计算每个活动的当前参与者数量
    result = []
    for activity in activities:
        # 统计该活动关联的任务中，状态为 accepted, in_progress, completed 的参与者数量
        current_count = db.query(func.count(TaskParticipant.id)).join(
            Task, TaskParticipant.task_id == Task.id
        ).filter(
            Task.parent_activity_id == activity.id,
            TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
        ).scalar() or 0
        
        # 使用 from_orm_with_participants 方法创建输出对象
        from app import schemas
        activity_out = schemas.ActivityOut.from_orm_with_participants(activity, current_count)
        result.append(activity_out)
    
    return result


@router.get("/activities/{activity_id}", response_model=ActivityOut)
def get_activity_detail(
    activity_id: int,
    db: Session = Depends(get_db),
):
    """
    获取活动详情
    """
    from app.models import Task, TaskParticipant
    from sqlalchemy import func
    from sqlalchemy.orm import joinedload
    
    # 加载关联的服务信息（用于获取服务图片）
    activity = db.query(Activity).options(joinedload(Activity.service)).filter(Activity.id == activity_id).first()
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # 计算当前参与者数量
    current_count = db.query(func.count(TaskParticipant.id)).join(
        Task, TaskParticipant.task_id == Task.id
    ).filter(
        Task.parent_activity_id == activity.id,
        TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
    ).scalar() or 0
    
    # 使用 from_orm_with_participants 方法创建输出对象
    from app import schemas
    return schemas.ActivityOut.from_orm_with_participants(activity, current_count)


@router.delete("/expert/activities/{activity_id}")
def delete_expert_activity(
    activity_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人删除/取消自己创建的活动
    - 只能删除自己创建的活动
    - 如果活动已开始，不允许删除
    - 删除活动时，会取消关联的未开始任务
    """
    from app.models import TaskExpert, Task, TaskAuditLog
    
    # 验证用户是否为任务达人
    expert = db.query(TaskExpert).filter(TaskExpert.id == current_user.id).first()
    if not expert or expert.status != "active":
        raise HTTPException(status_code=403, detail="User is not an active task expert")
    
    # 查询活动
    db_activity = db.query(Activity).filter(Activity.id == activity_id).first()
    if not db_activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # 验证活动是否属于当前任务达人
    if db_activity.expert_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own activities")
    
    # 检查活动状态：如果活动已完成或已取消，不允许删除
    if db_activity.status in ("completed", "cancelled"):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete activity with status: {db_activity.status}"
        )
    
    # 检查是否有已开始的任务
    related_tasks = db.query(Task).filter(
        and_(
            Task.parent_activity_id == activity_id,
            Task.status.in_(["in_progress", "completed"])
        )
    ).all()
    
    if related_tasks:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete activity with tasks in progress or completed"
        )
    
    # 取消活动（设置状态为cancelled）
    old_status = db_activity.status
    db_activity.status = "cancelled"
    db_activity.updated_at = get_utc_time()
    
    # 取消关联的未开始任务
    pending_tasks = db.query(Task).filter(
        and_(
            Task.parent_activity_id == activity_id,
            Task.status.in_(["open", "taken"])
        )
    ).all()
    
    for task in pending_tasks:
        old_task_status = task.status  # 保存旧状态
        task.status = "cancelled"
        task.updated_at = get_utc_time()
        
        # 记录审计日志
        audit_log = TaskAuditLog(
            task_id=task.id,
            action_type="task_cancelled",
            action_description=f"活动已取消，任务自动取消",
            user_id=current_user.id,
            old_status=old_task_status,
            new_status="cancelled",
        )
        db.add(audit_log)
    
    # 记录活动审计日志
    activity_audit_log = TaskAuditLog(
        task_id=None,  # 活动没有task_id
        action_type="activity_cancelled",
        action_description=f"任务达人取消活动",
        user_id=current_user.id,
        old_status=old_status,
        new_status="cancelled",
    )
    db.add(activity_audit_log)
    
    db.commit()
    db.refresh(db_activity)
    
    return {"message": "Activity cancelled successfully", "activity_id": activity_id}


@router.post("/expert/activities", response_model=ActivityOut)
def create_expert_activity(
    activity: ActivityCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人创建活动（新API，使用Activity表）
    """
    # 验证用户是否为任务达人
    expert = db.query(TaskExpert).filter(TaskExpert.id == current_user.id).first()
    if not expert or expert.status != "active":
        raise HTTPException(status_code=403, detail="User is not an active task expert")
    
    # 验证服务是否属于该任务达人（必须关联服务）
    if not activity.expert_service_id:
        raise HTTPException(status_code=400, detail="必须关联一个服务")
    
    # 查询服务
    service = db.query(TaskExpertService).filter(
        and_(
            TaskExpertService.id == activity.expert_service_id,
            TaskExpertService.expert_id == current_user.id,
            TaskExpertService.status == "active"
        )
    ).first()
    
    if not service:
        # 检查服务是否存在但可能不属于该用户或状态不对
        service_exists = db.query(TaskExpertService).filter(
            TaskExpertService.id == activity.expert_service_id
        ).first()
        
        if not service_exists:
            raise HTTPException(status_code=404, detail=f"服务不存在 (ID: {activity.expert_service_id})")
        elif service_exists.expert_id != current_user.id:
            raise HTTPException(status_code=403, detail="该服务不属于当前任务达人")
        elif service_exists.status != "active":
            raise HTTPException(status_code=400, detail=f"服务状态为 {service_exists.status}，无法关联。请确保服务已上架")
        else:
            raise HTTPException(status_code=404, detail="Service not found or not accessible")
    
    # 验证 min_participants <= max_participants
    if activity.min_participants > activity.max_participants:
        raise HTTPException(
            status_code=400,
            detail="min_participants must be <= max_participants"
        )
    
    # 计算价格（基于服务base_price，考虑折扣）
    original_price = float(service.base_price)
    discount_percentage = activity.discount_percentage or 0.0
    discounted_price = None
    
    if activity.reward_type in ("cash", "both"):
        # 如果提供了折扣百分比，计算折扣后的价格
        if discount_percentage > 0:
            discounted_price = original_price * (1 - discount_percentage / 100)
        # 如果直接提供了折扣后的价格，使用它
        elif activity.discounted_price_per_participant:
            discounted_price = activity.discounted_price_per_participant
            # 反向计算折扣百分比
            if original_price > 0:
                discount_percentage = (1 - discounted_price / original_price) * 100
        # 如果提供了原始价格和折扣百分比
        elif activity.original_price_per_participant and activity.discount_percentage:
            discounted_price = activity.original_price_per_participant * (1 - activity.discount_percentage / 100)
        else:
            # 默认使用服务基础价格
            discount_percentage = 0.0
            discounted_price = original_price
    
    # 创建活动记录
    db_activity = Activity(
        title=activity.title,
        description=activity.description,
        expert_id=current_user.id,
        expert_service_id=activity.expert_service_id,
        location=activity.location,
        task_type=activity.task_type,
        reward_type=activity.reward_type,
        original_price_per_participant=activity.original_price_per_participant or original_price,
        discount_percentage=discount_percentage if discount_percentage > 0 else None,
        discounted_price_per_participant=discounted_price,
        currency=activity.currency,
        points_reward=activity.points_reward if activity.reward_type in ("points", "both") else None,
        max_participants=activity.max_participants,
        min_participants=activity.min_participants,
        completion_rule=activity.completion_rule,
        reward_distribution=activity.reward_distribution,
        status="open",
        is_public=activity.is_public,
        visibility="public" if activity.is_public else "private",
        deadline=activity.deadline,
        activity_end_date=activity.activity_end_date,
        images=activity.images if activity.images else service.images,
        has_time_slots=service.has_time_slots,
    )
    
    db.add(db_activity)
    db.commit()
    db.refresh(db_activity)
    
    # 加载服务信息（用于返回service_images）
    from sqlalchemy.orm import joinedload
    db_activity = db.query(Activity).options(joinedload(Activity.service)).filter(Activity.id == db_activity.id).first()
    
    # 处理时间段关联（如果服务有时间段）
    if service.has_time_slots:
        # 验证必须选择时间段
        if not activity.time_slot_selection_mode:
            raise HTTPException(
                status_code=400,
                detail="时间段服务必须选择时间段"
            )
        
        # 固定模式：选择具体的时间段ID
        if activity.time_slot_selection_mode == "fixed":
            if not activity.selected_time_slot_ids or len(activity.selected_time_slot_ids) == 0:
                raise HTTPException(
                    status_code=400,
                    detail="固定模式必须选择至少一个时间段"
                )
            
            # 验证时间段是否存在且属于该服务，且未被其他活动使用
            for slot_id in activity.selected_time_slot_ids:
                slot = db.query(ServiceTimeSlot).filter(
                    and_(
                        ServiceTimeSlot.id == slot_id,
                        ServiceTimeSlot.service_id == service.id,
                        ServiceTimeSlot.is_manually_deleted == False
                    )
                ).first()
                
                if not slot:
                    raise HTTPException(
                        status_code=404,
                        detail=f"时间段 {slot_id} 不存在或已被删除"
                    )
                
                # 检查时间段是否已被其他活动使用
                existing_relation = db.query(ActivityTimeSlotRelation).filter(
                    and_(
                        ActivityTimeSlotRelation.time_slot_id == slot_id,
                        ActivityTimeSlotRelation.relation_mode == "fixed"
                    )
                ).first()
                
                if existing_relation:
                    raise HTTPException(
                        status_code=400,
                        detail=f"时间段 {slot_id} 已被其他活动使用"
                    )
                
                # 创建时间段关联
                relation = ActivityTimeSlotRelation(
                    activity_id=db_activity.id,
                    time_slot_id=slot_id,
                    relation_mode="fixed",
                    auto_add_new_slots=False,
                    activity_end_date=activity.activity_end_date
                )
                db.add(relation)
        
        # 重复模式：每天
        elif activity.time_slot_selection_mode == "recurring_daily":
            if not activity.recurring_daily_time_ranges or len(activity.recurring_daily_time_ranges) == 0:
                raise HTTPException(
                    status_code=400,
                    detail="每天重复模式必须指定时间段范围"
                )
            
            # 创建重复规则
            recurring_rule = {
                "type": "daily",
                "time_ranges": activity.recurring_daily_time_ranges
            }
            
            relation = ActivityTimeSlotRelation(
                activity_id=db_activity.id,
                time_slot_id=None,
                relation_mode="recurring",
                recurring_rule=recurring_rule,
                auto_add_new_slots=activity.auto_add_new_slots,
                activity_end_date=activity.activity_end_date
            )
            db.add(relation)
            
            # 查找并关联所有匹配的时间段
            from datetime import datetime as dt_datetime, time as dt_time
            from app.utils.time_utils import parse_local_as_utc, LONDON
            
            # 获取当前日期和未来30天的所有时间段
            today = datetime.now().date()
            future_date = datetime.now().date()
            from datetime import timedelta
            future_date += timedelta(days=30)
            
            # 查询该服务在日期范围内的所有时间段
            start_utc = parse_local_as_utc(
                dt_datetime.combine(today, dt_time(0, 0, 0)),
                LONDON
            )
            end_utc = parse_local_as_utc(
                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                LONDON
            )
            
            matching_slots = db.query(ServiceTimeSlot).filter(
                and_(
                    ServiceTimeSlot.service_id == service.id,
                    ServiceTimeSlot.slot_start_datetime >= start_utc,
                    ServiceTimeSlot.slot_start_datetime <= end_utc,
                    ServiceTimeSlot.is_manually_deleted == False
                )
            ).all()
            
            # 匹配时间段：检查时间段的时间是否在指定的时间范围内
            for slot in matching_slots:
                slot_time = slot.slot_start_datetime.time()
                slot_end_time = slot.slot_end_datetime.time()
                
                # 检查是否匹配任何一个时间范围
                matched = False
                for time_range in activity.recurring_daily_time_ranges:
                    range_start = dt_time.fromisoformat(time_range["start"])
                    range_end = dt_time.fromisoformat(time_range["end"])
                    
                    # 时间段开始时间在范围内，或时间段包含范围
                    if (range_start <= slot_time < range_end) or (slot_time <= range_start < slot_end_time):
                        matched = True
                        break
                
                if matched:
                    # 检查时间段是否已被其他活动使用（固定模式）
                    existing_relation = db.query(ActivityTimeSlotRelation).filter(
                        and_(
                            ActivityTimeSlotRelation.time_slot_id == slot.id,
                            ActivityTimeSlotRelation.relation_mode == "fixed"
                        )
                    ).first()
                    
                    if not existing_relation:
                        # 创建固定关联（用于重复模式的初始时间段）
                        fixed_relation = ActivityTimeSlotRelation(
                            activity_id=db_activity.id,
                            time_slot_id=slot.id,
                            relation_mode="fixed",
                            auto_add_new_slots=False
                        )
                        db.add(fixed_relation)
        
        # 重复模式：每周几
        elif activity.time_slot_selection_mode == "recurring_weekly":
            if not activity.recurring_weekly_weekdays or len(activity.recurring_weekly_weekdays) == 0:
                raise HTTPException(
                    status_code=400,
                    detail="每周重复模式必须指定星期几"
                )
            if not activity.recurring_weekly_time_ranges or len(activity.recurring_weekly_time_ranges) == 0:
                raise HTTPException(
                    status_code=400,
                    detail="每周重复模式必须指定时间段范围"
                )
            
            # 创建重复规则
            recurring_rule = {
                "type": "weekly",
                "weekdays": activity.recurring_weekly_weekdays,
                "time_ranges": activity.recurring_weekly_time_ranges
            }
            
            relation = ActivityTimeSlotRelation(
                activity_id=db_activity.id,
                time_slot_id=None,
                relation_mode="recurring",
                recurring_rule=recurring_rule,
                auto_add_new_slots=activity.auto_add_new_slots,
                activity_end_date=activity.activity_end_date
            )
            db.add(relation)
            
            # 查找并关联所有匹配的时间段
            from datetime import datetime as dt_datetime, time as dt_time
            from app.utils.time_utils import parse_local_as_utc, LONDON
            
            # 获取当前日期和未来30天的所有时间段
            today = datetime.now().date()
            future_date = datetime.now().date()
            from datetime import timedelta
            future_date += timedelta(days=30)
            
            # 查询该服务在日期范围内的所有时间段
            start_utc = parse_local_as_utc(
                dt_datetime.combine(today, dt_time(0, 0, 0)),
                LONDON
            )
            end_utc = parse_local_as_utc(
                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                LONDON
            )
            
            matching_slots = db.query(ServiceTimeSlot).filter(
                and_(
                    ServiceTimeSlot.service_id == service.id,
                    ServiceTimeSlot.slot_start_datetime >= start_utc,
                    ServiceTimeSlot.slot_start_datetime <= end_utc,
                    ServiceTimeSlot.is_manually_deleted == False
                )
            ).all()
            
            # 匹配时间段：检查星期几和时间范围
            for slot in matching_slots:
                slot_date = slot.slot_start_datetime.date()
                slot_weekday = slot_date.weekday()  # 0=Monday, 6=Sunday
                slot_time = slot.slot_start_datetime.time()
                slot_end_time = slot.slot_end_datetime.time()
                
                # 检查星期几是否匹配
                if slot_weekday not in activity.recurring_weekly_weekdays:
                    continue
                
                # 检查时间范围是否匹配
                matched = False
                for time_range in activity.recurring_weekly_time_ranges:
                    range_start = dt_time.fromisoformat(time_range["start"])
                    range_end = dt_time.fromisoformat(time_range["end"])
                    
                    # 时间段开始时间在范围内，或时间段包含范围
                    if (range_start <= slot_time < range_end) or (slot_time <= range_start < slot_end_time):
                        matched = True
                        break
                
                if matched:
                    # 检查时间段是否已被其他活动使用（固定模式）
                    existing_relation = db.query(ActivityTimeSlotRelation).filter(
                        and_(
                            ActivityTimeSlotRelation.time_slot_id == slot.id,
                            ActivityTimeSlotRelation.relation_mode == "fixed"
                        )
                    ).first()
                    
                    if not existing_relation:
                        # 创建固定关联（用于重复模式的初始时间段）
                        fixed_relation = ActivityTimeSlotRelation(
                            activity_id=db_activity.id,
                            time_slot_id=slot.id,
                            relation_mode="fixed",
                            auto_add_new_slots=False
                        )
                        db.add(fixed_relation)
    
    db.commit()
    
    # 重新加载活动和服务信息（用于返回service_images）
    db_activity = db.query(Activity).options(joinedload(Activity.service)).filter(Activity.id == db_activity.id).first()
    
    # 使用 from_orm_with_participants 方法创建输出对象（初始参与者数量为0）
    from app import schemas
    return schemas.ActivityOut.from_orm_with_participants(db_activity, 0)


# ===========================================
# 任务达人API：开始任务
# ===========================================

@router.post("/expert/tasks/{task_id}/start")
def start_expert_multi_participant_task(
    task_id: str,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人开始多人任务
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    if not db_task.created_by_expert or db_task.expert_creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task creator can start this task")
    
    if db_task.status != "open":
        raise HTTPException(status_code=400, detail="Task is not in open status")
    
    # 验证是否达到最小参与人数
    occupying_statuses = ("pending", "accepted", "in_progress", "exit_requested")
    current_count = db.query(func.count(TaskParticipant.id)).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status.in_(occupying_statuses)
        )
    ).scalar()
    
    if current_count < db_task.min_participants:
        raise HTTPException(
            status_code=400,
            detail=f"Task requires at least {db_task.min_participants} participants, currently has {current_count}"
        )
    
    # 更新任务状态
    db_task.status = "in_progress"
    db_task.accepted_at = get_utc_time()
    
    # 更新所有accepted状态的参与者为in_progress
    participants = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status == "accepted"
        )
    ).all()
    
    for participant in participants:
        participant.status = "in_progress"
        participant.started_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        action_type="task_started",
        action_description=f"任务达人开始任务",
        user_id=current_user.id,
        old_status="open",
        new_status="in_progress",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Task started successfully", "status": "in_progress"}


# ===========================================
# 任务达人API：审核申请
# ===========================================

@router.post("/expert/tasks/{task_id}/participants/{participant_id}/approve")
def approve_participant_application(
    task_id: str,
    participant_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人批准参与者申请
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.created_by_expert or db_task.expert_creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task creator can approve applications")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "pending":
        raise HTTPException(status_code=400, detail="Participant is not in pending status")
    
    # 检查是否达到最大人数
    occupying_statuses = ("pending", "accepted", "in_progress", "exit_requested")
    current_count = db.query(func.count(TaskParticipant.id)).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status.in_(occupying_statuses)
        )
    ).scalar()
    
    if current_count >= db_task.max_participants:
        raise HTTPException(status_code=400, detail="Task is full")
    
    # 更新状态
    participant.status = "accepted"
    participant.accepted_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="participant_approved",
        action_description=f"任务达人批准申请",
        user_id=current_user.id,
        old_status="pending",
        new_status="accepted",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Application approved successfully", "status": "accepted"}


@router.post("/expert/tasks/{task_id}/participants/{participant_id}/reject")
def reject_participant_application(
    task_id: str,
    participant_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人拒绝参与者申请
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.created_by_expert or db_task.expert_creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task creator can reject applications")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "pending":
        raise HTTPException(status_code=400, detail="Participant is not in pending status")
    
    # 更新状态为cancelled（拒绝申请）
    participant.status = "cancelled"
    participant.cancelled_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="participant_rejected",
        action_description=f"任务达人拒绝申请",
        user_id=current_user.id,
        old_status="pending",
        new_status="cancelled",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Application rejected", "status": "cancelled"}


# ===========================================
# 用户API：申请退出
# ===========================================

@router.post("/tasks/{task_id}/participants/me/exit-request")
def request_exit_from_task(
    task_id: str,
    request: TaskParticipantExitRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    参与者申请退出任务
    """
    parsed_task_id = parse_task_id(task_id)
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.user_id == current_user.id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    # 只允许accepted或in_progress状态的参与者申请退出
    if participant.status not in ("accepted", "in_progress"):
        raise HTTPException(
            status_code=400,
            detail="Only accepted or in_progress participants can request exit"
        )
    
    # 幂等性检查
    if participant.idempotency_key == request.idempotency_key:
        return {
            "id": participant.id,
            "status": participant.status,
            "message": "Exit request already submitted"
        }
    
    # 保存前一个状态
    participant.previous_status = participant.status
    participant.status = "exit_requested"
    participant.exit_requested_at = get_utc_time()
    participant.exit_reason = request.exit_reason
    participant.idempotency_key = request.idempotency_key
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="exit_requested",
        action_description=f"参与者申请退出",
        user_id=current_user.id,
        old_status=participant.previous_status,
        new_status="exit_requested",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Exit request submitted successfully", "status": "exit_requested"}


# ===========================================
# 管理员/任务达人API：批准/拒绝退出申请
# ===========================================

@router.post("/admin/tasks/{task_id}/participants/{participant_id}/exit/approve")
def admin_approve_exit(
    task_id: str,
    participant_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员批准退出申请（官方任务）
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task or not db_task.is_official_task:
        raise HTTPException(status_code=404, detail="Official task not found")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "exit_requested":
        raise HTTPException(status_code=400, detail="Participant has not requested exit")
    
    # 更新状态
    participant.status = "exited"
    participant.exited_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="exit_approved",
        action_description=f"管理员批准退出",
        admin_id=current_admin.id,
        old_status="exit_requested",
        new_status="exited",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Exit approved successfully", "status": "exited"}


@router.post("/expert/tasks/{task_id}/participants/{participant_id}/exit/approve")
def expert_approve_exit(
    task_id: str,
    participant_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人批准退出申请
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task or not db_task.created_by_expert or db_task.expert_creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task creator can approve exit")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "exit_requested":
        raise HTTPException(status_code=400, detail="Participant has not requested exit")
    
    # 更新状态
    participant.status = "exited"
    participant.exited_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="exit_approved",
        action_description=f"任务达人批准退出",
        user_id=current_user.id,
        old_status="exit_requested",
        new_status="exited",
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Exit approved successfully", "status": "exited"}


@router.post("/admin/tasks/{task_id}/participants/{participant_id}/exit/reject")
def admin_reject_exit(
    task_id: str,
    participant_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员拒绝退出申请（恢复原状态）
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task or not db_task.is_official_task:
        raise HTTPException(status_code=404, detail="Official task not found")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "exit_requested":
        raise HTTPException(status_code=400, detail="Participant has not requested exit")
    
    if not participant.previous_status:
        raise HTTPException(status_code=400, detail="Cannot restore: previous status not found")
    
    # 恢复原状态
    participant.status = participant.previous_status
    participant.previous_status = None
    participant.exit_requested_at = None
    participant.exit_reason = None
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="exit_rejected",
        action_description=f"管理员拒绝退出申请",
        admin_id=current_admin.id,
        old_status="exit_requested",
        new_status=participant.status,
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Exit request rejected", "status": participant.status}


@router.post("/expert/tasks/{task_id}/participants/{participant_id}/exit/reject")
def expert_reject_exit(
    task_id: str,
    participant_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人拒绝退出申请（恢复原状态）
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).first()
    if not db_task or not db_task.created_by_expert or db_task.expert_creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task creator can reject exit")
    
    participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.id == participant_id,
            TaskParticipant.task_id == parsed_task_id
        )
    ).first()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    if participant.status != "exit_requested":
        raise HTTPException(status_code=400, detail="Participant has not requested exit")
    
    if not participant.previous_status:
        raise HTTPException(status_code=400, detail="Cannot restore: previous status not found")
    
    # 恢复原状态
    participant.status = participant.previous_status
    participant.previous_status = None
    participant.exit_requested_at = None
    participant.exit_reason = None
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="exit_rejected",
        action_description=f"任务达人拒绝退出申请",
        user_id=current_user.id,
        old_status="exit_requested",
        new_status=participant.status,
    )
    db.add(audit_log)
    db.commit()
    
    return {"message": "Exit request rejected", "status": participant.status}


# ===========================================
# 管理员API：自定义分配奖励
# ===========================================

@router.post("/admin/tasks/{task_id}/complete/custom")
def distribute_rewards_custom(
    task_id: str,
    request: TaskRewardDistributeCustomRequest,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    管理员确认完成并自定义分配奖励
    """
    parsed_task_id = parse_task_id(task_id)
    
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    if db_task.reward_distribution != "custom":
        raise HTTPException(status_code=400, detail="Task reward distribution is not custom")
    
    if db_task.status != "completed":
        raise HTTPException(status_code=400, detail="Task is not completed")
    
    # 检查是否已分配过奖励
    existing_rewards = db.query(TaskParticipantReward).filter(
        TaskParticipantReward.task_id == parsed_task_id
    ).first()
    if existing_rewards:
        raise HTTPException(status_code=409, detail="Rewards already distributed")
    
    # 验证所有参与者都在奖励列表中
    completed_participants = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status == "completed"
        )
    ).all()
    
    participant_ids = {p.id for p in completed_participants}
    reward_participant_ids = {r.participant_id for r in request.rewards}
    
    if participant_ids != reward_participant_ids:
        raise HTTPException(
            status_code=400,
            detail="Reward list must include all completed participants"
        )
    
    # 创建奖励记录
    for reward_item in request.rewards:
        participant = next((p for p in completed_participants if p.id == reward_item.participant_id), None)
        if not participant:
            raise HTTPException(
                status_code=404,
                detail=f"Participant {reward_item.participant_id} not found"
            )
        
        reward = TaskParticipantReward(
            task_id=parsed_task_id,
            participant_id=reward_item.participant_id,
            user_id=participant.user_id,
            reward_type=reward_item.reward_type,
            reward_amount=reward_item.reward_amount,
            points_amount=reward_item.points_amount,
            currency=db_task.currency,
            payment_status="pending",
            points_status="pending",
            admin_operator_id=current_admin.id,
            idempotency_key=request.idempotency_key,
        )
        db.add(reward)
    
    db.commit()
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        action_type="rewards_distributed",
        action_description=f"管理员分配奖励（自定义分配）",
        admin_id=current_admin.id,
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "message": "Rewards distributed successfully",
        "participant_count": len(request.rewards),
        "reward_type": db_task.reward_type
    }


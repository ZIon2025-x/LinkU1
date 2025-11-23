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
    User, AdminUser
)
from app.schemas import (
    MultiParticipantTaskCreate, ExpertMultiParticipantTaskCreate,
    TaskApplyRequest, TaskParticipantOut, TaskParticipantCompleteRequest,
    TaskParticipantExitRequest, TaskRewardDistributeEqualRequest,
    TaskRewardDistributeCustomRequest, TaskParticipantRewardOut
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
# 用户API：申请参与多人任务
# ===========================================

@router.post("/tasks/{task_id}/apply")
def apply_to_multi_participant_task(
    task_id: str,
    request: TaskApplyRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    用户申请参与多人任务
    """
    # 解析任务ID
    parsed_task_id = parse_task_id(task_id)
    
    # 开启事务
    db_task = db.query(Task).filter(Task.id == parsed_task_id).with_for_update().first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if not db_task.is_multi_participant:
        raise HTTPException(status_code=400, detail="This is not a multi-participant task")
    
    # 验证任务状态
    if db_task.status not in ("open", "in_progress"):
        raise HTTPException(status_code=400, detail="Task is not accepting applications")
    
    # 幂等性检查
    existing = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.user_id == current_user.id,
            TaskParticipant.idempotency_key == request.idempotency_key
        )
    ).first()
    if existing:
        return {
            "id": existing.id,
            "status": existing.status,
            "message": "Application already submitted"
        }
    
    # 检查是否已申请
    existing_participant = db.query(TaskParticipant).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.user_id == current_user.id
        )
    ).first()
    if existing_participant:
        raise HTTPException(status_code=400, detail="Already applied to this task")
    
    # 计算当前参与人数（使用COUNT(*)实时查询）
    occupying_statuses = ("pending", "accepted", "in_progress", "exit_requested")
    current_count = db.query(func.count(TaskParticipant.id)).filter(
        and_(
            TaskParticipant.task_id == parsed_task_id,
            TaskParticipant.status.in_(occupying_statuses)
        )
    ).scalar()
    
    # 条件性迟到加入验证
    if db_task.status == "in_progress":
        if current_count >= db_task.min_participants:
            raise HTTPException(
                status_code=400,
                detail="Task is in progress and has reached min_participants"
            )
    
    # 检查是否达到最大人数
    if current_count >= db_task.max_participants:
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
        accepted_at=get_utc_time() if db_task.auto_accept else None,
        idempotency_key=request.idempotency_key,
    )
    
    db.add(participant)
    db.commit()
    db.refresh(participant)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=parsed_task_id,
        participant_id=participant.id,
        action_type="participant_applied",
        action_description=f"用户申请参与任务",
        user_id=current_user.id,
        new_status=participant.status,
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "id": participant.id,
        "status": participant.status,
        "message": "Application submitted successfully"
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

@router.post("/expert/tasks/multi-participant")
def create_expert_multi_participant_task(
    task: ExpertMultiParticipantTaskCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    任务达人创建多人任务
    """
    # 验证用户是否为任务达人
    expert = db.query(TaskExpert).filter(TaskExpert.id == current_user.id).first()
    if not expert or expert.status != "active":
        raise HTTPException(status_code=403, detail="User is not an active task expert")
    
    # 验证服务是否属于该任务达人
    service = db.query(TaskExpertService).filter(
        and_(
            TaskExpertService.id == task.expert_service_id,
            TaskExpertService.expert_id == current_user.id,
            TaskExpertService.status == "active"
        )
    ).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found or not accessible")
    
    # 验证 min_participants <= max_participants
    if task.min_participants > task.max_participants:
        raise HTTPException(
            status_code=400,
            detail="min_participants must be <= max_participants"
        )
    
    # 验证固定时间段相关字段
    if task.is_fixed_time_slot:
        if not task.time_slot_duration_minutes or not task.time_slot_start_time or not task.time_slot_end_time or not task.participants_per_slot:
            raise HTTPException(
                status_code=400,
                detail="Fixed time slot requires time_slot_duration_minutes, time_slot_start_time, time_slot_end_time, and participants_per_slot"
            )
    
    # 计算价格（基于服务base_price，考虑折扣）
    reward_amount = None
    if task.reward_type in ("cash", "both"):
        if task.discounted_price_per_participant:
            reward_amount = task.discounted_price_per_participant
        elif task.original_price_per_participant and task.discount_percentage:
            reward_amount = task.original_price_per_participant * (1 - task.discount_percentage / 100)
        else:
            reward_amount = float(service.base_price)
    
    # 设置taker_id（商业服务任务：达人收钱）
    taker_id = current_user.id if task.reward_type == "cash" else None
    
    # 创建任务记录
    db_task = Task(
        title=task.title,
        description=task.description,
        deadline=task.deadline,
        location=task.location,
        task_type=service.service_name,  # 使用服务名称作为task_type
        reward=reward_amount if reward_amount else 0.0,
        base_reward=reward_amount if reward_amount else 0.0,
        currency=task.currency,
        poster_id=None,  # 达人任务poster_id可以为NULL
        taker_id=taker_id,
        status="open",
        is_public=1 if task.is_public else 0,
        visibility="public" if task.is_public else "private",
        images=task.images if task.images else service.images,
        points_reward=task.points_reward if task.reward_type in ("points", "both") else 0,
        # 多人任务字段
        is_multi_participant=True,
        is_official_task=False,
        max_participants=task.max_participants,
        min_participants=task.min_participants,
        current_participants=0,
        completion_rule=task.completion_rule,
        reward_distribution=task.reward_distribution,
        reward_type=task.reward_type,
        auto_accept=False,  # 任务达人任务需要审核
        allow_negotiation=False,  # 多人任务不支持议价
        created_by_admin=False,
        created_by_expert=True,
        expert_creator_id=current_user.id,
        expert_service_id=task.expert_service_id,
        is_fixed_time_slot=task.is_fixed_time_slot,
        time_slot_duration_minutes=task.time_slot_duration_minutes,
        time_slot_start_time=time.fromisoformat(task.time_slot_start_time) if task.time_slot_start_time else None,
        time_slot_end_time=time.fromisoformat(task.time_slot_end_time) if task.time_slot_end_time else None,
        participants_per_slot=task.participants_per_slot,
        original_price_per_participant=task.original_price_per_participant,
        discount_percentage=task.discount_percentage,
        discounted_price_per_participant=task.discounted_price_per_participant,
    )
    
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=db_task.id,
        action_type="task_created",
        action_description=f"任务达人创建多人任务",
        user_id=current_user.id,
        new_status="open",
    )
    db.add(audit_log)
    db.commit()
    
    return {
        "id": format_task_id(db_task.id, is_expert=True),
        "title": db_task.title,
        "status": db_task.status,
        "max_participants": db_task.max_participants,
        "min_participants": db_task.min_participants,
        "reward_type": db_task.reward_type,
    }


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


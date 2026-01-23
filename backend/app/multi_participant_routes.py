"""
多人任务相关API路由
包括管理员、任务达人和用户的多人任务操作
"""

from fastapi import APIRouter, Depends, HTTPException, Body, BackgroundTasks, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from typing import List, Optional
from datetime import datetime, time, timedelta
import uuid

from app.database import get_db
from app.models import (
    Task, TaskParticipant, TaskParticipantReward, TaskAuditLog,
    User, AdminUser, TaskTimeSlotRelation, ServiceTimeSlot,
    Activity, ActivityTimeSlotRelation, ActivityFavorite, PointsAccount
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
    from app.utils.time_utils import format_iso_utc
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
            "preferred_deadline": format_iso_utc(participant.preferred_deadline) if participant.preferred_deadline else None,
            "is_flexible_time": participant.is_flexible_time,
            "applied_at": format_iso_utc(participant.applied_at) if participant.applied_at else None,
            "accepted_at": format_iso_utc(participant.accepted_at) if participant.accepted_at else None,
            "started_at": format_iso_utc(participant.started_at) if participant.started_at else None,
            "completed_at": format_iso_utc(participant.completed_at) if participant.completed_at else None,
            "exit_requested_at": format_iso_utc(participant.exit_requested_at) if participant.exit_requested_at else None,
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
    import logging
    logger = logging.getLogger(__name__)
    
    from app.models import TaskExpertService, ServiceTimeSlot
    from datetime import datetime, timezone as tz
    from app.utils.time_utils import get_utc_time
    
    logger.info(f"用户 {current_user.id} 申请活动 {activity_id}, time_slot_id={request.time_slot_id}, is_multi_participant={request.is_multi_participant}")
    
    # 查询活动
    db_activity = db.query(Activity).filter(Activity.id == activity_id).with_for_update().first()
    if not db_activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # 验证活动状态
    if db_activity.status != "open":
        raise HTTPException(status_code=400, detail="Activity is not accepting applications")
    
    # 根据活动的 max_participants 自动判断是否为多人任务
    # 如果活动的 max_participants > 1，则自动创建多人任务
    is_multi_participant = db_activity.max_participants > 1
    if is_multi_participant:
        logger.info(f"活动 {activity_id} 的 max_participants={db_activity.max_participants}，自动判断为多人任务")
    else:
        logger.info(f"活动 {activity_id} 的 max_participants={db_activity.max_participants}，自动判断为单人任务")
    
    # 查询服务
    service = db.query(TaskExpertService).filter(
        TaskExpertService.id == db_activity.expert_service_id
    ).first()
    
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    # 检查截止日期（非时间段服务）
    if not db_activity.has_time_slots:
        # 检查活动本身的截止日期是否已过期
        if db_activity.deadline:
            current_time = get_utc_time()
            if current_time > db_activity.deadline:
                raise HTTPException(status_code=400, detail="Activity has expired")
        
        # ⚠️ 验证用户申请的截止日期（类似服务申请的验证逻辑）
        if request.is_flexible_time:
            # 灵活模式，不需要截止日期
            preferred_deadline = None
        elif request.preferred_deadline is None:
            # 非灵活模式，必须提供截止日期
            raise HTTPException(
                status_code=400,
                detail="非灵活模式必须提供截止日期"
            )
        else:
            # 验证截止日期不能早于当前时间
            current_time = get_utc_time()
            if request.preferred_deadline < current_time:
                raise HTTPException(
                    status_code=400,
                    detail="截止日期不能早于当前时间"
                )
            preferred_deadline = request.preferred_deadline
    else:
        # 如果活动启用了时间段，不需要截止日期（时间段已经包含了日期信息）
        preferred_deadline = None
    
    # 对于多人任务且有时间段的情况，检查是否已经有任务关联到这个时间段
    # 如果有，让新用户加入现有任务，而不是创建新任务
    # 注意：非时间段的多人活动，每个用户申请时创建独立任务，不需要群聊
    existing_task = None
    if is_multi_participant and db_activity.has_time_slots and request.time_slot_id:
        logger.info(f"查找多人任务现有任务: activity_id={activity_id}, time_slot_id={request.time_slot_id}, is_multi_participant={is_multi_participant}")
        
        # 查找已存在的任务（通过时间段关联）
        # 先查找所有关联该时间段的任务，然后筛选出符合条件的多人任务
        existing_relations = db.query(TaskTimeSlotRelation).filter(
            and_(
                TaskTimeSlotRelation.time_slot_id == request.time_slot_id,
                TaskTimeSlotRelation.relation_mode == "fixed"
            )
        ).all()
        
        logger.info(f"找到 {len(existing_relations)} 个时间段关联")
        
        # 遍历所有关联，找到符合条件的任务
        for relation in existing_relations:
            task = db.query(Task).filter(
                and_(
                    Task.id == relation.task_id,
                    Task.parent_activity_id == activity_id,
                    Task.is_multi_participant == True,
                    Task.status.in_(["open", "taken", "in_progress"])
                )
            ).first()
            
            if task:
                logger.info(f"找到现有多人任务: task_id={task.id}, status={task.status}, current_participants={task.current_participants}, max_participants={task.max_participants}")
                existing_task = task
                break
        
        if existing_task:
            # 检查用户是否已经是该任务的参与者
            existing_participant = db.query(TaskParticipant).filter(
                and_(
                    TaskParticipant.task_id == existing_task.id,
                    TaskParticipant.user_id == current_user.id,
                    TaskParticipant.status.in_(["pending", "accepted", "in_progress"])
                )
            ).first()
            
            if existing_participant:
                logger.warning(f"用户 {current_user.id} 已经是任务 {existing_task.id} 的参与者")
                raise HTTPException(
                    status_code=400,
                    detail="You have already applied to this time slot. Please check your tasks."
                )
            logger.info(f"用户 {current_user.id} 将加入现有任务 {existing_task.id}")
        else:
            logger.info(f"未找到现有任务，将创建新任务")
    
    # 对于非多人任务或没有时间段的情况，检查用户是否已为此活动创建过任务
    # 注意：非时间段的多人活动，每个用户申请时创建独立任务，所以这里只检查用户自己是否已申请过
    if not existing_task and not (is_multi_participant and db_activity.has_time_slots):
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
    
    # 如果已存在任务（多人任务），让新用户加入现有任务
    if existing_task:
        # 检查时间段是否已满
        if db_activity.has_time_slots and request.time_slot_id:
            time_slot = db.query(ServiceTimeSlot).filter(
                and_(
                    ServiceTimeSlot.id == request.time_slot_id,
                    ServiceTimeSlot.service_id == service.id,
                    ServiceTimeSlot.is_manually_deleted == False
                )
            ).with_for_update().first()
            
            if not time_slot:
                raise HTTPException(status_code=404, detail="时间段不存在或已被删除")
            
            # 检查时间段是否已满
            if time_slot.current_participants >= time_slot.max_participants:
                raise HTTPException(status_code=400, detail="该时间段已满")
            
            # 检查时间段是否已过期
            current_time = get_utc_time()
            if time_slot.slot_start_datetime < current_time:
                raise HTTPException(status_code=400, detail="该时间段已过期")
            
            # 更新时间段的参与者数量
            time_slot.current_participants += 1
            db.add(time_slot)
        
        # ⚠️ 验证截止日期（对于非时间段服务，加入现有任务时也需要验证）
        validated_preferred_deadline = None
        if not db_activity.has_time_slots:
            if request.is_flexible_time:
                # 灵活模式，不需要截止日期
                validated_preferred_deadline = None
            elif request.preferred_deadline is None:
                # 非灵活模式，必须提供截止日期
                raise HTTPException(
                    status_code=400,
                    detail="非灵活模式必须提供截止日期"
                )
            else:
                # 验证截止日期不能早于当前时间
                current_time = get_utc_time()
                if request.preferred_deadline < current_time:
                    raise HTTPException(
                        status_code=400,
                        detail="截止日期不能早于当前时间"
                    )
                validated_preferred_deadline = request.preferred_deadline
        
        # 创建TaskParticipant记录，让新用户加入现有任务
        participant_status = "accepted" if db_activity.has_time_slots else "pending"
        participant = TaskParticipant(
            task_id=existing_task.id,
            user_id=current_user.id,
            activity_id=activity_id,
            status=participant_status,
            time_slot_id=request.time_slot_id if db_activity.has_time_slots else None,
            preferred_deadline=validated_preferred_deadline,
            is_flexible_time=request.is_flexible_time,
            is_expert_task=True,
            is_official_task=False,
            expert_creator_id=db_activity.expert_id,
            applied_at=get_utc_time(),
            accepted_at=get_utc_time() if db_activity.has_time_slots else None,
            idempotency_key=request.idempotency_key,
        )
        db.add(participant)
        
        # 更新任务的参与者数量
        if db_activity.has_time_slots:
            existing_task.current_participants += 1
        
        db.commit()
        db.refresh(participant)
        db.refresh(existing_task)
        
        # 记录审计日志
        audit_log = TaskAuditLog(
            task_id=existing_task.id,
            action_type="participant_joined_existing_task",
            action_description=f"用户加入已存在的任务 {existing_task.id}（活动 {activity_id}）",
            user_id=current_user.id,
            new_status=participant_status,
        )
        db.add(audit_log)
        db.commit()
        
        return {
            "task_id": existing_task.id,
            "activity_id": activity_id,
            "message": "Successfully joined existing task",
            "task_status": existing_task.status,
            "is_multi_participant": True,
            "participant_id": participant.id
        }
    
    # 确定任务状态和是否需要支付
    # 如果活动不是奖励申请者模式（reward_applicants=False），则需要支付
    needs_payment = not (hasattr(db_activity, 'reward_applicants') and db_activity.reward_applicants)
    
    # 对于有时间段的活动申请（无论是单个任务还是多人任务），如果需要支付且价格>0则进入"待支付"状态，否则进入"进行中"状态
    # 对于无时间段的多人活动，如果需要支付且价格>0则进入"待支付"状态，否则进入"进行中"状态
    # 对于无时间段的单人任务，如果需要支付且价格>0则进入"待支付"状态，否则保持open状态等待审核
    # 注意：如果价格为0，即使needs_payment=True，也视为不需要支付，直接进入进行中或open状态
    if needs_payment and price > 0:
        initial_status = "pending_payment"
    elif db_activity.has_time_slots:
        # 有时间段且不需要支付（或价格为0），直接进入进行中状态
        initial_status = "in_progress"
    elif is_multi_participant:
        # 无时间段的多人活动，不需要支付（或价格为0），直接进入进行中状态
        initial_status = "in_progress"
    else:
        # 无时间段的单人任务，不需要支付（或价格为0），保持open状态等待审核
        initial_status = "open"
    
    # 创建新任务
    # 重要：任务方向逻辑
    # - 对于单人任务：poster_id（发布者）= 付钱的人 = 申请活动的普通用户，taker_id（接收者）= 收钱的人 = 任务达人
    # - 对于多人任务：poster_id 应该为 None，因为所有参与者都通过 TaskParticipant 表管理，不应该有单一的发布者
    # 确定任务的截止日期
    # 对于非时间段服务：使用验证后的 preferred_deadline（如果用户提供了）或活动的 deadline
    # 对于时间段服务：不需要截止日期（时间段已包含日期信息）
    if not db_activity.has_time_slots:
        task_deadline = preferred_deadline if preferred_deadline else db_activity.deadline
        task_is_flexible = 1 if request.is_flexible_time else 0
    else:
        task_deadline = None  # 时间段服务不需要截止日期
        task_is_flexible = 0  # 时间段服务不是灵活模式
    
    new_task = Task(
        title=db_activity.title,
        description=db_activity.description,
        deadline=task_deadline,
        is_flexible=task_is_flexible,
        reward=price,
        base_reward=price,
        currency=db_activity.currency,
        location=db_activity.location,
        task_type=db_activity.task_type,
        # 对于多人任务，poster_id 应该为 None，因为参与者通过 TaskParticipant 管理
        # 对于单人任务，poster_id 是申请者（付钱的）
        poster_id=None if is_multi_participant else current_user.id,
        taker_id=db_activity.expert_id,  # 达人作为接收者（收钱的）
        status=initial_status,
        task_level="expert",
        is_public=1 if db_activity.is_public else 0,
        visibility=db_activity.visibility,
        images=db_activity.images,
        points_reward=db_activity.points_reward,
        # 关联到活动
        parent_activity_id=activity_id,
        # 记录实际申请人（对于多人任务，这是第一个申请者，但不应该作为 poster_id）
        originating_user_id=current_user.id,
        # 是否是多人任务（根据活动的 max_participants 自动判断）
        is_multi_participant=is_multi_participant,
        max_participants=db_activity.max_participants,
        min_participants=db_activity.min_participants,
        # 如果是多人任务，第一个参与者会被自动接受，所以初始计数为1
        current_participants=1 if is_multi_participant else 0,
        completion_rule=db_activity.completion_rule if is_multi_participant else "all",
        reward_distribution=db_activity.reward_distribution if is_multi_participant else "equal",
        reward_type=db_activity.reward_type,
        auto_accept=False,
        allow_negotiation=False,
        created_by_expert=True,
        expert_creator_id=db_activity.expert_id,
        expert_service_id=db_activity.expert_service_id,
        # 对于有时间段的活动申请，或者多人活动，设置接受时间
        accepted_at=get_utc_time() if (db_activity.has_time_slots or is_multi_participant) else None,
        # 如果需要支付，设置支付过期时间（24小时）
        payment_expires_at=get_utc_time() + timedelta(hours=24) if (needs_payment and price > 0) else None,
        is_paid=0,  # 明确标记为未支付
    )
    
    db.add(new_task)
    db.flush()  # 先flush获取任务ID，但不commit，以便后续创建支付意图失败时可以回滚
    
    # 如果需要支付，创建支付意图
    payment_intent_id = None
    if needs_payment and price > 0:
        # 检查达人是否有Stripe Connect账户
        expert_user = db.query(User).filter(User.id == db_activity.expert_id).first()
        if not expert_user or not expert_user.stripe_account_id:
            db.rollback()
            raise HTTPException(
                status_code=400,
                detail="任务达人尚未创建 Stripe Connect 收款账户，无法完成支付。请联系任务达人先创建收款账户。",
                headers={"X-Stripe-Connect-Required": "true"}
            )
        
        # 创建支付意图
        import stripe
        import os
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        task_amount_pence = int(price * 100)
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(task_amount_pence)
        
        try:
            # ⚠️ 优化：使用托管模式（与其他支付功能一致）
            # 交易市场托管模式：
            # - 支付时：资金先到平台账户（不立即转账给任务接受人）
            # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
            # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
            payment_intent = stripe.PaymentIntent.create(
                amount=task_amount_pence,
                currency=db_activity.currency.lower(),
                # 明确指定支付方式类型，确保 WeChat Pay 可用
                payment_method_types=["card", "wechat_pay"],
                # 不设置 transfer_data.destination，让资金留在平台账户（托管模式）
                # 不设置 application_fee_amount，服务费在任务完成转账时扣除
                metadata={
                    "task_id": str(new_task.id),
                    "activity_id": str(activity_id),
                    "poster_id": current_user.id if not is_multi_participant else None,
                    "taker_id": db_activity.expert_id,
                    "taker_stripe_account_id": expert_user.stripe_account_id,  # 保存接受人的 Stripe 账户ID，用于后续转账
                    "application_fee": str(application_fee_pence),  # 保存服务费金额，用于后续转账时扣除
                    "task_amount": str(task_amount_pence),  # 任务金额
                    "task_type": "activity_application",
                },
                description=f"活动申请支付 - {db_activity.title}",
            )
            payment_intent_id = payment_intent.id
            new_task.payment_intent_id = payment_intent_id
            logger.info(f"创建支付意图成功: payment_intent_id={payment_intent_id}, task_id={new_task.id}")
        except Exception as e:
            db.rollback()
            logger.error(f"创建支付意图失败: {e}")
            raise HTTPException(status_code=500, detail=f"创建支付意图失败: {str(e)}")
    
    db.commit()
    db.refresh(new_task)
    
    # 如果是多人任务，创建TaskParticipant记录
    participant = None
    if is_multi_participant:
        # 对于有时间段的活动申请，参与者状态直接设为"accepted"，不需要审核
        # 对于无时间段的多人活动，第一个申请者也应该自动接受，直接设为"accepted"
        participant_status = "accepted"  # 多人活动的申请者都自动接受
        participant = TaskParticipant(
            task_id=new_task.id,
            user_id=current_user.id,
            activity_id=activity_id,  # 冗余字段：关联的活动ID
            status=participant_status,
            time_slot_id=request.time_slot_id if db_activity.has_time_slots else None,
            preferred_deadline=preferred_deadline,  # 使用验证后的截止日期
            is_flexible_time=request.is_flexible_time,
            is_expert_task=True,
            is_official_task=False,
            expert_creator_id=db_activity.expert_id,
            applied_at=get_utc_time(),
            accepted_at=get_utc_time(),  # 多人活动的申请者都自动接受，设置接受时间
            idempotency_key=request.idempotency_key,
        )
        db.add(participant)
        db.commit()
        db.refresh(participant)
    
    # 如果是时间段服务，验证时间段
    if db_activity.has_time_slots:
        if not request.time_slot_id:
            logger.warning(f"活动 {activity_id} 申请失败: 时间段服务必须选择时间段")
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
            logger.warning(f"活动 {activity_id} 申请失败: 时间段 {request.time_slot_id} 不存在或已被删除")
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
            logger.warning(f"活动 {activity_id} 申请失败: 时间段 {request.time_slot_id} 不属于此活动")
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
            logger.warning(f"活动 {activity_id} 申请失败: 时间段 {request.time_slot_id} 已被其他活动 {other_relation.activity_id} 使用")
            raise HTTPException(status_code=400, detail="该时间段已被其他活动使用")
        
        # 检查时间段是否已满（在锁定的情况下检查，防止并发超卖）
        if time_slot.current_participants >= time_slot.max_participants:
            logger.warning(f"活动 {activity_id} 申请失败: 时间段 {request.time_slot_id} 已满 (当前: {time_slot.current_participants}, 最大: {time_slot.max_participants})")
            raise HTTPException(status_code=400, detail="该时间段已满")
        
        # 检查时间段是否已过期
        current_time = get_utc_time()
        if time_slot.slot_start_datetime < current_time:
            logger.warning(f"活动 {activity_id} 申请失败: 时间段 {request.time_slot_id} 已过期 (开始时间: {time_slot.slot_start_datetime}, 当前时间: {current_time})")
            raise HTTPException(status_code=400, detail="该时间段已过期")
        
        # 更新时间段的参与者数量（活动申请成功后，在锁定状态下更新）
        time_slot.current_participants += 1
        db.add(time_slot)
        
        # 创建TaskTimeSlotRelation来关联时间段（无论是单个任务还是多人任务）
        task_time_slot_relation = TaskTimeSlotRelation(
            task_id=new_task.id,
            time_slot_id=request.time_slot_id,
            relation_mode="fixed",
            auto_add_new_slots=False,
            slot_start_datetime=time_slot.slot_start_datetime,  # 冗余存储时间段信息
            slot_end_datetime=time_slot.slot_end_datetime,  # 冗余存储时间段信息
        )
        db.add(task_time_slot_relation)
    
    # 记录审计日志
    audit_log = TaskAuditLog(
        task_id=new_task.id,
        action_type="task_created_from_activity",
        action_description=f"用户申请活动 {activity_id}，创建了任务 {new_task.id}",
        user_id=current_user.id,
        new_status=initial_status,
    )
    db.add(audit_log)
    db.commit()
    
    # ⚠️ 优化：如果需要支付，返回支付信息（包括 client_secret）
    response_data = {
        "task_id": new_task.id,
        "activity_id": activity_id,
        "message": "Task created successfully from activity",
        "task_status": new_task.status,
        "is_multi_participant": is_multi_participant,
        "participant_id": participant.id if is_multi_participant else None
    }
    
    # 如果需要支付，添加支付信息
    if needs_payment and price > 0 and payment_intent_id:
        try:
            # 重新获取 PaymentIntent 以获取 client_secret
            payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)
            
            # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
            customer_id = None
            ephemeral_key_secret = None
            try:
                existing_customers = stripe.Customer.list(limit=1, metadata={"user_id": str(current_user.id)})
                if existing_customers.data:
                    customer_id = existing_customers.data[0].id
                else:
                    customer = stripe.Customer.create(
                        metadata={
                            "user_id": str(current_user.id),
                            "user_name": current_user.name or f"User {current_user.id}",
                        }
                    )
                    customer_id = customer.id

                ephemeral_key = stripe.EphemeralKey.create(
                    customer=customer_id,
                    stripe_version="2025-04-30.preview",
                )
                ephemeral_key_secret = ephemeral_key.secret
            except Exception as e:
                logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
                customer_id = None
                ephemeral_key_secret = None
            
            response_data.update({
                "payment_intent_id": payment_intent.id,
                "client_secret": payment_intent.client_secret,
                "amount": payment_intent.amount,
                "amount_display": f"{payment_intent.amount / 100:.2f}",
                "currency": payment_intent.currency.upper(),
                "customer_id": customer_id,
                "ephemeral_key_secret": ephemeral_key_secret,
                "payment_required": True,
                "payment_expires_at": new_task.payment_expires_at.isoformat() if new_task.payment_expires_at else None
            })
        except Exception as e:
            logger.error(f"获取支付信息失败: {e}")
            # 支付信息获取失败不影响主流程
    
    return response_data


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
    
    # ⚠️ 安全修复：检查支付状态，未支付的任务不能进入 in_progress 状态
    # 对于需要支付的任务（有 payment_intent_id 或 reward > 0），必须已支付
    if db_task.payment_intent_id or (db_task.reward and db_task.reward > 0):
        if db_task.is_paid != 1:
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法开始。请先完成支付。"
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
    
    # ⚠️ 安全修复：检查支付状态，确保只有已支付的任务才能完成
    # 注意：如果任务状态是 pending_payment，说明需要支付但未支付，不允许完成
    # 如果任务状态是 in_progress 但 is_paid=0，需要检查是否有 payment_intent_id
    # 如果有 payment_intent_id，说明需要支付但未支付，不允许完成
    import logging
    logger = logging.getLogger(__name__)
    
    # 如果任务状态是 pending_payment，必须支付才能完成
    if db_task.status == "pending_payment":
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试完成待支付状态的任务 {parsed_task_id}（多人任务参与者完成）"
        )
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无法完成。请联系发布者完成支付。"
        )
    
    # 如果任务状态是 in_progress 但未支付，且存在 payment_intent_id，说明需要支付但未支付
    if db_task.status == "in_progress" and not db_task.is_paid and db_task.payment_intent_id:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试完成未支付的任务 {parsed_task_id}（多人任务参与者完成，有支付意图但未支付）"
        )
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无法完成。请联系发布者完成支付。"
        )
    
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

def is_activity_expired(activity: Activity, db: Session) -> bool:
    """
    检查活动是否已过期
    
    判断逻辑：
    1. 对于时间段服务：
       - 检查 activity_end_date（在 ActivityTimeSlotRelation 中）
       - 检查最后一个时间段是否已结束
       - 如果有重复规则且 auto_add_new_slots 为 True，还需要检查是否有未来的时间段
    2. 对于非时间段服务：
       - 检查 deadline 是否已过期
    
    Returns:
        True: 活动已过期
        False: 活动未过期
    """
    from datetime import date, timedelta
    from datetime import datetime as dt_datetime, time as dt_time
    from app.utils.time_utils import parse_local_as_utc, LONDON
    
    current_time = get_utc_time()
    
    # 时间段服务：检查活动结束日期和时间段
    if activity.has_time_slots:
        # 查询重复规则关联
        recurring_relation = db.query(ActivityTimeSlotRelation).filter(
            ActivityTimeSlotRelation.activity_id == activity.id,
            ActivityTimeSlotRelation.relation_mode == "recurring"
        ).first()
        
        # 检查是否达到截至日期
        if recurring_relation and recurring_relation.activity_end_date:
            today = date.today()
            if today > recurring_relation.activity_end_date:
                return True
        
        # 查询所有固定时间段关联
        fixed_relations = db.query(ActivityTimeSlotRelation).filter(
            ActivityTimeSlotRelation.activity_id == activity.id,
            ActivityTimeSlotRelation.relation_mode == "fixed"
        ).all()
        
        if fixed_relations:
            # 获取所有关联的时间段ID
            time_slot_ids = [r.time_slot_id for r in fixed_relations if r.time_slot_id]
            if time_slot_ids:
                # 查询所有时间段，按结束时间降序排列
                time_slots = db.query(ServiceTimeSlot).filter(
                    ServiceTimeSlot.id.in_(time_slot_ids)
                ).order_by(ServiceTimeSlot.slot_end_datetime.desc()).all()
                
                if time_slots:
                    # 获取最后一个时间段
                    last_slot = time_slots[0]
                    
                    # 检查最后一个时间段是否已结束
                    if last_slot.slot_end_datetime < current_time:
                        # 如果活动有重复规则且auto_add_new_slots为True，检查是否有未来的时间段
                        if recurring_relation and recurring_relation.auto_add_new_slots:
                            # 检查是否还有未到期的匹配时间段（未来30天内）
                            future_date = date.today() + timedelta(days=30)
                            future_utc = parse_local_as_utc(
                                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                                LONDON
                            )
                            
                            # 查询服务是否有未来的时间段
                            service = db.query(TaskExpertService).filter(
                                TaskExpertService.id == activity.expert_service_id
                            ).first()
                            
                            if service:
                                future_slot = db.query(ServiceTimeSlot).filter(
                                    ServiceTimeSlot.service_id == service.id,
                                    ServiceTimeSlot.slot_start_datetime > current_time,
                                    ServiceTimeSlot.slot_start_datetime <= future_utc,
                                    ServiceTimeSlot.is_manually_deleted == False
                                ).first()
                                
                                if not future_slot:
                                    # 没有未来的时间段，活动已过期
                                    return True
                        else:
                            # 没有重复规则或auto_add_new_slots为False，最后一个时间段结束就过期
                            return True
        
        # 检查活动本身的 activity_end_date（如果设置了）
        if activity.activity_end_date:
            today = date.today()
            if today > activity.activity_end_date:
                return True
    
    # 非时间段服务：检查截止日期
    if not activity.has_time_slots and activity.deadline:
        if current_time > activity.deadline:
            return True
    
    return False


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
    
    注意：已过期的活动会自动过滤，不在任务大厅显示
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
    
    # 计算每个活动的当前参与者数量，并过滤已过期的活动
    result = []
    
    for activity in activities:
        # 实时检查活动是否已过期（即使状态还是 open）
        # 如果活动已过期，不显示在任务大厅
        # 注意：如果用户查看自己的活动（通过 expert_id 参数），即使已过期也显示
        if not expert_id and activity.status == "open" and is_activity_expired(activity, db):
            # 活动已过期，跳过不显示（除非是查看自己的活动）
            # 注意：这里不更新数据库状态，由定时任务统一处理
            continue
        
        # 统计该活动关联的任务中，状态为 accepted, in_progress, completed 的参与者数量
        # 1. 多人任务的参与者（通过TaskParticipant表）
        # 只统计任务状态不是cancelled的任务中的参与者
        multi_participant_count = db.query(func.count(TaskParticipant.id)).join(
            Task, TaskParticipant.task_id == Task.id
        ).filter(
            Task.parent_activity_id == activity.id,
            Task.is_multi_participant == True,
            Task.status != "cancelled",  # 排除已取消的任务
            TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
        ).scalar() or 0
        
        # 2. 单个任务（非多人任务，直接计数为1）
        # 只统计状态为open、taken、in_progress的任务（已排除cancelled）
        single_task_count = db.query(func.count(Task.id)).filter(
            Task.parent_activity_id == activity.id,
            Task.is_multi_participant == False,
            Task.status.in_(["open", "taken", "in_progress"])
        ).scalar() or 0
        
        # 总参与者数量 = 多人任务的参与者 + 单个任务数量
        current_count = multi_participant_count + single_task_count
        
        # 使用 from_orm_with_participants 方法创建输出对象
        from app import schemas
        activity_out = schemas.ActivityOut.from_orm_with_participants(activity, current_count)
        result.append(activity_out)
    
    return result


@router.get("/activities/{activity_id}", response_model=ActivityOut)
def get_activity_detail(
    activity_id: int,
    current_user=Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """
    获取活动详情
    """
    from app.models import Task, TaskParticipant
    from sqlalchemy import func, or_
    from sqlalchemy.orm import joinedload
    
    # 加载关联的服务信息（用于获取服务图片）
    activity = db.query(Activity).options(joinedload(Activity.service)).filter(Activity.id == activity_id).first()
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # 计算当前参与者数量
    # 1. 多人任务的参与者（通过TaskParticipant表）
    # 只统计任务状态不是cancelled的任务中的参与者
    multi_participant_count = db.query(func.count(TaskParticipant.id)).join(
        Task, TaskParticipant.task_id == Task.id
    ).filter(
        Task.parent_activity_id == activity.id,
        Task.is_multi_participant == True,
        Task.status != "cancelled",  # 排除已取消的任务
        TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
    ).scalar() or 0
    
    # 2. 单个任务（非多人任务，直接计数为1）
    # 只统计状态为open、taken、in_progress的任务（已排除cancelled）
    single_task_count = db.query(func.count(Task.id)).filter(
        Task.parent_activity_id == activity.id,
        Task.is_multi_participant == False,
        Task.status.in_(["open", "taken", "in_progress"])
    ).scalar() or 0
    
    # 总参与者数量 = 多人任务的参与者 + 单个任务数量
    current_count = multi_participant_count + single_task_count
    
    # 检查当前用户是否已申请（如果用户已登录）
    has_applied = None
    user_task_id = None
    user_task_status = None
    user_task_is_paid = None
    user_task_has_negotiation = None
    
    if current_user:
        # 检查用户是否在多人任务中申请过
        multi_participant_task = db.query(Task).join(
            TaskParticipant, Task.id == TaskParticipant.task_id
        ).filter(
            Task.parent_activity_id == activity.id,
            Task.is_multi_participant == True,
            TaskParticipant.user_id == current_user.id,
            TaskParticipant.status.in_(["pending", "accepted", "in_progress", "completed"])
        ).first()
        
        # 检查用户是否在单个任务中申请过
        single_task = db.query(Task).filter(
            Task.parent_activity_id == activity.id,
            Task.is_multi_participant == False,
            Task.originating_user_id == current_user.id,
            Task.status.in_(["open", "taken", "in_progress", "pending_payment", "completed"])
        ).first()
        
        # 优先使用单个任务（因为活动申请通常创建单个任务）
        user_task = single_task if single_task else multi_participant_task
        has_applied = user_task is not None
        
        if user_task:
            user_task_id = user_task.id
            user_task_status = user_task.status
            user_task_is_paid = bool(user_task.is_paid)
            # 检查是否有议价：agreed_reward 存在且与 base_reward 不同
            if user_task.agreed_reward is not None and user_task.base_reward is not None:
                user_task_has_negotiation = float(user_task.agreed_reward) != float(user_task.base_reward)
            else:
                user_task_has_negotiation = False
    
    # 使用 from_orm_with_participants 方法创建输出对象
    from app import schemas
    activity_out = schemas.ActivityOut.from_orm_with_participants(
        activity, current_count, 
        has_applied=has_applied,
        user_task_id=user_task_id,
        user_task_status=user_task_status,
        user_task_is_paid=user_task_is_paid,
        user_task_has_negotiation=user_task_has_negotiation
    )
    return activity_out


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
    import logging
    logger = logging.getLogger(__name__)
    
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
    
    # 检查活动是否已结束
    current_utc = get_utc_time()
    is_expired = False
    expiration_reason = ""
    
    # 检查截止日期（非时间段服务）
    if db_activity.deadline:
        if current_utc > db_activity.deadline:
            is_expired = True
            expiration_reason = "截止日期已过"
    
    # 检查活动结束日期（时间段服务）
    if not is_expired and db_activity.activity_end_date:
        from datetime import date
        if current_utc.date() > db_activity.activity_end_date:
            is_expired = True
            expiration_reason = "活动结束日期已过"
    
    # 检查是否有任务正在使用这个活动（检查所有状态，因为数据库外键约束是 RESTRICT）
    # 注意：数据库层面的 RESTRICT 约束会阻止删除任何引用此活动的任务，无论状态如何
    all_tasks_using_activity = db.query(Task).filter(
        Task.parent_activity_id == activity_id
    ).count()
    
    if all_tasks_using_activity > 0:
        # 如果活动已结束，只检查是否有已完成或进行中的任务（这些任务不应该被删除）
        if is_expired:
            active_tasks = db.query(Task).filter(
                and_(
                    Task.parent_activity_id == activity_id,
                    Task.status.in_(["in_progress", "completed"])
                )
            ).count()
            
            if active_tasks > 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"无法删除活动，虽然活动已结束（{expiration_reason}），但有 {active_tasks} 个进行中或已完成的任务。请先处理相关任务后再删除。"
                )
        else:
            # 活动未结束，检查活动状态
            if db_activity.status in ("completed", "cancelled"):
                raise HTTPException(
                    status_code=400,
                    detail=f"无法删除活动，活动状态为: {db_activity.status}"
                )
            
            # 检查是否有已开始的任务
            active_tasks = db.query(Task).filter(
                and_(
                    Task.parent_activity_id == activity_id,
                    Task.status.in_(["in_progress", "completed"])
                )
            ).count()
            
            if active_tasks > 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"无法删除活动，活动尚未结束，且有 {active_tasks} 个进行中或已完成的任务。请先处理相关任务后再删除。"
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
    
    from app.models import TaskParticipant
    
    for task in pending_tasks:
        old_task_status = task.status  # 保存旧状态
        task.status = "cancelled"
        task.updated_at = get_utc_time()
        
        # 对于多人任务，取消所有参与者的状态（pending、accepted、in_progress）
        if task.is_multi_participant:
            participants = db.query(TaskParticipant).filter(
                TaskParticipant.task_id == task.id,
                TaskParticipant.status.in_(["pending", "accepted", "in_progress"])
            ).all()
            
            for participant in participants:
                old_participant_status = participant.status
                participant.status = "cancelled"
                participant.cancelled_at = get_utc_time()
                participant.updated_at = get_utc_time()
                logger.info(f"活动取消：参与者 {participant.user_id} 的状态从 {old_participant_status} 变更为 cancelled")
        
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
    
    # 注意：TaskAuditLog 的 task_id 字段不允许为 None，所以不记录活动级别的审计日志
    # 活动的状态变更已经通过 status 字段记录在 Activity 表中
    
    # 返还未使用的预扣积分（如果有）
    refund_points = 0
    if db_activity.reserved_points_total and db_activity.reserved_points_total > 0:
        # 计算应返还的积分 = 预扣积分 - 已发放积分
        distributed = db_activity.distributed_points_total or 0
        refund_points = db_activity.reserved_points_total - distributed
        
        if refund_points > 0:
            from app.coupon_points_crud import add_points_transaction
            try:
                add_points_transaction(
                    db=db,
                    user_id=db_activity.expert_id,
                    type="refund",
                    amount=refund_points,  # 正数表示返还
                    source="activity_points_refund",
                    related_id=activity_id,
                    related_type="activity",
                    description=f"活动取消，返还未使用的预扣积分（预扣 {db_activity.reserved_points_total}，已发放 {distributed}，返还 {refund_points}）",
                    idempotency_key=f"activity_refund_{activity_id}_{refund_points}"
                )
                logger.info(f"活动 {activity_id} 取消，返还积分 {refund_points} 给用户 {db_activity.expert_id}")
            except Exception as e:
                logger.error(f"活动 {activity_id} 取消，返还积分失败: {e}")
                # 不抛出异常，继续取消活动
    
    db.commit()
    db.refresh(db_activity)
    
    return {"message": "Activity cancelled successfully", "activity_id": activity_id, "refunded_points": refund_points}


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
    
    # 如果奖励申请者积分，验证达人积分余额是否足够并预扣
    reserved_points_total = 0
    if activity.reward_applicants and activity.applicant_points_reward and activity.applicant_points_reward > 0:
        # 计算需要预扣的积分总额 = 每人积分奖励 × 最大参与人数
        reserved_points_total = activity.applicant_points_reward * activity.max_participants
        
        # 查询达人的积分账户（使用 SELECT FOR UPDATE 锁定）
        from sqlalchemy import select
        points_account_query = select(PointsAccount).where(
            PointsAccount.user_id == current_user.id
        ).with_for_update()
        points_account_result = db.execute(points_account_query)
        points_account = points_account_result.scalar_one_or_none()
        
        # 检查账户是否存在
        if not points_account:
            raise HTTPException(
                status_code=400,
                detail=f"您的积分余额不足。需要预扣 {reserved_points_total} 积分，但您当前没有积分账户。"
            )
        
        # 检查余额是否足够
        if points_account.balance < reserved_points_total:
            raise HTTPException(
                status_code=400,
                detail=f"积分余额不足。需要预扣 {reserved_points_total} 积分（每人 {activity.applicant_points_reward} × {activity.max_participants} 人），但您当前余额为 {points_account.balance} 积分。"
            )
        
        # 预扣积分（创建交易记录）
        from app.coupon_points_crud import add_points_transaction
        try:
            add_points_transaction(
                db=db,
                user_id=current_user.id,
                type="spend",
                amount=-reserved_points_total,  # 负数表示扣除
                source="activity_points_reserve",
                related_type="activity",
                description=f"创建活动预扣积分奖励（{activity.applicant_points_reward}积分 × {activity.max_participants}人）",
                idempotency_key=f"activity_reserve_{current_user.id}_{activity.title}_{reserved_points_total}_{db.execute(select(func.now())).scalar()}"
            )
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
    
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
        # 奖励申请者相关字段
        reward_applicants=activity.reward_applicants,
        applicant_reward_amount=activity.applicant_reward_amount if activity.reward_applicants and activity.reward_type in ("cash", "both") else None,
        applicant_points_reward=activity.applicant_points_reward if activity.reward_applicants and activity.reward_type in ("points", "both") else None,
        reserved_points_total=reserved_points_total if reserved_points_total > 0 else None,
        distributed_points_total=0,
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
                    activity_end_date=activity.activity_end_date,
                    slot_start_datetime=slot.slot_start_datetime,  # 冗余存储时间段信息
                    slot_end_datetime=slot.slot_end_datetime,  # 冗余存储时间段信息
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
            today = get_utc_time().date()
            future_date = get_utc_time().date()
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
                            auto_add_new_slots=False,
                            slot_start_datetime=slot.slot_start_datetime,  # 冗余存储时间段信息
                            slot_end_datetime=slot.slot_end_datetime,  # 冗余存储时间段信息
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
            today = get_utc_time().date()
            future_date = get_utc_time().date()
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
                            auto_add_new_slots=False,
                            slot_start_datetime=slot.slot_start_datetime,  # 冗余存储时间段信息
                            slot_end_datetime=slot.slot_end_datetime,  # 冗余存储时间段信息
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
    
    # ⚠️ 安全修复：检查支付状态，未支付的任务不能进入 in_progress 状态
    # 对于需要支付的任务（有 payment_intent_id 或 reward > 0），必须已支付
    if db_task.payment_intent_id or (db_task.reward and db_task.reward > 0):
        if db_task.is_paid != 1:
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法开始。请先完成支付。"
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
    
    # 更新任务的参与者数量（如果是多人任务且参与者之前是accepted或in_progress状态）
    if db_task.is_multi_participant and participant.previous_status in ("accepted", "in_progress"):
        if db_task.current_participants > 0:
            db_task.current_participants -= 1
        db.add(db_task)
    
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
    background_tasks: BackgroundTasks,
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
    
    # 更新任务的参与者数量（如果是多人任务且参与者之前是accepted或in_progress状态）
    if db_task.is_multi_participant and participant.previous_status in ("accepted", "in_progress"):
        if db_task.current_participants > 0:
            db_task.current_participants -= 1
        db.add(db_task)
    
    # 更新时间段的参与者数量（如果参与者有关联的时间段）
    time_slot_id_to_update = None
    if participant.time_slot_id:
        time_slot_id_to_update = participant.time_slot_id
        time_slot = db.query(ServiceTimeSlot).filter(
            ServiceTimeSlot.id == participant.time_slot_id
        ).with_for_update().first()
        if time_slot and time_slot.current_participants > 0:
            time_slot.current_participants -= 1
            # 如果时间段现在有空位，确保is_available为True
            if time_slot.current_participants < time_slot.max_participants:
                time_slot.is_available = True
            db.add(time_slot)
    
    # 如果任务通过TaskTimeSlotRelation关联了时间段，也需要更新
    task_time_slot_relation = db.query(TaskTimeSlotRelation).filter(
        TaskTimeSlotRelation.task_id == parsed_task_id
    ).first()
    if task_time_slot_relation and task_time_slot_relation.time_slot_id:
        relation_time_slot_id = task_time_slot_relation.time_slot_id
        # 如果和participant.time_slot_id不同，也需要更新
        if relation_time_slot_id != time_slot_id_to_update:
            relation_time_slot = db.query(ServiceTimeSlot).filter(
                ServiceTimeSlot.id == relation_time_slot_id
            ).with_for_update().first()
            if relation_time_slot and relation_time_slot.current_participants > 0:
                relation_time_slot.current_participants -= 1
                if relation_time_slot.current_participants < relation_time_slot.max_participants:
                    relation_time_slot.is_available = True
                db.add(relation_time_slot)
                time_slot_id_to_update = relation_time_slot_id
    
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
    
    # 如果任务有关联的活动，重新计算活动的参与者数量
    if db_task.parent_activity_id:
        from sqlalchemy import func
        # 统计该活动关联的多人任务中，状态为 accepted, in_progress 的参与者数量
        multi_participant_count = db.query(func.count(TaskParticipant.id)).join(
            Task, TaskParticipant.task_id == Task.id
        ).filter(
            Task.parent_activity_id == db_task.parent_activity_id,
            Task.is_multi_participant == True,
            TaskParticipant.status.in_(["accepted", "in_progress"])
        ).scalar() or 0
        
        # 统计该活动关联的单个任务中，状态为 open, taken, in_progress 的任务数量
        single_task_count = db.query(func.count(Task.id)).filter(
            Task.parent_activity_id == db_task.parent_activity_id,
            Task.is_multi_participant == False,
            Task.status.in_(["open", "taken", "in_progress"])
        ).scalar() or 0
        
        # 注意：活动的current_participants是动态计算的，不需要更新数据库字段
        # 但我们需要通过WebSocket通知其他用户活动参与者数量变化
    
    db.commit()
    
    # 通过WebSocket通知其他用户时间段可用性变化
    # 使用 BackgroundTasks 在后台执行异步操作
    if time_slot_id_to_update:
        # 获取时间段信息
        updated_time_slot = db.query(ServiceTimeSlot).filter(
            ServiceTimeSlot.id == time_slot_id_to_update
        ).first()
        
        if updated_time_slot:
            import logging
            logger = logging.getLogger(__name__)
            
            # 构建通知消息
            notification = {
                "type": "time_slot_availability_changed",
                "time_slot_id": updated_time_slot.id,
                "service_id": updated_time_slot.service_id,
                "current_participants": updated_time_slot.current_participants,
                "max_participants": updated_time_slot.max_participants,
                "is_available": updated_time_slot.is_available,
                "message": "时间段可用性已更新"
            }
            
            # 使用 BackgroundTasks 执行异步 WebSocket 广播
            async def broadcast_notification():
                try:
                    from app.websocket_manager import get_ws_manager
                    ws_manager = get_ws_manager()
                    # 使用 WebSocketManager 的 broadcast 方法，排除操作者本人
                    await ws_manager.broadcast(
                        notification,
                        exclude_users={str(current_user.id)}
                    )
                except Exception as e:
                    logger.error(f"Failed to broadcast time slot availability via WebSocket: {e}", exc_info=True)
            
            # 使用 BackgroundTasks 添加异步任务
            background_tasks.add_task(broadcast_notification)
    
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


# ==================== 活动收藏 API ====================

@router.post("/activities/{activity_id}/favorite", response_model=dict)
def toggle_activity_favorite(
    activity_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """收藏/取消收藏活动"""
    try:
        # 检查活动是否存在
        activity = db.query(Activity).filter(Activity.id == activity_id).first()
        if not activity:
            raise HTTPException(
                status_code=404,
                detail="活动不存在"
            )
        
        # 检查是否已收藏
        favorite = db.query(ActivityFavorite).filter(
            and_(
                ActivityFavorite.activity_id == activity_id,
                ActivityFavorite.user_id == current_user.id
            )
        ).first()
        
        if favorite:
            # 取消收藏
            db.delete(favorite)
            db.commit()
            return {
                "success": True,
                "data": {"is_favorited": False},
                "message": "已取消收藏"
            }
        else:
            # 添加收藏
            new_favorite = ActivityFavorite(
                user_id=current_user.id,
                activity_id=activity_id
            )
            db.add(new_favorite)
            db.commit()
            return {
                "success": True,
                "data": {"is_favorited": True},
                "message": "收藏成功"
            }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"收藏操作失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="操作失败"
        )


@router.get("/activities/{activity_id}/favorite/status", response_model=dict)
def get_activity_favorite_status(
    activity_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取活动收藏状态"""
    try:
        # 检查活动是否存在
        activity = db.query(Activity).filter(Activity.id == activity_id).first()
        if not activity:
            raise HTTPException(
                status_code=404,
                detail="活动不存在"
            )
        
        # 检查是否已收藏
        favorite = db.query(ActivityFavorite).filter(
            and_(
                ActivityFavorite.activity_id == activity_id,
                ActivityFavorite.user_id == current_user.id
            )
        ).first()
        
        # 获取收藏总数
        favorite_count = db.query(ActivityFavorite).filter(
            ActivityFavorite.activity_id == activity_id
        ).count()
        
        return {
            "success": True,
            "data": {
                "is_favorited": favorite is not None,
                "favorite_count": favorite_count
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"获取收藏状态失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="操作失败"
        )


@router.get("/my/activities", response_model=dict)
def get_my_activities(
    type: str = Query("all", description="活动类型：all（全部）、applied（申请过的）、favorited（收藏的）"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取我的活动（申请过的和收藏的）"""
    try:
        from sqlalchemy import distinct
        from sqlalchemy.orm import joinedload
        from app.models import TaskParticipant
        
        activities_list = []
        total = 0
        
        if type == "applied" or type == "all":
            # 获取申请过的活动（通过TaskParticipant表）
            applied_query = db.query(distinct(TaskParticipant.activity_id)).filter(
                and_(
                    TaskParticipant.user_id == current_user.id,
                    TaskParticipant.activity_id.isnot(None)
                )
            )
            applied_activity_ids = [row[0] for row in applied_query.all()]
            
            if applied_activity_ids:
                applied_activities = db.query(Activity).options(
                    joinedload(Activity.service)
                ).filter(Activity.id.in_(applied_activity_ids)).all()
                
                for activity in applied_activities:
                    # 计算当前参与者数量
                    current_count = db.query(TaskParticipant).filter(
                        and_(
                            TaskParticipant.activity_id == activity.id,
                            TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    ).count()
                    
                    # 获取用户在该活动中的参与状态
                    user_participant = db.query(TaskParticipant).filter(
                        and_(
                            TaskParticipant.activity_id == activity.id,
                            TaskParticipant.user_id == current_user.id
                        )
                    ).first()
                    
                    # 使用from_orm_with_participants方法
                    activity_out = ActivityOut.from_orm_with_participants(activity, current_count)
                    
                    # 转换为字典并处理日期序列化
                    from fastapi.encoders import jsonable_encoder
                    activity_dict = jsonable_encoder(activity_out)
                    activity_dict["type"] = "applied"
                    activity_dict["participant_status"] = user_participant.status if user_participant else None
                    activities_list.append(activity_dict)
        
        if type == "favorited" or type == "all":
            # 获取收藏的活动
            favorited_query = db.query(ActivityFavorite.activity_id).filter(
                ActivityFavorite.user_id == current_user.id
            )
            favorited_activity_ids = [row[0] for row in favorited_query.all()]
            
            if favorited_activity_ids:
                favorited_activities = db.query(Activity).options(
                    joinedload(Activity.service)
                ).filter(Activity.id.in_(favorited_activity_ids)).all()
                
                for activity in favorited_activities:
                    # 如果已经在applied列表中，跳过（避免重复）
                    if any(a["id"] == activity.id for a in activities_list):
                        # 更新类型为both
                        for a in activities_list:
                            if a["id"] == activity.id:
                                a["type"] = "both"
                                break
                        continue
                    
                    # 计算当前参与者数量
                    current_count = db.query(TaskParticipant).filter(
                        and_(
                            TaskParticipant.activity_id == activity.id,
                            TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    ).count()
                    
                    # 使用from_orm_with_participants方法
                    activity_out = ActivityOut.from_orm_with_participants(activity, current_count)
                    
                    # 转换为字典并处理日期序列化
                    from fastapi.encoders import jsonable_encoder
                    activity_dict = jsonable_encoder(activity_out)
                    activity_dict["type"] = "favorited"
                    activities_list.append(activity_dict)
        
        # 按创建时间倒序排序
        activities_list.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        
        total = len(activities_list)
        
        # 分页
        paginated_activities = activities_list[offset:offset + limit]
        
        return {
            "success": True,
            "data": {
                "activities": paginated_activities,
                "total": total,
                "limit": limit,
                "offset": offset,
                "has_more": offset + limit < total
            }
        }
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"获取我的活动失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="操作失败"
        )


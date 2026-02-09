"""
管理员 - 任务争议管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-任务争议管理"])


@router.get("/admin/task-disputes", response_model=dict)
def get_admin_task_disputes(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    keyword: Optional[str] = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务争议列表"""
    query = db.query(models.TaskDispute)
    
    # 状态筛选
    if status:
        query = query.filter(models.TaskDispute.status == status)
    
    # 关键词搜索（任务标题、发布者姓名、争议原因）
    has_keyword_search = keyword and keyword.strip()
    if has_keyword_search:
        keyword = keyword.strip()
        # 使用JOIN查询任务和用户信息
        query = query.join(models.Task, models.TaskDispute.task_id == models.Task.id).join(
            models.User, models.TaskDispute.poster_id == models.User.id
        ).filter(
            or_(
                models.Task.title.ilike(f'%{keyword}%'),
                models.User.name.ilike(f'%{keyword}%'),
                models.TaskDispute.reason.ilike(f'%{keyword}%')
            )
        )
    
    # 按创建时间倒序
    query = query.order_by(models.TaskDispute.created_at.desc())
    
    # 总数（如果有关键词搜索，需要去重计数）
    if has_keyword_search:
        total = query.distinct().count()
    else:
        total = query.count()
    
    # 分页 - 使用JOIN优化查询，避免N+1问题
    # 如果有关键词搜索，已经JOIN了Task和User，需要去重
    if has_keyword_search:
        disputes = (
            query
            .options(
                joinedload(models.TaskDispute.task),
                joinedload(models.TaskDispute.poster),
                joinedload(models.TaskDispute.resolver)
            )
            .distinct()
            .offset(skip)
            .limit(limit)
            .all()
        )
    else:
        disputes = (
            query
            .options(
                joinedload(models.TaskDispute.task),  # 预加载任务信息
                joinedload(models.TaskDispute.poster),  # 预加载发布者信息
                joinedload(models.TaskDispute.resolver)  # 预加载处理人信息
            )
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    # 构建返回数据（关联数据已预加载，无需额外查询）
    disputes_with_task = []
    for dispute in disputes:
        task = dispute.task  # 已预加载
        poster = dispute.poster  # 已预加载
        resolver = dispute.resolver  # 已预加载
        
        dispute_dict = {
            "id": dispute.id,
            "task_id": dispute.task_id,
            "task_title": task.title if task else "任务已删除",
            "poster_id": dispute.poster_id,
            "poster_name": poster.name if poster else f"用户{dispute.poster_id}",
            "reason": dispute.reason,
            "status": dispute.status,
            "created_at": dispute.created_at,
            "resolved_at": dispute.resolved_at,
            "resolved_by": dispute.resolved_by,
            "resolver_name": resolver.name if resolver else None,
            "resolution_note": dispute.resolution_note,
        }
        disputes_with_task.append(dispute_dict)
    
    return {
        "disputes": disputes_with_task,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/admin/task-disputes/{dispute_id}")
def get_admin_task_dispute_detail(
    dispute_id: int,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务争议详情（包含关联信息）"""
    dispute = db.query(models.TaskDispute).filter(models.TaskDispute.id == dispute_id).first()
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    # 获取关联的任务信息
    task = crud.get_task(db, dispute.task_id)
    poster = crud.get_user_by_id(db, dispute.poster_id)
    taker = crud.get_user_by_id(db, task.taker_id) if task and task.taker_id else None
    resolver = crud.get_user_by_id(db, dispute.resolved_by) if dispute.resolved_by else None
    
    # 计算任务金额（优先使用agreed_reward，否则使用base_reward）
    task_amount = None
    if task:
        if task.agreed_reward is not None:
            task_amount = float(task.agreed_reward)
        elif task.base_reward is not None:
            task_amount = float(task.base_reward)
        else:
            task_amount = float(task.reward) if task.reward else 0.0
    
    return {
        "id": dispute.id,
        "task_id": dispute.task_id,
        "task_title": task.title if task else "任务已删除",
        "task_status": task.status if task else None,
        "task_description": task.description if task else None,
        "task_created_at": task.created_at if task else None,
        "task_accepted_at": task.accepted_at if task else None,
        "task_completed_at": task.completed_at if task else None,
        "poster_id": dispute.poster_id,
        "poster_name": poster.name if poster else f"用户{dispute.poster_id}",
        "taker_id": task.taker_id if task else None,
        "taker_name": taker.name if taker else (f"用户{task.taker_id}" if task and task.taker_id else None),
        "task_amount": task_amount,
        "base_reward": float(task.base_reward) if task and task.base_reward else None,
        "agreed_reward": float(task.agreed_reward) if task and task.agreed_reward else None,
        "currency": task.currency if task else "GBP",
        "reason": dispute.reason,
        "status": dispute.status,
        "created_at": dispute.created_at,
        "resolved_at": dispute.resolved_at,
        "resolved_by": dispute.resolved_by,
        "resolver_name": resolver.name if resolver else None,
        "resolution_note": dispute.resolution_note,
    }


@router.post("/admin/task-disputes/{dispute_id}/resolve", response_model=schemas.TaskDisputeOut)
def resolve_task_dispute(
    dispute_id: int,
    resolution: schemas.TaskDisputeResolve,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员处理任务争议 - 原子事务，包含退款/转账逻辑"""
    from sqlalchemy import select, and_, func
    from decimal import Decimal
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定争议记录
    locked_dispute_query = select(models.TaskDispute).where(
        models.TaskDispute.id == dispute_id
    ).with_for_update()
    dispute = db.execute(locked_dispute_query).scalar_one_or_none()
    
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    if dispute.status != "pending":
        raise HTTPException(status_code=400, detail="Dispute is already resolved")
    
    # 🔒 同时锁定关联任务，确保原子操作
    locked_task_query = select(models.Task).where(
        models.Task.id == dispute.task_id
    ).with_for_update()
    task = db.execute(locked_task_query).scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 验证 resolution_type
    valid_types = {"refund_poster", "partial_refund", "pay_taker", "dismiss"}
    resolution_type = resolution.resolution_type
    if resolution_type not in valid_types:
        raise HTTPException(
            status_code=400,
            detail=f"无效的裁决类型: {resolution_type}。有效类型: {', '.join(valid_types)}"
        )
    
    try:
        # 更新争议状态
        dispute.status = "resolved"
        dispute.resolved_at = get_utc_time()
        dispute.resolved_by = current_user.id
        dispute.resolution_note = f"[{resolution_type}] {resolution.resolution_note}"
        
        if resolution_type == "refund_poster":
            # 全额退款给发布者
            task.status = "cancelled"
            
            if task.is_paid and task.payment_intent_id:
                # 自动创建退款申请并处理
                from app.refund_service import process_refund
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                
                # 创建退款申请记录
                refund_request = models.RefundRequest(
                    task_id=task.id,
                    poster_id=task.poster_id,
                    reason=f"争议裁决：全额退款 - {resolution.resolution_note}",
                    refund_amount=Decimal(str(task_amount)),
                    status="processing",
                    reviewed_by=current_user.id,
                    reviewed_at=get_utc_time(),
                    admin_comment=f"争议 #{dispute_id} 裁决：全额退款给发布者",
                    processed_at=get_utc_time(),
                )
                db.add(refund_request)
                db.flush()  # 获取ID
                
                success, refund_intent_id, refund_transfer_id, error_msg = process_refund(
                    db=db,
                    refund_request=refund_request,
                    task=task,
                    refund_amount=task_amount
                )
                
                if success:
                    refund_request.status = "completed"
                    refund_request.refund_intent_id = refund_intent_id
                    refund_request.refund_transfer_id = refund_transfer_id
                    refund_request.completed_at = get_utc_time()
                    logger.info(f"✅ 争议 {dispute_id} 全额退款成功: £{task_amount:.2f}")
                else:
                    refund_request.status = "failed"
                    refund_request.admin_comment += f"\n退款处理失败: {error_msg}"
                    logger.error(f"❌ 争议 {dispute_id} 全额退款失败: {error_msg}")
                    raise HTTPException(status_code=500, detail=f"退款处理失败: {error_msg}")
        
        elif resolution_type == "partial_refund":
            # 部分退款
            if not resolution.refund_amount or resolution.refund_amount <= 0:
                raise HTTPException(status_code=400, detail="部分退款必须指定有效的退款金额")
            
            task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
            if resolution.refund_amount >= task_amount:
                raise HTTPException(
                    status_code=400,
                    detail=f"部分退款金额（£{resolution.refund_amount:.2f}）不能大于等于任务金额（£{task_amount:.2f}），请使用全额退款"
                )
            
            task.status = "completed"
            
            if task.is_paid and task.payment_intent_id:
                from app.refund_service import process_refund
                
                refund_request = models.RefundRequest(
                    task_id=task.id,
                    poster_id=task.poster_id,
                    reason=f"争议裁决：部分退款 - {resolution.resolution_note}",
                    refund_amount=Decimal(str(resolution.refund_amount)),
                    status="processing",
                    reviewed_by=current_user.id,
                    reviewed_at=get_utc_time(),
                    admin_comment=f"争议 #{dispute_id} 裁决：部分退款 £{resolution.refund_amount:.2f}",
                    processed_at=get_utc_time(),
                )
                db.add(refund_request)
                db.flush()
                
                success, refund_intent_id, refund_transfer_id, error_msg = process_refund(
                    db=db,
                    refund_request=refund_request,
                    task=task,
                    refund_amount=resolution.refund_amount
                )
                
                if success:
                    refund_request.status = "completed"
                    refund_request.refund_intent_id = refund_intent_id
                    refund_request.refund_transfer_id = refund_transfer_id
                    refund_request.completed_at = get_utc_time()
                    logger.info(f"✅ 争议 {dispute_id} 部分退款成功: £{resolution.refund_amount:.2f}")
                else:
                    refund_request.status = "failed"
                    logger.error(f"❌ 争议 {dispute_id} 部分退款失败: {error_msg}")
                    raise HTTPException(status_code=500, detail=f"部分退款处理失败: {error_msg}")
        
        elif resolution_type == "pay_taker":
            # 支付给接单者 - 确认任务完成并触发转账
            task.status = "completed"
            task.confirmed_at = get_utc_time()
            task.auto_confirmed = 1  # 通过争议裁决确认
            task.is_confirmed = 1
            
            if task.is_paid and task.taker_id and task.escrow_amount and task.escrow_amount > 0:
                from app.payment_transfer_service import create_transfer_record, execute_transfer
                
                # 检查是否已有成功的转账
                total_transferred = db.query(
                    func.sum(models.PaymentTransfer.amount).label('total')
                ).filter(
                    and_(
                        models.PaymentTransfer.task_id == task.id,
                        models.PaymentTransfer.status == "succeeded"
                    )
                ).scalar() or Decimal('0')
                total_transferred = Decimal(str(total_transferred))
                remaining_escrow = Decimal(str(task.escrow_amount))
                transfer_amount = remaining_escrow - total_transferred
                
                if transfer_amount > Decimal('0.01'):
                    # 检查是否已有待处理的转账
                    existing_pending = db.query(models.PaymentTransfer).filter(
                        and_(
                            models.PaymentTransfer.task_id == task.id,
                            models.PaymentTransfer.status.in_(["pending", "retrying"])
                        )
                    ).first()
                    
                    if not existing_pending:
                        transfer_record = create_transfer_record(
                            db=db,
                            task_id=task.id,
                            taker_id=task.taker_id,
                            poster_id=task.poster_id,
                            amount=transfer_amount,
                            currency="GBP",
                            metadata={
                                "transfer_source": "dispute_resolution",
                                "dispute_id": str(dispute_id),
                            },
                            commit=False
                        )
                        
                        # 尝试立即执行转账
                        taker = crud.get_user_by_id(db, task.taker_id)
                        if taker and taker.stripe_account_id:
                            success, transfer_id, error_msg = execute_transfer(db, transfer_record, taker.stripe_account_id)
                            if success:
                                task.escrow_amount = 0.0
                                task.paid_to_user_id = task.taker_id
                                logger.info(f"✅ 争议 {dispute_id} 转账成功: £{transfer_amount:.2f}")
                            else:
                                logger.warning(f"⚠️ 争议 {dispute_id} 转账失败: {error_msg}，已创建转账记录，定时任务将自动重试")
                        else:
                            logger.info(f"ℹ️ 争议 {dispute_id} 接单人未设置Stripe账户，已创建转账记录")
                else:
                    task.escrow_amount = 0.0
                    task.paid_to_user_id = task.taker_id
                    logger.info(f"ℹ️ 争议 {dispute_id} 已全额转账，无需额外转账")
        
        elif resolution_type == "dismiss":
            # 驳回争议，恢复任务状态
            task.status = "pending_confirmation"
        
        # 发送通知给相关用户
        try:
            resolution_type_names = {
                "refund_poster": "全额退款给发布者",
                "partial_refund": "部分退款",
                "pay_taker": "支付给接单者",
                "dismiss": "驳回争议",
            }
            result_text = resolution_type_names.get(resolution_type, resolution_type)
            
            crud.create_notification(
                db=db,
                user_id=task.poster_id,
                type="dispute_resolved",
                title="争议已处理",
                content=f"您的任务「{task.title}」的争议已处理，裁决结果：{result_text}",
                related_id=str(task.id),
                auto_commit=False,
                title_en="Dispute Resolved",
                content_en=f"Dispute for task '{task.title}' has been resolved: {resolution_type}",
            )
            if task.taker_id:
                crud.create_notification(
                    db=db,
                    user_id=task.taker_id,
                    type="dispute_resolved",
                    title="争议已处理",
                    content=f"您接受的任务「{task.title}」的争议已处理，裁决结果：{result_text}",
                    related_id=str(task.id),
                    auto_commit=False,
                    title_en="Dispute Resolved",
                    content_en=f"Dispute for task '{task.title}' has been resolved: {resolution_type}",
                )
        except Exception as e:
            logger.warning(f"发送争议处理通知失败: {e}")
        
        db.commit()
        db.refresh(dispute)
        
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"处理争议 {dispute_id} 失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"处理争议失败: {str(e)}")
    
    return dispute


@router.post("/admin/task-disputes/{dispute_id}/dismiss", response_model=schemas.TaskDisputeOut)
def dismiss_task_dispute(
    dispute_id: int,
    dismissal: schemas.TaskDisputeDismiss,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员驳回任务争议"""
    from sqlalchemy import select
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定争议记录
    locked_dispute_query = select(models.TaskDispute).where(
        models.TaskDispute.id == dispute_id
    ).with_for_update()
    dispute = db.execute(locked_dispute_query).scalar_one_or_none()
    
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    if dispute.status != "pending":
        raise HTTPException(status_code=400, detail="Dispute is already resolved")
    
    try:
        # 更新争议状态
        dispute.status = "dismissed"
        dispute.resolved_at = get_utc_time()
        dispute.resolved_by = current_user.id
        dispute.resolution_note = dismissal.reason
        
        # 🔒 锁定任务并恢复状态
        locked_task_query = select(models.Task).where(
            models.Task.id == dispute.task_id
        ).with_for_update()
        task = db.execute(locked_task_query).scalar_one_or_none()
        
        if task and task.status == "disputed":
            task.status = "pending_confirmation"
        
        # 发送通知
        try:
            if task:
                crud.create_notification(
                    db=db,
                    user_id=task.poster_id,
                    type="dispute_dismissed",
                    title="争议已驳回",
                    content=f"您的任务「{task.title}」的争议已被管理员驳回，任务恢复为待确认状态",
                    related_id=str(task.id),
                    auto_commit=False,
                    title_en="Dispute Dismissed",
                    content_en=f"Dispute for task '{task.title}' has been dismissed",
                )
        except Exception as e:
            logger.warning(f"发送争议驳回通知失败: {e}")
        
        db.commit()
        db.refresh(dispute)
        
    except Exception as e:
        db.rollback()
        logger.error(f"驳回争议 {dispute_id} 失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"驳回争议失败: {str(e)}")
    
    return dispute

"""
管理员 - 退款申请管理路由
从 routers.py 迁移
"""
import json
import logging
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, select

from app import crud, models, schemas
from app.audit_logger import log_admin_action
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-退款管理"])


@router.get("/admin/refund-requests", response_model=dict)
def get_admin_refund_requests(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    keyword: Optional[str] = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取退款申请列表"""
    query = db.query(models.RefundRequest)
    
    # 状态筛选
    if status:
        query = query.filter(models.RefundRequest.status == status)
    
    # 关键词搜索（任务标题、发布者姓名、退款原因）
    has_keyword_search = keyword and keyword.strip()
    if has_keyword_search:
        query = query.join(models.Task, models.RefundRequest.task_id == models.Task.id).join(
            models.User, models.RefundRequest.poster_id == models.User.id
        ).filter(
            or_(
                models.Task.title.ilike(f'%{keyword}%'),
                models.User.name.ilike(f'%{keyword}%'),
                models.RefundRequest.reason.ilike(f'%{keyword}%')
            )
        )
    
    # 排序：按创建时间倒序
    query = query.order_by(models.RefundRequest.created_at.desc())
    
    # 总数
    total = query.count()
    
    # 分页
    refund_requests = query.offset(skip).limit(limit).all()
    
    # 处理证据文件（JSON数组转List）和解析退款信息
    result_list = []
    reason_type_names = {
        "completion_time_unsatisfactory": "对完成时间不满意",
        "not_completed": "接单者完全未完成",
        "quality_issue": "质量问题",
        "other": "其他"
    }
    
    for refund_request in refund_requests:
        evidence_files = None
        if refund_request.evidence_files:
            try:
                evidence_files = json.loads(refund_request.evidence_files)
            except:
                evidence_files = []
        
        # 解析退款原因字段（格式：reason_type|refund_type|reason）
        reason_type = None
        refund_type = None
        reason_text = refund_request.reason
        refund_percentage = None
        
        if "|" in refund_request.reason:
            parts = refund_request.reason.split("|", 2)
            if len(parts) >= 3:
                reason_type = parts[0]
                refund_type = parts[1]
                reason_text = parts[2]
        
        # 计算退款比例（如果有任务金额和退款金额）
        if refund_request.refund_amount and refund_request.task:
            task_amount = float(refund_request.task.agreed_reward) if refund_request.task.agreed_reward else float(refund_request.task.base_reward) if refund_request.task.base_reward else 0.0
            if task_amount > 0:
                refund_percentage = (float(refund_request.refund_amount) / task_amount) * 100
        
        result_list.append({
            "id": refund_request.id,
            "task_id": refund_request.task_id,
            "poster_id": refund_request.poster_id,
            "reason_type": reason_type,
            "reason_type_display": reason_type_names.get(reason_type, reason_type) if reason_type else None,
            "refund_type": refund_type,
            "refund_type_display": "全额退款" if refund_type == "full" else "部分退款" if refund_type == "partial" else None,
            "reason": reason_text,
            "evidence_files": evidence_files,
            "refund_amount": float(refund_request.refund_amount) if refund_request.refund_amount else None,
            "refund_percentage": refund_percentage,
            "status": refund_request.status,
            "admin_comment": refund_request.admin_comment,
            "reviewed_by": refund_request.reviewed_by,
            "reviewed_at": refund_request.reviewed_at,
            "refund_intent_id": refund_request.refund_intent_id,
            "refund_transfer_id": refund_request.refund_transfer_id,
            "processed_at": refund_request.processed_at,
            "completed_at": refund_request.completed_at,
            "created_at": refund_request.created_at,
            "updated_at": refund_request.updated_at,
            "task": {
                "id": refund_request.task.id,
                "title": refund_request.task.title,
                "base_reward": float(refund_request.task.base_reward),
                "agreed_reward": float(refund_request.task.agreed_reward) if refund_request.task.agreed_reward else None,
                "is_paid": refund_request.task.is_paid,
                "is_confirmed": refund_request.task.is_confirmed,
                "status": refund_request.task.status,
            } if refund_request.task else None,
            "poster": {
                "id": refund_request.poster.id,
                "name": refund_request.poster.name,
                "email": refund_request.poster.email,
            } if refund_request.poster else None,
        })
    
    return {
        "total": total,
        "items": result_list,
        "skip": skip,
        "limit": limit
    }


@router.post("/admin/refund-requests/{refund_id}/approve", response_model=schemas.RefundRequestOut)
def approve_refund_request(
    refund_id: int,
    approve_data: schemas.RefundRequestApprove,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员批准退款申请"""
    # 🔒 安全修复：大额退款（>£100）需要超级管理员权限
    # 先查询退款金额，在锁定前检查权限
    refund_check = db.query(models.RefundRequest).filter(
        models.RefundRequest.id == refund_id
    ).first()
    if refund_check and refund_check.refund_amount and float(refund_check.refund_amount) > 100.0:
        if not getattr(current_user, 'is_super_admin', 0):
            raise HTTPException(
                status_code=403,
                detail="大额退款（>£100）需要超级管理员权限"
            )
    
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.status == "pending"
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()
    
    if not refund_request:
        existing = db.query(models.RefundRequest).filter(
            models.RefundRequest.id == refund_id
        ).first()
        if existing:
            raise HTTPException(
                status_code=400, 
                detail=f"退款申请状态不正确，无法批准。当前状态: {existing.status}"
            )
        raise HTTPException(status_code=404, detail="Refund request not found")
    
    # 获取任务信息
    task = crud.get_task(db, refund_request.task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # ✅ 安全修复：验证任务仍然已支付
    if not task.is_paid:
        raise HTTPException(
            status_code=400,
            detail="任务已不再支付，无法处理退款。可能已被取消或退款。"
        )
    
    # ✅ 安全修复：验证任务状态仍然允许退款
    if task.status not in ["pending_confirmation", "in_progress", "completed"]:
        raise HTTPException(
            status_code=400,
            detail=f"任务状态已改变（当前状态: {task.status}），无法处理退款。"
        )
    
    # ✅ Stripe争议冻结检查
    if hasattr(task, 'stripe_dispute_frozen') and task.stripe_dispute_frozen == 1:
        raise HTTPException(
            status_code=400,
            detail="任务因Stripe争议已冻结，无法处理退款。请等待争议解决后再试。"
        )
    
    # 更新退款申请状态
    refund_request.status = "approved"
    refund_request.reviewed_by = current_user.id
    refund_request.reviewed_at = get_utc_time()
    refund_request.admin_comment = approve_data.admin_comment
    
    # ✅ 修复金额精度：使用Decimal进行金额计算
    task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
    
    # ✅ 安全修复：如果管理员指定了不同的退款金额，验证金额合理性
    if approve_data.refund_amount is not None:
        admin_refund_amount = Decimal(str(approve_data.refund_amount))
        
        if admin_refund_amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="退款金额必须大于0"
            )
        
        if admin_refund_amount > task_amount:
            raise HTTPException(
                status_code=400,
                detail=f"管理员指定的退款金额（£{admin_refund_amount:.2f}）超过任务金额（£{task_amount:.2f}）"
            )
        
        # 计算已转账的总金额
        total_transferred = db.query(
            func.sum(models.PaymentTransfer.amount).label('total_transferred')
        ).filter(
            and_(
                models.PaymentTransfer.task_id == task.id,
                models.PaymentTransfer.status == "succeeded"
            )
        ).scalar() or Decimal('0')
        total_transferred = Decimal(str(total_transferred)) if total_transferred else Decimal('0')
        
        current_escrow = Decimal(str(task.escrow_amount)) if task.escrow_amount else Decimal('0')
        
        if total_transferred > 0:
            max_refundable = task_amount - total_transferred
            if admin_refund_amount > max_refundable:
                raise HTTPException(
                    status_code=400,
                    detail=f"退款金额（£{admin_refund_amount:.2f}）超过可退款金额（£{max_refundable:.2f}）"
                )
        elif admin_refund_amount > current_escrow:
            raise HTTPException(
                status_code=400,
                detail=f"退款金额（£{admin_refund_amount:.2f}）超过可用金额（£{current_escrow:.2f}）"
            )
        
        refund_request.refund_amount = admin_refund_amount
    
    # 计算最终退款金额
    refund_amount = Decimal(str(refund_request.refund_amount)) if refund_request.refund_amount else task_amount
    refund_amount_float = float(refund_amount)
    
    # 开始处理退款
    refund_request.status = "processing"
    refund_request.processed_at = get_utc_time()
    db.flush()
    
    try:
        from app.refund_service import process_refund
        success, refund_intent_id, refund_transfer_id, error_message = process_refund(
            db=db,
            refund_request=refund_request,
            task=task,
            refund_amount=refund_amount_float
        )
        
        if success:
            refund_request.refund_intent_id = refund_intent_id
            refund_request.refund_transfer_id = refund_transfer_id
            refund_request.status = "completed"
            refund_request.completed_at = get_utc_time()
            
            # 发送系统消息
            try:
                admin_name = current_user.name or f"管理员{current_user.id}"
                content_zh = f"管理员 {admin_name} 已批准您的退款申请，退款金额：£{refund_amount_float:.2f}。"
                content_en = f"Admin {admin_name} has approved your refund request. Refund amount: £{refund_amount_float:.2f}."
                
                system_message = models.Message(
                    sender_id=None,
                    receiver_id=None,
                    content=content_zh,
                    task_id=task.id,
                    message_type="system",
                    conversation_type="task",
                    meta=json.dumps({
                        "system_action": "refund_approved",
                        "refund_request_id": refund_request.id,
                        "refund_amount": float(refund_amount),
                        "content_en": content_en
                    }),
                    created_at=get_utc_time()
                )
                db.add(system_message)
            except Exception as e:
                logger.error(f"Failed to send system message: {e}")
            
            # 发送通知给发布者
            try:
                crud.create_notification(
                    db=db,
                    user_id=refund_request.poster_id,
                    type="refund_approved",
                    title="退款申请已批准",
                    content=f"您的任务「{task.title}」的退款申请已批准，退款金额：£{refund_amount_float:.2f}",
                    related_id=str(task.id),
                    auto_commit=False
                )
            except Exception as e:
                logger.error(f"Failed to send notification: {e}")
            
            db.commit()
            log_admin_action(
                action="approve_refund",
                admin_id=current_user.id,
                request=request,
                target_type="refund_request",
                target_id=str(refund_id),
                details={"amount": refund_amount_float, "task_id": task.id, "admin_comment": approve_data.admin_comment},
            )
        else:
            db.rollback()
            db.refresh(task)
            db.refresh(refund_request)
            refund_request.status = "pending"
            refund_request.admin_comment = f"{refund_request.admin_comment or ''}\n退款处理失败: {error_message}"
            db.commit()
            logger.error(f"退款处理失败: {error_message}")
            raise HTTPException(
                status_code=500,
                detail=f"退款处理失败: {error_message}"
            )
    
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        logger.error(f"处理退款时发生错误: {e}", exc_info=True)
        db.rollback()
        db.refresh(refund_request)
        refund_request.status = "pending"
        db.commit()
        raise HTTPException(
            status_code=500,
            detail=f"处理退款时发生错误: {str(e)}"
        )
    
    db.refresh(refund_request)
    return refund_request


@router.post("/admin/refund-requests/{refund_id}/reject", response_model=schemas.RefundRequestOut)
def reject_refund_request(
    refund_id: int,
    reject_data: schemas.RefundRequestReject,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员拒绝退款申请"""
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.status == "pending"
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()
    
    if not refund_request:
        existing = db.query(models.RefundRequest).filter(
            models.RefundRequest.id == refund_id
        ).first()
        if existing:
            raise HTTPException(
                status_code=400, 
                detail=f"退款申请状态不正确，无法拒绝。当前状态: {existing.status}"
            )
        raise HTTPException(status_code=404, detail="Refund request not found")
    
    # 更新退款申请状态
    refund_request.status = "rejected"
    refund_request.reviewed_by = current_user.id
    refund_request.reviewed_at = get_utc_time()
    refund_request.admin_comment = reject_data.admin_comment
    
    # 获取任务信息
    task = crud.get_task(db, refund_request.task_id)
    
    # 发送系统消息
    try:
        admin_name = current_user.name or f"管理员{current_user.id}"
        content_zh = f"管理员 {admin_name} 已拒绝您的退款申请。理由：{reject_data.admin_comment}"
        content_en = f"Admin {admin_name} has rejected your refund request. Reason: {reject_data.admin_comment}"
        
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            content=content_zh,
            task_id=task.id if task else None,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_rejected",
                "refund_request_id": refund_request.id,
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
    
    # 发送通知给发布者
    if task:
        try:
            crud.create_notification(
                db=db,
                user_id=refund_request.poster_id,
                type="refund_rejected",
                title="退款申请已拒绝",
                content=f"您的任务「{task.title}」的退款申请已拒绝。理由：{reject_data.admin_comment}",
                related_id=str(task.id),
                auto_commit=False
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    
    db.commit()
    db.refresh(refund_request)

    log_admin_action(
        action="reject_refund",
        admin_id=current_user.id,
        request=request,
        target_type="refund_request",
        target_id=str(refund_id),
        details={"task_id": refund_request.task_id, "admin_comment": reject_data.admin_comment},
    )

    return refund_request

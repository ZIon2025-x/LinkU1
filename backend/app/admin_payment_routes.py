"""
管理员 - 支付管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.utils.time_utils import format_iso_utc

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-支付管理"])


# 使用 PaymentHistory（支付历史表）；金额存储为便士，对外返回英镑
def _payment_history_to_item(p):
    """PaymentHistory 单条转 API 格式：final_amount 便士 -> amount 英镑"""
    amount_pounds = float(p.final_amount or 0) / 100.0
    return {
        "id": str(p.id),
        "user_id": p.user_id,
        "amount": amount_pounds,
        "currency": p.currency or "GBP",
        "status": p.status,
        "payment_type": p.payment_method or "stripe",
        "payment_intent_id": p.payment_intent_id,
        "created_at": format_iso_utc(p.created_at) if p.created_at else None,
        "updated_at": format_iso_utc(p.updated_at) if p.updated_at else None,
    }


@router.get("/admin/payments")
def admin_get_payments(
    page: int = 1,
    size: int = 50,
    status: str = None,
    payment_type: str = None,
    user_id: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取支付记录列表（来自 payment_history 表）"""
    skip = (page - 1) * size
    query = db.query(models.PaymentHistory)
    if status:
        query = query.filter(models.PaymentHistory.status == status)
    if payment_type:
        query = query.filter(models.PaymentHistory.payment_method == payment_type)
    if user_id:
        query = query.filter(models.PaymentHistory.user_id == user_id)
    total = query.count()
    payments = query.order_by(models.PaymentHistory.created_at.desc()).offset(skip).limit(size).all()
    return {
        "payments": [_payment_history_to_item(p) for p in payments],
        "total": total,
        "page": page,
        "size": size,
    }


@router.get("/admin/payments/stats")
def admin_get_payment_stats(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取支付统计信息（payment_history：金额为便士，返回英镑）"""
    from app.utils.time_utils import get_utc_time
    # 总交易金额（便士 -> 英镑）
    total_pence = db.query(func.sum(models.PaymentHistory.final_amount)).filter(
        models.PaymentHistory.status == "succeeded"
    ).scalar() or 0
    total_amount = float(total_pence) / 100.0
    total_count = db.query(func.count(models.PaymentHistory.id)).filter(
        models.PaymentHistory.status == "succeeded"
    ).scalar() or 0
    today = get_utc_time().replace(hour=0, minute=0, second=0, microsecond=0)
    today_pence = db.query(func.sum(models.PaymentHistory.final_amount)).filter(
        models.PaymentHistory.status == "succeeded",
        models.PaymentHistory.created_at >= today
    ).scalar() or 0
    today_amount = float(today_pence) / 100.0
    today_count = db.query(func.count(models.PaymentHistory.id)).filter(
        models.PaymentHistory.status == "succeeded",
        models.PaymentHistory.created_at >= today
    ).scalar() or 0
    pending_count = db.query(func.count(models.PaymentHistory.id)).filter(
        models.PaymentHistory.status == "pending"
    ).scalar() or 0
    return {
        "total_amount": total_amount,
        "total_count": total_count,
        "today_amount": today_amount,
        "today_count": today_count,
        "pending_count": pending_count,
    }


@router.get("/admin/payments/{payment_id}")
def admin_get_payment_detail(
    payment_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取支付详情（payment_history）"""
    payment = db.query(models.PaymentHistory).filter(models.PaymentHistory.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    user = crud.get_user_by_id(db, payment.user_id) if payment.user_id else None
    task = crud.get_task(db, payment.task_id) if payment.task_id else None
    amount_pounds = float(payment.final_amount or 0) / 100.0
    return {
        "payment": {
            "id": str(payment.id),
            "user_id": payment.user_id,
            "amount": amount_pounds,
            "currency": payment.currency or "GBP",
            "status": payment.status,
            "payment_type": payment.payment_method or "stripe",
            "payment_intent_id": payment.payment_intent_id,
            "task_id": payment.task_id,
            "created_at": format_iso_utc(payment.created_at) if payment.created_at else None,
            "updated_at": format_iso_utc(payment.updated_at) if payment.updated_at else None,
        },
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
        } if user else None,
        "task": {
            "id": task.id,
            "title": task.title,
            "status": task.status,
        } if task else None,
    }


@router.get("/admin/dashboard/revenue")
def admin_get_revenue_stats(
    days: int = 30,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取收入统计（按天，payment_history 便士转英镑）"""
    from app.utils.time_utils import get_utc_time
    from datetime import timedelta
    end_date = get_utc_time()
    start_date = end_date - timedelta(days=days)
    daily_stats = db.query(
        func.date(models.PaymentHistory.created_at).label('date'),
        func.sum(models.PaymentHistory.final_amount).label('amount_pence'),
        func.count(models.PaymentHistory.id).label('count')
    ).filter(
        models.PaymentHistory.status == "succeeded",
        models.PaymentHistory.created_at >= start_date,
        models.PaymentHistory.created_at <= end_date
    ).group_by(
        func.date(models.PaymentHistory.created_at)
    ).order_by(
        func.date(models.PaymentHistory.created_at)
    ).all()
    return {
        "daily_revenue": [
            {
                "date": str(stat.date),
                "amount": float(stat.amount_pence or 0) / 100.0,
                "count": stat.count
            }
            for stat in daily_stats
        ],
        "period": {
            "start": format_iso_utc(start_date),
            "end": format_iso_utc(end_date),
            "days": days
        }
    }


@router.get("/admin/dashboard/payment-methods")
def admin_get_payment_methods_stats(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取支付方式统计（payment_history，金额便士转英镑）"""
    stats = db.query(
        models.PaymentHistory.payment_method,
        func.count(models.PaymentHistory.id).label('count'),
        func.sum(models.PaymentHistory.final_amount).label('total_pence')
    ).filter(
        models.PaymentHistory.status == "succeeded"
    ).group_by(
        models.PaymentHistory.payment_method
    ).all()
    return {
        "payment_methods": [
            {
                "type": stat.payment_method or "unknown",
                "count": stat.count,
                "total_amount": float(stat.total_pence or 0) / 100.0
            }
            for stat in stats
        ]
    }

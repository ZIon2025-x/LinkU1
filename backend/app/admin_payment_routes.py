"""
管理员 - 支付管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional
from decimal import Decimal

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
    """管理员获取支付记录列表"""
    skip = (page - 1) * size
    
    query = db.query(models.Payment)
    
    if status:
        query = query.filter(models.Payment.status == status)
    
    if payment_type:
        query = query.filter(models.Payment.payment_type == payment_type)
    
    if user_id:
        query = query.filter(models.Payment.user_id == user_id)
    
    total = query.count()
    payments = query.order_by(models.Payment.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "payments": [
            {
                "id": p.id,
                "user_id": p.user_id,
                "amount": float(p.amount) if p.amount else 0,
                "currency": p.currency,
                "status": p.status,
                "payment_type": p.payment_type,
                "payment_intent_id": p.payment_intent_id,
                "created_at": format_iso_utc(p.created_at) if p.created_at else None,
                "updated_at": format_iso_utc(p.updated_at) if p.updated_at else None,
            }
            for p in payments
        ],
        "total": total,
        "page": page,
        "size": size,
    }


@router.get("/admin/payments/stats")
def admin_get_payment_stats(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取支付统计信息"""
    # 总交易金额
    total_amount = db.query(func.sum(models.Payment.amount)).filter(
        models.Payment.status == "succeeded"
    ).scalar() or Decimal("0")
    
    # 总交易数量
    total_count = db.query(func.count(models.Payment.id)).filter(
        models.Payment.status == "succeeded"
    ).scalar() or 0
    
    # 今日交易金额
    from app.utils.time_utils import get_utc_time
    from datetime import timedelta
    
    today = get_utc_time().replace(hour=0, minute=0, second=0, microsecond=0)
    today_amount = db.query(func.sum(models.Payment.amount)).filter(
        models.Payment.status == "succeeded",
        models.Payment.created_at >= today
    ).scalar() or Decimal("0")
    
    today_count = db.query(func.count(models.Payment.id)).filter(
        models.Payment.status == "succeeded",
        models.Payment.created_at >= today
    ).scalar() or 0
    
    # 待处理支付
    pending_count = db.query(func.count(models.Payment.id)).filter(
        models.Payment.status == "pending"
    ).scalar() or 0
    
    return {
        "total_amount": float(total_amount),
        "total_count": total_count,
        "today_amount": float(today_amount),
        "today_count": today_count,
        "pending_count": pending_count,
    }


@router.get("/admin/payments/{payment_id}")
def admin_get_payment_detail(
    payment_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取支付详情"""
    payment = db.query(models.Payment).filter(models.Payment.id == payment_id).first()
    
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    # 获取关联用户信息
    user = crud.get_user_by_id(db, payment.user_id) if payment.user_id else None
    
    # 获取关联任务信息（如果有）
    task = None
    if payment.task_id:
        task = crud.get_task(db, payment.task_id)
    
    return {
        "payment": {
            "id": payment.id,
            "user_id": payment.user_id,
            "amount": float(payment.amount) if payment.amount else 0,
            "currency": payment.currency,
            "status": payment.status,
            "payment_type": payment.payment_type,
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
    """获取收入统计（按天）"""
    from app.utils.time_utils import get_utc_time
    from datetime import timedelta
    
    end_date = get_utc_time()
    start_date = end_date - timedelta(days=days)
    
    # 按日期分组统计
    daily_stats = db.query(
        func.date(models.Payment.created_at).label('date'),
        func.sum(models.Payment.amount).label('amount'),
        func.count(models.Payment.id).label('count')
    ).filter(
        models.Payment.status == "succeeded",
        models.Payment.created_at >= start_date,
        models.Payment.created_at <= end_date
    ).group_by(
        func.date(models.Payment.created_at)
    ).order_by(
        func.date(models.Payment.created_at)
    ).all()
    
    return {
        "daily_revenue": [
            {
                "date": str(stat.date),
                "amount": float(stat.amount) if stat.amount else 0,
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
    """获取支付方式统计"""
    stats = db.query(
        models.Payment.payment_type,
        func.count(models.Payment.id).label('count'),
        func.sum(models.Payment.amount).label('total_amount')
    ).filter(
        models.Payment.status == "succeeded"
    ).group_by(
        models.Payment.payment_type
    ).all()
    
    return {
        "payment_methods": [
            {
                "type": stat.payment_type or "unknown",
                "count": stat.count,
                "total_amount": float(stat.total_amount) if stat.total_amount else 0
            }
            for stat in stats
        ]
    }

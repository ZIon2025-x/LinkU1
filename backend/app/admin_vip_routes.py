"""
管理员 - VIP订阅管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-VIP订阅管理"])


@router.get("/admin/vip-subscriptions")
def admin_list_vip_subscriptions(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    user_id: Optional[str] = Query(None, description="按用户ID筛选"),
    status: Optional[str] = Query(None, description="按状态筛选 active|expired|cancelled|refunded"),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取VIP订阅列表"""
    rows, total = crud.get_all_vip_subscriptions(
        db, user_id=user_id, status=status, limit=limit, offset=skip
    )
    items = []
    for s in rows:
        items.append({
            "id": s.id,
            "user_id": s.user_id,
            "product_id": s.product_id,
            "transaction_id": s.transaction_id,
            "original_transaction_id": s.original_transaction_id,
            "purchase_date": s.purchase_date.isoformat() if s.purchase_date else None,
            "expires_date": s.expires_date.isoformat() if s.expires_date else None,
            "status": s.status,
            "environment": s.environment,
            "auto_renew_status": s.auto_renew_status,
            "cancellation_reason": s.cancellation_reason,
            "refunded_at": s.refunded_at.isoformat() if s.refunded_at else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        })
    return {"items": items, "total": total}


@router.get("/admin/vip-subscriptions/stats")
def admin_vip_subscription_stats(
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取VIP订阅统计数据"""
    q = db.query(
        models.VIPSubscription.status,
        func.count(models.VIPSubscription.id).label("count"),
    ).group_by(models.VIPSubscription.status)
    by_status = {r.status: r.count for r in q.all()}
    total = sum(by_status.values())
    active_users = (
        db.query(models.User)
        .filter(models.User.user_level.in_(["vip", "super"]))
        .count()
    )
    return {
        "by_status": by_status,
        "total_subscriptions": total,
        "active_vip_users": active_users,
    }


@router.patch("/admin/vip-subscriptions/{subscription_id}")
def admin_update_vip_subscription(
    subscription_id: int,
    body: schemas.AdminVipSubscriptionUpdate,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员手动更新VIP订阅状态"""
    if body.status not in ("active", "expired", "cancelled", "refunded"):
        raise HTTPException(status_code=400, detail="无效的 status")
    sub = (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.id == subscription_id)
        .first()
    )
    if not sub:
        raise HTTPException(status_code=404, detail="订阅记录不存在")
    refunded_at = get_utc_time() if body.status == "refunded" else None
    updated = crud.update_vip_subscription_status(
        db,
        sub.id,
        body.status,
        cancellation_reason=body.cancellation_reason,
        refunded_at=refunded_at,
    )
    if body.status in ("expired", "refunded"):
        active = crud.get_active_vip_subscription(db, sub.user_id)
        if not active:
            crud.update_user_vip_status(db, sub.user_id, "normal")
    try:
        from app.vip_subscription_service import vip_subscription_service
        vip_subscription_service.invalidate_vip_cache(updated.user_id)
    except Exception as e:
        logger.debug("VIP cache invalidate: %s", e)
    return {
        "id": updated.id,
        "user_id": updated.user_id,
        "status": body.status,
        "message": "已更新",
    }

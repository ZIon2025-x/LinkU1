"""达人套餐/次卡管理路由"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.models_expert import (
    Expert, ExpertMember, UserServicePackage, PackageUsageLog,
)
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_package_router = APIRouter(tags=["expert-packages"])


@expert_package_router.get("/api/my/packages")
async def get_my_packages(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取我购买的套餐列表"""
    result = await db.execute(
        select(UserServicePackage)
        .where(UserServicePackage.user_id == current_user.id)
        .order_by(UserServicePackage.purchased_at.desc())
    )
    packages = result.scalars().all()
    return [
        {
            "id": p.id,
            "service_id": p.service_id,
            "expert_id": p.expert_id,
            "total_sessions": p.total_sessions,
            "used_sessions": p.used_sessions,
            "remaining_sessions": p.total_sessions - p.used_sessions,
            "status": p.status,
            "purchased_at": p.purchased_at.isoformat() if p.purchased_at else None,
            "expires_at": p.expires_at.isoformat() if p.expires_at else None,
            # 支付关联字段 — 购买成功后前端用它来判定 webhook 已完成
            "payment_intent_id": p.payment_intent_id,
            "paid_amount": float(p.paid_amount) if p.paid_amount is not None else None,
            "currency": p.currency,
            "bundle_breakdown": p.bundle_breakdown,
        }
        for p in packages
    ]


@expert_package_router.post("/api/experts/{expert_id}/packages/{package_id}/use")
async def use_package_session(
    expert_id: str,
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """核销套餐一次（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(UserServicePackage).where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.expert_id == expert_id,
                UserServicePackage.status == "active",
            )
        )
    )
    package = result.scalar_one_or_none()
    if not package:
        raise HTTPException(status_code=404, detail="套餐不存在或已失效")

    # 过期检查 — 之前完全没查 expires_at,过期套餐照样能核销
    if package.expires_at:
        from app.utils.time_utils import get_utc_time as _now
        now_utc = _now()
        expires = package.expires_at
        if expires.tzinfo is None:
            from datetime import timezone
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now_utc:
            package.status = "expired"
            await db.commit()
            raise HTTPException(status_code=400, detail="套餐已过期")

    if package.used_sessions >= package.total_sessions:
        raise HTTPException(status_code=400, detail="套餐次数已用完")

    # 原子递增，防止并发丢失
    from sqlalchemy import update as sql_update
    rows = await db.execute(
        sql_update(UserServicePackage)
        .where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.used_sessions < UserServicePackage.total_sessions,
            )
        )
        .values(used_sessions=UserServicePackage.used_sessions + 1)
    )
    if rows.rowcount == 0:
        raise HTTPException(status_code=400, detail="套餐次数已用完（并发冲突）")

    # 刷新检查是否用完
    await db.refresh(package)
    if package.used_sessions >= package.total_sessions:
        package.status = "exhausted"
        # Trigger settlement: creates a pending PaymentTransfer for async processing
        from app.services.package_settlement import trigger_package_release
        trigger_package_release(db, package, reason="exhausted")

    log = PackageUsageLog(
        package_id=package_id,
        used_by=current_user.id,
        note=body.get("note"),
    )
    db.add(log)
    await db.commit()

    return {
        "remaining_sessions": package.total_sessions - package.used_sessions,
        "status": package.status,
    }

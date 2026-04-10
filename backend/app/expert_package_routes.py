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
    from app.services.package_settlement import compute_package_action_flags

    result = await db.execute(
        select(UserServicePackage)
        .where(UserServicePackage.user_id == current_user.id)
        .order_by(UserServicePackage.purchased_at.desc())
    )
    packages = result.scalars().all()
    now = get_utc_time()

    out = []
    for p in packages:
        flags = compute_package_action_flags(p, now)
        out.append({
            "id": p.id,
            "service_id": p.service_id,
            "expert_id": p.expert_id,
            "total_sessions": p.total_sessions,
            "used_sessions": p.used_sessions,
            "remaining_sessions": p.total_sessions - p.used_sessions,
            "status": p.status,
            "status_display": flags["status_display"],
            "purchased_at": p.purchased_at.isoformat() if p.purchased_at else None,
            "cooldown_until": p.cooldown_until.isoformat() if p.cooldown_until else None,
            "in_cooldown": flags["in_cooldown"],
            "expires_at": p.expires_at.isoformat() if p.expires_at else None,
            "payment_intent_id": p.payment_intent_id,
            "paid_amount": float(p.paid_amount) if p.paid_amount is not None else None,
            "currency": p.currency,
            "bundle_breakdown": p.bundle_breakdown,
            "released_amount_pence": p.released_amount_pence,
            "refunded_amount_pence": p.refunded_amount_pence,
            "platform_fee_pence": p.platform_fee_pence,
            "released_at": p.released_at.isoformat() if p.released_at else None,
            "refunded_at": p.refunded_at.isoformat() if p.refunded_at else None,
            "last_redeemed_at": p.last_redeemed_at.isoformat() if p.last_redeemed_at else None,
            "can_refund_full": flags["can_refund_full"],
            "can_refund_partial": flags["can_refund_partial"],
            "can_review": flags["can_review"],
            "can_dispute": flags["can_dispute"],
        })
    return out


@expert_package_router.post("/api/experts/{expert_id}/packages/{package_id}/use")
async def use_package_session(
    expert_id: str,
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """核销套餐一次（Owner/Admin）— 与 redeem_package 对齐"""
    from datetime import timezone
    from sqlalchemy.orm.attributes import flag_modified

    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    # SELECT FOR UPDATE 防止并发
    result = await db.execute(
        select(UserServicePackage).where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.expert_id == expert_id,
                UserServicePackage.status == "active",
            )
        ).with_for_update()
    )
    package = result.scalar_one_or_none()
    if not package:
        raise HTTPException(status_code=404, detail="套餐不存在或已失效")

    # 过期检查
    if package.expires_at:
        now_utc = get_utc_time()
        expires = package.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now_utc:
            package.status = "expired"
            await db.commit()
            raise HTTPException(status_code=400, detail="套餐已过期")

    if package.used_sessions >= package.total_sessions:
        raise HTTPException(status_code=400, detail="套餐次数已用完")

    # Bundle 套餐: 更新 bundle_breakdown
    sub_service_id = body.get("sub_service_id")
    if package.bundle_breakdown:
        if sub_service_id is None:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "sub_service_required", "message": "bundle 套餐必须指定 sub_service_id"},
            )
        sub_key = str(sub_service_id)
        bd = dict(package.bundle_breakdown)
        if sub_key not in bd:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "sub_service_not_in_bundle", "message": "该子服务不在此套餐中"},
            )
        sub_entry = dict(bd[sub_key])
        if int(sub_entry.get("used", 0)) >= int(sub_entry.get("total", 0)):
            raise HTTPException(
                status_code=400,
                detail={"error_code": "sub_service_exhausted", "message": "该子服务已核销完"},
            )
        sub_entry["used"] = int(sub_entry.get("used", 0)) + 1
        bd[sub_key] = sub_entry
        package.bundle_breakdown = dict(bd)
        flag_modified(package, "bundle_breakdown")

    # 通用核销
    package.used_sessions = package.used_sessions + 1
    package.last_redeemed_at = get_utc_time()

    if package.used_sessions >= package.total_sessions:
        package.status = "exhausted"
        from app.services.package_settlement import trigger_package_release
        trigger_package_release(db, package, reason="exhausted")

    log = PackageUsageLog(
        package_id=package_id,
        used_by=current_user.id,
        sub_service_id=sub_service_id,
        redeem_method="manual",
        note=body.get("note"),
    )
    db.add(log)
    await db.commit()
    await db.refresh(package)

    # 通知 buyer (best-effort)
    try:
        from app.async_crud import AsyncNotificationCRUD
        from app.utils.notification_templates import get_notification_texts
        t_zh, c_zh, t_en, c_en = get_notification_texts(
            "package_redeemed",
            used=package.used_sessions,
            total=package.total_sessions,
        )
        await AsyncNotificationCRUD.create_notification(
            db=db, user_id=package.user_id,
            notification_type="package_redeemed",
            title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
            related_id=str(package.id), related_type="user_service_package",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"通知 buyer 套餐核销失败: {e}")

    return {
        "remaining_sessions": package.total_sessions - package.used_sessions,
        "status": package.status,
        "bundle_breakdown": package.bundle_breakdown,
    }

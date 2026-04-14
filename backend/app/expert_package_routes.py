"""达人套餐/次卡管理路由"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.models_expert import UserServicePackage
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

    # Batch-load service names for all packages
    # 同时收集 bundle breakdown 里引用的子服务 id,一次性加载名称
    service_ids = list({p.service_id for p in packages if p.service_id})
    sub_service_ids: set[int] = set()
    for p in packages:
        if p.bundle_breakdown:
            for key in p.bundle_breakdown.keys():
                try:
                    sub_service_ids.add(int(key))
                except (TypeError, ValueError):
                    continue
    all_service_ids = list({*service_ids, *sub_service_ids})
    service_map: dict = {}
    if all_service_ids:
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                models.TaskExpertService.id.in_(all_service_ids)
            )
        )
        for svc in svc_result.scalars().all():
            service_map[svc.id] = svc

    def _build_sub_names(bd) -> dict:
        if not bd:
            return {}
        names = {}
        for key in bd.keys():
            try:
                sid = int(key)
            except (TypeError, ValueError):
                continue
            svc = service_map.get(sid)
            if svc:
                names[str(sid)] = {
                    "service_name": svc.service_name,
                    "service_name_en": svc.service_name_en,
                    "service_name_zh": svc.service_name_zh,
                }
        return names

    out = []
    for p in packages:
        flags = compute_package_action_flags(p, now)
        svc = service_map.get(p.service_id)
        out.append({
            "id": p.id,
            "service_id": p.service_id,
            "expert_id": p.expert_id,
            "service_name": svc.service_name if svc else None,
            "package_type": svc.package_type if svc else None,
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
            "sub_service_names": _build_sub_names(p.bundle_breakdown),
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


# /use 端点已合并到 package_purchase_routes.py 的 /redeem 端点
# 通过 body.package_id 参数实现 manual 核销 (无需 QR/OTP)

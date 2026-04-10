"""达人套餐购买 + QR 核销系统 (A1)

Endpoints:
  - POST /api/services/{service_id}/purchase-package         buyer 发起套餐购买,创建 PaymentIntent
  - GET  /api/my/packages/{package_id}/redemption-qr         buyer 端拉 QR + OTP (HMAC + 60s TTL)
  - POST /api/experts/{expert_id}/packages/redeem            团队 owner/admin 扫码/输入 OTP 核销
  - GET  /api/experts/{expert_id}/customer-packages          团队"我的客户"列表
  - GET  /api/my/packages/{package_id}                       buyer 查看单个套餐详情(含 breakdown 和历史)

webhook 处理 (在 routers.py): payment_type='package_purchase' 分支创建 UserServicePackage
"""
import base64
import hmac
import hashlib
import json as _json
import logging
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy import and_, select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.models_expert import (
    Expert,
    ExpertMember,
    UserServicePackage,
    PackageUsageLog,
)
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

package_purchase_router = APIRouter(tags=["package-purchase"])


# ==================== Helpers ====================

def _qr_secret() -> bytes:
    """从 SECRET_KEY 派生套餐 QR 签名密钥"""
    from app.config import Config
    base = (getattr(Config, "SECRET_KEY", None) or "fallback-dev-secret").encode("utf-8")
    return hashlib.sha256(b"package_qr_v1:" + base).digest()


def _build_bundle_breakdown(bundle_service_ids, db=None):
    """把 service.bundle_service_ids 解析为 UserServicePackage.bundle_breakdown 新格式。

    Args:
        bundle_service_ids: List from TaskExpertService.bundle_service_ids. Supports two formats:
            - [A, B, C]                                — legacy "each once"
            - [{"service_id": A, "count": 5}, ...]     — explicit count per service
        db: SQLAlchemy Session (sync — called from webhook context in routers.py).
            If provided, snapshots unit_price_pence from TaskExpertService.base_price.
            If None (e.g. async call sites used only for validation), unit_price_pence defaults to 0.

    Returns:
        New format dict:
            {"<sid>": {"total": N, "used": 0, "unit_price_pence": P}, ...}
        Or None if bundle_service_ids is empty/invalid.

    Note:
        unit_price_pence is snapshotted from TaskExpertService.base_price at purchase time
        so subsequent service price changes don't affect already-purchased packages.
    """
    if not bundle_service_ids:
        return None

    # Aggregate counts per service_id
    sid_counts = {}
    for item in bundle_service_ids:
        if isinstance(item, int):
            sid_counts[item] = sid_counts.get(item, 0) + 1
        elif isinstance(item, dict):
            sid = item.get("service_id")
            cnt = item.get("count", 1)
            if sid is not None:
                sid_counts[sid] = sid_counts.get(sid, 0) + int(cnt)

    if not sid_counts:
        return None

    # Snapshot unit prices at purchase time (protect against later service price changes)
    price_map = {}
    if db is not None:
        from app import models as _models
        sids = list(sid_counts.keys())
        sub_services = db.query(_models.TaskExpertService).filter(
            _models.TaskExpertService.id.in_(sids)
        ).all()
        price_map = {
            s.id: int(round(float(s.base_price) * 100))
            for s in sub_services
        }

    breakdown = {}
    for sid, total in sid_counts.items():
        breakdown[str(sid)] = {
            "total": total,
            "used": 0,
            "unit_price_pence": price_map.get(sid, 0),  # 0 fallback when db not provided or service missing
        }
    return breakdown


def _bundle_total_sessions(breakdown) -> int:
    """计算 bundle_breakdown 的总次数"""
    if not breakdown:
        return 0
    return sum(int(v.get("total", 0)) for v in breakdown.values())


def _generate_qr_payload(package_id: int, user_id: str) -> dict:
    """生成 QR 数据包: {package_id, user_id, exp, nonce, sig}, sig 是 HMAC-SHA256"""
    now = int(time.time())
    payload = {
        "p": package_id,
        "u": user_id,
        "e": now + 60,  # 60 秒 TTL
        "n": secrets.token_urlsafe(8),
    }
    message = f"{payload['p']}|{payload['u']}|{payload['e']}|{payload['n']}".encode("utf-8")
    sig = hmac.new(_qr_secret(), message, hashlib.sha256).hexdigest()[:16]
    payload["s"] = sig
    qr_data = base64.urlsafe_b64encode(_json.dumps(payload).encode("utf-8")).decode("utf-8")
    return {"qr_data": qr_data, "expires_at_ts": payload["e"]}


def _verify_qr_payload(qr_data: str) -> Optional[dict]:
    """验证 QR 签名 + TTL,返回 payload dict 或 None"""
    try:
        payload = _json.loads(base64.urlsafe_b64decode(qr_data.encode("utf-8")).decode("utf-8"))
    except Exception:
        return None
    required = {"p", "u", "e", "n", "s"}
    if not required.issubset(payload.keys()):
        return None
    # TTL
    if int(payload["e"]) < int(time.time()):
        return None
    # 签名
    message = f"{payload['p']}|{payload['u']}|{payload['e']}|{payload['n']}".encode("utf-8")
    expected = hmac.new(_qr_secret(), message, hashlib.sha256).hexdigest()[:16]
    if not hmac.compare_digest(expected, str(payload["s"])):
        return None
    return payload


# ==================== OTP cache (Redis 优先, fallback in-memory) ====================
# OTP map: otp_code → (package_id, user_id, expires_at_ts)
_OTP_CACHE: dict = {}
_OTP_TTL_SECONDS = 60


def _generate_otp(package_id: int, user_id: str) -> str:
    """生成 6 位 OTP,存到 cache,TTL 60s"""
    # 清理过期 (轻量,每次生成时顺带清)
    now = int(time.time())
    expired = [k for k, v in _OTP_CACHE.items() if v[2] < now]
    for k in expired:
        _OTP_CACHE.pop(k, None)
    # 生成不重复的 6 位
    for _ in range(10):
        otp = f"{secrets.randbelow(900000) + 100000}"
        if otp not in _OTP_CACHE:
            _OTP_CACHE[otp] = (package_id, user_id, now + _OTP_TTL_SECONDS)
            return otp
    raise RuntimeError("OTP 生成冲突,请重试")


def _consume_otp(otp: str) -> Optional[dict]:
    """验证 + 消费 OTP,返回 {package_id, user_id} 或 None"""
    entry = _OTP_CACHE.pop(otp, None)
    if not entry:
        return None
    package_id, user_id, exp_ts = entry
    if exp_ts < int(time.time()):
        return None
    return {"package_id": package_id, "user_id": user_id}


# ==================== 1. 套餐购买 ====================

@package_purchase_router.post("/api/services/{service_id}/purchase-package")
async def purchase_package(
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """buyer 购买套餐,创建 Stripe PaymentIntent。

    支持的 service 必须满足:
      - status='active'
      - package_type ∈ ('multi', 'bundle')
      - package_price 已设置
      - owner_type='expert' (团队服务,不支持个人服务的套餐)
      - 团队 Stripe 已 ready

    返回 client_secret,buyer 完成支付后 webhook 创建 UserServicePackage。
    """
    # 1. 加载服务
    service_result = await db.execute(
        select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "service_not_found", "message": "服务不存在"},
        )
    if service.status != "active":
        raise HTTPException(
            status_code=400,
            detail={"error_code": "service_inactive", "message": "服务未上架"},
        )
    if service.package_type not in ("multi", "bundle"):
        raise HTTPException(
            status_code=400,
            detail={"error_code": "service_not_package", "message": "该服务不是套餐类型"},
        )
    if service.package_price is None or float(service.package_price) <= 0:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "package_price_not_set", "message": "服务未设置套餐价格"},
        )
    if service.owner_type != "expert":
        raise HTTPException(
            status_code=400,
            detail={"error_code": "personal_service_no_package", "message": "个人服务暂不支持套餐购买"},
        )

    # 2. 解析团队 + Stripe 状态
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)
    if not taker_expert_id_value:
        raise HTTPException(
            status_code=500,
            detail={"error_code": "service_team_resolve_failed", "message": "无法解析服务团队"},
        )

    expert = await db.get(Expert, taker_expert_id_value)
    if not expert or not expert.stripe_account_id:
        raise HTTPException(status_code=500, detail={
            "error_code": "team_stripe_not_ready",
            "message": "团队 Stripe 未配置",
        })

    # 3. 检查用户没有重复未支付订单 (同 service 同 user 的 active 套餐 OR pending PI)
    existing_q = select(UserServicePackage).where(
        and_(
            UserServicePackage.user_id == current_user.id,
            UserServicePackage.service_id == service_id,
            UserServicePackage.status == "active",
        )
    )
    existing = (await db.execute(existing_q)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "package_already_active",
                "message": "你已有一个进行中的此服务套餐,请用完后再购买",
                "package_id": existing.id,
            },
        )

    # 4. 计算总课时数 (multi: total_sessions; bundle: sum of breakdown)
    if service.package_type == "multi":
        total_sessions = service.total_sessions or 0
        if total_sessions < 2:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "multi_total_sessions_invalid", "message": "multi 套餐 total_sessions 配置错误"},
            )
        bundle_breakdown = None
    else:  # bundle
        bundle_breakdown = _build_bundle_breakdown(service.bundle_service_ids)
        if not bundle_breakdown:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "expert_bundle_invalid", "message": "bundle 套餐配置错误"},
            )
        total_sessions = _bundle_total_sessions(bundle_breakdown)
        if total_sessions < 1:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "expert_bundle_invalid", "message": "bundle 套餐总次数为 0"},
            )

    # 5. 创建 Stripe PaymentIntent
    import stripe
    from app.stripe_config import ensure_stripe_configured
    from app.utils.fee_calculator import calculate_application_fee_pence
    ensure_stripe_configured()

    price = float(service.package_price)
    currency = (service.currency or "GBP").lower()
    if currency != "gbp":
        raise HTTPException(
            status_code=422,
            detail={"error_code": "expert_currency_unsupported", "message": "团队套餐目前仅支持 GBP"},
        )
    amount_pence = int(round(price * 100))
    application_fee_pence = calculate_application_fee_pence(
        amount_pence, task_source="expert_service", task_type=None
    )

    try:
        pi = stripe.PaymentIntent.create(
            amount=amount_pence,
            currency=currency,
            payment_method_types=["card"],
            description=f"套餐购买 #{service.id}: {service.service_name[:40]}",
            metadata={
                # webhook 用这些字段创建 UserServicePackage
                "payment_type": "package_purchase",
                "service_id": str(service.id),
                "buyer_id": str(current_user.id),
                "expert_id": str(taker_expert_id_value),
                "package_type": service.package_type,
                "total_sessions": str(total_sessions),
                "package_price": f"{price:.2f}",
                "validity_days": str(service.validity_days or 0),
                "application_fee": str(application_fee_pence),
                "platform": "Link\u00b2Ur",
            },
        )
    except stripe.error.StripeError as e:
        raise HTTPException(
            status_code=502,
            detail={"error_code": "stripe_create_failed", "message": f"Stripe 创建失败: {str(e)}"},
        )

    return {
        "payment_intent_id": pi.id,
        "client_secret": pi.client_secret,
        "amount": amount_pence,
        "currency": currency.upper(),
        "service_id": service.id,
        "package_type": service.package_type,
        "total_sessions": total_sessions,
    }


# ==================== 2. 我的套餐: 详情 + QR ====================

@package_purchase_router.get("/api/my/packages/{package_id}")
async def get_my_package_detail(
    package_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """buyer 查看单个套餐的详情(含 bundle_breakdown + 历史)"""
    pkg_result = await db.execute(
        select(UserServicePackage).where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.user_id == current_user.id,
            )
        )
    )
    pkg = pkg_result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "package_not_found", "message": "套餐不存在"},
        )

    # 加载关联 service 名称
    service = await db.get(models.TaskExpertService, pkg.service_id)
    expert = await db.get(Expert, pkg.expert_id) if pkg.expert_id else None

    # 历史
    logs_result = await db.execute(
        select(PackageUsageLog)
        .where(PackageUsageLog.package_id == package_id)
        .order_by(PackageUsageLog.used_at.desc())
        .limit(50)
    )
    logs = logs_result.scalars().all()
    history = [
        {
            "id": l.id,
            "used_at": l.used_at.isoformat() if l.used_at else None,
            "sub_service_id": l.sub_service_id,
            "redeem_method": l.redeem_method,
            "note": l.note,
        }
        for l in logs
    ]

    # validity_days 从 service 推导 (UserServicePackage 本身没存)
    validity_days = getattr(service, "validity_days", None) if service else None

    from app.services.package_settlement import compute_package_action_flags
    now = get_utc_time()
    flags = compute_package_action_flags(pkg, now)

    return {
        "id": pkg.id,
        "service_id": pkg.service_id,
        "service_name": service.service_name if service else None,
        "package_type": getattr(service, "package_type", None) if service else None,
        "expert_id": pkg.expert_id,
        "expert_name": expert.name if expert else None,
        "total_sessions": pkg.total_sessions,
        "used_sessions": pkg.used_sessions,
        "remaining_sessions": pkg.total_sessions - pkg.used_sessions,
        "status": pkg.status,
        "status_display": flags["status_display"],
        "purchased_at": pkg.purchased_at.isoformat() if pkg.purchased_at else None,
        "cooldown_until": pkg.cooldown_until.isoformat() if pkg.cooldown_until else None,
        "in_cooldown": flags["in_cooldown"],
        "expires_at": pkg.expires_at.isoformat() if pkg.expires_at else None,
        "validity_days": validity_days,
        "payment_intent_id": pkg.payment_intent_id,
        "paid_amount": float(pkg.paid_amount) if pkg.paid_amount is not None else None,
        "currency": pkg.currency,
        "bundle_breakdown": pkg.bundle_breakdown,
        "released_amount_pence": pkg.released_amount_pence,
        "refunded_amount_pence": pkg.refunded_amount_pence,
        "platform_fee_pence": pkg.platform_fee_pence,
        "released_at": pkg.released_at.isoformat() if pkg.released_at else None,
        "refunded_at": pkg.refunded_at.isoformat() if pkg.refunded_at else None,
        "last_redeemed_at": pkg.last_redeemed_at.isoformat() if pkg.last_redeemed_at else None,
        "can_refund_full": flags["can_refund_full"],
        "can_refund_partial": flags["can_refund_partial"],
        "can_review": flags["can_review"],
        "can_dispute": flags["can_dispute"],
        "history": history,
    }


@package_purchase_router.get("/api/my/packages/{package_id}/redemption-qr")
async def get_redemption_qr(
    package_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """buyer 端获取 QR 数据 + 6 位 OTP 备用,TTL 60s"""
    pkg_result = await db.execute(
        select(UserServicePackage).where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.user_id == current_user.id,
                UserServicePackage.status == "active",
            )
        )
    )
    pkg = pkg_result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "package_not_found_or_inactive", "message": "套餐不存在或已失效"},
        )

    if pkg.used_sessions >= pkg.total_sessions:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "package_exhausted", "message": "套餐次数已用完"},
        )

    # 过期检查 — 只读, 不写库
    # 注意: 这里不能 mark expired, 否则:
    #   1) 并发的 redeem 路径会因为状态变为 expired 而拿不到记录;
    #   2) buyer 第二次请求 QR 时会看到不一致状态。
    # 真正的过期 mark 由 redeem 路径处理 (那里有 with_for_update 行锁)。
    if pkg.expires_at:
        expires = pkg.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < get_utc_time():
            raise HTTPException(
                status_code=400,
                detail={"error_code": "package_expired", "message": "套餐已过期"},
            )

    qr = _generate_qr_payload(pkg.id, current_user.id)
    otp = _generate_otp(pkg.id, current_user.id)

    return {
        "qr_data": qr["qr_data"],
        "otp": otp,
        "expires_at_ts": qr["expires_at_ts"],
        "ttl_seconds": _OTP_TTL_SECONDS,
        "package_id": pkg.id,
    }


# ==================== 3. 团队侧: 扫码核销 ====================

@package_purchase_router.post("/api/experts/{expert_id}/packages/redeem")
async def redeem_package(
    expert_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """团队 owner/admin 扫码或输入 OTP 核销套餐。

    Body:
      - 二选一: qr_data (扫码) 或 otp (手动输入)
      - bundle 套餐必填: sub_service_id

    Returns: 更新后的 package 状态
    """
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    qr_data = body.get("qr_data")
    otp = body.get("otp")
    raw_sub_service_id = body.get("sub_service_id")
    # bundle 子服务 id 必须强转 int, 否则 PackageUsageLog.sub_service_id (INTEGER) insert 会爆
    sub_service_id: Optional[int] = None
    if raw_sub_service_id is not None:
        try:
            sub_service_id = int(raw_sub_service_id)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=400,
                detail={"error_code": "sub_service_id_invalid", "message": "sub_service_id 必须是整数"},
            )

    if not qr_data and not otp:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "qr_or_otp_required", "message": "必须提供 qr_data 或 otp 之一"},
        )

    # 解析 package_id + user_id
    if qr_data:
        payload = _verify_qr_payload(qr_data)
        if not payload:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "qr_invalid_or_expired", "message": "QR 无效或已过期,请刷新"},
            )
        target_package_id = int(payload["p"])
        target_user_id = str(payload["u"])
        redeem_method = "qr"
    else:
        otp_data = _consume_otp(str(otp))
        if not otp_data:
            raise HTTPException(
                status_code=400,
                detail={"error_code": "otp_invalid_or_expired", "message": "OTP 无效或已过期"},
            )
        target_package_id = otp_data["package_id"]
        target_user_id = otp_data["user_id"]
        redeem_method = "otp"

    # 加载 + 锁定 package
    pkg_result = await db.execute(
        select(UserServicePackage)
        .where(
            and_(
                UserServicePackage.id == target_package_id,
                UserServicePackage.user_id == target_user_id,
                UserServicePackage.expert_id == expert_id,
                UserServicePackage.status == "active",
            )
        )
        .with_for_update()
    )
    pkg = pkg_result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "package_not_found_or_not_team", "message": "套餐不存在或不属于该团队"},
        )

    # 过期检查
    if pkg.expires_at:
        expires = pkg.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < get_utc_time():
            pkg.status = "expired"
            await db.commit()
            raise HTTPException(
                status_code=400,
                detail={"error_code": "package_expired", "message": "套餐已过期"},
            )

    if pkg.used_sessions >= pkg.total_sessions:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "package_exhausted", "message": "套餐次数已用完"},
        )

    # bundle 套餐必须指定子服务,且 breakdown[sub].used < breakdown[sub].total
    if pkg.bundle_breakdown:
        if sub_service_id is None:
            # 需要前端弹出子服务选择器。
            # 这里必须返回 200 OK + requires_sub_service_selection=true,
            # 而不是 raise HTTPException(detail=dict), 原因:
            # 全局 http_exception_handler 通过 create_error_response(...) 只把
            # message/error_code 放到顶层, 丢掉 detail 里其他字段 (sub_services),
            # 导致前端永远拿不到子服务列表, bundle 套餐根本无法核销。
            sub_ids: list[int] = []
            for raw_key in pkg.bundle_breakdown.keys():
                try:
                    sub_ids.append(int(raw_key))
                except (TypeError, ValueError):
                    continue
            sub_service_map: dict[int, dict] = {}
            if sub_ids:
                sub_result = await db.execute(
                    select(models.TaskExpertService).where(
                        models.TaskExpertService.id.in_(sub_ids)
                    )
                )
                for svc in sub_result.scalars().all():
                    sub_service_map[svc.id] = {
                        "id": svc.id,
                        "service_name": svc.service_name,
                        "service_name_en": getattr(svc, "service_name_en", None),
                        "service_name_zh": getattr(svc, "service_name_zh", None),
                    }
            sub_services_payload: list[dict] = []
            for raw_key, entry in pkg.bundle_breakdown.items():
                try:
                    sid = int(raw_key)
                except (TypeError, ValueError):
                    continue
                total = int(entry.get("total", 0)) if isinstance(entry, dict) else 0
                used = int(entry.get("used", 0)) if isinstance(entry, dict) else 0
                info = sub_service_map.get(sid, {"id": sid})
                sub_services_payload.append({
                    **info,
                    "total": total,
                    "used": used,
                    "remaining": max(total - used, 0),
                })
            return {
                "requires_sub_service_selection": True,
                "package_id": pkg.id,
                "bundle_breakdown": pkg.bundle_breakdown,
                "sub_services": sub_services_payload,
            }
        sub_key = str(sub_service_id)
        bd = dict(pkg.bundle_breakdown)
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
        # 必须创建一个全新 dict 而非 in-place 修改, 保证 SQLAlchemy 的 dirty tracking
        # 一定能检测到 JSONB 字段变更; 双保险再加 flag_modified.
        pkg.bundle_breakdown = dict(bd)
        from sqlalchemy.orm.attributes import flag_modified
        flag_modified(pkg, "bundle_breakdown")

    # 通用核销
    pkg.used_sessions = pkg.used_sessions + 1
    pkg.last_redeemed_at = get_utc_time()
    if pkg.used_sessions >= pkg.total_sessions:
        pkg.status = "exhausted"
        # Trigger settlement: creates a pending PaymentTransfer for async processing
        from app.services.package_settlement import trigger_package_release
        trigger_package_release(db, pkg, reason="exhausted")

    log = PackageUsageLog(
        package_id=pkg.id,
        used_at=get_utc_time(),
        used_by=current_user.id,
        sub_service_id=sub_service_id,
        redeem_method=redeem_method,
        note=body.get("note"),
    )
    db.add(log)

    await db.commit()
    await db.refresh(pkg)

    # 通知 buyer (best-effort) — 用 i18n 模板
    try:
        from app.async_crud import AsyncNotificationCRUD
        from app.utils.notification_templates import get_notification_texts
        title_zh, content_zh, title_en, content_en = get_notification_texts(
            "package_redeemed",
            used=pkg.used_sessions,
            total=pkg.total_sessions,
        )
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=pkg.user_id,
            notification_type="package_redeemed",
            title=title_zh,
            content=content_zh,
            title_en=title_en,
            content_en=content_en,
            related_id=str(pkg.id),
            related_type="user_service_package",
        )
    except Exception as e:
        logger.warning(f"通知 buyer 套餐核销失败: {e}")

    return {
        "id": pkg.id,
        "used_sessions": pkg.used_sessions,
        "total_sessions": pkg.total_sessions,
        "remaining_sessions": pkg.total_sessions - pkg.used_sessions,
        "status": pkg.status,
        "bundle_breakdown": pkg.bundle_breakdown,
        "last_redeemed_at": pkg.last_redeemed_at.isoformat() if pkg.last_redeemed_at else None,
    }


# ==================== 4. 团队侧: 我的客户列表 ====================

@package_purchase_router.get("/api/experts/{expert_id}/customer-packages")
async def list_customer_packages(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """团队"我的客户"端点 - 列出该团队所有 buyer 的套餐余额"""
    await _get_expert_or_404(db, expert_id)
    # 仅 owner/admin 可见客户列表 — 普通 member 不应看到 buyer 隐私(姓名/头像/购买金额/套餐余额)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    base = select(UserServicePackage).where(UserServicePackage.expert_id == expert_id)
    if status_filter:
        base = base.where(UserServicePackage.status == status_filter)

    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    list_q = (
        base.order_by(UserServicePackage.last_redeemed_at.desc().nullslast(),
                      UserServicePackage.purchased_at.desc())
        .offset(offset)
        .limit(limit)
    )
    pkgs = (await db.execute(list_q)).scalars().all()

    # batch load users + services 避免 N+1
    user_ids = list({p.user_id for p in pkgs})
    service_ids = list({p.service_id for p in pkgs})
    users_by_id: dict = {}
    services_by_id: dict = {}
    if user_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(user_ids))
        )
        users_by_id = {u.id: u for u in users_result.scalars().all()}
    if service_ids:
        services_result = await db.execute(
            select(models.TaskExpertService).where(
                models.TaskExpertService.id.in_(service_ids)
            )
        )
        services_by_id = {s.id: s for s in services_result.scalars().all()}

    items = []
    for p in pkgs:
        user = users_by_id.get(p.user_id)
        service = services_by_id.get(p.service_id)
        items.append({
            "id": p.id,
            "user_id": p.user_id,
            "user_name": user.name if user else None,
            "user_avatar": user.avatar if user else None,
            "service_id": p.service_id,
            "service_name": service.service_name if service else None,
            "package_type": service.package_type if service else None,
            "total_sessions": p.total_sessions,
            "used_sessions": p.used_sessions,
            "remaining_sessions": p.total_sessions - p.used_sessions,
            "status": p.status,
            "purchased_at": p.purchased_at.isoformat() if p.purchased_at else None,
            "expires_at": p.expires_at.isoformat() if p.expires_at else None,
            "last_redeemed_at": p.last_redeemed_at.isoformat() if p.last_redeemed_at else None,
            "bundle_breakdown": p.bundle_breakdown,
        })

    return {"items": items, "total": total, "limit": limit, "offset": offset}


# ==================== 5. 退款 / 争议 / 评价 ====================

async def _load_package_for_update(
    db: AsyncSession, package_id: int, user_id: str
) -> UserServicePackage:
    """Load a package row with SELECT FOR UPDATE, verify ownership."""
    result = await db.execute(
        select(UserServicePackage)
        .where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.user_id == user_id,
            )
        )
        .with_for_update()
    )
    pkg = result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "package_not_found", "message": "套餐不存在"},
        )
    return pkg


async def _process_full_refund(db: AsyncSession, pkg, reason: str) -> dict:
    """Process a full refund: sets status='refunded', creates RefundRequest row."""
    paid_pence = int(round(float(pkg.paid_amount) * 100))
    pkg.status = "refunded"
    pkg.refunded_amount_pence = paid_pence

    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        poster_id=pkg.user_id,
        refund_amount=paid_pence / 100.0,
        reason=reason or "cooldown_full_refund",
        status="approved_auto",
    ))
    await db.commit()

    # Best-effort notifications
    try:
        await _notify_package_refunded(db, pkg, full=True)
    except Exception as e:
        logger.warning(f"Failed to send package refund notification: {e}")

    return {
        "refund_type": "full",
        "status": "refunded",
        "refund_amount_pence": paid_pence,
        "transfer_amount_pence": 0,
        "platform_fee_pence": 0,
    }


async def _process_partial_refund(db: AsyncSession, pkg, reason: str) -> dict:
    """Process a pro-rata refund: consumed → expert, unconsumed → buyer."""
    from app.services.package_settlement import compute_package_split

    split = compute_package_split(pkg)

    if split["consumed_value_pence"] == 0:
        # Past cooldown but never used → behaves as full refund
        return await _process_full_refund(db, pkg, reason)

    if split["unconsumed_value_pence"] == 0:
        raise HTTPException(
            400,
            {"error_code": "package_already_exhausted", "message": "套餐已用完"},
        )

    pkg.status = "partially_refunded"
    pkg.released_amount_pence = split["transfer_pence"]
    pkg.platform_fee_pence = split["fee_pence"]
    pkg.refunded_amount_pence = split["unconsumed_value_pence"]

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=split["transfer_pence"] / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_partial_transfer",
    ))
    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        poster_id=pkg.user_id,
        refund_amount=split["unconsumed_value_pence"] / 100.0,
        reason=reason or "user_cancel_partial",
        status="approved_auto",
    ))
    await db.commit()

    try:
        await _notify_package_refunded(db, pkg, full=False)
    except Exception as e:
        logger.warning(f"Failed to send partial refund notification: {e}")

    return {
        "refund_type": "pro_rata",
        "status": "partially_refunded",
        "refund_amount_pence": split["unconsumed_value_pence"],
        "transfer_amount_pence": split["transfer_pence"],
        "platform_fee_pence": split["fee_pence"],
    }


async def _notify_package_refunded(db: AsyncSession, pkg, full: bool):
    """Best-effort notification to buyer + expert team admins."""
    from app.async_crud import AsyncNotificationCRUD
    from app.utils.notification_templates import get_notification_texts

    # Look up service name for the template
    svc_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == pkg.service_id
        )
    )
    service_obj = svc_result.scalar_one_or_none()
    service_name = service_obj.service_name if service_obj else ""

    notif_type = "package_refunded_full" if full else "package_refunded_partial"
    t_zh, c_zh, t_en, c_en = get_notification_texts(notif_type, service_name=service_name)

    # Buyer
    await AsyncNotificationCRUD.create_notification(
        db=db, user_id=pkg.user_id, notification_type=notif_type,
        title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
        related_id=str(pkg.id), related_type="package",
    )

    # Expert team admins
    managers_result = await db.execute(
        select(ExpertMember.user_id).where(
            ExpertMember.expert_id == pkg.expert_id,
            ExpertMember.status == "active",
            ExpertMember.role.in_(["owner", "admin"]),
        )
    )
    for (mid,) in managers_result.all():
        await AsyncNotificationCRUD.create_notification(
            db=db, user_id=mid, notification_type=notif_type,
            title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
            related_id=str(pkg.id), related_type="package",
        )


@package_purchase_router.post("/api/my/packages/{package_id}/refund")
async def request_package_refund(
    package_id: int,
    request: Request,
    body: dict = None,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer requests refund for a package.

    Dispatches to full refund (scenario A/C1) or pro-rata (scenario B/C2)
    based on cooldown state and usage.
    """
    pkg = await _load_package_for_update(db, package_id, current_user.id)

    # State guard
    if pkg.status != "active":
        error_code_map = {
            "exhausted": "package_already_exhausted",
            "expired": "package_expired",
            "disputed": "package_disputed",
            "refunded": "package_already_refunded",
            "partially_refunded": "package_already_refunded",
            "released": "package_already_released",
            "cancelled": "package_cancelled",
        }
        error_code = error_code_map.get(pkg.status, "package_not_active")
        raise HTTPException(
            400,
            {"error_code": error_code, "message": f"Package status is {pkg.status}"},
        )

    now = get_utc_time()

    # Lazy expiry check
    if pkg.expires_at:
        expires = pkg.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now:
            from app.services.package_settlement import trigger_package_release
            pkg.status = "expired"
            trigger_package_release(db, pkg, reason="expired")
            await db.commit()
            raise HTTPException(
                400,
                {"error_code": "package_expired", "message": "套餐已过期"},
            )

    in_cooldown = pkg.cooldown_until and now < (
        pkg.cooldown_until.replace(tzinfo=timezone.utc)
        if pkg.cooldown_until.tzinfo is None
        else pkg.cooldown_until
    )
    never_used = pkg.used_sessions == 0
    reason = ((body or {}).get("reason") or "").strip()[:500]

    if in_cooldown and never_used:
        return await _process_full_refund(db, pkg, reason)
    else:
        return await _process_partial_refund(db, pkg, reason)


@package_purchase_router.post("/api/my/packages/{package_id}/review")
async def review_package(
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer submits a review for a package.

    Allowed statuses: exhausted, expired, released, partially_refunded
    (any state where at least some service was rendered).
    """
    rating = body.get("rating")
    comment = (body.get("comment") or "").strip()[:2000]

    if not isinstance(rating, (int, float)) or not (1 <= rating <= 5):
        raise HTTPException(
            400,
            {"error_code": "invalid_rating", "message": "评分必须是 1-5"},
        )

    pkg = await _load_package_for_update(db, package_id, current_user.id)

    allowed_statuses = ("exhausted", "expired", "released", "partially_refunded")
    if pkg.status not in allowed_statuses:
        raise HTTPException(
            400,
            {"error_code": "package_not_reviewable", "message": "当前状态不允许评价"},
        )

    # Check duplicate
    existing = await db.execute(
        select(models.Review).where(
            models.Review.package_id == package_id,
            models.Review.user_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            400,
            {"error_code": "review_already_exists", "message": "您已评价过该套餐"},
        )

    review = models.Review(
        task_id=None,
        package_id=package_id,
        user_id=current_user.id,
        rating=float(rating),
        comment=comment,
        expert_id=pkg.expert_id,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)

    return {
        "review_id": review.id,
        "package_id": package_id,
        "rating": rating,
        "status": "submitted",
    }


@package_purchase_router.post("/api/my/packages/{package_id}/dispute")
async def open_package_dispute(
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer opens a dispute for an active package with at least 1 usage."""
    reason = (body.get("reason") or "").strip()[:2000]
    evidence_files = body.get("evidence_files") or []

    if not reason:
        raise HTTPException(
            400,
            {"error_code": "reason_required", "message": "必须填写争议原因"},
        )

    pkg = await _load_package_for_update(db, package_id, current_user.id)

    if pkg.status != "active":
        raise HTTPException(
            400,
            {"error_code": "package_not_active", "message": "仅 active 套餐可发起争议"},
        )

    if pkg.used_sessions == 0:
        raise HTTPException(
            400,
            {
                "error_code": "package_never_used_use_refund",
                "message": "未使用的套餐请走退款流程",
            },
        )

    dispute = models.TaskDispute(
        task_id=None,
        package_id=pkg.id,
        poster_id=current_user.id,
        reason=reason,
        evidence_files=_json.dumps(evidence_files) if evidence_files else None,
        status="pending",
    )
    db.add(dispute)

    pkg.status = "disputed"

    # Freeze any pending PaymentTransfer for this package
    pending_result = await db.execute(
        select(models.PaymentTransfer).where(
            models.PaymentTransfer.package_id == pkg.id,
            models.PaymentTransfer.status == "pending",
        )
    )
    for t in pending_result.scalars().all():
        t.status = "on_hold"

    await db.commit()
    await db.refresh(dispute)

    # Best-effort notifications (expert team admins)
    try:
        await _notify_package_dispute_opened(db, pkg)
    except Exception as e:
        logger.warning(f"Failed to send dispute notification: {e}")

    return {
        "dispute_id": dispute.id,
        "status": "pending",
        "package_status": "disputed",
    }


async def _notify_package_dispute_opened(db: AsyncSession, pkg):
    """Notify expert team admins when a buyer opens a package dispute."""
    from app.async_crud import AsyncNotificationCRUD
    from app.utils.notification_templates import get_notification_texts

    svc_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == pkg.service_id
        )
    )
    service_obj = svc_result.scalar_one_or_none()
    service_name = service_obj.service_name if service_obj else ""

    t_zh, c_zh, t_en, c_en = get_notification_texts(
        "package_dispute_opened", service_name=service_name
    )

    managers_result = await db.execute(
        select(ExpertMember.user_id).where(
            ExpertMember.expert_id == pkg.expert_id,
            ExpertMember.status == "active",
            ExpertMember.role.in_(["owner", "admin"]),
        )
    )
    for (mid,) in managers_result.all():
        await AsyncNotificationCRUD.create_notification(
            db=db, user_id=mid, notification_type="package_dispute_opened",
            title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
            related_id=str(pkg.id), related_type="package_dispute",
        )

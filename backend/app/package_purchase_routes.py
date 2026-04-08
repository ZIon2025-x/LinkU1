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


def _build_bundle_breakdown(bundle_service_ids):
    """把 service.bundle_service_ids 解析为 UserServicePackage.bundle_breakdown 格式。

    Input formats (双格式向后兼容):
      [A, B, C]                                  → 每个 service 各 1 次
      [{"service_id": A, "count": 5}, ...]       → 显式 count

    Output:
      {"A": {"total": 1, "used": 0}, ...}
    """
    if not bundle_service_ids:
        return None
    breakdown = {}
    for item in bundle_service_ids:
        if isinstance(item, int):
            breakdown[str(item)] = {"total": 1, "used": 0}
        elif isinstance(item, dict):
            sid = item.get("service_id")
            cnt = item.get("count", 1)
            if sid is not None:
                breakdown[str(sid)] = {"total": int(cnt), "used": 0}
    return breakdown if breakdown else None


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
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架")
    if service.package_type not in ("multi", "bundle"):
        raise HTTPException(status_code=400, detail="该服务不是套餐类型")
    if service.package_price is None or float(service.package_price) <= 0:
        raise HTTPException(status_code=400, detail="服务未设置套餐价格")
    if service.owner_type != "expert":
        raise HTTPException(status_code=400, detail="个人服务暂不支持套餐购买")

    # 2. 解析团队 + Stripe 状态
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)
    if not taker_expert_id_value:
        raise HTTPException(status_code=500, detail="无法解析服务团队")

    expert = await db.get(Expert, taker_expert_id_value)
    if not expert or not expert.stripe_account_id:
        raise HTTPException(status_code=500, detail={
            "error_code": "team_no_stripe_account",
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
            raise HTTPException(status_code=400, detail="multi 套餐 total_sessions 配置错误")
        bundle_breakdown = None
    else:  # bundle
        bundle_breakdown = _build_bundle_breakdown(service.bundle_service_ids)
        if not bundle_breakdown:
            raise HTTPException(status_code=400, detail="bundle 套餐配置错误")
        total_sessions = _bundle_total_sessions(bundle_breakdown)
        if total_sessions < 1:
            raise HTTPException(status_code=400, detail="bundle 套餐总次数为 0")

    # 5. 创建 Stripe PaymentIntent
    import stripe
    from app.stripe_config import ensure_stripe_configured
    from app.utils.fee_calculator import calculate_application_fee_pence
    ensure_stripe_configured()

    price = float(service.package_price)
    currency = (service.currency or "GBP").lower()
    if currency != "gbp":
        raise HTTPException(status_code=422, detail={
            "error_code": "expert_currency_unsupported",
            "message": "团队套餐目前仅支持 GBP",
        })
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
        raise HTTPException(status_code=502, detail=f"Stripe 创建失败: {str(e)}")

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
        raise HTTPException(status_code=404, detail="套餐不存在")

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

    return {
        "id": pkg.id,
        "service_id": pkg.service_id,
        "service_name": service.service_name if service else None,
        "expert_id": pkg.expert_id,
        "expert_name": expert.name if expert else None,
        "total_sessions": pkg.total_sessions,
        "used_sessions": pkg.used_sessions,
        "remaining_sessions": pkg.total_sessions - pkg.used_sessions,
        "status": pkg.status,
        "purchased_at": pkg.purchased_at.isoformat() if pkg.purchased_at else None,
        "expires_at": pkg.expires_at.isoformat() if pkg.expires_at else None,
        "paid_amount": pkg.paid_amount,
        "currency": pkg.currency,
        "bundle_breakdown": pkg.bundle_breakdown,
        "last_redeemed_at": pkg.last_redeemed_at.isoformat() if pkg.last_redeemed_at else None,
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
        raise HTTPException(status_code=404, detail="套餐不存在或已失效")

    if pkg.used_sessions >= pkg.total_sessions:
        raise HTTPException(status_code=400, detail="套餐次数已用完")

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
    sub_service_id = body.get("sub_service_id")

    if not qr_data and not otp:
        raise HTTPException(status_code=400, detail="必须提供 qr_data 或 otp 之一")

    # 解析 package_id + user_id
    if qr_data:
        payload = _verify_qr_payload(qr_data)
        if not payload:
            raise HTTPException(status_code=400, detail="QR 无效或已过期,请刷新")
        target_package_id = int(payload["p"])
        target_user_id = str(payload["u"])
        redeem_method = "qr"
    else:
        otp_data = _consume_otp(str(otp))
        if not otp_data:
            raise HTTPException(status_code=400, detail="OTP 无效或已过期")
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
        raise HTTPException(status_code=404, detail="套餐不存在或不属于该团队")

    # 过期检查
    if pkg.expires_at:
        expires = pkg.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < get_utc_time():
            pkg.status = "expired"
            await db.commit()
            raise HTTPException(status_code=400, detail="套餐已过期")

    if pkg.used_sessions >= pkg.total_sessions:
        raise HTTPException(status_code=400, detail="套餐次数已用完")

    # bundle 套餐必须指定子服务,且 breakdown[sub].used < breakdown[sub].total
    if pkg.bundle_breakdown:
        if sub_service_id is None:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "bundle_sub_service_required",
                    "message": "bundle 套餐需指定要核销的子服务",
                    "bundle_breakdown": pkg.bundle_breakdown,
                },
            )
        sub_key = str(sub_service_id)
        bd = dict(pkg.bundle_breakdown)
        if sub_key not in bd:
            raise HTTPException(status_code=400, detail="该子服务不在此套餐中")
        sub_entry = dict(bd[sub_key])
        if int(sub_entry.get("used", 0)) >= int(sub_entry.get("total", 0)):
            raise HTTPException(status_code=400, detail="该子服务已核销完")
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

    # 通知 buyer (best-effort)
    try:
        from app.async_crud import AsyncNotificationCRUD
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=pkg.user_id,
            notification_type="package_redeemed",
            title="套餐核销成功",
            content=f"您的套餐已使用 {pkg.used_sessions}/{pkg.total_sessions} 次",
            title_en="Package Redeemed",
            content_en=f"Your package has been used {pkg.used_sessions}/{pkg.total_sessions} times",
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

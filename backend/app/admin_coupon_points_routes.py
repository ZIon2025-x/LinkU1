"""
优惠券和积分系统 - 管理员API路由
"""
import logging
from typing import Optional, List
from datetime import datetime, timezone as tz

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_

from app import schemas, models
from app.utils.time_utils import get_utc_time
from app.deps import get_db
from app.role_deps import get_current_admin_secure_sync
from app.coupon_points_crud import (
    get_coupon_by_id,
    get_coupon_by_code,
    get_points_account,
)

logger = logging.getLogger(__name__)


def get_client_ip(request: Request) -> Optional[str]:
    """获取客户端IP地址"""
    # 检查X-Forwarded-For头（代理/负载均衡器）
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        # 取第一个IP（原始客户端IP）
        return forwarded_for.split(",")[0].strip()
    
    # 检查X-Real-IP头
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    
    # 回退到直接客户端IP
    if request.client:
        return request.client.host
    
    return None

router = APIRouter(prefix="/api/admin", tags=["管理员-优惠券和积分系统"])


def _require_super_admin(admin: models.AdminUser, action: str = "此操作"):
    """🔒 安全检查：要求超级管理员权限"""
    if not getattr(admin, 'is_super_admin', 0):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"{action}需要超级管理员权限"
        )


# ==================== 优惠券管理 API ====================

@router.post("/coupons", response_model=schemas.CouponAdminOut)
def create_coupon(
    coupon_data: schemas.CouponCreate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """创建优惠券（管理员，需超级管理员权限）"""
    # 🔒 安全修复：创建优惠券需要超级管理员权限
    _require_super_admin(current_admin, "创建优惠券")
    
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_coupon_operation", {"limit": 30, "window": 300})
    rate_limit_info = rate_limiter.check_rate_limit(
        request,
        "admin_coupon_operation",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"优惠券操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 300))}
        )
    
    # 处理优惠券代码：如果为空，自动生成唯一代码
    coupon_code = coupon_data.code
    if not coupon_code or not coupon_code.strip():
        # 生成唯一代码：COUPON + 时间戳 + 随机数
        import random
        import string
        timestamp = int(datetime.now(tz.utc).timestamp())
        random_suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
        coupon_code = f"COUPON{timestamp}{random_suffix}"
        # 确保代码唯一
        while get_coupon_by_code(db, coupon_code):
            random_suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
            coupon_code = f"COUPON{timestamp}{random_suffix}"
    else:
        coupon_code = coupon_code.strip().upper()
        # 检查优惠券代码是否已存在（不区分大小写）
        existing = get_coupon_by_code(db, coupon_code)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"优惠券代码 {coupon_code} 已存在"
            )
    
    # 验证折扣值
    if coupon_data.type == "fixed_amount":
        if coupon_data.discount_value <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="满减券的折扣值必须大于0"
            )
    elif coupon_data.type == "percentage":
        if not (1 <= coupon_data.discount_value <= 10000):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="折扣券的折扣基点必须在1-10000之间（0.01%-100%）"
            )
    
    # 验证有效期
    if coupon_data.valid_until <= coupon_data.valid_from:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="有效期结束时间必须大于开始时间"
        )
    
    # 创建优惠券
    coupon = models.Coupon(
        code=coupon_code,
        name=coupon_data.name,
        description=coupon_data.description,
        type=coupon_data.type,
        discount_value=coupon_data.discount_value,
        min_amount=coupon_data.min_amount,
        max_discount=coupon_data.max_discount,
        currency=coupon_data.currency,
        total_quantity=coupon_data.total_quantity,
        per_user_limit=coupon_data.per_user_limit,
        per_device_limit=coupon_data.per_device_limit,
        per_ip_limit=coupon_data.per_ip_limit,
        can_combine=coupon_data.can_combine,
        combine_limit=coupon_data.combine_limit,
        apply_order=coupon_data.apply_order,
        valid_from=coupon_data.valid_from,
        valid_until=coupon_data.valid_until,
        usage_conditions=coupon_data.usage_conditions,
        eligibility_type=coupon_data.eligibility_type,
        eligibility_value=coupon_data.eligibility_value,
        per_user_per_month_limit=coupon_data.per_user_per_month_limit,
        per_user_limit_window=coupon_data.per_user_limit_window,
        per_user_per_window_limit=coupon_data.per_user_per_window_limit,
        per_day_limit=coupon_data.per_day_limit,
        vat_category=coupon_data.vat_category,
        points_required=coupon_data.points_required or 0,
        applicable_scenarios=coupon_data.applicable_scenarios,
        status="active"
    )
    
    db.add(coupon)
    db.commit()
    db.refresh(coupon)
    
    # 创建审计日志
    try:
        from app.crud import create_audit_log
        create_audit_log(
            db=db,
            action_type="coupon_create",
            entity_type="coupon",
            entity_id=str(coupon.id),
            admin_id=current_admin.id,
            old_value=None,
            new_value={
                "code": coupon.code,
                "name": coupon.name,
                "type": coupon.type,
                "discount_value": coupon.discount_value,
                "min_amount": coupon.min_amount,
                "valid_from": str(coupon.valid_from),
                "valid_until": str(coupon.valid_until),
                "status": coupon.status
            },
            reason=f"管理员创建优惠券: {coupon.name}",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建优惠券审计日志失败: {e}", exc_info=True)
    
    # 格式化返回
    discount_value_display = f"{coupon.discount_value / 100:.2f}"
    min_amount_display = f"{coupon.min_amount / 100:.2f}"
    
    return {
        "id": coupon.id,
        "code": coupon.code,
        "name": coupon.name,
        "type": coupon.type,
        "discount_value": coupon.discount_value,
        "discount_value_display": discount_value_display,
        "min_amount": coupon.min_amount,
        "min_amount_display": min_amount_display,
        "currency": coupon.currency,
        "valid_from": coupon.valid_from,
        "valid_until": coupon.valid_until,
        "status": coupon.status,
        "usage_conditions": coupon.usage_conditions
    }


@router.put("/coupons/{coupon_id}")
def update_coupon(
    coupon_id: int,
    coupon_data: schemas.CouponUpdate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新优惠券（管理员）"""
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_coupon_operation", {"limit": 30, "window": 300})
    rate_limit_info = rate_limiter.check_rate_limit(
        request,
        "admin_coupon_operation",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"优惠券操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 300))}
        )
    
    coupon = get_coupon_by_id(db, coupon_id)
    if not coupon:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="优惠券不存在"
        )
    
    # 记录旧值用于审计日志
    old_values = {
        "name": coupon.name,
        "description": coupon.description,
        "valid_until": str(coupon.valid_until),
        "status": coupon.status,
        "usage_conditions": coupon.usage_conditions,
        "per_user_per_month_limit": coupon.per_user_per_month_limit,
        "per_user_limit_window": coupon.per_user_limit_window,
        "per_user_per_window_limit": coupon.per_user_per_window_limit,
    }
    
    # 更新字段
    if coupon_data.name is not None:
        coupon.name = coupon_data.name
    if coupon_data.description is not None:
        coupon.description = coupon_data.description
    if coupon_data.valid_until is not None:
        if coupon_data.valid_until <= coupon.valid_from:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="有效期结束时间必须大于开始时间"
            )
        coupon.valid_until = coupon_data.valid_until
    if coupon_data.status is not None:
        coupon.status = coupon_data.status
    if coupon_data.usage_conditions is not None:
        coupon.usage_conditions = coupon_data.usage_conditions
    if coupon_data.per_user_per_month_limit is not None:
        coupon.per_user_per_month_limit = coupon_data.per_user_per_month_limit
    if coupon_data.per_user_limit_window is not None:
        coupon.per_user_limit_window = coupon_data.per_user_limit_window
    if coupon_data.per_user_per_window_limit is not None:
        coupon.per_user_per_window_limit = coupon_data.per_user_per_window_limit
    if coupon_data.points_required is not None:
        coupon.points_required = coupon_data.points_required
    if coupon_data.applicable_scenarios is not None:
        coupon.applicable_scenarios = coupon_data.applicable_scenarios
    if coupon_data.per_day_limit is not None:
        coupon.per_day_limit = coupon_data.per_day_limit
    if coupon_data.eligibility_type is not None:
        coupon.eligibility_type = coupon_data.eligibility_type
    if coupon_data.eligibility_value is not None:
        coupon.eligibility_value = coupon_data.eligibility_value

    db.commit()
    db.refresh(coupon)
    
    # 创建审计日志
    try:
        from app.crud import create_audit_log
        new_values = {
            "name": coupon.name,
            "description": coupon.description,
            "valid_until": str(coupon.valid_until),
            "status": coupon.status,
            "usage_conditions": coupon.usage_conditions,
            "per_user_per_month_limit": coupon.per_user_per_month_limit,
            "per_user_limit_window": coupon.per_user_limit_window,
            "per_user_per_window_limit": coupon.per_user_per_window_limit,
        }
        create_audit_log(
            db=db,
            action_type="coupon_update",
            entity_type="coupon",
            entity_id=str(coupon_id),
            admin_id=current_admin.id,
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员更新优惠券: {coupon.name}",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建优惠券更新审计日志失败: {e}", exc_info=True)
    
    return {
        "success": True,
        "message": "优惠券更新成功"
    }


@router.get("/coupons", response_model=schemas.CouponAdminList)
def get_coupons_list(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取优惠券列表（管理员）"""
    query = db.query(models.Coupon)
    
    if status_filter:
        query = query.filter(models.Coupon.status == status_filter)
    
    # 总数
    total = query.count()
    
    # 分页
    coupons = query.order_by(models.Coupon.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    # 格式化数据
    data = []
    for coupon in coupons:
        # 统计已使用数量
        used_count = db.query(func.count(models.UserCoupon.id)).filter(
            and_(
                models.UserCoupon.coupon_id == coupon.id,
                models.UserCoupon.status == "used"
            )
        ).scalar() or 0
        
        discount_value_display = f"{coupon.discount_value / 100:.2f}"
        min_amount_display = f"{coupon.min_amount / 100:.2f}"
        
        data.append({
            "id": coupon.id,
            "code": coupon.code,
            "name": coupon.name,
            "description": coupon.description,
            "type": coupon.type,
            "discount_value": coupon.discount_value,
            "discount_value_display": discount_value_display,
            "min_amount": coupon.min_amount,
            "min_amount_display": min_amount_display,
            "currency": coupon.currency or "GBP",
            "max_discount": coupon.max_discount,
            "valid_from": coupon.valid_from,
            "valid_until": coupon.valid_until,
            "status": coupon.status,
            "usage_conditions": coupon.usage_conditions,
            "total_quantity": coupon.total_quantity,
            "used_quantity": used_count,
            "per_user_limit": coupon.per_user_limit,
            "can_combine": coupon.can_combine,
            "points_required": coupon.points_required or 0,
            "applicable_scenarios": coupon.applicable_scenarios or [],
            "eligibility_type": coupon.eligibility_type,
            "eligibility_value": coupon.eligibility_value,
            "per_user_limit_window": coupon.per_user_limit_window,
            "per_user_per_window_limit": coupon.per_user_per_window_limit,
            "per_day_limit": coupon.per_day_limit,
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.get("/coupons/{coupon_id}", response_model=schemas.CouponAdminDetail)
def get_coupon_detail(
    coupon_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取优惠券详情（管理员）"""
    coupon = get_coupon_by_id(db, coupon_id)
    if not coupon:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="优惠券不存在"
        )
    
    # 统计信息
    total_issued = db.query(func.count(models.UserCoupon.id)).filter(
        models.UserCoupon.coupon_id == coupon.id
    ).scalar() or 0
    
    total_used = db.query(func.count(models.UserCoupon.id)).filter(
        and_(
            models.UserCoupon.coupon_id == coupon.id,
            models.UserCoupon.status == "used"
        )
    ).scalar() or 0
    
    # 计算总优惠金额
    total_discount = db.query(func.sum(models.CouponRedemption.discount_amount)).filter(
        and_(
            models.CouponRedemption.coupon_id == coupon.id,
            models.CouponRedemption.status == "confirmed"
        )
    ).scalar() or 0
    
    discount_value_display = f"{coupon.discount_value / 100:.2f}"
    min_amount_display = f"{coupon.min_amount / 100:.2f}"
    total_discount_display = f"{total_discount / 100:.2f}"
    
    statistics = {
        "total_issued": total_issued,
        "total_used": total_used,
        "total_discount_given": total_discount,
        "total_discount_given_display": total_discount_display
    }
    
    return {
        "id": coupon.id,
        "code": coupon.code,
        "name": coupon.name,
        "description": coupon.description,
        "type": coupon.type,
        "discount_value": coupon.discount_value,
        "discount_value_display": discount_value_display,
        "min_amount": coupon.min_amount,
        "min_amount_display": min_amount_display,
        "valid_from": coupon.valid_from,
        "valid_until": coupon.valid_until,
        "status": coupon.status,
        "usage_conditions": coupon.usage_conditions,
        "statistics": statistics
    }


@router.delete("/coupons/{coupon_id}")
def delete_coupon(
    coupon_id: int,
    request: Request,
    force: bool = Query(False, description="是否强制删除（即使有使用记录）"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """删除优惠券（管理员）"""
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_coupon_operation", {"limit": 30, "window": 300})
    rate_limit_info = rate_limiter.check_rate_limit(
        request,
        "admin_coupon_operation",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"优惠券操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 300))}
        )
    
    coupon = get_coupon_by_id(db, coupon_id)
    if not coupon:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="优惠券不存在"
        )
    
    # 记录旧值用于审计日志
    old_values = {
        "code": coupon.code,
        "name": coupon.name,
        "status": coupon.status,
        "used_count": 0
    }
    
    # 检查是否有使用记录
    used_count = db.query(func.count(models.UserCoupon.id)).filter(
        and_(
            models.UserCoupon.coupon_id == coupon.id,
            models.UserCoupon.status == "used"
        )
    ).scalar() or 0
    
    old_values["used_count"] = used_count
    
    if used_count > 0 and not force:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"优惠券已有 {used_count} 条使用记录，无法删除。如需删除，请设置 force=true"
        )
    
    # 🔒 安全修复：先创建审计日志（确保审计轨迹），再执行删除操作
    try:
        from app.crud import create_audit_log
        create_audit_log(
            db=db,
            action_type="coupon_delete",
            entity_type="coupon",
            entity_id=str(coupon_id),
            admin_id=current_admin.id,
            old_value=old_values,
            new_value={"status": "inactive", "force_delete": force},
            reason=f"管理员删除优惠券: {coupon.name} (强制删除: {force})",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建优惠券删除审计日志失败: {e}", exc_info=True)
    
    if force:
        # 🔒 安全修复：强制删除需要超级管理员权限
        _require_super_admin(current_admin, "强制删除优惠券")
        
        # 强制删除：审计日志已在上方创建，现在删除相关记录
        logger.warning(f"超级管理员 {current_admin.id} 强制删除优惠券 {coupon_id}，涉及 {used_count} 条使用记录")
        db.query(models.UserCoupon).filter(models.UserCoupon.coupon_id == coupon.id).delete()
        db.query(models.CouponRedemption).filter(models.CouponRedemption.coupon_id == coupon.id).delete()
        db.query(models.CouponUsageLog).filter(models.CouponUsageLog.coupon_id == coupon.id).delete()
    
    # 软删除：设置状态为inactive
    coupon.status = "inactive"
    db.commit()
    
    return {
        "success": True,
        "message": "优惠券删除成功"
    }


# ==================== 邀请码管理 API ====================

@router.post("/invitation-codes", response_model=schemas.InvitationCodeOut)
def create_invitation_code(
    invitation_data: schemas.InvitationCodeCreate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """创建邀请码（管理员）"""
    # 检查邀请码是否已存在（不区分大小写）
    existing = db.query(models.InvitationCode).filter(
        func.lower(models.InvitationCode.code) == func.lower(invitation_data.code)
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"邀请码 {invitation_data.code} 已存在"
        )
    
    # 验证奖励类型
    if invitation_data.reward_type == "points" and invitation_data.points_reward <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="积分奖励必须大于0"
        )
    elif invitation_data.reward_type == "coupon" and not invitation_data.coupon_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="优惠券奖励必须指定coupon_id"
        )
    elif invitation_data.reward_type == "both":
        if invitation_data.points_reward <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="积分奖励必须大于0"
            )
        if not invitation_data.coupon_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="优惠券奖励必须指定coupon_id"
            )
    
    # 验证有效期
    if invitation_data.valid_until <= invitation_data.valid_from:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="有效期结束时间必须大于开始时间"
        )
    
    # 验证优惠券是否存在
    if invitation_data.coupon_id:
        coupon = get_coupon_by_id(db, invitation_data.coupon_id)
        if not coupon:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="指定的优惠券不存在"
            )
    
    # 创建邀请码
    invitation_code = models.InvitationCode(
        code=invitation_data.code.upper(),
        name=invitation_data.name,
        description=invitation_data.description,
        reward_type=invitation_data.reward_type,
        points_reward=invitation_data.points_reward,
        coupon_id=invitation_data.coupon_id,
        max_uses=invitation_data.max_uses,
        valid_from=invitation_data.valid_from,
        valid_until=invitation_data.valid_until,
        is_active=invitation_data.is_active,
        created_by=current_admin.id
    )
    
    db.add(invitation_code)
    db.commit()
    db.refresh(invitation_code)
    
    points_reward_display = f"{invitation_code.points_reward / 100:.2f}"
    
    return {
        "id": invitation_code.id,
        "code": invitation_code.code,
        "message": "邀请码创建成功"
    }


@router.get("/invitation-codes", response_model=schemas.InvitationCodeList)
def get_invitation_codes_list(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取邀请码列表（管理员）"""
    query = db.query(models.InvitationCode)
    
    if status_filter == "active":
        query = query.filter(models.InvitationCode.is_active == True)
    elif status_filter == "inactive":
        query = query.filter(models.InvitationCode.is_active == False)
    
    # 总数
    total = query.count()
    
    # 分页
    invitation_codes = query.order_by(models.InvitationCode.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    # 格式化数据
    data = []
    for ic in invitation_codes:
        # 统计已使用数量
        used_count = db.query(func.count(models.UserInvitationUsage.id)).filter(
            and_(
                models.UserInvitationUsage.invitation_code_id == ic.id,
                models.UserInvitationUsage.reward_received == True
            )
        ).scalar() or 0
        
        points_reward_display = f"{ic.points_reward / 100:.2f}"
        
        data.append({
            "id": ic.id,
            "code": ic.code,
            "name": ic.name,
            "reward_type": ic.reward_type,
            "points_reward": ic.points_reward,
            "points_reward_display": points_reward_display,
            "coupon_id": ic.coupon_id,
            "max_uses": ic.max_uses,
            "used_count": used_count,
            "valid_from": ic.valid_from,
            "valid_until": ic.valid_until,
            "is_active": ic.is_active,
            "created_by": ic.created_by,
            "created_at": ic.created_at
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.get("/invitation-codes/{invitation_id}", response_model=schemas.InvitationCodeDetail)
def get_invitation_code_detail(
    invitation_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取邀请码详情（管理员）"""
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_id
    ).first()
    
    if not invitation_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="邀请码不存在"
        )
    
    # 统计信息
    total_users = db.query(func.count(models.UserInvitationUsage.id)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_code.id,
            models.UserInvitationUsage.reward_received == True
        )
    ).scalar() or 0
    
    total_points = db.query(func.sum(models.UserInvitationUsage.points_received)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_code.id,
            models.UserInvitationUsage.reward_received == True
        )
    ).scalar() or 0
    
    total_coupons = db.query(func.count(models.UserInvitationUsage.id)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_code.id,
            models.UserInvitationUsage.reward_received == True,
            models.UserInvitationUsage.coupon_received_id.isnot(None)
        )
    ).scalar() or 0
    
    used_count = total_users
    remaining_uses = None
    if invitation_code.max_uses:
        remaining_uses = max(0, invitation_code.max_uses - used_count)
    
    points_reward_display = f"{invitation_code.points_reward / 100:.2f}"
    total_points_display = f"{total_points / 100:.2f}"
    
    # 获取优惠券信息
    coupon = None
    if invitation_code.coupon_id:
        coupon_obj = get_coupon_by_id(db, invitation_code.coupon_id)
        if coupon_obj:
            coupon = {
                "id": coupon_obj.id,
                "name": coupon_obj.name,
                "type": coupon_obj.type,
                "discount_value": coupon_obj.discount_value,
                "discount_value_display": f"{coupon_obj.discount_value / 100:.2f}"
            }
    
    statistics = {
        "total_users": total_users,
        "total_points_given": total_points,
        "total_points_given_display": total_points_display,
        "total_coupons_given": total_coupons
    }
    
    return {
        "id": invitation_code.id,
        "code": invitation_code.code,
        "name": invitation_code.name,
        "description": invitation_code.description,
        "reward_type": invitation_code.reward_type,
        "points_reward": invitation_code.points_reward,
        "points_reward_display": points_reward_display,
        "coupon": coupon,
        "max_uses": invitation_code.max_uses,
        "used_count": used_count,
        "remaining_uses": remaining_uses,
        "valid_from": invitation_code.valid_from,
        "valid_until": invitation_code.valid_until,
        "is_active": invitation_code.is_active,
        "created_by": invitation_code.created_by,
        "created_at": invitation_code.created_at,
        "statistics": statistics
    }


@router.put("/invitation-codes/{invitation_id}")
def update_invitation_code(
    invitation_id: int,
    invitation_data: schemas.InvitationCodeUpdate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新邀请码（管理员）"""
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_id
    ).first()
    
    if not invitation_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="邀请码不存在"
        )
    
    # 记录旧值用于审计日志
    old_values = {
        "name": invitation_code.name,
        "description": invitation_code.description,
        "is_active": invitation_code.is_active,
        "max_uses": invitation_code.max_uses,
        "valid_from": str(invitation_code.valid_from),
        "valid_until": str(invitation_code.valid_until),
        "points_reward": invitation_code.points_reward,
        "coupon_id": invitation_code.coupon_id
    }
    
    # 更新字段
    if invitation_data.name is not None:
        invitation_code.name = invitation_data.name
    if invitation_data.description is not None:
        invitation_code.description = invitation_data.description
    if invitation_data.is_active is not None:
        invitation_code.is_active = invitation_data.is_active
    if invitation_data.max_uses is not None:
        invitation_code.max_uses = invitation_data.max_uses
    if invitation_data.valid_from is not None:
        invitation_code.valid_from = invitation_data.valid_from
    if invitation_data.valid_until is not None:
        invitation_code.valid_until = invitation_data.valid_until
    if invitation_data.points_reward is not None:
        invitation_code.points_reward = invitation_data.points_reward
    if invitation_data.coupon_id is not None:
        # 验证优惠券是否存在
        if invitation_data.coupon_id:
            coupon = get_coupon_by_id(db, invitation_data.coupon_id)
            if not coupon:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="指定的优惠券不存在"
                )
        invitation_code.coupon_id = invitation_data.coupon_id
    
    # 验证有效期
    if invitation_code.valid_until <= invitation_code.valid_from:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="有效期结束时间必须大于开始时间"
        )
    
    db.commit()
    db.refresh(invitation_code)
    
    # 创建审计日志
    try:
        from app.crud import create_audit_log
        new_values = {
            "name": invitation_code.name,
            "description": invitation_code.description,
            "is_active": invitation_code.is_active,
            "max_uses": invitation_code.max_uses,
            "valid_from": str(invitation_code.valid_from),
            "valid_until": str(invitation_code.valid_until),
            "points_reward": invitation_code.points_reward,
            "coupon_id": invitation_code.coupon_id
        }
        create_audit_log(
            db=db,
            action_type="invitation_code_update",
            entity_type="invitation_code",
            entity_id=str(invitation_id),
            admin_id=current_admin.id,
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员更新邀请码: {invitation_code.name}",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建邀请码更新审计日志失败: {e}", exc_info=True)
    
    return {
        "success": True,
        "message": "邀请码更新成功",
        "data": {
            "id": invitation_code.id,
            "code": invitation_code.code,
            "valid_until": invitation_code.valid_until
        }
    }


@router.delete("/invitation-codes/{invitation_id}")
def delete_invitation_code(
    invitation_id: int,
    request: Request,
    force: bool = Query(False, description="是否强制删除（即使有使用记录）"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """删除邀请码（管理员）"""
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_id
    ).first()
    
    if not invitation_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="邀请码不存在"
        )
    
    # 记录旧值用于审计日志
    old_values = {
        "code": invitation_code.code,
        "name": invitation_code.name,
        "is_active": invitation_code.is_active,
        "used_count": 0
    }
    
    # 检查是否有使用记录
    used_count = db.query(func.count(models.UserInvitationUsage.id)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True
        )
    ).scalar() or 0
    
    old_values["used_count"] = used_count
    
    if used_count > 0 and not force:
        # 软删除：设置状态为inactive并设置过期时间
        invitation_code.is_active = False
        invitation_code.valid_until = get_utc_time()
        db.commit()
        
        # 创建审计日志
        try:
            from app.crud import create_audit_log
            create_audit_log(
                db=db,
                action_type="invitation_code_delete",
                entity_type="invitation_code",
                entity_id=str(invitation_id),
                admin_id=current_admin.id,
                old_value=old_values,
                new_value={"is_active": False, "valid_until": str(get_utc_time()), "force_delete": False},
                reason=f"管理员删除邀请码: {invitation_code.name} (软删除)",
                ip_address=get_client_ip(request),
                device_fingerprint=None
            )
        except Exception as e:
            logger.error(f"创建邀请码删除审计日志失败: {e}", exc_info=True)
        
        return {
            "success": True,
            "message": "邀请码已禁用（软删除）",
            "deleted_at": get_utc_time()
        }
    
    if force:
        # 强制删除：删除所有相关记录
        db.query(models.UserInvitationUsage).filter(
            models.UserInvitationUsage.invitation_code_id == invitation_id
        ).delete()
    
    # 硬删除：删除邀请码记录
    db.delete(invitation_code)
    db.commit()
    
    # 创建审计日志
    try:
        from app.crud import create_audit_log
        create_audit_log(
            db=db,
            action_type="invitation_code_delete",
            entity_type="invitation_code",
            entity_id=str(invitation_id),
            admin_id=current_admin.id,
            old_value=old_values,
            new_value={"status": "deleted", "force_delete": force},
            reason=f"管理员删除邀请码: {invitation_code.name} (强制删除: {force})",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建邀请码删除审计日志失败: {e}", exc_info=True)
    
    return {
        "success": True,
        "message": "邀请码删除成功",
        "deleted_at": get_utc_time()
    }


@router.get("/invitation-codes/{invitation_id}/users", response_model=schemas.InvitationCodeUsersList)
def get_invitation_code_users(
    invitation_id: int,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取使用邀请码的用户列表（管理员）"""
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_id
    ).first()
    
    if not invitation_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="邀请码不存在"
        )
    
    # 查询使用记录
    query = db.query(models.UserInvitationUsage).filter(
        models.UserInvitationUsage.invitation_code_id == invitation_id
    )
    
    total = query.count()
    
    # 分页
    usages = query.order_by(models.UserInvitationUsage.used_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    # 格式化数据
    data = []
    for usage in usages:
        user = db.query(models.User).filter(models.User.id == usage.user_id).first()
        
        coupon_received = None
        if usage.coupon_received_id:
            coupon_obj = get_coupon_by_id(db, usage.coupon_received_id)
            if coupon_obj:
                coupon_received = {
                    "id": coupon_obj.id,
                    "name": coupon_obj.name
                }
        
        points_received_display = f"{usage.points_received / 100:.2f}" if usage.points_received else "0.00"
        
        data.append({
            "user_id": usage.user_id,
            "username": user.name if user else None,
            "email": user.email if user else None,
            "used_at": usage.used_at,
            "reward_received": usage.reward_received,
            "points_received": usage.points_received or 0,
            "points_received_display": points_received_display,
            "coupon_received": coupon_received
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.get("/invitation-codes/{invitation_id}/statistics", response_model=schemas.InvitationCodeStatistics)
def get_invitation_code_statistics(
    invitation_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取邀请码统计信息（管理员）"""
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_id
    ).first()
    
    if not invitation_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="邀请码不存在"
        )
    
    # 统计总用户数
    total_users = db.query(func.count(models.UserInvitationUsage.id)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True
        )
    ).scalar() or 0
    
    # 统计总积分
    total_points = db.query(func.sum(models.UserInvitationUsage.points_received)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True
        )
    ).scalar() or 0
    
    # 统计总优惠券
    total_coupons = db.query(func.count(models.UserInvitationUsage.id)).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True,
            models.UserInvitationUsage.coupon_received_id.isnot(None)
        )
    ).scalar() or 0
    
    # 按日期统计使用情况
    usage_by_date = db.query(
        func.date(models.UserInvitationUsage.used_at).label('date'),
        func.count(models.UserInvitationUsage.id).label('count')
    ).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True
        )
    ).group_by(func.date(models.UserInvitationUsage.used_at)).order_by(
        func.date(models.UserInvitationUsage.used_at).desc()
    ).limit(30).all()
    
    usage_by_date_list = [
        {
            "date": str(row.date),
            "count": row.count
        }
        for row in usage_by_date
    ]
    
    # 最近使用的用户
    recent_usages = db.query(models.UserInvitationUsage).filter(
        and_(
            models.UserInvitationUsage.invitation_code_id == invitation_id,
            models.UserInvitationUsage.reward_received == True
        )
    ).order_by(models.UserInvitationUsage.used_at.desc()).limit(10).all()
    
    recent_users = []
    for usage in recent_usages:
        user = db.query(models.User).filter(models.User.id == usage.user_id).first()
        recent_users.append({
            "user_id": usage.user_id,
            "username": user.name if user else None,
            "used_at": usage.used_at
        })
    
    total_points_display = f"{total_points / 100:.2f}"
    
    return {
        "code": invitation_code.code,
        "total_users": total_users,
        "total_points_given": total_points,
        "total_points_given_display": total_points_display,
        "total_coupons_given": total_coupons,
        "usage_by_date": usage_by_date_list,
        "recent_users": recent_users
    }


# ==================== 用户详情管理 API ====================

@router.get("/users/{user_id}/details", response_model=schemas.UserDetailOut)
def get_user_details(
    user_id: str,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取用户详情（包含积分和优惠券）（管理员）"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    # 获取积分账户
    points_account = get_points_account(db, user_id)
    points_account_data = None
    if points_account:
        points_account_data = {
            "balance": points_account.balance,
            "balance_display": f"{points_account.balance / 100:.2f}",
            "total_earned": points_account.total_earned,
            "total_earned_display": f"{points_account.total_earned / 100:.2f}",
            "total_spent": points_account.total_spent,
            "total_spent_display": f"{points_account.total_spent / 100:.2f}"
        }
    else:
        points_account_data = {
            "balance": 0,
            "balance_display": "0.00",
            "total_earned": 0,
            "total_earned_display": "0.00",
            "total_spent": 0,
            "total_spent_display": "0.00"
        }
    
    # 获取优惠券统计
    total_coupons = db.query(func.count(models.UserCoupon.id)).filter(
        models.UserCoupon.user_id == user_id
    ).scalar() or 0
    
    unused_coupons = db.query(func.count(models.UserCoupon.id)).filter(
        and_(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.status == "unused"
        )
    ).scalar() or 0
    
    used_coupons = db.query(func.count(models.UserCoupon.id)).filter(
        and_(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.status == "used"
        )
    ).scalar() or 0
    
    expired_coupons = db.query(func.count(models.UserCoupon.id)).filter(
        and_(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.status == "expired"
        )
    ).scalar() or 0
    
    # 获取优惠券列表（最近10个）
    user_coupons = db.query(models.UserCoupon).filter(
        models.UserCoupon.user_id == user_id
    ).order_by(models.UserCoupon.obtained_at.desc()).limit(10).all()
    
    coupon_list = []
    for uc in user_coupons:
        coupon = get_coupon_by_id(db, uc.coupon_id)
        if coupon:
            coupon_list.append({
                "id": uc.id,
                "coupon": {
                    "id": coupon.id,
                    "code": coupon.code,
                    "name": coupon.name,
                    "type": coupon.type,
                    "discount_value": coupon.discount_value,
                    "discount_value_display": f"{coupon.discount_value / 100:.2f}"
                },
                "status": uc.status,
                "obtained_at": uc.obtained_at,
                "valid_until": coupon.valid_until
            })
    
    coupons_data = {
        "total": total_coupons,
        "unused": unused_coupons,
        "used": used_coupons,
        "expired": expired_coupons,
        "list": coupon_list
    }
    
    # 获取积分交易记录（最近10条）
    recent_transactions = db.query(models.PointsTransaction).filter(
        models.PointsTransaction.user_id == user_id
    ).order_by(models.PointsTransaction.created_at.desc()).limit(10).all()
    
    transaction_list = []
    for trans in recent_transactions:
        transaction_list.append({
            "id": trans.id,
            "type": trans.type,
            "amount": trans.amount,
            "amount_display": f"{trans.amount / 100:.2f}",
            "source": trans.source,
            "description": trans.description,
            "created_at": trans.created_at
        })
    
    points_transactions_data = {
        "total": db.query(func.count(models.PointsTransaction.id)).filter(
            models.PointsTransaction.user_id == user_id
        ).scalar() or 0,
        "recent": transaction_list
    }
    
    # 获取签到统计
    last_check_in = db.query(models.CheckIn).filter(
        models.CheckIn.user_id == user_id
    ).order_by(models.CheckIn.check_in_date.desc()).first()
    
    total_check_ins = db.query(func.count(models.CheckIn.id)).filter(
        models.CheckIn.user_id == user_id
    ).scalar() or 0
    
    consecutive_days = last_check_in.consecutive_days if last_check_in else 0
    last_check_in_date = str(last_check_in.check_in_date) if last_check_in else None
    
    check_in_stats = {
        "total_days": total_check_ins,
        "consecutive_days": consecutive_days,
        "last_check_in": last_check_in_date
    }
    
    # 获取邀请码使用记录
    invitation_usage = None
    invitation_record = db.query(models.UserInvitationUsage).filter(
        models.UserInvitationUsage.user_id == user_id
    ).first()
    
    if invitation_record:
        invitation_code = db.query(models.InvitationCode).filter(
            models.InvitationCode.id == invitation_record.invitation_code_id
        ).first()
        if invitation_code:
            invitation_usage = {
                "code": invitation_code.code,
                "used_at": invitation_record.used_at,
                "reward_received": invitation_record.reward_received
            }
    
    # 获取用户邀请码文本
    invitation_code_text = user.invitation_code_text if hasattr(user, 'invitation_code_text') else None
    
    return {
        "user": {
            "id": user.id,
            "username": user.name,
            "email": user.email,
            "phone": user.phone,
            "created_at": user.created_at,
            "invitation_code": invitation_code_text
        },
        "points_account": points_account_data,
        "coupons": coupons_data,
        "points_transactions": points_transactions_data,
        "check_in_stats": check_in_stats,
        "invitation_usage": invitation_usage
    }


@router.post("/users/{user_id}/points/adjust")
def adjust_user_points(
    user_id: str,
    adjust_data: schemas.UserPointsAdjustRequest,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """调整用户积分（管理员，大额调整需超级管理员权限）"""
    # 🔒 安全修复：大额积分调整（>10000积分 = £100）需要超级管理员权限
    LARGE_ADJUSTMENT_THRESHOLD = 1_000_000  # 10000积分（以分为单位）
    if abs(adjust_data.amount) > LARGE_ADJUSTMENT_THRESHOLD:
        _require_super_admin(current_admin, f"大额积分调整（>{LARGE_ADJUSTMENT_THRESHOLD // 100}积分）")
    
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_points_adjust", {"limit": 50, "window": 300})
    rate_limit_info = rate_limiter.check_rate_limit(
        request,
        "admin_points_adjust",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"积分调整操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 300))}
        )
    
    # 单次调整金额上限验证（单次最多调整100万积分，即£10,000）
    MAX_ADJUST_AMOUNT = 100_000_000  # 100万积分
    if adjust_data.amount > MAX_ADJUST_AMOUNT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"单次积分调整不能超过 {MAX_ADJUST_AMOUNT / 100:.0f} 积分（£{MAX_ADJUST_AMOUNT / 10000:.2f}）"
        )
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    # 获取或创建积分账户
    from app.coupon_points_crud import get_or_create_points_account
    points_account = get_or_create_points_account(db, user_id)
    
    old_balance = points_account.balance
    
    # 根据操作类型调整积分
    if adjust_data.action == "add":
        new_balance = points_account.balance + adjust_data.amount
        transaction_type = "earn"
        description = f"管理员手动增加积分：{adjust_data.reason or '无说明'}"
    elif adjust_data.action == "subtract":
        if points_account.balance < adjust_data.amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"积分不足，当前余额：{points_account.balance / 100:.2f}，需要扣除：{adjust_data.amount / 100:.2f}"
            )
        new_balance = points_account.balance - adjust_data.amount
        transaction_type = "spend"
        description = f"管理员手动扣除积分：{adjust_data.reason or '无说明'}"
    elif adjust_data.action == "set":
        new_balance = adjust_data.amount
        if new_balance < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="积分不能设置为负数"
            )
        transaction_type = "earn" if new_balance > old_balance else "spend"
        diff = abs(new_balance - old_balance)
        description = f"管理员设置积分为：{new_balance / 100:.2f}（原余额：{old_balance / 100:.2f}）{adjust_data.reason or ''}"
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的操作类型，支持：add, subtract, set"
        )
    
    # 更新积分账户
    points_account.balance = new_balance
    if transaction_type == "earn":
        points_account.total_earned += abs(new_balance - old_balance)
    else:
        points_account.total_spent += abs(old_balance - new_balance)
    
    # 创建交易记录（使用幂等键防止重复操作）
    import uuid
    from app.utils.time_utils import get_utc_time
    admin_adjust_idempotency_key = f"admin_adjust_{current_admin.id}_{user_id}_{uuid.uuid4()}"
    transaction = models.PointsTransaction(
        user_id=user_id,
        type=transaction_type,
        amount=abs(new_balance - old_balance) if adjust_data.action != "set" else abs(new_balance - old_balance),
        balance_after=new_balance,
        source="admin_adjust",
        description=description,
        batch_id=None,
        idempotency_key=admin_adjust_idempotency_key
    )
    
    db.add(transaction)
    
    # 创建审计日志（记录管理员操作）
    try:
        from app.crud import create_audit_log
        create_audit_log(
            db=db,
            action_type="points_adjust",
            entity_type="points_account",
            entity_id=user_id,
            admin_id=current_admin.id,
            old_value={
                "balance": old_balance,
                "total_earned": points_account.total_earned - (abs(new_balance - old_balance) if transaction_type == "earn" else 0),
                "total_spent": points_account.total_spent - (abs(old_balance - new_balance) if transaction_type == "spend" else 0)
            },
            new_value={
                "balance": new_balance,
                "total_earned": points_account.total_earned,
                "total_spent": points_account.total_spent
            },
            reason=adjust_data.reason or f"管理员{adjust_data.action}积分操作",
            ip_address=get_client_ip(request),
            device_fingerprint=None
        )
    except Exception as e:
        # 审计日志失败不影响主流程，但记录错误
        logger.error(f"创建积分调整审计日志失败: {e}", exc_info=True)
    
    db.commit()
    db.refresh(points_account)
    db.refresh(transaction)
    
    return {
        "success": True,
        "message": "积分调整成功",
        "old_balance": old_balance,
        "old_balance_display": f"{old_balance / 100:.2f}",
        "new_balance": new_balance,
        "new_balance_display": f"{new_balance / 100:.2f}",
        "transaction_id": transaction.id
    }


# ==================== 批量发放 API ====================

@router.post("/rewards/points/batch", response_model=schemas.BatchRewardResponse)
def batch_reward_points(
    request: schemas.BatchRewardRequest,
    http_request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """批量发放积分（管理员，需超级管理员权限）"""
    # 🔒 安全修复：批量发放积分需要超级管理员权限
    _require_super_admin(current_admin, "批量发放积分")
    
    import json
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_batch_reward", {"limit": 5, "window": 3600})
    rate_limit_info = rate_limiter.check_rate_limit(
        http_request,
        "admin_batch_reward",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"批量发放操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 3600))}
        )
    
    # 金额上限验证（单次批量发放最多100万积分，即£10,000）
    MAX_BATCH_POINTS = 100_000_000  # 100万积分（以分为单位）
    if request.amount > MAX_BATCH_POINTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"单次批量发放积分不能超过 {MAX_BATCH_POINTS / 100:.0f} 积分（£{MAX_BATCH_POINTS / 10000:.2f}）"
        )
    
    # 用户数量上限验证（单次最多发放给10,000个用户）
    MAX_BATCH_USERS = 10000
    
    # 解析目标用户
    target_user_ids = []
    if request.target_type == "user":
        if not request.target_value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="target_type=user时，target_value必须提供用户ID列表（JSON格式）"
            )
        try:
            target_user_ids = json.loads(request.target_value)
            if not isinstance(target_user_ids, list):
                raise ValueError("target_value必须是JSON数组")
        except (json.JSONDecodeError, ValueError) as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"target_value格式错误：{str(e)}"
            )
    elif request.target_type == "user_type":
        if not request.target_value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="target_type=user_type时，target_value必须提供用户类型"
            )
        # 查询指定类型的用户
        target_user_ids = [
            user.id for user in db.query(models.User).filter(
                models.User.user_level == request.target_value
            ).all()
        ]
    elif request.target_type == "all":
        # 查询所有用户
        target_user_ids = [
            user.id for user in db.query(models.User).all()
        ]
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的target_type，支持：user, user_type, all"
        )
    
    if not target_user_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="没有找到符合条件的用户"
        )
    
    # 用户数量上限验证（单次最多发放给10,000个用户）
    if len(target_user_ids) > MAX_BATCH_USERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"单次批量发放用户数量不能超过 {MAX_BATCH_USERS} 个，当前：{len(target_user_ids)} 个"
        )
    
    # 总金额上限验证（总发放金额不能超过1000万积分，即£100,000）
    MAX_TOTAL_POINTS = 1_000_000_000  # 1000万积分
    total_points = request.amount * len(target_user_ids)
    if total_points > MAX_TOTAL_POINTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"批量发放总金额不能超过 {MAX_TOTAL_POINTS / 100:.0f} 积分（£{MAX_TOTAL_POINTS / 10000:.2f}），"
                   f"当前：{total_points / 100:.0f} 积分（£{total_points / 10000:.2f}）"
        )
    
    # 创建发放记录
    admin_reward = models.AdminReward(
        reward_type="points",
        target_type=request.target_type,
        target_value=request.target_value,
        points_value=request.amount,
        total_users=len(target_user_ids),
        status="pending",
        description=request.description,
        created_by=current_admin.id
    )
    
    db.add(admin_reward)
    db.commit()
    db.refresh(admin_reward)
    
    # 如果异步处理，创建详情记录并返回
    if request.is_async:
        # 创建详情记录（待处理）
        for user_id in target_user_ids:
            detail = models.AdminRewardDetail(
                admin_reward_id=admin_reward.id,
                user_id=user_id,
                reward_type="points",
                points_value=request.amount,
                status="pending"
            )
            db.add(detail)
        
        admin_reward.status = "processing"
        db.commit()
        
        # TODO: 启动后台任务处理批量发放
        # 这里可以创建一个后台任务来处理
        
        return {
            "reward_id": admin_reward.id,
            "status": "processing",
            "estimated_users": len(target_user_ids),
            "message": "批量发放任务已创建，正在处理中"
        }
    else:
        # 同步处理
        from app.coupon_points_crud import get_or_create_points_account, add_points_transaction
        
        success_count = 0
        failed_count = 0
        details = []
        
        for user_id in target_user_ids:
            try:
                # 获取或创建积分账户
                points_account = get_or_create_points_account(db, user_id)
                
                # 添加积分（使用幂等键防止重复发放）
                batch_idempotency_key = f"admin_batch_{admin_reward.id}_{user_id}"
                add_points_transaction(
                    db,
                    user_id,
                    type="earn",
                    amount=request.amount,
                    source="admin_batch_reward",
                    description=request.description,
                    batch_id=str(admin_reward.id),
                    idempotency_key=batch_idempotency_key
                )
                
                # 创建详情记录
                detail = models.AdminRewardDetail(
                    admin_reward_id=admin_reward.id,
                    user_id=user_id,
                    reward_type="points",
                    points_value=request.amount,
                    status="success",
                    completed_at=get_utc_time()
                )
                db.add(detail)
                
                success_count += 1
                details.append({
                    "user_id": user_id,
                    "status": "success"
                })
            except Exception as e:
                failed_count += 1
                detail = models.AdminRewardDetail(
                    admin_reward_id=admin_reward.id,
                    user_id=user_id,
                    reward_type="points",
                    points_value=request.amount,
                    status="failed",
                    error_message=str(e),
                    completed_at=get_utc_time()
                )
                db.add(detail)
                details.append({
                    "user_id": user_id,
                    "status": "failed",
                    "error": str(e)
                })
        
        # 更新发放记录
        admin_reward.success_count = success_count
        admin_reward.failed_count = failed_count
        admin_reward.status = "completed" if failed_count == 0 else "processing"
        admin_reward.completed_at = get_utc_time()
        
        db.commit()
        
        # 创建审计日志
        try:
            from app.crud import create_audit_log
            create_audit_log(
                db=db,
                action_type="batch_reward_points",
                entity_type="admin_reward",
                entity_id=str(admin_reward.id),
                admin_id=current_admin.id,
                old_value=None,
                new_value={
                    "reward_type": "points",
                    "target_type": request.target_type,
                    "target_value": request.target_value,
                    "points_value": request.amount,
                    "total_users": len(target_user_ids),
                    "success_count": success_count,
                    "failed_count": failed_count,
                    "status": admin_reward.status
                },
                reason=f"管理员批量发放积分: {request.description or '无说明'}",
                ip_address=get_client_ip(http_request),
                device_fingerprint=None
            )
        except Exception as e:
            logger.error(f"创建批量发放积分审计日志失败: {e}", exc_info=True)
        
        return {
            "reward_id": admin_reward.id,
            "status": "completed" if failed_count == 0 else "processing",
            "total_users": len(target_user_ids),
            "success_count": success_count,
            "failed_count": failed_count,
            "details": details
        }


@router.post("/rewards/coupons/batch", response_model=schemas.BatchRewardResponse)
def batch_reward_coupons(
    request: schemas.BatchCouponRequest,
    http_request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """批量发放优惠券（管理员，需超级管理员权限）"""
    # 🔒 安全修复：批量发放优惠券需要超级管理员权限
    _require_super_admin(current_admin, "批量发放优惠券")
    
    import json
    from app.rate_limiting import rate_limiter, RATE_LIMITS
    
    # 频率限制检查
    rate_limit_config = RATE_LIMITS.get("admin_batch_reward", {"limit": 5, "window": 3600})
    rate_limit_info = rate_limiter.check_rate_limit(
        http_request,
        "admin_batch_reward",
        limit=rate_limit_config["limit"],
        window=rate_limit_config["window"]
    )
    if not rate_limit_info.get("allowed", True):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"批量发放操作过于频繁，请稍后再试。限制：{rate_limit_config['limit']}次/{rate_limit_config['window']}秒",
            headers={"Retry-After": str(rate_limit_info.get("retry_after", 3600))}
        )
    
    # 验证优惠券是否存在
    coupon = get_coupon_by_id(db, request.coupon_id)
    if not coupon:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="优惠券不存在"
        )
    
    # 解析目标用户
    target_user_ids = []
    if request.target_type == "user":
        if not request.target_value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="target_type=user时，target_value必须提供用户ID列表（JSON格式）"
            )
        try:
            target_user_ids = json.loads(request.target_value)
            if not isinstance(target_user_ids, list):
                raise ValueError("target_value必须是JSON数组")
        except (json.JSONDecodeError, ValueError) as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"target_value格式错误：{str(e)}"
            )
    elif request.target_type == "user_type":
        if not request.target_value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="target_type=user_type时，target_value必须提供用户类型"
            )
        target_user_ids = [
            user.id for user in db.query(models.User).filter(
                models.User.user_level == request.target_value
            ).all()
        ]
    elif request.target_type == "all":
        target_user_ids = [
            user.id for user in db.query(models.User).all()
        ]
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的target_type，支持：user, user_type, all"
        )
    
    if not target_user_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="没有找到符合条件的用户"
        )
    
    # 创建发放记录
    admin_reward = models.AdminReward(
        reward_type="coupon",
        target_type=request.target_type,
        target_value=request.target_value,
        coupon_id=request.coupon_id,
        total_users=len(target_user_ids),
        status="pending",
        description=request.description,
        created_by=current_admin.id
    )
    
    db.add(admin_reward)
    db.commit()
    db.refresh(admin_reward)
    
    # 如果异步处理
    if request.is_async:
        for user_id in target_user_ids:
            detail = models.AdminRewardDetail(
                admin_reward_id=admin_reward.id,
                user_id=user_id,
                reward_type="coupon",
                coupon_id=request.coupon_id,
                status="pending"
            )
            db.add(detail)
        
        admin_reward.status = "processing"
        db.commit()
        
        # TODO: 启动后台任务处理批量发放
        
        return {
            "reward_id": admin_reward.id,
            "status": "processing",
            "estimated_users": len(target_user_ids),
            "message": "批量发放任务已创建，正在处理中"
        }
    else:
        # 同步处理
        from app.coupon_points_crud import claim_coupon
        
        success_count = 0
        failed_count = 0
        details = []
        
        for user_id in target_user_ids:
            try:
                # 领取优惠券
                user_coupon, error = claim_coupon(db, user_id, request.coupon_id)
                if error:
                    raise Exception(error)
                
                # 创建详情记录
                detail = models.AdminRewardDetail(
                    admin_reward_id=admin_reward.id,
                    user_id=user_id,
                    reward_type="coupon",
                    coupon_id=request.coupon_id,
                    status="success",
                    completed_at=get_utc_time()
                )
                db.add(detail)
                
                success_count += 1
                details.append({
                    "user_id": user_id,
                    "status": "success",
                    "user_coupon_id": user_coupon.id if user_coupon else None
                })
            except Exception as e:
                failed_count += 1
                detail = models.AdminRewardDetail(
                    admin_reward_id=admin_reward.id,
                    user_id=user_id,
                    reward_type="coupon",
                    coupon_id=request.coupon_id,
                    status="failed",
                    error_message=str(e),
                    completed_at=get_utc_time()
                )
                db.add(detail)
                details.append({
                    "user_id": user_id,
                    "status": "failed",
                    "error": str(e)
                })
        
        # 更新发放记录
        admin_reward.success_count = success_count
        admin_reward.failed_count = failed_count
        admin_reward.status = "completed" if failed_count == 0 else "processing"
        admin_reward.completed_at = get_utc_time()
        
        db.commit()
        
        # 创建审计日志
        try:
            from app.crud import create_audit_log
            create_audit_log(
                db=db,
                action_type="batch_reward_coupons",
                entity_type="admin_reward",
                entity_id=str(admin_reward.id),
                admin_id=current_admin.id,
                old_value=None,
                new_value={
                    "reward_type": "coupon",
                    "target_type": request.target_type,
                    "target_value": request.target_value,
                    "coupon_id": request.coupon_id,
                    "total_users": len(target_user_ids),
                    "success_count": success_count,
                    "failed_count": failed_count,
                    "status": admin_reward.status
                },
                reason=f"管理员批量发放优惠券: {request.description or '无说明'}",
                ip_address=get_client_ip(http_request),
                device_fingerprint=None
            )
        except Exception as e:
            logger.error(f"创建批量发放优惠券审计日志失败: {e}", exc_info=True)
        
        return {
            "reward_id": admin_reward.id,
            "status": "completed" if failed_count == 0 else "processing",
            "total_users": len(target_user_ids),
            "success_count": success_count,
            "failed_count": failed_count,
            "details": details
        }


@router.get("/rewards/{reward_id}", response_model=schemas.BatchRewardDetail)
def get_reward_detail(
    reward_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取发放任务详情（管理员）"""
    admin_reward = db.query(models.AdminReward).filter(
        models.AdminReward.id == reward_id
    ).first()
    
    if not admin_reward:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="发放任务不存在"
        )
    
    # 计算进度
    progress = None
    if admin_reward.total_users > 0:
        processed = admin_reward.success_count + admin_reward.failed_count
        progress = (processed / admin_reward.total_users) * 100
    
    # 获取失败用户列表
    failed_details = db.query(models.AdminRewardDetail).filter(
        and_(
            models.AdminRewardDetail.admin_reward_id == reward_id,
            models.AdminRewardDetail.status == "failed"
        )
    ).limit(100).all()
    
    failed_users = [
        {
            "user_id": detail.user_id,
            "error": detail.error_message
        }
        for detail in failed_details
    ]
    
    points_value_display = f"{admin_reward.points_value / 100:.2f}" if admin_reward.points_value else None
    
    return {
        "id": admin_reward.id,
        "reward_type": admin_reward.reward_type,
        "target_type": admin_reward.target_type,
        "target_value": admin_reward.target_value,
        "points_value": admin_reward.points_value,
        "points_value_display": points_value_display,
        "total_users": admin_reward.total_users,
        "success_count": admin_reward.success_count,
        "failed_count": admin_reward.failed_count,
        "status": admin_reward.status,
        "description": admin_reward.description,
        "created_by": admin_reward.created_by,
        "created_at": admin_reward.created_at,
        "completed_at": admin_reward.completed_at,
        "progress": progress,
        "failed_users": failed_users if failed_users else None
    }


@router.get("/rewards", response_model=schemas.BatchRewardList)
def get_rewards_list(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    reward_type: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取发放任务列表（管理员）"""
    query = db.query(models.AdminReward)
    
    if reward_type:
        query = query.filter(models.AdminReward.reward_type == reward_type)
    if status_filter:
        query = query.filter(models.AdminReward.status == status_filter)
    
    total = query.count()
    
    rewards = query.order_by(models.AdminReward.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    data = []
    for reward in rewards:
        points_value_display = f"{reward.points_value / 100:.2f}" if reward.points_value else None
        
        data.append({
            "id": reward.id,
            "reward_type": reward.reward_type,
            "target_type": reward.target_type,
            "target_value": reward.target_value,
            "points_value": reward.points_value,
            "points_value_display": points_value_display,
            "total_users": reward.total_users,
            "success_count": reward.success_count,
            "status": reward.status,
            "created_at": reward.created_at,
            "completed_at": reward.completed_at
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


# ==================== 系统配置管理 API ====================

@router.get("/settings/points", response_model=schemas.PointsSettings)
def get_points_settings(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取积分系统配置（管理员）"""
    from app.crud import get_system_setting
    
    # 获取各项配置，如果不存在则使用默认值
    exchange_rate_setting = get_system_setting(db, "points_exchange_rate")
    points_exchange_rate = float(exchange_rate_setting.setting_value) if exchange_rate_setting else 100.0
    
    task_bonus_setting = get_system_setting(db, "points_task_complete_bonus")
    points_task_complete_bonus = int(task_bonus_setting.setting_value) if task_bonus_setting else 0  # 默认0积分
    
    invite_reward_setting = get_system_setting(db, "points_invite_reward")
    points_invite_reward = int(invite_reward_setting.setting_value) if invite_reward_setting else 5000
    
    invite_task_bonus_setting = get_system_setting(db, "points_invite_task_bonus")
    points_invite_task_bonus = int(invite_task_bonus_setting.setting_value) if invite_task_bonus_setting else 500
    
    expire_days_setting = get_system_setting(db, "points_expire_days")
    points_expire_days = int(expire_days_setting.setting_value) if expire_days_setting else 0
    
    return {
        "points_exchange_rate": points_exchange_rate,
        "points_task_complete_bonus": points_task_complete_bonus,
        "points_invite_reward": points_invite_reward,
        "points_invite_task_bonus": points_invite_task_bonus,
        "points_expire_days": points_expire_days
    }


@router.put("/settings/points")
def update_points_settings(
    settings: schemas.PointsSettingsUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新积分系统配置（管理员）"""
    from app.crud import upsert_system_setting
    
    # 更新各项配置
    upsert_system_setting(db, "points_exchange_rate", str(settings.points_exchange_rate), "积分兑换比例（100积分=£1.00）")
    upsert_system_setting(db, "points_task_complete_bonus", str(settings.points_task_complete_bonus), "任务完成奖励积分（平台赠送，非任务报酬）")
    upsert_system_setting(db, "points_invite_reward", str(settings.points_invite_reward), "邀请新用户奖励积分（平台赠送）")
    upsert_system_setting(db, "points_invite_task_bonus", str(settings.points_invite_task_bonus), "被邀请用户完成任务，邀请者获得积分奖励（平台赠送，非任务报酬）")
    upsert_system_setting(db, "points_expire_days", str(settings.points_expire_days), "积分有效期（0表示永不过期）")
    
    return {
        "success": True,
        "message": "配置更新成功"
    }


@router.get("/checkin/settings", response_model=schemas.CheckInSettings)
def get_checkin_settings(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取签到系统配置（管理员）"""
    from app.crud import get_system_setting
    
    # 获取每日基础积分
    daily_base_points_setting = get_system_setting(db, "checkin_daily_base_points")
    daily_base_points = int(daily_base_points_setting.setting_value) if daily_base_points_setting else 0  # 默认0积分
    
    # 获取最大连续签到天数
    max_consecutive_days_setting = get_system_setting(db, "checkin_max_consecutive_days")
    max_consecutive_days = int(max_consecutive_days_setting.setting_value) if max_consecutive_days_setting else 30
    
    # 获取签到奖励规则
    rewards = db.query(models.CheckInReward).filter(
        models.CheckInReward.is_active == True
    ).order_by(models.CheckInReward.consecutive_days).all()
    
    reward_list = []
    for reward in rewards:
        points_reward_display = f"{reward.points_reward / 100:.2f}" if reward.points_reward else None
        coupon = None
        if reward.coupon_id:
            coupon_obj = get_coupon_by_id(db, reward.coupon_id)
            if coupon_obj:
                coupon = {
                    "id": coupon_obj.id,
                    "name": coupon_obj.name
                }
        
        reward_list.append({
            "id": reward.id,
            "consecutive_days": reward.consecutive_days,
            "reward_type": reward.reward_type,
            "points_reward": reward.points_reward,
            "points_reward_display": points_reward_display,
            "coupon_id": reward.coupon_id,
            "coupon": coupon,
            "reward_description": reward.reward_description,
            "is_active": reward.is_active
        })
    
    daily_base_points_display = f"{daily_base_points / 100:.2f}"
    
    return {
        "daily_base_points": daily_base_points,
        "daily_base_points_display": daily_base_points_display,
        "max_consecutive_days": max_consecutive_days,
        "rewards": reward_list
    }


@router.put("/checkin/settings")
def update_checkin_settings(
    settings: schemas.CheckInSettingsUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新签到系统配置（管理员）"""
    from app.crud import upsert_system_setting
    
    if settings.daily_base_points is not None:
        upsert_system_setting(db, "checkin_daily_base_points", str(settings.daily_base_points), "每日签到基础积分")
    if settings.max_consecutive_days is not None:
        upsert_system_setting(db, "checkin_max_consecutive_days", str(settings.max_consecutive_days), "最大连续签到天数")
    
    return {
        "success": True,
        "message": "签到配置更新成功"
    }


@router.get("/checkin/rewards", response_model=schemas.CheckInRewardList)
def get_checkin_rewards_list(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    is_active: Optional[bool] = Query(None),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取签到奖励规则列表（管理员）"""
    query = db.query(models.CheckInReward)
    
    if is_active is not None:
        query = query.filter(models.CheckInReward.is_active == is_active)
    
    total = query.count()
    
    rewards = query.order_by(models.CheckInReward.consecutive_days).offset((page - 1) * limit).limit(limit).all()
    
    data = []
    for reward in rewards:
        points_reward_display = f"{reward.points_reward / 100:.2f}" if reward.points_reward else None
        coupon = None
        if reward.coupon_id:
            coupon_obj = get_coupon_by_id(db, reward.coupon_id)
            if coupon_obj:
                coupon = {
                    "id": coupon_obj.id,
                    "name": coupon_obj.name,
                    "discount_value": coupon_obj.discount_value,
                    "discount_value_display": f"{coupon_obj.discount_value / 100:.2f}"
                }
        
        data.append({
            "id": reward.id,
            "consecutive_days": reward.consecutive_days,
            "reward_type": reward.reward_type,
            "points_reward": reward.points_reward,
            "points_reward_display": points_reward_display,
            "coupon_id": reward.coupon_id,
            "coupon": coupon,
            "reward_description": reward.reward_description,
            "is_active": reward.is_active,
            "created_at": reward.created_at,
            "updated_at": reward.updated_at
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.post("/checkin/rewards", response_model=schemas.CheckInRewardOut)
def create_checkin_reward(
    reward_data: schemas.CheckInRewardConfig,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """创建签到奖励规则（管理员）"""
    # 检查连续天数是否已存在
    existing = db.query(models.CheckInReward).filter(
        models.CheckInReward.consecutive_days == reward_data.consecutive_days
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"连续签到{reward_data.consecutive_days}天的奖励规则已存在"
        )
    
    # 验证奖励类型
    if reward_data.reward_type == "points" and not reward_data.points_reward:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="积分奖励必须指定points_reward"
        )
    elif reward_data.reward_type == "coupon" and not reward_data.coupon_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="优惠券奖励必须指定coupon_id"
        )
    
    # 验证优惠券是否存在
    if reward_data.coupon_id:
        coupon = get_coupon_by_id(db, reward_data.coupon_id)
        if not coupon:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="指定的优惠券不存在"
            )
    
    # 创建奖励规则
    reward = models.CheckInReward(
        consecutive_days=reward_data.consecutive_days,
        reward_type=reward_data.reward_type,
        points_reward=reward_data.points_reward,
        coupon_id=reward_data.coupon_id,
        reward_description=reward_data.reward_description,
        is_active=reward_data.is_active if reward_data.is_active is not None else True
    )
    
    db.add(reward)
    db.commit()
    db.refresh(reward)
    
    points_reward_display = f"{reward.points_reward / 100:.2f}" if reward.points_reward else None
    
    return {
        "id": reward.id,
        "consecutive_days": reward.consecutive_days,
        "reward_type": reward.reward_type,
        "points_reward": reward.points_reward,
        "points_reward_display": points_reward_display,
        "coupon_id": reward.coupon_id,
        "reward_description": reward.reward_description,
        "is_active": reward.is_active,
        "created_at": reward.created_at,
        "updated_at": reward.updated_at
    }


@router.put("/checkin/rewards/{reward_id}", response_model=schemas.CheckInRewardOut)
def update_checkin_reward(
    reward_id: int,
    reward_data: schemas.CheckInRewardConfigUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新签到奖励规则（管理员）"""
    reward = db.query(models.CheckInReward).filter(
        models.CheckInReward.id == reward_id
    ).first()
    
    if not reward:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="签到奖励规则不存在"
        )
    
    # 如果修改了连续天数，检查是否冲突
    if reward_data.consecutive_days is not None and reward_data.consecutive_days != reward.consecutive_days:
        existing = db.query(models.CheckInReward).filter(
            and_(
                models.CheckInReward.consecutive_days == reward_data.consecutive_days,
                models.CheckInReward.id != reward_id
            )
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"连续签到{reward_data.consecutive_days}天的奖励规则已存在"
            )
        reward.consecutive_days = reward_data.consecutive_days
    
    # 更新其他字段
    if reward_data.reward_type is not None:
        reward.reward_type = reward_data.reward_type
    if reward_data.points_reward is not None:
        reward.points_reward = reward_data.points_reward
    if reward_data.coupon_id is not None:
        # 验证优惠券是否存在
        if reward_data.coupon_id:
            coupon = get_coupon_by_id(db, reward_data.coupon_id)
            if not coupon:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="指定的优惠券不存在"
                )
        reward.coupon_id = reward_data.coupon_id
    if reward_data.reward_description is not None:
        reward.reward_description = reward_data.reward_description
    if reward_data.is_active is not None:
        reward.is_active = reward_data.is_active
    
    db.commit()
    db.refresh(reward)
    
    points_reward_display = f"{reward.points_reward / 100:.2f}" if reward.points_reward else None
    
    return {
        "id": reward.id,
        "consecutive_days": reward.consecutive_days,
        "reward_type": reward.reward_type,
        "points_reward": reward.points_reward,
        "points_reward_display": points_reward_display,
        "coupon_id": reward.coupon_id,
        "reward_description": reward.reward_description,
        "is_active": reward.is_active,
        "created_at": reward.created_at,
        "updated_at": reward.updated_at
    }


@router.delete("/checkin/rewards/{reward_id}")
def delete_checkin_reward(
    reward_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """删除签到奖励规则（管理员）"""
    reward = db.query(models.CheckInReward).filter(
        models.CheckInReward.id == reward_id
    ).first()
    
    if not reward:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="签到奖励规则不存在"
        )
    
    db.delete(reward)
    db.commit()
    
    return {
        "success": True,
        "message": "签到奖励规则删除成功"
    }


# ==================== 任务积分调整 API ====================

@router.put("/tasks/{task_id}/points-reward")
def update_task_points_reward(
    task_id: int,
    request: schemas.TaskPointsRewardUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """调整任务完成奖励积分（管理员）"""
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="任务不存在"
        )
    
    # 更新任务积分奖励
    task.points_reward = request.points_reward
    db.commit()
    db.refresh(task)
    
    # 创建审计日志
    try:
        from app.crud import create_audit_log
        create_audit_log(
            db=db,
            action_type="task_points_reward_update",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_admin.id,
            old_value={"points_reward": old_points_reward},
            new_value={"points_reward": request.points_reward},
            reason=f"管理员更新任务积分奖励: 任务ID {task_id}",
            ip_address=get_client_ip(http_request),
            device_fingerprint=None
        )
    except Exception as e:
        logger.error(f"创建任务积分奖励更新审计日志失败: {e}", exc_info=True)
    
    return {
        "success": True,
        "message": "任务积分奖励已更新",
        "task_id": task_id,
        "points_reward": task.points_reward
    }


# ==================== 审计日志查询 API ====================

@router.get("/audit-logs", response_model=schemas.AuditLogList)
def get_audit_logs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    action_type: Optional[str] = Query(None, description="操作类型筛选"),
    entity_type: Optional[str] = Query(None, description="实体类型筛选"),
    admin_id: Optional[str] = Query(None, description="管理员ID筛选"),
    start_date: Optional[datetime] = Query(None, description="开始日期"),
    end_date: Optional[datetime] = Query(None, description="结束日期"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取审计日志列表（管理员）"""
    from app.models import AuditLog
    
    query = db.query(AuditLog)
    
    # 筛选条件
    if action_type:
        query = query.filter(AuditLog.action_type == action_type)
    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)
    if admin_id:
        query = query.filter(AuditLog.admin_id == admin_id)
    if start_date:
        query = query.filter(AuditLog.created_at >= start_date)
    if end_date:
        query = query.filter(AuditLog.created_at <= end_date)
    
    # 总数
    total = query.count()
    
    # 分页
    logs = query.order_by(AuditLog.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    # 格式化数据
    data = []
    for log in logs:
        data.append({
            "id": log.id,
            "action_type": log.action_type,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "user_id": log.user_id,
            "admin_id": log.admin_id,
            "old_value": log.old_value,
            "new_value": log.new_value,
            "reason": log.reason,
            "ip_address": str(log.ip_address) if log.ip_address else None,
            "device_fingerprint": log.device_fingerprint,
            "error_code": log.error_code,
            "error_message": log.error_message,
            "created_at": log.created_at
        })
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": data
    }


@router.get("/audit-logs/{log_id}", response_model=schemas.AuditLogDetail)
def get_audit_log_detail(
    log_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取审计日志详情（管理员）"""
    from app.models import AuditLog
    
    log = db.query(AuditLog).filter(AuditLog.id == log_id).first()
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="审计日志不存在"
        )
    
    return {
        "id": log.id,
        "action_type": log.action_type,
        "entity_type": log.entity_type,
        "entity_id": log.entity_id,
        "user_id": log.user_id,
        "admin_id": log.admin_id,
        "old_value": log.old_value,
        "new_value": log.new_value,
        "reason": log.reason,
        "ip_address": str(log.ip_address) if log.ip_address else None,
        "device_fingerprint": log.device_fingerprint,
        "error_code": log.error_code,
        "error_message": log.error_message,
        "created_at": log.created_at
    }


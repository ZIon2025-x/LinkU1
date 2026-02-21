"""
优惠券和积分系统 CRUD 操作
"""
import json
import logging
from datetime import datetime, date, timedelta, timezone
from typing import Optional, List, Dict, Any
from decimal import Decimal

from sqlalchemy import and_, or_, func, select, update, delete
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.dialects.postgresql import insert

from app import models, schemas
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# 每用户限领周期：day=按日, week=按周(ISO周一), month=按月, year=按年
VALID_LIMIT_WINDOWS = ("day", "week", "month", "year")
WINDOW_LABELS = {"day": "今日", "week": "本周", "month": "本月", "year": "本年"}


def _start_of_window_utc(now: datetime, window: str) -> tuple[datetime, str]:
    """返回当前周期（UTC）的起始时间与中文标签。window: day|week|month|year"""
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    if window == "day":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif window == "week":
        # ISO 周：周一为第一天
        d = now.date()
        monday = d - timedelta(days=d.weekday())
        start = datetime(monday.year, monday.month, monday.day, 0, 0, 0, 0, tzinfo=timezone.utc)
    elif window == "month":
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    elif window == "year":
        start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    else:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        window = "month"
    label = WINDOW_LABELS.get(window, "本月")
    return start, label


# ==================== 积分相关 CRUD ====================

def get_points_account(db: Session, user_id: str) -> Optional[models.PointsAccount]:
    """获取用户积分账户"""
    return db.query(models.PointsAccount).filter(models.PointsAccount.user_id == user_id).first()


def create_points_account(db: Session, user_id: str) -> models.PointsAccount:
    """创建积分账户"""
    account = models.PointsAccount(
        user_id=user_id,
        balance=0,
        currency="GBP",
        total_earned=0,
        total_spent=0
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def get_or_create_points_account(db: Session, user_id: str) -> models.PointsAccount:
    """获取或创建积分账户"""
    account = get_points_account(db, user_id)
    if not account:
        account = create_points_account(db, user_id)
    return account


def add_points_transaction(
    db: Session,
    user_id: str,
    type: str,  # earn, spend, refund, expire
    amount: int,  # 积分数量（正数表示增加，负数表示减少）
    source: Optional[str] = None,
    related_id: Optional[int] = None,
    related_type: Optional[str] = None,
    batch_id: Optional[str] = None,
    expires_at: Optional[datetime] = None,
    description: Optional[str] = None,
    idempotency_key: Optional[str] = None
) -> models.PointsTransaction:
    """
    添加积分交易记录并更新账户余额（带并发控制和幂等性保护）
    """
    from sqlalchemy import select
    
    # 幂等性检查：如果提供了 idempotency_key，检查是否已存在
    if idempotency_key:
        existing_transaction = db.query(models.PointsTransaction).filter(
            models.PointsTransaction.idempotency_key == idempotency_key
        ).first()
        if existing_transaction:
            # 幂等性：返回已存在的交易
            return existing_transaction
    
    # 使用 SELECT FOR UPDATE 锁定积分账户，防止并发修改
    account_query = select(models.PointsAccount).where(
        models.PointsAccount.user_id == user_id
    ).with_for_update()
    account_result = db.execute(account_query)
    account = account_result.scalar_one_or_none()
    
    # 如果账户不存在，创建新账户
    if not account:
        account = models.PointsAccount(
            user_id=user_id,
            balance=0,
            currency="GBP",
            total_earned=0,
            total_spent=0
        )
        db.add(account)
        db.flush()  # 刷新以获取ID
    
    # 验证 amount 符号是否正确
    if type == "earn" or type == "refund":
        if amount <= 0:
            raise ValueError(f"类型 {type} 的 amount 必须为正数，当前值：{amount}")
    elif type == "spend" or type == "expire" or type == "coupon_redeem":
        if amount >= 0:
            raise ValueError(f"类型 {type} 的 amount 必须为负数，当前值：{amount}")
        # 对于消费类型，检查余额是否足够
        if account.balance < abs(amount):
            raise ValueError(
                f"积分余额不足，当前余额：{account.balance / 100:.2f}，"
                f"需要：{abs(amount) / 100:.2f}"
            )
    
    # 在锁内计算新余额（确保准确性）
    new_balance = account.balance + amount
    
    # 验证余额不会变成负数（额外安全检查）
    if new_balance < 0:
        raise ValueError(
            f"积分余额不能为负数，当前余额：{account.balance / 100:.2f}，"
            f"操作金额：{amount / 100:.2f}，结果余额：{new_balance / 100:.2f}"
        )
    
    # 创建交易记录
    transaction = models.PointsTransaction(
        user_id=user_id,
        type=type,
        amount=amount,
        balance_after=new_balance,
        currency=account.currency,
        source=source,
        related_id=related_id,
        related_type=related_type,
        batch_id=batch_id,
        expires_at=expires_at,
        description=description,
        idempotency_key=idempotency_key
    )
    db.add(transaction)
    
    # 更新账户余额（在锁内更新，安全）
    account.balance = new_balance
    if type == "earn" or type == "refund":
        account.total_earned += abs(amount)
    elif type == "spend" or type == "expire" or type == "coupon_redeem":
        account.total_spent += abs(amount)
    
    try:
        db.commit()
        db.refresh(transaction)
        return transaction
    except Exception as e:
        db.rollback()
        # 如果是唯一约束冲突（idempotency_key），重新查询并返回已存在的交易
        if idempotency_key and "unique constraint" in str(e).lower():
            existing = db.query(models.PointsTransaction).filter(
                models.PointsTransaction.idempotency_key == idempotency_key
            ).first()
            if existing:
                return existing
        raise


def get_points_transactions(
    db: Session,
    user_id: str,
    skip: int = 0,
    limit: int = 20
) -> tuple[List[models.PointsTransaction], int]:
    """获取用户积分交易记录"""
    query = db.query(models.PointsTransaction).filter(
        models.PointsTransaction.user_id == user_id
    ).order_by(models.PointsTransaction.created_at.desc())
    
    total = query.count()
    transactions = query.offset(skip).limit(limit).all()
    
    return transactions, total


# ==================== 优惠券相关 CRUD ====================

def get_coupon_by_code(db: Session, code: str) -> Optional[models.Coupon]:
    """通过代码获取优惠券（不区分大小写）"""
    return db.query(models.Coupon).filter(
        func.lower(models.Coupon.code) == func.lower(code)
    ).first()


def get_coupon_by_id(db: Session, coupon_id: int) -> Optional[models.Coupon]:
    """通过ID获取优惠券"""
    return db.query(models.Coupon).filter(models.Coupon.id == coupon_id).first()


def create_coupon(db: Session, coupon: schemas.CouponCreate) -> models.Coupon:
    """创建优惠券"""
    db_coupon = models.Coupon(**coupon.dict())
    db.add(db_coupon)
    db.commit()
    db.refresh(db_coupon)
    return db_coupon


def update_coupon(db: Session, coupon_id: int, coupon_update: schemas.CouponUpdate) -> Optional[models.Coupon]:
    """更新优惠券"""
    db_coupon = get_coupon_by_id(db, coupon_id)
    if not db_coupon:
        return None
    
    update_data = coupon_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_coupon, key, value)
    
    db.commit()
    db.refresh(db_coupon)
    return db_coupon


def _user_can_still_claim_coupon(db: Session, user_id: str, coupon: models.Coupon) -> bool:
    """检查用户是否还能领取该优惠券（与 claim_coupon 的限领逻辑一致）"""
    now = get_utc_time()
    coupon_id = coupon.id

    # 每用户每周期限领
    window = getattr(coupon, "per_user_limit_window", None)
    window = (window or "").strip().lower() or None
    limit_in_window = getattr(coupon, "per_user_per_window_limit", None)
    if limit_in_window is None and getattr(coupon, "per_user_per_month_limit", None) is not None:
        limit_in_window = coupon.per_user_per_month_limit
        window = "month" if not window else window
    if window and limit_in_window is not None and limit_in_window > 0:
        if window not in VALID_LIMIT_WINDOWS:
            window = "month"
        start_of_window_utc, _ = _start_of_window_utc(now, window)
        window_claim_count = db.query(models.UserCoupon).filter(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.obtained_at >= start_of_window_utc,
            models.UserCoupon.obtained_at <= now
        ).count()
        if window_claim_count >= limit_in_window:
            return False

    # 每用户总限领（per_user_limit）
    if coupon.per_user_limit:
        user_coupon_count = db.query(models.UserCoupon).filter(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.status.in_(["unused", "used", "expired"])
        ).count()
        if user_coupon_count >= coupon.per_user_limit:
            return False

    # 全局余量
    if coupon.total_quantity:
        total_issued = db.query(models.UserCoupon).filter(
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.status.in_(["unused", "used", "expired"])
        ).count()
        if total_issued >= coupon.total_quantity:
            return False

    return True


def get_available_coupons(db: Session, user_id: Optional[str] = None) -> List[models.Coupon]:
    """获取可用优惠券列表（会员专属券仅对 vip/super 用户展示，已领满的券不展示）"""
    now = get_utc_time()
    query = db.query(models.Coupon).filter(
        models.Coupon.status == "active",
        models.Coupon.valid_from <= now,
        models.Coupon.valid_until >= now
    )
    if user_id:
        user_obj = db.query(models.User).filter(models.User.id == user_id).first()
        is_member = user_obj and (user_obj.user_level or "normal").strip().lower() in ("vip", "super")
        if not is_member:
            query = query.filter(
                or_(
                    models.Coupon.eligibility_type.is_(None),
                    models.Coupon.eligibility_type != "member"
                )
            )
    coupons = query.all()
    # 已登录用户：过滤掉已领满的券
    if user_id:
        coupons = [c for c in coupons if _user_can_still_claim_coupon(db, user_id, c)]
    return coupons


def get_user_coupons(
    db: Session,
    user_id: str,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 20
) -> tuple[List[models.UserCoupon], int]:
    """获取用户优惠券列表"""
    query = db.query(models.UserCoupon).filter(
        models.UserCoupon.user_id == user_id
    )
    
    if status:
        query = query.filter(models.UserCoupon.status == status)
    
    total = query.count()
    user_coupons = query.order_by(models.UserCoupon.obtained_at.desc()).offset(skip).limit(limit).all()
    
    return user_coupons, total


def claim_coupon(
    db: Session,
    user_id: str,
    coupon_id: int,
    promotion_code_id: Optional[int] = None,
    device_fingerprint: Optional[str] = None,
    ip_address: Optional[str] = None,
    idempotency_key: Optional[str] = None
) -> tuple[Optional[models.UserCoupon], Optional[str]]:
    """
    领取优惠券（带并发控制）。
    返回 (user_coupon, error_message)：成功时 error_message 为 None，失败时 user_coupon 为 None 且 error_message 为具体原因。
    """
    # 检查幂等性
    if idempotency_key:
        existing = db.query(models.UserCoupon).filter(
            models.UserCoupon.idempotency_key == idempotency_key
        ).first()
        if existing:
            return existing, None
    
    # 使用 SELECT FOR UPDATE 锁定优惠券记录，防止并发超发
    coupon = db.query(models.Coupon).filter(
        models.Coupon.id == coupon_id
    ).with_for_update().first()
    
    if not coupon:
        return None, "优惠券不存在"
    
    # 检查优惠券状态和有效期
    now = get_utc_time()
    if coupon.status != "active" or coupon.valid_from > now or coupon.valid_until < now:
        return None, "优惠券已失效或不在有效期内"
    
    # 会员专属券：仅 vip/super 可领
    if coupon.eligibility_type == "member":
        user_obj = db.query(models.User).filter(models.User.id == user_id).first()
        if not user_obj:
            return None, "仅会员可领取该优惠券"
        user_level = (user_obj.user_level or "normal").strip().lower()
        allowed_levels = ["vip", "super"]
        if coupon.eligibility_value:
            allowed_levels = [x.strip().lower() for x in coupon.eligibility_value.split(",") if x.strip()]
        if user_level not in allowed_levels:
            return None, "仅会员可领取该优惠券"
    
    # 每用户每周期限领（per_user_limit_window + per_user_per_window_limit，或兼容 per_user_per_month_limit）
    window = getattr(coupon, "per_user_limit_window", None)
    window = (window or "").strip().lower() or None
    limit_in_window = getattr(coupon, "per_user_per_window_limit", None)
    if limit_in_window is None and getattr(coupon, "per_user_per_month_limit", None) is not None:
        limit_in_window = coupon.per_user_per_month_limit
        window = "month" if not window else window
    if window and limit_in_window is not None and limit_in_window > 0:
        if window not in VALID_LIMIT_WINDOWS:
            window = "month"
        start_of_window_utc, window_label = _start_of_window_utc(now, window)
        window_claim_count = db.query(models.UserCoupon).filter(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.obtained_at >= start_of_window_utc,
            models.UserCoupon.obtained_at <= now
        ).count()
        if window_claim_count >= limit_in_window:
            return None, f"{window_label}已领取过该优惠券"
    
    # 检查用户是否已领取（per_user_limit）
    if coupon.per_user_limit:
        user_coupon_count = db.query(models.UserCoupon).filter(
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.status.in_(["unused", "used", "expired"])
        ).count()
        if user_coupon_count >= coupon.per_user_limit:
            return None, "已达到该优惠券的领取上限"
    
    # 检查全局余量（total_quantity）- 已在锁内，安全
    if coupon.total_quantity:
        total_issued = db.query(models.UserCoupon).filter(
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.status.in_(["unused", "used", "expired"])
        ).count()
        if total_issued >= coupon.total_quantity:
            return None, "优惠券已领完"
    
    # 创建用户优惠券
    user_coupon = models.UserCoupon(
        user_id=user_id,
        coupon_id=coupon_id,
        promotion_code_id=promotion_code_id,
        status="unused",
        device_fingerprint=device_fingerprint,
        ip_address=ip_address,
        idempotency_key=idempotency_key
    )
    db.add(user_coupon)
    db.commit()
    db.refresh(user_coupon)
    
    return user_coupon, None


def validate_coupon_usage(
    db: Session,
    user_id: str,
    coupon_id: int,
    order_amount: int,
    task_location: Optional[str] = None,
    task_type: Optional[str] = None,
    task_date: Optional[datetime] = None
) -> tuple[bool, Optional[str], Optional[int]]:
    """
    验证优惠券是否可以使用
    返回: (是否有效, 错误消息, 优惠金额)
    """
    coupon = get_coupon_by_id(db, coupon_id)
    if not coupon:
        return False, "优惠券不存在", None
    
    now = get_utc_time()
    
    # 检查状态和有效期
    if coupon.status != "active":
        return False, "优惠券已禁用", None
    
    if now < coupon.valid_from:
        return False, f"优惠券尚未生效，生效时间：{coupon.valid_from}", None
    
    if now > coupon.valid_until:
        return False, f"优惠券已过期，过期时间：{coupon.valid_until}", None
    
    # 检查最低使用金额
    if order_amount < coupon.min_amount:
        return False, f"订单金额不足，最低使用金额：{coupon.min_amount / 100:.2f}", None
    
    # 检查使用条件限制
    if coupon.usage_conditions:
        conditions = coupon.usage_conditions
        
        # 地点限制
        if conditions.get("locations") and task_location:
            if task_location not in conditions["locations"]:
                return False, f"该优惠券仅限在 {', '.join(conditions['locations'])} 使用", None
        
        # 任务类型限制
        if conditions.get("task_types") and task_type:
            if task_type not in conditions["task_types"]:
                return False, "该优惠券不适用于此任务类型", None
        
        # 金额限制
        if conditions.get("min_task_amount") and order_amount < conditions["min_task_amount"]:
            return False, f"任务金额不符合优惠券使用条件（最低：{conditions['min_task_amount'] / 100:.2f}）", None
        
        if conditions.get("max_task_amount") and order_amount > conditions["max_task_amount"]:
            return False, f"任务金额不符合优惠券使用条件（最高：{conditions['max_task_amount'] / 100:.2f}）", None
    
    # 计算优惠金额
    if coupon.type == "fixed_amount":
        discount_amount = coupon.discount_value
    elif coupon.type == "percentage":
        discount_amount = int(order_amount * coupon.discount_value / 10000)
        if coupon.max_discount:
            discount_amount = min(discount_amount, coupon.max_discount)
    else:
        return False, "优惠券类型错误", None
    
    return True, None, discount_amount


def use_coupon(
    db: Session,
    user_id: str,
    user_coupon_id: int,
    task_id: int,
    order_amount: int,
    task_location: Optional[str] = None,
    task_type: Optional[str] = None,
    task_date: Optional[datetime] = None,
    idempotency_key: Optional[str] = None
) -> tuple[Optional[models.CouponUsageLog], Optional[str]]:
    """使用优惠券"""
    # 检查幂等性
    if idempotency_key:
        existing_log = db.query(models.CouponUsageLog).filter(
            models.CouponUsageLog.idempotency_key == idempotency_key
        ).first()
        if existing_log:
            return existing_log, None
    
    # 获取用户优惠券（SELECT FOR UPDATE 锁定行，防止并发使用同一张优惠券）
    user_coupon = db.query(models.UserCoupon).filter(
        models.UserCoupon.id == user_coupon_id,
        models.UserCoupon.user_id == user_id
    ).with_for_update().first()

    if not user_coupon:
        return None, "用户优惠券不存在"

    if user_coupon.status != "unused":
        return None, "优惠券已使用或已过期"

    # 验证优惠券
    is_valid, error_msg, discount_amount = validate_coupon_usage(
        db, user_id, user_coupon.coupon_id, order_amount, task_location, task_type, task_date
    )
    
    # 更新用户优惠券状态
    user_coupon.status = "used"
    user_coupon.used_at = get_utc_time()
    user_coupon.used_in_task_id = task_id
    
    # 创建使用记录
    final_amount = order_amount - discount_amount
    usage_log = models.CouponUsageLog(
        user_coupon_id=user_coupon_id,
        user_id=user_id,
        coupon_id=user_coupon.coupon_id,
        task_id=task_id,
        discount_amount_before_tax=discount_amount,
        discount_amount=discount_amount,
        order_amount_before_tax=order_amount,
        order_amount_incl_tax=order_amount,
        final_amount_before_tax=final_amount,
        final_amount_incl_tax=final_amount,
        currency="GBP",
        idempotency_key=idempotency_key
    )
    db.add(usage_log)
    db.commit()
    db.refresh(usage_log)
    
    return usage_log, None


def get_coupon_usage_log(db: Session, usage_log_id: int) -> Optional[models.CouponUsageLog]:
    """获取优惠券使用记录"""
    return db.query(models.CouponUsageLog).filter(
        models.CouponUsageLog.id == usage_log_id
    ).first()


def restore_coupon(db: Session, coupon_id: int, user_id: str) -> bool:
    """
    恢复优惠券（退款时使用）
    将已使用的优惠券恢复为未使用状态
    """
    try:
        # 查找用户优惠券（通过 coupon_id 和 user_id）
        # 需要找到最近使用的、状态为 used 的优惠券
        user_coupon = db.query(models.UserCoupon).filter(
            models.UserCoupon.coupon_id == coupon_id,
            models.UserCoupon.user_id == user_id,
            models.UserCoupon.status == "used"
        ).order_by(models.UserCoupon.used_at.desc()).first()
        
        if not user_coupon:
            logger.warning(f"未找到可恢复的优惠券：coupon_id={coupon_id}, user_id={user_id}")
            return False
        
        # 使用 SELECT FOR UPDATE 锁定行
        user_coupon = db.query(models.UserCoupon).filter(
            models.UserCoupon.id == user_coupon.id
        ).with_for_update().first()
        
        if user_coupon.status != "used":
            logger.warning(f"优惠券状态不正确，无法恢复：status={user_coupon.status}")
            return False
        
        # 恢复优惠券状态
        user_coupon.status = "unused"
        user_coupon.used_at = None
        user_coupon.used_in_task_id = None
        
        # 更新优惠券使用记录的退款状态
        usage_log = db.query(models.CouponUsageLog).filter(
            models.CouponUsageLog.user_coupon_id == user_coupon.id,
            models.CouponUsageLog.refund_status == "none"
        ).order_by(models.CouponUsageLog.created_at.desc()).first()
        
        if usage_log:
            usage_log.refund_status = "full"
            usage_log.refunded_at = get_utc_time()
        
        db.commit()
        logger.info(f"✅ 已恢复优惠券：user_coupon_id={user_coupon.id}, coupon_id={coupon_id}")
        return True
        
    except Exception as e:
        logger.error(f"恢复优惠券失败: {e}", exc_info=True)
        db.rollback()
        return False


# ==================== 签到相关 CRUD ====================

def get_check_in_today(db: Session, user_id: str, timezone_str: str = "Europe/London") -> Optional[models.CheckIn]:
    """获取用户今天的签到记录"""
    from zoneinfo import ZoneInfo
    from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON
    
    tz = ZoneInfo(timezone_str)
    utc_time = get_utc_time()
    local_time = to_user_timezone(utc_time, tz)
    today = local_time.date()
    
    return db.query(models.CheckIn).filter(
        models.CheckIn.user_id == user_id,
        models.CheckIn.check_in_date == today
    ).first()


def get_last_check_in(db: Session, user_id: str) -> Optional[models.CheckIn]:
    """获取用户最后一次签到记录"""
    return db.query(models.CheckIn).filter(
        models.CheckIn.user_id == user_id
    ).order_by(models.CheckIn.check_in_date.desc()).first()


def check_in(
    db: Session,
    user_id: str,
    timezone_str: str = "Europe/London",
    device_fingerprint: Optional[str] = None,
    ip_address: Optional[str] = None,
    idempotency_key: Optional[str] = None
) -> tuple[Optional[models.CheckIn], Optional[str]]:
    """每日签到（带并发控制）"""
    from zoneinfo import ZoneInfo
    from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON
    
    tz = ZoneInfo(timezone_str)
    utc_time = get_utc_time()
    local_time = to_user_timezone(utc_time, tz)
    today = local_time.date()
    
    # 检查幂等性
    if idempotency_key:
        existing = db.query(models.CheckIn).filter(
            models.CheckIn.idempotency_key == idempotency_key
        ).first()
        if existing:
            return existing, None
    
    # 使用 SELECT FOR UPDATE 锁定用户的积分账户，防止并发签到
    # 这里锁定积分账户而不是签到记录，因为签到记录可能不存在
    from app.coupon_points_crud import get_or_create_points_account
    points_account = db.query(models.PointsAccount).filter(
        models.PointsAccount.user_id == user_id
    ).with_for_update().first()
    
    # 如果没有积分账户，先创建一个（会在后续发放奖励时用到）
    if not points_account:
        points_account = get_or_create_points_account(db, user_id)
    
    # 检查今天是否已签到（在锁内检查，安全）
    today_check_in = get_check_in_today(db, user_id, timezone_str)
    if today_check_in:
        return None, "今天已经签到过了"
    
    # 获取最后一次签到
    last_check_in = get_last_check_in(db, user_id)
    
    # 计算连续签到天数
    consecutive_days = 1
    if last_check_in:
        yesterday = today - timedelta(days=1)
        if last_check_in.check_in_date == yesterday:
            consecutive_days = last_check_in.consecutive_days + 1
        elif last_check_in.check_in_date < yesterday:
            consecutive_days = 1
    
    # 获取基础积分奖励（从系统设置）
    try:
        from app.crud import get_system_setting
        daily_base_points_setting = get_system_setting(db, "checkin_daily_base_points")
        daily_base_points = int(daily_base_points_setting.setting_value) if daily_base_points_setting else 0  # 默认0积分
    except:
        daily_base_points = 0  # 默认值
    
    # 创建签到记录
    check_in = models.CheckIn(
        user_id=user_id,
        check_in_date=today,
        timezone=timezone_str,
        consecutive_days=consecutive_days,
        reward_type="points",
        points_reward=daily_base_points,
        device_fingerprint=device_fingerprint,
        ip_address=ip_address,
        idempotency_key=idempotency_key
    )
    
    # 检查连续签到奖励
    reward_config = db.query(models.CheckInReward).filter(
        models.CheckInReward.consecutive_days == consecutive_days,
        models.CheckInReward.is_active == True
    ).first()
    
    if reward_config:
        if reward_config.reward_type == "points":
            check_in.points_reward = (check_in.points_reward or 0) + reward_config.points_reward
        elif reward_config.reward_type == "coupon":
            check_in.reward_type = "coupon"
            check_in.points_reward = None
            check_in.coupon_id = reward_config.coupon_id
    
    db.add(check_in)
    
    # 如果奖励是积分，添加到积分账户
    if check_in.reward_type == "points" and check_in.points_reward:
        add_points_transaction(
            db,
            user_id,
            type="earn",
            amount=check_in.points_reward,
            source="checkin_bonus",
            description=f"签到奖励（连续{consecutive_days}天）",
            idempotency_key=f"checkin_{user_id}_{today}" if not idempotency_key else None
        )
    
    # 如果奖励是优惠券，创建用户优惠券
    if check_in.reward_type == "coupon" and check_in.coupon_id:
        _uc, _err = claim_coupon(db, user_id, check_in.coupon_id)
        if _err:
            logger.warning("Check-in coupon claim failed for user %s: %s", user_id, _err)
    
    db.commit()
    db.refresh(check_in)
    
    return check_in, None


# ==================== 邀请码相关 CRUD ====================

def is_user_id_format(code: str) -> bool:
    """判断输入是否是用户ID格式（8位纯数字）"""
    return code.isdigit() and len(code) == 8


def process_invitation_input(
    db: Session, 
    code: str
) -> tuple[Optional[str], Optional[int], Optional[str], Optional[str]]:
    """
    处理邀请码或用户ID输入
    
    返回: (inviter_id, invitation_code_id, invitation_code_text, error_msg)
    - 如果输入是8位纯数字：查找用户，返回 (user_id, None, None, None) 或 (None, None, None, error_msg)
    - 如果输入不是纯数字：查找邀请码，返回 (None, invitation_code_id, invitation_code_text, None) 或 (None, None, None, error_msg)
    """
    code = code.strip()
    
    # 判断是否是用户ID格式（8位纯数字）
    if is_user_id_format(code):
        # 查找用户
        user = db.query(models.User).filter(models.User.id == code).first()
        if user:
            return code, None, None, None  # 返回用户ID
        else:
            return None, None, None, f"用户ID {code} 不存在"
    else:
        # 查找邀请码
        invitation_code = get_invitation_code_by_code(db, code)
        if invitation_code:
            # 验证邀请码有效性
            is_valid, error_msg, validated_code = validate_invitation_code(db, code)
            if is_valid and validated_code:
                return None, validated_code.id, validated_code.code, None
            else:
                return None, None, None, error_msg or "邀请码无效"
        else:
            return None, None, None, "邀请码不存在"


def get_invitation_code_by_code(db: Session, code: str) -> Optional[models.InvitationCode]:
    """通过代码获取邀请码（不区分大小写）"""
    return db.query(models.InvitationCode).filter(
        func.lower(models.InvitationCode.code) == func.lower(code)
    ).first()


def validate_invitation_code(db: Session, code: str) -> tuple[bool, Optional[str], Optional[models.InvitationCode]]:
    """验证邀请码"""
    invitation_code = get_invitation_code_by_code(db, code)
    
    if not invitation_code:
        return False, "邀请码不存在", None
    
    if not invitation_code.is_active:
        return False, "邀请码已禁用", None
    
    now = get_utc_time()
    if now < invitation_code.valid_from:
        return False, f"邀请码尚未生效，生效时间：{invitation_code.valid_from}", None
    
    if now > invitation_code.valid_until:
        return False, f"邀请码已过期，过期时间：{invitation_code.valid_until}", None
    
    # 检查使用次数限制
    if invitation_code.max_uses:
        used_count = db.query(models.UserInvitationUsage).filter(
            models.UserInvitationUsage.invitation_code_id == invitation_code.id,
            models.UserInvitationUsage.reward_received == True
        ).count()
        if used_count >= invitation_code.max_uses:
            return False, "邀请码使用次数已达上限", None
    
    return True, None, invitation_code


def use_invitation_code(
    db: Session,
    user_id: str,
    invitation_code_id: int
) -> tuple[bool, Optional[str]]:
    """使用邀请码（注册时调用，带并发控制）"""
    # 检查是否已使用
    existing = db.query(models.UserInvitationUsage).filter(
        models.UserInvitationUsage.user_id == user_id,
        models.UserInvitationUsage.invitation_code_id == invitation_code_id
    ).first()
    
    if existing:
        return False, "该邀请码已被使用"
    
    # 使用 SELECT FOR UPDATE 锁定邀请码记录，防止并发超额使用
    invitation_code = db.query(models.InvitationCode).filter(
        models.InvitationCode.id == invitation_code_id
    ).with_for_update().first()
    
    if not invitation_code:
        return False, "邀请码不存在"
    
    # 再次检查邀请码有效性（在锁内检查）
    if not invitation_code.is_active:
        return False, "邀请码已禁用"
    
    now = get_utc_time()
    if now < invitation_code.valid_from or now > invitation_code.valid_until:
        return False, "邀请码已过期"
    
    # 检查使用次数限制（在锁内检查，安全）
    if invitation_code.max_uses:
        used_count = db.query(models.UserInvitationUsage).filter(
            models.UserInvitationUsage.invitation_code_id == invitation_code_id,
            models.UserInvitationUsage.reward_received == True
        ).count()
        if used_count >= invitation_code.max_uses:
            return False, "邀请码使用次数已达上限"
    
    # 创建使用记录
    usage = models.UserInvitationUsage(
        user_id=user_id,
        invitation_code_id=invitation_code_id,
        reward_received=False
    )
    db.add(usage)
    
    # 发放奖励
    try:
        # 积分奖励（使用幂等键防止重复发放）
        if invitation_code.reward_type in ["points", "both"] and invitation_code.points_reward:
            account = get_or_create_points_account(db, user_id)
            # 生成幂等键：用户ID + 邀请码ID，确保每个用户每个邀请码只能获得一次奖励
            invite_idempotency_key = f"invite_{user_id}_{invitation_code_id}"
            add_points_transaction(
                db,
                user_id,
                type="earn",
                amount=invitation_code.points_reward,
                source="invite_bonus",
                related_id=invitation_code_id,
                related_type="invitation_code",
                description=f"使用邀请码 {invitation_code.code} 获得积分奖励",
                idempotency_key=invite_idempotency_key
            )
            usage.points_received = invitation_code.points_reward
        
        # 优惠券奖励
        if invitation_code.reward_type in ["coupon", "both"] and invitation_code.coupon_id:
            _uc, _err = claim_coupon(db, user_id, invitation_code.coupon_id)
            if _uc:
                usage.coupon_received_id = invitation_code.coupon_id
            elif _err:
                logger.warning("Invitation coupon claim failed for user %s: %s", user_id, _err)
        
        usage.reward_received = True
        db.commit()
        return True, None
    
    except Exception as e:
        db.rollback()
        return False, f"发放奖励失败：{str(e)}"


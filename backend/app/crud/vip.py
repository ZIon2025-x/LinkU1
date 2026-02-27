"""VIP 订阅与会员等级相关 CRUD，独立模块便于维护与测试。"""

import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.crud.notification import create_notification
from app.crud.system import get_system_settings_dict
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_and_upgrade_vip_to_super(db: Session, user_id: str):
    """检查 VIP 用户是否满足晋升为超级 VIP 的条件，如果满足则自动晋升。"""
    from app.models import Task, User

    # 获取用户信息
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.user_level != "vip":
        return False

    # 获取系统设置
    settings = get_system_settings_dict(db)

    # 检查是否启用自动晋升
    if not settings.get("vip_to_super_enabled", True):
        return False

    # 获取晋升条件阈值
    task_count_threshold = int(settings.get("vip_to_super_task_count_threshold", 50))
    rating_threshold = float(settings.get("vip_to_super_rating_threshold", 4.5))
    completion_rate_threshold = float(
        settings.get("vip_to_super_completion_rate_threshold", 0.8)
    )

    # 计算用户的任务统计
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()
    accepted_tasks = db.query(Task).filter(Task.taker_id == user_id).count()
    total_task_count = posted_tasks + accepted_tasks

    completed_tasks = (
        db.query(Task)
        .filter(Task.taker_id == user_id, Task.status == "completed")
        .count()
    )
    completion_rate = completed_tasks / accepted_tasks if accepted_tasks > 0 else 0

    # 获取用户平均评分（若没有则为 0）
    user_rating = getattr(user, "avg_rating", 0) or 0

    # 检查是否满足所有晋升条件
    if (
        total_task_count >= task_count_threshold
        and user_rating >= rating_threshold
        and completion_rate >= completion_rate_threshold
    ):
        # 晋升为超级VIP
        user.user_level = "super"
        db.commit()
        db.refresh(user)

        # 创建晋升通知
        try:
            create_notification(
                db=db,
                user_id=user_id,
                type="vip_upgrade",
                title="恭喜晋升为超级VIP！",
                content="您已成功晋升为超级VIP会员！感谢您的优秀表现。",
                related_id="system",
            )
        except Exception as e:
            logger.warning(f"Failed to create upgrade notification: {e}")

        return True

    return False


def get_vip_subscription_by_transaction_id(db: Session, transaction_id: str):
    """根据交易ID获取VIP订阅记录"""
    return (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.transaction_id == transaction_id)
        .first()
    )


def get_active_vip_subscription(db: Session, user_id: str):
    """获取用户的有效VIP订阅"""
    return (
        db.query(models.VIPSubscription)
        .filter(
            models.VIPSubscription.user_id == user_id,
            models.VIPSubscription.status == "active",
        )
        .order_by(models.VIPSubscription.expires_date.desc().nullsfirst())
        .first()
    )


def get_vip_subscription_history(
    db: Session,
    user_id: str,
    limit: int = 50,
    offset: int = 0,
):
    """获取用户VIP订阅历史（按购买时间倒序）"""
    return (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.user_id == user_id)
        .order_by(models.VIPSubscription.purchase_date.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


def count_vip_subscriptions_by_user(db: Session, user_id: str) -> int:
    """获取用户VIP订阅总数"""
    return (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.user_id == user_id)
        .count()
    )


def get_all_vip_subscriptions(
    db: Session,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
):
    """管理员：获取VIP订阅列表（支持筛选、分页）"""
    q = db.query(models.VIPSubscription)
    if user_id:
        q = q.filter(models.VIPSubscription.user_id == user_id)
    if status:
        q = q.filter(models.VIPSubscription.status == status)
    q = q.order_by(models.VIPSubscription.purchase_date.desc())
    total = q.count()
    rows = q.offset(offset).limit(limit).all()
    return rows, total


def create_vip_subscription(
    db: Session,
    user_id: str,
    product_id: str,
    transaction_id: str,
    original_transaction_id: Optional[str],
    transaction_jws: str,
    purchase_date: datetime,
    expires_date: Optional[datetime],
    is_trial_period: bool,
    is_in_intro_offer_period: bool,
    environment: str,
    status: str = "active",
) -> models.VIPSubscription:
    """创建VIP订阅记录"""
    subscription = models.VIPSubscription(
        user_id=user_id,
        product_id=product_id,
        transaction_id=transaction_id,
        original_transaction_id=original_transaction_id,
        transaction_jws=transaction_jws,
        purchase_date=purchase_date,
        expires_date=expires_date,
        is_trial_period=is_trial_period,
        is_in_intro_offer_period=is_in_intro_offer_period,
        environment=environment,
        status=status,
    )
    db.add(subscription)
    db.commit()
    db.refresh(subscription)
    return subscription


def update_vip_subscription_status(
    db: Session,
    subscription_id: int,
    status: str,
    cancellation_reason: Optional[str] = None,
    refunded_at: Optional[datetime] = None,
):
    """更新VIP订阅状态"""
    subscription = (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.id == subscription_id)
        .first()
    )

    if subscription:
        subscription.status = status
        if cancellation_reason:
            subscription.cancellation_reason = cancellation_reason
        if refunded_at:
            subscription.refunded_at = refunded_at
        subscription.updated_at = get_utc_time()
        db.commit()
        db.refresh(subscription)
        return subscription
    return None


def mark_replaced_by_upgrade(
    db: Session,
    user_id: str,
    original_transaction_id: str,
    keep_transaction_id: str,
) -> int:
    """
    将同一订阅线（相同 original_transaction_id）下、除当前交易外的其他
    active 订阅标记为 replaced（因升级/换购被替换）。
    用于：用户先月订再年订时，月订记录不再保持 active，与 Apple 状态一致。
    Returns: 被标记为 replaced 的记录数。
    """
    if not original_transaction_id or not keep_transaction_id:
        return 0
    q = (
        db.query(models.VIPSubscription)
        .filter(
            models.VIPSubscription.user_id == user_id,
            models.VIPSubscription.status == "active",
            models.VIPSubscription.original_transaction_id == original_transaction_id,
            models.VIPSubscription.transaction_id != keep_transaction_id,
        )
    )
    count = q.update(
        {
            models.VIPSubscription.status: "replaced",
            models.VIPSubscription.cancellation_reason: "upgraded",
            models.VIPSubscription.updated_at: get_utc_time(),
        },
        synchronize_session="fetch",
    )
    if count:
        db.commit()
        logger.info(
            "VIP 升级替换: user_id=%s original_transaction_id=%s 已标记 %d 条旧订阅为 replaced",
            user_id,
            original_transaction_id,
            count,
        )
    return count


def update_user_vip_status(db: Session, user_id: str, user_level: str):
    """更新用户VIP状态"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.user_level = user_level
        db.commit()
        db.refresh(user)
        return user
    return None


def check_and_update_expired_subscriptions(db: Session):
    """检查并更新过期的订阅（批量更新）

    包括以下情况：
    1. 状态为 "active" 但已过期的订阅
    2. 状态为 "cancelled" 但已过期的订阅（取消订阅后等到到期才降级）
    """
    from datetime import datetime as dt, timezone

    now = dt.now(timezone.utc)
    utc_now = get_utc_time()

    # 检查所有已过期但尚未标记为 "expired" 的订阅（含 active/cancelled）
    expired = (
        db.query(models.VIPSubscription)
        .filter(
            models.VIPSubscription.status.in_(["active", "cancelled"]),
            models.VIPSubscription.expires_date.isnot(None),
            models.VIPSubscription.expires_date < now,
        )
        .all()
    )

    if not expired:
        return 0

    ids = [s.id for s in expired]
    user_ids = list({s.user_id for s in expired})

    # 将所有过期的订阅更新为 "expired" 状态
    (
        db.query(models.VIPSubscription)
        .filter(models.VIPSubscription.id.in_(ids))
        .update(
            {
                models.VIPSubscription.status: "expired",
                models.VIPSubscription.updated_at: utc_now,
            },
            synchronize_session="fetch",
        )
    )

    # 检查每个用户是否还有其他有效订阅，如果没有则降级
    for uid in user_ids:
        active = get_active_vip_subscription(db, uid)
        if not active:
            update_user_vip_status(db, uid, "normal")
            try:
                from app.redis_cache import invalidate_vip_status

                invalidate_vip_status(uid)
            except Exception:
                pass

    db.commit()
    logger.info("更新了 %d 个过期订阅", len(expired))
    return len(expired)


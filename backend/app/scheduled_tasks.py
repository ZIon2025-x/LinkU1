"""
定时任务
"""
import logging
from datetime import datetime, timedelta, timezone as tz
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app import models
from app.database import SessionLocal
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_expired_coupons(db: Session):
    """检查并更新过期优惠券"""
    now = get_utc_time()
    
    # 更新优惠券状态
    expired_coupons = db.query(models.Coupon).filter(
        and_(
            models.Coupon.valid_until < now,
            models.Coupon.status == "active"
        )
    ).all()
    
    for coupon in expired_coupons:
        coupon.status = "expired"
        logger.info(f"优惠券 {coupon.id} ({coupon.code}) 已过期")
    
    # 更新用户优惠券状态
    expired_user_coupons = db.query(models.UserCoupon).filter(
        and_(
            models.UserCoupon.status == "unused",
            models.UserCoupon.coupon_id.in_(
                db.query(models.Coupon.id).filter(
                    models.Coupon.valid_until < now
                )
            )
        )
    ).all()
    
    for user_coupon in expired_user_coupons:
        user_coupon.status = "expired"
        logger.info(f"用户优惠券 {user_coupon.id} 已过期")
    
    db.commit()
    
    logger.info(f"已处理 {len(expired_coupons)} 个过期优惠券和 {len(expired_user_coupons)} 个过期用户优惠券")


def check_expired_invitation_codes(db: Session):
    """检查并更新过期邀请码"""
    now = get_utc_time()
    
    expired_codes = db.query(models.InvitationCode).filter(
        and_(
            models.InvitationCode.valid_until < now,
            models.InvitationCode.is_active == True
        )
    ).all()
    
    for code in expired_codes:
        code.is_active = False
        logger.info(f"邀请码 {code.id} ({code.code}) 已过期")
    
    db.commit()
    
    logger.info(f"已处理 {len(expired_codes)} 个过期邀请码")


def check_expired_points(db: Session):
    """检查并处理过期积分（如果启用）"""
    from app.crud import get_system_setting
    
    expire_days_setting = get_system_setting(db, "points_expire_days")
    expire_days = int(expire_days_setting.setting_value) if expire_days_setting else 0
    
    if expire_days <= 0:
        return  # 永不过期，不处理
    
    # 查找过期的积分交易
    expire_date = get_utc_time() - timedelta(days=expire_days)
    
    expired_transactions = db.query(models.PointsTransaction).filter(
        and_(
            models.PointsTransaction.type == "earn",
            models.PointsTransaction.expires_at.isnot(None),
            models.PointsTransaction.expires_at < get_utc_time(),
            models.PointsTransaction.expired == False
        )
    ).all()
    
    for transaction in expired_transactions:
        # 扣除过期积分
        points_account = db.query(models.PointsAccount).filter(
            models.PointsAccount.user_id == transaction.user_id
        ).first()
        
        if points_account and points_account.balance >= transaction.amount:
            points_account.balance -= transaction.amount
            transaction.expired = True
            
            # 创建过期记录
            expire_transaction = models.PointsTransaction(
                user_id=transaction.user_id,
                type="expire",
                amount=transaction.amount,
                balance_after=points_account.balance,
                source="points_expire",
                description=f"积分过期（原始交易ID: {transaction.id}）",
                batch_id=transaction.batch_id,
                related_type="points_transaction",
                related_id=transaction.id
            )
            db.add(expire_transaction)
            logger.info(f"用户 {transaction.user_id} 的 {transaction.amount} 积分已过期")
    
    db.commit()
    
    logger.info(f"已处理 {len(expired_transactions)} 个过期积分交易")


def run_scheduled_tasks():
    """运行所有定时任务"""
    db = SessionLocal()
    try:
        logger.info("开始执行定时任务...")
        
        check_expired_coupons(db)
        check_expired_invitation_codes(db)
        check_expired_points(db)
        
        # 客服系统定时任务（每5分钟执行一次）
        try:
            from app.customer_service_tasks import (
                process_customer_service_queue,
                auto_end_timeout_chats,
                send_timeout_warnings,
                cleanup_long_inactive_chats
            )
            # 处理客服排队
            queue_result = process_customer_service_queue(db)
            logger.info(f"客服排队处理: {queue_result}")
            
            # 自动结束超时对话
            timeout_result = auto_end_timeout_chats(db, timeout_minutes=2)
            logger.info(f"超时对话处理: {timeout_result}")
            
            # 发送超时预警
            warning_result = send_timeout_warnings(db, warning_minutes=1)
            logger.info(f"超时预警: {warning_result}")
            
            # 清理长期无活动对话（每天执行一次，在定时任务中每天第一次运行时执行）
            # 每天凌晨2点执行清理（简化：每小时检查一次，如果是2点则执行）
            current_hour = get_utc_time().hour
            if current_hour == 2:
                cleanup_result = cleanup_long_inactive_chats(db, inactive_days=30)
                logger.info(f"清理长期无活动对话: {cleanup_result}")
        except Exception as e:
            logger.error(f"客服系统定时任务执行失败: {e}", exc_info=True)
        
        logger.info("定时任务执行完成")
    except Exception as e:
        logger.error(f"定时任务执行失败: {e}", exc_info=True)
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    # 可以直接运行此脚本执行定时任务
    run_scheduled_tasks()


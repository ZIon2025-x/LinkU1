"""设备令牌清理相关 CRUD，独立模块便于维护与测试。"""
import logging
from datetime import timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def cleanup_duplicate_device_tokens(db: Session) -> int:
    """清理同一 device_id 下的重复活跃令牌，保留最新的一个
    
    当 iOS 设备令牌刷新时，若注册逻辑未及时执行，可能留下同一设备的多个活跃令牌。
    此函数用于批量清理这类重复记录。
    
    Args:
        db: 数据库会话
        
    Returns:
        禁用的令牌数量
    """
    # 查找 (user_id, device_id) 组合中存在多个活跃令牌的情况
    dup_pairs = (
        db.query(models.DeviceToken.user_id, models.DeviceToken.device_id)
        .filter(
            models.DeviceToken.is_active == True,
            models.DeviceToken.device_id.isnot(None),
            models.DeviceToken.device_id != ""
        )
        .group_by(models.DeviceToken.user_id, models.DeviceToken.device_id)
        .having(func.count(models.DeviceToken.id) > 1)
        .all()
    )
    
    deactivated = 0
    for user_id, device_id in dup_pairs:
        # 按 updated_at 降序，保留最新的一条，禁用其余
        tokens = (
            db.query(models.DeviceToken)
            .filter(
                models.DeviceToken.user_id == user_id,
                models.DeviceToken.device_id == device_id,
                models.DeviceToken.is_active == True,
            )
            .order_by(models.DeviceToken.updated_at.desc())
            .all()
        )
        for t in tokens[1:]:
            t.is_active = False
            t.updated_at = get_utc_time()
            deactivated += 1
    
    if deactivated > 0:
        db.commit()
        logger.info(f"cleanup_duplicate_device_tokens: 禁用了 {deactivated} 个重复设备令牌")
    return deactivated


def delete_old_inactive_device_tokens(db: Session, inactive_days: int = 180) -> int:
    """删除长期不活跃的 is_active=False 令牌记录，释放数据库空间
    
    这些令牌已被 APNs 标记为无效，推送服务已将 is_active 设为 False。
    长期保留无意义，可安全删除。
    
    Args:
        db: 数据库会话
        inactive_days: 不活跃天数阈值，默认 180 天
        
    Returns:
        删除的令牌数量
    """
    cutoff = get_utc_time() - timedelta(days=inactive_days)
    deleted = (
        db.query(models.DeviceToken)
        .filter(
            models.DeviceToken.is_active == False,
            models.DeviceToken.updated_at < cutoff,
        )
        .delete()
    )
    if deleted > 0:
        db.commit()
        logger.info(f"delete_old_inactive_device_tokens: 删除了 {deleted} 个长期不活跃的令牌记录")
    return deleted


def cleanup_inactive_device_tokens(db: Session, inactive_days: int = 90) -> int:
    """清理无效的设备推送token（仅清理APNs返回无效的token）
    
    注意：此函数不再清理长时间未使用的token，因为：
    - 只要用户未登出，即使长时间未打开app，也应该能收到推送
    - 推送通知的目的就是让用户即使不打开app也能收到重要通知
    
    策略：
    - 只清理 is_active=False 的token（这些token已经被APNs标记为无效）
    - 不清理长时间未使用的token，因为用户可能只是没打开app但仍在登录状态
    
    Args:
        db: 数据库会话
        inactive_days: 此参数已废弃，保留仅为兼容性
        
    Returns:
        清理的token数量（当前返回0，因为不再清理长时间未使用的token）
    """
    # 不再清理长时间未使用的token
    # 只要用户未登出，就应该能收到推送，无论多久没打开app
    # 只有APNs返回token无效时，推送服务会自动标记 is_active=False
    logger.info("cleanup_inactive_device_tokens: 已禁用长时间未使用token的清理（用户未登出时应能收到推送）")
    return 0

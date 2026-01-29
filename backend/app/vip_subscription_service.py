"""
VIP订阅服务
处理订阅状态检查、续费、退款等
"""
import logging
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session

from app import crud, models
from app.iap_verification_service import iap_verification_service
from app.redis_cache import (
    redis_cache,
    get_cache_key,
    CACHE_PREFIXES,
    DEFAULT_TTL,
    invalidate_vip_status,
)

logger = logging.getLogger(__name__)


class VIPSubscriptionService:
    """VIP订阅服务类"""
    
    @staticmethod
    def check_subscription_status(db: Session, user_id: str) -> Optional[dict]:
        """
        检查用户的订阅状态
        
        Args:
            db: 数据库会话
            user_id: 用户ID
            
        Returns:
            订阅状态信息，如果没有有效订阅返回None
        """
        subscription = crud.get_active_vip_subscription(db, user_id)
        
        if not subscription:
            return None
        
        # 检查是否过期
        now = datetime.now(timezone.utc)
        is_expired = False
        
        if subscription.expires_date:
            is_expired = subscription.expires_date < now
        
        # 如果已过期，更新状态
        if is_expired and subscription.status == "active":
            crud.update_vip_subscription_status(db, subscription.id, "expired")
            subscription.status = "expired"
            
            # 检查是否有其他有效订阅
            active_subscription = crud.get_active_vip_subscription(db, user_id)
            if not active_subscription:
                crud.update_user_vip_status(db, user_id, "normal")
        
        return {
            "subscription_id": subscription.id,
            "product_id": subscription.product_id,
            "status": subscription.status,
            "purchase_date": subscription.purchase_date.isoformat() if subscription.purchase_date else None,
            "expires_date": subscription.expires_date.isoformat() if subscription.expires_date else None,
            "is_expired": is_expired,
            "auto_renew_status": subscription.auto_renew_status,
            "is_trial_period": subscription.is_trial_period,
            "is_in_intro_offer_period": subscription.is_in_intro_offer_period
        }

    @staticmethod
    def check_subscription_status_cached(db: Session, user_id: str) -> Optional[dict]:
        """检查用户订阅状态（带 Redis 缓存，TTL 60s）"""
        key = get_cache_key(CACHE_PREFIXES["VIP_STATUS"], user_id)
        try:
            cached = redis_cache.get(key)
            if cached is not None and isinstance(cached, dict):
                return cached
        except Exception as e:
            logger.debug("VIP status cache get: %s", e)
        result = VIPSubscriptionService.check_subscription_status(db, user_id)
        try:
            if result is not None:
                redis_cache.set(key, result, DEFAULT_TTL["VIP_STATUS"])
        except Exception as e:
            logger.debug("VIP status cache set: %s", e)
        return result

    @staticmethod
    def invalidate_vip_cache(user_id: str) -> None:
        """使指定用户的 VIP 状态缓存失效"""
        invalidate_vip_status(user_id)
    
    @staticmethod
    def process_subscription_renewal(
        db: Session,
        original_transaction_id: str,
        new_transaction_id: str,
        transaction_jws: str
    ) -> Optional[models.VIPSubscription]:
        """
        处理订阅续费
        
        Args:
            db: 数据库会话
            original_transaction_id: 原始交易ID
            new_transaction_id: 新交易ID
            transaction_jws: 新交易的JWS
            
        Returns:
            新创建的订阅记录，如果处理失败返回None
        """
        try:
            # 查找原始订阅
            original_subscription = db.query(models.VIPSubscription).filter(
                models.VIPSubscription.original_transaction_id == original_transaction_id
            ).order_by(models.VIPSubscription.purchase_date.desc()).first()
            
            if not original_subscription:
                logger.warning(f"未找到原始订阅: {original_transaction_id}")
                return None
            
            # 检查新交易是否已存在
            existing = crud.get_vip_subscription_by_transaction_id(db, new_transaction_id)
            if existing:
                logger.info(f"续费交易已存在: {new_transaction_id}")
                return existing
            
            # 验证新交易
            transaction_info = iap_verification_service.verify_transaction_jws(transaction_jws)
            
            # 转换时间戳
            purchase_date = iap_verification_service.convert_timestamp_to_datetime(
                transaction_info["purchase_date"]
            )
            expires_date = None
            if transaction_info["expires_date"]:
                expires_date = iap_verification_service.convert_timestamp_to_datetime(
                    transaction_info["expires_date"]
                )
            
            # 创建新订阅记录
            subscription = crud.create_vip_subscription(
                db=db,
                user_id=original_subscription.user_id,
                product_id=transaction_info["product_id"],
                transaction_id=new_transaction_id,
                original_transaction_id=original_transaction_id,
                transaction_jws=transaction_jws,
                purchase_date=purchase_date,
                expires_date=expires_date,
                is_trial_period=transaction_info["is_trial_period"],
                is_in_intro_offer_period=transaction_info["is_in_intro_offer_period"],
                environment=transaction_info["environment"],
                status="active"
            )
            
            # 确保用户VIP状态保持
            user = db.query(models.User).filter(
                models.User.id == original_subscription.user_id
            ).first()
            if user and user.user_level != "vip" and user.user_level != "super":
                crud.update_user_vip_status(db, user.id, "vip")
            VIPSubscriptionService.invalidate_vip_cache(original_subscription.user_id)
            logger.info(
                f"订阅续费成功: 用户={original_subscription.user_id}, "
                f"原始交易={original_transaction_id}, 新交易={new_transaction_id}"
            )
            return subscription
        except Exception as e:
            logger.error(f"处理订阅续费失败: {str(e)}", exc_info=True)
            return None
    
    @staticmethod
    def process_refund(
        db: Session,
        transaction_id: str,
        refund_reason: Optional[str] = None
    ) -> bool:
        """
        处理退款
        
        Args:
            db: 数据库会话
            transaction_id: 交易ID
            refund_reason: 退款原因
            
        Returns:
            如果处理成功返回True
        """
        try:
            subscription = crud.get_vip_subscription_by_transaction_id(db, transaction_id)
            
            if not subscription:
                logger.warning(f"未找到订阅记录: {transaction_id}")
                return False
            
            # 更新订阅状态
            crud.update_vip_subscription_status(
                db,
                subscription.id,
                "refunded",
                cancellation_reason=refund_reason,
                refunded_at=datetime.now(timezone.utc)
            )
            
            # 检查用户是否还有其他有效订阅
            active_subscription = crud.get_active_vip_subscription(db, subscription.user_id)
            if not active_subscription:
                # 如果没有其他有效订阅，降级用户
                crud.update_user_vip_status(db, subscription.user_id, "normal")

            VIPSubscriptionService.invalidate_vip_cache(subscription.user_id)
            logger.info(
                f"退款处理成功: 用户={subscription.user_id}, "
                f"交易={transaction_id}, 原因={refund_reason}"
            )
            return True
        except Exception as e:
            logger.error(f"处理退款失败: {str(e)}", exc_info=True)
            return False
    
    @staticmethod
    def cancel_subscription(
        db: Session,
        transaction_id: str,
        cancellation_reason: Optional[str] = None
    ) -> bool:
        """
        取消订阅
        
        Args:
            db: 数据库会话
            transaction_id: 交易ID
            cancellation_reason: 取消原因
            
        Returns:
            如果处理成功返回True
        """
        try:
            subscription = crud.get_vip_subscription_by_transaction_id(db, transaction_id)
            
            if not subscription:
                logger.warning(f"未找到订阅记录: {transaction_id}")
                return False
            
            # 更新订阅状态
            crud.update_vip_subscription_status(
                db,
                subscription.id,
                "cancelled",
                cancellation_reason=cancellation_reason
            )
            
            # 注意：取消订阅不会立即降级用户，等到订阅到期后才降级
            subscription.auto_renew_status = False
            db.commit()
            VIPSubscriptionService.invalidate_vip_cache(subscription.user_id)
            logger.info(
                f"订阅取消成功: 用户={subscription.user_id}, "
                f"交易={transaction_id}, 原因={cancellation_reason}"
            )
            return True
        except Exception as e:
            logger.error(f"取消订阅失败: {str(e)}", exc_info=True)
            return False


# 创建全局实例
vip_subscription_service = VIPSubscriptionService()

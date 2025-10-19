"""
管理员邮箱验证码管理模块
"""

import secrets
import logging
import json
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models import AdminUser
from app.config import Config

logger = logging.getLogger(__name__)

# Redis配置
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
    logger.info(f"[ADMIN_VERIFICATION] Redis连接状态: {USE_REDIS}")
except Exception as e:
    logger.error(f"[ADMIN_VERIFICATION] Redis连接失败: {e}")
    USE_REDIS = False
    redis_client = None


class AdminVerificationManager:
    """管理员验证码管理器"""
    
    @staticmethod
    def generate_verification_code() -> str:
        """生成6位数字验证码"""
        return f"{secrets.randbelow(900000) + 100000:06d}"
    
    @staticmethod
    def create_verification_code(db: Session, admin_id: str) -> str:
        """为管理员创建验证码"""
        try:
            # 生成新验证码
            code = AdminVerificationManager.generate_verification_code()
            expires_in_seconds = Config.ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES * 60
            
            if USE_REDIS and redis_client:
                # 使用Redis存储验证码
                verification_data = {
                    "admin_id": admin_id,
                    "code": code,
                    "created_at": datetime.utcnow().isoformat(),
                    "is_used": False
                }
                
                # 存储到Redis，设置过期时间
                redis_key = f"admin_verification_code:{admin_id}"
                redis_client.setex(
                    redis_key,
                    expires_in_seconds,
                    json.dumps(verification_data)
                )
                
                logger.info(f"为管理员 {admin_id} 创建验证码并存储到Redis: {code[:2]}****")
            else:
                # Redis不可用时的备选方案（内存存储）
                logger.warning("Redis不可用，使用内存存储验证码")
                # 这里可以实现内存存储逻辑，但为了简单起见，我们直接返回验证码
                # 在实际生产环境中，建议确保Redis可用
                pass
            
            return code
            
        except Exception as e:
            logger.error(f"创建管理员验证码失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建验证码失败"
            )
    
    @staticmethod
    def verify_code(db: Session, admin_id: str, code: str) -> bool:
        """验证管理员验证码"""
        try:
            if USE_REDIS and redis_client:
                # 从Redis获取验证码
                redis_key = f"admin_verification_code:{admin_id}"
                verification_data_str = redis_client.get(redis_key)
                
                if not verification_data_str:
                    logger.warning(f"管理员 {admin_id} 验证码不存在或已过期")
                    return False
                
                try:
                    verification_data = json.loads(verification_data_str)
                except json.JSONDecodeError:
                    logger.error(f"管理员 {admin_id} 验证码数据格式错误")
                    return False
                
                # 检查验证码是否匹配
                if verification_data.get("code") != code:
                    logger.warning(f"管理员 {admin_id} 验证码不匹配")
                    return False
                
                # 检查是否已使用
                if verification_data.get("is_used", False):
                    logger.warning(f"管理员 {admin_id} 验证码已使用")
                    return False
                
                # 标记为已使用（删除Redis中的验证码）
                redis_client.delete(redis_key)
                
                logger.info(f"管理员 {admin_id} 验证码验证成功")
                return True
            else:
                # Redis不可用时的备选方案
                logger.warning("Redis不可用，无法验证验证码")
                return False
            
        except Exception as e:
            logger.error(f"验证管理员验证码失败: {e}")
            return False
    
    @staticmethod
    def cleanup_old_codes(db: Session, admin_id: str) -> None:
        """清理管理员的旧验证码（Redis会自动过期，这里主要用于清理可能存在的旧数据）"""
        try:
            if USE_REDIS and redis_client:
                # Redis会自动处理过期，这里可以清理可能存在的旧key
                redis_key = f"admin_verification_code:{admin_id}"
                redis_client.delete(redis_key)
                logger.info(f"清理管理员 {admin_id} 的旧验证码")
            else:
                logger.info("Redis不可用，跳过清理操作")
            
        except Exception as e:
            logger.error(f"清理管理员验证码失败: {e}")
    
    @staticmethod
    def get_admin_by_username(db: Session, username: str) -> Optional[AdminUser]:
        """根据用户名获取管理员"""
        return db.query(AdminUser).filter(AdminUser.username == username).first()
    
    @staticmethod
    def is_verification_enabled() -> bool:
        """检查是否启用了邮箱验证"""
        return Config.ENABLE_ADMIN_EMAIL_VERIFICATION and bool(Config.ADMIN_EMAIL)
    
    @staticmethod
    def get_admin_email() -> str:
        """获取管理员邮箱地址"""
        return Config.ADMIN_EMAIL

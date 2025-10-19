"""
管理员邮箱验证码管理模块
"""

import secrets
import logging
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models import AdminVerificationCode, AdminUser
from app.config import Config

logger = logging.getLogger(__name__)


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
            # 先清理该管理员的旧验证码
            AdminVerificationManager.cleanup_old_codes(db, admin_id)
            
            # 生成新验证码
            code = AdminVerificationManager.generate_verification_code()
            expires_at = datetime.utcnow() + timedelta(minutes=Config.ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES)
            
            # 创建验证码记录
            verification_code = AdminVerificationCode(
                admin_id=admin_id,
                code=code,
                expires_at=expires_at,
                is_used=0
            )
            
            db.add(verification_code)
            db.commit()
            db.refresh(verification_code)
            
            logger.info(f"为管理员 {admin_id} 创建验证码: {code[:2]}****")
            return code
            
        except Exception as e:
            logger.error(f"创建管理员验证码失败: {e}")
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建验证码失败"
            )
    
    @staticmethod
    def verify_code(db: Session, admin_id: str, code: str) -> bool:
        """验证管理员验证码"""
        try:
            # 查找有效的验证码
            verification_code = db.query(AdminVerificationCode).filter(
                AdminVerificationCode.admin_id == admin_id,
                AdminVerificationCode.code == code,
                AdminVerificationCode.is_used == 0,
                AdminVerificationCode.expires_at > datetime.utcnow()
            ).first()
            
            if not verification_code:
                logger.warning(f"管理员 {admin_id} 验证码验证失败: {code}")
                return False
            
            # 标记验证码为已使用
            verification_code.is_used = 1
            verification_code.used_at = datetime.utcnow()
            db.commit()
            
            logger.info(f"管理员 {admin_id} 验证码验证成功")
            return True
            
        except Exception as e:
            logger.error(f"验证管理员验证码失败: {e}")
            db.rollback()
            return False
    
    @staticmethod
    def cleanup_old_codes(db: Session, admin_id: str) -> None:
        """清理管理员的旧验证码"""
        try:
            # 删除已使用或过期的验证码
            db.query(AdminVerificationCode).filter(
                AdminVerificationCode.admin_id == admin_id,
                (AdminVerificationCode.is_used == 1) | 
                (AdminVerificationCode.expires_at < datetime.utcnow())
            ).delete()
            
            db.commit()
            logger.info(f"清理管理员 {admin_id} 的旧验证码")
            
        except Exception as e:
            logger.error(f"清理管理员验证码失败: {e}")
            db.rollback()
    
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

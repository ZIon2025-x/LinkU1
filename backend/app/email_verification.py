"""
邮箱验证系统
处理用户注册时的邮箱验证流程
"""

import secrets
import hashlib
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
import logging

from app import models, schemas
# 移除不存在的导入
from app.security import get_password_hash

logger = logging.getLogger(__name__)

# 验证令牌过期时间（24小时）
VERIFICATION_TOKEN_EXPIRE_HOURS = 24


class EmailVerificationManager:
    """邮箱验证管理器"""
    
    @staticmethod
    def generate_verification_token(email: str) -> str:
        """生成邮箱验证令牌 - 使用与旧系统兼容的方式"""
        from app.email_utils import generate_confirmation_token
        return generate_confirmation_token(email)
    
    @staticmethod
    def create_pending_user(
        db: Session, 
        user_data: schemas.UserCreate,
        verification_token: str
    ) -> models.PendingUser:
        """创建待验证用户"""
        # 检查是否已存在待验证用户
        existing_pending = db.query(models.PendingUser).filter(
            models.PendingUser.email == user_data.email
        ).first()
        
        if existing_pending:
            # 更新现有待验证用户
            existing_pending.name = user_data.name
            existing_pending.hashed_password = get_password_hash(user_data.password)
            existing_pending.phone = user_data.phone
            existing_pending.verification_token = verification_token
            existing_pending.created_at = datetime.utcnow()
            existing_pending.expires_at = datetime.utcnow() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS)
            db.commit()
            db.refresh(existing_pending)
            return existing_pending
        
        # 创建新的待验证用户
        pending_user = models.PendingUser(
            name=user_data.name,
            email=user_data.email,
            hashed_password=get_password_hash(user_data.password),
            phone=user_data.phone,
            verification_token=verification_token,
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS)
        )
        
        db.add(pending_user)
        db.commit()
        db.refresh(pending_user)
        
        logger.info(f"创建待验证用户: {user_data.email}")
        return pending_user
    
    @staticmethod
    def verify_user(db: Session, token: str) -> Optional[models.User]:
        """验证用户邮箱 - 使用与旧系统兼容的方式"""
        from app.email_utils import confirm_token
        from app import crud
        
        # 使用旧的token验证方式
        email = confirm_token(token)
        if not email:
            logger.warning(f"验证令牌无效或已过期: {token}")
            return None
        
        # 查找用户
        user = crud.get_user_by_email(db, email)
        if not user:
            logger.warning(f"用户不存在: {email}")
            return None
        
        # 更新用户验证状态
        user.is_verified = 1
        db.commit()
        db.refresh(user)
        
        logger.info(f"用户验证成功: {user.email}")
        return user
    
    @staticmethod
    def resend_verification_email(
        db: Session, 
        email: str,
        background_tasks
    ) -> bool:
        """重新发送验证邮件"""
        # 查找待验证用户
        pending_user = db.query(models.PendingUser).filter(
            models.PendingUser.email == email
        ).first()
        
        if not pending_user:
            return False
        
        # 生成新的验证令牌
        new_token = EmailVerificationManager.generate_verification_token(email)
        pending_user.verification_token = new_token
        pending_user.expires_at = datetime.utcnow() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS)
        
        db.commit()
        
        # 发送验证邮件
        send_verification_email(background_tasks, email, new_token)
        
        logger.info(f"重新发送验证邮件: {email}")
        return True
    
    @staticmethod
    def cleanup_expired_pending_users(db: Session) -> int:
        """清理过期的待验证用户"""
        expired_users = db.query(models.PendingUser).filter(
            models.PendingUser.expires_at < datetime.utcnow()
        ).all()
        
        count = len(expired_users)
        for user in expired_users:
            db.delete(user)
        
        db.commit()
        
        if count > 0:
            logger.info(f"清理了 {count} 个过期的待验证用户")
        
        return count
    
    @staticmethod
    def get_pending_user_by_email(db: Session, email: str) -> Optional[models.PendingUser]:
        """根据邮箱获取待验证用户"""
        return db.query(models.PendingUser).filter(
            models.PendingUser.email == email
        ).first()


def send_verification_email_with_token(
    background_tasks,
    email: str, 
    token: str
) -> None:
    """发送包含验证链接的邮件"""
    from app.config import Config
    
    # 构建验证链接 - 使用旧的confirm端点以确保兼容性
    verification_url = f"{Config.BASE_URL}/api/users/confirm/{token}"
    
    subject = "LinkU 邮箱验证"
    body = f"""
    <h2>欢迎注册 LinkU 平台！</h2>
    <p>请点击下面的链接验证您的邮箱地址：</p>
    <p><a href="{verification_url}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">验证邮箱</a></p>
    <p>或者复制以下链接到浏览器中打开：</p>
    <p>{verification_url}</p>
    <p><strong>注意：</strong>此链接24小时内有效，请及时验证。</p>
    <p>如果您没有注册 LinkU 账户，请忽略此邮件。</p>
    """
    
    from app.email_utils import send_email
    background_tasks.add_task(send_email, email, subject, body)

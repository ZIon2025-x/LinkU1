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
        from datetime import datetime as dt
        
        # 处理同意时间
        terms_agreed_at = None
        if user_data.terms_agreed_at:
            terms_agreed_at = dt.fromisoformat(user_data.terms_agreed_at.replace('Z', '+00:00'))
        
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
            existing_pending.agreed_to_terms = 1 if user_data.agreed_to_terms else 0
            existing_pending.terms_agreed_at = terms_agreed_at
            existing_pending.inviter_id = user_data.inviter_id if user_data.inviter_id else None
            db.commit()
            db.refresh(existing_pending)
            return existing_pending
        
        # 创建新的待验证用户
        inviter_id_value = user_data.inviter_id if user_data.inviter_id else None
        logger.info(f"创建待验证用户: email={user_data.email}, inviter_id={inviter_id_value}")
        
        pending_user = models.PendingUser(
            name=user_data.name,
            email=user_data.email,
            hashed_password=get_password_hash(user_data.password),
            phone=user_data.phone,
            verification_token=verification_token,
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS),
            agreed_to_terms=1 if user_data.agreed_to_terms else 0,
            terms_agreed_at=terms_agreed_at,
            inviter_id=inviter_id_value
        )
        
        db.add(pending_user)
        db.commit()
        db.refresh(pending_user)
        
        logger.info(f"创建待验证用户成功: email={user_data.email}, inviter_id={pending_user.inviter_id}")
        return pending_user
    
    @staticmethod
    def verify_user(db: Session, token: str) -> Optional[models.User]:
        """验证用户邮箱 - 支持多种token格式"""
        from app.email_utils import confirm_token
        from app import crud
        
        email = None
        
        # 首先尝试查找PendingUser表（优先处理新注册用户）
        try:
            pending_user = db.query(models.PendingUser).filter(
                models.PendingUser.verification_token == token
            ).first()
            
            if pending_user:
                # 检查令牌是否过期
                if pending_user.expires_at < datetime.utcnow():
                    logger.warning(f"验证令牌已过期: {token}")
                    # 删除过期的待验证用户
                    db.delete(pending_user)
                    db.commit()
                    return None
                
                email = pending_user.email
                logger.info(f"使用PendingUser格式token验证成功: {email}")
                
                # 检查邮箱是否已被注册
                existing_user = db.query(models.User).filter(
                    models.User.email == email
                ).first()
                
                if existing_user:
                    logger.warning(f"邮箱已被注册: {email}")
                    # 删除待验证用户
                    db.delete(pending_user)
                    db.commit()
                    return None
                
                # 生成唯一的8位数字用户ID
                import random
                while True:
                    user_id = str(random.randint(10000000, 99999999))
                    # 检查ID是否已存在
                    existing_user_by_id = db.query(models.User).filter(
                        models.User.id == user_id
                    ).first()
                    if not existing_user_by_id:
                        break
                
                # 创建正式用户
                user = models.User(
                    id=user_id,
                    name=pending_user.name,
                    email=pending_user.email,
                    hashed_password=pending_user.hashed_password,
                    phone=pending_user.phone,
                    is_verified=1,  # 已验证
                    is_active=1,    # 激活
                    user_level="normal",
                    created_at=datetime.utcnow(),
                    agreed_to_terms=pending_user.agreed_to_terms,
                    terms_agreed_at=pending_user.terms_agreed_at,
                    inviter_id=pending_user.inviter_id
                )
                
                db.add(user)
                
                # 删除待验证用户
                db.delete(pending_user)
                
                db.commit()
                db.refresh(user)
                
                logger.info(f"用户验证成功并创建: {user.email}, ID: {user.id}")
                return user
                
        except Exception as e:
            logger.error(f"PendingUser格式token验证失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
        
        # 如果PendingUser表中找不到，尝试旧的token验证方式（URLSafeTimedSerializer格式）
        if not email:
            try:
                email = confirm_token(token)
                if email:
                    logger.info(f"使用旧格式token验证成功: {email}")
            except Exception as e:
                logger.debug(f"旧格式token验证失败: {e}")
        
        # 如果旧格式失败，尝试SHA256格式token验证
        if not email:
            try:
                email = EmailVerificationManager._verify_sha256_token(db, token)
                if email:
                    logger.info(f"使用SHA256格式token验证成功: {email}")
            except Exception as e:
                logger.error(f"SHA256 token验证异常: {e}")
                import traceback
                logger.error(f"详细错误: {traceback.format_exc()}")
        
        if not email:
            logger.warning(f"验证令牌无效或已过期: {token}")
            return None
        
        # 对于旧格式的token，查找并更新现有用户（已在User表中的用户）
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
    def _verify_sha256_token(db: Session, token: str) -> Optional[str]:
        """验证SHA256格式的token"""
        try:
            # 检查token是否为64位十六进制字符串
            if len(token) != 64 or not all(c in '0123456789abcdef' for c in token):
                logger.debug(f"Token格式不正确: {len(token)}位，不是64位十六进制")
                return None
            
            # 尝试通过数据库查找匹配的token
            from app import crud
            
            # 查找所有未验证的用户
            users = db.query(models.User).filter(models.User.is_verified == 0).all()
            logger.info(f"找到 {len(users)} 个未验证用户")
            
            for user in users:
                logger.debug(f"检查用户: {user.email} (ID: {user.id})")
                
                # 尝试不同的token生成方式
                test_tokens = [
                    hashlib.sha256(user.email.encode()).hexdigest(),
                    hashlib.sha256(f"{user.email}:{user.created_at}".encode()).hexdigest(),
                    hashlib.sha256(f"{user.email}:{user.id}".encode()).hexdigest(),
                    hashlib.sha256(f"{user.id}:{user.email}".encode()).hexdigest(),
                ]
                
                for i, test_token in enumerate(test_tokens):
                    if test_token == token:
                        logger.info(f"SHA256 token匹配成功: {user.email} (方法{i+1})")
                        return user.email
                    else:
                        logger.debug(f"方法{i+1}不匹配: {test_token[:20]}...")
            
            logger.warning(f"没有找到匹配的SHA256 token: {token[:20]}...")
            return None
            
        except Exception as e:
            logger.error(f"SHA256 token验证异常: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return None
    
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
    
    # 构建验证链接 - 使用verify-email端点，会自动重定向到前端页面
    verification_url = f"{Config.BASE_URL}/api/users/verify-email/{token}"
    
    subject = "Link²Ur 邮箱验证"
    body = f"""
    <h2>欢迎注册 Link²Ur 平台！</h2>
    <p>请点击下面的链接验证您的邮箱地址：</p>
    <p><a href="{verification_url}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">验证邮箱</a></p>
    <p>或者复制以下链接到浏览器中打开：</p>
    <p>{verification_url}</p>
    <p><strong>注意：</strong>此链接24小时内有效，请及时验证。</p>
    <p>如果您没有注册 Link²Ur 账户，请忽略此邮件。</p>
    """
    
    from app.email_utils import send_email
    background_tasks.add_task(send_email, email, subject, body)

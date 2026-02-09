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
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# 验证令牌过期时间（24小时）
VERIFICATION_TOKEN_EXPIRE_HOURS = 24


class EmailVerificationManager:
    """邮箱验证管理器"""
    
    @staticmethod
    def generate_verification_token(email: str) -> str:
        """生成邮箱验证令牌 - 使用与旧系统兼容的方式"""
        from app.email_utils import generate_confirmation_token
        token = generate_confirmation_token(email)
        
        # 将token存储到Redis，设置24小时过期，确保一次性使用
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            try:
                # 存储token到Redis，值为邮箱，过期时间24小时（86400秒）
                redis_client.setex(
                    f"email_verification_token:{token}",
                    86400,  # 24小时 = 86400秒
                    email
                )
            except Exception as e:
                logger.warning(f"存储邮箱验证token到Redis失败: {e}")
                # Redis失败时仍然返回token，但验证时会失败（需要Redis可用）
        else:
            logger.warning("Redis不可用，无法存储邮箱验证token")
        
        return token
    
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
            # 处理邀请码或用户ID（如果提供）
            invitation_code_id = None
            invitation_code_text = None
            inviter_id = None
            invitation_code = getattr(user_data, 'invitation_code', None)
            if invitation_code and invitation_code.strip():
                from app.coupon_points_crud import process_invitation_input
                inviter_id, invitation_code_id, invitation_code_text, error_msg = process_invitation_input(
                    db, invitation_code.strip()
                )
                if inviter_id:
                    logger.info(f"邀请人ID验证成功: {inviter_id}")
                elif invitation_code_id:
                    logger.info(f"邀请码验证成功: {invitation_code_text}, ID: {invitation_code_id}")
                elif error_msg:
                    logger.warning(f"邀请码/用户ID验证失败: {error_msg}")
                    # 邀请码/用户ID无效不影响注册，只记录警告
            
            # 更新现有待验证用户
            existing_pending.name = user_data.name
            existing_pending.hashed_password = get_password_hash(user_data.password)
            existing_pending.phone = user_data.phone
            existing_pending.verification_token = verification_token
            existing_pending.created_at = get_utc_time()
            existing_pending.expires_at = get_utc_time() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS)
            existing_pending.agreed_to_terms = 1 if user_data.agreed_to_terms else 0
            existing_pending.terms_agreed_at = terms_agreed_at
            existing_pending.inviter_id = inviter_id
            existing_pending.invitation_code_id = invitation_code_id
            existing_pending.invitation_code_text = invitation_code_text
            db.commit()
            db.refresh(existing_pending)
            return existing_pending
        
        # 处理邀请码或用户ID（如果提供）
        invitation_code_id = None
        invitation_code_text = None
        inviter_id = None
        invitation_code = getattr(user_data, 'invitation_code', None)
        logger.debug("创建待验证用户 - 原始邀请码输入: %s, 类型: %s", invitation_code, type(invitation_code))
        if invitation_code and invitation_code.strip():
            from app.coupon_points_crud import process_invitation_input
            cleaned_code = invitation_code.strip()
            logger.debug("处理邀请码输入: '%s'", cleaned_code)
            inviter_id, invitation_code_id, invitation_code_text, error_msg = process_invitation_input(
                db, cleaned_code
            )
            logger.debug("处理结果 - inviter_id: %s, invitation_code_id: %s, invitation_code_text: %s, error_msg: %s", inviter_id, invitation_code_id, invitation_code_text, error_msg)
            if inviter_id:
                logger.info(f"邀请人ID验证成功: {inviter_id}")
            elif invitation_code_id:
                logger.info(f"邀请码验证成功: {invitation_code_text}, ID: {invitation_code_id}")
            elif error_msg:
                logger.warning(f"邀请码/用户ID验证失败: {error_msg}")
                # 邀请码/用户ID无效不影响注册，只记录警告
        else:
            logger.debug("未提供邀请码或邀请码为空")
        
        # 创建新的待验证用户
        logger.info(f"创建待验证用户: email={user_data.email}, inviter_id={inviter_id}, invitation_code_id={invitation_code_id}, invitation_code_text={invitation_code_text}")
        
        pending_user = models.PendingUser(
            name=user_data.name,
            email=user_data.email,
            hashed_password=get_password_hash(user_data.password),
            phone=user_data.phone,
            verification_token=verification_token,
            created_at=get_utc_time(),
            expires_at=get_utc_time() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS),
            agreed_to_terms=1 if user_data.agreed_to_terms else 0,
            terms_agreed_at=terms_agreed_at,
            inviter_id=inviter_id,
            invitation_code_id=invitation_code_id,
            invitation_code_text=invitation_code_text
        )
        
        db.add(pending_user)
        db.commit()
        db.refresh(pending_user)
        
        logger.info(f"创建待验证用户成功: email={user_data.email}, inviter_id={pending_user.inviter_id}, invitation_code_id={pending_user.invitation_code_id}, invitation_code_text={pending_user.invitation_code_text}")
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
                if pending_user.expires_at < get_utc_time():
                    logger.warning(f"验证令牌已过期: {token}")
                    # 删除过期的待验证用户
                    db.delete(pending_user)
                    db.commit()
                    return None
                
                email = pending_user.email
                logger.info(f"使用PendingUser格式token验证成功: {email}")
                
                # 从Redis获取并删除token（原子操作，确保一次性使用）
                from app.redis_cache import get_redis_client
                redis_client = get_redis_client()
                
                if redis_client:
                    token_key = f"email_verification_token:{token}"
                    
                    # 使用GETDEL原子操作（Redis 6.2+），如果Redis版本不支持则使用Lua脚本
                    try:
                        # 尝试使用GETDEL（原子操作：获取并删除）
                        stored_email = redis_client.getdel(token_key)
                    except AttributeError:
                        # Redis版本不支持GETDEL，使用Lua脚本实现原子操作
                        lua_script = """
                        local value = redis.call('GET', KEYS[1])
                        if value then
                            redis.call('DEL', KEYS[1])
                        end
                        return value
                        """
                        stored_email = redis_client.eval(lua_script, 1, token_key)
                    except Exception as e:
                        logger.error(f"从Redis获取验证token失败: {e}")
                        stored_email = None
                    
                    # 如果Redis中有token记录，验证是否匹配
                    if stored_email:
                        stored_email_str = stored_email.decode('utf-8') if isinstance(stored_email, bytes) else stored_email
                        if stored_email_str != email:
                            logger.warning(f"Token邮箱不匹配: Redis中={stored_email_str}, PendingUser中={email}")
                            return None
                        # Token已从Redis删除，确保一次性使用
                        logger.info(f"Token已从Redis删除，确保一次性使用: {email}")
                    else:
                        # Redis中没有token记录，可能是旧token或已使用
                        logger.warning(f"Redis中没有token记录，可能已被使用: {email}")
                        # 仍然允许验证（向后兼容），但记录警告
                
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
                    created_at=get_utc_time(),
                    agreed_to_terms=pending_user.agreed_to_terms,
                    terms_agreed_at=pending_user.terms_agreed_at,
                    inviter_id=pending_user.inviter_id,
                    invitation_code_id=pending_user.invitation_code_id,
                    invitation_code_text=pending_user.invitation_code_text
                )
                
                db.add(user)
                
                # 删除待验证用户
                db.delete(pending_user)
                
                db.commit()
                db.refresh(user)
                
                logger.info(f"用户验证成功并创建: {user.email}, ID: {user.id}, inviter_id={user.inviter_id}, invitation_code_id={user.invitation_code_id}, invitation_code_text={user.invitation_code_text}")
                
                # 处理邀请码奖励（如果注册时提供了邀请码）
                if pending_user.invitation_code_id:
                    from app.coupon_points_crud import use_invitation_code
                    success, error_msg = use_invitation_code(db, user.id, pending_user.invitation_code_id)
                    if success:
                        logger.info(f"邀请码奖励发放成功: 用户 {user.id}, 邀请码ID {pending_user.invitation_code_id}")
                    else:
                        logger.warning(f"邀请码奖励发放失败: {error_msg}")
                
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
        
        # 对于旧格式的token，从Redis获取并删除token（原子操作，确保一次性使用）
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            token_key = f"email_verification_token:{token}"
            
            # 使用GETDEL原子操作（Redis 6.2+），如果Redis版本不支持则使用Lua脚本
            try:
                # 尝试使用GETDEL（原子操作：获取并删除）
                stored_email = redis_client.getdel(token_key)
            except AttributeError:
                # Redis版本不支持GETDEL，使用Lua脚本实现原子操作
                lua_script = """
                local value = redis.call('GET', KEYS[1])
                if value then
                    redis.call('DEL', KEYS[1])
                end
                return value
                """
                stored_email = redis_client.eval(lua_script, 1, token_key)
            except Exception as e:
                logger.error(f"从Redis获取验证token失败: {e}")
                # Redis操作失败，但token格式有效，允许验证（向后兼容）
                stored_email = None
            
            # 如果Redis中有token记录，验证是否匹配
            if stored_email:
                stored_email_str = stored_email.decode('utf-8') if isinstance(stored_email, bytes) else stored_email
                if stored_email_str != email:
                    logger.warning(f"Token邮箱不匹配: Redis中={stored_email_str}, Token中={email}")
                    return None
                # Token已从Redis删除，确保一次性使用
                logger.info(f"Token已从Redis删除，确保一次性使用: {email}")
            else:
                # Redis中没有token记录，可能是旧token或已使用
                # 检查用户是否已经验证过
                user = crud.get_user_by_email(db, email)
                if user and user.is_verified == 1:
                    logger.warning(f"用户已验证，token可能已被使用: {email}")
                    return None
                # 检查PendingUser表中是否有相同token但不同邮箱的记录（防止token被重复使用）
                other_pending = db.query(models.PendingUser).filter(
                    models.PendingUser.verification_token == token,
                    models.PendingUser.email != email
                ).first()
                if other_pending:
                    logger.warning(f"Token已被其他用户使用: {email}")
                    return None
                # 如果用户未验证且没有其他pending用户使用相同token，允许验证（向后兼容）
                logger.info(f"Redis中没有token记录，但允许验证（向后兼容）: {email}")
        else:
            # Redis不可用，检查用户是否已经验证过
            user = crud.get_user_by_email(db, email)
            if user and user.is_verified == 1:
                logger.warning(f"用户已验证，Redis不可用无法验证token: {email}")
                return None
            logger.warning("Redis不可用，无法验证token是否已使用")
        
        # 查找并更新现有用户（已在User表中的用户）
        user = crud.get_user_by_email(db, email)
        if not user:
            logger.warning(f"用户不存在: {email}")
            return None
        
        # 检查用户是否已经验证过
        if user.is_verified == 1:
            logger.warning(f"用户已验证: {email}")
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
        pending_user.expires_at = get_utc_time() + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS)
        
        db.commit()
        
        # 发送验证邮件（传递数据库会话，user_id为None因为这是待验证用户）
        send_verification_email_with_token(background_tasks, email, new_token, language='en', db=db, user_id=None)
        
        logger.info(f"重新发送验证邮件: {email}")
        return True
    
    @staticmethod
    def cleanup_expired_pending_users(db: Session) -> int:
        """清理过期的待验证用户"""
        expired_users = db.query(models.PendingUser).filter(
            models.PendingUser.expires_at < get_utc_time()
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
    token: str,
    language: str = 'en',  # 默认英文，可以从用户偏好获取
    db: Session = None,
    user_id: str = None
) -> None:
    """发送包含验证链接的邮件"""
    from app.config import Config
    from app.email_templates import get_email_verification_email
    from app.email_utils import send_email, is_temp_email, notify_user_to_update_email
    
    # 检查是否为临时邮箱
    if is_temp_email(email):
        # 如果提供了数据库会话和用户ID，创建通知提醒用户更新邮箱
        if db and user_id:
            try:
                notify_user_to_update_email(db, user_id, language)
                logger.info(f"检测到用户使用临时邮箱，已创建邮箱更新提醒通知: user_id={user_id}")
            except Exception as e:
                logger.error(f"创建邮箱更新提醒通知失败: {e}")
        # 临时邮箱无法接收邮件，直接返回
        logger.warning(f"尝试发送验证邮件到临时邮箱: {email}")
        return
    
    # 构建验证链接 - 使用verify-email端点，会自动重定向到前端页面
    verification_url = f"{Config.BASE_URL}/api/users/verify-email/{token}"
    
    subject, body = get_email_verification_email(language, verification_url)
    
    background_tasks.add_task(send_email, email, subject, body, db, user_id)

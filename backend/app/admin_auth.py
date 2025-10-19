"""
管理员独立认证系统
实现管理员专用的会话管理和认证
"""

import os
import json
import secrets
import hashlib
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from dataclasses import dataclass
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging

logger = logging.getLogger(__name__)

# 配置
from app.config import get_settings
settings = get_settings()

ADMIN_SESSION_EXPIRE_HOURS = int(os.getenv("ADMIN_SESSION_EXPIRE_HOURS", "8"))  # 管理员会话8小时
ADMIN_MAX_ACTIVE_SESSIONS = int(os.getenv("ADMIN_MAX_ACTIVE_SESSIONS", "3"))  # 管理员最多3个活跃会话

# 会话存储
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
    logger.info(f"[ADMIN_AUTH] Redis连接状态 - USE_REDIS: {USE_REDIS}")
except Exception as e:
    logger.error(f"[ADMIN_AUTH] Redis连接异常: {e}")
    USE_REDIS = False
    redis_client = None

def safe_redis_get(key: str) -> Optional[dict]:
    """安全地从 Redis 获取 JSON 数据"""
    if not redis_client:
        return None
    
    data = redis_client.get(key)
    if not data:
        return None
    
    if isinstance(data, bytes):
        data = data.decode('utf-8')
    
    try:
        return json.loads(data)
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        logger.error(f"Failed to decode Redis data for key {key}: {e}")
        return None

def safe_redis_set(key: str, value: dict, expire_seconds: int = None):
    """安全地向 Redis 设置 JSON 数据"""
    if not redis_client:
        return False
    
    try:
        json_data = json.dumps(value)
        if expire_seconds:
            redis_client.setex(key, expire_seconds, json_data)
        else:
            redis_client.set(key, json_data)
        return True
    except Exception as e:
        logger.error(f"Failed to set Redis data for key {key}: {e}")
        return False

def safe_redis_delete(key: str):
    """安全地从 Redis 删除数据"""
    if not redis_client:
        return False
    
    try:
        redis_client.delete(key)
        return True
    except Exception as e:
        logger.error(f"Failed to delete Redis data for key {key}: {e}")
        return False

# 内存存储（Redis不可用时的备选方案）
admin_active_sessions: Dict[str, 'AdminSessionInfo'] = {}

@dataclass
class AdminSessionInfo:
    """管理员会话信息"""
    session_id: str
    admin_id: str
    created_at: datetime
    last_activity: datetime
    device_fingerprint: str
    ip_address: str
    user_agent: str
    is_active: bool = True

class AdminAuthManager:
    """管理员认证管理器"""
    
    @staticmethod
    def generate_session_id() -> str:
        """生成管理员会话ID"""
        return f"admin_session_{secrets.token_urlsafe(32)}"
    
    @staticmethod
    def get_device_fingerprint(request: Request) -> str:
        """获取设备指纹"""
        user_agent = request.headers.get("user-agent", "")
        accept_language = request.headers.get("accept-language", "")
        accept_encoding = request.headers.get("accept-encoding", "")
        
        fingerprint_data = f"{user_agent}|{accept_language}|{accept_encoding}"
        return hashlib.sha256(fingerprint_data.encode()).hexdigest()[:16]
    
    @staticmethod
    def create_session(admin_id: str, request: Request) -> AdminSessionInfo:
        """创建管理员会话"""
        session_id = AdminAuthManager.generate_session_id()
        current_time = datetime.utcnow()
        
        # 获取客户端信息 - 使用统一的IP获取方法
        from app.security import get_client_ip
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        device_fingerprint = AdminAuthManager.get_device_fingerprint(request)
        
        # 创建会话信息
        session_info = AdminSessionInfo(
            session_id=session_id,
            admin_id=admin_id,
            created_at=current_time,
            last_activity=current_time,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent
        )
        
        # 存储会话
        AdminAuthManager._store_session(session_info)
        
        # 清理过期会话
        AdminAuthManager._cleanup_expired_sessions(admin_id)
        
        logger.info(f"[ADMIN_AUTH] 创建管理员会话: {admin_id}, session_id: {session_id[:8]}...")
        return session_info
    
    @staticmethod
    def get_session(session_id: str, update_activity: bool = True) -> Optional[AdminSessionInfo]:
        """获取管理员会话"""
        if not session_id:
            return None
        
        # 从Redis或内存获取会话
        session_data = AdminAuthManager._get_session_data(session_id)
        if not session_data:
            return None
        
        # 检查会话是否过期
        if AdminAuthManager._is_session_expired(session_data):
            AdminAuthManager._delete_session(session_id)
            return None
        
        # 更新活动时间
        if update_activity:
            session_data['last_activity'] = datetime.utcnow().isoformat()
            AdminAuthManager._store_session_data(session_id, session_data)
        
        return AdminSessionInfo(**session_data)
    
    @staticmethod
    def delete_session(session_id: str) -> bool:
        """删除管理员会话"""
        return AdminAuthManager._delete_session(session_id)
    
    @staticmethod
    def delete_all_sessions(admin_id: str) -> int:
        """删除管理员的所有会话"""
        deleted_count = 0
        
        if USE_REDIS:
            # 从Redis删除
            pattern = f"admin_session:{admin_id}:*"
            keys = redis_client.keys(pattern)
            if keys:
                deleted_count = redis_client.delete(*keys)
        else:
            # 从内存删除
            keys_to_delete = [sid for sid, session in admin_active_sessions.items() 
                            if session.admin_id == admin_id]
            for sid in keys_to_delete:
                del admin_active_sessions[sid]
                deleted_count += 1
        
        logger.info(f"[ADMIN_AUTH] 删除管理员所有会话: {admin_id}, 删除数量: {deleted_count}")
        return deleted_count
    
    @staticmethod
    def _store_session(session_info: AdminSessionInfo):
        """存储会话信息"""
        session_data = {
            'session_id': session_info.session_id,
            'admin_id': session_info.admin_id,
            'created_at': session_info.created_at.isoformat() if session_info.created_at else None,
            'last_activity': session_info.last_activity.isoformat() if session_info.last_activity else None,
            'device_fingerprint': session_info.device_fingerprint,
            'ip_address': session_info.ip_address,
            'user_agent': session_info.user_agent,
            'is_active': session_info.is_active
        }
        
        AdminAuthManager._store_session_data(session_info.session_id, session_data)
    
    @staticmethod
    def _store_session_data(session_id: str, session_data: dict):
        """存储会话数据到Redis或内存"""
        if USE_REDIS:
            key = f"admin_session:{session_data['admin_id']}:{session_id}"
            expire_seconds = ADMIN_SESSION_EXPIRE_HOURS * 3600
            safe_redis_set(key, session_data, expire_seconds)
        else:
            admin_active_sessions[session_id] = AdminSessionInfo(**session_data)
    
    @staticmethod
    def _get_session_data(session_id: str) -> Optional[dict]:
        """从Redis或内存获取会话数据"""
        if USE_REDIS:
            # 从Redis查找
            pattern = f"admin_session:*:{session_id}"
            keys = redis_client.keys(pattern)
            if keys:
                return safe_redis_get(keys[0])
            return None
        else:
            # 从内存查找
            session = admin_active_sessions.get(session_id)
            if session:
                return {
                    'session_id': session.session_id,
                    'admin_id': session.admin_id,
                    'created_at': session.created_at.isoformat() if session.created_at else None,
                    'last_activity': session.last_activity.isoformat() if session.last_activity else None,
                    'device_fingerprint': session.device_fingerprint,
                    'ip_address': session.ip_address,
                    'user_agent': session.user_agent,
                    'is_active': session.is_active
                }
            return None
    
    @staticmethod
    def _delete_session(session_id: str) -> bool:
        """删除会话"""
        if USE_REDIS:
            pattern = f"admin_session:*:{session_id}"
            keys = redis_client.keys(pattern)
            if keys:
                return safe_redis_delete(keys[0])
            return False
        else:
            if session_id in admin_active_sessions:
                del admin_active_sessions[session_id]
                return True
            return False
    
    @staticmethod
    def _is_session_expired(session_data: dict) -> bool:
        """检查会话是否过期"""
        last_activity = datetime.fromisoformat(session_data['last_activity'])
        expire_time = last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
        return datetime.utcnow() > expire_time
    
    @staticmethod
    def cleanup_expired_sessions():
        """清理过期会话（公共方法）"""
        try:
            if USE_REDIS and redis_client:
                # 主动清理Redis中的过期会话
                pattern = "admin_session:*"
                keys = redis_client.keys(pattern)
                cleaned_count = 0
                
                for key in keys:
                    # 确保key是字符串
                    key_str = key.decode() if isinstance(key, bytes) else key
                    data = safe_redis_get(key_str)
                    if data:
                        # 检查会话是否过期
                        # 首先检查是否被标记为不活跃
                        if not data.get('is_active', True):
                            # 删除不活跃的会话
                            redis_client.delete(key_str)
                            cleaned_count += 1
                        else:
                            # 检查时间过期
                            last_activity_str = data.get('last_activity', data.get('created_at'))
                            if last_activity_str:
                                last_activity = datetime.fromisoformat(last_activity_str)
                                if datetime.utcnow() - last_activity > timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS):
                                    # 删除过期会话
                                    redis_client.delete(key_str)
                                    cleaned_count += 1
                
                logger.info(f"[ADMIN_AUTH] Redis清理了 {cleaned_count} 个过期会话")
            else:
                # 清理内存中的过期会话
                current_time = datetime.utcnow()
                expired_sessions = []
                
                for session_id, session in admin_active_sessions.items():
                    expire_time = session.last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
                    if current_time > expire_time:
                        expired_sessions.append(session_id)
                
                for session_id in expired_sessions:
                    del admin_active_sessions[session_id]
                
                logger.info(f"[ADMIN_AUTH] 内存清理了 {len(expired_sessions)} 个过期会话")
                
        except Exception as e:
            logger.error(f"[ADMIN_AUTH] 清理过期会话失败: {e}")

    @staticmethod
    def _cleanup_expired_sessions(admin_id: str):
        """清理特定管理员的过期会话（私有方法）"""
        if USE_REDIS:
            # Redis会自动过期，无需手动清理
            pass
        else:
            # 清理内存中的过期会话
            current_time = datetime.utcnow()
            expired_sessions = []
            
            for session_id, session in admin_active_sessions.items():
                if session.admin_id == admin_id:
                    expire_time = session.last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
                    if current_time > expire_time:
                        expired_sessions.append(session_id)
            
            for session_id in expired_sessions:
                del admin_active_sessions[session_id]

def create_admin_session(admin_id: str, request: Request) -> str:
    """创建管理员会话并返回会话ID"""
    session_info = AdminAuthManager.create_session(admin_id, request)
    return session_info.session_id

def validate_admin_session(request: Request) -> Optional[AdminSessionInfo]:
    """验证管理员会话（最高安全等级）"""
    logger.info(f"[ADMIN_AUTH] validate_admin_session - URL: {request.url}")
    logger.info(f"[ADMIN_AUTH] validate_admin_session - Cookies: {dict(request.cookies)}")
    
    # 获取管理员会话Cookie
    admin_session_id = request.cookies.get("admin_session_id")
    
    if not admin_session_id:
        logger.info("[ADMIN_AUTH] 未找到admin_session_id")
        return None
    
    logger.info(f"[ADMIN_AUTH] 找到admin_session_id: {admin_session_id[:8]}...")
    
    # 验证会话
    session = AdminAuthManager.get_session(admin_session_id, update_activity=False)
    if not session:
        logger.info(f"[ADMIN_AUTH] 管理员会话验证失败: {admin_session_id[:8]}...")
        return None
    
    # 验证会话是否仍然活跃
    if not session.is_active:
        logger.warning(f"[ADMIN_AUTH] 管理员会话已失效: {session.admin_id}")
        return None
    
    # 验证设备指纹（用于检测会话劫持）
    current_fingerprint = AdminAuthManager.get_device_fingerprint(request)
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"[ADMIN_AUTH] 设备指纹不匹配，可能存在会话劫持: {session.admin_id}")
        # 强制登出可疑会话
        AdminAuthManager.delete_session(admin_session_id)
        return None
    
    # 验证IP地址（可选，用于检测异常登录）- 使用统一的IP获取方法
    from app.security import get_client_ip
    current_ip = get_client_ip(request)
    if session.ip_address != current_ip:
        logger.warning(f"[ADMIN_AUTH] IP地址不匹配: 会话IP={session.ip_address}, 当前IP={current_ip}")
        # 可以选择是否强制登出
        # AdminAuthManager.delete_session(admin_session_id)
        # return None
    
    logger.info(f"[ADMIN_AUTH] 管理员会话验证成功: {admin_session_id[:8]}..., 管理员: {session.admin_id}")
    return session

def create_admin_session_cookie(response: Response, session_id: str) -> Response:
    """创建管理员会话Cookie（支持跨域）"""
    from app.config import Config
    
    # 不设置domain，与客服保持一致
    cookie_domain = None
    
    # 确保samesite值有效
    samesite_value = Config.COOKIE_SAMESITE if Config.COOKIE_SAMESITE in ["lax", "strict", "none"] else "lax"
    
    # 设置管理员会话Cookie - 支持跨域
    response.set_cookie(
        key="admin_session_id",
        value=session_id,
        max_age=ADMIN_SESSION_EXPIRE_HOURS * 3600,  # 8小时
        httponly=True,  # 防止XSS攻击
        secure=Config.COOKIE_SECURE,    # 根据环境设置
        samesite=samesite_value,  # 根据环境设置
        path="/",  # 根路径，确保前端可以读取
        domain=cookie_domain  # 根据环境设置
    )
    
    # 设置管理员身份标识Cookie - 支持跨域
    response.set_cookie(
        key="admin_authenticated",
        value="true",
        max_age=ADMIN_SESSION_EXPIRE_HOURS * 3600,
        httponly=False,  # 前端需要读取
        secure=Config.COOKIE_SECURE,     # 根据环境设置
        samesite=samesite_value,  # 根据环境设置
        path="/",  # 根路径，确保前端可以读取
        domain=cookie_domain  # 根据环境设置
    )
    
    logger.info(f"[ADMIN_AUTH] 设置管理员Cookie - session_id: {session_id[:8]}..., secure: {Config.COOKIE_SECURE}, samesite: {samesite_value}, domain: {cookie_domain}")
    logger.info(f"[ADMIN_AUTH] 管理员Cookie设置完成 - admin_session_id 和 admin_authenticated")
    
    return response

def clear_admin_session_cookie(response: Response) -> Response:
    """清除管理员会话Cookie"""
    # 清除管理员相关cookie
    response.delete_cookie("admin_session_id")
    response.delete_cookie("admin_authenticated")
    response.delete_cookie("admin_refresh_token")
    
    # 清除CSRF token（管理员登录时也会设置）
    response.delete_cookie("csrf_token")
    
    return response


# ==================== 管理员Refresh Token功能 ====================

def create_admin_refresh_token(admin_id: str) -> str:
    """创建管理员refresh token"""
    import secrets
    from datetime import datetime, timedelta
    
    # 生成refresh token
    refresh_token = secrets.token_urlsafe(32)
    
    # 设置过期时间（12小时）
    expire_time = datetime.utcnow() + timedelta(hours=12)
    
    # 存储到Redis
    if USE_REDIS:
        redis_key = f"admin_refresh_token:{admin_id}:{refresh_token}"
        redis_client.setex(
            redis_key, 
            int(12 * 3600),  # 12小时
            json.dumps({
                "admin_id": admin_id,
                "created_at": datetime.utcnow().isoformat(),
                "expires_at": expire_time.isoformat()
            })
        )
    
    logger.info(f"[ADMIN_AUTH] 创建管理员refresh token: {admin_id}")
    return refresh_token


def verify_admin_refresh_token(refresh_token: str) -> Optional[str]:
    """验证管理员refresh token"""
    if not refresh_token:
        return None
    
    if not USE_REDIS:
        return None
    
    # 查找refresh token
    pattern = f"admin_refresh_token:*:{refresh_token}"
    keys = redis_client.keys(pattern)
    
    if not keys:
        return None
    
    # 获取token数据
    token_data = safe_redis_get(keys[0])
    if not token_data:
        return None
    
    # 检查是否过期
    try:
        expires_at = datetime.fromisoformat(token_data['expires_at'])
        if datetime.utcnow() > expires_at:
            # 过期了，删除token
            redis_client.delete(keys[0])
            return None
    except (ValueError, KeyError):
        return None
    
    return token_data.get('admin_id')


def revoke_admin_refresh_token(refresh_token: str) -> bool:
    """撤销管理员refresh token"""
    if not refresh_token or not USE_REDIS:
        return False
    
    # 查找并删除refresh token
    pattern = f"admin_refresh_token:*:{refresh_token}"
    keys = redis_client.keys(pattern)
    
    if keys:
        redis_client.delete(*keys)
        logger.info(f"[ADMIN_AUTH] 撤销管理员refresh token: {refresh_token}")
        return True
    
    return False


def revoke_all_admin_refresh_tokens(admin_id: str) -> int:
    """撤销管理员所有refresh token"""
    if not USE_REDIS:
        return 0
    
    pattern = f"admin_refresh_token:{admin_id}:*"
    keys = redis_client.keys(pattern)
    
    if keys:
        count = redis_client.delete(*keys)
        logger.info(f"[ADMIN_AUTH] 撤销管理员所有refresh token: {admin_id}, 删除数量: {count}")
        return count
    
    return 0


def create_admin_refresh_token_cookie(response: Response, refresh_token: str) -> Response:
    """设置管理员refresh token Cookie"""
    from app.config import Config
    
    # 不设置domain，与客服保持一致
    cookie_domain = None
    
    # 确保samesite值有效
    samesite_value = Config.COOKIE_SAMESITE if Config.COOKIE_SAMESITE in ["lax", "strict", "none"] else "lax"
    
    # 设置管理员refresh token Cookie
    response.set_cookie(
        key="admin_refresh_token",
        value=refresh_token,
        max_age=12 * 3600,  # 12小时
        httponly=True,  # 防止XSS攻击
        secure=Config.COOKIE_SECURE,
        samesite=samesite_value,
        path="/",
        domain=cookie_domain
    )
    
    return response

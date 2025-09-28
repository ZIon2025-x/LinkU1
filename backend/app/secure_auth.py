"""
安全认证模块
实现短有效期JWT + 可撤销机制 + 会话管理
"""

import json
import secrets
import hashlib
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, Set
from dataclasses import dataclass
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging

logger = logging.getLogger(__name__)

# 配置
ACCESS_TOKEN_EXPIRE_MINUTES = 5  # 访问令牌5分钟过期
REFRESH_TOKEN_EXPIRE_DAYS = 7    # 刷新令牌7天过期
SESSION_EXPIRE_HOURS = 24        # 会话24小时过期
MAX_ACTIVE_SESSIONS = 5          # 每个用户最多5个活跃会话

# 会话存储
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
except:
    USE_REDIS = False
    redis_client = None

# 内存存储（Redis不可用时的备选方案）
active_sessions: Dict[str, 'SessionInfo'] = {}
refresh_token_blacklist: Set[str] = set()

@dataclass
class SessionInfo:
    """会话信息"""
    user_id: str
    session_id: str
    device_fingerprint: str
    created_at: datetime
    last_activity: datetime
    ip_address: str
    user_agent: str
    is_active: bool = True

class SecureAuthManager:
    """安全认证管理器"""
    
    @staticmethod
    def generate_session_id() -> str:
        """生成高熵会话ID"""
        return secrets.token_urlsafe(32)  # 256 bits
    
    @staticmethod
    def generate_refresh_token() -> str:
        """生成刷新令牌"""
        return secrets.token_urlsafe(32)  # 256 bits
    
    @staticmethod
    def create_session(
        user_id: str,
        device_fingerprint: str,
        ip_address: str,
        user_agent: str
    ) -> SessionInfo:
        """创建新会话"""
        session_id = SecureAuthManager.generate_session_id()
        now = datetime.utcnow()
        
        session = SessionInfo(
            user_id=user_id,
            session_id=session_id,
            device_fingerprint=device_fingerprint,
            created_at=now,
            last_activity=now,
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        if USE_REDIS and redis_client:
            # 使用 Redis 存储会话
            session_data = {
                "user_id": session.user_id,
                "session_id": session.session_id,
                "device_fingerprint": session.device_fingerprint,
                "created_at": session.created_at.isoformat(),
                "last_activity": session.last_activity.isoformat(),
                "ip_address": session.ip_address,
                "user_agent": session.user_agent,
                "is_active": session.is_active
            }
            
            # 存储会话数据
            redis_client.setex(
                f"session:{session_id}",
                SESSION_EXPIRE_HOURS * 3600,  # TTL in seconds
                json.dumps(session_data)
            )
            
            # 维护用户会话列表
            user_sessions_key = f"user_sessions:{user_id}"
            redis_client.sadd(user_sessions_key, session_id)
            redis_client.expire(user_sessions_key, SESSION_EXPIRE_HOURS * 3600)
            
            # 清理用户的旧会话
            user_sessions = redis_client.smembers(user_sessions_key)
            if len(user_sessions) > MAX_ACTIVE_SESSIONS:
                # 获取最旧的会话并删除
                oldest_sessions = []
                for sid in user_sessions:
                    session_data = redis_client.get(f"session:{sid}")
                    if session_data:
                        data = json.loads(session_data)
                        oldest_sessions.append((data["last_activity"], sid))
                
                # 按最后活动时间排序，删除最旧的
                oldest_sessions.sort()
                for _, old_sid in oldest_sessions[:-MAX_ACTIVE_SESSIONS]:
                    redis_client.delete(f"session:{old_sid}")
                    redis_client.srem(user_sessions_key, old_sid)
        else:
            # 使用内存存储
            # 清理用户的旧会话（保持最多MAX_ACTIVE_SESSIONS个）
            user_sessions = [s for s in active_sessions.values() if s.user_id == user_id and s.is_active]
            if len(user_sessions) >= MAX_ACTIVE_SESSIONS:
                # 删除最旧的会话
                oldest_session = min(user_sessions, key=lambda s: s.last_activity)
                oldest_session.is_active = False
            
            active_sessions[session_id] = session
        
        return session
    
    @staticmethod
    def get_session(session_id: str) -> Optional[SessionInfo]:
        """获取会话信息"""
        if USE_REDIS and redis_client:
            # 从 Redis 获取会话
            session_data = redis_client.get(f"session:{session_id}")
            if not session_data:
                return None
            
            data = json.loads(session_data)
            session = SessionInfo(
                user_id=data["user_id"],
                session_id=data["session_id"],
                device_fingerprint=data["device_fingerprint"],
                created_at=datetime.fromisoformat(data["created_at"]),
                last_activity=datetime.fromisoformat(data["last_activity"]),
                ip_address=data["ip_address"],
                user_agent=data["user_agent"],
                is_active=data["is_active"]
            )
            
            if not session.is_active:
                return None
            
            # 检查会话是否过期
            if datetime.utcnow() - session.last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                # 删除过期会话
                redis_client.delete(f"session:{session_id}")
                redis_client.srem(f"user_sessions:{session.user_id}", session_id)
                return None
            
            # 更新最后活动时间
            session.last_activity = datetime.utcnow()
            session_data["last_activity"] = session.last_activity.isoformat()
            redis_client.setex(
                f"session:{session_id}",
                SESSION_EXPIRE_HOURS * 3600,
                json.dumps(session_data)
            )
            
            return session
        else:
            # 从内存获取会话
            session = active_sessions.get(session_id)
            if not session or not session.is_active:
                return None
            
            # 检查会话是否过期
            if datetime.utcnow() - session.last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                session.is_active = False
                return None
            
            # 更新最后活动时间
            session.last_activity = datetime.utcnow()
            return session
    
    @staticmethod
    def revoke_session(session_id: str) -> bool:
        """撤销会话"""
        if USE_REDIS and redis_client:
            # 从 Redis 撤销会话
            session_data = redis_client.get(f"session:{session_id}")
            if session_data:
                data = json.loads(session_data)
                data["is_active"] = False
                redis_client.setex(
                    f"session:{session_id}",
                    SESSION_EXPIRE_HOURS * 3600,
                    json.dumps(data)
                )
                # 从用户会话列表中移除
                redis_client.srem(f"user_sessions:{data['user_id']}", session_id)
                return True
            return False
        else:
            # 从内存撤销会话
            if session_id in active_sessions:
                active_sessions[session_id].is_active = False
                return True
            return False
    
    @staticmethod
    def revoke_user_sessions(user_id: str) -> int:
        """撤销用户的所有会话"""
        if USE_REDIS and redis_client:
            # 从 Redis 撤销用户的所有会话
            user_sessions_key = f"user_sessions:{user_id}"
            user_sessions = redis_client.smembers(user_sessions_key)
            count = 0
            
            for session_id in user_sessions:
                session_data = redis_client.get(f"session:{session_id}")
                if session_data:
                    data = json.loads(session_data)
                    data["is_active"] = False
                    redis_client.setex(
                        f"session:{session_id}",
                        SESSION_EXPIRE_HOURS * 3600,
                        json.dumps(data)
                    )
                    count += 1
            
            # 清空用户会话列表
            redis_client.delete(user_sessions_key)
            return count
        else:
            # 从内存撤销用户的所有会话
            count = 0
            for session in active_sessions.values():
                if session.user_id == user_id and session.is_active:
                    session.is_active = False
                    count += 1
            return count
    
    @staticmethod
    def cleanup_expired_sessions():
        """清理过期会话"""
        if USE_REDIS and redis_client:
            # Redis 会自动清理过期的键，这里只需要清理内存中的引用
            logger.info("Redis 自动清理过期会话")
            return
        
        # 内存存储的清理逻辑
        now = datetime.utcnow()
        expired_sessions = []
        
        for session_id, session in active_sessions.items():
            if not session.is_active:
                continue
            
            # 检查绝对过期时间
            if now - session.created_at > timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS):
                session.is_active = False
                expired_sessions.append(session_id)
                continue
            
            # 检查滑动过期时间
            if now - session.last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                session.is_active = False
                expired_sessions.append(session_id)
        
        # 清理过期的会话
        for session_id in expired_sessions:
            if session_id in active_sessions:
                del active_sessions[session_id]
        
        logger.info(f"清理了 {len(expired_sessions)} 个过期会话")

class SecureCookieManager:
    """安全Cookie管理器"""
    
    @staticmethod
    def set_secure_cookies(
        response: Response,
        session_id: str,
        refresh_token: str,
        user_id: str
    ) -> None:
        """设置安全Cookie"""
        # 设置会话ID Cookie（短期，用于API调用）
        response.set_cookie(
            key="session_id",
            value=session_id,
            max_age=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            httponly=True,
            secure=True,
            samesite="none",  # 跨域需要
            path="/"
        )
        
        # 设置刷新令牌Cookie（长期，用于刷新会话）
        response.set_cookie(
            key="refresh_token",
            value=refresh_token,
            max_age=REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
            httponly=True,
            secure=True,
            samesite="none",  # 跨域需要
            path="/"
        )
        
        # 设置用户ID Cookie（非敏感，用于前端显示）
        response.set_cookie(
            key="user_id",
            value=user_id,
            max_age=REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
            httponly=False,  # 前端需要访问
            secure=True,
            samesite="none",
            path="/"
        )
        
        logger.info(f"设置安全Cookie - session_id: {session_id[:8]}..., user_id: {user_id}")
    
    @staticmethod
    def clear_secure_cookies(response: Response) -> None:
        """清除安全Cookie"""
        response.delete_cookie(
            key="session_id",
            httponly=True,
            secure=True,
            samesite="none",
            path="/"
        )
        
        response.delete_cookie(
            key="refresh_token",
            httponly=True,
            secure=True,
            samesite="none",
            path="/"
        )
        
        response.delete_cookie(
            key="user_id",
            httponly=False,
            secure=True,
            samesite="none",
            path="/"
        )
        
        logger.info("清除安全Cookie")

class SecureTokenBearer(HTTPBearer):
    """安全令牌认证器"""
    
    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)
    
    def __call__(self, request: Request) -> Optional[HTTPAuthorizationCredentials]:
        # 首先尝试从Authorization头获取
        authorization_header = request.headers.get("Authorization")
        if authorization_header and authorization_header.startswith("Bearer "):
            token = authorization_header.split(" ")[1]
            return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        # 如果Authorization头没有，尝试从Cookie获取session_id
        session_id = request.cookies.get("session_id")
        if session_id:
            # 验证会话
            session = SecureAuthManager.get_session(session_id)
            if session:
                # 将session_id作为Bearer token返回
                return HTTPAuthorizationCredentials(scheme="Bearer", credentials=session_id)
        
        if self.auto_error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未提供有效的认证信息"
            )
        
        return None

# 创建认证实例
secure_bearer = SecureTokenBearer()

def get_client_ip(request: Request) -> str:
    """获取客户端IP"""
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

def get_device_fingerprint(request: Request) -> str:
    """生成设备指纹"""
    user_agent = request.headers.get("user-agent", "")
    accept_language = request.headers.get("accept-language", "")
    accept_encoding = request.headers.get("accept-encoding", "")
    
    # 组合设备特征
    device_string = f"{user_agent}|{accept_language}|{accept_encoding}"
    
    # 生成哈希指纹
    return hashlib.sha256(device_string.encode()).hexdigest()[:16]

def validate_session(request: Request) -> Optional[SessionInfo]:
    """验证会话"""
    session_id = request.cookies.get("session_id")
    if not session_id:
        return None
    
    session = SecureAuthManager.get_session(session_id)
    if not session:
        return None
    
    # 验证设备指纹（可选，用于检测会话劫持）
    current_fingerprint = get_device_fingerprint(request)
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"设备指纹不匹配 - session: {session_id[:8]}...")
        # 可以选择是否撤销会话
        # SecureAuthManager.revoke_session(session_id)
        # return None
    
    return session

"""
安全认证模块
实现短有效期JWT + 可撤销机制 + 会话管理
"""

import os
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

# 配置 - 从环境变量读取
from app.config import get_settings
settings = get_settings()

ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES
REFRESH_TOKEN_EXPIRE_DAYS = settings.REFRESH_TOKEN_EXPIRE_DAYS
SESSION_EXPIRE_HOURS = int(os.getenv("SESSION_EXPIRE_HOURS", "24"))
USER_SESSION_EXPIRE_HOURS = int(os.getenv("USER_SESSION_EXPIRE_HOURS", "24"))
MAX_ACTIVE_SESSIONS = int(os.getenv("MAX_ACTIVE_SESSIONS", "5"))

# 会话存储
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
    logger.info(f"[DEBUG] Redis连接状态 - USE_REDIS: {USE_REDIS}, redis_client: {redis_client is not None}")
except Exception as e:
    logger.error(f"[DEBUG] Redis连接异常: {e}")
    USE_REDIS = False
    redis_client = None

def safe_redis_get(key: str) -> Optional[dict]:
    """安全地从 Redis 获取 JSON 数据"""
    if not redis_client:
        return None
    
    data = redis_client.get(key)
    if not data:
        return None
    
    # 确保 data 是字符串
    if isinstance(data, bytes):
        data = data.decode('utf-8')
    
    try:
        return json.loads(data)
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        logger.error(f"Failed to decode Redis data for key {key}: {e}")
        return None

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
                # 获取最旧的会话并标记为不活跃
                oldest_sessions = []
                for sid in user_sessions:
                    data = safe_redis_get(f"session:{sid}")
                    if data and data.get("is_active", True):  # 只考虑活跃会话
                        oldest_sessions.append((data["last_activity"], sid))
                
                # 按最后活动时间排序，标记最旧的为不活跃
                oldest_sessions.sort()
                for _, old_sid in oldest_sessions[:-MAX_ACTIVE_SESSIONS]:
                    # 标记为不活跃而不是删除
                    data = safe_redis_get(f"session:{old_sid}")
                    if data:
                        data["is_active"] = False
                        redis_client.setex(
                            f"session:{old_sid}",
                            SESSION_EXPIRE_HOURS * 3600,
                            json.dumps(data)
                        )
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
    def get_session(session_id: str, update_activity: bool = True) -> Optional[SessionInfo]:
        """获取会话信息"""
        logger.info(f"[DEBUG] get_session - session_id: {session_id[:8]}...")
        if USE_REDIS and redis_client:
            # 从 Redis 获取会话
            data = safe_redis_get(f"session:{session_id}")
            logger.info(f"[DEBUG] get_session - Redis data: {data}")
            if not data:
                logger.info(f"[DEBUG] get_session - 未找到Redis数据")
                return None
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
            
            # 只有在需要更新活动时间时才更新（避免频繁更新导致token刷新）
            if update_activity:
                # 检查是否真的需要更新（避免过于频繁的更新）
                time_since_last_activity = datetime.utcnow() - session.last_activity
                if time_since_last_activity > timedelta(minutes=5):  # 至少5分钟才更新一次
                    session.last_activity = datetime.utcnow()
                    data["last_activity"] = session.last_activity.isoformat()
                    redis_client.setex(
                        f"session:{session_id}",
                        SESSION_EXPIRE_HOURS * 3600,
                        json.dumps(data)
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
            
            # 只有在需要更新活动时间时才更新
            if update_activity:
                # 检查是否真的需要更新（避免过于频繁的更新）
                time_since_last_activity = datetime.utcnow() - session.last_activity
                if time_since_last_activity > timedelta(minutes=5):  # 至少5分钟才更新一次
                    session.last_activity = datetime.utcnow()
            
            return session
    
    @staticmethod
    def update_session(session_id: str, session: SessionInfo) -> bool:
        """更新会话信息"""
        try:
            if USE_REDIS and redis_client:
                # 更新 Redis 中的会话
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
                redis_client.setex(
                    f"session:{session_id}",
                    SESSION_EXPIRE_HOURS * 3600,
                    json.dumps(session_data)
                )
                logger.info(f"会话已更新: {session_id[:8]}...")
                return True
            else:
                # 更新内存中的会话
                if session_id in active_sessions:
                    active_sessions[session_id] = session
                    logger.info(f"会话已更新: {session_id[:8]}...")
                    return True
            return False
        except Exception as e:
            logger.error(f"更新会话失败: {e}")
            return False

    @staticmethod
    def revoke_session(session_id: str) -> bool:
        """撤销会话"""
        if USE_REDIS and redis_client:
            # 从 Redis 直接删除会话数据
            data = safe_redis_get(f"session:{session_id}")
            if data:
                # 从用户会话列表中移除
                redis_client.srem(f"user_sessions:{data['user_id']}", session_id)
                # 直接删除会话数据
                redis_client.delete(f"session:{session_id}")
                logger.info(f"会话已撤销并删除: {session_id[:8]}...")
                return True
            return False
        else:
            # 从内存撤销会话
            if session_id in active_sessions:
                del active_sessions[session_id]
                return True
            return False
    
    @staticmethod
    def revoke_user_sessions(user_id: str) -> int:
        """撤销用户的所有会话"""
        if USE_REDIS and redis_client:
            # 从 Redis 删除用户的所有会话
            user_sessions_key = f"user_sessions:{user_id}"
            user_sessions = redis_client.smembers(user_sessions_key)
            count = 0
            
            for session_id in user_sessions:
                # 直接删除会话数据
                if redis_client.delete(f"session:{session_id}"):
                    count += 1
            
            # 清空用户会话列表
            redis_client.delete(user_sessions_key)
            logger.info(f"用户所有会话已撤销并删除: {user_id}, 删除数量: {count}")
            return count
        else:
            # 从内存删除用户的所有会话
            count = 0
            sessions_to_delete = []
            for session_id, session in active_sessions.items():
                if session.user_id == user_id:
                    sessions_to_delete.append(session_id)
                    count += 1
            
            for session_id in sessions_to_delete:
                del active_sessions[session_id]
            
            logger.info(f"用户所有会话已撤销并删除: {user_id}, 删除数量: {count}")
            return count
    
    @staticmethod
    def cleanup_expired_sessions():
        """清理过期会话"""
        if USE_REDIS and redis_client:
            # 主动清理Redis中的过期会话
            try:
                # 获取所有会话键
                session_keys = redis_client.keys("session:*")
                cleaned_count = 0
                
                for key in session_keys:
                    # 确保key是字符串
                    key_str = key.decode() if isinstance(key, bytes) else key
                    data = safe_redis_get(key_str)
                    if data:
                        # 检查会话是否过期
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            last_activity = datetime.fromisoformat(last_activity_str)
                            if datetime.utcnow() - last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                                # 删除过期会话
                                redis_client.delete(key_str)
                                # 从用户会话列表中移除
                                user_id = data.get('user_id')
                                if user_id:
                                    redis_client.srem(f"user_sessions:{user_id}", key_str.split(':')[1])
                                cleaned_count += 1
                
                logger.info(f"Redis清理了 {cleaned_count} 个过期会话")
            except Exception as e:
                logger.error(f"Redis清理过期会话失败: {e}")
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
        
        logger.info(f"内存清理了 {len(expired_sessions)} 个过期会话")

# SecureCookieManager 已移除，请使用 app.cookie_manager.CookieManager

class SecureTokenBearer(HTTPBearer):
    """安全令牌认证器"""
    
    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)
    
    async def __call__(self, request: Request) -> Optional[HTTPAuthorizationCredentials]:
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

def is_fingerprint_similar(original: str, current: str, threshold: float = 0.7) -> bool:
    """检查两个设备指纹是否相似"""
    if not original or not current:
        return False
    
    # 计算字符串相似度（简单的字符匹配）
    if len(original) != len(current):
        return False
    
    matches = sum(1 for a, b in zip(original, current) if a == b)
    similarity = matches / len(original)
    
    logger.debug(f"设备指纹相似度: {similarity:.2f} (阈值: {threshold})")
    return similarity >= threshold

def validate_session(request: Request) -> Optional[SessionInfo]:
    """验证会话"""
    logger.info(f"[DEBUG] validate_session - URL: {request.url}")
    logger.info(f"[DEBUG] validate_session - Cookies: {dict(request.cookies)}")
    logger.info(f"[DEBUG] validate_session - Headers: {dict(request.headers)}")
    
    # 1. 尝试主要Cookie名称
    session_id = request.cookies.get("session_id")
    
    # 2. 如果Cookie中没有，尝试从请求头获取（仅作为最后的备用方案）
    if not session_id:
        session_id = request.headers.get("X-Session-ID")
        if session_id:
            logger.info(f"[DEBUG] 从X-Session-ID头获取session_id: {session_id[:8]}...")
    
    # 3. 如果还是没有，尝试从Authorization头获取（仅用于移动端JWT认证）
    if not session_id:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            # 这是JWT token，不是session_id，应该通过JWT认证处理
            logger.info(f"[DEBUG] 检测到Authorization头，但这是JWT token，不是session_id")
            # 不将JWT token当作session_id处理
    
    if not session_id:
        logger.info("[DEBUG] 未找到session_id")
        return None
    
    logger.info(f"[DEBUG] 找到session_id: {session_id[:8]}...")
    
    session = SecureAuthManager.get_session(session_id, update_activity=False)  # 不更新活动时间
    if not session:
        logger.info(f"[DEBUG] 会话验证失败: {session_id[:8]}...")
        return None
    
    logger.info(f"[DEBUG] 会话验证成功: {session_id[:8]}..., 用户: {session.user_id}")
    
    # 验证设备指纹（用于检测会话劫持）
    current_fingerprint = get_device_fingerprint(request)
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"设备指纹不匹配 - session: {session_id[:8]}...")
        logger.warning(f"原始指纹: {session.device_fingerprint}")
        logger.warning(f"当前指纹: {current_fingerprint}")
        
        # 检查指纹差异是否在可接受范围内（允许部分变化）
        if is_fingerprint_similar(session.device_fingerprint, current_fingerprint):
            logger.info("设备指纹相似，允许访问但记录警告")
            # 更新会话的设备指纹为新的指纹
            session.device_fingerprint = current_fingerprint
            SecureAuthManager.update_session(session_id, session)
        else:
            logger.error("设备指纹差异过大，可能存在会话劫持，拒绝访问")
            # 撤销可疑会话
            SecureAuthManager.revoke_session(session_id)
            return None
    
    return session

def create_user_session_cookie(response: Response, session_id: str) -> Response:
    """创建用户会话Cookie（生产环境）"""
    # 设置用户会话Cookie
    response.set_cookie(
        key="session_id",
        value=session_id,
        max_age=USER_SESSION_EXPIRE_HOURS * 3600,  # 24小时
        httponly=True,
        secure=True,  # 生产环境使用HTTPS
        samesite="lax"
    )
    
    # 设置用户身份标识Cookie
    response.set_cookie(
        key="user_authenticated",
        value="true",
        max_age=USER_SESSION_EXPIRE_HOURS * 3600,
        httponly=False,  # 前端需要读取
        secure=True,  # 生产环境使用HTTPS
        samesite="lax"
    )
    
    return response

def clear_user_session_cookie(response: Response) -> Response:
    """清除用户会话Cookie"""
    response.delete_cookie("session_id")
    response.delete_cookie("user_authenticated")
    return response
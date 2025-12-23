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
from typing import Optional, List, Dict, Any, Set
from dataclasses import dataclass
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging

from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc

logger = logging.getLogger(__name__)

# 配置 - 从环境变量读取
from app.config import get_settings
settings = get_settings()

ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES
REFRESH_TOKEN_EXPIRE_HOURS = settings.REFRESH_TOKEN_EXPIRE_HOURS
SESSION_EXPIRE_HOURS = int(os.getenv("SESSION_EXPIRE_HOURS", "1"))  # 默认1小时，保持与Cookie一致
USER_SESSION_EXPIRE_HOURS = int(os.getenv("USER_SESSION_EXPIRE_HOURS", "1"))  # 默认1小时
MAX_ACTIVE_SESSIONS = int(os.getenv("MAX_ACTIVE_SESSIONS", "5"))

# 会话存储
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
    # Redis连接状态已初始化
except Exception as e:
    logger.error(f"Redis连接异常: {e}")
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
    refresh_token: str = ""
    is_active: bool = True
    is_ios_app: bool = False  # 是否为 iOS 应用会话

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
    def _get_active_sessions(user_id: str) -> List[SessionInfo]:
        """获取指定用户的活跃会话"""
        active_sessions = []
        
        if USE_REDIS and redis_client:
            try:
                # 查找所有该用户的会话
                pattern = f"session:*"
                keys = redis_client.keys(pattern)
                
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    data = safe_redis_get(key_str)
                    if data and data.get('user_id') == user_id and data.get('is_active', True):
                        # 检查是否过期
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            last_activity = parse_iso_utc(last_activity_str)
                            if get_utc_time() - last_activity <= timedelta(hours=SESSION_EXPIRE_HOURS):
                                # 转换为SessionInfo对象
                                session_info = SessionInfo(
                                    user_id=data['user_id'],
                                    session_id=data['session_id'],
                                    device_fingerprint=data.get('device_fingerprint', ''),
                                    created_at=parse_iso_utc(data['created_at']),
                                    last_activity=parse_iso_utc(last_activity_str),
                                    ip_address=data.get('ip_address', ''),
                                    user_agent=data.get('user_agent', ''),
                                    is_active=data.get('is_active', True)
                                )
                                active_sessions.append(session_info)
            except Exception as e:
                logger.error(f"[SECURE_AUTH] 获取活跃会话失败: {e}")
        
        return active_sessions
    
    @staticmethod
    def _revoke_session(session_id: str) -> bool:
        """撤销指定会话"""
        try:
            if USE_REDIS and redis_client:
                # 删除会话
                key = f"session:{session_id}"
                redis_client.delete(key)
                logger.info(f"[SECURE_AUTH] 撤销用户会话: {session_id}")
                return True
            return False
        except Exception as e:
            logger.error(f"[SECURE_AUTH] 撤销用户会话失败: {e}")
            return False

    @staticmethod
    def revoke_other_sessions(user_id: str, keep_session_id: str, keep_refresh_token: str = "") -> int:
        """撤销该用户除指定会话以外的所有会话，并清理对应refresh token。
        返回撤销的会话数量。
        """
        revoked_count = 0
        try:
            if USE_REDIS and redis_client:
                # 遍历用户会话集合
                user_sessions_key = f"user_sessions:{user_id}"
                session_ids = redis_client.smembers(user_sessions_key)
                for raw_id in session_ids:
                    session_id = raw_id.decode() if isinstance(raw_id, bytes) else raw_id
                    if session_id == keep_session_id:
                        continue
                    # 删除会话键
                    redis_client.delete(f"session:{session_id}")
                    # 从集合移除
                    redis_client.srem(user_sessions_key, session_id)
                    revoked_count += 1

                # 清理该用户的所有refresh token，保留当前会话的refresh token（若提供）
                pattern = f"user_refresh_token:{user_id}:*"
                keys = redis_client.keys(pattern)
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    # 如果提供了需要保留的refresh token，则跳过
                    if keep_refresh_token and key_str.endswith(keep_refresh_token):
                        continue
                    redis_client.delete(key)
            else:
                # 内存模式：简单清理
                to_delete: List[str] = []
                for sid, session in active_sessions.items():
                    if session.user_id == user_id and sid != keep_session_id:
                        to_delete.append(sid)
                for sid in to_delete:
                    del active_sessions[sid]
                    revoked_count += 1
        except Exception as e:
            logger.error(f"[SECURE_AUTH] 撤销其它会话失败: {e}")
        return revoked_count
    
    @staticmethod
    def _store_session(session: SessionInfo) -> None:
        """存储会话到Redis"""
        if USE_REDIS and redis_client:
            # iOS 应用会话使用更长的过期时间（1年），其他会话使用默认过期时间
            if session.is_ios_app:
                expire_hours = 365 * 24  # 1年
                logger.info(f"[SECURE_AUTH] iOS 应用会话，设置长期过期时间: {expire_hours}小时")
            else:
                expire_hours = SESSION_EXPIRE_HOURS
            
            # 计算过期时间
            expire_time = session.last_activity + timedelta(hours=expire_hours)
            
            session_data = {
                "user_id": session.user_id,
                "session_id": session.session_id,
                "device_fingerprint": session.device_fingerprint,
                "created_at": format_iso_utc(session.created_at),
                "last_activity": format_iso_utc(session.last_activity),
                "expires_at": format_iso_utc(expire_time),  # 添加过期时间
                "ip_address": session.ip_address,
                "user_agent": session.user_agent,
                "refresh_token": session.refresh_token,
                "is_active": session.is_active,
                "is_ios_app": session.is_ios_app  # 保存是否为 iOS 应用会话
            }
            
            # 存储会话数据
            redis_client.setex(
                f"session:{session.session_id}",
                expire_hours * 3600,  # 根据设备类型设置TTL
                json.dumps(session_data)
            )
            
            # 添加到用户会话集合
            redis_client.sadd(f"user_sessions:{session.user_id}", session.session_id)
            redis_client.expire(f"user_sessions:{session.user_id}", expire_hours * 3600)
    
    @staticmethod
    def create_session(
        user_id: str,
        device_fingerprint: str,
        ip_address: str,
        user_agent: str,
        refresh_token: str = "",
        is_ios_app: bool = False,
        single_sign_on: bool = True  # 默认启用单点登录
    ) -> SessionInfo:
        """创建新会话（单点登录：新登录会挤掉所有旧会话）"""
        now = get_utc_time()
        
        # 1. 检查现有活跃会话
        existing_sessions = SecureAuthManager._get_active_sessions(user_id)
        
        # 2. 如果存在活跃会话，优先复用（相同设备指纹和IP）
        for session in existing_sessions:
            if (session.device_fingerprint == device_fingerprint and 
                session.ip_address == ip_address and
                session.is_active):
                # 更新最后活动时间
                session.last_activity = now
                SecureAuthManager._store_session(session)
                logger.info(f"[SECURE_AUTH] 复用现有用户会话: {user_id}, session_id: {session.session_id[:8]}...")
                return session
        
        # 3. 单点登录：撤销所有旧会话（新登录会挤掉所有旧设备）
        if single_sign_on and existing_sessions:
            revoked_count = SecureAuthManager.revoke_user_sessions(user_id)
            logger.info(f"[SECURE_AUTH] 单点登录：撤销用户 {user_id} 的所有旧会话，共 {revoked_count} 个")
        
        # 4. 创建新会话
        session_id = SecureAuthManager.generate_session_id()
        session = SessionInfo(
            user_id=user_id,
            session_id=session_id,
            device_fingerprint=device_fingerprint,
            created_at=now,
            last_activity=now,
            ip_address=ip_address,
            user_agent=user_agent,
            refresh_token=refresh_token,
            is_ios_app=is_ios_app
        )
        
        # 存储会话
        SecureAuthManager._store_session(session)
        
        logger.info(f"[SECURE_AUTH] 创建新用户会话: {user_id}, session_id: {session_id[:8]}...")
        return session
    
    @staticmethod
    def get_session(session_id: str, update_activity: bool = True) -> Optional[SessionInfo]:
        """获取会话信息"""
        if USE_REDIS and redis_client:
            # 从 Redis 获取会话
            data = safe_redis_get(f"session:{session_id}")
            if not data:
                return None
            session = SessionInfo(
                user_id=data["user_id"],
                session_id=data["session_id"],
                device_fingerprint=data["device_fingerprint"],
                created_at=parse_iso_utc(data["created_at"]),
                last_activity=parse_iso_utc(data["last_activity"]),
                ip_address=data["ip_address"],
                user_agent=data["user_agent"],
                refresh_token=data.get("refresh_token", ""),
                is_active=data["is_active"],
                is_ios_app=data.get("is_ios_app", False)  # 兼容旧数据，默认为False
            )
            
            if not session.is_active:
                return None
            
            # iOS 应用会话不过期（或使用很长的过期时间），其他会话按正常逻辑检查
            if session.is_ios_app:
                # iOS 应用会话：只要会话存在就不过期（除非被手动撤销）
                # 不检查过期时间，让会话长期有效
                logger.debug(f"[SECURE_AUTH] iOS 应用会话不过期检查: {session_id[:8]}...")
            else:
                # 检查会话是否过期
                if get_utc_time() - session.last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                    # 删除过期会话
                    redis_client.delete(f"session:{session_id}")
                    redis_client.srem(f"user_sessions:{session.user_id}", session_id)
                    return None
            
            # 只有在需要更新活动时间时才更新（避免频繁更新导致token刷新）
            if update_activity:
                # 检查是否真的需要更新（避免过于频繁的更新）
                time_since_last_activity = get_utc_time() - session.last_activity
                if time_since_last_activity > timedelta(minutes=5):  # 至少5分钟才更新一次
                    session.last_activity = get_utc_time()
                    data["last_activity"] = format_iso_utc(session.last_activity)
                    # iOS 应用会话使用更长的过期时间
                    expire_hours = 365 * 24 if session.is_ios_app else SESSION_EXPIRE_HOURS
                    redis_client.setex(
                        f"session:{session_id}",
                        expire_hours * 3600,
                        json.dumps(data)
                    )
            
            return session
        else:
            # 从内存获取会话
            session = active_sessions.get(session_id)
            if not session or not session.is_active:
                return None
            
            # 检查会话是否过期
            if get_utc_time() - session.last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
                session.is_active = False
                return None
            
            # 只有在需要更新活动时间时才更新
            if update_activity:
                # 检查是否真的需要更新（避免过于频繁的更新）
                time_since_last_activity = get_utc_time() - session.last_activity
                if time_since_last_activity > timedelta(minutes=5):  # 至少5分钟才更新一次
                    session.last_activity = get_utc_time()
            
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
                    "created_at": format_iso_utc(session.created_at),
                    "last_activity": format_iso_utc(session.last_activity),
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
            
            # 删除用户的所有 refresh token
            pattern = f"user_refresh_token:{user_id}:*"
            refresh_keys = redis_client.keys(pattern)
            for key in refresh_keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                redis_client.delete(key_str)
            
            logger.info(f"[SECURE_AUTH] 用户所有会话和refresh token已撤销: {user_id}, 删除会话数: {count}, 删除refresh token数: {len(refresh_keys)}")
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
                        # 首先检查是否被标记为不活跃
                        if not data.get('is_active', True):
                            # 删除不活跃的会话
                            redis_client.delete(key_str)
                            # 从用户会话列表中移除
                            user_id = data.get('user_id')
                            if user_id:
                                redis_client.srem(f"user_sessions:{user_id}", key_str.split(':')[1])
                            cleaned_count += 1
                        else:
                            # 检查时间过期
                            last_activity_str = data.get('last_activity', data.get('created_at'))
                            if last_activity_str:
                                last_activity = parse_iso_utc(last_activity_str)
                                if get_utc_time() - last_activity > timedelta(hours=SESSION_EXPIRE_HOURS):
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
        now = get_utc_time()
        expired_sessions = []
        
        for session_id, session in active_sessions.items():
            if not session.is_active:
                continue
            
            # 检查绝对过期时间
            if now - session.created_at > timedelta(hours=REFRESH_TOKEN_EXPIRE_HOURS):
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

def is_mobile_request(request: Request) -> bool:
    """
    检测是否为经过验证的移动端请求
    
    使用严格验证：必须同时满足 X-Platform 和 User-Agent 匹配
    """
    from app.csrf import verify_mobile_request
    
    # 使用严格的移动端验证
    is_valid, platform = verify_mobile_request(request)
    if is_valid:
        logger.debug(f"移动端请求验证通过: 平台={platform}")
        return True
    
    # 验证失败
    logger.debug(f"移动端请求验证失败: {platform}")
    return False

def is_ios_app_request(request: Request) -> bool:
    """
    检测是否为 iOS 原生应用请求（排除Safari浏览器）
    
    检查条件（必须同时满足）：
    1. X-Platform 头为 "ios"
    2. User-Agent 包含 "Link2Ur-iOS" 或 "link2ur-ios"（应用特定标识）
    3. User-Agent 不包含 "Safari" 或 "Version/"（排除浏览器）
    
    注意：iPhone/iPad 上的 Safari 浏览器不应该被识别为 iOS 应用
    """
    # 1. 必须要有 X-Platform 头
    platform = request.headers.get("X-Platform", "").lower()
    if platform != "ios":
        return False
    
    # 2. 检查 User-Agent
    user_agent = request.headers.get("user-agent", "").lower()
    
    # 排除 Safari 浏览器（Safari 的 User-Agent 通常包含 "Safari" 和 "Version/"）
    if "safari" in user_agent and "version/" in user_agent:
        # 这是 Safari 浏览器，不是 iOS 应用
        logger.debug(f"检测到 Safari 浏览器，不是 iOS 应用: UA={user_agent[:80]}")
        return False
    
    # 3. 检查是否包含 iOS 应用特定标识
    # iOS 应用的 User-Agent 应该包含 "Link2Ur-iOS" 或 "link2ur-ios"
    # 不应该仅仅因为包含 "link2ur" 就认为是应用（可能是网页）
    if "link2ur-ios" in user_agent or "link2ur/ios" in user_agent:
        logger.info(f"检测到 iOS 原生应用请求: platform={platform}, UA={user_agent[:80]}")
        return True
    
    # 如果只有 X-Platform 头但没有应用标识，也不认为是应用
    # 这可能是网页请求但设置了错误的头
    logger.debug(f"X-Platform=ios 但缺少应用标识，不是 iOS 应用: UA={user_agent[:80]}")
    return False

def validate_session(request: Request) -> Optional[SessionInfo]:
    """验证会话"""
    # 会话验证中（已移除DEBUG日志以提升性能）
    
    # 1. 尝试主要Cookie名称
    session_id = request.cookies.get("session_id")
    
    # 2. 如果Cookie中没有，尝试从请求头获取（仅作为最后的备用方案）
    if not session_id:
        session_id = request.headers.get("X-Session-ID")
    
    # 3. 如果还是没有，尝试从Authorization头获取（仅用于移动端JWT认证）
    if not session_id:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            # 这是JWT token，不是session_id，应该通过JWT认证处理
            # 不将JWT token当作session_id处理
            pass
    
    if not session_id:
        return None
    
    
    session = SecureAuthManager.get_session(session_id, update_activity=True)  # 更新活动时间（内部有5分钟防抖机制）
    if not session:
        return None
    
    # 检测是否为移动端请求
    is_mobile = is_mobile_request(request)
    
    # 验证设备指纹（用于检测会话劫持）
    current_fingerprint = get_device_fingerprint(request)
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"设备指纹不匹配 - session: {session_id[:8]}... (移动端: {is_mobile})")
        logger.warning(f"原始指纹: {session.device_fingerprint}")
        logger.warning(f"当前指纹: {current_fingerprint}")
        
        # 移动端使用更宽松的阈值 (0.4)，Web端使用标准阈值 (0.7)
        threshold = 0.4 if is_mobile else 0.7
        
        # 检查指纹差异是否在可接受范围内（允许部分变化）
        if is_fingerprint_similar(session.device_fingerprint, current_fingerprint, threshold):
            logger.info(f"设备指纹相似 (阈值: {threshold})，允许访问并更新指纹")
            # 更新会话的设备指纹为新的指纹
            session.device_fingerprint = current_fingerprint
            SecureAuthManager.update_session(session_id, session)
        else:
            # 移动端：指纹不匹配时不撤销会话，只更新指纹并记录警告
            # 这是因为移动端的 Accept-Language 等可能因系统设置变化
            if is_mobile:
                logger.warning(f"移动端设备指纹差异较大，但不撤销会话，更新为新指纹")
                session.device_fingerprint = current_fingerprint
                SecureAuthManager.update_session(session_id, session)
            else:
                logger.error("设备指纹差异过大，可能存在会话劫持，拒绝访问")
                # 撤销可疑会话（仅限 Web 端）
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


# ==================== 用户Refresh Token功能 ====================

def create_user_refresh_token(user_id: str, ip_address: str = "", device_fingerprint: str = "") -> str:
    """创建用户refresh token，绑定IP和设备指纹（只允许一个设备）"""
    import secrets
    from datetime import datetime, timedelta
    from app.utils.time_utils import get_utc_time
    
    # 生成refresh token
    refresh_token = secrets.token_urlsafe(32)
    
    # 设置过期时间（12小时）
    expire_time = get_utc_time() + timedelta(hours=12)
    
    # 存储到Redis，包含IP和设备指纹绑定
    if USE_REDIS and redis_client:
        # 删除该用户的所有旧refresh token（只允许一个设备）
        old_token_pattern = f"user_refresh_token:{user_id}:*"
        old_keys = redis_client.keys(old_token_pattern)
        if old_keys:
            logger.info(f"[SECURE_AUTH] 删除用户 {user_id} 的旧refresh token，共 {len(old_keys)} 个")
            # 将 keys 转换为字符串（如果是从Redis返回的bytes）
            key_strings = []
            for key in old_keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                key_strings.append(key_str)
            redis_client.delete(*key_strings)
        
        redis_key = f"user_refresh_token:{user_id}:{refresh_token}"
        redis_client.setex(
            redis_key, 
            int(12 * 3600),  # 12小时
            json.dumps({
                "user_id": user_id,
                "ip_address": ip_address,
                "device_fingerprint": device_fingerprint,
                "created_at": format_iso_utc(get_utc_time()),
                "expires_at": format_iso_utc(expire_time),
                "last_used": None  # 记录最后使用时间，用于频率限制
            })
        )
        logger.info(f"[SECURE_AUTH] 创建用户refresh token: {user_id}, IP: {ip_address}, 设备: {device_fingerprint}")
    
    return refresh_token


def verify_user_refresh_token(refresh_token: str, ip_address: str = "", device_fingerprint: str = "") -> Optional[str]:
    """验证用户refresh token，检查IP和设备指纹绑定"""
    if not refresh_token:
        return None
    
    if not USE_REDIS or not redis_client:
        return None
    
    # 查找refresh token
    pattern = f"user_refresh_token:*:{refresh_token}"
    keys = redis_client.keys(pattern)
    
    if not keys:
        return None
    
    # 获取token数据
    data = safe_redis_get(keys[0])
    if not data:
        return None
    
    # 检查是否过期
    expires_at_str = data.get('expires_at')
    if expires_at_str:
        expires_at = parse_iso_utc(expires_at_str)
        if get_utc_time() > expires_at:
            # 过期了，删除
            redis_client.delete(keys[0])
            return None
    
    # 检查IP绑定
    stored_ip = data.get('ip_address', '')
    if stored_ip and ip_address and stored_ip != ip_address:
        logger.warning(f"[SECURE_AUTH] refresh token IP不匹配: 存储={stored_ip}, 当前={ip_address}")
        return None
    
    # 检查设备指纹绑定
    stored_device = data.get('device_fingerprint', '')
    if stored_device and device_fingerprint and stored_device != device_fingerprint:
        logger.warning(f"[SECURE_AUTH] refresh token 设备指纹不匹配: 存储={stored_device}, 当前={device_fingerprint}")
        return None
    
    # 检查频率限制（20分钟内最多使用一次）
    last_used_str = data.get('last_used')
    if last_used_str:
        last_used = parse_iso_utc(last_used_str)
        if get_utc_time() - last_used < timedelta(minutes=20):
            logger.warning(f"[SECURE_AUTH] refresh token 使用过于频繁: {refresh_token}")
            return None
    
    # 更新最后使用时间
    current_time = get_utc_time()
    data['last_used'] = format_iso_utc(current_time)
    redis_client.setex(keys[0], int(12 * 3600), json.dumps(data))
    
    return data.get('user_id')


def revoke_user_refresh_token(refresh_token: str) -> bool:
    """撤销用户refresh token"""
    if not refresh_token or not USE_REDIS or not redis_client:
        return False
    
    # 查找并删除refresh token
    pattern = f"user_refresh_token:*:{refresh_token}"
    keys = redis_client.keys(pattern)
    
    if keys:
        redis_client.delete(*keys)
        logger.info(f"[SECURE_AUTH] 撤销用户refresh token: {refresh_token}")
        return True
    
    return False


def revoke_all_user_refresh_tokens(user_id: str) -> int:
    """撤销用户所有refresh token"""
    if not USE_REDIS or not redis_client:
        return 0
    
    pattern = f"user_refresh_token:{user_id}:*"
    keys = redis_client.keys(pattern)
    
    if keys:
        count = redis_client.delete(*keys)
        logger.info(f"[SECURE_AUTH] 撤销用户所有refresh token: {user_id}, 删除数量: {count}")
        return count
    
    return 0


def cleanup_expired_sessions_aggressive() -> int:
    """激进清理过期会话与refresh token。
    规则：
    - 优先依据数据中的 expires_at 判断是否过期；
    - 若无 expires_at，则回退到 last_activity 超过60分钟（安全阈值）；
    - 追加清理 user_refresh_token:*，同样按 expires_at 判断。
    """
    if not USE_REDIS or not redis_client:
        return 0
    
    cleaned_count = 0
    current_time = get_utc_time()
    
    try:
        # 清理普通用户会话
        session_pattern = "session:*"
        session_keys = redis_client.keys(session_pattern)
        
        for key in session_keys:
            try:
                data = safe_redis_get(key)
                if data:
                    # 1) 优先按 expires_at 判断
                    expires_at_str = data.get('expires_at')
                    should_delete = False
                    if expires_at_str:
                        try:
                            expires_at = parse_iso_utc(expires_at_str)
                            if current_time > expires_at:
                                should_delete = True
                        except Exception:
                            # 解析失败则回退到last_activity规则
                            pass
                    # 2) 回退规则：基于last_activity的60分钟阈值
                    if not should_delete:
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            last_activity = parse_iso_utc(last_activity_str)
                            if current_time - last_activity > timedelta(minutes=60):
                                should_delete = True

                    if should_delete:
                        redis_client.delete(key)
                        # 同时清理用户会话集合中的引用
                        user_id = data.get('user_id')
                        if user_id:
                            redis_client.srem(f"user_sessions:{user_id}", key.split(':')[1])
                        cleaned_count += 1
            except Exception as e:
                logger.warning(f"[SECURE_AUTH] 清理会话失败 {key}: {e}")
                continue
        
        # 清理用户会话集合
        user_sessions_pattern = "user_sessions:*"
        user_sessions_keys = redis_client.keys(user_sessions_pattern)
        
        for key in user_sessions_keys:
            try:
                # 检查集合是否为空，如果为空则删除
                if redis_client.scard(key) == 0:
                    redis_client.delete(key)
                    cleaned_count += 1
            except Exception as e:
                logger.warning(f"[SECURE_AUTH] 清理用户会话集合失败 {key}: {e}")
                continue

        # 追加：清理用户 refresh token（user_refresh_token:*）
        refresh_pattern = "user_refresh_token:*"
        refresh_keys = redis_client.keys(refresh_pattern)
        for key in refresh_keys:
            try:
                data = safe_redis_get(key)
                if not data:
                    continue
                expires_at_str = data.get('expires_at')
                if not expires_at_str:
                    continue
                try:
                    expires_at = parse_iso_utc(expires_at_str)
                    if current_time > expires_at:
                        redis_client.delete(key)
                        cleaned_count += 1
                except Exception:
                    # 忽略解析错误
                    continue
            except Exception as e:
                logger.warning(f"[SECURE_AUTH] 清理refresh token失败 {key}: {e}")
                continue
        
        logger.info(f"[SECURE_AUTH] 激进清理完成，清理了 {cleaned_count} 个过期会话")
        return cleaned_count
        
    except Exception as e:
        logger.error(f"[SECURE_AUTH] 激进清理失败: {e}")
        return 0
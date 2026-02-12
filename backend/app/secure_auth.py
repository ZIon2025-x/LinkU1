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
# 会话过期时间：Web端使用较短时间，移动端应用（iOS原生/Flutter）使用较长时间
# 移动端应用会话使用 MOBILE_APP_SESSION_EXPIRE_DAYS 天（默认90天，可通过环境变量调整）
# 向后兼容：环境变量名仍支持 IOS_SESSION_EXPIRE_DAYS
SESSION_EXPIRE_HOURS = int(os.getenv("SESSION_EXPIRE_HOURS", "24"))  # 默认24小时（优化：从1小时改为24小时，提升用户体验）
IOS_SESSION_EXPIRE_HOURS = int(os.getenv("MOBILE_APP_SESSION_EXPIRE_DAYS", os.getenv("IOS_SESSION_EXPIRE_DAYS", "90"))) * 24  # 默认90天，移动端应用共享
USER_SESSION_EXPIRE_HOURS = int(os.getenv("USER_SESSION_EXPIRE_HOURS", "168"))  # 默认7天（优化：从1小时改为168小时，减少频繁登出）
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
                # 使用 user_sessions 集合直接查找该用户的 session，避免扫描全部 session
                user_sessions_key = f"user_sessions:{user_id}"
                session_ids = redis_client.smembers(user_sessions_key)

                for raw_id in session_ids:
                    session_id = raw_id.decode() if isinstance(raw_id, bytes) else raw_id
                    key_str = f"session:{session_id}"
                    data = safe_redis_get(key_str)
                    if data and data.get('is_active', True):
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
                from app.redis_utils import scan_keys
                pattern = f"user_refresh_token:{user_id}:*"
                keys = scan_keys(redis_client, pattern)
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
            # iOS 应用会话使用更长的过期时间，其他会话使用默认过期时间
            if session.is_ios_app:
                expire_hours = IOS_SESSION_EXPIRE_HOURS
                logger.info(f"[SECURE_AUTH] iOS 应用会话，过期时间: {expire_hours}小时（{expire_hours // 24}天）")
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
                logger.warning(f"[SECURE_AUTH] Session未找到 - session_id: {session_id[:8] if session_id else 'None'}... (可能已过期或被删除)")
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
                    expire_hours = IOS_SESSION_EXPIRE_HOURS if session.is_ios_app else SESSION_EXPIRE_HOURS
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
                # iOS 应用会话使用更长的过期时间，其他会话使用默认过期时间
                if session.is_ios_app:
                    expire_hours = IOS_SESSION_EXPIRE_HOURS
                else:
                    expire_hours = SESSION_EXPIRE_HOURS
                
                # 更新 Redis 中的会话
                session_data = {
                    "user_id": session.user_id,
                    "session_id": session.session_id,
                    "device_fingerprint": session.device_fingerprint,
                    "created_at": format_iso_utc(session.created_at),
                    "last_activity": format_iso_utc(session.last_activity),
                    "ip_address": session.ip_address,
                    "user_agent": session.user_agent,
                    "refresh_token": session.refresh_token,
                    "is_active": session.is_active,
                    "is_ios_app": session.is_ios_app  # 保存是否为 iOS 应用会话
                }
                redis_client.setex(
                    f"session:{session_id}",
                    expire_hours * 3600,  # 根据设备类型设置TTL
                    json.dumps(session_data)
                )
                logger.info(f"会话已更新: {session_id[:8]}... (iOS: {session.is_ios_app}, TTL: {expire_hours}小时)")
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
            from app.redis_utils import scan_keys
            pattern = f"user_refresh_token:{user_id}:*"
            refresh_keys = scan_keys(redis_client, pattern)
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
        """清理过期会话
        
        注意: Redis 使用 TTL 自动过期，无需手动清理
        撤销会话时直接删除键，不使用 is_active 标记
        """
        # Redis TTL 自动处理，无需操作
        pass
        
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
    """
    生成设备指纹
    
    只使用 User-Agent 来生成指纹，因为：
    1. User-Agent 是最稳定的浏览器特征
    2. Accept-Language 和 Accept-Encoding 可能因浏览器设置、扩展、隐私模式等变化
    3. 使用完整的 User-Agent 可以更准确地识别设备
    
    如果 User-Agent 为空，使用其他可用的头部信息作为后备
    """
    user_agent = request.headers.get("user-agent", "")
    
    # 如果 User-Agent 为空，尝试使用其他头部信息
    if not user_agent:
        # 尝试从其他头部获取信息
        accept_language = request.headers.get("accept-language", "")
        accept_encoding = request.headers.get("accept-encoding", "")
        device_string = f"unknown|{accept_language}|{accept_encoding}"
    else:
        # 只使用 User-Agent，这是最稳定的特征
        # 移除可能变化的部分（如扩展信息），但保留核心信息
        device_string = user_agent
    
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

def is_mobile_app_request(request: Request) -> bool:
    """
    检测是否为移动端原生应用请求（iOS 原生 / Flutter iOS / Flutter Android）
    
    匹配以下任一条件即视为移动端应用：
    
    A) iOS 原生应用（Swift/SwiftUI）：
       - X-Platform 头为 "ios"
       - User-Agent 包含 "Link2Ur-iOS" 或 "link2ur-ios"
       - User-Agent 不包含 "Safari"+"Version/"（排除浏览器）
    
    B) Flutter 应用（iOS 或 Android）：
       - X-App-Platform 头为 "flutter"
       - User-Agent 包含 "dart"（Flutter/Dart 的默认 UA 格式为 "Dart/x.y (dart:io)"）
       - 排除浏览器（不包含 "Mozilla"）
    
    移动端应用会话将获得长期有效期（默认90天），普通 Web 会话使用 SESSION_EXPIRE_HOURS
    """
    user_agent = request.headers.get("user-agent", "").lower()
    
    # ========== 路径 A: iOS 原生应用 ==========
    x_platform = request.headers.get("X-Platform", "").lower()
    
    if x_platform == "ios":
        # 排除 Safari 浏览器
        if "safari" in user_agent and "version/" in user_agent:
            logger.debug(f"[移动端检测] Safari 浏览器，非应用: UA={user_agent[:80]}")
            return False
        
        # iOS 原生应用特定标识
        if "link2ur-ios" in user_agent or "link2ur/ios" in user_agent:
            logger.info(f"[移动端检测] ✅ iOS 原生应用，长期会话（{IOS_SESSION_EXPIRE_HOURS // 24}天）: UA={user_agent[:80]}")
            return True
    
    # ========== 路径 B: Flutter 应用（iOS / Android） ==========
    x_app_platform = request.headers.get("X-App-Platform", "").lower()
    
    if x_app_platform == "flutter":
        # Flutter/Dart 的 User-Agent 格式为 "Dart/x.y (dart:io)"
        # 排除浏览器伪造（浏览器 UA 通常包含 "mozilla"）
        if "dart" in user_agent and "mozilla" not in user_agent:
            platform_detail = x_platform or "unknown"
            logger.info(f"[移动端检测] ✅ Flutter 应用（平台={platform_detail}），长期会话（{IOS_SESSION_EXPIRE_HOURS // 24}天）: UA={user_agent[:80]}")
            return True
        
        # X-App-Platform=flutter 但 UA 不匹配，可能是伪造
        logger.warning(f"[移动端检测] X-App-Platform=flutter 但 UA 不含 dart 或含 mozilla，拒绝: UA={user_agent[:80]}")
        return False
    
    # ========== 未匹配任何移动端特征 ==========
    if x_platform or x_app_platform:
        logger.debug(f"[移动端检测] 未匹配移动端应用: X-Platform={x_platform}, X-App-Platform={x_app_platform}, UA={user_agent[:80]}")
    return False


# 向后兼容别名：所有已有代码中 from app.secure_auth import is_ios_app_request 仍可正常工作
is_ios_app_request = is_mobile_app_request


def _is_ios_platform_request(request: Request) -> bool:
    """
    判断请求是否来自 iOS 平台（iOS 原生应用 或 Flutter iOS 版）。
    仅用于需要区分 iOS vs Android 的场景（如 Stripe 微信支付 client 参数）。
    """
    x_platform = request.headers.get("X-Platform", "").lower()
    return x_platform == "ios"


def get_wechat_pay_payment_method_options(request: Optional[Request]) -> dict:
    """
    返回 WeChat Pay 的 payment_method_options，用于创建 PaymentIntent。
    iOS PaymentSheet 必须为 wechat_pay 指定 client: "ios"，否则会报
    "None of the payment methods can be used in PaymentSheet"；
    Android 端指定 client: "android"；Web 端不传或传 client: "web" 即可。
    """
    if request is None:
        return {}
    x_platform = request.headers.get("X-Platform", "").lower()
    if x_platform == "ios":
        return {"wechat_pay": {"client": "ios"}}
    if x_platform == "android":
        return {"wechat_pay": {"client": "android"}}
    return {}


def validate_session(request: Request) -> Optional[SessionInfo]:
    """验证会话 - 严格绑定IP、设备指纹和地址，一个会话只能在一个IP、一个设备上使用"""
    # 会话验证中（已移除DEBUG日志以提升性能）
    
    # 1. 尝试主要Cookie名称
    session_id = request.cookies.get("session_id")
    session_source = "cookie"
    
    # 2. 如果Cookie中没有，尝试从请求头获取（仅作为最后的备用方案）
    if not session_id:
        session_id = request.headers.get("X-Session-ID")
        session_source = "header"
    
    # 3. 如果还是没有，尝试从Authorization头获取（仅用于移动端JWT认证）
    if not session_id:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            # 这是JWT token，不是session_id，应该通过JWT认证处理
            # 不将JWT token当作session_id处理
            pass
    
    if not session_id:
        return None
    
    # 获取当前请求的IP地址
    current_ip = get_client_ip(request)
    
    session = SecureAuthManager.get_session(session_id, update_activity=True)  # 更新活动时间（内部有5分钟防抖机制）
    if not session:
        # 诊断日志：session在Redis中不存在
        logger.warning(f"[SECURE_AUTH] validate_session失败 - session_id来源: {session_source}, session_id: {session_id[:8] if session_id else 'None'}..., IP: {current_ip}")
        return None
    
    # ========== IP地址验证：iOS应用使用更宽松的策略 ==========
    # iOS应用允许IP地址变化（用户可能切换WiFi/移动网络），其他会话严格验证
    is_ios_app = session.is_ios_app if hasattr(session, 'is_ios_app') else False
    
    if session.ip_address:
        if not current_ip or current_ip == "unknown":
            # iOS应用允许IP未知的情况（某些网络环境可能无法获取IP）
            if not is_ios_app:
                logger.error(f"[SECURE_AUTH] 无法获取当前IP地址，拒绝访问")
                logger.error(f"  会话ID: {session_id[:8]}...")
                logger.error(f"  用户ID: {session.user_id}")
                logger.error(f"  会话IP: {session.ip_address}")
                SecureAuthManager.revoke_session(session_id)
                return None
            else:
                logger.debug(f"[SECURE_AUTH] iOS应用IP未知，允许访问（宽松策略）")
        elif session.ip_address != current_ip:
            # iOS应用允许IP变化，其他会话严格验证
            if is_ios_app:
                logger.info(f"[SECURE_AUTH] iOS应用IP地址变化（允许）- 会话IP: {session.ip_address}, 当前IP: {current_ip}")
                # 更新会话的IP地址为当前IP
                session.ip_address = current_ip
                SecureAuthManager.update_session(session_id, session)
            else:
                logger.error(f"[SECURE_AUTH] 会话IP地址不匹配，拒绝访问并撤销会话")
                logger.error(f"  会话ID: {session_id[:8]}...")
                logger.error(f"  用户ID: {session.user_id}")
                logger.error(f"  会话IP: {session.ip_address}")
                logger.error(f"  当前IP: {current_ip}")
                # IP地址不匹配，立即撤销会话（安全策略：一个会话只能在一个IP使用）
                SecureAuthManager.revoke_session(session_id)
                return None
    elif not current_ip or current_ip == "unknown":
        # iOS应用允许IP未知，其他会话拒绝访问
        if not is_ios_app:
            logger.error(f"[SECURE_AUTH] 会话和当前请求都缺少IP地址，拒绝访问")
            logger.error(f"  会话ID: {session_id[:8]}...")
            logger.error(f"  用户ID: {session.user_id}")
            SecureAuthManager.revoke_session(session_id)
            return None
        else:
            logger.debug(f"[SECURE_AUTH] iOS应用IP未知，允许访问（宽松策略）")
    
    # 检测是否为移动端请求
    is_mobile = is_mobile_request(request)
    
    # ========== 严格验证：设备指纹必须匹配 ==========
    # 如果会话绑定了设备指纹，则必须匹配
    if not session.device_fingerprint:
        logger.error(f"[SECURE_AUTH] 会话缺少设备指纹，拒绝访问并撤销会话")
        logger.error(f"  会话ID: {session_id[:8]}...")
        logger.error(f"  用户ID: {session.user_id}")
        SecureAuthManager.revoke_session(session_id)
        return None
    
    current_fingerprint = get_device_fingerprint(request)
    if not current_fingerprint:
        logger.error(f"[SECURE_AUTH] 无法获取当前设备指纹，拒绝访问")
        logger.error(f"  会话ID: {session_id[:8]}...")
        logger.error(f"  用户ID: {session.user_id}")
        SecureAuthManager.revoke_session(session_id)
        return None
    
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"[SECURE_AUTH] 设备指纹不匹配 - session: {session_id[:8]}... (移动端: {is_mobile})")
        logger.warning(f"  用户ID: {session.user_id}")
        logger.warning(f"  原始指纹: {session.device_fingerprint}")
        logger.warning(f"  当前指纹: {current_fingerprint}")
        logger.warning(f"  IP地址: {session.ip_address} -> {current_ip}")
        
        # 移动端使用更宽松的阈值 (0.4)，Web端使用标准阈值 (0.6)
        # 由于只使用 User-Agent，指纹应该更稳定，但如果 User-Agent 变化（如浏览器更新），
        # 仍然需要允许一定的变化
        threshold = 0.4 if is_mobile else 0.6
        
        # 检查指纹差异是否在可接受范围内（允许部分变化）
        if is_fingerprint_similar(session.device_fingerprint, current_fingerprint, threshold):
            logger.info(f"[SECURE_AUTH] 设备指纹相似 (阈值: {threshold})，允许访问并更新指纹")
            # 更新会话的设备指纹为新的指纹
            session.device_fingerprint = current_fingerprint
            SecureAuthManager.update_session(session_id, session)
        elif session.ip_address == current_ip:
            # 如果 IP 地址相同，允许更新设备指纹（可能是浏览器设置变化）
            # 这是一个安全权衡：相同 IP 地址下，设备指纹变化更可能是合法的
            logger.info(f"[SECURE_AUTH] IP地址相同，允许更新设备指纹（可能是浏览器设置变化）")
            logger.info(f"  原始指纹: {session.device_fingerprint}")
            logger.info(f"  新指纹: {current_fingerprint}")
            # 更新会话的设备指纹为新的指纹
            session.device_fingerprint = current_fingerprint
            SecureAuthManager.update_session(session_id, session)
        else:
            # 设备指纹差异过大且 IP 地址不同，拒绝访问并撤销会话（安全策略：一个会话只能在一个设备使用）
            logger.error(f"[SECURE_AUTH] 设备指纹差异过大且IP地址不同，可能存在会话劫持或多地使用，拒绝访问并撤销会话")
            logger.error(f"  用户ID: {session.user_id}")
            logger.error(f"  会话ID: {session_id[:8]}...")
            logger.error(f"  IP地址变化: {session.ip_address} -> {current_ip}")
            # 撤销可疑会话
            SecureAuthManager.revoke_session(session_id)
            return None
    
    # ========== 验证User-Agent（作为额外的安全检查）==========
    current_user_agent = request.headers.get("user-agent", "")
    if session.user_agent and current_user_agent and session.user_agent != current_user_agent:
        # User-Agent不匹配，记录警告但不强制拒绝（因为某些浏览器可能会更新User-Agent）
        logger.warning(f"[SECURE_AUTH] User-Agent不匹配 - session: {session_id[:8]}...")
        logger.warning(f"  会话User-Agent: {session.user_agent[:100]}")
        logger.warning(f"  当前User-Agent: {current_user_agent[:100]}")
        # 更新User-Agent（允许浏览器更新）
        session.user_agent = current_user_agent
        SecureAuthManager.update_session(session_id, session)
    
    logger.debug(f"[SECURE_AUTH] 会话验证通过 - session: {session_id[:8]}..., user: {session.user_id}, IP: {current_ip}")
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

def create_user_refresh_token(user_id: str, ip_address: str = "", device_fingerprint: str = "", is_ios_app: bool = False) -> str:
    """创建用户refresh token，绑定IP和设备指纹（只允许一个设备）
    
    Args:
        user_id: 用户ID
        ip_address: IP地址
        device_fingerprint: 设备指纹
        is_ios_app: 是否为iOS应用（iOS应用使用更长的过期时间）
    """
    import secrets
    from datetime import datetime, timedelta
    from app.utils.time_utils import get_utc_time
    
    # 生成refresh token
    refresh_token = secrets.token_urlsafe(32)
    
    # 设置过期时间：iOS应用使用可配置的长期过期时间，其他12小时
    if is_ios_app:
        expire_hours = IOS_SESSION_EXPIRE_HOURS
        logger.info(f"[SECURE_AUTH] iOS 应用 refresh token，过期时间: {expire_hours}小时（{expire_hours // 24}天）")
    else:
        expire_hours = 12  # 12小时
    expire_time = get_utc_time() + timedelta(hours=expire_hours)
    
    # 存储到Redis，包含IP和设备指纹绑定
    if USE_REDIS and redis_client:
        # 删除该用户的所有旧refresh token（只允许一个设备）
        from app.redis_utils import scan_keys
        old_token_pattern = f"user_refresh_token:{user_id}:*"
        old_keys = scan_keys(redis_client, old_token_pattern)
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
            int(expire_hours * 3600),  # 根据设备类型设置TTL
            json.dumps({
                "user_id": user_id,
                "ip_address": ip_address,
                "device_fingerprint": device_fingerprint,
                "created_at": format_iso_utc(get_utc_time()),
                "expires_at": format_iso_utc(expire_time),
                "last_used": None,  # 记录最后使用时间，用于频率限制
                "is_ios_app": is_ios_app  # 记录是否为iOS应用
            })
        )
        logger.info(f"[SECURE_AUTH] 创建用户refresh token: {user_id}, IP: {ip_address}, 设备: {device_fingerprint}, iOS: {is_ios_app}, 过期时间: {expire_hours}小时")
    
    return refresh_token


def verify_user_refresh_token(refresh_token: str, ip_address: str = "", device_fingerprint: str = "", is_ios_app: bool = False) -> Optional[str]:
    """验证用户refresh token，严格检查IP和设备指纹绑定（一个token只能在一个IP、一个设备使用）
    
    Args:
        refresh_token: 刷新令牌
        ip_address: 当前IP地址
        device_fingerprint: 当前设备指纹
        is_ios_app: 是否为iOS应用（iOS应用允许IP变化）
    """
    if not refresh_token:
        logger.debug(f"[SECURE_AUTH] verify_user_refresh_token: refresh_token为空")
        return None
    
    if not USE_REDIS or not redis_client:
        logger.warning(f"[SECURE_AUTH] verify_user_refresh_token: Redis未启用或未连接")
        return None
    
    # 查找refresh token（使用 SCAN 替代 KEYS 避免阻塞 Redis）
    from app.redis_utils import scan_keys
    pattern = f"user_refresh_token:*:{refresh_token}"
    keys = scan_keys(redis_client, pattern)
    
    if not keys:
        # 诊断：检查Redis中该用户是否有任何refresh token
        logger.warning(f"[SECURE_AUTH] verify_user_refresh_token: 未找到refresh token: {refresh_token[:8]}...")
        logger.warning(f"[SECURE_AUTH] 诊断: Redis中查找模式 '{pattern}' 无匹配 - 可能原因: 1)服务器/Redis重启 2)token已过期被清理 3)在其他设备登录导致被删除")
        return None
    
    # 获取token数据
    key_str = keys[0].decode() if isinstance(keys[0], bytes) else keys[0]
    data = safe_redis_get(key_str)
    if not data:
        logger.warning(f"[SECURE_AUTH] verify_user_refresh_token: refresh token数据为空: {refresh_token[:8]}...")
        return None
    
    user_id = data.get('user_id')
    
    # 确定是否为iOS应用（优先使用存储的标志，其次使用传入的参数）
    token_is_ios_app = data.get('is_ios_app', False) or is_ios_app
    # 计算正确的TTL（iOS应用使用可配置的过期时间，其他12小时）
    token_ttl_seconds = IOS_SESSION_EXPIRE_HOURS * 3600 if token_is_ios_app else 12 * 3600
    
    # 检查是否过期
    expires_at_str = data.get('expires_at')
    if expires_at_str:
        expires_at = parse_iso_utc(expires_at_str)
        if get_utc_time() > expires_at:
            # 过期了，删除
            logger.info(f"[SECURE_AUTH] refresh token已过期，删除: {refresh_token[:8]}..., 用户: {user_id}")
            redis_client.delete(key_str)
            return None
    
    # ========== IP地址验证：iOS应用使用更宽松的策略 ==========
    stored_ip = data.get('ip_address', '')
    if not ip_address or ip_address == "unknown":
        # 当前IP地址未知或为空
        if token_is_ios_app:
            # iOS应用允许IP未知的情况（某些网络环境可能无法获取IP）
            logger.info(f"[SECURE_AUTH] refresh token IP地址未知（iOS应用允许）- 用户: {user_id}, 存储IP: {stored_ip}")
        elif stored_ip:
            # 非iOS应用，如果存储了IP但当前IP未知，拒绝访问
            logger.error(f"[SECURE_AUTH] refresh token 当前IP地址未知，拒绝访问并撤销token")
            logger.error(f"  用户ID: {user_id}")
            logger.error(f"  存储IP: {stored_ip}")
            logger.error(f"  当前IP: {ip_address}")
            redis_client.delete(key_str)
            return None
    elif stored_ip and stored_ip != ip_address:
        if token_is_ios_app:
            # iOS应用允许IP地址变化（用户可能切换WiFi/移动网络）
            logger.info(f"[SECURE_AUTH] refresh token IP地址变化（iOS应用允许）- 用户: {user_id}, 存储IP: {stored_ip}, 当前IP: {ip_address}")
            # 更新存储的IP地址为当前IP
            data['ip_address'] = ip_address
            redis_client.setex(key_str, token_ttl_seconds, json.dumps(data))
        else:
            logger.error(f"[SECURE_AUTH] refresh token IP地址不匹配，拒绝访问并撤销token")
            logger.error(f"  用户ID: {user_id}")
            logger.error(f"  存储IP: {stored_ip}")
            logger.error(f"  当前IP: {ip_address}")
            # IP地址不匹配，立即撤销token（安全策略：一个token只能在一个IP使用）
            redis_client.delete(key_str)
            return None
    elif not stored_ip and ip_address:
        # 如果存储的IP为空但当前有IP，更新存储的IP
        logger.info(f"[SECURE_AUTH] refresh token 更新IP地址 - 用户: {user_id}, 当前IP: {ip_address}")
        data['ip_address'] = ip_address
        redis_client.setex(key_str, token_ttl_seconds, json.dumps(data))
    
    # ========== 设备指纹验证：使用相似度检查 ==========
    stored_device = data.get('device_fingerprint', '')
    if not device_fingerprint:
        # 当前设备指纹为空
        if stored_device:
            # 如果存储了设备指纹但当前为空，拒绝访问（可能是请求缺少必要信息）
            logger.error(f"[SECURE_AUTH] refresh token 当前设备指纹为空，拒绝访问并撤销token")
            logger.error(f"  用户ID: {user_id}")
            logger.error(f"  存储设备: {stored_device}")
            redis_client.delete(key_str)
            return None
    elif stored_device and stored_device != device_fingerprint:
        # 检查指纹相似度（允许部分变化）
        # iOS应用使用更宽松的阈值，因为设备指纹可能因系统更新等原因变化
        threshold = 0.4 if token_is_ios_app else 0.7
        
        if is_fingerprint_similar(stored_device, device_fingerprint, threshold):
            logger.info(f"[SECURE_AUTH] refresh token 设备指纹相似 (阈值: {threshold})，允许访问并更新指纹 - 用户: {user_id}")
            # 更新设备指纹
            data['device_fingerprint'] = device_fingerprint
            redis_client.setex(key_str, token_ttl_seconds, json.dumps(data))
        else:
            logger.error(f"[SECURE_AUTH] refresh token 设备指纹差异过大，拒绝访问并撤销token")
            logger.error(f"  用户ID: {user_id}")
            logger.error(f"  存储设备: {stored_device}")
            logger.error(f"  当前设备: {device_fingerprint}")
            logger.error(f"  相似度阈值: {threshold}")
            # 设备指纹差异过大，立即撤销token（安全策略：一个token只能在一个设备使用）
            redis_client.delete(key_str)
            return None
    elif not stored_device and device_fingerprint:
        # 如果存储的设备指纹为空但当前有指纹，更新存储的指纹
        logger.info(f"[SECURE_AUTH] refresh token 更新设备指纹 - 用户: {user_id}, 当前设备: {device_fingerprint}")
        data['device_fingerprint'] = device_fingerprint
        redis_client.setex(key_str, token_ttl_seconds, json.dumps(data))
    
    # 检查频率限制（20分钟内最多使用一次）
    last_used_str = data.get('last_used')
    if last_used_str:
        last_used = parse_iso_utc(last_used_str)
        if get_utc_time() - last_used < timedelta(minutes=20):
            logger.warning(f"[SECURE_AUTH] refresh token 使用过于频繁: {refresh_token[:8]}..., 用户: {user_id}")
            return None
    
    # 更新最后使用时间
    current_time = get_utc_time()
    data['last_used'] = format_iso_utc(current_time)
    redis_client.setex(key_str, token_ttl_seconds, json.dumps(data))
    
    logger.debug(f"[SECURE_AUTH] refresh token验证通过 - 用户: {user_id}, IP: {ip_address}, iOS: {token_is_ios_app}")
    return user_id


def revoke_user_refresh_token(refresh_token: str) -> bool:
    """撤销用户refresh token"""
    if not refresh_token or not USE_REDIS or not redis_client:
        return False
    
    # 查找并删除refresh token（使用 SCAN 替代 KEYS）
    from app.redis_utils import scan_keys
    pattern = f"user_refresh_token:*:{refresh_token}"
    keys = scan_keys(redis_client, pattern)

    if keys:
        redis_client.delete(*keys)
        logger.info(f"[SECURE_AUTH] 撤销用户refresh token: {refresh_token}")
        return True

    return False


def revoke_all_user_refresh_tokens(user_id: str) -> int:
    """撤销用户所有refresh token"""
    if not USE_REDIS or not redis_client:
        return 0

    from app.redis_utils import scan_keys
    pattern = f"user_refresh_token:{user_id}:*"
    keys = scan_keys(redis_client, pattern)
    
    if keys:
        count = redis_client.delete(*keys)
        logger.info(f"[SECURE_AUTH] 撤销用户所有refresh token: {user_id}, 删除数量: {count}")
        return count
    
    return 0


## 已删除未使用的 cleanup_expired_sessions_aggressive 函数
# Redis TTL 机制会自动处理会话过期，无需手动清理
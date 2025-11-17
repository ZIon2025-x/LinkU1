"""
客服独立认证系统
实现客服专用的会话管理和认证
"""

import os
import json
import secrets
import hashlib
import time
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging

from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# 配置
from app.config import get_settings
settings = get_settings()

SERVICE_SESSION_EXPIRE_HOURS = int(os.getenv("SERVICE_SESSION_EXPIRE_HOURS", "6"))  # 客服会话6小时
SERVICE_MAX_ACTIVE_SESSIONS = int(os.getenv("SERVICE_MAX_ACTIVE_SESSIONS", "2"))  # 客服最多2个活跃会话

# 会话存储
try:
    from app.redis_cache import get_redis_client
    redis_client = get_redis_client()
    USE_REDIS = redis_client is not None
    logger.info(f"[SERVICE_AUTH] Redis连接状态 - USE_REDIS: {USE_REDIS}")
except Exception as e:
    logger.error(f"[SERVICE_AUTH] Redis连接异常: {e}")
    USE_REDIS = False
    redis_client = None

def safe_redis_get(key: str) -> Optional[dict]:
    """安全地从 Redis 获取 JSON 数据"""
    if not redis_client:
        logger.warning(f"[SERVICE_AUTH] Redis客户端不可用，无法获取key: {key}")
        return None
    
    try:
        data = redis_client.get(key)
        if not data:
            logger.debug(f"[SERVICE_AUTH] Redis中未找到key: {key}")
            return None
        
        # RedisCache使用decode_responses=False，所以data是bytes
        if isinstance(data, bytes):
            data = data.decode('utf-8')
        
        try:
            result = json.loads(data)
            logger.debug(f"[SERVICE_AUTH] 成功从Redis获取数据: {key}")
            return result
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            logger.error(f"[SERVICE_AUTH] JSON解码失败 key={key}: {e}")
            return None
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] Redis获取数据失败 key={key}: {e}")
        return None

def safe_redis_set(key: str, value: dict, expire_seconds: Optional[int] = None):
    """安全地向 Redis 设置 JSON 数据"""
    if not redis_client:
        logger.warning(f"[SERVICE_AUTH] Redis客户端不可用，无法设置key: {key}")
        return False
    
    try:
        json_data = json.dumps(value)
        if expire_seconds:
            redis_client.setex(key, expire_seconds, json_data)
        else:
            redis_client.set(key, json_data)
        logger.debug(f"[SERVICE_AUTH] 成功设置Redis数据: {key}")
        return True
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] Redis设置数据失败 key={key}: {e}")
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
service_active_sessions: Dict[str, 'ServiceSessionInfo'] = {}

@dataclass
class ServiceSessionInfo:
    """客服会话信息"""
    session_id: str
    service_id: str
    created_at: datetime
    last_activity: datetime
    device_fingerprint: str
    ip_address: str
    user_agent: str
    is_active: bool = True

class ServiceAuthManager:
    """客服认证管理器"""
    
    @staticmethod
    def generate_session_id() -> str:
        """生成客服会话ID"""
        return f"service_session_{secrets.token_urlsafe(32)}"
    
    @staticmethod
    def get_device_fingerprint(request: Request) -> str:
        """获取设备指纹"""
        user_agent = request.headers.get("user-agent", "")
        accept_language = request.headers.get("accept-language", "")
        accept_encoding = request.headers.get("accept-encoding", "")
        
        fingerprint_data = f"{user_agent}|{accept_language}|{accept_encoding}"
        return hashlib.sha256(fingerprint_data.encode()).hexdigest()[:16]
    
    @staticmethod
    def _get_active_sessions(service_id: str) -> List[ServiceSessionInfo]:
        """获取指定客服的活跃会话"""
        active_sessions = []
        
        if USE_REDIS and redis_client:
            try:
                # 查找所有该客服的会话
                pattern = f"service_session:{service_id}:*"
                keys = redis_client.keys(pattern)
                
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    data = safe_redis_get(key_str)
                    if data and data.get('is_active', True):
                        # 检查是否过期
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            last_activity = datetime.fromisoformat(last_activity_str)
                            if get_utc_time() - last_activity <= timedelta(hours=SERVICE_SESSION_EXPIRE_HOURS):
                                # 转换为ServiceSessionInfo对象
                                session_info = ServiceSessionInfo(
                                    session_id=data['session_id'],
                                    service_id=data['service_id'],
                                    created_at=datetime.fromisoformat(data['created_at']),
                                    last_activity=datetime.fromisoformat(last_activity_str),
                                    device_fingerprint=data.get('device_fingerprint', ''),
                                    ip_address=data.get('ip_address', ''),
                                    user_agent=data.get('user_agent', ''),
                                    is_active=data.get('is_active', True)
                                )
                                active_sessions.append(session_info)
            except Exception as e:
                logger.error(f"[SERVICE_AUTH] 获取活跃会话失败: {e}")
        
        return active_sessions
    
    @staticmethod
    def _revoke_session(session_id: str) -> bool:
        """撤销指定会话"""
        try:
            if USE_REDIS and redis_client:
                # 查找并删除会话
                pattern = f"service_session:*:{session_id}"
                keys = redis_client.keys(pattern)
                
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    redis_client.delete(key_str)
                    logger.info(f"[SERVICE_AUTH] 撤销会话: {session_id}")
                    return True
            return False
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 撤销会话失败: {e}")
            return False
    
    @staticmethod
    def create_session(service_id: str, request: Request) -> ServiceSessionInfo:
        """创建客服会话（优化版：支持会话复用和数量限制）"""
        current_time = get_utc_time()
        
        # 获取客户端信息 - 使用统一的IP获取方法
        from app.security import get_client_ip
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        device_fingerprint = ServiceAuthManager.get_device_fingerprint(request)
        
        # 1. 检查现有活跃会话
        existing_sessions = ServiceAuthManager._get_active_sessions(service_id)
        
        # 2. 如果存在活跃会话，优先复用（相同设备指纹）
        for session in existing_sessions:
            if (session.device_fingerprint == device_fingerprint and 
                session.ip_address == client_ip and
                session.is_active):
                # 更新最后活动时间
                session.last_activity = current_time
                ServiceAuthManager._store_session(session)
                logger.info(f"[SERVICE_AUTH] 复用现有客服会话: {service_id}, session_id: {session.session_id[:8]}...")
                return session
        
        # 3. 检查会话数量限制（最多3个活跃会话）
        if len(existing_sessions) >= 3:
            # 清理最旧的会话
            oldest_session = min(existing_sessions, key=lambda s: s.created_at)
            ServiceAuthManager._revoke_session(oldest_session.session_id)
            logger.info(f"[SERVICE_AUTH] 清理最旧会话: {oldest_session.session_id[:8]}...")
        
        # 4. 创建新会话
        session_id = ServiceAuthManager.generate_session_id()
        session_info = ServiceSessionInfo(
            session_id=session_id,
            service_id=service_id,
            created_at=current_time,
            last_activity=current_time,
            device_fingerprint=device_fingerprint,
            ip_address=client_ip,
            user_agent=user_agent
        )
        
        # 存储会话
        ServiceAuthManager._store_session(session_info)
        
        # 清理过期会话
        ServiceAuthManager._cleanup_expired_sessions(service_id)
        
        logger.info(f"[SERVICE_AUTH] 创建新客服会话: {service_id}, session_id: {session_id[:8]}...")
        return session_info
    
    @staticmethod
    def get_session(session_id: str, update_activity: bool = True) -> Optional[ServiceSessionInfo]:
        """获取客服会话"""
        if not session_id:
            return None
        
        # 从Redis或内存获取会话
        session_data = ServiceAuthManager._get_session_data(session_id)
        if not session_data:
            return None
        
        # 检查会话是否过期
        if ServiceAuthManager._is_session_expired(session_data):
            ServiceAuthManager._delete_session(session_id)
            return None
        
        # 更新活动时间
        if update_activity:
            session_data['last_activity'] = get_utc_time().isoformat()
            ServiceAuthManager._store_session_data(session_id, session_data)
        
        # 转换字符串日期时间为datetime对象
        if 'created_at' in session_data and isinstance(session_data['created_at'], str):
            session_data['created_at'] = datetime.fromisoformat(session_data['created_at'])
        if 'last_activity' in session_data and isinstance(session_data['last_activity'], str):
            session_data['last_activity'] = datetime.fromisoformat(session_data['last_activity'])
        
        return ServiceSessionInfo(**session_data)
    
    @staticmethod
    def delete_session(session_id: str) -> bool:
        """删除客服会话"""
        return ServiceAuthManager._delete_session(session_id)
    
    @staticmethod
    def delete_all_sessions(service_id: str) -> int:
        """删除客服的所有会话"""
        deleted_count = 0
        
        if USE_REDIS and redis_client:
            # 从Redis删除
            pattern = f"service_session:{service_id}:*"
            keys = redis_client.keys(pattern)
            if keys:
                deleted_count = redis_client.delete(*keys)
        else:
            # 从内存删除
            keys_to_delete = [sid for sid, session in service_active_sessions.items() 
                            if session.service_id == service_id]
            for sid in keys_to_delete:
                del service_active_sessions[sid]
                deleted_count += 1
        
        logger.info(f"[SERVICE_AUTH] 删除客服所有会话: {service_id}, 删除数量: {deleted_count}")
        return deleted_count
    
    @staticmethod
    def _store_session(session_info: ServiceSessionInfo):
        """存储会话信息"""
        session_data = {
            'session_id': session_info.session_id,
            'service_id': session_info.service_id,
            'created_at': session_info.created_at.isoformat() if session_info.created_at else None,
            'last_activity': session_info.last_activity.isoformat() if session_info.last_activity else None,
            'device_fingerprint': session_info.device_fingerprint,
            'ip_address': session_info.ip_address,
            'user_agent': session_info.user_agent,
            'is_active': session_info.is_active
        }
        
        ServiceAuthManager._store_session_data(session_info.session_id, session_data)
    
    @staticmethod
    def _store_session_data(session_id: str, session_data: dict):
        """存储会话数据到Redis或内存"""
        try:
            if USE_REDIS:
                key = f"service_session:{session_data['service_id']}:{session_id}"
                expire_seconds = SERVICE_SESSION_EXPIRE_HOURS * 3600
                success = safe_redis_set(key, session_data, expire_seconds)
                if not success:
                    logger.warning(f"[SERVICE_AUTH] Redis存储失败，回退到内存存储: {session_id[:8]}...")
                    service_active_sessions[session_id] = ServiceSessionInfo(**session_data)
            else:
                service_active_sessions[session_id] = ServiceSessionInfo(**session_data)
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 存储会话数据失败: {e}")
            # 回退到内存存储
            try:
                service_active_sessions[session_id] = ServiceSessionInfo(**session_data)
                logger.info(f"[SERVICE_AUTH] 已回退到内存存储: {session_id[:8]}...")
            except Exception as e2:
                logger.error(f"[SERVICE_AUTH] 内存存储也失败: {e2}")
    
    @staticmethod
    def _get_session_data(session_id: str) -> Optional[dict]:
        """从Redis或内存获取会话数据"""
        try:
            if USE_REDIS and redis_client:
                # 从Redis查找
                pattern = f"service_session:*:{session_id}"
                logger.debug(f"[SERVICE_AUTH] 查找会话数据 - pattern: {pattern}")
                keys = redis_client.keys(pattern)
                logger.debug(f"[SERVICE_AUTH] 找到的keys: {keys}")
                if keys:
                    result = safe_redis_get(keys[0])
                    logger.debug(f"[SERVICE_AUTH] 获取到的会话数据: {result}")
                    if result:
                        return result
                    else:
                        logger.warning(f"[SERVICE_AUTH] Redis数据获取失败，尝试内存查找")
                else:
                    logger.debug(f"[SERVICE_AUTH] Redis中未找到匹配的会话数据，尝试内存查找")
                
                # 如果Redis中没有找到，尝试从内存查找
                session = service_active_sessions.get(session_id)
                if session:
                    logger.debug(f"[SERVICE_AUTH] 从内存找到会话数据: {session_id[:8]}...")
                    return {
                        'session_id': session.session_id,
                        'service_id': session.service_id,
                        'created_at': session.created_at.isoformat() if session.created_at else None,
                        'last_activity': session.last_activity.isoformat() if session.last_activity else None,
                        'device_fingerprint': session.device_fingerprint,
                        'ip_address': session.ip_address,
                        'user_agent': session.user_agent,
                        'is_active': session.is_active
                    }
                
                logger.debug(f"[SERVICE_AUTH] 内存中也没有找到会话数据: {session_id[:8]}...")
                return None
            else:
                # 从内存查找
                session = service_active_sessions.get(session_id)
                if session:
                    return {
                        'session_id': session.session_id,
                        'service_id': session.service_id,
                        'created_at': session.created_at.isoformat() if session.created_at else None,
                        'last_activity': session.last_activity.isoformat() if session.last_activity else None,
                        'device_fingerprint': session.device_fingerprint,
                        'ip_address': session.ip_address,
                        'user_agent': session.user_agent,
                        'is_active': session.is_active
                    }
                return None
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 获取会话数据失败: {e}")
            # 回退到内存查找
            try:
                session = service_active_sessions.get(session_id)
                if session:
                    return {
                        'session_id': session.session_id,
                        'service_id': session.service_id,
                        'created_at': session.created_at.isoformat() if session.created_at else None,
                        'last_activity': session.last_activity.isoformat() if session.last_activity else None,
                        'device_fingerprint': session.device_fingerprint,
                        'ip_address': session.ip_address,
                        'user_agent': session.user_agent,
                        'is_active': session.is_active
                    }
            except Exception as e2:
                logger.error(f"[SERVICE_AUTH] 内存查找也失败: {e2}")
            return None
    
    @staticmethod
    def _delete_session(session_id: str) -> bool:
        """删除会话"""
        if USE_REDIS and redis_client:
            pattern = f"service_session:*:{session_id}"
            keys = redis_client.keys(pattern)
            if keys:
                return safe_redis_delete(keys[0])
            return False
        else:
            if session_id in service_active_sessions:
                del service_active_sessions[session_id]
                return True
            return False
    
    @staticmethod
    def _is_session_expired(session_data: dict) -> bool:
        """检查会话是否过期"""
        try:
            last_activity = datetime.fromisoformat(session_data['last_activity'])
            expire_time = last_activity + timedelta(hours=SERVICE_SESSION_EXPIRE_HOURS)
            current_time = get_utc_time()
            is_expired = current_time > expire_time
            
            logger.debug(f"[SERVICE_AUTH] 会话过期检查 - last_activity: {last_activity}, expire_time: {expire_time}, current_time: {current_time}, is_expired: {is_expired}")
            return is_expired
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 会话过期检查失败: {e}")
            return True  # 如果检查失败，认为已过期
    
    @staticmethod
    def cleanup_expired_sessions():
        """清理过期会话（公共方法）"""
        try:
            if USE_REDIS and redis_client:
                # 主动清理Redis中的过期会话
                pattern = "service_session:*"
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
                                if get_utc_time() - last_activity > timedelta(hours=SERVICE_SESSION_EXPIRE_HOURS):
                                    # 删除过期会话
                                    redis_client.delete(key_str)
                                    cleaned_count += 1
                
                logger.info(f"[SERVICE_AUTH] Redis清理了 {cleaned_count} 个过期会话")
            else:
                # 清理内存中的过期会话
                current_time = get_utc_time()
                expired_sessions = []
                
                for session_id, session in service_active_sessions.items():
                    # 确保last_activity是datetime对象
                    if isinstance(session.last_activity, str):
                        last_activity = datetime.fromisoformat(session.last_activity)
                    else:
                        last_activity = session.last_activity
                    
                    expire_time = last_activity + timedelta(hours=SERVICE_SESSION_EXPIRE_HOURS)
                    if current_time > expire_time:
                        expired_sessions.append(session_id)
                
                for session_id in expired_sessions:
                    del service_active_sessions[session_id]
                
                logger.info(f"[SERVICE_AUTH] 内存清理了 {len(expired_sessions)} 个过期会话")
                
        except Exception as e:
            logger.error(f"[SERVICE_AUTH] 清理过期会话失败: {e}")

    @staticmethod
    def _cleanup_expired_sessions(service_id: str):
        """清理特定客服的过期会话（私有方法）"""
        if USE_REDIS:
            # Redis会自动过期，无需手动清理
            pass
        else:
            # 清理内存中的过期会话
            current_time = get_utc_time()
            expired_sessions = []
            
            for session_id, session in service_active_sessions.items():
                if session.service_id == service_id:
                    # 确保last_activity是datetime对象
                    if isinstance(session.last_activity, str):
                        last_activity = datetime.fromisoformat(session.last_activity)
                    else:
                        last_activity = session.last_activity
                    
                    expire_time = last_activity + timedelta(hours=SERVICE_SESSION_EXPIRE_HOURS)
                    if current_time > expire_time:
                        expired_sessions.append(session_id)
            
            for session_id in expired_sessions:
                del service_active_sessions[session_id]

def create_service_session(service_id: str, request: Request) -> str:
    """创建客服会话并返回会话ID"""
    session_info = ServiceAuthManager.create_session(service_id, request)
    return session_info.session_id

def validate_service_session(request: Request) -> Optional[ServiceSessionInfo]:
    """验证客服会话（最高安全等级）"""
    logger.debug(f"[SERVICE_AUTH] validate_service_session - URL: {request.url}")
    logger.debug(f"[SERVICE_AUTH] validate_service_session - Cookies: {dict(request.cookies)}")
    
    # 获取客服会话Cookie
    service_session_id = request.cookies.get("service_session_id")
    
    if not service_session_id:
        logger.debug("[SERVICE_AUTH] 未找到service_session_id")
        return None
    
    logger.debug(f"[SERVICE_AUTH] 找到service_session_id: {service_session_id[:8]}...")
    
    # 验证会话
    logger.debug(f"[SERVICE_AUTH] 开始验证会话: {service_session_id[:8]}...")
    session = ServiceAuthManager.get_session(service_session_id, update_activity=False)
    if not session:
        logger.warning(f"[SERVICE_AUTH] 客服会话验证失败: {service_session_id[:8]}...")
        return None
    logger.debug(f"[SERVICE_AUTH] 会话验证成功: {session.service_id}")
    
    # 验证会话是否仍然活跃
    if not session.is_active:
        logger.warning(f"[SERVICE_AUTH] 客服会话已失效: {session.service_id}")
        return None
    
    # 验证设备指纹（用于检测会话劫持）- 暂时禁用严格验证
    current_fingerprint = ServiceAuthManager.get_device_fingerprint(request)
    if session.device_fingerprint != current_fingerprint:
        logger.warning(f"[SERVICE_AUTH] 设备指纹不匹配: {session.service_id}, 会话指纹: {session.device_fingerprint[:8]}..., 当前指纹: {current_fingerprint[:8]}...")
        # 暂时不强制登出，只记录警告
        # ServiceAuthManager.delete_session(service_session_id)
        # return None
    
    # 验证IP地址（可选，用于检测异常登录）- 使用统一的IP获取方法
    from app.security import get_client_ip
    current_ip = get_client_ip(request)
    if session.ip_address != current_ip:
        logger.warning(f"[SERVICE_AUTH] IP地址不匹配: 会话IP={session.ip_address}, 当前IP={current_ip}")
        # 可以选择是否强制登出
        # ServiceAuthManager.delete_session(service_session_id)
        # return None
    
    logger.debug(f"[SERVICE_AUTH] 客服会话验证成功: {service_session_id[:8]}..., 客服: {session.service_id}")
    return session

def create_service_session_cookie(response: Response, session_id: str, user_agent: str = "", service_id: Optional[str] = None, request: Optional[Request] = None) -> Response:
    """创建客服会话Cookie（完全按照用户登录的方式）"""
    from app.cookie_manager import CookieManager
    
    try:
        # 生成简单的refresh token（和用户一样）
        refresh_token = None
        if service_id:
            try:
                # 使用简单的随机字符串，和用户refresh token一样
                refresh_token = secrets.token_urlsafe(32)
                
                # 保存refresh token到Redis，绑定IP和设备指纹
                if USE_REDIS and redis_client and request:
                    from app.secure_auth import get_client_ip, get_device_fingerprint
                    refresh_data = {
                        "service_id": service_id,
                        "ip_address": get_client_ip(request),
                        "device_fingerprint": get_device_fingerprint(request),
                        "created_at": get_utc_time().isoformat(),
                        "expires_at": (get_utc_time() + timedelta(hours=12)).isoformat(),
                        "last_used": None  # 记录最后使用时间，用于频率限制
                    }
                    redis_client.setex(
                        f"service_refresh_token:{refresh_token}",
                        12 * 3600,  # 12小时TTL
                        json.dumps(refresh_data)
                    )
                    logger.info(f"[SERVICE_AUTH] 客服refresh token已保存到Redis: {service_id}")
                
                logger.info(f"[SERVICE_AUTH] 生成客服refresh token: {service_id}")
            except Exception as e:
                logger.warning(f"[SERVICE_AUTH] 生成refresh token失败: {e}")
        
        # 不混入用户Cookie，只设置客服专用的Cookie
        # 直接设置客服会话Cookie，不使用CookieManager避免混入用户Cookie
        
        from app.config import get_settings
        settings = get_settings()
        
        # 确保samesite值有效
        samesite_value = settings.COOKIE_SAMESITE if settings.COOKIE_SAMESITE in ["lax", "strict", "none"] else "lax"
        # 类型转换
        from typing import Literal
        from app.utils.time_utils import get_utc_time
        samesite_literal: Literal["lax", "strict", "none"] = samesite_value  # type: ignore
        
        # 只使用API域名，不设置domain属性
        # 确保cookie只绑定到api.link2ur.com
        cookie_domain = None
        
        # 设置客服会话Cookie - HttpOnly，后端验证用
        response.set_cookie(
            key="service_session_id",
            value=session_id,
            max_age=SERVICE_SESSION_EXPIRE_HOURS * 3600,  # 12小时
            httponly=True,  # 防止XSS攻击
            secure=settings.COOKIE_SECURE,
            samesite=samesite_literal,
            path="/",
            domain=cookie_domain  # 跨子域名支持
        )
        
        # 设置客服ID Cookie（用于refresh token验证）
        if service_id:
            response.set_cookie(
                key="service_id",
                value=service_id,
                max_age=SERVICE_SESSION_EXPIRE_HOURS * 3600,  # 12小时
                httponly=True,  # 防止XSS攻击
                secure=settings.COOKIE_SECURE,
                samesite=samesite_literal,
                path="/",
                domain=cookie_domain
            )
        
        # 设置客服refresh token Cookie（如果生成了）
        # service_refresh_token 使用 SameSite=None 以支持跨域请求
        if refresh_token:
            response.set_cookie(
                key="service_refresh_token",
                value=refresh_token,
                max_age=12 * 3600,  # 12小时，与JWT过期时间一致
                httponly=True,  # 防止XSS攻击
                secure=True,  # SameSite=None 必须使用 Secure
                samesite="none",  # 仅 service_refresh_token 使用 none
                path="/",
                domain=cookie_domain
            )
        
        # 前端不需要检测Cookie，所以不设置这些标识Cookie
        # 客服认证完全由后端HttpOnly Cookie处理
        
        logger.info(f"[SERVICE_AUTH] 客服Cookie设置成功: session_id={session_id[:8]}..., service_id={service_id}, refresh_token={'是' if refresh_token else '否'}")
        return response
        
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服Cookie设置失败: {e}")
        # 即使Cookie设置失败，也返回响应，避免500错误
        return response

def clear_service_session_cookie(response: Response) -> Response:
    """清除客服会话Cookie（清除所有客服相关Cookie）"""
    try:
        # 只使用API域名，不设置domain属性
        cookie_domain = None
        
        # 清除所有客服相关的Cookie
        response.delete_cookie("service_session_id", path="/", domain=cookie_domain)
        response.delete_cookie("service_refresh_token", path="/", domain=cookie_domain)
        response.delete_cookie("service_id", path="/", domain=cookie_domain)
        response.delete_cookie("csrf_token", path="/", domain=cookie_domain)
        
        logger.info(f"[SERVICE_AUTH] 客服Cookie清除成功")
        return response
        
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 客服Cookie清除失败: {e}")
        return response

def verify_service_refresh_token(refresh_token: str, ip_address: str = "", device_fingerprint: str = "") -> Optional[str]:
    """验证客服refresh token，检查IP和设备指纹绑定"""
    try:
        if not USE_REDIS or not redis_client:
            return None
        
        # 从Redis获取refresh token数据
        data = safe_redis_get(f"service_refresh_token:{refresh_token}")
        if not data:
            return None
        
        # 检查是否过期
        expires_at_str = data.get('expires_at')
        if expires_at_str:
            expires_at = datetime.fromisoformat(expires_at_str)
            if get_utc_time() > expires_at:
                # 过期了，删除
                redis_client.delete(f"service_refresh_token:{refresh_token}")
                return None
        
        # 检查IP绑定
        stored_ip = data.get('ip_address', '')
        if stored_ip and ip_address and stored_ip != ip_address:
            logger.warning(f"[SERVICE_AUTH] 客服refresh token IP不匹配: 存储={stored_ip}, 当前={ip_address}")
            return None
        
        # 检查设备指纹绑定
        stored_device = data.get('device_fingerprint', '')
        if stored_device and device_fingerprint and stored_device != device_fingerprint:
            logger.warning(f"[SERVICE_AUTH] 客服refresh token 设备指纹不匹配: 存储={stored_device}, 当前={device_fingerprint}")
            return None
        
        # 检查频率限制（20分钟内最多使用一次）
        last_used_str = data.get('last_used')
        if last_used_str:
            last_used = datetime.fromisoformat(last_used_str)
            if get_utc_time() - last_used < timedelta(minutes=20):
                logger.warning(f"[SERVICE_AUTH] 客服refresh token 使用过于频繁: {refresh_token}")
                return None
        
        # 更新最后使用时间
        current_time = get_utc_time()
        data['last_used'] = current_time.isoformat()
        redis_client.setex(f"service_refresh_token:{refresh_token}", 12 * 3600, json.dumps(data))
        
        return data.get('service_id')
        
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 验证refresh token失败: {e}")
        return None

def revoke_service_refresh_token(refresh_token: str) -> bool:
    """撤销客服refresh token"""
    try:
        if USE_REDIS and redis_client:
            return redis_client.delete(f"service_refresh_token:{refresh_token}") > 0
        return False
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 撤销refresh token失败: {e}")
        return False

def revoke_all_service_refresh_tokens(service_id: str) -> int:
    """撤销客服所有refresh token"""
    try:
        if not USE_REDIS or not redis_client:
            return 0
        
        pattern = f"service_refresh_token:{service_id}:*"
        keys = redis_client.keys(pattern)
        
        if keys:
            count = redis_client.delete(*keys)
            logger.info(f"[SERVICE_AUTH] 撤销客服所有refresh token: {service_id}, 删除数量: {count}")
            return count
        
        return 0
    except Exception as e:
        logger.error(f"[SERVICE_AUTH] 撤销客服所有refresh token失败: {e}")
        return 0
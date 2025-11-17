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

from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc

logger = logging.getLogger(__name__)

# 配置
from app.config import get_settings
settings = get_settings()

ADMIN_SESSION_EXPIRE_HOURS = int(os.getenv("ADMIN_SESSION_EXPIRE_HOURS", "2"))  # 管理员会话2小时
ADMIN_MAX_ACTIVE_SESSIONS = int(os.getenv("ADMIN_MAX_ACTIVE_SESSIONS", "1"))  # 管理员最多1个活跃会话（安全要求）

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
        """创建管理员会话（带会话数量限制）"""
        session_id = AdminAuthManager.generate_session_id()
        current_time = get_utc_time()
        
        # 获取客户端信息 - 使用统一的IP获取方法
        from app.security import get_client_ip
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        device_fingerprint = AdminAuthManager.get_device_fingerprint(request)
        
        # 清理过期会话（先清理，再检查数量）
        AdminAuthManager._cleanup_expired_sessions(admin_id)
        
        # 安全检查：每个管理员最多只能有1个活跃会话
        # 创建新会话前，删除该管理员的所有旧会话（包括活跃和未过期的）
        active_sessions = AdminAuthManager._get_active_sessions(admin_id)
        if len(active_sessions) > 0:
            # 删除该管理员的所有现有会话（安全策略：单会话登录）
            deleted_count = AdminAuthManager.delete_all_sessions(admin_id)
            logger.warning(f"[ADMIN_AUTH] 安全策略：管理员 {admin_id} 已有 {len(active_sessions)} 个活跃会话，创建新会话前已删除所有旧会话（共 {deleted_count} 个）")
        
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
        
        logger.info(f"[ADMIN_AUTH] 创建管理员会话: {admin_id}, session_id: {session_id[:8]}..., 当前活跃会话数: {len(AdminAuthManager._get_active_sessions(admin_id))}")
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
            session_data['last_activity'] = format_iso_utc(get_utc_time())
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
            'created_at': format_iso_utc(session_info.created_at) if session_info.created_at else None,
            'last_activity': format_iso_utc(session_info.last_activity) if session_info.last_activity else None,
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
                    'created_at': format_iso_utc(session.created_at) if session.created_at else None,
                    'last_activity': format_iso_utc(session.last_activity) if session.last_activity else None,
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
        last_activity = parse_iso_utc(session_data['last_activity'])
        expire_time = last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
        return get_utc_time() > expire_time
    
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
                                last_activity = parse_iso_utc(last_activity_str)
                                if get_utc_time() - last_activity > timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS):
                                    # 删除过期会话
                                    redis_client.delete(key_str)
                                    cleaned_count += 1
                
                logger.info(f"[ADMIN_AUTH] Redis清理了 {cleaned_count} 个过期会话")
            else:
                # 清理内存中的过期会话
                current_time = get_utc_time()
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
            # Redis会自动过期，但我们可以手动清理标记为不活跃的会话
            pattern = f"admin_session:{admin_id}:*"
            keys = redis_client.keys(pattern)
            cleaned_count = 0
            
            for key in keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                data = safe_redis_get(key_str)
                if data:
                    # 检查是否被标记为不活跃
                    if not data.get('is_active', True):
                        redis_client.delete(key_str)
                        cleaned_count += 1
                    else:
                        # 检查时间过期
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            try:
                                last_activity = parse_iso_utc(last_activity_str)
                                if get_utc_time() - last_activity > timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS):
                                    redis_client.delete(key_str)
                                    cleaned_count += 1
                            except (ValueError, TypeError):
                                pass
            
            if cleaned_count > 0:
                logger.info(f"[ADMIN_AUTH] 清理了 {cleaned_count} 个过期会话（管理员: {admin_id}）")
        else:
            # 清理内存中的过期会话
            current_time = get_utc_time()
            expired_sessions = []
            
            for session_id, session in admin_active_sessions.items():
                if session.admin_id == admin_id:
                    expire_time = session.last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
                    if current_time > expire_time:
                        expired_sessions.append(session_id)
            
            for session_id in expired_sessions:
                del admin_active_sessions[session_id]
    
    @staticmethod
    def _get_active_sessions(admin_id: str) -> list:
        """获取管理员的活跃会话列表"""
        active_sessions = []
        
        if USE_REDIS:
            pattern = f"admin_session:{admin_id}:*"
            keys = redis_client.keys(pattern)
            
            for key in keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                data = safe_redis_get(key_str)
                if data:
                    # 检查会话是否有效
                    is_active = data.get('is_active', True)
                    if is_active:
                        # 检查是否过期
                        last_activity_str = data.get('last_activity', data.get('created_at'))
                        if last_activity_str:
                            try:
                                last_activity = parse_iso_utc(last_activity_str)
                                if get_utc_time() - last_activity <= timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS):
                                    active_sessions.append(data)
                            except (ValueError, TypeError):
                                pass
        else:
            # 从内存获取
            current_time = get_utc_time()
            for session_id, session in admin_active_sessions.items():
                if session.admin_id == admin_id and session.is_active:
                    expire_time = session.last_activity + timedelta(hours=ADMIN_SESSION_EXPIRE_HOURS)
                    if current_time <= expire_time:
                        active_sessions.append({
                            'session_id': session.session_id,
                            'admin_id': session.admin_id,
                            'created_at': format_iso_utc(session.created_at) if session.created_at else None,
                            'last_activity': format_iso_utc(session.last_activity) if session.last_activity else None,
                        })
        
        return active_sessions

def create_admin_session(admin_id: str, request: Request) -> str:
    """创建管理员会话并返回会话ID"""
    session_info = AdminAuthManager.create_session(admin_id, request)
    return session_info.session_id

def validate_admin_session(request: Request) -> Optional[AdminSessionInfo]:
    """验证管理员会话（最高安全等级）"""
    logger.debug(f"[ADMIN_AUTH] validate_admin_session - URL: {request.url}")
    
    # 获取管理员会话Cookie
    admin_session_id = request.cookies.get("admin_session_id")
    
    if not admin_session_id:
        logger.debug("[ADMIN_AUTH] 未找到admin_session_id")
        return None
    
    logger.debug(f"[ADMIN_AUTH] 找到admin_session_id: {admin_session_id[:8]}...")
    
    # 验证会话
    session = AdminAuthManager.get_session(admin_session_id, update_activity=False)
    if not session:
        logger.debug(f"[ADMIN_AUTH] 管理员会话验证失败: {admin_session_id[:8]}...")
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
        logger.debug(f"[ADMIN_AUTH] IP地址不匹配: 会话IP={session.ip_address}, 当前IP={current_ip}")
        # 可以选择是否强制登出
        # AdminAuthManager.delete_session(admin_session_id)
        # return None
    
    logger.debug(f"[ADMIN_AUTH] 管理员会话验证成功: {admin_session_id[:8]}..., 管理员: {session.admin_id}")
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
    
    logger.debug(f"[ADMIN_AUTH] 设置管理员Cookie - session_id: {session_id[:8]}..., secure: {Config.COOKIE_SECURE}, samesite: {samesite_value}, domain: {cookie_domain}")
    logger.debug(f"[ADMIN_AUTH] 管理员Cookie设置完成 - admin_session_id 和 admin_authenticated")
    
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

def create_admin_refresh_token(admin_id: str, ip_address: str = "", device_fingerprint: str = "") -> str:
    """创建管理员refresh token，绑定IP和设备指纹"""
    import secrets
    from datetime import datetime, timedelta
    
    # 生成refresh token
    refresh_token = secrets.token_urlsafe(32)
    
    # 设置过期时间（12小时）
    expire_time = get_utc_time() + timedelta(hours=12)
    
    # 存储到Redis，包含IP和设备指纹绑定
    if USE_REDIS:
        redis_key = f"admin_refresh_token:{admin_id}:{refresh_token}"
        redis_client.setex(
            redis_key, 
            int(12 * 3600),  # 12小时
            json.dumps({
                "admin_id": admin_id,
                "ip_address": ip_address,
                "device_fingerprint": device_fingerprint,
                "created_at": format_iso_utc(get_utc_time()),
                "expires_at": format_iso_utc(expire_time),
                "last_used": None  # 记录最后使用时间，用于频率限制
            })
        )
    
    logger.debug(f"[ADMIN_AUTH] 创建管理员refresh token: {admin_id}, IP: {ip_address}, 设备: {device_fingerprint}")
    return refresh_token


def verify_admin_refresh_token(refresh_token: str, ip_address: str = "", device_fingerprint: str = "") -> Optional[str]:
    """验证管理员refresh token，检查IP和设备指纹绑定"""
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
        expires_at = parse_iso_utc(token_data['expires_at'])
        if get_utc_time() > expires_at:
            # 过期了，删除token
            redis_client.delete(keys[0])
            return None
    except (ValueError, KeyError):
        return None
    
    # 检查IP绑定
    stored_ip = token_data.get('ip_address', '')
    if stored_ip and ip_address and stored_ip != ip_address:
        logger.warning(f"[ADMIN_AUTH] 管理员refresh token IP不匹配: 存储={stored_ip}, 当前={ip_address}")
        return None
    
    # 检查设备指纹绑定
    stored_device = token_data.get('device_fingerprint', '')
    if stored_device and device_fingerprint and stored_device != device_fingerprint:
        logger.warning(f"[ADMIN_AUTH] 管理员refresh token 设备指纹不匹配: 存储={stored_device}, 当前={device_fingerprint}")
        return None
    
    # 检查频率限制（20分钟内最多使用一次）
    last_used_str = token_data.get('last_used')
    if last_used_str:
        last_used = parse_iso_utc(last_used_str)
        if get_utc_time() - last_used < timedelta(minutes=20):
            logger.warning(f"[ADMIN_AUTH] 管理员refresh token 使用过于频繁: {refresh_token}")
            return None
    
    # 更新最后使用时间
    current_time = get_utc_time()
    token_data['last_used'] = format_iso_utc(current_time)
    redis_client.setex(keys[0], int(12 * 3600), json.dumps(token_data))
    
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
    from app.utils.time_utils import get_utc_time
    
    # 不设置domain，与客服保持一致
    cookie_domain = None
    
    # 确保samesite值有效
    samesite_value = Config.COOKIE_SAMESITE if Config.COOKIE_SAMESITE in ["lax", "strict", "none"] else "lax"
    
    # 设置管理员refresh token Cookie
    # admin_refresh_token 使用 SameSite=None 以支持跨域请求
    response.set_cookie(
        key="admin_refresh_token",
        value=refresh_token,
        max_age=12 * 3600,  # 12小时
        httponly=True,  # 防止XSS攻击
        secure=True,  # SameSite=None 必须使用 Secure
        samesite="none",  # 仅 admin_refresh_token 使用 none
        path="/",
        domain=cookie_domain
    )
    
    return response

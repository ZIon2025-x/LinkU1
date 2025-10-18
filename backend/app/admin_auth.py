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
        
        # 获取客户端信息
        client_ip = request.client.host if request.client else "unknown"
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
            'created_at': session_info.created_at.isoformat(),
            'last_activity': session_info.last_activity.isoformat(),
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
                    'created_at': session.created_at.isoformat(),
                    'last_activity': session.last_activity.isoformat(),
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
    def _cleanup_expired_sessions(admin_id: str):
        """清理过期会话"""
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
    
    # 验证IP地址（可选，用于检测异常登录）
    current_ip = request.client.host if request.client else "unknown"
    if session.ip_address != current_ip:
        logger.warning(f"[ADMIN_AUTH] IP地址不匹配: 会话IP={session.ip_address}, 当前IP={current_ip}")
        # 可以选择是否强制登出
        # AdminAuthManager.delete_session(admin_session_id)
        # return None
    
    logger.info(f"[ADMIN_AUTH] 管理员会话验证成功: {admin_session_id[:8]}..., 管理员: {session.admin_id}")
    return session

def create_admin_session_cookie(response: Response, session_id: str) -> Response:
    """创建管理员会话Cookie（最高安全等级）"""
    # 设置管理员会话Cookie - 最高安全等级
    response.set_cookie(
        key="admin_session_id",
        value=session_id,
        max_age=ADMIN_SESSION_EXPIRE_HOURS * 3600,  # 8小时
        httponly=True,  # 防止XSS攻击
        secure=True,    # 仅HTTPS传输
        samesite="strict",  # 最严格的同站策略
        path="/",  # 根路径，确保前端可以读取
        domain=None  # 不设置domain，提高安全性
    )
    
    # 设置管理员身份标识Cookie - 最高安全等级
    response.set_cookie(
        key="admin_authenticated",
        value="true",
        max_age=ADMIN_SESSION_EXPIRE_HOURS * 3600,
        httponly=False,  # 前端需要读取
        secure=True,     # 仅HTTPS传输
        samesite="strict",  # 最严格的同站策略
        path="/",  # 根路径，确保前端可以读取
        domain=None  # 不设置domain，提高安全性
    )
    
    return response

def clear_admin_session_cookie(response: Response) -> Response:
    """清除管理员会话Cookie"""
    response.delete_cookie("admin_session_id")
    response.delete_cookie("admin_authenticated")
    return response

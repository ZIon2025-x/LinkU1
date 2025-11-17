"""
安全日志模块
提供安全事件记录和敏感信息保护
"""

import logging
import json
import hashlib
from datetime import datetime
from typing import Any, Dict, Optional
from fastapi import Request
import os
from app.utils.time_utils import get_utc_time

# 创建安全日志记录器
security_logger = logging.getLogger("security")
security_logger.setLevel(logging.INFO)

# 创建文件处理器
if not os.path.exists("logs"):
    os.makedirs("logs")

file_handler = logging.FileHandler("logs/security.log")
file_handler.setLevel(logging.INFO)

# 创建格式化器
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
file_handler.setFormatter(formatter)

# 添加处理器
security_logger.addHandler(file_handler)


class SecurityLogger:
    """安全日志记录器"""
    
    # 需要脱敏的字段
    SENSITIVE_FIELDS = {
        'password', 'token', 'secret', 'key', 'auth', 'credential',
        'email', 'phone', 'ssn', 'credit_card', 'bank_account',
        'session_id', 'user_id', 'ip_address'
    }
    
    # 安全事件类型
    EVENT_TYPES = {
        'LOGIN_SUCCESS': '登录成功',
        'LOGIN_FAILED': '登录失败',
        'LOGOUT': '登出',
        'REGISTRATION': '用户注册',
        'PASSWORD_CHANGE': '密码修改',
        'TOKEN_REFRESH': '令牌刷新',
        'TOKEN_REVOKE': '令牌撤销',
        'FILE_UPLOAD': '文件上传',
        'FILE_DELETE': '文件删除',
        'DATA_ACCESS': '数据访问',
        'UNAUTHORIZED_ACCESS': '未授权访问',
        'RATE_LIMIT_EXCEEDED': '速率限制超限',
        'CSRF_VIOLATION': 'CSRF攻击',
        'SQL_INJECTION_ATTEMPT': 'SQL注入尝试',
        'XSS_ATTEMPT': 'XSS攻击尝试',
        'FILE_UPLOAD_ATTEMPT': '恶意文件上传尝试',
        'ACCOUNT_LOCKED': '账户锁定',
        'SUSPICIOUS_ACTIVITY': '可疑活动'
    }
    
    @staticmethod
    def _mask_sensitive_data(data: Any) -> Any:
        """脱敏敏感数据"""
        if isinstance(data, dict):
            masked_data = {}
            for key, value in data.items():
                if any(sensitive in key.lower() for sensitive in SecurityLogger.SENSITIVE_FIELDS):
                    if isinstance(value, str) and len(value) > 4:
                        # 保留前2位和后2位，中间用*替代
                        masked_data[key] = value[:2] + '*' * (len(value) - 4) + value[-2:]
                    else:
                        masked_data[key] = '***'
                else:
                    masked_data[key] = SecurityLogger._mask_sensitive_data(value)
            return masked_data
        elif isinstance(data, list):
            return [SecurityLogger._mask_sensitive_data(item) for item in data]
        elif isinstance(data, str) and len(data) > 10:
            # 对于长字符串，只保留前3位和后3位
            return data[:3] + '...' + data[-3:]
        else:
            return data
    
    @staticmethod
    def _get_client_info(request: Request) -> Dict[str, str]:
        """获取客户端信息（脱敏）"""
        # 获取真实IP
        real_ip = request.headers.get("X-Real-IP")
        forwarded_for = request.headers.get("X-Forwarded-For")
        
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        elif real_ip:
            client_ip = real_ip
        else:
            client_ip = getattr(request.client, 'host', 'unknown')
        
        # 对IP进行部分脱敏
        if client_ip != 'unknown' and '.' in client_ip:
            ip_parts = client_ip.split('.')
            if len(ip_parts) == 4:
                client_ip = f"{ip_parts[0]}.{ip_parts[1]}.***.***"
        
        return {
            "ip": client_ip,
            "user_agent": request.headers.get("User-Agent", "unknown")[:50],  # 限制长度
            "referer": request.headers.get("Referer", "direct")[:100]
        }
    
    @staticmethod
    def log_security_event(
        event_type: str,
        message: str,
        request: Request = None,
        user_id: str = None,
        additional_data: Dict[str, Any] = None,
        severity: str = "INFO"
    ):
        """记录安全事件"""
        try:
            # 构建日志数据
            log_data = {
                "timestamp": get_utc_time().isoformat(),
                "event_type": event_type,
                "event_name": SecurityLogger.EVENT_TYPES.get(event_type, event_type),
                "message": message,
                "severity": severity
            }
            
            # 添加用户信息（脱敏）
            if user_id:
                log_data["user_id"] = user_id[:8] + "..."  # 只保留前8位
            
            # 添加请求信息（脱敏）
            if request:
                client_info = SecurityLogger._get_client_info(request)
                log_data.update(client_info)
                log_data["url"] = str(request.url)[:200]  # 限制URL长度
                log_data["method"] = request.method
            
            # 添加额外数据（脱敏）
            if additional_data:
                log_data["data"] = SecurityLogger._mask_sensitive_data(additional_data)
            
            # 记录日志
            security_logger.log(
                getattr(logging, severity.upper(), logging.INFO),
                json.dumps(log_data, ensure_ascii=False)
            )
            
        except Exception as e:
            # 避免日志记录本身出错
            print(f"安全日志记录失败: {e}")
    
    @staticmethod
    def log_login_success(user_id: str, request: Request):
        """记录登录成功"""
        SecurityLogger.log_security_event(
            event_type="LOGIN_SUCCESS",
            message=f"用户登录成功",
            request=request,
            user_id=user_id,
            severity="INFO"
        )
    
    @staticmethod
    def log_login_failed(email: str, request: Request, reason: str = "密码错误"):
        """记录登录失败"""
        SecurityLogger.log_security_event(
            event_type="LOGIN_FAILED",
            message=f"用户登录失败: {reason}",
            request=request,
            additional_data={"email": email[:3] + "***@***.***"},
            severity="WARNING"
        )
    
    @staticmethod
    def log_unauthorized_access(request: Request, user_id: str = None, resource: str = None):
        """记录未授权访问"""
        message = f"未授权访问尝试"
        if resource:
            message += f" - 资源: {resource}"
        
        SecurityLogger.log_security_event(
            event_type="UNAUTHORIZED_ACCESS",
            message=message,
            request=request,
            user_id=user_id,
            severity="WARNING"
        )
    
    @staticmethod
    def log_suspicious_activity(
        activity: str, 
        request: Request, 
        user_id: str = None,
        additional_data: Dict[str, Any] = None
    ):
        """记录可疑活动"""
        SecurityLogger.log_security_event(
            event_type="SUSPICIOUS_ACTIVITY",
            message=f"可疑活动: {activity}",
            request=request,
            user_id=user_id,
            additional_data=additional_data,
            severity="WARNING"
        )
    
    @staticmethod
    def log_file_upload(filename: str, file_size: int, user_id: str, request: Request):
        """记录文件上传"""
        SecurityLogger.log_security_event(
            event_type="FILE_UPLOAD",
            message=f"文件上传: {filename}",
            request=request,
            user_id=user_id,
            additional_data={
                "filename": filename,
                "file_size": file_size
            },
            severity="INFO"
        )
    
    @staticmethod
    def log_rate_limit_exceeded(request: Request, user_id: str = None):
        """记录速率限制超限"""
        SecurityLogger.log_security_event(
            event_type="RATE_LIMIT_EXCEEDED",
            message="请求频率超限",
            request=request,
            user_id=user_id,
            severity="WARNING"
        )
    
    @staticmethod
    def log_csrf_violation(request: Request, user_id: str = None):
        """记录CSRF攻击"""
        SecurityLogger.log_security_event(
            event_type="CSRF_VIOLATION",
            message="CSRF攻击尝试",
            request=request,
            user_id=user_id,
            severity="WARNING"
        )
    
    @staticmethod
    def log_data_access(resource: str, action: str, user_id: str, request: Request):
        """记录数据访问"""
        SecurityLogger.log_security_event(
            event_type="DATA_ACCESS",
            message=f"数据访问: {action} {resource}",
            request=request,
            user_id=user_id,
            additional_data={"resource": resource, "action": action},
            severity="INFO"
        )


# 便捷函数
def log_security_event(event_type: str, message: str, **kwargs):
    """便捷的安全事件记录函数"""
    SecurityLogger.log_security_event(event_type, message, **kwargs)


def log_login_success(user_id: str, request: Request):
    """便捷的登录成功记录函数"""
    SecurityLogger.log_login_success(user_id, request)


def log_login_failed(email: str, request: Request, reason: str = "密码错误"):
    """便捷的登录失败记录函数"""
    SecurityLogger.log_login_failed(email, request, reason)

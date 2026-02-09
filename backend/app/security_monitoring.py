"""
安全监控和日志模块
记录安全事件、异常访问和攻击尝试
"""

import json
import logging
import time
from datetime import datetime, timezone
from app.utils.time_utils import format_iso_utc, get_utc_time
from typing import Dict, Any, Optional
from fastapi import Request, Response
from app.config import get_settings

settings = get_settings()

# 配置安全日志
security_logger = logging.getLogger("security")
security_logger.setLevel(logging.INFO)

# 创建安全日志处理器
if not security_logger.handlers:
    handler = logging.FileHandler("security.log", encoding="utf-8")
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    handler.setFormatter(formatter)
    security_logger.addHandler(handler)

class SecurityMonitor:
    """安全监控器"""
    
    def __init__(self):
        self.suspicious_ips = set()
        self.failed_attempts = {}  # IP -> count
        self.blocked_ips = set()
    
    @staticmethod
    def _sanitize_for_log(s: str) -> str:
        """清理日志输入，防止CRLF注入攻击"""
        if not s:
            return ""
        return s.replace('\n', '\\n').replace('\r', '\\r').replace('\x00', '')[:500]
    
    def log_security_event(
        self,
        event_type: str,
        user_id: Optional[str],
        ip_address: str,
        details: str,
        request: Optional[Request] = None,
        severity: str = "INFO"
    ):
        """记录安全事件"""
        try:
            # 🔒 安全修复：清理用户可控的HTTP头，防止日志注入
            user_agent = self._sanitize_for_log(request.headers.get("User-Agent", "")) if request else None
            referer = self._sanitize_for_log(request.headers.get("Referer", "")) if request else None
            
            # 构建日志数据
            log_data = {
                "timestamp": format_iso_utc(get_utc_time()),
                "event_type": event_type,
                "user_id": user_id,
                "ip_address": ip_address,
                "details": details,
                "severity": severity,
                "user_agent": user_agent,
                "referer": referer,
                "path": request.url.path if request else None,
                "method": request.method if request else None
            }
            
            # 记录到日志文件
            security_logger.log(
                getattr(logging, severity.upper(), logging.INFO),
                json.dumps(log_data, ensure_ascii=False)
            )
            
            # 检查是否需要触发告警
            self._check_security_thresholds(event_type, ip_address, log_data)
            
        except Exception as e:
            logging.error(f"记录安全事件失败: {e}")
    
    def _check_security_thresholds(self, event_type: str, ip_address: str, log_data: Dict[str, Any]):
        """检查安全阈值并触发告警"""
        try:
            # 登录失败次数检查
            if event_type == "LOGIN_FAILED":
                if ip_address not in self.failed_attempts:
                    self.failed_attempts[ip_address] = 0
                
                self.failed_attempts[ip_address] += 1
                
                # 5分钟内失败5次，标记为可疑IP
                if self.failed_attempts[ip_address] >= 5:
                    self.suspicious_ips.add(ip_address)
                    self.log_security_event(
                        "SUSPICIOUS_IP_DETECTED",
                        None,
                        ip_address,
                        f"IP地址在短时间内多次登录失败: {self.failed_attempts[ip_address]}次",
                        severity="WARNING"
                    )
            
            # CSRF攻击尝试检查
            elif event_type == "CSRF_ATTACK_ATTEMPT":
                self.suspicious_ips.add(ip_address)
                self.log_security_event(
                    "CSRF_ATTACK_DETECTED",
                    None,
                    ip_address,
                    "检测到CSRF攻击尝试",
                    severity="CRITICAL"
                )
            
            # 速率限制触发检查
            elif event_type == "RATE_LIMIT_EXCEEDED":
                if ip_address not in self.failed_attempts:
                    self.failed_attempts[ip_address] = 0
                
                self.failed_attempts[ip_address] += 1
                
                # 多次触发速率限制，标记为可疑
                if self.failed_attempts[ip_address] >= 3:
                    self.suspicious_ips.add(ip_address)
                    self.log_security_event(
                        "ABUSIVE_BEHAVIOR_DETECTED",
                        None,
                        ip_address,
                        f"IP地址多次触发速率限制: {self.failed_attempts[ip_address]}次",
                        severity="WARNING"
                    )
            
            # 异常访问模式检查
            elif event_type == "UNUSUAL_ACCESS_PATTERN":
                self.suspicious_ips.add(ip_address)
                self.log_security_event(
                    "UNUSUAL_ACCESS_DETECTED",
                    None,
                    ip_address,
                    "检测到异常访问模式",
                    severity="WARNING"
                )
                
        except Exception as e:
            logging.error(f"检查安全阈值失败: {e}")
    
    def is_ip_blocked(self, ip_address: str) -> bool:
        """检查IP是否被阻止"""
        return ip_address in self.blocked_ips
    
    def block_ip(self, ip_address: str, reason: str):
        """阻止IP地址"""
        self.blocked_ips.add(ip_address)
        self.log_security_event(
            "IP_BLOCKED",
            None,
            ip_address,
            f"IP地址被阻止: {reason}",
            severity="CRITICAL"
        )
    
    def unblock_ip(self, ip_address: str, reason: str):
        """解除IP阻止"""
        self.blocked_ips.discard(ip_address)
        self.log_security_event(
            "IP_UNBLOCKED",
            None,
            ip_address,
            f"IP地址解除阻止: {reason}",
            severity="INFO"
        )
    
    def get_security_stats(self) -> Dict[str, Any]:
        """获取安全统计信息"""
        return {
            "suspicious_ips_count": len(self.suspicious_ips),
            "blocked_ips_count": len(self.blocked_ips),
            "failed_attempts_count": len(self.failed_attempts),
            "suspicious_ips": list(self.suspicious_ips),
            "blocked_ips": list(self.blocked_ips),
            "failed_attempts": dict(self.failed_attempts)
        }

# 创建全局安全监控器实例
security_monitor = SecurityMonitor()

def log_authentication_event(
    event_type: str,
    user_id: Optional[str],
    ip_address: str,
    details: str,
    request: Optional[Request] = None,
    severity: str = "INFO"
):
    """记录认证相关事件"""
    security_monitor.log_security_event(
        event_type, user_id, ip_address, details, request, severity
    )

def log_csrf_event(
    event_type: str,
    user_id: Optional[str],
    ip_address: str,
    details: str,
    request: Optional[Request] = None,
    severity: str = "WARNING"
):
    """记录CSRF相关事件"""
    security_monitor.log_security_event(
        event_type, user_id, ip_address, details, request, severity
    )

def log_rate_limit_event(
    event_type: str,
    user_id: Optional[str],
    ip_address: str,
    details: str,
    request: Optional[Request] = None,
    severity: str = "WARNING"
):
    """记录速率限制相关事件"""
    security_monitor.log_security_event(
        event_type, user_id, ip_address, details, request, severity
    )

def log_suspicious_activity(
    event_type: str,
    user_id: Optional[str],
    ip_address: str,
    details: str,
    request: Optional[Request] = None,
    severity: str = "WARNING"
):
    """记录可疑活动"""
    security_monitor.log_security_event(
        event_type, user_id, ip_address, details, request, severity
    )

def get_client_ip(request: Request) -> str:
    """获取客户端IP地址"""
    # 检查代理头
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    # 回退到直接连接IP
    if hasattr(request.client, 'host'):
        return request.client.host
    
    return "unknown"

async def check_security_middleware(request: Request, call_next):
    """安全检查中间件"""
    try:
        # 跳过OPTIONS请求（CORS预检请求）
        if request.method == "OPTIONS":
            return await call_next(request)
        
        # 获取客户端IP
        client_ip = get_client_ip(request)
        
        # 检查IP是否被阻止
        if security_monitor.is_ip_blocked(client_ip):
            log_suspicious_activity(
                "BLOCKED_IP_ACCESS_ATTEMPT",
                None,
                client_ip,
                f"被阻止的IP尝试访问: {request.url.path}",
                request,
                "CRITICAL"
            )
            return Response(
                content=json.dumps({"error": "访问被拒绝"}),
                status_code=403,
                media_type="application/json"
            )
        
        # 检查可疑IP
        if client_ip in security_monitor.suspicious_ips:
            log_suspicious_activity(
                "SUSPICIOUS_IP_ACCESS",
                None,
                client_ip,
                f"可疑IP访问: {request.url.path}",
                request,
                "WARNING"
            )
        
        # 继续处理请求
        response = await call_next(request)
        
        # 记录响应状态
        if response.status_code >= 400:
            log_suspicious_activity(
                "ERROR_RESPONSE",
                None,
                client_ip,
                f"错误响应 {response.status_code}: {request.url.path}",
                request,
                "WARNING"
            )
        
        return response
        
    except Exception as e:
        log_suspicious_activity(
            "MIDDLEWARE_ERROR",
            None,
            get_client_ip(request),
            f"安全中间件错误: {str(e)}",
            request,
            "ERROR"
        )
        # 重新抛出异常，让全局异常处理器处理
        raise

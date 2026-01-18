"""
管理员安全中间件
专门为 admin 子域名提供增强的安全保护
"""

import logging
import os
from typing import Optional
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from app.security import get_client_ip
from app.rate_limiting import rate_limiter

logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)

# 管理员子域名配置
ADMIN_SUBDOMAIN = "admin.link2ur.com"
ADMIN_SUBDOMAIN_DEV = "localhost:3001"

# IP 白名单（可选，通过环境变量配置）
ADMIN_IP_WHITELIST = os.getenv("ADMIN_IP_WHITELIST", "").split(",")
ADMIN_IP_WHITELIST = [ip.strip() for ip in ADMIN_IP_WHITELIST if ip.strip()]

# 是否启用 IP 白名单（默认关闭，通过环境变量启用）
ENABLE_ADMIN_IP_WHITELIST = os.getenv("ENABLE_ADMIN_IP_WHITELIST", "false").lower() == "true"

# 管理员路由前缀
ADMIN_ROUTE_PREFIXES = [
    "/api/admin",
    "/api/auth/admin",
]


def is_admin_route(path: str) -> bool:
    """检查是否是管理员路由"""
    return any(path.startswith(prefix) for prefix in ADMIN_ROUTE_PREFIXES)


def verify_admin_origin(request: Request) -> bool:
    """验证请求来源是否为 admin 子域名"""
    origin = request.headers.get("origin", "")
    referer = request.headers.get("referer", "")
    host = request.headers.get("host", "")
    
    # 检查 Origin 头
    if origin:
        if ADMIN_SUBDOMAIN in origin or ADMIN_SUBDOMAIN_DEV in origin:
            return True
    
    # 检查 Referer 头
    if referer:
        if ADMIN_SUBDOMAIN in referer or ADMIN_SUBDOMAIN_DEV in referer:
            return True
    
    # 检查 Host 头（直接访问时）
    if host:
        if ADMIN_SUBDOMAIN in host or ADMIN_SUBDOMAIN_DEV in host:
            return True
    
    # 开发环境：允许 localhost
    if "localhost" in origin or "localhost" in referer or "localhost" in host:
        return True
    
    return False


def verify_admin_ip(request: Request) -> bool:
    """验证 IP 是否在白名单中（如果启用）"""
    if not ENABLE_ADMIN_IP_WHITELIST:
        return True  # 未启用白名单，允许所有 IP
    
    if not ADMIN_IP_WHITELIST:
        return True  # 白名单为空，允许所有 IP
    
    client_ip = get_client_ip(request)
    
    # 检查 IP 是否在白名单中
    if client_ip in ADMIN_IP_WHITELIST:
        return True
    
    # 检查 IP 段（支持 CIDR 格式，简单实现）
    for whitelist_ip in ADMIN_IP_WHITELIST:
        if "/" in whitelist_ip:
            # CIDR 格式（简化实现，实际应该使用 ipaddress 库）
            continue
        if client_ip == whitelist_ip:
            return True
    
    return False


def log_admin_access(request: Request, action: str, status: str = "allowed"):
    """记录管理员访问日志"""
    client_ip = get_client_ip(request)
    origin = request.headers.get("origin", "")
    user_agent = request.headers.get("user-agent", "")
    path = request.url.path
    
    logger.info(
        f"[ADMIN_SECURITY] {action} | "
        f"Path: {path} | "
        f"IP: {client_ip} | "
        f"Origin: {origin} | "
        f"Status: {status} | "
        f"UA: {user_agent[:100]}"
    )


async def admin_security_middleware(request: Request, call_next):
    """
    管理员安全中间件
    对管理员路由进行额外的安全验证
    """
    # 只对管理员路由进行检查
    if not is_admin_route(request.url.path):
        return await call_next(request)
    
    client_ip = get_client_ip(request)
    path = request.url.path
    
    # 1. 验证请求来源
    if not verify_admin_origin(request):
        log_admin_access(request, "ORIGIN_VERIFICATION_FAILED", "blocked")
        logger.warning(
            f"[ADMIN_SECURITY] 管理员路由访问被阻止 - 来源验证失败 | "
            f"Path: {path} | IP: {client_ip} | "
            f"Origin: {request.headers.get('origin', 'N/A')}"
        )
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "detail": "访问被拒绝：请求来源未授权",
                "error_code": "ADMIN_ORIGIN_DENIED"
            }
        )
    
    # 2. 验证 IP 白名单（如果启用）
    if not verify_admin_ip(request):
        log_admin_access(request, "IP_WHITELIST_FAILED", "blocked")
        logger.warning(
            f"[ADMIN_SECURITY] 管理员路由访问被阻止 - IP 不在白名单 | "
            f"Path: {path} | IP: {client_ip}"
        )
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "detail": "访问被拒绝：IP 地址未授权",
                "error_code": "ADMIN_IP_DENIED"
            }
        )
    
    # 3. 加强速率限制（对管理员路由使用更严格的限制）
    # 这里可以添加额外的速率限制检查
    try:
        rate_limit_info = rate_limiter.check_rate_limit(
            request,
            "admin_operation",
            limit=100,  # 每分钟 100 次
            window=60
        )
        # 如果没有抛出异常，说明允许访问，继续处理
    except HTTPException as e:
        # 如果抛出 HTTPException，说明超过速率限制
        log_admin_access(request, "RATE_LIMIT_EXCEEDED", "blocked")
        logger.warning(
            f"[ADMIN_SECURITY] 管理员路由访问被阻止 - 速率限制 | "
            f"Path: {path} | IP: {client_ip}"
        )
        # 从异常中提取 retry_after 信息
        retry_after = 60
        if isinstance(e.detail, dict) and "retry_after" in e.detail:
            retry_after = e.detail["retry_after"]
        
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={
                "detail": "请求过于频繁，请稍后再试",
                "error_code": "ADMIN_RATE_LIMIT",
                "retry_after": retry_after
            },
            headers={
                "Retry-After": str(retry_after)
            }
        )
    
    # 4. 记录允许的访问
    log_admin_access(request, "ACCESS_GRANTED", "allowed")
    
    # 继续处理请求
    try:
        response = await call_next(request)
        
        # 5. 为管理员路由添加额外的安全响应头
        response.headers["X-Admin-Access"] = "verified"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        
        # 6. 记录响应状态
        if response.status_code >= 400:
            log_admin_access(request, f"ERROR_{response.status_code}", "error")
        
        return response
        
    except Exception as e:
        log_admin_access(request, f"EXCEPTION_{type(e).__name__}", "error")
        logger.error(
            f"[ADMIN_SECURITY] 管理员路由处理异常 | "
            f"Path: {path} | IP: {client_ip} | Error: {str(e)}"
        )
        raise

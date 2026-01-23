"""
安全中间件
提供 CSP、安全响应头等安全功能
"""
import logging
from fastapi import Request
from fastapi.responses import Response

logger = logging.getLogger(__name__)


async def security_headers_middleware(request: Request, call_next):
    """安全响应头中间件
    
    ⚠️ 注意：SPA 应用建议避免内联脚本，使用外部 JS 文件
    这样就不需要 nonce，CSP 更简单且安全
    """
    try:
        response = await call_next(request)
    except Exception:
        # 让异常传播到全局异常处理器
        raise
    
    # CSP 策略（SPA 场景，避免内联脚本）
    # 从配置中获取允许的 API 域名
    from app.config import Config
    api_domain = "https://api.link2ur.com" if Config.IS_PRODUCTION else "http://localhost:8000"
    
    # 构建允许的连接源列表
    connect_sources = ["'self'", api_domain, "wss://api.link2ur.com"]
    # 添加允许的 HTTPS 源
    for origin in Config.ALLOWED_ORIGINS:
        if origin.startswith('https://'):
            connect_sources.append(origin)
    
    csp = (
        "default-src 'self'; "
        "script-src 'self' 'strict-dynamic'; "  # 不使用 nonce，避免内联脚本
        "style-src 'self' 'unsafe-inline'; "  # 暂时保留 unsafe-inline 以兼容现有代码
        "img-src 'self' data: https: blob:; "
        "font-src 'self' data:; "
        f"connect-src {' '.join(connect_sources)}; "
        "object-src 'none'; "
        "base-uri 'self'; "
        "form-action 'self'; "
        "frame-ancestors 'none'; "
        "upgrade-insecure-requests; "
        "report-uri /api/csp-report;"  # CSP 违规报告
    )
    
    # 只对HTML响应设置CSP，API响应不需要
    if "text/html" in response.headers.get("Content-Type", ""):
        response.headers["Content-Security-Policy"] = csp
    
    # 必需的安全头
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"  # 改为SAMEORIGIN以支持iframe嵌入（如果需要）
    # ⚠️ X-XSS-Protection 已废弃，不设置
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    # 添加Permissions-Policy（限制浏览器功能）
    response.headers["Permissions-Policy"] = (
        "geolocation=(), "
        "microphone=(), "
        "camera=(), "
        "payment=(), "
        "usb=(), "
        "magnetometer=(), "
        "gyroscope=(), "
        "accelerometer=()"
    )
    
    # 添加HSTS（HTTP Strict Transport Security）
    # 生产环境始终添加，开发环境只在 HTTPS 时添加
    from app.config import Config
    if Config.IS_PRODUCTION or request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    
    return response


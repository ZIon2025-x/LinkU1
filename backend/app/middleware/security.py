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
    response = await call_next(request)
    
    # CSP 策略（SPA 场景，避免内联脚本）
    csp = (
        "default-src 'self'; "
        "script-src 'self' 'strict-dynamic'; "  # 不使用 nonce，避免内联脚本
        "style-src 'self'; "  # 逐步移除 'unsafe-inline'，使用外部样式或 CSS-in-JS
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' https://api.example.com wss:; "
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
    response.headers["X-Frame-Options"] = "DENY"
    # ⚠️ X-XSS-Protection 已废弃，不设置
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    return response


"""
请求日志与请求 ID 中间件
- 为每个请求生成唯一 request_id（通过 X-Request-ID 头传递）
- 记录请求方法、路径、状态码、响应时间
- 记录慢请求告警
- 将 request_id 注入 logging context 以实现日志关联
"""

import logging
import time
import uuid
import contextvars
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger("app.request")

# ContextVar 用于在同一请求的所有日志中传递 request_id
request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")


class RequestIDFilter(logging.Filter):
    """将当前请求的 request_id 注入所有日志记录"""

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = request_id_var.get("-")
        return True


# 不记录日志的路径（高频健康检查、静态资源等）
SKIP_LOG_PATHS = {
    "/health",
    "/ping",
    "/metrics",
    "/favicon.ico",
    "/robots.txt",
}

# 慢请求阈值（秒）
SLOW_REQUEST_THRESHOLD = 1.0
# 警告阈值（秒）
WARN_REQUEST_THRESHOLD = 0.5


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    综合请求日志中间件
    1. 生成/透传 X-Request-ID
    2. 记录请求和响应信息
    3. 慢请求告警
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # 1. 生成或接收 request_id
        req_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())[:12]
        request_id_var.set(req_id)

        # 把 request_id 绑定到 request.state，方便其他代码读取
        request.state.request_id = req_id

        # 2. 记录开始时间
        start_time = time.time()
        path = request.url.path
        method = request.method

        # 3. 调用下一层
        response: Response | None = None
        error_occurred = False
        try:
            response = await call_next(request)
        except Exception:
            error_occurred = True
            raise
        finally:
            duration = time.time() - start_time
            status_code = response.status_code if response else 500

            # 在响应头中透传 request_id
            if response:
                response.headers["X-Request-ID"] = req_id
                response.headers["X-Process-Time"] = f"{duration:.4f}"

            # 4. 记录日志（跳过高频无意义路径）
            if path not in SKIP_LOG_PATHS:
                # 提取客户端 IP
                client_ip = _get_client_ip(request)

                log_data = (
                    f"[{req_id}] {method} {path} "
                    f"-> {status_code} "
                    f"({duration:.3f}s) "
                    f"IP={client_ip}"
                )

                if error_occurred or status_code >= 500:
                    logger.error(log_data)
                elif duration >= SLOW_REQUEST_THRESHOLD:
                    logger.warning(f"SLOW {log_data}")
                elif status_code >= 400:
                    logger.warning(log_data)
                elif duration >= WARN_REQUEST_THRESHOLD:
                    logger.info(log_data)
                else:
                    logger.debug(log_data)

        return response


def _get_client_ip(request: Request) -> str:
    """从请求中提取客户端 IP，支持代理头"""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip
    if request.client:
        return request.client.host
    return "unknown"

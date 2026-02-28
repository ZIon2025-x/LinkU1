"""
资源代理（图片 + 文件）：为 Flutter Web（app.link2ur.com）解决 Cloudflare/CDN 跨域问题。

为什么 www 能直接访问 cdn，而 app 不能？
- CORS 是按「页面来源（Origin）」控制的。主站 www.link2ur.com 和 CDN cdn.link2ur.com
  通常在同一套 Cloudflare/配置下，CDN 可能只对 www 或同域返回了 Access-Control-Allow-Origin。
- Flutter Web 部署在 app.link2ur.com，是另一个 Origin。若 CDN 未配置允许 app.link2ur.com，
  浏览器就会拦截跨域请求。所以通过本代理由后端拉取 cdn/www 资源并带上 CORS 头返回。
"""
import logging
import urllib.parse
from typing import Optional

import requests
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from app.config import Config

logger = logging.getLogger(__name__)

router = APIRouter()

# 允许代理的源主机（Cloudflare/CDN/主站），防止开放代理
ALLOWED_HOSTS = frozenset({
    "cdn.link2ur.com",
    "www.link2ur.com",
    "link2ur.com",
    "api.link2ur.com",
    "linktest.up.railway.app",  # 测试环境
})

# 允许代理的 Content-Type：图片 + 常见文件（PDF、二进制等）
ALLOWED_CONTENT_TYPE_PREFIXES = (
    "image/",
    "application/octet-stream",
    "application/pdf",
    "application/zip",
    "text/plain",
    "text/csv",
)

# 请求超时（秒）
PROXY_TIMEOUT = 15

# 最大响应体（20MB，兼顾图片和文件）
MAX_BODY_BYTES = 20 * 1024 * 1024


def _get_origin(request: Request) -> Optional[str]:
    """从请求取 Origin，且必须在 ALLOWED_ORIGINS 内（由上层 CORS 中间件保证）。"""
    origin = request.headers.get("Origin")
    if not origin:
        return None
    origin = origin.strip()
    allowed = getattr(Config, "ALLOWED_ORIGINS", [])
    if allowed and origin not in allowed:
        return None
    return origin


def _proxy_resource(request: Request, url: str) -> Response:
    """通用资源代理：仅允许自家域名，返回带 CORS 的响应。"""
    if not url or not url.strip():
        raise HTTPException(status_code=400, detail="Missing url parameter")

    try:
        parsed = urllib.parse.urlparse(url.strip())
    except Exception as e:
        logger.warning("resource_proxy invalid url: %s", e)
        raise HTTPException(status_code=400, detail="Invalid url") from e

    if not parsed.scheme or not parsed.netloc:
        raise HTTPException(status_code=400, detail="Invalid url")

    host = (parsed.netloc or "").lower().split(":")[0]
    if host not in ALLOWED_HOSTS:
        logger.warning("resource_proxy disallowed host: %s", host)
        raise HTTPException(status_code=403, detail="Host not allowed")

    if parsed.scheme not in ("http", "https"):
        raise HTTPException(status_code=400, detail="Invalid scheme")

    try:
        r = requests.get(
            url,
            timeout=PROXY_TIMEOUT,
            stream=True,
            headers={
                "User-Agent": "Link2Ur-ResourceProxy/1.0",
                "Accept": "*/*",
            },
        )
        r.raise_for_status()
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Upstream timeout") from None
    except requests.exceptions.RequestException as e:
        logger.warning("resource_proxy upstream error url=%s: %s", url[:80], e)
        raise HTTPException(status_code=502, detail="Upstream error") from None

    content_type = (r.headers.get("Content-Type") or "").split(";")[0].strip().lower()
    if not content_type or not any(content_type.startswith(p) for p in ALLOWED_CONTENT_TYPE_PREFIXES):
        # 只代理允许的类型，避免滥用
        raise HTTPException(status_code=400, detail="Content type not allowed")

    content_length = r.headers.get("Content-Length")
    if content_length and int(content_length) > MAX_BODY_BYTES:
        raise HTTPException(status_code=413, detail="Resource too large")

    body = r.content
    if len(body) > MAX_BODY_BYTES:
        raise HTTPException(status_code=413, detail="Resource too large")

    origin = _get_origin(request)
    headers = {
        "Content-Type": content_type or "application/octet-stream",
        "Cache-Control": "public, max-age=86400",
    }
    if origin:
        headers["Access-Control-Allow-Origin"] = origin

    return Response(content=body, media_type=content_type or None, headers=headers)


@router.get("/proxy/resource")
def proxy_resource_route(request: Request, url: str) -> Response:
    """
    代理图片与文件请求，解决 Web 端从 app.link2ur.com 加载 cdn/www 资源时的 CORS 问题。
    仅允许指向 link2ur 自家域名的 URL，且仅允许图片和常见文件类型。
    """
    return _proxy_resource(request, url)


@router.get("/proxy/image")
def proxy_image(request: Request, url: str) -> Response:
    """
    兼容旧接口：仅代理图片。新调用请使用 /proxy/resource（支持图片+文件）。
    """
    return _proxy_resource(request, url)

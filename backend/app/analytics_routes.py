"""
Analytics API路由
用于收集前端性能指标（Web Vitals）
"""

import logging
from typing import Dict, Any
from fastapi import APIRouter, Request, Response
from pydantic import BaseModel
from app.config import Config
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/analytics", tags=["Analytics"])


class WebVitalsMetric(BaseModel):
    """Web Vitals 指标模型"""
    name: str  # LCP, CLS, FID, FCP, TTFB
    value: float
    id: str
    delta: float = None
    rating: str = None  # 'good', 'needs-improvement', 'poor'
    navigationType: str = None


@router.post("/web-vitals")
async def receive_web_vitals(
    metric: WebVitalsMetric,
    request: Request,
    response: Response
):
    """
    接收前端发送的 Web Vitals 性能指标
    
    收集的指标包括：
    - LCP (Largest Contentful Paint): 最大内容绘制时间
    - CLS (Cumulative Layout Shift): 累积布局偏移
    - FID (First Input Delay): 首次输入延迟
    - FCP (First Contentful Paint): 首次内容绘制时间
    - TTFB (Time to First Byte): 首字节时间
    """
    # 添加CORS头
    origin = request.headers.get("origin")
    if origin and origin in ["https://www.link2ur.com", "https://api.link2ur.com"]:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = ", ".join(Config.ALLOWED_HEADERS)
    
    try:
        # 获取用户信息（可选）
        user_agent = request.headers.get("user-agent", "")
        client_ip = request.client.host if request.client else None
        
        # 记录性能指标（可以根据需要存储到数据库）
        metric_data = {
            "name": metric.name,
            "value": metric.value,
            "id": metric.id,
            "delta": metric.delta,
            "rating": metric.rating,
            "navigation_type": metric.navigationType,
            "timestamp": format_iso_utc(get_utc_time()),
            "user_agent": user_agent,
            "client_ip": client_ip,
        }
        
        # 记录日志（可以根据需要改为存储到数据库）
        logger.info(f"[Web Vitals] {metric.name}: {metric.value:.2f}ms (rating: {metric.rating})")
        
        # TODO: 如果需要持久化存储，可以在这里添加数据库存储逻辑
        # 例如：存储到 analytics_web_vitals 表
        
        return {"status": "ok", "received": True}
        
    except Exception as e:
        logger.error(f"[Web Vitals] 接收指标失败: {str(e)}")
        # 即使出错也返回成功，避免影响用户体验
        return {"status": "ok", "received": False, "error": str(e)}


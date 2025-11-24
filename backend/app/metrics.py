"""
Prometheus 指标收集
提供应用性能监控和健康指标
"""
import time
import logging
from typing import Optional
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi import Response

logger = logging.getLogger(__name__)

# HTTP 请求指标
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

# WebSocket 连接指标
websocket_connections_total = Counter(
    'websocket_connections_total',
    'Total WebSocket connections',
    ['status']  # 'established', 'closed', 'error'
)

websocket_connections_active = Gauge(
    'websocket_connections_active',
    'Active WebSocket connections'
)

websocket_messages_total = Counter(
    'websocket_messages_total',
    'Total WebSocket messages',
    ['type']  # 'sent', 'received', 'error'
)

# 数据库连接指标
database_connections_active = Gauge(
    'database_connections_active',
    'Active database connections'
)

database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query duration in seconds',
    ['operation']
)

# 定时任务指标
scheduled_tasks_total = Counter(
    'scheduled_tasks_total',
    'Total scheduled tasks executed',
    ['task_name', 'status']  # 'success', 'error'
)

scheduled_task_duration_seconds = Histogram(
    'scheduled_task_duration_seconds',
    'Scheduled task duration in seconds',
    ['task_name']
)

# 应用健康指标
app_health_status = Gauge(
    'app_health_status',
    'Application health status (1=healthy, 0=unhealthy)',
    ['component']  # 'database', 'redis', 'overall'
)


def record_http_request(method: str, endpoint: str, status_code: int, duration: float):
    """记录 HTTP 请求指标"""
    http_requests_total.labels(method=method, endpoint=endpoint, status_code=status_code).inc()
    http_request_duration_seconds.labels(method=method, endpoint=endpoint).observe(duration)


def record_websocket_connection(status: str):
    """记录 WebSocket 连接指标"""
    websocket_connections_total.labels(status=status).inc()


def update_websocket_connections_active(count: int):
    """更新活跃 WebSocket 连接数"""
    websocket_connections_active.set(count)


def record_websocket_message(message_type: str):
    """记录 WebSocket 消息指标"""
    websocket_messages_total.labels(type=message_type).inc()


def update_database_connections_active(count: int):
    """更新活跃数据库连接数"""
    database_connections_active.set(count)


def record_database_query(operation: str, duration: float):
    """记录数据库查询指标"""
    database_query_duration_seconds.labels(operation=operation).observe(duration)


def record_scheduled_task(task_name: str, status: str, duration: float):
    """记录定时任务指标"""
    scheduled_tasks_total.labels(task_name=task_name, status=status).inc()
    scheduled_task_duration_seconds.labels(task_name=task_name).observe(duration)


def update_health_status(component: str, healthy: bool):
    """更新健康状态指标"""
    app_health_status.labels(component=component).set(1 if healthy else 0)


def get_metrics_response() -> Response:
    """获取 Prometheus 指标响应"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


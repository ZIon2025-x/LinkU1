"""
观测与回归 KPI 定义
定义 RUM + APM 的关键性能指标和阈值
"""
from typing import Dict, Any
from datetime import datetime
from app.utils.time_utils import get_utc_time, format_iso_utc

# KPI 阈值配置
KPI_THRESHOLDS = {
    # API 性能指标
    "api_p95_latency": {
        "task_detail": 200,  # 任务详情接口 P95 延迟（毫秒）
        "task_list": 300,    # 任务列表接口 P95 延迟（毫秒）
        "user_profile": 150, # 用户资料接口 P95 延迟（毫秒）
        "default": 500        # 默认接口 P95 延迟（毫秒）
    },
    
    # 缓存指标
    "cache_hit_rate": {
        "task_detail": 0.80,  # 任务详情缓存命中率（80%）
        "task_list": 0.70,     # 任务列表缓存命中率（70%）
        "translation": 0.60,   # 翻译缓存命中率（60%）
        "default": 0.50        # 默认缓存命中率（50%）
    },
    
    # 错误率
    "error_rate": {
        "api_errors": 0.01,    # API 错误率（1%）
        "5xx_errors": 0.005,   # 5xx 错误率（0.5%）
        "4xx_errors": 0.02,    # 4xx 错误率（2%）
        "default": 0.01         # 默认错误率（1%）
    },
    
    # 前端性能指标（RUM）
    "frontend_metrics": {
        "inp": 200,            # Interaction to Next Paint（毫秒）
        "fcp": 1800,           # First Contentful Paint（毫秒）
        "lcp": 2500,           # Largest Contentful Paint（毫秒）
        "cls": 0.1,            # Cumulative Layout Shift
        "ttfb": 600            # Time to First Byte（毫秒）
    },
    
    # 数据库性能
    "database_metrics": {
        "query_p95": 100,      # 查询 P95 延迟（毫秒）
        "connection_pool_usage": 0.80,  # 连接池使用率（80%）
        "slow_queries": 0.05   # 慢查询比例（5%）
    }
}

# 告警级别
ALERT_LEVELS = {
    "critical": "critical",  # 严重：立即处理
    "warning": "warning",    # 警告：需要关注
    "info": "info"           # 信息：记录日志
}

def check_kpi_threshold(metric_name: str, value: float, endpoint: str = "default") -> Dict[str, Any]:
    """
    检查 KPI 是否超过阈值
    
    Args:
        metric_name: 指标名称（如 "api_p95_latency"）
        value: 当前值
        endpoint: 端点名称（如 "task_detail"）
    
    Returns:
        包含检查结果的字典
    """
    thresholds = KPI_THRESHOLDS.get(metric_name, {})
    threshold = thresholds.get(endpoint, thresholds.get("default", float('inf')))
    
    is_exceeded = value > threshold
    
    # 确定告警级别
    if is_exceeded:
        # 超过阈值 50% 以上为严重
        if value > threshold * 1.5:
            level = ALERT_LEVELS["critical"]
        else:
            level = ALERT_LEVELS["warning"]
    else:
        level = ALERT_LEVELS["info"]
    
    return {
        "metric": metric_name,
        "endpoint": endpoint,
        "value": value,
        "threshold": threshold,
        "exceeded": is_exceeded,
        "level": level,
        "timestamp": format_iso_utc(get_utc_time())
    }

def get_kpi_summary() -> Dict[str, Any]:
    """获取所有 KPI 阈值摘要"""
    return {
        "thresholds": KPI_THRESHOLDS,
        "alert_levels": ALERT_LEVELS,
        "last_updated": format_iso_utc(get_utc_time())
    }


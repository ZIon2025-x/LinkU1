"""
后端性能监控工具
监控API响应时间、数据库查询时间等性能指标
"""
import time
import logging
from functools import wraps
from typing import Callable, Any
from collections import defaultdict
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class PerformanceMonitor:
    """性能监控器"""
    
    def __init__(self):
        self.metrics: list[dict] = []
        self.max_metrics = 1000  # 最多保存1000条指标
        self.slow_threshold = 1000  # 慢查询阈值（毫秒）
    
    def record_metric(
        self,
        name: str,
        duration_ms: float,
        metric_type: str = "custom",
        metadata: dict = None
    ):
        """记录性能指标"""
        metric = {
            "name": name,
            "duration_ms": duration_ms,
            "type": metric_type,
            "timestamp": datetime.utcnow().isoformat(),
            "metadata": metadata or {},
        }
        
        self.metrics.append(metric)
        
        # 限制指标数量
        if len(self.metrics) > self.max_metrics:
            self.metrics.pop(0)
        
        # 记录慢查询
        if duration_ms > self.slow_threshold:
            logger.warning(
                f"慢查询警告: {name} 耗时 {duration_ms:.2f}ms",
                extra={"metric": metric}
            )
    
    def measure(self, name: str, metric_type: str = "custom"):
        """性能测量装饰器"""
        def decorator(func: Callable) -> Callable:
            @wraps(func)
            async def async_wrapper(*args, **kwargs):
                start = time.perf_counter()
                try:
                    result = await func(*args, **kwargs)
                    duration_ms = (time.perf_counter() - start) * 1000
                    self.record_metric(name, duration_ms, metric_type)
                    return result
                except Exception as e:
                    duration_ms = (time.perf_counter() - start) * 1000
                    self.record_metric(
                        f"{name}_error",
                        duration_ms,
                        metric_type,
                        {"error": str(e)}
                    )
                    raise
            
            @wraps(func)
            def sync_wrapper(*args, **kwargs):
                start = time.perf_counter()
                try:
                    result = func(*args, **kwargs)
                    duration_ms = (time.perf_counter() - start) * 1000
                    self.record_metric(name, duration_ms, metric_type)
                    return result
                except Exception as e:
                    duration_ms = (time.perf_counter() - start) * 1000
                    self.record_metric(
                        f"{name}_error",
                        duration_ms,
                        metric_type,
                        {"error": str(e)}
                    )
                    raise
            
            import asyncio
            if asyncio.iscoroutinefunction(func):
                return async_wrapper
            else:
                return sync_wrapper
        
        return decorator
    
    def get_metrics(self, metric_type: str = None, limit: int = 100) -> list[dict]:
        """获取性能指标"""
        metrics = self.metrics
        if metric_type:
            metrics = [m for m in metrics if m["type"] == metric_type]
        return metrics[-limit:]
    
    def get_average_duration(self, name: str) -> float | None:
        """获取平均耗时"""
        matching_metrics = [m for m in self.metrics if m["name"] == name]
        if not matching_metrics:
            return None
        
        total_duration = sum(m["duration_ms"] for m in matching_metrics)
        return total_duration / len(matching_metrics)
    
    def get_slow_queries(self, threshold_ms: float = None) -> list[dict]:
        """获取慢查询列表"""
        threshold = threshold_ms or self.slow_threshold
        return [
            m for m in self.metrics
            if m["duration_ms"] > threshold
        ]
    
    def get_statistics(self) -> dict:
        """获取统计信息"""
        if not self.metrics:
            return {
                "total_metrics": 0,
                "average_durations": {},
                "slow_queries_count": 0,
            }
        
        # 按类型分组统计
        by_type: dict[str, list[float]] = defaultdict(list)
        for metric in self.metrics:
            by_type[metric["type"]].append(metric["duration_ms"])
        
        # 计算平均值
        averages = {
            metric_type: sum(durations) / len(durations)
            for metric_type, durations in by_type.items()
        }
        
        # 慢查询数量
        slow_count = len(self.get_slow_queries())
        
        return {
            "total_metrics": len(self.metrics),
            "average_durations": averages,
            "slow_queries_count": slow_count,
            "slow_threshold_ms": self.slow_threshold,
        }
    
    def clear(self):
        """清除所有指标"""
        self.metrics = []


# 创建全局单例
performance_monitor = PerformanceMonitor()


def measure_api_performance(api_name: str = None):
    """API性能测量装饰器"""
    def decorator(func: Callable) -> Callable:
        name = api_name or f"{func.__module__}.{func.__name__}"
        
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.perf_counter()
            try:
                result = await func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    name,
                    duration_ms,
                    "api_call",
                    {"method": "async"}
                )
                return result
            except Exception as e:
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    f"{name}_error",
                    duration_ms,
                    "api_call",
                    {"error": str(e), "method": "async"}
                )
                raise
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            start = time.perf_counter()
            try:
                result = func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    name,
                    duration_ms,
                    "api_call",
                    {"method": "sync"}
                )
                return result
            except Exception as e:
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    f"{name}_error",
                    duration_ms,
                    "api_call",
                    {"error": str(e), "method": "sync"}
                )
                raise
        
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator


def measure_db_query(query_name: str = None):
    """数据库查询性能测量装饰器"""
    def decorator(func: Callable) -> Callable:
        name = query_name or f"{func.__module__}.{func.__name__}"
        
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.perf_counter()
            try:
                result = await func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    name,
                    duration_ms,
                    "db_query",
                    {"method": "async"}
                )
                return result
            except Exception as e:
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    f"{name}_error",
                    duration_ms,
                    "db_query",
                    {"error": str(e), "method": "async"}
                )
                raise
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            start = time.perf_counter()
            try:
                result = func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    name,
                    duration_ms,
                    "db_query",
                    {"method": "sync"}
                )
                return result
            except Exception as e:
                duration_ms = (time.perf_counter() - start) * 1000
                performance_monitor.record_metric(
                    f"{name}_error",
                    duration_ms,
                    "db_query",
                    {"error": str(e), "method": "sync"}
                )
                raise
        
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator


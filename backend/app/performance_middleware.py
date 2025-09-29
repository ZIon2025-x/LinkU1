"""
性能监控中间件
监控API响应时间、数据库查询性能等
"""

import time
import logging
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)


class PerformanceMiddleware(BaseHTTPMiddleware):
    """性能监控中间件"""
    
    def __init__(self, app, slow_query_threshold: float = 1.0):
        super().__init__(app)
        self.slow_query_threshold = slow_query_threshold
        self.request_count = 0
        self.total_response_time = 0.0
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # 记录请求开始时间
        start_time = time.time()
        
        # 增加请求计数
        self.request_count += 1
        
        # 处理请求
        response = await call_next(request)
        
        # 计算响应时间
        process_time = time.time() - start_time
        self.total_response_time += process_time
        
        # 记录慢查询
        if process_time > self.slow_query_threshold:
            logger.warning(
                f"Slow request: {request.method} {request.url.path} "
                f"took {process_time:.3f}s"
            )
        
        # 添加性能头
        response.headers["X-Process-Time"] = str(process_time)
        response.headers["X-Request-Count"] = str(self.request_count)
        
        # 记录性能日志
        logger.info(
            f"Request: {request.method} {request.url.path} "
            f"Status: {response.status_code} "
            f"Time: {process_time:.3f}s"
        )
        
        return response
    
    def get_stats(self) -> dict:
        """获取性能统计"""
        avg_response_time = (
            self.total_response_time / self.request_count 
            if self.request_count > 0 else 0
        )
        
        return {
            "total_requests": self.request_count,
            "total_response_time": round(self.total_response_time, 3),
            "average_response_time": round(avg_response_time, 3),
            "slow_query_threshold": self.slow_query_threshold
        }


class DatabaseQueryMonitor:
    """数据库查询监控器"""
    
    def __init__(self):
        self.query_count = 0
        self.total_query_time = 0.0
        self.slow_queries = []
        self.query_threshold = 0.5  # 慢查询阈值（秒）
    
    @asynccontextmanager
    async def monitor_query(self, query_name: str):
        """监控数据库查询"""
        start_time = time.time()
        self.query_count += 1
        
        try:
            yield
        finally:
            query_time = time.time() - start_time
            self.total_query_time += query_time
            
            # 记录慢查询
            if query_time > self.query_threshold:
                slow_query = {
                    "query": query_name,
                    "time": query_time,
                    "timestamp": time.time()
                }
                self.slow_queries.append(slow_query)
                
                # 只保留最近100个慢查询
                if len(self.slow_queries) > 100:
                    self.slow_queries = self.slow_queries[-100:]
                
                logger.warning(
                    f"Slow query: {query_name} took {query_time:.3f}s"
                )
    
    def get_stats(self) -> dict:
        """获取查询统计"""
        avg_query_time = (
            self.total_query_time / self.query_count 
            if self.query_count > 0 else 0
        )
        
        return {
            "total_queries": self.query_count,
            "total_query_time": round(self.total_query_time, 3),
            "average_query_time": round(avg_query_time, 3),
            "slow_queries_count": len(self.slow_queries),
            "slow_query_threshold": self.query_threshold,
            "recent_slow_queries": self.slow_queries[-10:]  # 最近10个慢查询
        }


class MemoryMonitor:
    """内存使用监控器"""
    
    def __init__(self):
        self.peak_memory = 0
        self.current_memory = 0
    
    def update_memory_usage(self):
        """更新内存使用情况"""
        try:
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            self.current_memory = memory_info.rss / 1024 / 1024  # MB
            
            if self.current_memory > self.peak_memory:
                self.peak_memory = self.current_memory
                
        except ImportError:
            logger.warning("psutil not available, memory monitoring disabled")
        except Exception as e:
            logger.error(f"Error monitoring memory: {e}")
    
    def get_stats(self) -> dict:
        """获取内存统计"""
        return {
            "current_memory_mb": round(self.current_memory, 2),
            "peak_memory_mb": round(self.peak_memory, 2)
        }


class PerformanceCollector:
    """性能数据收集器"""
    
    def __init__(self):
        self.request_monitor = PerformanceMiddleware(None)
        self.query_monitor = DatabaseQueryMonitor()
        self.memory_monitor = MemoryMonitor()
    
    def collect_all_stats(self) -> dict:
        """收集所有性能统计"""
        self.memory_monitor.update_memory_usage()
        
        return {
            "requests": self.request_monitor.get_stats(),
            "database": self.query_monitor.get_stats(),
            "memory": self.memory_monitor.get_stats(),
            "timestamp": time.time()
        }
    
    def log_performance_summary(self):
        """记录性能摘要"""
        stats = self.collect_all_stats()
        
        logger.info(
            f"Performance Summary - "
            f"Requests: {stats['requests']['total_requests']}, "
            f"Avg Response: {stats['requests']['average_response_time']:.3f}s, "
            f"Queries: {stats['database']['total_queries']}, "
            f"Avg Query: {stats['database']['average_query_time']:.3f}s, "
            f"Memory: {stats['memory']['current_memory_mb']:.1f}MB"
        )


# 创建全局性能收集器
performance_collector = PerformanceCollector()

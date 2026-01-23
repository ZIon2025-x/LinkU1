"""
性能监控指标模块
提供系统性能指标和监控数据
"""

import time
import logging
from typing import Dict, Any, Optional
from collections import defaultdict
from datetime import datetime, timedelta

from app.database import sync_engine, async_engine, ASYNC_AVAILABLE
from app.redis_cache import get_redis_client
from app.performance_middleware import performance_collector

logger = logging.getLogger(__name__)


class PerformanceMetrics:
    """性能指标收集器"""
    
    def __init__(self):
        self.request_stats = defaultdict(lambda: {"count": 0, "total_time": 0.0, "errors": 0})
        self.query_stats = defaultdict(lambda: {"count": 0, "total_time": 0.0})
        self.error_stats = defaultdict(int)
    
    def record_request(self, endpoint: str, method: str, duration: float, status_code: int):
        """记录请求指标"""
        key = f"{method} {endpoint}"
        self.request_stats[key]["count"] += 1
        self.request_stats[key]["total_time"] += duration
        if status_code >= 400:
            self.request_stats[key]["errors"] += 1
    
    def record_query(self, query_name: str, duration: float):
        """记录查询指标"""
        self.query_stats[query_name]["count"] += 1
        self.query_stats[query_name]["total_time"] += duration
    
    def record_error(self, error_type: str):
        """记录错误"""
        self.error_stats[error_type] += 1
    
    def get_request_stats(self) -> Dict[str, Any]:
        """获取请求统计"""
        stats = {}
        for key, data in self.request_stats.items():
            count = data["count"]
            total_time = data["total_time"]
            stats[key] = {
                "count": count,
                "avg_time": total_time / count if count > 0 else 0,
                "total_time": total_time,
                "errors": data["errors"],
                "error_rate": data["errors"] / count if count > 0 else 0
            }
        return stats
    
    def get_query_stats(self) -> Dict[str, Any]:
        """获取查询统计"""
        stats = {}
        for key, data in self.query_stats.items():
            count = data["count"]
            total_time = data["total_time"]
            stats[key] = {
                "count": count,
                "avg_time": total_time / count if count > 0 else 0,
                "total_time": total_time
            }
        return stats
    
    def get_error_stats(self) -> Dict[str, int]:
        """获取错误统计"""
        return dict(self.error_stats)
    
    def get_database_pool_stats(self) -> Dict[str, Any]:
        """获取数据库连接池统计"""
        try:
            if not sync_engine:
                return {"status": "not_available"}
            
            pool = sync_engine.pool
            return {
                "pool_size": pool.size(),
                "checked_out": pool.checkedout(),
                "overflow": pool.overflow(),
                "invalid": pool.invalid(),
                "usage_percent": round((pool.checkedout() / pool.size() * 100) if pool.size() > 0 else 0, 1)
            }
        except Exception as e:
            logger.error(f"获取连接池统计失败: {e}")
            return {"error": str(e)}
    
    def get_redis_stats(self) -> Dict[str, Any]:
        """获取Redis统计"""
        try:
            redis_client = get_redis_client()
            if not redis_client:
                return {"status": "not_configured"}
            
            info = redis_client.info()
            return {
                "status": "connected",
                "connected_clients": info.get("connected_clients", 0),
                "used_memory_human": info.get("used_memory_human", "unknown"),
                "keyspace_hits": info.get("keyspace_hits", 0),
                "keyspace_misses": info.get("keyspace_misses", 0),
                "hit_rate": round(
                    info.get("keyspace_hits", 0) / 
                    (info.get("keyspace_hits", 0) + info.get("keyspace_misses", 1)) * 100, 
                    2
                ) if (info.get("keyspace_hits", 0) + info.get("keyspace_misses", 0)) > 0 else 0
            }
        except Exception as e:
            logger.error(f"获取Redis统计失败: {e}")
            return {"status": "error", "error": str(e)}
    
    def get_system_metrics(self) -> Dict[str, Any]:
        """获取系统指标"""
        try:
            import psutil
            process = psutil.Process()
            
            # CPU使用率
            cpu_percent = process.cpu_percent(interval=0.1)
            
            # 内存使用
            memory_info = process.memory_info()
            memory_mb = memory_info.rss / 1024 / 1024
            
            # 文件描述符
            try:
                num_fds = process.num_fds()
            except AttributeError:
                num_fds = None
            
            return {
                "cpu_percent": round(cpu_percent, 2),
                "memory_mb": round(memory_mb, 2),
                "num_fds": num_fds,
                "threads": process.num_threads()
            }
        except ImportError:
            return {"error": "psutil not available"}
        except Exception as e:
            logger.error(f"获取系统指标失败: {e}")
            return {"error": str(e)}
    
    def get_comprehensive_metrics(self) -> Dict[str, Any]:
        """获取综合性能指标"""
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "requests": self.get_request_stats(),
            "queries": self.get_query_stats(),
            "errors": self.get_error_stats(),
            "database_pool": self.get_database_pool_stats(),
            "redis": self.get_redis_stats(),
            "system": self.get_system_metrics(),
            "performance_collector": performance_collector.collect_all_stats() if performance_collector else None
        }


# 创建全局实例
performance_metrics = PerformanceMetrics()

"""
增强的健康检查模块
提供详细的系统健康状态检查
"""

import time
import logging
from typing import Dict, Any, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.database import sync_engine, async_engine, ASYNC_AVAILABLE
from app.redis_cache import get_redis_client
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)


class HealthChecker:
    """健康检查器"""
    
    @staticmethod
    def check_database_sync() -> Dict[str, Any]:
        """检查同步数据库连接"""
        start_time = time.time()
        try:
            with sync_engine.connect() as conn:
                result = conn.execute(text("SELECT 1"))
                result.fetchone()
            
            duration = time.time() - start_time
            return {
                "status": "healthy",
                "response_time_ms": round(duration * 1000, 2),
                "message": "数据库连接正常"
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"数据库连接检查失败: {e}", exc_info=True)
            return {
                "status": "unhealthy",
                "response_time_ms": round(duration * 1000, 2),
                "error": str(e),
                "message": "数据库连接失败"
            }
    
    @staticmethod
    async def check_database_async() -> Dict[str, Any]:
        """检查异步数据库连接"""
        if not ASYNC_AVAILABLE or not async_engine:
            return {
                "status": "not_available",
                "message": "异步数据库不可用"
            }
        
        start_time = time.time()
        try:
            async with async_engine.connect() as conn:
                result = await conn.execute(text("SELECT 1"))
                await result.fetchone()
            
            duration = time.time() - start_time
            return {
                "status": "healthy",
                "response_time_ms": round(duration * 1000, 2),
                "message": "异步数据库连接正常"
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"异步数据库连接检查失败: {e}", exc_info=True)
            return {
                "status": "unhealthy",
                "response_time_ms": round(duration * 1000, 2),
                "error": str(e),
                "message": "异步数据库连接失败"
            }
    
    @staticmethod
    def check_redis() -> Dict[str, Any]:
        """检查Redis连接"""
        start_time = time.time()
        try:
            redis_client = get_redis_client()
            if not redis_client:
                return {
                    "status": "not_configured",
                    "message": "Redis未配置"
                }
            
            redis_client.ping()
            duration = time.time() - start_time
            return {
                "status": "healthy",
                "response_time_ms": round(duration * 1000, 2),
                "message": "Redis连接正常"
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.warning(f"Redis连接检查失败: {e}")
            return {
                "status": "unhealthy",
                "response_time_ms": round(duration * 1000, 2),
                "error": str(e),
                "message": "Redis连接失败"
            }
    
    @staticmethod
    def check_disk_space() -> Dict[str, Any]:
        """检查磁盘空间"""
        try:
            from pathlib import Path
            import shutil
            
            upload_dir = Path("uploads")
            if not upload_dir.exists():
                return {
                    "status": "warning",
                    "message": "上传目录不存在"
                }
            
            # 检查磁盘空间（如果可用）
            try:
                total, used, free = shutil.disk_usage(upload_dir)
                free_gb = free / (1024 ** 3)
                
                # 如果剩余空间少于1GB，警告
                if free_gb < 1:
                    return {
                        "status": "warning",
                        "free_space_gb": round(free_gb, 2),
                        "message": f"磁盘空间不足: {free_gb:.2f}GB 剩余"
                    }
                
                return {
                    "status": "healthy",
                    "free_space_gb": round(free_gb, 2),
                    "message": "磁盘空间充足"
                }
            except Exception:
                # 某些系统可能不支持磁盘空间检查
                return {
                    "status": "unknown",
                    "message": "无法检查磁盘空间"
                }
        except Exception as e:
            logger.error(f"磁盘空间检查失败: {e}")
            return {
                "status": "error",
                "error": str(e),
                "message": "磁盘空间检查失败"
            }
    
    @staticmethod
    def check_database_pool() -> Dict[str, Any]:
        """检查数据库连接池状态"""
        try:
            if not sync_engine:
                return {
                    "status": "not_available",
                    "message": "同步数据库引擎不可用"
                }
            
            pool = sync_engine.pool
            pool_size = pool.size()
            checked_out = pool.checkedout()
            overflow = pool.overflow()
            invalid = pool.invalid()
            
            # 计算使用率
            usage_percent = (checked_out / pool_size * 100) if pool_size > 0 else 0
            
            # 如果使用率超过80%，警告
            if usage_percent > 80:
                status = "warning"
                message = f"连接池使用率较高: {usage_percent:.1f}%"
            elif overflow > 0:
                status = "warning"
                message = f"连接池溢出: {overflow} 个溢出连接"
            else:
                status = "healthy"
                message = "连接池状态正常"
            
            return {
                "status": status,
                "pool_size": pool_size,
                "checked_out": checked_out,
                "overflow": overflow,
                "invalid": invalid,
                "usage_percent": round(usage_percent, 1),
                "message": message
            }
        except Exception as e:
            logger.error(f"连接池检查失败: {e}")
            return {
                "status": "error",
                "error": str(e),
                "message": "连接池检查失败"
            }
    
    @staticmethod
    async def comprehensive_health_check() -> Dict[str, Any]:
        """综合健康检查"""
        start_time = time.time()
        
        health_status = {
            "status": "healthy",
            "timestamp": format_iso_utc(get_utc_time()),
            "checks": {},
            "summary": {}
        }
        
        # 检查同步数据库
        db_sync_check = HealthChecker.check_database_sync()
        health_status["checks"]["database_sync"] = db_sync_check
        
        # 检查异步数据库
        db_async_check = await HealthChecker.check_database_async()
        health_status["checks"]["database_async"] = db_async_check
        
        # 检查Redis
        redis_check = HealthChecker.check_redis()
        health_status["checks"]["redis"] = redis_check
        
        # 检查磁盘空间
        disk_check = HealthChecker.check_disk_space()
        health_status["checks"]["disk"] = disk_check
        
        # 检查连接池
        pool_check = HealthChecker.check_database_pool()
        health_status["checks"]["database_pool"] = pool_check
        
        # 计算总体状态
        critical_checks = ["database_sync"]
        warning_count = 0
        error_count = 0
        
        for check_name, check_result in health_status["checks"].items():
            status = check_result.get("status", "unknown")
            if status == "unhealthy" or status == "error":
                if check_name in critical_checks:
                    health_status["status"] = "unhealthy"
                error_count += 1
            elif status == "warning":
                warning_count += 1
                if health_status["status"] == "healthy":
                    health_status["status"] = "degraded"
        
        # 添加摘要
        health_status["summary"] = {
            "total_checks": len(health_status["checks"]),
            "healthy": sum(1 for c in health_status["checks"].values() if c.get("status") == "healthy"),
            "warnings": warning_count,
            "errors": error_count,
            "response_time_ms": round((time.time() - start_time) * 1000, 2)
        }
        
        return health_status


# 创建全局实例
health_checker = HealthChecker()

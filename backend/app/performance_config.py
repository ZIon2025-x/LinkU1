"""
性能优化配置
根据环境和使用情况动态调整性能参数
"""

import os
from typing import Dict, Any
from app.config import Config

class PerformanceConfig:
    """性能配置类"""
    
    def __init__(self):
        self.environment = Config.ENVIRONMENT
        self.is_production = Config.IS_PRODUCTION
    
    def get_database_config(self) -> Dict[str, Any]:
        """获取数据库配置"""
        if self.is_production:
            return {
                "pool_size": int(os.getenv("DB_POOL_SIZE", "20")),
                "max_overflow": int(os.getenv("DB_MAX_OVERFLOW", "30")),
                "pool_timeout": int(os.getenv("DB_POOL_TIMEOUT", "30")),
                "pool_recycle": int(os.getenv("DB_POOL_RECYCLE", "1800")),
                "query_timeout": int(os.getenv("DB_QUERY_TIMEOUT", "30")),
                "echo": False,
                "echo_pool": False
            }
        else:
            return {
                "pool_size": int(os.getenv("DB_POOL_SIZE", "5")),
                "max_overflow": int(os.getenv("DB_MAX_OVERFLOW", "10")),
                "pool_timeout": int(os.getenv("DB_POOL_TIMEOUT", "30")),
                "pool_recycle": int(os.getenv("DB_POOL_RECYCLE", "3600")),
                "query_timeout": int(os.getenv("DB_QUERY_TIMEOUT", "30")),
                "echo": os.getenv("DB_ECHO", "false").lower() == "true",
                "echo_pool": False
            }
    
    def get_redis_config(self) -> Dict[str, Any]:
        """获取Redis配置"""
        return {
            "socket_connect_timeout": 5,
            "socket_timeout": 5,
            "retry_on_timeout": True,
            "health_check_interval": 30,
            "max_connections": int(os.getenv("REDIS_MAX_CONNECTIONS", "50")),
            "decode_responses": False
        }
    
    def get_cache_config(self) -> Dict[str, Any]:
        """获取缓存配置"""
        if self.is_production:
            return {
                "user_info_ttl": 30 * 60,  # 30分钟
                "task_list_ttl": 5 * 60,   # 5分钟
                "task_detail_ttl": 15 * 60, # 15分钟
                "message_ttl": 2 * 60,     # 2分钟
                "system_settings_ttl": 60 * 60, # 1小时
                "max_cache_size": int(os.getenv("CACHE_MAX_SIZE", "1000"))
            }
        else:
            return {
                "user_info_ttl": 5 * 60,   # 5分钟
                "task_list_ttl": 1 * 60,   # 1分钟
                "task_detail_ttl": 5 * 60, # 5分钟
                "message_ttl": 30,         # 30秒
                "system_settings_ttl": 10 * 60, # 10分钟
                "max_cache_size": int(os.getenv("CACHE_MAX_SIZE", "100"))
            }
    
    def get_rate_limit_config(self) -> Dict[str, Any]:
        """获取速率限制配置"""
        if self.is_production:
            return {
                "login_limit": 5,      # 每分钟5次登录尝试
                "register_limit": 3,   # 每分钟3次注册尝试
                "api_limit": 100,      # 每分钟100次API调用
                "upload_limit": 10,    # 每分钟10次文件上传
                "window": 60           # 时间窗口（秒）
            }
        else:
            return {
                "login_limit": 20,     # 开发环境更宽松
                "register_limit": 10,
                "api_limit": 500,
                "upload_limit": 50,
                "window": 60
            }
    
    def get_logging_config(self) -> Dict[str, Any]:
        """获取日志配置"""
        if self.is_production:
            return {
                "level": "INFO",
                "slow_query_threshold": 1.0,  # 1秒
                "slow_request_threshold": 2.0, # 2秒
                "log_queries": False,
                "log_requests": True
            }
        else:
            return {
                "level": "DEBUG",
                "slow_query_threshold": 0.5,  # 0.5秒
                "slow_request_threshold": 1.0, # 1秒
                "log_queries": True,
                "log_requests": True
            }
    
    def get_optimization_config(self) -> Dict[str, Any]:
        """获取优化配置"""
        return {
            "enable_query_optimization": True,
            "enable_cache_warming": self.is_production,
            "enable_connection_pooling": True,
            "enable_query_caching": True,
            "enable_response_compression": self.is_production,
            "enable_gzip": self.is_production,
            "max_response_size": int(os.getenv("MAX_RESPONSE_SIZE", "1048576")),  # 1MB
            "chunk_size": int(os.getenv("CHUNK_SIZE", "8192"))  # 8KB
        }
    
    def get_all_config(self) -> Dict[str, Any]:
        """获取所有配置"""
        return {
            "environment": self.environment,
            "is_production": self.is_production,
            "database": self.get_database_config(),
            "redis": self.get_redis_config(),
            "cache": self.get_cache_config(),
            "rate_limit": self.get_rate_limit_config(),
            "logging": self.get_logging_config(),
            "optimization": self.get_optimization_config()
        }


# 创建全局配置实例
performance_config = PerformanceConfig()

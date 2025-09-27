"""
应用配置模块
"""

import os
from typing import Optional


class Config:
    """应用配置类"""

    # 数据库配置
    DATABASE_URL = os.getenv(
        "DATABASE_URL", "postgresql+psycopg2://postgres:123123@localhost:5432/linku_db"
    )
    ASYNC_DATABASE_URL = os.getenv(
        "ASYNC_DATABASE_URL",
        "postgresql+asyncpg://postgres:123123@localhost:5432/linku_db",
    )

    # JWT配置
    SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))
    CLOCK_SKEW_TOLERANCE = int(os.getenv("CLOCK_SKEW_TOLERANCE", "300"))

    # Redis配置
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
    REDIS_DB = int(os.getenv("REDIS_DB", "0"))
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)
    USE_REDIS = os.getenv("USE_REDIS", "true").lower() == "true"  # 默认使用Redis

    # Cookie配置
    COOKIE_SECURE = (
        os.getenv("COOKIE_SECURE", "false").lower() == "true"
    )  # 开发环境设为false
    COOKIE_HTTPONLY = True
    COOKIE_SAMESITE = "lax"  # 改为lax，允许跨站请求携带Cookie
    COOKIE_DOMAIN = os.getenv("COOKIE_DOMAIN", None)

    # CORS配置
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080"
    ).split(",")

    # 安全配置
    SECURITY_HEADERS = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Referrer-Policy": "strict-origin-when-cross-origin",
    }

    @classmethod
    def get_redis_config(cls) -> Optional[dict]:
        """获取Redis配置，如果禁用则返回None"""
        if not cls.USE_REDIS:
            return None

        return {"url": cls.REDIS_URL, "decode_responses": True}


# 创建全局配置实例
_settings = Config()


def get_settings() -> Config:
    """获取应用配置实例"""
    return _settings

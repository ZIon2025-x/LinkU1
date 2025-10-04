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
    
    # Railway Redis配置检测
    if os.getenv("RAILWAY_ENVIRONMENT"):
        # 在Railway环境中，优先使用REDIS_URL
        if REDIS_URL and not REDIS_URL.startswith("redis://localhost"):
            # 使用Railway提供的Redis URL
            pass
        else:
            # 如果没有有效的Redis URL，禁用Redis
            USE_REDIS = False

    # Cookie配置 - 智能环境检测
    ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
    IS_PRODUCTION = ENVIRONMENT == "production"
    
    # 根据环境自动设置Cookie安全配置
    COOKIE_SECURE = (
        os.getenv("COOKIE_SECURE", "true" if IS_PRODUCTION else "false").lower() == "true"
    )
    COOKIE_HTTPONLY = True
    # 移动端兼容性：使用strict而不是lax，避免跨站请求问题
    COOKIE_SAMESITE = os.getenv("COOKIE_SAMESITE", "strict" if IS_PRODUCTION else "lax")
    COOKIE_DOMAIN = os.getenv("COOKIE_DOMAIN", None)
    
    # 移动端兼容性配置
    COOKIE_PATH = "/"
    COOKIE_MAX_AGE = 24 * 60 * 60  # 24小时
    
    # 移动端特殊配置
    MOBILE_COOKIE_SAMESITE = "lax"   # 移动端使用lax提高兼容性
    MOBILE_COOKIE_SECURE = False     # 移动端不使用secure避免HTTPS问题
    
    # 开发环境配置
    DEBUG = os.getenv("DEBUG", "true").lower() == "true"

    # CORS配置 - 安全配置
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080"
    ).split(",")
    
    # 过滤空字符串
    ALLOWED_ORIGINS = [origin.strip() for origin in ALLOWED_ORIGINS if origin.strip()]
    
    # 如果没有配置，使用默认安全配置
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == [""]:
        ALLOWED_ORIGINS = ["http://localhost:3000"]  # 默认只允许本地开发
    
    # 允许的HTTP方法
    ALLOWED_METHODS = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    
    # 允许的请求头
    ALLOWED_HEADERS = [
        "Content-Type", 
        "Authorization", 
        "X-CSRF-Token",
        "X-Requested-With",
        "Accept",
        "Origin"
    ]

    # 邮箱配置
    EMAIL_FROM = os.getenv("EMAIL_FROM", "noreply@linku.com")
    SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "")
    SMTP_PASS = os.getenv("SMTP_PASS", "")
    SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    SMTP_USE_SSL = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    
    # 邮箱验证配置
    EMAIL_VERIFICATION_EXPIRE_HOURS = int(os.getenv("EMAIL_VERIFICATION_EXPIRE_HOURS", "24"))
    
    # 开发环境配置 - 跳过邮件验证
    SKIP_EMAIL_VERIFICATION = os.getenv("SKIP_EMAIL_VERIFICATION", "true").lower() == "true"
    
    # 基础URL配置
    BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
    
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

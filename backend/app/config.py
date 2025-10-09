"""
应用配置模块
"""

import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class Config:
    """应用配置类"""

    # 数据库配置
    DATABASE_URL = os.getenv(
        "DATABASE_URL", "postgresql+psycopg2://postgres:password@localhost:5432/linku_db"
    )
    ASYNC_DATABASE_URL = os.getenv(
        "ASYNC_DATABASE_URL",
        "postgresql+asyncpg://postgres:password@localhost:5432/linku_db",
    )

    # JWT配置
    SECRET_KEY = os.getenv("SECRET_KEY", "change-this-secret-key-in-production")
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
    
    # Railway环境检测
    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT", None)
    
    # Railway Redis配置检测
    if RAILWAY_ENVIRONMENT:
        # 在Railway环境中，优先使用REDIS_URL
        if REDIS_URL and not REDIS_URL.startswith("redis://localhost"):
            # 使用Railway提供的Redis URL
            logger.info(f"[DEBUG] Railway Redis配置 - REDIS_URL: {REDIS_URL[:20]}...")
            logger.info(f"[DEBUG] Railway Redis配置 - USE_REDIS: {USE_REDIS}")
        else:
            # 如果没有有效的Redis URL，禁用Redis
            logger.warning(f"[DEBUG] Railway Redis配置 - 没有有效的Redis URL，禁用Redis")
            USE_REDIS = False

    # Cookie配置 - 智能环境检测
    ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
    # 检测是否为生产环境：Railway环境或明确设置为production
    IS_PRODUCTION = (
        ENVIRONMENT == "production" or 
        os.getenv("RAILWAY_ENVIRONMENT") is not None or
        os.getenv("RAILWAY_PROJECT_ID") is not None
    )
    
    # 根据环境自动设置Cookie安全配置
    COOKIE_SECURE = (
        os.getenv("COOKIE_SECURE", "true" if IS_PRODUCTION else "false").lower() == "true"
    )
    COOKIE_HTTPONLY = True
    # 跨子域名兼容性：生产环境使用lax而不是strict，允许跨子域名Cookie
    COOKIE_SAMESITE = os.getenv("COOKIE_SAMESITE", "lax")
    COOKIE_DOMAIN = os.getenv("COOKIE_DOMAIN", ".link2ur.com" if IS_PRODUCTION else None)
    
    # 移动端兼容性配置
    COOKIE_PATH = "/"
    COOKIE_MAX_AGE = 24 * 60 * 60  # 24小时
    
    # 移动端特殊配置
    MOBILE_COOKIE_SAMESITE = "lax"   # 移动端使用lax提高兼容性
    MOBILE_COOKIE_SECURE = True      # 移动端使用secure（HTTPS环境）
    
    # 开发环境配置
    DEBUG = os.getenv("DEBUG", "true").lower() == "true"

    # CORS配置 - 安全配置
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080,https://www.link2ur.com,https://api.link2ur.com"
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
    EMAIL_FROM = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
    SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.link2ur.com")  # 使用 link2ur.com 的 SMTP 服务器
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "no-reply@link2ur.com")
    SMTP_PASS = os.getenv("SMTP_PASS", "")
    SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    SMTP_USE_SSL = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    
    # 邮箱验证配置
    EMAIL_VERIFICATION_EXPIRE_HOURS = int(os.getenv("EMAIL_VERIFICATION_EXPIRE_HOURS", "24"))
    
    # SendGrid配置
    SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY", "")
    USE_SENDGRID = os.getenv("USE_SENDGRID", "false").lower() == "true"
    
    # Resend配置
    RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
    USE_RESEND = os.getenv("USE_RESEND", "false").lower() == "true"
    
    # 开发环境配置 - 跳过邮件验证
    SKIP_EMAIL_VERIFICATION = os.getenv("SKIP_EMAIL_VERIFICATION", "false").lower() == "true"
    
    # 基础URL配置
    BASE_URL = os.getenv("BASE_URL", "https://api.link2ur.com")
    FRONTEND_URL = os.getenv("FRONTEND_URL", "https://www.link2ur.com")
    
    # 安全配置
    SECURITY_HEADERS = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Referrer-Policy": "strict-origin-when-cross-origin",
        "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:;",
        "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
    }
    
    # 环境配置
    ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

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

"""
应用配置模块
"""

import os
import logging
from typing import Optional
from dotenv import load_dotenv

# 确保 .env 文件中的环境变量已加载（无论哪个模块先导入 config）
load_dotenv()

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
    SECRET_KEY = os.getenv("SECRET_KEY", "")
    SIGNED_URL_SECRET = os.getenv("SIGNED_URL_SECRET", "")
    if not SECRET_KEY:
        import warnings
        warnings.warn(
            "SECRET_KEY environment variable is not set! "
            "Using an insecure default for LOCAL DEVELOPMENT ONLY. "
            "Set SECRET_KEY in production!",
            RuntimeWarning,
            stacklevel=2
        )
        # 使用固定的开发密钥（不用随机值，避免多进程/热重载时JWT失效）
        SECRET_KEY = "linku-dev-only-insecure-key-do-not-use-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    REFRESH_TOKEN_EXPIRE_HOURS = int(os.getenv("REFRESH_TOKEN_EXPIRE_HOURS", "12"))  # 12小时
    CLOCK_SKEW_TOLERANCE = int(os.getenv("CLOCK_SKEW_TOLERANCE", "300"))

    # Redis配置
    # 主Redis URL（用于会话、认证等关键数据）
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
    REDIS_DB = int(os.getenv("REDIS_DB", "0"))
    
    # Celery专用Redis URL（用于任务队列，使用db=1避免与会话数据冲突）
    # 如果未设置，则从REDIS_URL派生使用db=1
    CELERY_REDIS_URL = os.getenv("CELERY_REDIS_URL", "")
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)
    USE_REDIS = os.getenv("USE_REDIS", "true").lower() == "true"  # 默认使用Redis
    
    # Railway环境检测
    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT", None)
    
    # 独立认证系统配置
    ADMIN_SESSION_EXPIRE_HOURS = int(os.getenv("ADMIN_SESSION_EXPIRE_HOURS", "8"))
    SERVICE_SESSION_EXPIRE_HOURS = int(os.getenv("SERVICE_SESSION_EXPIRE_HOURS", "12"))
    USER_SESSION_EXPIRE_HOURS = int(os.getenv("USER_SESSION_EXPIRE_HOURS", "24"))
    
    ADMIN_MAX_ACTIVE_SESSIONS = int(os.getenv("ADMIN_MAX_ACTIVE_SESSIONS", "3"))
    SERVICE_MAX_ACTIVE_SESSIONS = int(os.getenv("SERVICE_MAX_ACTIVE_SESSIONS", "2"))
    USER_MAX_ACTIVE_SESSIONS = int(os.getenv("USER_MAX_ACTIVE_SESSIONS", "5"))
    
    # Twilio SMS 配置
    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", None)
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", None)
    TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", None)  # Messages API 需要（需购买手机号）
    TWILIO_VERIFY_SERVICE_SID = os.getenv("TWILIO_VERIFY_SERVICE_SID", None)  # Verify API 需要（不需要购买手机号，推荐）
    
    # CAPTCHA 配置
    # CAPTCHA_DISABLED=true 可临时关闭所有人机验证（无需移除密钥）
    RECAPTCHA_SECRET_KEY = os.getenv("RECAPTCHA_SECRET_KEY", None)  # Google reCAPTCHA v3 Secret Key
    RECAPTCHA_SITE_KEY = os.getenv("RECAPTCHA_SITE_KEY", None)  # Google reCAPTCHA v3 Site Key
    HCAPTCHA_SECRET_KEY = os.getenv("HCAPTCHA_SECRET_KEY", None)  # hCaptcha Secret Key
    HCAPTCHA_SITE_KEY = os.getenv("HCAPTCHA_SITE_KEY", None)  # hCaptcha Site Key  # Twilio 分配的号码
    
    # Railway Redis配置检测
    if RAILWAY_ENVIRONMENT:
        # 在Railway环境中，优先使用REDIS_URL
        if REDIS_URL and not REDIS_URL.startswith("redis://localhost"):
            # 使用Railway提供的Redis URL
            logger.debug("Railway Redis配置 - REDIS_URL: %s...", REDIS_URL[:20] if REDIS_URL else "None")
            logger.debug("Railway Redis配置 - USE_REDIS: %s", USE_REDIS)
        else:
            # 如果没有有效的Redis URL，禁用Redis
            logger.debug("Railway Redis配置 - 没有有效的Redis URL，禁用Redis")
            USE_REDIS = False

    # Cookie配置 - 智能环境检测
    ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
    RAILWAY_ENV = os.getenv("RAILWAY_ENVIRONMENT", "").lower()

    # 检测是否为生产环境：明确的production标识
    # 注意：只有明确标记为production才视为生产环境，staging等视为非生产
    IS_PRODUCTION = (
        ENVIRONMENT == "production" or
        RAILWAY_ENV == "production"
    )
    
    # 根据环境自动设置Cookie安全配置
    COOKIE_SECURE = (
        os.getenv("COOKIE_SECURE", "true" if IS_PRODUCTION else "false").lower() == "true"
    )
    COOKIE_HTTPONLY = True
    # 跨子域名兼容性：生产环境使用lax而不是strict，允许跨子域名Cookie
    COOKIE_SAMESITE = os.getenv("COOKIE_SAMESITE", "lax")
    # COOKIE_DOMAIN 已移除 - 现在只使用当前域名（api.link2ur.com）的Cookie
    
    # 移动端兼容性配置
    COOKIE_PATH = "/"
    COOKIE_MAX_AGE = 24 * 60 * 60  # 24小时
    
    # 移动端特殊配置
    MOBILE_COOKIE_SAMESITE = "lax"   # 移动端使用lax提高兼容性
    MOBILE_COOKIE_SECURE = True      # 移动端使用secure（HTTPS环境）
    
    # 开发环境配置
    DEBUG = os.getenv("DEBUG", "true").lower() == "true"
    
    # 只读模式 — 设为 true 时拒绝所有写操作（POST/PUT/PATCH/DELETE），
    # 仅允许 GET/HEAD/OPTIONS，用于数据库维护期间保证最小可用性。
    # 可通过环境变量 READ_ONLY_MODE=true 开启，或通过 /admin/read-only 端点动态切换。
    READ_ONLY_MODE = os.getenv("READ_ONLY_MODE", "false").lower() == "true"

    # CORS配置 - 安全配置
    # 复用上面已定义的 IS_PRODUCTION（避免重复定义导致不一致）
    
    if IS_PRODUCTION:
        # 生产环境：允许主站、管理后台和客服系统
        ALLOWED_ORIGINS = os.getenv(
            "ALLOWED_ORIGINS", 
            "https://www.link2ur.com,https://link2ur.com,https://app.link2ur.com,https://admin.link2ur.com,https://service.link2ur.com"
        ).split(",")
    else:
        # 开发环境：允许本地开发服务器（主站3000，管理后台3001，客服系统3002）
        ALLOWED_ORIGINS = os.getenv(
            "ALLOWED_ORIGINS", 
            "http://localhost:3000,http://localhost:3001,http://localhost:3002,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:3001,http://127.0.0.1:3002"
        ).split(",")
    
    # 过滤空字符串
    ALLOWED_ORIGINS = [origin.strip() for origin in ALLOWED_ORIGINS if origin.strip()]
    
    # 如果没有配置，使用默认安全配置
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == [""]:
        if IS_PRODUCTION:
            ALLOWED_ORIGINS = ["https://www.link2ur.com"]  # 生产环境默认
        else:
            ALLOWED_ORIGINS = ["http://localhost:3000"]  # 开发环境默认
    
    # 允许的HTTP方法
    ALLOWED_METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    
    # 允许的请求头
    ALLOWED_HEADERS = [
        "Content-Type", 
        "Authorization", 
        "X-CSRF-Token",
        "X-Requested-With",
        "Accept",
        "Origin",
        "X-Session-ID",  # 移动端会话ID
        "X-User-ID",     # 移动端用户ID
        "Cache-Control", # 缓存控制
        "Pragma",        # 缓存控制
        "Expires"        # 过期时间（缓存控制）
    ]
    
    # 暴露的响应头（前端可以访问）
    EXPOSE_HEADERS = [
        "X-Total-Count",
        "X-Page-Count",
        "X-Page-Size",
        "X-Current-Page",
        "X-Requires-2FA",  # 2FA 验证需要
        "X-Requires-Verification"  # 邮箱验证需要
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
    
    # 管理员邮箱验证码配置
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "")  # 管理员邮箱地址
    ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES = int(os.getenv("ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES", "5"))  # 验证码过期时间（分钟）
    ENABLE_ADMIN_EMAIL_VERIFICATION = os.getenv("ENABLE_ADMIN_EMAIL_VERIFICATION", "true").lower() == "true"  # 是否启用管理员邮箱验证
    
    # 基础URL配置
    BASE_URL = os.getenv("BASE_URL", "https://api.link2ur.com")
    FRONTEND_URL = os.getenv("FRONTEND_URL", "https://www.link2ur.com")
    
    # 🔒 安全修复：验证 FRONTEND_URL 格式，防止开放重定向
    if FRONTEND_URL and not FRONTEND_URL.startswith(("https://", "http://localhost")):
        import logging as _logging
        _logging.getLogger(__name__).warning(f"FRONTEND_URL 使用非 HTTPS 协议: {FRONTEND_URL}")
    
    # 允许的前端域名白名单（用于重定向验证）
    ALLOWED_FRONTEND_ORIGINS = [
        "https://www.link2ur.com",
        "https://link2ur.com", 
        "https://linktest.up.railway.app",
        "http://localhost:3000",
        "http://localhost:5173",
    ]

    # OAuth 2.0 / OIDC Provider 配置
    OAUTH_ISSUER = os.getenv("OAUTH_ISSUER", "") or None  # 空则用 BASE_URL
    OAUTH_ACCESS_TOKEN_EXPIRE_SECONDS = int(os.getenv("OAUTH_ACCESS_TOKEN_EXPIRE_SECONDS", "3600"))
    OAUTH_REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("OAUTH_REFRESH_TOKEN_EXPIRE_DAYS", "30"))
    OAUTH_AUTHORIZATION_CODE_EXPIRE_SECONDS = int(os.getenv("OAUTH_AUTHORIZATION_CODE_EXPIRE_SECONDS", "600"))
    OAUTH_ACCESS_TOKEN_SECRET = os.getenv("OAUTH_ACCESS_TOKEN_SECRET", "") or None  # 空则用 SECRET_KEY
    OAUTH_ID_TOKEN_SECRET = os.getenv("OAUTH_ID_TOKEN_SECRET", "") or None  # 空则用 OAUTH_ACCESS_TOKEN_SECRET 或 SECRET_KEY

    # 翻译服务配置
    # 翻译服务优先级（用逗号分隔，按优先级排序）
    # 可选值: google_cloud, google, mymemory, libretranslate, pons, lingvanex, qcri, baidu, youdao, deepl, microsoft
    # google_cloud: Google Cloud Translation API（官方API，每月前50万字符免费）
    # google: deep-translator的Google翻译（免费但可能有限制）
    # mymemory: MyMemory翻译（免费，无需API密钥）
    # libretranslate: LibreTranslate（免费开源，可自建）
    # pons: Pons翻译（免费）
    # lingvanex: Lingvanex翻译（免费，有额度限制）
    # qcri: QCRI翻译（免费）
    # deepl: DeepL翻译（需要API密钥，但有免费额度）
    # 默认优先级：google, mymemory, libretranslate, pons, qcri, google_cloud（Google Cloud放在最后，需要配置）
    TRANSLATION_SERVICES = os.getenv("TRANSLATION_SERVICES", "google,mymemory,libretranslate,pons,qcri,google_cloud").split(",")
    
    # Google Cloud Translation API配置（官方API，推荐使用）
    # 方式1: 使用API密钥（简单）
    GOOGLE_CLOUD_TRANSLATE_API_KEY = os.getenv("GOOGLE_CLOUD_TRANSLATE_API_KEY", "")
    # 方式2: 使用服务账号JSON文件路径（更安全，推荐生产环境）
    GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH = os.getenv("GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH", "")
    # 方式3: 使用环境变量GOOGLE_APPLICATION_CREDENTIALS（Google Cloud默认方式）
    # 如果设置了GOOGLE_APPLICATION_CREDENTIALS环境变量，会自动使用
    
    # 其他翻译服务API密钥（如果需要）
    BAIDU_TRANSLATE_APPID = os.getenv("BAIDU_TRANSLATE_APPID", "")
    BAIDU_TRANSLATE_SECRET = os.getenv("BAIDU_TRANSLATE_SECRET", "")
    YOUDAO_TRANSLATE_APPID = os.getenv("YOUDAO_TRANSLATE_APPID", "")
    YOUDAO_TRANSLATE_SECRET = os.getenv("YOUDAO_TRANSLATE_SECRET", "")
    DEEPL_API_KEY = os.getenv("DEEPL_API_KEY", "")  # DeepL API密钥（可选，有免费额度）
    MICROSOFT_TRANSLATE_KEY = os.getenv("MICROSOFT_TRANSLATE_KEY", "")
    
    # LibreTranslate配置（免费开源）
    LIBRETRANSLATE_API_KEY = os.getenv("LIBRETRANSLATE_API_KEY", "")  # 可选，如果使用自建实例
    LIBRETRANSLATE_BASE_URL = os.getenv("LIBRETRANSLATE_BASE_URL", "")  # 可选，默认使用公共实例
    
    # Lingvanex配置（可选）
    LINGVANEX_API_KEY = os.getenv("LINGVANEX_API_KEY", "")  # 可选，某些功能需要
    
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
    
    # AI Agent 配置
    # ---- 小模型（意图识别/简单问答） ----
    AI_MODEL_SMALL = os.getenv("AI_MODEL_SMALL", "claude-haiku-4-5-20251001")
    AI_MODEL_SMALL_PROVIDER = os.getenv("AI_MODEL_SMALL_PROVIDER", "anthropic")  # anthropic / openai_compatible
    AI_MODEL_SMALL_API_KEY = os.getenv("AI_MODEL_SMALL_API_KEY", "")  # 空则复用 ANTHROPIC_API_KEY
    AI_MODEL_SMALL_BASE_URL = os.getenv("AI_MODEL_SMALL_BASE_URL", "")  # OpenAI 兼容 API base URL
    # ---- 大模型（复杂推理/多步工具调用） ----
    AI_MODEL_LARGE = os.getenv("AI_MODEL_LARGE", "claude-sonnet-4-5-20250929")
    AI_MODEL_LARGE_PROVIDER = os.getenv("AI_MODEL_LARGE_PROVIDER", "anthropic")  # anthropic / openai_compatible
    AI_MODEL_LARGE_API_KEY = os.getenv("AI_MODEL_LARGE_API_KEY", "")  # 空则复用 ANTHROPIC_API_KEY
    AI_MODEL_LARGE_BASE_URL = os.getenv("AI_MODEL_LARGE_BASE_URL", "")  # OpenAI 兼容 API base URL
    # ---- 通用 ----
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")  # 默认 API Key（Anthropic）
    # LLM 请求超时（秒）。GLM/智谱等首 token 可能较慢，建议小模型≥60
    AI_LLM_SMALL_TIMEOUT = float(os.getenv("AI_LLM_SMALL_TIMEOUT", "60"))
    AI_LLM_LARGE_TIMEOUT = float(os.getenv("AI_LLM_LARGE_TIMEOUT", "90"))
    # Token 限制
    AI_MAX_OUTPUT_TOKENS = int(os.getenv("AI_MAX_OUTPUT_TOKENS", "1024"))  # 单次回复上限
    AI_MAX_HISTORY_TURNS = int(os.getenv("AI_MAX_HISTORY_TURNS", "10"))   # 保留最近 N 轮
    # 速率与预算
    AI_RATE_LIMIT_RPM = int(os.getenv("AI_RATE_LIMIT_RPM", "10"))         # 每分钟请求数
    AI_DAILY_REQUEST_LIMIT = int(os.getenv("AI_DAILY_REQUEST_LIMIT", "100"))  # 每用户每天请求数
    AI_DAILY_TOKEN_BUDGET = int(os.getenv("AI_DAILY_TOKEN_BUDGET", "50000"))  # 每用户每天 token 预算
    AI_SESSION_TTL_HOURS = int(os.getenv("AI_SESSION_TTL_HOURS", "24"))
    # FAQ 缓存 TTL（秒）
    AI_FAQ_CACHE_TTL = int(os.getenv("AI_FAQ_CACHE_TTL", "3600"))  # 1 小时

    # 搜索配置
    USE_PG_TRGM = os.getenv("USE_PG_TRGM", "false").lower() == "true"  # 是否使用pg_trgm扩展
    SEARCH_LANGUAGE = os.getenv("SEARCH_LANGUAGE", "english")  # 全文搜索语言

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

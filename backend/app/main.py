import asyncio
import json
import logging
import os
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from app.utils.time_utils import get_utc_time, format_iso_utc
from pathlib import Path

# pytz已移除，统一使用zoneinfo
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    HTTPException,
    Request,
    Response,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.websockets import WebSocketState
from fastapi.responses import JSONResponse, FileResponse, Response
from sqlalchemy import inspect
from sqlalchemy.orm import Session

from app import crud
# auth_routes 已移除，使用 secure_auth_routes 替代
from app.secure_auth_routes import secure_auth_router
# 旧的客服认证路由已删除，使用新的独立认证系统
# 旧的管理员认证路由已删除，使用新的独立认证系统
from app.separate_auth_routes import router as separate_auth_router
from app.cs_auth_routes import cs_auth_router
from app.csrf_routes import router as csrf_router
from app.rate_limit_routes import router as rate_limit_router
from app.security_monitoring_routes import router as security_monitoring_router
from app.deps import get_db
from app.routers import router as main_router
from app.sitemap_routes import sitemap_router
from app.security import add_security_headers
from app.security_monitoring import check_security_middleware
from app.error_handlers import (
    http_exception_handler,
    validation_exception_handler,
    security_exception_handler,
    business_exception_handler,
    general_exception_handler,
    read_only_mode_handler,
    ReadOnlyModeError
)
from app.utils.check_dependencies import check_translation_dependencies
from app.error_handlers import SecurityError, ValidationError, BusinessError

# 设置日志（统一配置：结构化输出 + 日志轮转 + RequestID 注入）
try:
    from app.logging_config import configure_logging
    configure_logging()
except Exception as e:
    # 回退：确保最低限度的日志可用
    logging.basicConfig(level=logging.INFO)
    logging.getLogger(__name__).warning(f"日志系统配置失败，使用默认配置: {e}")

logger = logging.getLogger(__name__)

# 配置敏感信息日志过滤器
try:
    from app.logging_filters import setup_sensitive_data_filter
    setup_sensitive_data_filter()
    logger.info("敏感信息日志过滤器已启用")
except Exception as e:
    logger.warning(f"配置敏感信息日志过滤器时出错: {e}")

# 配置webhook详细日志过滤器（减少生产环境日志量）
try:
    from app.logging_filters import setup_webhook_verbose_log_filter
    setup_webhook_verbose_log_filter()
    logger.info("Webhook详细日志过滤器已启用（详细日志已降级为DEBUG）")
except Exception as e:
    logger.warning(f"配置webhook详细日志过滤器时出错: {e}")

# 添加日志过滤器，将 SQLAlchemy 连接池的事件循环错误降级为警告
# 这些错误不影响应用功能，只是连接池内部清理时的常见问题
class SQLAlchemyPoolErrorFilter(logging.Filter):
    def filter(self, record):
        # 只处理 SQLAlchemy 内部连接池的日志
        if not record.name.startswith("sqlalchemy.pool"):
            return True
        
        msg = record.getMessage()
        
        # 过滤掉连接池关闭时的事件循环错误
        if "Exception terminating connection" in msg:
            # 检查是否是事件循环关闭相关的错误
            if any(keyword in msg for keyword in [
                "Event loop is closed",
                "loop is closed",
            ]):
                # 降级为 DEBUG，因为这些是应用关闭时的正常情况
                record.levelno = logging.DEBUG
                record.levelname = "DEBUG"
                return True
            # "attached to a different loop" 需要关注，不降级
            if "attached to a different loop" in msg:
                # 保持原始级别，让这个错误正常暴露
                return True
        
        # 过滤掉 asyncpg 的协程未等待警告
        if "coroutine" in msg and "was never awaited" in msg and "Connection._cancel" in msg:
            # 这是连接关闭时的正常情况，降级为 DEBUG
            record.levelno = logging.DEBUG
            record.levelname = "DEBUG"
            return True
        
        return True

# 应用过滤器到 SQLAlchemy 连接池日志
sqlalchemy_pool_logger = logging.getLogger("sqlalchemy.pool")
sqlalchemy_pool_logger.addFilter(SQLAlchemyPoolErrorFilter())

# 也过滤 asyncpg 的警告（仅限连接取消相关的）
class AsyncPGConnectionFilter(logging.Filter):
    def filter(self, record):
        if not record.name.startswith("asyncpg"):
            return True
        
        msg = record.getMessage()
        if "coroutine" in msg and "was never awaited" in msg and "Connection._cancel" in msg:
            record.levelno = logging.DEBUG
            record.levelname = "DEBUG"
            return True
        
        return True

asyncpg_logger = logging.getLogger("asyncpg")
asyncpg_logger.addFilter(AsyncPGConnectionFilter())


# API 文档配置 - 生产环境禁用文档访问
from app.config import Config
docs_url = None if Config.IS_PRODUCTION else "/docs"
redoc_url = None if Config.IS_PRODUCTION else "/redoc"
openapi_url = None if Config.IS_PRODUCTION else "/openapi.json"

app = FastAPI(
    title="Link²Ur Task Platform",
    description="A simple task platform for students, freelancers, and job seekers.",
    version="0.1.0",
    docs_url=docs_url,
    redoc_url=redoc_url,
    openapi_url=openapi_url,
)

# 添加CORS中间件 - 使用安全配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=Config.ALLOWED_METHODS,
    allow_headers=Config.ALLOWED_HEADERS,
    expose_headers=Config.EXPOSE_HEADERS,
    max_age=3600,  # 预检请求缓存1小时
)

# P2 优化：添加 GZip 响应压缩中间件
# 压缩大于 1000 字节的响应，减少带宽使用
app.add_middleware(GZipMiddleware, minimum_size=1000)

# 请求日志中间件 — 记录所有请求的方法、路径、状态码、响应时间，并生成 X-Request-ID
from app.request_logging_middleware import RequestLoggingMiddleware
app.add_middleware(RequestLoggingMiddleware)

# 安全中间件 - 必须在CORS中间件之后
from app.middleware.security import security_headers_middleware
app.middleware("http")(security_headers_middleware)

# 管理员安全中间件 - 专门保护 admin 子域名
from app.admin_security_middleware import admin_security_middleware
app.middleware("http")(admin_security_middleware)

# 安全监控中间件（纯异步实现，仅使用内存数据结构，无 DB 依赖）
@app.middleware("http")
async def security_monitoring_middleware(request: Request, call_next):
    """安全监控中间件"""
    return await check_security_middleware(request, call_next)

# ==================== 只读模式中间件 ====================
# 在 READ_ONLY_MODE 开启时，拒绝所有写操作（POST/PUT/PATCH/DELETE），
# 仅放行 GET/HEAD/OPTIONS 以及健康检查端点，保证最小可读性。
@app.middleware("http")
async def read_only_mode_middleware(request: Request, call_next):
    """只读模式中间件 — DB 维护期间拒绝写操作"""
    if Config.READ_ONLY_MODE and request.method in ("POST", "PUT", "PATCH", "DELETE"):
        # 放行健康检查和存活探测
        safe_paths = ("/health", "/live", "/ping", "/", "/metrics")
        if request.url.path not in safe_paths:
            raise ReadOnlyModeError()
    return await call_next(request)


@app.middleware("http")
async def add_noindex_header(request: Request, call_next):
    """为API端点添加noindex头，防止搜索引擎索引"""
    try:
        response = await call_next(request)
    except Exception:
        # 让异常传播到全局异常处理器
        raise
    
    # 检查是否是API端点或API域名
    is_api_path = request.url.path.startswith("/api")
    is_api_domain = request.url.hostname and (
        request.url.hostname == "api.link2ur.com" or 
        request.url.hostname.startswith("api.link2ur.com")
    )
    
    if is_api_path or is_api_domain:
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
    
    return response

@app.middleware("http")
async def custom_cors_middleware(request: Request, call_next):
    """自定义CORS中间件，覆盖Railway默认设置"""
    origin = request.headers.get("origin")
    # 使用 Config.ALLOWED_ORIGINS（从环境变量读取）
    allowed_origins = Config.ALLOWED_ORIGINS
    
    def is_allowed_origin(origin: str) -> bool:
        """检查origin是否在允许列表中"""
        if not origin:
            return False
        # 精确匹配或前缀匹配
        for allowed in allowed_origins:
            if origin == allowed or origin.startswith(allowed.rstrip('/')):
                return True
        return False
    
    def set_cors_headers(response: Response):
        """设置CORS响应头（使用 Config.ALLOWED_HEADERS，含 X-App-Platform 等）"""
        if origin and is_allowed_origin(origin):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = ", ".join(Config.ALLOWED_HEADERS)
            response.headers["Access-Control-Max-Age"] = "86400"  # 24小时
    
    # 处理OPTIONS预检请求
    if request.method == "OPTIONS":
        response = Response(status_code=200)
        set_cors_headers(response)
        return response
    
    # 处理实际请求
    try:
        response = await call_next(request)
    except Exception as e:
        # 让异常传播到全局异常处理器，异常处理器会设置CORS头
        # 不要在这里创建响应，否则会导致响应状态不一致
        raise
    
    # 强制设置CORS头（包括错误响应）
    set_cors_headers(response)
    add_security_headers(response)
    return response

# DEBUG 中间件已移除 - 性能优化

app.include_router(main_router, prefix="/api/users", tags=["users"])

# 客服端员工通知（/api/users/staff/notifications*），需在 main_router 之后注册以便优先匹配
from app.staff_notification_routes import router as staff_notification_router
app.include_router(staff_notification_router, prefix="/api/users", tags=["客服-员工通知"])

# ==================== 管理员子域名路由（优先于 main_router 注册以确保正确匹配） ====================
# 管理员推荐系统路由
from app.admin_recommendation_routes import router as admin_recommendation_router
app.include_router(admin_recommendation_router, tags=["管理员-推荐系统"])

# 管理员任务争议管理路由
from app.admin_dispute_routes import router as admin_dispute_router
app.include_router(admin_dispute_router, tags=["管理员-任务争议管理"])

# 管理员退款管理路由
from app.admin_refund_routes import router as admin_refund_router
app.include_router(admin_refund_router, tags=["管理员-退款管理"])

# 管理员VIP订阅管理路由
from app.admin_vip_routes import router as admin_vip_router
app.include_router(admin_vip_router, tags=["管理员-VIP订阅管理"])

# 管理员用户管理路由
from app.admin_user_management_routes import router as admin_user_management_router
app.include_router(admin_user_management_router, tags=["管理员-用户管理"])

# 管理员任务管理路由
from app.admin_task_management_routes import router as admin_task_management_router
app.include_router(admin_task_management_router, tags=["管理员-任务管理"])

# 管理员客服管理路由
from app.admin_customer_service_routes import router as admin_customer_service_router
app.include_router(admin_customer_service_router, tags=["管理员-客服管理"])

# 管理员支付管理路由
from app.admin_payment_routes import router as admin_payment_router
app.include_router(admin_payment_router, tags=["管理员-支付管理"])

# 管理员系统设置路由
from app.admin_system_routes import router as admin_system_router
app.include_router(admin_system_router, tags=["管理员-系统设置"])

# 管理员通知管理路由
from app.admin_notification_routes import router as admin_notification_router
app.include_router(admin_notification_router, tags=["管理员-通知管理"])

# 管理员内容审核路由
from app.admin_content_moderation_routes import router as admin_content_moderation_router
app.include_router(admin_content_moderation_router, tags=["管理员-内容审核"])

# ==================== 画像路由（必须在 main_router 之前，否则 /profile/{user_id} 通配符会拦截 /profile/summary 等） ====================
from app.routes.user_profile import router as user_profile_router
app.include_router(user_profile_router)

# ==================== 主路由（包含所有未迁移的路由） ====================
app.include_router(main_router, prefix="/api", tags=["main"])  # 添加主路由，包含图片上传API
# auth_router 已移除，使用 secure_auth_router 替代
app.include_router(secure_auth_router, tags=["安全认证"]) # 使用新的安全认证系统
# 旧的客服认证路由已删除，使用新的独立认证系统
# 旧的管理员认证路由已删除，使用新的独立认证系统
app.include_router(separate_auth_router, prefix="/api/auth", tags=["独立认证系统"])  # 新增独立认证系统
app.include_router(cs_auth_router, tags=["客服认证"])  # 客服认证路由
# 管理员 2FA 路由
from app.admin_2fa_routes import router as admin_2fa_router
app.include_router(admin_2fa_router, prefix="/api/auth", tags=["管理员-2FA"])
app.include_router(csrf_router, tags=["CSRF保护"])
app.include_router(rate_limit_router, tags=["速率限制"])

# OAuth 2.0 / OIDC Provider（/.well-known 需尽早注册以便匹配）
from app.oauth.oauth_routes import oauth_router
app.include_router(oauth_router)

# OAuth 客户端管理（管理员）
from app.oauth_admin_routes import router as oauth_admin_router
app.include_router(oauth_admin_router)

# 添加时间检查端点
from app.time_check_endpoint import router as time_check_router
app.include_router(time_check_router, tags=["时间检查"])

# 添加清理任务端点
from app.cleanup_routes import router as cleanup_router
app.include_router(cleanup_router, prefix="/api/cleanup", tags=["数据清理"])

# Add time validation endpoint
from app.time_validation_endpoint import router as time_validation_router
app.include_router(time_validation_router, tags=["时间验证"])

# 添加sitemap路由（不需要/api前缀，直接访问/sitemap.xml）
app.include_router(sitemap_router, tags=["SEO"])

# 添加 AI 友好路由（为AI爬虫和AI助手提供结构化数据）
from app.ai_friendly_routes import ai_router
app.include_router(ai_router, prefix="/api", tags=["AI友好端点"])

# 添加 SSR 路由（为社交媒体爬虫提供正确的 Open Graph meta 标签）
from app.ssr_routes import ssr_router
app.include_router(ssr_router, tags=["SSR"])

# 添加Analytics路由（用于收集Web Vitals性能指标）
from app.analytics_routes import router as analytics_router
app.include_router(analytics_router, tags=["Analytics"])

# 暂时禁用安全监控路由以解决异步/同步混用问题
# app.include_router(security_monitoring_router, tags=["安全监控"])

# 注册全局异常处理器
from fastapi.exceptions import RequestValidationError
from fastapi import HTTPException
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(SecurityError, security_exception_handler)
app.add_exception_handler(BusinessError, business_exception_handler)
app.add_exception_handler(ReadOnlyModeError, read_only_mode_handler)
app.add_exception_handler(Exception, general_exception_handler)

# AI 任务描述优化接口
from app.routes.ai_optimize import router as ai_optimize_router
app.include_router(ai_optimize_router)

# 添加任务相关的路由（不需要/users前缀）
from app.async_routers import async_router

# 先注册异步路由，确保优先级
app.include_router(async_router, prefix="/api", tags=["async"])

# 添加任务聊天功能路由
from app.task_chat_routes import task_chat_router
app.include_router(task_chat_router, prefix="/api", tags=["任务聊天"])

# 添加优惠券和积分系统路由
from app.coupon_points_routes import router as coupon_points_router
app.include_router(coupon_points_router, tags=["优惠券和积分系统"])

from app.stripe_connect_routes import router as stripe_connect_router
app.include_router(stripe_connect_router, tags=["Stripe Connect"])

# 添加管理员优惠券和积分系统路由
from app.admin_coupon_points_routes import router as admin_coupon_points_router
app.include_router(admin_coupon_points_router, tags=["管理员-优惠券和积分系统"])

# 数据库管理工具
from app.admin_db_tools import router as admin_db_tools_router
app.include_router(admin_db_tools_router, tags=["管理员-数据库工具"])

# 任务达人功能路由
from app.task_expert_routes import task_expert_router
app.include_router(task_expert_router)

# 添加自定义排行榜路由
from app.custom_leaderboard_routes import router as custom_leaderboard_router
app.include_router(custom_leaderboard_router)

from app.user_service_application_routes import user_service_application_router
app.include_router(user_service_application_router)

# 个人服务 CRUD 路由
from app.personal_service_routes import personal_service_router
app.include_router(personal_service_router)

# 服务评价路由
from app.service_review_routes import service_review_router
app.include_router(service_review_router)

# 服务浏览（公开）路由
from app.service_browse_routes import service_browse_router
app.include_router(service_browse_router)

from app.admin_task_expert_routes import admin_task_expert_router
app.include_router(admin_task_expert_router)

# 跳蚤市场路由
from app.flea_market_routes import flea_market_router
app.include_router(flea_market_router)

# 跳蚤市场租赁路由
from app.flea_market_rental_routes import rental_router
app.include_router(rental_router)

# 多人任务路由
from app.multi_participant_routes import router as multi_participant_router
app.include_router(multi_participant_router)

# 论坛路由
from app.forum_routes import router as forum_router
app.include_router(forum_router)

# 热搜榜路由
from app.trending_routes import router as trending_router
app.include_router(trending_router)

# Discovery Feed 路由
from app.discovery_routes import router as discovery_router
app.include_router(discovery_router)

# Follow 系统路由
from app.follow_routes import router as follow_router
app.include_router(follow_router)

# Follow Feed 路由
from app.follow_feed_routes import router as follow_feed_router
app.include_router(follow_feed_router)

# Ticker 动态路由
from app.ticker_routes import router as ticker_router
app.include_router(ticker_router)

# 学生认证路由
from app.student_verification_routes import router as student_verification_router
app.include_router(student_verification_router, prefix="/api/student-verification", tags=["学生认证"])

# 学生认证管理路由
from app.admin_student_verification_routes import router as admin_student_verification_router
app.include_router(admin_student_verification_router, prefix="/api/admin", tags=["管理员-学生认证"])

# Banner 广告管理路由
from app.admin_banner_routes import router as admin_banner_router
app.include_router(admin_banner_router, tags=["管理员-Banner广告管理"])

# 优化版图片上传路由 (V2)
from app.upload_routes import router as upload_v2_router
app.include_router(upload_v2_router, tags=["图片上传V2"])

# AI Agent 路由
from app.ai_agent_routes import router as ai_agent_router
app.include_router(ai_agent_router, tags=["AI Agent"])

# 官方账号 & 官方活动管理路由
from app.admin_official_routes import admin_official_router
app.include_router(admin_official_router, tags=["管理员-官方账号与活动"])
from app.official_activity_routes import official_activity_router
app.include_router(official_activity_router)

# Newbie Tasks & Incentive System
from app.routes.newbie_tasks import router as newbie_tasks_router
app.include_router(newbie_tasks_router, tags=["新手任务"])

from app.routes.user_skills import router as user_skills_router
app.include_router(user_skills_router, tags=["用户技能"])

from app.routes.official_tasks import router as official_tasks_router
app.include_router(official_tasks_router, tags=["官方任务"])

from app.routes.leaderboard import router as leaderboard_router
app.include_router(leaderboard_router, tags=["技能排行榜"])

from app.routes.badges import router as badges_router
app.include_router(badges_router, tags=["勋章系统"])

from app.routes.admin_incentive import router as admin_incentive_router
app.include_router(admin_incentive_router, tags=["管理员-激励系统"])

# 图片代理（Flutter Web 跨域加载 Cloudflare/CDN 图片）
from app.image_proxy_routes import router as image_proxy_router
app.include_router(image_proxy_router, prefix="/api", tags=["图片代理"])

from app.routes.questions import router as questions_router
app.include_router(questions_router)

# 钱包系统路由
from app.wallet_routes import router as wallet_router
app.include_router(wallet_router, tags=["钱包系统"])

# 达人团队路由
from app.expert_routes import expert_router
app.include_router(expert_router)

from app.admin_expert_routes import admin_expert_router
app.include_router(admin_expert_router)
from app.expert_service_routes import expert_service_router
app.include_router(expert_service_router)

from app.chat_participant_routes import chat_participant_router
app.include_router(chat_participant_router)

from app.expert_package_routes import expert_package_router
app.include_router(expert_package_router)

from app.expert_marketing_routes import expert_marketing_router
app.include_router(expert_marketing_router)

from app.expert_consultation_routes import consultation_router
app.include_router(consultation_router)

from app.group_buy_routes import group_buy_router
app.include_router(group_buy_router)

from app.expert_timeslot_routes import expert_timeslot_router, public_service_router
app.include_router(expert_timeslot_router)
app.include_router(public_service_router)

from app.expert_dashboard_routes import expert_dashboard_router
app.include_router(expert_dashboard_router)

from app.expert_activity_routes import router as expert_activity_router
app.include_router(expert_activity_router)

# 创建上传目录
import os
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")

if RAILWAY_ENVIRONMENT:
    # Railway环境：使用持久化卷
    UPLOAD_DIR = Path("/data/uploads")
    # 公开目录（用于静态文件服务）
    (UPLOAD_DIR / "public").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images").mkdir(parents=True, exist_ok=True)
    # 创建分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "public" / "images" / "expert_avatars").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "service_images").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "public").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "leaderboard_items").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "leaderboard_covers").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "banner").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "files").mkdir(parents=True, exist_ok=True)
    # 私有目录（需要签名URL访问）
    (UPLOAD_DIR / "private").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private" / "images").mkdir(parents=True, exist_ok=True)
    # 创建私密图片分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "private_images" / "tasks").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private_images" / "chats").mkdir(parents=True, exist_ok=True)
    # 创建私密文件分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "private_files" / "tasks").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private_files" / "chats").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private" / "files").mkdir(parents=True, exist_ok=True)
    # 跳蚤市场图片目录
    (UPLOAD_DIR / "flea_market").mkdir(parents=True, exist_ok=True)
else:
    # 本地开发环境
    UPLOAD_DIR = Path("uploads")
    UPLOAD_DIR.mkdir(exist_ok=True)
    # 公开目录
    (UPLOAD_DIR / "public").mkdir(exist_ok=True)
    (UPLOAD_DIR / "public" / "images").mkdir(exist_ok=True)
    # 创建分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "public" / "images" / "expert_avatars").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "service_images").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "public").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "leaderboard_items").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "leaderboard_covers").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images" / "banner").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "files").mkdir(exist_ok=True)
    # 私有目录
    (UPLOAD_DIR / "private").mkdir(exist_ok=True)
    (UPLOAD_DIR / "private" / "images").mkdir(exist_ok=True)
    # 创建私密图片分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "private_images" / "tasks").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private_images" / "chats").mkdir(parents=True, exist_ok=True)
    # 创建私密文件分类子目录（子文件夹会在上传时按需创建）
    (UPLOAD_DIR / "private_files" / "tasks").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private_files" / "chats").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private" / "files").mkdir(exist_ok=True)

# 添加静态文件服务 - 只允许访问公开目录
# 注意：在生产环境中，StaticFiles可能无法正常工作，因此我们使用路由来处理
if RAILWAY_ENVIRONMENT:
    # Railway环境：使用路由方式提供静态文件访问
    @app.get("/uploads/{file_path:path}")
    async def serve_public_uploads(file_path: str):
        """提供公开上传文件的访问（包括跳蚤市场图片）"""
        from fastapi.responses import FileResponse
        import mimetypes
        
        # 支持跳蚤市场图片路径：/uploads/flea_market/{item_id}/{filename}
        # 其他公开文件：/uploads/public/images/public/{task_id}/{filename} 等
        # 存储 path 格式为 "public/images/public/163/xxx" 或 "flea_market/..."，均在 /data/uploads 下
        #
        # 兼容旧格式：/uploads/images/service_images/...、/uploads/images/leaderboard_covers/... 等
        # 实际文件在 public/images/... 下，将 images/ 重写为 public/images/
        if file_path.startswith("images/") and not file_path.startswith("public/"):
            file_path = "public/" + file_path
        file_full_path = Path("/data/uploads") / file_path

        # 安全检查：确保路径在 /data/uploads 内，防止路径遍历
        try:
            file_full_path.resolve().relative_to(Path("/data/uploads").resolve())
        except ValueError:
            raise HTTPException(status_code=403, detail="访问被拒绝")
        
        if not file_full_path.exists():
            raise HTTPException(status_code=404, detail="文件不存在")
        
        # 检查是否是文件而不是目录
        if not file_full_path.is_file():
            raise HTTPException(status_code=404, detail="文件不存在")
        
        # 获取MIME类型
        media_type, _ = mimetypes.guess_type(str(file_full_path))
        if not media_type:
            media_type = "application/octet-stream"
        
        return FileResponse(
            path=str(file_full_path),
            media_type=media_type,
            headers={
                "Cache-Control": "public, max-age=31536000",
            }
        )
else:
    # 本地开发环境：使用静态文件服务
    # 注意：StaticFiles只支持单个目录，需要添加路由处理跳蚤市场图片
    app.mount("/uploads/public", StaticFiles(directory="uploads/public"), name="uploads_public")
    
    # 跳蚤市场图片路由
    @app.get("/uploads/flea_market/{file_path:path}")
    async def serve_flea_market_images(file_path: str):
        """提供跳蚤市场图片的访问"""
        from fastapi.responses import FileResponse
        import mimetypes
        
        file_full_path = Path("uploads/flea_market") / file_path
        
        # 安全检查
        try:
            file_full_path.resolve().relative_to(Path("uploads/flea_market").resolve())
        except ValueError:
            raise HTTPException(status_code=403, detail="访问被拒绝")
        
        if not file_full_path.exists() or not file_full_path.is_file():
            raise HTTPException(status_code=404, detail="文件不存在")
        
        media_type, _ = mimetypes.guess_type(str(file_full_path))
        if not media_type:
            media_type = "application/octet-stream"
        
        return FileResponse(
            path=str(file_full_path),
            media_type=media_type,
            headers={
                "Cache-Control": "public, max-age=31536000",
            }
        )

    # 兼容旧格式：/uploads/images/service_images/...、/uploads/images/leaderboard_covers/... 等
    # 实际文件在 uploads/public/images/ 下
    @app.get("/uploads/images/{file_path:path}")
    async def serve_uploads_images_compat(file_path: str):
        from fastapi.responses import FileResponse
        import mimetypes
        file_full_path = Path("uploads/public/images") / file_path
        try:
            file_full_path.resolve().relative_to(Path("uploads/public/images").resolve())
        except ValueError:
            raise HTTPException(status_code=403, detail="访问被拒绝")
        if not file_full_path.exists() or not file_full_path.is_file():
            raise HTTPException(status_code=404, detail="文件不存在")
        media_type, _ = mimetypes.guess_type(str(file_full_path))
        if not media_type:
            media_type = "application/octet-stream"
        return FileResponse(
            path=str(file_full_path),
            media_type=media_type,
            headers={"Cache-Control": "public, max-age=31536000"}
        )

# /static 静态资源（头像、客服图标等），供客服/管理端请求 API 域名下的 /static/xxx.png
# 若文件存在则返回文件，否则返回 1x1 透明 PNG 占位，避免 404
_STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
_PLACEHOLDER_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
    b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)

@app.get("/static/{file_path:path}")
async def serve_static(file_path: str):
    if not file_path or ".." in file_path:
        raise HTTPException(status_code=403, detail="访问被拒绝")
    full_path = _STATIC_DIR / file_path
    try:
        full_path.resolve().relative_to(_STATIC_DIR.resolve())
    except (ValueError, OSError):
        raise HTTPException(status_code=403, detail="访问被拒绝")
    if full_path.is_file():
        import mimetypes
        media_type, _ = mimetypes.guess_type(str(full_path))
        if not media_type:
            media_type = "application/octet-stream"
        return FileResponse(
            path=str(full_path),
            media_type=media_type,
            headers={"Cache-Control": "public, max-age=86400"},
        )
    # 图片类请求返回占位图，避免前端 404
    if file_path.lower().endswith((".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")):
        return Response(
            content=_PLACEHOLDER_PNG,
            media_type="image/png",
            headers={"Cache-Control": "public, max-age=3600"},
        )
    raise HTTPException(status_code=404, detail="文件不存在")

# 使用 WebSocket 管理器进行连接池管理
from app.websocket_manager import get_ws_manager

# 向后兼容：保留 active_connections 字典（通过 WebSocketManager 访问）
def get_active_connections():
    """获取活跃连接字典（向后兼容）"""
    ws_manager = get_ws_manager()
    return {user_id: conn.websocket for user_id, conn in ws_manager.connections.items() if conn.is_alive}

# 用户级连接锁，确保原子替换（通过 WebSocketManager 访问）
def get_connection_locks():
    """获取连接锁字典（向后兼容）"""
    ws_manager = get_ws_manager()
    return ws_manager.connection_locks

# 全局变量：保存后台任务引用，用于优雅关闭
_background_cleanup_task = None
_shutdown_flag = False


async def close_old_connection(old_websocket: WebSocket, user_id: str):
    """异步关闭旧连接，使用正常关闭码和固定reason"""
    try:
        from app.constants import WS_CLOSE_CODE_NORMAL, WS_CLOSE_REASON_NEW_CONNECTION
        # 使用1000（正常关闭）配合固定reason，作为协议契约
        await old_websocket.close(
            code=WS_CLOSE_CODE_NORMAL, 
            reason=WS_CLOSE_REASON_NEW_CONNECTION  # 固定文案，不要随意修改
        )
        logger.debug(f"Closed existing WebSocket connection for user {user_id}")
    except Exception as e:
        logger.debug(f"Error closing old WebSocket for user {user_id}: {e}")


async def heartbeat_loop(websocket: WebSocket, user_id: str):
    """心跳循环，使用业务循环统一处理（方案B）"""
    ping_interval = 20  # 20秒发送一次ping
    max_missing_pongs = 3  # 连续3次未收到pong才断开
    missing_pongs = 0
    last_ping_time = get_utc_time()  # 统一使用UTC时间
    
    try:
        while True:
            # 检查是否需要发送ping
            current_time = get_utc_time()  # 统一使用UTC时间
            if (current_time - last_ping_time).total_seconds() >= ping_interval:
                try:
                    # 使用业务帧发送ping（仅在框架不支持websocket.ping()时）
                    await websocket.send_json({"type": "ping"})
                    last_ping_time = current_time
                except Exception as e:
                    logger.error(f"Failed to send ping to user {user_id}: {e}")
                    break
            
            # 统一接收消息（心跳和业务消息都在这里处理，避免竞争）
            try:
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=5.0
                )
                
                msg = json.loads(data)
                
                # 处理pong响应
                if msg.get("type") == "pong":
                    missing_pongs = 0
                    continue
                
                # 处理业务消息（转发给主循环）
                # 注意：这里只处理心跳，业务消息由主循环处理
                # 如果收到非pong消息，说明是业务消息，需要特殊处理
                
            except asyncio.TimeoutError:
                # 超时检查pong
                missing_pongs += 1
                if missing_pongs >= max_missing_pongs:
                    # ⚠️ 使用非1000的关闭码（4001），前端需要重连
                    from app.constants import WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    await websocket.close(
                        code=WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
                        reason=WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    )
                    break
            except Exception as e:
                logger.error(f"Heartbeat error for user {user_id}: {e}")
                break
    except asyncio.CancelledError:
        logger.debug(f"Heartbeat cancelled for user {user_id}")
    except Exception as e:
        logger.error(f"Heartbeat loop error for user {user_id}: {e}")


# 后台任务：自动取消过期任务
def cancel_expired_tasks():
    """自动取消已过期的未接受任务"""
    from app.database import SessionLocal
    from app.task_scheduler import DBUnavailableError, _is_db_connection_error

    db = None
    try:
        db = SessionLocal()
        cancelled_count = crud.cancel_expired_tasks(db)
        if cancelled_count > 0:
            logger.info(f"成功取消 {cancelled_count} 个过期任务")

    except Exception as e:
        if _is_db_connection_error(e):
            raise DBUnavailableError(f"取消过期任务时数据库不可用: {e}") from e
        logger.error(f"自动取消过期任务时出错: {e}")
    finally:
        if db:
            db.close()


def update_all_users_statistics():
    """更新所有用户的统计信息（使用分页批处理，避免一次性加载所有用户到内存）"""
    from app.database import SessionLocal
    from app.models import User
    from app.task_scheduler import DBUnavailableError, _is_db_connection_error

    db = None
    try:
        db = SessionLocal()
        updated_count = 0
        page_size = 100
        offset = 0
        
        while True:
            # 分页查询，只获取用户ID，减少内存占用
            user_ids = db.query(User.id).limit(page_size).offset(offset).all()
            if not user_ids:
                break
            
            for (user_id,) in user_ids:
                try:
                    crud.update_user_statistics(db, str(user_id))
                    updated_count += 1
                except Exception as e:
                    if _is_db_connection_error(e):
                        raise DBUnavailableError(f"更新用户统计时数据库不可用: {e}") from e
                    logger.error(f"更新用户 {user_id} 统计信息时出错: {e}")
                    continue
            
            offset += page_size

        if updated_count > 0:
            logger.info(f"成功更新 {updated_count} 个用户的统计信息")

    except DBUnavailableError:
        raise
    except Exception as e:
        if _is_db_connection_error(e):
            raise DBUnavailableError(f"更新用户统计时数据库不可用: {e}") from e
        logger.error(f"更新用户统计信息时出错: {e}")
    finally:
        if db:
            db.close()


def run_background_task():
    """运行后台任务循环
    
    注意：大部分任务已由 Celery Beat 接管，这里只保留未被 Celery 覆盖的任务
    - cancel_expired_tasks: 已由 Celery cancel-expired-tasks 处理
    - update_all_users_statistics: 已由 Celery update-all-users-statistics 处理
    - update_all_task_experts_bio: 仍在此执行（每天一次）
    """
    import datetime
    global _shutdown_flag
    last_bio_update_date = None  # 记录上次更新 bio 的日期
    
    # 🔒 安全修复：使用事件等待替代阻塞 time.sleep，以便及时响应关闭信号
    import threading
    _bg_shutdown_event = threading.Event()
    
    while not _shutdown_flag:
        try:
            # 更新所有任务达人的 bio（每天执行一次，Celery 未覆盖此任务）
            current_date = datetime.date.today()
            if last_bio_update_date != current_date:
                logger.info("开始更新所有任务达人的 bio...")
                crud.update_all_task_experts_bio()
                last_bio_update_date = current_date
                logger.info("任务达人 bio 更新完成")

            # 每10分钟检查一次（使用事件等待，关闭时立即唤醒）
            _bg_shutdown_event.wait(timeout=600)
            if _shutdown_flag:
                break
        except Exception as e:
            logger.error(f"后台任务循环出错: {e}")
            _bg_shutdown_event.wait(timeout=600)
            if _shutdown_flag:
                break


def cleanup_all_sessions_unified():
    """
    统一的会话清理函数
    
    注意: Redis 使用 TTL 自动过期，无需手动清理会话
    此函数保留仅用于接口兼容性
    """
    # Redis TTL 自动处理，无需操作
    pass


def run_session_cleanup_task():
    """
    ⚠️ 已废弃：Redis 使用 TTL 自动过期，无需手动清理会话
    保留此函数仅用于兼容性，实际不执行任何操作
    """
    # 不再启动循环，直接返回
    logger.debug("run_session_cleanup_task 已废弃，Redis TTL 自动处理会话过期")
    pass


@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库并启动后台任务"""
    # 保存主事件循环，供后台线程使用
    from app.state import set_main_event_loop
    loop = asyncio.get_running_loop()
    set_main_event_loop(loop)
    logger.info("主事件循环已保存")
    
    # 初始化 Stripe API 配置（设置超时）
    try:
        from app.stripe_config import configure_stripe
        configure_stripe()
        logger.info("Stripe API 配置已初始化（带超时设置）")
    except Exception as e:
        logger.warning(f"初始化 Stripe API 配置失败: {e}")
    
    # 初始化 Prometheus 指标
    try:
        from app.metrics import update_health_status
        update_health_status("overall", True)
        logger.info("Prometheus 指标已初始化")
    except Exception as e:
        logger.warning(f"初始化 Prometheus 指标失败: {e}")
    
    # 启动行为采集器
    try:
        from app.services.behavior_collector import BehaviorCollector
        behavior_collector = BehaviorCollector.get_instance()
        behavior_collector.start()
        logger.info("✅ BehaviorCollector 已启动")
    except Exception as e:
        logger.warning(f"⚠️  BehaviorCollector 启动失败: {e}")

    # 启动定时任务调度器 - 优先使用 Celery，备用 TaskScheduler
    import threading
    import time
    
    # 获取调度器模式（环境变量控制，避免双跑）
    SCHEDULER_MODE = os.getenv("SCHEDULER_MODE", "auto").lower()  # auto, celery, local
    
    # 检查 Celery Worker 是否可用 - 优先使用 Celery，备用 TaskScheduler
    celery_available = False
    
    if SCHEDULER_MODE == "local":
        # 强制使用 TaskScheduler，跳过 Celery 检测（节省 ~10 秒启动时间）
        logger.info("ℹ️  SCHEDULER_MODE=local，使用 TaskScheduler 执行定时任务（跳过 Celery 检测）")
    else:
        # auto 或 celery 模式：检测 Celery Worker
        try:
            from app.celery_app import celery_app, USE_REDIS
            from app.redis_cache import get_redis_client
            
            logger.info("🔍 开始检测 Celery Worker 可用性...")
            
            # 检查 Redis 连接
            if USE_REDIS:
                redis_client = get_redis_client()
                if redis_client:
                    try:
                        redis_client.ping()
                        logger.info("✅ Redis 连接成功")
                        
                        # 检查 Celery Worker 是否在线
                        logger.info("🔍 正在检测 Celery Worker...")
                        celery_inspect = celery_app.control.inspect(timeout=10.0)

                        # 方法1: 使用 ping() 检测 worker
                        ping_result = celery_inspect.ping()
                        if ping_result and isinstance(ping_result, dict) and len(ping_result) > 0:
                            worker_count = len(ping_result)
                            worker_names = list(ping_result.keys())
                            celery_available = True
                            logger.info(f"✅ Celery Worker 在线 ({worker_count} workers): {', '.join(worker_names)}")
                            logger.info("✅ 将使用 Celery 执行定时任务（Celery Beat 负责调度）")
                        else:
                            # 方法2: 尝试使用 stats() 检测
                            logger.info("⚠️  ping() 未检测到 worker，尝试使用 stats()...")
                            stats_result = celery_inspect.stats()
                            if stats_result and isinstance(stats_result, dict) and len(stats_result) > 0:
                                worker_count = len(stats_result)
                                worker_names = list(stats_result.keys())
                                celery_available = True
                                logger.info(f"✅ Celery Worker 在线 ({worker_count} workers): {', '.join(worker_names)}")
                                logger.info("✅ 将使用 Celery 执行定时任务（Celery Beat 负责调度）")
                            else:
                                logger.warning("⚠️  Celery Worker 未检测到（可能还未启动）")
                                logger.info("ℹ️  将使用 TaskScheduler 作为备用（如果 Worker 稍后启动，Celery Beat 会自动接管）")
                                
                    except Exception as e:
                        logger.warning(f"⚠️  检测 Celery Worker 状态失败: {e}")
                        logger.info("ℹ️  将使用 TaskScheduler 作为备用")
                else:
                    logger.info("ℹ️  Redis 客户端不可用，将使用 TaskScheduler 执行定时任务")
            else:
                logger.info("ℹ️  USE_REDIS=false，将使用 TaskScheduler 执行定时任务")
        except ImportError as e:
            logger.info(f"ℹ️  Celery 未安装 ({e})，将使用 TaskScheduler 执行定时任务")
        except Exception as e:
            logger.warning(f"⚠️  检查 Celery 可用性时出错: {e}，将使用 TaskScheduler 作为备用")
            import traceback
            logger.debug(f"详细错误: {traceback.format_exc()}")
        
        # celery 模式的额外检查
        if SCHEDULER_MODE == "celery":
            if celery_available:
                logger.info("✅ SCHEDULER_MODE=celery，使用 Celery 执行定时任务（Celery Beat 负责调度）")
            else:
                logger.warning("⚠️  SCHEDULER_MODE=celery，但 Celery Worker 不可用，请检查 Celery Worker 是否启动")
        else:  # auto
            if celery_available:
                logger.info("ℹ️  Celery 可用，不启动 TaskScheduler（定时任务由 Celery Beat 调度，Celery Worker 执行）")
            else:
                logger.info("ℹ️  Celery 不可用，将使用 TaskScheduler 作为备用")
    
    # 注意：TaskScheduler 将在数据库迁移完成后启动，以避免迁移前运行任务导致列不存在的错误
    logger.info("应用启动中...")
    
    # ⚠️ 环境变量验证 - 高优先级修复
    required_env_vars = ["DATABASE_URL"]
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    
    if missing_vars:
        error_msg = f"❌ 缺少必要的环境变量: {missing_vars}"
        logger.error(error_msg)
        raise RuntimeError(error_msg)
    else:
        logger.info("✅ 所有必要的环境变量已设置")
    
    # 生产环境：校验关键密钥已配置且不得为占位符（与 Config.IS_PRODUCTION 对齐）
    if Config.IS_PRODUCTION:
        _checks = [
            ("STRIPE_SECRET_KEY", os.getenv("STRIPE_SECRET_KEY"), ["placeholder", "replace_with_real", "replace_with"]),
            ("IMAGE_ACCESS_SECRET", os.getenv("IMAGE_ACCESS_SECRET"), ["your-image-secret", "change-in-production", "change_in_production"]),
            ("STRIPE_WEBHOOK_SECRET", os.getenv("STRIPE_WEBHOOK_SECRET"), ["yourkey", "...yourkey..."]),
            ("SECRET_KEY", Config.SECRET_KEY, ["change-this-secret-key-in-production", "dev-secret-key-change-in-production", "change-in-production", "linku-dev-only"]),
            ("SIGNED_URL_SECRET", Config.SIGNED_URL_SECRET, []),
        ]
        for _name, _val, _bad in _checks:
            if not _val or not _val.strip():
                raise RuntimeError(f"生产环境必须配置 {_name}")
            _v = (_val or "").lower()
            if any(_b in _v for _b in _bad):
                raise RuntimeError(f"生产环境 {_name} 不得使用占位符/示例值，请配置真实密钥")
        logger.info("✅ 生产环境密钥校验通过（STRIPE_SECRET_KEY, IMAGE_ACCESS_SECRET, STRIPE_WEBHOOK_SECRET, SECRET_KEY, SIGNED_URL_SECRET）")
    
    # 环境检测和配置信息
    environment = os.getenv("ENVIRONMENT", "development")
    debug_mode = os.getenv("DEBUG", "true").lower() == "true"
    use_redis = os.getenv("USE_REDIS", "true").lower() == "true"
    cookie_secure = os.getenv("COOKIE_SECURE", "false").lower() == "true"
    
    logger.info(f"环境: {environment}")
    logger.info(f"调试模式: {debug_mode}")
    logger.info(f"使用Redis: {use_redis}")
    logger.info(f"Cookie安全模式: {cookie_secure}")
    
    # 翻译缓存预热（后台任务，不阻塞启动）
    if use_redis and environment == "production":
        try:
            import threading
            from app.utils.translation_cache_warmup import warmup_hot_tasks
            from app.deps import get_db
            
            def warmup_cache():
                try:
                    # 等待数据库连接就绪
                    import time
                    time.sleep(5)
                    
                    db = next(get_db())
                    stats = warmup_hot_tasks(db, limit=100)
                    logger.info(f"翻译缓存预热完成: {stats}")
                except Exception as e:
                    logger.warning(f"翻译缓存预热失败: {e}")
            
            # 在后台线程中执行预热
            warmup_thread = threading.Thread(target=warmup_cache, daemon=True)
            warmup_thread.start()
            logger.info("翻译缓存预热任务已启动（后台）")
        except Exception as e:
            logger.warning(f"启动翻译缓存预热失败: {e}")
    
    # 检查翻译服务依赖
    try:
        dep_result = check_translation_dependencies()
        if not dep_result["all_installed"]:
            logger.warning("⚠️  部分翻译服务依赖缺失，某些翻译功能可能不可用")
            logger.warning("   建议运行以下命令安装缺失的依赖:")
            if "deep-translator" in dep_result["missing"]:
                logger.warning("     pip install deep-translator")
            if "google-cloud-translate" in dep_result["missing"]:
                logger.warning("     pip install google-cloud-translate")
            logger.warning("   或安装所有翻译依赖: pip install -r requirements.txt")
        else:
            logger.info(f"✅ 翻译服务依赖检查通过，可用服务: {', '.join(dep_result['available'])}")
    except Exception as e:
        logger.warning(f"检查翻译服务依赖时出错: {e}")
    
    # 启动缓存清理定时任务（定期淘汰过期缓存）
    if use_redis:
        try:
            import threading
            from app.utils.cache_eviction import evict_old_cache
            
            def cache_cleanup_task():
                """定期清理过期缓存"""
                import time
                while True:
                    try:
                        time.sleep(3600)  # 每小时执行一次
                        evict_old_cache('task_translation', max_age_seconds=7 * 24 * 60 * 60)
                        evict_old_cache('batch_query', max_age_seconds=60 * 60)
                        evict_old_cache('general_translation', max_age_seconds=7 * 24 * 60 * 60)
                    except Exception as e:
                        logger.warning(f"缓存清理任务失败: {e}")
            
            cleanup_thread = threading.Thread(target=cache_cleanup_task, daemon=True)
            cleanup_thread.start()
            logger.info("缓存清理定时任务已启动（每小时执行一次）")
        except Exception as e:
            logger.warning(f"启动缓存清理任务失败: {e}")
    
    # 初始化数据库表
    try:
        from app.database import sync_engine
        # 必须明确导入所有模型类，确保它们被注册到 Base.metadata
        # 只导入模块不够，必须导入具体的类
        from app.models import (
            Base, User, Task, Review, Message, Notification,
            University, FeaturedTaskExpert, AdminUser, CustomerService,
            TaskHistory, UserTaskInteraction, RecommendationFeedback,
            TaskDispute, RefundRequest, TaskCancelRequest, AdminRequest,
            AdminChatMessage, StaffNotification, SystemSettings,
            CustomerServiceChat, CustomerServiceMessage,
            # 更多核心表
            Activity, DeviceToken, TaskTranslation, FleaMarketItem,
            ServiceTimeSlot, PaymentHistory, PaymentTransfer, WebhookEvent,
            Banner, ForumCategory, ForumPost, ForumReply, CustomLeaderboard,
            StudentVerification, VIPSubscription, LegalDocument, FaqSection, FaqItem,
            OAuthClient, TaskExpert, TaskExpertService, Coupon, PointsAccount,
            # AI Agent
            AIConversation, AIMessage,
            # Official accounts & activities
            OfficialActivityApplication,
            # Content filtering
            SensitiveWord, HomophoneMapping, ContentReview, FilterLog,
            # Flea market rental
            FleaMarketRentalRequest, FleaMarketRental
        )

        # 🔧 自动检测并修复迁移状态（如果启用）
        try:
            from app.auto_fix_migrations import run_auto_fix_if_needed
            run_auto_fix_if_needed(sync_engine)
        except Exception as e:
            logger.warning(f"自动修复检查失败（继续启动）: {e}")

        logger.info("正在创建数据库表...")

        # 创建所有表
        try:
            Base.metadata.create_all(bind=sync_engine, checkfirst=True)
        except Exception as e:
            if "already exists" in str(e):
                # 可能有残留的孤立索引，尝试清理后重试
                logger.warning(f"表创建遇到已存在对象，尝试清理后重试: {e}")
                try:
                    raw_conn = sync_engine.raw_connection()
                    try:
                        raw_conn.autocommit = True
                        cursor = raw_conn.cursor()
                        cursor.execute("""
                            SELECT c.relname FROM pg_class c
                            JOIN pg_namespace n ON n.oid = c.relnamespace
                            WHERE c.relkind = 'i' AND n.nspname = 'public'
                            AND c.relname NOT LIKE 'pg_%%'
                        """)
                        for (idx_name,) in cursor.fetchall():
                            try:
                                cursor.execute(f'DROP INDEX IF EXISTS "{idx_name}" CASCADE')
                                logger.info(f"  ✓ 已删除孤立索引: {idx_name}")
                            except Exception:
                                pass
                        cursor.close()
                    finally:
                        raw_conn.close()
                    sync_engine.dispose()
                    Base.metadata.create_all(bind=sync_engine, checkfirst=True)
                except Exception as retry_err:
                    logger.error(f"重试创建表仍然失败: {retry_err}")
                    raise
            else:
                raise

        # 验证表是否创建成功
        inspector = inspect(sync_engine)
        created_tables = inspector.get_table_names()
        logger.info(f"✅ 数据库表创建完成！已创建 {len(created_tables)} 个表")

        if not created_tables:
            logger.error("⚠️ 警告：没有创建任何表！请检查模型导入和数据库连接")
        else:
            # 列出一些核心表以确认
            core_tables = ['users', 'tasks', 'universities', 'notifications']
            existing_core = [t for t in core_tables if t in created_tables]
            logger.info(f"核心表状态: {len(existing_core)}/{len(core_tables)} 已创建 {existing_core}")

        # 自动执行数据库迁移（如果启用）
        auto_migrate = os.getenv("AUTO_MIGRATE", "true").lower() == "true"
        if auto_migrate:
            logger.info("开始执行数据库迁移...")
            try:
                from app.db_migrations import run_migrations
                run_migrations(sync_engine, force=False)
                logger.info("数据库迁移执行完成！")
            except Exception as e:
                logger.error(f"数据库迁移执行失败: {e}")
                import traceback
                traceback.print_exc()
                # 迁移失败不阻止应用启动，只记录错误
        else:
            logger.info("自动迁移已禁用（AUTO_MIGRATE=false）")

        # Migrate user preferences into user_profile_preferences (safe to run multiple times)
        try:
            from app.migrations.merge_preferences import migrate_user_preferences
            from app.database import SessionLocal as MigrationSessionLocal
            migration_db = MigrationSessionLocal()
            try:
                migrate_user_preferences(migration_db, sync_engine)
            finally:
                migration_db.close()
        except Exception as e:
            logger.warning(f"User preferences migration skipped: {e}")

        # 在迁移完成后启动 TaskScheduler，确保所有列已存在
        if celery_available:
            pass  # Celery 可用，不启动 TaskScheduler
        else:
            logger.info("📋 启动 TaskScheduler 作为备用调度器...")
            try:
                from app.task_scheduler import init_scheduler
                scheduler = init_scheduler()
                scheduler.start()
                logger.info("✅ 细粒度定时任务调度器（TaskScheduler）已启动（备用方案）")
            except Exception as e:
                logger.error(f"❌ 启动任务调度器失败，回退到旧方案: {e}", exc_info=True)
                from app.scheduled_tasks import run_scheduled_tasks

                def run_tasks_periodically():
                    """每5分钟执行一次定时任务（回退方案）"""
                    global _shutdown_flag
                    from app.state import is_app_shutting_down

                    while not _shutdown_flag and not is_app_shutting_down():
                        try:
                            run_scheduled_tasks()
                        except Exception as e:
                            error_str = str(e)
                            if is_app_shutting_down() and (
                                "Event loop is closed" in error_str
                                or "loop is closed" in error_str
                                or "attached to a different loop" in error_str
                            ):
                                logger.debug(f"定时任务在关闭时跳过: {e}")
                                break
                            logger.error(f"定时任务执行失败: {e}", exc_info=True)

                        for _ in range(300):  # 5分钟 = 300秒
                            if _shutdown_flag or is_app_shutting_down():
                                break
                            time.sleep(1)

                scheduler_thread = threading.Thread(target=run_tasks_periodically, daemon=True)
                scheduler_thread.start()
                logger.info("✅ 定时任务已启动（回退方案，每5分钟执行一次）")

        # 自动初始化大学数据（如果表为空）
        try:
            from app.database import SessionLocal
            from app import models
            db = SessionLocal()
            try:
                university_count = db.query(models.University).count()
                if university_count == 0:
                    logger.info("检测到大学表为空，开始自动初始化大学数据...")
                    # 直接读取JSON文件并初始化
                    import json
                    from pathlib import Path
                    # 尝试多个可能的路径（支持不同的部署环境）
                    # 注意：在Docker中，backend/目录被复制到/app/，所以scripts/应该在/app/scripts/
                    possible_paths = [
                        Path(__file__).parent.parent / "scripts" / "university_email_domains.json",  # 开发环境：backend/scripts/
                        Path(__file__).parent.parent.parent / "scripts" / "university_email_domains.json",  # 项目根目录：scripts/
                        Path("/app/scripts/university_email_domains.json"),  # Docker部署：如果复制了scripts目录
                        Path("/app/app/scripts/university_email_domains.json"),  # Docker部署：backend/scripts/ -> /app/app/scripts/
                        Path("scripts/university_email_domains.json"),  # 相对路径
                    ]
                    json_path = None
                    for path in possible_paths:
                        if path.exists():
                            json_path = path
                            logger.info(f"找到大学数据文件: {json_path}")
                            break
                    
                    if json_path and json_path.exists():
                        with open(json_path, 'r', encoding='utf-8') as f:
                            universities_data = json.load(f)
                        success_count = 0
                        skip_count = 0
                        for uni_data in universities_data:
                            existing = db.query(models.University).filter(
                                models.University.email_domain == uni_data['email_domain']
                            ).first()
                            if existing:
                                skip_count += 1
                                continue
                            university = models.University(
                                name=uni_data['name'],
                                name_cn=uni_data.get('name_cn'),
                                email_domain=uni_data['email_domain'],
                                domain_pattern=uni_data.get('domain_pattern', f"@{uni_data['email_domain']}"),
                                is_active=True
                            )
                            db.add(university)
                            db.commit()
                            success_count += 1
                        logger.info(f"大学数据自动初始化完成！成功：{success_count}，跳过：{skip_count}")
                    else:
                        logger.warning(f"找不到大学数据文件，已尝试以下路径：")
                        for path in possible_paths:
                            logger.warning(f"  - {path} (存在: {path.exists()})")
                        logger.info("请手动运行: python backend/scripts/init_universities.py")
                        logger.info("或者确保 university_email_domains.json 文件在正确的位置")
                else:
                    logger.info(f"大学数据已存在（{university_count} 条记录），跳过初始化")
                
                # 初始化大学匹配器（加载到内存）
                try:
                    from app.university_matcher import _university_matcher
                    _university_matcher.initialize(db)
                    logger.info("大学匹配器初始化完成")
                except Exception as e:
                    logger.warning(f"初始化大学匹配器失败: {e}")
                
                # 自动初始化论坛学校板块（如果还没有初始化）
                try:
                    # 检查是否已经有大学板块
                    university_category_count = db.query(models.ForumCategory).filter(
                        models.ForumCategory.type == 'university'
                    ).count()
                    
                    # 检查是否已经有英国大学编码
                    uk_university_with_code_count = db.query(models.University).filter(
                        models.University.country == 'UK',
                        models.University.code.isnot(None)
                    ).count()
                    
                    if university_category_count == 0:
                        logger.info("检测到需要初始化论坛学校板块，开始自动初始化...")
                        # 导入初始化函数（使用相对导入或直接调用脚本函数）
                        try:
                            import sys
                            from pathlib import Path
                            
                            # 添加项目根目录到路径（脚本需要从项目根目录导入 app）
                            project_root = Path(__file__).parent.parent.parent
                            if str(project_root) not in sys.path:
                                sys.path.insert(0, str(project_root))
                            
                            # 添加 scripts 目录到路径
                            scripts_path = Path(__file__).parent.parent / "scripts"
                            if scripts_path.exists() and str(scripts_path) not in sys.path:
                                sys.path.insert(0, str(scripts_path))
                            
                            # 尝试导入初始化函数
                            from init_forum_school_categories import (
                                init_university_codes,
                                init_forum_categories,
                                verify_consistency
                            )
                            
                            # 1. 初始化大学编码（如果还没有）
                            if uk_university_with_code_count == 0:
                                logger.info("开始初始化大学编码...")
                                init_university_codes(db)
                            
                            # 2. 初始化论坛板块
                            logger.info("开始初始化论坛板块...")
                            init_forum_categories(db)
                            
                            # 3. 验证一致性（不阻止启动，只记录警告）
                            try:
                                is_consistent = verify_consistency(db)
                                if is_consistent:
                                    logger.info("✅ 论坛学校板块自动初始化完成！")
                                else:
                                    logger.warning("⚠️  论坛学校板块初始化完成，但发现数据不一致问题，请检查日志")
                            except Exception as e:
                                logger.warning(f"验证数据一致性时出错: {e}")
                        except ImportError as import_err:
                            logger.warning(f"无法导入论坛学校板块初始化函数: {import_err}")
                            logger.info("将尝试直接运行脚本...")
                            # 备用方案：直接运行脚本
                            import subprocess
                            try:
                                # 确保 project_root 已定义
                                if 'project_root' not in locals():
                                    project_root = Path(__file__).parent.parent.parent
                                
                                script_path = Path(__file__).parent.parent / "scripts" / "init_forum_school_categories.py"
                                if script_path.exists():
                                    logger.info(f"运行初始化脚本: {script_path}")
                                    result = subprocess.run(
                                        [sys.executable, str(script_path)],
                                        capture_output=True,
                                        text=True,
                                        timeout=60,
                                        cwd=str(project_root)
                                    )
                                    if result.returncode == 0:
                                        logger.info("✅ 论坛学校板块自动初始化完成（通过脚本）！")
                                        if result.stdout:
                                            logger.debug(f"脚本输出: {result.stdout}")
                                    else:
                                        logger.warning(f"脚本执行失败 (返回码: {result.returncode})")
                                        if result.stderr:
                                            logger.warning(f"错误输出: {result.stderr}")
                                        if result.stdout:
                                            logger.debug(f"标准输出: {result.stdout}")
                                else:
                                    logger.warning(f"找不到脚本文件: {script_path}")
                            except subprocess.TimeoutExpired:
                                logger.warning("脚本执行超时（60秒）")
                            except Exception as script_err:
                                logger.warning(f"运行初始化脚本失败: {script_err}")
                                import traceback
                                logger.debug(f"详细错误: {traceback.format_exc()}")
                                logger.info("请手动运行: python backend/scripts/init_forum_school_categories.py")
                    elif university_category_count > 0:
                        logger.info(f"论坛学校板块已存在（{university_category_count} 个大学板块），跳过初始化")
                except Exception as e:
                    logger.warning(f"自动初始化论坛学校板块时出错: {e}")
                    import traceback
                    logger.debug(f"详细错误: {traceback.format_exc()}")
                    logger.info("请手动运行: python backend/scripts/init_forum_school_categories.py")

                # 自动初始化敏感词数据（如果表为空）
                try:
                    sensitive_word_count = db.query(models.SensitiveWord).count()
                    if sensitive_word_count == 0:
                        logger.info("检测到敏感词表为空，开始自动初始化...")
                        from app.content_filter.seed_data import INITIAL_WORDS, INITIAL_HOMOPHONES
                        for entry in INITIAL_WORDS:
                            db.add(models.SensitiveWord(
                                word=entry["word"],
                                category=entry["category"],
                                level=entry["level"],
                                is_active=True,
                            ))
                        for entry in INITIAL_HOMOPHONES:
                            db.add(models.HomophoneMapping(
                                variant=entry["variant"],
                                standard=entry["standard"],
                                is_active=True,
                            ))
                        db.commit()
                        logger.info(f"✅ 敏感词数据初始化完成！{len(INITIAL_WORDS)} 个敏感词，{len(INITIAL_HOMOPHONES)} 个谐音映射")
                    else:
                        logger.info(f"敏感词数据已存在（{sensitive_word_count} 条记录），跳过初始化")
                except Exception as e:
                    logger.warning(f"自动初始化敏感词数据时出错: {e}")
            finally:
                db.close()
        except Exception as e:
            logger.warning(f"自动初始化大学数据时出错: {e}")
            logger.info("请手动运行: python backend/scripts/init_universities.py")
        
    except Exception as e:
        logger.error(f"数据库初始化失败: {e}")
        import traceback
        traceback.print_exc()
    
    logger.info("启动后台任务：自动取消过期任务")
    background_thread = threading.Thread(target=run_background_task, daemon=True)
    background_thread.start()
    
    # 会话清理已废弃（Redis TTL 自动处理过期）
    logger.debug("会话清理已废弃，Redis TTL 自动处理")
    
    # 启动定期清理任务
    logger.info("启动定期清理任务")
    try:
        from app.cleanup_tasks import start_background_cleanup
        global _background_cleanup_task
        _background_cleanup_task = asyncio.create_task(start_background_cleanup())
        logger.info("定期清理任务已启动")
    except Exception as e:
        logger.error(f"启动定期清理任务失败: {e}")
    
    # 启动连接池监控任务
    logger.info("启动数据库连接池监控任务")
    try:
        from app.database import start_pool_monitor
        start_pool_monitor()
        logger.info("数据库连接池监控任务已启动")
    except Exception as e:
        logger.error(f"启动连接池监控任务失败: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时清理资源"""
    global _shutdown_flag, _background_cleanup_task
    
    logger.info("应用正在关闭，开始清理资源...")
    
    # 设置关停标志（必须在最开始就设置，这样后台线程看到就会自动"早退"）
    from app.state import set_app_shutting_down
    set_app_shutting_down(True)
    _shutdown_flag = True
    
    # 给正在处理的请求一点时间
    await asyncio.sleep(0.3)

    # 0. 停止行为采集器（先于DB清理，确保最终flush完成）
    try:
        from app.services.behavior_collector import BehaviorCollector
        BehaviorCollector.get_instance().stop()
        logger.info("已停止 BehaviorCollector")
    except Exception as e:
        logger.warning(f"停止 BehaviorCollector 时出错: {e}")

    # 1. 停止连接池监控任务
    try:
        from app.database import stop_pool_monitor
        stop_pool_monitor()
        logger.info("已停止连接池监控任务")
    except Exception as e:
        logger.warning(f"停止连接池监控任务时出错: {e}")
    
    # 2. 停止异步清理任务
    try:
        from app.cleanup_tasks import stop_background_cleanup
        stop_background_cleanup()
        logger.info("已停止异步清理任务")
        
        # 取消异步任务（如果还在运行）
        if _background_cleanup_task and not _background_cleanup_task.done():
            _background_cleanup_task.cancel()
            try:
                await _background_cleanup_task
            except asyncio.CancelledError:
                logger.debug("异步清理任务已取消")
            except Exception as e:
                logger.warning(f"取消异步清理任务时出错: {e}")
    except Exception as e:
        logger.warning(f"停止清理任务时出错: {e}")
    
    # 3. 关闭所有活跃的 WebSocket 连接（使用 WebSocketManager）
    try:
        from app.websocket_manager import get_ws_manager
        ws_manager = get_ws_manager()
        await ws_manager.close_all()
        logger.info("WebSocket 连接已关闭")
    except Exception as e:
        logger.warning(f"关闭 WebSocket 连接时出错: {e}")
    
    # 4. 停止 Celery Worker（如果使用 Celery）
    try:
        from app.celery_app import celery_app, USE_REDIS
        if USE_REDIS:
            # 发送关闭信号给所有 Celery Worker
            try:
                celery_app.control.shutdown()
                logger.info("已发送关闭信号给 Celery Worker")
            except Exception as e:
                logger.debug(f"发送 Celery Worker 关闭信号失败（可能 Worker 未运行）: {e}")
    except Exception as e:
        logger.debug(f"Celery Worker 清理失败: {e}")
    
    # 5. 关闭 APNs HTTP/2 长连接
    try:
        from app.push_notification_service import close_apns_client
        close_apns_client()
    except Exception as e:
        logger.warning(f"关闭 APNs 连接时出错: {e}")

    # 6. 关闭数据库连接池（必须在事件循环还活着的时候做）
    try:
        from app.database import close_database_pools
        await close_database_pools()
    except Exception as e:
        logger.warning(f"关闭数据库连接池时出错: {e}")

    logger.info("资源清理完成")


@app.websocket("/ws/chat/{user_id}")
async def websocket_chat(
    websocket: WebSocket, user_id: str, db: Session = Depends(get_db)
):
    # 支持多种认证方式：用户认证和客服认证
    session_id = None
    cookies = websocket.cookies
    is_service_auth = False

    # 检查用户session_id cookie
    if "session_id" in cookies:
        session_id = cookies["session_id"]
        logger.debug(f"Found user session_id in cookies for user {user_id}")
    
    # 检查客服service_session_id cookie
    elif "service_session_id" in cookies:
        session_id = cookies["service_session_id"]
        is_service_auth = True
        logger.debug(f"Found service_session_id in cookies for user {user_id}")
    
    # 如果Cookie中没有session_id，尝试从查询参数获取（向后兼容）
    if not session_id:
        # 支持 session_id 和 token 两种参数名（iOS使用token）
        session_id = websocket.query_params.get("session_id") or websocket.query_params.get("token")
        if session_id:
            logger.debug(f"Found session_id/token in query params for user {user_id}")
    
    if not session_id:
        has_cookies = bool(cookies)
        cookie_keys = list(cookies.keys()) if cookies else []
        query_params = dict(websocket.query_params)
        origin = websocket.headers.get("origin", "unknown")
        user_agent = websocket.headers.get("user-agent", "unknown")
        logger.warning(
            f"WebSocket connection rejected: Missing session_id/token for user {user_id} | "
            f"origin={origin}, has_cookies={has_cookies}, cookie_keys={cookie_keys}, "
            f"query_params_keys={list(query_params.keys())}, ua={user_agent[:80]}"
        )
        await websocket.close(code=1008, reason="Missing session_id")
        return

    # 验证会话
    try:
        if is_service_auth:
            # 客服认证
            from app.service_auth import ServiceAuthManager
            session = ServiceAuthManager.get_session(session_id)
            if not session:
                logger.error(f"Invalid service session for user {user_id}")
                await websocket.close(code=1008, reason="Invalid service session")
                return
            
            # 验证客服ID与WebSocket路径中的user_id是否匹配
            if session.service_id != user_id:
                logger.error(f"Service ID mismatch: session={session.service_id}, path={user_id}")
                await websocket.close(code=1008, reason="Service ID mismatch")
                return
            
            logger.debug(f"WebSocket service authentication successful for user {user_id}")
        else:
            # 用户认证
            from app.secure_auth import SecureAuthManager
            
            session = SecureAuthManager.get_session(session_id, update_activity=False)
            if not session:
                logger.error(f"Invalid session for user {user_id}")
                await websocket.close(code=1008, reason="Invalid session")
                return

            # 验证会话中的用户ID与WebSocket路径中的user_id是否匹配
            if session.user_id != user_id:
                logger.error(f"User ID mismatch: session={session.user_id}, path={user_id}")
                await websocket.close(code=1008, reason="User ID mismatch")
                return

            logger.debug(f"WebSocket user authentication successful for user {user_id}")
    except Exception as e:
        logger.error(f"WebSocket authentication failed for user {user_id}: {e}")
        await websocket.close(code=1008, reason="Invalid session")
        return

    # ⚠️ 原子替换：使用用户级锁确保原子操作
    connection_established = False
    ws_manager = get_ws_manager()
    
    try:
        connection_lock = ws_manager.get_lock(user_id)
        
        async with connection_lock:
            # 先获取旧连接（原子操作）
            old_connection = ws_manager.connections.get(user_id)
            old_websocket = old_connection.websocket if old_connection else None
            
            # 创建并登记新连接为当前连接（原子操作）
            from app.websocket_manager import WebSocketConnection
            new_connection = WebSocketConnection(websocket, user_id)
            ws_manager.connections[user_id] = new_connection
            
            # 接受新连接（如果失败，需要回滚连接注册）
            try:
                await websocket.accept()
                connection_established = True
                new_connection.is_accepted = True  # 标记为已接受，允许心跳循环发送 ping
                logger.debug(f"WebSocket connection established for user {user_id} (total: {len(ws_manager.connections)})")
            except Exception as accept_error:
                # accept 失败，回滚连接注册
                if ws_manager.connections.get(user_id) == new_connection:
                    del ws_manager.connections[user_id]
                raise accept_error
            
            # 异步关闭旧连接（不影响新连接）
            if old_websocket:
                logger.info(
                    f"Closing previous WebSocket for user {user_id} (replaced by new connection); "
                    "frequent repeats may indicate client reconnecting or multi-instance without sticky session."
                )
                asyncio.create_task(close_old_connection(old_websocket, user_id))
        
        # 在锁外启动清理和心跳任务（避免阻塞）
        if ws_manager._cleanup_task is None or ws_manager._cleanup_task.done():
            ws_manager._cleanup_task = asyncio.create_task(ws_manager._cleanup_loop())
        if ws_manager._heartbeat_task is None or ws_manager._heartbeat_task.done():
            ws_manager._heartbeat_task = asyncio.create_task(ws_manager._heartbeat_loop())
        
        # 更新 Prometheus 指标
        try:
            from app.metrics import (
                record_websocket_connection,
                update_websocket_connections_active
            )
            record_websocket_connection("established")
            update_websocket_connections_active(len(ws_manager.connections))
        except Exception as e:
            logger.debug(f"更新WebSocket Prometheus指标失败: {e}")
    except Exception as e:
        logger.error(f"Error during WebSocket connection setup for user {user_id}: {e}", exc_info=True)
        # 只有在连接已建立但后续出错时才需要清理
        if connection_established:
            ws_manager.remove_connection(user_id)
        elif user_id in ws_manager.connections:
            # 如果连接已注册但 accept 失败，清理注册
            del ws_manager.connections[user_id]
        try:
            await websocket.close(code=1011, reason="Connection setup failed")
        except Exception as e:
            logger.debug(f"关闭失败的WebSocket连接时出错 (user_id={user_id}): {e}")
        return
    
    # ⚠️ 注意：心跳已在业务循环中统一处理（方案B），不再单独启动心跳任务
    # 心跳逻辑已整合到主消息循环中，避免与业务receive竞争
    
    # 心跳相关变量
    last_ping_time = get_utc_time()  # 统一使用UTC时间
    ping_interval = 20  # 20秒发送一次ping
    missing_pongs = 0
    max_missing_pongs = 6  # 6 * 10s = 60s 无响应才断开，适应移动网络

    try:
        # 主消息循环（统一处理心跳和业务消息）
        while True:
            # ⚠️ 检查是否需要发送ping（心跳与业务消息统一处理）
            current_time = get_utc_time()  # 统一使用UTC时间
            if (current_time - last_ping_time).total_seconds() >= ping_interval:
                try:
                    await websocket.send_json({"type": "ping"})
                    last_ping_time = current_time
                except Exception as e:
                    logger.warning(f"Failed to send ping to user {user_id}: {e}")
                    break  # 连接已断开，退出循环交由外层 except 清理

            # 统一接收消息（心跳和业务消息都在这里处理，避免竞争）
            try:
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=10.0
                )
            except asyncio.TimeoutError:
                # 超时检查pong
                missing_pongs += 1
                if missing_pongs >= max_missing_pongs:
                    # ⚠️ 使用非1000的关闭码（4001），前端需要重连
                    from app.constants import WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    await websocket.close(
                        code=WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
                        reason=WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    )
                    break
                continue
            
            logger.debug(f"Received message from user {user_id}: {data[:100]}...")  # 只记录前100字符

            try:
                # 检查数据是否为有效的JSON
                if not data.strip():
                    await websocket.send_text(
                        json.dumps({"error": "Empty message received"})
                    )
                    continue

                msg = json.loads(data)
                logger.debug(f"Parsed message type: {msg.get('type', 'unknown')} from user {user_id}")
                
                # ⚠️ 处理pong响应（心跳）
                if msg.get("type") == "pong":
                    missing_pongs = 0  # 重置缺失pong计数
                    ws_manager = get_ws_manager()
                    ws_manager.record_pong(user_id)
                    logger.debug(f"Received pong from user {user_id}")
                    continue

                # ⚠️ 处理 typing 状态转发（不存库，直接转发给接收方）
                if msg.get("type") == "typing":
                    typing_receiver = msg.get("receiver_id")
                    if typing_receiver and isinstance(typing_receiver, str):
                        ws_manager = get_ws_manager()
                        await ws_manager.send_to_user(
                            typing_receiver,
                            {
                                "type": "typing",
                                "sender_id": user_id,
                                "task_id": msg.get("task_id"),
                            },
                        )
                    continue

                # 验证消息格式
                if not isinstance(msg, dict):
                    await websocket.send_text(
                        json.dumps({"error": "Message must be a JSON object"})
                    )
                    continue

                if "receiver_id" not in msg or "content" not in msg:
                    await websocket.send_text(
                        json.dumps(
                            {
                                "error": "Invalid message format. Expected receiver_id and content."
                            }
                        )
                    )
                    continue

                # 获取chat_id（可选，用于客服对话）
                chat_id = msg.get("chat_id")

                # 验证chat_id格式
                if chat_id is not None and not isinstance(chat_id, str):
                    await websocket.send_text(
                        json.dumps(
                            {"error": "Invalid chat_id type. Must be string or null."}
                        )
                    )
                    continue

                # 验证数据类型和内容
                if not isinstance(msg["content"], str):
                    await websocket.send_text(
                        json.dumps(
                            {"error": "Invalid data types. content must be string."}
                        )
                    )
                    continue

                # 验证消息内容不为空
                if not msg["content"].strip():
                    await websocket.send_text(
                        json.dumps({"error": "Message content cannot be empty."})
                    )
                    continue

                # 检查用户是否为客服账号
                from app.security import decode_access_token
                from app.id_generator import (
                    is_admin_id,
                    is_customer_service_id,
                    is_user_id,
                )
                from app.models import CustomerService

                # 从WebSocket连接中获取用户类型信息
                # 由于user_id可能是数字格式，我们需要从JWT token中获取用户类型
                is_customer_service = False
                is_admin = False
                is_user = True  # 默认为普通用户

                # 检查是否为客服ID
                if is_customer_service_id(user_id):
                    # 直接通过ID格式判断为客服
                    is_customer_service = True
                    is_user = False
                    logger.info(f"识别为客服: {user_id}")
                elif is_admin_id(user_id):
                    # 识别为管理员
                    is_admin = True
                    is_user = False
                    logger.info(f"识别为管理员: {user_id}")
                else:
                    # 默认为普通用户
                    is_user = True
                    logger.info(f"识别为普通用户: {user_id}")

                # 处理客服对话消息
                if chat_id:
                    logger.info(
                        f"Processing customer service message with chat_id: {chat_id}"
                    )
                    # 验证chat_id是否有效
                    chat = crud.get_customer_service_chat(db, chat_id)
                    if not chat:
                        logger.error(f"Invalid chat_id: {chat_id}")
                        await websocket.send_text(
                            json.dumps({"error": "Invalid chat_id"})
                        )
                        continue
                    logger.info(
                        f"Chat found: user_id={chat['user_id']}, service_id={chat['service_id']}"
                    )

                    # 验证用户是否有权限在此对话中发送消息
                    if chat["user_id"] != user_id and chat["service_id"] != user_id:
                        await websocket.send_text(
                            json.dumps(
                                {"error": "Not authorized to send message in this chat"}
                            )
                        )
                        continue

                    # 检查对话是否已结束
                    if chat["is_ended"] == 1:
                        await websocket.send_text(
                            json.dumps({"error": "Chat has ended"})
                        )
                        continue

                    # 确定发送者类型
                    sender_type = "customer_service" if is_customer_service else "user"

                    # 处理图片消息
                    image_id = None
                    if msg["content"].startswith('[图片] '):
                        # 提取图片ID
                        image_id = msg["content"].replace('[图片] ', '')
                        logger.debug("客服消息检测到图片，image_id: %s", image_id)
                    
                    # 保存客服对话消息
                    message = crud.save_customer_service_message(
                        db, chat_id, user_id, sender_type, msg["content"], image_id=image_id
                    )

                    # 立即广播客服对话消息给接收者
                    # 确定接收者ID
                    receiver_id = (
                        chat["user_id"] if is_customer_service else chat["service_id"]
                    )
                    logger.info(
                        f"Determined receiver_id: {receiver_id} (is_customer_service: {is_customer_service})"
                    )

                    # 构建消息响应（含 id 便于前端去重，避免轮询时同一条消息显示两次）
                    message_response = {
                        "id": message["id"],
                        "from": user_id,
                        "receiver_id": receiver_id,
                        "content": msg["content"],
                        "created_at": str(message["created_at"]),
                        "sender_type": sender_type,
                        "original_sender_id": user_id,
                        "chat_id": chat_id,
                    }
                    logger.info(f"Message response: {message_response}")

                    # 推送给接收方（使用 WebSocketManager）
                    ws_manager = get_ws_manager()
                    success = await ws_manager.send_to_user(receiver_id, message_response)
                    logger.debug(
                        f"Message send to {receiver_id}: {'success' if success else 'failed (no active connection)'}"
                    )

                    if not success:
                        logger.debug(
                            f"No active WebSocket connection found for receiver {receiver_id}"
                        )

                    # 向发送者发送确认响应
                    try:
                        confirmation_response = {
                            "type": "message_sent",
                            "message_id": message["id"],
                            "chat_id": chat_id,
                            "sender_type": sender_type,
                        }
                        await websocket.send_text(json.dumps(confirmation_response))
                        logger.info(f"Confirmation sent to sender {user_id}")
                    except Exception as e:
                        logger.error(
                            f"Failed to send confirmation to sender {user_id}: {e}"
                        )

                    continue  # 跳过普通消息处理逻辑

                else:
                    # ⚠️ 普通消息（联系人聊天）已废弃，不再处理
                    # 所有消息必须通过任务聊天或客服会话发送
                    await websocket.send_text(
                        json.dumps({
                            "error": "普通消息功能已废弃。请使用任务聊天接口或客服会话发送消息。",
                            "type": "error"
                        })
                    )
                    logger.warning(f"用户 {user_id} 尝试发送普通消息（已废弃功能）")
                    continue

                # 创建通知给接收者
                try:
                    # 检查是否已经存在相同的通知
                    from app.models import Notification

                    existing_notification = (
                        db.query(Notification)
                        .filter(
                            Notification.user_id == msg["receiver_id"],
                            Notification.type == "message",
                            Notification.related_id == user_id,
                        )
                        .first()
                    )

                    if not existing_notification:
                        # 检查发送者是否为客服账号
                        from app.models import CustomerService

                        is_customer_service = (
                            db.query(CustomerService)
                            .filter(CustomerService.id == user_id)
                            .first()
                            is not None
                        )

                        if is_customer_service:
                            # 从客服数据库获取客服名字
                            service = (
                                db.query(CustomerService)
                                .filter(CustomerService.id == user_id)
                                .first()
                            )
                            sender_name = service.name if service else f"客服{user_id}"
                            notification_content = (
                                f"客服 {sender_name} 给您发送了一条消息"
                            )
                        else:
                            # 从用户数据库获取普通用户名字
                            sender = crud.get_user_by_id(db, user_id)
                            sender_name = sender.name if sender else f"用户{user_id}"
                            notification_content = (
                                f"用户 {sender_name} 给您发送了一条消息"
                            )

                        # 创建通知
                        crud.create_notification(
                            db,
                            msg["receiver_id"],
                            "message",
                            "新消息",
                            notification_content,
                            user_id,
                        )
                        logger.info(
                            f"Notification created for user {msg['receiver_id']}"
                        )
                        
                        # 发送推送通知
                        try:
                            from app.push_notification_service import send_push_notification
                            send_push_notification(
                                db=db,
                                user_id=msg["receiver_id"],
                                title=None,  # 从模板生成
                                body=None,  # 从模板生成
                                notification_type="message",
                                data={"sender_id": user_id},
                                template_vars={"message": notification_content}
                            )
                        except Exception as e:
                            logger.warning(f"发送私信推送通知失败: {e}")
                            # 推送通知失败不影响主流程
                    else:
                        logger.info(
                            f"Notification already exists for user {msg['receiver_id']}"
                        )
                except Exception as e:
                    logger.error(f"Failed to create notification: {e}")
                    # 回滚事务以继续处理消息
                    db.rollback()

                # 构建消息响应
                # 确定发送者类型
                if is_customer_service:
                    sender_type = "customer_service"
                elif is_admin:
                    sender_type = "admin"
                else:
                    sender_type = "user"

                message_response = {
                    "type": "chat_message",
                    "from": user_id,  # 数据库已经存储格式化ID
                    "receiver_id": msg["receiver_id"],
                    "content": msg["content"],
                    "created_at": str(message.created_at),
                    "sender_type": sender_type,
                    "original_sender_id": user_id,
                }

                # 推送给接收方（使用 WebSocketManager）
                ws_manager = get_ws_manager()
                success = await ws_manager.send_to_user(msg["receiver_id"], message_response)
                if not success:
                    logger.debug(f"Message not sent to receiver {msg['receiver_id']} (no active connection)")

                # 向发送者发送确认响应
                try:
                    confirmation_response = {
                        "type": "message_sent",
                        "message_id": message.id,
                        "receiver_id": msg["receiver_id"],
                        "content": msg["content"],
                        "created_at": str(message.created_at),
                        "status": "success",
                    }
                    await websocket.send_text(json.dumps(confirmation_response))
                    logger.debug(f"Confirmation sent to sender {user_id}")
                except Exception as e:
                    logger.error(
                        f"Failed to send confirmation to sender {user_id}: {e}"
                    )

                logger.debug(f"Message processed for sender {user_id}")

            except json.JSONDecodeError as e:
                logger.error(f"JSON decode error: {e}, data: {data}")
                await websocket.send_text(
                    json.dumps({"error": f"Invalid JSON format: {str(e)}"})
                )
            except Exception as e:
                logger.error(f"Error processing message: {e}, data: {data}")
                await websocket.send_text(
                    json.dumps({"error": f"Internal server error: {str(e)}"})
                )

    except WebSocketDisconnect:
        logger.debug(f"WebSocket disconnected for user {user_id}")
        # 连接正常断开，清理连接
        ws_manager.remove_connection(user_id)
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}", exc_info=True)
        # 连接异常，清理连接
        ws_manager.remove_connection(user_id)
        try:
            await websocket.close()
        except Exception as e:
            logger.debug(f"关闭异常WebSocket连接时出错 (user_id={user_id}): {e}")
    finally:
        # 确保连接被清理（防止异常情况下连接泄漏）
        # remove_connection 内部有检查，重复调用是安全的
        if user_id in ws_manager.connections:
            ws_manager.remove_connection(user_id)


@app.get("/")
def read_root():
    """根路径 - 不依赖数据库，用于基本健康检查"""
    return {"status": "ok", "message": "Welcome to Link²Ur!"}


@app.get("/live")
def liveness_check():
    """轻量级存活探测 — 不依赖 DB/Redis，仅证明进程在运行。
    
    用于负载均衡 / Railway 的 Liveness 探测，避免 DB 短暂不可用时
    平台误判实例不健康并频繁重启。
    """
    return {"status": "alive"}


@app.get("/health")
async def health_check():
    """完整的健康检查 - 使用增强的健康检查模块"""
    from app.health_check import health_checker
    
    health_status = await health_checker.comprehensive_health_check()
    
    # 更新 Prometheus 指标
    try:
        from app.metrics import update_health_status, record_http_request
        update_health_status("database", health_status["checks"].get("database_sync", {}).get("status") == "healthy")
        update_health_status("redis", health_status["checks"].get("redis", {}).get("status") == "healthy")
        update_health_status("overall", health_status["status"] == "healthy")
        
        # 记录 HTTP 请求指标
        response_time = health_status["summary"].get("response_time_ms", 0) / 1000
        status_code = 200 if health_status["status"] == "healthy" else 503
        record_http_request("GET", "/health", status_code, response_time)
    except Exception as e:
        logger.debug(f"更新健康检查Prometheus指标失败: {e}")
    
    # 根据检查结果决定最终状态
    if health_status["status"] == "healthy":
        return health_status
    else:
        # 如果关键服务不可用，返回503状态码
        status_code = 503 if health_status["status"] == "unhealthy" else 200
        return JSONResponse(
            status_code=status_code,
            content=health_status
        )

@app.get("/ping")
def ping():
    """简单的ping端点 - 用于健康检查"""
    return "pong"


# ==================== 只读模式管理端点 ====================
@app.get("/admin/read-only")
def get_read_only_status(request: Request):
    """查询当前只读模式状态（需管理员密钥）"""
    admin_key = request.headers.get("X-Admin-Key", "")
    expected_key = os.getenv("ADMIN_TOGGLE_KEY", "")
    if not expected_key or admin_key != expected_key:
        raise HTTPException(status_code=403, detail="Forbidden")
    return {"read_only": Config.READ_ONLY_MODE}


@app.post("/admin/read-only")
def toggle_read_only_mode(request: Request, enable: bool = True):
    """动态切换只读模式（需管理员权限）
    
    用法：POST /admin/read-only?enable=true  开启只读
         POST /admin/read-only?enable=false 关闭只读
    """
    # 简单的管理员密钥验证（避免依赖 DB）
    admin_key = request.headers.get("X-Admin-Key", "")
    expected_key = os.getenv("ADMIN_TOGGLE_KEY", "")
    if not expected_key or admin_key != expected_key:
        raise HTTPException(status_code=403, detail="Forbidden")
    
    Config.READ_ONLY_MODE = enable
    logger.warning(f"只读模式已{'开启' if enable else '关闭'}（操作者IP: {request.client.host if request.client else 'unknown'}）")
    return {"read_only": Config.READ_ONLY_MODE, "message": f"只读模式已{'开启' if enable else '关闭'}"}


@app.get("/metrics/performance")
async def performance_metrics():
    """获取性能监控指标"""
    try:
        from app.performance_metrics import performance_metrics
        return performance_metrics.get_comprehensive_metrics()
    except Exception as e:
        logger.error(f"获取性能指标失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取性能指标失败")


@app.get("/metrics")
def metrics():
    """Prometheus 指标端点"""
    try:
        from app.metrics import get_metrics_response
        return get_metrics_response()
    except ImportError:
        logger.warning("Prometheus client not installed, metrics endpoint unavailable")
        return JSONResponse(
            status_code=503,
            content={"error": "Metrics not available"}
        )
    except Exception as e:
        logger.error(f"Error generating metrics: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"error": "Failed to generate metrics"}
        )


if not Config.IS_PRODUCTION:
    @app.get("/test-db")
    def test_db(db: Session = Depends(get_db)):
        try:
            from app.models import User
            user_count = db.query(User).count()
            return {"message": "Database connection successful", "user_count": user_count}
        except Exception:
            raise HTTPException(status_code=500, detail="Database connection failed")

    @app.get("/test-ws")
    def test_ws():
        return {"message": "WebSocket test endpoint"}

    @app.get("/test-active-connections")
    def test_active_connections():
        """测试活跃WebSocket连接"""
        from app.websocket_manager import get_ws_manager
        ws_manager = get_ws_manager()
        stats = ws_manager.get_stats()
        return {
            "connection_count": stats['total_connections'],
            "active_count": stats['active_connections'],
        }


def _verify_admin_key(request: Request):
    """验证管理员密钥（用于不依赖DB的管理操作）"""
    admin_key = request.headers.get("X-Admin-Key", "")
    expected_key = os.getenv("ADMIN_TOGGLE_KEY", "")
    if not expected_key or admin_key != expected_key:
        raise HTTPException(status_code=403, detail="Forbidden")


@app.post("/api/admin/cancel-expired-tasks")
def manual_cancel_expired_tasks(request: Request, db: Session = Depends(get_db)):
    """手动触发过期任务取消（需管理员密钥）"""
    _verify_admin_key(request)
    try:
        cancelled_count = crud.cancel_expired_tasks(db)
        return {
            "message": f"成功取消 {cancelled_count} 个过期任务",
            "cancelled_count": cancelled_count,
        }
    except Exception as e:
        logger.error(f"手动取消过期任务时出错: {e}")
        raise HTTPException(status_code=500, detail="操作失败")


@app.post("/api/admin/update-user-statistics")
def manual_update_user_statistics(request: Request, db: Session = Depends(get_db)):
    """手动触发用户统计信息更新（需管理员密钥）"""
    _verify_admin_key(request)
    try:
        from app.models import User

        users = db.query(User).all()
        updated_count = 0

        for user in users:
            try:
                crud.update_user_statistics(db, str(user.id))
                updated_count += 1
            except Exception as e:
                logger.error(f"更新用户 {user.id} 统计信息时出错: {e}")
                continue

        return {
            "message": f"成功更新 {updated_count} 个用户的统计信息",
            "updated_count": updated_count,
            "total_users": len(users),
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"手动更新用户统计信息时出错: {e}")
        raise HTTPException(status_code=500, detail="操作失败")


# 已删除过时的客服会话清理函数

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
from fastapi.responses import JSONResponse
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
from app.routers import router as user_router, router as main_router
from app.sitemap_routes import sitemap_router
from app.security import add_security_headers
from app.security_monitoring import check_security_middleware
from app.error_handlers import (
    http_exception_handler,
    validation_exception_handler,
    security_exception_handler,
    business_exception_handler,
    general_exception_handler
)
from app.error_handlers import SecurityError, ValidationError, BusinessError

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 配置日志过滤器（401 错误降噪）
try:
    from app.logging_config import configure_logging
    configure_logging()
except Exception as e:
    logger.warning(f"配置日志过滤器时出错: {e}")

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


app = FastAPI(
    title="Link²Ur Task Platform",
    description="A simple task platform for students, freelancers, and job seekers.",
    version="0.1.0",
)

# 添加CORS中间件 - 使用安全配置
from app.config import Config

app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=Config.ALLOWED_METHODS,
    allow_headers=Config.ALLOWED_HEADERS,
)

# P2 优化：添加 GZip 响应压缩中间件
# 压缩大于 1000 字节的响应，减少带宽使用
app.add_middleware(GZipMiddleware, minimum_size=1000)

# 安全中间件 - 必须在CORS中间件之后
from app.middleware.security import security_headers_middleware
app.middleware("http")(security_headers_middleware)

# 安全监控中间件（暂时禁用以解决异步/同步混用问题）
# @app.middleware("http")
# async def security_monitoring_middleware(request: Request, call_next):
#     """安全监控中间件"""
#     return await check_security_middleware(request, call_next)

@app.middleware("http")
async def add_noindex_header(request: Request, call_next):
    """为API端点添加noindex头，防止搜索引擎索引"""
    response = await call_next(request)
    
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
    allowed_domains = [
        "https://link-u1", 
        "http://localhost", 
        "https://www.link2ur.com", 
        "https://api.link2ur.com",
        "http://localhost:3000",
        "http://localhost:8080"
    ]
    
    def is_allowed_origin(origin: str) -> bool:
        """检查origin是否在允许列表中"""
        if not origin:
            return False
        for domain in allowed_domains:
            if origin == domain or origin.startswith(domain):
                return True
        return False
    
    def set_cors_headers(response: Response):
        """设置CORS响应头"""
        if origin and is_allowed_origin(origin):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, X-CSRF-Token, X-Session-ID"
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
        # 即使出现异常，也要设置CORS头
        response = JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )
        set_cors_headers(response)
        raise
    
    # 强制设置CORS头（包括错误响应）
    set_cors_headers(response)
    add_security_headers(response)
    return response

# DEBUG 中间件已移除 - 性能优化

app.include_router(user_router, prefix="/api/users", tags=["users"])
app.include_router(main_router, prefix="/api", tags=["main"])  # 添加主路由，包含图片上传API
# auth_router 已移除，使用 secure_auth_router 替代
app.include_router(secure_auth_router, tags=["安全认证"]) # 使用新的安全认证系统
# 旧的客服认证路由已删除，使用新的独立认证系统
# 旧的管理员认证路由已删除，使用新的独立认证系统
app.include_router(separate_auth_router, prefix="/api/auth", tags=["独立认证系统"])  # 新增独立认证系统
app.include_router(cs_auth_router, tags=["客服认证"])  # 客服认证路由
app.include_router(csrf_router, tags=["CSRF保护"])
app.include_router(rate_limit_router, tags=["速率限制"])

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
app.add_exception_handler(Exception, general_exception_handler)

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

from app.admin_task_expert_routes import admin_task_expert_router
app.include_router(admin_task_expert_router)

# 跳蚤市场路由
from app.flea_market_routes import flea_market_router
app.include_router(flea_market_router)

# 多人任务路由
from app.multi_participant_routes import router as multi_participant_router
app.include_router(multi_participant_router)

# 论坛路由
from app.forum_routes import router as forum_router
app.include_router(forum_router)

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
        if file_path.startswith("flea_market/"):
            # 跳蚤市场图片
            file_full_path = Path("/data/uploads") / file_path
        else:
            # 其他公开文件
            file_full_path = Path("/data/uploads/public") / file_path
        
        # 安全检查：确保文件在允许的目录内
        try:
            if file_path.startswith("flea_market/"):
                # 跳蚤市场图片：允许访问
                file_full_path.resolve().relative_to(Path("/data/uploads").resolve())
            else:
                # 其他文件：必须在公开目录内
                file_full_path.resolve().relative_to(Path("/data/uploads/public").resolve())
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
                "Cache-Control": "public, max-age=31536000",  # 缓存1年
                "Access-Control-Allow-Origin": "*"  # 允许跨域访问
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
                "Access-Control-Allow-Origin": "*"
            }
        )

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

    db = None
    try:
        db = SessionLocal()
        cancelled_count = crud.cancel_expired_tasks(db)
        if cancelled_count > 0:
            logger.info(f"成功取消 {cancelled_count} 个过期任务")

    except Exception as e:
        logger.error(f"自动取消过期任务时出错: {e}")
    finally:
        if db:
            db.close()


def update_all_users_statistics():
    """更新所有用户的统计信息"""
    from app.database import SessionLocal
    from app.models import User

    db = None
    try:
        db = SessionLocal()
        users = db.query(User).all()
        updated_count = 0

        for user in users:
            try:
                crud.update_user_statistics(db, str(user.id))
                updated_count += 1
            except Exception as e:
                logger.error(f"更新用户 {user.id} 统计信息时出错: {e}")
                continue

        if updated_count > 0:
            logger.info(f"成功更新 {updated_count} 个用户的统计信息")

    except Exception as e:
        logger.error(f"更新用户统计信息时出错: {e}")
    finally:
        if db:
            db.close()


def run_background_task():
    """运行后台任务循环"""
    import datetime
    global _shutdown_flag
    task_counter = 0
    last_bio_update_date = None  # 记录上次更新 bio 的日期
    
    while not _shutdown_flag:
        try:
            # 取消过期任务（每分钟执行）
            cancel_expired_tasks()

            # 更新所有用户统计信息（每10分钟执行一次）
            if task_counter % 10 == 0:
                update_all_users_statistics()

            # 更新所有任务达人的 bio（每天执行一次）
            current_date = datetime.date.today()
            if last_bio_update_date != current_date:
                logger.info("开始更新所有任务达人的 bio...")
                crud.update_all_task_experts_bio()
                last_bio_update_date = current_date
                logger.info("任务达人 bio 更新完成")

            task_counter += 1
            # 每1分钟检查一次
            time.sleep(60)
        except Exception as e:
            logger.error(f"后台任务循环出错: {e}")
            time.sleep(60)  # 出错时等待1分钟后重试


def cleanup_all_sessions_unified():
    """
    统一的会话清理函数
    清理所有类型的过期会话（用户、客服、管理员）和用户Redis数据
    """
    try:
        from app.secure_auth import SecureAuthManager
        from app.service_auth import ServiceAuthManager
        from app.admin_auth import AdminAuthManager
        from app.user_redis_cleanup import user_redis_cleanup
        
        # 清理用户会话
        SecureAuthManager.cleanup_expired_sessions()
        
        # 清理客服会话
        ServiceAuthManager.cleanup_expired_sessions()
        
        # 清理管理员会话
        AdminAuthManager.cleanup_expired_sessions()
        
        # 清理用户Redis数据
        user_redis_cleanup.cleanup_all_user_data()
        
    except Exception as e:
        logger.error(f"统一会话清理失败: {e}")


def run_session_cleanup_task():
    """
    运行会话清理任务（已优化：降低频率，改为每小时执行一次）
    注意：此任务与 CleanupTasks._cleanup_expired_sessions 功能重叠，
    但保留此任务作为独立线程，频率已降低以避免重复清理
    """
    global _shutdown_flag
    while not _shutdown_flag:
        try:
            # 使用统一的清理函数
            cleanup_all_sessions_unified()
            # 改为每小时清理一次（降低频率，避免与 CleanupTasks 重复）
            time.sleep(3600)  # 1小时
        except Exception as e:
            logger.error(f"会话清理任务出错: {e}")
            time.sleep(3600)  # 出错时等待1小时后重试




@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库并启动后台任务"""
    # 保存主事件循环，供后台线程使用
    from app.state import set_main_event_loop
    loop = asyncio.get_running_loop()
    set_main_event_loop(loop)
    logger.info("主事件循环已保存")
    
    # 初始化 Prometheus 指标
    try:
        from app.metrics import update_health_status
        update_health_status("overall", True)
        logger.info("Prometheus 指标已初始化")
    except Exception as e:
        logger.warning(f"初始化 Prometheus 指标失败: {e}")
    
    # 启动定时任务调度器 - 优先使用 Celery，备用 TaskScheduler
    import threading
    import time
    
    # 获取调度器模式（环境变量控制，避免双跑）
    SCHEDULER_MODE = os.getenv("SCHEDULER_MODE", "auto").lower()  # auto, celery, local
    
    # 检查 Celery Worker 是否可用 - 优先使用 Celery，备用 TaskScheduler
    celery_available = False
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
                    # 使用 ping() 方法检测 worker，更可靠
                    logger.info("🔍 正在检测 Celery Worker...")
                    inspect = celery_app.control.inspect(timeout=10.0)
                    
                    # 方法1: 使用 ping() 检测 worker
                    ping_result = inspect.ping()
                    if ping_result and isinstance(ping_result, dict) and len(ping_result) > 0:
                        worker_count = len(ping_result)
                        worker_names = list(ping_result.keys())
                        celery_available = True
                        logger.info(f"✅ Celery Worker 在线 ({worker_count} workers): {', '.join(worker_names)}")
                        logger.info("✅ 将使用 Celery 执行定时任务（Celery Beat 负责调度）")
                    else:
                        # 方法2: 尝试使用 stats() 检测
                        logger.info("⚠️  ping() 未检测到 worker，尝试使用 stats()...")
                        stats_result = inspect.stats()
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
    
    # 根据 SCHEDULER_MODE 决定使用哪个调度器
    if SCHEDULER_MODE == "celery":
        # 强制使用 Celery，不启动 TaskScheduler
        if celery_available:
            logger.info("✅ SCHEDULER_MODE=celery，使用 Celery 执行定时任务（Celery Beat 负责调度）")
        else:
            logger.warning("⚠️  SCHEDULER_MODE=celery，但 Celery Worker 不可用，请检查 Celery Worker 是否启动")
    elif SCHEDULER_MODE == "local":
        # 强制使用 TaskScheduler，不检测 Celery
        celery_available = False
        logger.info("ℹ️  SCHEDULER_MODE=local，使用 TaskScheduler 执行定时任务（不检测 Celery）")
    else:  # auto
        # 自动检测模式（原有逻辑）
        if celery_available:
            logger.info("ℹ️  Celery 可用，不启动 TaskScheduler（定时任务由 Celery Beat 调度，Celery Worker 执行）")
        else:
            logger.info("ℹ️  Celery 不可用，将使用 TaskScheduler 作为备用")
    
    # 如果 Celery 可用，不启动 TaskScheduler（由 Celery Beat 负责调度）
    if celery_available:
        # 已在上面记录日志，这里不需要重复
        pass
    else:
        # 如果 Celery 不可用，启动 TaskScheduler 作为备用
        logger.info("📋 启动 TaskScheduler 作为备用调度器...")
        try:
            from app.task_scheduler import init_scheduler
            scheduler = init_scheduler()
            scheduler.start()
            logger.info("✅ 细粒度定时任务调度器（TaskScheduler）已启动（备用方案）")
        except Exception as e:
            logger.error(f"❌ 启动任务调度器失败，回退到旧方案: {e}", exc_info=True)
            # 回退到旧的调度方式
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
                            "Event loop is closed" in error_str or 
                            "loop is closed" in error_str or
                            "attached to a different loop" in error_str
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
    
    # 环境检测和配置信息
    environment = os.getenv("ENVIRONMENT", "development")
    debug_mode = os.getenv("DEBUG", "true").lower() == "true"
    use_redis = os.getenv("USE_REDIS", "true").lower() == "true"
    cookie_secure = os.getenv("COOKIE_SECURE", "false").lower() == "true"
    
    logger.info(f"环境: {environment}")
    logger.info(f"调试模式: {debug_mode}")
    logger.info(f"使用Redis: {use_redis}")
    logger.info(f"Cookie安全模式: {cookie_secure}")
    
    # 初始化数据库表
    try:
        from app.database import sync_engine
        from app.models import Base
        
        logger.info("正在创建数据库表...")
        Base.metadata.create_all(bind=sync_engine)
        logger.info("数据库表创建完成！")
        
        # 验证表是否创建成功
        from sqlalchemy import inspect
        inspector = inspect(sync_engine)
        tables = inspector.get_table_names()
        logger.info(f"已创建的表: {tables}")
        
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
        
    except Exception as e:
        logger.error(f"数据库初始化失败: {e}")
        import traceback
        traceback.print_exc()
    
    logger.info("启动后台任务：自动取消过期任务")
    background_thread = threading.Thread(target=run_background_task, daemon=True)
    background_thread.start()
    
    # 启动会话清理任务
    logger.info("启动后台任务：清理过期会话")
    session_cleanup_thread = threading.Thread(target=run_session_cleanup_task, daemon=True)
    session_cleanup_thread.start()
    
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
    
    # 5. 关闭数据库连接池（必须在事件循环还活着的时候做）
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
        session_id = websocket.query_params.get("session_id")
        if session_id:
            logger.debug(f"Found session_id in query params for user {user_id}")
    
    if not session_id:
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
                logger.debug(f"WebSocket connection established for user {user_id} (total: {len(ws_manager.connections)})")
            except Exception as accept_error:
                # accept 失败，回滚连接注册
                if ws_manager.connections.get(user_id) == new_connection:
                    del ws_manager.connections[user_id]
                raise accept_error
            
            # 异步关闭旧连接（不影响新连接）
            if old_websocket:
                logger.debug(f"Closing old WebSocket connection for user {user_id}")
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
        except Exception:
            pass
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
        except:
            pass
        return
    
    # ⚠️ 注意：心跳已在业务循环中统一处理（方案B），不再单独启动心跳任务
    # 心跳逻辑已整合到主消息循环中，避免与业务receive竞争
    
    # 心跳相关变量
    last_ping_time = get_utc_time()  # 统一使用UTC时间
    ping_interval = 20  # 20秒发送一次ping
    missing_pongs = 0
    max_missing_pongs = 3

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
                    logger.error(f"Failed to send ping to user {user_id}: {e}")
            
            # 统一接收消息（心跳和业务消息都在这里处理，避免竞争）
            try:
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=5.0
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
                        logger.info(f"🔍 [DEBUG] 客服消息检测到图片，image_id: {image_id}")
                    
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

                    # 构建消息响应
                    message_response = {
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
        except:
            pass
    finally:
        # 确保连接被清理（防止异常情况下连接泄漏）
        # remove_connection 内部有检查，重复调用是安全的
        if user_id in ws_manager.connections:
            ws_manager.remove_connection(user_id)


@app.get("/")
def read_root():
    """根路径 - 不依赖数据库，用于基本健康检查"""
    return {"status": "ok", "message": "Welcome to Link²Ur!"}


@app.get("/health")
async def health_check():
    """完整的健康检查 - 高优先级优化"""
    import time
    from datetime import datetime
    from sqlalchemy import text
    
    start_time = time.time()
    health_status = {
        "status": "healthy",
        "timestamp": format_iso_utc(get_utc_time()),
        "checks": {}
    }
    
    # 检查数据库连接
    db_healthy = False
    try:
        from app.database import sync_engine
        with sync_engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        health_status["checks"]["database"] = "ok"
        db_healthy = True
        logger.debug("✅ 数据库连接检查通过")
    except Exception as e:
        health_status["checks"]["database"] = f"error: {str(e)}"
        health_status["status"] = "degraded"
        logger.error(f"❌ 数据库连接失败: {e}")
    
    # 更新 Prometheus 指标
    try:
        from app.metrics import update_health_status
        update_health_status("database", db_healthy)
    except Exception:
        pass
    
    # 检查Redis连接
    redis_healthy = False
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            redis_client.ping()
            health_status["checks"]["redis"] = "ok"
            redis_healthy = True
            logger.debug("✅ Redis连接检查通过")
        else:
            health_status["checks"]["redis"] = "not configured"
            logger.info("ℹ️  Redis未配置")
    except Exception as e:
        health_status["checks"]["redis"] = f"error: {str(e)}"
        logger.warning(f"⚠️  Redis连接失败: {e}")
    
    # 更新 Prometheus 指标
    try:
        from app.metrics import update_health_status
        update_health_status("redis", redis_healthy)
    except Exception:
        pass
    
    # 检查磁盘空间（上传目录）
    try:
        from pathlib import Path
        upload_dir = Path("uploads")
        if upload_dir.exists():
            stat = upload_dir.stat()
            health_status["checks"]["disk"] = "ok"
            logger.debug("✅ 磁盘空间检查通过")
        else:
            health_status["checks"]["disk"] = "directory missing"
            logger.warning("⚠️  上传目录不存在")
    except Exception as e:
        health_status["checks"]["disk"] = f"error: {str(e)}"
        logger.error(f"❌ 磁盘检查失败: {e}")
    
    # 更新整体健康状态
    try:
        from app.metrics import update_health_status
        overall_healthy = health_status["status"] == "healthy"
        update_health_status("overall", overall_healthy)
    except Exception:
        pass
    
    # 记录 HTTP 请求指标
    try:
        from app.metrics import record_http_request
        duration = time.time() - start_time
        status_code = 200 if health_status["status"] == "healthy" else 503
        record_http_request("GET", "/health", status_code, duration)
    except Exception:
        pass
    
    # 根据检查结果决定最终状态
    if health_status["status"] == "healthy":
        return health_status
    else:
        # 如果数据库不可用，返回503状态码
        return JSONResponse(
            status_code=503,
            content=health_status
        )

@app.get("/ping")
def ping():
    """简单的ping端点 - 用于健康检查"""
    return "pong"


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


@app.get("/test-db")
def test_db(db: Session = Depends(get_db)):
    try:
        # 尝试查询用户表
        from app.models import User

        user_count = db.query(User).count()
        return {"message": "Database connection successful", "user_count": user_count}
    except Exception as e:
        return {"error": f"Database connection failed: {str(e)}"}


@app.get("/test-ws")
def test_ws():
    return {
        "message": "WebSocket test endpoint",
        "example_message": {
            "receiver_id": 2,
            "content": "Hello, this is a test message",
        },
    }


@app.get("/test-users")
def test_users(db: Session = Depends(get_db)):
    users = crud.get_all_users(db)
    return {
        "users": [
            {"id": user.id, "name": user.name, "email": user.email} for user in users
        ]
    }


@app.get("/test-active-connections")
def test_active_connections():
    """测试活跃WebSocket连接"""
    from app.websocket_manager import get_ws_manager
    ws_manager = get_ws_manager()
    stats = ws_manager.get_stats()
    return {
        "active_connections": [conn['user_id'] for conn in stats['connections']],
        "connection_count": stats['total_connections'],
        "active_count": stats['active_connections'],
        "detailed_stats": stats
    }


@app.post("/api/admin/cancel-expired-tasks")
def manual_cancel_expired_tasks(db: Session = Depends(get_db)):
    """手动触发过期任务取消（用于测试）"""
    try:
        cancelled_count = crud.cancel_expired_tasks(db)
        return {
            "message": f"成功取消 {cancelled_count} 个过期任务",
            "cancelled_count": cancelled_count,
        }
    except Exception as e:
        logger.error(f"手动取消过期任务时出错: {e}")
        return {"error": str(e)}


@app.post("/api/admin/update-user-statistics")
def manual_update_user_statistics(db: Session = Depends(get_db)):
    """手动触发用户统计信息更新（用于测试）"""
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
    except Exception as e:
        logger.error(f"手动更新用户统计信息时出错: {e}")
        return {"error": str(e)}


# 已删除过时的客服会话清理函数

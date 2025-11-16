import asyncio
import json
import logging
import os
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytz
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
    
    # 检查是否是API端点
    if request.url.path.startswith("/api"):
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
    elif request.url.hostname == "api.link2ur.com" or request.url.hostname == "api.link2ur.com/":
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
    
    return response

@app.middleware("http")
async def custom_cors_middleware(request: Request, call_next):
    """自定义CORS中间件，覆盖Railway默认设置"""
    # 处理OPTIONS预检请求
    if request.method == "OPTIONS":
        response = Response(status_code=200)
        origin = request.headers.get("origin")
        allowed_domains = [
            "https://link-u1", "http://localhost", "https://www.link2ur.com", "https://api.link2ur.com"
        ]
        if origin and any(origin == domain or origin.startswith(domain) for domain in allowed_domains):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, X-CSRF-Token, X-Session-ID"
        return response
    
    response = await call_next(request)
    
    # 强制设置CORS头（包括错误响应）
    origin = request.headers.get("origin")
    allowed_domains = [
        "https://link-u1", "http://localhost", "https://www.link2ur.com", "https://api.link2ur.com"
    ]
    if origin and any(origin == domain or origin.startswith(domain) for domain in allowed_domains):
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, X-CSRF-Token, X-Session-ID"
        # 确保即使错误响应也包含CORS头
        if response.status_code >= 400:
            # 对于错误响应，也要确保CORS头存在
            pass  # CORS头已经在上面的条件中设置了
    
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

# 任务达人功能路由
from app.task_expert_routes import task_expert_router
app.include_router(task_expert_router)

from app.user_service_application_routes import user_service_application_router
app.include_router(user_service_application_router)

from app.admin_task_expert_routes import admin_task_expert_router
app.include_router(admin_task_expert_router)

# 创建上传目录
import os
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")

if RAILWAY_ENVIRONMENT:
    # Railway环境：使用持久化卷
    UPLOAD_DIR = Path("/data/uploads")
    # 公开目录（用于静态文件服务）
    (UPLOAD_DIR / "public").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "images").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "public" / "files").mkdir(parents=True, exist_ok=True)
    # 私有目录（需要签名URL访问）
    (UPLOAD_DIR / "private").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private" / "images").mkdir(parents=True, exist_ok=True)
    (UPLOAD_DIR / "private" / "files").mkdir(parents=True, exist_ok=True)
else:
    # 本地开发环境
    UPLOAD_DIR = Path("uploads")
    UPLOAD_DIR.mkdir(exist_ok=True)
    # 公开目录
    (UPLOAD_DIR / "public").mkdir(exist_ok=True)
    (UPLOAD_DIR / "public" / "images").mkdir(exist_ok=True)
    (UPLOAD_DIR / "public" / "files").mkdir(exist_ok=True)
    # 私有目录
    (UPLOAD_DIR / "private").mkdir(exist_ok=True)
    (UPLOAD_DIR / "private" / "images").mkdir(exist_ok=True)
    (UPLOAD_DIR / "private" / "files").mkdir(exist_ok=True)

# 添加静态文件服务 - 只允许访问公开目录
# 注意：在生产环境中，StaticFiles可能无法正常工作，因此我们使用路由来处理
if RAILWAY_ENVIRONMENT:
    # Railway环境：使用路由方式提供静态文件访问
    @app.get("/uploads/{file_path:path}")
    async def serve_public_uploads(file_path: str):
        """提供公开上传文件的访问"""
        from fastapi.responses import FileResponse
        import mimetypes
        
        # 构建文件路径
        file_full_path = Path("/data/uploads/public") / file_path
        
        # 安全检查：确保文件在公开目录内
        try:
            file_full_path.resolve().relative_to(Path("/data/uploads/public").resolve())
        except ValueError:
            raise HTTPException(status_code=403, detail="访问被拒绝")
        
        if not file_full_path.exists():
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
    app.mount("/uploads", StaticFiles(directory="uploads/public"), name="uploads")

active_connections = {}


async def heartbeat_loop(websocket: WebSocket, user_id: str):
    """心跳循环，保持WebSocket连接活跃"""
    try:
        while True:
            await asyncio.sleep(30)  # 每30秒发送一次心跳
            if websocket.client_state == WebSocketState.CONNECTED:
                try:
                    uk_tz = pytz.timezone("Europe/London")
                    uk_time = datetime.now(uk_tz)  # 英国时间
                    await websocket.send_text(
                        json.dumps(
                            {"type": "heartbeat", "timestamp": uk_time.isoformat()}
                        )
                    )
                    logger.debug(f"Heartbeat sent to user {user_id}")
                except Exception as e:
                    logger.error(f"Failed to send heartbeat to user {user_id}: {e}")
                    break
            else:
                logger.info(
                    f"WebSocket disconnected for user {user_id}, stopping heartbeat"
                )
                break
    except asyncio.CancelledError:
        logger.info(f"Heartbeat task cancelled for user {user_id}")
    except Exception as e:
        logger.error(f"Heartbeat error for user {user_id}: {e}")


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
    task_counter = 0
    last_bio_update_date = None  # 记录上次更新 bio 的日期
    
    while True:
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


def run_session_cleanup_task():
    """运行会话清理任务"""
    while True:
        try:
            from app.secure_auth import SecureAuthManager
            SecureAuthManager.cleanup_expired_sessions()
            # 每5分钟清理一次过期会话
            time.sleep(300)
        except Exception as e:
            logger.error(f"会话清理任务出错: {e}")
            time.sleep(300)  # 出错时等待5分钟后重试




@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库并启动后台任务"""
    # 启动定时任务（可选：使用APScheduler或Celery）
    # 这里使用简单的后台线程方式
    import threading
    import time
    from app.scheduled_tasks import run_scheduled_tasks
    
    def run_tasks_periodically():
        """每5分钟执行一次定时任务"""
        while True:
            try:
                run_scheduled_tasks()
            except Exception as e:
                logger.error(f"定时任务执行失败: {e}", exc_info=True)
            time.sleep(300)  # 5分钟
    
    # 启动后台线程
    scheduler_thread = threading.Thread(target=run_tasks_periodically, daemon=True)
    scheduler_thread.start()
    logger.info("定时任务已启动（每5分钟执行一次）")
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
        
        # 注意：数据库迁移脚本需要手动执行，不在启动时自动执行
        # 迁移脚本位置：backend/migrations/
        # 1. create_coupon_points_tables.sql
        # 2. add_task_indexes.sql
        # 3. create_task_expert_tables.sql
        
        # 创建优化索引（使用 pg_trgm）
        try:
            database_url = os.getenv("DATABASE_URL")
            if database_url:
                import sys
                sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
                from create_indexes import create_trgm_indexes
                create_trgm_indexes(database_url)
        except Exception as e:
            logger.warning(f"创建索引时出错（可继续运行）: {e}")
        
        # 验证表是否创建成功
        from sqlalchemy import inspect
        inspector = inspect(sync_engine)
        tables = inspector.get_table_names()
        logger.info(f"已创建的表: {tables}")
        
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
        asyncio.create_task(start_background_cleanup())
        logger.info("定期清理任务已启动")
    except Exception as e:
        logger.error(f"启动定期清理任务失败: {e}")


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
        logger.info(f"Found user session_id in cookies for user {user_id}")
    
    # 检查客服service_session_id cookie
    elif "service_session_id" in cookies:
        session_id = cookies["service_session_id"]
        is_service_auth = True
        logger.info(f"Found service_session_id in cookies for user {user_id}")
    
    # 如果Cookie中没有session_id，尝试从查询参数获取（向后兼容）
    if not session_id:
        session_id = websocket.query_params.get("session_id")
        if session_id:
            logger.info(f"Found session_id in query params for user {user_id}")
    
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
            
            logger.info(f"WebSocket service authentication successful for user {user_id}")
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

            logger.info(f"WebSocket user authentication successful for user {user_id}")
    except Exception as e:
        logger.error(f"WebSocket authentication failed for user {user_id}: {e}")
        await websocket.close(code=1008, reason="Invalid session")
        return

    await websocket.accept()
    active_connections[user_id] = websocket
    logger.info(f"WebSocket connection established for user {user_id}")

    # 启动心跳任务
    import asyncio

    heartbeat_task = asyncio.create_task(heartbeat_loop(websocket, user_id))

    try:
        while True:
            data = await websocket.receive_text()
            logger.info(f"Received message from user {user_id}: {data}")

            try:
                # 检查数据是否为有效的JSON
                if not data.strip():
                    await websocket.send_text(
                        json.dumps({"error": "Empty message received"})
                    )
                    continue

                msg = json.loads(data)
                logger.info(f"Parsed message: {msg}")

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

                    # 推送给接收方
                    receiver_ws = active_connections.get(receiver_id)
                    logger.info(
                        f"Active connections: {list(active_connections.keys())}"
                    )
                    logger.info(
                        f"Looking for receiver_ws for {receiver_id}: {receiver_ws is not None}"
                    )

                    if receiver_ws:
                        try:
                            await receiver_ws.send_text(json.dumps(message_response))
                            logger.info(
                                f"Customer service message sent to receiver {receiver_id}"
                            )
                        except Exception as e:
                            logger.error(
                                f"Failed to send customer service message to receiver {receiver_id}: {e}"
                            )
                            # 如果接收方连接失败，从活跃连接中移除
                            active_connections.pop(receiver_id, None)
                    else:
                        logger.warning(
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
                    # 处理普通消息（向后兼容）
                    if is_customer_service:
                        # 客服账号只能发送客服会话消息
                        if not isinstance(data, dict) or not data.get("session_id"):
                            await websocket.send_text(
                                json.dumps({"error": "客服账号只能发送客服会话消息"})
                            )
                            continue
                    else:
                        # 普通用户向客服发送消息时，必须通过客服会话
                        is_receiver_customer_service = (
                            db.query(CustomerService)
                            .filter(CustomerService.id == msg["receiver_id"])
                            .first()
                            is not None
                        )
                        if is_receiver_customer_service:
                            if not chat_id:
                                await websocket.send_text(
                                    json.dumps(
                                        {"error": "向客服发送消息必须通过客服会话"}
                                    )
                                )
                                continue

                    # 处理图片消息
                    image_id = None
                    if msg["content"].startswith('[图片] '):
                        # 提取图片ID
                        image_id = msg["content"].replace('[图片] ', '')
                        logger.info(f"🔍 [DEBUG] WebSocket检测到图片消息，image_id: {image_id}")
                    
                    # 保存普通消息到数据库
                    message = crud.send_message(
                        db, 
                        user_id, 
                        msg["receiver_id"], 
                        msg["content"], 
                        msg.get("message_id", None),
                        msg.get("timezone", "Europe/London"),
                        msg.get("local_time", None),
                        image_id=image_id
                    )

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

                # 推送给接收方
                receiver_ws = active_connections.get(msg["receiver_id"])
                if receiver_ws:
                    try:
                        await receiver_ws.send_text(json.dumps(message_response))
                        logger.info(f"Message sent to receiver {msg['receiver_id']}")
                    except Exception as e:
                        logger.error(
                            f"Failed to send message to receiver {msg['receiver_id']}: {e}"
                        )
                        # 如果接收方连接失败，从活跃连接中移除
                        active_connections.pop(msg["receiver_id"], None)

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
                    logger.info(f"Confirmation sent to sender {user_id}")
                except Exception as e:
                    logger.error(
                        f"Failed to send confirmation to sender {user_id}: {e}"
                    )

                logger.info(f"Message processed for sender {user_id}")

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
        logger.info(f"WebSocket disconnected for user {user_id}")
        active_connections.pop(user_id, None)
        heartbeat_task.cancel()
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}")
        active_connections.pop(user_id, None)
        heartbeat_task.cancel()
        try:
            await websocket.close()
        except:
            pass


@app.get("/")
def read_root():
    """根路径 - 不依赖数据库，用于基本健康检查"""
    return {"status": "ok", "message": "Welcome to Link²Ur!"}


@app.get("/health")
async def health_check():
    """完整的健康检查 - 高优先级优化"""
    from datetime import datetime
    from sqlalchemy import text
    
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "checks": {}
    }
    
    # 检查数据库连接
    try:
        from app.database import sync_engine
        with sync_engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        health_status["checks"]["database"] = "ok"
        logger.debug("✅ 数据库连接检查通过")
    except Exception as e:
        health_status["checks"]["database"] = f"error: {str(e)}"
        health_status["status"] = "degraded"
        logger.error(f"❌ 数据库连接失败: {e}")
    
    # 检查Redis连接
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            redis_client.ping()
            health_status["checks"]["redis"] = "ok"
            logger.debug("✅ Redis连接检查通过")
        else:
            health_status["checks"]["redis"] = "not configured"
            logger.info("ℹ️  Redis未配置")
    except Exception as e:
        health_status["checks"]["redis"] = f"error: {str(e)}"
        logger.warning(f"⚠️  Redis连接失败: {e}")
    
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
    return {
        "active_connections": list(active_connections.keys()),
        "connection_count": len(active_connections),
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

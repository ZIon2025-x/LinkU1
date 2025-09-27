import asyncio
import json
import logging
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytz
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    Request,
    Response,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.websockets import WebSocketState
from sqlalchemy.orm import Session

from app import crud
from app.auth_routes import auth_router
from app.cs_auth_routes import cs_auth_router
from app.admin_auth_routes import admin_auth_router
from app.csrf_routes import router as csrf_router
from app.rate_limit_routes import router as rate_limit_router
from app.security_monitoring_routes import router as security_monitoring_router
from app.deps import get_db
from app.routers import router as user_router
from app.security import add_security_headers
from app.security_monitoring import check_security_middleware

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="LinkU Task Platform",
    description="A simple task platform for students, freelancers, and job seekers.",
    version="0.1.0",
)

# 添加CORS中间件 - 必须在安全中间件之前
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # 开发环境
        "https://link-u1.vercel.app",  # Vercel 生产环境
        "https://link-u1-pl8v23y2h-zion2025-xs-projects.vercel.app",  # 之前的 Vercel 域名
        "https://link-u1-mgkv.vercel.app",  # 当前 Vercel 域名
        "https://*.vercel.app",  # 所有 Vercel 子域名
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 安全中间件 - 必须在CORS中间件之后（暂时禁用以解决异步/同步混用问题）
# @app.middleware("http")
# async def security_monitoring_middleware(request: Request, call_next):
#     """安全监控中间件"""
#     return await check_security_middleware(request, call_next)

@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """添加安全响应头"""
    response = await call_next(request)
    add_security_headers(response)
    return response


app.include_router(user_router, prefix="/api/users", tags=["users"])
app.include_router(auth_router, tags=["用户认证"])
app.include_router(cs_auth_router, tags=["客服认证"])
app.include_router(admin_auth_router, tags=["管理员认证"])
app.include_router(csrf_router, tags=["CSRF保护"])
app.include_router(rate_limit_router, tags=["速率限制"])
# 暂时禁用安全监控路由以解决异步/同步混用问题
# app.include_router(security_monitoring_router, tags=["安全监控"])

# 添加任务相关的路由（不需要/users前缀）
from app.routers import router as task_router
from app.async_routers import async_router

# 先注册异步路由，确保优先级
app.include_router(async_router, prefix="/api", tags=["async"])
app.include_router(task_router, prefix="/api", tags=["tasks"])

# 创建上传目录
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
(UPLOAD_DIR / "images").mkdir(exist_ok=True)

# 添加静态文件服务
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

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
    task_counter = 0
    while True:
        try:
            # 取消过期任务（每分钟执行）
            cancel_expired_tasks()

            # 更新所有用户统计信息（每10分钟执行一次）
            if task_counter % 10 == 0:
                update_all_users_statistics()

            task_counter += 1
            # 每1分钟检查一次
            time.sleep(60)
        except Exception as e:
            logger.error(f"后台任务循环出错: {e}")
            time.sleep(60)  # 出错时等待1分钟后重试


# 启动后台任务
@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库并启动后台任务"""
    logger.info("应用启动中...")
    
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
        
    except Exception as e:
        logger.error(f"数据库初始化失败: {e}")
        import traceback
        traceback.print_exc()
    
    logger.info("启动后台任务：自动取消过期任务")
    background_thread = threading.Thread(target=run_background_task, daemon=True)
    background_thread.start()


@app.websocket("/ws/chat/{user_id}")
async def websocket_chat(
    websocket: WebSocket, user_id: str, db: Session = Depends(get_db)
):
    # 首先尝试从Cookie中获取token
    token = None
    cookies = websocket.cookies
    
    # 检查access_token cookie
    if "access_token" in cookies:
        token = cookies["access_token"]
        logger.info(f"Found access_token in cookies for user {user_id}")
    
    # 如果Cookie中没有token，尝试从查询参数获取（向后兼容）
    if not token:
        token = websocket.query_params.get("token")
        if token:
            logger.info(f"Found token in query params for user {user_id}")
    
    if not token:
        await websocket.close(code=1008, reason="Missing authentication token")
        return

    # 验证JWT token
    try:
        from app.auth import decode_access_token

        payload = decode_access_token(token)

        # 验证JWT token中的用户ID与WebSocket路径中的user_id是否匹配
        if not payload:
            logger.error("Invalid token payload")
            await websocket.close(code=1008, reason="Invalid token")
            return

        token_user_id = payload.get("sub")  # JWT token中使用sub字段存储用户ID
        if token_user_id != user_id:
            logger.error(f"User ID mismatch: token={token_user_id}, path={user_id}")
            await websocket.close(code=1008, reason="User ID mismatch")
            return

        logger.info(f"WebSocket authentication successful for user {user_id}")
    except Exception as e:
        logger.error(f"WebSocket authentication failed for user {user_id}: {e}")
        await websocket.close(code=1008, reason="Invalid authentication token")
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
                from app.auth import decode_access_token
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

                    # 保存客服对话消息
                    message = crud.save_customer_service_message(
                        db, chat_id, user_id, sender_type, msg["content"]
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
                        if not data.get("session_id"):
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

                    # 保存普通消息到数据库
                    message = crud.send_message(
                        db, user_id, msg["receiver_id"], msg["content"]
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
    return {"status": "ok", "message": "Welcome to LinkU!"}


@app.get("/health")
def health_check():
    """健康检查端点 - 不依赖数据库"""
    return {"status": "healthy"}

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

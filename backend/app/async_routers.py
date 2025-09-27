"""
异步API路由模块
展示如何使用异步数据库操作
"""

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, models, schemas
from app.database import check_database_health, get_pool_status
from app.deps import get_async_db_dependency, get_current_user_async, get_current_user_secure
from app.csrf import csrf_cookie_bearer
from app.security import cookie_bearer
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

# 创建异步路由器
async_router = APIRouter()


# 异步用户路由
@async_router.get("/users/me", response_model=schemas.UserOut)
async def get_current_user_info(
    current_user: models.User = Depends(get_current_user_secure),
):
    """获取当前用户信息（异步版本）"""
    return current_user


@async_router.get("/users/{user_id}", response_model=schemas.UserOut)
async def get_user_by_id(
    user_id: str, db: AsyncSession = Depends(get_async_db_dependency)
):
    """根据ID获取用户信息（异步版本）"""
    user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@async_router.get("/users", response_model=List[schemas.UserOut])
async def get_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户列表（异步版本）"""
    users = await async_crud.async_user_crud.get_users(db, skip=skip, limit=limit)
    return users


# 异步任务路由
@async_router.get("/tasks")
async def get_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    task_type: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    sort_by: Optional[str] = Query("latest"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务列表（异步版本）"""
    # 支持page/page_size参数，向后兼容skip/limit
    if page > 1 or page_size != 20:
        skip = (page - 1) * page_size
        limit = page_size
    
    tasks, total = await async_crud.async_task_crud.get_tasks_with_total(
        db,
        skip=skip,
        limit=limit,
        task_type=task_type,
        location=location,
        status=status,
        keyword=keyword,
        sort_by=sort_by,
    )
    
    # 返回与前端期望的数据结构兼容的格式
    return {
        "tasks": tasks,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@async_router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
async def get_task_by_id(
    task_id: int, db: AsyncSession = Depends(get_async_db_dependency)
):
    """根据ID获取任务信息（异步版本）"""
    task = await async_crud.async_task_crud.get_task_by_id(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


# 创建任务专用的认证依赖（支持Cookie，暂时不需要CSRF保护）
async def get_current_user_for_task_creation(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(cookie_bearer),
) -> models.User:
    """任务创建专用的用户认证（支持Cookie，需要CSRF保护）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        from app.security import verify_token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(csrf_cookie_bearer),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        from app.security import verify_token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        # 检查用户状态
        if hasattr(user, "is_suspended") and user.is_suspended:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
            )

        if hasattr(user, "is_banned") and user.is_banned:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")

# 简化的测试路由
@async_router.get("/test")
async def test_simple_route():
    """简单的测试路由"""
    return {"message": "测试路由正常工作", "status": "success"}

@async_router.post("/test")
async def test_simple_route_post():
    """简单的测试路由POST"""
    return {"message": "测试路由POST正常工作", "status": "success"}

# 异步任务创建端点（支持CSRF保护）
@async_router.post("/tasks", response_model=schemas.TaskOut)
@rate_limit("create_task")
async def create_task_async(
    task: schemas.TaskCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务（异步版本，支持CSRF保护）"""
    try:
        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能发布任务")

        print(f"DEBUG: 开始创建任务，用户ID: {current_user.id}")
        print(f"DEBUG: 任务数据: {task}")
        
        db_task = await async_crud.async_task_crud.create_task(
            db, task, current_user.id
        )
        
        print(f"DEBUG: 任务创建成功，任务ID: {db_task.id}")
        
        # 返回简单的成功响应，避免序列化问题
        result = {
            "id": db_task.id,
            "title": db_task.title,
            "description": db_task.description,
            "deadline": db_task.deadline.isoformat() if db_task.deadline else None,
            "reward": float(db_task.reward),
            "location": db_task.location,
            "task_type": db_task.task_type,
            "poster_id": db_task.poster_id,
            "taker_id": db_task.taker_id,
            "status": db_task.status,
            "task_level": db_task.task_level,
            "created_at": db_task.created_at.isoformat() if db_task.created_at else None,
            "is_public": int(db_task.is_public) if db_task.is_public is not None else 1
        }
        
        print(f"DEBUG: 准备返回结果: {result}")
        return result
        
    except HTTPException as e:
        # Re-raise HTTPExceptions to preserve error details
        print(f"DEBUG: HTTPException in task creation: {e.detail}")
        logger.error(f"HTTPException in task creation: {e.detail}")
        raise
    except Exception as e:
        print(f"DEBUG: Exception in task creation: {e}")
        logger.error(f"Error creating task: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to create task: {str(e)}")


@async_router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
async def accept_task(
    task_id: int,
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """接受任务（异步版本）"""
    task = await async_crud.async_task_crud.accept_task(db, task_id, current_user.id)
    if not task:
        raise HTTPException(
            status_code=400, detail="Task not available or already taken"
        )
    return task


@async_router.get("/users/{user_id}/tasks", response_model=dict)
async def get_user_tasks(
    user_id: str,
    task_type: str = Query("all"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的任务（异步版本）"""
    tasks = await async_crud.async_task_crud.get_user_tasks(db, user_id, task_type)
    return tasks


# 异步消息路由
@async_router.post("/messages", response_model=schemas.MessageOut)
async def send_message(
    message: schemas.MessageCreate,
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """发送消息（异步版本）"""
    try:
        db_message = await async_crud.async_message_crud.create_message(
            db, current_user.id, message.receiver_id, message.content
        )
        return db_message
    except Exception as e:
        logger.error(f"Error sending message: {e}")
        raise HTTPException(status_code=500, detail="Failed to send message")


@async_router.get("/messages", response_model=List[schemas.MessageOut])
async def get_messages(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的消息（异步版本）"""
    messages = await async_crud.async_message_crud.get_messages(
        db, current_user.id, skip=skip, limit=limit
    )
    return messages


@async_router.get(
    "/messages/conversation/{user_id}", response_model=List[schemas.MessageOut]
)
async def get_conversation_messages(
    user_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取与指定用户的对话消息（异步版本）"""
    messages = await async_crud.async_message_crud.get_conversation_messages(
        db, current_user.id, user_id, skip=skip, limit=limit
    )
    return messages


# 异步通知路由
@async_router.get("/notifications", response_model=List[schemas.NotificationOut])
async def get_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户通知（异步版本）"""
    notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=skip, limit=limit, unread_only=unread_only
    )
    return notifications


@async_router.put(
    "/notifications/{notification_id}/read", response_model=schemas.NotificationOut
)
async def mark_notification_as_read(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """标记通知为已读（异步版本）"""
    notification = await async_crud.async_notification_crud.mark_notification_as_read(
        db, notification_id
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


# 系统监控路由
@async_router.get("/system/health")
async def system_health_check():
    """系统健康检查（异步版本）"""
    db_health = await check_database_health()
    return {
        "status": "healthy" if db_health else "unhealthy",
        "database": "connected" if db_health else "disconnected",
        "timestamp": "2025-01-01T00:00:00Z",  # 实际应该使用当前时间
    }


@async_router.get("/system/database/stats")
async def get_database_stats(db: AsyncSession = Depends(get_async_db_dependency)):
    """获取数据库统计信息（异步版本）"""
    stats = await async_crud.async_performance_monitor.get_database_stats(db)
    return stats


@async_router.get("/system/database/pool")
async def get_database_pool_status():
    """获取数据库连接池状态（异步版本）"""
    pool_status = await get_pool_status()
    return pool_status


# 批量操作路由
@async_router.post("/notifications/batch")
async def batch_create_notifications(
    notifications: List[schemas.NotificationCreate],
    current_user: models.User = Depends(get_current_user_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """批量创建通知（异步版本）"""
    try:
        notification_data = [
            {
                "user_id": current_user.id,
                "type": notification.type,
                "title": notification.title,
                "content": notification.content,
                "related_id": notification.related_id,
            }
            for notification in notifications
        ]

        db_notifications = await async_crud.async_batch_ops.batch_create_notifications(
            db, notification_data
        )
        return db_notifications
    except Exception as e:
        logger.error(f"Error batch creating notifications: {e}")
        raise HTTPException(status_code=500, detail="Failed to create notifications")

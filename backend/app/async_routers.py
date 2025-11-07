"""
异步API路由模块
展示如何使用异步数据库操作
"""

import json
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status, BackgroundTasks, Body
from fastapi.security import HTTPAuthorizationCredentials
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app import async_crud, models, schemas
from app.database import check_database_health, get_pool_status
from app.deps import get_async_db_dependency
from app.csrf import csrf_cookie_bearer
from app.security import cookie_bearer
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

# 创建异步路由器
async_router = APIRouter()


# 创建任务专用的认证依赖（支持Cookie + CSRF保护）
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(csrf_cookie_bearer),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    # 首先尝试使用会话认证
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
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
    
    # 如果会话认证失败，抛出认证错误
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


# 异步用户路由
@async_router.get("/users/me", response_model=schemas.UserOut)
async def get_current_user_info(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
        
        # 清除用户任务缓存，确保新任务能立即显示
        try:
            from app.redis_cache import invalidate_user_cache, invalidate_tasks_cache
            invalidate_user_cache(current_user.id)
            invalidate_tasks_cache()
            print(f"DEBUG: 已清除用户 {current_user.id} 的任务缓存")
        except Exception as e:
            print(f"DEBUG: 清除缓存失败: {e}")
        
        # 额外清除特定格式的缓存键
        try:
            from app.redis_cache import redis_cache
            # 清除所有可能的用户任务缓存键格式
            patterns = [
                f"user_tasks:{current_user.id}*",
                f"{current_user.id}_*",
                f"user_tasks:{current_user.id}_*"
            ]
            for pattern in patterns:
                deleted = redis_cache.delete_pattern(pattern)
                if deleted > 0:
                    print(f"DEBUG: 清除模式 {pattern}，删除了 {deleted} 个键")
        except Exception as e:
            print(f"DEBUG: 额外清除缓存失败: {e}")
        
        # 处理图片字段：将JSON字符串解析为列表
        import json
        images_list = None
        if db_task.images:
            try:
                images_list = json.loads(db_task.images)
            except (json.JSONDecodeError, TypeError):
                images_list = []
        
        # 返回简单的成功响应，避免序列化问题
        result = {
            "id": db_task.id,
            "title": db_task.title,
            "description": db_task.description,
            "deadline": db_task.deadline.isoformat() if db_task.deadline else None,
            "reward": float(db_task.agreed_reward) if db_task.agreed_reward is not None else float(db_task.base_reward) if db_task.base_reward is not None else float(db_task.reward),
            "base_reward": float(db_task.base_reward) if db_task.base_reward else None,
            "agreed_reward": float(db_task.agreed_reward) if db_task.agreed_reward else None,
            "currency": db_task.currency or "GBP",
            "location": db_task.location,
            "task_type": db_task.task_type,
            "poster_id": db_task.poster_id,
            "taker_id": db_task.taker_id,
            "status": db_task.status,
            "task_level": db_task.task_level,
            "created_at": db_task.created_at.isoformat() if db_task.created_at else None,
            "is_public": int(db_task.is_public) if db_task.is_public is not None else 1,
            "images": images_list  # 返回图片列表
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


@async_router.post("/tasks/{task_id}/apply-test", response_model=dict)
async def apply_for_task_test(
    task_id: int,
    request_data: dict = Body({}),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请任务测试端点（简化版本）"""
    try:
        message = request_data.get('message', None)
        print(f"DEBUG: 测试申请任务，任务ID: {task_id}, 用户ID: {current_user.id}, message: {message}")
        
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        print(f"DEBUG: 任务存在: {task.title}")
        
        return {
            "message": "测试成功",
            "task_id": task_id,
            "user_id": str(current_user.id),
            "task_title": task.title
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Test error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Test error: {str(e)}")


@async_router.post("/tasks/{task_id}/apply", response_model=dict)
async def apply_for_task(
    task_id: int,
    request_data: dict = Body({}),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """申请任务（异步版本，支持议价价格）"""
    try:
        message = request_data.get('message', None)
        negotiated_price = request_data.get('negotiated_price', None)
        currency = request_data.get('currency', None)
        
        logger.info(f"开始申请任务 - 任务ID: {task_id}, 用户ID: {current_user.id}, message: {message}, negotiated_price: {negotiated_price}, currency: {currency}")
        print(f"DEBUG: 开始申请任务，任务ID: {task_id}, 用户ID: {current_user.id}, message: {message}, negotiated_price: {negotiated_price}")
        
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            error_msg = "任务不存在"
            logger.warning(f"申请任务失败: {error_msg}")
            raise HTTPException(status_code=404, detail=error_msg)
        
        logger.info(f"任务检查 - 任务ID: {task_id}, 状态: {task.status}, 货币: {task.currency}")
        
        # 检查任务状态：必须是 open
        if task.status != "open":
            error_msg = f"任务状态为 {task.status}，不允许申请"
            logger.warning(f"申请任务失败: {error_msg}")
            raise HTTPException(
                status_code=400,
                detail=error_msg
            )
        
        # 检查是否已经申请过（无论状态）
        applicant_id = str(current_user.id) if current_user.id else None
        if not applicant_id:
            raise HTTPException(status_code=400, detail="Invalid user ID")
        
        existing_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == applicant_id
            )
        )
        existing_result = await db.execute(existing_query)
        existing = existing_result.scalar_one_or_none()
        
        if existing:
            raise HTTPException(
                status_code=400,
                detail="您已经申请过此任务"
            )
        
        # 校验货币一致性
        if currency and task.currency:
            if currency != task.currency:
                raise HTTPException(
                    status_code=400,
                    detail=f"货币不一致：任务使用 {task.currency}，申请使用 {currency}"
                )
        
        # 检查等级匹配
        level_hierarchy = {'normal': 1, 'vip': 2, 'super': 3}
        user_level_value = level_hierarchy.get(str(current_user.user_level or 'normal'), 1)
        task_level_value = level_hierarchy.get(str(task.task_level or 'normal'), 1)
        
        if user_level_value < task_level_value:
            task_level_name = task.task_level.upper() if task.task_level else "VIP"
            raise HTTPException(
                status_code=403,
                detail=f"您的用户等级不足以申请此任务。此任务需要{task_level_name}用户才能申请。"
            )
        
        # 创建申请记录
        from app.models import get_uk_time_naive
        from decimal import Decimal
        
        current_time = get_uk_time_naive()
        new_application = models.TaskApplication(
            task_id=task_id,
            applicant_id=applicant_id,
            message=message,
            negotiated_price=Decimal(str(negotiated_price)) if negotiated_price is not None else None,
            currency=currency or task.currency or "GBP",
            status="pending",
            created_at=current_time
        )
        
        db.add(new_application)
        await db.flush()
        await db.commit()
        await db.refresh(new_application)
        
        # 发送通知给发布者（在申请记录提交后单独处理，避免影响申请流程）
        try:
            from app.models import get_uk_time_naive
            notification_time = get_uk_time_naive()
            
            # 构建通知内容
            notification_content = {
                "type": "task_application",
                "task_id": task_id,
                "task_title": task.title,
                "application_id": new_application.id,
                "applicant_name": current_user.name or f"用户{current_user.id}",
                "message": message,
                "negotiated_price": float(negotiated_price) if negotiated_price else None,
                "currency": currency or task.currency or "GBP"
            }
            
            new_notification = models.Notification(
                user_id=task.poster_id,
                type="task_application",
                title="新任务申请",
                content=json.dumps(notification_content, ensure_ascii=False),
                related_id=str(new_application.id),
                created_at=notification_time
            )
            db.add(new_notification)
            await db.commit()
            logger.info(f"已创建申请通知，任务ID: {task_id}, 申请ID: {new_application.id}")
        except Exception as e:
            logger.error(f"创建申请通知失败: {e}")
            # 通知失败不影响申请流程，申请记录已经成功提交
            # 如果通知创建失败，只回滚通知相关的操作，不影响已提交的申请记录
            try:
                await db.rollback()
            except:
                pass
        
        return {
            "message": "申请成功，请等待发布者审核",
            "application_id": new_application.id,
            "status": new_application.status
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"申请任务失败: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"申请任务失败: {str(e)}")



@async_router.get("/my-applications", response_model=List[dict])
async def get_user_applications(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取当前用户的申请记录"""
    try:
        # 获取用户的所有申请记录
        applications_query = select(models.TaskApplication).where(
            models.TaskApplication.applicant_id == current_user.id
        ).order_by(models.TaskApplication.created_at.desc())
        
        applications_result = await db.execute(applications_query)
        applications = applications_result.scalars().all()
        
        # 获取每个申请对应的任务信息
        result = []
        for app in applications:
            task_query = select(models.Task).where(models.Task.id == app.task_id)
            task_result = await db.execute(task_query)
            task = task_result.scalar_one_or_none()
            
            if task:
                result.append({
                    "id": app.id,
                    "task_id": app.task_id,
                    "task_title": task.title,
                    "task_reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else float(task.reward),
                    "task_location": task.location,
                    "status": app.status,
                    "message": app.message,
                    "created_at": app.created_at.isoformat(),
                    "task_poster_id": task.poster_id
                })
        
        return result
    except Exception as e:
        logger.error(f"Error getting user applications: {e}")
        raise HTTPException(status_code=500, detail="Failed to get applications")

@async_router.get("/tasks/{task_id}/applications", response_model=List[dict])
async def get_task_applications(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务的申请者列表（仅任务发布者可查看）"""
    try:
        print(f"[DEBUG] 获取任务 {task_id} 的申请列表，用户: {current_user.id}")
        
        # 检查是否为任务发布者
        task = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task.scalar_one_or_none()
        
        if not task:
            print(f"[DEBUG] 任务 {task_id} 不存在")
            raise HTTPException(status_code=404, detail="Task not found")
        
        print(f"[DEBUG] 任务 {task_id} 发布者: {task.poster_id}, 当前用户: {current_user.id}")
        
        if task.poster_id != current_user.id:
            print(f"[DEBUG] 用户 {current_user.id} 不是任务 {task_id} 的发布者")
            raise HTTPException(status_code=403, detail="Only task poster can view applications")
        
        print(f"[DEBUG] 开始获取任务 {task_id} 的申请列表")
        applications = await async_crud.async_task_crud.get_task_applications(db, task_id)
        print(f"[DEBUG] 找到 {len(applications)} 个申请")
    
        # 获取申请者详细信息
        result = []
        for app in applications:
            print(f"[DEBUG] 处理申请 {app.id}, 申请者: {app.applicant_id}")
            user = await db.execute(
                select(models.User).where(models.User.id == app.applicant_id)
            )
            user = user.scalar_one_or_none()
            
            if user:
                print(f"[DEBUG] 找到申请者用户: {user.name}")
                result.append({
                    "id": app.id,
                    "applicant_id": app.applicant_id,
                    "applicant_name": user.name,
                    "message": app.message,
                    "created_at": app.created_at,
                    "status": app.status
                })
            else:
                print(f"[DEBUG] 申请者用户 {app.applicant_id} 不存在")
        
        print(f"[DEBUG] 返回 {len(result)} 个申请结果")
        return result
        
    except Exception as e:
        print(f"[ERROR] 获取任务申请列表失败: {e}")
        logger.error(f"Error getting task applications for {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get applications: {str(e)}")


@async_router.post("/tasks/{task_id}/approve/{applicant_id}", response_model=schemas.TaskOut)
async def approve_application(
    task_id: int,
    applicant_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """批准申请者（仅任务发布者可操作）"""
    # 检查是否为任务发布者
    task = await db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )
    task = task.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task poster can approve applications")
    
    approved_task = await async_crud.async_task_crud.approve_application(
        db, task_id, applicant_id
    )
    
    if not approved_task:
        raise HTTPException(
            status_code=400, detail="Failed to approve application"
        )
    
    # 批准成功后发送通知和邮件给接收者
    try:
        # 获取接收者信息
        applicant_query = select(models.User).where(models.User.id == applicant_id)
        applicant_result = await db.execute(applicant_query)
        applicant = applicant_result.scalar_one_or_none()
        
        if applicant:
            # 发送通知和邮件
            from app.task_notifications import send_task_approval_notification
            from app.database import get_db
            
            # 创建同步数据库会话用于通知
            sync_db = next(get_db())
            try:
                send_task_approval_notification(
                    db=sync_db,
                    background_tasks=background_tasks,
                    task=approved_task,
                    applicant=applicant
                )
            finally:
                sync_db.close()
                
    except Exception as e:
        # 通知发送失败不影响批准流程
        logger.error(f"Failed to send task approval notification: {e}")
    
    return approved_task


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
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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


@async_router.get("/tasks/{task_id}/reviews", response_model=List[schemas.ReviewOut])
async def get_task_reviews_async(
    task_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务评价（异步版本）"""
    try:
        # 先获取所有评价（用于当前用户自己的评价检查）
        all_reviews_query = select(models.Review).where(
            models.Review.task_id == task_id
        )
        all_reviews_result = await db.execute(all_reviews_query)
        all_reviews = all_reviews_result.scalars().all()
        
        # 尝试获取当前用户
        current_user = None
        print(f"DEBUG: Cookie headers: {request.headers.get('cookie')}")
        print(f"DEBUG: 请求Cookie: {request.cookies}")
        try:
            # 尝试从Cookie中获取用户
            session_id = request.cookies.get("session_id")
            print(f"DEBUG: 从Cookie获取的session_id: {session_id}")
            if session_id:
                from app.secure_auth import validate_session
                session_info = validate_session(session_id, request, update_activity=False)
                print(f"DEBUG: 验证session结果: {session_info}")
                if session_info:
                    user_query = select(models.User).where(models.User.id == session_info.user_id)
                    user_result = await db.execute(user_query)
                    current_user = user_result.scalar_one_or_none()
                    print(f"DEBUG: 获取到当前用户: {current_user.id if current_user else None}")
        except Exception as e:
            print(f"DEBUG: 获取用户失败: {e}")
            import traceback
            traceback.print_exc()
            pass  # 未登录用户
        
        print(f"DEBUG: 所有评价数量: {len(all_reviews)}")
        print(f"DEBUG: 当前用户ID: {current_user.id if current_user else None}")
        
        # 过滤出非匿名评价供公开显示
        # 如果当前用户已评价，也要返回他们自己的评价（包括匿名）
        public_reviews = []
        
        if current_user:
            print(f"DEBUG: 当前用户已登录: {current_user.id}")
            for review in all_reviews:
                print(f"DEBUG: 检查评价 - review.user_id: {review.user_id}, is_anonymous: {review.is_anonymous}, current_user.id: {current_user.id}")
                is_current_user_review = str(review.user_id) == str(current_user.id)
                print(f"DEBUG: 是否当前用户评价: {is_current_user_review}")
                if is_current_user_review:
                    # 始终包含当前用户自己的评价，即使是匿名的
                    print(f"DEBUG: 包含当前用户自己的评价: {review.id}")
                    public_reviews.append(review)
                elif review.is_anonymous == 0:
                    # 只包含非匿名的其他用户评价
                    print(f"DEBUG: 包含非匿名评价: {review.id}")
                    public_reviews.append(review)
        else:
            # 未登录用户只看到非匿名评价
            print(f"DEBUG: 用户未登录，只返回非匿名评价")
            for review in all_reviews:
                if review.is_anonymous == 0:
                    public_reviews.append(review)
        
        print(f"DEBUG: 返回评价数量: {len(public_reviews)}")
        print(f"DEBUG: 返回的评价ID: {[r.id for r in public_reviews]}")
        print(f"DEBUG: 返回的评价用户ID: {[r.user_id for r in public_reviews]}")
        return public_reviews
    except Exception as e:
        logger.error(f"Error getting task reviews for {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get task reviews: {str(e)}")


@async_router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
async def create_review_async(
    task_id: int,
    review: schemas.ReviewCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务评价（异步版本）"""
    try:
        # 检查任务是否存在且已确认完成
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        if task.status != "completed":
            raise HTTPException(status_code=400, detail="Task must be completed to create review")
        
        # 检查用户是否是任务的参与者（发布者或接受者）
        if task.poster_id != current_user.id and task.taker_id != current_user.id:
            raise HTTPException(status_code=403, detail="Only task participants can create reviews")
        
        # 检查用户是否已经评价过这个任务
        existing_review_query = select(models.Review).where(
            models.Review.task_id == task_id,
            models.Review.user_id == current_user.id
        )
        existing_review_result = await db.execute(existing_review_query)
        existing_review = existing_review_result.scalar_one_or_none()
        
        if existing_review:
            raise HTTPException(status_code=400, detail="You have already reviewed this task")
        
        # 创建评价
        db_review = models.Review(
            user_id=current_user.id,
            task_id=task_id,
            rating=review.rating,
            comment=review.comment,
            is_anonymous=1 if review.is_anonymous else 0,
        )
        
        db.add(db_review)
        await db.commit()
        await db.refresh(db_review)
        
        # 注意：统计信息更新暂时跳过，避免异步/同步混用问题
        # 统计信息可以通过后台任务或定时任务更新
        
        return db_review
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating review for task {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create review: {str(e)}")


@async_router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
async def confirm_task_completion_async(
    task_id: int,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务发布者确认任务完成（异步版本）"""
    try:
        # 获取任务信息
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # 检查权限
        if task.poster_id != current_user.id:
            raise HTTPException(status_code=403, detail="Only task poster can confirm completion")
        
        # 检查任务状态
        if task.status != "pending_confirmation":
            raise HTTPException(status_code=400, detail="Task is not pending confirmation")
        
        # 更新任务状态为已完成
        task.status = "completed"
        await db.commit()
        
        # 添加任务历史记录
        from app import crud
        from app.database import get_db
        sync_db = next(get_db())
        try:
            crud.add_task_history(sync_db, task_id, current_user.id, "confirmed_completion")
        finally:
            sync_db.close()
        
        await db.refresh(task)
        
        # 发送任务确认完成通知和邮件给接收者
        if task.taker_id:
            try:
                # 获取接收者信息
                taker_query = select(models.User).where(models.User.id == task.taker_id)
                taker_result = await db.execute(taker_query)
                taker = taker_result.scalar_one_or_none()
                
                if taker:
                    # 发送通知和邮件
                    from app.task_notifications import send_task_confirmation_notification
                    from app.database import get_db
                    
                    # 创建同步数据库会话用于通知
                    sync_db = next(get_db())
                    try:
                        send_task_confirmation_notification(
                            db=sync_db,
                            background_tasks=background_tasks,
                            task=task,
                            taker=taker
                        )
                    finally:
                        sync_db.close()
            except Exception as e:
                # 通知发送失败不影响确认流程
                logger.error(f"Failed to send task confirmation notification: {e}")
        
        # 注意：统计信息更新暂时跳过，避免异步/同步混用问题
        # 统计信息可以通过后台任务或定时任务更新
        
        return task
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error confirming task completion: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to confirm task completion: {str(e)}")


# 批量操作路由
@async_router.post("/notifications/batch")
async def batch_create_notifications(
    notifications: List[schemas.NotificationCreate],
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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

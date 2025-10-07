import logging
import os
import uuid
from pathlib import Path

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordRequestForm, HTTPAuthorizationCredentials
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import crud, models, schemas
from app.database import get_async_db
from app.rate_limiting import rate_limit
from app.deps import get_current_user_secure_sync_csrf

logger = logging.getLogger(__name__)
import os
from datetime import datetime, timedelta

import stripe
from pydantic import BaseModel
from sqlalchemy import or_

from app.security import verify_password
from app.security import create_access_token
from app.deps import (
    check_admin_user_status,
    check_user_status,
    get_current_admin_user,
    get_current_customer_service,
    get_current_customer_service_or_user,
    get_current_user_secure_sync,
    get_current_user_optional,
    get_db,
)
from app.security import sync_cookie_bearer
from app.email_utils import (
    confirm_reset_token,
    confirm_token,
    generate_confirmation_token,
    generate_reset_token,
    send_confirmation_email,
    send_reset_email,
    send_task_update_email,
)
from app.models import CustomerService, User

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "sk_test_placeholder_replace_with_real_key")

router = APIRouter()


def admin_required(current_user=Depends(get_current_admin_user)):
    return current_user


@router.post("/register/test")
def register_test(user: schemas.UserCreate):
    """测试注册数据格式"""
    return {
        "message": "数据格式正确",
        "data": user.dict(),
        "validation": "passed"
    }

@router.post("/register/debug")
def register_debug(request_data: dict):
    """调试注册数据 - 接受原始JSON"""
    return {
        "message": "收到原始数据",
        "data": request_data,
        "keys": list(request_data.keys()),
        "types": {k: type(v).__name__ for k, v in request_data.items()}
    }

@router.post("/register")
async def register(
    user: schemas.UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
):
    """用户注册 - 根据配置决定是否需要邮箱验证"""
    from app.validators import UserValidator, validate_input
    from app.email_verification import EmailVerificationManager, send_verification_email_with_token
    from app.config import Config
    from app.security import get_password_hash
    from datetime import datetime
    from app.async_crud import async_user_crud
    
    # 使用验证器验证输入数据
    try:
        validated_data = validate_input(user.dict(), UserValidator)
    except HTTPException as e:
        raise e
    
    # 调试信息
    print(f"注册请求数据: name={validated_data['name']}, email={validated_data['email']}, phone={validated_data.get('phone', 'None')}")
    
    # 检查邮箱是否已被注册（正式用户）
    db_user = await async_user_crud.get_user_by_email(db, validated_data['email'])
    if db_user:
        raise HTTPException(
            status_code=400, 
            detail="该邮箱已被注册，请使用其他邮箱或直接登录"
        )
    
    # 检查用户名是否已被注册（正式用户）
    db_name = await async_user_crud.get_user_by_name(db, validated_data['name'])
    if db_name:
        raise HTTPException(
            status_code=400, 
            detail="该用户名已被使用，请选择其他用户名"
        )

    # 检查用户名是否包含客服相关关键词，防止用户注册客服账号
    customer_service_keywords = ["客服", "customer", "service", "support", "help"]
    name_lower = validated_data['name'].lower()
    if any(keyword.lower() in name_lower for keyword in customer_service_keywords):
        raise HTTPException(
            status_code=400, 
            detail="用户名不能包含客服相关关键词"
        )

    # 检查是否跳过邮件验证（开发环境）
    if Config.SKIP_EMAIL_VERIFICATION:
        print("开发环境：跳过邮件验证，直接创建用户")
        
        # 使用异步CRUD创建用户
        user_data = schemas.UserCreate(**validated_data)
        new_user = await async_user_crud.create_user(db, user_data)
        
        # 更新用户状态为已验证和激活
        from sqlalchemy import update
        await db.execute(
            update(User)
            .where(User.id == new_user.id)
            .values(
                is_verified=1,
                is_active=1,
                user_level="normal"
            )
        )
        await db.commit()
        await db.refresh(new_user)
        
        print(f"开发环境：用户 {new_user.email} 注册成功，无需邮箱验证")
        
        return {
            "message": "注册成功！（开发环境：已跳过邮箱验证）",
            "email": validated_data['email'],
            "verification_required": False,
            "user_id": new_user.id
        }
    else:
        # 生产环境：需要邮箱验证
        print("生产环境：需要邮箱验证")
        
        # 生成验证令牌
        verification_token = EmailVerificationManager.generate_verification_token(validated_data['email'])
        
        # 创建待验证用户（这里需要同步操作，因为EmailVerificationManager使用同步数据库）
        user_data = schemas.UserCreate(**validated_data)
        
        # 临时使用同步数据库操作创建待验证用户
        from app.database import SessionLocal
        sync_db = SessionLocal()
        try:
            pending_user = EmailVerificationManager.create_pending_user(sync_db, user_data, verification_token)
        finally:
            sync_db.close()
        
        # 发送验证邮件
        send_verification_email_with_token(background_tasks, validated_data['email'], verification_token)
        
        return {
            "message": "注册成功！请检查您的邮箱并点击验证链接完成注册。",
            "email": validated_data['email'],
            "verification_required": True
        }


@router.get("/verify-email/{token}")
def verify_email(
    token: str,
    db: Session = Depends(get_db),
):
    """验证用户邮箱"""
    try:
        from app.email_verification import EmailVerificationManager
        
        # 验证用户
        user = EmailVerificationManager.verify_user(db, token)
        
        if not user:
            raise HTTPException(
                status_code=400, 
                detail="验证失败。令牌无效或已过期，请重新注册。"
            )
        
        return {
            "message": "邮箱验证成功！您现在可以正常使用平台了。",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "is_verified": user.is_verified
            }
        }
    except Exception as e:
        logger.error(f"邮箱验证异常: {e}")
        raise HTTPException(
            status_code=400, 
            detail=f"验证失败：{str(e)}"
        )


@router.post("/resend-verification")
def resend_verification_email(
    email: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """重新发送验证邮件"""
    from app.email_verification import EmailVerificationManager
    
    # 检查邮箱格式
    from app.validators import StringValidator
    try:
        validated_email = StringValidator.validate_email(email)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # 重新发送验证邮件
    success = EmailVerificationManager.resend_verification_email(db, validated_email, background_tasks)
    
    if not success:
        raise HTTPException(
            status_code=400, 
            detail="未找到待验证的用户，请先注册。"
        )
    
    return {
        "message": "验证邮件已重新发送，请检查您的邮箱。"
    }


@router.post("/login")
def login(
    response: Response,
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    # 支持ID或邮箱登录
    username = form_data.username
    db_user = None
    
    # 首先尝试作为ID查找（8位数字）
    if username.isdigit() and len(username) == 8:
        db_user = crud.get_user_by_id(db, username)
    
    # 如果ID查找失败，尝试作为邮箱查找
    if not db_user:
        db_user = crud.get_user_by_email(db, username)
    
    if not db_user or not verify_password(form_data.password, db_user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    
    # 检查用户是否已验证邮箱
    if not db_user.is_verified:
        raise HTTPException(
            status_code=400, 
            detail="请先验证您的邮箱。请检查您的邮箱并点击验证链接。"
        )

    # 使用security.py中的函数创建token
    from app.security import create_access_token, create_refresh_token, set_secure_cookies
    access_token = create_access_token({"sub": db_user.id})
    refresh_token = create_refresh_token({"sub": db_user.id})
    
    # 设置HttpOnly Cookie
    set_secure_cookies(response, access_token, refresh_token)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_info": {
            "id": db_user.id,  # 数据库已经存储格式化ID
            "name": db_user.name,
            "email": db_user.email,
            "user_type": "normal_user",
        },
    }


@router.post("/customer-service/login")
def customer_service_login(
    login_data: schemas.CustomerServiceLogin, db: Session = Depends(get_db)
):
    """客服登录端点 - 支持ID或邮箱登录"""
    # 支持ID或邮箱登录
    username = login_data.cs_id  # 这里cs_id字段实际是用户名（可能是ID或邮箱）
    cs = None
    
    # 首先尝试作为ID查找（CS + 4位数字格式）
    if username.startswith('CS') and len(username) == 6 and username[2:].isdigit():
        cs = crud.get_customer_service_by_id(db, username)
        if cs and verify_password(login_data.password, cs.hashed_password):
            pass  # 验证成功
        else:
            cs = None
    
    # 如果ID查找失败，尝试作为邮箱查找
    if not cs:
        cs = crud.get_customer_service_by_email(db, username)
        if cs and verify_password(login_data.password, cs.hashed_password):
            pass  # 验证成功
        else:
            cs = None
    
    if not cs:
        raise HTTPException(status_code=400, detail="Incorrect username or password")

    # 创建客服专用的token
    access_token = create_access_token(
        {"sub": cs.id, "cs_id": cs.id, "user_type": "customer_service"}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "cs_info": {
            "id": cs.id,  # 数据库已经存储格式化ID
            "name": cs.name,
            "email": cs.email,
            "is_online": cs.is_online,
            "user_type": "customer_service",
        },
    }


@router.post("/admin/login")
def admin_login(login_data: schemas.AdminUserLogin, db: Session = Depends(get_db)):
    """后台管理员登录端点"""
    admin = crud.authenticate_admin_user(db, login_data.username, login_data.password)
    if not admin:
        raise HTTPException(status_code=400, detail="Incorrect username or password")

    # 更新最后登录时间
    crud.update_admin_last_login(db, admin.id)

    # 创建管理员专用的token
    access_token = create_access_token(
        {"sub": admin.username, "admin_id": admin.id, "user_type": "admin"}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "admin_info": {
            "id": admin.id,  # 数据库已经存储格式化ID
            "name": admin.name,
            "username": admin.username,
            "email": admin.email,
            "is_super_admin": admin.is_super_admin,
            "user_type": "admin",
        },
    }


@router.get("/user/info")
def get_user_info(
    current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    """获取当前用户信息"""
    return {
        "id": current_user.id,  # 数据库已经存储格式化ID
        "name": current_user.name,
        "email": current_user.email,
        "user_type": "normal_user",
    }


@router.get("/confirm/{token}")
def confirm_email(token: str, db: Session = Depends(get_db)):
    """邮箱验证端点（支持多种token格式）"""
    try:
        # 首先尝试旧的验证方式
        from app.email_utils import confirm_token
        from app import crud
        
        email = confirm_token(token)
        if email:
            # 使用旧方式验证
            user = crud.get_user_by_email(db, email)
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            
            user.is_verified = 1
            db.commit()
            
            return {
                "message": "Email confirmed successfully!",
                "user": {
                    "id": user.id,
                    "name": user.name,
                    "email": user.email,
                    "is_verified": user.is_verified
                }
            }
        
        # 如果旧方式失败，尝试新方式
        try:
            from app.email_verification import EmailVerificationManager
            user = EmailVerificationManager.verify_user(db, token)
            
            if not user:
                raise HTTPException(
                    status_code=400, 
                    detail="验证失败。令牌无效或已过期，请重新注册。"
                )
            
            return {
                "message": "Email confirmed successfully!",
                "user": {
                    "id": user.id,
                    "name": user.name,
                    "email": user.email,
                    "is_verified": user.is_verified
                }
            }
        except ImportError as e:
            logger.error(f"导入EmailVerificationManager失败: {e}")
            raise HTTPException(
                status_code=400, 
                detail="验证失败。令牌无效或已过期，请重新注册。"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"邮箱验证异常 (confirm): {e}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        raise HTTPException(
            status_code=400, 
            detail="验证失败。令牌无效或已过期，请重新注册。"
        )


@router.post("/forgot_password")
def forgot_password(
    email: str = Form(...),
    background_tasks: BackgroundTasks = None,
    db: Session = Depends(get_db),
):
    user = crud.get_user_by_email(db, email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    token = generate_reset_token(email)
    send_reset_email(background_tasks, email, token)
    return {"message": "Password reset email sent."}


@router.post("/reset_password/{token}")
def reset_password(
    token: str, new_password: str = Form(...), db: Session = Depends(get_db)
):
    email = confirm_reset_token(token)
    if not email:
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    user = crud.get_user_by_email(db, email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    from app.security import get_password_hash

    user.hashed_password = get_password_hash(new_password)
    db.commit()
    return {"message": "Password reset successful."}


# 同步发布任务路由已禁用，使用异步版本
# @router.post("/tasks", response_model=schemas.TaskOut)
# @rate_limit("create_task")
# def create_task(
#     task: schemas.TaskCreate,
#     current_user=Depends(get_current_user_secure_sync_csrf),
#     db: Session = Depends(get_db),
# ):
#     # 检查用户是否为客服账号
#     if False:  # 普通用户不再有客服权限
#         raise HTTPException(status_code=403, detail="客服账号不能发布任务")
#
#     try:
#         db_task = crud.create_task(db, current_user.id, task)
#         # 手动序列化Task对象，避免关系字段问题
#         return {
#             "id": db_task.id,
#             "title": db_task.title,
#             "description": db_task.description,
#             "deadline": db_task.deadline,
#             "reward": db_task.reward,
#             "location": db_task.location,
#             "task_type": db_task.task_type,
#             "poster_id": db_task.poster_id,
#             "taker_id": db_task.taker_id,
#             "status": db_task.status,
#             "task_level": db_task.task_level,
#             "created_at": db_task.created_at,
#             "is_public": db_task.is_public
#         }
#     except Exception as e:
#         print(f"Error creating task: {e}")
#         raise HTTPException(status_code=500, detail=f"创建任务失败: {str(e)}")


@router.patch("/profile/timezone")
def update_timezone(
    timezone: str = Body(...),
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
):
    """更新用户时区"""
    from app.models import User

    user = db.query(User).filter(User.id == current_user.id).first()
    if user:
        user.timezone = timezone
        db.commit()
        return {"message": "Timezone updated successfully"}
    raise HTTPException(status_code=404, detail="User not found")


# 同步任务列表路由已禁用，使用异步版本
# @router.get("/tasks")
# def list_tasks(
#     page: int = 1,
#     page_size: int = 20,
#     task_type: str = None,
#     location: str = None,
#     keyword: str = None,
#     sort_by: str = "latest",
#     db: Session = Depends(get_db),
# ):
#     skip = (page - 1) * page_size
#     tasks = crud.list_tasks(db, skip, page_size, task_type, location, keyword, sort_by)
#     total = crud.count_tasks(db, task_type, location, keyword)
#
#     return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}


@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(task_id: int, db: Session = Depends(get_db)):
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
def accept_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    print(f"[DEBUG] accept_task - 开始处理接收任务请求，任务ID: {task_id}")
    print(f"[DEBUG] accept_task - 当前用户: {current_user.id if current_user else 'None'}")
    
    # 如果current_user为None，说明认证失败
    if not current_user:
        print("[DEBUG] accept_task - 认证失败，current_user为None")
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    try:
        print(
            f"DEBUG: accept_task called for task_id={task_id}, user_id={current_user.id}"
        )

        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能接受任务")

        db_task = crud.get_task(db, task_id)
        if not db_task:
            print(f"DEBUG: Task {task_id} not found")
            raise HTTPException(status_code=404, detail="Task not found")

        print(f"DEBUG: Task {task_id} found, status={db_task.status}")

        if db_task.status != "open":
            print(f"DEBUG: Task {task_id} status is {db_task.status}, not open")
            raise HTTPException(
                status_code=400, detail="Task is not available for acceptance"
            )

        if db_task.poster_id == current_user.id:
            print(f"DEBUG: User {current_user.id} trying to accept own task")
            raise HTTPException(
                status_code=400, detail="You cannot accept your own task"
            )

        # 检查用户等级是否满足任务等级要求
        user_level = current_user.user_level
        task_level = db_task.task_level

        # 权限检查：用户等级必须大于等于任务等级
        level_hierarchy = {"normal": 1, "vip": 2, "super": 3}
        user_level_value = level_hierarchy.get(user_level, 1)
        task_level_value = level_hierarchy.get(task_level, 1)

        if user_level_value < task_level_value:
            print(
                f"DEBUG: User {current_user.id} level {user_level} insufficient for task level {task_level}"
            )
            if task_level == "vip":
                raise HTTPException(
                    status_code=403,
                    detail="此任务需要VIP用户才能接受，请升级您的账户等级",
                )
            elif task_level == "super":
                raise HTTPException(
                    status_code=403,
                    detail="此任务需要超级VIP用户才能接受，请升级您的账户等级",
                )
            else:
                raise HTTPException(
                    status_code=403, detail="您的账户等级不足以接受此任务"
                )

        # 检查任务是否已过期
        from datetime import datetime

        import pytz

        uk_tz = pytz.timezone("Europe/London")
        current_time = datetime.now(uk_tz)

        # 如果deadline是naive datetime，假设它是英国时间
        if db_task.deadline.tzinfo is None:
            deadline_uk = uk_tz.localize(db_task.deadline)
        else:
            deadline_uk = db_task.deadline.astimezone(uk_tz)

        if deadline_uk < current_time:
            print(f"DEBUG: Task {task_id} deadline has passed")
            raise HTTPException(status_code=400, detail="Task deadline has passed")

        print(f"DEBUG: Calling crud.accept_task for task {task_id}")
        updated_task = crud.accept_task(db, task_id, current_user.id)
        if not updated_task:
            print(f"DEBUG: crud.accept_task returned None for task {task_id}")
            raise HTTPException(status_code=400, detail="Failed to accept task")

        print(f"DEBUG: Task {task_id} accepted successfully")

        # 发送通知给任务发布者
        if background_tasks:
            try:
                crud.create_notification(
                    db,
                    db_task.poster_id,
                    "task_accepted",
                    "任务已被接受",
                    f"用户 {current_user.name} 接受了您的任务 '{db_task.title}'",
                    current_user.id,
                )
            except Exception as e:
                print(f"Failed to create notification: {e}")
                # 不要因为通知失败而影响任务接受

        return updated_task
    except HTTPException:
        raise
    except Exception as e:
        print(f"DEBUG: Unexpected error in accept_task: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/tasks/{task_id}/approve", response_model=schemas.TaskOut)
def approve_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者同意接受者进行任务"""
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can approve the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 更新任务状态为进行中
    db_task.status = "in_progress"
    db.commit()
    db.refresh(db_task)

    # 创建通知给任务接受者
    if background_tasks and db_task.taker_id:
        try:
            crud.create_notification(
                db,
                db_task.taker_id,
                "task_approved",
                "任务已批准",
                f"您的任务申请 '{db_task.title}' 已被发布者批准，可以开始工作了",
                current_user.id,
            )
        except Exception as e:
            print(f"Failed to create notification: {e}")

    return db_task


@router.post("/tasks/{task_id}/reject", response_model=schemas.TaskOut)
def reject_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者拒绝接受者，任务重新变为open状态"""
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以拒绝
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can reject the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 记录被拒绝的接受者ID
    rejected_taker_id = db_task.taker_id

    # 重置任务状态为open，清除接受者
    db_task.status = "open"
    db_task.taker_id = None
    db.commit()
    db.refresh(db_task)

    # 创建通知给被拒绝的接受者
    if background_tasks and rejected_taker_id:
        try:
            crud.create_notification(
                db,
                rejected_taker_id,
                "task_rejected",
                "任务申请被拒绝",
                f"您的任务申请 '{db_task.title}' 已被发布者拒绝，任务已重新开放",
                current_user.id,
            )
        except Exception as e:
            print(f"Failed to create notification: {e}")

    return db_task


@router.patch("/tasks/{task_id}/reward", response_model=schemas.TaskOut)
def update_task_reward(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务价格（仅任务发布者可见）"""
    task = crud.update_task_reward(db, task_id, current_user.id, task_update.reward)
    if not task:
        raise HTTPException(
            status_code=400,
            detail="Task not found or you don't have permission to update it",
        )
    return task


@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: dict = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（仅任务发布者可见）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    is_public = visibility_update.get("is_public")
    if is_public not in [0, 1]:
        raise HTTPException(status_code=400, detail="is_public must be 0 or 1")

    task.is_public = is_public
    db.commit()
    db.refresh(task)
    return task


@router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
def create_review(
    task_id: int,
    review: schemas.ReviewCreate = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能创建评价")

    db_review = crud.create_review(db, current_user.id, task_id, review)
    if not db_review:
        raise HTTPException(
            status_code=400,
            detail="Cannot create review. Task may not be completed, you may not be a participant, or you may have already reviewed this task.",
        )
    return db_review


@router.get("/tasks/{task_id}/reviews", response_model=list[schemas.ReviewOut])
def get_task_reviews(task_id: int, db: Session = Depends(get_db)):
    return crud.get_task_reviews(db, task_id)


@router.get("/users/{user_id}/received-reviews", response_model=list[schemas.ReviewOut])
def get_user_received_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return crud.get_user_received_reviews(db, user_id)


@router.get(
    "/users/{user_id}/reviews", response_model=list[schemas.ReviewWithReviewerInfo]
)
def get_user_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的评价（用于个人主页显示）"""
    return crud.get_user_reviews_with_reviewer_info(db, user_id)


@router.post("/tasks/{task_id}/complete", response_model=schemas.TaskOut)
def complete_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能完成任务")

    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    if db_task.status != "in_progress":
        raise HTTPException(status_code=400, detail="Task is not in progress")

    if db_task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the task taker can complete the task"
        )

    # 更新任务状态为等待确认
    db_task.status = "pending_confirmation"
    db_task.completed_at = crud.get_uk_time()
    db.commit()
    db.refresh(db_task)

    # 发送任务完成通知和邮件给发布者
    if background_tasks:
        try:
            from app.task_notifications import send_task_completion_notification
            
            # 获取发布者信息
            poster = crud.get_user_by_id(db, db_task.poster_id)
            if poster:
                send_task_completion_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=db_task,
                    taker=current_user
                )
        except Exception as e:
            print(f"Failed to send task completion notification: {e}")

    # 检查任务接受者是否满足VIP晋升条件
    try:
        crud.check_and_upgrade_vip_to_super(db, current_user.id)
    except Exception as e:
        print(f"Failed to check VIP upgrade: {e}")

    return db_task


@router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
def confirm_task_completion(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者确认任务完成"""
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    if task.status != "pending_confirmation":
        raise HTTPException(status_code=400, detail="Task is not pending confirmation")

    # 将任务状态改为已完成
    task.status = "completed"
    db.commit()
    crud.add_task_history(db, task_id, current_user.id, "confirmed_completion")
    db.refresh(task)

    # 发送任务确认完成通知和邮件给接收者
    if task.taker_id and background_tasks:
        try:
            from app.task_notifications import send_task_confirmation_notification
            
            # 获取接收者信息
            taker = crud.get_user_by_id(db, task.taker_id)
            if taker:
                send_task_confirmation_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    taker=taker
                )
        except Exception as e:
            print(f"Failed to send task confirmation notification: {e}")

    # 自动更新相关用户的统计信息
    crud.update_user_statistics(db, task.poster_id)
    if task.taker_id:
        crud.update_user_statistics(db, task.taker_id)

    return task


@router.post("/tasks/{task_id}/cancel")
def cancel_task(
    task_id: int,
    cancel_data: schemas.TaskCancelRequest = Body(default=schemas.TaskCancelRequest()),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """取消任务 - 如果任务已被接受，需要客服审核"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者或接受者可以取消任务
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster or taker can cancel the task"
        )

    # 如果任务状态是 'open'，直接取消
    if task.status == "open":
        cancelled_task = crud.cancel_task(db, task_id, current_user.id)
        if not cancelled_task:
            raise HTTPException(status_code=400, detail="Task cannot be cancelled")
        return cancelled_task

    # 如果任务已被接受或正在进行中，创建取消请求等待客服审核
    elif task.status in ["taken", "in_progress"]:
        # 检查是否已有待审核的取消请求
        existing_request = crud.get_task_cancel_requests(db, "pending")
        existing_request = next(
            (req for req in existing_request if req.task_id == task_id), None
        )

        if existing_request:
            raise HTTPException(
                status_code=400,
                detail="A cancel request is already pending for this task",
            )

        # 创建取消请求
        cancel_request = crud.create_task_cancel_request(
            db, task_id, current_user.id, cancel_data.reason
        )

        # 创建通知给客服
        crud.create_notification(
            db,
            1,  # 假设管理员ID为1，实际应该通知所有管理员
            "cancel_request",
            "任务取消请求",
            f'任务 "{task.title}" 的取消请求等待审核，请求原因：{cancel_data.reason or "无"}',
            task_id,
        )

        return {
            "message": "Cancel request submitted for admin review",
            "request_id": cancel_request.id,
        }

    else:
        raise HTTPException(
            status_code=400, detail="Task cannot be cancelled in current status"
        )


@router.delete("/tasks/{task_id}/delete")
def delete_cancelled_task(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """删除已取消的任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 只有任务发布者可以删除任务
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can delete the task"
        )

    # 只有已取消的任务可以删除
    if task.status != "cancelled":
        raise HTTPException(
            status_code=400, detail="Only cancelled tasks can be deleted"
        )

    # 使用新的安全删除函数
    result = crud.delete_user_task(db, task_id, current_user.id)
    if not result:
        raise HTTPException(status_code=500, detail="Failed to delete task")

    return result


@router.get("/tasks/{task_id}/history")
def get_task_history(task_id: int, db: Session = Depends(get_db)):
    history = crud.get_task_history(db, task_id)
    return [
        {
            "id": h.id,
            "user_id": h.user_id,
            "action": h.action,
            "timestamp": h.timestamp,
            "remark": h.remark,
        }
        for h in history
    ]


@router.get("/profile/me", response_model=schemas.UserOut)
def get_my_profile(
    request: Request, current_user=Depends(get_current_customer_service_or_user)
):
    print("Authorization header:", request.headers.get("authorization"))

    # 安全地创建用户对象，避免SQLAlchemy内部属性
    try:
        # 检查是否为客服
        if hasattr(current_user, 'email') and hasattr(current_user, 'id') and current_user.id.startswith('CS'):
            formatted_user = {
                "id": current_user.id,
                "name": getattr(current_user, 'name', ''),
                "email": getattr(current_user, 'email', ''),
                "user_type": "customer_service"
            }
        else:
            # 普通用户
            formatted_user = {
                "id": current_user.id,
                "name": getattr(current_user, 'name', ''),
                "email": getattr(current_user, 'email', ''),
                "phone": getattr(current_user, 'phone', ''),
                "is_verified": getattr(current_user, 'is_verified', False),
                "user_level": getattr(current_user, 'user_level', 1),
                "avatar": getattr(current_user, 'avatar', ''),
                "created_at": getattr(current_user, 'created_at', None),
                "user_type": "normal_user"
            }
        
        return formatted_user
    except Exception as e:
        print(f"Error in get_my_profile: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/my-tasks", response_model=list[schemas.TaskOut])
def get_my_tasks(
    current_user=Depends(check_user_status), 
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0)
):
    """获取当前用户的任务（发布的和接受的）"""
    tasks = crud.get_user_tasks(db, current_user.id, limit=limit, offset=offset)
    return tasks


@router.get("/profile/{user_id}")
def user_profile(
    user_id: str, current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    # 尝试直接查找
    user = crud.get_user_by_id(db, user_id)

    # 如果没找到且是7位数字，尝试转换为8位格式
    if not user and user_id.isdigit() and len(user_id) <= 7:
        # 补齐前导零到8位
        formatted_id = user_id.zfill(8)
        user = crud.get_user_by_id(db, formatted_id)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 计算注册天数
    import datetime

    days_since_joined = (datetime.datetime.utcnow() - user.created_at).days

    # 获取用户的任务统计（限制数量以提高性能）
    tasks = crud.get_user_tasks(db, user_id, limit=100)  # 限制为最近100个任务
    # 只显示公开的任务（is_public=1）或者用户自己查看自己的任务时显示所有任务
    if current_user.id == user_id:
        # 用户查看自己的任务，显示所有任务
        posted_tasks = [t for t in tasks if t.poster_id == user_id]
        taken_tasks = [t for t in tasks if t.taker_id == user_id]
    else:
        # 其他用户查看，只显示已完成且公开的任务
        posted_tasks = [
            t
            for t in tasks
            if t.poster_id == user_id and t.is_public == 1 and t.status == "completed"
        ]
        taken_tasks = [
            t
            for t in tasks
            if t.taker_id == user_id and t.is_public == 1 and t.status == "completed"
        ]

    # 计算用户接受的任务中完成的数量
    completed_taken_tasks = [t for t in taken_tasks if t.status == "completed"]

    # 计算总任务数 = 发布任务数 + 接受任务数
    total_tasks = len(posted_tasks) + len(taken_tasks)

    # 计算完成率 = 完成的任务数 / 接受过的任务数（包括中途被取消的任务）
    completion_rate = 0.0
    if len(taken_tasks) > 0:
        completion_rate = (len(completed_taken_tasks) / len(taken_tasks)) * 100

    # 获取用户收到的评价
    reviews = crud.get_reviews_received_by_user(
        db, user_id, limit=10
    )  # 获取最近10条评价

    # 实时计算平均评分
    from sqlalchemy import func

    from app.models import Review, User

    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    return {
        "user": {
            "id": user.id,  # 数据库已经存储格式化ID
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "created_at": user.created_at,
            "is_verified": user.is_verified,
            "user_level": user.user_level,
            "avatar": user.avatar,
            "avg_rating": avg_rating,
            "days_since_joined": days_since_joined,
            "task_count": user.task_count,
        },
        "stats": {
            "total_tasks": total_tasks,
            "posted_tasks": len(posted_tasks),
            "taken_tasks": len(taken_tasks),
            "completed_tasks": len(completed_taken_tasks),
            "completion_rate": round(completion_rate, 1),
            "total_reviews": len(reviews),
        },
        "recent_tasks": [
            {
                "id": t.id,
                "title": t.title,
                "status": t.status,
                "created_at": t.created_at,
                "reward": t.reward,
                "task_type": t.task_type,
            }
            for t in (posted_tasks + taken_tasks)[
                :5
            ]  # 最近5个任务（基于过滤后的任务列表）
        ],
        "reviews": [
            {
                "id": r.id,
                "rating": r.rating,
                "comment": r.comment,
                "created_at": r.created_at,
                "task_id": r.task_id,
                "is_anonymous": bool(r.is_anonymous),
                "reviewer_name": "匿名用户" if r.is_anonymous else user.name,
            }
            for r, user in reviews
        ],
    }


class AvatarUpdate(BaseModel):
    avatar: str


@router.patch("/profile/avatar")
def update_avatar(
    data: AvatarUpdate,
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
):
    # 从数据库重新获取用户对象，确保它在当前会话中
    user = crud.get_user_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 更新头像
    user.avatar = data.avatar
    db.commit()
    db.refresh(user)
    return {"avatar": user.avatar}


@router.post("/admin/user/{user_id}/set_level")
def admin_set_user_level(
    user_id: str,
    level: str = Body(...),
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    user.user_level = level
    db.commit()
    return {"message": f"User {user_id} level set to {level}."}


@router.post("/admin/user/{user_id}/set_status")
def admin_set_user_status(
    user_id: str,
    is_banned: int = Body(None),
    is_suspended: int = Body(None),
    suspend_until: str = Body(None),
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if is_banned is not None:
        user.is_banned = is_banned
    if is_suspended is not None:
        user.is_suspended = is_suspended
    if suspend_until:
        import datetime

        user.suspend_until = datetime.datetime.fromisoformat(suspend_until)
    db.commit()
    return {"message": f"User {user_id} status updated."}


@router.post("/admin/task/{task_id}/set_level")
def admin_set_task_level(
    task_id: int,
    level: str = Body(...),
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found.")
    task.task_level = level
    db.commit()
    return {"message": f"Task {task_id} level set to {level}."}


@router.post("/messages/send", response_model=schemas.MessageOut)
@rate_limit("send_message")
def send_message_api(
    msg: schemas.MessageCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查接收者是否存在
    receiver = crud.get_user_by_id(db, msg.receiver_id)
    if not receiver:
        raise HTTPException(status_code=404, detail="接收者不存在")

    # 保存消息
    message = crud.send_message(db, current_user.id, msg.receiver_id, msg.content)

    # 创建通知
    try:
        # 检查发送者是否为客服账号
        is_customer_service = False  # 普通用户不再有客服权限

        if is_customer_service:
            # 从客服数据库获取客服名字
            from app.models import CustomerService

            service = (
                db.query(CustomerService)
                .filter(CustomerService.id == current_user.id)
                .first()
            )
            sender_name = service.name if service else f"客服{current_user.id}"
            notification_content = f"客服 {sender_name} 给您发送了一条消息"
        else:
            # 从用户数据库获取普通用户名字
            sender_name = current_user.name or f"用户{current_user.id}"
            notification_content = f"用户 {sender_name} 给您发送了一条消息"

        crud.create_notification(
            db,
            msg.receiver_id,
            "message",
            "新消息",
            notification_content,
            current_user.id,
        )
    except Exception as e:
        print(f"Failed to create notification: {e}")

    return message


@router.get("/messages/history/{user_id}", response_model=list[schemas.MessageOut])
def get_chat_history_api(
    user_id: str,
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
    limit: int = 20,  # 增加默认加载数量
    offset: int = 0,
    session_id: int = None,
):
    # 如果提供了session_id，直接使用它
    if session_id is not None:
        return crud.get_chat_history(
            db, current_user.id, user_id, limit, offset, session_id=session_id
        )

    # 普通用户之间的消息
    return crud.get_chat_history(db, current_user.id, user_id, limit, offset)


@router.get("/messages/unread", response_model=list[schemas.MessageOut])
def get_unread_messages_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.get_unread_messages(db, current_user.id)


@router.get("/messages/unread/count")
def get_unread_count_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return {"unread_count": len(crud.get_unread_messages(db, current_user.id))}


@router.post("/messages/{msg_id}/read", response_model=schemas.MessageOut)
def mark_message_read_api(
    msg_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.mark_message_read(db, msg_id, current_user.id)


@router.get("/admin/messages", response_model=list[schemas.MessageOut])
def get_admin_messages_api(
    current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    return crud.get_admin_messages(db, current_user.id)


# 通知相关API
@router.get("/notifications", response_model=list[schemas.NotificationOut])
def get_notifications_api(
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
    limit: int = 20,
):
    return crud.get_user_notifications(db, current_user.id, limit)


@router.get("/notifications/unread", response_model=list[schemas.NotificationOut])
def get_unread_notifications_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.get_unread_notifications(db, current_user.id)


@router.get("/notifications/with-recent-read", response_model=list[schemas.NotificationOut])
def get_notifications_with_recent_read_api(
    current_user=Depends(check_user_status), 
    db: Session = Depends(get_db),
    recent_read_limit: int = 10
):
    """获取所有未读通知和最近N条已读通知"""
    return crud.get_notifications_with_recent_read(db, current_user.id, recent_read_limit)


@router.get("/notifications/unread/count")
def get_unread_notification_count_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return {"unread_count": crud.get_unread_notification_count(db, current_user.id)}


@router.post(
    "/notifications/{notification_id}/read", response_model=schemas.NotificationOut
)
def mark_notification_read_api(
    notification_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    return crud.mark_notification_read(db, notification_id, current_user.id)


@router.post("/notifications/read-all")
def mark_all_notifications_read_api(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    crud.mark_all_notifications_read(db, current_user.id)
    return {"message": "All notifications marked as read"}


@router.post("/notifications/send-announcement")
def send_announcement_api(
    announcement: dict = Body(...),
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """发送平台公告给所有用户"""
    from app.models import User

    # 获取所有用户
    users = db.query(User).all()

    # 为每个用户创建公告通知
    for user in users:
        crud.create_notification(
            db,
            user.id,
            "announcement",
            announcement.get("title", "平台公告"),
            announcement.get("content", ""),
            None,
        )

    return {"message": f"Announcement sent to {len(users)} users"}


@router.post("/tasks/{task_id}/pay")
def create_payment(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if task.is_paid:
        return {"message": "Task already paid."}
    # 创建Stripe支付会话
    session = stripe.checkout.Session.create(
        payment_method_types=["card"],
        line_items=[
            {
                "price_data": {
                    "currency": "gbp",
                    "product_data": {"name": task.title},
                    "unit_amount": int(task.reward * 100),
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        success_url=f"http://localhost:8000/api/users/tasks/{task_id}/pay/success",
        cancel_url=f"http://localhost:8000/api/users/tasks/{task_id}/pay/cancel",
        metadata={"task_id": task_id},
    )
    return {"checkout_url": session.url}


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET", "whsec_...yourkey...")
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except Exception as e:
        return {"error": str(e)}
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        task_id = int(session["metadata"]["task_id"])
        task = crud.get_task(db, task_id)
        if task:
            task.is_paid = 1
            task.escrow_amount = task.reward
            db.commit()
    return {"status": "success"}


@router.post("/tasks/{task_id}/confirm_complete")
def confirm_task_complete(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if not task.is_paid or task.status != "completed" or task.is_confirmed:
        raise HTTPException(
            status_code=400, detail="Task not eligible for confirmation."
        )
    task.is_confirmed = 1
    task.paid_to_user_id = task.taker_id
    task.escrow_amount = 0.0
    db.commit()
    return {"message": "Payment released to taker."}


# 删除重复的admin/users端点，使用后面的get_users_for_admin


@router.get("/admin/tasks")
def admin_get_tasks(
    skip: int = 0,
    limit: int = 50,
    status: str = None,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员获取任务列表（支持分页和筛选）"""
    from sqlalchemy import or_

    from app.models import Task

    # 构建查询
    query = db.query(Task)

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(Task.status == status)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location)

    # 添加关键词搜索
    if keyword and keyword.strip():
        keyword = keyword.strip()
        query = query.filter(
            or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%"),
                Task.task_type.ilike(f"%{keyword}%"),
                Task.location.ilike(f"%{keyword}%"),
            )
        )

    # 获取总数
    total = query.count()

    # 执行查询并排序
    tasks = query.order_by(Task.created_at.desc()).offset(skip).limit(limit).all()

    return {"tasks": tasks, "total": total, "skip": skip, "limit": limit}


@router.get("/admin/tasks/{task_id}")
def admin_get_task_detail(
    task_id: int, current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    """管理员获取任务详情"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 获取任务历史
    history = crud.get_task_history(db, task_id)

    return {"task": task, "history": history}


@router.put("/admin/tasks/{task_id}")
def admin_update_task(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员更新任务信息"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 更新任务
    updated_task = crud.update_task_by_admin(
        db, task_id, task_update.dict(exclude_unset=True)
    )

    # 记录操作历史
    crud.add_task_history(
        db, task_id, current_user.id, "admin_update", f"管理员更新了任务信息"
    )

    return {"message": "任务更新成功", "task": updated_task}


@router.delete("/admin/tasks/{task_id}")
def admin_delete_task(
    task_id: int, current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    """管理员删除任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 记录删除历史
    crud.add_task_history(
        db, task_id, current_user.id, "admin_delete", f"管理员删除了任务"
    )

    # 删除任务
    success = crud.delete_task_by_admin(db, task_id)

    if success:
        return {"message": f"任务 {task_id} 已删除"}
    else:
        raise HTTPException(status_code=500, detail="删除任务失败")


@router.post("/admin/tasks/batch-update")
def admin_batch_update_tasks(
    task_ids: list[int],
    task_update: schemas.TaskUpdate,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员批量更新任务"""
    updated_tasks = []
    failed_tasks = []

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                updated_task = crud.update_task_by_admin(
                    db, task_id, task_update.dict(exclude_unset=True)
                )
                crud.add_task_history(
                    db,
                    task_id,
                    current_user.id,
                    "admin_batch_update",
                    f"管理员批量更新了任务信息",
                )
                updated_tasks.append(updated_task)
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    return {
        "message": f"批量更新完成，成功: {len(updated_tasks)}, 失败: {len(failed_tasks)}",
        "updated_tasks": updated_tasks,
        "failed_tasks": failed_tasks,
    }


@router.post("/admin/tasks/batch-delete")
def admin_batch_delete_tasks(
    task_ids: list[int],
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员批量删除任务"""
    deleted_tasks = []
    failed_tasks = []

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                crud.add_task_history(
                    db,
                    task_id,
                    current_user.id,
                    "admin_batch_delete",
                    f"管理员批量删除了任务",
                )
                success = crud.delete_task_by_admin(db, task_id)
                if success:
                    deleted_tasks.append(task_id)
                else:
                    failed_tasks.append({"task_id": task_id, "error": "删除失败"})
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    return {
        "message": f"批量删除完成，成功: {len(deleted_tasks)}, 失败: {len(failed_tasks)}",
        "deleted_tasks": deleted_tasks,
        "failed_tasks": failed_tasks,
    }


# 管理员处理客服请求相关API
@router.get("/admin/customer-service-requests")
def admin_get_customer_service_requests(
    status: str = None,
    priority: str = None,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员获取客服请求列表"""
    from app.models import AdminRequest, CustomerService

    query = db.query(AdminRequest)

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(AdminRequest.status == status)

    # 添加优先级筛选
    if priority and priority.strip():
        query = query.filter(AdminRequest.priority == priority)

    requests = query.order_by(AdminRequest.created_at.desc()).all()

    # 为每个请求添加客服信息
    result = []
    for request in requests:
        customer_service = (
            db.query(CustomerService)
            .filter(CustomerService.id == request.requester_id)
            .first()
        )
        request_dict = {
            "id": request.id,
            "requester_id": request.requester_id,
            "requester_name": customer_service.name if customer_service else "未知客服",
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": request.created_at,
            "updated_at": request.updated_at,
        }
        result.append(request_dict)

    return {"requests": result, "total": len(result)}


@router.get("/admin/customer-service-requests/{request_id}")
def admin_get_customer_service_request_detail(
    request_id: int, current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    """管理员获取客服请求详情"""
    from app.models import AdminRequest, CustomerService

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    customer_service = (
        db.query(CustomerService)
        .filter(CustomerService.id == request.requester_id)
        .first()
    )

    return {
        "request": request,
        "customer_service": {
            "id": customer_service.id if customer_service else None,
            "name": customer_service.name if customer_service else "未知客服",
        },
    }


@router.put("/admin/customer-service-requests/{request_id}")
def admin_update_customer_service_request(
    request_id: int,
    request_update: dict,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员更新客服请求状态和回复"""
    from datetime import datetime

    from app.models import AdminRequest

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    # 更新请求信息
    if "status" in request_update:
        request.status = request_update["status"]
    if "admin_response" in request_update:
        request.admin_response = request_update["admin_response"]
    if "priority" in request_update:
        request.priority = request_update["priority"]

    request.admin_id = current_user.id
    request.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(request)

    return {"message": "Request updated successfully", "request": request}


@router.get("/admin/customer-service-chat")
def admin_get_customer_service_chat_messages(
    current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    """管理员获取与客服的聊天记录"""
    from app.models import AdminChatMessage, CustomerService

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )

    # 为每个消息添加发送者信息
    result = []
    for message in messages:
        sender_name = None
        if message.sender_type == "customer_service" and message.sender_id:
            customer_service = (
                db.query(CustomerService)
                .filter(CustomerService.id == message.sender_id)
                .first()
            )
            sender_name = customer_service.name if customer_service else "未知客服"
        elif message.sender_type == "admin" and message.sender_id:
            # 这里可以添加管理员信息查询
            sender_name = "管理员"

        message_dict = {
            "id": message.id,
            "sender_id": message.sender_id,
            "sender_type": message.sender_type,
            "sender_name": sender_name,
            "content": message.content,
            "created_at": message.created_at,
        }
        result.append(message_dict)

    return {"messages": result, "total": len(result)}


@router.post("/admin/customer-service-chat")
def admin_send_customer_service_chat_message(
    message_data: dict,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员发送消息给客服"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id, sender_type="admin", content=message_data["content"]
    )

    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)

    return {"message": "Message sent successfully", "chat_message": chat_message}


@router.get("/admin/payments")
def admin_get_payments(
    current_user=Depends(admin_required), db: Session = Depends(get_db)
):
    from app.models import Task

    return db.query(Task).filter(Task.is_paid == 1).all()


@router.get("/contacts")
def get_contacts(current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)):
    try:
        from app.models import Message, User
        
        print(f"DEBUG: 开始获取联系人，用户ID: {current_user.id}")

        # 简化版本：直接获取所有与当前用户有消息往来的用户
        # 获取发送的消息
        sent_contacts = db.query(Message.receiver_id).filter(
            Message.sender_id == current_user.id
        ).distinct().all()
        
        # 获取接收的消息
        received_contacts = db.query(Message.sender_id).filter(
            Message.receiver_id == current_user.id
        ).distinct().all()

        # 合并并去重
        contact_ids = set()
        for result in sent_contacts:
            if result[0]:
                contact_ids.add(result[0])
        for result in received_contacts:
            if result[0]:
                contact_ids.add(result[0])

        # 排除自己
        contact_ids.discard(current_user.id)
        
        print(f"DEBUG: 找到 {len(contact_ids)} 个联系人ID: {list(contact_ids)}")

        if not contact_ids:
            print("DEBUG: 没有找到联系人，返回空列表")
            return []

        # 使用一次查询获取所有用户信息和最新消息时间
        from sqlalchemy import func, case
        
        # 构建联系人ID列表用于IN查询
        contact_id_list = list(contact_ids)
        
        # 一次性查询所有用户信息
        users_query = db.query(User).filter(User.id.in_(contact_id_list)).all()
        users_dict = {user.id: user for user in users_query}
        
        # 一次性查询所有最新消息时间
        latest_messages = db.query(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            ).label('contact_id'),
            func.max(Message.created_at).label('last_message_time')
        ).filter(
            ((Message.sender_id == current_user.id) & (Message.receiver_id.in_(contact_id_list))) |
            ((Message.receiver_id == current_user.id) & (Message.sender_id.in_(contact_id_list)))
        ).group_by(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            )
        ).all()
        
        latest_messages_dict = {msg.contact_id: msg.last_message_time for msg in latest_messages}
        
        # 构建联系人信息
        contacts_with_last_message = []
        for contact_id in contact_id_list:
            user = users_dict.get(contact_id)
            if user:
                contact_info = {
                    "id": user.id,
                    "name": getattr(user, 'name', None) or f"用户{user.id}",
                    "avatar": getattr(user, 'avatar', None) or "/avatar1.png",
                    "email": getattr(user, 'email', None),
                    "user_level": 1,  # 默认等级
                    "task_count": 0,
                    "avg_rating": 0.0,
                    "last_message_time": latest_messages_dict.get(contact_id),
                    "is_verified": False
                }
                contacts_with_last_message.append(contact_info)
                print(f"DEBUG: 添加联系人: {contact_info['name']} (ID: {contact_info['id']})")
        
        # 按最新消息时间排序
        contacts_with_last_message.sort(
            key=lambda x: x["last_message_time"] or "1970-01-01T00:00:00", 
            reverse=True
        )

        print(f"DEBUG: 成功获取 {len(contacts_with_last_message)} 个联系人")
        return contacts_with_last_message
        
    except Exception as e:
        print(f"DEBUG: contacts API发生错误: {e}")
        import traceback
        traceback.print_exc()
        return []


@router.get("/users/shared-tasks/{other_user_id}")
def get_shared_tasks(
    other_user_id: str,
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
):
    """获取当前用户与指定用户之间的共同任务"""
    from app.models import Task

    # 查找当前用户和对方用户都参与的任务
    # 任务状态为 'taken' 或 'pending_confirmation' 或 'completed'
    shared_tasks = (
        db.query(Task)
        .filter(
            Task.status.in_(["taken", "pending_confirmation", "completed"]),
            ((Task.poster_id == current_user.id) & (Task.taker_id == other_user_id))
            | ((Task.poster_id == other_user_id) & (Task.taker_id == current_user.id)),
        )
        .order_by(Task.created_at.desc())
        .all()
    )

    return [
        {
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "created_at": task.created_at,
            "reward": task.reward,
            "task_type": task.task_type,
            "is_poster": task.poster_id == current_user.id,
        }
        for task in shared_tasks
    ]


@router.get("/admin/cancel-requests", response_model=list[schemas.TaskCancelRequestOut])
def admin_get_cancel_requests(
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
    status: str = None,
):
    """管理员获取任务取消请求列表"""
    requests = crud.get_task_cancel_requests(db, status)
    return requests


@router.post("/admin/cancel-requests/{request_id}/review")
def admin_review_cancel_request(
    request_id: int,
    review: schemas.TaskCancelRequestReview,
    current_user=Depends(admin_required),
    db: Session = Depends(get_db),
):
    """管理员审核任务取消请求"""
    cancel_request = crud.get_task_cancel_request_by_id(db, request_id)
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Request has already been reviewed")

    # 更新请求状态
    updated_request = crud.update_task_cancel_request(
        db, request_id, review.status, current_user.id, review.admin_comment
    )

    # 如果审核通过，实际取消任务
    if review.status == "approved":
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            # 实际取消任务
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )

            # 通知另一方（发布者或接受者）
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == task.taker_id
                else task.taker_id
            )
            if other_user_id:
                crud.create_notification(
                    db,
                    other_user_id,
                    "task_cancelled",
                    "任务已取消",
                    f'任务 "{task.title}" 已被取消',
                    task.id,
                )

    elif review.status == "rejected":
        # 通知请求者
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_rejected",
                "取消请求被拒绝",
                f'您的任务 "{task.title}" 取消请求被拒绝，原因：{review.admin_comment or "无"}',
                task.id,
            )

    return {"message": f"Cancel request {review.status}", "request": updated_request}


@router.post("/assign_customer_service")
def assign_customer_service(
    current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    try:
        # 随机分配一个在线客服
        services = (
            db.query(CustomerService).filter(CustomerService.is_online == 1).all()
        )

        print(f"找到 {len(services)} 个在线客服")

        import random

        if not services:
            # 没有可用客服时，返回错误信息
            return {
                "error": "no_available_service",
                "message": "暂无在线客服",
                "system_message": {
                    "content": "目前没有可用的客服，请您稍后再试。客服时间为每日8:00-18:00，如有紧急情况请发送邮件至客服邮箱。"
                },
            }

        service = random.choice(services)
        print(f"选择客服: {service.id} - {service.name}")

        # 创建或获取客服对话
        chat_data = crud.create_customer_service_chat(db, current_user.id, service.id)
        print(f"创建/获取客服对话成功: {chat_data['chat_id']}")

        # 向客服发送用户连接通知
        try:
            import asyncio
            import json

            from app.main import active_connections

            if service.id in active_connections:
                notification_message = {
                    "type": "user_connected",
                    "user_info": {
                        "id": current_user.id,
                        "name": current_user.name or f"用户{current_user.id}",
                    },
                    "chat_id": chat_data["chat_id"],
                    "timestamp": datetime.utcnow().isoformat(),
                }
                # 使用asyncio.create_task来异步发送通知
                asyncio.create_task(
                    active_connections[service.id].send_text(
                        json.dumps(notification_message)
                    )
                )
                print(f"已向客服 {service.id} 发送用户连接通知")
        except Exception as e:
            print(f"发送客服通知失败: {e}")

        return {
            "service": {
                "id": service.id,
                "name": service.name,
                "avatar": "/service.png",
                "avg_rating": service.avg_rating,
                "total_ratings": service.total_ratings,
            },
            "chat": {
                "chat_id": chat_data["chat_id"],
                "user_id": chat_data["user_id"],
                "service_id": chat_data["service_id"],
                "is_ended": chat_data["is_ended"],
                "created_at": chat_data["created_at"],
                "total_messages": chat_data["total_messages"],
            },
        }
    except Exception as e:
        print(f"客服会话分配错误: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"客服会话分配失败: {str(e)}")


# 客服在线状态管理
@router.post("/customer-service/online")
def set_customer_service_online(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """设置客服为在线状态"""
    current_user.is_online = 1
    db.commit()
    return {"message": "客服已设置为在线状态"}


@router.post("/customer-service/offline")
def set_customer_service_offline(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """设置客服为离线状态"""
    current_user.is_online = 0
    db.commit()
    return {"message": "客服已设置为离线状态"}


@router.post("/logout")
def logout(response: Response):
    """用户登出端点"""
    # 清除HttpOnly Cookie
    from app.security import clear_secure_cookies
    clear_secure_cookies(response)
    return {"message": "登出成功"}

@router.post("/customer-service/logout")
def customer_service_logout(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """客服登出时自动设置为离线状态"""
    current_user.is_online = 0
    db.commit()
    return {"message": "已登出并设置为离线状态"}


@router.get("/customer-service/status")
def get_customer_service_status(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """获取客服在线状态和名字"""
    # 使用新的客服对话系统获取评分数据
    from sqlalchemy import func

    from app.models import CustomerServiceChat

    ratings_result = (
        db.query(
            func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
            func.count(CustomerServiceChat.user_rating).label("total_ratings"),
        )
        .filter(
            CustomerServiceChat.service_id == current_user.id,
            CustomerServiceChat.user_rating.isnot(None),
        )
        .first()
    )

    # 获取实时评分数据
    real_time_avg_rating = (
        float(ratings_result.avg_rating)
        if ratings_result and ratings_result.avg_rating is not None
        else 0.0
    )
    real_time_total_ratings = (
        int(ratings_result.total_ratings)
        if ratings_result and ratings_result.total_ratings is not None
        else 0
    )

    # 更新数据库中的评分数据
    current_user.avg_rating = real_time_avg_rating
    current_user.total_ratings = real_time_total_ratings
    db.commit()

    return {
        "is_online": current_user.is_online == 1,
        "service": {
            "id": current_user.id,  # 数据库已经存储格式化ID
            "name": current_user.name,
            "avg_rating": real_time_avg_rating,
            "total_ratings": real_time_total_ratings,
        },
    }


@router.get("/customer-service/check-availability")
def check_customer_service_availability(db: Session = Depends(get_db)):
    """检查是否有在线客服可用"""
    from app.models import CustomerService

    # 查询在线客服数量
    online_services = (
        db.query(CustomerService).filter(CustomerService.is_online == 1).count()
    )

    return {
        "available": online_services > 0,
        "online_count": online_services,
        "message": (
            f"当前有 {online_services} 个客服在线"
            if online_services > 0
            else "当前无客服在线"
        ),
    }


# 客服管理相关接口
@router.get("/customer-service/chats")
def get_customer_service_chats(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """获取分配给当前客服的用户对话列表"""
    chats = crud.get_service_customer_service_chats(db, current_user.id)

    # 获取用户信息和未读消息数量
    user_chats = []
    for chat in chats:
        user = db.query(User).filter(User.id == chat["user_id"]).first()
        if user:
            # 计算未读消息数量
            unread_count = crud.get_unread_customer_service_messages_count(
                db, chat["chat_id"], current_user.id
            )

            user_chats.append(
                {
                    "chat_id": chat["chat_id"],
                    "user_id": user.id,
                    "user_name": user.name,
                    "user_avatar": user.avatar or "/avatar1.png",
                    "created_at": chat["created_at"],
                    "last_message_at": chat["last_message_at"],
                    "is_ended": chat["is_ended"],
                    "total_messages": chat["total_messages"],
                    "unread_count": unread_count,
                    "user_rating": chat["user_rating"],
                    "user_comment": chat["user_comment"],
                }
            )

    return user_chats


@router.get("/customer-service/messages/{chat_id}")
def get_customer_service_messages(
    chat_id: str,
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """获取客服对话消息（仅限分配给该客服的对话）"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/customer-service/mark-messages-read/{chat_id}")
def mark_customer_service_messages_read(
    chat_id: str,
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """标记客服对话消息为已读"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 标记消息为已读
    marked_count = crud.mark_customer_service_messages_read(
        db, chat_id, current_user.id
    )

    return {"message": "Messages marked as read", "marked_count": marked_count}


@router.post("/customer-service/send-message/{chat_id}")
def send_customer_service_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """客服发送消息给用户"""
    # 验证chat_id是否属于当前客服且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db,
        chat_id,
        current_user.id,
        "customer_service",
        message_data.get("content", ""),
    )

    # 创建通知给用户（客服ID不在users表中，所以不传递related_id）
    try:
        crud.create_notification(
            db,
            chat["user_id"],
            "message",
            "新消息",
            "客服给您发来一条消息",
            None,  # 不传递客服ID作为related_id，因为客服ID不在users表中
        )
    except Exception as e:
        # 通知创建失败不应该影响消息发送
        print(f"Failed to create notification: {e}")
        pass

    return message


# 结束对话和评分相关接口
@router.post("/customer-service/end-chat/{chat_id}")
def end_customer_service_chat(
    chat_id: str, current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    """结束客服对话"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户或客服可以结束对话
    if chat["user_id"] != current_user.id and chat["service_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to end this chat")

    # 检查对话状态
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat already ended")

    # 结束对话
    success = crud.end_customer_service_chat(db, chat_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to end chat")

    return {"message": "Chat ended successfully"}


@router.post("/customer-service/rate/{chat_id}")
def rate_customer_service(
    chat_id: str,
    rating_data: schemas.CustomerServiceRating,
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
):
    """用户对客服评分"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户可以评分
    if chat["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to rate this chat")

    # 检查对话状态
    if chat["is_ended"] != 1:
        raise HTTPException(status_code=400, detail="Can only rate ended chats")

    # 检查是否已经评分
    if chat["user_rating"] is not None:
        raise HTTPException(status_code=400, detail="Chat already rated")

    # 保存评分
    success = crud.rate_customer_service_chat(
        db, chat_id, rating_data.rating, rating_data.comment
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to save rating")

    # 更新客服的平均评分
    service = (
        db.query(CustomerService)
        .filter(CustomerService.id == chat["service_id"])
        .first()
    )
    if service:
        # 计算该客服的所有评分
        from sqlalchemy import func

        from app.models import CustomerServiceChat

        ratings_result = (
            db.query(
                func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
                func.count(CustomerServiceChat.user_rating).label("total_ratings"),
            )
            .filter(
                CustomerServiceChat.service_id == chat["service_id"],
                CustomerServiceChat.user_rating.isnot(None),
            )
            .first()
        )

        if ratings_result and ratings_result.avg_rating is not None:
            # 更新客服的平均评分和总评分数量
            service.avg_rating = float(ratings_result.avg_rating)
            service.total_ratings = int(ratings_result.total_ratings)
            db.commit()

    return {"message": "Rating submitted successfully"}


@router.get("/customer-service/my-chats")
def get_my_customer_service_chats(
    current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    """获取用户的客服对话历史"""
    chats = crud.get_user_customer_service_chats(db, current_user.id)
    return chats


@router.get("/customer-service/chat/{chat_id}/messages")
def get_customer_service_chat_messages(
    chat_id: str, current_user=Depends(get_current_user_secure_sync), db: Session = Depends(get_db)
):
    """获取客服对话消息（用户端）"""
    # 验证chat_id是否属于当前用户
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/customer-service/chat/{chat_id}/send-message")
def send_customer_service_chat_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_user_secure_sync),
    db: Session = Depends(get_db),
):
    """用户发送消息到客服对话"""
    # 验证chat_id是否属于当前用户且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db, chat_id, current_user.id, "user", message_data.get("content", "")
    )

    # 注意：不创建通知给客服，因为客服ID不在users表中
    # 客服可以通过WebSocket实时接收消息通知
    # crud.create_notification(
    #     db,
    #     chat['service_id'],
    #     "message",
    #     "新消息",
    #     f"用户 {current_user.name} 给您发来一条消息",
    #     current_user.id
    # )

    return message


@router.get("/customer-service/{service_id}/rating")
def get_customer_service_rating(service_id: str, db: Session = Depends(get_db)):
    """获取客服的平均评分信息"""
    service = db.query(CustomerService).filter(CustomerService.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Customer service not found")

    return {
        "service_id": service.id,
        "service_name": service.name,
        "avg_rating": service.avg_rating,
        "total_ratings": service.total_ratings,
    }


@router.get("/customer-service/all-ratings")
def get_all_customer_service_ratings(db: Session = Depends(get_db)):
    """获取所有客服的平均评分信息"""
    services = db.query(CustomerService).all()

    return [
        {
            "service_id": service.id,
            "service_name": service.name,
            "avg_rating": service.avg_rating,
            "total_ratings": service.total_ratings,
            "is_online": service.is_online == 1,
        }
        for service in services
    ]


@router.get("/customer-service/cancel-requests", response_model=list[schemas.TaskCancelRequestOut])
def cs_get_cancel_requests(
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
    status: str = None,
):
    """客服获取任务取消请求列表"""
    requests = crud.get_task_cancel_requests(db, status)
    return requests


@router.post("/customer-service/cancel-requests/{request_id}/review")
def cs_review_cancel_request(
    request_id: int,
    review: schemas.TaskCancelRequestReview,
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """客服审核任务取消请求"""
    cancel_request = crud.get_task_cancel_request_by_id(db, request_id)
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Request has already been reviewed")

    # 更新请求状态
    updated_request = crud.update_task_cancel_request(
        db, request_id, review.status, current_user.id, review.admin_comment
    )

    if review.status == "approved":
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            # 实际取消任务
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )

            # 通知另一方（发布者或接受者）
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == task.taker_id
                else task.taker_id
            )
            if other_user_id:
                crud.create_notification(
                    db,
                    other_user_id,
                    "task_cancelled",
                    "任务已取消",
                    f'任务 "{task.title}" 已被取消',
                    task.id,
                )

    elif review.status == "rejected":
        # 通知请求者
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_rejected",
                "取消请求被拒绝",
                f'您的任务 "{task.title}" 取消请求被拒绝，原因：{review.admin_comment or "无"}',
                task.id,
            )

    return {"message": f"Cancel request {review.status}", "request": updated_request}


# 管理请求相关API
@router.get(
    "/customer-service/admin-requests", response_model=list[schemas.AdminRequestOut]
)
def get_admin_requests(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """获取客服提交的管理请求列表"""
    from app.models import AdminRequest

    requests = (
        db.query(AdminRequest)
        .filter(AdminRequest.requester_id == current_user.id)
        .order_by(AdminRequest.created_at.desc())
        .all()
    )
    return requests


@router.post("/customer-service/admin-requests", response_model=schemas.AdminRequestOut)
def create_admin_request(
    request_data: schemas.AdminRequestCreate,
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """客服提交管理请求"""
    from app.models import AdminRequest

    admin_request = AdminRequest(
        requester_id=current_user.id,
        type=request_data.type,
        title=request_data.title,
        description=request_data.description,
        priority=request_data.priority,
    )
    db.add(admin_request)
    db.commit()
    db.refresh(admin_request)
    return admin_request


@router.get(
    "/customer-service/admin-chat", response_model=list[schemas.AdminChatMessageOut]
)
def get_admin_chat_messages(
    current_user=Depends(get_current_customer_service), db: Session = Depends(get_db)
):
    """获取与后台工作人员的聊天记录"""
    from app.models import AdminChatMessage

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )
    return messages


@router.post("/customer-service/admin-chat", response_model=schemas.AdminChatMessageOut)
def send_admin_chat_message(
    message_data: schemas.AdminChatMessageCreate,
    current_user=Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """客服发送消息给后台工作人员"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id,
        sender_type="customer_service",
        content=message_data.content,
    )
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    return chat_message


# 清理过期会话的后台任务（不自动结束超时对话）


# 管理后台相关API接口
from app.deps import check_admin, check_admin_user_status, check_super_admin


@router.get("/admin/dashboard/stats")
def get_dashboard_stats(
    current_admin=Depends(check_admin_user_status), db: Session = Depends(get_db)
):
    """获取管理后台统计数据"""
    try:
        stats = crud.get_dashboard_stats(db)
        return stats
    except Exception as e:
        print(f"Error in get_dashboard_stats: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/admin/users")
def get_users_for_admin(
    page: int = 1,
    size: int = 20,
    search: str = None,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员获取用户列表"""
    skip = (page - 1) * size
    result = crud.get_users_for_admin(db, skip=skip, limit=size, search=search)

    return {
        "users": result["users"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.patch("/admin/users/{user_id}")
def update_user_by_admin(
    user_id: str,
    user_update: schemas.AdminUserUpdate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """后台管理员更新用户信息"""
    update_data = user_update.dict(exclude_unset=True)
    user = crud.update_user_by_admin(db, user_id, update_data)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {"message": "User updated successfully", "user": user}


@router.get("/admin/admin-users")
def get_admin_users_for_super_admin(
    page: int = 1,
    size: int = 20,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员获取管理员列表"""
    # 只有超级管理员才能查看管理员列表
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can view admin users"
        )

    skip = (page - 1) * size
    result = crud.get_admin_users_for_admin(db, skip=skip, limit=size)

    return {
        "admin_users": result["admin_users"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.post("/admin/admin-user")
def create_admin_user_by_super_admin(
    admin_data: schemas.AdminUserCreate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员创建管理员账号"""
    # 只有超级管理员才能创建新的管理员用户
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can create admin users"
        )

    # 检查用户名是否已存在
    existing_admin = crud.get_admin_user_by_username(db, admin_data.username)
    if existing_admin:
        raise HTTPException(status_code=400, detail="Username already exists")

    # 检查邮箱是否已存在
    existing_email = crud.get_admin_user_by_email(db, admin_data.email)
    if existing_email:
        raise HTTPException(status_code=400, detail="Email already exists")

    # 创建管理员用户
    admin_user = crud.create_admin_user(db, admin_data.dict())

    return {
        "message": "Admin user created successfully",
        "admin_user": {
            "id": admin_user.id,
            "name": admin_user.name,
            "username": admin_user.username,
            "email": admin_user.email,
            "is_super_admin": admin_user.is_super_admin,
            "is_active": admin_user.is_active,
            "created_at": admin_user.created_at,
        },
    }


@router.delete("/admin/admin-user/{admin_id}")
def delete_admin_user_by_super_admin(
    admin_id: str,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员删除管理员账号"""
    # 只有超级管理员才能删除管理员用户
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can delete admin users"
        )

    # 不能删除自己
    if admin_id == current_admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")

    success = crud.delete_admin_user_by_super_admin(db, admin_id)
    if not success:
        raise HTTPException(
            status_code=404, detail="Admin user not found or cannot be deleted"
        )

    return {"message": "Admin user deleted successfully"}


# 员工提醒相关API
@router.post("/admin/staff-notification")
def send_staff_notification(
    notification: schemas.StaffNotificationCreate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员发送员工提醒"""
    # 只有超级管理员才能发送提醒
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403, detail="Only super admin can send staff notifications"
        )

    # 验证接收者是否存在
    if notification.recipient_type == "customer_service":
        recipient = (
            db.query(models.CustomerService)
            .filter(models.CustomerService.id == notification.recipient_id)
            .first()
        )
    elif notification.recipient_type == "admin":
        recipient = (
            db.query(models.AdminUser)
            .filter(models.AdminUser.id == notification.recipient_id)
            .first()
        )
    else:
        raise HTTPException(status_code=400, detail="Invalid recipient type")

    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")

    # 创建提醒
    notification_data = {
        "recipient_id": notification.recipient_id,
        "recipient_type": notification.recipient_type,
        "sender_id": current_admin.id,
        "title": notification.title,
        "content": notification.content,
        "notification_type": notification.notification_type,
    }

    staff_notification = crud.create_staff_notification(db, notification_data)

    return {
        "message": "Staff notification sent successfully",
        "notification": {
            "id": staff_notification.id,
            "recipient_id": staff_notification.recipient_id,
            "recipient_type": staff_notification.recipient_type,
            "title": staff_notification.title,
            "content": staff_notification.content,
            "notification_type": staff_notification.notification_type,
            "created_at": staff_notification.created_at,
        },
    }


@router.get("/staff/notifications")
def get_staff_notifications(
    current_user=Depends(get_current_customer_service_or_user),
    db: Session = Depends(get_db),
):
    """获取员工提醒列表（所有提醒，已读+未读，限制5条最新）"""
    # 确定用户类型
    if (
        hasattr(current_user, "email")
        and hasattr(current_user, "name")
        and not hasattr(current_user, "username")
    ):
        # 客服用户：有email和name，但没有username
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 管理员用户
        recipient_type = "admin"
        recipient_id = current_user.id

    # 获取所有未读提醒 + 5条最新已读提醒
    notifications = crud.get_staff_notifications(db, recipient_id, recipient_type)
    # 获取未读数量
    unread_count = crud.get_unread_staff_notification_count(
        db, recipient_id, recipient_type
    )

    return {
        "notifications": notifications,
        "total": len(notifications),
        "unread_count": unread_count,
    }


@router.get("/staff/notifications/unread")
def get_unread_staff_notifications(
    current_user=Depends(get_current_customer_service_or_user),
    db: Session = Depends(get_db),
):
    """获取未读员工提醒"""
    # 确定用户类型
    if (
        hasattr(current_user, "email")
        and hasattr(current_user, "name")
        and not hasattr(current_user, "username")
    ):
        # 客服用户：有email和name，但没有username
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 管理员用户
        recipient_type = "admin"
        recipient_id = current_user.id

    notifications = crud.get_unread_staff_notifications(
        db, recipient_id, recipient_type
    )
    count = crud.get_unread_staff_notification_count(db, recipient_id, recipient_type)

    return {"notifications": notifications, "unread_count": count}


@router.post("/staff/notifications/{notification_id}/read")
def mark_staff_notification_read(
    notification_id: int,
    current_user=Depends(get_current_customer_service_or_user),
    db: Session = Depends(get_db),
):
    """标记员工提醒为已读"""
    # 确定用户类型
    if (
        hasattr(current_user, "email")
        and hasattr(current_user, "name")
        and not hasattr(current_user, "username")
    ):
        # 客服用户：有email和name，但没有username
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 管理员用户
        recipient_type = "admin"
        recipient_id = current_user.id

    notification = crud.mark_staff_notification_read(
        db, notification_id, recipient_id, recipient_type
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    return {"message": "Notification marked as read"}


@router.post("/staff/notifications/read-all")
def mark_all_staff_notifications_read(
    current_user=Depends(get_current_customer_service_or_user),
    db: Session = Depends(get_db),
):
    """标记所有员工提醒为已读"""
    # 确定用户类型
    if (
        hasattr(current_user, "email")
        and hasattr(current_user, "name")
        and not hasattr(current_user, "username")
    ):
        # 客服用户：有email和name，但没有username
        recipient_type = "customer_service"
        recipient_id = current_user.id
    else:
        # 管理员用户
        recipient_type = "admin"
        recipient_id = current_user.id

    count = crud.mark_all_staff_notifications_read(db, recipient_id, recipient_type)

    return {"message": f"Marked {count} notifications as read"}


@router.post("/admin/customer-service")
def create_customer_service_by_admin(
    cs_data: schemas.AdminCustomerServiceCreate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员创建客服账号"""
    # 检查邮箱是否已存在（在用户表和客服表中）
    existing_user = crud.get_user_by_email(db, cs_data.email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already exists")

    existing_cs_email = crud.get_customer_service_by_email(db, cs_data.email)
    if existing_cs_email:
        raise HTTPException(status_code=400, detail="Email already exists")

    # 生成唯一的客服ID
    import random

    from app.id_generator import format_customer_service_id

    while True:
        # 生成4位随机数字
        random_id = random.randint(1000, 9999)
        cs_id = format_customer_service_id(random_id)

        # 检查ID是否已存在
        existing_cs_id = crud.get_customer_service_by_id(db, cs_id)
        if not existing_cs_id:
            break

    # 添加ID到数据中
    cs_data_dict = cs_data.dict()
    cs_data_dict["id"] = cs_id

    # 检查姓名是否已存在（在客服表中）
    from app.models import CustomerService

    existing_cs_name = (
        db.query(CustomerService).filter(CustomerService.name == cs_data.name).first()
    )
    if existing_cs_name:
        raise HTTPException(status_code=400, detail="Name already exists")

    result = crud.create_customer_service_with_login(db, cs_data_dict)
    return {"message": "Customer service created successfully", "data": result}


@router.delete("/admin/customer-service/{cs_id}")
def delete_customer_service_by_admin(
    cs_id: int,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员删除客服账号"""
    success = crud.delete_customer_service_by_admin(db, cs_id)
    if not success:
        raise HTTPException(status_code=404, detail="Customer service not found")

    return {"message": "Customer service deleted successfully"}


@router.get("/admin/customer-service")
def get_customer_services_for_admin(
    page: int = 1,
    size: int = 20,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员获取客服列表"""
    skip = (page - 1) * size
    result = crud.get_customer_services_for_admin(db, skip=skip, limit=size)

    return {
        "customer_services": result["customer_services"],
        "total": result["total"],
        "page": page,
        "size": size,
    }


@router.post("/admin/notifications/send")
def send_admin_notification(
    notification: schemas.AdminNotificationCreate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员发送通知"""
    notifications = crud.send_admin_notification(
        db,
        notification.user_ids,
        notification.title,
        notification.content,
        notification.type,
    )

    return {
        "message": f"Notification sent to {len(notifications)} users",
        "count": len(notifications),
    }


@router.patch("/admin/tasks/{task_id}")
def update_task_by_admin(
    task_id: int,
    task_update: schemas.AdminTaskUpdate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员更新任务信息"""
    update_data = task_update.dict(exclude_unset=True)
    task = crud.update_task_by_admin(db, task_id, update_data)

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    return {"message": "Task updated successfully", "task": task}


@router.delete("/admin/tasks/{task_id}")
def delete_task_by_admin(
    task_id: int,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员删除任务"""
    success = crud.delete_task_by_admin(db, task_id)
    if not success:
        raise HTTPException(status_code=404, detail="Task not found")

    return {"message": "Task deleted successfully"}


@router.post("/admin/customer-service/{cs_id}/notify")
def notify_customer_service(
    cs_id: int,
    message: str = Body(...),
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """超级管理员给指定客服发送提醒"""
    # 获取客服信息
    cs = db.query(CustomerService).filter(CustomerService.id == cs_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Customer service not found")

    # 找到对应的用户账号
    from app.models import User

    user = db.query(User).filter(User.name == cs.name).first()

    if not user:
        raise HTTPException(status_code=404, detail="Customer service user not found")

    # 发送通知
    notification = crud.create_notification(
        db, user.id, "admin_notification", "管理员提醒", message
    )

    return {
        "message": "Notification sent to customer service",
        "notification": notification,
    }


# 系统设置相关API
@router.get("/admin/system-settings")
def get_system_settings(
    current_admin=Depends(check_admin_user_status), db: Session = Depends(get_db)
):
    """获取系统设置"""
    settings_dict = crud.get_system_settings_dict(db)

    # 返回默认设置（如果数据库中没有设置）
    default_settings = {
        "vip_enabled": True,
        "super_vip_enabled": True,
        "vip_task_threshold": 5,
        "super_vip_task_threshold": 20,
        "vip_price_threshold": 10.0,
        "super_vip_price_threshold": 50.0,
        "vip_button_visible": True,
        "vip_auto_upgrade_enabled": False,
        "vip_benefits_description": "优先任务推荐、专属客服服务、任务发布数量翻倍",
        "super_vip_benefits_description": "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识",
        # VIP晋升超级VIP的条件
        "vip_to_super_task_count_threshold": 50,
        "vip_to_super_rating_threshold": 4.5,
        "vip_to_super_completion_rate_threshold": 0.8,
        "vip_to_super_enabled": True,
    }

    # 合并数据库设置和默认设置
    for key, value in default_settings.items():
        if key not in settings_dict:
            settings_dict[key] = value

    return settings_dict


@router.put("/admin/system-settings")
def update_system_settings(
    settings_data: schemas.SystemSettingsBulkUpdate,
    current_admin=Depends(check_admin_user_status),
    db: Session = Depends(get_db),
):
    """更新系统设置"""
    try:
        updated_settings = crud.bulk_update_system_settings(db, settings_data)
        return {
            "message": "系统设置更新成功",
            "updated_count": len(updated_settings),
            "settings": crud.get_system_settings_dict(db),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"更新系统设置失败: {str(e)}")


@router.get("/system-settings/public")
def get_public_system_settings(db: Session = Depends(get_db)):
    """获取公开的系统设置（前端使用）"""
    settings_dict = crud.get_system_settings_dict(db)

    # 只返回前端需要的公开设置
    public_settings = {
        "vip_enabled": settings_dict.get("vip_enabled", True),
        "super_vip_enabled": settings_dict.get("super_vip_enabled", True),
        "vip_button_visible": settings_dict.get("vip_button_visible", True),
        "vip_benefits_description": settings_dict.get(
            "vip_benefits_description", "优先任务推荐、专属客服服务、任务发布数量翻倍"
        ),
        "super_vip_benefits_description": settings_dict.get(
            "super_vip_benefits_description",
            "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识",
        ),
    }

    return public_settings


@router.get("/users/{user_id}/task-statistics")
def get_user_task_statistics(
    user_id: str, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """获取用户的任务统计信息"""
    # 只能查看自己的统计信息
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="只能查看自己的统计信息")

    statistics = crud.get_user_task_statistics(db, user_id)

    # 获取晋升条件设置
    settings = crud.get_system_settings_dict(db)
    upgrade_conditions = {
        "task_count_threshold": settings.get("vip_to_super_task_count_threshold", 50),
        "rating_threshold": settings.get("vip_to_super_rating_threshold", 4.5),
        "completion_rate_threshold": settings.get(
            "vip_to_super_completion_rate_threshold", 0.8
        ),
        "upgrade_enabled": settings.get("vip_to_super_enabled", True),
    }

    return {
        "statistics": statistics,
        "upgrade_conditions": upgrade_conditions,
        "current_level": current_user.user_level,
    }


@router.post("/customer-service/cleanup-old-chats/{service_id}")
def cleanup_old_customer_service_chats(
    service_id: str,
    current_user: models.CustomerService = Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """清理客服的旧已结束对话"""
    if current_user.id != service_id:
        raise HTTPException(status_code=403, detail="无权限清理其他客服的对话")

    try:
        deleted_count = crud.cleanup_old_ended_chats(db, service_id)
        return {
            "message": f"成功清理 {deleted_count} 个旧对话",
            "deleted_count": deleted_count,
        }
    except Exception as e:
        logger.error(f"清理旧对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


@router.post("/customer-service/timeout-end-chat/{chat_id}")
def timeout_end_customer_service_chat(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """超时结束客服对话"""
    try:
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            raise HTTPException(status_code=403, detail="无权限操作此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            raise HTTPException(status_code=400, detail="对话已结束")

        # 结束对话
        success = crud.end_customer_service_chat(db, chat_id)
        if not success:
            raise HTTPException(status_code=500, detail="结束对话失败")

        # 发送超时通知给用户
        crud.create_notification(
            db=db,
            user_id=chat["user_id"],
            type="chat_timeout",
            title="对话超时结束",
            content="您的客服对话因超时（2分钟无活动）已自动结束。如需继续咨询，请重新联系客服。",
            related_id=chat_id,
        )

        return {"message": "对话已超时结束", "chat_id": chat_id, "user_notified": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"超时结束对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")


@router.get("/timezone/info")
def get_timezone_info():
    """获取当前服务器时区信息"""
    import pytz

    uk_tz = pytz.timezone("Europe/London")
    current_time = datetime.now(uk_tz)

    return {
        "server_timezone": "Europe/London",
        "server_time": current_time.isoformat(),
        "timezone_offset": current_time.strftime("%z"),
        "is_dst": current_time.dst().total_seconds() > 0,
        "timezone_name": current_time.tzname(),
    }


@router.get("/customer-service/chat-timeout-status/{chat_id}")
def get_chat_timeout_status(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_customer_service),
    db: Session = Depends(get_db),
):
    """获取对话超时状态"""
    try:
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            raise HTTPException(status_code=403, detail="无权限查看此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            return {"is_ended": True, "is_timeout": False, "timeout_available": False}

        # 计算最后消息时间到现在的时间差
        from datetime import datetime, timedelta, timezone

        last_message_time = chat["last_message_at"]

        # 统一处理时间格式 - 使用动态英国时间
        import pytz

        uk_tz = pytz.timezone("Europe/London")
        current_time = datetime.now(uk_tz)

        if isinstance(last_message_time, str):
            # 处理字符串格式的时间
            if last_message_time.endswith("Z"):
                # UTC时间，转换为英国时间
                last_message_time = last_message_time[:-1] + "+00:00"
                last_message_time = datetime.fromisoformat(
                    last_message_time
                ).astimezone(uk_tz)
            elif "+" not in last_message_time and "T" in last_message_time:
                # 如果没有时区信息，假设是英国时间
                last_message_time = datetime.fromisoformat(last_message_time)
                # 添加当前英国时区信息
                last_message_time = uk_tz.localize(last_message_time)
                logger.info(f"处理无时区信息的时间，添加英国时区: {last_message_time}")
            else:
                last_message_time = datetime.fromisoformat(last_message_time)
                if last_message_time.tzinfo is None:
                    last_message_time = uk_tz.localize(last_message_time)
        elif hasattr(last_message_time, "replace"):
            # 如果是datetime对象但没有时区信息，添加英国时区
            if last_message_time.tzinfo is None:
                last_message_time = uk_tz.localize(last_message_time)
                logger.info(f"为datetime对象添加英国时区: {last_message_time}")
        else:
            # 如果是其他类型，使用当前英国时间
            logger.warning(
                f"Unexpected time type: {type(last_message_time)}, value: {last_message_time}"
            )
            last_message_time = current_time

        # 获取当前英国时区偏移信息
        uk_offset = current_time.strftime("%z")  # +0100 或 +0000
        uk_hours = int(uk_offset[1:3])  # 提取小时数
        logger.info(f"英国当前时区偏移: {uk_offset} (UTC+{uk_hours})")
        time_diff = current_time - last_message_time

        # 调试信息
        logger.info(
            f"Current time: {current_time}, Last message time: {last_message_time}, Diff: {time_diff.total_seconds()} seconds"
        )
        logger.info(
            f"Current time type: {type(current_time)}, Last message time type: {type(last_message_time)}"
        )
        logger.info(
            f"Current time tzinfo: {current_time.tzinfo}, Last message time tzinfo: {last_message_time.tzinfo}"
        )

        # 2分钟 = 120秒
        is_timeout = time_diff.total_seconds() > 120

        return {
            "is_ended": False,
            "is_timeout": is_timeout,
            "timeout_available": is_timeout,
            "last_message_time": chat["last_message_at"],
            "time_since_last_message": int(time_diff.total_seconds()),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取对话超时状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")


# 图片上传相关配置
UPLOAD_DIR = Path("uploads/images")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB


@router.post("/upload/image")
async def upload_image(
    image: UploadFile = File(...), current_user: models.User = Depends(get_current_user_secure_sync)
):
    """
    上传图片文件
    """
    try:
        # 检查文件类型
        file_extension = Path(image.filename).suffix.lower()
        if file_extension not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。支持的格式: {', '.join(ALLOWED_EXTENSIONS)}",
            )

        # 检查文件大小
        content = await image.read()
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大。最大允许大小: {MAX_FILE_SIZE // (1024*1024)}MB",
            )

        # 生成唯一文件名
        file_id = str(uuid.uuid4())
        filename = f"{file_id}{file_extension}"
        file_path = UPLOAD_DIR / filename

        # 保存文件
        with open(file_path, "wb") as buffer:
            buffer.write(content)

        # 生成访问URL
        base_url = "http://localhost:8000"  # 可以根据需要修改
        image_url = f"{base_url}/uploads/images/{filename}"

        logger.info(f"用户 {current_user.id} 上传图片: {filename}")

        return JSONResponse(
            content={
                "success": True,
                "url": image_url,
                "filename": filename,
                "size": len(content),
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.get("/uploads/images/{filename}")
async def get_image(filename: str):
    """
    获取上传的图片文件
    """
    try:
        file_path = UPLOAD_DIR / filename

        if not file_path.exists():
            raise HTTPException(status_code=404, detail="图片不存在")

        from fastapi.responses import FileResponse

        return FileResponse(path=file_path, media_type="image/*", filename=filename)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取图片失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取图片失败: {str(e)}")

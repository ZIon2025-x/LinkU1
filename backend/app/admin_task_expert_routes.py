"""
管理员任务达人审核API路由
实现管理员审核任务达人申请的相关接口
"""

import logging
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app import models, schemas
from app.deps import get_async_db_dependency
# 管理员认证依赖（异步版本）
async def get_current_admin_async(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.AdminUser:
    """获取当前管理员（异步版本）"""
    from app.admin_auth import validate_admin_session
    
    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败，请重新登录"
        )
    
    # 获取管理员信息（异步）
    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在"
        )
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    return admin

logger = logging.getLogger(__name__)

# 创建管理员任务达人路由器
admin_task_expert_router = APIRouter(prefix="/api/admin", tags=["admin-task-experts"])


@admin_task_expert_router.get("/task-expert-applications", response_model=schemas.PaginatedResponse)
async def get_expert_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员获取申请列表"""
    query = select(models.TaskExpertApplication)
    
    if status_filter:
        query = query.where(models.TaskExpertApplication.status == status_filter)
    
    # 获取总数
    count_query = select(func.count(models.TaskExpertApplication.id))
    if status_filter:
        count_query = count_query.where(models.TaskExpertApplication.status == status_filter)
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(models.TaskExpertApplication.created_at.desc()).offset(offset).limit(limit)
    
    result = await db.execute(query)
    applications = result.scalars().all()
    
    # 加载关联数据
    items = []
    for app in applications:
        app_dict = schemas.TaskExpertApplicationOut.model_validate(app).model_dump()
        # 加载用户信息
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, app.user_id)
        if user:
            app_dict["user_name"] = user.name
        items.append(app_dict)
    
    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@admin_task_expert_router.post("/task-expert-applications/{application_id}/review")
async def review_expert_application(
    application_id: int,
    review_data: schemas.TaskExpertApplicationReview,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核任务达人申请"""
    # 1. 获取申请记录（使用FOR UPDATE锁，防止并发）
    application = await db.execute(
        select(models.TaskExpertApplication)
        .where(models.TaskExpertApplication.id == application_id)
        .where(models.TaskExpertApplication.status == "pending")
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在或已处理")
    
    if review_data.action == "approve":
        # 2. 验证用户是否存在
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, application.user_id)
        
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 3. 验证用户是否已经是任务达人（主键约束自然防重）
        existing_expert = await db.execute(
            select(models.TaskExpert).where(models.TaskExpert.id == application.user_id)
        )
        if existing_expert.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="该用户已经是任务达人")
        
        # 4. 创建任务达人记录（ID使用用户的ID）
        try:
            new_expert = models.TaskExpert(
                id=application.user_id,  # 重要：使用用户的ID作为任务达人的ID
                expert_name=None,  # 可选，默认为NULL
                bio=None,  # 可选
                avatar=None,  # 可选，使用用户默认头像
                status="active",
                approved_by=current_admin.id,  # 批准的管理员ID
                approved_at=models.get_utc_time(),
            )
            
            db.add(new_expert)
            
            # 5. 更新申请记录
            application.status = "approved"
            application.reviewed_by = current_admin.id
            application.reviewed_at = models.get_utc_time()
            application.review_comment = review_data.review_comment
            application.updated_at = models.get_utc_time()
            
            await db.commit()
            await db.refresh(new_expert)
        except IntegrityError:
            await db.rollback()
            raise HTTPException(status_code=409, detail="该用户已经是任务达人（并发冲突）")
        
        # 6. 发送通知给用户
        from app.task_notifications import send_expert_application_approved_notification
        try:
            await send_expert_application_approved_notification(
                db=db,
                user_id=application.user_id,
                expert_id=new_expert.id
            )
        except Exception as e:
            logger.error(f"Failed to send approval notification: {e}")
        
        return {
            "message": "申请已批准，任务达人已创建",
            "application_id": application_id,
            "expert": schemas.TaskExpertOut.model_validate(new_expert).model_dump(),
        }
    
    elif review_data.action == "reject":
        # 拒绝申请
        application.status = "rejected"
        application.reviewed_by = current_admin.id
        application.reviewed_at = models.get_utc_time()
        application.review_comment = review_data.review_comment
        application.updated_at = models.get_utc_time()
        
        await db.commit()
        
        # 发送通知给用户
        from app.task_notifications import send_expert_application_rejected_notification
        try:
            await send_expert_application_rejected_notification(db, application.user_id, review_data.review_comment)
        except Exception as e:
            logger.error(f"Failed to send rejection notification: {e}")
        
        return {
            "message": "申请已拒绝"
        }


@admin_task_expert_router.post("/task-expert-applications/{application_id}/create-expert")
async def create_expert_from_application(
    application_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    根据已批准的申请创建任务达人记录
    用于在批准申请后手动创建任务达人（如果批准时未自动创建）
    """
    # 1. 获取申请记录
    application_result = await db.execute(
        select(models.TaskExpertApplication).where(models.TaskExpertApplication.id == application_id)
    )
    application = application_result.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    if application.status != "approved":
        raise HTTPException(status_code=400, detail="只能为已批准的申请创建任务达人")
    
    # 2. 验证用户是否存在
    from app import async_crud
    user = await async_crud.async_user_crud.get_user_by_id(db, application.user_id)
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 3. 检查是否已经是任务达人
    existing_expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == application.user_id)
    )
    if existing_expert.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该用户已经是任务达人")
    
    # 4. 创建任务达人记录（ID使用用户的ID）
    try:
        new_expert = models.TaskExpert(
            id=application.user_id,  # 重要：使用用户的ID作为任务达人的ID
            expert_name=None,  # 可选，默认为NULL
            bio=None,  # 可选
            avatar=None,  # 可选，使用用户默认头像
            status="active",
            approved_by=current_admin.id,  # 批准的管理员ID
            approved_at=models.get_utc_time(),
        )
        
        db.add(new_expert)
        await db.commit()
        await db.refresh(new_expert)
        
        logger.info(f"管理员 {current_admin.id} 为申请 {application_id} 创建了任务达人 {new_expert.id}")
        
        return {
            "message": "任务达人创建成功",
            "expert_id": new_expert.id
        }
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="该用户已经是任务达人（并发冲突）")
    
    elif review_data.action == "reject":
        # 拒绝申请
        application.status = "rejected"
        application.reviewed_by = current_admin.id
        application.reviewed_at = models.get_utc_time()
        application.review_comment = review_data.review_comment
        application.updated_at = models.get_utc_time()
        
        await db.commit()
        
        # 发送通知给用户
        from app.task_notifications import send_expert_application_rejected_notification
        try:
            await send_expert_application_rejected_notification(
                db=db,
                user_id=application.user_id,
                review_comment=review_data.review_comment
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
        
        return {
            "message": "申请已拒绝",
            "application_id": application_id,
            "status": "rejected",
        }
    
    else:
        raise HTTPException(status_code=400, detail="无效的操作类型")


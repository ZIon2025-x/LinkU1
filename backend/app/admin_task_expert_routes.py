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


@admin_task_expert_router.post("/task-expert-applications/{application_id}/create-featured-expert")
async def create_featured_expert_from_application(
    application_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    根据已批准的申请创建特色任务达人记录（FeaturedTaskExpert）
    用于在前端任务达人页面展示
    注意：TaskExpert 应该在批准申请时自动创建，这里只创建 FeaturedTaskExpert
    """
    # 1. 获取申请记录
    application_result = await db.execute(
        select(models.TaskExpertApplication).where(models.TaskExpertApplication.id == application_id)
    )
    application = application_result.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    if application.status != "approved":
        raise HTTPException(status_code=400, detail="只能为已批准的申请创建特色任务达人")
    
    # 2. 验证用户是否存在
    from app import async_crud
    user = await async_crud.async_user_crud.get_user_by_id(db, application.user_id)
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 3. 检查用户是否已经是 TaskExpert（批准申请时应该已经创建）
    task_expert_result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == application.user_id)
    )
    task_expert = task_expert_result.scalar_one_or_none()
    
    if not task_expert:
        raise HTTPException(status_code=400, detail="该用户还不是任务达人，请先批准申请")
    
    # 4. 检查是否已经存在 FeaturedTaskExpert（避免重复创建）
    from sqlalchemy import text
    existing_featured_result = await db.execute(
        text("SELECT id FROM featured_task_experts WHERE user_id = :user_id"),
        {"user_id": application.user_id}
    )
    existing_featured = existing_featured_result.fetchone()
    
    if existing_featured:
        raise HTTPException(status_code=400, detail="该用户已经是特色任务达人")
    
    # 5. 创建特色任务达人记录（FeaturedTaskExpert）
    # 使用同步数据库会话（因为 FeaturedTaskExpert 是同步模型）
    from app.database import SessionLocal
    
    sync_db = None
    try:
        # 创建同步数据库会话
        sync_db = SessionLocal()
        
        import json
        new_featured_expert = models.FeaturedTaskExpert(
            user_id=application.user_id,  # 关联到用户ID
            name=user.name or f"用户{application.user_id}",  # 使用用户名
            avatar=user.avatar or "",  # 使用用户头像
            user_level="normal",  # 默认等级
            bio=application.application_message or None,  # 使用申请说明作为简介
            bio_en=None,
            avg_rating=0.0,
            completed_tasks=0,
            total_tasks=0,
            completion_rate=0.0,
            expertise_areas=None,
            expertise_areas_en=None,
            featured_skills=None,
            featured_skills_en=None,
            achievements=None,
            achievements_en=None,
            response_time=None,
            response_time_en=None,
            success_rate=0.0,
            is_verified=0,
            is_active=1,  # 默认启用
            is_featured=1,  # 默认精选
            display_order=0,
            category=None,
            location=None,
            created_by=current_admin.id
        )
        
        sync_db.add(new_featured_expert)
        sync_db.commit()
        sync_db.refresh(new_featured_expert)
        
        logger.info(f"管理员 {current_admin.id} 为申请 {application_id} 创建了特色任务达人 {new_featured_expert.id}")
        
        return {
            "message": "特色任务达人创建成功",
            "featured_expert_id": new_featured_expert.id,
            "user_id": application.user_id
        }
    except IntegrityError as e:
        if sync_db:
            sync_db.rollback()
        logger.error(f"创建特色任务达人失败: {e}")
        raise HTTPException(status_code=409, detail="该用户已经是特色任务达人（并发冲突）")
    except Exception as e:
        if sync_db:
            sync_db.rollback()
        logger.error(f"创建特色任务达人失败: {e}")
        raise HTTPException(status_code=500, detail=f"创建特色任务达人失败: {str(e)}")
    finally:
        if sync_db:
            sync_db.close()


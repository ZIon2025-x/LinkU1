"""
管理员任务达人审核API路由
实现管理员审核任务达人申请的相关接口
"""

import logging
from typing import List, Optional
from datetime import datetime, timezone
from decimal import Decimal

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
    try:
        logger.info(f"开始审核申请 {application_id}, 操作: {review_data.action}, 管理员: {current_admin.id}")
        
        # 1. 获取申请记录（使用FOR UPDATE锁，防止并发）
        # 先检查申请是否存在（不限制状态），用于更好的错误提示
        check_result = await db.execute(
            select(models.TaskExpertApplication)
            .where(models.TaskExpertApplication.id == application_id)
        )
        check_app = check_result.scalar_one_or_none()
        
        if not check_app:
            logger.warning(f"申请不存在: {application_id}")
            raise HTTPException(status_code=404, detail="申请不存在")
        
        if check_app.status != "pending":
            logger.warning(f"申请已处理: {application_id}, 当前状态: {check_app.status}")
            raise HTTPException(status_code=400, detail=f"申请已处理，当前状态: {check_app.status}")
        
        # 使用FOR UPDATE锁获取pending状态的申请
        application_result = await db.execute(
            select(models.TaskExpertApplication)
            .where(models.TaskExpertApplication.id == application_id)
            .where(models.TaskExpertApplication.status == "pending")
            .with_for_update()  # 并发安全：行级锁
        )
        application = application_result.scalar_one_or_none()
        
        if not application:
            # 这种情况理论上不应该发生，因为上面已经检查过了
            # 但如果在两次查询之间状态被其他请求修改了，这里会捕获
            logger.warning(f"申请状态在查询间已变更: {application_id}")
            raise HTTPException(status_code=400, detail="申请状态已变更，请刷新页面重试")
        
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
            new_expert = None
            commit_success = False
            expert_id_value = application.user_id  # 在 commit 之前保存 ID，避免后续访问对象属性
            try:
                new_expert = models.TaskExpert(
                    id=expert_id_value,  # 重要：使用用户的ID作为任务达人的ID
                    expert_name=None,  # 可选，默认为NULL
                    bio=None,  # 可选
                    avatar=None,  # 可选，使用用户默认头像
                    status="active",
                    rating=0.00,  # 初始评分为0
                    total_services=0,  # 初始服务数为0
                    completed_tasks=0,  # 初始完成任务数为0
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
                commit_success = True
                # 注意：不要在 commit 后访问 new_expert 的属性，因为可能触发延迟加载
                logger.info(f"成功创建任务达人: {expert_id_value}, 状态: active")
            except IntegrityError as e:
                await db.rollback()
                logger.error(f"创建任务达人失败（完整性错误）: {e}")
                raise HTTPException(status_code=409, detail="该用户已经是任务达人（并发冲突）")
            except Exception as e:
                await db.rollback()
                logger.error(f"创建任务达人失败: {e}", exc_info=True)
                raise HTTPException(status_code=500, detail=f"创建任务达人失败: {str(e)}")
            
            # 如果 commit 成功，后续代码即使出错也要返回成功响应
            # 6. 发送通知给用户（失败不影响主流程）
            from app.task_notifications import send_expert_application_approved_notification
            try:
                await send_expert_application_approved_notification(
                    db=db,
                    user_id=application.user_id,
                    expert_id=expert_id_value  # 使用保存的 ID 值，而不是访问对象属性
                )
            except Exception as e:
                logger.error(f"Failed to send approval notification: {e}")
            
            # 返回响应（手动构建，避免序列化错误）
            # 如果 commit 成功，无论如何都要返回成功响应
            if commit_success:
                logger.info(f"申请 {application_id} 已批准，任务达人 {expert_id_value} 已创建")
                
                # 使用已保存的 expert_id_value，避免访问对象属性
                expert_id_str = str(expert_id_value) if expert_id_value else ""
                
                # 手动构建响应，确保类型正确
                # 注意：不要访问 new_expert 的属性，因为可能触发延迟加载
                # 使用默认值，因为这是新创建的对象
                try:
                    # 使用当前时间作为 created_at
                    created_at_str = datetime.now(timezone.utc).isoformat()
                    
                    expert_dict = {
                        "id": expert_id_str,
                        "expert_name": None,  # 新创建的对象，这些字段都是 None
                        "bio": None,
                        "avatar": None,
                        "status": "active",  # 我们设置的状态
                        "rating": 0.0,  # 初始值
                        "total_services": 0,  # 初始值
                        "completed_tasks": 0,  # 初始值
                        "created_at": created_at_str,
                    }
                    
                    # 记录构建的字典，用于调试
                    logger.info(f"构建的 expert_dict: {expert_dict}")
                    
                except Exception as e:
                    logger.error(f"构建 expert_dict 失败，使用简化响应: {e}", exc_info=True)
                    # 即使序列化失败，也返回成功响应（数据已经创建）
                    expert_dict = {
                        "id": expert_id_str,
                        "status": "active",
                    }
                
                # 确保返回成功响应（数据已经成功创建）
                response = {
                    "message": "申请已批准，任务达人已创建",
                    "application_id": application_id,
                    "expert_id": expert_id_str,
                    "expert": expert_dict,
                }
                logger.info(f"准备返回响应: {response}")
                return response
            else:
                # 如果 commit 失败，抛出异常
                logger.error(f"commit_success={commit_success}, expert_id_value={expert_id_value}")
                raise HTTPException(status_code=500, detail="创建任务达人失败：未知错误")
        
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
            
            logger.info(f"申请 {application_id} 已拒绝")
            return {
                "message": "申请已拒绝"
            }
        else:
            logger.error(f"无效的操作: {review_data.action}")
            raise HTTPException(status_code=400, detail=f"无效的操作: {review_data.action}")
    
    except HTTPException:
        # 重新抛出HTTP异常（不rollback，因为可能已经commit了）
        raise
    except Exception as e:
        logger.error(f"审核申请 {application_id} 时发生错误: {e}", exc_info=True)
        # 只有在未提交的情况下才rollback
        # 注意：如果 commit 已经成功，rollback 不会回滚已提交的数据
        try:
            await db.rollback()
        except Exception as rollback_error:
            logger.warning(f"Rollback 失败（可能已经commit）: {rollback_error}")
        raise HTTPException(status_code=500, detail=f"审核失败: {str(e)}")


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
            is_active=0,  # 默认禁用，需要管理员完善信息后手动启用
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


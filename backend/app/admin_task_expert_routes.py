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
            commit_success = False
            expert_id_value = application.user_id  # 在 commit 之前保存 ID，避免后续访问对象属性
            user_name = user.name  # 在 commit 之前保存用户名，避免后续访问对象属性（达人名字就是用户名）
            user_avg_rating = float(user.avg_rating) if user.avg_rating is not None else 0.0  # 使用用户的平均评分
            user_completed_tasks = int(user.completed_task_count) if user.completed_task_count is not None else 0  # 使用用户已完成任务数量
            try:
                new_expert = models.TaskExpert(
                    id=expert_id_value,  # 重要：使用用户的ID作为任务达人的ID
                    expert_name=user_name,  # 达人名字就是用户名
                    bio=None,  # 可选
                    avatar=None,  # 可选，使用用户默认头像
                    status="active",
                    rating=Decimal(str(user_avg_rating)).quantize(Decimal('0.01')),  # 使用用户的平均评分，保留2位小数
                    total_services=0,  # 初始服务数为0
                    completed_tasks=user_completed_tasks,  # 使用用户已完成任务数量
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
                
                # 手动构建响应（使用已知的默认值，不访问 new_expert 属性避免延迟加载）
                expert_dict = {
                    "id": expert_id_value,  # user_id 已经是字符串类型
                    "expert_name": user_name,  # 达人名字就是用户名
                    "bio": None,
                    "avatar": None,
                    "status": "active",
                    "rating": user_avg_rating,  # 使用用户的平均评分
                    "total_services": 0,
                    "completed_tasks": user_completed_tasks,  # 使用用户已完成任务数量
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
                
                return {
                    "message": "申请已批准，任务达人已创建",
                    "application_id": application_id,
                    "expert_id": expert_id_value,
                    "expert": expert_dict,
                }
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
        text("SELECT id FROM featured_task_experts WHERE id = :user_id"),
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
            id=application.user_id,  # 使用用户ID作为主键
            user_id=application.user_id,  # 关联到用户ID（与id相同）
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


@admin_task_expert_router.get("/task-expert-profile-update-requests", response_model=schemas.PaginatedResponse)
async def get_profile_update_requests(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员获取任务达人信息修改请求列表"""
    from sqlalchemy.orm import selectinload
    
    query = select(models.TaskExpertProfileUpdateRequest).options(
        selectinload(models.TaskExpertProfileUpdateRequest.expert)
    )
    
    if status_filter:
        query = query.where(models.TaskExpertProfileUpdateRequest.status == status_filter)
    
    # 获取总数
    count_query = select(func.count(models.TaskExpertProfileUpdateRequest.id))
    if status_filter:
        count_query = count_query.where(models.TaskExpertProfileUpdateRequest.status == status_filter)
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(
        models.TaskExpertProfileUpdateRequest.created_at.desc()
    ).offset(offset).limit(limit)
    
    result = await db.execute(query)
    requests = result.scalars().all()
    
    # 构建响应数据，包含专家信息
    items = []
    for r in requests:
        item = schemas.TaskExpertProfileUpdateRequestOut.model_validate(r).model_dump()
        # 添加专家信息
        if r.expert:
            item['expert'] = {
                'expert_name': r.expert.expert_name,
                'bio': r.expert.bio,
                'avatar': r.expert.avatar,
            }
        items.append(item)
    
    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@admin_task_expert_router.post("/task-expert-profile-update-requests/{request_id}/review")
async def review_profile_update_request(
    request_id: int,
    review_data: schemas.TaskExpertProfileUpdateRequestReview,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核任务达人信息修改请求"""
    try:
        logger.info(f"开始审核信息修改请求 {request_id}, 操作: {review_data.action}, 管理员: {current_admin.id}")
        
        # 1. 获取修改请求（使用FOR UPDATE锁，防止并发）
        request_result = await db.execute(
            select(models.TaskExpertProfileUpdateRequest)
            .where(models.TaskExpertProfileUpdateRequest.id == request_id)
            .where(models.TaskExpertProfileUpdateRequest.status == "pending")
            .with_for_update()  # 并发安全：行级锁
        )
        update_request = request_result.scalar_one_or_none()
        
        if not update_request:
            logger.warning(f"修改请求不存在或已处理: {request_id}")
            raise HTTPException(status_code=404, detail="修改请求不存在或已处理")
        
        # 2. 获取任务达人记录
        expert_result = await db.execute(
            select(models.TaskExpert).where(models.TaskExpert.id == update_request.expert_id)
        )
        expert = expert_result.scalar_one_or_none()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        if review_data.action == "approve":
            # 在 commit() 之前保存 expert_id，避免后续访问 ORM 对象时触发延迟加载
            expert_id_value = update_request.expert_id
            
            # 3. 批准：更新任务达人信息
            if update_request.new_expert_name is not None:
                expert.expert_name = update_request.new_expert_name
            if update_request.new_bio is not None:
                expert.bio = update_request.new_bio
            if update_request.new_avatar is not None:
                expert.avatar = update_request.new_avatar
            expert.updated_at = models.get_utc_time()
            
            # 4. 同步更新 FeaturedTaskExpert（如果存在）
            from sqlalchemy import text
            featured_expert_result = await db.execute(
                text("SELECT id FROM featured_task_experts WHERE user_id = :user_id"),
                {"user_id": expert_id_value}
            )
            featured_expert_row = featured_expert_result.fetchone()
            
            if featured_expert_row:
                # 使用同步数据库会话更新 FeaturedTaskExpert
                from app.database import SessionLocal
                sync_db = SessionLocal()
                try:
                    featured_expert = sync_db.query(models.FeaturedTaskExpert).filter(
                        models.FeaturedTaskExpert.user_id == expert_id_value
                    ).first()
                    if featured_expert:
                        if update_request.new_expert_name is not None:
                            featured_expert.name = update_request.new_expert_name
                        if update_request.new_bio is not None:
                            featured_expert.bio = update_request.new_bio
                        if update_request.new_avatar is not None:
                            featured_expert.avatar = update_request.new_avatar
                        sync_db.commit()
                        sync_db.refresh(featured_expert)
                finally:
                    sync_db.close()
            
            # 5. 更新修改请求状态
            update_request.status = "approved"
            update_request.reviewed_by = current_admin.id
            update_request.reviewed_at = models.get_utc_time()
            update_request.review_comment = review_data.review_comment
            update_request.updated_at = models.get_utc_time()
            
            await db.commit()
            
            # 6. 发送通知给任务达人
            from app.task_notifications import send_expert_profile_update_approved_notification
            try:
                await send_expert_profile_update_approved_notification(db, expert_id_value, request_id)
            except Exception as e:
                logger.error(f"发送通知失败: {e}")
            
            logger.info(f"信息修改请求 {request_id} 已批准")
            return {
                "message": "修改请求已批准",
                "request_id": request_id,
                "expert_id": expert_id_value
            }
        
        elif review_data.action == "reject":
            # 在 commit() 之前保存 expert_id，避免后续访问 ORM 对象时触发延迟加载
            expert_id_value = update_request.expert_id
            
            # 拒绝：只更新请求状态
            update_request.status = "rejected"
            update_request.reviewed_by = current_admin.id
            update_request.reviewed_at = models.get_utc_time()
            update_request.review_comment = review_data.review_comment
            update_request.updated_at = models.get_utc_time()
            
            await db.commit()
            
            # 发送通知给任务达人
            from app.task_notifications import send_expert_profile_update_rejected_notification
            try:
                await send_expert_profile_update_rejected_notification(db, expert_id_value, request_id, review_data.review_comment)
            except Exception as e:
                logger.error(f"发送通知失败: {e}")
            
            logger.info(f"信息修改请求 {request_id} 已拒绝")
            return {
                "message": "修改请求已拒绝",
                "request_id": request_id
            }
        else:
            logger.error(f"无效的操作: {review_data.action}")
            raise HTTPException(status_code=400, detail=f"无效的操作: {review_data.action}")
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"审核信息修改请求 {request_id} 时发生错误: {e}", exc_info=True)
        try:
            await db.rollback()
        except Exception as rollback_error:
            logger.warning(f"Rollback 失败: {rollback_error}")
        raise HTTPException(status_code=500, detail="审核失败，请稍后重试")


"""
管理员任务达人审核API路由
实现管理员审核任务达人申请的相关接口
"""

import logging
from typing import List, Optional
from datetime import datetime, timezone
from app.utils.time_utils import format_iso_utc, get_utc_time
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


@admin_task_expert_router.get("/task-expert-services")
async def get_all_expert_services_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按达人ID筛选"),
    status_filter: Optional[str] = Query(None, description="按状态筛选: pending, active, rejected"),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取全部达人服务列表（管理员），支持分页、按达人与状态筛选"""
    try:
        q = select(models.TaskExpertService)
        if expert_id:
            q = q.where(models.TaskExpertService.expert_id == expert_id)
        if status_filter:
            q = q.where(models.TaskExpertService.status == status_filter)
        count_q = select(func.count()).select_from(q.subquery())
        total_result = await db.execute(count_q)
        total = total_result.scalar() or 0
        offset = (page - 1) * limit
        q = q.order_by(
            models.TaskExpertService.display_order,
            models.TaskExpertService.created_at.desc(),
        ).offset(offset).limit(limit)
        result = await db.execute(q)
        services = result.scalars().all()
        items = []
        for s in services:
            expert_result = await db.execute(
                select(models.TaskExpert).where(models.TaskExpert.id == s.expert_id)
            )
            expert = expert_result.scalar_one_or_none()
            expert_name = (expert.expert_name if expert else None) or s.expert_id or ""
            desc = s.description
            if desc is None:
                desc = ""
            desc_str = str(desc)[:200] if desc else ""
            items.append({
                "id": s.id,
                "expert_id": s.expert_id,
                "expert_name": expert_name,
                "service_name": s.service_name or "",
                "service_name_en": s.service_name_en,
                "service_name_zh": s.service_name_zh,
                "description": desc_str,
                "description_en": (s.description_en or "")[:200] if s.description_en else None,
                "description_zh": (s.description_zh or "")[:200] if s.description_zh else None,
                "images": s.images,
                "base_price": float(s.base_price) if s.base_price is not None else 0,
                "currency": s.currency or "GBP",
                "status": s.status or "active",
                "display_order": s.display_order or 0,
                "view_count": s.view_count or 0,
                "application_count": s.application_count or 0,
                "has_time_slots": getattr(s, "has_time_slots", False) or False,
                "created_at": s.created_at.isoformat() if s.created_at else None,
            })
        return {"items": items, "total": total, "page": page, "limit": limit}
    except Exception as e:
        logger.exception("获取全部达人服务列表失败")
        raise HTTPException(status_code=500, detail=str(e))


@admin_task_expert_router.get("/task-expert-activities")
async def get_all_expert_activities_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    expert_id: Optional[str] = Query(None, description="按达人ID筛选"),
    status_filter: Optional[str] = Query(None, description="按状态筛选"),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取全部达人活动列表（管理员），支持分页与筛选"""
    try:
        q = select(models.Activity).where(
            models.Activity.activity_type == "standard"
        )
        if expert_id:
            q = q.where(models.Activity.expert_id == expert_id)
        if status_filter:
            q = q.where(models.Activity.status == status_filter)
        count_q = select(func.count()).select_from(q.subquery())
        total_result = await db.execute(count_q)
        total = total_result.scalar() or 0
        offset = (page - 1) * limit
        q = q.order_by(models.Activity.created_at.desc()).offset(offset).limit(limit)
        result = await db.execute(q)
        activities = result.scalars().all()
        items = []
        for a in activities:
            expert_result = await db.execute(
                select(models.TaskExpert).where(models.TaskExpert.id == a.expert_id)
            )
            expert = expert_result.scalar_one_or_none()
            expert_name = (expert.expert_name if expert else None) or a.expert_id or ""
            desc = a.description
            desc_str = (str(desc)[:200] if desc else "")
            items.append({
                "id": a.id,
                "expert_id": a.expert_id,
                "expert_name": expert_name,
                "title": a.title or "",
                "description": desc_str,
                "expert_service_id": a.expert_service_id,
                "location": a.location or "",
                "task_type": a.task_type or "",
                "status": a.status or "open",
                "max_participants": a.max_participants or 1,
                "currency": a.currency or "GBP",
                "discounted_price_per_participant": float(a.discounted_price_per_participant) if a.discounted_price_per_participant is not None else None,
                "deadline": a.deadline.isoformat() if a.deadline else None,
                "created_at": a.created_at.isoformat() if a.created_at else None,
            })
        return {"items": items, "total": total, "page": page, "limit": limit}
    except Exception as e:
        logger.exception("获取全部达人活动列表失败")
        raise HTTPException(status_code=500, detail=str(e))


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
    
    # 4. 检查是否已经存在 FeaturedTaskExpert
    # 使用同步数据库会话（因为 FeaturedTaskExpert 是同步模型）
    from app.database import SessionLocal
    
    sync_db = None
    try:
        # 创建同步数据库会话
        sync_db = SessionLocal()
        
        # 检查是否已有精选任务达人记录
        existing_expert = sync_db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == application.user_id
        ).first()
        
        if existing_expert:
            # 如果记录已存在，保留现有头像，不覆盖
            # 这样可以避免部署时重新创建记录导致头像被用户表头像覆盖
            raise HTTPException(status_code=400, detail="该用户已经是特色任务达人")
        
        # 5. 创建特色任务达人记录（FeaturedTaskExpert）
        # 重要：头像永远不要自动从用户表同步，必须由管理员手动设置
        # 创建时使用空字符串，管理员后续可以通过编辑功能设置头像
        import json
        new_featured_expert = models.FeaturedTaskExpert(
            id=application.user_id,  # 使用用户ID作为主键
            user_id=application.user_id,  # 关联到用户ID（与id相同）
            name=user.name or f"用户{application.user_id}",  # 使用用户名
            avatar="",  # 头像必须由管理员手动设置，不自动使用用户头像
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
        
        # ⚠️ 创建后立即更新统计数据（包括完成率）
        try:
            from app import crud
            crud.update_user_statistics(sync_db, application.user_id)
            logger.info(f"已更新特色任务达人 {application.user_id} 的统计数据")
        except Exception as e:
            logger.warning(f"更新特色任务达人统计数据失败: {e}，但不影响创建流程")
        sync_db.refresh(new_featured_expert)
        
        logger.info(f"管理员 {current_admin.id} 为申请 {application_id} 创建了特色任务达人 {new_featured_expert.id}")

        # 同步到新 featured_experts_v2 表
        try:
            from sqlalchemy import text as sa_text
            map_result = sync_db.execute(
                sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
                {"old_id": application.user_id}
            ).first()
            if map_result:
                from app.models_expert import FeaturedExpertV2
                existing_fv2 = sync_db.query(FeaturedExpertV2).filter(
                    FeaturedExpertV2.expert_id == map_result[0]
                ).first()
                if not existing_fv2:
                    sync_db.add(FeaturedExpertV2(
                        expert_id=map_result[0],
                        is_featured=True,
                        display_order=0,
                        created_by=current_admin.id,
                    ))
                    sync_db.commit()
                    logger.info(f"同步创建 featured_experts_v2: {map_result[0]}")
        except Exception as sync_err:
            logger.warning(f"同步 featured_experts_v2 失败: {sync_err}")

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


# ==================== 服务审核 ====================

@admin_task_expert_router.post("/task-expert-services/{service_id}/review")
async def review_expert_service(
    service_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核达人服务（approve → active, reject → rejected）"""
    action = review_data.get("action")
    if action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action 必须是 approve 或 reject")

    result = await db.execute(
        select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    if action == "approve":
        service.status = "active"
    else:
        service.status = "rejected"

    await db.commit()
    return {"message": f"服务已{'批准' if action == 'approve' else '拒绝'}", "status": service.status}


# ==================== 活动审核 ====================

@admin_task_expert_router.post("/task-expert-activities/{activity_id}/review")
async def review_expert_activity(
    activity_id: int,
    review_data: dict,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核达人活动（approve → open, reject → rejected）"""
    action = review_data.get("action")
    if action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action 必须是 approve 或 reject")

    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    if action == "approve":
        activity.status = "open"
    else:
        activity.status = "rejected"

    await db.commit()
    return {"message": f"活动已{'批准' if action == 'approve' else '拒绝'}", "status": activity.status}


"""
用户服务申请管理API路由
实现用户对服务申请的管理接口
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

from app import models, schemas
from app.deps import get_async_db_dependency

logger = logging.getLogger(__name__)

# 创建用户服务申请路由器
user_service_application_router = APIRouter(prefix="/api/users/me", tags=["user-service-applications"])


# 认证依赖
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


@user_service_application_router.get("/service-applications", response_model=schemas.PaginatedResponse)
async def get_my_service_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户获取自己的申请列表"""
    query = select(models.ServiceApplication).where(
        models.ServiceApplication.applicant_id == current_user.id
    )
    
    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
    
    # 获取总数
    count_query = select(func.count(models.ServiceApplication.id)).where(
        models.ServiceApplication.applicant_id == current_user.id
    )
    if status_filter:
        count_query = count_query.where(models.ServiceApplication.status == status_filter)
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(models.ServiceApplication.created_at.desc()).offset(offset).limit(limit)
    
    result = await db.execute(query)
    applications = result.scalars().all()
    
    # 加载关联数据
    items = []
    for app in applications:
        app_dict = schemas.ServiceApplicationOut.model_validate(app).model_dump()
        # 加载服务信息
        service = await db.get(models.TaskExpertService, app.service_id)
        if service:
            app_dict["service_name"] = service.service_name
        # 加载任务达人信息
        expert = await db.get(models.TaskExpert, app.expert_id)
        if expert:
            app_dict["expert_name"] = expert.expert_name
        items.append(app_dict)
    
    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@user_service_application_router.post("/service-applications/{application_id}/respond-counter-offer")
async def respond_to_counter_offer(
    application_id: int,
    request: schemas.AcceptCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户同意/拒绝任务达人的议价（完整校验 + 并发安全）"""
    # 1. 获取申请记录（带锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 2. 权限校验：只能处理自己的申请
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能处理自己的申请")
    
    # 3. 状态校验：必须是negotiating状态
    if application.status != "negotiating":
        raise HTTPException(status_code=400, detail="当前状态不允许此操作")
    
    # 4. 验证申请中有任务达人的议价价格
    if application.expert_counter_price is None:
        raise HTTPException(status_code=400, detail="任务达人尚未提出议价")
    
    if request.accept:
        # 5. 同意议价：更新状态为price_agreed
        application.status = "price_agreed"
        application.final_price = application.expert_counter_price
        application.price_agreed_at = models.get_utc_time()
        application.updated_at = models.get_utc_time()
        
        await db.commit()
        await db.refresh(application)
        
        # 6. 发送通知给任务达人
        from app.task_notifications import send_counter_offer_accepted_notification
        try:
            await send_counter_offer_accepted_notification(
                db=db,
                expert_id=application.expert_id,
                applicant_id=application.applicant_id,
                counter_price=application.expert_counter_price,
                service_id=application.service_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
        
        return {
            "message": "已同意任务达人的议价",
            "application_id": application_id,
            "status": "price_agreed",
            "final_price": float(application.final_price),
        }
    else:
        # 7. 拒绝议价：恢复为pending状态
        application.status = "pending"
        application.expert_counter_price = None  # 清除议价
        application.updated_at = models.get_utc_time()
        
        await db.commit()
        await db.refresh(application)
        
        # 8. 发送通知给任务达人
        from app.task_notifications import send_counter_offer_rejected_notification
        try:
            await send_counter_offer_rejected_notification(
                db=db,
                expert_id=application.expert_id,
                applicant_id=application.applicant_id,
                service_id=application.service_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
        
        return {
            "message": "已拒绝任务达人的议价",
            "application_id": application_id,
            "status": "pending",
        }


@user_service_application_router.post("/service-applications/{application_id}/cancel")
async def cancel_service_application(
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户取消自己的服务申请（完整校验 + 并发安全 + 幂等性）"""
    # 1. 获取申请记录（带锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 2. 权限校验：只能取消自己的申请
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能取消自己的申请")
    
    # 3. 幂等性检查：如果已经是cancelled状态，直接返回
    if application.status == "cancelled":
        return {
            "message": "申请已取消",
            "application_id": application_id,
            "status": "cancelled",
        }
    
    # 4. 状态校验：只能取消特定状态的申请
    allowed_statuses = ["pending", "negotiating", "price_agreed"]
    if application.status not in allowed_statuses:
        raise HTTPException(
            status_code=400, 
            detail=f"当前状态（{application.status}）不允许取消，只能取消以下状态的申请：{', '.join(allowed_statuses)}"
        )
    
    # 5. 更新状态
    application.status = "cancelled"
    application.updated_at = models.get_utc_time()
    
    await db.commit()
    await db.refresh(application)
    
    # 6. 发送通知给任务达人（可选）
    from app.task_notifications import send_service_application_cancelled_notification
    try:
        await send_service_application_cancelled_notification(
            db=db,
            expert_id=application.expert_id,
            applicant_id=application.applicant_id,
            service_id=application.service_id
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return {
        "message": "申请已取消",
        "application_id": application_id,
        "status": "cancelled",
    }


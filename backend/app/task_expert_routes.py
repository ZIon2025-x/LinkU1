"""
任务达人功能API路由
实现任务达人相关的所有接口
"""

import logging
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import select, update, and_, or_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app import models, schemas
from app.deps import get_async_db_dependency
from app.separate_auth_deps import get_current_admin

logger = logging.getLogger(__name__)

# 创建任务达人路由器
task_expert_router = APIRouter(prefix="/api/task-experts", tags=["task-experts"])


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


async def get_current_expert(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.TaskExpert:
    """获取当前用户的任务达人身份"""
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == current_user.id)
    )
    expert = expert.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="您还不是任务达人"
        )
    if expert.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="任务达人账户未激活"
        )
    return expert


# ==================== 任务达人申请相关接口 ====================

@task_expert_router.post("/apply", response_model=schemas.TaskExpertApplicationOut)
async def apply_to_be_expert(
    application_data: schemas.TaskExpertApplicationCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户申请成为任务达人"""
    # 检查是否已有待审核的申请
    existing = await db.execute(
        select(models.TaskExpertApplication)
        .where(models.TaskExpertApplication.user_id == current_user.id)
        .where(models.TaskExpertApplication.status == "pending")
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="您已提交申请，请等待审核"
        )
    
    # 检查是否已经是任务达人
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == current_user.id)
    )
    if expert.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="您已经是任务达人"
        )
    
    # 创建申请
    new_application = models.TaskExpertApplication(
        user_id=current_user.id,
        application_message=application_data.application_message,
        status="pending",
    )
    db.add(new_application)
    await db.commit()
    await db.refresh(new_application)
    
    # 发送通知给管理员
    from app.task_notifications import send_expert_application_notification
    try:
        await send_expert_application_notification(db, current_user.id)
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return new_application


@task_expert_router.get("/my-application", response_model=schemas.TaskExpertApplicationOut)
async def get_my_application(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的申请状态"""
    application = await db.execute(
        select(models.TaskExpertApplication)
        .where(models.TaskExpertApplication.user_id == current_user.id)
        .order_by(models.TaskExpertApplication.created_at.desc())
    )
    application = application.scalar_one_or_none()
    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="未找到申请记录"
        )
    return application


# ==================== 任务达人管理接口 ====================

@task_expert_router.get("", response_model=List[schemas.TaskExpertOut])
async def get_experts_list(
    status_filter: Optional[str] = Query("active", alias="status"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人列表（公开接口）"""
    query = select(models.TaskExpert).where(
        models.TaskExpert.status == status_filter
    )
    
    # 获取总数
    count_query = select(func.count(models.TaskExpert.id)).where(
        models.TaskExpert.status == status_filter
    )
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(
        models.TaskExpert.created_at.desc()
    ).offset(offset).limit(limit)
    
    result = await db.execute(query)
    experts = result.scalars().all()
    
    # 加载关联的用户信息
    items = []
    for expert in experts:
        expert_dict = schemas.TaskExpertOut.model_validate(expert).model_dump()
        # 加载用户信息以获取名称和头像
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, expert.id)
        if user:
            expert_dict["user_name"] = user.name
            expert_dict["user_avatar"] = user.avatar
        items.append(expert_dict)
    
    return items


@task_expert_router.get("/{expert_id}", response_model=schemas.TaskExpertOut)
async def get_expert(
    expert_id: str,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人信息"""
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == expert_id)
    )
    expert = expert.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="任务达人不存在"
        )
    return expert


@task_expert_router.put("/me", response_model=schemas.TaskExpertOut)
async def update_expert_profile(
    expert_data: schemas.TaskExpertUpdate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人更新个人信息（已废弃，请使用 submit_profile_update_request）"""
    # 为了向后兼容，保留此接口，但实际应该使用 submit_profile_update_request
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="此接口已废弃，请使用 POST /api/task-experts/me/profile-update-request 提交修改请求"
    )


@task_expert_router.post("/me/profile-update-request", response_model=schemas.TaskExpertProfileUpdateRequestOut)
async def submit_profile_update_request(
    update_data: schemas.TaskExpertProfileUpdateRequestCreate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人提交信息修改请求（需要管理员审核）"""
    from sqlalchemy.exc import IntegrityError
    
    # 检查是否至少有一个字段需要修改
    if not any([update_data.expert_name, update_data.bio, update_data.avatar]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="至少需要修改一个字段（名字、简介或头像）"
        )
    
    # 检查是否已有待审核的修改请求
    existing_request = await db.execute(
        select(models.TaskExpertProfileUpdateRequest)
        .where(
            models.TaskExpertProfileUpdateRequest.expert_id == current_expert.id,
            models.TaskExpertProfileUpdateRequest.status == "pending"
        )
    )
    if existing_request.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您已有一个待审核的修改请求，请等待审核完成后再提交新的请求"
        )
    
    # 创建修改请求
    new_request = models.TaskExpertProfileUpdateRequest(
        expert_id=current_expert.id,
        new_expert_name=update_data.expert_name,
        new_bio=update_data.bio,
        new_avatar=update_data.avatar,
        status="pending"
    )
    
    db.add(new_request)
    
    try:
        await db.commit()
        
        # 在 commit() 之后，需要重新查询对象以避免 greenlet_spawn 错误
        # 或者手动构建响应数据
        request_result = await db.execute(
            select(models.TaskExpertProfileUpdateRequest)
            .where(models.TaskExpertProfileUpdateRequest.id == new_request.id)
        )
        refreshed_request = request_result.scalar_one()
        
        # 发送通知给管理员
        from app.task_notifications import send_expert_profile_update_notification
        try:
            await send_expert_profile_update_notification(db, current_expert.id, refreshed_request.id)
        except Exception as e:
            logger.error(f"发送通知失败: {e}")
        
        return refreshed_request
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="提交失败，可能存在并发冲突，请重试"
        )


@task_expert_router.get("/me/profile-update-request", response_model=Optional[schemas.TaskExpertProfileUpdateRequestOut])
async def get_my_profile_update_request(
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取当前任务达人的待审核修改请求"""
    request = await db.execute(
        select(models.TaskExpertProfileUpdateRequest)
        .where(
            models.TaskExpertProfileUpdateRequest.expert_id == current_expert.id,
            models.TaskExpertProfileUpdateRequest.status == "pending"
        )
        .order_by(models.TaskExpertProfileUpdateRequest.created_at.desc())
    )
    return request.scalar_one_or_none()


# ==================== 服务菜单管理接口 ====================

@task_expert_router.post("/me/services", response_model=schemas.TaskExpertServiceOut)
async def create_service(
    service_data: schemas.TaskExpertServiceCreate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人创建服务"""
    new_service = models.TaskExpertService(
        expert_id=current_expert.id,
        service_name=service_data.service_name,
        description=service_data.description,
        images=service_data.images,
        base_price=service_data.base_price,
        currency=service_data.currency,
        display_order=service_data.display_order,
        status="active",
    )
    db.add(new_service)
    
    # 更新任务达人的服务总数
    current_expert.total_services += 1
    
    await db.commit()
    await db.refresh(new_service)
    return new_service


@task_expert_router.get("/me/services", response_model=schemas.PaginatedResponse)
async def get_my_services(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人获取自己的服务列表"""
    query = select(models.TaskExpertService).where(
        models.TaskExpertService.expert_id == current_expert.id
    )
    
    if status_filter:
        query = query.where(models.TaskExpertService.status == status_filter)
    
    # 获取总数
    count_query = select(func.count(models.TaskExpertService.id)).where(
        models.TaskExpertService.expert_id == current_expert.id
    )
    if status_filter:
        count_query = count_query.where(models.TaskExpertService.status == status_filter)
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(
        models.TaskExpertService.display_order,
        models.TaskExpertService.created_at.desc()
    ).offset(offset).limit(limit)
    
    result = await db.execute(query)
    services = result.scalars().all()
    
    return {
        "total": total,
        "items": [schemas.TaskExpertServiceOut.from_orm(s) for s in services],
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@task_expert_router.put("/me/services/{service_id}", response_model=schemas.TaskExpertServiceOut)
async def update_service(
    service_id: int,
    service_data: schemas.TaskExpertServiceUpdate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人更新服务"""
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .where(models.TaskExpertService.expert_id == current_expert.id)
    )
    service = service.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在"
        )
    
    if service_data.service_name is not None:
        service.service_name = service_data.service_name
    if service_data.description is not None:
        service.description = service_data.description
    if service_data.images is not None:
        service.images = service_data.images
    if service_data.base_price is not None:
        service.base_price = service_data.base_price
    if service_data.currency is not None:
        service.currency = service_data.currency
    if service_data.status is not None:
        service.status = service_data.status
    if service_data.display_order is not None:
        service.display_order = service_data.display_order
    
    service.updated_at = models.get_utc_time()
    
    await db.commit()
    await db.refresh(service)
    return service


@task_expert_router.delete("/me/services/{service_id}")
async def delete_service(
    service_id: int,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人删除服务"""
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .where(models.TaskExpertService.expert_id == current_expert.id)
    )
    service = service.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在"
        )
    
    await db.delete(service)
    current_expert.total_services = max(0, current_expert.total_services - 1)
    await db.commit()
    
    return {"message": "服务已删除"}


@task_expert_router.get("/{expert_id}/services")
async def get_expert_services(
    expert_id: str,
    status_filter: Optional[str] = Query("active", alias="status"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人的公开服务列表"""
    expert = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == expert_id)
    )
    expert = expert.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="任务达人不存在"
        )
    
    query = select(models.TaskExpertService).where(
        models.TaskExpertService.expert_id == expert_id,
        models.TaskExpertService.status == status_filter
    ).order_by(
        models.TaskExpertService.display_order,
        models.TaskExpertService.created_at.desc()
    )
    
    result = await db.execute(query)
    services = result.scalars().all()
    
    return {
        "expert_id": expert_id,
        "expert_name": expert.expert_name or expert.user.name if hasattr(expert, "user") else None,
        "services": [schemas.TaskExpertServiceOut.model_validate(s).model_dump() for s in services],
    }


@task_expert_router.get("/services/{service_id}", response_model=schemas.TaskExpertServiceOut)
async def get_service_detail(
    service_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情"""
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .options(select(models.TaskExpert).where(models.TaskExpert.id == models.TaskExpertService.expert_id))
    )
    service = service.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在"
        )
    
    # 增加浏览次数
    await db.execute(
        update(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .values(view_count=models.TaskExpertService.view_count + 1)
    )
    await db.commit()
    await db.refresh(service)
    
    return service


# ==================== 服务申请相关接口 ====================

@task_expert_router.post("/services/{service_id}/apply", response_model=schemas.ServiceApplicationOut)
async def apply_for_service(
    service_id: int,
    application_data: schemas.ServiceApplicationCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户申请服务（完整校验 + 并发安全）"""
    # 1. 获取服务信息（带锁，防止并发修改）
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .with_for_update()  # 并发安全：锁定服务记录
    )
    service = service.scalar_one_or_none()
    
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    
    # 2. 校验服务状态必须为active
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架，无法申请")
    
    # 3. 校验用户不能申请自己的服务
    if service.expert_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能申请自己的服务")
    
    # 4. 校验是否已有待处理的申请
    existing = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.service_id == service_id)
        .where(models.ServiceApplication.applicant_id == current_user.id)
        .where(models.ServiceApplication.status.in_(["pending", "negotiating", "price_agreed"]))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="您已申请过此服务，请等待处理")
    
    # 5. 校验议价价格
    if application_data.negotiated_price is not None:
        if application_data.negotiated_price <= 0:
            raise HTTPException(status_code=400, detail="议价价格必须大于0")
        # 设置最低价为基础价格的50%
        min_price = service.base_price * Decimal('0.5')
        if application_data.negotiated_price < min_price:
            raise HTTPException(
                status_code=400, 
                detail=f"议价价格不能低于基础价格的50%（最低{min_price}）"
            )
    
    # 6. 创建申请记录
    new_application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        expert_id=service.expert_id,
        application_message=application_data.application_message,
        negotiated_price=application_data.negotiated_price,
        currency=application_data.currency,
        status="pending",
    )
    db.add(new_application)
    
    # 7. 更新服务统计：申请时+1（原子更新，避免并发丢失）
    try:
        await db.execute(
            update(models.TaskExpertService)
            .where(models.TaskExpertService.id == service_id)
            .values(application_count=models.TaskExpertService.application_count + 1)
        )
        
        await db.commit()
        await db.refresh(new_application)
    except IntegrityError:
        await db.rollback()
        # 部分唯一索引冲突：并发情况下可能同时创建申请
        raise HTTPException(
            status_code=409, 
            detail="您已申请过此服务，请等待处理（并发冲突）"
        )
    
    # 8. 发送通知给任务达人
    from app.task_notifications import send_service_application_notification
    try:
        await send_service_application_notification(
            db=db,
            expert_id=service.expert_id,
            applicant_id=current_user.id,
            service_id=service_id,
            service_name=service.service_name,
            negotiated_price=application_data.negotiated_price
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return new_application


@task_expert_router.get("/me/applications", response_model=schemas.PaginatedResponse)
async def get_my_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    service_id: Optional[int] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人获取收到的申请列表"""
    query = select(models.ServiceApplication).where(
        models.ServiceApplication.expert_id == current_expert.id
    )
    
    if status_filter:
        query = query.where(models.ServiceApplication.status == status_filter)
    if service_id:
        query = query.where(models.ServiceApplication.service_id == service_id)
    
    # 获取总数
    count_query = select(func.count(models.ServiceApplication.id)).where(
        models.ServiceApplication.expert_id == current_expert.id
    )
    if status_filter:
        count_query = count_query.where(models.ServiceApplication.status == status_filter)
    if service_id:
        count_query = count_query.where(models.ServiceApplication.service_id == service_id)
    
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
        # 加载申请用户信息
        from app import async_crud
        applicant = await async_crud.async_user_crud.get_user_by_id(db, app.applicant_id)
        if applicant:
            app_dict["applicant_name"] = applicant.name
        items.append(app_dict)
    
    return {
        "total": total,
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


@task_expert_router.post("/applications/{application_id}/counter-offer", response_model=schemas.ServiceApplicationOut)
async def counter_offer_service_application(
    application_id: int,
    counter_offer: schemas.CounterOfferRequest,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人再次议价（完整校验 + 并发安全）"""
    # 1. 获取申请（带锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 2. 校验必须是任务达人本人
    if application.expert_id != current_expert.id:
        raise HTTPException(status_code=403, detail="只能处理自己的服务申请")
    
    # 3. 校验状态
    if application.status not in ["pending", "negotiating"]:
        raise HTTPException(status_code=400, detail="当前状态不允许议价")
    
    # 4. 校验议价价格
    if counter_offer.counter_price <= 0:
        raise HTTPException(status_code=400, detail="议价价格必须大于0")
    
    # 5. 更新申请记录
    application.status = "negotiating"
    application.expert_counter_price = counter_offer.counter_price
    application.updated_at = models.get_utc_time()
    
    await db.commit()
    await db.refresh(application)
    
    # 6. 发送通知给申请用户
    from app.task_notifications import send_counter_offer_notification
    try:
        await send_counter_offer_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=application.expert_id,
            counter_price=counter_offer.counter_price,
            message=counter_offer.message
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return application


@task_expert_router.post("/applications/{application_id}/approve")
async def approve_service_application(
    application_id: int,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人同意申请（创建任务）"""
    # 1. 获取申请记录（使用FOR UPDATE锁，防止并发）
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .where(models.ServiceApplication.expert_id == current_expert.id)
        .with_for_update()  # 并发安全：行级锁
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    # 幂等性检查：如果已创建任务，直接返回
    if application.status == "approved" and application.task_id:
        task = await db.get(models.Task, application.task_id)
        return {
            "message": "任务已创建",
            "application_id": application_id,
            "task_id": application.task_id,
            "task": task,
        }
    
    # 2. 校验状态：仅允许pending或price_agreed状态创建任务
    if application.status not in ("pending", "price_agreed"):
        raise HTTPException(status_code=409, detail="当前状态不允许创建任务")
    
    # 3. 获取服务信息
    service = await db.get(models.TaskExpertService, application.service_id)
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    
    # 3.1 校验服务状态必须为active
    if service.status != "active":
        raise HTTPException(status_code=400, detail="服务未上架，无法创建任务")
    
    # 4. 确定最终价格
    if application.status == "price_agreed":
        # 用户已同意任务达人的议价，使用任务达人的议价价格
        if application.expert_counter_price is None:
            raise HTTPException(status_code=400, detail="议价价格不存在")
        price = float(application.expert_counter_price)
    elif application.negotiated_price is not None:
        # 用户提出的议价价格
        price = float(application.negotiated_price)
    else:
        # 使用服务基础价格
        price = float(service.base_price)
    
    # 5. 创建任务
    # 设置截止日期（默认7天后）
    deadline = models.get_utc_time() + timedelta(days=7)
    
    # 处理图片（JSONB类型，直接使用list）
    images_list = service.images if service.images else None
    
    new_task = models.Task(
        title=service.service_name,
        description=service.description,
        deadline=deadline,
        reward=price,
        base_reward=service.base_price,
        agreed_reward=price,
        currency=application.currency or service.currency,
        location="线上",  # 任务达人服务默认线上
        task_type="其他",
        poster_id=application.applicant_id,  # 申请用户是发布人
        taker_id=application.expert_id,  # 任务达人接收方
        status="in_progress",
        images=images_list,  # 直接使用list，ORM会自动处理JSONB序列化
        accepted_at=models.get_utc_time()
    )
    
    db.add(new_task)
    await db.flush()  # 获取任务ID
    
    # 6. 更新申请记录
    application.status = "approved"
    application.final_price = price
    application.task_id = new_task.id
    application.approved_at = models.get_utc_time()
    application.updated_at = models.get_utc_time()
    
    await db.commit()
    await db.refresh(new_task)
    
    # 7. 发送通知给申请用户（任务已创建）
    from app.task_notifications import send_service_application_approved_notification
    try:
        await send_service_application_approved_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=application.expert_id,
            task_id=new_task.id,
            service_name=service.service_name
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return {
        "message": "申请已同意，任务已创建",
        "application_id": application_id,
        "task_id": new_task.id,
        "task": new_task,
    }


@task_expert_router.post("/applications/{application_id}/reject")
async def reject_service_application(
    application_id: int,
    reject_data: schemas.ServiceApplicationRejectRequest,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人拒绝申请"""
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .where(models.ServiceApplication.expert_id == current_expert.id)
        .with_for_update()
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    if application.status != "pending":
        raise HTTPException(status_code=400, detail="只能拒绝待处理的申请")
    
    application.status = "rejected"
    application.rejected_at = models.get_utc_time()
    application.updated_at = models.get_utc_time()
    
    await db.commit()
    
    # 发送通知给申请用户
    from app.task_notifications import send_service_application_rejected_notification
    try:
        await send_service_application_rejected_notification(
            db=db,
            applicant_id=application.applicant_id,
            expert_id=application.expert_id,
            service_id=application.service_id,
            reject_reason=reject_data.reject_reason
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    return {
        "message": "申请已拒绝",
        "application_id": application_id,
    }


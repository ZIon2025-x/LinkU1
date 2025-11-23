"""
任务达人功能API路由
实现任务达人相关的所有接口
"""

import logging
from datetime import datetime, timedelta, timezone, date, time as dt_time
from decimal import Decimal
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
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
    from datetime import time as dt_time
    
    # 验证时间段相关字段
    if service_data.has_time_slots:
        if not service_data.time_slot_duration_minutes or not service_data.time_slot_start_time or not service_data.time_slot_end_time or not service_data.participants_per_slot:
            raise HTTPException(
                status_code=400,
                detail="启用时间段时，必须提供时间段时长、开始时间、结束时间和参与者数量"
            )
        # 验证时间格式
        try:
            start_time = dt_time.fromisoformat(service_data.time_slot_start_time)
            end_time = dt_time.fromisoformat(service_data.time_slot_end_time)
            if start_time >= end_time:
                raise HTTPException(status_code=400, detail="开始时间必须早于结束时间")
        except ValueError:
            raise HTTPException(status_code=400, detail="时间格式错误，应为HH:MM:SS")
    
    new_service = models.TaskExpertService(
        expert_id=current_expert.id,
        service_name=service_data.service_name,
        description=service_data.description,
        images=service_data.images,
        base_price=service_data.base_price,
        currency=service_data.currency,
        display_order=service_data.display_order,
        status="active",
        has_time_slots=service_data.has_time_slots,
        time_slot_duration_minutes=service_data.time_slot_duration_minutes,
        time_slot_start_time=dt_time.fromisoformat(service_data.time_slot_start_time) if service_data.time_slot_start_time else None,
        time_slot_end_time=dt_time.fromisoformat(service_data.time_slot_end_time) if service_data.time_slot_end_time else None,
        participants_per_slot=service_data.participants_per_slot,
    )
    db.add(new_service)
    
    # 更新任务达人的服务总数
    current_expert.total_services += 1
    
    await db.commit()
    await db.refresh(new_service)
    return schemas.TaskExpertServiceOut.from_orm(new_service)


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
    from datetime import time as dt_time
    
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
    
    # 更新时间段相关字段
    if service_data.has_time_slots is not None:
        service.has_time_slots = service_data.has_time_slots
        if service_data.has_time_slots:
            # 启用时间段时，验证必填字段
            if not service_data.time_slot_duration_minutes or not service_data.time_slot_start_time or not service_data.time_slot_end_time or not service_data.participants_per_slot:
                raise HTTPException(
                    status_code=400,
                    detail="启用时间段时，必须提供时间段时长、开始时间、结束时间和参与者数量"
                )
            # 验证时间格式
            try:
                start_time = dt_time.fromisoformat(service_data.time_slot_start_time)
                end_time = dt_time.fromisoformat(service_data.time_slot_end_time)
                if start_time >= end_time:
                    raise HTTPException(status_code=400, detail="开始时间必须早于结束时间")
                service.time_slot_start_time = start_time
                service.time_slot_end_time = end_time
            except ValueError:
                raise HTTPException(status_code=400, detail="时间格式错误，应为HH:MM:SS")
        else:
            # 禁用时间段时，清除相关字段
            service.time_slot_duration_minutes = None
            service.time_slot_start_time = None
            service.time_slot_end_time = None
            service.participants_per_slot = None
    
    if service_data.time_slot_duration_minutes is not None:
        service.time_slot_duration_minutes = service_data.time_slot_duration_minutes
    if service_data.time_slot_start_time is not None:
        try:
            service.time_slot_start_time = dt_time.fromisoformat(service_data.time_slot_start_time)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始时间格式错误，应为HH:MM:SS")
    if service_data.time_slot_end_time is not None:
        try:
            service.time_slot_end_time = dt_time.fromisoformat(service_data.time_slot_end_time)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束时间格式错误，应为HH:MM:SS")
    if service_data.participants_per_slot is not None:
        service.participants_per_slot = service_data.participants_per_slot
    if service_data.currency is not None:
        service.currency = service_data.currency
    if service_data.status is not None:
        service.status = service_data.status
    if service_data.display_order is not None:
        service.display_order = service_data.display_order
    
    service.updated_at = models.get_utc_time()
    
    await db.commit()
    await db.refresh(service)
    return schemas.TaskExpertServiceOut.from_orm(service)


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
    
    # 保存服务图片URL，用于后续删除
    service_images = service.images if hasattr(service, 'images') and service.images else []
    expert_id = current_expert.id
    
    await db.delete(service)
    current_expert.total_services = max(0, current_expert.total_services - 1)
    await db.commit()
    
    # 删除服务的所有图片
    if service_images:
        from app.image_cleanup import delete_service_images
        try:
            # 如果images是JSONB类型，可能需要解析
            import json
            if isinstance(service_images, str):
                image_urls = json.loads(service_images)
            elif isinstance(service_images, list):
                image_urls = service_images
            else:
                image_urls = []
            
            delete_service_images(expert_id, service_id, image_urls)
        except Exception as e:
            logger.warning(f"删除服务图片失败: {e}")
    
    return {"message": "服务已删除"}


# ==================== 服务时间段管理接口 ====================

@task_expert_router.post("/me/services/{service_id}/time-slots", response_model=schemas.ServiceTimeSlotOut)
async def create_service_time_slot(
    service_id: int,
    time_slot_data: schemas.ServiceTimeSlotCreate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务达人创建服务时间段"""
    # 验证服务是否存在且属于当前任务达人
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
    
    # 验证服务是否启用了时间段
    if not service.has_time_slots:
        raise HTTPException(
            status_code=400, detail="该服务未启用时间段功能"
        )
    
    # 解析日期和时间
    try:
        slot_date = date.fromisoformat(time_slot_data.slot_date)
        start_time = dt_time.fromisoformat(time_slot_data.start_time)
        end_time = dt_time.fromisoformat(time_slot_data.end_time)
        
        if start_time >= end_time:
            raise HTTPException(status_code=400, detail="开始时间必须早于结束时间")
        
        # 验证时间段是否在服务的允许时间范围内
        if service.time_slot_start_time and service.time_slot_end_time:
            if start_time < service.time_slot_start_time or end_time > service.time_slot_end_time:
                raise HTTPException(
                    status_code=400,
                    detail=f"时间段必须在 {service.time_slot_start_time.strftime('%H:%M')} 到 {service.time_slot_end_time.strftime('%H:%M')} 之间"
                )
        
        # 验证时间段时长是否符合设置
        if service.time_slot_duration_minutes:
            duration_minutes = (end_time.hour * 60 + end_time.minute) - (start_time.hour * 60 + start_time.minute)
            if duration_minutes != service.time_slot_duration_minutes:
                raise HTTPException(
                    status_code=400,
                    detail=f"时间段时长必须为 {service.time_slot_duration_minutes} 分钟"
                )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"日期或时间格式错误: {str(e)}")
    
    # 检查是否已存在相同的时间段
    existing_slot = await db.execute(
        select(models.ServiceTimeSlot)
        .where(models.ServiceTimeSlot.service_id == service_id)
        .where(models.ServiceTimeSlot.slot_date == slot_date)
        .where(models.ServiceTimeSlot.start_time == start_time)
        .where(models.ServiceTimeSlot.end_time == end_time)
    )
    if existing_slot.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该时间段已存在")
    
    # 创建时间段
    new_time_slot = models.ServiceTimeSlot(
        service_id=service_id,
        slot_date=slot_date,
        start_time=start_time,
        end_time=end_time,
        price_per_participant=time_slot_data.price_per_participant,
        max_participants=time_slot_data.max_participants,
        current_participants=0,
        is_available=True,
    )
    db.add(new_time_slot)
    await db.commit()
    await db.refresh(new_time_slot)
    return schemas.ServiceTimeSlotOut.from_orm(new_time_slot)


@task_expert_router.get("/me/services/{service_id}/time-slots", response_model=List[schemas.ServiceTimeSlotOut])
async def get_service_time_slots(
    service_id: int,
    start_date: Optional[str] = Query(None, description="开始日期，格式：YYYY-MM-DD"),
    end_date: Optional[str] = Query(None, description="结束日期，格式：YYYY-MM-DD"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务的时间段列表"""
    # 验证服务是否存在且属于当前任务达人
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
    
    # 构建查询
    query = select(models.ServiceTimeSlot).where(
        models.ServiceTimeSlot.service_id == service_id
    )
    
    if start_date:
        try:
            start = date.fromisoformat(start_date)
            query = query.where(models.ServiceTimeSlot.slot_date >= start)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    
    if end_date:
        try:
            end = date.fromisoformat(end_date)
            query = query.where(models.ServiceTimeSlot.slot_date <= end)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")
    
    # 按日期和时间排序
    query = query.order_by(
        models.ServiceTimeSlot.slot_date.asc(),
        models.ServiceTimeSlot.start_time.asc()
    )
    
    result = await db.execute(query)
    time_slots = result.scalars().all()
    
    # 转换为输出格式
    return [schemas.ServiceTimeSlotOut.from_orm(slot) for slot in time_slots]


@task_expert_router.put("/me/services/{service_id}/time-slots/{time_slot_id}", response_model=schemas.ServiceTimeSlotOut)
async def update_service_time_slot(
    service_id: int,
    time_slot_id: int,
    time_slot_data: schemas.ServiceTimeSlotUpdate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新服务时间段"""
    # 验证服务是否存在且属于当前任务达人
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
    
    # 验证时间段是否存在且属于该服务
    time_slot = await db.execute(
        select(models.ServiceTimeSlot)
        .where(models.ServiceTimeSlot.id == time_slot_id)
        .where(models.ServiceTimeSlot.service_id == service_id)
    )
    time_slot = time_slot.scalar_one_or_none()
    if not time_slot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="时间段不存在"
        )
    
    # 更新字段
    if time_slot_data.price_per_participant is not None:
        time_slot.price_per_participant = time_slot_data.price_per_participant
    if time_slot_data.max_participants is not None:
        if time_slot_data.max_participants < time_slot.current_participants:
            raise HTTPException(
                status_code=400,
                detail=f"最多参与者数量不能小于当前参与者数量（{time_slot.current_participants}）"
            )
        time_slot.max_participants = time_slot_data.max_participants
    if time_slot_data.is_available is not None:
        time_slot.is_available = time_slot_data.is_available
    
    await db.commit()
    await db.refresh(time_slot)
    return schemas.ServiceTimeSlotOut.from_orm(time_slot)


@task_expert_router.delete("/me/services/{service_id}/time-slots/{time_slot_id}")
async def delete_service_time_slot(
    service_id: int,
    time_slot_id: int,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除服务时间段"""
    # 验证服务是否存在且属于当前任务达人
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
    
    # 验证时间段是否存在且属于该服务
    time_slot = await db.execute(
        select(models.ServiceTimeSlot)
        .where(models.ServiceTimeSlot.id == time_slot_id)
        .where(models.ServiceTimeSlot.service_id == service_id)
    )
    time_slot = time_slot.scalar_one_or_none()
    if not time_slot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="时间段不存在"
        )
    
    # 检查是否有已申请的参与者
    if time_slot.current_participants > 0:
        raise HTTPException(
            status_code=400,
            detail="该时间段已有参与者，无法删除"
        )
    
    await db.delete(time_slot)
    await db.commit()
    
    return {"message": "时间段已删除"}


@task_expert_router.post("/me/services/{service_id}/time-slots/batch-create")
async def batch_create_service_time_slots(
    service_id: int,
    start_date: str = Query(..., description="开始日期，格式：YYYY-MM-DD"),
    end_date: str = Query(..., description="结束日期，格式：YYYY-MM-DD"),
    price_per_participant: Decimal = Query(..., description="每个参与者的价格"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """批量创建服务时间段（根据服务的设置自动生成）"""
    # 验证服务是否存在且属于当前任务达人
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
    
    # 验证服务是否启用了时间段
    if not service.has_time_slots:
        raise HTTPException(
            status_code=400, detail="该服务未启用时间段功能"
        )
    
    if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
        raise HTTPException(
            status_code=400, detail="服务的时间段配置不完整"
        )
    
    # 解析日期
    try:
        start = date.fromisoformat(start_date)
        end = date.fromisoformat(end_date)
        if start > end:
            raise HTTPException(status_code=400, detail="开始日期必须早于或等于结束日期")
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
    
    # 生成时间段
    created_slots = []
    current_date = start
    slot_start_time = service.time_slot_start_time
    slot_end_time = service.time_slot_end_time
    duration_minutes = service.time_slot_duration_minutes
    
    while current_date <= end:
        # 计算该日期的时间段
        current_time = slot_start_time
        while current_time < slot_end_time:
            # 计算结束时间
            total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
            end_hour = total_minutes // 60
            end_minute = total_minutes % 60
            if end_hour >= 24:
                break  # 超出一天，跳过
            
            slot_end = dt_time(end_hour, end_minute)
            if slot_end > slot_end_time:
                break  # 超出服务允许的结束时间
            
            # 检查是否已存在
            existing = await db.execute(
                select(models.ServiceTimeSlot)
                .where(models.ServiceTimeSlot.service_id == service_id)
                .where(models.ServiceTimeSlot.slot_date == current_date)
                .where(models.ServiceTimeSlot.start_time == current_time)
                .where(models.ServiceTimeSlot.end_time == slot_end)
            )
            if not existing.scalar_one_or_none():
                # 创建新时间段
                new_slot = models.ServiceTimeSlot(
                    service_id=service_id,
                    slot_date=current_date,
                    start_time=current_time,
                    end_time=slot_end,
                    price_per_participant=price_per_participant,
                    max_participants=service.participants_per_slot,
                    current_participants=0,
                    is_available=True,
                )
                db.add(new_slot)
                created_slots.append(new_slot)
            
            # 移动到下一个时间段
            total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
            next_hour = total_minutes // 60
            next_minute = total_minutes % 60
            if next_hour >= 24:
                break
            current_time = dt_time(next_hour, next_minute)
        
        # 移动到下一天
        current_date += timedelta(days=1)
    
    await db.commit()
    
    # 刷新所有创建的时间段
    for slot in created_slots:
        await db.refresh(slot)
    
    return {
        "message": f"成功创建 {len(created_slots)} 个时间段",
        "created_count": len(created_slots),
        "time_slots": [schemas.ServiceTimeSlotOut.from_orm(s) for s in created_slots]
    }


# 注意：更具体的路由必须放在通用路由之前
# 否则 FastAPI 可能会将 /services/123 匹配到 /{expert_id}/services

# 公开接口：获取服务的时间段列表（无需认证）
@task_expert_router.get("/services/{service_id}/time-slots", response_model=List[schemas.ServiceTimeSlotOut])
async def get_service_time_slots_public(
    service_id: int,
    start_date: Optional[str] = Query(None, description="开始日期，格式：YYYY-MM-DD"),
    end_date: Optional[str] = Query(None, description="结束日期，格式：YYYY-MM-DD"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务的公开时间段列表（无需认证）"""
    # 验证服务是否存在
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
        .where(models.TaskExpertService.status == "active")  # 只返回上架的服务
    )
    service = service.scalar_one_or_none()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="服务不存在或未上架"
        )
    
    # 验证服务是否启用了时间段
    if not service.has_time_slots:
        return []  # 如果服务未启用时间段，返回空列表
    
    # 构建查询
    query = select(models.ServiceTimeSlot).where(
        models.ServiceTimeSlot.service_id == service_id,
        models.ServiceTimeSlot.is_available == True  # 只返回可用的时间段
    )
    
    if start_date:
        try:
            start = date.fromisoformat(start_date)
            query = query.where(models.ServiceTimeSlot.slot_date >= start)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    
    if end_date:
        try:
            end = date.fromisoformat(end_date)
            query = query.where(models.ServiceTimeSlot.slot_date <= end)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")
    
    # 按日期和时间排序
    query = query.order_by(
        models.ServiceTimeSlot.slot_date.asc(),
        models.ServiceTimeSlot.start_time.asc()
    )
    
    result = await db.execute(query)
    time_slots = result.scalars().all()
    
    # 转换为输出格式
    return [schemas.ServiceTimeSlotOut.from_orm(slot) for slot in time_slots]


@task_expert_router.get("/services/{service_id}", response_model=schemas.TaskExpertServiceOut)
async def get_service_detail(
    service_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情"""
    service = await db.execute(
        select(models.TaskExpertService)
        .where(models.TaskExpertService.id == service_id)
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
    
    return schemas.TaskExpertServiceOut.from_orm(service)


# 获取任务达人的公开服务列表（放在 /services/{service_id} 之后，避免路由冲突）
@task_expert_router.get("/{expert_id}/services")
async def get_expert_services(
    expert_id: str,
    status_filter: Optional[str] = Query("active", alias="status"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人的公开服务列表"""
    try:
        expert = await db.execute(
            select(models.TaskExpert).where(models.TaskExpert.id == expert_id)
        )
        expert = expert.scalar_one_or_none()
        if not expert:
            logger.warning(f"任务达人不存在: {expert_id}")
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
            "expert_name": expert.expert_name or (expert.user.name if hasattr(expert, "user") and expert.user else None),
            "services": [schemas.TaskExpertServiceOut.from_orm(s) for s in services],
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人服务列表失败: {expert_id}, 错误: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取服务列表失败"
        )


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
    
    # 6. 如果服务启用了时间段，验证时间段
    time_slot = None
    if service.has_time_slots:
        if not application_data.time_slot_id:
            raise HTTPException(status_code=400, detail="该服务需要选择时间段")
        
        # 验证时间段是否存在且属于该服务
        time_slot = await db.execute(
            select(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == application_data.time_slot_id)
            .where(models.ServiceTimeSlot.service_id == service_id)
        )
        time_slot = time_slot.scalar_one_or_none()
        
        if not time_slot:
            raise HTTPException(status_code=404, detail="时间段不存在")
        
        # 验证时间段是否可用
        if not time_slot.is_available:
            raise HTTPException(status_code=400, detail="该时间段不可用")
        
        # 验证时间段是否已满
        if time_slot.current_participants >= time_slot.max_participants:
            raise HTTPException(status_code=400, detail="该时间段已满")
    
    # 7. 校验截至日期（如果服务未启用时间段）
    if not service.has_time_slots:
        if application_data.is_flexible == 1:
            # 灵活模式，不需要截至日期
            deadline = None
        elif application_data.deadline is None:
            raise HTTPException(status_code=400, detail="非灵活模式必须提供截至日期")
        else:
            # 验证截至日期不能早于当前时间
            if application_data.deadline < models.get_utc_time():
                raise HTTPException(status_code=400, detail="截至日期不能早于当前时间")
            deadline = application_data.deadline
    else:
        # 如果服务启用了时间段，不需要截至日期（时间段已经包含了日期信息）
        deadline = None
    
    # 8. 创建申请记录
    new_application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        expert_id=service.expert_id,
        time_slot_id=application_data.time_slot_id,
        application_message=application_data.application_message,
        negotiated_price=application_data.negotiated_price,
        currency=application_data.currency,
        deadline=deadline,
        is_flexible=application_data.is_flexible or 0,
        status="pending",
    )
    db.add(new_application)
    
    # 9. 如果选择了时间段，更新时间段的参与者数量（在提交前更新，避免并发问题）
    if time_slot:
        await db.execute(
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == time_slot.id)
            .values(current_participants=models.ServiceTimeSlot.current_participants + 1)
        )
    
    # 10. 更新服务统计：申请时+1（原子更新，避免并发丢失）
    try:
        await db.execute(
            update(models.TaskExpertService)
            .where(models.TaskExpertService.id == service_id)
            .values(application_count=models.TaskExpertService.application_count + 1)
        )
        
        await db.commit()
        # ⚠️ 在异步上下文中，需要重新查询对象以确保所有属性都被正确加载
        # 避免 MissingGreenlet 错误（惰性加载的关系属性）
        await db.refresh(new_application)
        # 重新查询以确保所有属性都被加载
        refreshed_application = await db.execute(
            select(models.ServiceApplication)
            .where(models.ServiceApplication.id == new_application.id)
        )
        new_application = refreshed_application.scalar_one()
    except IntegrityError:
        await db.rollback()
        # 部分唯一索引冲突：并发情况下可能同时创建申请
        raise HTTPException(
            status_code=409, 
            detail="您已申请过此服务，请等待处理（并发冲突）"
        )
    
    # 11. 发送通知给任务达人
    from app.task_notifications import send_service_application_notification
    try:
        await send_service_application_notification(
            db=db,
            expert_id=service.expert_id,
            applicant_id=current_user.id,
            service_id=service_id,
            service_name=service.service_name,
            negotiated_price=application_data.negotiated_price,
            service_description=service.description,
            base_price=service.base_price,
            application_message=application_data.application_message,
            currency=application_data.currency or service.currency,
            deadline=deadline,
            is_flexible=(application_data.is_flexible == 1),
            application_time=new_application.created_at
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
    
    # ⚠️ 确保所有属性都被访问，避免惰性加载问题
    # 访问所有可能被响应模型使用的属性
    _ = (
        new_application.id,
        new_application.service_id,
        new_application.applicant_id,
        new_application.expert_id,
        new_application.time_slot_id,
        new_application.application_message,
        new_application.negotiated_price,
        new_application.expert_counter_price,
        new_application.currency,
        new_application.status,
        new_application.final_price,
        new_application.task_id,
        new_application.deadline,
        new_application.is_flexible,
        new_application.created_at,
        new_application.approved_at,
        new_application.price_agreed_at,
    )
    
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
            service_id=application.service_id,
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
    
    # 5. 获取任务达人的位置信息
    # 优先从 FeaturedTaskExpert 获取 location，如果没有则从 User 的 residence_city 获取
    location = None
    featured_expert = await db.get(models.FeaturedTaskExpert, application.expert_id)
    if featured_expert and featured_expert.location:
        location = featured_expert.location.strip() if featured_expert.location else None
    
    # 如果 FeaturedTaskExpert 没有 location，从 User 表获取 residence_city
    if not location:
        from app import async_crud
        expert_user = await async_crud.async_user_crud.get_user_by_id(db, application.expert_id)
        if expert_user and expert_user.residence_city:
            location = expert_user.residence_city.strip() if expert_user.residence_city else None
    
    # 如果仍然没有 location，使用默认值 "线上"
    if not location:
        location = "线上"
    # 如果 location 是 "Online" 或 "线上"（不区分大小写），统一为 "线上"
    elif location.lower() in ["online", "线上"]:
        location = "线上"
    
    # 6. 确定任务的截止日期
    # 如果申请是灵活的，则没有截止日期；否则使用申请中的截止日期
    if application.is_flexible == 1:
        task_deadline = None
    elif application.deadline:
        task_deadline = application.deadline
    else:
        # 如果没有设置截止日期且不是灵活模式，默认7天后
        task_deadline = models.get_utc_time() + timedelta(days=7)
    
    # 7. 处理图片（JSONB类型，直接使用list）
    images_list = service.images if service.images else None
    
    # 8. 创建任务（任务达人服务创建的任务等级为 expert）
    new_task = models.Task(
        title=service.service_name,
        description=service.description,
        deadline=task_deadline,
        is_flexible=application.is_flexible or 0,  # 设置灵活时间标识
        reward=price,
        base_reward=service.base_price,
        agreed_reward=price,
        currency=application.currency or service.currency,
        location=location,  # 使用任务达人的位置
        task_type="其他",
        task_level="expert",  # 任务达人服务创建的任务等级为 expert
        poster_id=application.applicant_id,  # 申请用户是发布人
        taker_id=application.expert_id,  # 任务达人接收方
        status="in_progress",
        images=images_list,  # 直接使用list，ORM会自动处理JSONB序列化
        accepted_at=models.get_utc_time()
    )
    
    db.add(new_task)
    await db.flush()  # 获取任务ID
    
    # 9. 更新申请记录
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
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """任务达人拒绝申请"""
    # ⚠️ 性能优化：移除 with_for_update()，拒绝操作不需要锁定
    application = await db.execute(
        select(models.ServiceApplication)
        .where(models.ServiceApplication.id == application_id)
        .where(models.ServiceApplication.expert_id == current_expert.id)
    )
    application = application.scalar_one_or_none()
    
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    
    if application.status != "pending":
        raise HTTPException(status_code=400, detail="只能拒绝待处理的申请")
    
    # 保存通知所需的数据（在更新状态前）
    applicant_id = application.applicant_id
    expert_id = application.expert_id
    service_id = application.service_id
    reject_reason = reject_data.reject_reason
    
    application.status = "rejected"
    application.rejected_at = models.get_utc_time()
    application.updated_at = models.get_utc_time()
    
    await db.commit()
    
    # ⚠️ 性能优化：将通知发送改为后台任务，不阻塞响应
    # 使用 asyncio.create_task 在后台异步执行，不等待完成
    from app.task_notifications import send_service_application_rejected_notification
    import asyncio
    
    async def send_notification_background():
        """后台发送通知（不阻塞主响应）"""
        # 创建新的数据库会话用于后台任务
        from app.database import AsyncSessionLocal
        async with AsyncSessionLocal() as async_db:
            try:
                await send_service_application_rejected_notification(
                    db=async_db,
                    applicant_id=applicant_id,
                    expert_id=expert_id,
                    service_id=service_id,
                    reject_reason=reject_reason
                )
            except Exception as e:
                logger.error(f"Failed to send notification in background: {e}")
    
    # 在后台执行通知发送，不阻塞响应
    asyncio.create_task(send_notification_background())
    
    return {
        "message": "申请已拒绝",
        "application_id": application_id,
    }


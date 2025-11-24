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
from app.utils.time_utils import get_utc_time

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
        # 检查是否使用按周几配置
        has_weekly_config = service_data.weekly_time_slot_config and isinstance(service_data.weekly_time_slot_config, dict)
        
        if has_weekly_config:
            # 使用按周几配置：只需要时间段时长和参与者数量
            if not service_data.time_slot_duration_minutes or not service_data.participants_per_slot:
                raise HTTPException(
                    status_code=400,
                    detail="启用时间段时，必须提供时间段时长和参与者数量"
                )
        else:
            # 使用统一时间配置：需要时间段时长、开始时间、结束时间和参与者数量
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
        weekly_time_slot_config=service_data.weekly_time_slot_config,
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
    
    # 保存旧配置，用于后续比较
    old_weekly_config = service.weekly_time_slot_config if service.weekly_time_slot_config else None
    old_has_time_slots = service.has_time_slots
    
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
            # 检查是否使用按周几配置
            has_weekly_config = service_data.weekly_time_slot_config and isinstance(service_data.weekly_time_slot_config, dict)
            
            if has_weekly_config:
                # 使用按周几配置：只需要时间段时长和参与者数量
                if not service_data.time_slot_duration_minutes or not service_data.participants_per_slot:
                    raise HTTPException(
                        status_code=400,
                        detail="启用时间段时，必须提供时间段时长和参与者数量"
                    )
            else:
                # 使用统一时间配置：需要时间段时长、开始时间、结束时间和参与者数量
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
            service.weekly_time_slot_config = None
    
    # 更新其他时间段相关字段（如果单独提供）
    if service_data.time_slot_duration_minutes is not None:
        service.time_slot_duration_minutes = service_data.time_slot_duration_minutes
    if service_data.participants_per_slot is not None:
        service.participants_per_slot = service_data.participants_per_slot
    
    # 处理 weekly_time_slot_config 和 time_slot_start_time/time_slot_end_time 的互斥关系
    if service_data.weekly_time_slot_config is not None:
        service.weekly_time_slot_config = service_data.weekly_time_slot_config
        # 如果使用按周几配置，清除统一时间配置
        if service_data.weekly_time_slot_config:
            service.time_slot_start_time = None
            service.time_slot_end_time = None
    elif service_data.time_slot_start_time is not None or service_data.time_slot_end_time is not None:
        # 如果提供了统一时间配置，且没有提供 weekly_time_slot_config，则使用统一时间
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
    if service_data.currency is not None:
        service.currency = service_data.currency
    if service_data.status is not None:
        service.status = service_data.status
    if service_data.display_order is not None:
        service.display_order = service_data.display_order
    
    service.updated_at = get_utc_time()
    
    # 如果时间段配置发生变化，需要清理不符合新配置的时间段
    # 检查是否从统一时间改为按周几配置，或按周几配置发生了变化
    config_changed = False
    
    # 检查配置变化：需要深度比较字典内容
    import json
    
    # 情况1：提供了新的按周几配置
    if service_data.weekly_time_slot_config is not None:
        # 使用JSON序列化进行深度比较
        old_config_str = json.dumps(old_weekly_config, sort_keys=True) if old_weekly_config else None
        new_config_str = json.dumps(service_data.weekly_time_slot_config, sort_keys=True) if service_data.weekly_time_slot_config else None
        if old_config_str != new_config_str:
            config_changed = True
            logger.info(f"检测到按周几配置变化: service_id={service_id}, 旧配置={old_config_str}, 新配置={new_config_str}")
    
    # 情况2：从按周几配置改为统一时间配置（提供了has_time_slots=true但没有weekly_time_slot_config）
    if not config_changed and service_data.has_time_slots is not None and service_data.has_time_slots:
        if old_weekly_config and service_data.weekly_time_slot_config is None:
            # 之前有按周几配置，现在改为统一时间配置
            config_changed = True
            logger.info(f"检测到从按周几配置改为统一时间配置: service_id={service_id}")
    
    # 情况3：从统一时间配置改为按周几配置（之前没有weekly_time_slot_config，现在有了）
    if not config_changed and service_data.weekly_time_slot_config is not None:
        if not old_weekly_config and old_has_time_slots:
            # 之前是统一时间配置，现在改为按周几配置
            config_changed = True
            logger.info(f"检测到从统一时间配置改为按周几配置: service_id={service_id}")
    
    if config_changed and service.has_time_slots:
        # 需要清理不符合新配置的时间段
        from datetime import datetime as dt_datetime
        from app.utils.time_utils import LONDON, to_user_timezone
        
        # 获取当前服务的最新配置（已更新但未提交）
        current_weekly_config = service.weekly_time_slot_config if service.weekly_time_slot_config else None
        
        # 获取所有未来的时间段（未过期且未手动删除的）
        current_utc = get_utc_time()
        future_slots = await db.execute(
            select(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.service_id == service_id)
            .where(models.ServiceTimeSlot.slot_start_datetime >= current_utc)
            .where(models.ServiceTimeSlot.is_manually_deleted == False)
        )
        future_slots = future_slots.scalars().all()
        
        # 周几名称映射（Python的weekday(): 0=Monday, 6=Sunday）
        weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        
        deleted_count = 0
        for slot in future_slots:
            # 将UTC时间转换为英国时间获取日期和星期几
            slot_uk = to_user_timezone(slot.slot_start_datetime, LONDON)
            slot_date = slot_uk.date()
            weekday = slot_date.weekday()
            weekday_name = weekday_names[weekday]
            
            # 检查该时间段是否符合新配置
            should_delete = False
            
            if current_weekly_config:
                # 使用按周几配置：检查该周几是否启用
                day_config = current_weekly_config.get(weekday_name, {})
                if not day_config.get('enabled', False):
                    # 该周几未启用，应该删除
                    should_delete = True
                else:
                    # 检查时间段是否在配置的时间范围内
                    slot_start_time_str = day_config.get('start_time', '09:00:00')
                    slot_end_time_str = day_config.get('end_time', '18:00:00')
                    
                    # 解析时间字符串
                    try:
                        if len(slot_start_time_str) == 5:
                            slot_start_time_str += ':00'
                        if len(slot_end_time_str) == 5:
                            slot_end_time_str += ':00'
                        config_start_time = dt_time.fromisoformat(slot_start_time_str)
                        config_end_time = dt_time.fromisoformat(slot_end_time_str)
                    except ValueError:
                        config_start_time = dt_time(9, 0, 0)
                        config_end_time = dt_time(18, 0, 0)
                    
                    # 获取时间段的时间部分（英国时间）
                    slot_time = slot_uk.time()
                    
                    # 如果时间段不在配置的时间范围内，应该删除
                    if slot_time < config_start_time or slot_time >= config_end_time:
                        should_delete = True
            else:
                # 使用统一时间配置：检查时间段是否在配置的时间范围内
                if service.time_slot_start_time and service.time_slot_end_time:
                    slot_time = slot_uk.time()
                    if slot_time < service.time_slot_start_time or slot_time >= service.time_slot_end_time:
                        should_delete = True
            
            # 如果时间段不符合新配置，且没有参与者，则标记为手动删除
            if should_delete:
                if slot.current_participants == 0:
                    slot.is_manually_deleted = True
                    slot.is_available = False
                    deleted_count += 1
                # 如果有参与者，保留时间段但标记为不可用（不删除，避免影响已申请的参与者）
                else:
                    slot.is_available = False
        
        if deleted_count > 0:
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"服务 {service_id} 配置更新后，删除了 {deleted_count} 个不符合新配置的时间段")
    
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
    
    # 解析日期和时间，转换为UTC时间
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime
    
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
        
        # 将英国时间的日期+时间组合，然后转换为UTC
        slot_start_local = dt_datetime.combine(slot_date, start_time)
        slot_end_local = dt_datetime.combine(slot_date, end_time)
        
        # 转换为UTC时间
        slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
        slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"日期或时间格式错误: {str(e)}")
    
    # 检查是否已存在相同的时间段（使用新的datetime字段）
    existing_slot = await db.execute(
        select(models.ServiceTimeSlot)
        .where(models.ServiceTimeSlot.service_id == service_id)
        .where(models.ServiceTimeSlot.slot_start_datetime == slot_start_utc)
        .where(models.ServiceTimeSlot.slot_end_datetime == slot_end_utc)
    )
    if existing_slot.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该时间段已存在")
    
    # 创建时间段（使用UTC时间）
    new_time_slot = models.ServiceTimeSlot(
        service_id=service_id,
        slot_start_datetime=slot_start_utc,
        slot_end_datetime=slot_end_utc,
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
    
    # 构建查询（加载活动关联信息）
    from sqlalchemy.orm import selectinload
    query = select(models.ServiceTimeSlot).where(
        models.ServiceTimeSlot.service_id == service_id
    ).options(
        selectinload(models.ServiceTimeSlot.activity_relations).selectinload(models.ActivityTimeSlotRelation.activity),
        selectinload(models.ServiceTimeSlot.task_relations)  # 加载任务关联，用于动态计算参与者数量
    )
    
    # 日期过滤：将输入的日期转换为UTC datetime范围进行查询
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime, time as dt_time
    
    if start_date:
        try:
            start = date.fromisoformat(start_date)
            # 将开始日期的00:00:00转换为UTC
            start_datetime_local = dt_datetime.combine(start, dt_time(0, 0, 0))
            start_datetime_utc = parse_local_as_utc(start_datetime_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime >= start_datetime_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    
    if end_date:
        try:
            end = date.fromisoformat(end_date)
            # 将结束日期的23:59:59转换为UTC
            end_datetime_local = dt_datetime.combine(end, dt_time(23, 59, 59))
            end_datetime_utc = parse_local_as_utc(end_datetime_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime <= end_datetime_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")
    
    # 按开始时间排序（使用UTC datetime）
    query = query.order_by(
        models.ServiceTimeSlot.slot_start_datetime.asc()
    )
    
    result = await db.execute(query)
    time_slots = result.scalars().all()
    
    # 动态计算每个时间段的实际参与者数量（排除已取消的任务）
    # 使用批量查询避免N+1问题
    from app.models import Task, TaskParticipant, TaskTimeSlotRelation
    from sqlalchemy import func
    
    if time_slots:
        slot_ids = [slot.id for slot in time_slots]
        
        # 批量查询所有时间段关联的任务（排除已取消的任务）
        related_tasks_query = select(
            TaskTimeSlotRelation,
            Task
        ).join(
            Task, TaskTimeSlotRelation.task_id == Task.id
        ).where(
            TaskTimeSlotRelation.time_slot_id.in_(slot_ids),
            Task.status != "cancelled"
        )
        related_tasks_result = await db.execute(related_tasks_query)
        all_relations = related_tasks_result.all()
        
        # 按时间段ID分组任务
        tasks_by_slot: dict[int, list] = {}
        for relation_row in all_relations:
            # 处理不同的返回格式
            if hasattr(relation_row, 'TaskTimeSlotRelation'):
                slot_id = relation_row.TaskTimeSlotRelation.time_slot_id
                task = relation_row.Task
            else:
                # 如果返回的是元组格式
                slot_id = relation_row[0].time_slot_id
                task = relation_row[1]
            if slot_id not in tasks_by_slot:
                tasks_by_slot[slot_id] = []
            tasks_by_slot[slot_id].append(task)
        
        # 批量查询多人任务的参与者数量
        multi_task_ids = [task.id for tasks in tasks_by_slot.values() for task in tasks if task.is_multi_participant]
        participants_count_by_task: dict[int, int] = {}
        if multi_task_ids:
            participants_count_query = select(
                TaskParticipant.task_id,
                func.count(TaskParticipant.id).label('count')
            ).where(
                TaskParticipant.task_id.in_(multi_task_ids),
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            ).group_by(TaskParticipant.task_id)
            participants_count_result = await db.execute(participants_count_query)
            for row in participants_count_result:
                participants_count_by_task[row.task_id] = row.count
        
        # 为每个时间段计算实际参与者数量
        for slot in time_slots:
            actual_participants = 0
            tasks = tasks_by_slot.get(slot.id, [])
            for task in tasks:
                if task.is_multi_participant:
                    # 多人任务：使用批量查询的结果
                    actual_participants += participants_count_by_task.get(task.id, 0)
                else:
                    # 单个任务：如果状态为open、taken、in_progress，计数为1
                    if task.status in ["open", "taken", "in_progress"]:
                        actual_participants += 1
            
            # 更新slot对象的current_participants（临时修改，不影响数据库）
            slot.current_participants = actual_participants
    
    # 转换为输出格式
    return [schemas.ServiceTimeSlotOut.from_orm(slot) for slot in time_slots]


# 注意：更具体的路由必须放在通用路由之前
# 否则 FastAPI 可能会将 /by-date 匹配到 /{time_slot_id}

@task_expert_router.delete("/me/services/{service_id}/time-slots/by-date")
async def delete_time_slots_by_date(
    service_id: int,
    target_date: str = Query(..., description="要删除的日期，格式：YYYY-MM-DD"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除指定日期的所有时间段（标记为手动删除，避免自动重新生成）"""
    logger.info(f"删除时间段请求: service_id={service_id}, target_date={target_date}")
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
    
    # 解析日期
    try:
        target_date_obj = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
    
    # 将目标日期的开始和结束时间转换为UTC进行查询
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime, time as dt_time
    
    # 目标日期的00:00:00和23:59:59（英国时间）转换为UTC
    start_local = dt_datetime.combine(target_date_obj, dt_time(0, 0, 0))
    end_local = dt_datetime.combine(target_date_obj, dt_time(23, 59, 59))
    start_utc = parse_local_as_utc(start_local, LONDON)
    end_utc = parse_local_as_utc(end_local, LONDON)
    
    # 查找该日期的所有时间段
    time_slots_query = select(models.ServiceTimeSlot).where(
        models.ServiceTimeSlot.service_id == service_id
    ).where(
        models.ServiceTimeSlot.slot_start_datetime >= start_utc
    ).where(
        models.ServiceTimeSlot.slot_start_datetime <= end_utc
    ).where(
        models.ServiceTimeSlot.is_manually_deleted == False  # 只删除未标记为手动删除的
    )
    
    result = await db.execute(time_slots_query)
    time_slots = result.scalars().all()
    
    logger.info(f"找到 {len(time_slots)} 个时间段需要删除 (service_id={service_id}, target_date={target_date}, start_utc={start_utc}, end_utc={end_utc})")
    
    if not time_slots:
        logger.info(f"没有找到可删除的时间段 (service_id={service_id}, target_date={target_date})")
        return {"message": f"{target_date} 没有可删除的时间段", "deleted_count": 0}
    
    # 检查是否有已申请的时间段
    slots_with_participants = [slot for slot in time_slots if slot.current_participants > 0]
    if slots_with_participants:
        logger.warning(f"有 {len(slots_with_participants)} 个时间段已有参与者，无法删除")
        raise HTTPException(
            status_code=400,
            detail=f"{target_date} 有已申请的时间段，无法删除"
        )
    
    # 标记为手动删除（而不是真正删除，避免自动重新生成）
    slot_ids = [slot.id for slot in time_slots]
    deleted_count = len(slot_ids)
    
    if deleted_count == 0:
        return {"message": f"{target_date} 没有可删除的时间段", "deleted_count": 0}
    
    logger.info(f"准备标记 {deleted_count} 个时间段为已删除: {slot_ids}")
    
    try:
        # 使用批量更新，提高效率
        update_stmt = (
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id.in_(slot_ids))
            .where(models.ServiceTimeSlot.service_id == service_id)
            .values(
                is_manually_deleted=True,
                is_available=False
            )
        )
        
        result = await db.execute(update_stmt)
        updated_count = result.rowcount
        
        logger.info(f"批量更新结果: {updated_count} 个时间段被标记为已删除")
        
        if updated_count != deleted_count:
            logger.warning(f"更新数量不匹配: 期望 {deleted_count} 个，实际更新 {updated_count} 个")
            # 如果更新数量不匹配，回滚并抛出错误
            await db.rollback()
            raise HTTPException(
                status_code=500,
                detail=f"删除失败: 期望删除 {deleted_count} 个时间段，实际只更新了 {updated_count} 个"
            )
        
        # 提交事务
        await db.commit()
        
        logger.info(f"成功删除 {target_date} 的 {deleted_count} 个时间段: {slot_ids}")
        
    except HTTPException:
        # 重新抛出HTTP异常
        raise
    except Exception as e:
        logger.error(f"删除时间段时发生错误: {e}", exc_info=True)
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"删除时间段失败: {str(e)}"
        )
    
    return {
        "message": f"成功删除 {target_date} 的 {deleted_count} 个时间段",
        "deleted_count": deleted_count,
        "target_date": target_date,
        "slot_ids": slot_ids
    }


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
    
    # 检查配置：优先使用 weekly_time_slot_config，否则使用旧的 time_slot_start_time/time_slot_end_time
    has_weekly_config = service.weekly_time_slot_config and isinstance(service.weekly_time_slot_config, dict)
    
    if not has_weekly_config:
        # 使用旧的配置方式（向后兼容）
        if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
            raise HTTPException(
                status_code=400, detail="服务的时间段配置不完整"
            )
    else:
        # 使用新的按周几配置
        if not service.time_slot_duration_minutes or not service.participants_per_slot:
            raise HTTPException(
                status_code=400, detail="服务的时间段配置不完整（缺少时间段时长或参与者数量）"
            )
    
    # 解析日期
    try:
        start = date.fromisoformat(start_date)
        end = date.fromisoformat(end_date)
        if start > end:
            raise HTTPException(status_code=400, detail="开始日期必须早于或等于结束日期")
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
    
    # 生成时间段（使用UTC时间存储）
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime
    
    created_slots = []
    current_date = start
    duration_minutes = service.time_slot_duration_minutes
    
    # 周几名称映射（Python的weekday(): 0=Monday, 6=Sunday）
    weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
    
    while current_date <= end:
        # 获取当前日期是周几（0=Monday, 6=Sunday）
        weekday = current_date.weekday()
        weekday_name = weekday_names[weekday]
        
        # 确定该日期的时间段配置
        if has_weekly_config:
            # 使用按周几配置
            day_config = service.weekly_time_slot_config.get(weekday_name, {})
            if not day_config.get('enabled', False):
                # 该周几未启用，跳过
                current_date += timedelta(days=1)
                continue
            
            slot_start_time_str = day_config.get('start_time', '09:00:00')
            slot_end_time_str = day_config.get('end_time', '18:00:00')
            
            # 解析时间字符串
            try:
                slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                slot_end_time = dt_time.fromisoformat(slot_end_time_str)
            except ValueError:
                # 如果格式不对，尝试添加秒数
                if len(slot_start_time_str) == 5:  # HH:MM
                    slot_start_time_str += ':00'
                if len(slot_end_time_str) == 5:  # HH:MM
                    slot_end_time_str += ':00'
                slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                slot_end_time = dt_time.fromisoformat(slot_end_time_str)
        else:
            # 使用旧的统一配置
            slot_start_time = service.time_slot_start_time
            slot_end_time = service.time_slot_end_time
        
        # 检查该日期是否被手动删除（跳过手动删除的日期）
        start_local = dt_datetime.combine(current_date, dt_time(0, 0, 0))
        end_local = dt_datetime.combine(current_date, dt_time(23, 59, 59))
        start_utc = parse_local_as_utc(start_local, LONDON)
        end_utc = parse_local_as_utc(end_local, LONDON)
        
        # 检查该日期是否有手动删除的时间段
        deleted_check = await db.execute(
            select(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.service_id == service_id)
            .where(models.ServiceTimeSlot.slot_start_datetime >= start_utc)
            .where(models.ServiceTimeSlot.slot_start_datetime <= end_utc)
            .where(models.ServiceTimeSlot.is_manually_deleted == True)
            .limit(1)
        )
        if deleted_check.scalar_one_or_none():
            # 该日期已被手动删除，跳过
            current_date += timedelta(days=1)
            continue
        
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
            
            # 将英国时间的日期+时间组合，然后转换为UTC
            slot_start_local = dt_datetime.combine(current_date, current_time)
            slot_end_local = dt_datetime.combine(current_date, slot_end)
            
            # 转换为UTC时间
            slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
            slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
            
            # 检查是否已存在且未被手动删除
            existing = await db.execute(
                select(models.ServiceTimeSlot)
                .where(models.ServiceTimeSlot.service_id == service_id)
                .where(models.ServiceTimeSlot.slot_start_datetime == slot_start_utc)
                .where(models.ServiceTimeSlot.slot_end_datetime == slot_end_utc)
                .where(models.ServiceTimeSlot.is_manually_deleted == False)
            )
            if not existing.scalar_one_or_none():
                # 创建新时间段（使用UTC时间）
                new_slot = models.ServiceTimeSlot(
                    service_id=service_id,
                    slot_start_datetime=slot_start_utc,
                    slot_end_datetime=slot_end_utc,
                    price_per_participant=price_per_participant,
                    max_participants=service.participants_per_slot,
                    current_participants=0,
                    is_available=True,
                    is_manually_deleted=False,
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
    
    # 自动添加匹配的时间段到活动中（使用错误处理，避免影响时间段创建的成功）
    if created_slots:
        try:
            await auto_add_time_slots_to_activities(db, service_id, created_slots)
        except Exception as e:
            # 记录错误但不影响时间段创建的成功
            logger.error(f"自动添加时间段到活动时出错: {e}", exc_info=True)
    
    return {
        "message": f"成功创建 {len(created_slots)} 个时间段",
        "created_count": len(created_slots),
        "time_slots": [schemas.ServiceTimeSlotOut.from_orm(s) for s in created_slots]
    }


# ===========================================
# 辅助函数：自动添加时间段到活动
# ===========================================

async def auto_add_time_slots_to_activities(
    db: AsyncSession,
    service_id: int,
    new_slots: List[models.ServiceTimeSlot]
):
    """
    自动将新创建的时间段添加到匹配重复规则的活动
    
    参数:
        db: 数据库会话
        service_id: 服务ID
        new_slots: 新创建的时间段列表
    """
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime
    
    if not new_slots:
        return
    
    # 查询该服务的所有活动的重复规则
    recurring_relations = await db.execute(
        select(models.ActivityTimeSlotRelation)
        .join(models.Activity)
        .where(models.Activity.expert_service_id == service_id)
        .where(models.ActivityTimeSlotRelation.relation_mode == "recurring")
        .where(models.ActivityTimeSlotRelation.auto_add_new_slots == True)
        .where(models.Activity.status == "open")  # 只处理开放中的活动
    )
    recurring_relations = recurring_relations.scalars().all()
    
    if not recurring_relations:
        return
    
    added_count = 0
    
    for relation in recurring_relations:
        # 检查活动是否已结束（通过截至日期）
        if relation.activity_end_date:
            today = date.today()
            if today > relation.activity_end_date:
                # 活动已超过截至日期，不再添加时间段
                continue
        
        recurring_rule = relation.recurring_rule
        if not recurring_rule:
            continue
        
        rule_type = recurring_rule.get("type")
        
        # 处理每天重复模式
        if rule_type == "daily":
            time_ranges = recurring_rule.get("time_ranges", [])
            if not time_ranges:
                continue
            
            for slot in new_slots:
                # 检查时间段是否已被其他活动使用（固定模式）
                existing_relation = await db.execute(
                    select(models.ActivityTimeSlotRelation)
                    .where(models.ActivityTimeSlotRelation.time_slot_id == slot.id)
                    .where(models.ActivityTimeSlotRelation.relation_mode == "fixed")
                )
                if existing_relation.scalar_one_or_none():
                    continue  # 时间段已被使用
                
                # 检查时间段是否已在当前活动中
                existing_in_activity = await db.execute(
                    select(models.ActivityTimeSlotRelation)
                    .where(models.ActivityTimeSlotRelation.activity_id == relation.activity_id)
                    .where(models.ActivityTimeSlotRelation.time_slot_id == slot.id)
                )
                if existing_in_activity.scalar_one_or_none():
                    continue  # 已在活动中
                
                # 获取时间段的时间（英国时间）
                slot_start_utc = slot.slot_start_datetime
                slot_end_utc = slot.slot_end_datetime
                
                # 转换为英国时间
                from app.utils.time_utils import to_user_timezone
                slot_start_local = to_user_timezone(slot_start_utc, LONDON)
                slot_end_local = to_user_timezone(slot_end_utc, LONDON)
                
                slot_start_time = slot_start_local.time()
                slot_end_time = slot_end_local.time()
                
                # 检查是否匹配任何一个时间范围
                matched = False
                for time_range in time_ranges:
                    range_start = dt_time.fromisoformat(time_range["start"])
                    range_end = dt_time.fromisoformat(time_range["end"])
                    
                    # 时间段开始时间在范围内，或时间段包含范围
                    if (range_start <= slot_start_time < range_end) or (slot_start_time <= range_start < slot_end_time):
                        matched = True
                        break
                
                if matched:
                    # 检查时间段是否超过活动截至日期
                    if relation.activity_end_date:
                        slot_date = slot.slot_start_datetime.date()
                        if slot_date > relation.activity_end_date:
                            # 时间段超过截至日期，不添加
                            continue
                    
                    # 创建固定关联（用于重复模式的匹配时间段）
                    fixed_relation = models.ActivityTimeSlotRelation(
                        activity_id=relation.activity_id,
                        time_slot_id=slot.id,
                        relation_mode="fixed",
                        auto_add_new_slots=False
                    )
                    db.add(fixed_relation)
                    added_count += 1
        
        # 处理每周重复模式
        elif rule_type == "weekly":
            weekdays = recurring_rule.get("weekdays", [])
            time_ranges = recurring_rule.get("time_ranges", [])
            
            if not weekdays or not time_ranges:
                continue
            
            for slot in new_slots:
                # 检查时间段是否已被其他活动使用（固定模式）
                existing_relation = await db.execute(
                    select(models.ActivityTimeSlotRelation)
                    .where(models.ActivityTimeSlotRelation.time_slot_id == slot.id)
                    .where(models.ActivityTimeSlotRelation.relation_mode == "fixed")
                )
                if existing_relation.scalar_one_or_none():
                    continue  # 时间段已被使用
                
                # 检查时间段是否已在当前活动中
                existing_in_activity = await db.execute(
                    select(models.ActivityTimeSlotRelation)
                    .where(models.ActivityTimeSlotRelation.activity_id == relation.activity_id)
                    .where(models.ActivityTimeSlotRelation.time_slot_id == slot.id)
                )
                if existing_in_activity.scalar_one_or_none():
                    continue  # 已在活动中
                
                # 获取时间段的日期和星期几
                slot_start_utc = slot.slot_start_datetime
                slot_date = slot_start_utc.date()
                slot_weekday = slot_date.weekday()  # 0=Monday, 6=Sunday
                
                # 检查星期几是否匹配
                if slot_weekday not in weekdays:
                    continue
                
                # 获取时间段的时间（英国时间）
                from app.utils.time_utils import to_user_timezone
                slot_start_local = to_user_timezone(slot_start_utc, LONDON)
                slot_end_local = to_user_timezone(slot.slot_end_datetime, LONDON)
                
                slot_start_time = slot_start_local.time()
                slot_end_time = slot_end_local.time()
                
                # 检查时间范围是否匹配
                matched = False
                for time_range in time_ranges:
                    range_start = dt_time.fromisoformat(time_range["start"])
                    range_end = dt_time.fromisoformat(time_range["end"])
                    
                    # 时间段开始时间在范围内，或时间段包含范围
                    if (range_start <= slot_start_time < range_end) or (slot_start_time <= range_start < slot_end_time):
                        matched = True
                        break
                
                if matched:
                    # 检查时间段是否超过活动截至日期
                    if relation.activity_end_date:
                        slot_date = slot.slot_start_datetime.date()
                        if slot_date > relation.activity_end_date:
                            # 时间段超过截至日期，不添加
                            continue
                    
                    # 创建固定关联（用于重复模式的匹配时间段）
                    fixed_relation = models.ActivityTimeSlotRelation(
                        activity_id=relation.activity_id,
                        time_slot_id=slot.id,
                        relation_mode="fixed",
                        auto_add_new_slots=False
                    )
                    db.add(fixed_relation)
                    added_count += 1
    
    if added_count > 0:
        await db.commit()
        logger.info(f"自动添加了 {added_count} 个时间段到活动中")


# ===========================================
# 辅助函数：检查并结束活动
# ===========================================

async def check_and_end_activities(db: AsyncSession):
    """
    检查活动是否应该结束（最后一个时间段结束或达到截至日期），并自动结束活动
    
    应该在定时任务中定期调用
    """
    from datetime import datetime as dt_datetime
    from app.utils.time_utils import get_utc_time
    
    # 查询所有开放中的活动
    open_activities = await db.execute(
        select(models.Activity)
        .where(models.Activity.status == "open")
    )
    open_activities = open_activities.scalars().all()
    
    ended_count = 0
    current_time = get_utc_time()
    
    for activity in open_activities:
        should_end = False
        end_reason = ""
        
        # 查询活动的所有时间段关联
        relations = await db.execute(
            select(models.ActivityTimeSlotRelation)
            .where(models.ActivityTimeSlotRelation.activity_id == activity.id)
            .where(models.ActivityTimeSlotRelation.relation_mode == "fixed")
        )
        fixed_relations = relations.scalars().all()
        
        # 查询重复规则关联
        recurring_relation = await db.execute(
            select(models.ActivityTimeSlotRelation)
            .where(models.ActivityTimeSlotRelation.activity_id == activity.id)
            .where(models.ActivityTimeSlotRelation.relation_mode == "recurring")
            .limit(1)
        )
        recurring_relation = recurring_relation.scalar_one_or_none()
        
        # 检查是否达到截至日期
        if recurring_relation and recurring_relation.activity_end_date:
            today = date.today()
            if today > recurring_relation.activity_end_date:
                should_end = True
                end_reason = f"已达到活动截至日期 {recurring_relation.activity_end_date}"
        
        # 检查最后一个时间段是否已结束
        if not should_end and fixed_relations:
            # 获取所有关联的时间段
            time_slot_ids = [r.time_slot_id for r in fixed_relations if r.time_slot_id]
            if time_slot_ids:
                time_slots = await db.execute(
                    select(models.ServiceTimeSlot)
                    .where(models.ServiceTimeSlot.id.in_(time_slot_ids))
                    .order_by(models.ServiceTimeSlot.slot_end_datetime.desc())
                )
                time_slots = time_slots.scalars().all()
                
                if time_slots:
                    # 获取最后一个时间段
                    last_slot = time_slots[0]
                    
                    # 检查最后一个时间段是否已结束
                    if last_slot.slot_end_datetime < current_time:
                        # 如果活动有重复规则且auto_add_new_slots为True，不结束活动
                        if recurring_relation and recurring_relation.auto_add_new_slots:
                            # 检查是否还有未到期的匹配时间段（未来30天内）
                            from app.utils.time_utils import parse_local_as_utc, LONDON
                            future_date = date.today() + timedelta(days=30)
                            future_utc = parse_local_as_utc(
                                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                                LONDON
                            )
                            
                            # 查询服务是否有未来的时间段
                            service = await db.execute(
                                select(models.TaskExpertService)
                                .where(models.TaskExpertService.id == activity.expert_service_id)
                            )
                            service = service.scalar_one_or_none()
                            
                            if service:
                                future_slots = await db.execute(
                                    select(models.ServiceTimeSlot)
                                    .where(models.ServiceTimeSlot.service_id == service.id)
                                    .where(models.ServiceTimeSlot.slot_start_datetime > current_time)
                                    .where(models.ServiceTimeSlot.slot_start_datetime <= future_utc)
                                    .where(models.ServiceTimeSlot.is_manually_deleted == False)
                                    .limit(1)
                                )
                                if not future_slots.scalar_one_or_none():
                                    # 没有未来的时间段，结束活动
                                    should_end = True
                                    end_reason = "最后一个时间段已结束，且没有未来的匹配时间段"
                        else:
                            # 没有重复规则或auto_add_new_slots为False，最后一个时间段结束就结束活动
                            should_end = True
                            end_reason = f"最后一个时间段已结束（{last_slot.slot_end_datetime}）"
        
        # 非时间段服务：检查截止日期
        if not should_end and not activity.has_time_slots and activity.deadline:
            if current_time > activity.deadline:
                should_end = True
                end_reason = f"已达到活动截止日期 {activity.deadline}"
        
        # 如果活动应该结束，更新状态
        if should_end:
            # 更新活动状态为已完成
            await db.execute(
                update(models.Activity)
                .where(models.Activity.id == activity.id)
                .values(status="completed", updated_at=get_utc_time())
            )
            
            # 自动处理关联的任务状态
            # 查询所有关联到此活动的任务（状态为open或taken）
            related_tasks_query = await db.execute(
                select(models.Task)
                .where(models.Task.parent_activity_id == activity.id)
                .where(models.Task.status.in_(["open", "taken"]))
            )
            related_tasks = related_tasks_query.scalars().all()
            
            for task in related_tasks:
                # 将未开始的任务标记为已取消
                old_status = task.status
                await db.execute(
                    update(models.Task)
                    .where(models.Task.id == task.id)
                    .values(status="cancelled", updated_at=get_utc_time())
                )
                
                # 记录审计日志
                task_audit_log = models.TaskAuditLog(
                    task_id=task.id,
                    action_type="task_cancelled",
                    action_description=f"活动已结束，任务自动取消",
                    user_id=None,
                    old_status=old_status,
                    new_status="cancelled",
                )
                db.add(task_audit_log)
            
            # 记录活动审计日志
            audit_log = models.TaskAuditLog(
                task_id=None,  # 活动没有task_id
                action_type="activity_completed",
                action_description=f"活动自动结束: {end_reason}",
                user_id=None,
                old_status="open",
                new_status="completed",
            )
            db.add(audit_log)
            
            ended_count += 1
            logger.info(f"活动 {activity.id} 自动结束：{end_reason}")
    
    if ended_count > 0:
        await db.commit()
        logger.info(f"自动结束了 {ended_count} 个活动")
    
    return ended_count


# ===========================================
# API端点：手动触发活动结束检查（管理员或系统调用）
# ===========================================

@task_expert_router.post("/admin/check-and-end-activities")
async def check_and_end_activities_endpoint(
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    手动触发活动结束检查（管理员接口）
    应该在定时任务中定期调用
    """
    ended_count = await check_and_end_activities(db)
    return {
        "message": f"检查完成，结束了 {ended_count} 个活动",
        "ended_count": ended_count
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
    
    # 构建查询（使用UTC时间）
    from app.utils.time_utils import parse_local_as_utc, LONDON
    from datetime import datetime as dt_datetime, time as dt_time
    
    # 构建查询（加载活动关联信息）
    from sqlalchemy.orm import selectinload
    query = select(models.ServiceTimeSlot).where(
        models.ServiceTimeSlot.service_id == service_id
        # 注意：不再过滤is_available，让已满的时间段也能显示
    ).options(
        selectinload(models.ServiceTimeSlot.activity_relations).selectinload(models.ActivityTimeSlotRelation.activity),
        selectinload(models.ServiceTimeSlot.task_relations)  # 加载任务关联，用于动态计算参与者数量
    )
    
    if start_date:
        try:
            start_date_obj = date.fromisoformat(start_date)
            # 将开始日期的00:00:00（英国时间）转换为UTC
            start_local = dt_datetime.combine(start_date_obj, dt_time(0, 0, 0))
            start_utc = parse_local_as_utc(start_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime >= start_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    
    if end_date:
        try:
            end_date_obj = date.fromisoformat(end_date)
            # 将结束日期的23:59:59（英国时间）转换为UTC
            end_local = dt_datetime.combine(end_date_obj, dt_time(23, 59, 59))
            end_utc = parse_local_as_utc(end_local, LONDON)
            query = query.where(models.ServiceTimeSlot.slot_start_datetime <= end_utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")
    
    # 按开始时间排序
    query = query.order_by(
        models.ServiceTimeSlot.slot_start_datetime.asc()
    )
    
    result = await db.execute(query)
    time_slots = result.scalars().all()
    
    # 动态计算每个时间段的实际参与者数量（排除已取消的任务）
    # 使用批量查询避免N+1问题
    from app.models import Task, TaskParticipant, TaskTimeSlotRelation
    from sqlalchemy import func
    
    if time_slots:
        slot_ids = [slot.id for slot in time_slots]
        
        # 批量查询所有时间段关联的任务（排除已取消的任务）
        related_tasks_query = select(
            TaskTimeSlotRelation,
            Task
        ).join(
            Task, TaskTimeSlotRelation.task_id == Task.id
        ).where(
            TaskTimeSlotRelation.time_slot_id.in_(slot_ids),
            Task.status != "cancelled"
        )
        related_tasks_result = await db.execute(related_tasks_query)
        all_relations = related_tasks_result.all()
        
        # 按时间段ID分组任务
        tasks_by_slot: dict[int, list] = {}
        for relation_row in all_relations:
            # 处理不同的返回格式
            if hasattr(relation_row, 'TaskTimeSlotRelation'):
                slot_id = relation_row.TaskTimeSlotRelation.time_slot_id
                task = relation_row.Task
            else:
                # 如果返回的是元组格式
                slot_id = relation_row[0].time_slot_id
                task = relation_row[1]
            if slot_id not in tasks_by_slot:
                tasks_by_slot[slot_id] = []
            tasks_by_slot[slot_id].append(task)
        
        # 批量查询多人任务的参与者数量
        multi_task_ids = [task.id for tasks in tasks_by_slot.values() for task in tasks if task.is_multi_participant]
        participants_count_by_task: dict[int, int] = {}
        if multi_task_ids:
            participants_count_query = select(
                TaskParticipant.task_id,
                func.count(TaskParticipant.id).label('count')
            ).where(
                TaskParticipant.task_id.in_(multi_task_ids),
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            ).group_by(TaskParticipant.task_id)
            participants_count_result = await db.execute(participants_count_query)
            for row in participants_count_result:
                participants_count_by_task[row.task_id] = row.count
        
        # 为每个时间段计算实际参与者数量
        for slot in time_slots:
            actual_participants = 0
            tasks = tasks_by_slot.get(slot.id, [])
            for task in tasks:
                if task.is_multi_participant:
                    # 多人任务：使用批量查询的结果
                    actual_participants += participants_count_by_task.get(task.id, 0)
                else:
                    # 单个任务：如果状态为open、taken、in_progress，计数为1
                    if task.status in ["open", "taken", "in_progress"]:
                        actual_participants += 1
            
            # 更新slot对象的current_participants（临时修改，不影响数据库）
            slot.current_participants = actual_participants
    
    # 查询任务达人的关门日期
    closed_dates_query = select(models.ExpertClosedDate).where(
        models.ExpertClosedDate.expert_id == service.expert_id
    )
    if start_date:
        try:
            start_date_obj = date.fromisoformat(start_date)
            closed_dates_query = closed_dates_query.where(
                models.ExpertClosedDate.closed_date >= start_date_obj
            )
        except ValueError:
            pass
    if end_date:
        try:
            end_date_obj = date.fromisoformat(end_date)
            closed_dates_query = closed_dates_query.where(
                models.ExpertClosedDate.closed_date <= end_date_obj
            )
        except ValueError:
            pass
    
    closed_dates_result = await db.execute(closed_dates_query)
    closed_dates = closed_dates_result.scalars().all()
    closed_date_set = {cd.closed_date for cd in closed_dates}
    
    # 过滤掉关门日期的时间段
    filtered_slots = []
    for slot in time_slots:
        # 将UTC时间转换为英国时间，然后获取日期
        slot_date_local = slot.slot_start_datetime.astimezone(LONDON).date()
        if slot_date_local not in closed_date_set:
            filtered_slots.append(slot)
    
    # 转换为输出格式
    return [schemas.ServiceTimeSlotOut.from_orm(slot) for slot in filtered_slots]


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
        
        # 验证时间段是否已过期（开始时间是否已过当前时间）
        current_utc = get_utc_time()
        if time_slot.slot_start_datetime < current_utc:
            raise HTTPException(status_code=400, detail="该时间段已过期，无法申请")
        
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
            if application_data.deadline < get_utc_time():
                raise HTTPException(status_code=400, detail="截至日期不能早于当前时间")
            deadline = application_data.deadline
    else:
        # 如果服务启用了时间段，不需要截至日期（时间段已经包含了日期信息）
        deadline = None
    
    # 8. 判断是否自动批准：不议价且选择了时间段
    should_auto_approve = (
        application_data.negotiated_price is None and  # 没有议价
        service.has_time_slots and  # 服务启用了时间段
        application_data.time_slot_id is not None  # 选择了时间段
    )
    
    # 9. 创建申请记录
    initial_status = "approved" if should_auto_approve else "pending"
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
        status=initial_status,
    )
    
    # 如果自动批准，设置最终价格和批准时间
    if should_auto_approve:
        # 使用时间段的价格，如果没有则使用服务基础价格
        if time_slot:
            new_application.final_price = time_slot.price_per_participant
        else:
            new_application.final_price = service.base_price
        new_application.approved_at = get_utc_time()
    
    db.add(new_application)
    
    # 10. 如果选择了时间段，更新时间段的参与者数量（在提交前更新，避免并发问题）
    if time_slot:
        await db.execute(
            update(models.ServiceTimeSlot)
            .where(models.ServiceTimeSlot.id == time_slot.id)
            .values(current_participants=models.ServiceTimeSlot.current_participants + 1)
        )
    
    # 11. 更新服务统计：申请时+1（原子更新，避免并发丢失）
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
    
    # 12. 如果自动批准，创建任务
    if should_auto_approve:
        from datetime import timedelta
        
        # 获取任务达人的位置信息（使用和approve_service_application相同的逻辑）
        location = None
        featured_expert = await db.get(models.FeaturedTaskExpert, service.expert_id)
        if featured_expert and featured_expert.location:
            location = featured_expert.location.strip() if featured_expert.location else None
        
        # 如果 FeaturedTaskExpert 没有 location，从 User 表获取 residence_city
        if not location:
            from app import async_crud
            expert_user = await async_crud.async_user_crud.get_user_by_id(db, service.expert_id)
            if expert_user and expert_user.residence_city:
                location = expert_user.residence_city.strip() if expert_user.residence_city else None
        
        # 如果仍然没有 location，使用默认值 "线上"
        if not location:
            location = "线上"
        # 如果 location 是 "Online" 或 "线上"（不区分大小写），统一为 "线上"
        elif location.lower() in ["online", "线上"]:
            location = "线上"
        
        # 确定任务价格
        price = new_application.final_price
        
        # 确定任务截止日期
        if service.has_time_slots and time_slot:
            # 使用时间段的结束时间作为任务截止日期
            task_deadline = time_slot.slot_end_datetime
        elif deadline:
            task_deadline = deadline
        else:
            # 默认7天后
            task_deadline = get_utc_time() + timedelta(days=7)
        
        # 处理图片（JSONB类型，直接使用list）
        images_list = service.images if service.images else None
        
        # 创建任务（任务达人服务创建的任务等级为 expert）
        new_task = models.Task(
            title=service.service_name,
            description=service.description,
            deadline=task_deadline,
            is_flexible=application_data.is_flexible or 0,
            reward=price,
            base_reward=service.base_price,
            agreed_reward=price,
            currency=application_data.currency or service.currency,
            location=location,
            task_type="其他",
            task_level="expert",
            poster_id=current_user.id,  # 申请用户是发布人
            taker_id=service.expert_id,  # 任务达人接收方
            status="in_progress",
            images=images_list,
            accepted_at=get_utc_time()
        )
        
        db.add(new_task)
        await db.flush()  # 获取任务ID
        
        # 更新申请记录，关联任务ID
        new_application.task_id = new_task.id
        await db.commit()
        await db.refresh(new_task)
        
        # 发送通知给申请用户（任务已创建）
        from app.task_notifications import send_service_application_approved_notification
        try:
            await send_service_application_approved_notification(
                db=db,
                applicant_id=current_user.id,
                expert_id=service.expert_id,
                task_id=new_task.id,
                service_name=service.service_name
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    else:
        # 13. 发送通知给任务达人（需要批准）
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
    application.updated_at = get_utc_time()
    
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
        task_deadline = get_utc_time() + timedelta(days=7)
    
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
        accepted_at=get_utc_time()
    )
    
    db.add(new_task)
    await db.flush()  # 获取任务ID
    
    # 9. 更新申请记录
    application.status = "approved"
    application.final_price = price
    application.task_id = new_task.id
    application.approved_at = get_utc_time()
    application.updated_at = get_utc_time()
    
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


# ==================== 任务达人仪表盘和时刻表 ====================

@task_expert_router.get("/me/dashboard/stats")
async def get_expert_dashboard_stats(
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人仪表盘统计数据"""
    expert_id = current_expert.id
    
    # 统计服务数量
    services_count = await db.execute(
        select(func.count(models.TaskExpertService.id))
        .where(models.TaskExpertService.expert_id == expert_id)
    )
    total_services = services_count.scalar() or 0
    
    active_services_count = await db.execute(
        select(func.count(models.TaskExpertService.id))
        .where(
            and_(
                models.TaskExpertService.expert_id == expert_id,
                models.TaskExpertService.status == "active"
            )
        )
    )
    active_services = active_services_count.scalar() or 0
    
    # 统计申请数量
    applications_count = await db.execute(
        select(func.count(models.ServiceApplication.id))
        .join(models.TaskExpertService)
        .where(models.TaskExpertService.expert_id == expert_id)
    )
    total_applications = applications_count.scalar() or 0
    
    pending_applications_count = await db.execute(
        select(func.count(models.ServiceApplication.id))
        .join(models.TaskExpertService)
        .where(
            and_(
                models.TaskExpertService.expert_id == expert_id,
                models.ServiceApplication.status == "pending"
            )
        )
    )
    pending_applications = pending_applications_count.scalar() or 0
    
    # 统计多人任务数量
    multi_tasks_count = await db.execute(
        select(func.count(models.Task.id))
        .where(
            and_(
                models.Task.expert_creator_id == expert_id,
                models.Task.is_multi_participant == True
            )
        )
    )
    total_multi_tasks = multi_tasks_count.scalar() or 0
    
    in_progress_multi_tasks_count = await db.execute(
        select(func.count(models.Task.id))
        .where(
            and_(
                models.Task.expert_creator_id == expert_id,
                models.Task.is_multi_participant == True,
                models.Task.status == "in_progress"
            )
        )
    )
    in_progress_multi_tasks = in_progress_multi_tasks_count.scalar() or 0
    
    # 统计参与者数量
    participants_count = await db.execute(
        select(func.count(models.TaskParticipant.id))
        .join(models.Task)
        .where(
            and_(
                models.Task.expert_creator_id == expert_id,
                models.Task.is_multi_participant == True
            )
        )
    )
    total_participants = participants_count.scalar() or 0
    
    # 统计时间段数量（未来30天）
    from datetime import datetime, timedelta
    from app.utils.time_utils import get_utc_time
    now = get_utc_time()
    future_date = now + timedelta(days=30)
    
    time_slots_count = await db.execute(
        select(func.count(models.ServiceTimeSlot.id))
        .join(models.TaskExpertService)
        .where(
            and_(
                models.TaskExpertService.expert_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= now,
                models.ServiceTimeSlot.slot_start_datetime <= future_date
            )
        )
    )
    upcoming_time_slots = time_slots_count.scalar() or 0
    
    # 统计有参与者的时间段数量
    time_slots_with_participants_count = await db.execute(
        select(func.count(models.ServiceTimeSlot.id))
        .join(models.TaskExpertService)
        .where(
            and_(
                models.TaskExpertService.expert_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= now,
                models.ServiceTimeSlot.current_participants > 0
            )
        )
    )
    time_slots_with_participants = time_slots_with_participants_count.scalar() or 0
    
    return {
        "total_services": total_services,
        "active_services": active_services,
        "total_applications": total_applications,
        "pending_applications": pending_applications,
        "total_multi_tasks": total_multi_tasks,
        "in_progress_multi_tasks": in_progress_multi_tasks,
        "total_participants": total_participants,
        "upcoming_time_slots": upcoming_time_slots,
        "time_slots_with_participants": time_slots_with_participants,
    }


@task_expert_router.get("/me/schedule")
async def get_expert_schedule(
    start_date: Optional[str] = Query(None, description="开始日期 (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="结束日期 (YYYY-MM-DD)"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务达人时刻表数据（时间段服务安排）"""
    expert_id = current_expert.id
    
    from datetime import datetime, timedelta
    from app.utils.time_utils import get_utc_time, parse_local_as_utc, LONDON
    
    # 如果没有提供日期，默认查询未来30天
    now = get_utc_time()
    if not start_date:
        start_date_obj = now.date()
    else:
        start_date_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
    
    if not end_date:
        end_date_obj = (now + timedelta(days=30)).date()
    else:
        end_date_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
    
    # 转换为UTC时间范围
    start_datetime = parse_local_as_utc(
        datetime.combine(start_date_obj, dt_time.min), LONDON
    )
    end_datetime = parse_local_as_utc(
        datetime.combine(end_date_obj, dt_time.max), LONDON
    )
    
    # 查询时间段数据（加载任务关联，用于动态计算参与者数量）
    from sqlalchemy.orm import selectinload
    query = (
        select(
            models.ServiceTimeSlot,
            models.TaskExpertService.service_name,
            models.TaskExpertService.id.label("service_id")
        )
        .join(models.TaskExpertService)
        .where(
            and_(
                models.TaskExpertService.expert_id == expert_id,
                models.ServiceTimeSlot.slot_start_datetime >= start_datetime,
                models.ServiceTimeSlot.slot_start_datetime <= end_datetime
            )
        )
        .options(
            selectinload(models.ServiceTimeSlot.task_relations)  # 加载任务关联，用于动态计算参与者数量
        )
        .order_by(models.ServiceTimeSlot.slot_start_datetime.asc())
    )
    
    result = await db.execute(query)
    rows = result.all()
    
    # 动态计算每个时间段的实际参与者数量（排除已取消的任务）
    from app.models import Task, TaskParticipant, TaskTimeSlotRelation
    from sqlalchemy import func
    
    time_slots = [row.ServiceTimeSlot for row in rows]
    
    # 初始化变量（确保在if块外也能访问）
    tasks_by_slot: dict[int, list] = {}
    participants_count_by_task: dict[int, int] = {}
    
    # 批量查询所有时间段关联的任务（排除已取消的任务）
    if time_slots:
        slot_ids = [slot.id for slot in time_slots]
        
        related_tasks_query = select(
            TaskTimeSlotRelation,
            Task
        ).join(
            Task, TaskTimeSlotRelation.task_id == Task.id
        ).where(
            TaskTimeSlotRelation.time_slot_id.in_(slot_ids),
            Task.status != "cancelled"
        )
        related_tasks_result = await db.execute(related_tasks_query)
        all_relations = related_tasks_result.all()
        
        # 按时间段ID分组任务
        for relation_row in all_relations:
            # 处理不同的返回格式
            if hasattr(relation_row, 'TaskTimeSlotRelation'):
                slot_id = relation_row.TaskTimeSlotRelation.time_slot_id
                task = relation_row.Task
            else:
                # 如果返回的是元组格式
                slot_id = relation_row[0].time_slot_id
                task = relation_row[1]
            if slot_id not in tasks_by_slot:
                tasks_by_slot[slot_id] = []
            tasks_by_slot[slot_id].append(task)
        
        # 批量查询多人任务的参与者数量
        multi_task_ids = [task.id for tasks in tasks_by_slot.values() for task in tasks if task.is_multi_participant]
        if multi_task_ids:
            participants_count_query = select(
                TaskParticipant.task_id,
                func.count(TaskParticipant.id).label('count')
            ).where(
                TaskParticipant.task_id.in_(multi_task_ids),
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            ).group_by(TaskParticipant.task_id)
            participants_count_result = await db.execute(participants_count_query)
            for row in participants_count_result:
                participants_count_by_task[row.task_id] = row.count
    
    # 组织数据
    schedule_items = []
    for row in rows:
        slot = row.ServiceTimeSlot
        service_name = row.service_name
        service_id = row.service_id
        
        # 实时计算参与者数量
        actual_participants = 0
        if time_slots and slot.id in tasks_by_slot:
            tasks = tasks_by_slot[slot.id]
            for task in tasks:
                if task.is_multi_participant:
                    # 多人任务：使用批量查询的结果
                    actual_participants += participants_count_by_task.get(task.id, 0)
                else:
                    # 单个任务：如果状态为open、taken、in_progress，计数为1
                    if task.status in ["open", "taken", "in_progress"]:
                        actual_participants += 1
        
        # 转换为本地时间显示
        slot_start_local = slot.slot_start_datetime.astimezone(LONDON)
        slot_end_local = slot.slot_end_datetime.astimezone(LONDON)
        
        schedule_items.append({
            "id": slot.id,
            "service_id": service_id,
            "service_name": service_name,
            "slot_start_datetime": slot.slot_start_datetime.isoformat(),
            "slot_end_datetime": slot.slot_end_datetime.isoformat(),
            "date": slot_start_local.strftime("%Y-%m-%d"),
            "start_time": slot_start_local.strftime("%H:%M"),
            "end_time": slot_end_local.strftime("%H:%M"),
            "current_participants": actual_participants,  # 使用实时计算的值
            "max_participants": slot.max_participants,
            "is_available": slot.is_available,
            "is_expired": slot.slot_start_datetime < now,
        })
    
    # 查询多人任务（非固定时间段）
    multi_tasks_query = (
        select(models.Task)
        .where(
            and_(
                models.Task.expert_creator_id == expert_id,
                models.Task.is_multi_participant == True,
                models.Task.is_fixed_time_slot == False,
                models.Task.status.in_(["open", "in_progress"]),
                models.Task.deadline >= start_datetime,
                models.Task.deadline <= end_datetime
            )
        )
        .order_by(models.Task.deadline.asc())
    )
    
    multi_tasks_result = await db.execute(multi_tasks_query)
    multi_tasks = multi_tasks_result.scalars().all()
    
    # 批量查询多人任务的参与者数量（实时计算）
    multi_task_ids = [task.id for task in multi_tasks]
    task_participants_count: dict[int, int] = {}
    if multi_task_ids:
        participants_count_query = select(
            TaskParticipant.task_id,
            func.count(TaskParticipant.id).label('count')
        ).where(
            TaskParticipant.task_id.in_(multi_task_ids),
            TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
        ).group_by(TaskParticipant.task_id)
        participants_count_result = await db.execute(participants_count_query)
        for row in participants_count_result:
            task_participants_count[row.task_id] = row.count
    
    # 添加多人任务到时刻表
    for task in multi_tasks:
        deadline_local = task.deadline.astimezone(LONDON) if task.deadline else None
        if deadline_local:
            # 实时计算参与者数量
            actual_participants = task_participants_count.get(task.id, 0)
            
            schedule_items.append({
                "id": f"task_{task.id}",
                "service_id": task.expert_service_id,
                "service_name": task.title,
                "slot_start_datetime": None,
                "slot_end_datetime": None,
                "date": deadline_local.strftime("%Y-%m-%d"),
                "start_time": None,
                "end_time": None,
                "deadline": deadline_local.isoformat(),
                "current_participants": actual_participants,  # 使用实时计算的值
                "max_participants": task.max_participants,
                "task_status": task.status,
                "is_task": True,
            })
    
    # 按日期和时间排序
    schedule_items.sort(key=lambda x: (
        x["date"],
        x["start_time"] if x.get("start_time") else "99:99"
    ))
    
    return {
        "items": schedule_items,
        "start_date": start_date_obj.isoformat(),
        "end_date": end_date_obj.isoformat(),
    }


# ==================== 任务达人关门日期管理 ====================

@task_expert_router.post("/me/closed-dates", response_model=schemas.ExpertClosedDateOut)
async def create_closed_date(
    closed_date_data: schemas.ExpertClosedDateCreate,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """添加关门日期"""
    expert_id = current_expert.id
    
    # 解析日期
    try:
        closed_date_obj = date.fromisoformat(closed_date_data.closed_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
    
    # 检查日期不能是过去的日期
    from app.utils.time_utils import get_utc_time
    today = get_utc_time().date()
    if closed_date_obj < today:
        raise HTTPException(status_code=400, detail="不能设置过去的日期为关门日期")
    
    # 检查是否已存在
    existing = await db.execute(
        select(models.ExpertClosedDate)
        .where(models.ExpertClosedDate.expert_id == expert_id)
        .where(models.ExpertClosedDate.closed_date == closed_date_obj)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该日期已设置为关门日期")
    
    # 创建关门日期记录
    closed_date = models.ExpertClosedDate(
        expert_id=expert_id,
        closed_date=closed_date_obj,
        reason=closed_date_data.reason
    )
    
    db.add(closed_date)
    await db.commit()
    await db.refresh(closed_date)
    
    return schemas.ExpertClosedDateOut(
        id=closed_date.id,
        expert_id=closed_date.expert_id,
        closed_date=closed_date.closed_date.isoformat(),
        reason=closed_date.reason,
        created_at=closed_date.created_at,
        updated_at=closed_date.updated_at,
    )


@task_expert_router.get("/me/closed-dates", response_model=List[schemas.ExpertClosedDateOut])
async def get_closed_dates(
    start_date: Optional[str] = Query(None, description="开始日期 (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="结束日期 (YYYY-MM-DD)"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取关门日期列表"""
    expert_id = current_expert.id
    
    query = select(models.ExpertClosedDate).where(
        models.ExpertClosedDate.expert_id == expert_id
    )
    
    if start_date:
        try:
            start_date_obj = date.fromisoformat(start_date)
            query = query.where(models.ExpertClosedDate.closed_date >= start_date_obj)
        except ValueError:
            raise HTTPException(status_code=400, detail="开始日期格式错误，应为YYYY-MM-DD")
    
    if end_date:
        try:
            end_date_obj = date.fromisoformat(end_date)
            query = query.where(models.ExpertClosedDate.closed_date <= end_date_obj)
        except ValueError:
            raise HTTPException(status_code=400, detail="结束日期格式错误，应为YYYY-MM-DD")
    
    query = query.order_by(models.ExpertClosedDate.closed_date.asc())
    
    result = await db.execute(query)
    closed_dates = result.scalars().all()
    
    return [
        schemas.ExpertClosedDateOut(
            id=cd.id,
            expert_id=cd.expert_id,
            closed_date=cd.closed_date.isoformat(),
            reason=cd.reason,
            created_at=cd.created_at,
            updated_at=cd.updated_at,
        )
        for cd in closed_dates
    ]


@task_expert_router.delete("/me/closed-dates/{closed_date_id}")
async def delete_closed_date(
    closed_date_id: int,
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除关门日期"""
    expert_id = current_expert.id
    
    # 查找关门日期
    closed_date = await db.execute(
        select(models.ExpertClosedDate)
        .where(models.ExpertClosedDate.id == closed_date_id)
        .where(models.ExpertClosedDate.expert_id == expert_id)
    )
    closed_date = closed_date.scalar_one_or_none()
    
    if not closed_date:
        raise HTTPException(status_code=404, detail="关门日期不存在")
    
    await db.delete(closed_date)
    await db.commit()
    
    return {"message": "关门日期已删除"}


@task_expert_router.delete("/me/closed-dates/by-date")
async def delete_closed_date_by_date(
    target_date: str = Query(..., description="要删除的日期，格式：YYYY-MM-DD"),
    current_expert: models.TaskExpert = Depends(get_current_expert),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """按日期删除关门日期"""
    expert_id = current_expert.id
    
    try:
        target_date_obj = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
    
    # 查找关门日期
    closed_date = await db.execute(
        select(models.ExpertClosedDate)
        .where(models.ExpertClosedDate.expert_id == expert_id)
        .where(models.ExpertClosedDate.closed_date == target_date_obj)
    )
    closed_date = closed_date.scalar_one_or_none()
    
    if not closed_date:
        raise HTTPException(status_code=404, detail="该日期未设置为关门日期")
    
    await db.delete(closed_date)
    await db.commit()
    
    return {"message": f"{target_date} 的关门日期已删除"}


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
    application.rejected_at = get_utc_time()
    application.updated_at = get_utc_time()
    
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


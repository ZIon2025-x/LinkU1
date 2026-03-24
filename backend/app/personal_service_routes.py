from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.async_routers import get_current_user_secure_async_csrf
from app.deps import get_async_db_dependency

personal_service_router = APIRouter(
    prefix="/api/services",
    tags=["personal-services"],
)

MAX_PERSONAL_SERVICES_PER_USER = 10


def _serialize_service(s: models.TaskExpertService) -> dict:
    return {
        "id": s.id,
        "service_name": s.service_name,
        "service_name_en": None,
        "description": s.description,
        "description_en": None,
        "category": s.category,
        "base_price": float(s.base_price) if s.base_price else 0,
        "currency": s.currency,
        "pricing_type": s.pricing_type or "fixed",
        "location_type": s.location_type or "online",
        "location": s.location,
        "latitude": float(s.latitude) if s.latitude else None,
        "longitude": float(s.longitude) if s.longitude else None,
        "images": s.images or [],
        "status": s.status,
        "view_count": s.view_count or 0,
        "application_count": s.application_count or 0,
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "updated_at": s.updated_at.isoformat() if s.updated_at else None,
    }


@personal_service_router.post("/me", status_code=status.HTTP_201_CREATED)
async def create_personal_service(
    data: schemas.PersonalServiceCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    # Rate limit check
    count_result = await db.execute(
        select(func.count(models.TaskExpertService.id)).where(
            models.TaskExpertService.user_id == current_user.id,
            models.TaskExpertService.service_type == "personal",
            models.TaskExpertService.status.in_(["active", "pending"]),
        )
    )
    count = count_result.scalar() or 0
    if count >= MAX_PERSONAL_SERVICES_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"最多创建 {MAX_PERSONAL_SERVICES_PER_USER} 个个人服务",
        )

    # id is Integer auto-increment — do NOT set it manually
    new_service = models.TaskExpertService(
        service_type="personal",
        user_id=current_user.id,
        expert_id=None,
        service_name=data.service_name,
        description=data.description,
        category=data.category,
        base_price=data.base_price or 0,
        currency=data.currency,
        pricing_type=data.pricing_type,
        location_type=data.location_type,
        location=data.location,
        latitude=data.latitude,
        longitude=data.longitude,
        images=data.images or [],
        status="active",
    )
    db.add(new_service)
    await db.commit()
    await db.refresh(new_service)
    return {"message": "服务发布成功", "service_id": new_service.id}


@personal_service_router.get("/me")
async def list_my_personal_services(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService)
        .where(
            models.TaskExpertService.user_id == current_user.id,
            models.TaskExpertService.service_type == "personal",
        )
        .order_by(models.TaskExpertService.created_at.desc())
    )
    services = result.scalars().all()
    return [_serialize_service(s) for s in services]


@personal_service_router.get("/me/{service_id}")
async def get_personal_service(
    service_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.user_id == current_user.id,
            models.TaskExpertService.service_type == "personal",
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    return _serialize_service(service)


@personal_service_router.put("/me/{service_id}")
async def update_personal_service(
    service_id: int,
    data: schemas.PersonalServiceUpdate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.service_type == "personal",
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权修改此服务")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(service, key, value)

    await db.commit()
    return {"message": "服务更新成功"}


@personal_service_router.delete("/me/{service_id}")
async def delete_personal_service(
    service_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.service_type == "personal",
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除此服务")

    await db.delete(service)
    await db.commit()
    return {"message": "服务已删除"}

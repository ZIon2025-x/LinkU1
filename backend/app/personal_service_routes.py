import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.async_routers import get_current_user_secure_async_csrf
from app.deps import get_async_db_dependency
from app.utils.bilingual_helper import detect_language_simple

logger = logging.getLogger(__name__)

personal_service_router = APIRouter(
    prefix="/api/services",
    tags=["personal-services"],
)

MAX_PERSONAL_SERVICES_PER_USER = 10


async def _auto_translate_service(
    name: str,
    description: str | None,
    name_en: str | None = None,
    name_zh: str | None = None,
    description_en: str | None = None,
    description_zh: str | None = None,
) -> tuple[str | None, str | None, str | None, str | None]:
    """
    Auto-detect language and translate service name/description bidirectionally.
    - Chinese input → fill _zh from input, translate to _en
    - English input → fill _en from input, translate to _zh
    Returns (name_en, name_zh, description_en, description_zh).
    """
    from app.utils.bilingual_helper import _translate_with_encoding_protection
    from app.translation_manager import get_translation_manager

    lang = detect_language_simple(name)

    if lang == 'zh':
        if not name_zh:
            name_zh = name
        if not name_en:
            tm = get_translation_manager()
            name_en = await _translate_with_encoding_protection(
                tm, text=name, target_lang='en', source_lang='zh-CN', max_retries=2,
            )
        if description:
            if not description_zh:
                description_zh = description
            if not description_en:
                tm = get_translation_manager()
                description_en = await _translate_with_encoding_protection(
                    tm, text=description, target_lang='en', source_lang='zh-CN', max_retries=2,
                )
    else:
        if not name_en:
            name_en = name
        if not name_zh:
            tm = get_translation_manager()
            name_zh = await _translate_with_encoding_protection(
                tm, text=name, target_lang='zh-CN', source_lang='en', max_retries=2,
            )
        if description:
            if not description_en:
                description_en = description
            if not description_zh:
                tm = get_translation_manager()
                description_zh = await _translate_with_encoding_protection(
                    tm, text=description, target_lang='zh-CN', source_lang='en', max_retries=2,
                )

    return name_en, name_zh, description_en, description_zh


def _serialize_service(s: models.TaskExpertService) -> dict:
    return {
        "id": s.id,
        "service_name": s.service_name,
        "service_name_en": s.service_name_en,
        "service_name_zh": s.service_name_zh,
        "description": s.description,
        "description_en": s.description_en,
        "description_zh": s.description_zh,
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

    # Auto-translate name and description
    service_name_en = data.service_name_en
    service_name_zh = data.service_name_zh
    description_en = data.description_en
    description_zh = data.description_zh
    try:
        service_name_en, service_name_zh, description_en, description_zh = await _auto_translate_service(
            data.service_name, data.description,
            service_name_en, service_name_zh, description_en, description_zh,
        )
    except Exception as e:
        logger.warning(f"Service auto-translate failed: {e}")

    new_service = models.TaskExpertService(
        service_type="personal",
        user_id=current_user.id,
        expert_id=None,
        service_name=data.service_name,
        service_name_en=service_name_en,
        service_name_zh=service_name_zh,
        description=data.description,
        description_en=description_en,
        description_zh=description_zh,
        category=data.category,
        base_price=data.base_price or 0,
        currency=data.currency,
        pricing_type=data.pricing_type,
        location_type=data.location_type,
        location=data.location,
        latitude=data.latitude,
        longitude=data.longitude,
        images=data.images or [],
        skills=data.skills or [],
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

    # Auto-translate if name or description changed
    new_name = update_data.get('service_name', service.service_name)
    new_desc = update_data.get('description', service.description)
    if 'service_name' in update_data or 'description' in update_data:
        try:
            name_en, name_zh, desc_en, desc_zh = await _auto_translate_service(
                new_name, new_desc,
                update_data.get('service_name_en'),
                update_data.get('service_name_zh'),
                update_data.get('description_en'),
                update_data.get('description_zh'),
            )
            update_data['service_name_en'] = name_en
            update_data['service_name_zh'] = name_zh
            update_data['description_en'] = desc_en
            update_data['description_zh'] = desc_zh
        except Exception as e:
            logger.warning(f"Service auto-translate on update failed: {e}")

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


@personal_service_router.patch("/me/{service_id}/status")
async def toggle_personal_service_status(
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
        raise HTTPException(status_code=403, detail="无权修改此服务")

    new_status = "inactive" if service.status == "active" else "active"
    service.status = new_status
    await db.commit()
    return {"message": f"服务已{'上架' if new_status == 'active' else '下架'}", "status": new_status}

"""
管理员 - 官方账号 & 官方活动管理
"""
import random
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils import get_utc_time

admin_official_router = APIRouter(
    prefix="/api/admin/official",
    tags=["admin-official"],
)


# ── 管理员认证依赖 ──────────────────────────

async def get_current_admin_async(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.AdminUser:
    """获取当前管理员（异步版本，与 admin_task_expert_routes 保持一致）"""
    from app.admin_auth import validate_admin_session

    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败，请重新登录",
        )

    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在",
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用",
        )

    return admin


# ── 工具函数 ───────────────────────────────────────

async def _get_official_expert(db: AsyncSession):
    """获取官方达人团队，不存在则报错"""
    from app.models_expert import Expert
    result = await db.execute(
        select(Expert).where(Expert.is_official == True).limit(1)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=400,
            detail="尚未设置官方账号，请先调用 /api/admin/official/account/setup"
        )
    return expert


async def _perform_draw(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """Delegate to shared draw logic."""
    from app.draw_logic import perform_draw_async
    return await perform_draw_async(db, activity)


# ── 官方账号管理 ─────────────────────────────────────

@admin_official_router.post("/account/setup", response_model=dict)
async def setup_official_account(
    data: schemas.OfficialAccountSetup,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """将指定用户设为官方达人账号"""
    user_result = await db.execute(
        select(models.User).where(models.User.id == data.user_id)
    )
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    expert_result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == data.user_id)
    )
    expert = expert_result.scalar_one_or_none()

    if not expert:
        expert = models.TaskExpert(
            id=data.user_id,
            expert_name=user.name,
            status="active",
            rating=5.0,
            total_services=0,
            completed_tasks=0,
            is_official=True,
            official_badge=data.official_badge or "官方",
        )
        db.add(expert)
    else:
        expert.is_official = True
        expert.official_badge = data.official_badge or "官方"

    # B1: 同时 mirror 到新 Expert/ExpertMember/_expert_id_migration_map
    # 让官方账号在新模型(团队 dashboard / 公开主页)下也可见。
    # 1 人团队语义: 这位 user 自己就是 owner。
    from app.models_expert import (
        Expert,
        ExpertMember,
        generate_expert_id,
    )
    from sqlalchemy import text as sa_text

    map_check = await db.execute(
        sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
        {"old_id": data.user_id},
    )
    map_row = map_check.first()

    if not map_row:
        # 生成新 8 位 id (避免与现有 experts.id 撞)
        new_expert_id = None
        for _ in range(10):
            candidate = generate_expert_id()
            exists = await db.execute(
                select(Expert).where(Expert.id == candidate)
            )
            if exists.scalar_one_or_none() is None:
                new_expert_id = candidate
                break
        if not new_expert_id:
            raise HTTPException(
                status_code=500,
                detail="无法生成唯一 expert id,请重试",
            )

        new_expert = Expert(
            id=new_expert_id,
            name=user.name or f"User {data.user_id}",
            bio=None,
            avatar=None,
            status="active",
            allow_applications=True,
            max_members=20,
            member_count=1,
            rating=5.0,
            total_services=0,
            completed_tasks=0,
            completion_rate=0.0,
            is_official=True,
            official_badge=data.official_badge or "官方",
            stripe_onboarding_complete=False,
        )
        db.add(new_expert)

        owner_member = ExpertMember(
            expert_id=new_expert_id,
            user_id=data.user_id,
            role="owner",
            status="active",
        )
        db.add(owner_member)

        # 持久化映射
        await db.execute(
            sa_text(
                "INSERT INTO _expert_id_migration_map (old_id, new_id) "
                "VALUES (:old_id, :new_id) ON CONFLICT DO NOTHING"
            ),
            {"old_id": data.user_id, "new_id": new_expert_id},
        )
    else:
        # 已有映射 — 同步 official 标记到新 Expert
        existing_new_id = map_row[0]
        existing_expert = await db.get(Expert, existing_new_id)
        if existing_expert:
            existing_expert.is_official = True
            existing_expert.official_badge = data.official_badge or "官方"

    await db.commit()
    return {"success": True, "user_id": data.user_id, "badge": expert.official_badge}


@admin_official_router.get("/account", response_model=dict)
async def get_official_account(
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """获取当前官方账号信息"""
    from app.models_expert import Expert, ExpertMember
    result = await db.execute(
        select(Expert).where(Expert.is_official == True).limit(1)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        return {"official_account": None}

    # 从 ExpertMember(owner) JOIN User 取代表用户
    owner_row = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(
            ExpertMember.expert_id == expert.id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
        .limit(1)
    )
    rec = owner_row.first()
    if not rec:
        # 数据异常(Expert 存在但无 active owner),不崩
        return {"official_account": None}
    _member, owner_user = rec
    return {
        "official_account": {
            "user_id": owner_user.id,      # 保持兼容 key: 填代表 user 的 id
            "name": owner_user.name,
            "badge": expert.official_badge,
            "avatar": expert.avatar,
            "status": expert.status,
        }
    }


# ── 官方活动 CRUD ──────────────────────────────────────────

@admin_official_router.get("/activities", response_model=dict)
async def list_official_activities(
    page: int = 1,
    limit: int = 20,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """获取官方活动列表（仅 lottery/first_come 类型）"""
    from sqlalchemy import func

    count_q = select(func.count()).select_from(models.Activity).where(
        models.Activity.activity_type.in_(["lottery", "first_come"])
    )
    total = (await db.execute(count_q)).scalar() or 0

    q = (
        select(models.Activity)
        .where(models.Activity.activity_type.in_(["lottery", "first_come"]))
        .order_by(models.Activity.id.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    rows = (await db.execute(q)).scalars().all()

    items = []
    for a in rows:
        items.append({
            "id": a.id,
            "title": a.title,
            "title_en": a.title_en,
            "title_zh": a.title_zh,
            "description": a.description or "",
            "description_en": a.description_en,
            "description_zh": a.description_zh,
            "location": a.location,
            "activity_type": a.activity_type,
            "prize_type": a.prize_type,
            "prize_description": a.prize_description,
            "prize_description_en": a.prize_description_en,
            "prize_count": a.prize_count,
            "voucher_codes": a.voucher_codes,
            "draw_mode": a.draw_mode,
            "draw_at": a.draw_at.isoformat() if a.draw_at else None,
            "deadline": a.deadline.isoformat() if a.deadline else None,
            "images": a.images,
            "is_public": a.is_public,
            "status": a.status,
            "is_drawn": a.is_drawn,
            "created_at": a.created_at.isoformat() if a.created_at else None,
            "updated_at": a.updated_at.isoformat() if a.updated_at else None,
        })

    return {"items": items, "total": total, "page": page, "limit": limit}


@admin_official_router.post("/activities", response_model=dict)
async def create_official_activity(
    data: schemas.OfficialActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """创建官方活动（抽奖 or 抢位）"""
    expert = await _get_official_expert(db)

    if data.activity_type == "lottery" and not data.draw_mode:
        raise HTTPException(status_code=400, detail="抽奖活动必须指定 draw_mode")
    if data.activity_type == "lottery" and data.draw_mode == "auto" and not data.draw_at:
        raise HTTPException(status_code=400, detail="自动开奖必须指定 draw_at")
    if data.prize_type == "voucher_code" and data.voucher_codes:
        if len(data.voucher_codes) < data.prize_count:
            raise HTTPException(
                status_code=400,
                detail=f"券码数量({len(data.voucher_codes)})少于奖品数量({data.prize_count})"
            )

    activity = models.Activity(
        title=data.title,
        title_en=data.title_en,
        title_zh=data.title_zh,
        description=data.description,
        description_en=data.description_en,
        description_zh=data.description_zh,
        location=data.location or "",
        expert_id=expert.id,
        expert_service_id=None,
        activity_type=data.activity_type,
        prize_type=data.prize_type,
        prize_description=data.prize_description,
        prize_description_en=data.prize_description_en,
        prize_count=data.prize_count,
        voucher_codes=data.voucher_codes,
        draw_mode=data.draw_mode,
        draw_at=data.draw_at,
        is_drawn=False,
        status="open",
        is_public=data.is_public,
        max_participants=data.max_participants or data.prize_count * 10,
        min_participants=1,
        completion_rule="min",
        reward_distribution="equal",
        reward_type="points" if data.prize_type == "points" else "cash",
        currency=getattr(data, "currency", None) or "GBP",
        has_time_slots=False,
        deadline=data.draw_at or data.deadline,
        images=data.images,
        task_type="official",
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    # 创建时若带了图片且是临时目录上传的，移到正式目录 activities/{id}/，避免一直留在 temp 下被清理
    if data.images:
        from app.services import ImageCategory, get_image_upload_service
        service = get_image_upload_service()
        new_images = service.move_from_temp(
            ImageCategory.ACTIVITY,
            str(admin.id),
            str(activity.id),
            data.images,
        )
        if new_images != data.images:
            activity.images = new_images
            await db.commit()

    return {"success": True, "activity_id": activity.id}


@admin_official_router.put("/activities/{activity_id}", response_model=dict)
async def update_official_activity(
    activity_id: int,
    data: schemas.OfficialActivityUpdate,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="官方活动不存在")
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail="已开奖的活动不能修改")

    update_fields = data.model_dump(exclude_none=True)
    for field, value in update_fields.items():
        setattr(activity, field, value)
    await db.commit()

    # 如果更新了图片且包含临时目录路径，移到正式目录
    if "images" in update_fields and update_fields["images"]:
        has_temp = any("/temp_" in (url or "") for url in update_fields["images"])
        if has_temp:
            from app.services import ImageCategory, get_image_upload_service
            service = get_image_upload_service()
            new_images = service.move_from_temp(
                ImageCategory.ACTIVITY,
                str(admin.id),
                str(activity.id),
                update_fields["images"],
            )
            if new_images != update_fields["images"]:
                activity.images = new_images
                await db.commit()

    return {"success": True}


@admin_official_router.delete("/activities/{activity_id}", response_model=dict)
async def cancel_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")
    activity.status = "cancelled"
    await db.commit()
    return {"success": True}


@admin_official_router.get("/activities/{activity_id}/applicants", response_model=dict)
async def get_activity_applicants(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    result = await db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(models.OfficialActivityApplication.activity_id == activity_id)
        .order_by(models.OfficialActivityApplication.applied_at)
    )
    rows = result.all()
    return {
        "total": len(rows),
        "applicants": [
            {
                "user_id": app.user_id,
                "name": user.name,
                "status": app.status,
                "applied_at": app.applied_at.isoformat(),
                "prize_index": app.prize_index,
            }
            for app, user in rows
        ],
    }


@admin_official_router.delete("/activities/{activity_id}/applicants/{user_id}", response_model=dict)
async def remove_activity_applicant(
    activity_id: int,
    user_id: str,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """移除参与官方活动的用户（仅未开奖时可用；移除后该用户不再参与抽奖/抢位）"""
    activity_result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
        )
    )
    activity = activity_result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="官方活动不存在")
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail="已开奖的活动不能移除参与者")

    app_result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == user_id,
        )
    )
    app = app_result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="该用户未报名此活动")

    await db.delete(app)
    await db.commit()
    return {"success": True, "message": "已移除该参与者"}


@admin_official_router.post("/activities/{activity_id}/draw", response_model=dict)
async def manual_draw(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """手动触发开奖"""
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type == "lottery",
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="抽奖活动不存在")
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail="已开过奖")

    winners = await _perform_draw(db, activity)
    return {"success": True, "winner_count": len(winners), "winners": winners}

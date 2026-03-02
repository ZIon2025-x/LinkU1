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

async def _get_official_expert(db: AsyncSession) -> models.TaskExpert:
    """获取官方达人账号，不存在则报错"""
    result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.is_official == True)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=400,
            detail="尚未设置官方账号，请先调用 /api/admin/official/account/setup"
        )
    return expert


async def _perform_draw(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """
    核心开奖逻辑（异步版，供 admin 手动开奖使用）：
    1. 随机抽取 prize_count 个 pending 报名者
    2. 更新 status: won/lost
    3. 分配券码（如适用）
    4. 发站内通知
    5. 更新 activity.is_drawn, drawn_at, winners
    """
    from app.async_crud import AsyncNotificationCRUD

    apps_result = await db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending",
        )
    )
    all_apps = apps_result.all()

    prize_count = activity.prize_count or 1
    selected = random.sample(all_apps, min(prize_count, len(all_apps)))
    selected_ids = {app.user_id for app, _ in selected}
    voucher_codes = activity.voucher_codes or []
    winners_data = []

    for i, (app, user) in enumerate(selected):
        app.status = "won"
        app.notified_at = get_utc_time()
        if activity.prize_type == "voucher_code" and i < len(voucher_codes):
            app.prize_index = i
        winners_data.append({
            "user_id": app.user_id,
            "name": user.name,
            "prize_index": app.prize_index,
        })

        prize_desc = activity.prize_description or "奖品"
        voucher_info = (
            f"\n您的优惠码：{voucher_codes[i]}"
            if app.prize_index is not None and i < len(voucher_codes)
            else ""
        )
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=app.user_id,
            notification_type="official_activity_won",
            title="🎉 恭喜中奖！",
            content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
            related_id=str(activity.id),
        )

    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"

    await db.commit()
    return winners_data


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

    await db.commit()
    return {"success": True, "user_id": data.user_id, "badge": expert.official_badge}


@admin_official_router.get("/account", response_model=dict)
async def get_official_account(
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_async),
):
    """获取当前官方账号信息"""
    result = await db.execute(
        select(models.TaskExpert, models.User)
        .join(models.User, models.User.id == models.TaskExpert.id)
        .where(models.TaskExpert.is_official == True)
    )
    row = result.first()
    if not row:
        return {"official_account": None}
    expert, user = row
    return {
        "official_account": {
            "user_id": expert.id,
            "name": user.name,
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
        currency="GBP",
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

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(activity, field, value)
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

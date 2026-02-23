"""
用户端 - 官方活动报名 / 取消 / 结果
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils import get_utc_time

official_activity_router = APIRouter(
    prefix="/api/official-activities",
    tags=["official-activities"],
)


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


@official_activity_router.post("/{activity_id}/apply", response_model=dict)
async def apply_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """报名官方活动（抽奖/抢位均用此接口）"""
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
            models.Activity.status == "open",
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在或已结束")

    existing = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="您已报名此活动")

    if activity.activity_type == "first_come":
        count_result = await db.execute(
            select(func.count()).select_from(models.OfficialActivityApplication).where(
                models.OfficialActivityApplication.activity_id == activity_id,
                models.OfficialActivityApplication.status == "attending",
            )
        )
        current_count = count_result.scalar() or 0
        if current_count >= (activity.prize_count or 0):
            raise HTTPException(status_code=400, detail="名额已满")
        app_status = "attending"
    else:
        app_status = "pending"

    application = models.OfficialActivityApplication(
        activity_id=activity_id,
        user_id=current_user.id,
        status=app_status,
    )
    db.add(application)
    await db.commit()
    return {
        "success": True,
        "status": app_status,
        "message": "报名成功，等待开奖" if app_status == "pending" else "报名成功！",
    }


@official_activity_router.delete("/{activity_id}/apply", response_model=dict)
async def cancel_official_activity_application(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """取消报名（截止前可取消）"""
    result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="未找到报名记录")
    if application.status in ("won", "lost"):
        raise HTTPException(status_code=400, detail="已开奖，无法取消")

    await db.delete(application)
    await db.commit()
    return {"success": True}


@official_activity_router.get("/{activity_id}/result", response_model=schemas.OfficialActivityResultOut)
async def get_official_activity_result(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看开奖结果（含我的状态）"""
    act_result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = act_result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    my_app_result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    my_app = my_app_result.scalar_one_or_none()

    my_voucher = None
    if my_app and my_app.status == "won" and my_app.prize_index is not None:
        codes = activity.voucher_codes or []
        if my_app.prize_index < len(codes):
            my_voucher = codes[my_app.prize_index]

    winners = []
    if activity.winners:
        winners = [
            schemas.ActivityWinner(
                user_id=w["user_id"],
                name=w["name"],
                prize_index=w.get("prize_index"),
            )
            for w in activity.winners
        ]

    return schemas.OfficialActivityResultOut(
        is_drawn=activity.is_drawn,
        drawn_at=activity.drawn_at,
        winners=winners,
        my_status=my_app.status if my_app else None,
        my_voucher_code=my_voucher,
    )

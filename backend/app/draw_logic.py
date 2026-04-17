"""
Shared lottery draw logic — async and sync versions.

Consumers:
- admin_official_routes.py (admin manual draw) — async
- official_draw_task.py (scheduled auto draw) — sync
- expert_activity_routes.py (expert manual draw) — async
- official_activity_routes.py (by_count trigger) — async
"""
import random
import logging
from typing import List

from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.utils import get_utc_time

logger = logging.getLogger(__name__)


async def perform_draw_async(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """Async draw: pick winners, update statuses, send notifications, commit.

    Works for all prize_type values:
    - voucher_code: assigns prize_index for code lookup
    - points / physical / in_person: winners list only, no extra distribution
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


def perform_draw_sync(db: Session, activity: models.Activity) -> List[dict]:
    """Sync draw: same logic for task-scheduler context."""
    from app.crud.notification import create_notification

    all_apps = db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending",
        )
    ).all()

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

        try:
            prize_desc = activity.prize_description or "奖品"
            voucher_info = (
                f"\n您的优惠码：{voucher_codes[i]}"
                if app.prize_index is not None and i < len(voucher_codes)
                else ""
            )
            create_notification(
                db=db,
                user_id=app.user_id,
                type="official_activity_won",
                title="🎉 恭喜中奖！",
                content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
                related_id=str(activity.id),
                related_type="activity_id",
                auto_commit=False,
            )
        except Exception as e:
            logger.warning(f"Failed to send notification to {app.user_id}: {e}")

    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"
    db.commit()
    return winners_data

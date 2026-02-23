"""
官方活动自动开奖 - task scheduler 同步任务
（保留 Celery 接口注释，便于切换）
"""
import random
import logging
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import models
from app.utils import get_utc_time

logger = logging.getLogger(__name__)


def run_auto_draws(db: Session):
    """
    定时检查需要自动开奖的活动（每 60 秒执行一次）。
    找 draw_mode=auto, is_drawn=False, draw_at <= now 的活动执行开奖。
    """
    now = get_utc_time()
    activities = db.execute(
        select(models.Activity).where(
            models.Activity.activity_type == "lottery",
            models.Activity.draw_mode == "auto",
            models.Activity.is_drawn == False,
            models.Activity.draw_at <= now,
            models.Activity.status == "open",
        )
    ).scalars().all()

    for activity in activities:
        try:
            _perform_draw_sync(db, activity)
            logger.info(f"Auto draw completed for activity {activity.id}")
        except Exception as e:
            logger.error(f"Auto draw failed for activity {activity.id}: {e}")
            db.rollback()


def _perform_draw_sync(db: Session, activity: models.Activity):
    """同步版本开奖逻辑（task scheduler 使用同步 DB session）"""
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

        # 同步通知（使用 sync crud）
        try:
            from app.crud.notification import create_notification
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


# ── Celery 接口（保留，便于切换）─────────────────────────
# 取消下方注释即可切换到 Celery
#
# from celery import shared_task
#
# @shared_task(name="official_draw.run_auto_draw")
# def celery_auto_draw(activity_id: int):
#     from app.database import SessionLocal
#     db = SessionLocal()
#     try:
#         activity = db.execute(
#             select(models.Activity).where(models.Activity.id == activity_id)
#         ).scalar_one()
#         _perform_draw_sync(db, activity)
#     finally:
#         db.close()

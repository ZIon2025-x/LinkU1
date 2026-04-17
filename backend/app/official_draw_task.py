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
    Scans ALL lottery activities (official + expert) with auto draw mode.
    Only triggers for by_time/both where draw_at has passed.
    NULL draw_trigger = legacy official activities (treat as by_time).
    """
    from app.draw_logic import perform_draw_sync

    now = get_utc_time()
    activities = db.execute(
        select(models.Activity).where(
            models.Activity.activity_type == "lottery",
            models.Activity.draw_mode == "auto",
            models.Activity.is_drawn == False,
            models.Activity.status == "open",
            models.Activity.draw_at <= now,
        )
    ).scalars().all()

    for activity in activities:
        try:
            perform_draw_sync(db, activity)
            logger.info(f"Auto draw completed for activity {activity.id}")
        except Exception as e:
            logger.error(f"Auto draw failed for activity {activity.id}: {e}")
            db.rollback()


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

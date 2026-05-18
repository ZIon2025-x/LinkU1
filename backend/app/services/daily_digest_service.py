"""Daily city task digest push.

每天固定时间扫所有 opt-in 用户，给每人查"今天 24h 内同城 + Online 新任务"数量，
≥1 个就发一条 push 摘要。按 (user_id, sent_date) 去重，每个用户每天最多一条。

候选过滤：
- UserProfilePreference.daily_digest_enabled = true
- UserProfilePreference.city 非空（且不为字面 "Online" 以避免退化）
- 有至少一个 active DeviceToken
- 当日还未推过

任务匹配（同城 ∪ Online，OR 自动去重）：
- status='open'
- created_at 在过去 WINDOW_HOURS 内
- poster_id != user_id
- task.location ILIKE '%city%' (子串)  OR  lower(task.location) IN ('online', '线上')（精确）
  - Online 用精确匹配，与 async_crud.py / admin_task_management_routes.py 等口径一致
- 用户未在 TaskApplication 申请过

文案分支：当 online_count > 0 时使用 daily_task_digest_with_online 模板；
否则使用 daily_task_digest 模板。
"""
import logging
from datetime import date, datetime, timezone, timedelta
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import select, func, or_

from app.models import (
    Task, UserProfilePreference, DailyTaskDigestPush,
    DeviceToken, TaskApplication,
)

logger = logging.getLogger(__name__)

WINDOW_HOURS = 24


def _count_today_tasks_for_user(db: Session, user_id: str, city: str) -> tuple[int, int]:
    """统计该用户今日可接的新任务数量。

    Returns:
        (total, online_count) —— total 已经过 OR 去重，online_count 是其中线上任务数。
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=WINDOW_HOURS)
    city_lower = (city or "").strip().lower()
    if not city_lower:
        return 0, 0

    not_applied = ~Task.id.in_(
        select(TaskApplication.task_id).where(
            TaskApplication.applicant_id == user_id
        )
    )
    base_filters = [
        Task.status == "open",
        Task.created_at >= cutoff,
        Task.poster_id != user_id,
        not_applied,
    ]

    online_predicate = func.lower(Task.location).in_(("online", "线上"))

    total = db.query(func.count(Task.id)).filter(
        *base_filters,
        or_(
            func.lower(Task.location).contains(city_lower),
            online_predicate,
        ),
    ).scalar() or 0

    online_count = db.query(func.count(Task.id)).filter(
        *base_filters,
        online_predicate,
    ).scalar() or 0

    return int(total), int(online_count)


def _list_candidates(db: Session):
    """返回 [(user_id, city), ...] —— 今日还可接收的候选用户。

    排除 city 字面为 "Online" / "线上" 的退化情况（这种用户的查询会等价于"全部 Online 任务"）。
    """
    return (
        db.query(UserProfilePreference.user_id, UserProfilePreference.city)
        .filter(
            UserProfilePreference.daily_digest_enabled.is_(True),
            UserProfilePreference.city.isnot(None),
            UserProfilePreference.city != "",
            ~func.lower(UserProfilePreference.city).in_(("online", "线上")),
            UserProfilePreference.user_id.in_(
                select(DeviceToken.user_id).where(
                    DeviceToken.is_active.is_(True)
                ).distinct()
            ),
        )
        .all()
    )


def run_daily_digest(db: Session, today: Optional[date] = None) -> dict:
    """主入口：跑一遍每日同城任务摘要推送。

    Returns:
        dict: {"sent": int, "skipped": int, "errors": int}
    """
    today = today or datetime.now(timezone.utc).date()

    # 当日已推过的 user_id 集合（防重）
    already_sent = {
        row[0] for row in db.query(DailyTaskDigestPush.user_id).filter(
            DailyTaskDigestPush.sent_date == today
        ).all()
    }

    candidates = _list_candidates(db)
    sent = skipped = errors = 0

    for user_id, city in candidates:
        if user_id in already_sent:
            skipped += 1
            continue
        try:
            total, online_count = _count_today_tasks_for_user(db, user_id, city)
            if total < 1:
                skipped += 1
                continue

            # 有 Online 任务时切到带细分的模板，文案展示 "(含 X 个 Online)"
            if online_count > 0:
                notification_type = "daily_task_digest_with_online"
                tpl_vars = {
                    "city": city,
                    "task_count": str(total),
                    "online_count": str(online_count),
                }
            else:
                notification_type = "daily_task_digest"
                tpl_vars = {"city": city, "task_count": str(total)}

            from app.push_notification_service import send_push_notification
            ok = send_push_notification(
                db=db,
                user_id=user_id,
                notification_type=notification_type,
                template_vars=tpl_vars,
                data={
                    "type": "daily_task_digest",
                    "city": city,
                    "task_count": str(total),
                    "online_count": str(online_count),
                },
            )
            if ok:
                db.add(DailyTaskDigestPush(
                    user_id=user_id,
                    sent_date=today,
                    task_count=total,
                    city=city,
                ))
                db.commit()
                sent += 1
            else:
                skipped += 1
        except Exception as e:
            db.rollback()
            errors += 1
            logger.warning(f"Daily digest failed user={user_id}: {e}")

    logger.info(
        f"Daily digest done: sent={sent} skipped={skipped} errors={errors} "
        f"candidates={len(candidates)}"
    )
    return {"sent": sent, "skipped": skipped, "errors": errors}


def cleanup_old_digest_pushes(db: Session, days: int = 60) -> int:
    """删除 N 天前的摘要推送记录"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    deleted = db.query(DailyTaskDigestPush).filter(
        DailyTaskDigestPush.pushed_at < cutoff
    ).delete(synchronize_session=False)
    logger.info(f"Cleaned {deleted} old daily digest push records")
    return deleted

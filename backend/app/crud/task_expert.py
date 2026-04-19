"""任务达人/特色任务达人响应时间与统计更新，独立模块便于维护与测试。"""
import logging
from datetime import timezone

from sqlalchemy import distinct, func
from sqlalchemy.orm import Session

from app import models

logger = logging.getLogger(__name__)


def _as_aware_utc(dt):
    """将 datetime 规范化为 UTC aware；naive 视为 UTC。"""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _format_response_time_short(seconds, lang="zh"):
    """将秒数格式化为简短文本（如：2小时内）。"""
    if seconds is None:
        return None
    if seconds < 3600:
        minutes = int(seconds / 60)
        if minutes == 0:
            return "1小时内" if lang == "zh" else "Within 1 hour"
        return (
            f"{minutes}分钟内"
            if lang == "zh"
            else f"Within {minutes} minutes"
        )
    if seconds < 86400:
        hours = int(seconds / 3600)
        return (
            f"{hours}小时内"
            if lang == "zh"
            else f"Within {hours} hours"
        )
    days = int(seconds / 86400)
    return f"{days}天内" if lang == "zh" else f"Within {days} days"


def update_task_expert_bio(db: Session, user_id: str):
    """计算并更新任务达人的响应时间和相关统计字段。
    bio 不在此更新；仅更新 response_time / response_time_en 及统计。
    """
    from app.models import Review, Task

    avg_response_time_seconds = None
    read_messages = (
        db.query(models.Message, models.MessageRead)
        .join(
            models.MessageRead,
            models.MessageRead.message_id == models.Message.id,
        )
        .filter(
            models.Message.receiver_id == user_id,
            models.Message.sender_id != user_id,
            models.MessageRead.user_id == user_id,
        )
        .all()
    )
    if read_messages:
        response_times = []
        for message, message_read in read_messages:
            if message.created_at and message_read.read_at:
                delta = (
                    _as_aware_utc(message_read.read_at)
                    - _as_aware_utc(message.created_at)
                ).total_seconds()
                if delta > 0:
                    response_times.append(delta)
        if response_times:
            avg_response_time_seconds = sum(response_times) / len(
                response_times
            )

    response_time_zh = _format_response_time_short(
        avg_response_time_seconds, "zh"
    )
    response_time_en = _format_response_time_short(
        avg_response_time_seconds, "en"
    )

    posted_tasks = (
        db.query(Task).filter(
            Task.poster_id == user_id,
            Task.is_consultation_placeholder == False,
        ).count()
    )
    taken_tasks = (
        db.query(Task).filter(Task.taker_id == user_id).count()
    )
    total_tasks = posted_tasks + taken_tasks
    completed_taken_tasks = (
        db.query(Task)
        .filter(
            Task.taker_id == user_id,
            Task.status == "completed",
        )
        .count()
    )
    completed_posted_tasks = (
        db.query(Task)
        .filter(
            Task.poster_id == user_id,
            Task.status == "completed",
            Task.is_consultation_placeholder == False,  # noqa: E712
        )
        .count()
    )
    completed_tasks = completed_taken_tasks + completed_posted_tasks
    completion_rate = (
        (completed_taken_tasks / taken_tasks * 100.0)
        if taken_tasks > 0
        else 0.0
    )

    avg_rating_result = (
        db.query(func.avg(Review.rating))
        .filter(Review.user_id == user_id)
        .scalar()
    )
    avg_rating = (
        float(avg_rating_result) if avg_rating_result is not None else 0.0
    )

    successful_tasks_count = (
        db.query(distinct(Task.id))
        .join(Review, Task.id == Review.task_id)
        .filter(
            Task.status == "completed",
            (Task.poster_id == user_id) | (Task.taker_id == user_id),
            Review.rating >= 3.0,
        )
        .count()
    )
    success_rate = (
        (successful_tasks_count / completed_tasks * 100.0)
        if completed_tasks > 0
        else 0.0
    )

    # Phase A: 写 Expert 代替 FeaturedTaskExpert (通过 _expert_id_migration_map 查 team_id)
    from sqlalchemy import text as sa_text
    from app.models_expert import Expert

    map_row = db.execute(
        sa_text(
            "SELECT new_id FROM _expert_id_migration_map WHERE old_id = :uid"
        ),
        {"uid": user_id},
    ).first()

    if map_row:
        expert_id = map_row[0]
        expert = db.get(Expert, expert_id)
        if expert:
            expert.response_time = response_time_zh
            expert.response_time_en = response_time_en
            expert.rating = avg_rating  # FTE.avg_rating → Expert.rating (字段名不同)
            expert.completed_tasks = completed_tasks
            # Expert 无 total_tasks 字段;该统计只在 FTE 有过,Phase A 不迁
            expert.completion_rate = completion_rate
            expert.success_rate = success_rate  # 210 migration 已加此列
            db.commit()
            db.refresh(expert)

    return response_time_zh


def update_all_task_experts_bio():
    """更新所有任务达人的响应时间和统计（每天执行）。已弃用，委托给 update_all_featured_task_experts_response_time。"""
    return update_all_featured_task_experts_response_time()


def update_all_featured_task_experts_response_time():
    """更新所有 Expert 团队 owner 的响应时间/统计（每天执行一次）。

    Phase A: 遍历 Expert owner users 调 update_task_expert_bio (签名保持
    user_id,内部通过映射找 Expert 团队写入).
    函数名保留(已有 Celery/scheduler 调用),语义迁移到 Expert.
    """
    from app.database import SessionLocal
    from app.models_expert import ExpertMember

    db = None
    try:
        db = SessionLocal()
        # 取所有 active owner 的 user_id
        owner_rows = (
            db.query(ExpertMember.user_id)
            .filter(
                ExpertMember.role == "owner",
                ExpertMember.status == "active",
            )
            .all()
        )
        updated_count = 0
        for (user_id,) in owner_rows:
            try:
                update_task_expert_bio(db, user_id)
                updated_count += 1
            except Exception as e:
                logger.error(
                    "更新 expert team owner %s 的响应时间时出错: %s",
                    user_id,
                    e,
                )
                continue
        if updated_count > 0:
            logger.info(
                "成功更新 %s 个 expert team owner 的响应时间/统计",
                updated_count,
            )
    finally:
        if db is not None:
            db.close()

"""任务达人/特色任务达人响应时间与统计更新，独立模块便于维护与测试。"""
import logging

from sqlalchemy import distinct, func
from sqlalchemy.orm import Session

from app import models

logger = logging.getLogger(__name__)


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
                    message_read.read_at - message.created_at
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
        db.query(Task).filter(Task.poster_id == user_id).count()
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

    featured_expert = (
        db.query(models.FeaturedTaskExpert)
        .filter(models.FeaturedTaskExpert.id == user_id)
        .first()
    )
    if featured_expert:
        featured_expert.response_time = response_time_zh
        featured_expert.response_time_en = response_time_en
        featured_expert.avg_rating = avg_rating
        featured_expert.completed_tasks = completed_tasks
        featured_expert.total_tasks = total_tasks
        featured_expert.completion_rate = completion_rate
        featured_expert.success_rate = success_rate
        db.commit()
        db.refresh(featured_expert)

    return response_time_zh


def update_all_task_experts_bio():
    """更新所有任务达人的响应时间和统计（每天执行）。已弃用，委托给 update_all_featured_task_experts_response_time。"""
    return update_all_featured_task_experts_response_time()


def update_all_featured_task_experts_response_time():
    """更新所有 FeaturedTaskExpert 的响应时间（每天执行一次）。"""
    from app.database import SessionLocal
    from app.models import FeaturedTaskExpert

    db = None
    try:
        db = SessionLocal()
        featured_experts = db.query(FeaturedTaskExpert).all()
        updated_count = 0
        for expert in featured_experts:
            try:
                update_task_expert_bio(db, expert.id)
                updated_count += 1
            except Exception as e:
                logger.error(
                    "更新特征任务达人 %s 的响应时间时出错: %s",
                    expert.id,
                    e,
                )
                continue
        if updated_count > 0:
            logger.info(
                "成功更新 %s 个特征任务达人的响应时间",
                updated_count,
            )
        else:
            logger.info("没有需要更新的特征任务达人")
        return updated_count
    except Exception as e:
        logger.error("更新特征任务达人响应时间时出错: %s", e)
        raise
    finally:
        if db:
            db.close()

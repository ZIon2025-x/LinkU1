"""Reliability score calculator with event-driven incremental updates."""
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import UserReliability

MINIMUM_TASKS_THRESHOLD = 3


def calculate_reliability_score(reliability: UserReliability) -> float | None:
    """Calculate composite reliability score (0-100). Returns None if insufficient data."""
    if reliability.total_tasks_taken < MINIMUM_TASKS_THRESHOLD:
        return None
    return (
        reliability.completion_rate * 30 +
        reliability.on_time_rate * 25 +
        (1 - reliability.cancellation_rate) * 20 +
        (reliability.communication_score / 5.0) * 15 +
        (1 - reliability.complaint_rate) * 10
    )


def get_or_create_reliability(db: Session, user_id: str) -> UserReliability:
    """Get existing reliability record or create a new one."""
    reliability = db.query(UserReliability).filter(
        UserReliability.user_id == user_id
    ).first()
    if not reliability:
        reliability = UserReliability(user_id=user_id)
        db.add(reliability)
        db.flush()
    return reliability


def on_task_completed(db: Session, user_id: str, was_on_time: bool):
    """Update reliability when a task is completed."""
    reliability = get_or_create_reliability(db, user_id)
    reliability.total_tasks_taken += 1
    old_count = reliability.total_tasks_taken - 1
    reliability.completion_rate = (
        (reliability.completion_rate * old_count + 1.0) / reliability.total_tasks_taken
    )
    on_time_val = 1.0 if was_on_time else 0.0
    reliability.on_time_rate = (
        (reliability.on_time_rate * old_count + on_time_val) / reliability.total_tasks_taken
    )
    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_task_cancelled(db: Session, user_id: str):
    """Update reliability when a task is cancelled by the taker."""
    reliability = get_or_create_reliability(db, user_id)
    reliability.total_tasks_taken += 1
    old_count = reliability.total_tasks_taken - 1
    reliability.completion_rate = (
        (reliability.completion_rate * old_count) / reliability.total_tasks_taken
    )
    reliability.cancellation_rate = (
        (reliability.cancellation_rate * old_count + 1.0) / reliability.total_tasks_taken
    )
    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_review_created(db: Session, user_id: str, communication_rating: float):
    """Update communication score when a review is received."""
    reliability = get_or_create_reliability(db, user_id)
    if reliability.communication_score == 0.0:
        reliability.communication_score = communication_rating
    else:
        reliability.communication_score = (
            0.7 * reliability.communication_score + 0.3 * communication_rating
        )
    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_complaint_created(db: Session, user_id: str):
    """Update complaint rate when a complaint is filed."""
    reliability = get_or_create_reliability(db, user_id)
    if reliability.total_tasks_taken > 0:
        current_complaints = reliability.complaint_rate * reliability.total_tasks_taken
        reliability.complaint_rate = (current_complaints + 1) / reliability.total_tasks_taken
    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_application_responded(db: Session, user_id: str, response_seconds: float):
    """Update average response speed when a helper responds to an application."""
    reliability = get_or_create_reliability(db, user_id)
    if reliability.response_speed_avg == 0.0:
        reliability.response_speed_avg = response_seconds
    else:
        reliability.response_speed_avg = (
            0.7 * reliability.response_speed_avg + 0.3 * response_seconds
        )
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_task_assigned(db: Session, helper_user_id: str, poster_user_id: str):
    """Update repeat_rate when a task is assigned."""
    from app.models import Task
    reliability = get_or_create_reliability(db, helper_user_id)
    times_selected = db.query(func.count(Task.id)).filter(
        Task.poster_id == poster_user_id,
        Task.taker_id == helper_user_id,
        Task.status.in_(["completed", "confirmed", "in_progress"])
    ).scalar() or 0
    if times_selected > 1:
        total_assignments = db.query(func.count(Task.id)).filter(
            Task.taker_id == helper_user_id,
            Task.status.in_(["completed", "confirmed", "in_progress"])
        ).scalar() or 1
        repeat_assignments = db.query(func.count(Task.id)).filter(
            Task.taker_id == helper_user_id,
            Task.poster_id.in_(
                db.query(Task.poster_id).filter(
                    Task.taker_id == helper_user_id
                ).group_by(Task.poster_id).having(func.count(Task.id) > 1)
            )
        ).scalar() or 0
        reliability.repeat_rate = repeat_assignments / total_assignments
    reliability.last_calculated_at = datetime.now(timezone.utc)


def recalculate_all_reliability(db: Session, limit: int = 500):
    """Weekly full recalculation to fix incremental drift."""
    from app.models import Task, User
    users = db.query(User).filter(User.task_count > 0).limit(limit).all()
    for user in users:
        reliability = get_or_create_reliability(db, user.id)
        taken_tasks = db.query(Task).filter(Task.taker_id == user.id).all()
        total = len(taken_tasks)
        if total == 0:
            continue
        completed = sum(1 for t in taken_tasks if t.status in ("completed", "confirmed"))
        cancelled = sum(1 for t in taken_tasks if t.status == "cancelled" and t.taker_id == user.id)
        on_time = sum(1 for t in taken_tasks if t.status in ("completed", "confirmed")
                      and t.deadline and t.completed_at and t.completed_at <= t.deadline)
        reliability.total_tasks_taken = total
        reliability.completion_rate = completed / total
        reliability.cancellation_rate = cancelled / total
        reliability.on_time_rate = on_time / max(completed, 1)
        reliability.reliability_score = calculate_reliability_score(reliability)
        reliability.last_calculated_at = datetime.now(timezone.utc)

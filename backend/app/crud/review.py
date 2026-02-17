"""评价相关 CRUD，独立模块便于维护与测试。"""
from html import escape

from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.crud.user import update_user_statistics


def get_user_reviews(db: Session, user_id: str, limit: int = 5):
    return (
        db.query(models.Review)
        .filter(models.Review.user_id == user_id)
        .order_by(models.Review.created_at.desc())
        .limit(limit)
        .all()
    )


def get_reviews_received_by_user(db: Session, user_id: str, limit: int = 5):
    """获取用户收到的评价（其他用户对该用户的评价），含评价者信息。"""
    return (
        db.query(models.Review, models.User)
        .select_from(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .join(models.User, models.Review.user_id == models.User.id)
        .filter(
            ((models.Task.poster_id == user_id) & (models.Review.user_id == models.Task.taker_id))
            | ((models.Task.taker_id == user_id) & (models.Review.user_id == models.Task.poster_id))
        )
        .order_by(models.Review.created_at.desc())
        .limit(limit)
        .all()
    )


def get_user_reviews_with_reviewer_info(db: Session, user_id: str, limit: int = 5):
    """获取用户收到的评价，包含评价者信息（用于个人主页显示）"""
    reviews = (
        db.query(models.Review, models.User, models.Task)
        .join(models.User, models.Review.user_id == models.User.id)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .filter(
            ((models.Task.poster_id == user_id) & (models.Review.user_id == models.Task.taker_id))
            | ((models.Task.taker_id == user_id) & (models.Review.user_id == models.Task.poster_id))
        )
        .order_by(models.Review.created_at.desc())
        .limit(limit)
        .all()
    )
    result = []
    for review, reviewer, task in reviews:
        result.append(
            {
                "id": review.id,
                "task_id": review.task_id,
                "user_id": review.user_id,
                "rating": review.rating,
                "comment": review.comment,
                "is_anonymous": bool(review.is_anonymous),
                "created_at": review.created_at,
                "reviewer_name": "匿名用户" if review.is_anonymous else reviewer.name,
                "reviewer_avatar": reviewer.avatar if not review.is_anonymous else "",
                "task_title": task.title,
            }
        )
    return result


def calculate_user_avg_rating(db: Session, user_id: str):
    """计算并更新用户的平均评分"""
    result = (
        db.query(func.avg(models.Review.rating))
        .filter(models.Review.user_id == user_id)
        .scalar()
    )
    avg_rating = float(result) if result is not None else 0.0
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)
    return avg_rating


def create_review(
    db: Session, user_id: str, task_id: int, review: schemas.ReviewCreate
):
    from app.models import Review, Task

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task or task.status != "completed":
        return None

    is_participant = False
    if task.poster_id == user_id or task.taker_id == user_id:
        is_participant = True
    elif task.is_multi_participant:
        from app.models import TaskParticipant

        participant = (
            db.query(TaskParticipant)
            .filter(
                TaskParticipant.task_id == task_id,
                TaskParticipant.user_id == user_id,
                TaskParticipant.status.in_(
                    ["accepted", "in_progress", "completed"]
                ),
            )
            .first()
        )
        if participant:
            is_participant = True

    if not is_participant:
        return None

    existing_review = (
        db.query(Review)
        .filter(Review.task_id == task_id, Review.user_id == user_id)
        .first()
    )
    if existing_review:
        return None

    cleaned_comment = None
    if review.comment:
        cleaned_comment = escape(review.comment.strip())
        if len(cleaned_comment) > 500:
            cleaned_comment = cleaned_comment[:500]

    db_review = Review(
        user_id=user_id,
        task_id=task_id,
        rating=review.rating,
        comment=cleaned_comment,
        is_anonymous=1 if review.is_anonymous else 0,
    )
    db.add(db_review)
    db.commit()
    db.refresh(db_review)

    reviewed_user_id = None
    if task.is_multi_participant:
        if task.created_by_expert and task.expert_creator_id:
            if user_id != task.expert_creator_id:
                reviewed_user_id = task.expert_creator_id
            elif task.originating_user_id:
                reviewed_user_id = task.originating_user_id
        elif task.taker_id and user_id != task.taker_id:
            reviewed_user_id = task.taker_id
    else:
        reviewed_user_id = (
            task.taker_id if user_id == task.poster_id else task.poster_id
        )

    if reviewed_user_id:
        update_user_statistics(db, reviewed_user_id)

    return db_review


def get_task_reviews(db: Session, task_id: int):
    """获取任务评价 - 只返回实名评价，匿名评价不显示在任务页面"""
    return (
        db.query(models.Review)
        .filter(
            models.Review.task_id == task_id,
            models.Review.is_anonymous == 0,
        )
        .all()
    )


def get_user_received_reviews(db: Session, user_id: str):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return (
        db.query(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .filter(
            (models.Task.poster_id == user_id)
            | (models.Task.taker_id == user_id),
            models.Review.user_id != user_id,
        )
        .all()
    )

"""评价相关 CRUD，独立模块便于维护与测试。"""
from html import escape

from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models, schemas
from app.crud.user import update_user_statistics


def get_user_reviews(db: Session, user_id: str, limit: int = 5):
    return (
        db.query(models.Review)
        .filter(models.Review.user_id == user_id, models.Review.is_deleted.is_(False))
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
            models.Review.is_deleted.is_(False),
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
            models.Review.is_deleted.is_(False),
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


def update_expert_team_statistics(db: Session, expert_id: str):
    """聚合并更新达人团队的评分 / 完成任务数 / 完成率。

    在每次创建针对团队任务的 Review 后调用,确保团队详情/列表展示的
    rating 和 completed_tasks 与实际评价/任务状态保持一致。

    Args:
        expert_id: 新 experts 表的 id (8 位字符串)
    """
    from decimal import Decimal
    from app.models_expert import Expert
    from app.models import Review, Task

    expert = db.query(Expert).filter(Expert.id == expert_id).first()
    if not expert:
        return None

    # 1) 平均评分: 仅取这条团队收到的评价
    avg_rating_result = (
        db.query(func.avg(Review.rating))
        .filter(Review.expert_id == expert_id, Review.is_deleted.is_(False))
        .scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    # 2) 完成任务数: 这个团队作为 taker 的已完成任务
    completed_tasks = (
        db.query(Task)
        .filter(Task.taker_expert_id == expert_id, Task.status == "completed")
        .count()
    )

    # 3) 完成率: completed / 已派单(taken_expert + completed)
    total_taken = (
        db.query(Task)
        .filter(
            Task.taker_expert_id == expert_id,
            Task.status.in_(["in_progress", "completed", "pending_confirmation", "disputed"]),
        )
        .count()
    )
    completion_rate = (completed_tasks / total_taken * 100.0) if total_taken > 0 else 0.0

    expert.rating = Decimal(str(avg_rating)).quantize(Decimal("0.01"))
    expert.completed_tasks = completed_tasks
    expert.completion_rate = completion_rate
    db.commit()
    db.refresh(expert)
    return {
        "rating": float(expert.rating),
        "completed_tasks": completed_tasks,
        "completion_rate": completion_rate,
    }


async def update_expert_team_statistics_async(db, expert_id: str):
    """异步版 update_expert_team_statistics，用于 async 路由。

    逻辑与同步版完全一致：聚合评分 / 完成任务数 / 完成率。
    """
    from decimal import Decimal
    from sqlalchemy import select, and_
    from app.models_expert import Expert
    from app.models import Review, Task

    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        return None

    # 1) 平均评分
    avg_result = await db.execute(
        select(func.avg(Review.rating)).where(
            Review.expert_id == expert_id,
            Review.is_deleted.is_(False),
        )
    )
    avg_rating_val = avg_result.scalar()
    avg_rating = float(avg_rating_val) if avg_rating_val is not None else 0.0

    # 2) 完成任务数
    completed_result = await db.execute(
        select(func.count()).select_from(Task).where(
            and_(Task.taker_expert_id == expert_id, Task.status == "completed")
        )
    )
    completed_tasks = completed_result.scalar()

    # 3) 完成率
    taken_result = await db.execute(
        select(func.count()).select_from(Task).where(
            and_(
                Task.taker_expert_id == expert_id,
                Task.status.in_(["in_progress", "completed", "pending_confirmation", "disputed"]),
            )
        )
    )
    total_taken = taken_result.scalar()
    completion_rate = (completed_tasks / total_taken * 100.0) if total_taken > 0 else 0.0

    expert.rating = Decimal(str(avg_rating)).quantize(Decimal("0.01"))
    expert.completed_tasks = completed_tasks
    expert.completion_rate = completion_rate
    await db.commit()
    await db.refresh(expert)
    return {
        "rating": float(expert.rating),
        "completed_tasks": completed_tasks,
        "completion_rate": completion_rate,
    }


def calculate_user_avg_rating(db: Session, user_id: str):
    """计算并更新用户的平均评分"""
    result = (
        db.query(func.avg(models.Review.rating))
        .filter(models.Review.user_id == user_id, models.Review.is_deleted.is_(False))
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
    """创建评价。成功返回 Review 对象，失败返回错误原因字符串。"""
    from app.models import Review, Task

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task or task.status != "completed":
        return "task_not_completed"

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
        return "not_participant"

    # 仅检查"未删除"的评价 —— 软删除的历史记录不阻塞新评价,
    # 这为未来"改评"功能预留通道(先 soft-delete 旧记录再创建新记录)。
    # DB 层有 partial UNIQUE 约束兜底(见 migration 212)。
    existing_review = (
        db.query(Review)
        .filter(
            Review.task_id == task_id,
            Review.user_id == user_id,
            Review.is_deleted.is_(False),
        )
        .first()
    )
    if existing_review:
        return "already_reviewed"

    cleaned_comment = None
    if review.comment:
        cleaned_comment = escape(review.comment.strip())
        if len(cleaned_comment) > 500:
            cleaned_comment = cleaned_comment[:500]

    # 团队任务: 把 expert_id 同步过来,这样:
    #   1) GET /api/experts/{id}/reviews 能查到这条评价
    #   2) 团队 Owner/Admin 可以回复 (expert_marketing_routes)
    #   3) Expert.rating 聚合(下方 update_user_statistics)能正确归并到团队
    review_expert_id = task.taker_expert_id if getattr(task, 'taker_expert_id', None) else None

    db_review = Review(
        user_id=user_id,
        task_id=task_id,
        rating=review.rating,
        comment=cleaned_comment,
        is_anonymous=1 if review.is_anonymous else 0,
        expert_id=review_expert_id,
    )
    db.add(db_review)
    # DB 层 partial UNIQUE 兜底:应用层检查失败时(并发),IntegrityError 捕获后返回业务错误码
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        return "already_reviewed"
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
        # 更新可靠度画像（被评价方）
        try:
            from app.services.reliability_calculator import on_review_created
            on_review_created(db, reviewed_user_id, float(review.rating))
            db.commit()
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f"更新可靠度失败(review_created): {e}")

    # 团队任务: 同步聚合到 Expert 团队评分
    if review_expert_id:
        try:
            update_expert_team_statistics(db, review_expert_id)
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f"更新团队评分失败: {e}")

    return db_review


def get_task_reviews(db: Session, task_id: int, current_user_id: str | None = None):
    """获取任务评价 - 返回非匿名评价 + 当前用户自己的匿名评价"""
    query = db.query(models.Review).filter(
        models.Review.task_id == task_id,
        models.Review.is_deleted.is_(False),
    )
    if current_user_id:
        query = query.filter(
            or_(
                models.Review.is_anonymous == 0,
                models.Review.user_id == current_user_id,
            )
        )
    else:
        query = query.filter(models.Review.is_anonymous == 0)
    return query.all()


def get_user_received_reviews(db: Session, user_id: str):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return (
        db.query(models.Review)
        .join(models.Task, models.Review.task_id == models.Task.id)
        .filter(
            (models.Task.poster_id == user_id)
            | (models.Task.taker_id == user_id),
            models.Review.user_id != user_id,
            models.Review.is_deleted.is_(False),
        )
        .all()
    )

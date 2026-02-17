"""用户相关 CRUD（User 表及统计同步），独立模块便于维护与测试。"""
import re
import random
from decimal import Decimal

from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app import models, schemas
from app.utils.time_utils import parse_iso_utc
from app.security import get_password_hash


def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()


def get_user_by_phone(db: Session, phone: str):
    """通过手机号查找用户。支持带+完整格式、07 开头 11 位、清理后数字。"""
    user = db.query(models.User).filter(models.User.phone == phone).first()
    if user:
        return user

    digits = re.sub(r"\D", "", phone)
    if len(digits) == 11 and digits.startswith("07"):
        formatted_phone = f"+44{digits[1:]}"
        user = db.query(models.User).filter(models.User.phone == formatted_phone).first()
        if user:
            return user

    return db.query(models.User).filter(models.User.phone == digits).first()


def get_user_by_id(db: Session, user_id: str):
    from app.redis_cache import get_user_info, cache_user_info

    cached_user = get_user_info(user_id)

    if cached_user and isinstance(cached_user, dict):
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if user:
            cache_user_info(user_id, user)
        return user

    if cached_user and hasattr(cached_user, "__table__"):
        return cached_user

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        cache_user_info(user_id, user)
    return user


def get_all_users(db: Session):
    return db.query(models.User).all()


def update_user_statistics(db: Session, user_id: str):
    """自动更新用户的统计信息：task_count, completed_task_count 和 avg_rating；
    同时同步更新 TaskExpert 与 FeaturedTaskExpert（如存在）。"""
    from app.models import Review, Task

    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()
    taken_tasks = db.query(Task).filter(Task.taker_id == user_id).count()
    total_tasks = posted_tasks + taken_tasks

    completed_taken_tasks = db.query(Task).filter(
        Task.taker_id == user_id, Task.status == "completed"
    ).count()
    completed_posted_tasks = db.query(Task).filter(
        Task.poster_id == user_id, Task.status == "completed"
    ).count()
    completed_tasks = completed_taken_tasks + completed_posted_tasks

    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    completion_rate = (
        (completed_taken_tasks / taken_tasks * 100.0) if taken_tasks > 0 else 0.0
    )

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.task_count = total_tasks
        user.completed_task_count = completed_tasks
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)

        task_expert = (
            db.query(models.TaskExpert)
            .options(joinedload(models.TaskExpert.services))
            .filter(models.TaskExpert.id == user_id)
            .first()
        )
        if task_expert:
            task_expert.completed_tasks = completed_tasks
            task_expert.rating = Decimal(str(avg_rating)).quantize(Decimal("0.01"))
            db.commit()
            db.refresh(task_expert)

        featured_expert = (
            db.query(models.FeaturedTaskExpert)
            .filter(models.FeaturedTaskExpert.id == user_id)
            .first()
        )
        if featured_expert:
            featured_expert.avg_rating = avg_rating
            featured_expert.completed_tasks = completed_tasks
            featured_expert.total_tasks = total_tasks
            featured_expert.completion_rate = completion_rate
            db.commit()
            db.refresh(featured_expert)

    return {
        "task_count": total_tasks,
        "completed_task_count": completed_tasks,
        "avg_rating": avg_rating,
    }


def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = get_password_hash(user.password)

    while True:
        user_id = str(random.randint(10000000, 99999999))
        existing_user = (
            db.query(models.User).filter(models.User.id == user_id).first()
        )
        if not existing_user:
            break

    terms_agreed_at = None
    if user.terms_agreed_at:
        raw = user.terms_agreed_at.replace("Z", "+00:00") if user.terms_agreed_at.endswith("Z") else user.terms_agreed_at
        terms_agreed_at = parse_iso_utc(raw)

    db_user = models.User(
        id=user_id,
        name=user.name,
        email=user.email,
        phone=user.phone,
        hashed_password=hashed_password,
        avatar=user.avatar or "",
        agreed_to_terms=1 if user.agreed_to_terms else 0,
        terms_agreed_at=terms_agreed_at,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

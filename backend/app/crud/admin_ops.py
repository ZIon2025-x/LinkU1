"""管理后台操作用户/管理员列表与更新（白名单字段），独立模块便于维护与测试。"""
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models

ALLOWED_USER_UPDATE_FIELDS = {
    "user_level",
    "is_active",
    "is_banned",
    "is_suspended",
    "suspend_until",
    "name",
    "avatar",
    "email",
    "phone",
    "bio",
    "residence_city",
    "language_preference",
    "is_verified",
    "is_student_verified",
}


def get_users_for_admin(
    db: Session, skip: int = 0, limit: int = 20, search: str = None
):
    """管理员获取用户列表，支持 pg_trgm 搜索。"""
    query = db.query(models.User)
    if search:
        search_clean = search.strip()
        query = query.filter(
            or_(
                func.similarity(models.User.name, search_clean) > 0.2,
                func.similarity(models.User.email, search_clean) > 0.2,
                models.User.id.contains(search_clean),
                models.User.name.ilike(f"%{search_clean}%"),
                models.User.email.ilike(f"%{search_clean}%"),
            )
        )
    total = query.count()
    users = query.offset(skip).limit(limit).all()
    return {"users": users, "total": total}


def get_admin_users_for_admin(
    db: Session, skip: int = 0, limit: int = 20
):
    """超级管理员获取管理员列表。"""
    query = db.query(models.AdminUser)
    total = query.count()
    admin_users = query.offset(skip).limit(limit).all()
    return {"admin_users": admin_users, "total": total}


def delete_admin_user_by_super_admin(db: Session, admin_id: str):
    """超级管理员删除管理员账号。不可删自己；若有关联 JobPosition/FeaturedTaskExpert/AdminReward 则不可删。"""
    admin = (
        db.query(models.AdminUser)
        .filter(models.AdminUser.id == admin_id)
        .first()
    )
    if not admin:
        return False
    if admin.is_super_admin:
        return False
    job_count = (
        db.query(models.JobPosition)
        .filter(models.JobPosition.created_by == admin_id)
        .count()
    )
    expert_count = (
        db.query(models.FeaturedTaskExpert)
        .filter(models.FeaturedTaskExpert.created_by == admin_id)
        .count()
    )
    reward_count = (
        db.query(models.AdminReward)
        .filter(models.AdminReward.created_by == admin_id)
        .count()
    )
    if job_count > 0 or expert_count > 0 or reward_count > 0:
        return False
    db.delete(admin)
    db.commit()
    return True


def update_user_by_admin(db: Session, user_id: str, user_update: dict):
    """管理员更新用户信息（仅允许白名单字段）。返回 (user, old_values, new_values)，有变更时 old_values/new_values 非 None。"""
    user = (
        db.query(models.User)
        .filter(models.User.id == user_id)
        .first()
    )
    if not user:
        return None, None, None
    old_values = {}
    new_values = {}
    for field, value in user_update.items():
        if field not in ALLOWED_USER_UPDATE_FIELDS:
            continue
        if value is not None and hasattr(user, field):
            old_val = getattr(user, field)
            if old_val != value:
                old_values[field] = old_val
                new_values[field] = value
                setattr(user, field, value)
    db.commit()
    db.refresh(user)
    if old_values:
        return user, old_values, new_values
    return user, None, None

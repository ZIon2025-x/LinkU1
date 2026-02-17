"""后台管理员（AdminUser）相关 CRUD，独立模块便于维护与测试。"""
import random

from sqlalchemy.orm import Session

from app import models
from app.id_generator import format_admin_id
from app.security import get_password_hash, verify_password
from app.utils.time_utils import get_utc_time


def get_admin_user_by_username(db: Session, username: str):
    """根据用户名获取后台管理员"""
    return (
        db.query(models.AdminUser)
        .filter(models.AdminUser.username == username)
        .first()
    )


def get_admin_user_by_id(db: Session, admin_id: str):
    """根据ID获取后台管理员"""
    return (
        db.query(models.AdminUser)
        .filter(models.AdminUser.id == admin_id)
        .first()
    )


def get_admin_user_by_email(db: Session, email: str):
    """根据邮箱获取后台管理员"""
    return (
        db.query(models.AdminUser)
        .filter(models.AdminUser.email == email)
        .first()
    )


def authenticate_admin_user(db: Session, username: str, password: str):
    """验证后台管理员登录凭据，成功返回 AdminUser，否则 False"""
    admin = get_admin_user_by_username(db, username)
    if not admin or not admin.is_active:
        return False
    if not verify_password(password, admin.hashed_password):
        return False
    return admin


def create_admin_user(db: Session, admin_data: dict):
    """创建后台管理员账号。is_super_admin 始终由服务端设为 0。"""
    hashed_password = get_password_hash(admin_data["password"])
    while True:
        random_id = random.randint(1000, 9999)
        admin_id = format_admin_id(random_id)
        existing = (
            db.query(models.AdminUser)
            .filter(models.AdminUser.id == admin_id)
            .first()
        )
        if not existing:
            break
    admin = models.AdminUser(
        id=admin_id,
        name=admin_data["name"],
        username=admin_data["username"],
        email=admin_data["email"],
        hashed_password=hashed_password,
        is_super_admin=0,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


def update_admin_last_login(db: Session, admin_id: str):
    """更新管理员最后登录时间"""
    admin = (
        db.query(models.AdminUser)
        .filter(models.AdminUser.id == admin_id)
        .first()
    )
    if admin:
        admin.last_login = get_utc_time()
        db.commit()
        db.refresh(admin)
    return admin

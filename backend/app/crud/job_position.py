"""岗位（JobPosition）相关 CRUD，独立模块便于维护与测试。"""
import json
from typing import Optional

from sqlalchemy.orm import Session

from app import models, schemas
from app.utils.time_utils import get_utc_time


def create_job_position(
    db: Session, position: schemas.JobPositionCreate, created_by: str
):
    """创建岗位"""
    db_position = models.JobPosition(
        title=position.title,
        title_en=position.title_en,
        department=position.department,
        department_en=position.department_en,
        type=position.type,
        type_en=position.type_en,
        location=position.location,
        location_en=position.location_en,
        experience=position.experience,
        experience_en=position.experience_en,
        salary=position.salary,
        salary_en=position.salary_en,
        description=position.description,
        description_en=position.description_en,
        requirements=json.dumps(position.requirements, ensure_ascii=False),
        requirements_en=(
            json.dumps(position.requirements_en, ensure_ascii=False)
            if position.requirements_en
            else None
        ),
        tags=(
            json.dumps(position.tags, ensure_ascii=False)
            if position.tags
            else None
        ),
        tags_en=(
            json.dumps(position.tags_en, ensure_ascii=False)
            if position.tags_en
            else None
        ),
        is_active=1 if position.is_active else 0,
        created_by=created_by,
    )
    db.add(db_position)
    db.commit()
    db.refresh(db_position)
    return db_position


def get_job_position(db: Session, position_id: int):
    """获取单个岗位"""
    return (
        db.query(models.JobPosition)
        .filter(models.JobPosition.id == position_id)
        .first()
    )


def get_job_positions(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    department: Optional[str] = None,
    type: Optional[str] = None,
):
    """获取岗位列表，返回 (positions, total)。"""
    query = db.query(models.JobPosition)
    if is_active is not None:
        query = query.filter(
            models.JobPosition.is_active == (1 if is_active else 0)
        )
    if department:
        query = query.filter(models.JobPosition.department == department)
    if type:
        query = query.filter(models.JobPosition.type == type)
    total = query.count()
    positions = query.offset(skip).limit(limit).all()
    return positions, total


def update_job_position(
    db: Session, position_id: int, position: schemas.JobPositionUpdate
):
    """更新岗位"""
    db_position = (
        db.query(models.JobPosition)
        .filter(models.JobPosition.id == position_id)
        .first()
    )
    if not db_position:
        return None
    update_data = position.dict(exclude_unset=True)
    if "requirements" in update_data and update_data["requirements"] is not None:
        update_data["requirements"] = json.dumps(
            update_data["requirements"], ensure_ascii=False
        )
    if (
        "requirements_en" in update_data
        and update_data["requirements_en"] is not None
    ):
        update_data["requirements_en"] = json.dumps(
            update_data["requirements_en"], ensure_ascii=False
        )
    if "tags" in update_data and update_data["tags"] is not None:
        update_data["tags"] = json.dumps(
            update_data["tags"], ensure_ascii=False
        )
    if "tags_en" in update_data and update_data["tags_en"] is not None:
        update_data["tags_en"] = json.dumps(
            update_data["tags_en"], ensure_ascii=False
        )
    if "is_active" in update_data:
        update_data["is_active"] = 1 if update_data["is_active"] else 0
    for field, value in update_data.items():
        setattr(db_position, field, value)
    db_position.updated_at = get_utc_time()
    db.commit()
    db.refresh(db_position)
    return db_position


def delete_job_position(db: Session, position_id: int):
    """删除岗位"""
    db_position = (
        db.query(models.JobPosition)
        .filter(models.JobPosition.id == position_id)
        .first()
    )
    if not db_position:
        return False
    db.delete(db_position)
    db.commit()
    return True


def toggle_job_position_status(db: Session, position_id: int):
    """切换岗位启用状态"""
    db_position = (
        db.query(models.JobPosition)
        .filter(models.JobPosition.id == position_id)
        .first()
    )
    if not db_position:
        return None
    db_position.is_active = 1 if db_position.is_active == 0 else 0
    db_position.updated_at = get_utc_time()
    db.commit()
    db.refresh(db_position)
    return db_position

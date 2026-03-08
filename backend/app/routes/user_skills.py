"""
用户技能管理路由
实现用户技能的增删查以及技能分类查询
"""

import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/skills", tags=["用户技能"])


@router.get("/my")
def get_my_skills(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户的技能列表"""
    skills = (
        db.query(models.UserSkill)
        .filter(models.UserSkill.user_id == current_user.id)
        .all()
    )
    return {"data": [
        {"id": s.id, "skill_category": s.skill_category, "skill_name": s.skill_name}
        for s in skills
    ]}


@router.post("/my", response_model=schemas.UserSkillOut, status_code=201)
def add_my_skill(
    data: schemas.UserSkillCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """添加一项技能（用户维度去重：同一用户不能重复添加相同 skill_name）"""
    # 检查重复
    existing = (
        db.query(models.UserSkill)
        .filter(
            models.UserSkill.user_id == current_user.id,
            models.UserSkill.skill_name == data.skill_name,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="您已添加过该技能")

    skill = models.UserSkill(
        user_id=current_user.id,
        skill_category=data.skill_category,
        skill_name=data.skill_name,
    )
    db.add(skill)
    db.commit()
    db.refresh(skill)
    return {
        "id": skill.id,
        "skill_category": skill.skill_category,
        "skill_name": skill.skill_name,
    }


@router.delete("/my/{skill_id}")
def delete_my_skill(
    skill_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """删除一项技能（只能删除自己的）"""
    skill = (
        db.query(models.UserSkill)
        .filter(
            models.UserSkill.id == skill_id,
            models.UserSkill.user_id == current_user.id,
        )
        .first()
    )
    if not skill:
        raise HTTPException(status_code=404, detail="技能不存在或不属于当前用户")

    db.delete(skill)
    db.commit()
    return {"message": "技能已删除"}


@router.get("/categories")
def get_skill_categories(
    db: Session = Depends(get_db),
):
    """获取所有激活的技能分类"""
    categories = (
        db.query(models.SkillCategory)
        .filter(models.SkillCategory.is_active == True)
        .order_by(models.SkillCategory.display_order)
        .all()
    )
    return {"data": [
        {
            "id": c.id,
            "name_zh": c.name_zh,
            "name_en": c.name_en,
            "icon": c.icon,
            "display_order": c.display_order,
            "is_active": c.is_active,
        }
        for c in categories
    ]}

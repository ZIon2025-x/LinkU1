"""
徽章管理路由
实现用户徽章查询、展示切换等功能
"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/badges", tags=["徽章"])


@router.get("/my")
def get_my_badges(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户的所有徽章"""
    badges = (
        db.query(models.UserBadge)
        .filter(models.UserBadge.user_id == current_user.id)
        .all()
    )
    return {"data": [
        {
            "id": b.id,
            "badge_type": b.badge_type,
            "skill_category": b.skill_category,
            "rank": b.rank,
            "is_displayed": b.is_displayed,
            "granted_at": b.granted_at,
        }
        for b in badges
    ]}


@router.put("/{badge_id}/display")
def toggle_badge_display(
    badge_id: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """切换徽章展示状态（头像旁显示的徽章）"""
    badge = (
        db.query(models.UserBadge)
        .filter(
            models.UserBadge.id == badge_id,
            models.UserBadge.user_id == current_user.id,
        )
        .first()
    )
    if not badge:
        raise HTTPException(status_code=404, detail="徽章不存在或不属于当前用户")

    if badge.is_displayed:
        # Already displayed — toggle OFF
        badge.is_displayed = False
        current_user.displayed_badge_id = None
        db.commit()
        return {"message": "已取消展示徽章", "is_displayed": False}

    # Set all user's badges to not displayed
    db.query(models.UserBadge).filter(
        models.UserBadge.user_id == current_user.id,
    ).update({"is_displayed": False})

    # Set this badge as displayed
    badge.is_displayed = True
    current_user.displayed_badge_id = badge.id
    db.commit()
    return {"message": "已设置展示徽章", "is_displayed": True}


@router.get("/user/{user_id}")
def get_user_badges(
    user_id: str,
    db: Session = Depends(get_db),
):
    """获取指定用户的徽章列表（公开接口）"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    badges = (
        db.query(models.UserBadge)
        .filter(models.UserBadge.user_id == user_id)
        .all()
    )
    return {"data": [
        {
            "id": b.id,
            "badge_type": b.badge_type,
            "skill_category": b.skill_category,
            "rank": b.rank,
            "is_displayed": b.is_displayed,
            "granted_at": b.granted_at,
        }
        for b in badges
    ]}

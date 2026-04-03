"""
共享勋章加载工具 — 提供同步和异步两个版本，供各路由复用。
"""
import logging
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app import models

logger = logging.getLogger(__name__)


def enrich_displayed_badges_sync(db: Session, user_ids: list[str]) -> dict:
    """同步版：批量查询用户展示勋章，返回 {user_id: badge_dict}。"""
    if not user_ids:
        return {}
    try:
        badges = (
            db.query(models.UserBadge)
            .filter(
                models.UserBadge.user_id.in_(user_ids),
                models.UserBadge.is_displayed == True,
            )
            .all()
        )
        if not badges:
            return {}

        skill_cats = {b.skill_category for b in badges}
        cat_map = {}
        if skill_cats:
            rows = (
                db.query(
                    models.SkillCategory.task_type,
                    models.SkillCategory.name_zh,
                    models.SkillCategory.name_en,
                )
                .filter(models.SkillCategory.task_type.in_(skill_cats))
                .all()
            )
            for row in rows:
                cat_map[row.task_type] = (row.name_zh, row.name_en)

        cache = {}
        for badge in badges:
            names = cat_map.get(badge.skill_category, (badge.skill_category, badge.skill_category))
            cache[badge.user_id] = {
                "id": badge.id,
                "badge_type": badge.badge_type,
                "skill_category": badge.skill_category,
                "skill_name_zh": names[0] or badge.skill_category,
                "skill_name_en": names[1] or badge.skill_category,
                "city": badge.city,
                "rank": badge.rank,
                "is_displayed": True,
            }
        return cache
    except Exception as e:
        logger.warning(f"Failed to load badge cache (sync): {e}")
        return {}


async def enrich_displayed_badges_async(db: AsyncSession, user_ids: list[str]) -> dict:
    """异步版：批量查询用户展示勋章，返回 {user_id: badge_dict}。"""
    if not user_ids:
        return {}
    try:
        badge_result = await db.execute(
            select(models.UserBadge).where(
                models.UserBadge.user_id.in_(user_ids),
                models.UserBadge.is_displayed == True,
            )
        )
        badges = badge_result.scalars().all()
        if not badges:
            return {}

        skill_cats = {b.skill_category for b in badges}
        cat_map = {}
        if skill_cats:
            cat_result = await db.execute(
                select(
                    models.SkillCategory.task_type,
                    models.SkillCategory.name_zh,
                    models.SkillCategory.name_en,
                ).where(models.SkillCategory.task_type.in_(skill_cats))
            )
            for row in cat_result.all():
                cat_map[row.task_type] = (row.name_zh, row.name_en)

        cache = {}
        for badge in badges:
            names = cat_map.get(badge.skill_category, (badge.skill_category, badge.skill_category))
            cache[badge.user_id] = {
                "id": badge.id,
                "badge_type": badge.badge_type,
                "skill_category": badge.skill_category,
                "skill_name_zh": names[0] or badge.skill_category,
                "skill_name_en": names[1] or badge.skill_category,
                "city": badge.city,
                "rank": badge.rank,
                "is_displayed": True,
            }
        return cache
    except Exception as e:
        logger.warning(f"Failed to load badge cache (async): {e}")
        return {}

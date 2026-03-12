"""
Skill Leaderboard API Routes
技能排行榜 API 路由
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, text

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/leaderboard", tags=["技能排行榜"])


# ==================== Utility Functions ====================


def recalculate_leaderboard(db: Session, category: Optional[str] = None) -> None:
    """
    Recalculate skill leaderboard scores and ranks.

    For each skill category (or a specific one):
    1. Find users who completed tasks with task_type matching the category
    2. Calculate their completed_tasks, total_amount, avg_rating for that task_type only
    3. Score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10
    4. Upsert into skill_leaderboard, rank by score desc
    5. Grant badges to Top 10, remove badges for users who dropped out
    """
    # Determine which categories to process
    if category:
        categories = [category]
    else:
        categories = [
            row[0]
            for row in db.query(models.SkillCategory.name_en)
            .filter(models.SkillCategory.is_active == True)
            .all()
        ]

    now = get_utc_time()

    for cat in categories:
        # Single query: aggregate task stats + avg review rating per user for this task_type
        task_stats = (
            db.query(
                models.Task.taker_id,
                func.count(models.Task.id).label("completed_tasks"),
                func.coalesce(func.sum(models.Task.reward), 0).label("total_amount"),
            )
            .filter(
                models.Task.task_type == cat,
                models.Task.status == "completed",
                models.Task.taker_id.isnot(None),
            )
            .group_by(models.Task.taker_id)
            .subquery()
        )

        # Join with review ratings
        results = (
            db.query(
                task_stats.c.taker_id,
                task_stats.c.completed_tasks,
                task_stats.c.total_amount,
                func.avg(models.Review.rating).label("avg_rating"),
            )
            .outerjoin(
                models.Task,
                (models.Task.taker_id == task_stats.c.taker_id)
                & (models.Task.task_type == cat)
                & (models.Task.status == "completed"),
            )
            .outerjoin(models.Review, models.Review.task_id == models.Task.id)
            .group_by(
                task_stats.c.taker_id,
                task_stats.c.completed_tasks,
                task_stats.c.total_amount,
            )
            .all()
        )

        if not results:
            # No users in this category — clear leaderboard entries
            db.query(models.SkillLeaderboard).filter(
                models.SkillLeaderboard.skill_category == cat
            ).delete(synchronize_session=False)
            db.query(models.UserBadge).filter(
                models.UserBadge.skill_category == cat
            ).delete(synchronize_session=False)
            db.commit()
            continue

        # Calculate scores
        user_scores = []
        for row in results:
            completed_tasks = row.completed_tasks
            total_amount = float(row.total_amount)
            avg_rating = float(row.avg_rating) if row.avg_rating is not None else 0.0
            score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10

            user_scores.append({
                "user_id": row.taker_id,
                "completed_tasks": completed_tasks,
                "total_amount": int(total_amount),
                "avg_rating": round(avg_rating, 2),
                "score": round(score, 2),
            })

        # Sort by score descending
        user_scores.sort(key=lambda x: x["score"], reverse=True)

        # Upsert leaderboard entries with ranks
        current_user_ids = set()
        for rank_pos, entry in enumerate(user_scores, start=1):
            current_user_ids.add(entry["user_id"])
            existing = (
                db.query(models.SkillLeaderboard)
                .filter(
                    models.SkillLeaderboard.skill_category == cat,
                    models.SkillLeaderboard.user_id == entry["user_id"],
                )
                .first()
            )
            if existing:
                existing.completed_tasks = entry["completed_tasks"]
                existing.total_amount = entry["total_amount"]
                existing.avg_rating = entry["avg_rating"]
                existing.score = entry["score"]
                existing.rank = rank_pos
                existing.updated_at = now
            else:
                new_entry = models.SkillLeaderboard(
                    skill_category=cat,
                    user_id=entry["user_id"],
                    completed_tasks=entry["completed_tasks"],
                    total_amount=entry["total_amount"],
                    avg_rating=entry["avg_rating"],
                    score=entry["score"],
                    rank=rank_pos,
                    updated_at=now,
                )
                db.add(new_entry)

        # Remove stale leaderboard entries for users no longer qualifying
        if current_user_ids:
            db.query(models.SkillLeaderboard).filter(
                models.SkillLeaderboard.skill_category == cat,
                ~models.SkillLeaderboard.user_id.in_(current_user_ids),
            ).delete(synchronize_session=False)

        db.commit()

        # Handle badges for Top 10
        top_10_user_ids = [e["user_id"] for e in user_scores[:10]]

        # Grant/update badges for Top 10
        for rank_pos, entry in enumerate(user_scores[:10], start=1):
            existing_badge = (
                db.query(models.UserBadge)
                .filter(
                    models.UserBadge.user_id == entry["user_id"],
                    models.UserBadge.skill_category == cat,
                )
                .first()
            )
            if existing_badge:
                existing_badge.rank = rank_pos
                existing_badge.granted_at = now
            else:
                new_badge = models.UserBadge(
                    user_id=entry["user_id"],
                    badge_type="skill_rank",
                    skill_category=cat,
                    rank=rank_pos,
                    is_displayed=False,
                    granted_at=now,
                )
                db.add(new_badge)

        # Remove badges for users who dropped out of Top 10
        db.query(models.UserBadge).filter(
            models.UserBadge.skill_category == cat,
            models.UserBadge.badge_type == "skill_rank",
            ~models.UserBadge.user_id.in_(top_10_user_ids) if top_10_user_ids else True,
        ).delete(synchronize_session=False)

        db.commit()

    logger.info(f"Leaderboard recalculation completed for categories: {categories}")


# ==================== Endpoints ====================


@router.get("/skills")
def list_skill_categories(db: Session = Depends(get_db)):
    """
    List all active skill categories, ordered by display_order.
    No auth required.
    """
    categories = (
        db.query(models.SkillCategory)
        .filter(models.SkillCategory.is_active == True)
        .order_by(models.SkillCategory.display_order)
        .all()
    )
    return {"data": [schemas.SkillCategoryOut.model_validate(c).model_dump() for c in categories]}


@router.get("/skills/{category}")
def get_leaderboard(category: str, db: Session = Depends(get_db)):
    """
    Get Top 10 leaderboard entries for a skill category.
    No auth required.
    """
    entries = (
        db.query(models.SkillLeaderboard, models.User)
        .join(
            models.User,
            models.SkillLeaderboard.user_id == models.User.id,
        )
        .filter(
            models.SkillLeaderboard.skill_category == category,
            models.SkillLeaderboard.rank <= 10,
        )
        .order_by(models.SkillLeaderboard.rank)
        .all()
    )

    return {"data": [
        {
            "user_id": entry.SkillLeaderboard.user_id,
            "user_name": entry.User.name,
            "user_avatar": entry.User.avatar or "",
            "skill_category": category,
            "completed_tasks": entry.SkillLeaderboard.completed_tasks,
            "total_amount": entry.SkillLeaderboard.total_amount,
            "avg_rating": entry.SkillLeaderboard.avg_rating,
            "score": entry.SkillLeaderboard.score,
            "rank": entry.SkillLeaderboard.rank,
        }
        for entry in entries
    ]}


@router.get("/skills/{category}/my-rank")
def get_my_rank(
    category: str,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Get the current user's rank in a skill category leaderboard.
    Returns the entry or null if not ranked.
    """
    entry = (
        db.query(models.SkillLeaderboard)
        .filter(
            models.SkillLeaderboard.skill_category == category,
            models.SkillLeaderboard.user_id == current_user.id,
        )
        .first()
    )

    if not entry:
        return None

    return {
        "user_id": entry.user_id,
        "user_name": current_user.name,
        "user_avatar": current_user.avatar or "",
        "skill_category": category,
        "completed_tasks": entry.completed_tasks,
        "total_amount": entry.total_amount,
        "avg_rating": entry.avg_rating,
        "score": entry.score,
        "rank": entry.rank,
    }

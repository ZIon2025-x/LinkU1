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
    1. Find users who have at least one skill in that category
    2. Calculate their completed_tasks, total_amount, avg_rating
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
        # Find users who have at least one skill in this category
        user_ids = [
            row[0]
            for row in db.query(models.UserSkill.user_id)
            .filter(models.UserSkill.skill_category == cat)
            .distinct()
            .all()
        ]

        if not user_ids:
            # No users in this category — clear leaderboard entries
            db.query(models.SkillLeaderboard).filter(
                models.SkillLeaderboard.skill_category == cat
            ).delete(synchronize_session=False)
            # Remove badges for this category
            db.query(models.UserBadge).filter(
                models.UserBadge.skill_category == cat
            ).delete(synchronize_session=False)
            db.commit()
            continue

        # Calculate stats for each user
        user_scores = []
        for uid in user_ids:
            # Completed tasks count (as taker)
            completed_tasks = (
                db.query(func.count(models.Task.id))
                .filter(
                    models.Task.taker_id == uid,
                    models.Task.status == "completed",
                )
                .scalar()
            ) or 0

            # Total amount from completed tasks
            total_amount = (
                db.query(func.sum(models.Task.reward))
                .filter(
                    models.Task.taker_id == uid,
                    models.Task.status == "completed",
                )
                .scalar()
            ) or 0

            # Average review rating
            avg_rating = (
                db.query(func.avg(models.Review.rating))
                .join(models.Task, models.Review.task_id == models.Task.id)
                .filter(
                    models.Task.taker_id == uid,
                    models.Task.status == "completed",
                )
                .scalar()
            )
            avg_rating = float(avg_rating) if avg_rating is not None else 0.0

            # Calculate score
            score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10

            user_scores.append({
                "user_id": uid,
                "completed_tasks": completed_tasks,
                "total_amount": int(total_amount),
                "avg_rating": round(avg_rating, 2),
                "score": round(score, 2),
            })

        # Sort by score descending
        user_scores.sort(key=lambda x: x["score"], reverse=True)

        # Upsert leaderboard entries with ranks
        existing_entry_ids = set()
        for rank_pos, entry in enumerate(user_scores, start=1):
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
                existing_entry_ids.add(existing.id)
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


@router.get("/skills", response_model=List[schemas.SkillCategoryOut])
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
    return categories


@router.get("/skills/{category}", response_model=List[schemas.LeaderboardEntryOut])
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

    return [
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
    ]


@router.get("/skills/{category}/my-rank", response_model=Optional[schemas.LeaderboardEntryOut])
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

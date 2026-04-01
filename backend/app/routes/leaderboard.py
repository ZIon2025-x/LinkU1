"""
Skill Leaderboard API Routes
技能排行榜 API 路由
"""
import logging
import re
from collections import Counter
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, text

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/leaderboard", tags=["技能排行榜"])


# ==================== City Normalization ====================

# UK major cities with aliases (English + Chinese)
_CITY_ALIASES = {
    "London": ["london", "伦敦"],
    "Birmingham": ["birmingham", "伯明翰"],
    "Manchester": ["manchester", "曼彻斯特", "曼城"],
    "Edinburgh": ["edinburgh", "爱丁堡"],
    "Glasgow": ["glasgow", "格拉斯哥"],
    "Bristol": ["bristol", "布里斯托"],
    "Sheffield": ["sheffield", "谢菲尔德"],
    "Leeds": ["leeds", "利兹"],
    "Nottingham": ["nottingham", "诺丁汉"],
    "Liverpool": ["liverpool", "利物浦"],
    "Newcastle": ["newcastle", "纽卡斯尔", "纽卡"],
    "Cardiff": ["cardiff", "卡迪夫"],
    "Belfast": ["belfast", "贝尔法斯特"],
    "Cambridge": ["cambridge", "剑桥"],
    "Oxford": ["oxford", "牛津"],
    "Bath": ["bath", "巴斯"],
    "Southampton": ["southampton", "南安普顿"],
    "Coventry": ["coventry", "考文垂"],
    "Leicester": ["leicester", "莱斯特"],
    "Aberdeen": ["aberdeen", "阿伯丁"],
}

# Build a flat lookup: alias_lower -> city_name
_ALIAS_LOOKUP = {}
for city, aliases in _CITY_ALIASES.items():
    for alias in aliases:
        _ALIAS_LOOKUP[alias.lower()] = city


def normalize_city(location: Optional[str]) -> str:
    """
    Extract and normalize a city name from a task's location string.

    - location is 'Online' or 'online' → 'Online'
    - Scan location string for known city names/aliases (English + Chinese)
    - No match → 'Other'
    """
    if not location:
        return "Other"

    loc_lower = location.strip().lower()

    if loc_lower == "online":
        return "Online"

    # Check each alias against the location string
    for alias, city in _ALIAS_LOOKUP.items():
        if alias in loc_lower:
            return city

    return "Other"


SUPPORTED_CITIES = ["Online"] + sorted(_CITY_ALIASES.keys()) + ["Other"]


# ==================== Utility Functions ====================


def recalculate_leaderboard(db: Session, category: Optional[str] = None) -> None:
    """
    Recalculate skill leaderboard scores and ranks.

    For each skill category (or a specific one):
    1. Find users who completed tasks with task_type matching the category
    2. Determine each user's primary city (city with most completed tasks)
    3. Calculate completed_tasks, total_amount, avg_rating
    4. Score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10
    5. Upsert into skill_leaderboard with city, rank by score desc
    6. Grant badges to Top 10 per category (regardless of city)
    """
    # Determine which categories to process
    if category:
        categories = [category]
    else:
        categories = [
            row[0]
            for row in db.query(models.SkillCategory.task_type)
            .filter(models.SkillCategory.is_active == True)
            .all()
        ]

    now = get_utc_time()

    for cat in categories:
        # 1. Get all completed tasks for this category with location info
        tasks = (
            db.query(
                models.Task.taker_id,
                models.Task.id,
                models.Task.location,
                models.Task.reward,
            )
            .filter(
                models.Task.task_type == cat,
                models.Task.status == "completed",
                models.Task.taker_id.isnot(None),
            )
            .all()
        )

        if not tasks:
            # No tasks — clear leaderboard entries for this category
            db.query(models.SkillLeaderboard).filter(
                models.SkillLeaderboard.skill_category == cat
            ).delete(synchronize_session=False)
            db.query(models.UserBadge).filter(
                models.UserBadge.skill_category == cat,
                models.UserBadge.badge_type == "skill_rank",
            ).delete(synchronize_session=False)
            db.commit()
            continue

        # 2. Aggregate per user: total stats + primary city
        user_data = {}  # user_id -> {task_ids, total_reward, city_counter}
        for task in tasks:
            uid = task.taker_id
            if uid not in user_data:
                user_data[uid] = {
                    "task_ids": [],
                    "total_reward": 0.0,
                    "city_counter": Counter(),
                }
            city = normalize_city(task.location)
            user_data[uid]["task_ids"].append(task.id)
            user_data[uid]["total_reward"] += float(task.reward or 0)
            user_data[uid]["city_counter"][city] += 1

        # 3. Get review ratings for these tasks
        all_task_ids = [t.id for t in tasks]
        reviews = {}  # task_id -> [ratings]
        if all_task_ids:
            review_rows = (
                db.query(models.Review.task_id, models.Review.rating, models.Review.user_id)
                .filter(models.Review.task_id.in_(all_task_ids))
                .all()
            )
            # Map: taker_id -> [ratings from others]
            task_taker = {t.id: t.taker_id for t in tasks}
            user_ratings = {}  # user_id -> [ratings]
            for r in review_rows:
                taker = task_taker.get(r.task_id)
                if taker and r.user_id != taker:  # Only reviews from poster, not self
                    user_ratings.setdefault(taker, []).append(r.rating)

        # 4. Build scores
        user_scores = []
        for uid, data in user_data.items():
            completed_tasks = len(data["task_ids"])
            total_amount = data["total_reward"]
            ratings = user_ratings.get(uid, []) if all_task_ids else []
            avg_rating = sum(ratings) / len(ratings) if ratings else 0.0
            score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10
            primary_city = data["city_counter"].most_common(1)[0][0]

            user_scores.append({
                "user_id": uid,
                "city": primary_city,
                "completed_tasks": completed_tasks,
                "total_amount": int(total_amount),
                "avg_rating": round(avg_rating, 2),
                "score": round(score, 2),
            })

        # 5. Sort by score descending
        user_scores.sort(key=lambda x: x["score"], reverse=True)

        # 6. Upsert leaderboard entries with ranks
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
                existing.city = entry["city"]
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
                    city=entry["city"],
                    completed_tasks=entry["completed_tasks"],
                    total_amount=entry["total_amount"],
                    avg_rating=entry["avg_rating"],
                    score=entry["score"],
                    rank=rank_pos,
                    updated_at=now,
                )
                db.add(new_entry)

        # Remove stale entries
        if current_user_ids:
            db.query(models.SkillLeaderboard).filter(
                models.SkillLeaderboard.skill_category == cat,
                ~models.SkillLeaderboard.user_id.in_(current_user_ids),
            ).delete(synchronize_session=False)

        db.commit()

        # 7. Handle badges for Top 10 (global, not per-city)
        top_10_user_ids = [e["user_id"] for e in user_scores[:10]]

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


@router.get("/cities")
def list_supported_cities():
    """List all supported cities for leaderboard filtering."""
    return {"data": SUPPORTED_CITIES}


@router.get("/skills/{category}")
def get_leaderboard(
    category: str,
    city: Optional[str] = Query(None, description="Filter by city (e.g. London, Online, Other). Omit for all."),
    db: Session = Depends(get_db),
):
    """
    Get Top 10 leaderboard entries for a skill category, optionally filtered by city.
    No auth required.
    """
    query = (
        db.query(models.SkillLeaderboard, models.User)
        .join(
            models.User,
            models.SkillLeaderboard.user_id == models.User.id,
        )
        .filter(
            models.SkillLeaderboard.skill_category == category,
        )
    )

    if city:
        query = query.filter(models.SkillLeaderboard.city == city)

    entries = (
        query
        .order_by(models.SkillLeaderboard.score.desc())
        .limit(10)
        .all()
    )

    return {"data": [
        {
            "user_id": entry.SkillLeaderboard.user_id,
            "user_name": entry.User.name,
            "user_avatar": entry.User.avatar or "",
            "skill_category": category,
            "city": entry.SkillLeaderboard.city,
            "completed_tasks": entry.SkillLeaderboard.completed_tasks,
            "total_amount": entry.SkillLeaderboard.total_amount,
            "avg_rating": entry.SkillLeaderboard.avg_rating,
            "score": entry.SkillLeaderboard.score,
            "rank": idx + 1,  # Re-rank within city filter
        }
        for idx, entry in enumerate(entries)
    ]}


@router.get("/skills/{category}/my-rank")
def get_my_rank(
    category: str,
    city: Optional[str] = Query(None),
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

    # If city filter, calculate rank within that city
    rank = entry.rank
    if city and entry.city == city:
        rank = (
            db.query(func.count(models.SkillLeaderboard.id))
            .filter(
                models.SkillLeaderboard.skill_category == category,
                models.SkillLeaderboard.city == city,
                models.SkillLeaderboard.score > entry.score,
            )
            .scalar() or 0
        ) + 1
    elif city and entry.city != city:
        return None  # User is not in this city's leaderboard

    return {
        "user_id": entry.user_id,
        "user_name": current_user.name,
        "user_avatar": current_user.avatar or "",
        "skill_category": category,
        "city": entry.city,
        "completed_tasks": entry.completed_tasks,
        "total_amount": entry.total_amount,
        "avg_rating": entry.avg_rating,
        "score": entry.score,
        "rank": rank,
    }

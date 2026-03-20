"""Migrate data from UserSkill to UserCapability.

Usage: python -m scripts.migrate_user_skills [--dry-run]
"""
import sys
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import (
    UserSkill, SkillCategory, User,
    UserCapability, UserReliability, ProficiencyLevel, VerificationSource
)


def build_category_map(db: Session) -> dict[str, int]:
    """Map category name strings to SkillCategory IDs."""
    categories = db.query(SkillCategory).filter(SkillCategory.is_active == True).all()
    mapping = {}
    for cat in categories:
        if cat.name_zh:
            mapping[cat.name_zh.lower()] = cat.id
        if cat.name_en:
            mapping[cat.name_en.lower()] = cat.id
    return mapping


def migrate_skills(db: Session, dry_run: bool = False) -> dict:
    """Migrate UserSkill records to UserCapability."""
    category_map = build_category_map(db)
    stats = {"migrated": 0, "skipped_duplicate": 0, "skipped_no_category": 0}

    other_cat = db.query(SkillCategory).filter(SkillCategory.name_zh == "其他").first()
    if not other_cat and not dry_run:
        other_cat = SkillCategory(name_zh="其他", name_en="Other", is_active=True, display_order=99)
        db.add(other_cat)
        db.flush()
    other_cat_id = other_cat.id if other_cat else None

    skills = db.query(UserSkill).all()
    for skill in skills:
        existing = db.query(UserCapability).filter(
            UserCapability.user_id == skill.user_id,
            UserCapability.skill_name == skill.skill_name,
        ).first()
        if existing:
            stats["skipped_duplicate"] += 1
            continue

        cat_id = category_map.get(skill.skill_category.lower()) if skill.skill_category else None
        if not cat_id:
            cat_id = other_cat_id
        if not cat_id:
            stats["skipped_no_category"] += 1
            continue

        if not dry_run:
            cap = UserCapability(
                user_id=skill.user_id,
                category_id=cat_id,
                skill_name=skill.skill_name,
                proficiency=ProficiencyLevel.beginner,
                verification_source=VerificationSource.self_declared,
            )
            db.add(cap)
        stats["migrated"] += 1

    return stats


def init_reliability(db: Session, dry_run: bool = False) -> int:
    """Initialize UserReliability for all users with task history."""
    users = db.query(User).filter(User.task_count > 0).all()
    count = 0
    for user in users:
        existing = db.query(UserReliability).filter(
            UserReliability.user_id == user.id
        ).first()
        if existing:
            continue

        if not dry_run:
            rel = UserReliability(
                user_id=user.id,
                total_tasks_taken=user.completed_task_count or 0,
                completion_rate=(user.completed_task_count or 0) / max(user.task_count, 1),
                communication_score=user.avg_rating or 0.0,
            )
            db.add(rel)
        count += 1
    return count


def main():
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY RUN MODE ===")

    db = SessionLocal()
    try:
        print("Migrating skills...")
        stats = migrate_skills(db, dry_run)
        print(f"  Skills: {stats}")

        print("Initializing reliability...")
        rel_count = init_reliability(db, dry_run)
        print(f"  Reliability records created: {rel_count}")

        if not dry_run:
            db.commit()
            print("Migration committed.")
        else:
            db.rollback()
            print("Dry run complete, no changes made.")
    finally:
        db.close()


if __name__ == "__main__":
    main()

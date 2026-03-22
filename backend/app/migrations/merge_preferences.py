"""One-time migration: merge user_preferences into user_profile_preferences."""
import json
import logging
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def migrate_user_preferences(db: Session, engine) -> None:
    """Add new columns to user_profile_preferences and migrate data from user_preferences.

    Safe to run multiple times -- checks if columns already exist.
    """
    inspector = inspect(engine)

    # Check if user_profile_preferences table exists
    if 'user_profile_preferences' not in inspector.get_table_names():
        logger.info("user_profile_preferences table not found, skipping migration")
        return

    # Check if columns already exist
    existing_columns = {col['name'] for col in inspector.get_columns('user_profile_preferences')}
    new_columns = {
        'task_types': 'JSON',
        'locations': 'JSON',
        'task_levels': 'JSON',
        'keywords': 'JSON',
        'min_deadline_days': 'INTEGER DEFAULT 1',
    }

    columns_to_add = {name: typ for name, typ in new_columns.items() if name not in existing_columns}

    if not columns_to_add:
        logger.info("All columns already exist in user_profile_preferences, skipping")
        return

    # Add missing columns
    for col_name, col_type in columns_to_add.items():
        try:
            db.execute(text(f"ALTER TABLE user_profile_preferences ADD COLUMN {col_name} {col_type}"))
            logger.info(f"Added column {col_name} to user_profile_preferences")
        except Exception as e:
            logger.warning(f"Could not add column {col_name}: {e}")

    db.commit()

    # Migrate data from user_preferences if table exists
    if 'user_preferences' not in inspector.get_table_names():
        logger.info("user_preferences table not found, no data to migrate")
        return

    try:
        rows = db.execute(text(
            "SELECT user_id, task_types, locations, task_levels, keywords, min_deadline_days "
            "FROM user_preferences"
        )).fetchall()

        migrated = 0
        for row in rows:
            user_id = row[0]

            def safe_parse(val):
                if not val:
                    return None
                try:
                    return json.loads(val) if isinstance(val, str) else val
                except (json.JSONDecodeError, TypeError):
                    return None

            task_types = safe_parse(row[1])
            locations_val = safe_parse(row[2])
            task_levels = safe_parse(row[3])
            keywords = safe_parse(row[4])
            min_deadline_days = row[5]

            # Check if user has a profile preference row
            existing = db.execute(text(
                "SELECT user_id FROM user_profile_preferences WHERE user_id = :uid"
            ), {"uid": user_id}).fetchone()

            if existing:
                # Update only null fields (don't overwrite user's manual settings)
                db.execute(text("""
                    UPDATE user_profile_preferences
                    SET task_types = COALESCE(task_types, :task_types),
                        locations = COALESCE(locations, :locations),
                        task_levels = COALESCE(task_levels, :task_levels),
                        keywords = COALESCE(keywords, :keywords),
                        min_deadline_days = COALESCE(min_deadline_days, :min_deadline_days)
                    WHERE user_id = :user_id
                """), {
                    "user_id": user_id,
                    "task_types": json.dumps(task_types) if task_types else None,
                    "locations": json.dumps(locations_val) if locations_val else None,
                    "task_levels": json.dumps(task_levels) if task_levels else None,
                    "keywords": json.dumps(keywords) if keywords else None,
                    "min_deadline_days": min_deadline_days,
                })
            else:
                # Insert new row
                db.execute(text("""
                    INSERT INTO user_profile_preferences
                    (user_id, task_types, locations, task_levels, keywords, min_deadline_days)
                    VALUES (:user_id, :task_types, :locations, :task_levels, :keywords, :min_deadline_days)
                """), {
                    "user_id": user_id,
                    "task_types": json.dumps(task_types) if task_types else None,
                    "locations": json.dumps(locations_val) if locations_val else None,
                    "task_levels": json.dumps(task_levels) if task_levels else None,
                    "keywords": json.dumps(keywords) if keywords else None,
                    "min_deadline_days": min_deadline_days,
                })
            migrated += 1

        db.commit()
        logger.info(f"Migrated {migrated} user preferences successfully")

    except Exception as e:
        logger.error(f"Error migrating user preferences: {e}")
        db.rollback()

"""Nearby task push: find tasks within 1km and send push notification."""
import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models import (
    Task, UserLocation, NearbyTaskPush, UserProfilePreference, TaskApplication
)
from app.utils.location_utils import calculate_distance
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

COOLDOWN_HOURS = 6
RADIUS_KM = 1.0
TASK_FRESHNESS_DAYS = 7
# Approximate degree offsets for 1km bounding box
LAT_OFFSET = 0.009  # ~1km in latitude
LON_OFFSET = 0.013  # ~1km in longitude (at ~51° latitude, UK)


def upsert_user_location(db: Session, user_id: str, latitude: float, longitude: float) -> UserLocation:
    """Create or update user's last known location."""
    loc = db.query(UserLocation).filter(UserLocation.user_id == user_id).first()
    if not loc:
        loc = UserLocation(user_id=user_id, latitude=latitude, longitude=longitude)
        db.add(loc)
    else:
        loc.latitude = latitude
        loc.longitude = longitude
        loc.updated_at = get_utc_time()
    db.flush()
    return loc


def check_cooldown(db: Session, user_id: str) -> bool:
    """Return True if user can receive a push (cooldown expired)."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=COOLDOWN_HOURS)
    latest = db.query(NearbyTaskPush.pushed_at).filter(
        NearbyTaskPush.user_id == user_id,
        NearbyTaskPush.pushed_at >= cutoff
    ).order_by(NearbyTaskPush.pushed_at.desc()).first()
    return latest is None


def find_nearest_task(db: Session, user_id: str, lat: float, lon: float) -> Task | None:
    """Find the most recently posted open task within 1km, not yet pushed to this user."""
    freshness_cutoff = datetime.now(timezone.utc) - timedelta(days=TASK_FRESHNESS_DAYS)

    # Bounding box pre-filter (uses B-tree index on lat/lon)
    candidates = db.query(Task).filter(
        Task.latitude.isnot(None),
        Task.longitude.isnot(None),
        Task.status == "open",
        Task.created_at >= freshness_cutoff,
        Task.poster_id != user_id,
        Task.latitude.between(lat - LAT_OFFSET, lat + LAT_OFFSET),
        Task.longitude.between(lon - LON_OFFSET, lon + LON_OFFSET),
        ~Task.id.in_(
            select(NearbyTaskPush.task_id).where(NearbyTaskPush.user_id == user_id)
        ),
        ~Task.id.in_(
            select(TaskApplication.task_id).where(TaskApplication.applicant_id == user_id)
        ),
    ).order_by(Task.created_at.desc()).limit(10).all()

    # Haversine precision filter
    for task in candidates:
        dist = calculate_distance(lat, lon, float(task.latitude), float(task.longitude))
        if dist <= RADIUS_KM:
            return task
    return None


def record_push(db: Session, user_id: str, task_id: int):
    """Record that a task was pushed to a user."""
    push = NearbyTaskPush(user_id=user_id, task_id=task_id)
    db.add(push)
    db.flush()


def process_nearby_push(db: Session, user_id: str, latitude: float, longitude: float) -> bool:
    """Main entry point: check eligibility, find task, send push. Returns True if pushed."""
    # 1. Check preference
    pref = db.query(UserProfilePreference).filter(
        UserProfilePreference.user_id == user_id
    ).first()
    if not pref or not pref.nearby_push_enabled:
        return False

    # 2. Check cooldown
    if not check_cooldown(db, user_id):
        return False

    # 3. Find nearby task
    task = find_nearest_task(db, user_id, latitude, longitude)
    if not task:
        return False

    # 4. Send push
    try:
        from app.push_notification_service import send_push_notification
        task_title = task.title_zh or task.title_en or task.title or ""
        send_push_notification(
            db=db,
            user_id=user_id,
            notification_type="nearby_task",
            template_vars={"task_title": task_title},
            data={"type": "nearby_task", "task_id": str(task.id)},
        )
        record_push(db, user_id, task.id)
        logger.info(f"Nearby push sent: user={user_id}, task={task.id}")
        return True
    except Exception as e:
        logger.warning(f"Nearby push failed: user={user_id}, error={e}")
        return False


def cleanup_old_pushes(db: Session, days: int = 30):
    """Delete push records older than N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    deleted = db.query(NearbyTaskPush).filter(
        NearbyTaskPush.pushed_at < cutoff
    ).delete(synchronize_session=False)
    logger.info(f"Cleaned up {deleted} old nearby push records")
    return deleted

"""
BehaviorCollector — in-memory queue with background flush to DB.

Collects user behavior events via a non-blocking `record()` call,
then batch-writes them to the database every 30 seconds.
For ai_insight events, merges extracted data into UserDemand in real-time.
"""

import logging
import threading
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class BehaviorCollector:
    """Singleton that queues behavior events and periodically flushes to DB."""

    FLUSH_INTERVAL = 30  # seconds between flushes

    _instance = None
    _instance_lock = threading.Lock()

    def __init__(self):
        self._queue: list = []
        self._lock = threading.Lock()
        self._running = False
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()

    @classmethod
    def get_instance(cls) -> "BehaviorCollector":
        """Return the singleton instance, creating it if necessary."""
        if cls._instance is None:
            with cls._instance_lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def start(self):
        """Start the background daemon thread for periodic flushing."""
        if self._running:
            logger.warning("BehaviorCollector is already running")
            return
        self._running = True
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._thread.start()
        logger.info("BehaviorCollector started (flush every %ds)", self.FLUSH_INTERVAL)

    def stop(self):
        """Stop the background thread and perform a final flush."""
        if not self._running:
            return
        self._running = False
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=10)
            self._thread = None
        # Final flush to avoid losing queued events
        try:
            self._flush()
        except Exception:
            logger.exception("Error during final flush on stop")
        logger.info("BehaviorCollector stopped")

    def record(self, user_id: str, event_type: str, event_data: dict):
        """Append an event to the queue. Non-blocking, thread-safe."""
        self._queue.append({
            "user_id": user_id,
            "event_type": event_type,
            "event_data": event_data,
            "created_at": datetime.now(timezone.utc),
        })

    def _flush_loop(self):
        """Background loop: sleep then flush, repeat until stopped."""
        while not self._stop_event.is_set():
            self._stop_event.wait(timeout=self.FLUSH_INTERVAL)
            if not self._running:
                break
            try:
                self._flush()
            except Exception:
                logger.exception("Unhandled error in _flush_loop")

    def _flush(self):
        """Drain the queue and write events to the database."""
        # 1. Snapshot and clear queue under lock
        with self._lock:
            if not self._queue:
                return
            events = list(self._queue)
            self._queue.clear()

        if not events:
            return

        # Lazy imports to avoid circular dependencies
        from app.database import SessionLocal
        from app.models import UserBehaviorEvent, UserDemand

        db = SessionLocal()
        try:
            # 2. Batch insert all events
            db_events = [
                UserBehaviorEvent(
                    user_id=e["user_id"],
                    event_type=e["event_type"],
                    event_data=e["event_data"],
                    created_at=e["created_at"],
                )
                for e in events
            ]
            db.bulk_save_objects(db_events)

            # 3. Process ai_insight events → merge into UserDemand
            ai_events = [e for e in events if e["event_type"] == "ai_insight"]
            if ai_events:
                self._merge_ai_insights(db, ai_events)

            db.commit()
            logger.debug("Flushed %d events (%d ai_insight)", len(events), len(ai_events))
        except Exception:
            db.rollback()
            logger.exception("Failed to flush %d events", len(events))
        finally:
            db.close()

    def _merge_ai_insights(self, db, ai_events: list):
        """Merge ai_insight events into UserDemand records, grouped by user."""
        from app.models import UserDemand

        # Try importing determine_user_stages; it may not exist yet (Task 6)
        try:
            from app.services.demand_inference import determine_user_stages
        except ImportError:
            determine_user_stages = None

        # Group events by user_id
        by_user: dict[str, list[dict]] = {}
        for e in ai_events:
            by_user.setdefault(e["user_id"], []).append(e["event_data"])

        now = datetime.now(timezone.utc)

        for user_id, data_list in by_user.items():
            demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
            if demand is None:
                demand = UserDemand(user_id=user_id)
                db.add(demand)

            for data in data_list:
                # Merge interests: dict keyed by topic, keep highest confidence
                if "interests" in data and isinstance(data["interests"], dict):
                    current = demand.recent_interests or {}
                    for topic, confidence in data["interests"].items():
                        if topic not in current or confidence > current.get(topic, 0):
                            current[topic] = confidence
                    demand.recent_interests = current

                # Merge skills: list of dicts, dedup by skill name, keep highest confidence
                if "skills" in data and isinstance(data["skills"], list):
                    current = demand.inferred_skills or []
                    skill_map: dict[str, dict] = {}
                    for s in current:
                        if isinstance(s, dict) and "name" in s:
                            skill_map[s["name"]] = s
                    for s in data["skills"]:
                        if isinstance(s, dict) and "name" in s:
                            existing = skill_map.get(s["name"])
                            if existing is None or s.get("confidence", 0) > existing.get("confidence", 0):
                                skill_map[s["name"]] = s
                    demand.inferred_skills = list(skill_map.values())

                # Merge preferences: dict, update
                if "preferences" in data and isinstance(data["preferences"], dict):
                    current = demand.inferred_preferences or {}
                    current.update(data["preferences"])
                    demand.inferred_preferences = current

                # Merge stages
                if "stages" in data and isinstance(data["stages"], list):
                    ai_stages = set(data["stages"])
                    # Compute month-based stages if available
                    if determine_user_stages is not None:
                        try:
                            month_stages = set(determine_user_stages(
                                identity=demand.identity,
                                month=now.month,
                            ))
                        except Exception:
                            logger.debug(
                                "determine_user_stages failed for user %s, using AI stages only",
                                user_id,
                            )
                            month_stages = set()
                    else:
                        month_stages = set()
                    demand.user_stage = list(ai_stages | month_stages)

            demand.last_inferred_at = now
            demand.inference_version = "v2.0-realtime"

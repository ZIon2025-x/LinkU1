"""Scheduled tasks for user profile system.

Wire these into the existing Celery beat schedule or cron:
- nightly_demand_inference: every day at 3:00 AM UTC
- weekly_reliability_calibration: every Monday at 4:00 AM UTC
"""
import logging
from app.database import SessionLocal
from app.services.demand_inference import batch_infer_demands
from app.services.reliability_calculator import recalculate_all_reliability

logger = logging.getLogger(__name__)


def nightly_demand_inference():
    """Run nightly at 3 AM: update demand profiles for active users."""
    db = SessionLocal()
    try:
        results = batch_infer_demands(db, limit=500)
        db.commit()
        logger.info(f"Nightly demand inference: updated {len(results)} users")
    except Exception as e:
        db.rollback()
        logger.error(f"Nightly demand inference failed: {e}")
    finally:
        db.close()


def weekly_reliability_calibration():
    """Run weekly on Monday at 4 AM: full recalculation of reliability scores."""
    db = SessionLocal()
    try:
        recalculate_all_reliability(db, limit=500)
        db.commit()
        logger.info("Weekly reliability calibration completed")
    except Exception as e:
        db.rollback()
        logger.error(f"Weekly reliability calibration failed: {e}")
    finally:
        db.close()

"""
Newbie Tasks API Routes
新手任务系统 API 路由
"""
import logging
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.coupon_points_crud import add_points_transaction
from app.push_notification_service import send_push_notification
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/newbie-tasks", tags=["新手任务"])

# Default avatar patterns that should NOT count as "uploaded"
DEFAULT_AVATAR_PATTERNS = [
    "default_avatar",
    "preset_avatar",
    "/avatars/default",
]


def _is_custom_avatar(avatar: Optional[str]) -> bool:
    """Check if avatar is a user-uploaded one (not default/empty)."""
    if not avatar or not avatar.strip():
        return False
    avatar_lower = avatar.lower()
    for pattern in DEFAULT_AVATAR_PATTERNS:
        if pattern in avatar_lower:
            return False
    return True


def _detect_task_completion(db: Session, user: models.User, task_key: str) -> bool:
    """
    Auto-detect whether a user has already completed a specific newbie task.
    Uses raw SQL for tables to avoid import issues.
    Returns True if the task condition is met.
    """
    uid = user.id

    try:
        if task_key == "upload_avatar":
            return _is_custom_avatar(user.avatar)

        elif task_key == "fill_bio":
            return bool(user.bio and len(user.bio.strip()) >= 10)

        elif task_key == "add_skills":
            result = db.execute(
                text("SELECT COUNT(*) FROM user_skills WHERE user_id = :uid"),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 3

        elif task_key == "student_verify":
            # Check student_verifications table for a verified record
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM student_verifications "
                    "WHERE user_id = :uid AND status = 'verified'"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 1

        elif task_key == "first_post":
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM forum_posts "
                    "WHERE author_id = :uid AND is_deleted = false"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 1

        elif task_key == "first_flea_item":
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM flea_market_items "
                    "WHERE seller_id = :uid"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 1

        elif task_key == "join_activity":
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM official_activity_applications "
                    "WHERE user_id = :uid"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 1

        elif task_key == "posts_5":
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM forum_posts "
                    "WHERE author_id = :uid AND is_deleted = false"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 5

        elif task_key == "posts_20":
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM forum_posts "
                    "WHERE author_id = :uid AND is_deleted = false"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 20

        elif task_key == "first_assigned_task":
            # Check if user has been assigned (taken) at least one task
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM tasks "
                    "WHERE taker_id = :uid AND status != 'open'"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 1

        elif task_key == "complete_5_tasks":
            # Completed tasks where user was the taker with avg rating >= 4
            result = db.execute(
                text(
                    "SELECT COUNT(*) FROM tasks "
                    "WHERE taker_id = :uid AND status = 'completed'"
                ),
                {"uid": uid},
            ).scalar()
            count = result or 0
            if count < 5:
                return False
            # Check average rating from reviews
            avg = db.execute(
                text(
                    "SELECT AVG(r.rating) FROM reviews r "
                    "JOIN tasks t ON r.task_id = t.id "
                    "WHERE t.taker_id = :uid AND t.status = 'completed'"
                ),
                {"uid": uid},
            ).scalar()
            return avg is not None and float(avg) >= 4.0

        elif task_key == "profile_views_50":
            return (user.profile_views or 0) >= 50

        elif task_key == "profile_views_200":
            return (user.profile_views or 0) >= 200

        elif task_key == "checkin_7":
            result = db.execute(
                text(
                    "SELECT MAX(consecutive_days) FROM check_ins "
                    "WHERE user_id = :uid"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 7

        elif task_key == "checkin_30":
            result = db.execute(
                text(
                    "SELECT MAX(consecutive_days) FROM check_ins "
                    "WHERE user_id = :uid"
                ),
                {"uid": uid},
            ).scalar()
            return (result or 0) >= 30

    except Exception as e:
        # If a table doesn't exist or query fails, log and return False
        logger.warning(f"Failed to detect completion for task '{task_key}': {e}")
        return False

    # Unknown task_key
    return False


def _ensure_progress_rows(db: Session, user_id: str) -> None:
    """
    Ensure UserTasksProgress rows exist for all active task configs.
    Creates missing rows with status='pending'.
    """
    configs = (
        db.query(models.NewbieTaskConfig)
        .filter(models.NewbieTaskConfig.is_active == True)
        .all()
    )
    existing_keys = set(
        row[0]
        for row in db.query(models.UserTasksProgress.task_key)
        .filter(models.UserTasksProgress.user_id == user_id)
        .all()
    )
    for config in configs:
        if config.task_key not in existing_keys:
            progress = models.UserTasksProgress(
                user_id=user_id,
                task_key=config.task_key,
                status="pending",
            )
            db.add(progress)
    db.commit()


def _ensure_stage_rows(db: Session, user_id: str) -> None:
    """
    Ensure StageBonusProgress rows exist for all stage configs.
    """
    stage_configs = (
        db.query(models.StageBonusConfig)
        .filter(models.StageBonusConfig.is_active == True)
        .all()
    )
    existing_stages = set(
        row[0]
        for row in db.query(models.StageBonusProgress.stage)
        .filter(models.StageBonusProgress.user_id == user_id)
        .all()
    )
    for sc in stage_configs:
        if sc.stage not in existing_stages:
            sp = models.StageBonusProgress(
                user_id=user_id,
                stage=sc.stage,
                status="pending",
            )
            db.add(sp)
    db.commit()


def _auto_detect_and_update(db: Session, user: models.User) -> None:
    """
    For all pending tasks, auto-detect if conditions are met
    and update status to 'completed'.
    Sends a push notification for each newly completed task.
    """
    pending_tasks = (
        db.query(models.UserTasksProgress)
        .filter(
            models.UserTasksProgress.user_id == user.id,
            models.UserTasksProgress.status == "pending",
        )
        .all()
    )
    now = get_utc_time()
    updated = False
    newly_completed_keys = []
    for task_progress in pending_tasks:
        if _detect_task_completion(db, user, task_progress.task_key):
            task_progress.status = "completed"
            task_progress.completed_at = now
            updated = True
            newly_completed_keys.append(task_progress.task_key)
    if updated:
        db.commit()

    # Send push notifications for newly completed tasks
    if newly_completed_keys:
        # Build config lookup for notification content
        configs = {
            c.task_key: c
            for c in db.query(models.NewbieTaskConfig)
            .filter(models.NewbieTaskConfig.task_key.in_(newly_completed_keys))
            .all()
        }
        for task_key in newly_completed_keys:
            config = configs.get(task_key)
            if not config:
                continue
            try:
                send_push_notification(
                    db=db,
                    user_id=user.id,
                    title="任务完成！",
                    body=f"你已完成'{config.title_zh}'，快去领取{config.reward_amount}积分奖励！",
                    notification_type="newbie_task_completed",
                    data={"type": "newbie_task", "task_key": task_key},
                )
            except Exception:
                logger.warning(f"Failed to send push notification for newbie task '{task_key}' to user {user.id}")
                pass  # Non-critical, don't fail if notification fails


def _check_stage_completion(db: Session, user_id: str, stage: int) -> bool:
    """
    Check if all tasks in a given stage have been claimed.
    Returns True if all tasks in the stage are claimed.
    """
    stage_task_keys = [
        row[0]
        for row in db.query(models.NewbieTaskConfig.task_key)
        .filter(
            models.NewbieTaskConfig.stage == stage,
            models.NewbieTaskConfig.is_active == True,
        )
        .all()
    ]
    if not stage_task_keys:
        return False

    claimed_count = (
        db.query(models.UserTasksProgress)
        .filter(
            models.UserTasksProgress.user_id == user_id,
            models.UserTasksProgress.task_key.in_(stage_task_keys),
            models.UserTasksProgress.status == "claimed",
        )
        .count()
    )
    return claimed_count >= len(stage_task_keys)


def _update_stage_progress(db: Session, user_id: str, stage: int) -> None:
    """
    If all tasks in a stage are claimed, update stage progress to 'completed'.
    """
    if _check_stage_completion(db, user_id, stage):
        stage_progress = (
            db.query(models.StageBonusProgress)
            .filter(
                models.StageBonusProgress.user_id == user_id,
                models.StageBonusProgress.stage == stage,
            )
            .first()
        )
        if stage_progress and stage_progress.status == "pending":
            stage_progress.status = "completed"
            db.commit()


# ==================== Endpoints ====================


@router.get("/progress")
def get_progress(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Get all task progress for the current user.
    On first call, auto-creates progress rows and detects already-completed tasks.
    """
    # Ensure progress rows exist for all active tasks
    _ensure_progress_rows(db, current_user.id)

    # Auto-detect completed tasks (only checks pending ones)
    _auto_detect_and_update(db, current_user)

    # Also ensure stage rows exist
    _ensure_stage_rows(db, current_user.id)

    # Fetch all progress with configs
    progress_rows = (
        db.query(models.UserTasksProgress)
        .filter(models.UserTasksProgress.user_id == current_user.id)
        .all()
    )

    # Build config lookup
    configs = {
        c.task_key: c
        for c in db.query(models.NewbieTaskConfig)
        .filter(models.NewbieTaskConfig.is_active == True)
        .all()
    }

    result = []
    for p in progress_rows:
        config = configs.get(p.task_key)
        if not config:
            continue
        result.append(
            schemas.UserTaskProgressOut(
                task_key=p.task_key,
                status=p.status,
                completed_at=p.completed_at,
                claimed_at=p.claimed_at,
                config=schemas.NewbieTaskConfigOut.model_validate(config),
            )
        )

    # Sort by stage then display_order
    result.sort(key=lambda x: (x.config.stage, x.config.display_order))
    return {"data": [r.model_dump() if hasattr(r, 'model_dump') else r for r in result]}


@router.post("/{task_key}/claim")
def claim_task_reward(
    task_key: str,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Claim reward for a completed newbie task.
    """
    # 1. Verify progress exists and status is "completed"
    progress = (
        db.query(models.UserTasksProgress)
        .filter(
            models.UserTasksProgress.user_id == current_user.id,
            models.UserTasksProgress.task_key == task_key,
        )
        .first()
    )
    if not progress:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task progress not found",
        )
    if progress.status == "claimed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reward already claimed",
        )
    if progress.status != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task not completed yet",
        )

    # 2. Get task config
    config = (
        db.query(models.NewbieTaskConfig)
        .filter(models.NewbieTaskConfig.task_key == task_key)
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task config not found",
        )

    # 3. Award points
    if config.reward_type == "points" and config.reward_amount > 0:
        add_points_transaction(
            db=db,
            user_id=current_user.id,
            type="earn",
            amount=config.reward_amount,
            source="newbie_task_reward",
            description=f"Completed newbie task: {task_key}",
            idempotency_key=f"newbie_task_{current_user.id}_{task_key}",
        )

    # 4. Update status to "claimed"
    progress.status = "claimed"
    progress.claimed_at = get_utc_time()
    db.commit()

    # 5. Check if all tasks in the stage are now claimed → update stage progress
    _update_stage_progress(db, current_user.id, config.stage)

    return {
        "success": True,
        "task_key": task_key,
        "reward_type": config.reward_type,
        "reward_amount": config.reward_amount,
    }


@router.get("/stages")
def get_stages(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Get stage progress for all stages.
    """
    # Ensure stage rows exist
    _ensure_stage_rows(db, current_user.id)

    # Fetch stage progress
    stage_rows = (
        db.query(models.StageBonusProgress)
        .filter(models.StageBonusProgress.user_id == current_user.id)
        .order_by(models.StageBonusProgress.stage)
        .all()
    )

    # Config lookup
    stage_configs = {
        sc.stage: sc
        for sc in db.query(models.StageBonusConfig)
        .filter(models.StageBonusConfig.is_active == True)
        .all()
    }

    result = []
    for sp in stage_rows:
        config = stage_configs.get(sp.stage)
        if not config:
            continue
        result.append(
            schemas.StageProgressOut(
                stage=sp.stage,
                status=sp.status,
                claimed_at=sp.claimed_at,
                config=schemas.StageBonusConfigOut.model_validate(config),
            )
        )

    return {"data": [r.model_dump() if hasattr(r, 'model_dump') else r for r in result]}


@router.post("/stages/{stage}/claim")
def claim_stage_bonus(
    stage: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Claim the bonus reward for completing all tasks in a stage.
    """
    # 1. Verify stage progress exists
    stage_progress = (
        db.query(models.StageBonusProgress)
        .filter(
            models.StageBonusProgress.user_id == current_user.id,
            models.StageBonusProgress.stage == stage,
        )
        .first()
    )
    if not stage_progress:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Stage progress not found",
        )
    if stage_progress.status == "claimed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stage bonus already claimed",
        )

    # 2. Verify all tasks in this stage are claimed
    if not _check_stage_completion(db, current_user.id, stage):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not all tasks in this stage are claimed yet",
        )

    # 3. Get stage bonus config
    stage_config = (
        db.query(models.StageBonusConfig)
        .filter(models.StageBonusConfig.stage == stage)
        .first()
    )
    if not stage_config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Stage bonus config not found",
        )

    # 4. Award points
    if stage_config.reward_type == "points" and stage_config.reward_amount > 0:
        add_points_transaction(
            db=db,
            user_id=current_user.id,
            type="earn",
            amount=stage_config.reward_amount,
            source="newbie_stage_bonus",
            description=f"Completed newbie stage {stage}",
            idempotency_key=f"newbie_stage_{current_user.id}_{stage}",
        )

    # 5. Update status
    stage_progress.status = "claimed"
    stage_progress.claimed_at = get_utc_time()
    db.commit()

    return {
        "success": True,
        "stage": stage,
        "reward_type": stage_config.reward_type,
        "reward_amount": stage_config.reward_amount,
    }

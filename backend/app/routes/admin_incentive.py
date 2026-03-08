"""
Admin Incentive System API Routes
管理员激励系统管理 API 路由
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import models, schemas
from app.deps import get_db
from app.role_deps import get_current_admin_secure_sync
from app.coupon_points_crud import add_points_transaction
from app.routes.leaderboard import recalculate_leaderboard
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["管理员-激励系统"])


# ==================== Newbie Task Config ====================


@router.get("/newbie-tasks/config")
def list_newbie_task_configs(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """List all newbie task configs."""
    configs = (
        db.query(models.NewbieTaskConfig)
        .order_by(models.NewbieTaskConfig.stage, models.NewbieTaskConfig.display_order)
        .all()
    )
    return [schemas.NewbieTaskConfigOut.model_validate(c).model_dump() for c in configs]


@router.put("/newbie-tasks/config/{task_key}")
def update_newbie_task_config(
    task_key: str,
    body: schemas.NewbieTaskConfigUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Update a newbie task config by task_key."""
    config = (
        db.query(models.NewbieTaskConfig)
        .filter(models.NewbieTaskConfig.task_key == task_key)
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Newbie task config '{task_key}' not found",
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(config, field, value)

    db.commit()
    db.refresh(config)
    return schemas.NewbieTaskConfigOut.model_validate(config).model_dump()


# ==================== Stage Bonus Config ====================


@router.get("/stage-bonus/config")
def list_stage_bonus_configs(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """List all stage bonus configs."""
    configs = (
        db.query(models.StageBonusConfig)
        .order_by(models.StageBonusConfig.stage)
        .all()
    )
    return [schemas.StageBonusConfigOut.model_validate(c).model_dump() for c in configs]


@router.put("/stage-bonus/config/{stage}")
def update_stage_bonus_config(
    stage: int,
    body: schemas.StageBonusConfigUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Update a stage bonus config by stage number."""
    config = (
        db.query(models.StageBonusConfig)
        .filter(models.StageBonusConfig.stage == stage)
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Stage bonus config for stage {stage} not found",
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(config, field, value)

    db.commit()
    db.refresh(config)
    return schemas.StageBonusConfigOut.model_validate(config).model_dump()


# ==================== Official Tasks Management ====================


@router.get("/official-tasks")
def list_all_official_tasks(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """List all official tasks (including inactive)."""
    tasks = (
        db.query(models.OfficialTask)
        .order_by(models.OfficialTask.created_at.desc())
        .all()
    )
    return [schemas.OfficialTaskOut.model_validate(t).model_dump() for t in tasks]


@router.post("/official-tasks")
def create_official_task(
    body: schemas.OfficialTaskCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Create a new official task."""
    task = models.OfficialTask(
        title_zh=body.title_zh,
        title_en=body.title_en,
        description_zh=body.description_zh,
        description_en=body.description_en,
        topic_tag=body.topic_tag,
        task_type=body.task_type,
        reward_type=body.reward_type,
        reward_amount=body.reward_amount,
        coupon_id=body.coupon_id,
        max_per_user=body.max_per_user,
        valid_from=body.valid_from,
        valid_until=body.valid_until,
        is_active=True,
        created_by=current_admin.id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return schemas.OfficialTaskOut.model_validate(task).model_dump()


@router.put("/official-tasks/{task_id}")
def update_official_task(
    task_id: int,
    body: schemas.OfficialTaskUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Update an official task."""
    task = (
        db.query(models.OfficialTask)
        .filter(models.OfficialTask.id == task_id)
        .first()
    )
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Official task not found",
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(task, field, value)

    db.commit()
    db.refresh(task)
    return schemas.OfficialTaskOut.model_validate(task).model_dump()


@router.delete("/official-tasks/{task_id}")
def deactivate_official_task(
    task_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Deactivate an official task (soft delete: set is_active=False)."""
    task = (
        db.query(models.OfficialTask)
        .filter(models.OfficialTask.id == task_id)
        .first()
    )
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Official task not found",
        )

    task.is_active = False
    db.commit()
    return {"success": True, "message": "Official task deactivated"}


@router.get("/official-tasks/{task_id}/stats")
def get_official_task_stats(
    task_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Get submission statistics for an official task."""
    task = (
        db.query(models.OfficialTask)
        .filter(models.OfficialTask.id == task_id)
        .first()
    )
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Official task not found",
        )

    # Total submission count
    submission_count = (
        db.query(func.count(models.OfficialTaskSubmission.id))
        .filter(models.OfficialTaskSubmission.official_task_id == task_id)
        .scalar()
    ) or 0

    # Unique users who submitted
    unique_users = (
        db.query(func.count(func.distinct(models.OfficialTaskSubmission.user_id)))
        .filter(models.OfficialTaskSubmission.official_task_id == task_id)
        .scalar()
    ) or 0

    # Claimed submissions count
    claimed_count = (
        db.query(func.count(models.OfficialTaskSubmission.id))
        .filter(
            models.OfficialTaskSubmission.official_task_id == task_id,
            models.OfficialTaskSubmission.status == "claimed",
        )
        .scalar()
    ) or 0

    return {
        "task_id": task_id,
        "submission_count": submission_count,
        "unique_users": unique_users,
        "claimed_count": claimed_count,
    }


# ==================== Manual Rewards ====================


@router.post("/rewards/send")
def send_manual_reward(
    body: schemas.AdminRewardSend,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Send points or coupon to a user manually."""
    # Verify user exists
    user = db.query(models.User).filter(models.User.id == body.user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User '{body.user_id}' not found",
        )

    # Award points if reward_type is "points"
    if body.reward_type == "points":
        if not body.points_amount or body.points_amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="points_amount must be a positive integer for points rewards",
            )
        add_points_transaction(
            db=db,
            user_id=body.user_id,
            type="earn",
            amount=body.points_amount,
            source="admin_manual_reward",
            description=body.reason or f"Admin manual reward by admin {current_admin.id}",
            idempotency_key=f"admin_reward_{current_admin.id}_{body.user_id}_{int(get_utc_time().timestamp())}",
        )

    # Log the reward action
    log_entry = models.AdminRewardLog(
        admin_id=current_admin.id,
        user_id=body.user_id,
        reward_type=body.reward_type,
        points_amount=body.points_amount,
        coupon_id=body.coupon_id,
        reason=body.reason,
    )
    db.add(log_entry)
    db.commit()
    db.refresh(log_entry)

    return {
        "success": True,
        "log": schemas.AdminRewardLogOut.model_validate(log_entry).model_dump(),
    }


@router.get("/rewards/logs")
def list_reward_logs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    user_id: Optional[str] = Query(None),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Query admin reward logs with pagination and optional user_id filter."""
    query = db.query(models.AdminRewardLog)

    if user_id:
        query = query.filter(models.AdminRewardLog.user_id == user_id)

    total = query.count()
    logs = (
        query.order_by(models.AdminRewardLog.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "logs": [schemas.AdminRewardLogOut.model_validate(log).model_dump() for log in logs],
    }


# ==================== Check-in Reward Config ====================


@router.get("/checkin/rewards")
def list_checkin_rewards(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """List all check-in reward configs."""
    rewards = (
        db.query(models.CheckInReward)
        .order_by(models.CheckInReward.consecutive_days)
        .all()
    )
    return [
        {
            "id": r.id,
            "consecutive_days": r.consecutive_days,
            "reward_type": r.reward_type,
            "points_reward": r.points_reward,
            "coupon_id": r.coupon_id,
            "reward_description": r.reward_description,
            "is_active": r.is_active,
            "created_at": r.created_at,
            "updated_at": r.updated_at,
        }
        for r in rewards
    ]


@router.post("/checkin/rewards")
def create_checkin_reward(
    body: schemas.CheckInRewardCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Create a new check-in reward config."""
    # Check for duplicate consecutive_days
    existing = (
        db.query(models.CheckInReward)
        .filter(models.CheckInReward.consecutive_days == body.consecutive_days)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Check-in reward for {body.consecutive_days} consecutive days already exists",
        )

    reward = models.CheckInReward(
        consecutive_days=body.consecutive_days,
        reward_type=body.reward_type,
        points_reward=body.points_reward,
        coupon_id=body.coupon_id,
        reward_description=body.reward_description,
        is_active=True,
    )
    db.add(reward)
    db.commit()
    db.refresh(reward)

    return {
        "id": reward.id,
        "consecutive_days": reward.consecutive_days,
        "reward_type": reward.reward_type,
        "points_reward": reward.points_reward,
        "coupon_id": reward.coupon_id,
        "reward_description": reward.reward_description,
        "is_active": reward.is_active,
    }


@router.put("/checkin/rewards/{reward_id}")
def update_checkin_reward(
    reward_id: int,
    body: schemas.CheckInRewardUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Update a check-in reward config."""
    reward = (
        db.query(models.CheckInReward)
        .filter(models.CheckInReward.id == reward_id)
        .first()
    )
    if not reward:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Check-in reward config not found",
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(reward, field, value)

    db.commit()
    db.refresh(reward)

    return {
        "id": reward.id,
        "consecutive_days": reward.consecutive_days,
        "reward_type": reward.reward_type,
        "points_reward": reward.points_reward,
        "coupon_id": reward.coupon_id,
        "reward_description": reward.reward_description,
        "is_active": reward.is_active,
    }


# ==================== Skill Categories ====================


@router.get("/skill-categories")
def list_skill_categories(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """List all skill categories (including inactive)."""
    categories = (
        db.query(models.SkillCategory)
        .order_by(models.SkillCategory.display_order)
        .all()
    )
    return [schemas.SkillCategoryOut.model_validate(c).model_dump() for c in categories]


@router.post("/skill-categories")
def create_skill_category(
    body: schemas.SkillCategoryCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Create a new skill category."""
    category = models.SkillCategory(
        name_zh=body.name_zh,
        name_en=body.name_en,
        icon=body.icon,
        display_order=body.display_order,
        is_active=True,
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return schemas.SkillCategoryOut.model_validate(category).model_dump()


@router.put("/skill-categories/{category_id}")
def update_skill_category(
    category_id: int,
    body: schemas.SkillCategoryUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Update a skill category."""
    category = (
        db.query(models.SkillCategory)
        .filter(models.SkillCategory.id == category_id)
        .first()
    )
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Skill category not found",
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(category, field, value)

    db.commit()
    db.refresh(category)
    return schemas.SkillCategoryOut.model_validate(category).model_dump()


@router.delete("/skill-categories/{category_id}")
def deactivate_skill_category(
    category_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Deactivate a skill category (soft delete: set is_active=False)."""
    category = (
        db.query(models.SkillCategory)
        .filter(models.SkillCategory.id == category_id)
        .first()
    )
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Skill category not found",
        )

    category.is_active = False
    db.commit()
    return {"success": True, "message": "Skill category deactivated"}


# ==================== Leaderboard ====================


@router.post("/leaderboard/refresh")
def refresh_leaderboard(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db),
):
    """Trigger a full leaderboard recalculation."""
    recalculate_leaderboard(db)
    return {"success": True, "message": "Leaderboard recalculation completed"}

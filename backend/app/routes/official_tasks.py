"""
Official Tasks API Routes
官方任务系统 API 路由
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app import models, schemas
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.coupon_points_crud import add_points_transaction
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/official-tasks", tags=["官方任务"])


# ==================== Endpoints ====================


@router.get("/")
def list_active_tasks(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    List active official tasks.
    Filters: is_active=True, valid_from <= now, valid_until >= now (or null).
    Each task includes the user's submission count.
    """
    now = get_utc_time()

    tasks = (
        db.query(models.OfficialTask)
        .filter(
            models.OfficialTask.is_active == True,
            or_(
                models.OfficialTask.valid_from == None,
                models.OfficialTask.valid_from <= now,
            ),
            or_(
                models.OfficialTask.valid_until == None,
                models.OfficialTask.valid_until >= now,
            ),
        )
        .order_by(models.OfficialTask.created_at.desc())
        .all()
    )

    # Build submission counts for current user
    task_ids = [t.id for t in tasks]
    submission_counts = {}
    if task_ids:
        from sqlalchemy import func

        rows = (
            db.query(
                models.OfficialTaskSubmission.official_task_id,
                func.count(models.OfficialTaskSubmission.id).label("cnt"),
            )
            .filter(
                models.OfficialTaskSubmission.user_id == current_user.id,
                models.OfficialTaskSubmission.official_task_id.in_(task_ids),
            )
            .group_by(models.OfficialTaskSubmission.official_task_id)
            .all()
        )
        submission_counts = {row[0]: row[1] for row in rows}

    # Return tasks with user_submission_count injected
    response = []
    for task in tasks:
        d = schemas.OfficialTaskOut.model_validate(task).model_dump()
        d["user_submission_count"] = submission_counts.get(task.id, 0)
        response.append(d)

    return {"data": response}


@router.get("/{task_id}")
def get_task_detail(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Get official task detail with user's submissions for this task.
    """
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

    # Get user's submissions for this task
    submissions = (
        db.query(models.OfficialTaskSubmission)
        .filter(
            models.OfficialTaskSubmission.official_task_id == task_id,
            models.OfficialTaskSubmission.user_id == current_user.id,
        )
        .order_by(models.OfficialTaskSubmission.submitted_at.desc())
        .all()
    )

    task_out = schemas.OfficialTaskOut.model_validate(task).model_dump()
    task_out["submissions"] = [
        schemas.OfficialTaskSubmissionOut.model_validate(s).model_dump()
        for s in submissions
    ]
    task_out["user_submission_count"] = len(submissions)

    return task_out


@router.post("/{task_id}/submit")
def submit_task(
    task_id: int,
    body: schemas.OfficialTaskSubmit,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Submit for a forum_post type official task.
    Body: {"forum_post_id": 123}
    """
    # 1. Task exists
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

    # 2. Task is active and not expired
    now = get_utc_time()
    if not task.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task is not active",
        )
    if task.valid_from and task.valid_from > now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task has not started yet",
        )
    if task.valid_until and task.valid_until < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task has expired",
        )

    # 3. Task type must be "forum_post"
    if task.task_type != "forum_post":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This task does not accept forum post submissions",
        )

    # 4. User hasn't exceeded max_per_user
    existing_count = (
        db.query(models.OfficialTaskSubmission)
        .filter(
            models.OfficialTaskSubmission.official_task_id == task_id,
            models.OfficialTaskSubmission.user_id == current_user.id,
        )
        .count()
    )
    if existing_count >= task.max_per_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum submissions ({task.max_per_user}) reached for this task",
        )

    # 5. The forum post exists and belongs to current user
    forum_post = (
        db.query(models.ForumPost)
        .filter(
            models.ForumPost.id == body.forum_post_id,
            models.ForumPost.is_deleted == False,
        )
        .first()
    )
    if not forum_post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Forum post not found",
        )
    if forum_post.author_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forum post does not belong to you",
        )

    # 6. Check for duplicate submission with same forum_post_id
    duplicate = (
        db.query(models.OfficialTaskSubmission)
        .filter(
            models.OfficialTaskSubmission.official_task_id == task_id,
            models.OfficialTaskSubmission.user_id == current_user.id,
            models.OfficialTaskSubmission.forum_post_id == body.forum_post_id,
        )
        .first()
    )
    if duplicate:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This forum post has already been submitted for this task",
        )

    # 7. Create submission record
    submission = models.OfficialTaskSubmission(
        user_id=current_user.id,
        official_task_id=task_id,
        forum_post_id=body.forum_post_id,
        status="submitted",
        reward_amount=task.reward_amount,
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)

    return {
        "success": True,
        "submission": schemas.OfficialTaskSubmissionOut.model_validate(submission).model_dump(),
    }


@router.post("/{task_id}/claim")
def claim_task_reward(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Claim reward for a submission with status='submitted'.
    Awards points and updates status to 'claimed'.
    """
    # Find the user's submission with status="submitted" for this task
    submission = (
        db.query(models.OfficialTaskSubmission)
        .filter(
            models.OfficialTaskSubmission.official_task_id == task_id,
            models.OfficialTaskSubmission.user_id == current_user.id,
            models.OfficialTaskSubmission.status == "submitted",
        )
        .order_by(models.OfficialTaskSubmission.submitted_at.asc())
        .first()
    )
    if not submission:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No claimable submission found for this task",
        )

    # Get the task to determine reward details
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

    # Award points
    reward_amount = submission.reward_amount or task.reward_amount
    if task.reward_type == "points" and reward_amount > 0:
        add_points_transaction(
            db=db,
            user_id=current_user.id,
            type="earn",
            amount=reward_amount,
            source="official_task_reward",
            description=f"Official task reward: {task.title_en or task.title_zh}",
            idempotency_key=f"official_task_{current_user.id}_{submission.id}",
        )

    # Update submission status
    submission.status = "claimed"
    submission.claimed_at = get_utc_time()
    db.commit()

    return {
        "success": True,
        "submission_id": submission.id,
        "reward_type": task.reward_type,
        "reward_amount": reward_amount,
    }

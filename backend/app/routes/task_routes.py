"""
Task domain routes — extracted from app/routers.py (Task 14).

19 routes covering task lifecycle, recommendations, reviews:
  - GET  /recommendations, /user/recommendation-stats
  - GET  /tasks/{task_id}/match-score
  - POST /tasks/{task_id}/interaction
  - POST /recommendations/{task_id}/feedback
  - POST /tasks/{task_id}/accept, /approve, /reject, /complete, /cancel,
         /review
  - GET  /tasks/{task_id}/reviews, /tasks/{task_id}/history
  - PATCH /tasks/{task_id}/reward, /tasks/{task_id}/visibility
  - DELETE /tasks/{task_id}/delete
  - GET  /users/{user_id}/received-reviews, /{user_id}/reviews
  - GET  /my-tasks

Mounts at both /api and /api/users via main.py. The /{user_id}/reviews
route ends up at /api/{user_id}/reviews (two segments) so it does not
collide with single-segment paths.

Module-level helpers (_get_task_detail_legacy, _request_lang_sync,
_safe_parse_images, _trigger_background_translation_prefetch) stay in
app/routers.py and are re-imported here.
"""
import json
import logging
from decimal import Decimal
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.cache import cache_response
from app.deps import (
    check_user_status,
    get_async_db_dependency,
    get_current_user_optional,
    get_current_user_secure_async_csrf,
    get_current_user_secure_sync_csrf,
    get_db,
    get_sync_db,
)
from app.performance_monitor import measure_api_performance
from app.permissions.expert_permissions import require_team_role_sync
from app.push_notification_service import send_push_notification
from app.rate_limiting import rate_limit
from app.recommendation_monitor import RecommendationMonitor, get_recommendation_metrics
from app.task_recommendation import calculate_task_match_score, get_task_recommendations
from app.user_behavior_tracker import (
    UserBehaviorTracker,
    record_task_click,
    record_task_view,
)
from app.utils.task_guards import load_real_task_or_404_sync
from app.utils.time_utils import format_iso_utc, get_utc_time
# Module-level helpers staying in app/routers.py:
from app.routers import (
    _get_task_detail_legacy,
    _request_lang_sync,
    _safe_parse_images,
    _trigger_background_translation_prefetch,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/recommendations")
def get_recommendations(
    current_user=Depends(get_current_user_secure_sync_csrf),
    limit: int = Query(20, ge=1, le=50),
    algorithm: str = Query("hybrid", pattern="^(content_based|collaborative|hybrid)$"),
    task_type: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None, max_length=200),
    latitude: Optional[float] = Query(None, ge=-90, le=90),
    longitude: Optional[float] = Query(None, ge=-180, le=180),
    db: Session = Depends(get_db),
):
    """
    获取个性化任务推荐（支持筛选条件和GPS位置）
    
    Args:
        limit: 返回任务数量（1-50）
        algorithm: 推荐算法类型
            - content_based: 基于内容的推荐
            - collaborative: 协同过滤推荐
            - hybrid: 混合推荐（推荐）
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
        latitude: 用户当前纬度（用于基于位置的推荐）
        longitude: 用户当前经度（用于基于位置的推荐）
    """
    try:
        # 将GPS位置直接传递给推荐算法（无需存储到数据库）
        recommendations = get_task_recommendations(
            db=db,
            user_id=current_user.id,
            limit=limit,
            algorithm=algorithm,
            task_type=task_type,
            location=location,
            keyword=keyword,
            latitude=latitude,
            longitude=longitude
        )
        
        # 任务双语标题从任务表列读取；缺失时后台触发预取
        task_ids = [item["task"].id for item in recommendations]
        missing_task_ids = []
        for item in recommendations:
            t = item["task"]
            if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None):
                missing_task_ids.append(t.id)
        if missing_task_ids:
            _trigger_background_translation_prefetch(
                missing_task_ids,
                target_languages=["en", "zh"],
                label="后台翻译任务标题",
            )

        result = []
        from app.utils.location_utils import obfuscate_location
        for item in recommendations:
            task = item["task"]
            title_en = getattr(task, "title_en", None)
            title_zh = getattr(task, "title_zh", None)

            # 解析图片字段
            images_list = []
            if task.images:
                try:
                    import json
                    if isinstance(task.images, str):
                        images_list = json.loads(task.images)
                    elif isinstance(task.images, list):
                        images_list = task.images
                except (json.JSONDecodeError, TypeError):
                    images_list = []

            result.append({
                "id": task.id,
                "task_id": task.id,
                "title": task.title,
                "title_en": title_en,
                "title_zh": title_zh,
                "description": task.description,
                "task_type": task.task_type,
                "location": obfuscate_location(task.location),
                "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else (float(task.reward) if task.reward else 0.0),
                "base_reward": float(task.base_reward) if task.base_reward else None,
                "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
                "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
                "deadline": task.deadline.isoformat() if task.deadline else None,
                "task_level": task.task_level,
                "match_score": round(item["score"], 3),
                "recommendation_reason": item["reason"],
                "created_at": task.created_at.isoformat() if task.created_at else None,
                "images": images_list,  # 添加图片字段
            })
        
        return {
            "recommendations": result,
            "total": len(result),
            "algorithm": algorithm
        }
    except Exception as e:
        logger.error(f"获取推荐失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐失败")


@router.get("/tasks/{task_id}/match-score")
def get_task_match_score(
    task_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    获取任务对当前用户的匹配分数
    
    用于在任务详情页显示匹配度
    """
    try:
        task = crud.get_task(db, task_id)
        if not task or not task.is_visible:
            raise HTTPException(status_code=404, detail="Task not found")
        score = calculate_task_match_score(
            db=db,
            user_id=current_user.id,
            task_id=task_id
        )

        return {
            "task_id": task_id,
            "match_score": round(score, 3),
            "match_percentage": round(score * 100, 1)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"计算匹配分数失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="计算匹配分数失败")


@router.post("/tasks/{task_id}/interaction")
def record_task_interaction(
    task_id: int,
    interaction_type: str = Body(..., pattern="^(view|click|apply|skip)$"),
    duration_seconds: Optional[int] = Body(None),
    device_type: Optional[str] = Body(None),
    is_recommended: Optional[bool] = Body(None),
    metadata: Optional[dict] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    记录用户对任务的交互行为
    
    Args:
        interaction_type: 交互类型 (view, click, apply, skip)
        duration_seconds: 浏览时长（秒），仅用于view类型
        device_type: 设备类型 (mobile, desktop, tablet)
        is_recommended: 是否为推荐任务
        metadata: 额外元数据（设备信息、推荐信息等）
    """
    try:
        # 优化：先验证任务是否存在，避免记录不存在的任务交互
        task = crud.get_task(db, task_id)
        if not task:
            logger.warning(
                f"尝试记录交互时任务不存在: user_id={current_user.id}, "
                f"task_id={task_id}, interaction_type={interaction_type}"
            )
            raise HTTPException(status_code=404, detail="Task not found")
        
        tracker = UserBehaviorTracker(db)
        is_rec = is_recommended if is_recommended is not None else False
        
        # 合并metadata，确保包含推荐信息
        final_metadata = metadata or {}
        final_metadata["is_recommended"] = is_rec
        
        if interaction_type == "view":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="view",
                duration_seconds=duration_seconds,
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "click":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="click",
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "apply":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="apply",
                device_type=device_type,
                metadata=final_metadata
            )
        elif interaction_type == "skip":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="skip",
                device_type=device_type,
                metadata=final_metadata
            )
        
        # 记录Prometheus指标
        try:
            from app.recommendation_metrics import record_user_interaction
            record_user_interaction(interaction_type, is_rec)
        except Exception as e:
            logger.debug(f"记录Prometheus推荐指标失败: {e}")
        
        return {"status": "success", "message": "交互记录成功"}
    except Exception as e:
        logger.error(f"记录交互失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录交互失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-metrics

@router.get("/user/recommendation-stats")
def get_user_recommendation_stats(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户的推荐统计"""
    try:
        monitor = RecommendationMonitor(db)
        stats = monitor.get_user_recommendation_stats(current_user.id)
        return stats
    except Exception as e:
        logger.error(f"获取用户推荐统计失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取用户推荐统计失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-analytics, /admin/top-recommended-tasks, /admin/recommendation-health, /admin/recommendation-optimization

@router.post("/recommendations/{task_id}/feedback")
def submit_recommendation_feedback(
    task_id: int,
    feedback_type: str = Body(..., pattern="^(like|dislike|not_interested|helpful)$"),
    recommendation_id: Optional[str] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    提交推荐反馈
    
    Args:
        feedback_type: 反馈类型 (like, dislike, not_interested, helpful)
        recommendation_id: 推荐批次ID（可选）
    """
    try:
        from app.recommendation_feedback import RecommendationFeedbackManager
        manager = RecommendationFeedbackManager(db)
        
        # 获取任务的推荐信息（如果有）
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        manager.record_feedback(
            user_id=current_user.id,
            task_id=task_id,
            feedback_type=feedback_type,
            recommendation_id=recommendation_id
        )
        
        return {"status": "success", "message": "反馈已记录"}
    except Exception as e:
        logger.error(f"记录推荐反馈失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录推荐反馈失败")


@router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
def accept_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 接收任务处理中（已移除DEBUG日志以提升性能）
    
    # 如果current_user为None，说明认证失败
    if not current_user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    try:

        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能接受任务")

        db_task = load_real_task_or_404_sync(db, task_id)

        if db_task.status != "open":
            raise HTTPException(
                status_code=400, detail="Task is not available for acceptance"
            )

        if db_task.poster_id == current_user.id:
            raise HTTPException(
                status_code=400, detail="You cannot accept your own task"
            )

        # 所有用户均可接受任意等级任务（任务等级仅按赏金划分，由数据库配置的阈值决定，不限制接单权限）

        # 检查任务是否已过期
        from datetime import datetime, timezone
        from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone

        current_time = get_utc_time()

        # 如果deadline是naive datetime，假设它是UTC时间（数据库迁移后应该都是带时区的）
        if db_task.deadline.tzinfo is None:
            # 旧数据兼容：假设是UTC时间
            deadline_utc = db_task.deadline.replace(tzinfo=timezone.utc)
        else:
            deadline_utc = db_task.deadline.astimezone(timezone.utc)

        if deadline_utc < current_time:
            raise HTTPException(status_code=400, detail="Task deadline has passed")

        result = crud.accept_task(db, task_id, current_user.id)
        if isinstance(result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "user_not_found": "User not found.",
                "not_designated_taker": "This task is designated for another user.",
                "task_not_open": "Task is not available for acceptance.",
                "task_already_taken": "Task has already been taken by another user.",
                "task_deadline_passed": "Task deadline has passed.",
                "commit_failed": "Failed to save, please try again.",
                "internal_error": "An internal error occurred, please try again.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(result, result),
            )
        updated_task = result

        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（接受任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")

        # 发送通知给任务发布者
        if background_tasks:
            try:
                crud.create_notification(
                    db,
                    db_task.poster_id,
                    "task_accepted",
                    "任务已被接受",
                    f"用户 {current_user.name} 接受了您的任务 '{db_task.title}'",
                    current_user.id,
                )
            except Exception as e:
                logger.warning(f"Failed to create notification: {e}")
                # 不要因为通知失败而影响任务接受

        return updated_task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/tasks/{task_id}/approve", response_model=schemas.TaskOut)
def approve_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    任务发布者同意接受者进行任务
    
    ⚠️ 安全修复：添加支付验证，防止绕过支付
    注意：此端点可能已废弃，新的流程使用 accept_application 端点
    """
    import logging
    logger = logging.getLogger(__name__)
    
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can approve the taker"
        )

    # ⚠️ 安全修复：检查支付状态，防止绕过支付
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试批准未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400, 
            detail="任务尚未支付，无法批准。请先完成支付。"
        )

    # 检查任务状态：必须是 pending_payment 或 in_progress 状态
    # 注意：旧的 "taken" 状态已废弃，新流程使用 pending_payment
    if db_task.status not in ["pending_payment", "in_progress", "taken"]:
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法批准。当前状态: {db_task.status}"
        )

    # 更新任务状态为进行中（如果还不是）
    # ⚠️ 安全修复：确保只有已支付的任务才能进入 in_progress 状态
    if db_task.status == "pending_payment":
        # 再次确认支付状态（双重检查）
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 pending_payment 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 pending_payment 更新为 in_progress（已确认支付）")
    elif db_task.status == "taken":
        # 兼容旧流程：如果状态是 taken，也更新为 in_progress
        # ⚠️ 安全修复：确保已支付
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 taken 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 taken 更新为 in_progress（旧流程兼容，已确认支付）")
    # 如果已经是 in_progress，不需要更新
    
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（批准任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 创建通知给任务接受者
    if background_tasks and db_task.taker_id:
        try:
            crud.create_notification(
                db,
                db_task.taker_id,
                "task_approved",
                "任务已批准",
                f"您的任务申请 '{db_task.title}' 已被发布者批准，可以开始工作了",
                current_user.id,
            )
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")

    return db_task


@router.post("/tasks/{task_id}/reject", response_model=schemas.TaskOut)
def reject_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者拒绝接受者，任务重新变为open状态"""
    db_task = load_real_task_or_404_sync(db, task_id)

    # 检查权限：只有任务发布者可以拒绝
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can reject the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 记录被拒绝的接受者ID
    rejected_taker_id = db_task.taker_id

    # 重置任务状态为open，清除接受者
    db_task.status = "open"
    db_task.taker_id = None
    db.commit()
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（拒绝任务接受者）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 创建通知给被拒绝的接受者
    if background_tasks and rejected_taker_id:
        try:
            crud.create_notification(
                db,
                rejected_taker_id,
                "task_rejected",
                "任务申请被拒绝",
                f"您的任务申请 '{db_task.title}' 已被发布者拒绝，任务已重新开放",
                current_user.id,
            )
            
            # 发送推送通知
            try:
                send_push_notification(
                    db=db,
                    user_id=rejected_taker_id,
                    notification_type="task_rejected",
                    data={"task_id": task_id},
                    template_vars={"task_title": db_task.title, "task_id": task_id}
                )
            except Exception as e:
                logger.warning(f"发送任务拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")

    return db_task


@router.patch("/tasks/{task_id}/reward", response_model=schemas.TaskOut)
def update_task_reward(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务价格（仅任务发布者可见）"""
    result = crud.update_task_reward(db, task_id, current_user.id, task_update.reward)
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "You don't have permission to update this task.",
            "task_not_open": "Task can only be updated while in open status.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    return result


class VisibilityUpdate(BaseModel):
    is_public: int = Field(..., ge=0, le=1, description="0=私密, 1=公开")


@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: VisibilityUpdate = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（发布者更新 is_public，接单者更新 taker_public）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    is_public = visibility_update.is_public

    if task.poster_id == current_user.id:
        task.is_public = is_public
    elif task.taker_id == current_user.id:
        task.taker_public = is_public
    else:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    db.commit()
    db.refresh(task)
    return task


@router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
@rate_limit("api_write", limit=10, window=60)  # 限制：10次/分钟，防止刷评价
def create_review(
    task_id: int,
    review: schemas.ReviewCreate = Body(...),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能创建评价")

    result = crud.create_review(db, current_user.id, task_id, review)
    if isinstance(result, str):
        error_messages = {
            "task_not_completed": "Task is not completed yet.",
            "not_participant": "You are not a participant of this task.",
            "already_reviewed": "You have already reviewed this task.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    db_review = result
    
    # 清除评价列表缓存，确保新评价立即显示
    try:
        from app.cache import invalidate_cache
        # 清除该任务的所有评价缓存（使用通配符匹配所有可能的缓存键）
        invalidate_cache(f"task_reviews:get_task_reviews:*")
        logger.info(f"已清除任务 {task_id} 的评价列表缓存")
    except Exception as e:
        logger.warning(f"清除评价缓存失败: {e}")
    
    # P2 优化：异步处理非关键操作（发送通知等）
    if background_tasks:
        def send_review_notification():
            """后台发送评价通知（非关键操作）"""
            try:
                # 获取任务信息
                task = crud.get_task(db, task_id)
                if not task:
                    return
                
                # 确定被评价的用户（不是评价者）
                reviewed_user_id = None
                if task.is_multi_participant:
                    # 多人任务：参与者评价达人，达人评价第一个参与者
                    if task.created_by_expert and task.expert_creator_id:
                        if current_user.id != task.expert_creator_id:
                            reviewed_user_id = task.expert_creator_id
                        elif task.originating_user_id:
                            reviewed_user_id = task.originating_user_id
                    elif task.taker_id and current_user.id != task.taker_id:
                        reviewed_user_id = task.taker_id
                else:
                    # 单人任务：发布者评价接受者，接受者评价发布者
                    reviewed_user_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
                
                # 通知被评价的用户
                if reviewed_user_id and reviewed_user_id != current_user.id:
                    crud.create_notification(
                        db,
                        reviewed_user_id,
                        "review_created",
                        "收到新评价",
                        f"任务 '{task.title}' 收到了新评价",
                        related_id=str(task_id),
                        related_type="task_id",
                        title_en="New Review Received",
                        content_en=f"New review received for task '{task.title}'",
                    )
            except Exception as e:
                logger.warning(f"发送评价通知失败: {e}")
        
        background_tasks.add_task(send_review_notification)
    
    return db_review


@router.get("/tasks/{task_id}/reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_task_reviews")
def get_task_reviews(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    # 内容审核检查：隐藏的任务不返回评价
    task = load_real_task_or_404_sync(db, task_id)
    if not task.is_visible:
        raise HTTPException(status_code=404, detail="Task not found")
    current_user_id = current_user.id if current_user else None
    reviews = crud.get_task_reviews(db, task_id, current_user_id=current_user_id)
    return [schemas.ReviewOut.model_validate(r) for r in reviews]


@router.get("/users/{user_id}/received-reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_user_received_reviews")
@cache_response(ttl=300, key_prefix="user_reviews")  # 缓存5分钟
def get_user_received_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return crud.get_user_received_reviews(db, user_id)


@router.get("/{user_id}/reviews")
@measure_api_performance("get_user_reviews")
@cache_response(ttl=300, key_prefix="user_reviews_alt")  # 缓存5分钟
def get_user_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的评价（用于个人主页显示）"""
    try:
        reviews = crud.get_user_reviews_with_reviewer_info(db, user_id)
        return reviews
    except Exception as e:
        import traceback
        logger.error(f"获取用户评价失败: {e}")
        logger.error(traceback.format_exc())
        return []


@router.post("/tasks/{task_id}/complete", response_model=schemas.TaskOut)
def complete_task(
    task_id: int,
    evidence_images: Optional[List[str]] = Body(None, description="证据图片URL列表"),
    evidence_text: Optional[str] = Body(None, description="文字证据说明（可选）"),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能完成任务")

    # 验证文字证据长度
    if evidence_text and len(evidence_text.strip()) > 500:
        raise HTTPException(
            status_code=400,
            detail="文字证据说明不能超过500字符"
        )

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发完成
    locked_task_query = select(models.Task).where(
        models.Task.id == task_id
    ).with_for_update()
    db_task = db.execute(locked_task_query).scalar_one_or_none()
    
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    if db_task.is_consultation_placeholder:
        raise HTTPException(status_code=404, detail="任务不存在")  # 防探测:同 404 遮掩占位 task 存在

    if db_task.status != "in_progress":
        raise HTTPException(status_code=400, detail="Task is not in progress")

    # 权限检查: 单人任务只有 taker 能完成；
    # 团队任务 (taker_expert_id 非空) 允许 owner/admin 任意一人完成。
    if db_task.taker_id != current_user.id:
        if db_task.taker_expert_id:
            from app.permissions.expert_permissions import require_team_role_sync
            require_team_role_sync(
                db, db_task.taker_expert_id, current_user.id, minimum="admin"
            )
        else:
            raise HTTPException(
                status_code=403, detail="Only the task taker can complete the task"
            )

    # ⚠️ 安全修复：检查支付状态，确保只有已支付的任务才能完成
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试完成未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无法完成。请联系发布者完成支付。"
        )

    # 更新任务状态为等待确认
    from datetime import timedelta
    now = get_utc_time()
    db_task.status = "pending_confirmation"
    db_task.completed_at = now
    # 设置确认截止时间：completed_at + 5天
    db_task.confirmation_deadline = now + timedelta(days=5)
    # 清除之前的提醒状态
    db_task.confirmation_reminder_sent = 0
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"完成任务状态更新失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="任务状态更新失败，请重试")
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（完成任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message, MessageAttachment
        from app.utils.notification_templates import get_notification_texts
        import json
        
        taker_name = current_user.name or f"用户{current_user.id}"
        # 根据是否有证据（图片或文字）显示不同的消息内容
        has_evidence = (evidence_images and len(evidence_images) > 0) or (evidence_text and evidence_text.strip())
        if has_evidence:
            # 使用国际化模板
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=True
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                if evidence_text and evidence_text.strip():
                    content_zh = f"任务已完成。{evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_zh = "任务已完成，请查看证据图片。"
            if not content_en:
                if evidence_text and evidence_text.strip():
                    content_en = f"Task completed. {evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_en = "Task completed. Please check the evidence images."
        else:
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=False
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                content_zh = f"接收者 {taker_name} 已确认完成任务，等待发布者确认。"
            if not content_en:
                content_en = f"Recipient {taker_name} has confirmed task completion, waiting for poster confirmation."
        
        # 构建meta信息，包含证据信息
        meta_data = {
            "system_action": "task_completed_by_taker",
            "content_en": content_en
        }
        if evidence_text and evidence_text.strip():
            meta_data["evidence_text"] = evidence_text
        if evidence_images and len(evidence_images) > 0:
            meta_data["evidence_images_count"] = len(evidence_images)
        
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps(meta_data),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID
        
        # 如果有证据图片，创建附件（满足 ck_message_attachments_url_blob：url 与 blob_id 二选一）
        if evidence_images:
            for image_url in evidence_images:
                # 从URL中提取image_id（如果URL格式为 {base_url}/api/private-image/{image_id}?user=...&token=...）
                image_id = None
                if image_url and '/api/private-image/' in image_url:
                    try:
                        from urllib.parse import urlparse
                        parsed_url = urlparse(image_url)
                        if '/api/private-image/' in parsed_url.path:
                            path_parts = parsed_url.path.split('/api/private-image/')
                            if len(path_parts) > 1:
                                image_id = path_parts[1].split('?')[0]
                                logger.debug(f"Extracted image_id {image_id} from URL {image_url}")
                    except Exception as e:
                        logger.warning(f"Failed to extract image_id from URL {image_url}: {e}")
                # 约束要求 (url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL)
                if image_id:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=None,
                        blob_id=image_id,
                        meta=None,
                        created_at=get_utc_time()
                    )
                else:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=image_url,
                        blob_id=None,
                        meta=None,
                        created_at=get_utc_time()
                    )
                db.add(attachment)
        
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务完成流程

    # 发送任务完成通知和邮件给发布者（始终创建通知，让发布者知道完成情况与证据）
    try:
        from app.task_notifications import send_task_completion_notification
        from fastapi import BackgroundTasks
        
        # 确保 background_tasks 存在，如果为 None 则创建新实例
        if background_tasks is None:
            background_tasks = BackgroundTasks()
        
        # 只要任务有发布者就发送通知（不依赖 poster 对象是否存在）
        if db_task.poster_id:
            send_task_completion_notification(
                db=db,
                background_tasks=background_tasks,
                task=db_task,
                taker=current_user,
                evidence_images=evidence_images,
                evidence_text=evidence_text,
            )
    except Exception as e:
        logger.warning(f"Failed to send task completion notification: {e}")
        # 通知发送失败不影响任务完成流程

    # 检查任务接受者是否满足VIP晋升条件
    try:
        crud.check_and_upgrade_vip_to_super(db, current_user.id)
    except Exception as e:
        logger.warning(f"Failed to check VIP upgrade: {e}")

    return db_task


@router.post("/tasks/{task_id}/cancel")
def cancel_task(
    task_id: int,
    cancel_data: schemas.TaskCancelRequest = Body(default=schemas.TaskCancelRequest()),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """取消任务 - 如果任务已被接受，需要客服审核"""
    task = load_real_task_or_404_sync(db, task_id)

    # 检查权限：只有任务发布者或接受者可以取消任务
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster or taker can cancel the task"
        )

    # 如果任务状态是 'open'，直接取消
    if task.status == "open":
        cancel_result = crud.cancel_task(db, task_id, current_user.id)
        if isinstance(cancel_result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "cancel_not_permitted": "You don't have permission to cancel this task.",
                "not_participant": "Only task participants can cancel.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(cancel_result, cancel_result),
            )
        cancelled_task = cancel_result
        
        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（取消任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")
        
        return cancelled_task

    # pending_payment 状态: buyer 在支付前可以自助取消(无需客服审核)
    # 场景: 团队服务被 owner approve 后,Task 进入 pending_payment 等支付,
    # buyer 反悔不想付。需要 cancel PaymentIntent + 回滚 ServiceApplication。
    elif task.status == "pending_payment":
        # 仅 poster (买家) 能在 pending_payment 自助取消;接单方也可以(代取消)
        if task.poster_id != current_user.id and task.taker_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail="Only the buyer or assignee can cancel a pending payment task",
            )

        # 1) Cancel Stripe PaymentIntent (best-effort)
        if task.payment_intent_id:
            try:
                import stripe
                from app.stripe_config import ensure_stripe_configured
                ensure_stripe_configured()
                pi = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                # 仅当 PI 还可以取消的状态才 cancel(已 succeeded 走 refund 路径,不在这里处理)
                if pi.status in (
                    "requires_payment_method",
                    "requires_confirmation",
                    "requires_action",
                    "processing",
                ):
                    stripe.PaymentIntent.cancel(task.payment_intent_id)
                    logger.info(f"PaymentIntent {task.payment_intent_id} cancelled by user")
                elif pi.status == "succeeded":
                    # PI 已 succeeded 但 webhook 还没处理,这是窗口期。拒绝自助取消,
                    # 让 webhook 流转完成后走标准退款流程
                    raise HTTPException(
                        status_code=409,
                        detail="支付已完成,请刷新页面后通过取消任务流程申请退款",
                    )
            except HTTPException:
                raise
            except Exception as e:
                logger.warning(f"Stripe PI cancel 失败 (不阻塞任务取消): {e}")

        # 2) 回滚 ServiceApplication 到 cancelled (如果是团队服务流程)
        try:
            sa = db.query(models.ServiceApplication).filter(
                models.ServiceApplication.task_id == task_id
            ).first()
            if sa:
                sa.status = "cancelled"
                sa.updated_at = get_utc_time()
                # 回退时间段参与者占位 (与 user_service_application_routes 一致)
                if sa.time_slot_id:
                    db.execute(
                        update(models.ServiceTimeSlot)
                        .where(models.ServiceTimeSlot.id == sa.time_slot_id)
                        .where(models.ServiceTimeSlot.current_participants > 0)
                        .values(
                            current_participants=models.ServiceTimeSlot.current_participants - 1
                        )
                    )
        except Exception as e:
            logger.warning(f"回滚 ServiceApplication 失败: {e}")

        # 3) 任务标记为 cancelled
        task.status = "cancelled"
        task.cancelled_at = get_utc_time()

        # 原任务取消 → 所有指向它的咨询占位一并归档
        try:
            from app.consultation.approval import close_placeholders_for_task
            close_placeholders_for_task(
                db,
                original_task_id=task_id,
                reason_zh="任务已被取消,咨询自动关闭",
                reason_en="Task cancelled. Consultation auto-closed.",
                system_action="consultation_auto_closed_on_task_cancelled",
            )
        except Exception as _cp_err:
            logger.warning(
                f"⚠️ [cancel-task] 批量归档咨询占位失败(不阻断主流程): "
                f"task_id={task_id} err={_cp_err}"
            )

        db.commit()

        # 4) 通知双方
        try:
            from app.utils.notification_templates import get_notification_texts
            crud.create_notification(
                db=db,
                user_id=task.poster_id,
                type="task_cancelled",
                title="任务已取消",
                content=f"任务「{task.title}」已取消,如已扣款将自动退回。",
                related_id=str(task_id),
                auto_commit=False,
            )
            if task.taker_id and task.taker_id != task.poster_id:
                crud.create_notification(
                    db=db,
                    user_id=task.taker_id,
                    type="task_cancelled",
                    title="订单已被取消",
                    content=f"任务「{task.title}」已被买家取消。",
                    related_id=str(task_id),
                    auto_commit=False,
                )
            db.commit()
        except Exception as e:
            logger.warning(f"取消通知发送失败: {e}")

        # 清缓存
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
        except Exception:
            pass

        return {"message": "任务已取消", "status": "cancelled"}

    # 如果任务已被接受或正在进行中，创建取消请求等待客服审核
    elif task.status in ["taken", "in_progress"]:
        # 检查是否已有待审核的取消请求
        existing_request = crud.get_task_cancel_requests(db, "pending")
        existing_request = next(
            (req for req in existing_request if req.task_id == task_id), None
        )

        if existing_request:
            raise HTTPException(
                status_code=400,
                detail="A cancel request is already pending for this task",
            )

        # 创建取消请求
        cancel_request = crud.create_task_cancel_request(
            db, task_id, current_user.id, cancel_data.reason
        )

        # 注意：不发送通知到 notifications 表，因为客服不在 users 表中
        # 客服可以通过客服面板的取消请求列表查看待审核的请求
        # 如果需要通知功能，应该使用 staff_notifications 表通知所有在线客服

        return {
            "message": "Cancel request submitted for admin review",
            "request_id": cancel_request.id,
        }

    else:
        raise HTTPException(
            status_code=400, detail="Task cannot be cancelled in current status"
        )


@router.delete("/tasks/{task_id}/delete")
def delete_cancelled_task(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """删除已取消的任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 只有任务发布者可以删除任务
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can delete the task"
        )

    # 只有已取消的任务可以删除
    if task.status != "cancelled":
        raise HTTPException(
            status_code=400, detail="Only cancelled tasks can be deleted"
        )

    # 使用新的安全删除函数
    result = crud.delete_user_task(db, task_id, current_user.id)
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "Only the task poster can delete this task.",
            "task_not_cancelled": "Only cancelled tasks can be deleted.",
            "delete_failed": "Failed to delete task, please try again.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )

    return result


@router.get("/tasks/{task_id}/history")
@measure_api_performance("get_task_history")
@cache_response(ttl=180, key_prefix="task_history")  # 缓存3分钟
def get_task_history(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 安全校验：只允许任务参与者查看任务历史
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this task's history")
    
    history = crud.get_task_history(db, task_id)
    return [
        {
            "id": h.id,
            "user_id": h.user_id,
            "action": h.action,
            "timestamp": h.timestamp,
            "remark": h.remark,
        }
        for h in history
    ]


@router.get("/my-tasks")
@measure_api_performance("get_my_tasks")
def get_my_tasks(
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, description="页码，从 1 开始"),
    page_size: int = Query(20, ge=1, le=100, description="每页条数"),
    role: str | None = Query(None, description="角色筛选: poster=我发布的, taker=我接取的"),
    status: str | None = Query(None, description="状态筛选: open, in_progress, completed, cancelled 等"),
):
    """获取当前用户的任务（支持按 role/status 筛选与分页）。返回 { tasks, total, page, page_size }。"""
    offset = (page - 1) * page_size
    tasks, total = crud.get_user_tasks(
        db, current_user.id,
        limit=page_size, offset=offset,
        role=role, status=status,
    )

    # 任务双语字段已由 ORM 从任务表列加载；缺失时后台触发预取
    task_ids = [task.id for task in tasks]
    missing_task_ids = [
        t.id for t in tasks
        if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None)
        or not getattr(t, "description_en", None) or not getattr(t, "description_zh", None)
    ]
    if missing_task_ids:
        _trigger_background_translation_prefetch(
            missing_task_ids,
            target_languages=["en", "zh"],
            label="后台翻译任务",
        )

    # 批量加载展示勋章
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_user_ids = set()
    for t in tasks:
        if t.poster is not None:
            _badge_user_ids.add(t.poster.id)
        if t.taker is not None:
            _badge_user_ids.add(t.taker.id)
    _badge_cache = enrich_displayed_badges_sync(db, list(_badge_user_ids))

    # 序列化任务，并附带相关用户简要信息（当前用户是任务相关方）
    task_list = []
    for t in tasks:
        task_dict = schemas.TaskOut.model_validate(t).model_dump()
        if t.poster is not None:
            task_dict["poster"] = schemas.UserBrief.model_validate(t.poster).model_dump()
            task_dict["poster"]["displayed_badge"] = _badge_cache.get(t.poster.id)
        if t.taker is not None:
            task_dict["taker"] = schemas.UserBrief.model_validate(t.taker).model_dump()
            task_dict["taker"]["displayed_badge"] = _badge_cache.get(t.taker.id)
        task_list.append(task_dict)

    return {
        "tasks": task_list,
        "total": total,
        "page": page,
        "page_size": page_size,
    }



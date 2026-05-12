"""
管理员 - 任务管理路由
从 routers.py 迁移
"""
import json
import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Body
from sqlalchemy.orm import Session
from sqlalchemy import or_, func

from app import crud, models, schemas
from app.audit_logger import log_admin_action
from app.deps import get_db
from app.rate_limiting import rate_limit
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.services.task_service import TaskService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-任务管理"])


@router.get("/admin/tasks")
@rate_limit("admin_read", limit=100, window=60)
def admin_get_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status: str = None,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    include_placeholders: bool = Query(False, description="包含咨询占位 task；客服专用，默认隐藏"),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务列表（支持分页和筛选）"""
    from app.models import Task

    # 构建查询
    query = db.query(Task)

    # 默认排除占位 task；客服显式需要时加 ?include_placeholders=true
    if not include_placeholders:
        query = query.filter(Task.is_consultation_placeholder == False)  # noqa: E712

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(Task.status == status)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选（使用精确城市匹配，避免街道名误匹配）
    if location and location.strip():
        loc = location.strip()
        if loc.lower() == 'other':
            from sqlalchemy import not_
            from app.utils.city_filter_utils import build_other_exclusion_filter
            exclusion_expr = build_other_exclusion_filter(Task.location)
            if exclusion_expr is not None:
                query = query.filter(not_(exclusion_expr))
        elif loc.lower() == 'online':
            query = query.filter(Task.location.ilike("%online%"))
        else:
            from app.utils.city_filter_utils import build_city_location_filter
            city_expr = build_city_location_filter(Task.location, loc)
            if city_expr is not None:
                query = query.filter(city_expr)

    # 添加关键词搜索（使用 pg_trgm + 双语扩展优化）
    if keyword and keyword.strip():
        from app.utils.search_expander import build_keyword_filter
        keyword_expr = build_keyword_filter(
            columns=[Task.title, Task.description, Task.task_type, Task.location],
            keyword=keyword.strip(),
            use_similarity=True,
        )
        if keyword_expr is not None:
            query = query.filter(keyword_expr)

    # 获取总数
    total = query.count()

    # 执行查询并排序
    tasks = query.order_by(Task.created_at.desc()).offset(skip).limit(limit).all()

    return {"tasks": tasks, "total": total, "skip": skip, "limit": limit}


@router.get("/admin/tasks/{task_id}")
def admin_get_task_detail(
    task_id: int, current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取任务详情"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 获取任务历史
    history = crud.get_task_history(db, task_id)

    return {"task": task, "history": history}


@router.put("/admin/tasks/{task_id}")
def admin_update_task(
    task_id: int,
    task_update: schemas.AdminTaskUpdate,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员更新任务信息"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查是否尝试修改敏感字段
    update_data = task_update.dict(exclude_unset=True)
    SENSITIVE_FIELDS = {'is_paid', 'escrow_amount', 'payment_intent_id', 'is_confirmed', 'paid_to_user_id', 'taker_id', 'agreed_reward'}
    attempted_sensitive_fields = set(update_data.keys()) & SENSITIVE_FIELDS
    
    if attempted_sensitive_fields:
        # 记录尝试修改敏感字段的审计日志
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="attempted_sensitive_field_update",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value=None,
            new_value={k: v for k, v in update_data.items() if k in attempted_sensitive_fields},
            reason=f"管理员 {current_user.id} ({current_user.name}) 尝试修改敏感支付字段（已被阻止）",
            ip_address=ip_address,
        )
        logger.warning(
            f"⚠️ 管理员 {current_user.id} 尝试修改任务的敏感字段（已阻止）: "
            f"task_id={task_id}, fields={attempted_sensitive_fields}"
        )

    # 更新任务（返回变更信息）
    updated_task, old_values, new_values = crud.update_task_by_admin(
        db, task_id, update_data
    )

    # 记录操作历史
    crud.add_task_history(
        db, task_id, None, "admin_update", f"管理员 {current_user.id} ({current_user.name}) 更新了任务信息"
    )
    
    # 记录审计日志（如果有变更）
    if old_values and new_values:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_task",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value=old_values,
            new_value=new_values,
            reason=f"管理员 {current_user.id} ({current_user.name}) 更新了任务信息",
            ip_address=ip_address,
        )

    # 如果更新了图片且包含临时目录路径，移到正式目录
    if "images" in update_data and update_data["images"]:
        has_temp = any("/temp_" in (url or "") for url in update_data["images"])
        if has_temp:
            try:
                from app.services import ImageCategory, get_image_upload_service
                service = get_image_upload_service()
                new_images = service.move_from_temp(
                    category=ImageCategory.TASK,
                    user_id=current_user.id,
                    resource_id=str(task_id),
                    image_urls=update_data["images"],
                )
                if new_images != update_data["images"]:
                    updated_task.images = json.dumps(new_images)
                    db.commit()
            except Exception as e:
                logger.warning(f"管理员更新任务时移动临时图片失败: {e}")

    # 使任务详情缓存失效
    TaskService.invalidate_cache(task_id)

    return {"message": "任务更新成功", "task": updated_task}


@router.delete("/admin/tasks/{task_id}")
def admin_delete_task(
    task_id: int, 
    current_user=Depends(get_current_admin), 
    request: Request = None,
    db: Session = Depends(get_db)
):
    """管理员删除任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 记录任务信息（用于审计日志）
    task_data = {
        'id': task.id,
        'title': task.title,
        'status': task.status,
        'poster_id': task.poster_id,
        'taker_id': task.taker_id,
        'reward': float(task.reward) if task.reward else None,
        'task_type': task.task_type,
        'location': task.location,
    }

    # 记录删除历史
    crud.add_task_history(
        db, task_id, None, "admin_delete", f"管理员 {current_user.id} ({current_user.name}) 删除了任务"
    )

    # 删除任务
    success = crud.delete_task_by_admin(db, task_id)

    if success:
        # 记录审计日志
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="delete_task",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value=task_data,
            new_value=None,
            reason=f"管理员 {current_user.id} ({current_user.name}) 删除了任务",
            ip_address=ip_address,
        )
        log_admin_action(
            action="delete_task",
            admin_id=current_user.id,
            request=request,
            target_type="task",
            target_id=str(task_id),
            details=task_data,
        )
        return {"message": f"任务 {task_id} 已删除"}
    else:
        raise HTTPException(status_code=500, detail="删除任务失败")


@router.post("/admin/tasks/batch-update")
def admin_batch_update_tasks(
    task_ids: list[int],
    task_update: schemas.AdminTaskUpdate,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员批量更新任务"""
    # 🔒 安全修复：限制批量操作数组大小，防止 DoS
    if len(task_ids) > 200:
        raise HTTPException(status_code=400, detail=f"批量操作最多支持200个任务，当前提交{len(task_ids)}个")
    
    updated_tasks = []
    failed_tasks = []
    ip_address = get_client_ip(request) if request else None

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                updated_task, old_values, new_values = crud.update_task_by_admin(
                    db, task_id, task_update.dict(exclude_unset=True)
                )
                crud.add_task_history(
                    db,
                    task_id,
                    None,
                    "admin_batch_update",
                    f"管理员 {current_user.id} ({current_user.name}) 批量更新了任务信息",
                )
                # 记录审计日志（如果有变更）
                if old_values and new_values:
                    crud.create_audit_log(
                        db=db,
                        action_type="batch_update_task",
                        entity_type="task",
                        entity_id=str(task_id),
                        admin_id=current_user.id,
                        user_id=task.poster_id,
                        old_value=old_values,
                        new_value=new_values,
                        reason=f"管理员 {current_user.id} ({current_user.name}) 批量更新了任务信息",
                        ip_address=ip_address,
                    )
                TaskService.invalidate_cache(task_id)
                updated_tasks.append(updated_task)
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    return {
        "message": f"批量更新完成，成功: {len(updated_tasks)}, 失败: {len(failed_tasks)}",
        "updated_tasks": updated_tasks,
        "failed_tasks": failed_tasks,
    }


@router.post("/admin/tasks/batch-delete")
def admin_batch_delete_tasks(
    task_ids: list[int],
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员批量删除任务"""
    # 🔒 安全修复：限制批量操作数组大小，防止 DoS
    if len(task_ids) > 200:
        raise HTTPException(status_code=400, detail=f"批量操作最多支持200个任务，当前提交{len(task_ids)}个")
    
    deleted_tasks = []
    failed_tasks = []

    for task_id in task_ids:
        try:
            task = crud.get_task(db, task_id)
            if task:
                crud.add_task_history(
                    db,
                    task_id,
                    None,
                    "admin_batch_delete",
                    f"管理员 {current_user.id} ({current_user.name}) 批量删除了任务",
                )
                success = crud.delete_task_by_admin(db, task_id)
                if success:
                    deleted_tasks.append(task_id)
                else:
                    failed_tasks.append({"task_id": task_id, "error": "删除失败"})
            else:
                failed_tasks.append({"task_id": task_id, "error": "任务不存在"})
        except Exception as e:
            failed_tasks.append({"task_id": task_id, "error": str(e)})

    if deleted_tasks:
        log_admin_action(
            action="batch_delete_tasks",
            admin_id=current_user.id,
            request=request,
            target_type="task",
            target_id=",".join(str(t) for t in deleted_tasks),
            details={"count": len(deleted_tasks), "task_ids": deleted_tasks},
        )

    return {
        "message": f"批量删除完成，成功: {len(deleted_tasks)}, 失败: {len(failed_tasks)}",
        "deleted_tasks": deleted_tasks,
        "failed_tasks": failed_tasks,
    }


@router.post("/admin/task/{task_id}/set_level")
def admin_set_task_level(
    task_id: int,
    level: str = Body(...),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员设置任务等级"""
    # 安全：验证等级值是否合法
    ALLOWED_TASK_LEVELS = {"normal", "vip", "super", "expert"}
    if level not in ALLOWED_TASK_LEVELS:
        raise HTTPException(
            status_code=400,
            detail=f"无效的任务等级，允许的值: {', '.join(ALLOWED_TASK_LEVELS)}"
        )
    
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found.")
    
    old_level = task.task_level
    task.task_level = level
    db.commit()
    
    # 记录审计日志
    if old_level != level:
        ip_address = get_client_ip(request) if request else None
        crud.create_audit_log(
            db=db,
            action_type="update_task_level",
            entity_type="task",
            entity_id=str(task_id),
            admin_id=current_user.id,
            user_id=task.poster_id,
            old_value={"task_level": old_level},
            new_value={"task_level": level},
            reason=f"管理员 {current_user.id} ({current_user.name}) 修改了任务等级",
            ip_address=ip_address,
        )
    
    return {"message": f"Task {task_id} level set to {level}."}


@router.get("/admin/cancel-requests", response_model=list[schemas.TaskCancelRequestOut])
def admin_get_cancel_requests(
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取取消请求列表"""
    return crud.get_task_cancel_requests(db)


@router.post("/admin/cancel-requests/{request_id}/review")
def admin_review_cancel_request(
    request_id: int,
    decision: str = Body(..., pattern="^(approve|reject)$"),
    admin_comment: str = Body(None),
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """管理员审核取消请求"""
    cancel_request = db.query(models.TaskCancelRequest).filter(
        models.TaskCancelRequest.id == request_id
    ).first()
    
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Cancel request has already been reviewed")

    from app.utils.time_utils import get_utc_time
    from app.push_notification_service import send_push_notification

    # 提前读 task,需要在 crud.cancel_task 之前保存 taker_id —— reverted_to_open
    # 分支会把 task.taker_id 清成 None,失去通知"另一方"的信息源。
    task = crud.get_task(db, cancel_request.task_id)
    original_taker_id = task.taker_id if task else None

    if decision == "approve":
        # ⚠️ 关键修复:原来直接 task.status="cancelled" 一行就完,完全不做资金/状态清理:
        #   - 不退款 (escrow 卡死)
        #   - 不清 is_paid / payment_intent_id / escrow_amount
        #   - 不清 taker_id / taker_expert_id
        #   - 不 reject 旧 application (zombie approved row)
        #   - 不回滚 ServiceApplication (团队服务流程会留 dangling 引用)
        # 改成调用 crud.cancel_task(is_admin_review=True),复用 cs_routes 用的同一个
        # 经过加固的取消路径 —— 自动退款 + 字段清理 + reverted_to_open vs cancelled
        # 分支判断 + 团队任务走 cancelled 终态等全部行为统一。
        # 顺序: 先执行实际取消,成功后再标 request=approved。万一 crud.cancel_task
        # 失败,cancel_request 保留 pending 状态便于重试,而不是留下"已批准但任务没取消"
        # 的悬空状态。
        try:
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )
        except Exception as e:
            logger.error(
                f"admin_review_cancel_request: crud.cancel_task 失败 "
                f"request_id={request_id} task_id={cancel_request.task_id} err={e}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="任务取消执行失败,请检查后台日志")
        cancel_request.status = "approved"
        # 仍保留 admin 自己的历史记录条目,便于审计区分 admin 路径 vs CS 路径
        crud.add_task_history(
            db, cancel_request.task_id, None, "admin_approved_cancel",
            f"管理员批准了取消请求"
        )

        # 通知请求者 + 另一方 (对齐 cs_routes 的通知模式)
        if task:
            try:
                crud.create_notification(
                    db,
                    cancel_request.requester_id,
                    "cancel_request_approved",
                    "取消请求已通过",
                    f'您的任务 "{task.title}" 取消请求已通过审核',
                    task.id,
                )
            except Exception as e:
                logger.warning(f"admin 通知请求者(approved)失败: {e}")
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_approved",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id},
                )
            except Exception as e:
                logger.warning(f"admin push 通知请求者(approved)失败: {e}")

            # 另一方: 用 crud.cancel_task 之前抓到的 original_taker_id
            # (reverted_to_open 路径下 task.taker_id 已被清成 None)
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == original_taker_id
                else original_taker_id
            )
            if other_user_id and other_user_id != cancel_request.requester_id:
                try:
                    crud.create_notification(
                        db,
                        other_user_id,
                        "task_cancelled",
                        "任务已取消",
                        f'任务 "{task.title}" 已被取消',
                        task.id,
                    )
                except Exception as e:
                    logger.warning(f"admin 通知另一方(cancelled)失败: {e}")
                try:
                    send_push_notification(
                        db=db,
                        user_id=other_user_id,
                        notification_type="task_cancelled",
                        data={"task_id": task.id},
                        template_vars={"task_title": task.title, "task_id": task.id},
                    )
                except Exception as e:
                    logger.warning(f"admin push 通知另一方(cancelled)失败: {e}")

        # 清缓存,跟 cs_routes 对齐
        try:
            TaskService.invalidate_cache(cancel_request.task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
        except Exception as e:
            logger.warning(f"清任务缓存失败: {e}")
    else:
        cancel_request.status = "rejected"
        # 通知请求者: 拒绝
        if task:
            try:
                crud.create_notification(
                    db,
                    cancel_request.requester_id,
                    "cancel_request_rejected",
                    "取消请求被拒绝",
                    f'您的任务 "{task.title}" 取消请求被拒绝，原因：{admin_comment or "无"}',
                    task.id,
                )
            except Exception as e:
                logger.warning(f"admin 通知请求者(rejected)失败: {e}")
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_rejected",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id},
                )
            except Exception as e:
                logger.warning(f"admin push 通知请求者(rejected)失败: {e}")

    cancel_request.admin_id = current_user.id
    cancel_request.reviewed_at = get_utc_time()
    cancel_request.admin_comment = admin_comment

    db.commit()

    log_admin_action(
        action=f"cancel_request_{decision}",
        admin_id=current_user.id,
        request=request,
        target_type="cancel_request",
        target_id=str(request_id),
        details={"task_id": cancel_request.task_id, "admin_comment": admin_comment},
    )
    
    return {
        "message": f"Cancel request {decision}d",
        "request_id": request_id,
        "status": cancel_request.status
    }


# ─────────────────────────────────────────────────────────────────────────────
# 卡死任务 payout 恢复端点 (临时/紧急工具)
#
# 用途: 修历史上 confirm_task_completion bug 留下的 zombie 任务
# (status=completed + is_confirmed=0 + escrow>0 + paid_to_user_id=NULL)。
#
# 这是个"紧急工具",随时可以禁用 —— 业务正常运行时不应该有 zombie 任务
# (代码层面已修, 见 commit 947a194e0)。如果几个月没看到列表里有新条目,
# 把环境变量 STUCK_PAYOUT_RECOVERY_ENABLED 设成 false 即可禁用这俩端点。
#
# 风险等级: HIGH (直接动钱包余额)。已加的防护见每个端点的 docstring。
# ─────────────────────────────────────────────────────────────────────────────
import os as _os

def _stuck_payout_recovery_enabled() -> bool:
    """读取 env var,默认 true。设成 false 可一键禁用整个工具。"""
    return _os.getenv("STUCK_PAYOUT_RECOVERY_ENABLED", "true").lower() in ("true", "1", "yes")

# 单笔恢复金额硬上限 (GBP)。超过此值需走人工 SQL/工程师介入,防止
# admin 账号被攻陷一键转走大额资金。
# 现实里 stuck task 的 escrow 一般都是几英镑到几十英镑量级,£200 足够覆盖
# 绝大多数正常场景;超过这个数说明任务金额异常大,值得人工 review 一下
# 再决定怎么补 (可能是数据有问题,也可能是真的大额订单)。
STUCK_PAYOUT_MAX_AMOUNT_GBP = 200


@router.get("/admin/internal/stuck-task-payouts")
def admin_list_stuck_task_payouts(
    limit: int = Query(100, ge=1, le=500),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    列出所有 confirm payout 卡死的任务。匹配条件:
    - status = 'completed'
    - is_confirmed = 0
    - escrow_amount > 0
    - is_paid = 1
    - taker_id IS NOT NULL
    - paid_to_user_id IS NULL  (尚未支付出去)
    - stripe_dispute_frozen != 1  (不展示争议冻结中的任务)

    可通过环境变量 STUCK_PAYOUT_RECOVERY_ENABLED=false 禁用本端点。
    """
    if not _stuck_payout_recovery_enabled():
        raise HTTPException(
            status_code=503,
            detail="卡死任务恢复工具已被禁用 (STUCK_PAYOUT_RECOVERY_ENABLED=false)",
        )
    rows = (
        db.query(models.Task)
        .filter(
            models.Task.status == "completed",
            models.Task.is_confirmed == 0,
            models.Task.escrow_amount > 0,
            models.Task.is_paid == 1,
            models.Task.taker_id.isnot(None),
            models.Task.paid_to_user_id.is_(None),
            models.Task.stripe_dispute_frozen != 1,  # 争议冻结中的任务不展示
        )
        .order_by(models.Task.confirmed_at.desc().nullslast())
        .limit(limit)
        .all()
    )
    return [
        {
            "task_id": t.id,
            "title": t.title,
            "status": t.status,
            "taker_id": t.taker_id,
            "poster_id": t.poster_id,
            "escrow_amount": str(t.escrow_amount or 0),
            "currency": (t.currency or "GBP").upper(),
            "confirmed_at": t.confirmed_at.isoformat() if t.confirmed_at else None,
            "parent_activity_id": t.parent_activity_id,
            "taker_expert_id": t.taker_expert_id,
        }
        for t in rows
    ]


@router.post("/admin/internal/recover-stuck-task-payout/{task_id}")
def admin_recover_stuck_task_payout(
    task_id: int,
    current_user=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """
    人工恢复因 confirm_task_completion 失败 (历史 UnboundLocalError bug 等) 卡在
    zombie 态的任务: status=completed + is_confirmed=0 + escrow>0 + paid_to_user_id NULL。

    auto_transfer_expired_tasks 调度器查询要求 confirmed_at IS NULL, zombie 任务
    confirmed_at 已被设上, 调度器永远拿不到, 必须人工触发恢复。

    行为: 把 escrow 余额通过 credit_wallet 入到 taker 的本地钱包, 清 escrow,
    标 is_confirmed=1, 写 paid_to_user_id。幂等键 earning:task:X:user:Y 与
    confirm_task_completion 路径一致, 重复调安全。

    防护栈:
    - env STUCK_PAYOUT_RECOVERY_ENABLED=false 一键禁用整个端点
    - status / is_confirmed / taker_id / escrow_amount 白名单校验
    - paid_to_user_id IS NULL 校验 (防绕过 list 端点构造 URL 直调)
    - stripe_dispute_frozen != 1 校验 (争议中的任务不能补钱给 taker,
      否则争议 lost 时平台两头亏)
    - 金额硬上限 STUCK_PAYOUT_MAX_AMOUNT_GBP (默认 £5000),超过的要工程师介入
    - 幂等键 + with_for_update 行锁防并发/双付
    - log_admin_action 全程审计
    """
    if not _stuck_payout_recovery_enabled():
        raise HTTPException(
            status_code=503,
            detail="卡死任务恢复工具已被禁用 (STUCK_PAYOUT_RECOVERY_ENABLED=false)",
        )

    from decimal import Decimal
    from app.wallet_service import credit_wallet

    task = (
        db.query(models.Task)
        .filter(models.Task.id == task_id)
        .with_for_update()
        .first()
    )
    if not task:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")

    before = {
        "status": task.status,
        "is_confirmed": int(task.is_confirmed or 0),
        "escrow_amount": str(task.escrow_amount or 0),
        "paid_to_user_id": task.paid_to_user_id,
        "taker_id": task.taker_id,
        "is_paid": int(task.is_paid or 0),
        "stripe_dispute_frozen": int(getattr(task, "stripe_dispute_frozen", 0) or 0),
    }

    if task.is_confirmed == 1:
        raise HTTPException(
            status_code=400,
            detail=f"Task {task_id} is_confirmed=1, 已结算过,不需要恢复",
        )
    if task.status != "completed":
        raise HTTPException(
            status_code=400,
            detail=f"Task {task_id} status={task.status}, 仅支持 completed 态的 zombie 恢复",
        )
    if not task.taker_id:
        raise HTTPException(
            status_code=400,
            detail=f"Task {task_id} 没有 taker_id, 无法恢复",
        )
    if not task.escrow_amount or task.escrow_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail=f"Task {task_id} escrow_amount=0, 没钱可补",
        )
    # 防御深度: list 端点已过滤 paid_to_user_id IS NULL, 这里复查
    # 防止 admin 构造 URL 绕过 list 直调
    if task.paid_to_user_id is not None:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Task {task_id} paid_to_user_id={task.paid_to_user_id} 已被记录支付过, "
                f"拒绝重复恢复"
            ),
        )
    # 争议冻结中的任务不能补钱给 taker. 如果争议 lost, 平台已被 Stripe 划走
    # 一份钱, 这里再补一份给 taker → 平台两头亏。
    if getattr(task, "stripe_dispute_frozen", 0) == 1:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Task {task_id} 正在 Stripe 争议冻结中 (stripe_dispute_frozen=1), "
                f"等争议关闭并确认平台未失血后才能恢复"
            ),
        )

    net = Decimal(str(task.escrow_amount))

    # 金额硬上限: admin 账号被攻陷场景下,防一键转走大额。超过的让工程师
    # 直接看一眼/手工恢复。
    if net > Decimal(STUCK_PAYOUT_MAX_AMOUNT_GBP):
        logger.critical(
            f"🚨 admin {current_user.id} 试图恢复超大金额 task: "
            f"task_id={task_id} amount=£{net} > £{STUCK_PAYOUT_MAX_AMOUNT_GBP} (上限). 拒绝"
        )
        raise HTTPException(
            status_code=400,
            detail=(
                f"Task {task_id} escrow=£{net} 超过单笔恢复上限 "
                f"£{STUCK_PAYOUT_MAX_AMOUNT_GBP}, 需联系工程师手工恢复"
            ),
        )

    gross_raw = task.agreed_reward or task.base_reward or task.reward or net
    gross = Decimal(str(gross_raw))
    fee = gross - net if gross > net else Decimal("0")
    currency = (task.currency or "GBP").upper()
    idempotency_key = f"earning:task:{task.id}:user:{task.taker_id}"

    try:
        credit_wallet(
            db=db,
            user_id=task.taker_id,
            amount=net,
            source="task_earning",
            related_id=str(task.id),
            related_type="task",
            description=f"任务 #{task.id} 奖励 (admin 人工恢复 confirm payout 卡死)",
            fee_amount=fee,
            gross_amount=gross,
            idempotency_key=idempotency_key,
            currency=currency,
        )
    except Exception as e:
        logger.error(
            f"admin_recover_stuck_task_payout: credit_wallet 失败 "
            f"task_id={task_id} taker={task.taker_id} amount={net}: {e}",
            exc_info=True,
        )
        raise HTTPException(status_code=500, detail=f"credit_wallet failed: {e}")

    task.escrow_amount = Decimal("0.00")
    task.paid_to_user_id = task.taker_id
    task.is_confirmed = 1
    try:
        crud.add_task_history(
            db, task.id, None, "admin_recovered_stuck_payout",
            f"管理员恢复卡死的 payout, 通过 wallet 补 £{net} 给 {task.taker_id}",
        )
    except Exception as e:
        logger.warning(f"add_task_history 失败 (不阻塞): {e}")

    db.commit()
    db.refresh(task)

    after = {
        "status": task.status,
        "is_confirmed": int(task.is_confirmed or 0),
        "escrow_amount": str(task.escrow_amount or 0),
        "paid_to_user_id": task.paid_to_user_id,
    }

    log_admin_action(
        action="recover_stuck_task_payout",
        admin_id=current_user.id,
        request=request,
        target_type="task",
        target_id=str(task_id),
        details={
            "amount": str(net),
            "currency": currency,
            "taker_id": task.taker_id,
            "before": before,
            "after": after,
        },
    )

    return {
        "message": f"Recovered task {task_id}: credited £{net} to taker {task.taker_id}",
        "task_id": task_id,
        "amount": str(net),
        "currency": currency,
        "taker_id": task.taker_id,
        "before": before,
        "after": after,
    }

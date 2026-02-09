"""
管理员 - 任务管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Body
from sqlalchemy.orm import Session
from sqlalchemy import or_, func

from app import crud, models, schemas
from app.audit_logger import log_admin_action
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.services.task_service import TaskService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-任务管理"])


@router.get("/admin/tasks")
def admin_get_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status: str = None,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务列表（支持分页和筛选）"""
    from app.models import Task

    # 构建查询
    query = db.query(Task)

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

    # 添加关键词搜索（使用 pg_trgm 优化）
    if keyword and keyword.strip():
        keyword_clean = keyword.strip()
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                func.similarity(Task.task_type, keyword_clean) > 0.2,
                func.similarity(Task.location, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),
                Task.description.ilike(f"%{keyword_clean}%")
            )
        )

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
    return crud.get_all_cancel_requests(db)


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
    
    if decision == "approve":
        cancel_request.status = "approved"
        # 取消对应的任务
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            task.status = "cancelled"
            crud.add_task_history(db, task.id, None, "admin_approved_cancel", 
                                  f"管理员批准了取消请求")
    else:
        cancel_request.status = "rejected"
    
    cancel_request.reviewed_by = current_user.id
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

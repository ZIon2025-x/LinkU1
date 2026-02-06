"""
管理员 - 任务争议管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-任务争议管理"])


@router.get("/admin/task-disputes", response_model=dict)
def get_admin_task_disputes(
    skip: int = 0,
    limit: int = 20,
    status: Optional[str] = None,
    keyword: Optional[str] = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务争议列表"""
    query = db.query(models.TaskDispute)
    
    # 状态筛选
    if status:
        query = query.filter(models.TaskDispute.status == status)
    
    # 关键词搜索（任务标题、发布者姓名、争议原因）
    has_keyword_search = keyword and keyword.strip()
    if has_keyword_search:
        keyword = keyword.strip()
        # 使用JOIN查询任务和用户信息
        query = query.join(models.Task, models.TaskDispute.task_id == models.Task.id).join(
            models.User, models.TaskDispute.poster_id == models.User.id
        ).filter(
            or_(
                models.Task.title.ilike(f'%{keyword}%'),
                models.User.name.ilike(f'%{keyword}%'),
                models.TaskDispute.reason.ilike(f'%{keyword}%')
            )
        )
    
    # 按创建时间倒序
    query = query.order_by(models.TaskDispute.created_at.desc())
    
    # 总数（如果有关键词搜索，需要去重计数）
    if has_keyword_search:
        total = query.distinct().count()
    else:
        total = query.count()
    
    # 分页 - 使用JOIN优化查询，避免N+1问题
    # 如果有关键词搜索，已经JOIN了Task和User，需要去重
    if has_keyword_search:
        disputes = (
            query
            .options(
                joinedload(models.TaskDispute.task),
                joinedload(models.TaskDispute.poster),
                joinedload(models.TaskDispute.resolver)
            )
            .distinct()
            .offset(skip)
            .limit(limit)
            .all()
        )
    else:
        disputes = (
            query
            .options(
                joinedload(models.TaskDispute.task),  # 预加载任务信息
                joinedload(models.TaskDispute.poster),  # 预加载发布者信息
                joinedload(models.TaskDispute.resolver)  # 预加载处理人信息
            )
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    # 构建返回数据（关联数据已预加载，无需额外查询）
    disputes_with_task = []
    for dispute in disputes:
        task = dispute.task  # 已预加载
        poster = dispute.poster  # 已预加载
        resolver = dispute.resolver  # 已预加载
        
        dispute_dict = {
            "id": dispute.id,
            "task_id": dispute.task_id,
            "task_title": task.title if task else "任务已删除",
            "poster_id": dispute.poster_id,
            "poster_name": poster.name if poster else f"用户{dispute.poster_id}",
            "reason": dispute.reason,
            "status": dispute.status,
            "created_at": dispute.created_at,
            "resolved_at": dispute.resolved_at,
            "resolved_by": dispute.resolved_by,
            "resolver_name": resolver.name if resolver else None,
            "resolution_note": dispute.resolution_note,
        }
        disputes_with_task.append(dispute_dict)
    
    return {
        "disputes": disputes_with_task,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/admin/task-disputes/{dispute_id}")
def get_admin_task_dispute_detail(
    dispute_id: int,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取任务争议详情（包含关联信息）"""
    dispute = db.query(models.TaskDispute).filter(models.TaskDispute.id == dispute_id).first()
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    # 获取关联的任务信息
    task = crud.get_task(db, dispute.task_id)
    poster = crud.get_user_by_id(db, dispute.poster_id)
    taker = crud.get_user_by_id(db, task.taker_id) if task and task.taker_id else None
    resolver = crud.get_user_by_id(db, dispute.resolved_by) if dispute.resolved_by else None
    
    # 计算任务金额（优先使用agreed_reward，否则使用base_reward）
    task_amount = None
    if task:
        if task.agreed_reward is not None:
            task_amount = float(task.agreed_reward)
        elif task.base_reward is not None:
            task_amount = float(task.base_reward)
        else:
            task_amount = float(task.reward) if task.reward else 0.0
    
    return {
        "id": dispute.id,
        "task_id": dispute.task_id,
        "task_title": task.title if task else "任务已删除",
        "task_status": task.status if task else None,
        "task_description": task.description if task else None,
        "task_created_at": task.created_at if task else None,
        "task_accepted_at": task.accepted_at if task else None,
        "task_completed_at": task.completed_at if task else None,
        "poster_id": dispute.poster_id,
        "poster_name": poster.name if poster else f"用户{dispute.poster_id}",
        "taker_id": task.taker_id if task else None,
        "taker_name": taker.name if taker else (f"用户{task.taker_id}" if task and task.taker_id else None),
        "task_amount": task_amount,
        "base_reward": float(task.base_reward) if task and task.base_reward else None,
        "agreed_reward": float(task.agreed_reward) if task and task.agreed_reward else None,
        "currency": task.currency if task else "GBP",
        "reason": dispute.reason,
        "status": dispute.status,
        "created_at": dispute.created_at,
        "resolved_at": dispute.resolved_at,
        "resolved_by": dispute.resolved_by,
        "resolver_name": resolver.name if resolver else None,
        "resolution_note": dispute.resolution_note,
    }


@router.post("/admin/task-disputes/{dispute_id}/resolve", response_model=schemas.TaskDisputeOut)
def resolve_task_dispute(
    dispute_id: int,
    resolution: schemas.TaskDisputeResolve,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员处理任务争议"""
    dispute = db.query(models.TaskDispute).filter(models.TaskDispute.id == dispute_id).first()
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    if dispute.status != "pending":
        raise HTTPException(status_code=400, detail="Dispute is already resolved")
    
    # 更新争议状态
    dispute.status = "resolved"
    dispute.resolved_at = get_utc_time()
    dispute.resolved_by = current_user.id
    dispute.resolution_note = resolution.resolution_note
    
    # 根据裁决结果处理任务
    task = crud.get_task(db, dispute.task_id)
    if task:
        if resolution.resolution_type == "refund_poster":
            # 全额退款给发布者
            task.status = "cancelled"
            # TODO: 执行退款逻辑
        elif resolution.resolution_type == "partial_refund":
            # 部分退款
            task.status = "completed"
            # TODO: 执行部分退款逻辑
        elif resolution.resolution_type == "pay_taker":
            # 支付给接单者
            task.status = "completed"
            # TODO: 执行支付逻辑
        elif resolution.resolution_type == "dismiss":
            # 驳回争议，恢复任务状态
            task.status = "pending_confirmation"
    
    db.commit()
    db.refresh(dispute)
    
    return dispute


@router.post("/admin/task-disputes/{dispute_id}/dismiss", response_model=schemas.TaskDisputeOut)
def dismiss_task_dispute(
    dispute_id: int,
    dismissal: schemas.TaskDisputeDismiss,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员驳回任务争议"""
    dispute = db.query(models.TaskDispute).filter(models.TaskDispute.id == dispute_id).first()
    if not dispute:
        raise HTTPException(status_code=404, detail="Dispute not found")
    
    if dispute.status != "pending":
        raise HTTPException(status_code=400, detail="Dispute is already resolved")
    
    # 更新争议状态
    dispute.status = "dismissed"
    dispute.resolved_at = get_utc_time()
    dispute.resolved_by = current_user.id
    dispute.resolution_note = dismissal.reason
    
    # 恢复任务状态
    task = crud.get_task(db, dispute.task_id)
    if task and task.status == "disputed":
        task.status = "pending_confirmation"
    
    db.commit()
    db.refresh(dispute)
    
    return dispute

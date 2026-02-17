"""任务取消请求及用户删除已取消任务相关 CRUD，独立模块便于维护与测试。"""
from sqlalchemy.orm import Session

from app import models
from app.crud.notification import create_notification
from app.crud.task import add_task_history, delete_task_safely
from app.utils.time_utils import get_utc_time


def delete_user_task(db: Session, task_id: int, user_id: str):
    """用户删除自己的已取消任务。仅发布者可删，且任务须为 cancelled。"""
    from app.models import Task

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task or task.poster_id != user_id or task.status != "cancelled":
        return None

    try:
        add_task_history(
            db,
            task.id,
            task.poster_id,
            "deleted",
            f"任务发布者手动删除（状态：{task.status}）",
        )
        create_notification(
            db,
            task.poster_id,
            "task_deleted",
            "任务已删除",
            f'您的{task.status}任务"{task.title}"已被删除',
            related_id=str(task.id),
        )
        if delete_task_safely(db, task.id):
            return {"message": "Task deleted successfully"}
        return None
    except Exception as e:
        db.rollback()
        raise


def create_task_cancel_request(
    db: Session, task_id: int, requester_id: str, reason: str = None
):
    from app.models import TaskCancelRequest

    cancel_request = TaskCancelRequest(
        task_id=task_id, requester_id=requester_id, reason=reason
    )
    db.add(cancel_request)
    db.commit()
    db.refresh(cancel_request)
    return cancel_request


def get_task_cancel_requests(db: Session, status: str = None):
    query = db.query(models.TaskCancelRequest)
    if status:
        query = query.filter(models.TaskCancelRequest.status == status)
    return query.order_by(models.TaskCancelRequest.created_at.desc()).all()


def get_task_cancel_request_by_id(db: Session, request_id: int):
    return (
        db.query(models.TaskCancelRequest)
        .filter(models.TaskCancelRequest.id == request_id)
        .first()
    )


def update_task_cancel_request(
    db: Session,
    request_id: int,
    status: str,
    reviewer_id: str,
    admin_comment: str = None,
    reviewer_type: str = None,
):
    """更新任务取消请求状态。reviewer_type 为 'admin' 或 'service'，None 时按 reviewer_id 前缀推断。"""
    request = (
        db.query(models.TaskCancelRequest)
        .filter(models.TaskCancelRequest.id == request_id)
        .first()
    )
    if not request:
        return request
    request.status = status
    request.admin_comment = admin_comment
    request.reviewed_at = get_utc_time()

    if reviewer_type is None:
        if reviewer_id.startswith("A"):
            reviewer_type = "admin"
        elif reviewer_id.startswith("CS"):
            reviewer_type = "service"
        else:
            reviewer_type = "admin"

    if reviewer_type == "admin":
        request.service_id = None
        request.admin_id = reviewer_id
    elif reviewer_type == "service":
        request.admin_id = None
        request.service_id = reviewer_id

    db.flush()
    db.commit()
    db.refresh(request)
    return request

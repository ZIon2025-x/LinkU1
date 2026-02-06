"""
管理员 - 系统设置和清理路由
从 routers.py 迁移
"""
import logging
import os
import shutil
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Body
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import crud, models, schemas
from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.security import get_client_ip
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-系统设置"])


@router.get("/admin/system-settings")
def admin_get_system_settings(
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取系统设置"""
    settings = db.query(models.SystemSetting).all()
    
    return {
        "settings": [
            {
                "key": s.key,
                "value": s.value,
                "description": s.description,
                "updated_at": format_iso_utc(s.updated_at) if s.updated_at else None,
            }
            for s in settings
        ]
    }


@router.put("/admin/system-settings/{key}")
def admin_update_system_setting(
    key: str,
    value: str = Body(...),
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """更新系统设置"""
    setting = db.query(models.SystemSetting).filter(
        models.SystemSetting.key == key
    ).first()
    
    if not setting:
        # 创建新设置
        setting = models.SystemSetting(
            key=key,
            value=value,
            created_at=get_utc_time(),
            updated_at=get_utc_time(),
        )
        db.add(setting)
        old_value = None
    else:
        old_value = setting.value
        setting.value = value
        setting.updated_at = get_utc_time()
    
    db.commit()
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="update_system_setting",
        entity_type="system_setting",
        entity_id=key,
        admin_id=current_admin.id,
        user_id=None,
        old_value={"value": old_value},
        new_value={"value": value},
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 更新了系统设置",
        ip_address=ip_address,
    )
    
    return {"message": f"Setting '{key}' updated successfully"}


@router.get("/admin/job-positions")
def admin_get_job_positions(
    page: int = 1,
    size: int = 50,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取职位列表"""
    skip = (page - 1) * size
    
    query = db.query(models.JobPosition)
    total = query.count()
    positions = query.order_by(models.JobPosition.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "positions": positions,
        "total": total,
        "page": page,
        "size": size,
    }


@router.post("/admin/job-positions")
def admin_create_job_position(
    position: schemas.JobPositionCreate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """创建职位"""
    new_position = models.JobPosition(
        **position.dict(),
        created_at=get_utc_time(),
    )
    db.add(new_position)
    db.commit()
    db.refresh(new_position)
    
    return {"message": "Job position created successfully", "position": new_position}


@router.put("/admin/job-positions/{position_id}")
def admin_update_job_position(
    position_id: int,
    position_update: schemas.JobPositionUpdate,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新职位"""
    position = db.query(models.JobPosition).filter(
        models.JobPosition.id == position_id
    ).first()
    
    if not position:
        raise HTTPException(status_code=404, detail="Job position not found")
    
    update_data = position_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(position, key, value)
    
    position.updated_at = get_utc_time()
    db.commit()
    
    return {"message": "Job position updated successfully", "position": position}


@router.delete("/admin/job-positions/{position_id}")
def admin_delete_job_position(
    position_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除职位"""
    position = db.query(models.JobPosition).filter(
        models.JobPosition.id == position_id
    ).first()
    
    if not position:
        raise HTTPException(status_code=404, detail="Job position not found")
    
    db.delete(position)
    db.commit()
    
    return {"message": "Job position deleted successfully"}


@router.post("/admin/cleanup/expired-tasks")
def admin_cleanup_expired_tasks(
    days: int = Body(30, description="清理多少天前过期的任务"),
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """清理过期任务"""
    from datetime import timedelta
    
    cutoff_date = get_utc_time() - timedelta(days=days)
    
    # 查找过期的已取消或已完成任务
    expired_tasks = db.query(models.Task).filter(
        models.Task.status.in_(["cancelled", "completed", "expired"]),
        models.Task.updated_at < cutoff_date
    ).all()
    
    count = len(expired_tasks)
    task_ids = [t.id for t in expired_tasks]
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="cleanup_expired_tasks",
        entity_type="task",
        entity_id="batch",
        admin_id=current_admin.id,
        user_id=None,
        old_value={"task_ids": task_ids},
        new_value={"deleted_count": count},
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 清理了 {days} 天前的过期任务",
        ip_address=ip_address,
    )
    
    # 可以选择软删除或硬删除
    # 这里示例为标记删除
    for task in expired_tasks:
        task.is_deleted = True
    
    db.commit()
    
    return {
        "message": f"Cleaned up {count} expired tasks",
        "deleted_count": count,
        "cutoff_date": format_iso_utc(cutoff_date)
    }


@router.post("/admin/cleanup/task-files/{task_id}")
def admin_cleanup_task_files(
    task_id: int,
    current_admin=Depends(get_current_admin),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """清理任务相关文件"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 获取任务文件目录
    upload_dir = os.getenv("UPLOAD_DIR", "uploads")
    task_files_dir = os.path.join(upload_dir, "tasks", str(task_id))
    
    deleted_files = []
    if os.path.exists(task_files_dir):
        try:
            for filename in os.listdir(task_files_dir):
                file_path = os.path.join(task_files_dir, filename)
                if os.path.isfile(file_path):
                    os.remove(file_path)
                    deleted_files.append(filename)
            # 删除目录
            shutil.rmtree(task_files_dir, ignore_errors=True)
        except Exception as e:
            logger.error(f"Error cleaning up task files: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to clean up files: {str(e)}")
    
    # 记录审计日志
    ip_address = get_client_ip(request) if request else None
    crud.create_audit_log(
        db=db,
        action_type="cleanup_task_files",
        entity_type="task",
        entity_id=str(task_id),
        admin_id=current_admin.id,
        user_id=task.poster_id,
        old_value={"files": deleted_files},
        new_value={"deleted_count": len(deleted_files)},
        reason=f"管理员 {current_admin.id} ({current_admin.name}) 清理了任务 {task_id} 的文件",
        ip_address=ip_address,
    )
    
    return {
        "message": f"Cleaned up {len(deleted_files)} files for task {task_id}",
        "deleted_files": deleted_files
    }


@router.get("/admin/audit-logs")
def admin_get_audit_logs(
    page: int = 1,
    size: int = 50,
    action_type: str = None,
    entity_type: str = None,
    admin_id: str = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取审计日志"""
    skip = (page - 1) * size
    
    query = db.query(models.AuditLog)
    
    if action_type:
        query = query.filter(models.AuditLog.action_type == action_type)
    
    if entity_type:
        query = query.filter(models.AuditLog.entity_type == entity_type)
    
    if admin_id:
        query = query.filter(models.AuditLog.admin_id == admin_id)
    
    total = query.count()
    logs = query.order_by(models.AuditLog.created_at.desc()).offset(skip).limit(size).all()
    
    return {
        "logs": [
            {
                "id": log.id,
                "action_type": log.action_type,
                "entity_type": log.entity_type,
                "entity_id": log.entity_id,
                "admin_id": log.admin_id,
                "user_id": log.user_id,
                "old_value": log.old_value,
                "new_value": log.new_value,
                "reason": log.reason,
                "ip_address": log.ip_address,
                "created_at": format_iso_utc(log.created_at) if log.created_at else None,
            }
            for log in logs
        ],
        "total": total,
        "page": page,
        "size": size,
    }

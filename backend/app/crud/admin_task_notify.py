"""管理后台任务操作 + 通知 + 仪表盘统计相关 CRUD。"""

import json
import logging
from typing import Dict, Tuple

from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.utils.translation_validator import invalidate_task_translations
from app.utils.task_translation_cache import invalidate_task_translation_cache

logger = logging.getLogger(__name__)


def send_admin_notification(
    db: Session,
    user_ids: list,
    title: str,
    content: str,
    notification_type: str = "admin_notification",
):
    """管理员发送站内通知（支持全量广播，排除客服账号）。"""
    notifications = []

    if not user_ids:  # 发送给所有用户
        from app.id_generator import is_customer_service_id

        user_ids = []
        page_size = 500
        offset = 0
        while True:
            batch = db.query(models.User.id).limit(page_size).offset(offset).all()
            if not batch:
                break
            for (uid,) in batch:
                if not is_customer_service_id(uid):
                    user_ids.append(uid)
            offset += page_size

    for user_id in user_ids:
        notification = models.Notification(
            user_id=user_id,
            type=notification_type,
            title=title,
            content=content,
            title_en=None,
            content_en=None,
        )
        db.add(notification)
        notifications.append(notification)

    db.commit()
    return notifications


def get_dashboard_stats(db: Session) -> Dict[str, float]:
    """获取管理后台统计数据（用户数、任务数、客服会话等）。"""
    total_users = db.query(models.User).count()
    total_tasks = db.query(models.Task).count()
    total_customer_service = db.query(models.CustomerService).count()
    active_sessions = (
        db.query(models.CustomerServiceChat)
        .filter(models.CustomerServiceChat.is_ended == 0)
        .count()
    )

    total_revenue = (
        db.query(func.sum(models.Task.base_reward))
        .filter(models.Task.status == "completed")
        .scalar()
        or 0.0
    )

    avg_rating = db.query(func.avg(models.CustomerService.avg_rating)).scalar() or 0.0

    return {
        "total_users": total_users,
        "total_tasks": total_tasks,
        "total_customer_service": total_customer_service,
        "active_sessions": active_sessions,
        "total_revenue": float(total_revenue),
        "avg_rating": float(avg_rating),
    }


def update_task_by_admin(
    db: Session, task_id: int, task_update: dict
) -> Tuple[models.Task, Dict, Dict]:
    """管理员更新任务信息，屏蔽敏感字段，必要时清理翻译缓存。"""
    # 敏感字段黑名单（不允许通过 API 直接修改，只能通过 webhook 或系统逻辑更新）
    SENSITIVE_FIELDS = {
        "is_paid",  # 任务是否已支付（只能通过 webhook 更新）
        "escrow_amount",  # 托管金额（只能通过 webhook 或系统逻辑更新）
        "payment_intent_id",  # Stripe Payment Intent ID（只能通过 webhook 更新）
        "is_confirmed",  # 任务是否已确认完成（只能通过系统逻辑更新）
        "paid_to_user_id",  # 已支付给的用户ID（只能通过转账逻辑更新）
        "taker_id",  # 任务接受人（只能通过申请批准流程设置）
        "agreed_reward",  # 最终成交价（只能通过议价流程设置）
    }

    # 过滤掉敏感字段
    filtered_update = {k: v for k, v in task_update.items() if k not in SENSITIVE_FIELDS}

    # 如果尝试修改敏感字段，记录警告
    attempted_sensitive_fields = set(task_update.keys()) & SENSITIVE_FIELDS
    if attempted_sensitive_fields:
        logger.warning(
            "⚠️ 管理员尝试修改任务的敏感字段（已阻止）: "
            f"task_id={task_id}, fields={attempted_sensitive_fields}"
        )

    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if task:
        old_values: Dict = {}
        new_values: Dict = {}
        content_fields_updated = []

        for field, value in filtered_update.items():
            if value is not None and hasattr(task, field):
                old_value = getattr(task, field)
                # 特殊处理 images 字段：如果是列表，需要序列化为 JSON 字符串
                if field == "images" and isinstance(value, list):
                    new_value = json.dumps(value) if value else None
                else:
                    new_value = value

                if old_value != new_value:
                    if field == "images" and isinstance(old_value, str):
                        try:
                            old_values[field] = (
                                json.loads(old_value) if old_value else None
                            )
                        except Exception:
                            old_values[field] = old_value
                    else:
                        old_values[field] = old_value

                    if field == "images" and isinstance(new_value, str):
                        try:
                            new_values[field] = (
                                json.loads(new_value) if new_value else None
                            )
                        except Exception:
                            new_values[field] = new_value
                    else:
                        new_values[field] = new_value

                    # 设置新值
                    if field == "images" and isinstance(value, list):
                        setattr(task, field, json.dumps(value) if value else None)
                    else:
                        setattr(task, field, value)

                    # 如果更新了title或description，标记需要清理翻译
                    if field in ["title", "description"]:
                        content_fields_updated.append(field)

        db.commit()
        db.refresh(task)

        # 如果更新了内容字段，清理相关翻译 & 缓存
        if content_fields_updated:
            for field_type in content_fields_updated:
                invalidate_task_translations(db, task_id, field_type)
                invalidate_task_translation_cache(task_id, field_type)
            logger.info(
                "已清理任务 %s 的过期翻译（字段: %s）",
                task_id,
                ", ".join(content_fields_updated),
            )

        if old_values:
            return task, old_values, new_values
    return task, None, None


def delete_task_by_admin(db: Session, task_id: int):
    """管理员删除任务（使用安全删除方法，确保删除所有相关数据）。"""
    from app.crud.task import delete_task_safely

    return delete_task_safely(db, task_id)


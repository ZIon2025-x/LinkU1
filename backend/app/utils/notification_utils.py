"""
通知工具函数
用于处理通知相关的通用逻辑，如提取 task_id
"""
import logging
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app import models
from app import schemas
from app.utils.notification_variables import extract_notification_variables

logger = logging.getLogger(__name__)


def enrich_notification_dict_with_task_id_sync(
    notification: models.Notification,
    notification_dict: Dict[str, Any],
    db: Session
) -> Dict[str, Any]:
    """
    同步方式：为通知字典添加 task_id 字段
    
    Args:
        notification: 通知模型对象
        notification_dict: 通知字典（已转换为 NotificationOut 格式）
        db: 数据库会话（同步）
    
    Returns:
        更新后的通知字典
    """
    # 提取动态变量
    notification_dict["variables"] = extract_notification_variables(
        notification.type or "unknown",
        notification.content,
        notification.content_en
    )
    
    # 使用 related_type 字段来判断 related_id 的类型（新数据）
    if notification.related_type == "task_id" and notification.related_id:
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    if notification.related_type == "application_id" and notification.related_id:
        # related_id 是 application_id，需要通过 TaskApplication 表查询 task_id
        try:
            application = db.query(models.TaskApplication).filter(
                models.TaskApplication.id == notification.related_id
            ).first()
            
            if application:
                notification_dict["task_id"] = application.task_id
            else:
                logger.warning(
                    f"Application not found for notification {notification.id}, "
                    f"related_id: {notification.related_id}"
                )
        except Exception as e:
            logger.warning(f"Failed to get task_id for notification {notification.id}: {e}")
        return notification_dict
    
    # 旧数据兼容：如果没有 related_type，根据通知类型推断（向后兼容）
    if notification.related_type is None:
        # task_application 类型：related_id 直接就是 task_id
        if notification.type == "task_application" and notification.related_id:
            notification_dict["task_id"] = notification.related_id
            return notification_dict
        
        # application_message, negotiation_offer, application_rejected, application_withdrawn, negotiation_rejected 类型：related_id 是 application_id
        if notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
            try:
                application = db.query(models.TaskApplication).filter(
                    models.TaskApplication.id == notification.related_id
                ).first()
                
                if application:
                    notification_dict["task_id"] = application.task_id
                else:
                    logger.warning(
                        f"Application not found for notification {notification.id}, "
                        f"related_id: {notification.related_id}"
                    )
            except Exception as e:
                logger.warning(f"Failed to get task_id for notification {notification.id}: {e}")
            return notification_dict
        
        # application_accepted 类型：旧数据可能是 task_id 或 application_id，验证是否是有效的 task_id
        if notification.type == "application_accepted" and notification.related_id:
            related_id = int(notification.related_id) if notification.related_id else None
            if related_id:
                # 验证是否是有效的 task_id
                task = db.query(models.Task).filter(models.Task.id == related_id).first()
                if task:
                    notification_dict["task_id"] = related_id
                # 如果不是有效的 task_id，不设置 task_id（可能是旧数据中的 application_id，避免误判）
            return notification_dict
    
    # task_approved, task_completed, task_confirmed, task_cancelled 等类型：related_id 就是 task_id
    task_status_types = ["task_approved", "task_completed", "task_confirmed", "task_cancelled", "task_reward_paid"]
    if notification.type in task_status_types and notification.related_id:
        # 确保 task_id 是整数类型（related_id 在数据库中已经是 Integer，但确保类型正确）
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    # 达人服务/活动相关：service_application_approved、payment_reminder 的 related_id 就是 task_id
    expert_task_types = ["service_application_approved", "payment_reminder"]
    if notification.type in expert_task_types and notification.related_id:
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    return notification_dict


async def enrich_notification_dict_with_task_id_async(
    notification: models.Notification,
    notification_dict: Dict[str, Any],
    db: AsyncSession
) -> Dict[str, Any]:
    """
    异步方式：为通知字典添加 task_id 字段
    
    Args:
        notification: 通知模型对象
        notification_dict: 通知字典（已转换为 NotificationOut 格式）
        db: 数据库会话（异步）
    
    Returns:
        更新后的通知字典
    """
    # 提取动态变量
    notification_dict["variables"] = extract_notification_variables(
        notification.type or "unknown",
        notification.content,
        notification.content_en
    )
    
    # 使用 related_type 字段来判断 related_id 的类型（新数据）
    if notification.related_type == "task_id" and notification.related_id:
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    if notification.related_type == "application_id" and notification.related_id:
        # related_id 是 application_id，需要通过 TaskApplication 表查询 task_id
        try:
            application_query = select(models.TaskApplication).where(
                models.TaskApplication.id == notification.related_id
            )
            application_result = await db.execute(application_query)
            application = application_result.scalar_one_or_none()
            
            if application:
                notification_dict["task_id"] = application.task_id
            else:
                logger.warning(
                    f"Application not found for notification {notification.id}, "
                    f"related_id: {notification.related_id}"
                )
        except Exception as e:
            logger.warning(f"Failed to get task_id for notification {notification.id}: {e}")
        return notification_dict
    
    # 旧数据兼容：如果没有 related_type，根据通知类型推断（向后兼容）
    if notification.related_type is None:
        # task_application 类型：related_id 直接就是 task_id
        if notification.type == "task_application" and notification.related_id:
            notification_dict["task_id"] = notification.related_id
            return notification_dict
        
        # application_message, negotiation_offer, application_rejected, application_withdrawn, negotiation_rejected 类型：related_id 是 application_id
        if notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
            try:
                application_query = select(models.TaskApplication).where(
                    models.TaskApplication.id == notification.related_id
                )
                application_result = await db.execute(application_query)
                application = application_result.scalar_one_or_none()
                
                if application:
                    notification_dict["task_id"] = application.task_id
                else:
                    logger.warning(
                        f"Application not found for notification {notification.id}, "
                        f"related_id: {notification.related_id}"
                    )
            except Exception as e:
                logger.warning(f"Failed to get task_id for notification {notification.id}: {e}")
            return notification_dict
        
        # application_accepted 类型：旧数据可能是 task_id 或 application_id，验证是否是有效的 task_id
        if notification.type == "application_accepted" and notification.related_id:
            related_id = int(notification.related_id) if notification.related_id else None
            if related_id:
                # 验证是否是有效的 task_id
                task_query = select(models.Task).where(models.Task.id == related_id)
                task_result = await db.execute(task_query)
                task = task_result.scalar_one_or_none()
                if task:
                    notification_dict["task_id"] = related_id
                # 如果不是有效的 task_id，不设置 task_id（可能是旧数据中的 application_id，避免误判）
            return notification_dict
    
    # task_approved, task_completed, task_confirmed, task_cancelled 等类型：related_id 就是 task_id
    task_status_types = ["task_approved", "task_completed", "task_confirmed", "task_cancelled", "task_reward_paid"]
    if notification.type in task_status_types and notification.related_id:
        # 确保 task_id 是整数类型（related_id 在数据库中已经是 Integer，但确保类型正确）
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    # 达人服务/活动相关：service_application_approved、payment_reminder 的 related_id 就是 task_id
    expert_task_types = ["service_application_approved", "payment_reminder"]
    if notification.type in expert_task_types and notification.related_id:
        notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        return notification_dict
    
    return notification_dict


def enrich_notifications_with_task_id_sync(
    notifications: list[models.Notification],
    db: Session
) -> list[schemas.NotificationOut]:
    """
    同步方式：批量为通知列表添加 task_id 字段
    
    优化：批量查询 application_id 对应的 task_id，减少数据库查询次数
    
    Args:
        notifications: 通知列表
        db: 数据库会话（同步）
    
    Returns:
        包含 task_id 的通知列表
    """
    # 收集所有需要查询的 application_id
    # 优先使用 related_type 字段（新数据），如果没有则根据通知类型推断（旧数据兼容）
    application_ids = []
    notification_indices = {}  # application_id -> [notification_index, ...]
    
    for idx, notification in enumerate(notifications):
        # 新数据：使用 related_type 字段
        if notification.related_type == "application_id" and notification.related_id:
            application_id = notification.related_id
            application_ids.append(application_id)
            if application_id not in notification_indices:
                notification_indices[application_id] = []
            notification_indices[application_id].append(idx)
        # 旧数据兼容：根据通知类型推断
        elif notification.related_type is None and notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
            application_id = notification.related_id
            application_ids.append(application_id)
            if application_id not in notification_indices:
                notification_indices[application_id] = []
            notification_indices[application_id].append(idx)
    
    # 批量查询所有需要的 application -> task_id 映射
    application_task_map = {}
    if application_ids:
        try:
            applications = db.query(
                models.TaskApplication.id,
                models.TaskApplication.task_id
            ).filter(
                models.TaskApplication.id.in_(application_ids)
            ).all()
            
            for app_id, task_id in applications:
                application_task_map[app_id] = task_id
        except Exception as e:
            logger.warning(f"Failed to batch query task_ids for applications: {e}")
    
    # 处理所有通知
    result = []
    for idx, notification in enumerate(notifications):
        notification_dict = schemas.NotificationOut.model_validate(notification).model_dump()
        
        # 新数据：使用 related_type 字段判断
        if notification.related_type == "task_id" and notification.related_id:
            notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        
        elif notification.related_type == "application_id" and notification.related_id:
            # related_id 是 application_id，使用批量查询的结果
            task_id = application_task_map.get(notification.related_id)
            if task_id:
                notification_dict["task_id"] = task_id
            elif notification.related_id in application_ids:
                # 查询失败或不存在，记录警告
                logger.warning(
                    f"Application not found for notification {notification.id}, "
                    f"related_id: {notification.related_id}"
                )
        
        # 旧数据兼容：如果没有 related_type，根据通知类型推断
        elif notification.related_type is None:
            # task_application 类型：related_id 直接就是 task_id
            if notification.type == "task_application" and notification.related_id:
                notification_dict["task_id"] = notification.related_id
            
            # application_message, negotiation_offer, application_rejected, application_withdrawn, negotiation_rejected 类型：使用批量查询的结果
            elif notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
                task_id = application_task_map.get(notification.related_id)
                if task_id:
                    notification_dict["task_id"] = task_id
                elif notification.related_id in application_ids:
                    # 查询失败或不存在，记录警告
                    logger.warning(
                        f"Application not found for notification {notification.id}, "
                        f"related_id: {notification.related_id}"
                    )
            
            # application_accepted 类型：旧数据可能是 task_id 或 application_id，验证是否是有效的 task_id
            elif notification.type == "application_accepted" and notification.related_id:
                related_id = int(notification.related_id) if notification.related_id else None
                if related_id:
                    # 验证是否是有效的 task_id
                    task = db.query(models.Task).filter(models.Task.id == related_id).first()
                    if task:
                        notification_dict["task_id"] = related_id
                    # 如果不是有效的 task_id，不设置 task_id（可能是旧数据中的 application_id，避免误判）
            
            # task_approved, task_completed, task_confirmed, task_cancelled 等类型：related_id 就是 task_id
            # 达人服务/活动：service_application_approved、payment_reminder 的 related_id 就是 task_id
            else:
                task_status_types = ["task_approved", "task_completed", "task_confirmed", "task_cancelled", "task_reward_paid"]
                expert_task_types = ["service_application_approved", "payment_reminder"]
                if notification.type in task_status_types and notification.related_id:
                    notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
                elif notification.type in expert_task_types and notification.related_id:
                    notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        
        result.append(schemas.NotificationOut(**notification_dict))
    
    return result


async def enrich_notifications_with_task_id_async(
    notifications: list[models.Notification],
    db: AsyncSession
) -> list[schemas.NotificationOut]:
    """
    异步方式：批量为通知列表添加 task_id 字段
    
    优化：批量查询 application_id 对应的 task_id，减少数据库查询次数
    
    Args:
        notifications: 通知列表
        db: 数据库会话（异步）
    
    Returns:
        包含 task_id 的通知列表
    """
    # 收集所有需要查询的 application_id
    # 优先使用 related_type 字段（新数据），如果没有则根据通知类型推断（旧数据兼容）
    application_ids = []
    notification_indices = {}  # application_id -> [notification_index, ...]
    
    for idx, notification in enumerate(notifications):
        # 新数据：使用 related_type 字段
        if notification.related_type == "application_id" and notification.related_id:
            application_id = notification.related_id
            application_ids.append(application_id)
            if application_id not in notification_indices:
                notification_indices[application_id] = []
            notification_indices[application_id].append(idx)
        # 旧数据兼容：根据通知类型推断
        elif notification.related_type is None and notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
            application_id = notification.related_id
            application_ids.append(application_id)
            if application_id not in notification_indices:
                notification_indices[application_id] = []
            notification_indices[application_id].append(idx)
    
    # 批量查询所有需要的 application -> task_id 映射
    application_task_map = {}
    if application_ids:
        try:
            application_query = select(
                models.TaskApplication.id,
                models.TaskApplication.task_id
            ).where(
                models.TaskApplication.id.in_(application_ids)
            )
            application_result = await db.execute(application_query)
            applications = application_result.all()
            
            for app_id, task_id in applications:
                application_task_map[app_id] = task_id
        except Exception as e:
            logger.warning(f"Failed to batch query task_ids for applications: {e}")
    
    # 处理所有通知
    result = []
    for idx, notification in enumerate(notifications):
        notification_dict = schemas.NotificationOut.model_validate(notification).model_dump()
        
        # 新数据：使用 related_type 字段判断
        if notification.related_type == "task_id" and notification.related_id:
            notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        
        elif notification.related_type == "application_id" and notification.related_id:
            # related_id 是 application_id，使用批量查询的结果
            task_id = application_task_map.get(notification.related_id)
            if task_id:
                notification_dict["task_id"] = task_id
            elif notification.related_id in application_ids:
                # 查询失败或不存在，记录警告
                logger.warning(
                    f"Application not found for notification {notification.id}, "
                    f"related_id: {notification.related_id}"
                )
        
        # 旧数据兼容：如果没有 related_type，根据通知类型推断
        elif notification.related_type is None:
            # task_application 类型：related_id 直接就是 task_id
            if notification.type == "task_application" and notification.related_id:
                notification_dict["task_id"] = notification.related_id
            
            # application_message, negotiation_offer, application_rejected, application_withdrawn, negotiation_rejected 类型：使用批量查询的结果
            elif notification.type in ["application_message", "negotiation_offer", "application_rejected", "application_withdrawn", "negotiation_rejected"] and notification.related_id:
                task_id = application_task_map.get(notification.related_id)
                if task_id:
                    notification_dict["task_id"] = task_id
                elif notification.related_id in application_ids:
                    # 查询失败或不存在，记录警告
                    logger.warning(
                        f"Application not found for notification {notification.id}, "
                        f"related_id: {notification.related_id}"
                    )
            
            # application_accepted 类型：旧数据可能是 task_id 或 application_id，验证是否是有效的 task_id
            elif notification.type == "application_accepted" and notification.related_id:
                related_id = int(notification.related_id) if notification.related_id else None
                if related_id:
                    # 验证是否是有效的 task_id
                    task_query = select(models.Task).where(models.Task.id == related_id)
                    task_result = await db.execute(task_query)
                    task = task_result.scalar_one_or_none()
                    if task:
                        notification_dict["task_id"] = related_id
                    # 如果不是有效的 task_id，不设置 task_id（可能是旧数据中的 application_id，避免误判）
            
            # task_approved, task_completed, task_confirmed, task_cancelled 等类型：related_id 就是 task_id
            # 达人服务/活动：service_application_approved、payment_reminder 的 related_id 就是 task_id
            else:
                task_status_types = ["task_approved", "task_completed", "task_confirmed", "task_cancelled", "task_reward_paid"]
                expert_task_types = ["service_application_approved", "payment_reminder"]
                if notification.type in task_status_types and notification.related_id:
                    notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
                elif notification.type in expert_task_types and notification.related_id:
                    notification_dict["task_id"] = int(notification.related_id) if notification.related_id else None
        
        result.append(schemas.NotificationOut(**notification_dict))
    
    return result

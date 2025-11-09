"""
任务流程通知模块
处理任务申请、同意、完成等状态变化时的通知和邮件发送
"""

from typing import Optional
from fastapi import BackgroundTasks
from sqlalchemy.orm import Session
from app import crud, models
from app.email_utils import send_email
from app.config import Config
from app.email_templates import (
    get_user_language,
    get_task_application_email,
    get_task_approval_email,
    get_task_completion_email,
    get_task_confirmation_email,
    get_task_rejection_email
)
import logging
from decimal import Decimal

logger = logging.getLogger(__name__)


def get_display_reward(task: models.Task) -> float:
    """获取显示价格：agreed_reward 或 base_reward"""
    if task.agreed_reward is not None:
        return float(task.agreed_reward)
    elif task.base_reward is not None:
        return float(task.base_reward)
    else:
        return 0.0


def send_task_application_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    applicant: models.User,
    application_message: str = "",
    negotiated_price: Optional[float] = None,
    currency: str = "GBP",
    application_id: Optional[int] = None
):
    """发送任务申请通知和邮件给发布者"""
    try:
        print(f"DEBUG: 开始发送任务申请通知，任务ID: {task.id}, 发布者ID: {task.poster_id}, 申请者: {applicant.name}")
        
        # 构建通知内容（JSON格式，包含议价信息）
        import json
        notification_content_dict = {
            "type": "task_application",
            "task_id": task.id,
            "task_title": task.title,
            "application_id": application_id,
            "applicant_name": applicant.name or f"用户{applicant.id}",
            "message": application_message,
            "negotiated_price": negotiated_price,
            "currency": currency
        }
        notification_content = json.dumps(notification_content_dict, ensure_ascii=False)
        
        # 创建通知
        notification = crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_application",
            title="新任务申请",
            content=notification_content,
            related_id=str(application_id) if application_id else str(task.id)
        )
        print(f"DEBUG: 通知创建结果: {notification}")
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        if poster and poster.email:
            # 根据用户语言偏好获取邮件模板
            language = get_user_language(poster)
            email_subject, email_body = get_task_application_email(
                language=language,
                task_title=task.title,
                task_description=task.description,
                reward=get_display_reward(task),
                applicant_name=applicant.name or f"用户{applicant.id}",
                application_message=application_message,
                negotiated_price=negotiated_price,
                currency=currency
            )
            background_tasks.add_task(send_email, poster.email, email_subject, email_body)
        logger.info(f"任务申请通知已发送给发布者 {task.poster_id}")
        
    except Exception as e:
        logger.error(f"发送任务申请通知失败: {e}")


def send_task_approval_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    applicant: models.User
):
    """发送任务申请同意通知和邮件给接收者"""
    try:
        # 创建通知
        notification_content = f"您的任务申请已被同意！任务：{task.title}"
        
        crud.create_notification(
            db=db,
            user_id=applicant.id,
            type="task_approved",
            title="任务申请已同意",
            content=notification_content,
            related_id=str(task.id)
        )
        
        # 根据用户语言偏好获取邮件模板
        language = get_user_language(applicant)
        email_subject, email_body = get_task_approval_email(
            language=language,
            task_title=task.title,
            task_description=task.description,
            reward=get_display_reward(task)
        )
        
        if applicant.email:
            background_tasks.add_task(send_email, applicant.email, email_subject, email_body)
        logger.info(f"任务同意通知已发送给接收者 {applicant.id}")
        
    except Exception as e:
        logger.error(f"发送任务同意通知失败: {e}")


def send_task_completion_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    taker: models.User
):
    """发送任务完成通知和邮件给发布者"""
    try:
        # 创建通知
        notification_content = f"用户 {taker.name} 标记任务已完成：{task.title}"
        
        crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_completed",
            title="任务已完成",
            content=notification_content,
            related_id=str(task.id)
        )
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        if poster and poster.email:
            # 根据用户语言偏好获取邮件模板
            language = get_user_language(poster)
            email_subject, email_body = get_task_completion_email(
                language=language,
                task_title=task.title,
                task_description=task.description,
                reward=get_display_reward(task),
                taker_name=taker.name or f"用户{taker.id}"
            )
            background_tasks.add_task(send_email, poster.email, email_subject, email_body)
        logger.info(f"任务完成通知已发送给发布者 {task.poster_id}")
        
    except Exception as e:
        logger.error(f"发送任务完成通知失败: {e}")


def send_task_confirmation_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    taker: models.User
):
    """发送任务确认完成通知和邮件给接收者"""
    try:
        # 创建通知
        notification_content = f"任务已完成并确认！奖励已发放：{task.title}"
        
        crud.create_notification(
            db=db,
            user_id=taker.id,
            type="task_confirmed",
            title="任务已确认完成",
            content=notification_content,
            related_id=str(task.id)
        )
        
        # 根据用户语言偏好获取邮件模板
        language = get_user_language(taker)
        email_subject, email_body = get_task_confirmation_email(
            language=language,
            task_title=task.title,
            task_description=task.description,
            reward=get_display_reward(task)
        )
        
        if taker.email:
            background_tasks.add_task(send_email, taker.email, email_subject, email_body)
        logger.info(f"任务确认通知已发送给接收者 {taker.id}")
        
    except Exception as e:
        logger.error(f"发送任务确认通知失败: {e}")


def send_task_rejection_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    applicant: models.User
):
    """发送任务申请拒绝通知和邮件给申请者"""
    try:
        # 创建通知
        notification_content = f"很抱歉，您的任务申请被拒绝：{task.title}"
        
        crud.create_notification(
            db=db,
            user_id=applicant.id,
            type="task_rejected",
            title="任务申请被拒绝",
            content=notification_content,
            related_id=str(task.id)
        )
        
        # 根据用户语言偏好获取邮件模板
        language = get_user_language(applicant)
        email_subject, email_body = get_task_rejection_email(
            language=language,
            task_title=task.title,
            task_description=task.description,
            reward=get_display_reward(task)
        )
        
        if applicant.email:
            background_tasks.add_task(send_email, applicant.email, email_subject, email_body)
        logger.info(f"任务拒绝通知已发送给申请者 {applicant.id}")
        
    except Exception as e:
        logger.error(f"发送任务拒绝通知失败: {e}")

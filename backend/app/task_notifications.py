"""
任务流程通知模块
处理任务申请、同意、完成等状态变化时的通知和邮件发送
"""

from typing import Optional
from fastapi import BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
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
import json
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


# ==================== 任务达人功能通知（异步版本）====================

async def send_expert_application_notification(
    db: AsyncSession,
    user_id: str,
):
    """用户申请成为任务达人，发送通知给管理员"""
    try:
        from app import async_crud
        
        # 获取所有管理员（简化处理：发送给所有活跃管理员）
        from sqlalchemy import select
        admin_result = await db.execute(
            select(models.AdminUser).where(models.AdminUser.is_active == True)
        )
        admins = admin_result.scalars().all()
        
        # 获取申请用户信息
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            return
        
        # 为每个管理员创建通知
        for admin in admins:
            notification_content = json.dumps({
                "type": "expert_application",
                "user_id": user_id,
                "user_name": user.name or f"用户{user_id}",
            }, ensure_ascii=False)
            
            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=admin.id,
                notification_type="expert_application",
                title="新任务达人申请",
                content=notification_content,
                related_id=user_id,
            )
        
        logger.info(f"任务达人申请通知已发送给管理员，申请用户: {user_id}")
        
    except Exception as e:
        logger.error(f"发送任务达人申请通知失败: {e}")


async def send_expert_application_approved_notification(
    db: AsyncSession,
    user_id: str,
    expert_id: str,
):
    """管理员批准任务达人申请，发送通知给用户"""
    try:
        from app import async_crud
        
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            return
        
        # 直接使用简单文本作为通知内容，前端直接显示
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=user_id,
            notification_type="expert_application_approved",
            title="任务达人申请已通过",
            content="您的任务达人申请已通过审核",  # 直接使用文本，不存储 JSON
            related_id=None,  # expert_id 是字符串类型，不能存储在 Integer 字段中
        )
        
        logger.info(f"任务达人申请批准通知已发送给用户: {user_id}")
        
    except Exception as e:
        logger.error(f"发送任务达人申请批准通知失败: {e}")


async def send_expert_application_rejected_notification(
    db: AsyncSession,
    user_id: str,
    review_comment: Optional[str] = None,
):
    """管理员拒绝任务达人申请，发送通知给用户"""
    try:
        from app import async_crud
        
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            return
        
        # 构建通知内容：如果有拒绝原因，包含在消息中
        message = "您的任务达人申请未通过审核"
        if review_comment:
            message += f"。原因：{review_comment}"
        
        # 直接使用简单文本作为通知内容，前端直接显示
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=user_id,
            notification_type="expert_application_rejected",
            title="任务达人申请未通过",
            content=message,  # 直接使用文本，不存储 JSON
            related_id=None,  # user_id 是字符串类型，不能存储在 Integer 字段中
        )
        
        logger.info(f"任务达人申请拒绝通知已发送给用户: {user_id}")
        
    except Exception as e:
        logger.error(f"发送任务达人申请拒绝通知失败: {e}")


async def send_service_application_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
    service_id: int,
    service_name: str,
    negotiated_price: Optional[Decimal] = None,
):
    """用户申请服务，发送通知给任务达人"""
    try:
        from app import async_crud
        
        # 获取申请用户信息
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        notification_content = json.dumps({
            "type": "service_application",
            "service_id": service_id,
            "service_name": service_name,
            "applicant_id": applicant_id,
            "applicant_name": applicant.name or f"用户{applicant_id}",
            "negotiated_price": float(negotiated_price) if negotiated_price else None,
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="service_application",
            title="新服务申请",
            content=notification_content,
            related_id=str(service_id),
        )
        
        logger.info(f"服务申请通知已发送给任务达人: {expert_id}, 服务: {service_name}")
        
    except Exception as e:
        logger.error(f"发送服务申请通知失败: {e}")


async def send_counter_offer_notification(
    db: AsyncSession,
    applicant_id: str,
    expert_id: str,
    counter_price: Decimal,
    message: Optional[str] = None,
):
    """任务达人再次议价，发送通知给申请用户"""
    try:
        from app import async_crud
        
        notification_content = json.dumps({
            "type": "counter_offer",
            "expert_id": expert_id,
            "counter_price": float(counter_price),
            "message": message or "",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="counter_offer",
            title="任务达人提出新价格",
            content=notification_content,
            related_id=expert_id,
        )
        
        logger.info(f"议价通知已发送给申请用户: {applicant_id}")
        
    except Exception as e:
        logger.error(f"发送议价通知失败: {e}")


async def send_counter_offer_accepted_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
    counter_price: Decimal,
):
    """用户同意任务达人的议价，发送通知给任务达人"""
    try:
        from app import async_crud
        
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        notification_content = json.dumps({
            "type": "counter_offer_accepted",
            "applicant_id": applicant_id,
            "applicant_name": applicant.name or f"用户{applicant_id}",
            "counter_price": float(counter_price),
            "message": "用户已同意您的议价，可以创建任务了",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="counter_offer_accepted",
            title="用户已同意议价",
            content=notification_content,
            related_id=applicant_id,
        )
        
        logger.info(f"议价同意通知已发送给任务达人: {expert_id}")
        
    except Exception as e:
        logger.error(f"发送议价同意通知失败: {e}")


async def send_counter_offer_rejected_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
):
    """用户拒绝任务达人的议价，发送通知给任务达人"""
    try:
        from app import async_crud
        
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        notification_content = json.dumps({
            "type": "counter_offer_rejected",
            "applicant_id": applicant_id,
            "applicant_name": applicant.name or f"用户{applicant_id}",
            "message": "用户拒绝了您的议价",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="counter_offer_rejected",
            title="用户拒绝了议价",
            content=notification_content,
            related_id=applicant_id,
        )
        
        logger.info(f"议价拒绝通知已发送给任务达人: {expert_id}")
        
    except Exception as e:
        logger.error(f"发送议价拒绝通知失败: {e}")


async def send_service_application_approved_notification(
    db: AsyncSession,
    applicant_id: str,
    expert_id: str,
    task_id: int,
    service_name: str,
):
    """任务达人同意服务申请（创建任务），发送通知给申请用户"""
    try:
        from app import async_crud
        
        notification_content = json.dumps({
            "type": "service_application_approved",
            "task_id": task_id,
            "service_name": service_name,
            "expert_id": expert_id,
            "message": f"您的服务申请已通过，任务已创建",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="service_application_approved",
            title="服务申请已通过",
            content=notification_content,
            related_id=str(task_id),
        )
        
        logger.info(f"服务申请批准通知已发送给申请用户: {applicant_id}, 任务ID: {task_id}")
        
    except Exception as e:
        logger.error(f"发送服务申请批准通知失败: {e}")


async def send_service_application_rejected_notification(
    db: AsyncSession,
    applicant_id: str,
    expert_id: str,
    service_id: int,
    reject_reason: Optional[str] = None,
):
    """任务达人拒绝服务申请，发送通知给申请用户"""
    try:
        from app import async_crud
        
        notification_content = json.dumps({
            "type": "service_application_rejected",
            "service_id": service_id,
            "expert_id": expert_id,
            "reject_reason": reject_reason or "",
            "message": "您的服务申请已被拒绝",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="service_application_rejected",
            title="服务申请被拒绝",
            content=notification_content,
            related_id=str(service_id),
        )
        
        logger.info(f"服务申请拒绝通知已发送给申请用户: {applicant_id}")
        
    except Exception as e:
        logger.error(f"发送服务申请拒绝通知失败: {e}")


async def send_service_application_cancelled_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
    service_id: int,
):
    """用户取消服务申请，发送通知给任务达人"""
    try:
        from app import async_crud
        
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        notification_content = json.dumps({
            "type": "service_application_cancelled",
            "service_id": service_id,
            "applicant_id": applicant_id,
            "applicant_name": applicant.name or f"用户{applicant_id}",
            "message": "用户取消了服务申请",
        }, ensure_ascii=False)
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="service_application_cancelled",
            title="服务申请已取消",
            content=notification_content,
            related_id=str(service_id),
        )
        
        logger.info(f"服务申请取消通知已发送给任务达人: {expert_id}")
        
    except Exception as e:
        logger.error(f"发送服务申请取消通知失败: {e}")


async def send_expert_profile_update_notification(
    db: AsyncSession,
    expert_id: str,
    request_id: int
):
    """发送任务达人信息修改请求通知给管理员（使用 StaffNotification 表）"""
    try:
        notification_content = f"任务达人 {expert_id} 提交了信息修改请求，请及时审核"
        
        # 获取所有管理员
        from sqlalchemy import select
        admin_result = await db.execute(select(models.AdminUser))
        admin_users = admin_result.scalars().all()
        
        # 使用 StaffNotification 表发送通知给管理员
        # 确保使用不带时区的 datetime（数据库字段是 TIMESTAMP WITHOUT TIME ZONE）
        from datetime import datetime
        current_time = datetime.now()  # 使用不带时区的本地时间
        
        for admin in admin_users:
            staff_notification = models.StaffNotification(
                recipient_id=admin.id,
                recipient_type="admin",
                title="任务达人信息修改请求",
                content=notification_content,
                notification_type="info",
                is_read=0,
                created_at=current_time  # 显式设置不带时区的 datetime
            )
            db.add(staff_notification)
        
        await db.commit()
        
        logger.info(f"信息修改请求通知已发送给所有管理员，请求ID: {request_id}")
        
    except Exception as e:
        logger.error(f"发送信息修改请求通知失败: {e}")


async def send_expert_profile_update_approved_notification(
    db: AsyncSession,
    expert_id: str,
    request_id: int
):
    """发送信息修改请求批准通知给任务达人"""
    try:
        notification_content = "您的信息修改请求已通过审核，信息已更新"
        
        from app import async_crud
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="expert_profile_update_approved",
            title="信息修改已批准",
            content=notification_content,
            related_id=request_id  # request_id 已经是整数
        )
        
        logger.info(f"信息修改批准通知已发送给任务达人 {expert_id}")
        
    except Exception as e:
        logger.error(f"发送信息修改批准通知失败: {e}")


async def send_expert_profile_update_rejected_notification(
    db: AsyncSession,
    expert_id: str,
    request_id: int,
    review_comment: Optional[str] = None
):
    """发送信息修改请求拒绝通知给任务达人"""
    try:
        if review_comment:
            notification_content = f"您的信息修改请求已被拒绝。拒绝原因：{review_comment}"
        else:
            notification_content = "您的信息修改请求已被拒绝"
        
        from app import async_crud
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="expert_profile_update_rejected",
            title="信息修改已拒绝",
            content=notification_content,
            related_id=request_id  # request_id 已经是整数
        )
        
        logger.info(f"信息修改拒绝通知已发送给任务达人 {expert_id}")
        
    except Exception as e:
        logger.error(f"发送信息修改拒绝通知失败: {e}")

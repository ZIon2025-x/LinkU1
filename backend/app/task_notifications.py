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
from datetime import datetime
from app.utils.time_utils import get_utc_time

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
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        applicant_name = applicant.name or f"用户{applicant.id}"
        content_parts = [f"{applicant_name} 申请了任务「{task.title}」"]
        
        if application_message:
            content_parts.append(f"申请留言：{application_message}")
        else:
            content_parts.append("申请留言：无")
        
        if negotiated_price:
            content_parts.append(f"议价金额：£{negotiated_price:.2f} {currency}")
        else:
            content_parts.append("议价金额：无议价（使用任务原定金额）")
        
        notification_content = "\n".join(content_parts)
        
        # 创建通知
        # related_id 始终使用 task_id，因为通知的目的是让用户跳转到任务详情页
        notification = crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_application",
            title="新任务申请",
            content=notification_content,
            related_id=str(task.id)  # 始终使用 task_id，确保前端可以正确跳转
        )
        print(f"DEBUG: 通知创建结果: {notification}")
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        if poster and poster.email:
            # 检查是否为临时邮箱
            from app.email_utils import is_temp_email, notify_user_to_update_email
            if is_temp_email(poster.email):
                # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                language = get_user_language(poster)
                notify_user_to_update_email(db, poster.id, language)
                logger.info(f"检测到发布者使用临时邮箱，已创建邮箱更新提醒通知: user_id={poster.id}")
            else:
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
            # 检查是否为临时邮箱
            from app.email_utils import is_temp_email, notify_user_to_update_email
            if is_temp_email(applicant.email):
                # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                notify_user_to_update_email(db, applicant.id, language)
                logger.info(f"检测到申请者使用临时邮箱，已创建邮箱更新提醒通知: user_id={applicant.id}")
            else:
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
            # 检查是否为临时邮箱
            from app.email_utils import is_temp_email, notify_user_to_update_email
            if is_temp_email(poster.email):
                # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                language = get_user_language(poster)
                notify_user_to_update_email(db, poster.id, language)
                logger.info(f"检测到发布者使用临时邮箱，已创建邮箱更新提醒通知: user_id={poster.id}")
            else:
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
            # 检查是否为临时邮箱
            from app.email_utils import is_temp_email, notify_user_to_update_email
            if is_temp_email(taker.email):
                # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                notify_user_to_update_email(db, taker.id, language)
                logger.info(f"检测到接收者使用临时邮箱，已创建邮箱更新提醒通知: user_id={taker.id}")
            else:
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
            # 检查是否为临时邮箱
            from app.email_utils import is_temp_email, notify_user_to_update_email
            if is_temp_email(applicant.email):
                # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                notify_user_to_update_email(db, applicant.id, language)
                logger.info(f"检测到申请者使用临时邮箱，已创建邮箱更新提醒通知: user_id={applicant.id}")
            else:
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
        # ⚠️ 直接使用文本内容，不存储 JSON
        user_name = user.name or f"用户{user_id}"
        content = f"用户 {user_name} 申请成为任务达人"
        
        for admin in admins:
            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=admin.id,
                notification_type="expert_application",
                title="新任务达人申请",
                content=content,  # 直接使用文本，不存储 JSON
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
    service_description: Optional[str] = None,
    base_price: Optional[Decimal] = None,
    application_message: Optional[str] = None,
    currency: Optional[str] = None,
    deadline: Optional[datetime] = None,
    is_flexible: Optional[bool] = None,
    application_time: Optional[datetime] = None,
):
    """用户申请服务，发送通知和邮件给任务达人"""
    try:
        from app import async_crud
        from app.email_templates import get_service_application_email, get_user_language
        import asyncio
        
        # 获取申请用户信息
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        # 获取任务达人信息（用于语言偏好和邮箱）
        expert = await async_crud.async_user_crud.get_user_by_id(db, expert_id)
        if not expert or not expert.email:
            logger.warning(f"任务达人 {expert_id} 不存在或没有邮箱，跳过邮件发送")
        
        # 获取服务信息（如果未提供）
        if not service_description or not base_price:
            from sqlalchemy import select
            service_result = await db.execute(
                select(models.TaskExpertService).where(models.TaskExpertService.id == service_id)
            )
            service = service_result.scalar_one_or_none()
            if service:
                service_description = service_description or service.description or ""
                base_price = base_price or service.base_price
                currency = currency or service.currency or "GBP"
            else:
                service_description = service_description or ""
                base_price = base_price or Decimal('0')
                currency = currency or "GBP"
        
        # 获取申请记录信息（如果未提供）
        if application_message is None or deadline is None or is_flexible is None or application_time is None:
            from sqlalchemy import select
            application_result = await db.execute(
                select(models.ServiceApplication)
                .where(models.ServiceApplication.service_id == service_id)
                .where(models.ServiceApplication.applicant_id == applicant_id)
                .order_by(models.ServiceApplication.created_at.desc())
                .limit(1)
            )
            application = application_result.scalar_one_or_none()
            if application:
                application_message = application_message or application.application_message or ""
                deadline = deadline or application.deadline
                is_flexible = is_flexible if is_flexible is not None else (application.is_flexible == 1)
                application_time = application_time or application.created_at
                currency = currency or application.currency or "GBP"
            else:
                application_message = application_message or ""
                is_flexible = is_flexible if is_flexible is not None else False
                application_time = application_time or get_utc_time()
                currency = currency or "GBP"
        
        # 格式化时间
        if isinstance(application_time, datetime):
            application_time_str = application_time.strftime("%Y-%m-%d %H:%M:%S")
        else:
            application_time_str = str(application_time) if application_time else ""
        
        if isinstance(deadline, datetime):
            deadline_str = deadline.strftime("%Y-%m-%d %H:%M:%S")
        else:
            deadline_str = str(deadline) if deadline else None
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        applicant_name = applicant.name or f"用户{applicant_id}"
        applicant_email = applicant.email or ""
        
        if negotiated_price:
            content = f"用户 {applicant_name} 申请了服务「{service_name}」，议价金额：{currency} {float(negotiated_price):.2f}"
        else:
            content = f"用户 {applicant_name} 申请了服务「{service_name}」"
        
        # 创建站内通知
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="service_application",
            title="新服务申请",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=str(service_id),
        )
        
        # 发送邮件（如果有任务达人邮箱）
        if expert and expert.email:
            try:
                # 获取任务达人语言偏好
                language = get_user_language(expert)
                
                # 生成邮件内容
                email_subject, email_body = get_service_application_email(
                    language=language,
                    service_name=service_name,
                    service_description=service_description or "",
                    base_price=float(base_price),
                    applicant_name=applicant_name,
                    applicant_email=applicant_email,
                    application_message=application_message or "",
                    negotiated_price=float(negotiated_price) if negotiated_price else None,
                    currency=currency or "GBP",
                    deadline=deadline_str,
                    is_flexible=is_flexible or False,
                    application_time=application_time_str,
                    service_id=service_id
                )
                
                # 检查是否为临时邮箱
                from app.email_utils import is_temp_email, notify_user_to_update_email
                if is_temp_email(expert.email):
                    # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
                    # 注意：这里需要同步数据库操作，但我们在异步函数中
                    # 使用同步数据库会话
                    from app.database import SessionLocal
                    sync_db = SessionLocal()
                    try:
                        notify_user_to_update_email(sync_db, expert.id, language)
                        logger.info(f"检测到任务达人使用临时邮箱，已创建邮箱更新提醒通知: user_id={expert.id}")
                    finally:
                        sync_db.close()
                else:
                    # 异步发送邮件（使用 asyncio 在后台任务中执行）
                    async def send_email_task():
                        try:
                            from fastapi import BackgroundTasks
                            from app.email_utils import send_email
                            # 由于 send_email 是同步函数，我们需要在线程池中执行
                            loop = asyncio.get_event_loop()
                            await loop.run_in_executor(
                                None,
                                lambda: send_email(expert.email, email_subject, email_body)
                            )
                        logger.info(f"服务申请邮件已发送给任务达人: {expert.email}, 服务: {service_name}")
                    except Exception as e:
                        logger.error(f"发送服务申请邮件失败: {e}")
                
                # 在后台执行邮件发送，不阻塞主流程
                asyncio.create_task(send_email_task())
                
            except Exception as e:
                logger.error(f"准备发送服务申请邮件时出错: {e}")
        
        logger.info(f"服务申请通知已发送给任务达人: {expert_id}, 服务: {service_name}")
        
    except Exception as e:
        logger.error(f"发送服务申请通知失败: {e}")


async def send_counter_offer_notification(
    db: AsyncSession,
    applicant_id: str,
    expert_id: str,
    counter_price: Decimal,
    service_id: int,
    message: Optional[str] = None,
):
    """任务达人再次议价，发送通知给申请用户"""
    try:
        from app import async_crud
        
        # 查询任务达人信息和服务信息
        expert = await db.get(models.TaskExpert, expert_id)
        service = await db.get(models.TaskExpertService, service_id)
        
        expert_name = expert.expert_name if expert and expert.expert_name else f"任务达人{expert_id}"
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        if message and message.strip():
            content = f"任务达人提出新价格。\n任务达人：{expert_name}\n服务名称：{service_name}\n新价格：£{float(counter_price):.2f}\n留言：{message}"
        else:
            content = f"任务达人提出新价格。\n任务达人：{expert_name}\n服务名称：{service_name}\n新价格：£{float(counter_price):.2f}"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="counter_offer",
            title="任务达人提出新价格",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=str(service_id),
        )
        
        logger.info(f"议价通知已发送给申请用户: {applicant_id}")
        
    except Exception as e:
        logger.error(f"发送议价通知失败: {e}")


async def send_counter_offer_accepted_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
    counter_price: Decimal,
    service_id: int,
):
    """用户同意任务达人的议价，发送通知给任务达人"""
    try:
        from app import async_crud
        
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        # 查询服务信息
        service = await db.get(models.TaskExpertService, service_id)
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        applicant_name = applicant.name or f"用户{applicant_id}"
        content = f"{applicant_name} 已同意您的议价。\n服务名称：{service_name}\n议价金额：£{float(counter_price):.2f}\n可以创建任务了"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="counter_offer_accepted",
            title="用户已同意议价",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=str(service_id),
        )
        
        logger.info(f"议价同意通知已发送给任务达人: {expert_id}")
        
    except Exception as e:
        logger.error(f"发送议价同意通知失败: {e}")


async def send_counter_offer_rejected_notification(
    db: AsyncSession,
    expert_id: str,
    applicant_id: str,
    service_id: int,
):
    """用户拒绝任务达人的议价，发送通知给任务达人"""
    try:
        from app import async_crud
        
        applicant = await async_crud.async_user_crud.get_user_by_id(db, applicant_id)
        if not applicant:
            return
        
        # 查询服务信息
        service = await db.get(models.TaskExpertService, service_id)
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        applicant_name = applicant.name or f"用户{applicant_id}"
        content = f"{applicant_name} 拒绝了您的议价。\n服务名称：{service_name}"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="counter_offer_rejected",
            title="用户拒绝了议价",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=str(service_id),
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
        
        # 查询任务达人信息
        expert = await db.get(models.TaskExpert, expert_id)
        expert_name = expert.expert_name if expert and expert.expert_name else f"任务达人{expert_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        notification_content = f"您的服务申请已通过，任务已创建。\n任务达人：{expert_name}\n服务名称：{service_name}"
        
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
        
        # 查询任务达人信息和服务信息
        expert = await db.get(models.TaskExpert, expert_id)
        service = await db.get(models.TaskExpertService, service_id)
        
        # 获取任务达人名字（如果没有则使用默认值）
        expert_name = expert.expert_name if expert and expert.expert_name else f"任务达人{expert_id}"
        
        # 获取服务名称（如果没有则使用默认值）
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # 构建通知内容，包含任务达人名字和服务名称
        if reject_reason and reject_reason.strip():
            content = f"您的服务申请已被拒绝。\n任务达人：{expert_name}\n服务名称：{service_name}\n拒绝原因：{reject_reason}"
        else:
            content = f"您的服务申请已被拒绝。\n任务达人：{expert_name}\n服务名称：{service_name}"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="service_application_rejected",
            title="服务申请被拒绝",
            content=content,  # 直接使用文本，不存储 JSON
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
        
        # 查询服务信息
        service = await db.get(models.TaskExpertService, service_id)
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        applicant_name = applicant.name or f"用户{applicant_id}"
        content = f"{applicant_name} 取消了服务申请。\n服务名称：{service_name}"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=expert_id,
            notification_type="service_application_cancelled",
            title="服务申请已取消",
            content=content,  # 直接使用文本，不存储 JSON
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
        # 使用UTC时间（带时区）
        current_time = get_utc_time()
        
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

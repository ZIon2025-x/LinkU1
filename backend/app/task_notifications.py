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


def send_dispute_notification_to_admin(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    dispute: models.TaskDispute,
    poster: models.User
):
    """发送争议通知给管理员（后台任务）"""
    def _send_notifications():
        """实际发送通知的函数（在后台任务中执行）"""
        try:
            # 创建新的数据库会话（后台任务需要独立的会话）
            from app.database import SessionLocal
            db_session = SessionLocal()
            try:
                # 获取所有管理员用户（通过 admin_users 表）
                from app.models import AdminUser
                admins = db_session.query(AdminUser).filter(AdminUser.is_active == True).all()
                
                if not admins:
                    logger.warning("没有找到活跃的管理员用户")
                    return
                
                poster_name = poster.name or f"用户{poster.id}"
                notification_content = f"任务「{task.title}」（ID: {task.id}）的发布者 {poster_name} 对任务完成状态有异议。\n争议原因：{dispute.reason}"
                
                # 为每个管理员创建通知
                for admin in admins:
                    # AdminUser 的 id 字段就是用户ID（字符串格式）
                    try:
                        crud.create_notification(
                            db=db_session,
                            user_id=admin.id,
                            type="task_dispute",
                            title="任务争议",
                            content=notification_content,
                            related_id=str(task.id)
                        )
                    except Exception as e:
                        logger.error(f"为管理员 {admin.id} 创建争议通知失败: {e}")
                
                db_session.commit()
                logger.info(f"已向 {len(admins)} 位管理员发送任务争议通知: task_id={task.id}, dispute_id={dispute.id}")
            finally:
                db_session.close()
        except Exception as e:
            logger.error(f"发送争议通知给管理员失败: {e}")
    
    # 将通知发送任务添加到后台任务队列
    if background_tasks:
        background_tasks.add_task(_send_notifications)
    else:
        # 如果没有 background_tasks，直接执行（不应该发生，但作为后备）
        _send_notifications()


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
        logger.debug("开始发送任务申请通知，任务ID: %s, 发布者ID: %s, 申请者: %s", task.id, task.poster_id, applicant.name)
        
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
        
        # 生成英文版本
        applicant_name_en = applicant.name or f"User {applicant.id}"
        content_parts_en = [f"{applicant_name_en} applied for task「{task.title}」"]
        
        if application_message:
            content_parts_en.append(f"Application message: {application_message}")
        else:
            content_parts_en.append("Application message: None")
        
        if negotiated_price:
            content_parts_en.append(f"Negotiated price: £{negotiated_price:.2f} {currency}")
        else:
            content_parts_en.append("Negotiated price: No negotiation (using original task amount)")
        
        notification_content_en = "\n".join(content_parts_en)
        
        # 创建通知
        # related_id 始终使用 task_id，因为通知的目的是让用户跳转到任务详情页
        notification = crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_application",
            title="新任务申请",
            content=notification_content,
            title_en="New Task Application",
            content_en=notification_content_en,
            related_id=str(task.id)  # 始终使用 task_id，确保前端可以正确跳转
        )
        logger.debug("通知创建结果: %s", notification)
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification
            logger.info(f"准备发送推送通知给用户 {task.poster_id}，任务ID: {task.id}")
            result = send_push_notification(
                db=db,
                user_id=task.poster_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="task_application",
                data={"task_id": task.id, "application_id": application_id},
                template_vars={
                    "applicant_name": applicant_name,
                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                    "task_id": task.id  # 传递 task_id 以便获取翻译
                }
            )
            if result:
                logger.info(f"推送通知发送成功，用户ID: {task.poster_id}")
            else:
                logger.warning(f"推送通知发送失败（返回 False），用户ID: {task.poster_id}")
        except Exception as e:
            logger.error(f"发送任务申请推送通知失败: {e}", exc_info=True)
            # 推送通知失败不影响主流程
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        # ⚠️ 暂时禁用任务状态变化时的自动邮件发送
        # if poster and poster.email:
        #     # 检查是否为临时邮箱
        #     from app.email_utils import is_temp_email, notify_user_to_update_email
        #     if is_temp_email(poster.email):
        #         # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        #         language = get_user_language(poster)
        #         notify_user_to_update_email(db, poster.id, language)
        #         logger.info(f"检测到发布者使用临时邮箱，已创建邮箱更新提醒通知: user_id={poster.id}")
        #     else:
        #         # 根据用户语言偏好获取邮件模板
        #         language = get_user_language(poster)
        #         email_subject, email_body = get_task_application_email(
        #             language=language,
        #             task_title=task.title,
        #             task_description=task.description,
        #             reward=get_display_reward(task),
        #             applicant_name=applicant.name or f"用户{applicant.id}",
        #             application_message=application_message,
        #             negotiated_price=negotiated_price,
        #             currency=currency
        #         )
        #         background_tasks.add_task(send_email, poster.email, email_subject, email_body)
        logger.info(f"任务申请通知已发送给发布者 {task.poster_id}（邮件发送已暂时禁用）")
        
    except Exception as e:
        logger.error(f"发送任务申请通知失败: {e}")


def send_task_approval_notification(
    db: Session,
    background_tasks: Optional[BackgroundTasks],
    task: models.Task,
    applicant: models.User
):
    """发送任务申请同意通知和邮件给接收者"""
    try:
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=applicant.id,
                title=None,  # 从模板生成
                body=None,  # 从模板生成
                notification_type="application_accepted",
                data={"task_id": task.id},
                template_vars={
                    "task_title": task.title
                }
            )
        except Exception as e:
            logger.warning(f"发送任务申请接受推送通知失败: {e}")
            # 推送通知失败不影响主流程
        # 创建通知（如果任务需要支付，添加支付提醒）
        payment_expires_info = ""
        if task.status == "pending_payment" and task.payment_expires_at:
            from app.utils.time_utils import format_iso_utc
            expires_at_str = format_iso_utc(task.payment_expires_at)
            payment_expires_info = f"\n请尽快完成支付以开始任务。支付过期时间：{expires_at_str}\n请在24小时内完成支付，否则任务将自动取消。"
        
        notification_content = f"您的任务申请已被同意！任务：{task.title}{payment_expires_info}"
        
        # 生成英文版本
        payment_expires_info_en = ""
        if task.status == "pending_payment" and task.payment_expires_at:
            from app.utils.time_utils import format_iso_utc
            expires_at_str = format_iso_utc(task.payment_expires_at)
            payment_expires_info_en = f"\nPlease complete the payment as soon as possible to start the task. Payment expires at: {expires_at_str}\nPlease complete the payment within 24 hours, otherwise the task will be automatically cancelled."
        
        notification_content_en = f"Your task application has been approved! Task: {task.title}{payment_expires_info_en}"
        title = "任务申请已同意，请完成支付" if task.status == "pending_payment" else "任务申请已同意"
        title_en = "Task Application Approved - Payment Required" if task.status == "pending_payment" else "Task Application Approved"
        
        crud.create_notification(
            db=db,
            user_id=applicant.id,
            type="task_approved",
            title=title,
            content=notification_content,
            title_en=title_en,
            content_en=notification_content_en,
            related_id=str(task.id)
        )
        
        # ⚠️ 暂时禁用任务状态变化时的自动邮件发送
        # 根据用户语言偏好获取邮件模板
        # language = get_user_language(applicant)
        # email_subject, email_body = get_task_approval_email(
        #     language=language,
        #     task_title=task.title,
        #     task_description=task.description,
        #     reward=get_display_reward(task)
        # )
        # 
        # if applicant.email:
        #     # 检查是否为临时邮箱
        #     from app.email_utils import is_temp_email, notify_user_to_update_email
        #     if is_temp_email(applicant.email):
        #         # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        #         notify_user_to_update_email(db, applicant.id, language)
        #         logger.info(f"检测到申请者使用临时邮箱，已创建邮箱更新提醒通知: user_id={applicant.id}")
        #     else:
        #         background_tasks.add_task(send_email, applicant.email, email_subject, email_body)
        logger.info(f"任务同意通知已发送给接收者 {applicant.id}（邮件发送已暂时禁用）")
        
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
        taker_name = taker.name or f"用户{taker.id}"
        notification_content = f"用户 {taker_name} 标记任务已完成：{task.title}"
        
        # 生成英文版本
        taker_name_en = taker.name or f"User {taker.id}"
        notification_content_en = f"{taker_name_en} has marked task as completed: {task.title}"
        
        crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_completed",
            title="任务已完成",
            content=notification_content,
            title_en="Task Completed",
            content_en=notification_content_en,
            related_id=str(task.id)
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=task.poster_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="task_completed",
                data={"task_id": task.id},
                template_vars={
                    "taker_name": taker_name,
                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                    "task_id": task.id  # 传递 task_id 以便获取翻译
                }
            )
        except Exception as e:
            logger.warning(f"发送任务完成推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        # ⚠️ 暂时禁用任务状态变化时的自动邮件发送
        # 获取发布者信息
        # poster = crud.get_user_by_id(db, task.poster_id)
        # if poster and poster.email:
        #     # 检查是否为临时邮箱
        #     from app.email_utils import is_temp_email, notify_user_to_update_email
        #     if is_temp_email(poster.email):
        #         # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        #         language = get_user_language(poster)
        #         notify_user_to_update_email(db, poster.id, language)
        #         logger.info(f"检测到发布者使用临时邮箱，已创建邮箱更新提醒通知: user_id={poster.id}")
        #     else:
        #         # 根据用户语言偏好获取邮件模板
        #         language = get_user_language(poster)
        #         email_subject, email_body = get_task_completion_email(
        #             language=language,
        #             task_title=task.title,
        #             task_description=task.description,
        #             reward=get_display_reward(task),
        #             taker_name=taker.name or f"用户{taker.id}"
        #         )
        #         background_tasks.add_task(send_email, poster.email, email_subject, email_body)
        logger.info(f"任务完成通知已发送给发布者 {task.poster_id}（邮件发送已暂时禁用）")
        
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
        notification_content_en = f"Task completed and confirmed! Reward has been issued: {task.title}"
        
        crud.create_notification(
            db=db,
            user_id=taker.id,
            type="task_confirmed",
            title="任务已确认完成",
            content=notification_content,
            title_en="Task Confirmed",
            content_en=notification_content_en,
            related_id=str(task.id)
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=taker.id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="task_confirmed",
                data={"task_id": task.id},
                template_vars={
                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                    "task_id": task.id  # 传递 task_id 以便获取翻译
                }
            )
        except Exception as e:
            logger.warning(f"发送任务确认推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        # ⚠️ 暂时禁用任务状态变化时的自动邮件发送
        # 根据用户语言偏好获取邮件模板
        # language = get_user_language(taker)
        # email_subject, email_body = get_task_confirmation_email(
        #     language=language,
        #     task_title=task.title,
        #     task_description=task.description,
        #     reward=get_display_reward(task)
        # )
        # 
        # if taker.email:
        #     # 检查是否为临时邮箱
        #     from app.email_utils import is_temp_email, notify_user_to_update_email
        #     if is_temp_email(taker.email):
        #         # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        #         notify_user_to_update_email(db, taker.id, language)
        #         logger.info(f"检测到接收者使用临时邮箱，已创建邮箱更新提醒通知: user_id={taker.id}")
        #     else:
        #         background_tasks.add_task(send_email, taker.email, email_subject, email_body)
        logger.info(f"任务确认通知已发送给接收者 {taker.id}（邮件发送已暂时禁用）")
        
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
        notification_content_en = f"Sorry, your task application has been rejected: {task.title}"
        
        crud.create_notification(
            db=db,
            user_id=applicant.id,
            type="task_rejected",
            title="任务申请被拒绝",
            content=notification_content,
            title_en="Task Application Rejected",
            content_en=notification_content_en,
            related_id=str(task.id)
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=applicant.id,
                title=None,  # 从模板生成
                body=None,  # 从模板生成
                notification_type="task_rejected",
                data={"task_id": task.id},
                template_vars={
                    "task_title": task.title
                }
            )
        except Exception as e:
            logger.warning(f"发送任务拒绝推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        # ⚠️ 暂时禁用任务状态变化时的自动邮件发送
        # 根据用户语言偏好获取邮件模板
        # language = get_user_language(applicant)
        # email_subject, email_body = get_task_rejection_email(
        #     language=language,
        #     task_title=task.title,
        #     task_description=task.description,
        #     reward=get_display_reward(task)
        # )
        # 
        # if applicant.email:
        #     # 检查是否为临时邮箱
        #     from app.email_utils import is_temp_email, notify_user_to_update_email
        #     if is_temp_email(applicant.email):
        #         # 临时邮箱无法接收邮件，创建通知提醒用户更新邮箱
        #         notify_user_to_update_email(db, applicant.id, language)
        #         logger.info(f"检测到申请者使用临时邮箱，已创建邮箱更新提醒通知: user_id={applicant.id}")
        #     else:
        #         background_tasks.add_task(send_email, applicant.email, email_subject, email_body)
        logger.info(f"任务拒绝通知已发送给申请者 {applicant.id}（邮件发送已暂时禁用）")
        
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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=expert_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="service_application",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "applicant_name": applicant_name,
                    "service_name": service_name
                }
            )
        except Exception as e:
            logger.warning(f"发送服务申请推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=applicant_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="counter_offer",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "service_name": service_name,
                    "counter_price": float(counter_price)
                }
            )
        except Exception as e:
            logger.warning(f"发送任务达人议价推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=expert_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="counter_offer_accepted",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "applicant_name": applicant_name,
                    "service_name": service_name
                }
            )
        except Exception as e:
            logger.warning(f"发送议价同意推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        logger.info(f"议价同意通知已发送给任务达人: {expert_id}")
        
    except Exception as e:
        logger.error(f"发送议价同意通知失败: {e}")


async def send_counter_offer_accepted_to_applicant_notification(
    db: AsyncSession,
    applicant_id: str,
    expert_id: str,
    counter_price: Decimal,
    service_id: int,
):
    """用户同意任务达人的议价后，发送通知给用户（申请者），提醒等待支付"""
    try:
        from app import async_crud
        
        # 查询服务信息
        service = await db.get(models.TaskExpertService, service_id)
        service_name = service.service_name if service and service.service_name else f"服务#{service_id}"
        
        # 获取任务达人信息
        expert_user = await async_crud.async_user_crud.get_user_by_id(db, expert_id)
        expert_name = expert_user.name if expert_user and expert_user.name else f"任务达人{expert_id}"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        content = f"您已同意任务达人 {expert_name} 的议价。\n服务名称：{service_name}\n议价金额：£{float(counter_price):.2f}\n请等待任务达人创建任务，创建后需要完成支付。"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="counter_offer_accepted_to_applicant",
            title="已同意议价",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=str(service_id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=applicant_id,
                title="已同意议价",
                body=f"您已同意任务达人 {expert_name} 的议价，请等待任务创建并完成支付",
                notification_type="counter_offer_accepted_to_applicant",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "expert_name": expert_name,
                    "service_name": service_name,
                    "counter_price": float(counter_price)
                }
            )
        except Exception as e:
            logger.warning(f"发送议价同意推送通知给用户失败: {e}")
            # 推送通知失败不影响主流程
        
        logger.info(f"议价同意通知已发送给用户（申请者）: {applicant_id}")
        
    except Exception as e:
        logger.error(f"发送议价同意通知给用户失败: {e}")


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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=expert_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="counter_offer_rejected",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "applicant_name": applicant_name,
                    "service_name": service_name
                }
            )
        except Exception as e:
            logger.warning(f"发送议价拒绝推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
        
        # 查询任务信息，获取支付过期时间
        task = await db.get(models.Task, task_id)
        payment_expires_info = ""
        if task and task.payment_expires_at:
            from app.utils.time_utils import format_iso_utc
            expires_at_str = format_iso_utc(task.payment_expires_at)
            payment_expires_info = f"\n支付过期时间：{expires_at_str}\n请在24小时内完成支付，否则任务将自动取消。"
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        notification_content = f"您的服务申请已通过，任务已创建。\n任务达人：{expert_name}\n服务名称：{service_name}\n请尽快完成支付以开始任务。{payment_expires_info}"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=applicant_id,
            notification_type="service_application_approved",
            title="服务申请已通过，请完成支付",
            content=notification_content,
            related_id=str(task_id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=applicant_id,
                title="服务申请已通过，请完成支付",
                body=f"任务已创建，请尽快完成支付以开始任务「{service_name}」",
                notification_type="service_application_approved",
                data={
                    "task_id": task_id,
                    "service_id": service_id
                },
                template_vars={
                    "service_name": service_name,
                    "task_id": task_id
                }
            )
        except Exception as e:
            logger.warning(f"发送服务申请批准推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=applicant_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="service_application_rejected",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "service_name": service_name
                }
            )
        except Exception as e:
            logger.warning(f"发送服务申请拒绝推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            send_push_notification_async_safe(
                async_db=db,
                user_id=expert_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="service_application_cancelled",
                data={
                    "service_id": service_id
                },
                template_vars={
                    "applicant_name": applicant_name,
                    "service_name": service_name
                }
            )
        except Exception as e:
            logger.warning(f"发送服务申请取消推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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


def send_payment_reminder_notification(
    db: Session,
    user_id: str,
    task_id: int,
    task_title: str,
    hours_remaining: int,
    expires_at: datetime
):
    """发送支付提醒通知给用户（同步版本）"""
    try:
        from app.push_notification_service import send_push_notification
        from app.utils.time_utils import format_iso_utc
        
        # 创建通知
        hours_text = f"{hours_remaining}小时" if hours_remaining >= 1 else f"{hours_remaining * 60}分钟"
        notification_content = f"任务「{task_title}」的支付将在{hours_text}后过期，请尽快完成支付。"
        
        crud.create_notification(
            db=db,
            user_id=user_id,
            type="payment_reminder",
            title="支付提醒",
            content=notification_content,
            related_id=str(task_id)
        )
        
        # 发送推送通知
        try:
            send_push_notification(
                db=db,
                user_id=user_id,
                title="支付提醒",
                body=f"任务「{task_title}」的支付将在{hours_text}后过期",
                notification_type="payment_reminder",
                data={"task_id": task_id},
                template_vars={
                    "task_title": task_title,
                    "task_id": task_id,
                    "hours_remaining": hours_remaining,
                    "expires_at": format_iso_utc(expires_at)
                }
            )
        except Exception as e:
            logger.warning(f"发送支付提醒推送通知失败: {e}")
        
        logger.info(f"支付提醒通知已发送给用户 {user_id}（任务 {task_id}，{hours_remaining}小时后过期）")
        
    except Exception as e:
        logger.error(f"发送支付提醒通知失败: {e}", exc_info=True)
        raise

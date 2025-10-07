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
import logging

logger = logging.getLogger(__name__)


def send_task_application_notification(
    db: Session,
    background_tasks: BackgroundTasks,
    task: models.Task,
    applicant: models.User,
    application_message: str = ""
):
    """发送任务申请通知和邮件给发布者"""
    try:
        print(f"DEBUG: 开始发送任务申请通知，任务ID: {task.id}, 发布者ID: {task.poster_id}, 申请者: {applicant.name}")
        
        # 创建通知
        notification_content = f"用户 {applicant.name} 申请了您的任务：{task.title}"
        if application_message:
            notification_content += f"\n申请留言：{application_message}"
        
        notification = crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="task_application",
            title="新任务申请",
            content=notification_content,
            related_id=str(task.id)
        )
        print(f"DEBUG: 通知创建结果: {notification}")
        
        # 发送邮件
        email_subject = f"Link2Ur - 新任务申请：{task.title}"
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    📝 新任务申请
                </h2>
                
                <p>您好！</p>
                
                <p>用户 <strong>{applicant.name}</strong> 申请了您发布的任务：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task.title}</h3>
                    <p><strong>任务描述：</strong>{task.description}</p>
                    <p><strong>任务奖励：</strong>£{task.reward}</p>
                </div>
                
                {f'<p><strong>申请留言：</strong>{application_message}</p>' if application_message else ''}
                
                <p>请登录 Link2Ur 平台查看申请详情并决定是否同意该用户接受任务。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks/{task.id}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link2Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        if poster and poster.email:
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
        
        # 发送邮件
        email_subject = f"Link2Ur - 任务申请已同意：{task.title}"
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    ✅ 任务申请已同意
                </h2>
                
                <p>恭喜！</p>
                
                <p>您申请的任务已被发布者同意，现在可以开始执行任务了：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task.title}</h3>
                    <p><strong>任务描述：</strong>{task.description}</p>
                    <p><strong>任务奖励：</strong>£{task.reward}</p>
                </div>
                
                <p>请按照任务要求完成工作，完成后记得标记任务完成。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks/{task.id}" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link2Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
        
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
        
        # 发送邮件
        email_subject = f"Link2Ur - 任务已完成：{task.title}"
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #ff9800; border-bottom: 2px solid #ff9800; padding-bottom: 10px;">
                    🎉 任务已完成
                </h2>
                
                <p>您好！</p>
                
                <p>用户 <strong>{taker.name}</strong> 已标记任务完成：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task.title}</h3>
                    <p><strong>任务描述：</strong>{task.description}</p>
                    <p><strong>任务奖励：</strong>£{task.reward}</p>
                </div>
                
                <p>请检查任务完成情况，如果满意请确认完成以释放奖励。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks/{task.id}" 
                       style="background: #ff9800; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link2Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
        
        # 获取发布者信息
        poster = crud.get_user_by_id(db, task.poster_id)
        if poster and poster.email:
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
        
        # 发送邮件
        email_subject = f"Link2Ur - 任务已确认完成：{task.title}"
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    🎊 任务已确认完成
                </h2>
                
                <p>恭喜！</p>
                
                <p>您完成的任务已被发布者确认，奖励已发放到您的账户：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task.title}</h3>
                    <p><strong>任务描述：</strong>{task.description}</p>
                    <p><strong>获得奖励：</strong>£{task.reward}</p>
                </div>
                
                <p>感谢您使用 Link2Ur 平台！继续寻找更多任务机会吧。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看更多任务
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link2Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
        
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
        
        # 发送邮件
        email_subject = f"Link2Ur - 任务申请被拒绝：{task.title}"
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                    ❌ 任务申请被拒绝
                </h2>
                
                <p>很抱歉，</p>
                
                <p>您申请的任务被发布者拒绝了：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task.title}</h3>
                    <p><strong>任务描述：</strong>{task.description}</p>
                    <p><strong>任务奖励：</strong>£{task.reward}</p>
                </div>
                
                <p>不要灰心！还有很多其他任务机会等着您。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看更多任务
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link2Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
        
        if applicant.email:
            background_tasks.add_task(send_email, applicant.email, email_subject, email_body)
        logger.info(f"任务拒绝通知已发送给申请者 {applicant.id}")
        
    except Exception as e:
        logger.error(f"发送任务拒绝通知失败: {e}")

"""
学生认证过期提醒和通知任务
"""
import logging
import time
from app.celery_app import celery_app
from app.database import SessionLocal
from app.celery_tasks import _record_task_metrics

logger = logging.getLogger(__name__)


@celery_app.task(
    name='app.celery_tasks_expiry.send_expiry_reminders_task',
    bind=True,
    max_retries=3,
    default_retry_delay=60
)
def send_expiry_reminders_task(self, days_before: int):
    """发送过期提醒邮件 - Celery任务包装"""
    start_time = time.time()
    task_name = f'send_expiry_reminders_task_{days_before}'
    logger.info(f"🔄 开始执行定时任务: {task_name}")
    db = SessionLocal()
    try:
        from app.scheduled_tasks import send_expiry_reminders
        send_expiry_reminders(db, days_before)
        duration = time.time() - start_time
        logger.info(f"✅ 发送过期提醒邮件完成 ({days_before}天前) (耗时: {duration:.2f}秒)")
        _record_task_metrics(task_name, "success", duration)
        return {"status": "success", "message": f"Expiry reminders sent ({days_before} days before)"}
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"发送过期提醒邮件失败 ({days_before}天): {e}", exc_info=True)
        _record_task_metrics(task_name, "error", duration)
        try:
            db.rollback()
        except:
            pass
        if self.request.retries < self.max_retries:
            logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
            raise self.retry(exc=e)
        raise
    finally:
        db.close()


@celery_app.task(
    name='app.celery_tasks_expiry.send_expiry_notifications_task',
    bind=True,
    max_retries=3,
    default_retry_delay=60
)
def send_expiry_notifications_task(self):
    """发送过期通知邮件 - Celery任务包装"""
    start_time = time.time()
    task_name = 'send_expiry_notifications_task'
    logger.info(f"🔄 开始执行定时任务: {task_name}")
    db = SessionLocal()
    try:
        from app.scheduled_tasks import send_expiry_notifications
        send_expiry_notifications(db)
        duration = time.time() - start_time
        logger.info(f"✅ 发送过期通知邮件完成 (耗时: {duration:.2f}秒)")
        _record_task_metrics(task_name, "success", duration)
        return {"status": "success", "message": "Expiry notifications sent"}
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"发送过期通知邮件失败: {e}", exc_info=True)
        _record_task_metrics(task_name, "error", duration)
        try:
            db.rollback()
        except:
            pass
        if self.request.retries < self.max_retries:
            logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
            raise self.retry(exc=e)
        raise
    finally:
        db.close()


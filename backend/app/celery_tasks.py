"""
Celery 定时任务包装
将所有定时任务包装为 Celery 任务，支持 Celery Beat 调度
"""
import logging
import time
from typing import Dict, Any

logger = logging.getLogger(__name__)

# 辅助函数：记录 Prometheus 指标
def _record_task_metrics(task_name: str, status: str, duration: float):
    """记录任务执行指标"""
    try:
        from app.metrics import record_scheduled_task
        record_scheduled_task(task_name, status, duration)
    except Exception:
        pass  # 指标记录失败不影响任务执行

# 尝试导入 Celery
try:
    from app.celery_app import celery_app
    CELERY_AVAILABLE = True
except ImportError:
    logger.warning("Celery未安装，将使用后台线程方式执行定时任务")
    CELERY_AVAILABLE = False
    celery_app = None

if CELERY_AVAILABLE:
    from app.database import SessionLocal
    from app.scheduled_tasks import (
        check_expired_coupons,
        check_expired_invitation_codes,
        check_expired_points,
        check_and_end_activities_sync,
        auto_complete_expired_time_slot_tasks
    )
    from app.crud import (
        cancel_expired_tasks,
        update_all_featured_task_experts_response_time
    )
    from app.main import update_all_users_statistics
    
    @celery_app.task(
        name='app.celery_tasks.cancel_expired_tasks_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def cancel_expired_tasks_task(self):
        """取消过期任务 - Celery任务包装"""
        start_time = time.time()
        task_name = 'cancel_expired_tasks_task'
        db = SessionLocal()
        try:
            cancel_expired_tasks(db)
            duration = time.time() - start_time
            logger.info(f"取消过期任务完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Expired tasks cancelled"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"取消过期任务失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            # 重试机制：对于临时错误（如数据库连接问题）进行重试
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.check_expired_coupons_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def check_expired_coupons_task(self):
        """检查过期优惠券 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_expired_coupons_task'
        db = SessionLocal()
        try:
            check_expired_coupons(db)
            duration = time.time() - start_time
            logger.info(f"检查过期优惠券完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Expired coupons checked"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查过期优惠券失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 注意：check_expired_coupons 内部已经有 commit，如果出错会在 commit 之前
            # 这里尝试 rollback，但如果已经 commit 会失败（忽略即可）
            try:
                db.rollback()
            except Exception:
                pass  # 如果已经 commit 或连接已关闭，忽略 rollback 错误
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.check_expired_invitation_codes_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def check_expired_invitation_codes_task(self):
        """检查过期邀请码 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_expired_invitation_codes_task'
        db = SessionLocal()
        try:
            check_expired_invitation_codes(db)
            duration = time.time() - start_time
            logger.info(f"检查过期邀请码完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Expired invitation codes checked"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查过期邀请码失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 注意：check_expired_invitation_codes 内部已经有 commit，如果出错会在 commit 之前
            try:
                db.rollback()
            except Exception:
                pass  # 如果已经 commit 或连接已关闭，忽略 rollback 错误
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.check_expired_points_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def check_expired_points_task(self):
        """检查过期积分 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_expired_points_task'
        db = SessionLocal()
        try:
            check_expired_points(db)
            duration = time.time() - start_time
            logger.info(f"检查过期积分完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Expired points checked"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查过期积分失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 注意：check_expired_points 内部已经有 commit，如果出错会在 commit 之前
            try:
                db.rollback()
            except Exception:
                pass  # 如果已经 commit 或连接已关闭，忽略 rollback 错误
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.auto_complete_expired_time_slot_tasks_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def auto_complete_expired_time_slot_tasks_task(self):
        """自动完成已过期时间段的任务 - Celery任务包装"""
        start_time = time.time()
        task_name = 'auto_complete_expired_time_slot_tasks_task'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            completed_count = auto_complete_expired_time_slot_tasks(db)
            duration = time.time() - start_time
            logger.info(f"✅ 自动完成过期时间段任务执行完成，完成了 {completed_count} 个任务 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": f"Completed {completed_count} expired time slot tasks", "completed_count": completed_count}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"自动完成过期时间段任务失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.check_and_end_activities_task',
        bind=True,
        max_retries=2,  # 活动结束任务重试次数较少
        default_retry_delay=120  # 重试延迟2分钟
    )
    def check_and_end_activities_task(self):
        """检查并结束活动 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_and_end_activities_task'
        # 注意：check_and_end_activities_sync 内部使用异步数据库会话，不依赖传入的 db
        # 但为了保持接口一致性，仍然传入 db（虽然不会被使用）
        db = SessionLocal()
        try:
            ended_count = check_and_end_activities_sync(db)
            duration = time.time() - start_time
            logger.info(f"检查并结束活动完成，结束了 {ended_count} 个活动 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": f"Ended {ended_count} activities", "ended_count": ended_count}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查并结束活动失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # check_and_end_activities_sync 内部使用异步会话，不依赖同步 db
            # 这里 rollback 主要是为了清理同步会话状态
            try:
                db.rollback()
            except Exception:
                pass  # 如果连接已关闭，忽略 rollback 错误
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.celery_tasks.update_all_users_statistics_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300  # 重试延迟5分钟（统计更新不是紧急任务）
    )
    def update_all_users_statistics_task(self):
        """更新所有用户统计信息 - Celery任务包装"""
        start_time = time.time()
        task_name = 'update_all_users_statistics_task'
        try:
            update_all_users_statistics()
            duration = time.time() - start_time
            logger.info(f"更新所有用户统计信息完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "User statistics updated"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"更新所有用户统计信息失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
    
    @celery_app.task(
        name='app.celery_tasks.update_featured_task_experts_response_time_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300  # 重试延迟5分钟
    )
    def update_featured_task_experts_response_time_task(self):
        """更新特征任务达人的响应时间 - Celery任务包装（每天凌晨3点执行）"""
        start_time = time.time()
        task_name = 'update_featured_task_experts_response_time_task'
        # 注意：时间检查由 Celery Beat 的 crontab 调度完成，这里不需要再检查
        try:
            updated_count = update_all_featured_task_experts_response_time()
            duration = time.time() - start_time
            logger.info(f"更新特征任务达人响应时间完成，更新了 {updated_count} 个达人 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": f"Updated {updated_count} featured task experts response time", "updated_count": updated_count}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"更新特征任务达人响应时间失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
    
    @celery_app.task(
        name='app.celery_tasks.cleanup_long_inactive_chats_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300  # 重试延迟5分钟
    )
    def cleanup_long_inactive_chats_task(self):
        """清理长期无活动对话 - Celery任务包装（每天凌晨2点执行）"""
        start_time = time.time()
        task_name = 'cleanup_long_inactive_chats_task'
        from app.customer_service_tasks import cleanup_long_inactive_chats
        # 注意：时间检查由 Celery Beat 的 crontab 调度完成，这里不需要再检查
        db = SessionLocal()
        try:
            result = cleanup_long_inactive_chats(db, inactive_days=30)
            duration = time.time() - start_time
            logger.info(f"清理长期无活动对话完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Long inactive chats cleaned", "result": result}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"清理长期无活动对话失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 任务函数内部已经处理了 rollback，这里只需要记录错误
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()


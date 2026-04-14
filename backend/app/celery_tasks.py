"""
Celery 定时任务包装
将所有定时任务包装为 Celery 任务，支持 Celery Beat 调度
"""
import logging
import time
from typing import Dict, Any

logger = logging.getLogger(__name__)


def get_redis_distributed_lock(lock_key: str, lock_ttl: int = 3600) -> bool:
    """
    获取 Redis 分布式锁（使用 SETNX）
    返回 True 表示获取成功，False 表示锁已被占用
    
    Args:
        lock_key: 锁的键名
        lock_ttl: 锁的过期时间（秒），默认1小时
    
    Returns:
        bool: 是否成功获取锁
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if not redis_client:
            # Redis 不可用时，返回 True（允许执行，但会有多实例重复执行的风险）
            logger.warning(f"Redis 不可用，跳过分布式锁检查: {lock_key}")
            return True
        
        # 使用 SETNX 原子操作获取锁
        lock_value = str(time.time())
        result = redis_client.set(lock_key, lock_value, nx=True, ex=lock_ttl)
        
        if result:
            logger.debug(f"成功获取分布式锁: {lock_key}")
            return True
        else:
            logger.debug(f"分布式锁已被占用: {lock_key}")
            return False
            
    except Exception as e:
        logger.warning(f"获取分布式锁失败 {lock_key}: {e}，允许执行（降级处理）")
        return True  # 出错时允许执行，避免因锁机制故障导致任务无法执行


def release_redis_distributed_lock(lock_key: str):
    """
    释放 Redis 分布式锁
    
    Args:
        lock_key: 锁的键名
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            redis_client.delete(lock_key)
            logger.debug(f"释放分布式锁: {lock_key}")
    except Exception as e:
        logger.warning(f"释放分布式锁失败 {lock_key}: {e}")

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
        auto_complete_expired_time_slot_tasks,
        process_expired_verifications,
        check_expired_payment_tasks
    )
    from app.crud import check_and_update_expired_subscriptions
    from app.crud import (
        cancel_expired_tasks,
        update_all_featured_task_experts_response_time,
        revert_unpaid_application_approvals
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
        name='app.celery_tasks.check_expired_payment_tasks_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def check_expired_payment_tasks_task(self):
        """检查并取消支付过期的任务 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_expired_payment_tasks_task'
        db = SessionLocal()
        try:
            cancelled_count = check_expired_payment_tasks(db)
            duration = time.time() - start_time
            logger.info(f"检查支付过期任务完成，取消了 {cancelled_count} 个任务 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "cancelled_count": cancelled_count}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查支付过期任务失败: {e}", exc_info=True)
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
        name='app.celery_tasks.process_pending_payment_transfers_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def process_pending_payment_transfers_task(self):
        """处理待处理的支付转账 - Celery任务包装"""
        start_time = time.time()
        task_name = 'process_pending_payment_transfers_task'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            from app.payment_transfer_service import process_pending_transfers
            stats = process_pending_transfers(db)
            duration = time.time() - start_time
            logger.info(f"✅ 处理待处理转账完成: 处理={stats['processed']}, 成功={stats['succeeded']}, 失败={stats['failed']}, 重试中={stats['retrying']} (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "stats": stats}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"处理待处理转账失败: {e}", exc_info=True)
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
        name='app.celery_tasks.revert_unpaid_application_approvals_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def revert_unpaid_application_approvals_task(self):
        """撤销超时未支付的申请批准 - Celery任务包装（每1小时执行）"""
        start_time = time.time()
        task_name = 'revert_unpaid_application_approvals_task'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            reverted_count = revert_unpaid_application_approvals(db)
            duration = time.time() - start_time
            logger.info(f"✅ 撤销超时未支付申请批准执行完成，撤销了 {reverted_count} 个任务 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": f"Reverted {reverted_count} unpaid application approvals", "reverted_count": reverted_count}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"撤销超时未支付申请批准失败: {e}", exc_info=True)
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
        name='app.celery_tasks.check_transfer_timeout_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def check_transfer_timeout_task(self):
        """检查转账超时 - Celery任务包装"""
        start_time = time.time()
        task_name = 'check_transfer_timeout_task'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            from app.payment_transfer_service import check_transfer_timeout
            stats = check_transfer_timeout(db, timeout_hours=24)
            duration = time.time() - start_time
            logger.info(f"✅ 转账超时检查完成: 检查={stats['checked']}, 超时={stats['timeout']}, 更新={stats['updated']} (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "stats": stats}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"检查转账超时失败: {e}", exc_info=True)
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
        name='app.celery_tasks.process_expired_verifications_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def process_expired_verifications_task(self):
        """处理过期认证 - Celery任务包装"""
        start_time = time.time()
        task_name = 'process_expired_verifications_task'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            process_expired_verifications(db)
            duration = time.time() - start_time
            logger.info(f"✅ 处理过期认证完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "message": "Processed expired verifications"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"处理过期认证失败: {e}", exc_info=True)
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
        default_retry_delay=60
    )
    def update_all_users_statistics_task(self):
        """更新所有用户统计信息 - Celery任务包装（带分布式锁，避免叠跑）"""
        lock_key = "scheduled:update_all_users_statistics:lock"
        lock_ttl = 600  # 10分钟（任务执行周期）
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.warning("更新用户统计信息任务正在执行中，跳过本次调度")
            return {"status": "skipped", "reason": "previous_task_running"}
        
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
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
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
    
    @celery_app.task(
        name='app.celery_tasks.sync_forum_view_counts_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300  # 重试延迟5分钟
    )
    def sync_forum_view_counts_task(self):
        """同步论坛帖子浏览数从 Redis 到数据库 - Celery任务包装（每5分钟执行）"""
        logger.info("🔄 开始执行同步论坛浏览量任务")
        start_time = time.time()
        task_name = 'sync_forum_view_counts_task'
        lock_key = 'forum:sync_view_counts:lock'
        
        # 获取分布式锁，防止多实例重复执行
        if not get_redis_distributed_lock(lock_key, lock_ttl=600):  # 锁10分钟
            logger.warning("⚠️ 同步论坛浏览数任务已在其他实例执行，跳过本次执行")
            return {"status": "skipped", "message": "Task already running in another instance"}
        
        try:
            from app.redis_cache import get_redis_client
            from app.database import SessionLocal
            from app.models import ForumPost
            from sqlalchemy import update
            
            redis_client = get_redis_client()
            if not redis_client:
                logger.warning("Redis 不可用，无法同步论坛浏览数")
                return {"status": "skipped", "message": "Redis not available"}
            
            db = SessionLocal()
            try:
                # 获取所有论坛浏览数的 Redis key（使用 SCAN 替代 KEYS）
                from app.redis_utils import scan_keys
                pattern = "forum:post:view_count:*"
                keys = scan_keys(redis_client, pattern)
                
                if not keys:
                    logger.info("ℹ️ 没有需要同步的论坛浏览数（Redis 中没有 forum:post:view_count:* keys）")
                    return {"status": "success", "message": "No view counts to sync", "synced_count": 0}
                
                synced_count = 0
                failed_count = 0
                synced_keys = []  # 记录成功同步的 keys，用于后续删除
                
                for key in keys:
                    try:
                        # 处理 bytes 类型的 key（Redis 二进制模式）
                        if isinstance(key, bytes):
                            key_str = key.decode('utf-8')
                        else:
                            key_str = str(key)
                        
                        # 从 key 中提取 post_id
                        post_id = int(key_str.split(":")[-1])
                        
                        # 获取 Redis 中的增量
                        redis_increment = redis_client.get(key)
                        if redis_increment:
                            # 处理 bytes 类型的值
                            if isinstance(redis_increment, bytes):
                                increment = int(redis_increment.decode('utf-8'))
                            else:
                                increment = int(redis_increment)
                            
                            if increment > 0:
                                # 更新数据库中的浏览数
                                db.execute(
                                    update(ForumPost)
                                    .where(ForumPost.id == post_id)
                                    .values(view_count=ForumPost.view_count + increment)
                                )
                                synced_count += 1
                                synced_keys.append(key)  # 记录成功同步的 key
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理浏览数 key {key} 时出错: {e}")
                        failed_count += 1
                        continue
                    except Exception as e:
                        logger.error(f"同步帖子 {key} 浏览数失败: {e}")
                        failed_count += 1
                        continue
                
                # 先提交数据库事务
                db.commit()
                
                # 数据库提交成功后，删除已同步的 Redis keys
                deleted_count = 0
                for key in synced_keys:
                    try:
                        redis_client.delete(key)
                        deleted_count += 1
                    except Exception as e:
                        logger.warning(f"删除 Redis key {key} 失败: {e}")
                        # 继续处理其他 key
                
                duration = time.time() - start_time
                if failed_count > 0:
                    logger.warning(f"✅ 同步论坛浏览数完成，同步了 {synced_count} 个帖子，失败 {failed_count} 个 (耗时: {duration:.2f}秒)")
                else:
                    logger.info(f"✅ 同步论坛浏览数完成，同步了 {synced_count} 个帖子 (耗时: {duration:.2f}秒)")
                _record_task_metrics(task_name, "success", duration)
                return {
                    "status": "success", 
                    "message": f"Synced {synced_count} post view counts", 
                    "synced_count": synced_count,
                    "failed_count": failed_count,
                    "deleted_keys": deleted_count
                }
            finally:
                db.close()
                # 释放分布式锁
                release_redis_distributed_lock(lock_key)
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"同步论坛浏览数失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 释放分布式锁
            release_redis_distributed_lock(lock_key)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise

    @celery_app.task(
        name='app.celery_tasks.sync_task_view_counts_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300
    )
    def sync_task_view_counts_task(self):
        """同步任务浏览数从 Redis 到数据库 - Celery任务包装（每5分钟执行）"""
        logger.info("🔄 开始执行同步任务浏览量任务")
        start_time = time.time()
        task_name = 'sync_task_view_counts_task'
        lock_key = 'task:sync_view_counts:lock'

        if not get_redis_distributed_lock(lock_key, lock_ttl=600):
            logger.warning("⚠️ 同步任务浏览数已在其他实例执行，跳过")
            return {"status": "skipped"}

        try:
            from app.redis_cache import get_redis_client
            from app.database import SessionLocal
            from app.models import Task
            from sqlalchemy import update

            redis_client = get_redis_client()
            if not redis_client:
                return {"status": "skipped", "message": "Redis not available"}

            db = SessionLocal()
            try:
                from app.redis_utils import scan_keys
                keys = scan_keys(redis_client, "task:view_count:*")
                if not keys:
                    return {"status": "success", "synced_count": 0}

                synced_count = 0
                synced_keys = []
                for key in keys:
                    try:
                        key_str = key.decode('utf-8') if isinstance(key, bytes) else str(key)
                        task_id = int(key_str.split(":")[-1])
                        raw = redis_client.get(key)
                        if raw:
                            increment = int(raw.decode('utf-8') if isinstance(raw, bytes) else raw)
                            if increment > 0:
                                db.execute(
                                    update(Task)
                                    .where(Task.id == task_id)
                                    .values(view_count=Task.view_count + increment)
                                )
                                synced_count += 1
                                synced_keys.append(key)
                    except Exception as e:
                        logger.warning(f"同步任务浏览数 key {key} 失败: {e}")

                db.commit()

                for key in synced_keys:
                    try:
                        redis_client.delete(key)
                    except Exception:
                        pass

                duration = time.time() - start_time
                logger.info(f"✅ 同步任务浏览数完成，同步了 {synced_count} 个任务 (耗时: {duration:.2f}秒)")
                _record_task_metrics(task_name, "success", duration)
                return {"status": "success", "synced_count": synced_count}
            finally:
                db.close()
                release_redis_distributed_lock(lock_key)
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"同步任务浏览数失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            release_redis_distributed_lock(lock_key)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise

    @celery_app.task(
        name='app.celery_tasks.sync_leaderboard_view_counts_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300  # 重试延迟5分钟
    )
    def sync_leaderboard_view_counts_task(self):
        """同步榜单浏览数从 Redis 到数据库 - Celery任务包装（每5分钟执行）"""
        logger.info("🔄 开始执行同步榜单浏览量任务")
        start_time = time.time()
        task_name = 'sync_leaderboard_view_counts_task'
        lock_key = 'leaderboard:sync_view_counts:lock'
        
        # 获取分布式锁，防止多实例重复执行
        if not get_redis_distributed_lock(lock_key, lock_ttl=600):  # 锁10分钟
            logger.warning("⚠️ 同步榜单浏览数任务已在其他实例执行，跳过本次执行")
            return {"status": "skipped", "message": "Task already running in another instance"}
        
        try:
            from app.redis_cache import get_redis_client
            from app.database import SessionLocal
            from app.models import CustomLeaderboard
            from sqlalchemy import update
            
            redis_client = get_redis_client()
            if not redis_client:
                logger.warning("Redis 不可用，无法同步榜单浏览数")
                return {"status": "skipped", "message": "Redis not available"}
            
            db = SessionLocal()
            try:
                # 获取所有榜单浏览数的 Redis key（使用 SCAN 替代 KEYS）
                from app.redis_utils import scan_keys
                pattern = "leaderboard:view_count:*"
                keys = scan_keys(redis_client, pattern)
                
                if not keys:
                    logger.info("ℹ️ 没有需要同步的榜单浏览数（Redis 中没有 leaderboard:view_count:* keys）")
                    return {"status": "success", "message": "No view counts to sync", "synced_count": 0}
                
                synced_count = 0
                failed_count = 0
                synced_keys = []  # 记录成功同步的 keys，用于后续删除
                
                for key in keys:
                    try:
                        # 处理 bytes 类型的 key（Redis 二进制模式）
                        if isinstance(key, bytes):
                            key_str = key.decode('utf-8')
                        else:
                            key_str = str(key)
                        
                        # 从 key 中提取 leaderboard_id
                        leaderboard_id = int(key_str.split(":")[-1])
                        
                        # 获取 Redis 中的增量
                        redis_increment = redis_client.get(key)
                        if redis_increment:
                            # 处理 bytes 类型的值
                            if isinstance(redis_increment, bytes):
                                increment = int(redis_increment.decode('utf-8'))
                            else:
                                increment = int(redis_increment)
                            
                            if increment > 0:
                                # 更新数据库中的浏览数
                                db.execute(
                                    update(CustomLeaderboard)
                                    .where(CustomLeaderboard.id == leaderboard_id)
                                    .values(view_count=CustomLeaderboard.view_count + increment)
                                )
                                synced_count += 1
                                synced_keys.append(key)  # 记录成功同步的 key
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理榜单浏览数 key {key} 时出错: {e}")
                        failed_count += 1
                        continue
                    except Exception as e:
                        logger.error(f"同步榜单 {key} 浏览数失败: {e}")
                        failed_count += 1
                        continue
                
                # 先提交数据库事务
                db.commit()
                
                # 数据库提交成功后，删除已同步的 Redis keys
                deleted_count = 0
                for key in synced_keys:
                    try:
                        redis_client.delete(key)
                        deleted_count += 1
                    except Exception as e:
                        logger.warning(f"删除 Redis key {key} 失败: {e}")
                        # 继续处理其他 key
                
                duration = time.time() - start_time
                if failed_count > 0:
                    logger.warning(f"✅ 同步榜单浏览数完成，同步了 {synced_count} 个榜单，失败 {failed_count} 个 (耗时: {duration:.2f}秒)")
                else:
                    logger.info(f"✅ 同步榜单浏览数完成，同步了 {synced_count} 个榜单 (耗时: {duration:.2f}秒)")
                _record_task_metrics(task_name, "success", duration)
                return {
                    "status": "success", 
                    "message": f"Synced {synced_count} leaderboard view counts", 
                    "synced_count": synced_count,
                    "failed_count": failed_count,
                    "deleted_keys": deleted_count
                }
            finally:
                db.close()
                # 释放分布式锁
                release_redis_distributed_lock(lock_key)
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"同步榜单浏览数任务失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            # 释放分布式锁
            release_redis_distributed_lock(lock_key)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise

    @celery_app.task(
        name='app.celery_tasks.check_expired_vip_subscriptions_task',
        bind=True,
        max_retries=3,
        default_retry_delay=300  # 重试延迟5分钟
    )
    def check_expired_vip_subscriptions_task(self):
        """检查并更新过期的VIP订阅 - Celery任务包装（每1小时执行）"""
        start_time = time.time()
        task_name = 'check_expired_vip_subscriptions_task'
        db = SessionLocal()
        try:
            updated_count = check_and_update_expired_subscriptions(db)
            duration = time.time() - start_time
            logger.info(f"VIP订阅过期检查完成: 更新了 {updated_count} 个过期订阅 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {
                "status": "success",
                "message": f"Updated {updated_count} expired subscriptions",
                "updated_count": updated_count
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"VIP订阅过期检查失败: {e}", exc_info=True)
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


if CELERY_AVAILABLE:
    @celery_app.task(name='app.celery_tasks.cleanup_nearby_task_pushes_task', bind=True, max_retries=2)
    def cleanup_nearby_task_pushes_task(self):
        """清理30天前的附近任务推送记录"""
        task_name = "cleanup_nearby_task_pushes"
        lock_key = f"celery_lock:{task_name}"
        lock_value = get_redis_distributed_lock(lock_key, expire_seconds=300)
        if not lock_value:
            return {"status": "skipped", "reason": "lock_held"}

        import time
        start_time = time.time()
        db = SessionLocal()
        try:
            from app.services.nearby_task_service import cleanup_old_pushes
            deleted = cleanup_old_pushes(db, days=30)
            db.commit()
            duration = time.time() - start_time
            logger.info(f"附近推送记录清理完成: 删除 {deleted} 条 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "deleted": deleted}
        except Exception as e:
            db.rollback()
            duration = time.time() - start_time
            logger.error(f"附近推送记录清理失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            raise self.retry(exc=e, countdown=120)
        finally:
            db.close()
            release_redis_distributed_lock(lock_key, lock_value)


    # ========== 用户画像系统任务 ==========

    @celery_app.task(bind=True, max_retries=2, default_retry_delay=120)
    def nightly_demand_inference_task(self):
        """需求画像夜间推断：更新活跃用户的需求画像"""
        task_name = "nightly_demand_inference"
        lock_key = f"celery_task:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            logger.debug(f"{task_name}: 已有实例在运行，跳过")
            return {"status": "skipped", "reason": "already_running"}

        start_time = time.time()
        db = SessionLocal()
        try:
            from app.services.demand_inference import batch_infer_demands
            results = batch_infer_demands(db, limit=500)
            db.commit()
            duration = time.time() - start_time
            logger.info(f"需求画像推断完成: 成功 {results['succeeded']}/{results['total']} 个用户, 失败 {results['failed']} (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", **results}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"需求画像推断失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)


    @celery_app.task(bind=True, max_retries=2, default_retry_delay=120)
    def weekly_reliability_calibration_task(self):
        """可靠度分数周校准：全量重算修正增量更新的累积误差"""
        task_name = "weekly_reliability_calibration"
        lock_key = f"celery_task:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            logger.debug(f"{task_name}: 已有实例在运行，跳过")
            return {"status": "skipped", "reason": "already_running"}

        start_time = time.time()
        db = SessionLocal()
        try:
            from app.services.reliability_calculator import recalculate_all_reliability
            recalculate_all_reliability(db, limit=500)
            db.commit()
            duration = time.time() - start_time
            logger.info(f"可靠度校准完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success"}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"可靠度校准失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ==================== 钱包 pending 交易超时清理 ====================

    @celery_app.task(
        name='app.celery_tasks.cleanup_stale_pending_wallet_txs_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def cleanup_stale_pending_wallet_txs_task(self):
        """清理超时的 pending 钱包支付交易（防止余额被永久锁定）

        扫描 wallet_transactions 中 type='payment' AND status='pending'
        且 created_at 超过 30 分钟的记录，逐条 reverse。
        """
        start_time = time.time()
        task_name = 'cleanup_stale_pending_wallet_txs_task'
        lock_key = f"celery_lock:{task_name}"

        if not get_redis_distributed_lock(lock_key, lock_ttl=300):
            logger.info(f"跳过 {task_name}：另一实例正在执行")
            return {"status": "skipped", "message": "lock held"}

        db = SessionLocal()
        try:
            from datetime import datetime, timedelta, timezone
            from app.wallet_models import WalletTransaction
            from app.wallet_service import reverse_debit

            cutoff = datetime.now(timezone.utc) - timedelta(minutes=30)
            # 先收集需要处理的 tx 信息到 list，避免 commit 后 ORM 对象 stale
            stale_rows = (
                db.query(
                    WalletTransaction.id,
                    WalletTransaction.user_id,
                    WalletTransaction.amount,
                    WalletTransaction.currency,
                    WalletTransaction.created_at,
                )
                .filter(
                    WalletTransaction.type == "payment",
                    WalletTransaction.status == "pending",
                    WalletTransaction.created_at < cutoff,
                )
                .limit(100)  # 每次最多处理 100 条，避免长事务
                .all()
            )

            reversed_count = 0
            for row in stale_rows:
                tx_id, user_id, amount_raw, currency, created_at = row
                try:
                    amount = abs(amount_raw)
                    reverse_debit(db, tx_id, user_id, amount, currency=currency)
                    db.commit()
                    reversed_count += 1
                    logger.info(
                        f"✅ 已 reverse 超时 pending wallet tx: "
                        f"id={tx_id}, user={user_id}, amount={amount}, "
                        f"created_at={created_at}"
                    )
                except Exception as e:
                    db.rollback()
                    logger.error(
                        f"❌ reverse pending wallet tx 失败: "
                        f"id={tx_id}, error={e}"
                    )

            duration = time.time() - start_time
            logger.info(
                f"钱包 pending 清理完成: reversed={reversed_count}/{len(stale_rows)} "
                f"(耗时: {duration:.2f}秒)"
            )
            _record_task_metrics(task_name, "success", duration)
            return {
                "status": "success",
                "reversed": reversed_count,
                "total_stale": len(stale_rows),
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"钱包 pending 清理失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ==================== 钱包提现 pending 对账 ====================

    @celery_app.task(
        name='app.celery_tasks.reconcile_pending_withdrawals_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def reconcile_pending_withdrawals_task(self):
        """对账超时的 pending 提现交易

        扫描 wallet_transactions 中 type='withdrawal' AND status='pending'
        且 created_at 超过 15 分钟的记录，通过 Stripe API 查询 Transfer 状态：
        - Transfer succeeded → complete_withdrawal
        - Transfer failed/not found → fail_withdrawal（退还余额）
        """
        start_time = time.time()
        task_name = 'reconcile_pending_withdrawals_task'
        lock_key = f"celery_lock:{task_name}"

        if not get_redis_distributed_lock(lock_key, lock_ttl=300):
            logger.info(f"跳过 {task_name}：另一实例正在执行")
            return {"status": "skipped", "message": "lock held"}

        db = SessionLocal()
        try:
            import stripe
            from datetime import datetime, timedelta, timezone
            from app.wallet_models import WalletTransaction
            from app.wallet_service import complete_withdrawal, fail_withdrawal

            cutoff = datetime.now(timezone.utc) - timedelta(minutes=15)
            pending_rows = (
                db.query(
                    WalletTransaction.id,
                    WalletTransaction.user_id,
                    WalletTransaction.amount,
                    WalletTransaction.currency,
                    WalletTransaction.related_id,  # Stripe transfer ID (if already set)
                    WalletTransaction.created_at,
                )
                .filter(
                    WalletTransaction.type == "withdrawal",
                    WalletTransaction.status == "pending",
                    WalletTransaction.created_at < cutoff,
                )
                .limit(50)
                .all()
            )

            completed_count = 0
            failed_count = 0
            for row in pending_rows:
                tx_id, user_id, amount_raw, currency, related_id, created_at = row
                try:
                    # 如果 related_id 已经是 Transfer ID，直接查询
                    if related_id and related_id.startswith("tr_"):
                        transfer = stripe.Transfer.retrieve(related_id)
                    else:
                        # 没有 Transfer ID，按创建时间范围搜索 Stripe Transfer
                        transfers = stripe.Transfer.list(
                            limit=20,
                            created={"gte": int(created_at.timestamp())},
                        )
                        transfer = None
                        for t in transfers.data:
                            if t.metadata.get("wallet_tx_id") == str(tx_id):
                                transfer = t
                                break

                    if transfer and not transfer.get("reversed", False):
                        # Transfer 存在且未被 reverse → 确认提现
                        # 幂等检查：重新查 DB 确认仍是 pending
                        from app.wallet_models import WalletTransaction as _WTCheck
                        _fresh = db.query(_WTCheck).filter(_WTCheck.id == tx_id).first()
                        if _fresh and _fresh.status == "pending":
                            complete_withdrawal(db, tx_id, transfer.id)
                            db.commit()
                            completed_count += 1
                            logger.info(
                                f"✅ 对账完成提现: tx_id={tx_id}, transfer_id={transfer.id}"
                            )
                    else:
                        # Transfer 不存在或已 reverse，超时 → 退还余额
                        # 仅对超过 30 分钟的进行 fail（给 webhook 充足时间）
                        if created_at < datetime.now(timezone.utc) - timedelta(minutes=30):
                            refund_amount = abs(amount_raw)
                            fail_withdrawal(db, tx_id, user_id, refund_amount, currency=currency)
                            db.commit()
                            failed_count += 1
                            logger.info(
                                f"✅ 对账退还提现: tx_id={tx_id}, amount={refund_amount}"
                            )
                except Exception as e:
                    db.rollback()
                    logger.error(f"❌ 对账提现失败: tx_id={tx_id}, error={e}")

            duration = time.time() - start_time
            logger.info(
                f"提现对账完成: completed={completed_count}, failed={failed_count}, "
                f"total={len(pending_rows)} (耗时: {duration:.2f}秒)"
            )
            _record_task_metrics(task_name, "success", duration)
            return {
                "status": "success",
                "completed": completed_count,
                "failed": failed_count,
                "total": len(pending_rows),
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"提现对账任务失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            try:
                db.rollback()
            except Exception:
                pass
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ═══════════════════════════════════════════════════════════════════
    # 通用 Redis → DB 浏览数同步辅助函数（DECRBY 模式，防数据丢失）
    # ═══════════════════════════════════════════════════════════════════
    def _sync_view_counts_generic(model_class, key_pattern: str, entity_name: str, lock_key: str, self_task):
        """
        通用浏览数同步：Redis 增量 → DB view_count，使用 DECRBY 而非 DELETE。
        """
        if not get_redis_distributed_lock(lock_key, lock_ttl=600):
            return {"status": "skipped", "message": "Task already running"}

        start_time = time.time()
        task_name = f'sync_{entity_name}_view_counts_task'
        try:
            from app.redis_cache import get_redis_client
            from app.redis_utils import scan_keys
            from sqlalchemy import update

            redis_client = get_redis_client()
            if not redis_client:
                return {"status": "skipped", "message": "Redis not available"}

            keys = scan_keys(redis_client, key_pattern)
            if not keys:
                return {"status": "success", "synced_count": 0}

            db = SessionLocal()
            try:
                synced_count = 0
                increments = []
                for key in keys:
                    try:
                        key_str = key.decode('utf-8') if isinstance(key, bytes) else str(key)
                        entity_id = int(key_str.split(":")[-1])
                        raw = redis_client.get(key)
                        if raw:
                            increment = int(raw.decode('utf-8') if isinstance(raw, bytes) else raw)
                            if increment > 0:
                                increments.append((key, entity_id, increment))
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理{entity_name}浏览数 key {key} 时出错: {e}")
                        continue

                for key, entity_id, increment in increments:
                    db.execute(
                        update(model_class)
                        .where(model_class.id == entity_id)
                        .values(view_count=model_class.view_count + increment)
                    )
                    synced_count += 1

                db.commit()

                # DECRBY 减去已同步增量，剩余 <=0 则删 key
                for key, entity_id, increment in increments:
                    try:
                        remaining = redis_client.decrby(key, increment)
                        if remaining is not None and remaining <= 0:
                            redis_client.delete(key)
                    except Exception:
                        pass

                duration = time.time() - start_time
                _record_task_metrics(task_name, "success", duration)
                if synced_count > 0:
                    logger.info(f"同步{entity_name}浏览数完成，同步了 {synced_count} 个 (耗时: {duration:.2f}秒)")
                return {"status": "success", "synced_count": synced_count}
            finally:
                db.close()
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"同步{entity_name}浏览数失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self_task.request.retries < self_task.max_retries:
                raise self_task.retry(exc=e)
            raise
        finally:
            release_redis_distributed_lock(lock_key)

    # ═══════════════════════════════════════════════════════════════════
    # 14 个新增 Celery 定时任务
    # ═══════════════════════════════════════════════════════════════════

    # ── 1. send_auto_transfer_reminders_task (每1小时) ──
    @celery_app.task(name='app.celery_tasks.send_auto_transfer_reminders_task', bind=True, max_retries=2, default_retry_delay=60)
    def send_auto_transfer_reminders_task(self):
        """发送自动转账提醒 - 每1小时"""
        task_name = 'send_auto_transfer_reminders_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import send_auto_transfer_reminders
            send_auto_transfer_reminders(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"发送自动转账提醒失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 2. auto_transfer_expired_tasks_task (每15分钟) ──
    @celery_app.task(name='app.celery_tasks.auto_transfer_expired_tasks_task', bind=True, max_retries=2, default_retry_delay=60)
    def auto_transfer_expired_tasks_task(self):
        """自动转账过期任务 - 每15分钟"""
        task_name = 'auto_transfer_expired_tasks_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import auto_transfer_expired_tasks
            auto_transfer_expired_tasks(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"自动转账过期任务失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 3. auto_confirm_expired_tasks_task (每15分钟) ──
    @celery_app.task(name='app.celery_tasks.auto_confirm_expired_tasks_task', bind=True, max_retries=2, default_retry_delay=60)
    def auto_confirm_expired_tasks_task(self):
        """自动确认过期任务 - 每15分钟"""
        task_name = 'auto_confirm_expired_tasks_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import auto_confirm_expired_tasks
            auto_confirm_expired_tasks(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"自动确认过期任务失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 4. send_confirmation_reminders_task (每15分钟) ──
    @celery_app.task(name='app.celery_tasks.send_confirmation_reminders_task', bind=True, max_retries=2, default_retry_delay=60)
    def send_confirmation_reminders_task(self):
        """发送确认提醒 - 每15分钟"""
        task_name = 'send_confirmation_reminders_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import send_confirmation_reminders
            send_confirmation_reminders(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"发送确认提醒失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 5. sync_activity_view_counts_task (每5分钟) ──
    @celery_app.task(name='app.celery_tasks.sync_activity_view_counts_task', bind=True, max_retries=2, default_retry_delay=300)
    def sync_activity_view_counts_task(self):
        """同步活动浏览数从 Redis 到数据库 - 每5分钟"""
        from app.models import Activity
        return _sync_view_counts_generic(
            model_class=Activity,
            key_pattern="activity:view_count:*",
            entity_name="activity",
            lock_key='activity:sync_view_counts:lock',
            self_task=self,
        )

    # ── 6. sync_forum_category_view_counts_task (每5分钟) ──
    @celery_app.task(name='app.celery_tasks.sync_forum_category_view_counts_task', bind=True, max_retries=2, default_retry_delay=300)
    def sync_forum_category_view_counts_task(self):
        """同步论坛分类浏览数从 Redis 到数据库 - 每5分钟"""
        from app.models import ForumCategory
        return _sync_view_counts_generic(
            model_class=ForumCategory,
            key_pattern="forum:category:view_count:*",
            entity_name="forum_category",
            lock_key='forum_category:sync_view_counts:lock',
            self_task=self,
        )

    # ── 7. sync_flea_market_view_counts_task (每5分钟) ──
    @celery_app.task(name='app.celery_tasks.sync_flea_market_view_counts_task', bind=True, max_retries=2, default_retry_delay=300)
    def sync_flea_market_view_counts_task(self):
        """同步跳蚤市场浏览数从 Redis 到数据库 - 每5分钟"""
        from app.models import FleaMarketItem
        return _sync_view_counts_generic(
            model_class=FleaMarketItem,
            key_pattern="flea_market:view_count:*",
            entity_name="flea_market",
            lock_key='flea_market:sync_view_counts:lock',
            self_task=self,
        )

    # ── 8. sync_service_view_counts_task (每5分钟) ──
    @celery_app.task(name='app.celery_tasks.sync_service_view_counts_task', bind=True, max_retries=2, default_retry_delay=300)
    def sync_service_view_counts_task(self):
        """同步服务浏览数从 Redis 到数据库 - 每5分钟"""
        from app.models import TaskExpertService
        return _sync_view_counts_generic(
            model_class=TaskExpertService,
            key_pattern="service:view_count:*",
            entity_name="service",
            lock_key='service:sync_view_counts:lock',
            self_task=self,
        )

    # ── 9. compute_trending_searches_task (每1小时) ──
    @celery_app.task(name='app.celery_tasks.compute_trending_searches_task', bind=True, max_retries=2, default_retry_delay=60)
    def compute_trending_searches_task(self):
        """计算热门搜索 - 每1小时"""
        task_name = 'compute_trending_searches_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.trending_search import compute_trending
            compute_trending(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"计算热门搜索失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 10. compute_skill_category_counts_task (每1小时) ──
    @celery_app.task(name='app.celery_tasks.compute_skill_category_counts_task', bind=True, max_retries=2, default_retry_delay=60)
    def compute_skill_category_counts_task(self):
        """计算技能分类计数 - 每1小时"""
        task_name = 'compute_skill_category_counts_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from sqlalchemy import func as sa_func
            from app import models

            skill_categories = db.query(models.ForumCategory).filter(
                models.ForumCategory.skill_type.isnot(None),
                models.ForumCategory.skill_type != '',
            ).all()
            if not skill_categories:
                return {"status": "success", "message": "No skill categories"}

            skill_types = [cat.skill_type for cat in skill_categories]

            svc_rows = db.query(
                models.TaskExpertService.category,
                sa_func.count(models.TaskExpertService.id),
            ).filter(
                models.TaskExpertService.category.in_(skill_types),
                models.TaskExpertService.status == 'active',
            ).group_by(models.TaskExpertService.category).all()
            svc_map = {row[0]: row[1] for row in svc_rows}

            tsk_rows = db.query(
                models.Task.task_type,
                sa_func.count(models.Task.id),
            ).filter(
                models.Task.task_type.in_(skill_types),
                models.Task.status == 'open',
            ).group_by(models.Task.task_type).all()
            tsk_map = {row[0]: row[1] for row in tsk_rows}

            for cat in skill_categories:
                cat.service_count = svc_map.get(cat.skill_type, 0)
                cat.task_count = tsk_map.get(cat.skill_type, 0)
            db.commit()
            return {"status": "success", "updated": len(skill_categories)}
        except Exception as e:
            db.rollback()
            logger.error(f"计算技能分类计数失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 11. official_activity_auto_draw_task (每60秒) ──
    @celery_app.task(name='app.celery_tasks.official_activity_auto_draw_task', bind=True, max_retries=2, default_retry_delay=60)
    def official_activity_auto_draw_task(self):
        """官方活动自动抽奖 - 每60秒"""
        task_name = 'official_activity_auto_draw_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=120):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.official_draw_task import run_auto_draws
            run_auto_draws(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"官方活动自动抽奖失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 12. check_overdue_rentals_task (每1小时) ──
    @celery_app.task(name='app.celery_tasks.check_overdue_rentals_task', bind=True, max_retries=2, default_retry_delay=60)
    def check_overdue_rentals_task(self):
        """检查逾期租赁 - 每1小时"""
        task_name = 'check_overdue_rentals_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.rental_scheduled_tasks import check_overdue_rentals
            check_overdue_rentals(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"检查逾期租赁失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 13. check_pending_return_timeout_task (每6小时) ──
    @celery_app.task(name='app.celery_tasks.check_pending_return_timeout_task', bind=True, max_retries=2, default_retry_delay=60)
    def check_pending_return_timeout_task(self):
        """检查待归还超时 - 每6小时"""
        task_name = 'check_pending_return_timeout_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=21600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.rental_scheduled_tasks import check_pending_return_timeout
            check_pending_return_timeout(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"检查待归还超时失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 14. check_expired_rental_approvals_task (每30分钟) ──
    @celery_app.task(name='app.celery_tasks.check_expired_rental_approvals_task', bind=True, max_retries=2, default_retry_delay=60)
    def check_expired_rental_approvals_task(self):
        """检查过期租赁审批 - 每30分钟"""
        task_name = 'check_expired_rental_approvals_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.rental_scheduled_tasks import check_expired_rental_approvals
            check_expired_rental_approvals(db)
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            logger.error(f"检查过期租赁审批失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)


# ── warn_long_running_team_tasks_task (每天) ──
# spec §3.4a — 接近 Stripe 90 天 Transfer 时效的团队任务提醒 owner
if CELERY_AVAILABLE:
    @celery_app.task(name='app.celery_tasks.warn_long_running_team_tasks_task', bind=True, max_retries=2, default_retry_delay=300)
    def warn_long_running_team_tasks_task(self):
        """每天扫一次,通知 owner 接近 90 天 Transfer 时效的 in-flight 团队任务. spec §3.4a"""
        task_name = 'warn_long_running_team_tasks_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=86400):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from datetime import datetime, timedelta
            from app import models, crud

            threshold = datetime.utcnow() - timedelta(days=60)
            tasks = db.query(models.Task).filter(
                models.Task.taker_expert_id.is_not(None),
                models.Task.status.in_(['in_progress', 'disputed']),
                models.Task.payment_completed_at < threshold,
            ).all()
            notified = 0
            for t in tasks:
                try:
                    crud.create_notification(
                        db, str(t.taker_id),
                        "expert_transfer_window_warning",
                        "款项接近时效",
                        f"任务 #{t.id} 已超过 60 天未完成，请尽快完成，否则款项无法 Transfer",
                        related_id=str(t.id),
                        auto_commit=False,
                    )
                    notified += 1
                except Exception as e:
                    logger.error(f"通知 taker 任务 {t.id} 失败: {e}")
            db.commit()
            logger.info(f"warn_long_running_team_tasks_task: scanned, notified {notified} tasks")
            return {"status": "success", "notified": notified}
        except Exception as e:
            db.rollback()
            logger.error(f"团队任务时效警告任务失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 套餐过期扫描 (每 15 分钟) ──
    # 没有这个任务,过期套餐会永远停在 status='active',资金永远滞留 pending transfer。
    @celery_app.task(name='app.celery_tasks.check_expired_packages_task', bind=True, max_retries=2, default_retry_delay=60)
    def check_expired_packages_task(self):
        """套餐过期扫描: 把 expires_at < now 的 active 套餐标 expired 并触发结算。"""
        task_name = 'check_expired_packages_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=1800):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import check_expired_packages
            result = check_expired_packages(db)
            return {"status": "success", **result}
        except Exception as e:
            db.rollback()
            logger.error(f"套餐过期扫描失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

    # ── 套餐过期提醒 (每小时) ──
    @celery_app.task(name='app.celery_tasks.send_package_expiry_reminders_task', bind=True, max_retries=2, default_retry_delay=60)
    def send_package_expiry_reminders_task(self):
        """套餐过期提醒: 到期 7d/3d/1d 前给买家发通知。"""
        task_name = 'send_package_expiry_reminders_task'
        lock_key = f"celery_lock:{task_name}"
        if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
            return {"status": "skipped"}
        db = SessionLocal()
        try:
            from app.scheduled_tasks import send_package_expiry_reminders
            result = send_package_expiry_reminders(db)
            return {"status": "success", **result}
        except Exception as e:
            db.rollback()
            logger.error(f"套餐过期提醒失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
            release_redis_distributed_lock(lock_key)

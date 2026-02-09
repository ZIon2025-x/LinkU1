"""
细粒度定时任务调度器
支持不同任务使用不同的执行频率
"""
import threading
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Callable, Optional
from app.state import is_app_shutting_down
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)


class TaskScheduler:
    """细粒度任务调度器"""
    
    def __init__(self):
        self.tasks: Dict[str, Dict] = {}
        self._shutdown_flag = False
        self._thread: Optional[threading.Thread] = None
    
    def register_task(
        self,
        name: str,
        func: Callable,
        interval_seconds: int,
        description: str = ""
    ):
        """
        注册定时任务
        
        Args:
            name: 任务名称
            func: 要执行的函数
            interval_seconds: 执行间隔（秒）
            description: 任务描述
        """
        self.tasks[name] = {
            'func': func,
            'interval': interval_seconds,
            'last_run': None,
            'description': description,
            'run_count': 0,
            'error_count': 0
        }
        logger.info(f"注册定时任务: {name} (间隔: {interval_seconds}秒)")
    
    def _should_run(self, task_name: str) -> bool:
        """检查任务是否应该运行"""
        if is_app_shutting_down():
            return False
        
        task = self.tasks[task_name]
        if task['last_run'] is None:
            return True
        
        elapsed = (get_utc_time() - task['last_run']).total_seconds()
        return elapsed >= task['interval']
    
    def _run_task(self, task_name: str):
        """执行单个任务"""
        task = self.tasks[task_name]
        start_time = time.time()
        try:
            task['func']()
            duration = time.time() - start_time
            task['last_run'] = get_utc_time()
            task['run_count'] += 1
            logger.debug(f"任务 {task_name} 执行完成 (耗时: {duration:.2f}秒)")
            
            # 记录 Prometheus 指标
            try:
                from app.metrics import record_scheduled_task
                record_scheduled_task(task_name, "success", duration)
            except Exception:
                pass
        except Exception as e:
            duration = time.time() - start_time
            task['error_count'] += 1
            logger.error(f"任务 {task_name} 执行失败: {e}", exc_info=True)
            
            # 记录 Prometheus 指标
            try:
                from app.metrics import record_scheduled_task
                record_scheduled_task(task_name, "error", duration)
            except Exception:
                pass
    
    def run(self):
        """运行调度器主循环"""
        logger.info("定时任务调度器已启动")
        
        # 计算最小间隔（用于主循环）
        min_interval = min(
            (task['interval'] for task in self.tasks.values()),
            default=60
        )
        # 主循环使用最小间隔的一半，确保及时检查
        check_interval = max(min_interval // 2, 10)
        
        while not self._shutdown_flag and not is_app_shutting_down():
            try:
                # 检查所有任务
                for task_name in list(self.tasks.keys()):
                    if self._should_run(task_name):
                        self._run_task(task_name)
                
                # 等待下次检查
                time.sleep(check_interval)
            except Exception as e:
                logger.error(f"调度器循环出错: {e}", exc_info=True)
                time.sleep(check_interval)
        
        logger.info("定时任务调度器已停止")
    
    def start(self):
        """启动调度器线程"""
        if self._thread and self._thread.is_alive():
            logger.warning("调度器已在运行")
            return
        
        self._shutdown_flag = False
        self._thread = threading.Thread(target=self.run, daemon=True)
        self._thread.start()
        logger.info("定时任务调度器线程已启动")
    
    def stop(self):
        """停止调度器"""
        self._shutdown_flag = True
        if self._thread:
            self._thread.join(timeout=5)
        logger.info("定时任务调度器已停止")
    
    def get_status(self) -> Dict:
        """获取调度器状态"""
        return {
            'running': self._thread.is_alive() if self._thread else False,
            'tasks': {
                name: {
                    'description': task['description'],
                    'interval': task['interval'],
                    'last_run': format_iso_utc(task['last_run']) if task['last_run'] else None,
                    'run_count': task['run_count'],
                    'error_count': task['error_count']
                }
                for name, task in self.tasks.items()
            }
        }


# 全局调度器实例
_scheduler: Optional[TaskScheduler] = None


def get_scheduler() -> TaskScheduler:
    """获取全局调度器实例"""
    global _scheduler
    if _scheduler is None:
        _scheduler = TaskScheduler()
    return _scheduler


def init_scheduler():
    """初始化并注册所有定时任务（与 Celery Beat 完全对齐）"""
    from app.scheduled_tasks import (
        check_expired_coupons,
        check_expired_invitation_codes,
        check_expired_points,
        check_and_end_activities_sync,
        auto_complete_expired_time_slot_tasks,
        process_expired_verifications,
        check_expired_payment_tasks,
        send_expiry_reminders,
        send_expiry_notifications
    )
    from app.customer_service_tasks import (
        process_customer_service_queue,
        auto_end_timeout_chats,
        send_timeout_warnings,
        cleanup_long_inactive_chats
    )
    from app.database import SessionLocal
    from app.main import cancel_expired_tasks, update_all_users_statistics
    from app.crud import (
        update_all_featured_task_experts_response_time,
        check_and_update_expired_subscriptions,
        revert_unpaid_application_approvals
    )
    from app.payment_transfer_service import (
        process_pending_transfers,
        check_transfer_timeout
    )
    
    scheduler = get_scheduler()
    
    # 创建数据库会话的包装函数
    def with_db(func):
        def wrapper():
            db = SessionLocal()
            try:
                func(db)
            finally:
                db.close()
        return wrapper
    
    # ========== 高频任务（每30秒-1分钟）==========
    
    # 客服相关任务（高频：每30秒，确保及时响应）
    scheduler.register_task(
        'process_customer_service_queue',
        with_db(process_customer_service_queue),
        interval_seconds=30,
        description="处理客服排队"
    )
    
    scheduler.register_task(
        'auto_end_timeout_chats',
        lambda: with_db(lambda db: auto_end_timeout_chats(db, timeout_minutes=2))(),
        interval_seconds=30,
        description="自动结束超时对话"
    )
    
    scheduler.register_task(
        'send_timeout_warnings',
        lambda: with_db(lambda db: send_timeout_warnings(db, warning_minutes=1))(),
        interval_seconds=30,
        description="发送超时预警"
    )
    
    # 取消过期任务 - 每1分钟
    scheduler.register_task(
        'cancel_expired_tasks',
        cancel_expired_tasks,
        interval_seconds=60,
        description="取消过期任务"
    )
    
    # 自动完成已过期时间段的任务 - 每1分钟
    scheduler.register_task(
        'auto_complete_expired_time_slot_tasks',
        with_db(auto_complete_expired_time_slot_tasks),
        interval_seconds=60,
        description="自动完成已过期时间段的任务"
    )
    
    # ========== 中频任务（每5-15分钟）==========
    
    # 检查支付过期的任务 - 每5分钟
    scheduler.register_task(
        'check_expired_payment_tasks',
        with_db(check_expired_payment_tasks),
        interval_seconds=300,  # 5分钟
        description="检查并取消支付过期的任务"
    )
    
    # 处理待处理的支付转账 - 每5分钟（重试失败的转账）
    scheduler.register_task(
        'process_pending_payment_transfers',
        with_db(process_pending_transfers),
        interval_seconds=300,  # 5分钟
        description="处理待处理的支付转账（重试失败的转账）"
    )
    
    # 同步论坛浏览数（Redis → DB）- 每5分钟
    def sync_forum_views():
        try:
            from app.redis_cache import get_redis_client
            from app.redis_utils import scan_keys
            from app.models import ForumPost
            from sqlalchemy import update
            
            redis_client = get_redis_client()
            if not redis_client:
                return
            
            keys = scan_keys(redis_client, "forum:post:view_count:*")
            if not keys:
                return
            
            db = SessionLocal()
            try:
                synced_count = 0
                synced_keys = []
                for key in keys:
                    try:
                        key_str = key.decode('utf-8') if isinstance(key, bytes) else str(key)
                        post_id = int(key_str.split(":")[-1])
                        redis_increment = redis_client.get(key)
                        if redis_increment:
                            increment = int(redis_increment.decode('utf-8') if isinstance(redis_increment, bytes) else redis_increment)
                            if increment > 0:
                                db.execute(
                                    update(ForumPost)
                                    .where(ForumPost.id == post_id)
                                    .values(view_count=ForumPost.view_count + increment)
                                )
                                synced_count += 1
                                synced_keys.append(key)
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理浏览数 key {key} 时出错: {e}")
                        continue
                
                db.commit()
                for key in synced_keys:
                    try:
                        redis_client.delete(key)
                    except Exception:
                        pass
                
                if synced_count > 0:
                    logger.info(f"同步论坛浏览数完成，同步了 {synced_count} 个帖子")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"同步论坛浏览数失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'sync_forum_view_counts',
        sync_forum_views,
        interval_seconds=300,  # 5分钟
        description="同步论坛浏览数（Redis → DB）"
    )
    
    # 同步榜单浏览数（Redis → DB）- 每5分钟
    def sync_leaderboard_views():
        try:
            from app.redis_cache import get_redis_client
            from app.redis_utils import scan_keys
            from app.models import CustomLeaderboard
            from sqlalchemy import update
            
            redis_client = get_redis_client()
            if not redis_client:
                return
            
            keys = scan_keys(redis_client, "leaderboard:view_count:*")
            if not keys:
                return
            
            db = SessionLocal()
            try:
                synced_count = 0
                synced_keys = []
                for key in keys:
                    try:
                        key_str = key.decode('utf-8') if isinstance(key, bytes) else str(key)
                        leaderboard_id = int(key_str.split(":")[-1])
                        redis_increment = redis_client.get(key)
                        if redis_increment:
                            increment = int(redis_increment.decode('utf-8') if isinstance(redis_increment, bytes) else redis_increment)
                            if increment > 0:
                                db.execute(
                                    update(CustomLeaderboard)
                                    .where(CustomLeaderboard.id == leaderboard_id)
                                    .values(view_count=CustomLeaderboard.view_count + increment)
                                )
                                synced_count += 1
                                synced_keys.append(key)
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理榜单浏览数 key {key} 时出错: {e}")
                        continue
                
                db.commit()
                for key in synced_keys:
                    try:
                        redis_client.delete(key)
                    except Exception:
                        pass
                
                if synced_count > 0:
                    logger.info(f"同步榜单浏览数完成，同步了 {synced_count} 个榜单")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"同步榜单浏览数失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'sync_leaderboard_view_counts',
        sync_leaderboard_views,
        interval_seconds=300,  # 5分钟
        description="同步榜单浏览数（Redis → DB）"
    )
    
    # 检查过期优惠券 - 每15分钟
    scheduler.register_task(
        'check_expired_coupons',
        with_db(check_expired_coupons),
        interval_seconds=900,  # 15分钟
        description="检查过期优惠券"
    )
    
    # 检查过期邀请码 - 每15分钟
    scheduler.register_task(
        'check_expired_invitation_codes',
        with_db(check_expired_invitation_codes),
        interval_seconds=900,  # 15分钟
        description="检查过期邀请码"
    )
    
    # 检查并结束活动 - 每15分钟
    scheduler.register_task(
        'check_and_end_activities',
        lambda: check_and_end_activities_sync(SessionLocal()),
        interval_seconds=900,  # 15分钟
        description="检查并结束活动（检查多人活动是否过期，过期则标记为已完成）"
    )
    
    # ========== 低频任务（每10分钟-1小时）==========
    
    # 更新所有用户统计信息 - 每10分钟
    scheduler.register_task(
        'update_all_users_statistics',
        update_all_users_statistics,
        interval_seconds=600,  # 10分钟
        description="更新所有用户统计信息"
    )
    
    # 检查过期积分 - 每1小时
    scheduler.register_task(
        'check_expired_points',
        with_db(check_expired_points),
        interval_seconds=3600,  # 1小时
        description="检查过期积分"
    )
    
    # 处理过期认证 - 每1小时（兜底任务）
    scheduler.register_task(
        'process_expired_verifications',
        with_db(process_expired_verifications),
        interval_seconds=3600,  # 1小时
        description="处理过期认证（兜底任务）"
    )
    
    # 检查并更新过期的VIP订阅 - 每1小时
    scheduler.register_task(
        'check_expired_vip_subscriptions',
        with_db(check_and_update_expired_subscriptions),
        interval_seconds=3600,  # 1小时
        description="检查并更新过期的VIP订阅"
    )
    
    # 检查转账超时 - 每1小时（检查长时间处于 pending 状态的转账）
    scheduler.register_task(
        'check_transfer_timeout',
        lambda: with_db(lambda db: check_transfer_timeout(db, timeout_hours=24))(),
        interval_seconds=3600,  # 1小时
        description="检查转账超时（pending 超过24小时）"
    )
    
    # 撤销超时未支付的申请批准 - 每1小时
    scheduler.register_task(
        'revert_unpaid_application_approvals',
        with_db(revert_unpaid_application_approvals),
        interval_seconds=3600,  # 1小时
        description="撤销超时未支付的申请批准（pending_payment 超过24小时）"
    )
    
    # ========== 推荐系统任务 ==========
    
    # 更新热门任务列表 - 每30分钟
    def update_popular_tasks():
        import json
        try:
            from app.models import Task, UserTaskInteraction
            from app.redis_cache import redis_cache
            from sqlalchemy import func, desc
            
            db = SessionLocal()
            try:
                recent_time = get_utc_time() - timedelta(hours=24)
                popular_tasks = db.query(
                    Task.id,
                    func.count(UserTaskInteraction.id).label('interaction_count')
                ).join(
                    UserTaskInteraction,
                    Task.id == UserTaskInteraction.task_id
                ).filter(
                    UserTaskInteraction.interaction_time >= recent_time,
                    Task.status == "open"
                ).group_by(
                    Task.id
                ).order_by(
                    desc('interaction_count')
                ).limit(50).all()
                
                task_ids = [task.id for task in popular_tasks]
                redis_cache.setex("popular_tasks:24h", 3600, json.dumps(task_ids))
                logger.info(f"热门任务列表已更新: count={len(task_ids)}")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"更新热门任务失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'update_popular_tasks',
        update_popular_tasks,
        interval_seconds=1800,  # 30分钟
        description="更新热门任务列表"
    )
    
    # 预计算推荐 - 每1小时
    def precompute_recommendations():
        try:
            from app.task_recommendation import TaskRecommendationEngine
            from app.models import UserTaskInteraction
            from sqlalchemy import distinct
            
            db = SessionLocal()
            try:
                # 通过最近有交互行为的用户来判断活跃用户（最多100个）
                recent_time = get_utc_time() - timedelta(days=7)
                active_users = db.query(
                    distinct(UserTaskInteraction.user_id)
                ).filter(
                    UserTaskInteraction.interaction_time >= recent_time
                ).limit(100).all()
                
                engine = TaskRecommendationEngine(db)
                computed_count = 0
                for (user_id,) in active_users:
                    try:
                        engine.recommend_tasks(user_id=user_id, limit=10, algorithm="hybrid")
                        computed_count += 1
                    except Exception:
                        continue
                
                logger.info(f"预计算推荐完成: {computed_count}/{len(active_users)} 个用户")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"预计算推荐失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'precompute_recommendations',
        precompute_recommendations,
        interval_seconds=3600,  # 1小时
        description="预计算活跃用户推荐"
    )
    
    # ========== 每日任务 ==========
    
    # 清理长期无活动对话 - 每天凌晨2点
    def daily_cleanup():
        current_hour = get_utc_time().hour
        if current_hour == 2:
            db = SessionLocal()
            try:
                cleanup_long_inactive_chats(db, inactive_days=30)
                logger.info("清理长期无活动对话完成")
            finally:
                db.close()
    
    scheduler.register_task(
        'cleanup_long_inactive_chats',
        daily_cleanup,
        interval_seconds=3600,  # 每小时检查一次，但只在2点执行
        description="清理长期无活动对话（每天凌晨2点）"
    )
    
    # 学生认证过期提醒 - 每天凌晨2点（30天/7天/1天前 + 过期当天通知）
    def daily_expiry_reminders():
        current_hour = get_utc_time().hour
        if current_hour == 2:
            db = SessionLocal()
            try:
                for days in [30, 7, 1]:
                    try:
                        send_expiry_reminders(db, days_before=days)
                        logger.info(f"发送过期提醒邮件完成（{days}天前）")
                    except Exception as e:
                        logger.error(f"发送过期提醒邮件失败（{days}天前）: {e}")
                try:
                    send_expiry_notifications(db)
                    logger.info("发送过期通知邮件完成")
                except Exception as e:
                    logger.error(f"发送过期通知邮件失败: {e}")
            finally:
                db.close()
    
    scheduler.register_task(
        'send_expiry_reminders',
        daily_expiry_reminders,
        interval_seconds=3600,  # 每小时检查一次，但只在2点执行
        description="学生认证过期提醒邮件（每天凌晨2点）"
    )
    
    # 推荐数据清理 - 每天凌晨2点
    def daily_recommendation_cleanup():
        current_hour = get_utc_time().hour
        if current_hour == 2:
            try:
                from app.recommendation_data_cleanup import cleanup_recommendation_data
                db = SessionLocal()
                try:
                    stats = cleanup_recommendation_data(db)
                    logger.info(f"推荐数据清理完成: {stats}")
                finally:
                    db.close()
            except Exception as e:
                logger.error(f"推荐数据清理失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'cleanup_recommendation_data',
        daily_recommendation_cleanup,
        interval_seconds=3600,  # 每小时检查一次，但只在2点执行
        description="推荐数据清理（每天凌晨2点）"
    )
    
    # 更新特征任务达人的响应时间 - 每天凌晨3点
    def daily_response_time_update():
        current_hour = get_utc_time().hour
        if current_hour == 3:
            updated_count = update_all_featured_task_experts_response_time()
            logger.info(f"更新特征任务达人响应时间完成，更新了 {updated_count} 个达人")
    
    scheduler.register_task(
        'update_featured_task_experts_response_time',
        daily_response_time_update,
        interval_seconds=3600,  # 每小时检查一次，但只在3点执行
        description="更新特征任务达人响应时间（每天凌晨3点）"
    )
    
    # 推荐系统优化 - 每天凌晨4点
    def daily_recommendation_optimize():
        current_hour = get_utc_time().hour
        if current_hour == 4:
            try:
                from app.recommendation_optimizer import optimize_recommendation_system
                db = SessionLocal()
                try:
                    result = optimize_recommendation_system(db)
                    logger.info(f"推荐系统优化完成: {result}")
                finally:
                    db.close()
            except Exception as e:
                logger.error(f"推荐系统优化失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'optimize_recommendation_system',
        daily_recommendation_optimize,
        interval_seconds=3600,  # 每小时检查一次，但只在4点执行
        description="推荐系统优化（每天凌晨4点）"
    )
    
    # ========== 每周任务 ==========
    
    # 数据匿名化 - 每周日凌晨3点
    def weekly_anonymize_data():
        now = get_utc_time()
        if now.weekday() == 6 and now.hour == 3:  # 周日凌晨3点
            try:
                from app.data_anonymization import anonymize_old_interactions, anonymize_old_feedback
                db = SessionLocal()
                try:
                    interaction_count = anonymize_old_interactions(db, days_old=90)
                    feedback_count = anonymize_old_feedback(db, days_old=90)
                    logger.info(f"数据匿名化完成: 交互记录 {interaction_count} 条, 反馈记录 {feedback_count} 条")
                finally:
                    db.close()
            except Exception as e:
                logger.error(f"数据匿名化失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'anonymize_old_data',
        weekly_anonymize_data,
        interval_seconds=3600,  # 每小时检查一次，但只在周日3点执行
        description="数据匿名化（每周日凌晨3点）"
    )
    
    logger.info(f"已注册 {len(scheduler.tasks)} 个定时任务")
    return scheduler


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
from app.utils.time_utils import get_utc_time

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
                    'last_run': task['last_run'].isoformat() if task['last_run'] else None,
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
    """初始化并注册所有定时任务"""
    from app.scheduled_tasks import (
        check_expired_coupons,
        check_expired_invitation_codes,
        check_expired_points,
        check_and_end_activities_sync
    )
    from app.customer_service_tasks import (
        process_customer_service_queue,
        auto_end_timeout_chats,
        send_timeout_warnings,
        cleanup_long_inactive_chats
    )
    from app.database import SessionLocal
    from app.main import cancel_expired_tasks, update_all_users_statistics
    from app.crud import update_all_task_experts_bio
    
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
    
    # 注册任务 - 使用不同的执行频率
    
    # 高频任务（每1分钟）
    scheduler.register_task(
        'cancel_expired_tasks',
        cancel_expired_tasks,
        interval_seconds=60,
        description="取消过期任务"
    )
    
    # 中频任务（每5分钟）
    scheduler.register_task(
        'check_expired_coupons',
        with_db(check_expired_coupons),
        interval_seconds=300,
        description="检查过期优惠券"
    )
    
    scheduler.register_task(
        'check_expired_invitation_codes',
        with_db(check_expired_invitation_codes),
        interval_seconds=300,
        description="检查过期邀请码"
    )
    
    scheduler.register_task(
        'check_expired_points',
        with_db(check_expired_points),
        interval_seconds=300,
        description="检查过期积分"
    )
    
    scheduler.register_task(
        'check_and_end_activities',
        lambda: check_and_end_activities_sync(SessionLocal()),
        interval_seconds=300,
        description="检查并结束活动"
    )
    
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
    
    # 低频任务（每10分钟）
    scheduler.register_task(
        'update_all_users_statistics',
        update_all_users_statistics,
        interval_seconds=600,
        description="更新所有用户统计信息"
    )
    
    # 每日任务（每天凌晨2点执行）
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
    
    # 每日任务：更新任务达人 bio
    def daily_bio_update():
        current_hour = get_utc_time().hour
        if current_hour == 3:  # 凌晨3点执行，避免与清理任务冲突
            update_all_task_experts_bio()
            logger.info("更新任务达人 bio 完成")
    
    scheduler.register_task(
        'update_task_experts_bio',
        daily_bio_update,
        interval_seconds=3600,  # 每小时检查一次，但只在3点执行
        description="更新任务达人 bio（每天凌晨3点）"
    )
    
    logger.info(f"已注册 {len(scheduler.tasks)} 个定时任务")
    return scheduler


"""
细粒度定时任务调度器
支持不同任务使用不同的执行频率

修复日志（2026-02-09）：
- P0 #1: check_and_end_activities DB 连接泄漏 → 改用 with_db
- P0 #2: Redis 浏览数同步数据丢失 → DECRBY 替代 DELETE
- P0 #3: 失败任务立即重试 → last_run 在失败时也更新
- P1 #4: 每日任务跳过/重复 → 记录 last_successful_date 补偿执行
- P1 #5: with_db 缺少显式 rollback
- P2 #6: get_scheduler 全局单例非线程安全 → 加 Lock
- P2 #8: 调度器线程健康检查
- P2 #9: 高频任务优先执行
- P3 #10: Prometheus import 优化
- P3 #12: 执行耗时告警阈值

修复日志（2026-02-12）：
- P0 #13: DB 不可用时定时任务刷屏报错 → with_db 捕获 OperationalError，降级为 warning
- P0 #14: DB 不可用时日志限流 → 全局 cooldown，同一错误 60 秒内只报一次
- P0 #15: 任务调度状态 Redis 持久化 → 部署重启后从 Redis 恢复 last_run / last_successful_date，
         避免所有任务立刻全跑一轮；每日/每周任务不会因部署而重复执行
"""
import threading
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Callable, Optional
from app.state import is_app_shutting_down
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)

# P3 #10: 模块顶部 import Prometheus 指标（可选依赖）
_record_scheduled_task: Optional[Callable] = None
try:
    from app.metrics import record_scheduled_task as _record_scheduled_task
except ImportError:
    pass


class DBUnavailableError(Exception):
    """
    P0 #13: 标记数据库不可用的异常。
    当 with_db 检测到 OperationalError（连接超时/拒绝等）时抛出此异常，
    让 _run_task 可以区分 DB 不可用和业务逻辑错误，避免刷屏报错。
    """
    pass


# P0 #14: DB 不可用日志限流 — 同一错误 60 秒内只报一次
_db_unavailable_last_logged: float = 0.0
_DB_UNAVAILABLE_LOG_COOLDOWN = 60  # 秒


def _is_db_connection_error(exc: Exception) -> bool:
    """判断异常是否为数据库连接不可用错误"""
    from sqlalchemy.exc import OperationalError, InvalidatePoolError
    if isinstance(exc, (OperationalError, InvalidatePoolError)):
        return True
    # psycopg2 原始错误
    error_msg = str(exc).lower()
    return any(keyword in error_msg for keyword in [
        "connection refused",
        "connection timed out",
        "could not connect",
        "connection reset",
        "server closed the connection unexpectedly",
        "connection is closed",
        "ssl connection has been closed unexpectedly",
    ])


class TaskScheduler:
    """细粒度任务调度器"""
    
    # P0 #15: Redis 持久化 key 前缀和 TTL
    _REDIS_KEY_PREFIX = "scheduler:task:"
    _REDIS_STATE_TTL = 7 * 24 * 3600  # 7天
    
    def __init__(self):
        self.tasks: Dict[str, Dict] = {}
        self._shutdown_flag = False
        self._thread: Optional[threading.Thread] = None
        self._last_heartbeat: Optional[datetime] = None  # P2 #8: 健康检查心跳
        self._redis_client = None  # P0 #15: Redis 客户端（延迟初始化）
        self._redis_initialized = False
    
    # ========== P0 #15: Redis 状态持久化 ==========
    
    def _get_redis(self):
        """延迟获取 Redis 客户端（避免模块加载时循环依赖）"""
        if not self._redis_initialized:
            self._redis_initialized = True
            try:
                from app.redis_cache import get_redis_client
                self._redis_client = get_redis_client()
                if self._redis_client:
                    logger.info("调度器 Redis 持久化已启用")
                else:
                    logger.warning("调度器 Redis 不可用，任务状态不会跨部署保存")
            except Exception as e:
                logger.warning(f"调度器 Redis 初始化失败: {e}")
                self._redis_client = None
        return self._redis_client
    
    def _save_task_state(self, task_name: str):
        """将单个任务的运行状态保存到 Redis"""
        redis_client = self._get_redis()
        if not redis_client:
            return
        
        task = self.tasks.get(task_name)
        if not task:
            return
        
        try:
            import json
            state = {}
            if task['last_run']:
                state['last_run'] = task['last_run'].isoformat()
            if task.get('last_successful_date'):
                state['last_successful_date'] = task['last_successful_date'].isoformat()
            
            key = f"{self._REDIS_KEY_PREFIX}{task_name}"
            redis_client.setex(key, self._REDIS_STATE_TTL, json.dumps(state))
        except Exception as e:
            # 保存失败不影响任务执行
            logger.debug(f"保存任务 {task_name} 状态到 Redis 失败: {e}")
    
    def _load_all_task_states(self):
        """从 Redis 恢复所有已注册任务的运行状态（部署后调用）"""
        redis_client = self._get_redis()
        if not redis_client:
            logger.info("Redis 不可用，所有任务将从头开始执行")
            return
        
        import json
        restored_count = 0
        for task_name, task in self.tasks.items():
            try:
                key = f"{self._REDIS_KEY_PREFIX}{task_name}"
                raw = redis_client.get(key)
                if not raw:
                    continue
                
                state = json.loads(raw.decode('utf-8') if isinstance(raw, bytes) else raw)
                
                if 'last_run' in state and state['last_run']:
                    task['last_run'] = datetime.fromisoformat(state['last_run'])
                    restored_count += 1
                
                if 'last_successful_date' in state and state['last_successful_date']:
                    from datetime import date as date_type
                    date_str = state['last_successful_date']
                    # 支持 date 和 datetime 格式
                    if 'T' in date_str:
                        task['last_successful_date'] = datetime.fromisoformat(date_str).date()
                    else:
                        task['last_successful_date'] = date_type.fromisoformat(date_str)
            except Exception as e:
                logger.debug(f"恢复任务 {task_name} 状态失败: {e}")
                continue
        
        if restored_count > 0:
            logger.info(f"从 Redis 恢复了 {restored_count}/{len(self.tasks)} 个任务的运行状态")
        else:
            logger.info("Redis 中没有找到任务运行状态（首次部署或状态已过期）")
    
    # ========== 任务注册 ==========
    
    def register_task(
        self,
        name: str,
        func: Callable,
        interval_seconds: int,
        description: str = "",
        priority: str = "normal"
    ):
        """
        注册定时任务
        
        Args:
            name: 任务名称
            func: 要执行的函数
            interval_seconds: 执行间隔（秒）
            description: 任务描述
            priority: 优先级 "high" | "normal"，高优先级任务先执行
        """
        self.tasks[name] = {
            'func': func,
            'interval': interval_seconds,
            'last_run': None,
            'description': description,
            'run_count': 0,
            'error_count': 0,
            'priority': priority,
            'last_successful_date': None,  # P1 #4: 记录上次成功执行的日期（用于每日任务补偿）
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
        global _db_unavailable_last_logged
        task = self.tasks[task_name]
        start_time = time.time()
        try:
            task['func']()
            duration = time.time() - start_time
            task['last_run'] = get_utc_time()
            task['run_count'] += 1
            
            # P3 #12: 执行耗时告警 — 超过间隔的 50% 则 WARNING
            warn_threshold = task['interval'] * 0.5
            if duration > warn_threshold:
                logger.warning(
                    f"⚠️ 任务 {task_name} 执行耗时 {duration:.2f}秒，"
                    f"超过间隔 {task['interval']}秒 的 50% 阈值 ({warn_threshold:.0f}秒)"
                )
            else:
                logger.debug(f"任务 {task_name} 执行完成 (耗时: {duration:.2f}秒)")
            
            # P0 #15: 持久化任务状态到 Redis
            self._save_task_state(task_name)
            
            # 记录 Prometheus 指标
            if _record_scheduled_task:
                try:
                    _record_scheduled_task(task_name, "success", duration)
                except Exception:
                    pass
        except DBUnavailableError:
            # P0 #13: DB 不可用 — 降级为 warning，不打印完整 traceback
            duration = time.time() - start_time
            task['last_run'] = get_utc_time()
            task['error_count'] += 1
            
            # P0 #14: 日志限流 — 60 秒内只报一次
            now = time.time()
            if now - _db_unavailable_last_logged > _DB_UNAVAILABLE_LOG_COOLDOWN:
                _db_unavailable_last_logged = now
                logger.warning(
                    f"⚠️ 数据库不可用，任务 {task_name} 已跳过 (耗时: {duration:.2f}秒)。"
                    f"后续 {_DB_UNAVAILABLE_LOG_COOLDOWN} 秒内同类错误将被静默。"
                )
            
            # P0 #15: DB 不可用时也保存 last_run（防止重启后立即重试）
            self._save_task_state(task_name)
            
            # 记录 Prometheus 指标
            if _record_scheduled_task:
                try:
                    _record_scheduled_task(task_name, "db_unavailable", duration)
                except Exception:
                    pass
        except Exception as e:
            duration = time.time() - start_time
            # P0 #3: 失败时也更新 last_run，防止立即重试导致 Stripe rate limit / 重复转账
            task['last_run'] = get_utc_time()
            task['error_count'] += 1
            logger.error(f"任务 {task_name} 执行失败 (耗时: {duration:.2f}秒): {e}", exc_info=True)
            
            # P0 #15: 失败时也保存 last_run
            self._save_task_state(task_name)
            
            # 记录 Prometheus 指标
            if _record_scheduled_task:
                try:
                    _record_scheduled_task(task_name, "error", duration)
                except Exception:
                    pass
    
    def run(self):
        """运行调度器主循环"""
        logger.info("定时任务调度器已启动")
        
        # P0 #15: 从 Redis 恢复上次的任务运行状态（部署重启后不会立刻全跑一轮）
        self._load_all_task_states()
        
        # 计算最小间隔（用于主循环）
        min_interval = min(
            (task['interval'] for task in self.tasks.values()),
            default=60
        )
        # 主循环使用最小间隔的一半，确保及时检查
        check_interval = max(min_interval // 2, 10)
        
        while not self._shutdown_flag and not is_app_shutting_down():
            try:
                # P2 #8: 更新心跳
                self._last_heartbeat = get_utc_time()
                
                # P2 #9: 高优先级任务先执行，保证客服等关键任务不被长任务阻塞
                task_names = sorted(
                    self.tasks.keys(),
                    key=lambda n: (0 if self.tasks[n]['priority'] == 'high' else 1)
                )
                
                for task_name in task_names:
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
    
    def is_healthy(self, max_heartbeat_age_seconds: int = 120) -> bool:
        """
        P2 #8: 检查调度器线程是否健康
        
        Args:
            max_heartbeat_age_seconds: 心跳最大允许年龄（秒），超过则认为不健康
        
        Returns:
            True 如果线程存活且心跳正常
        """
        if not self._thread or not self._thread.is_alive():
            return False
        if self._last_heartbeat is None:
            return True  # 刚启动还没来得及心跳
        age = (get_utc_time() - self._last_heartbeat).total_seconds()
        return age < max_heartbeat_age_seconds
    
    def get_status(self) -> Dict:
        """获取调度器状态"""
        return {
            'running': self._thread.is_alive() if self._thread else False,
            'healthy': self.is_healthy(),
            'last_heartbeat': format_iso_utc(self._last_heartbeat) if self._last_heartbeat else None,
            'tasks': {
                name: {
                    'description': task['description'],
                    'interval': task['interval'],
                    'priority': task['priority'],
                    'last_run': format_iso_utc(task['last_run']) if task['last_run'] else None,
                    'run_count': task['run_count'],
                    'error_count': task['error_count']
                }
                for name, task in self.tasks.items()
            }
        }


# P2 #6: 全局调度器实例 + 线程安全锁
_scheduler: Optional[TaskScheduler] = None
_scheduler_lock = threading.Lock()


def get_scheduler() -> TaskScheduler:
    """获取全局调度器实例（线程安全）"""
    global _scheduler
    if _scheduler is None:
        with _scheduler_lock:
            if _scheduler is None:  # double-checked locking
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
        send_expiry_notifications,
        send_auto_transfer_reminders,
        auto_transfer_expired_tasks,
        auto_confirm_expired_tasks,
        send_confirmation_reminders
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
    
    # P1 #5: 创建数据库会话的包装函数 — 加显式 rollback
    # P0 #13: 捕获 DB 连接错误，转为 DBUnavailableError，避免刷屏
    def with_db(func):
        def wrapper():
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
            try:
                func(db)
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"数据库操作失败（连接不可用）: {e}") from e
                raise
            finally:
                db.close()
        return wrapper
    
    # P1 #4: 每日/每周任务的包装器 — 记录上次成功日期，支持补偿执行
    # P0 #15: 更新 last_successful_date 后同步持久化到 Redis
    def make_daily_task(task_name: str, target_hour: int, task_func):
        """
        创建每日任务包装函数。
        通过 last_successful_date 判断今天是否已执行，避免重复或跳过。
        
        Args:
            task_name: 任务名（用于在 scheduler.tasks 中查找元数据）
            target_hour: 目标执行 UTC 小时
            task_func: 实际执行的函数 (无参数)
        """
        def wrapper():
            now = get_utc_time()
            today = now.date()
            task_meta = scheduler.tasks.get(task_name)
            if not task_meta:
                return
            
            last_date = task_meta.get('last_successful_date')
            
            # 如果今天已经成功执行过，跳过
            if last_date == today:
                return
            
            # 只在目标小时或之后执行（补偿：如果错过了目标小时，之后的小时也会触发）
            if now.hour >= target_hour:
                task_func()
                task_meta['last_successful_date'] = today
                # P0 #15: 持久化 last_successful_date（由 _run_task 统一保存 last_run，
                # 但 last_successful_date 在这里更新，所以需要额外触发保存）
                scheduler._save_task_state(task_name)
        
        return wrapper
    
    def make_weekly_task(task_name: str, target_weekday: int, target_hour: int, task_func):
        """
        创建每周任务包装函数。weekday: 0=周一, 6=周日
        """
        def wrapper():
            now = get_utc_time()
            today = now.date()
            task_meta = scheduler.tasks.get(task_name)
            if not task_meta:
                return
            
            last_date = task_meta.get('last_successful_date')
            
            # 如果本周已经成功执行过（7天内），跳过
            if last_date and (today - last_date).days < 7:
                return
            
            # 只在目标星期几的目标小时或之后执行
            if now.weekday() == target_weekday and now.hour >= target_hour:
                task_func()
                task_meta['last_successful_date'] = today
                # P0 #15: 持久化 last_successful_date
                scheduler._save_task_state(task_name)
        
        return wrapper
    
    # P0 #2: 通用的 Redis → DB 浏览数同步函数（消除重复代码 + DECRBY 修复数据丢失）
    def sync_redis_view_counts(key_pattern: str, model_class, entity_name: str):
        """
        通用的 Redis 浏览数同步函数。
        使用 DECRBY（减去已同步的增量）替代 DELETE，防止同步窗口期间的新增浏览数丢失。
        """
        try:
            from app.redis_cache import get_redis_client
            from app.redis_utils import scan_keys
            from sqlalchemy import update
            
            redis_client = get_redis_client()
            if not redis_client:
                return
            
            keys = scan_keys(redis_client, key_pattern)
            if not keys:
                return
            
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
            try:
                synced_count = 0
                # 第一步：读取所有增量并记录
                increments = []
                for key in keys:
                    try:
                        key_str = key.decode('utf-8') if isinstance(key, bytes) else str(key)
                        entity_id = int(key_str.split(":")[-1])
                        redis_increment = redis_client.get(key)
                        if redis_increment:
                            increment = int(redis_increment.decode('utf-8') if isinstance(redis_increment, bytes) else redis_increment)
                            if increment > 0:
                                increments.append((key, entity_id, increment))
                    except (ValueError, TypeError) as e:
                        logger.warning(f"处理{entity_name}浏览数 key {key} 时出错: {e}")
                        continue
                
                # 第二步：批量写入 DB
                for key, entity_id, increment in increments:
                    db.execute(
                        update(model_class)
                        .where(model_class.id == entity_id)
                        .values(view_count=model_class.view_count + increment)
                    )
                    synced_count += 1
                
                db.commit()
                
                # 第三步：用 DECRBY 减去已同步的增量（而非 DELETE）
                # 这样在 GET 和 DECRBY 之间新增的浏览数不会丢失
                for key, entity_id, increment in increments:
                    try:
                        remaining = redis_client.decrby(key, increment)
                        # 如果减完后 <= 0，清理 key（避免 key 无限积累）
                        if remaining is not None and remaining <= 0:
                            redis_client.delete(key)
                    except Exception:
                        pass
                
                if synced_count > 0:
                    logger.info(f"同步{entity_name}浏览数完成，同步了 {synced_count} 个")
            except DBUnavailableError:
                raise
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"同步{entity_name}浏览数时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"同步{entity_name}浏览数失败: {e}", exc_info=True)
    
    # ========== 高频任务（每30秒-1分钟）==========
    
    # P2 #9: 客服相关任务标记为高优先级，保证不被长任务阻塞
    scheduler.register_task(
        'process_customer_service_queue',
        with_db(process_customer_service_queue),
        interval_seconds=30,
        description="处理客服排队",
        priority="high"
    )
    
    scheduler.register_task(
        'auto_end_timeout_chats',
        lambda: with_db(lambda db: auto_end_timeout_chats(db, timeout_minutes=2))(),
        interval_seconds=30,
        description="自动结束超时对话",
        priority="high"
    )
    
    scheduler.register_task(
        'send_timeout_warnings',
        lambda: with_db(lambda db: send_timeout_warnings(db, warning_minutes=1))(),
        interval_seconds=30,
        description="发送超时预警",
        priority="high"
    )
    
    # 取消过期任务 - 每1分钟
    scheduler.register_task(
        'cancel_expired_tasks',
        cancel_expired_tasks,
        interval_seconds=60,
        description="取消过期任务",
        priority="high"
    )
    
    # ========== 中频任务（每5-15分钟）==========
    
    # 自动完成已过期时间段的达人任务 - 每15分钟
    scheduler.register_task(
        'auto_complete_expired_time_slot_tasks',
        with_db(auto_complete_expired_time_slot_tasks),
        interval_seconds=900,
        description="自动完成已过期时间段的达人任务（pending_confirmation + 时间段过期 → completed）"
    )
    
    # 检查支付过期的任务 - 每5分钟
    scheduler.register_task(
        'check_expired_payment_tasks',
        with_db(check_expired_payment_tasks),
        interval_seconds=300,
        description="检查并取消支付过期的任务"
    )
    
    # 处理待处理的支付转账 - 每5分钟（重试失败的转账）
    scheduler.register_task(
        'process_pending_payment_transfers',
        with_db(process_pending_transfers),
        interval_seconds=300,
        description="处理待处理的支付转账（重试失败的转账）"
    )
    
    # 同步论坛浏览数（Redis → DB）- 每5分钟
    scheduler.register_task(
        'sync_forum_view_counts',
        lambda: sync_redis_view_counts(
            "forum:post:view_count:*",
            __import__('app.models', fromlist=['ForumPost']).ForumPost,
            "论坛帖子"
        ),
        interval_seconds=300,
        description="同步论坛浏览数（Redis → DB）"
    )
    
    # 同步榜单浏览数（Redis → DB）- 每5分钟
    scheduler.register_task(
        'sync_leaderboard_view_counts',
        lambda: sync_redis_view_counts(
            "leaderboard:view_count:*",
            __import__('app.models', fromlist=['CustomLeaderboard']).CustomLeaderboard,
            "榜单"
        ),
        interval_seconds=300,
        description="同步榜单浏览数（Redis → DB）"
    )
    
    # 检查过期优惠券 - 每15分钟
    scheduler.register_task(
        'check_expired_coupons',
        with_db(check_expired_coupons),
        interval_seconds=900,
        description="检查过期优惠券"
    )
    
    # 检查过期邀请码 - 每15分钟
    scheduler.register_task(
        'check_expired_invitation_codes',
        with_db(check_expired_invitation_codes),
        interval_seconds=900,
        description="检查过期邀请码"
    )
    
    # P0 #1: 修复 DB 连接泄漏 — 改用 with_db 包装
    # check_and_end_activities_sync 接收 db 参数但内部用异步桥接
    # 原代码 lambda: check_and_end_activities_sync(SessionLocal()) 永远不关闭 session
    scheduler.register_task(
        'check_and_end_activities',
        with_db(check_and_end_activities_sync),
        interval_seconds=900,
        description="检查并结束活动（检查多人活动是否过期，过期则标记为已完成）"
    )
    
    # ========== 自动转账相关任务 ==========
    
    # Phase 2: 自动转账确认提醒 - 每1小时
    # 提醒发布者：达人任务完成后即将自动确认转账（过期第1天/第2天提醒）
    scheduler.register_task(
        'send_auto_transfer_reminders',
        with_db(send_auto_transfer_reminders),
        interval_seconds=3600,
        description="自动转账确认提醒（提醒发布者即将自动转账给接单方）"
    )
    
    # 自动转账 - 每15分钟
    # 所有已完成、已付款、escrow>0、deadline已过期的任务 → Stripe Transfer
    scheduler.register_task(
        'auto_transfer_expired_tasks',
        with_db(auto_transfer_expired_tasks),
        interval_seconds=900,
        description="自动转账（已完成付费任务 deadline 过期后自动确认并转账）"
    )
    
    # 自动确认过期未确认的任务 - 每15分钟
    # 统一处理所有 pending_confirmation + deadline 过期的任务（不分达人/非达人）
    # escrow==0: 完整确认（最终状态）; escrow>0: 仅改状态为 completed，由 auto_transfer 处理转账
    scheduler.register_task(
        'auto_confirm_expired_tasks',
        with_db(auto_confirm_expired_tasks),
        interval_seconds=900,
        description="自动确认过期未确认的任务（统一处理所有类型，按 escrow 分支）"
    )
    
    # 发送确认提醒通知（针对 pending_confirmation 状态的任务）- 每15分钟
    scheduler.register_task(
        'send_confirmation_reminders',
        with_db(send_confirmation_reminders),
        interval_seconds=900,
        description="发送确认提醒通知（pending_confirmation 状态的任务）"
    )
    
    # ========== 低频任务（每10分钟-1小时）==========
    
    # 更新所有用户统计信息 - 每10分钟
    scheduler.register_task(
        'update_all_users_statistics',
        update_all_users_statistics,
        interval_seconds=600,
        description="更新所有用户统计信息"
    )
    
    # 检查过期积分 - 每1小时
    scheduler.register_task(
        'check_expired_points',
        with_db(check_expired_points),
        interval_seconds=3600,
        description="检查过期积分"
    )
    
    # 处理过期认证 - 每1小时（兜底任务）
    scheduler.register_task(
        'process_expired_verifications',
        with_db(process_expired_verifications),
        interval_seconds=3600,
        description="处理过期认证（兜底任务）"
    )
    
    # 检查并更新过期的VIP订阅 - 每1小时
    scheduler.register_task(
        'check_expired_vip_subscriptions',
        with_db(check_and_update_expired_subscriptions),
        interval_seconds=3600,
        description="检查并更新过期的VIP订阅"
    )
    
    # 检查转账超时 - 每1小时（检查长时间处于 pending 状态的转账）
    scheduler.register_task(
        'check_transfer_timeout',
        lambda: with_db(lambda db: check_transfer_timeout(db, timeout_hours=24))(),
        interval_seconds=3600,
        description="检查转账超时（pending 超过24小时）"
    )
    
    # 撤销超时未支付的申请批准 - 每1小时
    scheduler.register_task(
        'revert_unpaid_application_approvals',
        with_db(revert_unpaid_application_approvals),
        interval_seconds=3600,
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
            
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
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
            except DBUnavailableError:
                raise
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"更新热门任务时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"更新热门任务失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'update_popular_tasks',
        update_popular_tasks,
        interval_seconds=1800,
        description="更新热门任务列表"
    )
    
    # 预计算推荐 - 每1小时
    def precompute_recommendations():
        try:
            from app.task_recommendation import TaskRecommendationEngine
            from app.models import UserTaskInteraction
            from sqlalchemy import distinct
            
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
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
            except DBUnavailableError:
                raise
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"预计算推荐时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"预计算推荐失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'precompute_recommendations',
        precompute_recommendations,
        interval_seconds=3600,
        description="预计算活跃用户推荐"
    )
    
    # ========== 每日任务（P1 #4: 使用 make_daily_task 包装，支持补偿执行）==========
    
    # 清理长期无活动对话 - 每天凌晨2点
    def _cleanup_chats():
        try:
            db = SessionLocal()
        except Exception as e:
            if _is_db_connection_error(e):
                raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
            raise
        try:
            cleanup_long_inactive_chats(db, inactive_days=30)
            logger.info("清理长期无活动对话完成")
        except DBUnavailableError:
            raise
        except Exception as e:
            db.rollback()
            if _is_db_connection_error(e):
                raise DBUnavailableError(f"清理对话时数据库不可用: {e}") from e
            raise
        finally:
            db.close()
    
    scheduler.register_task(
        'cleanup_long_inactive_chats',
        make_daily_task('cleanup_long_inactive_chats', 2, _cleanup_chats),
        interval_seconds=3600,
        description="清理长期无活动对话（每天凌晨2点）"
    )
    
    # 学生认证过期提醒 - 每天凌晨2点
    def _expiry_reminders():
        try:
            db = SessionLocal()
        except Exception as e:
            if _is_db_connection_error(e):
                raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
            raise
        try:
            for days in [30, 7, 1]:
                try:
                    send_expiry_reminders(db, days_before=days)
                    logger.info(f"发送过期提醒邮件完成（{days}天前）")
                except Exception as e:
                    if _is_db_connection_error(e):
                        raise DBUnavailableError(f"发送过期提醒时数据库不可用: {e}") from e
                    logger.error(f"发送过期提醒邮件失败（{days}天前）: {e}")
            try:
                send_expiry_notifications(db)
                logger.info("发送过期通知邮件完成")
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"发送过期通知时数据库不可用: {e}") from e
                logger.error(f"发送过期通知邮件失败: {e}")
        finally:
            db.close()
    
    scheduler.register_task(
        'send_expiry_reminders',
        make_daily_task('send_expiry_reminders', 2, _expiry_reminders),
        interval_seconds=3600,
        description="学生认证过期提醒邮件（每天凌晨2点）"
    )
    
    # 推荐数据清理 - 每天凌晨2点
    def _recommendation_cleanup():
        try:
            from app.recommendation_data_cleanup import cleanup_recommendation_data
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
            try:
                stats = cleanup_recommendation_data(db)
                logger.info(f"推荐数据清理完成: {stats}")
            except DBUnavailableError:
                raise
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"推荐数据清理时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"推荐数据清理失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'cleanup_recommendation_data',
        make_daily_task('cleanup_recommendation_data', 2, _recommendation_cleanup),
        interval_seconds=3600,
        description="推荐数据清理（每天凌晨2点）"
    )
    
    # 更新特征任务达人的响应时间 - 每天凌晨3点
    def _response_time_update():
        updated_count = update_all_featured_task_experts_response_time()
        logger.info(f"更新特征任务达人响应时间完成，更新了 {updated_count} 个达人")
    
    scheduler.register_task(
        'update_featured_task_experts_response_time',
        make_daily_task('update_featured_task_experts_response_time', 3, _response_time_update),
        interval_seconds=3600,
        description="更新特征任务达人响应时间（每天凌晨3点）"
    )
    
    # 推荐系统优化 - 每天凌晨4点
    def _recommendation_optimize():
        try:
            from app.recommendation_optimizer import optimize_recommendation_system
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
            try:
                result = optimize_recommendation_system(db)
                logger.info(f"推荐系统优化完成: {result}")
            except DBUnavailableError:
                raise
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"推荐系统优化时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"推荐系统优化失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'optimize_recommendation_system',
        make_daily_task('optimize_recommendation_system', 4, _recommendation_optimize),
        interval_seconds=3600,
        description="推荐系统优化（每天凌晨4点）"
    )
    
    # ========== 每周任务 ==========
    
    # 数据匿名化 - 每周日凌晨3点
    def _anonymize_data():
        try:
            from app.data_anonymization import anonymize_old_interactions, anonymize_old_feedback
            try:
                db = SessionLocal()
            except Exception as e:
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"无法创建数据库连接: {e}") from e
                raise
            try:
                interaction_count = anonymize_old_interactions(db, days_old=90)
                feedback_count = anonymize_old_feedback(db, days_old=90)
                logger.info(f"数据匿名化完成: 交互记录 {interaction_count} 条, 反馈记录 {feedback_count} 条")
            except DBUnavailableError:
                raise
            except Exception as e:
                db.rollback()
                if _is_db_connection_error(e):
                    raise DBUnavailableError(f"数据匿名化时数据库不可用: {e}") from e
                raise
            finally:
                db.close()
        except DBUnavailableError:
            raise
        except Exception as e:
            logger.error(f"数据匿名化失败: {e}", exc_info=True)
    
    scheduler.register_task(
        'anonymize_old_data',
        make_weekly_task('anonymize_old_data', 6, 3, _anonymize_data),  # 6=周日
        interval_seconds=3600,
        description="数据匿名化（每周日凌晨3点）"
    )
    
    logger.info(f"已注册 {len(scheduler.tasks)} 个定时任务")
    return scheduler

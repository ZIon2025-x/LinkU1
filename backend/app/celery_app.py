"""
Celery应用配置
用于定时任务调度（Celery Beat）
"""

import os
from celery import Celery
from celery.schedules import crontab

# 从环境变量获取Redis配置
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
USE_REDIS = os.getenv("USE_REDIS", "true").lower() == "true"

# 创建Celery应用
celery_app = Celery(
    'linku_tasks',
    broker=REDIS_URL if USE_REDIS else 'memory://',
    backend=REDIS_URL if USE_REDIS else 'cache+memory://',
    include=[
        'app.customer_service_tasks',
        'app.celery_tasks',
        'app.celery_tasks_expiry'
    ]
)

# Celery配置
celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,  # 30分钟超时
    task_soft_time_limit=25 * 60,  # 25分钟软超时
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
    # 任务重试配置
    task_acks_late=True,  # 任务完成后才确认，防止任务丢失
    task_reject_on_worker_lost=True,  # Worker 丢失时拒绝任务
    # 默认重试配置（可在任务级别覆盖）
    task_default_retry_delay=60,  # 默认重试延迟60秒
    task_max_retries=3,  # 默认最大重试3次
)

# Celery Beat定时任务配置
celery_app.conf.beat_schedule = {
    # ========== 高频任务（每30秒-1分钟）==========
    
    # 客服相关任务 - 每30秒执行一次（确保及时响应）
    'process-customer-service-queue': {
        'task': 'app.customer_service_tasks.process_customer_service_queue_task',
        'schedule': 30.0,  # 30秒
    },
    'auto-end-timeout-chats': {
        'task': 'app.customer_service_tasks.auto_end_timeout_chats_task',
        'schedule': 30.0,  # 30秒
    },
    'send-timeout-warnings': {
        'task': 'app.customer_service_tasks.send_timeout_warnings_task',
        'schedule': 30.0,  # 30秒
    },
    
    # 取消过期任务 - 每1分钟执行一次
    'cancel-expired-tasks': {
        'task': 'app.celery_tasks.cancel_expired_tasks_task',
        'schedule': 60.0,  # 1分钟
    },
    
    # 自动完成已过期时间段的任务 - 每1分钟执行一次
    'auto-complete-expired-time-slot-tasks': {
        'task': 'app.celery_tasks.auto_complete_expired_time_slot_tasks_task',
        'schedule': 60.0,  # 1分钟
    },
    
    # 处理待处理的支付转账 - 每5分钟执行一次（重试失败的转账）
    'process-pending-payment-transfers': {
        'task': 'app.celery_tasks.process_pending_payment_transfers_task',
        'schedule': 300.0,  # 5分钟
    },
    
    # 检查转账超时 - 每1小时执行一次（检查长时间处于 pending 状态的转账）
    'check-transfer-timeout': {
        'task': 'app.celery_tasks.check_transfer_timeout_task',
        'schedule': 3600.0,  # 1小时
    },
    
    # ========== 中频任务（每5分钟）==========
    
    # 检查过期优惠券 - 每15分钟执行一次（降低频率，减少DB压力）
    'check-expired-coupons': {
        'task': 'app.celery_tasks.check_expired_coupons_task',
        'schedule': 900.0,  # 15分钟
    },
    
    # 检查过期邀请码 - 每15分钟执行一次（降低频率，减少DB压力）
    'check-expired-invitation-codes': {
        'task': 'app.celery_tasks.check_expired_invitation_codes_task',
        'schedule': 900.0,  # 15分钟
    },
    
    # 检查过期积分 - 每1小时执行一次（降低频率，积分过期对实时性要求不高）
    'check-expired-points': {
        'task': 'app.celery_tasks.check_expired_points_task',
        'schedule': 3600.0,  # 1小时
    },
    
    # 处理过期认证 - 每1小时执行一次（兜底任务）
    'process-expired-verifications': {
        'task': 'app.celery_tasks.process_expired_verifications_task',
        'schedule': 3600.0,  # 1小时
    },
    
    # ========== 学生认证过期提醒任务 ==========
    
    # 过期提醒邮件 - 30天前（每天凌晨2点执行）
    'send-expiry-reminders-30-days': {
        'task': 'app.celery_tasks_expiry.send_expiry_reminders_task',
        'schedule': crontab(hour=2, minute=0),  # 每天凌晨2点
        'kwargs': {'days_before': 30}
    },
    
    # 过期提醒邮件 - 7天前（每天凌晨2点5分执行）
    'send-expiry-reminders-7-days': {
        'task': 'app.celery_tasks_expiry.send_expiry_reminders_task',
        'schedule': crontab(hour=2, minute=5),  # 每天凌晨2点5分
        'kwargs': {'days_before': 7}
    },
    
    # 过期提醒邮件 - 1天前（每天凌晨2点10分执行）
    'send-expiry-reminders-1-day': {
        'task': 'app.celery_tasks_expiry.send_expiry_reminders_task',
        'schedule': crontab(hour=2, minute=10),  # 每天凌晨2点10分
        'kwargs': {'days_before': 1}
    },
    
    # 过期通知邮件 - 过期当天（每天凌晨2点15分执行）
    'send-expiry-notifications': {
        'task': 'app.celery_tasks_expiry.send_expiry_notifications_task',
        'schedule': crontab(hour=2, minute=15),  # 每天凌晨2点15分
    },
    
    # 检查并结束活动 - 每15分钟执行一次（降低频率，减少DB压力）
    # 检查多人活动是否过期（最后一个时间段结束或达到截止日期），过期则标记为已完成
    'check-and-end-activities': {
        'task': 'app.celery_tasks.check_and_end_activities_task',
        'schedule': 900.0,  # 15分钟
    },
    
    # 同步论坛浏览数 - 每5分钟执行一次
    'sync-forum-view-counts': {
        'task': 'app.celery_tasks.sync_forum_view_counts_task',
        'schedule': 300.0,  # 5分钟
    },
    
    # 同步榜单浏览数 - 每5分钟执行一次
    'sync-leaderboard-view-counts': {
        'task': 'app.celery_tasks.sync_leaderboard_view_counts_task',
        'schedule': 300.0,  # 5分钟
    },
    
    # ========== 低频任务（每10分钟）==========
    
    # 更新所有用户统计信息 - 每10分钟执行一次
    'update-all-users-statistics': {
        'task': 'app.celery_tasks.update_all_users_statistics_task',
        'schedule': 600.0,  # 10分钟
    },
    
    # ========== 每日任务（每天特定时间）==========
    
    # 清理长期无活动对话 - 每天凌晨2点执行
    'cleanup-long-inactive-chats': {
        'task': 'app.celery_tasks.cleanup_long_inactive_chats_task',
        'schedule': crontab(hour=2, minute=0),  # 每天凌晨2点
    },
    
    # 更新特征任务达人的响应时间 - 每天凌晨3点执行
    'update-featured-task-experts-response-time': {
        'task': 'app.celery_tasks.update_featured_task_experts_response_time_task',
        'schedule': crontab(hour=3, minute=0),  # 每天凌晨3点
    },
}

# 如果使用内存后端，禁用结果存储
if not USE_REDIS:
    celery_app.conf.result_backend = None
    celery_app.conf.task_ignore_result = True

if __name__ == '__main__':
    celery_app.start()


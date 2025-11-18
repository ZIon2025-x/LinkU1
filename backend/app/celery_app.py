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
    include=['app.customer_service_tasks']
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
)

# Celery Beat定时任务配置
celery_app.conf.beat_schedule = {
    # 处理客服排队 - 每30秒执行一次
    'process-customer-service-queue': {
        'task': 'app.customer_service_tasks.process_customer_service_queue_task',
        'schedule': 30.0,  # 30秒
    },
    # 自动结束超时对话 - 每30秒执行一次
    'auto-end-timeout-chats': {
        'task': 'app.customer_service_tasks.auto_end_timeout_chats_task',
        'schedule': 30.0,  # 30秒
    },
    # 发送超时预警 - 每30秒执行一次
    'send-timeout-warnings': {
        'task': 'app.customer_service_tasks.send_timeout_warnings_task',
        'schedule': 30.0,  # 30秒
    },
    # 清理长期无活动对话 - 每天凌晨2点执行
    'cleanup-long-inactive-chats': {
        'task': 'app.customer_service_tasks.cleanup_long_inactive_chats_task',
        'schedule': crontab(hour=2, minute=0),  # 每天凌晨2点
    },
}

# 如果使用内存后端，禁用结果存储
if not USE_REDIS:
    celery_app.conf.result_backend = None
    celery_app.conf.task_ignore_result = True

if __name__ == '__main__':
    celery_app.start()


#!/bin/bash
# Celery Worker/Beat 启动脚本
# 根据环境变量决定启动 Worker 还是 Beat

if [ "$CELERY_TYPE" = "beat" ]; then
    echo "Starting Celery Beat..."
    celery -A app.celery_app beat --loglevel=info
elif [ "$CELERY_TYPE" = "worker" ]; then
    echo "Starting Celery Worker..."
    celery -A app.celery_app worker --loglevel=info --concurrency=2
else
    echo "Error: CELERY_TYPE environment variable must be set to 'worker' or 'beat'"
    exit 1
fi


#!/bin/bash
# Railway 启动脚本

echo "Starting LinkU backend..."

# 设置默认端口
export PORT=${PORT:-8000}

echo "Using port: $PORT"

# 运行数据库迁移
echo "Running database migrations..."
python migrate_inviter_id.py

# 启动应用
echo "Starting application..."
exec python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT

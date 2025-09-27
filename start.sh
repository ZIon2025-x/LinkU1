#!/bin/bash
# Railway 启动脚本

echo "Starting LinkU backend..."

# 设置默认端口
export PORT=${PORT:-8000}

echo "Using port: $PORT"

# 启动应用
exec python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT

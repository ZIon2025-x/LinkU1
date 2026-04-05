#!/usr/bin/env python3
"""
后端主启动文件
独立部署的后端服务

生产环境使用 gunicorn + uvicorn workers 多进程部署
开发环境使用 uvicorn 单进程（支持热重载）
"""

import os
import uvicorn
from app.main import app

if __name__ == "__main__":
    is_production = os.getenv("ENVIRONMENT", "development") == "production" or \
                    os.getenv("RAILWAY_ENVIRONMENT", "") == "production"

    if is_production:
        # 生产环境：通过 gunicorn 启动（见 Dockerfile / gunicorn.conf.py）
        # 这里作为 fallback，如果直接 python main.py 也能跑
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=int(os.getenv("PORT", "8000")),
            log_level="info",
        )
    else:
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=8000,
            reload=True,
            log_level="info",
        )

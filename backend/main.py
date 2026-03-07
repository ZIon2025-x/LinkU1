#!/usr/bin/env python3
"""
后端主启动文件
独立部署的后端服务
"""

import os
import uvicorn
from app.main import app

if __name__ == "__main__":
    is_production = os.getenv("ENVIRONMENT", "development") == "production" or \
                    os.getenv("RAILWAY_ENVIRONMENT", "") == "production"
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=not is_production,
        log_level="info"
    )

#!/usr/bin/env python3
"""
本地开发环境启动脚本
配置适合本地开发的Cookie和安全设置
"""

import os
import sys
import uvicorn

# 设置本地开发环境变量
os.environ["ENVIRONMENT"] = "development"
os.environ["DEBUG"] = "true"
os.environ["COOKIE_SECURE"] = "false"
os.environ["COOKIE_SAMESITE"] = "lax"
os.environ["USE_REDIS"] = "false"  # 本地开发可以禁用Redis
os.environ["ALLOWED_ORIGINS"] = "http://localhost:3000,http://localhost:8080"

# 数据库配置
os.environ["DATABASE_URL"] = "postgresql+psycopg2://postgres:123123@localhost:5432/linku_db"
os.environ["ASYNC_DATABASE_URL"] = "postgresql+asyncpg://postgres:123123@localhost:5432/linku_db"

# JWT配置
os.environ["SECRET_KEY"] = "your-secret-key-change-in-production"
os.environ["ACCESS_TOKEN_EXPIRE_MINUTES"] = "15"
os.environ["REFRESH_TOKEN_EXPIRE_DAYS"] = "30"

print("🚀 启动本地开发环境...")
print("📝 环境配置:")
print(f"   - 环境: {os.environ.get('ENVIRONMENT')}")
print(f"   - 调试模式: {os.environ.get('DEBUG')}")
print(f"   - Cookie安全: {os.environ.get('COOKIE_SECURE')}")
print(f"   - Cookie SameSite: {os.environ.get('COOKIE_SAMESITE')}")
print(f"   - 使用Redis: {os.environ.get('USE_REDIS')}")
print(f"   - 允许的源: {os.environ.get('ALLOWED_ORIGINS')}")
print()

if __name__ == "__main__":
    try:
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=8000,
            reload=True,
            log_level="info"
        )
    except KeyboardInterrupt:
        print("\n👋 开发服务器已停止")
    except Exception as e:
        print(f"❌ 启动失败: {e}")
        sys.exit(1)

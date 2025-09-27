#!/usr/bin/env python3
"""
测试环境变量
"""
import os

print("=== 环境变量测试 ===")
print(f"DATABASE_URL: {os.getenv('DATABASE_URL', 'Not set')}")
print(f"ASYNC_DATABASE_URL: {os.getenv('ASYNC_DATABASE_URL', 'Not set')}")
print(f"REDIS_URL: {os.getenv('REDIS_URL', 'Not set')}")
print(f"PORT: {os.getenv('PORT', 'Not set')}")

# 检查数据库连接
try:
    from backend.app.database import DATABASE_URL, ASYNC_DATABASE_URL
    print(f"\n=== 数据库配置 ===")
    print(f"DATABASE_URL from app.database: {DATABASE_URL}")
    print(f"ASYNC_DATABASE_URL from app.database: {ASYNC_DATABASE_URL}")
except Exception as e:
    print(f"导入数据库配置失败: {e}")

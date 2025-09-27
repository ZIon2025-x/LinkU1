#!/usr/bin/env python3
"""
Railway 数据库初始化脚本 - 直接创建表
"""
import os
import sys
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_dir))

# 切换到 backend 目录
os.chdir(backend_dir)

def init_database():
    """初始化数据库表"""
    print("Initializing Railway database...")
    print(f"Current directory: {os.getcwd()}")
    print(f"DATABASE_URL: {os.getenv('DATABASE_URL', 'Not set')}")
    
    try:
        from app.database import sync_engine
        from app.models import Base
        
        # 创建所有表
        print("Creating database tables...")
        Base.metadata.create_all(bind=sync_engine)
        print("Database tables created successfully!")
        
        # 验证表是否创建
        from sqlalchemy import inspect
        inspector = inspect(sync_engine)
        tables = inspector.get_table_names()
        print(f"Created tables: {tables}")
        
    except Exception as e:
        print(f"Database initialization failed: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    success = init_database()
    sys.exit(0 if success else 1)

#!/usr/bin/env python3
"""
测试数据库迁移脚本
"""
import os
import sys
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_dir))

# 切换到 backend 目录
os.chdir(backend_dir)

def test_migration():
    """测试迁移"""
    print("Testing database migration...")
    print(f"Current directory: {os.getcwd()}")
    print(f"DATABASE_URL: {os.getenv('DATABASE_URL', 'Not set')}")
    
    try:
        from alembic.config import Config
        from alembic import command
        
        # 创建 Alembic 配置
        alembic_cfg = Config("alembic.ini")
        
        # 检查当前版本
        print("Checking current database version...")
        command.current(alembic_cfg)
        
        # 运行迁移
        print("Running database migration...")
        command.upgrade(alembic_cfg, "head")
        print("Database migration completed!")
        
    except Exception as e:
        print(f"Migration failed: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    success = test_migration()
    sys.exit(0 if success else 1)

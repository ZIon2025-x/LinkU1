#!/usr/bin/env python3
"""
Railway 数据库迁移脚本
"""
import os
import sys
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_dir))

# 切换到 backend 目录
os.chdir(backend_dir)

from alembic.config import Config
from alembic import command

def main():
    """运行数据库迁移"""
    print("🚀 开始 Railway 数据库迁移...")
    print(f"当前工作目录: {os.getcwd()}")
    print(f"DATABASE_URL: {os.getenv('DATABASE_URL', 'Not set')}")
    
    # 创建 Alembic 配置
    alembic_cfg = Config("alembic.ini")
    
    try:
        # 运行迁移
        print("📊 运行数据库迁移...")
        command.upgrade(alembic_cfg, "head")
        print("✅ 数据库迁移完成！")
        
    except Exception as e:
        print(f"❌ 迁移失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()

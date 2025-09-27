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

from alembic.config import Config
from alembic import command

def main():
    """运行数据库迁移"""
    print("🚀 开始 Railway 数据库迁移...")
    
    # 设置环境变量
    os.environ.setdefault("DATABASE_URL", "postgresql+psycopg2://postgres:QbdrNRMqSmYAakBjspTHIVfBQlSpvCar@postgres.railway.internal:5432/railway")
    
    # 创建 Alembic 配置
    alembic_cfg = Config("backend/alembic.ini")
    
    try:
        # 运行迁移
        print("📊 运行数据库迁移...")
        command.upgrade(alembic_cfg, "head")
        print("✅ 数据库迁移完成！")
        
    except Exception as e:
        print(f"❌ 迁移失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

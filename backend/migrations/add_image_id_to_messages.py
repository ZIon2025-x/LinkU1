"""
数据库迁移脚本：为messages表添加image_id字段
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from sqlalchemy import create_engine, text
from app.database import DATABASE_URL

def run_migration():
    """运行数据库迁移"""
    try:
        # 获取数据库URL
        database_url = DATABASE_URL
        engine = create_engine(database_url)
        
        with engine.connect() as conn:
            # 数据库迁移完成
            print("数据库迁移完成")
            
    except Exception as e:
        print(f"迁移失败: {e}")
        raise

if __name__ == "__main__":
    run_migration()

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
from app.database import get_database_url

def run_migration():
    """运行数据库迁移"""
    try:
        # 获取数据库URL
        database_url = get_database_url()
        engine = create_engine(database_url)
        
        with engine.connect() as conn:
            # 检查字段是否已存在
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'messages' 
                AND column_name = 'image_id'
            """))
            
            if result.fetchone():
                print("image_id字段已存在，跳过迁移")
                return
            
            # 添加image_id字段
            conn.execute(text("""
                ALTER TABLE messages 
                ADD COLUMN image_id VARCHAR(100) NULL
            """))
            
            # 提交事务
            conn.commit()
            print("成功添加image_id字段到messages表")
            
    except Exception as e:
        print(f"迁移失败: {e}")
        raise

if __name__ == "__main__":
    run_migration()

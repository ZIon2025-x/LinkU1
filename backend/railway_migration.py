#!/usr/bin/env python3
"""
Railway数据库迁移脚本 - 添加image_id字段
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def run_railway_migration():
    """在Railway环境中运行数据库迁移"""
    try:
        # 获取Railway数据库URL
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            print("错误: 未找到DATABASE_URL环境变量")
            return False
        
        print(f"数据库URL: {database_url[:20]}...")
        
        # 使用psycopg2直接连接
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        
        # 连接数据库
        conn = psycopg2.connect(database_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        try:
            # 检查字段是否已存在
            print("检查image_id字段是否已存在...")
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'messages' 
                AND column_name = 'image_id'
            """)
            
            if cursor.fetchone():
                print("image_id字段已存在，跳过添加")
                return True
            
            # 添加image_id字段
            print("添加image_id字段到messages表...")
            cursor.execute("""
                ALTER TABLE messages 
                ADD COLUMN image_id VARCHAR(100) NULL
            """)
            
            # 添加索引
            print("添加索引...")
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_messages_image_id 
                ON messages(image_id)
            """)
            
            print("✅ 成功添加image_id字段到messages表")
            return True
            
        except Exception as e:
            print(f"❌ 数据库操作失败: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
            
    except Exception as e:
        print(f"❌ 连接数据库失败: {e}")
        return False

if __name__ == "__main__":
    success = run_railway_migration()
    sys.exit(0 if success else 1)

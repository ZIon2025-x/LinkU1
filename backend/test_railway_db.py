#!/usr/bin/env python3
"""
测试Railway数据库连接和image_id字段
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def test_railway_db():
    """测试Railway数据库"""
    try:
        # 设置Railway环境变量
        railway_db_url = os.getenv('DATABASE_URL')
        if not railway_db_url:
            print("未找到DATABASE_URL环境变量")
            return
        
        print(f"数据库URL: {railway_db_url[:50]}...")
        
        # 使用psycopg2直接连接
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        
        conn = psycopg2.connect(railway_db_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        try:
            # 检查messages表结构
            cursor.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'messages' 
                ORDER BY ordinal_position
            """)
            columns = cursor.fetchall()
            print("Messages表结构:")
            for col in columns:
                print(f"  {col[0]}: {col[1]}")
            
            # 检查是否有image_id列
            has_image_id = any(col[0] == 'image_id' for col in columns)
            print(f"\n是否有image_id列: {has_image_id}")
            
            if not has_image_id:
                print("添加image_id字段...")
                cursor.execute("""
                    ALTER TABLE messages 
                    ADD COLUMN image_id VARCHAR(100) NULL
                """)
                print("image_id字段添加成功！")
                
                # 添加索引
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_messages_image_id 
                    ON messages(image_id)
                """)
                print("索引添加成功！")
            
            # 检查最近的消息
            cursor.execute("""
                SELECT id, content, image_id 
                FROM messages 
                ORDER BY id DESC 
                LIMIT 5
            """)
            messages = cursor.fetchall()
            print("\n最近的消息:")
            for msg in messages:
                print(f"  ID: {msg[0]}, Content: {msg[1][:50]}..., Image ID: {msg[2]}")
                
        finally:
            cursor.close()
            conn.close()
            
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_railway_db()

#!/usr/bin/env python3
"""
添加image_id字段到messages表
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from sqlalchemy import create_engine, text
from app.database import DATABASE_URL

def add_image_id_field():
    """添加image_id字段到messages表"""
    try:
        print("正在连接数据库...")
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            
            try:
                # 检查字段是否已存在
                print("检查image_id字段是否已存在...")
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'messages' 
                    AND column_name = 'image_id'
                """))
                
                if result.fetchone():
                    print("image_id字段已存在，跳过添加")
                    trans.rollback()
                    return
                
                # 添加image_id字段
                print("添加image_id字段...")
                conn.execute(text("""
                    ALTER TABLE messages 
                    ADD COLUMN image_id VARCHAR(100) NULL
                """))
                
                # 添加索引
                print("添加索引...")
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_messages_image_id 
                    ON messages(image_id)
                """))
                
                # 提交事务
                trans.commit()
                print("✅ 成功添加image_id字段到messages表")
                
            except Exception as e:
                print(f"❌ 添加字段失败: {e}")
                trans.rollback()
                raise
                
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        raise

if __name__ == "__main__":
    add_image_id_field()

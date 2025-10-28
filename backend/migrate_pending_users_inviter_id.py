#!/usr/bin/env python3
"""
数据库迁移脚本 - 添加 inviter_id 列到 pending_users 表
"""

import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

def add_pending_users_inviter_id_column():
    """添加 inviter_id 列到 pending_users 表"""
    load_dotenv()
    
    # 获取数据库URL
    database_url = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:password@localhost:5432/linku_db")
    
    # 如果是 Railway 环境，使用异步数据库URL
    if "railway" in database_url.lower() or "postgresql+psycopg2" in database_url:
        # 转换为同步连接
        sync_url = database_url.replace("postgresql+psycopg2://", "postgresql://")
    else:
        sync_url = database_url
    
    print(f"Connecting to database: {sync_url[:50]}...")
    
    try:
        engine = create_engine(sync_url)
        
        with engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            
            try:
                # 检查列是否已存在
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'pending_users' AND column_name = 'inviter_id'
                """))
                
                if result.fetchone() is None:
                    # 列不存在，添加它
                    print("Adding inviter_id column to pending_users table...")
                    
                    # 先添加基本列
                    conn.execute(text('ALTER TABLE pending_users ADD COLUMN inviter_id TEXT'))
                    
                    # 修改列类型为 VARCHAR(8)
                    conn.execute(text('ALTER TABLE pending_users ALTER COLUMN inviter_id TYPE VARCHAR(8)'))
                    
                    # 添加外键约束
                    conn.execute(text('ALTER TABLE pending_users ADD CONSTRAINT fk_pending_users_inviter_id FOREIGN KEY (inviter_id) REFERENCES users(id)'))
                    
                    trans.commit()
                    print("✅ inviter_id column added successfully to pending_users table")
                else:
                    print("ℹ️ inviter_id column already exists in pending_users table")
                    trans.commit()
                    
            except Exception as e:
                trans.rollback()
                print(f"❌ Failed to add column: {e}")
                raise
                
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    add_pending_users_inviter_id_column()

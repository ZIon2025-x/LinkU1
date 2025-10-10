#!/usr/bin/env python3
"""
添加messages表新字段的脚本
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def add_message_fields():
    """为messages表添加新字段"""
    
    # 数据库连接
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/linku")
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    with SessionLocal() as db:
        try:
            logger.info("开始为messages表添加新字段...")
            
            # 添加时区字段
            alter_sql = """
            ALTER TABLE messages 
            ADD COLUMN IF NOT EXISTS created_at_tz VARCHAR(50) DEFAULT 'UTC';
            """
            db.execute(text(alter_sql))
            logger.info("✅ 添加 created_at_tz 字段")
            
            # 添加本地时间字段
            alter_sql2 = """
            ALTER TABLE messages 
            ADD COLUMN IF NOT EXISTS local_time TEXT;
            """
            db.execute(text(alter_sql2))
            logger.info("✅ 添加 local_time 字段")
            
            # 更新现有数据的时区信息
            update_sql = """
            UPDATE messages 
            SET created_at_tz = 'Europe/London (Legacy)' 
            WHERE created_at_tz IS NULL;
            """
            db.execute(text(update_sql))
            logger.info("✅ 更新现有数据的时区信息")
            
            # 提交更改
            db.commit()
            logger.info("✅ 字段添加完成！")
            
            # 验证结果
            check_sql = """
            SELECT 
                COUNT(*) as total,
                COUNT(created_at_tz) as with_tz,
                COUNT(local_time) as with_local
            FROM messages
            """
            result = db.execute(text(check_sql))
            stats = result.fetchone()
            
            logger.info(f"📊 messages表统计:")
            logger.info(f"  总记录数: {stats[0]}")
            logger.info(f"  有时区信息: {stats[1]}")
            logger.info(f"  有本地时间: {stats[2]}")
            
        except Exception as e:
            logger.error(f"❌ 添加字段失败: {e}")
            db.rollback()
            raise

def main():
    """主函数"""
    try:
        add_message_fields()
        print("\n✅ 字段添加完成！")
    except Exception as e:
        print(f"\n❌ 添加失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

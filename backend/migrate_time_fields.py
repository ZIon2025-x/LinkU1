#!/usr/bin/env python3
"""
时间字段迁移脚本
将现有的时间字段从英国时间迁移到UTC时间系统
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text, MetaData, Table, Column, String, DateTime
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import pytz
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_time_fields():
    """迁移时间字段到新的UTC系统"""
    
    # 数据库连接
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/linku")
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    with SessionLocal() as db:
        try:
            logger.info("开始时间字段迁移...")
            
            # 需要迁移的表和字段
            tables_to_migrate = [
                {
                    "table": "users",
                    "fields": ["created_at"],
                    "add_tz_field": True
                },
                {
                    "table": "tasks", 
                    "fields": ["created_at", "accepted_at", "completed_at"],
                    "add_tz_field": True
                },
                {
                    "table": "task_reviews",
                    "fields": ["created_at"],
                    "add_tz_field": True
                },
                {
                    "table": "notifications",
                    "fields": ["created_at"],
                    "add_tz_field": True
                },
                {
                    "table": "admin_requests",
                    "fields": ["created_at", "reviewed_at"],
                    "add_tz_field": True
                },
                {
                    "table": "admin_chat_messages",
                    "fields": ["created_at"],
                    "add_tz_field": True
                },
                {
                    "table": "admin_users",
                    "fields": ["created_at", "last_login"],
                    "add_tz_field": True
                },
                {
                    "table": "admin_notifications",
                    "fields": ["created_at", "read_at"],
                    "add_tz_field": True
                },
                {
                    "table": "admin_settings",
                    "fields": ["created_at", "updated_at"],
                    "add_tz_field": True
                },
                {
                    "table": "customer_service_chats",
                    "fields": ["created_at", "ended_at", "last_message_at"],
                    "add_tz_field": True
                },
                {
                    "table": "customer_service_messages",
                    "fields": ["created_at"],
                    "add_tz_field": True
                },
                {
                    "table": "email_verifications",
                    "fields": ["created_at", "expires_at"],
                    "add_tz_field": True
                },
                {
                    "table": "vip_applications",
                    "fields": ["created_at"],
                    "add_tz_field": True
                }
            ]
            
            # 1. 添加时区字段
            logger.info("1. 添加时区字段...")
            for table_info in tables_to_migrate:
                table_name = table_info["table"]
                try:
                    # 添加时区字段
                    alter_sql = f"""
                    ALTER TABLE {table_name} 
                    ADD COLUMN IF NOT EXISTS created_at_tz VARCHAR(50) DEFAULT 'UTC';
                    """
                    db.execute(text(alter_sql))
                    logger.info(f"  ✅ {table_name}: 添加时区字段")
                except Exception as e:
                    logger.warning(f"  ⚠️ {table_name}: 添加时区字段失败 - {e}")
            
            # 2. 更新现有数据
            logger.info("2. 更新现有数据...")
            uk_tz = pytz.timezone("Europe/London")
            
            for table_info in tables_to_migrate:
                table_name = table_info["table"]
                fields = table_info["fields"]
                
                for field in fields:
                    try:
                        # 获取需要更新的记录
                        select_sql = f"""
                        SELECT id, {field} 
                        FROM {table_name} 
                        WHERE {field} IS NOT NULL 
                        AND created_at_tz IS NULL
                        LIMIT 1000
                        """
                        
                        result = db.execute(text(select_sql))
                        records = result.fetchall()
                        
                        if records:
                            logger.info(f"  📝 {table_name}.{field}: 找到 {len(records)} 条记录需要更新")
                            
                            for record in records:
                                record_id, time_value = record
                                
                                try:
                                    # 假设现有时间是英国时间，转换为UTC
                                    if isinstance(time_value, datetime):
                                        # 如果时间没有时区信息，假设是英国时间
                                        if time_value.tzinfo is None:
                                            uk_time = uk_tz.localize(time_value)
                                        else:
                                            uk_time = time_value
                                        
                                        # 转换为UTC
                                        utc_time = uk_time.astimezone(pytz.UTC)
                                        
                                        # 更新记录
                                        update_sql = f"""
                                        UPDATE {table_name} 
                                        SET {field} = :utc_time, 
                                            created_at_tz = :tz_info
                                        WHERE id = :record_id
                                        """
                                        
                                        db.execute(text(update_sql), {
                                            "utc_time": utc_time.replace(tzinfo=None),
                                            "tz_info": "Europe/London (Legacy)",
                                            "record_id": record_id
                                        })
                                        
                                except Exception as e:
                                    logger.warning(f"    ⚠️ 记录 {record_id} 更新失败: {e}")
                                    continue
                            
                            # 提交更改
                            db.commit()
                            logger.info(f"  ✅ {table_name}.{field}: 更新完成")
                        else:
                            logger.info(f"  ℹ️ {table_name}.{field}: 无需更新")
                            
                    except Exception as e:
                        logger.warning(f"  ⚠️ {table_name}.{field}: 更新失败 - {e}")
                        db.rollback()
                        continue
            
            # 3. 更新默认值
            logger.info("3. 更新默认值...")
            try:
                # 更新Message表的默认值
                update_message_default = """
                ALTER TABLE messages 
                ALTER COLUMN created_at SET DEFAULT (NOW() AT TIME ZONE 'UTC');
                """
                db.execute(text(update_message_default))
                logger.info("  ✅ messages表: 更新默认值为UTC")
                
            except Exception as e:
                logger.warning(f"  ⚠️ 更新默认值失败: {e}")
            
            # 4. 验证迁移结果
            logger.info("4. 验证迁移结果...")
            try:
                # 检查messages表
                check_sql = """
                SELECT 
                    COUNT(*) as total,
                    COUNT(created_at_tz) as with_tz,
                    MIN(created_at) as min_time,
                    MAX(created_at) as max_time
                FROM messages
                """
                
                result = db.execute(text(check_sql))
                stats = result.fetchone()
                
                logger.info(f"  📊 messages表统计:")
                logger.info(f"    总记录数: {stats[0]}")
                logger.info(f"    有时区信息: {stats[1]}")
                logger.info(f"    最早时间: {stats[2]}")
                logger.info(f"    最晚时间: {stats[3]}")
                
            except Exception as e:
                logger.warning(f"  ⚠️ 验证失败: {e}")
            
            logger.info("✅ 时间字段迁移完成！")
            
        except Exception as e:
            logger.error(f"❌ 迁移失败: {e}")
            db.rollback()
            raise

def rollback_migration():
    """回滚迁移（如果需要）"""
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/linku")
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    with SessionLocal() as db:
        try:
            logger.info("开始回滚时间字段迁移...")
            
            # 删除时区字段
            tables = [
                "users", "tasks", "task_reviews", "notifications", 
                "admin_requests", "admin_chat_messages", "admin_users",
                "admin_notifications", "admin_settings", "customer_service_chats",
                "customer_service_messages", "email_verifications", "vip_applications"
            ]
            
            for table_name in tables:
                try:
                    alter_sql = f"ALTER TABLE {table_name} DROP COLUMN IF EXISTS created_at_tz;"
                    db.execute(text(alter_sql))
                    logger.info(f"  ✅ {table_name}: 删除时区字段")
                except Exception as e:
                    logger.warning(f"  ⚠️ {table_name}: 删除时区字段失败 - {e}")
            
            db.commit()
            logger.info("✅ 回滚完成！")
            
        except Exception as e:
            logger.error(f"❌ 回滚失败: {e}")
            db.rollback()
            raise

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="时间字段迁移工具")
    parser.add_argument("--rollback", action="store_true", help="回滚迁移")
    args = parser.parse_args()
    
    if args.rollback:
        rollback_migration()
    else:
        migrate_time_fields()

if __name__ == "__main__":
    main()

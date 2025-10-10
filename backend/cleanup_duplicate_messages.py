#!/usr/bin/env python3
"""
清理重复消息脚本
删除数据库中的重复消息记录
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.models import Message, Base
from datetime import datetime, timedelta
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def cleanup_duplicate_messages():
    """清理重复消息"""
    
    # 数据库连接
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/linku")
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    with SessionLocal() as db:
        try:
            # 查找重复消息
            logger.info("开始查找重复消息...")
            
            # 查找完全相同的消息（除了ID）
            duplicate_query = text("""
                SELECT sender_id, receiver_id, content, created_at, 
                       COUNT(*) as count, 
                       ARRAY_AGG(id ORDER BY id) as ids
                FROM messages 
                WHERE created_at >= NOW() - INTERVAL '24 hours'
                GROUP BY sender_id, receiver_id, content, created_at
                HAVING COUNT(*) > 1
                ORDER BY created_at DESC
            """)
            
            result = db.execute(duplicate_query)
            duplicates = result.fetchall()
            
            logger.info(f"找到 {len(duplicates)} 组重复消息")
            
            total_deleted = 0
            
            for row in duplicates:
                sender_id, receiver_id, content, created_at, count, ids = row
                
                logger.info(f"处理重复消息: {sender_id} -> {receiver_id}, 内容: '{content}', 时间: {created_at}, 数量: {count}")
                
                # 保留第一个ID，删除其他的
                ids_to_keep = [ids[0]]
                ids_to_delete = ids[1:]
                
                logger.info(f"保留ID: {ids_to_keep}, 删除ID: {ids_to_delete}")
                
                # 删除重复的消息
                delete_query = text("""
                    DELETE FROM messages 
                    WHERE id = ANY(:ids_to_delete)
                """)
                
                result = db.execute(delete_query, {"ids_to_delete": ids_to_delete})
                deleted_count = result.rowcount
                total_deleted += deleted_count
                
                logger.info(f"删除了 {deleted_count} 条重复消息")
            
            # 查找时间相差1小时但内容相同的消息
            logger.info("查找时间相差1小时但内容相同的消息...")
            
            time_diff_query = text("""
                SELECT DISTINCT m1.id as id1, m2.id as id2,
                       m1.sender_id, m1.receiver_id, m1.content,
                       m1.created_at as time1, m2.created_at as time2
                FROM messages m1
                JOIN messages m2 ON (
                    m1.sender_id = m2.sender_id AND
                    m1.receiver_id = m2.receiver_id AND
                    m1.content = m2.content AND
                    m1.id != m2.id AND
                    ABS(EXTRACT(EPOCH FROM (m1.created_at - m2.created_at))) BETWEEN 3500 AND 3700
                )
                WHERE m1.created_at >= NOW() - INTERVAL '24 hours'
                ORDER BY m1.created_at DESC
            """)
            
            result = db.execute(time_diff_query)
            time_diff_duplicates = result.fetchall()
            
            logger.info(f"找到 {len(time_diff_duplicates)} 组时间相差1小时的消息")
            
            for row in time_diff_duplicates:
                id1, id2, sender_id, receiver_id, content, time1, time2 = row
                
                logger.info(f"处理时间差异消息: {sender_id} -> {receiver_id}, 内容: '{content}'")
                logger.info(f"  ID {id1}: {time1}")
                logger.info(f"  ID {id2}: {time2}")
                
                # 删除时间较晚的那条（通常是错误的）
                if time1 > time2:
                    delete_id = id1
                    keep_id = id2
                else:
                    delete_id = id2
                    keep_id = id1
                
                logger.info(f"删除ID {delete_id}，保留ID {keep_id}")
                
                delete_query = text("DELETE FROM messages WHERE id = :delete_id")
                result = db.execute(delete_query, {"delete_id": delete_id})
                deleted_count = result.rowcount
                total_deleted += deleted_count
                
                logger.info(f"删除了 {deleted_count} 条时间错误的消息")
            
            # 提交更改
            db.commit()
            
            logger.info(f"清理完成！总共删除了 {total_deleted} 条重复消息")
            
            # 显示清理后的统计信息
            count_query = text("SELECT COUNT(*) FROM messages WHERE created_at >= NOW() - INTERVAL '24 hours'")
            result = db.execute(count_query)
            remaining_count = result.scalar()
            
            logger.info(f"清理后24小时内的消息数量: {remaining_count}")
            
        except Exception as e:
            logger.error(f"清理过程中发生错误: {e}")
            db.rollback()
            raise

def main():
    """主函数"""
    print("开始清理重复消息...")
    print("=" * 50)
    
    try:
        cleanup_duplicate_messages()
        print("\n✅ 清理完成！")
    except Exception as e:
        print(f"\n❌ 清理失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

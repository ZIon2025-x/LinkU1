#!/usr/bin/env python3
"""
检查数据库结构和image_id字段
"""

import sys
import os
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def check_database():
    """检查数据库结构"""
    try:
        from app.database import SessionLocal
        from app.models import Message
        from sqlalchemy import text

        db = SessionLocal()
        try:
            # 检查messages表结构
            result = db.execute(text("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'messages' 
                ORDER BY ordinal_position
            """))
            columns = result.fetchall()
            print('Messages表结构:')
            for col in columns:
                print(f'  {col[0]}: {col[1]}')
            
            # 检查是否有image_id列
            has_image_id = any(col[0] == 'image_id' for col in columns)
            print(f'\n是否有image_id列: {has_image_id}')
            
            # 检查最近的消息
            recent_messages = db.query(Message).order_by(Message.id.desc()).limit(5).all()
            print('\n最近的消息:')
            for msg in recent_messages:
                image_id = getattr(msg, 'image_id', 'N/A')
                print(f'  ID: {msg.id}, Content: {msg.content[:50]}..., Image ID: {image_id}')
                
        finally:
            db.close()
            
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    check_database()

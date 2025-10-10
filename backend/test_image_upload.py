#!/usr/bin/env python3
"""
测试图片上传功能
"""

import sys
import os
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def test_image_upload():
    """测试图片上传功能"""
    try:
        from app.database import SessionLocal
        from app.models import Message
        from sqlalchemy import text

        db = SessionLocal()
        try:
            # 检查messages表是否有image_id字段
            result = db.execute(text("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'messages' 
                AND column_name = 'image_id'
            """))
            
            has_image_id = result.fetchone() is not None
            print(f"数据库是否有image_id字段: {has_image_id}")
            
            if not has_image_id:
                print("添加image_id字段...")
                db.execute(text("""
                    ALTER TABLE messages 
                    ADD COLUMN image_id VARCHAR(100) NULL
                """))
                db.commit()
                print("image_id字段添加成功！")
                
                # 添加索引
                db.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_messages_image_id 
                    ON messages(image_id)
                """))
                db.commit()
                print("索引添加成功！")
            
            # 测试创建消息
            test_message = Message(
                sender_id="test_user",
                receiver_id="test_receiver", 
                content="测试消息",
                image_id="test_image_123"
            )
            
            db.add(test_message)
            db.commit()
            print("测试消息创建成功！")
            
            # 清理测试数据
            db.delete(test_message)
            db.commit()
            print("测试数据清理完成！")
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_image_upload()

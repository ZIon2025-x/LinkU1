#!/usr/bin/env python3
"""
测试消息发送流程，特别是image_id的赋值
"""

import sys
import os
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def test_message_flow():
    """测试消息发送流程"""
    try:
        from app.database import SessionLocal
        from app.models import Message
        from app import crud
        
        db = SessionLocal()
        try:
            # 测试创建消息
            test_image_id = "test_image_12345"
            test_content = f"[图片] {test_image_id}"
            
            print(f"测试创建消息:")
            print(f"  content: {test_content}")
            print(f"  image_id: {test_image_id}")
            
            # 检查Message模型是否有image_id字段
            print(f"Message模型是否有image_id字段: {hasattr(Message, 'image_id')}")
            
            # 创建消息
            message = crud.send_message(
                db=db,
                sender_id="test_sender",
                receiver_id="test_receiver", 
                content=test_content,
                image_id=test_image_id
            )
            
            print(f"消息创建成功!")
            print(f"  消息ID: {message.id}")
            print(f"  内容: {message.content}")
            print(f"  image_id: {getattr(message, 'image_id', 'N/A')}")
            
            # 从数据库重新查询验证
            db.refresh(message)
            print(f"从数据库重新查询:")
            print(f"  image_id: {getattr(message, 'image_id', 'N/A')}")
            
            # 清理测试数据
            db.delete(message)
            db.commit()
            print("测试数据清理完成!")
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_message_flow()

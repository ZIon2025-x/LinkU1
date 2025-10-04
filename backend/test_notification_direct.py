#!/usr/bin/env python3
"""
直接测试通知创建
"""

import sys
import os

# 添加项目路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal
from app import crud, models

def test_notification_creation():
    """直接测试通知创建"""
    print("Testing notification creation directly...")
    
    db = SessionLocal()
    try:
        # 1. 查找一个用户
        user = db.query(models.User).first()
        if not user:
            print("ERROR: No users found")
            return
        
        print(f"Found user: {user.id} - {user.name}")
        
        # 2. 直接创建通知
        print("Creating notification...")
        notification = crud.create_notification(
            db=db,
            user_id=user.id,
            type="test_notification",
            title="测试通知",
            content="这是一个测试通知",
            related_id="999"
        )
        
        if notification:
            print(f"SUCCESS: Notification created with ID: {notification.id}")
            print(f"Notification details: {notification.title} - {notification.content}")
        else:
            print("ERROR: Notification creation failed")
            return
        
        # 3. 查询通知
        notifications = db.query(models.Notification).filter(
            models.Notification.user_id == user.id
        ).all()
        
        print(f"User {user.id} has {len(notifications)} notifications:")
        for notif in notifications:
            print(f"  - ID: {notif.id}, Type: {notif.type}, Title: {notif.title}")
            
    except Exception as e:
        print(f"ERROR: Exception during test: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_notification_creation()

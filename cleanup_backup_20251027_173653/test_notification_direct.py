#!/usr/bin/env python3
"""
直接测试通知函数
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from backend.app.database import get_db
from backend.app.models import User, Task
from backend.app.task_notifications import send_task_application_notification, send_task_approval_notification
from fastapi import BackgroundTasks

def test_notification_functions():
    """直接测试通知函数"""
    print("=== 直接测试通知函数 ===\n")
    
    db = next(get_db())
    background_tasks = BackgroundTasks()
    
    try:
        # 1. 查找一个用户作为发布者
        print("1. 查找用户...")
        user = db.query(User).first()
        if not user:
            print("ERROR: 没有找到用户")
            return
        print(f"OK 找到用户: {user.name} (ID: {user.id})")
        
        # 2. 查找一个任务
        print("\n2. 查找任务...")
        task = db.query(Task).first()
        if not task:
            print("ERROR: 没有找到任务")
            return
        print(f"OK 找到任务: {task.title} (ID: {task.id})")
        
        # 3. 测试申请通知
        print("\n3. 测试申请通知...")
        try:
            send_task_application_notification(
                db=db,
                background_tasks=background_tasks,
                task=task,
                applicant=user,
                application_message="测试申请消息"
            )
            print("OK 申请通知发送成功")
        except Exception as e:
            print(f"ERROR 申请通知发送失败: {e}")
        
        # 4. 测试同意通知
        print("\n4. 测试同意通知...")
        try:
            send_task_approval_notification(
                db=db,
                background_tasks=background_tasks,
                task=task,
                applicant=user
            )
            print("OK 同意通知发送成功")
        except Exception as e:
            print(f"ERROR 同意通知发送失败: {e}")
        
        # 5. 检查数据库中的通知
        print("\n5. 检查数据库中的通知...")
        from backend.app.models import Notification
        notifications = db.query(Notification).order_by(Notification.created_at.desc()).limit(5).all()
        print(f"OK 最近5条通知:")
        for notif in notifications:
            print(f"  - ID: {notif.id}, 类型: {notif.type}, 标题: {notif.title}")
            print(f"    内容: {notif.content[:50]}...")
            print(f"    用户: {notif.user_id}, 时间: {notif.created_at}")
            print("  ---")
        
    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    test_notification_functions()

#!/usr/bin/env python3
"""
检查数据库中的通知记录
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from backend.app.database import get_db
from backend.app.models import Notification, User, Task
from sqlalchemy.orm import Session
from sqlalchemy import text

def check_notifications():
    """检查数据库中的通知记录"""
    db = next(get_db())
    
    try:
        print("=== 检查数据库中的通知记录 ===\n")
        
        # 1. 查看所有通知类型
        print("1. 所有通知类型:")
        notification_types = db.query(Notification.type).distinct().all()
        for nt in notification_types:
            print(f"  - {nt[0]}")
        
        print("\n2. 各类型通知数量:")
        for nt in notification_types:
            count = db.query(Notification).filter(Notification.type == nt[0]).count()
            print(f"  - {nt[0]}: {count} 条")
        
        # 2. 查看最近的通知记录
        print("\n3. 最近10条通知记录:")
        recent_notifications = db.query(Notification).order_by(Notification.created_at.desc()).limit(10).all()
        for notif in recent_notifications:
            print(f"  ID: {notif.id}, 用户: {notif.user_id}, 类型: {notif.type}")
            print(f"  标题: {notif.title}")
            print(f"  内容: {notif.content[:100]}...")
            print(f"  时间: {notif.created_at}")
            print(f"  已读: {notif.is_read}")
            print("  ---")
        
        # 3. 检查任务相关的通知
        print("\n4. 任务相关通知:")
        task_notifications = db.query(Notification).filter(
            Notification.type.in_(['task_application', 'task_approved', 'task_completed', 'task_cancelled'])
        ).order_by(Notification.created_at.desc()).all()
        
        for notif in task_notifications:
            print(f"  ID: {notif.id}, 用户: {notif.user_id}, 类型: {notif.type}")
            print(f"  标题: {notif.title}")
            print(f"  内容: {notif.content}")
            print(f"  相关ID: {notif.related_id}")
            print(f"  时间: {notif.created_at}")
            print("  ---")
        
        # 4. 检查用户和任务数据
        print("\n5. 用户和任务统计:")
        user_count = db.query(User).count()
        task_count = db.query(Task).count()
        print(f"  用户总数: {user_count}")
        print(f"  任务总数: {task_count}")
        
        # 5. 检查任务状态分布
        print("\n6. 任务状态分布:")
        task_statuses = db.query(Task.status, db.func.count(Task.id)).group_by(Task.status).all()
        for status, count in task_statuses:
            print(f"  {status}: {count} 个")
        
        # 6. 检查是否有申请记录
        print("\n7. 检查任务申请记录:")
        try:
            # 尝试查询任务申请表
            result = db.execute(text("SELECT COUNT(*) FROM task_applications"))
            app_count = result.scalar()
            print(f"  任务申请记录数: {app_count}")
            
            if app_count > 0:
                # 查看申请记录详情
                result = db.execute(text("""
                    SELECT ta.*, t.title as task_title, u.name as applicant_name 
                    FROM task_applications ta 
                    LEFT JOIN tasks t ON ta.task_id = t.id 
                    LEFT JOIN users u ON ta.applicant_id = u.id 
                    ORDER BY ta.created_at DESC 
                    LIMIT 5
                """))
                applications = result.fetchall()
                print("  最近5条申请记录:")
                for app in applications:
                    print(f"    申请ID: {app[0]}, 任务: {app[6]}, 申请者: {app[7]}, 状态: {app[3]}")
        except Exception as e:
            print(f"  查询申请记录失败: {e}")
        
    except Exception as e:
        print(f"检查通知记录时出错: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_notifications()

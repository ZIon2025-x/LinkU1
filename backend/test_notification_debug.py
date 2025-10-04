#!/usr/bin/env python3
"""
调试通知系统 - 直接测试通知创建
"""

import requests
import json
import time
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import os

# 数据库连接
DATABASE_URL = "sqlite:///./backend/app/database.db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

BASE_URL = "http://localhost:8000"

def test_direct_notification_creation():
    """直接测试通知创建"""
    print("[DEBUG] 直接测试通知创建...")
    
    db = SessionLocal()
    try:
        # 1. 查找一个用户ID
        result = db.execute(text("SELECT id FROM users LIMIT 1"))
        user_id = result.fetchone()
        if not user_id:
            print("[ERROR] 没有找到用户")
            return
        user_id = user_id[0]
        print(f"✅ 找到用户ID: {user_id}")
        
        # 2. 直接创建通知
        from app import crud
        
        notification = crud.create_notification(
            db=db,
            user_id=user_id,
            type="test_notification",
            title="测试通知",
            content="这是一个测试通知，用于验证通知系统是否正常工作。",
            related_id="999"
        )
        
        if notification:
            print(f"✅ 通知创建成功，ID: {notification.id}")
        else:
            print("❌ 通知创建失败")
            return
            
        # 3. 查询通知
        result = db.execute(text("SELECT * FROM notifications WHERE user_id = :user_id ORDER BY created_at DESC LIMIT 5"), 
                          {"user_id": user_id})
        notifications = result.fetchall()
        
        print(f"✅ 用户 {user_id} 的通知数量: {len(notifications)}")
        for notif in notifications:
            print(f"  - ID: {notif[0]}, 类型: {notif[2]}, 标题: {notif[3]}, 内容: {notif[4]}")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

def test_task_application_flow():
    """测试任务申请流程"""
    print("\n[DEBUG] 测试任务申请流程...")
    
    # 1. 注册发布者
    print("\n1. 注册发布者...")
    poster_data = {
        "email": "poster_debug@example.com",
        "password": "testpass123",
        "name": "poster_debug",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=poster_data)
        if response.status_code == 200:
            print("[SUCCESS] 发布者注册成功")
        else:
            print(f"❌ 发布者注册失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 发布者注册异常: {e}")
        return
    
    # 2. 登录发布者
    print("\n2. 登录发布者...")
    try:
        login_data = {
            "email": poster_data["email"],
            "password": poster_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("✅ 发布者登录成功")
            poster_cookies = response.cookies
        else:
            print(f"❌ 发布者登录失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 发布者登录异常: {e}")
        return
    
    # 3. 创建任务
    print("\n3. 创建任务...")
    try:
        task_data = {
            "title": "通知调试任务",
            "description": "这是一个用于调试通知系统的任务",
            "reward": 50.0,
            "task_level": "normal",
            "location": "测试地点"
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks", 
            json=task_data,
            cookies=poster_cookies
        )
        if response.status_code == 200:
            task = response.json()
            task_id = task["id"]
            print(f"✅ 任务创建成功，ID: {task_id}")
        else:
            print(f"❌ 任务创建失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 任务创建异常: {e}")
        return
    
    # 4. 注册申请者
    print("\n4. 注册申请者...")
    applicant_data = {
        "email": "applicant_debug@example.com",
        "password": "testpass123",
        "name": "applicant_debug",
        "phone": "0987654321"
    }
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=applicant_data)
        if response.status_code == 200:
            print("✅ 申请者注册成功")
        else:
            print(f"❌ 申请者注册失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 申请者注册异常: {e}")
        return
    
    # 5. 登录申请者
    print("\n5. 登录申请者...")
    try:
        login_data = {
            "email": applicant_data["email"],
            "password": applicant_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("✅ 申请者登录成功")
            applicant_cookies = response.cookies
        else:
            print(f"❌ 申请者登录失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 申请者登录异常: {e}")
        return
    
    # 6. 申请任务
    print("\n6. 申请任务...")
    try:
        apply_data = {
            "message": "我想申请这个任务！"
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks/{task_id}/apply",
            json=apply_data,
            cookies=applicant_cookies
        )
        if response.status_code == 200:
            print("✅ 任务申请成功")
        else:
            print(f"❌ 任务申请失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 任务申请异常: {e}")
        return
    
    # 7. 检查发布者通知
    print("\n7. 检查发布者通知...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=poster_cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"✅ 发布者收到 {len(notifications)} 条通知")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"❌ 获取发布者通知失败: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ 检查发布者通知异常: {e}")
    
    # 8. 检查数据库中的通知
    print("\n8. 检查数据库中的通知...")
    db = SessionLocal()
    try:
        result = db.execute(text("SELECT * FROM notifications ORDER BY created_at DESC LIMIT 10"))
        notifications = result.fetchall()
        
        print(f"✅ 数据库中的通知数量: {len(notifications)}")
        for notif in notifications:
            print(f"  - ID: {notif[0]}, 用户ID: {notif[1]}, 类型: {notif[2]}, 标题: {notif[3]}")
            print(f"    内容: {notif[4]}, 相关ID: {notif[5]}, 已读: {notif[6]}")
            
    except Exception as e:
        print(f"❌ 数据库查询异常: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    test_direct_notification_creation()
    test_task_application_flow()

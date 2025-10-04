#!/usr/bin/env python3
"""
测试通知系统是否正常工作
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_notification_system():
    """测试通知系统"""
    print("🧪 测试通知系统...")
    
    # 1. 注册测试用户
    print("\n1. 注册测试用户...")
    user_data = {
        "email": "notification_test@example.com",
        "password": "testpass123",
        "name": "notification_test",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=user_data)
        if response.status_code == 200:
            print("✅ 用户注册成功")
        else:
            print(f"❌ 用户注册失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 用户注册异常: {e}")
        return
    
    # 2. 登录用户
    print("\n2. 登录用户...")
    try:
        login_data = {
            "email": user_data["email"],
            "password": user_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("✅ 用户登录成功")
            cookies = response.cookies
        else:
            print(f"❌ 用户登录失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 用户登录异常: {e}")
        return
    
    # 3. 检查通知API
    print("\n3. 检查通知API...")
    try:
        # 获取通知列表
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=cookies)
        print(f"通知列表API状态: {response.status_code}")
        if response.status_code == 200:
            notifications = response.json()
            print(f"✅ 获取通知列表成功，数量: {len(notifications)}")
            for notif in notifications[:3]:  # 显示前3个通知
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"❌ 获取通知列表失败: {response.text}")
        
        # 获取未读通知数量
        response = requests.get(f"{BASE_URL}/api/notifications/unread/count", cookies=cookies)
        print(f"未读通知数量API状态: {response.status_code}")
        if response.status_code == 200:
            unread_data = response.json()
            print(f"✅ 获取未读通知数量成功: {unread_data.get('unread_count', 0)}")
        else:
            print(f"❌ 获取未读通知数量失败: {response.text}")
            
    except Exception as e:
        print(f"❌ 通知API测试异常: {e}")
    
    # 4. 创建测试通知
    print("\n4. 创建测试通知...")
    try:
        # 直接调用后端API创建通知
        notification_data = {
            "user_id": "12345678",  # 使用一个测试用户ID
            "type": "test_notification",
            "title": "测试通知",
            "content": "这是一个测试通知，用于验证通知系统是否正常工作。",
            "related_id": "1"
        }
        
        # 这里我们需要直接调用后端函数，因为前端没有创建通知的API
        print("注意：需要直接调用后端函数创建通知")
        print("可以通过数据库直接插入测试通知")
        
    except Exception as e:
        print(f"❌ 创建测试通知异常: {e}")
    
    # 5. 检查通知数据库表
    print("\n5. 检查通知数据库...")
    try:
        # 这里可以添加数据库查询逻辑
        print("建议检查数据库中的notifications表")
        print("SQL查询: SELECT * FROM notifications ORDER BY created_at DESC LIMIT 10;")
        
    except Exception as e:
        print(f"❌ 数据库检查异常: {e}")

def test_task_application_notification():
    """测试任务申请通知"""
    print("\n🧪 测试任务申请通知...")
    
    # 这里可以添加完整的任务申请流程测试
    print("建议运行完整的任务申请流程来测试通知")

if __name__ == "__main__":
    test_notification_system()
    test_task_application_notification()

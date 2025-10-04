#!/usr/bin/env python3
"""
直接测试通知创建
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_direct_notification():
    """直接测试通知创建"""
    print("Testing direct notification creation...")
    
    # 1. 注册用户
    print("\n1. Registering user...")
    timestamp = int(time.time())
    user_data = {
        "email": f"notification_test_{timestamp}@example.com",
        "password": "testpass123",
        "name": f"notification_test_{timestamp}",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=user_data)
        if response.status_code == 200:
            print("SUCCESS: User registered")
        else:
            print(f"ERROR: User registration failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: User registration exception: {e}")
        return
    
    # 2. 登录用户
    print("\n2. Logging in user...")
    try:
        login_data = {
            "email": user_data["email"],
            "password": user_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("SUCCESS: User logged in")
            cookies = response.cookies
        else:
            print(f"ERROR: User login failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: User login exception: {e}")
        return
    
    # 3. 直接创建通知（通过数据库）
    print("\n3. Creating notification directly...")
    try:
        # 这里我们需要直接调用后端API创建通知
        # 但是前端没有创建通知的API，我们需要通过其他方式
        
        # 先检查现有通知
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"SUCCESS: Found {len(notifications)} existing notifications")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"ERROR: Failed to get notifications: {response.status_code} - {response.text}")
            
    except Exception as e:
        print(f"ERROR: Notification creation exception: {e}")
    
    # 4. 检查未读通知数量
    print("\n4. Checking unread notification count...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications/unread/count", cookies=cookies)
        if response.status_code == 200:
            unread_data = response.json()
            print(f"SUCCESS: Unread count: {unread_data.get('unread_count', 0)}")
        else:
            print(f"ERROR: Failed to get unread count: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"ERROR: Unread count check exception: {e}")

if __name__ == "__main__":
    test_direct_notification()

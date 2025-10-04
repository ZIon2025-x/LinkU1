#!/usr/bin/env python3
"""
简单的通知测试
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_notifications():
    """测试通知系统"""
    print("Testing notification system...")
    
    # 1. 注册用户
    print("\n1. Registering user...")
    user_data = {
        "email": "test_notification@example.com",
        "password": "testpass123",
        "name": "test_notification",
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
    
    # 3. 检查通知
    print("\n3. Checking notifications...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"SUCCESS: Found {len(notifications)} notifications")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"ERROR: Failed to get notifications: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"ERROR: Notification check exception: {e}")
    
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
    test_notifications()

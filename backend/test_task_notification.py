#!/usr/bin/env python3
"""
测试任务申请通知
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_task_notification():
    """测试任务申请通知"""
    print("Testing task application notification...")
    
    # 1. 注册发布者
    print("\n1. Registering poster...")
    timestamp = int(time.time())
    poster_data = {
        "email": f"poster_test_{timestamp}@example.com",
        "password": "testpass123",
        "name": f"poster_test_{timestamp}",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=poster_data)
        if response.status_code == 200:
            print("SUCCESS: Poster registered")
        else:
            print(f"ERROR: Poster registration failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Poster registration exception: {e}")
        return
    
    # 2. 登录发布者
    print("\n2. Logging in poster...")
    try:
        login_data = {
            "email": poster_data["email"],
            "password": poster_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("SUCCESS: Poster logged in")
            poster_cookies = response.cookies
        else:
            print(f"ERROR: Poster login failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Poster login exception: {e}")
        return
    
    # 2.5. 获取CSRF token
    print("\n2.5. Getting CSRF token...")
    try:
        response = requests.get(f"{BASE_URL}/api/csrf/token", cookies=poster_cookies)
        if response.status_code == 200:
            csrf_data = response.json()
            csrf_token = csrf_data.get("csrf_token")
            print(f"SUCCESS: CSRF token obtained: {csrf_token[:10]}...")
            
            # 更新cookies，包含新的CSRF token
            poster_cookies.update(response.cookies)
            print(f"DEBUG: Updated cookies: {dict(poster_cookies)}")
        else:
            print(f"ERROR: Failed to get CSRF token: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: CSRF token exception: {e}")
        return
    
    # 3. 创建任务
    print("\n3. Creating task...")
    try:
        task_data = {
            "title": "Notification Test Task",
            "description": "This is a task for testing notifications",
            "reward": 5.0,
            "task_level": "normal",
            "location": "Test Location",
            "deadline": "2024-12-31T23:59:59",
            "task_type": "other"
        }
        headers = {
            "X-CSRF-Token": csrf_token
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks", 
            json=task_data,
            cookies=poster_cookies,
            headers=headers
        )
        if response.status_code == 200:
            task = response.json()
            task_id = task["id"]
            print(f"SUCCESS: Task created with ID: {task_id}")
            print(f"DEBUG: Task level: {task.get('task_level', 'N/A')}")
        else:
            print(f"ERROR: Task creation failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Task creation exception: {e}")
        return
    
    # 4. 注册申请者
    print("\n4. Registering applicant...")
    applicant_data = {
        "email": f"applicant_test_{timestamp}@example.com",
        "password": "testpass123",
        "name": f"applicant_test_{timestamp}",
        "phone": "0987654321"
    }
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=applicant_data)
        if response.status_code == 200:
            print("SUCCESS: Applicant registered")
        else:
            print(f"ERROR: Applicant registration failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Applicant registration exception: {e}")
        return
    
    # 5. 登录申请者
    print("\n5. Logging in applicant...")
    try:
        login_data = {
            "email": applicant_data["email"],
            "password": applicant_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("SUCCESS: Applicant logged in")
            applicant_cookies = response.cookies
        else:
            print(f"ERROR: Applicant login failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Applicant login exception: {e}")
        return
    
    # 5.5. 获取申请者CSRF token
    print("\n5.5. Getting applicant CSRF token...")
    try:
        response = requests.get(f"{BASE_URL}/api/csrf/token", cookies=applicant_cookies)
        if response.status_code == 200:
            csrf_data = response.json()
            applicant_csrf_token = csrf_data.get("csrf_token")
            print(f"SUCCESS: Applicant CSRF token obtained: {applicant_csrf_token[:10]}...")
            
            # 更新cookies，包含新的CSRF token
            applicant_cookies.update(response.cookies)
            print(f"DEBUG: Updated applicant cookies: {dict(applicant_cookies)}")
        else:
            print(f"ERROR: Failed to get applicant CSRF token: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Applicant CSRF token exception: {e}")
        return
    
    # 6. 申请任务
    print("\n6. Applying for task...")
    try:
        apply_data = {
            "message": "I want to apply for this task!"
        }
        headers = {
            "X-CSRF-Token": applicant_csrf_token
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks/{task_id}/apply",
            json=apply_data,
            cookies=applicant_cookies,
            headers=headers
        )
        if response.status_code == 200:
            print("SUCCESS: Task application submitted")
        else:
            print(f"ERROR: Task application failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Task application exception: {e}")
        return
    
    # 7. 检查发布者通知
    print("\n7. Checking poster notifications...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=poster_cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"SUCCESS: Poster has {len(notifications)} notifications")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"ERROR: Failed to get poster notifications: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"ERROR: Poster notification check exception: {e}")
    
    # 8. 发布者同意申请
    print("\n8. Approving application...")
    try:
        # 获取申请者ID
        response = requests.get(
            f"{BASE_URL}/api/tasks/{task_id}/applications",
            cookies=poster_cookies
        )
        if response.status_code == 200:
            applications = response.json()
            if applications:
                applicant_id = applications[0]["applicant_id"]
                print(f"SUCCESS: Found applicant ID: {applicant_id}")
                
                # 同意申请
                headers = {
                    "X-CSRF-Token": csrf_token
                }
                response = requests.post(
                    f"{BASE_URL}/api/tasks/{task_id}/approve/{applicant_id}",
                    cookies=poster_cookies,
                    headers=headers
                )
                if response.status_code == 200:
                    print("SUCCESS: Application approved")
                else:
                    print(f"ERROR: Application approval failed: {response.status_code} - {response.text}")
                    return
            else:
                print("ERROR: No applications found")
                return
        else:
            print(f"ERROR: Failed to get applications: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Application approval exception: {e}")
        return
    
    # 9. 检查申请者通知
    print("\n9. Checking applicant notifications...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=applicant_cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"SUCCESS: Applicant has {len(notifications)} notifications")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"ERROR: Failed to get applicant notifications: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"ERROR: Applicant notification check exception: {e}")

if __name__ == "__main__":
    test_task_notification()

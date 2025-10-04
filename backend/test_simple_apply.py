#!/usr/bin/env python3
"""
简单测试任务申请
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_simple_apply():
    """简单测试任务申请"""
    print("Testing simple task application...")
    
    # 1. 注册发布者
    print("\n1. Registering poster...")
    timestamp = int(time.time())
    poster_data = {
        "email": f"poster_simple_{timestamp}@example.com",
        "password": "testpass123",
        "name": f"poster_simple_{timestamp}",
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
    
    # 3. 获取CSRF token
    print("\n3. Getting CSRF token...")
    try:
        response = requests.get(f"{BASE_URL}/api/csrf/token", cookies=poster_cookies)
        if response.status_code == 200:
            csrf_data = response.json()
            csrf_token = csrf_data.get("csrf_token")
            print(f"SUCCESS: CSRF token obtained: {csrf_token[:10]}...")
            poster_cookies.update(response.cookies)
        else:
            print(f"ERROR: Failed to get CSRF token: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: CSRF token exception: {e}")
        return
    
    # 4. 创建任务
    print("\n4. Creating task...")
    try:
        task_data = {
            "title": "Simple Test Task",
            "description": "This is a simple test task",
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
    
    # 5. 注册申请者
    print("\n5. Registering applicant...")
    applicant_data = {
        "email": f"applicant_simple_{timestamp}@example.com",
        "password": "testpass123",
        "name": f"applicant_simple_{timestamp}",
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
    
    # 6. 登录申请者
    print("\n6. Logging in applicant...")
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
    
    # 7. 获取申请者CSRF token
    print("\n7. Getting applicant CSRF token...")
    try:
        response = requests.get(f"{BASE_URL}/api/csrf/token", cookies=applicant_cookies)
        if response.status_code == 200:
            csrf_data = response.json()
            applicant_csrf_token = csrf_data.get("csrf_token")
            print(f"SUCCESS: Applicant CSRF token obtained: {applicant_csrf_token[:10]}...")
            applicant_cookies.update(response.cookies)
        else:
            print(f"ERROR: Failed to get applicant CSRF token: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Applicant CSRF token exception: {e}")
        return
    
    # 8. 申请任务
    print("\n8. Applying for task...")
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
            print(f"Response: {response.json()}")
        else:
            print(f"ERROR: Task application failed: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"ERROR: Task application exception: {e}")
        return

if __name__ == "__main__":
    test_simple_apply()

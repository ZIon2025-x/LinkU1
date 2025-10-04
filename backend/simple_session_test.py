#!/usr/bin/env python3
"""
简单测试会话
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import requests

def simple_test():
    # 登录
    login_url = "http://localhost:8000/api/secure-auth/login"
    login_data = {
        "email": "kx24942@bristol.ac.uk",
        "password": "123456"
    }
    
    print("登录...")
    login_response = requests.post(login_url, json=login_data)
    print(f"登录状态: {login_response.status_code}")
    
    if login_response.status_code == 200:
        cookies = login_response.cookies
        print(f"Session ID: {cookies.get('session_id')}")
        
        # 测试通知API
        print("测试通知API...")
        notifications_url = "http://localhost:8000/api/notifications"
        response = requests.get(notifications_url, cookies=cookies)
        print(f"通知API状态: {response.status_code}")
        print(f"响应: {response.text}")

if __name__ == "__main__":
    simple_test()

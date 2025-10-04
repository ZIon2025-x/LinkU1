#!/usr/bin/env python3
"""
直接测试后端API
"""

import requests
import json

# 测试数据
session_id = "aQ6_U6XmBvnkGl8-msC19du_LHCFgLXqSLvwUQNgKWs"
user_id = "15310417"
csrf_token = "DvtsSu1CHr3cySsfQeTBgJZsGzjdbTaw1a5q0d47eqA"
refresh_token = "S1hN8yN5YOxARKm0sHhqi1ihF_WGeQi1eQBpLfGE3ao"

# 设置Cookie
cookies = {
    'user_id': user_id,
    'csrf_token': csrf_token,
    'session_id': session_id,
    'refresh_token': refresh_token
}

# 设置请求头
headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0'
}

print("测试notifications API...")
print(f"Session ID: {session_id}")
print(f"User ID: {user_id}")

try:
    response = requests.get(
        'http://localhost:8000/api/notifications?limit=20',
        cookies=cookies,
        headers=headers
    )
    
    print(f"状态码: {response.status_code}")
    print(f"响应头: {dict(response.headers)}")
    print(f"响应内容: {response.text}")
    
except Exception as e:
    print(f"请求失败: {e}")

print("\n测试认证状态API...")
try:
    response = requests.get(
        'http://localhost:8000/api/secure-auth/status',
        cookies=cookies,
        headers=headers
    )
    
    print(f"状态码: {response.status_code}")
    print(f"响应内容: {response.text}")
    
except Exception as e:
    print(f"请求失败: {e}")

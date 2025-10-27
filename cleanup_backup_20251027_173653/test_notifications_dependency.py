#!/usr/bin/env python3
"""
测试notifications API的依赖
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

print("测试notifications相关的API端点...")

# 测试1: 通知API
print("\n1. 通知API")
try:
    response = requests.get('http://localhost:8000/api/notifications?limit=20', cookies=cookies, headers=headers)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")
except Exception as e:
    print(f"请求失败: {e}")

# 测试2: 未读通知API
print("\n2. 未读通知API")
try:
    response = requests.get('http://localhost:8000/api/notifications/unread', cookies=cookies, headers=headers)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")
except Exception as e:
    print(f"请求失败: {e}")

# 测试3: 未读通知数量API
print("\n3. 未读通知数量API")
try:
    response = requests.get('http://localhost:8000/api/notifications/unread/count', cookies=cookies, headers=headers)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")
except Exception as e:
    print(f"请求失败: {e}")

# 测试4: 员工通知API
print("\n4. 员工通知API")
try:
    response = requests.get('http://localhost:8000/api/staff/notifications', cookies=cookies, headers=headers)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")
except Exception as e:
    print(f"请求失败: {e}")

# 测试5: 员工未读通知API
print("\n5. 员工未读通知API")
try:
    response = requests.get('http://localhost:8000/api/staff/notifications/unread', cookies=cookies, headers=headers)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")
except Exception as e:
    print(f"请求失败: {e}")

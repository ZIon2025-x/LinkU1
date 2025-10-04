#!/usr/bin/env python3
"""
简单注册测试
"""

import requests
import json

# 测试数据 - 使用符合要求的密码
test_data = {
    "name": "testuser999",
    "email": "testuser999@example.com", 
    "password": "Password123",  # 8位以上，包含字母和数字
    "phone": "1234567890"
}

print("测试注册功能...")
print(f"测试数据: {test_data}")

try:
    response = requests.post(
        'http://localhost:8000/api/users/register',
        json=test_data,
        headers={'Content-Type': 'application/json'}
    )
    
    print(f"状态码: {response.status_code}")
    print(f"响应头: {dict(response.headers)}")
    print(f"响应内容: {response.text}")
    
    if response.status_code == 200:
        print("注册成功！")
        data = response.json()
        print(f"用户ID: {data.get('user_id', 'N/A')}")
        print(f"消息: {data.get('message', 'N/A')}")
    else:
        print("注册失败")
        
except Exception as e:
    print(f"请求失败: {e}")
    import traceback
    traceback.print_exc()

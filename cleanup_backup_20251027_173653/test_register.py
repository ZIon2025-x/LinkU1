#!/usr/bin/env python3
"""
测试注册功能
"""

import requests
import json

# 测试数据
test_users = [
    {
        "name": "testuser1",
        "email": "testuser1@example.com",
        "password": "password123",
        "phone": "1234567890"
    },
    {
        "name": "testuser2", 
        "email": "testuser2@example.com",
        "password": "Password123",
        "phone": "0987654321"
    },
    {
        "name": "testuser3",
        "email": "testuser3@example.com", 
        "password": "12345678",  # 只有数字，应该失败
        "phone": "1111111111"
    },
    {
        "name": "testuser4",
        "email": "testuser4@example.com",
        "password": "abcdefgh",  # 只有字母，应该失败
        "phone": "2222222222"
    }
]

print("测试注册功能...")
print("=" * 50)

for i, user in enumerate(test_users, 1):
    print(f"\n测试用例 {i}: {user['name']}")
    print(f"邮箱: {user['email']}")
    print(f"密码: {user['password']}")
    print(f"电话: {user['phone']}")
    
    try:
        response = requests.post(
            'http://localhost:8000/api/users/register',
            json=user,
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"状态码: {response.status_code}")
        print(f"响应: {response.text}")
        
        if response.status_code == 200:
            print("注册成功")
        else:
            print("注册失败")
            
    except Exception as e:
        print(f"请求失败: {e}")
    
    print("-" * 30)

print("\n测试完成！")

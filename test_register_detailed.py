#!/usr/bin/env python3
"""
详细注册测试
"""

import requests
import json
import sys
import os
sys.path.append('backend')

from app.validators import UserValidator, validate_input
from app.schemas import UserCreate

def test_validation():
    print("测试验证器...")
    
    # 测试数据
    test_data = {
        "name": "testuser999",
        "email": "testuser999@example.com",
        "password": "Password123",
        "phone": "1234567890"
    }
    
    try:
        # 测试UserValidator
        validator = UserValidator(**test_data)
        print("UserValidator验证成功")
        print(f"验证结果: {validator.dict()}")
        
        # 测试validate_input
        validated_data = validate_input(test_data, UserValidator)
        print("validate_input验证成功")
        print(f"验证结果: {validated_data}")
        
    except Exception as e:
        print(f"验证失败: {e}")
        import traceback
        traceback.print_exc()

def test_register_api():
    print("\n测试注册API...")
    
    test_data = {
        "name": "testuser999",
        "email": "testuser999@example.com",
        "password": "Password123",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(
            'http://localhost:8000/api/users/register',
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"状态码: {response.status_code}")
        print(f"响应: {response.text}")
        
    except Exception as e:
        print(f"API请求失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_validation()
    test_register_api()

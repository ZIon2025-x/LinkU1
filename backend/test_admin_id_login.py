#!/usr/bin/env python3
"""
测试管理员ID登录功能
"""

import requests
import json
from datetime import datetime

# 配置
API_BASE_URL = "https://api.link2ur.com"

def test_admin_id_login():
    """测试管理员ID登录"""
    print("=== 管理员ID登录测试 ===")
    print(f"时间: {datetime.now()}")
    print(f"API地址: {API_BASE_URL}")
    print()
    
    # 测试数据
    test_cases = [
        {
            "name": "使用ID登录 (A6688)",
            "username": "A6688",
            "password": "test123"
        },
        {
            "name": "使用用户名登录",
            "username": "admin",
            "password": "test123"
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"{i}. {test_case['name']}")
        print(f"   用户名/ID: {test_case['username']}")
        
        login_data = {
            "username": test_case["username"],
            "password": test_case["password"]
        }
        
        try:
            response = requests.post(
                f"{API_BASE_URL}/api/auth/admin/login",
                json=login_data,
                headers={
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                timeout=10
            )
            
            print(f"   状态码: {response.status_code}")
            
            try:
                response_data = response.json()
                print(f"   响应: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
            except:
                print(f"   响应文本: {response.text}")
            
            # 分析响应
            if response.status_code == 202:
                print("   ✅ 需要邮箱验证码 - 这是正常的！")
            elif response.status_code == 401:
                print("   ❌ 401错误 - 用户名/ID或密码错误")
            elif response.status_code == 403:
                print("   ❌ 403错误 - 管理员账户被禁用")
            elif response.status_code == 200:
                print("   ✅ 登录成功 - 邮箱验证未启用")
            else:
                print(f"   ❓ 未知状态码: {response.status_code}")
                
        except Exception as e:
            print(f"   请求失败: {e}")
        
        print()

def test_admin_verification_flow():
    """测试管理员验证码流程"""
    print("=== 管理员验证码流程测试 ===")
    
    # 1. 发送验证码
    print("1. 发送验证码...")
    login_data = {
        "username": "A6688",  # 使用ID
        "password": "test123"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/auth/admin/send-verification-code",
            json=login_data,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            timeout=10
        )
        
        print(f"   状态码: {response.status_code}")
        try:
            response_data = response.json()
            print(f"   响应: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
            
            if response.status_code == 200 and "admin_id" in response_data:
                admin_id = response_data["admin_id"]
                print(f"   ✅ 验证码已发送，管理员ID: {admin_id}")
                
                # 2. 验证验证码（这里使用假验证码，实际需要从邮箱获取）
                print("\n2. 验证验证码...")
                verification_data = {
                    "admin_id": admin_id,
                    "code": "123456"  # 假验证码
                }
                
                verify_response = requests.post(
                    f"{API_BASE_URL}/api/auth/admin/verify-code",
                    json=verification_data,
                    headers={
                        "Content-Type": "application/json",
                        "Accept": "application/json"
                    },
                    timeout=10
                )
                
                print(f"   验证状态码: {verify_response.status_code}")
                try:
                    verify_data = verify_response.json()
                    print(f"   验证响应: {json.dumps(verify_data, indent=2, ensure_ascii=False)}")
                except:
                    print(f"   验证响应文本: {verify_response.text}")
            else:
                print("   ❌ 发送验证码失败")
                
        except Exception as e:
            print(f"   解析响应失败: {e}")
            
    except Exception as e:
        print(f"   发送验证码请求失败: {e}")

if __name__ == "__main__":
    print("管理员ID登录测试工具")
    print("=" * 50)
    
    # 测试ID登录
    test_admin_id_login()
    
    # 测试验证码流程
    test_admin_verification_flow()
    
    print("=== 测试完成 ===")
    print("现在管理员可以使用以下方式登录：")
    print("1. 用户名: admin")
    print("2. ID: A6688 (如果存在)")
    print("3. 任何有效的管理员ID格式: A + 4位数字")

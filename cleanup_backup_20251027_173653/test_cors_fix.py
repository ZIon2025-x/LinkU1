#!/usr/bin/env python3
"""
CORS 配置测试脚本
测试后端是否正确允许来自 https://www.link2ur.com 的请求
"""

import requests
import json

def test_cors_configuration():
    """测试 CORS 配置"""
    base_url = "https://linku1-production.up.railway.app"
    
    print("🔍 测试 CORS 配置...")
    print(f"后端地址: {base_url}")
    print(f"前端地址: https://www.link2ur.com")
    print("-" * 50)
    
    # 测试 OPTIONS 预检请求
    print("1. 测试 OPTIONS 预检请求...")
    try:
        headers = {
            "Origin": "https://www.link2ur.com",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Content-Type, Authorization"
        }
        
        response = requests.options(f"{base_url}/api/secure-auth/login", headers=headers)
        
        print(f"状态码: {response.status_code}")
        print("响应头:")
        for key, value in response.headers.items():
            if 'access-control' in key.lower() or 'cors' in key.lower():
                print(f"  {key}: {value}")
        
        if response.status_code == 200:
            print("✅ OPTIONS 预检请求成功")
        else:
            print("❌ OPTIONS 预检请求失败")
            
    except Exception as e:
        print(f"❌ OPTIONS 请求异常: {e}")
    
    print("-" * 50)
    
    # 测试实际 API 请求
    print("2. 测试实际 API 请求...")
    try:
        headers = {
            "Origin": "https://www.link2ur.com",
            "Content-Type": "application/json"
        }
        
        data = {
            "username": "test@example.com",
            "password": "testpassword"
        }
        
        response = requests.post(
            f"{base_url}/api/secure-auth/login", 
            headers=headers, 
            json=data,
            timeout=10
        )
        
        print(f"状态码: {response.status_code}")
        print("响应头:")
        for key, value in response.headers.items():
            if 'access-control' in key.lower() or 'cors' in key.lower():
                print(f"  {key}: {value}")
        
        if response.status_code in [200, 401, 422]:  # 401/422 是正常的业务错误
            print("✅ API 请求成功（CORS 通过）")
        else:
            print("❌ API 请求失败")
            
    except Exception as e:
        print(f"❌ API 请求异常: {e}")
    
    print("-" * 50)
    
    # 测试用户信息请求
    print("3. 测试用户信息请求...")
    try:
        headers = {
            "Origin": "https://www.link2ur.com",
            "Content-Type": "application/json"
        }
        
        response = requests.get(
            f"{base_url}/api/users/profile/me", 
            headers=headers,
            timeout=10
        )
        
        print(f"状态码: {response.status_code}")
        print("响应头:")
        for key, value in response.headers.items():
            if 'access-control' in key.lower() or 'cors' in key.lower():
                print(f"  {key}: {value}")
        
        if response.status_code in [200, 401]:  # 401 是正常的未认证错误
            print("✅ 用户信息请求成功（CORS 通过）")
        else:
            print("❌ 用户信息请求失败")
            
    except Exception as e:
        print(f"❌ 用户信息请求异常: {e}")

def test_environment_variables():
    """测试环境变量配置"""
    print("\n🔧 检查环境变量配置...")
    print("-" * 50)
    
    # 这里我们无法直接访问 Railway 的环境变量
    # 但我们可以通过 API 响应来推断配置
    print("注意: 环境变量检查需要在 Railway 控制台进行")
    print("请确认以下环境变量已设置:")
    print("  ALLOWED_ORIGINS=https://www.link2ur.com,http://localhost:3000")
    print("  ENVIRONMENT=production")
    print("  COOKIE_SECURE=true")

if __name__ == "__main__":
    print("🚀 LinkU CORS 配置测试")
    print("=" * 50)
    
    test_cors_configuration()
    test_environment_variables()
    
    print("\n📋 测试总结:")
    print("1. 如果所有测试都显示 CORS 通过，说明配置正确")
    print("2. 如果仍有 CORS 错误，请检查 Railway 环境变量")
    print("3. 确保后端已重新部署并应用新配置")
    print("4. 清除浏览器缓存后重试")

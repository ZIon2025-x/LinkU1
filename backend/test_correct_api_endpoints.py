#!/usr/bin/env python3
"""
测试正确的API端点
"""

import requests
import json
from datetime import datetime

def test_correct_api_endpoints():
    """测试正确的API端点"""
    print("🔧 测试正确的API端点")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 测试忘记密码功能 - 正确的端点
    print("1️⃣ 测试忘记密码功能 - 正确的端点")
    print("-" * 40)
    
    try:
        # 正确的端点应该是 /api/users/forgot_password
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        response = requests.post(
            forgot_password_url,
            data={"email": "zixiong316@gmail.com"},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        
        print(f"忘记密码请求状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 忘记密码请求成功")
            try:
                data = response.json()
                print(f"响应: {data}")
            except:
                print(f"响应: {response.text}")
        else:
            print(f"❌ 忘记密码请求失败: {response.status_code}")
            print(f"响应: {response.text}")
            
    except Exception as e:
        print(f"❌ 忘记密码测试异常: {e}")
    
    print()
    
    # 2. 测试用户注册功能
    print("2️⃣ 测试用户注册功能")
    print("-" * 40)
    
    try:
        register_url = f"{base_url}/api/users/register"
        
        # 使用测试邮箱
        test_credentials = {
            "name": "API端点测试用户",
            "email": "test-api-endpoints@example.com",
            "password": "testpassword123"
        }
        
        response = requests.post(
            register_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"注册状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 注册成功")
            try:
                data = response.json()
                print(f"注册响应: {data}")
                
                # 检查是否返回了验证要求
                if data.get("verification_required"):
                    print("✅ 邮件验证已启用")
                else:
                    print("❌ 邮件验证未启用")
                    
            except:
                print(f"注册响应: {response.text}")
        elif response.status_code == 400:
            print("❌ 注册失败 - 用户可能已存在")
            try:
                data = response.json()
                print(f"错误信息: {data}")
            except:
                print(f"错误信息: {response.text}")
        else:
            print(f"❌ 注册失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 注册测试异常: {e}")
    
    print()
    
    # 3. 测试其他可能的端点
    print("3️⃣ 测试其他可能的端点")
    print("-" * 40)
    
    # 测试不同的忘记密码端点
    test_endpoints = [
        "/api/users/forgot_password",
        "/api/forgot_password", 
        "/forgot_password",
        "/api/users/reset_password",
        "/api/reset_password"
    ]
    
    for endpoint in test_endpoints:
        try:
            url = f"{base_url}{endpoint}"
            response = requests.post(
                url,
                data={"email": "test@example.com"},
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=5
            )
            
            print(f"端点 {endpoint}: 状态码 {response.status_code}")
            if response.status_code == 200:
                print(f"  ✅ 成功: {response.text[:100]}...")
            elif response.status_code == 404:
                print(f"  ❌ 404 - 端点不存在")
            else:
                print(f"  ⚠️  其他状态码: {response.text[:100]}...")
                
        except Exception as e:
            print(f"  ❌ 异常: {e}")
    
    print()

def analyze_api_structure():
    """分析API结构"""
    print("📊 分析API结构")
    print("=" * 60)
    
    print("🔍 路由注册分析:")
    print("  1. user_router 注册为 /api/users 前缀")
    print("  2. forgot_password 在 user_router 中")
    print("  3. 完整路径应该是 /api/users/forgot_password")
    print()
    
    print("🔍 可能的问题:")
    print("  1. 端点路径错误")
    print("  2. 路由注册问题")
    print("  3. 中间件拦截")
    print("  4. 权限问题")
    print()
    
    print("🔧 解决方案:")
    print("  1. 使用正确的端点路径")
    print("  2. 检查路由注册")
    print("  3. 检查中间件配置")
    print("  4. 检查权限设置")
    print()

def main():
    """主函数"""
    print("🚀 测试正确的API端点")
    print("=" * 60)
    
    # 测试正确的API端点
    test_correct_api_endpoints()
    
    # 分析API结构
    analyze_api_structure()
    
    print("📋 测试总结:")
    print("API端点测试完成")
    print("请使用正确的端点路径 /api/users/forgot_password")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
详细测试忘记密码功能
"""

import requests
import json
from datetime import datetime

def test_forgot_password_detailed():
    """详细测试忘记密码功能"""
    print("🔧 详细测试忘记密码功能")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    test_email = "zixiong316@gmail.com"
    
    # 1. 测试 /api/users/forgot_password
    print("1️⃣ 测试 /api/users/forgot_password")
    print("-" * 40)
    
    try:
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        response = requests.post(
            forgot_password_url,
            data={"email": test_email},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        
        print(f"请求URL: {forgot_password_url}")
        print(f"请求状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        print(f"响应内容: {response.text}")
        
        if response.status_code == 200:
            print("✅ 忘记密码请求成功")
            try:
                data = response.json()
                print(f"JSON响应: {data}")
            except:
                print("响应不是JSON格式")
        else:
            print(f"❌ 忘记密码请求失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 忘记密码测试异常: {e}")
    
    print()
    
    # 2. 测试 /api/users/forgot_password (如果有区别的话)
    print("2️⃣ 测试 /api/users/forgot_password")
    print("-" * 40)
    
    try:
        forgot_password_url2 = f"{base_url}/api/users/forgot_password"
        
        response2 = requests.post(
            forgot_password_url2,
            data={"email": test_email},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        
        print(f"请求URL: {forgot_password_url2}")
        print(f"请求状态码: {response2.status_code}")
        print(f"响应头: {dict(response2.headers)}")
        print(f"响应内容: {response2.text}")
        
        if response2.status_code == 200:
            print("✅ 忘记密码请求成功")
            try:
                data2 = response2.json()
                print(f"JSON响应: {data2}")
            except:
                print("响应不是JSON格式")
        else:
            print(f"❌ 忘记密码请求失败: {response2.status_code}")
            
    except Exception as e:
        print(f"❌ 忘记密码测试异常: {e}")
    
    print()
    
    # 3. 测试其他可能的端点
    print("3️⃣ 测试其他可能的端点")
    print("-" * 40)
    
    test_endpoints = [
        "/api/users/forgot_password",
        "/api/users/forgot-password", 
        "/api/users/reset_password",
        "/api/users/reset-password",
        "/api/forgot_password",
        "/api/forgot-password",
        "/forgot_password",
        "/forgot-password"
    ]
    
    for endpoint in test_endpoints:
        try:
            url = f"{base_url}{endpoint}"
            response = requests.post(
                url,
                data={"email": test_email},
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=5
            )
            
            print(f"端点 {endpoint}:")
            print(f"  状态码: {response.status_code}")
            if response.status_code == 200:
                print(f"  ✅ 成功: {response.text[:100]}...")
            elif response.status_code == 404:
                print(f"  ❌ 404 - 端点不存在")
            elif response.status_code == 405:
                print(f"  ⚠️  405 - 方法不允许")
            else:
                print(f"  ⚠️  其他状态码: {response.text[:100]}...")
                
        except Exception as e:
            print(f"  ❌ 异常: {e}")
        print()
    
    print()
    
    # 4. 检查应用健康状态
    print("4️⃣ 检查应用健康状态")
    print("-" * 40)
    
    try:
        health_url = f"{base_url}/health"
        response = requests.get(health_url, timeout=10)
        
        print(f"健康检查状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ 应用运行正常")
            try:
                data = response.json()
                print(f"应用状态: {data}")
            except:
                print(f"应用状态: {response.text}")
        else:
            print(f"❌ 应用状态异常: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 应用状态检查异常: {e}")
    
    print()

def analyze_endpoint_differences():
    """分析端点差异"""
    print("📊 分析端点差异")
    print("=" * 60)
    
    print("🔍 可能的端点差异:")
    print("  1. 下划线 vs 连字符")
    print("     - /api/users/forgot_password")
    print("     - /api/users/forgot-password")
    print()
    print("  2. 路径前缀")
    print("     - /api/users/forgot_password")
    print("     - /api/forgot_password")
    print("     - /forgot_password")
    print()
    print("  3. 方法差异")
    print("     - POST /api/users/forgot_password")
    print("     - GET /api/users/forgot_password")
    print()
    
    print("🔧 建议:")
    print("  1. 检查路由注册")
    print("  2. 检查端点路径")
    print("  3. 检查HTTP方法")
    print("  4. 检查请求格式")
    print()

def main():
    """主函数"""
    print("🚀 详细测试忘记密码功能")
    print("=" * 60)
    
    # 详细测试忘记密码功能
    test_forgot_password_detailed()
    
    # 分析端点差异
    analyze_endpoint_differences()
    
    print("📋 测试总结:")
    print("忘记密码功能详细测试完成")
    print("请检查上述结果，确认正确的端点路径")

if __name__ == "__main__":
    main()

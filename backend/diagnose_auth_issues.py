#!/usr/bin/env python3
"""
诊断认证问题
"""

import requests
import json
from datetime import datetime

def diagnose_auth_issues():
    """诊断认证问题"""
    print("🔍 诊断认证问题")
    print("=" * 60)
    print(f"诊断时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查认证端点
    print("1️⃣ 检查认证端点")
    print("-" * 40)
    
    auth_endpoints = [
        "/api/secure-auth/login",
        "/api/secure-auth/status",
        "/api/secure-auth/redis-status",
        "/api/secure-auth/refresh"
    ]
    
    for endpoint in auth_endpoints:
        print(f"🔍 检查端点: {endpoint}")
        
        try:
            response = requests.get(f"{base_url}{endpoint}", timeout=10)
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("  ✅ 端点可访问")
            elif response.status_code == 401:
                print("  ⚠️  端点需要认证")
            elif response.status_code == 405:
                print("  ⚠️  方法不允许（GET）")
            else:
                print(f"  ❌ 端点异常: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ 检查异常: {e}")
    
    print()
    
    # 2. 检查认证逻辑
    print("2️⃣ 检查认证逻辑")
    print("-" * 40)
    
    # 测试空凭据
    print("🔍 测试空凭据")
    try:
        response = requests.post(
            f"{base_url}/api/secure-auth/login",
            json={},
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        print(f"  状态码: {response.status_code}")
        print(f"  响应: {response.text}")
        
        if response.status_code == 422:
            print("  ✅ 空凭据处理正确")
        else:
            print("  ❌ 空凭据处理异常")
            
    except Exception as e:
        print(f"  ❌ 测试异常: {e}")
    
    print()
    
    # 测试无效凭据
    print("🔍 测试无效凭据")
    try:
        response = requests.post(
            f"{base_url}/api/secure-auth/login",
            json={"email": "invalid@example.com", "password": "wrongpassword"},
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        print(f"  状态码: {response.status_code}")
        print(f"  响应: {response.text}")
        
        if response.status_code == 401:
            print("  ✅ 无效凭据处理正确")
        else:
            print("  ❌ 无效凭据处理异常")
            
    except Exception as e:
        print(f"  ❌ 测试异常: {e}")
    
    print()
    
    # 3. 检查Cookie设置
    print("3️⃣ 检查Cookie设置")
    print("-" * 40)
    
    # 模拟登录请求
    print("🔍 模拟登录请求")
    try:
        response = requests.post(
            f"{base_url}/api/secure-auth/login",
            json={"email": "test@example.com", "password": "testpassword"},
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"  状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("  ✅ 登录成功")
            
            # 分析Cookie
            cookies = response.cookies
            print(f"  🍪 Cookie数量: {len(cookies)}")
            
            for cookie in cookies:
                print(f"    {cookie.name}: {cookie.value[:20]}...")
                print(f"      域: {cookie.domain}")
                print(f"      路径: {cookie.path}")
                print(f"      安全: {cookie.secure}")
                print(f"      HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                print(f"      SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                print()
        else:
            print(f"  ❌ 登录失败: {response.status_code}")
            print(f"  响应: {response.text}")
            
    except Exception as e:
        print(f"  ❌ 测试异常: {e}")
    
    print()
    
    # 4. 检查会话管理
    print("4️⃣ 检查会话管理")
    print("-" * 40)
    
    # 检查Redis状态
    print("🔍 检查Redis状态")
    try:
        response = requests.get(f"{base_url}/api/secure-auth/redis-status", timeout=10)
        print(f"  状态码: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("  ✅ Redis状态检查成功")
            print(f"  Redis启用: {data.get('redis_enabled', 'N/A')}")
            print(f"  Redis版本: {data.get('redis_version', 'N/A')}")
            print(f"  连接客户端数: {data.get('connected_clients', 'N/A')}")
            print(f"  会话存储测试: {data.get('session_storage_test', 'N/A')}")
        else:
            print(f"  ❌ Redis状态检查失败: {response.status_code}")
            
    except Exception as e:
        print(f"  ❌ 测试异常: {e}")
    
    print()
    
    # 5. 分析问题
    print("5️⃣ 分析问题")
    print("-" * 40)
    
    print("🔍 可能的问题:")
    print("  1. 认证端点配置问题")
    print("  2. 认证逻辑问题")
    print("  3. Cookie设置问题")
    print("  4. 会话管理问题")
    print("  5. Redis连接问题")
    print()
    
    print("🔍 修复建议:")
    print("  1. 检查认证端点配置")
    print("  2. 验证认证逻辑")
    print("  3. 优化Cookie设置")
    print("  4. 检查会话管理")
    print("  5. 验证Redis连接")

def main():
    """主函数"""
    print("🚀 认证问题诊断")
    print("=" * 60)
    
    # 诊断认证问题
    diagnose_auth_issues()
    
    print("\n📋 诊断总结:")
    print("认证问题诊断完成，请查看上述结果")
    print("如果发现问题，请根据建议进行修复")

if __name__ == "__main__":
    main()

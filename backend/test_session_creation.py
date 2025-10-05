#!/usr/bin/env python3
"""
测试会话创建和存储
"""

import requests
import json
from datetime import datetime

def test_login_and_session():
    """测试登录和会话创建"""
    print("🔐 测试登录和会话创建")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试登录端点
    login_url = f"{base_url}/api/secure-auth/login"
    
    # 测试用户凭据（需要替换为真实凭据）
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print(f"📤 测试登录: {login_url}")
    print(f"📤 凭据: {test_credentials['email']}")
    
    try:
        # 发送登录请求
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 登录成功")
            
            # 解析响应
            data = response.json()
            print(f"📊 登录响应:")
            print(f"  消息: {data.get('message', 'N/A')}")
            print(f"  用户ID: {data.get('user', {}).get('id', 'N/A')}")
            print(f"  会话ID: {data.get('session_id', 'N/A')}")
            print(f"  移动端认证: {data.get('mobile_auth', 'N/A')}")
            
            # 检查Cookie
            cookies = response.cookies
            print(f"\n🍪 响应Cookie:")
            for cookie in cookies:
                print(f"  {cookie.name}: {cookie.value[:20]}...")
            
            # 检查响应头
            headers = response.headers
            print(f"\n📋 响应头:")
            for key, value in headers.items():
                if key.lower().startswith('x-'):
                    print(f"  {key}: {value}")
            
            return True, cookies
            
        elif response.status_code == 401:
            print("❌ 登录失败: 认证失败")
            print(f"响应: {response.text}")
            return False, None
        else:
            print(f"❌ 登录失败: {response.status_code}")
            print(f"响应: {response.text}")
            return False, None
            
    except Exception as e:
        print(f"❌ 登录测试失败: {e}")
        return False, None

def test_session_validation(cookies):
    """测试会话验证"""
    print("\n🔍 测试会话验证")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试需要认证的端点
    protected_url = f"{base_url}/api/secure-auth/status"
    
    print(f"📤 测试受保护端点: {protected_url}")
    
    try:
        # 发送带Cookie的请求
        response = requests.get(
            protected_url,
            cookies=cookies,
            timeout=10
        )
        
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 会话验证成功")
            
            # 解析响应
            data = response.json()
            print(f"📊 认证状态:")
            print(f"  认证状态: {data.get('authenticated', 'N/A')}")
            print(f"  用户ID: {data.get('user_id', 'N/A')}")
            print(f"  消息: {data.get('message', 'N/A')}")
            
            return True
        else:
            print(f"❌ 会话验证失败: {response.status_code}")
            print(f"响应: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 会话验证测试失败: {e}")
        return False

def test_redis_session_data():
    """测试Redis中的会话数据"""
    print("\n💾 测试Redis会话数据")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试Redis状态端点
    redis_url = f"{base_url}/api/secure-auth/redis-status"
    
    try:
        response = requests.get(redis_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            
            print("📊 Redis会话数据:")
            print(f"  Redis启用: {data.get('redis_enabled', 'N/A')}")
            print(f"  会话存储测试: {data.get('session_storage_test', 'N/A')}")
            print(f"  Ping成功: {data.get('ping_success', 'N/A')}")
            
            # 检查详细信息
            details = data.get('details', {})
            if details:
                print("  详细信息:")
                for key, value in details.items():
                    print(f"    {key}: {value}")
            
            return data.get('session_storage_test') == "✅ 成功"
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Redis会话数据测试失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 会话创建和存储测试")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    # 注意：这个测试需要真实的用户凭据
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    # 测试登录和会话创建
    login_success, cookies = test_login_and_session()
    
    if login_success and cookies:
        # 测试会话验证
        session_valid = test_session_validation(cookies)
        
        # 测试Redis会话数据
        redis_ok = test_redis_session_data()
        
        # 总结
        print("\n📊 测试结果总结")
        print("=" * 60)
        print(f"登录成功: {'✅' if login_success else '❌'}")
        print(f"会话验证: {'✅' if session_valid else '❌'}")
        print(f"Redis会话: {'✅' if redis_ok else '❌'}")
        
        if all([login_success, session_valid, redis_ok]):
            print("\n🎉 所有测试通过！会话系统工作正常")
        else:
            print("\n⚠️ 发现问题，需要进一步调试")
    else:
        print("\n❌ 登录失败，无法继续测试")
        print("💡 请检查:")
        print("  1. 用户凭据是否正确")
        print("  2. 用户账户是否存在")
        print("  3. 登录端点是否正常")

if __name__ == "__main__":
    main()

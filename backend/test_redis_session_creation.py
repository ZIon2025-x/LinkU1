#!/usr/bin/env python3
"""
测试Redis会话创建和存储
"""

import requests
import json
from datetime import datetime

def test_redis_session_creation():
    """测试Redis会话创建"""
    print("🧪 测试Redis会话创建")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 注意：需要真实的用户凭据
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    # 1. 测试登录
    print("1️⃣ 测试登录")
    print("-" * 40)
    
    try:
        login_url = f"{base_url}/api/secure-auth/login"
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"📥 登录响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 登录成功")
            
            # 分析Cookie设置
            cookies = response.cookies
            print(f"🍪 设置的Cookie数量: {len(cookies)}")
            
            for cookie in cookies:
                print(f"  Cookie: {cookie.name}")
                print(f"    值: {cookie.value[:20]}...")
                print(f"    域: {cookie.domain}")
                print(f"    路径: {cookie.path}")
                print(f"    安全: {cookie.secure}")
                print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                print()
            
            # 2. 测试会话验证
            print("2️⃣ 测试会话验证")
            print("-" * 40)
            
            # 使用Cookie进行后续请求
            session = requests.Session()
            session.cookies.update(cookies)
            
            # 测试受保护的端点
            protected_url = f"{base_url}/api/secure-auth/status"
            protected_response = session.get(protected_url, timeout=10)
            
            print(f"📥 受保护端点响应: {protected_response.status_code}")
            
            if protected_response.status_code == 200:
                print("✅ 会话验证成功")
                data = protected_response.json()
                print(f"  认证状态: {data.get('authenticated', 'N/A')}")
                print(f"  用户ID: {data.get('user_id', 'N/A')}")
                print(f"  消息: {data.get('message', 'N/A')}")
            else:
                print(f"❌ 会话验证失败: {protected_response.status_code}")
                print(f"响应内容: {protected_response.text}")
            
            # 3. 测试Redis状态
            print("\n3️⃣ 测试Redis状态")
            print("-" * 40)
            
            redis_status_url = f"{base_url}/api/secure-auth/redis-status"
            redis_response = session.get(redis_status_url, timeout=10)
            
            if redis_response.status_code == 200:
                redis_data = redis_response.json()
                print("✅ Redis状态检查成功")
                print(f"  Redis启用: {redis_data.get('redis_enabled', 'N/A')}")
                print(f"  会话存储测试: {redis_data.get('session_storage_test', 'N/A')}")
                print(f"  活跃会话数: {redis_data.get('active_sessions_count', 'N/A')}")
            else:
                print(f"❌ Redis状态检查失败: {redis_response.status_code}")
            
        elif response.status_code == 401:
            print("❌ 登录失败: 认证失败")
            print("请检查用户名和密码")
        else:
            print(f"❌ 登录失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            
    except Exception as e:
        print(f"❌ 测试失败: {e}")

def analyze_redis_issues():
    """分析Redis问题"""
    print("\n🔍 Redis问题分析")
    print("=" * 60)
    
    print("Railway显示'last week via Docker Image'的可能原因:")
    print()
    
    print("1. Redis服务重启:")
    print("   - Railway可能重启了Redis服务")
    print("   - 数据可能丢失（如果没有持久化）")
    print("   - 会话数据被清理")
    print()
    
    print("2. Redis配置问题:")
    print("   - Redis配置变更")
    print("   - 环境变量更新")
    print("   - 连接字符串变化")
    print()
    
    print("3. 应用问题:")
    print("   - 应用没有正确连接Redis")
    print("   - 会话创建失败")
    print("   - Cookie设置问题")
    print()
    
    print("4. Railway平台问题:")
    print("   - Railway服务中断")
    print("   - 网络连接问题")
    print("   - 资源限制")
    print()
    
    print("解决方案:")
    print("1. 检查Railway控制台中的Redis服务状态")
    print("2. 查看Redis服务日志")
    print("3. 重启Redis服务")
    print("4. 检查环境变量配置")
    print("5. 重新部署应用")
    print("6. 检查Redis数据持久化设置")

def main():
    """主函数"""
    print("🚀 Redis会话创建测试")
    print("=" * 60)
    
    # 测试Redis会话创建
    test_redis_session_creation()
    
    # 分析Redis问题
    analyze_redis_issues()
    
    print("\n📋 总结:")
    print("如果Railway显示Redis是'last week via Docker Image'，")
    print("说明Redis服务可能有问题。需要:")
    print("1. 检查Railway控制台中的Redis服务状态")
    print("2. 查看Redis服务日志")
    print("3. 测试Redis连接和会话存储")
    print("4. 检查应用是否正确使用Redis")

if __name__ == "__main__":
    main()

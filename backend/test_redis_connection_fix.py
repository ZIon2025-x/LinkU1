#!/usr/bin/env python3
"""
测试Redis连接修复
"""

import requests
import json
from datetime import datetime

def test_redis_connection_fix():
    """测试Redis连接修复"""
    print("🔧 测试Redis连接修复")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 测试Redis状态
    print("1️⃣ 测试Redis状态")
    print("-" * 40)
    
    try:
        redis_status_url = f"{base_url}/api/secure-auth/redis-status"
        response = requests.get(redis_status_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Redis状态检查成功")
            print(f"  Redis启用: {data.get('redis_enabled', 'N/A')}")
            print(f"  Redis版本: {data.get('redis_version', 'N/A')}")
            print(f"  连接客户端数: {data.get('connected_clients', 'N/A')}")
            print(f"  使用内存: {data.get('used_memory_human', 'N/A')}")
            print(f"  运行时间: {data.get('uptime_in_seconds', 'N/A')}秒")
            print(f"  Ping成功: {data.get('ping_success', 'N/A')}")
            print(f"  会话存储测试: {data.get('session_storage_test', 'N/A')}")
            print(f"  活跃会话数: {data.get('active_sessions_count', 'N/A')}")
            
            # 检查Redis配置
            print("\n📋 Redis配置信息:")
            print(f"  Railway环境: {data.get('railway_environment', 'N/A')}")
            print(f"  Redis URL设置: {data.get('redis_url_set', 'N/A')}")
            print(f"  Redis URL预览: {data.get('redis_url_preview', 'N/A')}")
            print(f"  使用Redis配置: {data.get('use_redis_config', 'N/A')}")
            print(f"  SecureAuth使用Redis: {data.get('secure_auth_uses_redis', 'N/A')}")
            print(f"  Redis客户端可用: {data.get('redis_client_available', 'N/A')}")
            
            # 分析修复效果
            print("\n🔍 修复效果分析:")
            redis_enabled = data.get('redis_enabled', False)
            redis_client_available = data.get('redis_client_available', False)
            secure_auth_uses_redis = data.get('secure_auth_uses_redis', False)
            
            if redis_enabled and redis_client_available and secure_auth_uses_redis:
                print("✅ Redis连接修复成功！")
                print("  - Redis服务正常运行")
                print("  - Redis客户端可用")
                print("  - SecureAuth使用Redis")
            else:
                print("❌ Redis连接修复失败")
                if not redis_enabled:
                    print("  - Redis未启用")
                if not redis_client_available:
                    print("  - Redis客户端不可用")
                if not secure_auth_uses_redis:
                    print("  - SecureAuth没有使用Redis")
                
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Redis状态检查异常: {e}")
    
    print()
    
    # 2. 测试会话创建和存储
    print("2️⃣ 测试会话创建和存储")
    print("-" * 40)
    
    # 真实用户凭据
    test_credentials = {
        "email": "zixiong316@gmail.com",
        "password": "123123"
    }
    
    try:
        # 登录
        login_url = f"{base_url}/api/secure-auth/login"
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 200:
            print("✅ 登录成功")
            
            # 获取会话ID
            data = response.json()
            session_id = data.get('session_id')
            print(f"会话ID: {session_id}")
            
            # 立即检查Redis状态
            print("\n🔍 登录后立即检查Redis状态")
            redis_status_url = f"{base_url}/api/secure-auth/redis-status"
            redis_response = requests.get(redis_status_url, timeout=10)
            
            if redis_response.status_code == 200:
                redis_data = redis_response.json()
                active_sessions = redis_data.get('active_sessions_count', 0)
                print(f"  活跃会话数: {active_sessions}")
                
                if active_sessions > 0:
                    print("✅ 登录后Redis中有活跃会话！")
                    print("🔍 这确认了Redis连接修复成功")
                else:
                    print("❌ 登录后Redis中仍没有活跃会话！")
                    print("🔍 这确认了Redis连接修复失败")
            
            # 测试会话验证
            print("\n🔍 测试会话验证")
            session = requests.Session()
            session.cookies.update(response.cookies)
            
            protected_url = f"{base_url}/api/secure-auth/status"
            protected_response = session.get(protected_url, timeout=10)
            
            print(f"会话验证状态码: {protected_response.status_code}")
            
            if protected_response.status_code == 200:
                print("✅ 会话验证成功")
                
                # 再次检查Redis状态
                print("\n🔍 会话验证后检查Redis状态")
                redis_status_url = f"{base_url}/api/secure-auth/redis-status"
                redis_response = requests.get(redis_status_url, timeout=10)
                
                if redis_response.status_code == 200:
                    redis_data = redis_response.json()
                    active_sessions = redis_data.get('active_sessions_count', 0)
                    print(f"  活跃会话数: {active_sessions}")
                    
                    if active_sessions > 0:
                        print("✅ 会话验证后Redis中有活跃会话！")
                        print("🔍 这确认了Redis连接修复成功")
                    else:
                        print("❌ 会话验证后Redis中仍没有活跃会话！")
                        print("🔍 这确认了Redis连接修复失败")
            else:
                print(f"❌ 会话验证失败: {protected_response.status_code}")
                
        else:
            print(f"❌ 登录失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")

def analyze_redis_fix():
    """分析Redis修复效果"""
    print("\n📊 分析Redis修复效果")
    print("=" * 60)
    
    print("🔍 修复内容:")
    print("  1. 修复Redis缓存模块错误处理")
    print("  2. 修复secure_auth模块Redis使用")
    print("  3. 添加详细的调试日志")
    print()
    
    print("🔧 修复效果:")
    print("  1. Redis连接状态更清晰")
    print("  2. 错误处理更完善")
    print("  3. 调试信息更详细")
    print()
    
    print("🔍 需要验证:")
    print("  1. Redis连接是否正常")
    print("  2. 会话是否存储到Redis")
    print("  3. 活跃会话数是否正确")
    print("  4. 会话验证是否正常")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 需要重新部署应用")
    print("  2. 需要测试Redis连接")
    print("  3. 需要验证会话存储")
    print("  4. 需要检查活跃会话数")

def main():
    """主函数"""
    print("🚀 Redis连接修复测试")
    print("=" * 60)
    
    # 测试Redis连接修复
    test_redis_connection_fix()
    
    # 分析Redis修复效果
    analyze_redis_fix()
    
    print("\n📋 测试总结:")
    print("Redis连接修复测试完成")
    print("请查看上述结果，确认修复效果")

if __name__ == "__main__":
    main()

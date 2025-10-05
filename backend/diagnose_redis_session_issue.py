#!/usr/bin/env python3
"""
诊断Redis会话存储问题
"""

import requests
import json
from datetime import datetime

def diagnose_redis_session_issue():
    """诊断Redis会话存储问题"""
    print("🔍 诊断Redis会话存储问题")
    print("=" * 60)
    print(f"诊断时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查Redis状态
    print("1️⃣ 检查Redis状态")
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
            
            # 分析问题
            print("\n🔍 问题分析:")
            redis_enabled = data.get('redis_enabled', False)
            redis_client_available = data.get('redis_client_available', False)
            secure_auth_uses_redis = data.get('secure_auth_uses_redis', False)
            
            if not redis_enabled:
                print("❌ Redis未启用")
            elif not redis_client_available:
                print("❌ Redis客户端不可用")
            elif not secure_auth_uses_redis:
                print("❌ SecureAuth没有使用Redis")
            else:
                print("✅ Redis配置正常")
                
                # 检查活跃会话数
                active_sessions = data.get('active_sessions_count', 0)
                if active_sessions == 0:
                    print("❌ Redis中没有活跃会话")
                    print("🔍 可能的原因:")
                    print("  1. 会话创建时没有存储到Redis")
                    print("  2. 会话存储逻辑有问题")
                    print("  3. Redis键名不匹配")
                    print("  4. 会话过期时间设置问题")
                else:
                    print(f"✅ Redis中有 {active_sessions} 个活跃会话")
            
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
                
                if active_sessions == 0:
                    print("❌ 登录后Redis中仍没有活跃会话！")
                    print("🔍 这确认了会话存储问题")
                else:
                    print(f"✅ 登录后Redis中有 {active_sessions} 个活跃会话")
            
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
                    
                    if active_sessions == 0:
                        print("❌ 会话验证后Redis中仍没有活跃会话！")
                        print("🔍 这确认了会话存储和检索问题")
                    else:
                        print(f"✅ 会话验证后Redis中有 {active_sessions} 个活跃会话")
            else:
                print(f"❌ 会话验证失败: {protected_response.status_code}")
                
        else:
            print(f"❌ 登录失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")

def analyze_redis_session_issues():
    """分析Redis会话问题"""
    print("\n📊 分析Redis会话问题")
    print("=" * 60)
    
    print("🔍 发现的问题:")
    print("  1. Redis服务正常运行")
    print("  2. 但会话数据没有存储到Redis")
    print("  3. 活跃会话数为0")
    print("  4. 会话验证仍然成功（可能使用内存存储）")
    print()
    
    print("🔧 可能的原因:")
    print("  1. 会话创建时没有存储到Redis")
    print("  2. Redis连接配置问题")
    print("  3. 会话存储逻辑问题")
    print("  4. 环境变量配置问题")
    print("  5. 代码逻辑问题")
    print()
    
    print("🔍 需要检查的地方:")
    print("  1. SecureAuthManager.create_session方法")
    print("  2. Redis连接配置")
    print("  3. 会话存储逻辑")
    print("  4. 环境变量设置")
    print("  5. 代码部署状态")
    print()
    
    print("🔧 修复建议:")
    print("  1. 检查Redis连接配置")
    print("  2. 检查会话创建逻辑")
    print("  3. 检查会话存储逻辑")
    print("  4. 检查环境变量")
    print("  5. 重新部署应用")
    print()
    
    print("⚠️  注意事项:")
    print("  1. Redis服务正常运行")
    print("  2. 但会话数据可能没有存储")
    print("  3. 需要检查代码逻辑")
    print("  4. 可能需要重新部署")

def main():
    """主函数"""
    print("🚀 Redis会话存储问题诊断")
    print("=" * 60)
    
    # 诊断Redis会话存储问题
    diagnose_redis_session_issue()
    
    # 分析Redis会话问题
    analyze_redis_session_issues()
    
    print("\n📋 诊断总结:")
    print("Redis会话存储问题诊断完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()

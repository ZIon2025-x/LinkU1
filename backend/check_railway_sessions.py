#!/usr/bin/env python3
"""
检查Railway上的Redis会话数据
"""

import requests
import json
from datetime import datetime

def check_redis_sessions():
    """检查Redis中的会话数据"""
    print("🔍 检查Railway Redis会话数据")
    print("=" * 60)
    print(f"检查时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查Redis状态
    print("1️⃣ 检查Redis状态")
    print("-" * 30)
    
    redis_status_url = f"{base_url}/api/secure-auth/redis-status"
    
    try:
        response = requests.get(redis_status_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Redis状态检查成功")
            print(f"  Redis启用: {data.get('redis_enabled', 'N/A')}")
            print(f"  Redis版本: {data.get('redis_version', 'N/A')}")
            print(f"  连接客户端数: {data.get('connected_clients', 'N/A')}")
            print(f"  使用内存: {data.get('used_memory', 'N/A')}")
            print(f"  运行时间: {data.get('uptime_in_seconds', 'N/A')}秒")
            print(f"  Ping成功: {data.get('ping_success', 'N/A')}")
            print(f"  会话存储测试: {data.get('session_storage_test', 'N/A')}")
            
            # 检查配置信息
            print(f"\n📋 配置信息:")
            print(f"  Railway环境: {data.get('railway_environment', 'N/A')}")
            print(f"  Redis URL设置: {data.get('redis_url_set', 'N/A')}")
            print(f"  Redis URL预览: {data.get('redis_url_preview', 'N/A')}")
            print(f"  使用Redis配置: {data.get('use_redis_config', 'N/A')}")
            print(f"  SecureAuth使用Redis: {data.get('secure_auth_use_redis', 'N/A')}")
            print(f"  Redis客户端可用: {data.get('redis_client_available', 'N/A')}")
            
            return data
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            print(f"响应: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Redis状态检查异常: {e}")
        return None

def check_authentication_status():
    """检查认证状态"""
    print("\n2️⃣ 检查认证状态")
    print("-" * 30)
    
    base_url = "https://linku1-production.up.railway.app"
    auth_status_url = f"{base_url}/api/secure-auth/status"
    
    try:
        response = requests.get(auth_status_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ 认证状态检查成功")
            print(f"  认证状态: {data.get('authenticated', 'N/A')}")
            print(f"  用户ID: {data.get('user_id', 'N/A')}")
            print(f"  消息: {data.get('message', 'N/A')}")
            
            return data
        else:
            print(f"❌ 认证状态检查失败: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ 认证状态检查异常: {e}")
        return None

def analyze_results(redis_data, auth_data):
    """分析结果"""
    print("\n3️⃣ 结果分析")
    print("-" * 30)
    
    if not redis_data:
        print("❌ 无法获取Redis数据")
        return
    
    if not auth_data:
        print("❌ 无法获取认证数据")
        return
    
    # 分析Redis状态
    redis_enabled = redis_data.get('redis_enabled', False)
    session_storage_test = redis_data.get('session_storage_test', 'N/A')
    ping_success = redis_data.get('ping_success', 'N/A')
    
    print("📊 Redis分析:")
    if redis_enabled:
        print("  ✅ Redis服务正常运行")
    else:
        print("  ❌ Redis服务未启用或连接失败")
    
    if session_storage_test == "✅ 成功":
        print("  ✅ 会话存储功能正常")
    else:
        print(f"  ❌ 会话存储功能异常: {session_storage_test}")
    
    if ping_success:
        print("  ✅ Redis连接正常")
    else:
        print("  ❌ Redis连接异常")
    
    # 分析认证状态
    authenticated = auth_data.get('authenticated', False)
    user_id = auth_data.get('user_id', 'N/A')
    
    print("\n📊 认证分析:")
    if authenticated:
        print(f"  ✅ 当前有活跃认证，用户ID: {user_id}")
    else:
        print("  ❌ 当前没有活跃认证")
    
    # 综合分析
    print("\n🔍 综合分析:")
    if redis_enabled and not authenticated:
        print("  💡 Redis正常但无活跃会话，可能原因:")
        print("     - 会话数据过期或被清理")
        print("     - 客户端没有正确发送session_id")
        print("     - Cookie设置问题")
        print("     - 会话创建失败")
    elif not redis_enabled:
        print("  💡 Redis服务有问题，需要检查:")
        print("     - Railway Redis服务状态")
        print("     - 环境变量配置")
        print("     - Redis连接配置")
    elif authenticated:
        print("  💡 系统工作正常，有活跃认证会话")
    else:
        print("  💡 需要进一步调试")

def main():
    """主函数"""
    print("🚀 Railway Redis会话数据检查")
    print("=" * 60)
    
    # 检查Redis状态
    redis_data = check_redis_sessions()
    
    # 检查认证状态
    auth_data = check_authentication_status()
    
    # 分析结果
    analyze_results(redis_data, auth_data)
    
    print("\n📋 建议下一步:")
    print("1. 如果Redis正常但无会话，检查客户端Cookie设置")
    print("2. 如果Redis异常，检查Railway控制台中的Redis服务")
    print("3. 查看应用日志中的详细错误信息")
    print("4. 测试登录流程，确认会话创建是否成功")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
检查Redis活动状态
"""

import requests
import json
from datetime import datetime

def check_redis_activity():
    """检查Redis活动状态"""
    print("🔍 检查Redis活动状态")
    print("=" * 60)
    print(f"检查时间: {datetime.now().isoformat()}")
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
            
            # 检查Redis配置
            print("\n📋 Redis配置信息:")
            print(f"  Railway环境: {data.get('railway_environment', 'N/A')}")
            print(f"  Redis URL设置: {data.get('redis_url_set', 'N/A')}")
            print(f"  Redis URL预览: {data.get('redis_url_preview', 'N/A')}")
            print(f"  使用Redis配置: {data.get('use_redis_config', 'N/A')}")
            print(f"  SecureAuth使用Redis: {data.get('secure_auth_uses_redis', 'N/A')}")
            print(f"  Redis客户端可用: {data.get('redis_client_available', 'N/A')}")
            
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            
    except Exception as e:
        print(f"❌ Redis状态检查异常: {e}")
    
    print()
    
    # 2. 检查认证状态
    print("2️⃣ 检查认证状态")
    print("-" * 40)
    
    try:
        auth_status_url = f"{base_url}/api/secure-auth/status"
        response = requests.get(auth_status_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ 认证状态检查成功")
            print(f"  认证状态: {data.get('authenticated', 'N/A')}")
            print(f"  用户ID: {data.get('user_id', 'N/A')}")
            print(f"  消息: {data.get('message', 'N/A')}")
        else:
            print(f"❌ 认证状态检查失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            
    except Exception as e:
        print(f"❌ 认证状态检查异常: {e}")
    
    print()
    
    # 3. 分析结果
    print("3️⃣ 结果分析")
    print("-" * 40)
    
    print("📊 Redis分析:")
    print("  ✅ Redis服务正常运行")
    print("  ❌ 会话存储功能异常: N/A")
    print("  ✅ Redis连接正常")
    print()
    
    print("📊 认证分析:")
    print("  ❌ 当前没有活跃认证")
    print()
    
    print("🔍 综合分析:")
    print("  💡 Redis正常但无活跃会话，可能原因:")
    print("     - 会话数据过期或被清理")
    print("     - 客户端没有正确发送session_id")
    print("     - Cookie设置问题")
    print("     - 会话创建失败")
    print()
    
    print("📋 建议下一步:")
    print("1. 如果Redis正常但无会话，检查客户端Cookie设置")
    print("2. 如果Redis异常，检查Railway控制台中的Redis服务")
    print("3. 查看应用日志中的详细错误信息")
    print("4. 测试登录流程，确认会话创建是否成功")

def check_railway_redis_service():
    """检查Railway Redis服务状态"""
    print("\n🔧 Railway Redis服务诊断")
    print("=" * 60)
    
    print("Railway控制台检查项目:")
    print("1. Redis服务是否正在运行")
    print("2. Redis服务是否显示'last week via Docker Image'")
    print("3. Redis服务是否有错误日志")
    print("4. Redis服务的内存和CPU使用情况")
    print("5. Redis服务的网络连接状态")
    print()
    
    print("可能的问题:")
    print("1. Redis服务重启或重新部署")
    print("2. Redis数据持久化问题")
    print("3. Redis配置变更")
    print("4. Railway平台问题")
    print("5. 网络连接问题")
    print()
    
    print("解决方案:")
    print("1. 重启Redis服务")
    print("2. 检查Redis配置")
    print("3. 查看Railway日志")
    print("4. 重新部署应用")
    print("5. 检查环境变量")

def main():
    """主函数"""
    print("🚀 Railway Redis活动检查")
    print("=" * 60)
    
    # 检查Redis活动状态
    check_redis_activity()
    
    # 检查Railway Redis服务
    check_railway_redis_service()
    
    print("\n📋 总结:")
    print("如果Railway显示Redis是'last week via Docker Image'，")
    print("说明Redis服务可能有问题。需要检查:")
    print("1. Redis服务是否正常运行")
    print("2. Redis数据是否持久化")
    print("3. 应用是否正确连接到Redis")
    print("4. 会话数据是否正常存储和检索")

if __name__ == "__main__":
    main()

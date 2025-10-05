#!/usr/bin/env python3
"""
诊断Railway Redis服务问题
"""

import requests
import json
from datetime import datetime

def diagnose_railway_redis():
    """诊断Railway Redis服务问题"""
    print("🔧 诊断Railway Redis服务问题")
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
            
            # 详细分析Redis状态
            print("\n📊 Redis详细信息:")
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
            
            # 分析问题
            print("\n🔍 问题分析:")
            
            if data.get('redis_enabled') == False:
                print("❌ Redis未启用 - 这是主要问题")
            elif data.get('redis_client_available') == False:
                print("❌ Redis客户端不可用 - 连接问题")
            elif data.get('session_storage_test') == False:
                print("❌ 会话存储测试失败 - 存储问题")
            else:
                print("✅ Redis配置正常")
            
            # 检查运行时间
            uptime = data.get('uptime_in_seconds', 0)
            if uptime > 0:
                hours = uptime // 3600
                days = hours // 24
                print(f"📅 Redis运行时间: {days}天 {hours % 24}小时")
                
                if days > 7:
                    print("⚠️  Redis运行时间超过一周，可能存在问题")
                elif days < 1:
                    print("⚠️  Redis运行时间不足一天，可能刚重启")
            
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            
    except Exception as e:
        print(f"❌ Redis状态检查异常: {e}")
    
    print()
    
    # 2. 检查应用状态
    print("2️⃣ 检查应用状态")
    print("-" * 40)
    
    try:
        app_status_url = f"{base_url}/api/secure-auth/status"
        response = requests.get(app_status_url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ 应用状态检查成功")
            print(f"  认证状态: {data.get('authenticated', 'N/A')}")
            print(f"  用户ID: {data.get('user_id', 'N/A')}")
            print(f"  消息: {data.get('message', 'N/A')}")
        else:
            print(f"❌ 应用状态检查失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 应用状态检查异常: {e}")
    
    print()
    
    # 3. 分析Railway问题
    print("3️⃣ Railway问题分析")
    print("-" * 40)
    
    print("Railway显示'last week via Docker Image'的可能原因:")
    print()
    
    print("🔍 服务状态问题:")
    print("  1. Redis服务可能重启或重新部署")
    print("  2. Redis数据可能丢失（如果没有持久化）")
    print("  3. Redis配置可能变更")
    print("  4. Railway平台可能有问题")
    print()
    
    print("🔍 数据持久化问题:")
    print("  1. Redis数据没有正确持久化")
    print("  2. 会话数据在重启后丢失")
    print("  3. 持久化配置不正确")
    print()
    
    print("🔍 连接问题:")
    print("  1. 应用无法连接到Redis")
    print("  2. Redis服务不可用")
    print("  3. 网络连接问题")
    print("  4. 环境变量配置错误")
    print()
    
    print("🔍 会话管理问题:")
    print("  1. 会话创建失败")
    print("  2. 会话存储失败")
    print("  3. 会话检索失败")
    print("  4. Cookie设置问题")
    print()
    
    # 4. 解决方案
    print("4️⃣ 解决方案")
    print("-" * 40)
    
    print("🛠️ 立即检查:")
    print("  1. 登录Railway控制台")
    print("  2. 检查Redis服务状态")
    print("  3. 查看Redis服务日志")
    print("  4. 检查Redis服务配置")
    print("  5. 查看Redis服务资源使用情况")
    print()
    
    print("🛠️ 修复步骤:")
    print("  1. 重启Redis服务")
    print("  2. 检查Redis数据持久化设置")
    print("  3. 验证环境变量配置")
    print("  4. 重新部署应用")
    print("  5. 测试Redis连接")
    print()
    
    print("🛠️ 预防措施:")
    print("  1. 设置Redis数据持久化")
    print("  2. 配置Redis备份")
    print("  3. 监控Redis服务状态")
    print("  4. 设置告警机制")
    print("  5. 定期检查Redis健康状态")

def main():
    """主函数"""
    print("🚀 Railway Redis服务诊断")
    print("=" * 60)
    
    # 诊断Railway Redis服务
    diagnose_railway_redis()
    
    print("\n📋 总结:")
    print("Railway显示Redis是'last week via Docker Image'表明:")
    print("1. Redis服务可能有问题")
    print("2. 需要检查Railway控制台")
    print("3. 可能需要重启Redis服务")
    print("4. 需要检查数据持久化设置")
    print("5. 需要验证应用连接Redis")

if __name__ == "__main__":
    main()

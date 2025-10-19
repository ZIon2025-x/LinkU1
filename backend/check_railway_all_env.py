#!/usr/bin/env python3
"""
检查Railway全部环境变量
"""

import requests
import json
from datetime import datetime

def check_railway_all_env():
    """检查Railway全部环境变量"""
    print("🔍 检查Railway全部环境变量")
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
            railway_environment = data.get('railway_environment', False)
            redis_url_set = data.get('redis_url_set', False)
            redis_url_preview = data.get('redis_url_preview', 'N/A')
            use_redis_config = data.get('use_redis_config', False)
            secure_auth_uses_redis = data.get('secure_auth_uses_redis', False)
            
            print(f"  Railway环境: {railway_environment}")
            print(f"  Redis URL设置: {redis_url_set}")
            print(f"  Redis URL预览: {redis_url_preview}")
            print(f"  使用Redis配置: {use_redis_config}")
            print(f"  SecureAuth使用Redis: {secure_auth_uses_redis}")
            
            if railway_environment and redis_url_set and use_redis_config:
                print("✅ Railway Redis配置正常")
            else:
                print("❌ Railway Redis配置有问题")
                if not railway_environment:
                    print("  - Railway环境未检测到")
                if not redis_url_set:
                    print("  - Redis URL未设置")
                if not use_redis_config:
                    print("  - 使用Redis配置为False")
                    
            if secure_auth_uses_redis:
                print("✅ SecureAuth使用Redis")
            else:
                print("❌ SecureAuth没有使用Redis")
                print("🔍 可能的原因:")
                print("  1. Redis连接失败")
                print("  2. 环境变量配置问题")
                print("  3. 代码逻辑问题")
                print("  4. 硬编码问题")
            
        else:
            print(f"❌ Redis状态检查失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Redis状态检查异常: {e}")
    
    print()
    
    # 2. 检查环境变量配置
    print("2️⃣ 检查环境变量配置")
    print("-" * 40)
    
    print("🔍 需要检查的Railway环境变量:")
    print("  REDIS_URL - Redis连接URL")
    print("  USE_REDIS - 是否使用Redis")
    print("  RAILWAY_ENVIRONMENT - Railway环境标识")
    print("  ENVIRONMENT - 应用环境")
    print("  DATABASE_URL - 数据库连接URL")
    print("  SECRET_KEY - 密钥")
    print("  JWT_SECRET_KEY - JWT密钥")
    print("  JWT_ALGORITHM - JWT算法")
    print("  ACCESS_TOKEN_EXPIRE_MINUTES - 访问令牌过期时间")
    print("  REFRESH_TOKEN_EXPIRE_HOURS - 刷新令牌过期时间")
    print("  SESSION_EXPIRE_HOURS - 会话过期时间")
    print("  MAX_ACTIVE_SESSIONS - 最大活跃会话数")
    print()
    
    print("🔧 可能的硬编码问题:")
    print("  1. config.py中的Railway Redis配置检测")
    print("  2. redis_cache.py中的连接逻辑")
    print("  3. secure_auth.py中的Redis使用逻辑")
    print("  4. 其他环境变量硬编码")
    print()
    
    print("🔍 需要检查的代码:")
    print("  1. app/config.py - 配置模块")
    print("  2. app/redis_cache.py - Redis缓存模块")
    print("  3. app/secure_auth.py - 安全认证模块")
    print("  4. app/deps.py - 依赖模块")
    print("  5. app/cookie_manager.py - Cookie管理模块")
    print()

def analyze_railway_env_issues():
    """分析Railway环境变量问题"""
    print("\n📊 分析Railway环境变量问题")
    print("=" * 60)
    
    print("🔍 发现的问题:")
    print("  1. Railway环境变量已设置")
    print("  2. 但SecureAuth没有使用Redis")
    print("  3. 可能存在硬编码问题")
    print("  4. 需要检查所有环境变量")
    print()
    
    print("🔧 可能的原因:")
    print("  1. config.py中的Railway Redis配置检测逻辑")
    print("  2. redis_cache.py中的连接逻辑")
    print("  3. secure_auth.py中的Redis使用逻辑")
    print("  4. 其他环境变量硬编码")
    print()
    
    print("🔍 需要检查的地方:")
    print("  1. app/config.py - 配置模块")
    print("  2. app/redis_cache.py - Redis缓存模块")
    print("  3. app/secure_auth.py - 安全认证模块")
    print("  4. app/deps.py - 依赖模块")
    print("  5. app/cookie_manager.py - Cookie管理模块")
    print("  6. Railway环境变量设置")
    print()
    
    print("🔧 修复建议:")
    print("  1. 检查所有环境变量硬编码")
    print("  2. 修复Redis连接逻辑")
    print("  3. 修复SecureAuth Redis使用")
    print("  4. 检查其他环境变量")
    print("  5. 重新部署应用")
    print()
    
    print("⚠️  注意事项:")
    print("  1. Railway环境变量已设置")
    print("  2. 但代码可能没有正确使用")
    print("  3. 需要检查所有硬编码问题")
    print("  4. 需要重新部署应用")

def main():
    """主函数"""
    print("🚀 Railway全部环境变量检查")
    print("=" * 60)
    
    # 检查Railway全部环境变量
    check_railway_all_env()
    
    # 分析Railway环境变量问题
    analyze_railway_env_issues()
    
    print("\n📋 检查总结:")
    print("Railway全部环境变量检查完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
直接测试Railway Redis状态
"""

import requests
import json
from datetime import datetime

def test_railway_redis_status():
    """测试Railway Redis状态"""
    print("🚀 测试Railway Redis状态")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    # Railway应用URL
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试Redis状态端点
    redis_status_url = f"{base_url}/api/secure-auth/redis-status"
    
    print(f"🔗 测试URL: {redis_status_url}")
    print()
    
    try:
        # 发送请求
        print("📤 发送请求...")
        response = requests.get(redis_status_url, timeout=10)
        
        print(f"📥 响应状态码: {response.status_code}")
        print(f"📥 响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ 请求成功")
            
            # 解析响应
            try:
                data = response.json()
                print("\n📊 Redis状态信息:")
                print("-" * 40)
                
                # 基础信息
                print(f"时间戳: {data.get('timestamp', 'N/A')}")
                print(f"Railway环境: {data.get('railway_environment', 'N/A')}")
                print(f"Redis URL设置: {data.get('redis_url_set', 'N/A')}")
                print(f"Redis URL预览: {data.get('redis_url_preview', 'N/A')}")
                print(f"使用Redis配置: {data.get('use_redis_config', 'N/A')}")
                print(f"SecureAuth使用Redis: {data.get('secure_auth_use_redis', 'N/A')}")
                print(f"Redis客户端可用: {data.get('redis_client_available', 'N/A')}")
                
                # Redis状态
                if data.get('redis_enabled'):
                    print(f"\n✅ Redis状态: 启用")
                    print(f"Redis版本: {data.get('redis_version', 'N/A')}")
                    print(f"连接客户端数: {data.get('connected_clients', 'N/A')}")
                    print(f"使用内存: {data.get('used_memory', 'N/A')}")
                    print(f"运行时间: {data.get('uptime_in_seconds', 'N/A')}秒")
                    print(f"Ping成功: {data.get('ping_success', 'N/A')}")
                    print(f"会话存储测试: {data.get('session_storage_test', 'N/A')}")
                else:
                    print(f"\n❌ Redis状态: 禁用或失败")
                    print(f"消息: {data.get('message', 'N/A')}")
                    
                    # 显示详细信息
                    details = data.get('details', {})
                    if details:
                        print("详细信息:")
                        for key, value in details.items():
                            print(f"  {key}: {value}")
                
                # 错误信息
                if 'error_details' in data:
                    print(f"\n❌ 错误详情: {data.get('error_details')}")
                
                return data.get('redis_enabled', False)
                
            except json.JSONDecodeError as e:
                print(f"❌ JSON解析失败: {e}")
                print(f"原始响应: {response.text}")
                return False
        else:
            print(f"❌ 请求失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ 请求超时")
        return False
    except requests.exceptions.ConnectionError:
        print("❌ 连接错误")
        return False
    except Exception as e:
        print(f"❌ 请求异常: {e}")
        return False

def test_other_endpoints():
    """测试其他相关端点"""
    print("\n🔍 测试其他相关端点")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试认证状态端点
    auth_status_url = f"{base_url}/api/secure-auth/status"
    
    try:
        print(f"📤 测试认证状态: {auth_status_url}")
        response = requests.get(auth_status_url, timeout=10)
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ 认证状态端点正常")
            print(f"认证状态: {data.get('authenticated', 'N/A')}")
            print(f"消息: {data.get('message', 'N/A')}")
        else:
            print(f"❌ 认证状态端点失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 认证状态测试失败: {e}")

def main():
    """主函数"""
    print("🚀 Railway Redis直接测试")
    print("=" * 60)
    
    # 测试Redis状态
    redis_ok = test_railway_redis_status()
    
    # 测试其他端点
    test_other_endpoints()
    
    # 总结
    print("\n📊 测试结果总结")
    print("=" * 60)
    
    if redis_ok:
        print("✅ Railway Redis连接正常")
        print("💡 可能的问题:")
        print("   - 会话数据在Redis中丢失")
        print("   - 客户端没有正确发送session_id")
        print("   - Cookie设置问题")
    else:
        print("❌ Railway Redis连接有问题")
        print("💡 建议:")
        print("   - 检查Railway Redis服务状态")
        print("   - 验证环境变量配置")
        print("   - 检查Redis服务日志")
    
    print("\n🔍 下一步建议:")
    print("1. 检查Railway控制台中的Redis服务状态")
    print("2. 查看应用日志中的Redis连接信息")
    print("3. 验证环境变量是否正确设置")
    print("4. 检查客户端是否正确发送session_id")

if __name__ == "__main__":
    main()

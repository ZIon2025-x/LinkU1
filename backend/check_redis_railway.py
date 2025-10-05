#!/usr/bin/env python3
"""
Railway Redis连接诊断工具
检查Redis连接状态和配置
"""

import os
import sys
import json
import logging
from datetime import datetime

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_environment_variables():
    """检查环境变量"""
    print("=" * 60)
    print("🔍 检查环境变量")
    print("=" * 60)
    
    # Railway环境检测
    railway_env = os.getenv("RAILWAY_ENVIRONMENT")
    print(f"RAILWAY_ENVIRONMENT: {railway_env}")
    
    # Redis相关环境变量
    redis_vars = [
        "REDIS_URL",
        "REDIS_HOST", 
        "REDIS_PORT",
        "REDIS_DB",
        "REDIS_PASSWORD",
        "USE_REDIS"
    ]
    
    for var in redis_vars:
        value = os.getenv(var)
        if var == "REDIS_PASSWORD" and value:
            print(f"{var}: {'*' * len(value)} (已设置)")
        else:
            print(f"{var}: {value}")
    
    print()

def test_redis_connection():
    """测试Redis连接"""
    print("=" * 60)
    print("🔗 测试Redis连接")
    print("=" * 60)
    
    try:
        import redis
        print("✅ Redis模块已安装")
    except ImportError:
        print("❌ Redis模块未安装")
        return False
    
    # 获取Redis配置
    redis_url = os.getenv("REDIS_URL")
    use_redis = os.getenv("USE_REDIS", "true").lower() == "true"
    
    print(f"USE_REDIS: {use_redis}")
    print(f"REDIS_URL: {redis_url}")
    
    if not use_redis:
        print("⚠️ Redis已禁用")
        return False
    
    if not redis_url:
        print("❌ REDIS_URL未设置")
        return False
    
    try:
        # 尝试连接Redis
        client = redis.from_url(redis_url, decode_responses=True)
        
        # 测试连接
        client.ping()
        print("✅ Redis连接成功")
        
        # 获取Redis信息
        info = client.info()
        print(f"Redis版本: {info.get('redis_version', 'unknown')}")
        print(f"连接客户端数: {info.get('connected_clients', 0)}")
        print(f"使用内存: {info.get('used_memory_human', 'unknown')}")
        print(f"运行时间: {info.get('uptime_in_seconds', 0)}秒")
        
        # 测试基本操作
        test_key = "test_connection"
        test_value = f"test_{datetime.now().isoformat()}"
        
        # 设置测试键
        client.set(test_key, test_value, ex=60)  # 60秒过期
        print("✅ 设置测试键成功")
        
        # 获取测试键
        retrieved_value = client.get(test_key)
        if retrieved_value == test_value:
            print("✅ 获取测试键成功")
        else:
            print(f"❌ 获取测试键失败: 期望 {test_value}, 实际 {retrieved_value}")
        
        # 删除测试键
        client.delete(test_key)
        print("✅ 删除测试键成功")
        
        return True
        
    except Exception as e:
        print(f"❌ Redis连接失败: {e}")
        return False

def test_session_storage():
    """测试会话存储"""
    print("=" * 60)
    print("💾 测试会话存储")
    print("=" * 60)
    
    try:
        import redis
        redis_url = os.getenv("REDIS_URL")
        if not redis_url:
            print("❌ REDIS_URL未设置")
            return False
        
        client = redis.from_url(redis_url, decode_responses=True)
        
        # 测试会话存储
        session_id = "test_session_12345"
        session_data = {
            "user_id": "test_user",
            "session_id": session_id,
            "device_fingerprint": "test_device",
            "created_at": datetime.now().isoformat(),
            "last_activity": datetime.now().isoformat(),
            "ip_address": "127.0.0.1",
            "user_agent": "test_agent",
            "is_active": True
        }
        
        # 存储会话
        import json
        client.setex(f"session:{session_id}", 3600, json.dumps(session_data))
        print("✅ 存储会话成功")
        
        # 获取会话
        retrieved_data = client.get(f"session:{session_id}")
        if retrieved_data:
            parsed_data = json.loads(retrieved_data)
            if parsed_data["user_id"] == "test_user":
                print("✅ 获取会话成功")
            else:
                print("❌ 会话数据不匹配")
        else:
            print("❌ 获取会话失败")
        
        # 清理测试数据
        client.delete(f"session:{session_id}")
        print("✅ 清理测试数据成功")
        
        return True
        
    except Exception as e:
        print(f"❌ 会话存储测试失败: {e}")
        return False

def check_secure_auth_config():
    """检查安全认证配置"""
    print("=" * 60)
    print("🔐 检查安全认证配置")
    print("=" * 60)
    
    try:
        # 导入配置
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from app.config import Config
        
        print(f"USE_REDIS: {Config.USE_REDIS}")
        print(f"REDIS_URL: {Config.REDIS_URL}")
        
        # 检查Redis配置
        redis_config = Config.get_redis_config()
        if redis_config:
            print(f"Redis配置: {redis_config}")
        else:
            print("❌ Redis配置为空")
        
        # 检查安全认证模块
        from app.secure_auth import USE_REDIS, redis_client
        
        print(f"SecureAuth USE_REDIS: {USE_REDIS}")
        print(f"SecureAuth redis_client: {'已连接' if redis_client else '未连接'}")
        
        if redis_client:
            try:
                redis_client.ping()
                print("✅ SecureAuth Redis连接正常")
            except Exception as e:
                print(f"❌ SecureAuth Redis连接失败: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ 检查安全认证配置失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 Railway Redis连接诊断工具")
    print(f"运行时间: {datetime.now().isoformat()}")
    print()
    
    # 检查环境变量
    check_environment_variables()
    
    # 测试Redis连接
    redis_ok = test_redis_connection()
    
    # 测试会话存储
    if redis_ok:
        session_ok = test_session_storage()
    else:
        session_ok = False
    
    # 检查安全认证配置
    auth_ok = check_secure_auth_config()
    
    # 总结
    print("=" * 60)
    print("📊 诊断结果总结")
    print("=" * 60)
    
    print(f"Redis连接: {'✅ 正常' if redis_ok else '❌ 失败'}")
    print(f"会话存储: {'✅ 正常' if session_ok else '❌ 失败'}")
    print(f"安全认证: {'✅ 正常' if auth_ok else '❌ 失败'}")
    
    if redis_ok and session_ok and auth_ok:
        print("\n🎉 所有检查通过！Redis配置正常")
        return 0
    else:
        print("\n⚠️ 发现问题，请检查配置")
        return 1

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Redis问题诊断脚本
检查为什么电脑端和手机端都没有调用Redis
"""

import os
import sys
import json
import logging
from datetime import datetime

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_redis_config():
    """检查Redis配置"""
    print("🔍 检查Redis配置")
    print("=" * 60)
    
    # 检查环境变量
    redis_url = os.getenv("REDIS_URL")
    use_redis = os.getenv("USE_REDIS", "true").lower() == "true"
    railway_env = os.getenv("RAILWAY_ENVIRONMENT")
    
    print(f"RAILWAY_ENVIRONMENT: {railway_env}")
    print(f"USE_REDIS: {use_redis}")
    print(f"REDIS_URL: {redis_url[:30] + '...' if redis_url else 'None'}")
    
    # 检查Config类
    try:
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from app.config import Config
        
        print(f"Config.USE_REDIS: {Config.USE_REDIS}")
        print(f"Config.REDIS_URL: {Config.REDIS_URL[:30] + '...' if Config.REDIS_URL else 'None'}")
        
        # 检查Redis配置检测逻辑
        if os.getenv("RAILWAY_ENVIRONMENT"):
            print("✅ 检测到Railway环境")
            if Config.REDIS_URL and not Config.REDIS_URL.startswith("redis://localhost"):
                print("✅ 使用Railway提供的Redis URL")
            else:
                print("❌ 没有有效的Redis URL，Redis被禁用")
                print(f"   REDIS_URL: {Config.REDIS_URL}")
        else:
            print("ℹ️ 非Railway环境")
            
    except Exception as e:
        print(f"❌ 导入Config失败: {e}")
    
    print()

def check_secure_auth_redis():
    """检查SecureAuth模块的Redis状态"""
    print("🔐 检查SecureAuth Redis状态")
    print("=" * 60)
    
    try:
        from app.secure_auth import USE_REDIS, redis_client
        
        print(f"SecureAuth.USE_REDIS: {USE_REDIS}")
        print(f"SecureAuth.redis_client: {'已连接' if redis_client else '未连接'}")
        
        if redis_client:
            try:
                redis_client.ping()
                print("✅ Redis连接测试成功")
                
                # 获取Redis信息
                info = redis_client.info()
                print(f"Redis版本: {info.get('redis_version', 'unknown')}")
                print(f"连接客户端数: {info.get('connected_clients', 0)}")
                print(f"使用内存: {info.get('used_memory_human', 'unknown')}")
                
            except Exception as e:
                print(f"❌ Redis连接测试失败: {e}")
        else:
            print("❌ Redis客户端未初始化")
            
    except Exception as e:
        print(f"❌ 导入SecureAuth失败: {e}")
    
    print()

def test_session_creation():
    """测试会话创建"""
    print("💾 测试会话创建")
    print("=" * 60)
    
    try:
        from app.secure_auth import SecureAuthManager, USE_REDIS, redis_client
        
        print(f"USE_REDIS: {USE_REDIS}")
        print(f"redis_client: {'可用' if redis_client else '不可用'}")
        
        if not USE_REDIS or not redis_client:
            print("❌ Redis不可用，无法测试会话创建")
            return False
        
        # 创建测试会话
        test_session = SecureAuthManager.create_session(
            user_id="test_user_123",
            device_fingerprint="test_device",
            ip_address="127.0.0.1",
            user_agent="test_agent"
        )
        
        print(f"✅ 会话创建成功: {test_session.session_id[:8]}...")
        
        # 尝试获取会话
        retrieved_session = SecureAuthManager.get_session(test_session.session_id)
        if retrieved_session:
            print("✅ 会话获取成功")
            print(f"   用户ID: {retrieved_session.user_id}")
            print(f"   设备指纹: {retrieved_session.device_fingerprint}")
        else:
            print("❌ 会话获取失败")
        
        # 清理测试会话
        SecureAuthManager.revoke_session(test_session.session_id)
        print("✅ 测试会话已清理")
        
        return True
        
    except Exception as e:
        print(f"❌ 会话创建测试失败: {e}")
        return False

def check_redis_cache_module():
    """检查Redis缓存模块"""
    print("🗄️ 检查Redis缓存模块")
    print("=" * 60)
    
    try:
        from app.redis_cache import redis_cache
        
        print(f"redis_cache.enabled: {redis_cache.enabled}")
        print(f"redis_cache.redis_client: {'可用' if redis_cache.redis_client else '不可用'}")
        
        if redis_cache.enabled and redis_cache.redis_client:
            try:
                redis_cache.redis_client.ping()
                print("✅ Redis缓存连接正常")
                
                # 测试缓存操作
                test_key = "test_cache_key"
                test_value = {"test": "data", "timestamp": datetime.now().isoformat()}
                
                # 设置缓存
                success = redis_cache.set(test_key, test_value, 60)
                if success:
                    print("✅ 缓存设置成功")
                    
                    # 获取缓存
                    retrieved = redis_cache.get(test_key)
                    if retrieved and retrieved.get("test") == "data":
                        print("✅ 缓存获取成功")
                    else:
                        print("❌ 缓存获取失败")
                    
                    # 清理测试数据
                    redis_cache.delete(test_key)
                    print("✅ 测试数据已清理")
                else:
                    print("❌ 缓存设置失败")
                    
            except Exception as e:
                print(f"❌ Redis缓存测试失败: {e}")
        else:
            print("❌ Redis缓存未启用")
            
    except Exception as e:
        print(f"❌ 导入Redis缓存模块失败: {e}")
    
    print()

def check_authentication_flow():
    """检查认证流程"""
    print("🔑 检查认证流程")
    print("=" * 60)
    
    try:
        from app.secure_auth import validate_session, SecureAuthManager
        from app.deps import authenticate_with_session
        
        print("✅ 认证模块导入成功")
        
        # 检查认证依赖
        print(f"validate_session函数: {validate_session}")
        print(f"authenticate_with_session函数: {authenticate_with_session}")
        
        # 检查SecureAuthManager
        print(f"SecureAuthManager.USE_REDIS: {SecureAuthManager.USE_REDIS}")
        print(f"SecureAuthManager.redis_client: {'可用' if SecureAuthManager.redis_client else '不可用'}")
        
    except Exception as e:
        print(f"❌ 认证流程检查失败: {e}")
    
    print()

def main():
    """主函数"""
    print("🚀 Redis问题诊断工具")
    print(f"运行时间: {datetime.now().isoformat()}")
    print()
    
    # 检查Redis配置
    check_redis_config()
    
    # 检查SecureAuth Redis状态
    check_secure_auth_redis()
    
    # 测试会话创建
    session_ok = test_session_creation()
    
    # 检查Redis缓存模块
    check_redis_cache_module()
    
    # 检查认证流程
    check_authentication_flow()
    
    # 总结
    print("📊 诊断结果总结")
    print("=" * 60)
    
    if session_ok:
        print("✅ Redis配置正常，会话创建和获取功能正常")
        print("💡 可能的问题:")
        print("   - 会话数据在Redis中丢失（过期、重启等）")
        print("   - 客户端没有正确发送session_id")
        print("   - Cookie设置问题")
    else:
        print("❌ Redis配置有问题")
        print("💡 建议:")
        print("   - 检查Railway Redis服务状态")
        print("   - 验证REDIS_URL环境变量")
        print("   - 检查Redis连接配置")
    
    print("\n🔍 下一步调试建议:")
    print("1. 检查应用日志中的Redis连接信息")
    print("2. 访问 /api/secure-auth/redis-status 端点")
    print("3. 检查客户端是否正确发送session_id")
    print("4. 验证Cookie设置是否正确")

if __name__ == "__main__":
    main()

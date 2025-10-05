#!/usr/bin/env python3
"""
会话流程检查工具
检查从登录到认证的完整流程
"""

import os
import sys
import json
import logging
from datetime import datetime

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_redis_connection():
    """检查Redis连接"""
    print("🔗 检查Redis连接")
    print("=" * 50)
    
    try:
        from app.secure_auth import USE_REDIS, redis_client
        
        print(f"USE_REDIS: {USE_REDIS}")
        print(f"redis_client: {'已连接' if redis_client else '未连接'}")
        
        if not USE_REDIS or not redis_client:
            print("❌ Redis未启用或未连接")
            return False
        
        # 测试连接
        redis_client.ping()
        print("✅ Redis连接正常")
        
        # 检查Redis中的会话数据
        print("\n🔍 检查Redis中的会话数据:")
        
        # 查找所有会话键
        session_keys = redis_client.keys("session:*")
        print(f"找到 {len(session_keys)} 个会话键")
        
        if session_keys:
            for key in session_keys[:5]:  # 只显示前5个
                data = redis_client.get(key)
                if data:
                    try:
                        session_data = json.loads(data)
                        print(f"  {key}: 用户 {session_data.get('user_id', 'unknown')}, 活跃: {session_data.get('is_active', False)}")
                    except:
                        print(f"  {key}: 数据解析失败")
                else:
                    print(f"  {key}: 数据为空")
        else:
            print("❌ Redis中没有找到会话数据")
        
        # 检查用户会话列表
        user_session_keys = redis_client.keys("user_sessions:*")
        print(f"\n找到 {len(user_session_keys)} 个用户会话列表")
        
        if user_session_keys:
            for key in user_session_keys[:3]:  # 只显示前3个
                session_ids = redis_client.smembers(key)
                print(f"  {key}: {len(session_ids)} 个会话")
        
        return True
        
    except Exception as e:
        print(f"❌ Redis连接检查失败: {e}")
        return False

def test_session_creation_and_retrieval():
    """测试会话创建和获取"""
    print("\n💾 测试会话创建和获取")
    print("=" * 50)
    
    try:
        from app.secure_auth import SecureAuthManager, USE_REDIS, redis_client
        
        if not USE_REDIS or not redis_client:
            print("❌ Redis不可用，跳过测试")
            return False
        
        # 创建测试会话
        print("1. 创建测试会话...")
        test_session = SecureAuthManager.create_session(
            user_id="test_user_456",
            device_fingerprint="test_device_456",
            ip_address="127.0.0.1",
            user_agent="test_agent_456"
        )
        
        print(f"✅ 会话创建成功: {test_session.session_id[:8]}...")
        print(f"   用户ID: {test_session.user_id}")
        print(f"   设备指纹: {test_session.device_fingerprint}")
        
        # 立即获取会话
        print("\n2. 立即获取会话...")
        retrieved_session = SecureAuthManager.get_session(test_session.session_id)
        if retrieved_session:
            print("✅ 会话获取成功")
            print(f"   用户ID: {retrieved_session.user_id}")
            print(f"   设备指纹: {retrieved_session.device_fingerprint}")
            print(f"   是否活跃: {retrieved_session.is_active}")
        else:
            print("❌ 会话获取失败")
            return False
        
        # 检查Redis中的原始数据
        print("\n3. 检查Redis中的原始数据...")
        redis_data = redis_client.get(f"session:{test_session.session_id}")
        if redis_data:
            try:
                parsed_data = json.loads(redis_data)
                print("✅ Redis中有会话数据")
                print(f"   用户ID: {parsed_data.get('user_id')}")
                print(f"   是否活跃: {parsed_data.get('is_active')}")
                print(f"   创建时间: {parsed_data.get('created_at')}")
            except Exception as e:
                print(f"❌ Redis数据解析失败: {e}")
        else:
            print("❌ Redis中没有找到会话数据")
            return False
        
        # 清理测试会话
        print("\n4. 清理测试会话...")
        SecureAuthManager.revoke_session(test_session.session_id)
        print("✅ 测试会话已清理")
        
        return True
        
    except Exception as e:
        print(f"❌ 会话创建和获取测试失败: {e}")
        return False

def check_authentication_dependencies():
    """检查认证依赖"""
    print("\n🔑 检查认证依赖")
    print("=" * 50)
    
    try:
        from app.deps import authenticate_with_session
        from app.secure_auth import validate_session
        from app.security import SyncCookieHTTPBearer
        
        print("✅ 认证依赖导入成功")
        
        # 检查认证器
        cookie_bearer = SyncCookieHTTPBearer()
        print(f"Cookie认证器: {cookie_bearer}")
        
        # 检查认证函数
        print(f"authenticate_with_session: {authenticate_with_session}")
        print(f"validate_session: {validate_session}")
        
        return True
        
    except Exception as e:
        print(f"❌ 认证依赖检查失败: {e}")
        return False

def simulate_authentication_flow():
    """模拟认证流程"""
    print("\n🔄 模拟认证流程")
    print("=" * 50)
    
    try:
        from app.secure_auth import SecureAuthManager, validate_session
        from fastapi import Request
        from unittest.mock import Mock
        
        # 创建测试会话
        test_session = SecureAuthManager.create_session(
            user_id="simulation_user",
            device_fingerprint="simulation_device",
            ip_address="127.0.0.1",
            user_agent="simulation_agent"
        )
        
        print(f"✅ 创建模拟会话: {test_session.session_id[:8]}...")
        
        # 模拟请求
        mock_request = Mock()
        mock_request.cookies = {"session_id": test_session.session_id}
        mock_request.headers = {}
        mock_request.url = "http://test.com/api/test"
        
        print("📤 模拟请求:")
        print(f"   Cookies: {mock_request.cookies}")
        print(f"   Headers: {mock_request.headers}")
        
        # 验证会话
        print("\n🔍 验证会话...")
        validated_session = validate_session(mock_request)
        
        if validated_session:
            print("✅ 会话验证成功")
            print(f"   用户ID: {validated_session.user_id}")
            print(f"   设备指纹: {validated_session.device_fingerprint}")
        else:
            print("❌ 会话验证失败")
            return False
        
        # 清理
        SecureAuthManager.revoke_session(test_session.session_id)
        print("✅ 模拟会话已清理")
        
        return True
        
    except Exception as e:
        print(f"❌ 认证流程模拟失败: {e}")
        return False

def check_configuration_issues():
    """检查配置问题"""
    print("\n⚙️ 检查配置问题")
    print("=" * 50)
    
    try:
        from app.config import Config
        
        print("配置检查:")
        print(f"  USE_REDIS: {Config.USE_REDIS}")
        print(f"  REDIS_URL: {Config.REDIS_URL[:30] + '...' if Config.REDIS_URL else 'None'}")
        print(f"  IS_PRODUCTION: {Config.IS_PRODUCTION}")
        print(f"  ENVIRONMENT: {Config.ENVIRONMENT}")
        
        # 检查Railway环境
        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        print(f"  RAILWAY_ENVIRONMENT: {railway_env}")
        
        if railway_env:
            print("✅ 检测到Railway环境")
            if Config.REDIS_URL and not Config.REDIS_URL.startswith("redis://localhost"):
                print("✅ 使用Railway Redis URL")
            else:
                print("❌ 没有有效的Redis URL")
        else:
            print("ℹ️ 非Railway环境")
        
        # 检查Redis配置
        redis_config = Config.get_redis_config()
        if redis_config:
            print(f"✅ Redis配置: {redis_config}")
        else:
            print("❌ Redis配置为空")
        
        return True
        
    except Exception as e:
        print(f"❌ 配置检查失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 会话流程检查工具")
    print(f"运行时间: {datetime.now().isoformat()}")
    print()
    
    # 检查Redis连接
    redis_ok = check_redis_connection()
    
    # 测试会话创建和获取
    session_ok = test_session_creation_and_retrieval()
    
    # 检查认证依赖
    auth_deps_ok = check_authentication_dependencies()
    
    # 模拟认证流程
    auth_flow_ok = simulate_authentication_flow()
    
    # 检查配置问题
    config_ok = check_configuration_issues()
    
    # 总结
    print("\n📊 检查结果总结")
    print("=" * 60)
    
    print(f"Redis连接: {'✅ 正常' if redis_ok else '❌ 失败'}")
    print(f"会话创建: {'✅ 正常' if session_ok else '❌ 失败'}")
    print(f"认证依赖: {'✅ 正常' if auth_deps_ok else '❌ 失败'}")
    print(f"认证流程: {'✅ 正常' if auth_flow_ok else '❌ 失败'}")
    print(f"配置检查: {'✅ 正常' if config_ok else '❌ 失败'}")
    
    if all([redis_ok, session_ok, auth_deps_ok, auth_flow_ok, config_ok]):
        print("\n🎉 所有检查通过！")
        print("💡 可能的问题:")
        print("   - 客户端没有正确发送session_id")
        print("   - Cookie设置问题")
        print("   - 会话数据在Redis中丢失")
    else:
        print("\n⚠️ 发现问题，需要修复")
        if not redis_ok:
            print("   - 检查Redis连接配置")
        if not session_ok:
            print("   - 检查会话创建和存储")
        if not auth_flow_ok:
            print("   - 检查认证流程")

if __name__ == "__main__":
    main()

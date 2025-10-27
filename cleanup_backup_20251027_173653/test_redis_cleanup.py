#!/usr/bin/env python3
"""
测试Redis清理功能
验证过期会话数据是否能正确删除
"""

import os
import sys
import json
import time
from datetime import datetime, timedelta

# 添加项目路径
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

def test_redis_cleanup():
    """测试Redis清理功能"""
    print("🧪 开始测试Redis清理功能...")
    
    try:
        from app.redis_cache import get_redis_client
        from app.secure_auth import SecureAuthManager
        
        redis_client = get_redis_client()
        if not redis_client:
            print("❌ Redis客户端不可用")
            return False
        
        print("✅ Redis客户端连接成功")
        
        # 1. 创建测试会话
        print("\n📝 创建测试会话...")
        test_session_id = "test_session_cleanup_123"
        test_user_id = "test_user_123"
        
        # 创建一个过期的会话数据
        expired_time = datetime.utcnow() - timedelta(hours=25)  # 25小时前，已过期
        session_data = {
            "user_id": test_user_id,
            "session_id": test_session_id,
            "device_fingerprint": "test_fingerprint",
            "created_at": expired_time.isoformat(),
            "last_activity": expired_time.isoformat(),
            "ip_address": "127.0.0.1",
            "user_agent": "test_agent",
            "is_active": True
        }
        
        # 存储到Redis
        redis_client.setex(
            f"session:{test_session_id}",
            3600,  # 1小时TTL
            json.dumps(session_data)
        )
        
        # 添加到用户会话列表
        redis_client.sadd(f"user_sessions:{test_user_id}", test_session_id)
        
        print(f"✅ 测试会话已创建: {test_session_id}")
        
        # 2. 验证会话存在
        print("\n🔍 验证会话存在...")
        stored_data = redis_client.get(f"session:{test_session_id}")
        if stored_data:
            print("✅ 会话数据存在")
            print(f"   数据: {json.loads(stored_data)}")
        else:
            print("❌ 会话数据不存在")
            return False
        
        # 3. 执行清理
        print("\n🧹 执行清理...")
        SecureAuthManager.cleanup_expired_sessions()
        
        # 4. 验证清理结果
        print("\n🔍 验证清理结果...")
        stored_data = redis_client.get(f"session:{test_session_id}")
        if stored_data:
            print("❌ 过期会话未被清理")
            print(f"   剩余数据: {json.loads(stored_data)}")
            return False
        else:
            print("✅ 过期会话已被清理")
        
        # 5. 验证用户会话列表
        user_sessions = redis_client.smembers(f"user_sessions:{test_user_id}")
        if test_session_id.encode() in user_sessions:
            print("❌ 用户会话列表中仍包含已清理的会话")
            return False
        else:
            print("✅ 用户会话列表已清理")
        
        print("\n🎉 所有测试通过！Redis清理功能正常工作")
        return True
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_session_revoke():
    """测试会话撤销功能"""
    print("\n🧪 开始测试会话撤销功能...")
    
    try:
        from app.redis_cache import get_redis_client
        from app.secure_auth import SecureAuthManager
        
        redis_client = get_redis_client()
        if not redis_client:
            print("❌ Redis客户端不可用")
            return False
        
        # 1. 创建测试会话
        test_session_id = "test_revoke_session_456"
        test_user_id = "test_user_456"
        
        session_data = {
            "user_id": test_user_id,
            "session_id": test_session_id,
            "device_fingerprint": "test_fingerprint",
            "created_at": datetime.utcnow().isoformat(),
            "last_activity": datetime.utcnow().isoformat(),
            "ip_address": "127.0.0.1",
            "user_agent": "test_agent",
            "is_active": True
        }
        
        # 存储到Redis
        redis_client.setex(
            f"session:{test_session_id}",
            3600,
            json.dumps(session_data)
        )
        
        redis_client.sadd(f"user_sessions:{test_user_id}", test_session_id)
        
        print(f"✅ 测试会话已创建: {test_session_id}")
        
        # 2. 撤销会话
        print("\n🚫 撤销会话...")
        result = SecureAuthManager.revoke_session(test_session_id)
        if not result:
            print("❌ 会话撤销失败")
            return False
        
        print("✅ 会话撤销成功")
        
        # 3. 验证会话被删除
        stored_data = redis_client.get(f"session:{test_session_id}")
        if stored_data:
            print("❌ 撤销的会话未被删除")
            return False
        
        print("✅ 撤销的会话已被删除")
        
        # 4. 验证用户会话列表
        user_sessions = redis_client.smembers(f"user_sessions:{test_user_id}")
        if test_session_id.encode() in user_sessions:
            print("❌ 用户会话列表中仍包含已撤销的会话")
            return False
        
        print("✅ 用户会话列表已清理")
        print("🎉 会话撤销测试通过！")
        return True
        
    except Exception as e:
        print(f"❌ 会话撤销测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 开始Redis清理功能测试")
    print("=" * 50)
    
    # 测试清理功能
    cleanup_success = test_redis_cleanup()
    
    # 测试撤销功能
    revoke_success = test_session_revoke()
    
    print("\n" + "=" * 50)
    if cleanup_success and revoke_success:
        print("🎉 所有测试通过！Redis清理功能正常工作")
        sys.exit(0)
    else:
        print("❌ 部分测试失败，请检查代码")
        sys.exit(1)

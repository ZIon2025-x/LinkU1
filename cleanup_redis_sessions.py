#!/usr/bin/env python3
"""
Redis会话清理脚本
用于清理过期的会话数据，减少Redis存储压力
"""

import os
import sys
import json
from datetime import datetime, timedelta

# 添加项目路径
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backend'))

from app.redis_cache import get_redis_client
from app.secure_auth import cleanup_expired_sessions_aggressive

def main():
    """主函数"""
    print("🧹 开始清理Redis会话数据...")
    
    try:
        # 获取Redis客户端
        redis_client = get_redis_client()
        if not redis_client:
            print("❌ 无法连接到Redis")
            return
        
        print("✅ 已连接到Redis")
        
        # 获取当前Redis中的会话统计
        session_keys = redis_client.keys("session:*")
        user_sessions_keys = redis_client.keys("user_sessions:*")
        admin_session_keys = redis_client.keys("admin_session:*")
        service_session_keys = redis_client.keys("service_session:*")
        
        print(f"📊 清理前统计:")
        print(f"   普通用户会话: {len(session_keys)}")
        print(f"   用户会话集合: {len(user_sessions_keys)}")
        print(f"   管理员会话: {len(admin_session_keys)}")
        print(f"   客服会话: {len(service_session_keys)}")
        print(f"   总计: {len(session_keys) + len(user_sessions_keys) + len(admin_session_keys) + len(service_session_keys)}")
        
        # 执行激进清理（超过20分钟不活跃就清理）
        cleaned_count = cleanup_expired_sessions_aggressive()
        
        # 获取清理后的统计
        session_keys_after = redis_client.keys("session:*")
        user_sessions_keys_after = redis_client.keys("user_sessions:*")
        admin_session_keys_after = redis_client.keys("admin_session:*")
        service_session_keys_after = redis_client.keys("service_session:*")
        
        print(f"📊 清理后统计:")
        print(f"   普通用户会话: {len(session_keys_after)}")
        print(f"   用户会话集合: {len(user_sessions_keys_after)}")
        print(f"   管理员会话: {len(admin_session_keys_after)}")
        print(f"   客服会话: {len(service_session_keys_after)}")
        print(f"   总计: {len(session_keys_after) + len(user_sessions_keys_after) + len(admin_session_keys_after) + len(service_session_keys_after)}")
        
        print(f"✅ 清理完成！共清理了 {cleaned_count} 个过期会话")
        
        # 显示一些示例会话的TTL
        if session_keys_after:
            print(f"\n🔍 示例会话TTL:")
            for i, key in enumerate(session_keys_after[:3]):  # 只显示前3个
                ttl = redis_client.ttl(key)
                if ttl > 0:
                    hours = ttl // 3600
                    minutes = (ttl % 3600) // 60
                    print(f"   {key}: {hours}小时{minutes}分钟")
                else:
                    print(f"   {key}: 无TTL或已过期")
        
    except Exception as e:
        print(f"❌ 清理过程中出现错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
检查新会话状态
"""

import redis
import json
from datetime import datetime

# 连接到Redis
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

# 新的session_id
session_id = "aQ6_U6XmBvnkGl8-msC19du_LHCFgLXqSLvwUQNgKWs"
user_id = "15310417"

print(f"检查新session_id: {session_id}")

# 1. 检查会话数据
session_key = f"session:{session_id}"
session_data = redis_client.get(session_key)

if session_data:
    data = json.loads(session_data)
    print(f"1. 会话数据存在")
    print(f"   - user_id: {data.get('user_id')}")
    print(f"   - session_id: {data.get('session_id')}")
    print(f"   - is_active: {data.get('is_active')}")
    print(f"   - created_at: {data.get('created_at')}")
    print(f"   - last_activity: {data.get('last_activity')}")
    print(f"   - device_fingerprint: {data.get('device_fingerprint')}")
    print(f"   - ip_address: {data.get('ip_address')}")
    print(f"   - user_agent: {data.get('user_agent')}")
    
    # 2. 检查会话是否过期
    last_activity = datetime.fromisoformat(data["last_activity"])
    now = datetime.utcnow()
    time_diff = now - last_activity
    
    print(f"\n2. 时间检查")
    print(f"   - 最后活动时间: {last_activity}")
    print(f"   - 当前时间: {now}")
    print(f"   - 时间差: {time_diff}")
    print(f"   - 是否过期 (>24小时): {time_diff.total_seconds() > 24 * 3600}")
    
    # 3. 检查用户会话列表
    user_sessions_key = f"user_sessions:{user_id}"
    user_sessions = redis_client.smembers(user_sessions_key)
    print(f"\n3. 用户会话列表")
    print(f"   - 用户ID: {user_id}")
    print(f"   - 会话列表key: {user_sessions_key}")
    print(f"   - 会话数量: {len(user_sessions)}")
    print(f"   - 当前会话在列表中: {session_id in user_sessions}")
    
    # 4. 模拟get_session逻辑
    print(f"\n4. 模拟get_session逻辑")
    if not data.get("is_active", False):
        print("   - 会话不活跃，应该返回None")
    else:
        print("   - 会话活跃")
        
        # 检查过期时间
        if time_diff.total_seconds() > 24 * 3600:
            print("   - 会话已过期，应该返回None")
        else:
            print("   - 会话未过期，应该返回会话信息")
            
else:
    print("1. 会话数据不存在")

# 5. 检查所有相关的Redis key
print(f"\n5. Redis key检查")
all_session_keys = redis_client.keys("session:*")
print(f"   - 总会话数: {len(all_session_keys)}")
print(f"   - 当前会话key存在: {session_key in all_session_keys}")

# 6. 检查是否有其他活跃会话
print(f"\n6. 用户其他活跃会话")
if 'user_id' in locals():
    active_sessions = []
    for sid in user_sessions:
        if sid != session_id:  # 排除当前会话
            data = redis_client.get(f"session:{sid}")
            if data:
                data_json = json.loads(data)
                if data_json.get("is_active", False):
                    active_sessions.append(sid)
    
    print(f"   - 其他活跃会话数: {len(active_sessions)}")
    if active_sessions:
        print(f"   - 其他活跃会话: {active_sessions[:5]}...")  # 只显示前5个

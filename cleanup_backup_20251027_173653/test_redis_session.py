#!/usr/bin/env python3
"""
测试Redis中的会话数据
"""

import redis
import json
from datetime import datetime

# 连接到Redis
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

# 测试的session_id
session_id = "2Pll2B8CkwVWKdaai8mGNn60uTddQrD3fqWTunqobEE"

print(f"检查session_id: {session_id}")

# 检查会话数据
session_key = f"session:{session_id}"
session_data = redis_client.get(session_key)

print(f"Redis key: {session_key}")
print(f"Session data: {session_data}")

if session_data:
    try:
        data = json.loads(session_data)
        print(f"Parsed data: {data}")
        
        # 检查会话是否过期
        last_activity = datetime.fromisoformat(data["last_activity"])
        now = datetime.utcnow()
        time_diff = now - last_activity
        
        print(f"Last activity: {last_activity}")
        print(f"Current time: {now}")
        print(f"Time difference: {time_diff}")
        print(f"Is active: {data.get('is_active', False)}")
        
        # 检查是否过期（24小时）
        if time_diff.total_seconds() > 24 * 3600:
            print("会话已过期")
        else:
            print("会话未过期")
            
    except Exception as e:
        print(f"解析数据失败: {e}")
else:
    print("未找到会话数据")

# 检查用户的所有会话
user_id = "15310417"
user_sessions_key = f"user_sessions:{user_id}"
user_sessions = redis_client.smembers(user_sessions_key)
print(f"用户 {user_id} 的所有会话: {user_sessions}")

# 列出所有session相关的key
all_session_keys = redis_client.keys("session:*")
print(f"所有会话key: {all_session_keys[:10]}...")  # 只显示前10个

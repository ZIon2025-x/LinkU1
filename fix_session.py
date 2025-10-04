#!/usr/bin/env python3
"""
修复会话状态
"""

import redis
import json

# 连接到Redis
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

# 要修复的session_id
session_id = "2Pll2B8CkwVWKdaai8mGNn60uTddQrD3fqWTunqobEE"
user_id = "15310417"

print(f"修复session_id: {session_id}")

# 获取会话数据
session_key = f"session:{session_id}"
session_data = redis_client.get(session_key)

if session_data:
    data = json.loads(session_data)
    print(f"当前状态: is_active = {data.get('is_active', False)}")
    
    # 修复会话状态
    data["is_active"] = True
    
    # 保存回Redis
    redis_client.setex(
        session_key,
        24 * 3600,  # 24小时过期
        json.dumps(data)
    )
    
    print("会话已修复为活跃状态")
    
    # 将会话ID重新添加到用户会话列表
    user_sessions_key = f"user_sessions:{user_id}"
    redis_client.sadd(user_sessions_key, session_id)
    redis_client.expire(user_sessions_key, 24 * 3600)
    
    print("会话已重新添加到用户会话列表")
    
    # 验证修复结果
    updated_data = redis_client.get(session_key)
    if updated_data:
        updated_json = json.loads(updated_data)
        print(f"修复后状态: is_active = {updated_json.get('is_active', False)}")
else:
    print("未找到会话数据")

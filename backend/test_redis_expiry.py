#!/usr/bin/env python3
"""
测试Redis自动过期功能
"""

import redis
import json
import time
from datetime import datetime

# 连接Redis
r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

def test_redis_expiry():
    """测试Redis自动过期"""
    print("=== Redis自动过期测试 ===")
    
    # 测试数据
    test_data = {
        "admin_id": "A0001",
        "code": "123456",
        "created_at": datetime.utcnow().isoformat(),
        "is_used": False
    }
    
    key = "admin_verification_code:A0001"
    
    # 1. 设置数据，TTL为10秒（测试用）
    print(f"1. 设置验证码，TTL=10秒")
    r.setex(key, 10, json.dumps(test_data))
    
    # 2. 立即检查
    print(f"2. 立即检查TTL: {r.ttl(key)}秒")
    print(f"   数据存在: {r.exists(key)}")
    
    # 3. 等待5秒后检查
    print(f"3. 等待5秒...")
    time.sleep(5)
    print(f"   剩余TTL: {r.ttl(key)}秒")
    print(f"   数据存在: {r.exists(key)}")
    
    # 4. 等待6秒后检查（应该过期）
    print(f"4. 再等待6秒...")
    time.sleep(6)
    print(f"   剩余TTL: {r.ttl(key)}秒")
    print(f"   数据存在: {r.exists(key)}")
    
    # 5. 尝试获取数据
    data = r.get(key)
    if data:
        print(f"   数据内容: {data}")
    else:
        print("   数据已自动过期并被删除！")
    
    print("\n=== 测试完成 ===")
    print("结论：Redis会自动清理过期的验证码数据，无需手动清理！")

if __name__ == "__main__":
    try:
        test_redis_expiry()
    except redis.ConnectionError:
        print("错误：无法连接到Redis服务器")
        print("请确保Redis正在运行：redis-server")
    except Exception as e:
        print(f"错误：{e}")

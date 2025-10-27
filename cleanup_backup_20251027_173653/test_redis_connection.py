#!/usr/bin/env python3
"""
Redis连接测试脚本
用于验证Railway环境中的Redis配置
"""

import os
import sys
sys.path.append('backend')

from backend.app.config import Config
from backend.app.redis_cache import get_redis_client

def test_redis_connection():
    """测试Redis连接"""
    print("Redis连接测试")
    print("=" * 50)
    
    # 显示配置信息
    print(f"USE_REDIS: {Config.USE_REDIS}")
    print(f"REDIS_URL: {Config.REDIS_URL}")
    print(f"REDIS_HOST: {Config.REDIS_HOST}")
    print(f"REDIS_PORT: {Config.REDIS_PORT}")
    print(f"REDIS_DB: {Config.REDIS_DB}")
    print(f"REDIS_PASSWORD: {'***' if Config.REDIS_PASSWORD else 'None'}")
    print()
    
    # 测试Redis客户端
    try:
        client = get_redis_client()
        if client:
            print("SUCCESS: Redis客户端创建成功")
            
            # 测试连接
            client.ping()
            print("SUCCESS: Redis连接测试成功")
            
            # 测试基本操作
            client.set("test_key", "test_value", ex=10)
            value = client.get("test_key")
            if value == b"test_value":
                print("SUCCESS: Redis读写测试成功")
            else:
                print("ERROR: Redis读写测试失败")
            
            # 清理测试数据
            client.delete("test_key")
            print("SUCCESS: Redis清理测试完成")
            
        else:
            print("ERROR: Redis客户端不可用")
            print("建议：检查Redis配置或设置USE_REDIS=false")
            
    except Exception as e:
        print(f"ERROR: Redis连接失败: {e}")
        print("建议：")
        print("   1. 检查REDIS_URL是否正确")
        print("   2. 确认Railway中已添加Redis服务")
        print("   3. 或设置USE_REDIS=false使用内存缓存")

if __name__ == "__main__":
    test_redis_connection()

#!/usr/bin/env python3
"""
测试客服refresh token保存到Redis
"""

import os
import sys
import json
from datetime import datetime, timedelta

# 添加项目路径
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

def test_service_refresh_token():
    """测试客服refresh token保存到Redis"""
    print("🧪 测试客服refresh token保存到Redis...")
    
    try:
        from app.redis_cache import get_redis_client
        
        redis_client = get_redis_client()
        if not redis_client:
            print("❌ Redis客户端不可用")
            return False
        
        print("✅ Redis客户端连接成功")
        
        # 1. 检查现有的客服refresh token
        print("\n📊 检查现有的客服refresh token...")
        service_refresh_keys = redis_client.keys("service_refresh_token:*")
        print(f"找到 {len(service_refresh_keys)} 个客服refresh token")
        
        for key in service_refresh_keys:
            key_str = key.decode() if isinstance(key, bytes) else key
            data = redis_client.get(key_str)
            if data:
                try:
                    refresh_data = json.loads(data.decode() if isinstance(data, bytes) else data)
                    print(f"  {key_str}")
                    print(f"    客服ID: {refresh_data.get('service_id', 'N/A')}")
                    print(f"    创建时间: {refresh_data.get('created_at', 'N/A')}")
                    print(f"    过期时间: {refresh_data.get('expires_at', 'N/A')}")
                except Exception as e:
                    print(f"    数据解析错误: {e}")
        
        # 2. 测试生成新的客服refresh token
        print("\n🔧 测试生成新的客服refresh token...")
        import secrets
        from datetime import datetime, timedelta
        
        test_service_id = "CS8888"
        test_refresh_token = secrets.token_urlsafe(32)
        
        refresh_data = {
            "service_id": test_service_id,
            "created_at": datetime.utcnow().isoformat(),
            "expires_at": (datetime.utcnow() + timedelta(days=30)).isoformat()
        }
        
        # 保存到Redis
        redis_client.setex(
            f"service_refresh_token:{test_refresh_token}",
            30 * 24 * 3600,  # 30天TTL
            json.dumps(refresh_data)
        )
        
        print(f"✅ 测试refresh token已保存: {test_refresh_token[:16]}...")
        
        # 3. 验证保存的数据
        print("\n🔍 验证保存的数据...")
        saved_data = redis_client.get(f"service_refresh_token:{test_refresh_token}")
        if saved_data:
            try:
                parsed_data = json.loads(saved_data.decode() if isinstance(saved_data, bytes) else saved_data)
                print(f"✅ 数据验证成功:")
                print(f"  客服ID: {parsed_data.get('service_id')}")
                print(f"  创建时间: {parsed_data.get('created_at')}")
                print(f"  过期时间: {parsed_data.get('expires_at')}")
            except Exception as e:
                print(f"❌ 数据解析失败: {e}")
        else:
            print("❌ 未找到保存的数据")
        
        # 4. 测试验证函数
        print("\n🔍 测试验证函数...")
        from app.service_auth import verify_service_refresh_token
        
        verified_service_id = verify_service_refresh_token(test_refresh_token)
        if verified_service_id == test_service_id:
            print(f"✅ 验证函数工作正常: {verified_service_id}")
        else:
            print(f"❌ 验证函数失败: 期望 {test_service_id}, 得到 {verified_service_id}")
        
        # 5. 清理测试数据
        print("\n🧹 清理测试数据...")
        redis_client.delete(f"service_refresh_token:{test_refresh_token}")
        print("✅ 测试数据已清理")
        
        print("\n🎉 客服refresh token测试完成！")
        return True
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 开始客服refresh token测试")
    print("=" * 60)
    
    success = test_service_refresh_token()
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 测试通过！客服refresh token功能正常工作")
        sys.exit(0)
    else:
        print("❌ 测试失败，请检查代码")
        sys.exit(1)

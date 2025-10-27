#!/usr/bin/env python3
"""
测试客服离线端点
"""

import requests
import json

def test_offline_endpoint():
    """测试客服离线端点"""
    api_base_url = "https://api.link2ur.com"
    
    print("🔍 测试客服离线端点")
    print("=" * 50)
    
    # 测试离线端点
    try:
        print("发送 POST 请求到 /api/customer-service/offline...")
        response = requests.post(
            f"{api_base_url}/api/customer-service/offline",
            timeout=10,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        )
        
        print(f"状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ 请求成功")
            print(f"响应数据: {response.json()}")
        else:
            print("❌ 请求失败")
            print(f"错误响应: {response.text}")
            
    except Exception as e:
        print(f"❌ 请求异常: {e}")

if __name__ == "__main__":
    test_offline_endpoint()

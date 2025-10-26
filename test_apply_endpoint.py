#!/usr/bin/env python3
"""
测试 /api/tasks/{task_id}/apply 端点
"""

import requests
import json

# 测试配置
API_BASE_URL = "https://api.link2ur.com"
TASK_ID = 42

# 模拟请求头（需要真实的 session 和 CSRF token）
headers = {
    'Content-Type': 'application/json',
    'X-CSRF-Token': 'DFa32xl-wFzVTgSNjwapuw2xiF4vurdS5Jd-ikn48yw',  # 从请求中获取
    'Cookie': 'user_id=27167013; user_authenticated=true; session_id=082lhNNTFJLNNdiOTSih0HODz56hPvfyrhX3bKlMt0A; refresh_token=Aj_MJ53f9I3nhVxq15bjgY5rJUQ0cSyAAmGm6fQuhfQ; csrf_token=DFa32xl-wFzVTgSNjwapuw2xiF4vurdS5Jd-ikn48yw'
}

# 测试数据
test_data = {
    "message": ""
}

def test_apply_endpoint():
    """测试申请任务端点"""
    url = f"{API_BASE_URL}/api/tasks/{TASK_ID}/apply"
    
    print(f"测试 URL: {url}")
    print(f"请求头: {headers}")
    print(f"请求体: {test_data}")
    
    try:
        response = requests.post(url, headers=headers, json=test_data)
        
        print(f"\n响应状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ 请求成功!")
            print(f"响应数据: {response.json()}")
        else:
            print("❌ 请求失败!")
            try:
                error_data = response.json()
                print(f"错误信息: {error_data}")
            except:
                print(f"错误文本: {response.text}")
                
    except Exception as e:
        print(f"❌ 请求异常: {e}")

if __name__ == "__main__":
    test_apply_endpoint()

#!/usr/bin/env python3
"""
最终测试客服登录功能
"""

import requests
import json
import time

def test_service_login():
    """测试客服登录API"""
    base_url = "http://localhost:8000"
    
    # 等待服务器完全启动
    print("等待服务器启动...")
    time.sleep(3)
    
    # 测试数据 - 使用一个可能存在的客服账号
    test_cases = [
        {
            "cs_id": "CS0001",
            "password": "password123"
        },
        {
            "cs_id": "test@example.com", 
            "password": "password123"
        }
    ]
    
    for i, test_data in enumerate(test_cases, 1):
        print(f"\n=== 测试用例 {i} ===")
        print(f"请求URL: {base_url}/api/auth/service/login")
        print(f"请求数据: {json.dumps(test_data, indent=2)}")
        
        try:
            response = requests.post(
                f"{base_url}/api/auth/service/login",
                json=test_data,
                headers={"Content-Type": "application/json"},
                cookies={},
                timeout=10
            )
            
            print(f"响应状态码: {response.status_code}")
            print(f"响应头: {dict(response.headers)}")
            
            try:
                response_data = response.json()
                print(f"响应内容: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
            except:
                print(f"响应内容(非JSON): {response.text}")
            
            if response.status_code == 200:
                print("✅ 客服登录成功")
                return True
            elif response.status_code == 401:
                print("⚠️ 认证失败（用户名或密码错误）")
            elif response.status_code == 500:
                print("❌ 服务器内部错误")
            else:
                print(f"❌ 未知错误: {response.status_code}")
                
        except requests.exceptions.ConnectionError:
            print("❌ 连接失败：服务器可能未启动")
            return False
        except Exception as e:
            print(f"❌ 请求异常: {e}")
            return False
    
    return False

if __name__ == "__main__":
    print("测试客服登录功能...")
    success = test_service_login()
    if success:
        print("\n🎉 客服登录测试通过！")
    else:
        print("\n💥 客服登录测试失败！")

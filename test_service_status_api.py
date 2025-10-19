#!/usr/bin/env python3
"""
测试客服在线状态API
"""

import requests
import json

def test_service_status_api():
    """测试客服在线状态API"""
    
    print("🧪 测试客服在线状态API")
    print("=" * 50)
    
    # 1. 先登录获取Cookie
    print("1. 客服登录...")
    login_data = {
        "cs_id": "CS8888",
        "password": "password123"
    }
    
    session = requests.Session()
    response = session.post(
        "https://api.link2ur.com/api/auth/service/login",
        json=login_data
    )
    
    if response.status_code != 200:
        print(f"❌ 登录失败: {response.status_code}")
        print(f"响应: {response.text}")
        return
    
    print("✅ 登录成功")
    print(f"响应: {response.json()}")
    
    # 2. 获取当前状态
    print("\n2. 获取当前状态...")
    response = session.get("https://api.link2ur.com/api/customer-service/status")
    
    if response.status_code == 200:
        status_data = response.json()
        print(f"✅ 当前状态: {status_data}")
        current_status = status_data.get('is_online', False)
    else:
        print(f"❌ 获取状态失败: {response.status_code}")
        print(f"响应: {response.text}")
        return
    
    # 3. 测试状态切换
    print(f"\n3. 测试状态切换 (当前: {'在线' if current_status else '离线'})...")
    
    # 切换到相反状态
    if current_status:
        print("切换到离线状态...")
        response = session.post("https://api.link2ur.com/api/customer-service/offline")
    else:
        print("切换到在线状态...")
        response = session.post("https://api.link2ur.com/api/customer-service/online")
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ 状态切换成功: {result}")
    else:
        print(f"❌ 状态切换失败: {response.status_code}")
        print(f"响应: {response.text}")
        return
    
    # 4. 验证状态是否真的改变了
    print("\n4. 验证状态是否改变...")
    response = session.get("https://api.link2ur.com/api/customer-service/status")
    
    if response.status_code == 200:
        new_status_data = response.json()
        print(f"✅ 新状态: {new_status_data}")
        new_status = new_status_data.get('is_online', False)
        
        if new_status != current_status:
            print("✅ 状态确实改变了！")
        else:
            print("❌ 状态没有改变！")
    else:
        print(f"❌ 验证状态失败: {response.status_code}")
        print(f"响应: {response.text}")
    
    # 5. 测试切换回原状态
    print(f"\n5. 切换回原状态...")
    if new_status:
        print("切换回离线状态...")
        response = session.post("https://api.link2ur.com/api/customer-service/offline")
    else:
        print("切换回在线状态...")
        response = session.post("https://api.link2ur.com/api/customer-service/online")
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ 切换回原状态成功: {result}")
    else:
        print(f"❌ 切换回原状态失败: {response.status_code}")
        print(f"响应: {response.text}")

def test_direct_database_check():
    """直接检查数据库中的状态"""
    print("\n6. 直接检查数据库状态...")
    print("注意：这需要数据库访问权限，可能无法在远程环境中执行")
    
    try:
        # 这里可以添加直接数据库查询的代码
        # 但由于这是远程环境，我们无法直接访问数据库
        print("⚠️ 无法直接访问数据库，跳过此测试")
    except Exception as e:
        print(f"❌ 数据库检查失败: {e}")

if __name__ == "__main__":
    print("开始测试客服在线状态API...")
    
    test_service_status_api()
    test_direct_database_check()
    
    print("\n测试完成")

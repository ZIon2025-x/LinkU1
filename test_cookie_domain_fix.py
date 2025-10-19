#!/usr/bin/env python3
"""
测试Cookie域名修复
"""

import requests
import json

def test_cookie_domain_fix():
    """测试Cookie域名修复"""
    
    print("🧪 测试Cookie域名修复")
    print("=" * 50)
    
    # 1. 客服登录
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
    
    # 2. 检查Cookie设置
    print("\n2. 检查Cookie设置...")
    cookies = session.cookies.get_dict()
    print(f"获取到的Cookie: {cookies}")
    
    # 检查是否有重复的Cookie
    cookie_names = list(cookies.keys())
    duplicate_names = [name for name in set(cookie_names) if cookie_names.count(name) > 1]
    
    if duplicate_names:
        print(f"❌ 发现重复Cookie: {duplicate_names}")
    else:
        print("✅ 没有重复Cookie")
    
    # 3. 测试状态切换
    print("\n3. 测试状态切换...")
    
    # 获取当前状态
    response = session.get("https://api.link2ur.com/api/customer-service/status")
    if response.status_code == 200:
        status_data = response.json()
        current_status = status_data.get('is_online', False)
        print(f"当前状态: {'在线' if current_status else '离线'}")
        
        # 切换状态
        if current_status:
            print("切换到离线状态...")
            response = session.post("https://api.link2ur.com/api/customer-service/offline")
        else:
            print("切换到在线状态...")
            response = session.post("https://api.link2ur.com/api/customer-service/online")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 状态切换成功: {result}")
            
            # 验证状态是否真的改变了
            response = session.get("https://api.link2ur.com/api/customer-service/status")
            if response.status_code == 200:
                new_status_data = response.json()
                new_status = new_status_data.get('is_online', False)
                print(f"新状态: {'在线' if new_status else '离线'}")
                
                if new_status != current_status:
                    print("✅ 状态确实改变了！")
                else:
                    print("❌ 状态没有改变！")
            else:
                print(f"❌ 验证状态失败: {response.status_code}")
        else:
            print(f"❌ 状态切换失败: {response.status_code}")
            print(f"响应: {response.text}")
    else:
        print(f"❌ 获取状态失败: {response.status_code}")

if __name__ == "__main__":
    test_cookie_domain_fix()

#!/usr/bin/env python3
"""
测试只使用api.link2ur.com域名的Cookie
"""

import requests
import json

def test_api_domain_cookies():
    """测试只使用api.link2ur.com域名的Cookie"""
    
    print("🧪 测试只使用api.link2ur.com域名的Cookie")
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
    
    # 检查Cookie域名
    for cookie in session.cookies:
        print(f"Cookie: {cookie.name} = {cookie.value[:20]}...")
        print(f"  域名: {cookie.domain}")
        print(f"  路径: {cookie.path}")
        print(f"  HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
        print()
    
    # 3. 测试API调用
    print("3. 测试API调用...")
    
    # 测试状态获取
    response = session.get("https://api.link2ur.com/api/customer-service/status")
    if response.status_code == 200:
        status_data = response.json()
        print(f"✅ 状态获取成功: {status_data}")
    else:
        print(f"❌ 状态获取失败: {response.status_code}")
    
    # 测试状态切换
    print("\n4. 测试状态切换...")
    response = session.post("https://api.link2ur.com/api/customer-service/offline")
    if response.status_code == 200:
        result = response.json()
        print(f"✅ 状态切换成功: {result}")
    else:
        print(f"❌ 状态切换失败: {response.status_code}")
        print(f"响应: {response.text}")

if __name__ == "__main__":
    test_api_domain_cookies()

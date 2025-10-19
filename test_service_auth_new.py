#!/usr/bin/env python3
"""
测试新的客服认证系统
验证客服登录、登出、会话管理等功能
"""

import requests
import json
import time

# 配置
BASE_URL = "https://linku1-production.up.railway.app"  # Railway部署地址
SERVICE_LOGIN_ENDPOINT = f"{BASE_URL}/api/auth/service/login"
SERVICE_PROFILE_ENDPOINT = f"{BASE_URL}/api/auth/service/profile"
SERVICE_LOGOUT_ENDPOINT = f"{BASE_URL}/api/auth/service/logout"

def test_service_login():
    """测试客服登录"""
    print("=== 测试客服登录 ===")
    
    # 测试数据
    login_data = {
        "cs_id": "CS0001",  # 客服ID
        "password": "password123"
    }
    
    try:
        # 发送登录请求
        response = requests.post(
            SERVICE_LOGIN_ENDPOINT,
            json=login_data,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"登录响应状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        print(f"Set-Cookie: {response.headers.get('Set-Cookie', 'None')}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"登录成功: {json.dumps(data, indent=2, ensure_ascii=False)}")
            
            # 检查Cookie
            cookies = response.cookies
            print(f"返回的Cookie: {dict(cookies)}")
            
            # 检查是否有客服相关的Cookie
            service_cookies = {}
            for cookie in cookies:
                if 'service' in cookie.name:
                    service_cookies[cookie.name] = cookie.value
            
            print(f"客服相关Cookie: {service_cookies}")
            
            return cookies
        else:
            print(f"登录失败: {response.text}")
            return None
            
    except Exception as e:
        print(f"登录请求异常: {e}")
        return None

def test_service_profile(cookies):
    """测试获取客服信息"""
    print("\n=== 测试获取客服信息 ===")
    
    if not cookies:
        print("没有有效的Cookie，跳过测试")
        return
    
    try:
        response = requests.get(
            SERVICE_PROFILE_ENDPOINT,
            cookies=cookies
        )
        
        print(f"Profile响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"客服信息: {json.dumps(data, indent=2, ensure_ascii=False)}")
        else:
            print(f"获取客服信息失败: {response.text}")
            
    except Exception as e:
        print(f"获取客服信息异常: {e}")

def test_service_logout(cookies):
    """测试客服登出"""
    print("\n=== 测试客服登出 ===")
    
    if not cookies:
        print("没有有效的Cookie，跳过测试")
        return
    
    try:
        response = requests.post(
            SERVICE_LOGOUT_ENDPOINT,
            cookies=cookies
        )
        
        print(f"登出响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"登出成功: {json.dumps(data, indent=2, ensure_ascii=False)}")
            
            # 检查Cookie是否被清除
            print(f"登出后的Set-Cookie: {response.headers.get('Set-Cookie', 'None')}")
        else:
            print(f"登出失败: {response.text}")
            
    except Exception as e:
        print(f"登出请求异常: {e}")

def test_cookie_validation():
    """测试Cookie验证"""
    print("\n=== 测试Cookie验证 ===")
    
    # 先登录获取Cookie
    cookies = test_service_login()
    
    if cookies:
        # 等待一下
        time.sleep(1)
        
        # 测试获取信息
        test_service_profile(cookies)
        
        # 测试登出
        test_service_logout(cookies)
        
        # 登出后再次尝试获取信息（应该失败）
        print("\n=== 测试登出后的访问 ===")
        test_service_profile(cookies)

def main():
    """主测试函数"""
    print("开始测试新的客服认证系统...")
    print(f"测试目标: {BASE_URL}")
    print("=" * 50)
    
    # 运行所有测试
    test_cookie_validation()
    
    print("\n" + "=" * 50)
    print("测试完成")

if __name__ == "__main__":
    main()

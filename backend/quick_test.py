#!/usr/bin/env python3
"""
快速测试移动端Cookie修复
"""

import requests
import json

def test_local_mobile_login():
    """测试本地移动端登录"""
    local_url = 'http://localhost:8000'
    
    # 模拟移动端User-Agent
    mobile_headers = {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1',
        'Accept': 'application/json, text/plain, */*',
        'Origin': 'https://link-u1.vercel.app',
        'Referer': 'https://link-u1.vercel.app/'
    }
    
    # 创建会话
    session = requests.Session()
    session.headers.update(mobile_headers)
    
    # 测试登录
    login_data = {
        "email": "mobiletest@example.com",
        "password": "test123"
    }
    
    try:
        print("测试本地移动端登录...")
        login_response = session.post(f"{local_url}/api/secure-auth/login", json=login_data)
        print(f"登录状态: {login_response.status_code}")
        
        if login_response.status_code == 200:
            login_result = login_response.json()
            print(f"Login success: {login_result.get('message')}")
            print(f"Session ID: {login_result.get('session_id', 'N/A')[:8]}...")
            
            # 检查Cookie
            cookies = session.cookies.get_dict()
            print(f"Cookies: {cookies}")
            
            # 测试获取用户信息
            print("Testing cookie authentication...")
            profile_response = session.get(f"{local_url}/api/users/profile/me")
            print(f"Profile status: {profile_response.status_code}")
            
            if profile_response.status_code == 200:
                profile_data = profile_response.json()
                print(f"Cookie auth success: {profile_data.get('name', 'N/A')}")
                return True
            else:
                print(f"Cookie auth failed: {profile_response.text}")
                return False
        else:
            print(f"Login failed: {login_response.text}")
            return False
            
    except Exception as e:
        print(f"Test failed: {e}")
        return False

if __name__ == "__main__":
    test_local_mobile_login()

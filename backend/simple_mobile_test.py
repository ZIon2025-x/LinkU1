"""
简化的移动端测试工具
"""

import requests
import json

def test_mobile_login():
    """测试移动端登录"""
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟移动端User-Agent
    mobile_headers = {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Origin': 'https://link-u1.vercel.app',
        'Referer': 'https://link-u1.vercel.app/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site'
    }
    
    session = requests.Session()
    
    print("1. 测试CSRF token...")
    csrf_response = session.get(f"{base_url}/api/csrf/token", headers=mobile_headers)
    print(f"   Status: {csrf_response.status_code}")
    print(f"   Response: {csrf_response.text[:200]}")
    
    print("\n2. 测试登录...")
    import os
    login_data = {
        "email": os.getenv("TEST_EMAIL", "test@example.com"),
        "password": os.getenv("TEST_PASSWORD", "test-password")
    }
    
    login_response = session.post(
        f"{base_url}/api/secure-auth/login",
        json=login_data,
        headers=mobile_headers
    )
    
    print(f"   Status: {login_response.status_code}")
    print(f"   Response: {login_response.text[:200]}")
    print(f"   Cookies: {dict(login_response.cookies)}")
    
    # 检查Set-Cookie头
    set_cookie = login_response.headers.get('Set-Cookie', '')
    print(f"   Set-Cookie: {set_cookie}")
    
    print("\n3. 测试认证...")
    profile_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
    print(f"   Status: {profile_response.status_code}")
    print(f"   Response: {profile_response.text[:200]}")
    print(f"   Request Cookie: {profile_response.request.headers.get('Cookie', '')}")

if __name__ == "__main__":
    test_mobile_login()

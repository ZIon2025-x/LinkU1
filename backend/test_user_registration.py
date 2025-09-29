"""
测试用户注册和登录
"""

import requests
import json
import time

def test_user_registration_and_login():
    """测试用户注册和登录"""
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
    
    # 生成唯一的测试用户
    timestamp = int(time.time())
    test_email = f"test_mobile_{timestamp}@example.com"
    test_password = "test_password_123"
    
    print(f"测试用户: {test_email}")
    
    print("\n1. 测试用户注册...")
    register_data = {
        "name": f"Test Mobile User {timestamp}",
        "email": test_email,
        "password": test_password,
        "phone": "1234567890"
    }
    
    register_response = session.post(
        f"{base_url}/api/users/register",
        json=register_data,
        headers=mobile_headers
    )
    
    print(f"   Status: {register_response.status_code}")
    print(f"   Response: {register_response.text[:300]}")
    print(f"   Cookies: {dict(register_response.cookies)}")
    
    # 检查Set-Cookie头
    set_cookie = register_response.headers.get('Set-Cookie', '')
    print(f"   Set-Cookie: {set_cookie}")
    
    if register_response.status_code == 200:
        print("\n2. 测试登录...")
        login_data = {
            "email": test_email,
            "password": test_password
        }
        
        login_response = session.post(
            f"{base_url}/api/secure-auth/login",
            json=login_data,
            headers=mobile_headers
        )
        
        print(f"   Status: {login_response.status_code}")
        print(f"   Response: {login_response.text[:300]}")
        print(f"   Cookies: {dict(login_response.cookies)}")
        
        # 检查Set-Cookie头
        set_cookie = login_response.headers.get('Set-Cookie', '')
        print(f"   Set-Cookie: {set_cookie}")
        
        if login_response.status_code == 200:
            print("\n3. 测试认证...")
            profile_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
            print(f"   Status: {profile_response.status_code}")
            print(f"   Response: {profile_response.text[:300]}")
            print(f"   Request Cookie: {profile_response.request.headers.get('Cookie', '')}")
            
            # 检查所有Cookie
            print(f"\n4. 检查所有Cookie:")
            print(f"   Session cookies: {dict(session.cookies)}")
            
            # 测试多次请求
            print(f"\n5. 测试多次请求...")
            for i in range(3):
                test_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
                print(f"   请求 {i+1}: Status={test_response.status_code}, Cookie={bool(test_response.request.headers.get('Cookie', ''))}")
        else:
            print("   登录失败，无法继续测试")
    else:
        print("   注册失败，无法继续测试")

if __name__ == "__main__":
    test_user_registration_and_login()

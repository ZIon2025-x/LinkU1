"""
测试用户凭据
"""

import requests
import json

def test_user_login():
    """测试用户登录"""
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
    
    # 使用您提供的凭据
    user_creds = {
        "email": "zixiong316@gmail.com",
        "password": "123123"
    }
    
    print(f"测试用户: {user_creds['email']}")
    
    # 1. 获取CSRF token
    print("\n1. 获取CSRF token...")
    csrf_response = session.get(f"{base_url}/api/csrf/token", headers=mobile_headers)
    print(f"   Status: {csrf_response.status_code}")
    print(f"   Response: {csrf_response.text[:200]}")
    
    if csrf_response.status_code != 200:
        print("   CSRF token获取失败，无法继续")
        return
    
    # 2. 尝试登录
    print("\n2. 尝试登录...")
    login_response = session.post(
        f"{base_url}/api/secure-auth/login",
        json=user_creds,
        headers=mobile_headers
    )
    
    print(f"   Status: {login_response.status_code}")
    print(f"   Response: {login_response.text[:300]}")
    print(f"   Cookies: {dict(login_response.cookies)}")
    
    # 检查Set-Cookie头
    set_cookie = login_response.headers.get('Set-Cookie', '')
    if set_cookie:
        print(f"   Set-Cookie: {set_cookie}")
    
    if login_response.status_code == 200:
        print("   登录成功！")
        
        # 3. 测试认证
        print("\n3. 测试认证...")
        profile_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
        print(f"   Status: {profile_response.status_code}")
        print(f"   Response: {profile_response.text[:300]}")
        print(f"   Request Cookie: {profile_response.request.headers.get('Cookie', '')}")
        
        if profile_response.status_code == 200:
            print("   认证成功！移动端Cookie工作正常！")
            
            # 4. 测试多次请求
            print("\n4. 测试多次请求...")
            for i in range(3):
                test_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
                print(f"   请求 {i+1}: Status={test_response.status_code}, Cookie={bool(test_response.request.headers.get('Cookie', ''))}")
        else:
            print("   认证失败，Cookie未持久化")
    else:
        print("   登录失败")

if __name__ == "__main__":
    test_user_login()

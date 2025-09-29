"""
测试移动端认证头方案
"""

import requests
import json

def test_mobile_auth_with_headers():
    """测试移动端认证头方案"""
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
    
    print(f"测试移动端认证头方案")
    print(f"用户: {user_creds['email']}")
    
    # 1. 获取CSRF token
    print("\n1. 获取CSRF token...")
    csrf_response = session.get(f"{base_url}/api/csrf/token", headers=mobile_headers)
    print(f"   Status: {csrf_response.status_code}")
    
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
    
    # 检查响应头
    print(f"   响应头:")
    for header, value in login_response.headers.items():
        if header.startswith('X-'):
            print(f"     {header}: {value}")
    
    if login_response.status_code == 200:
        print("   登录成功！")
        
        # 解析响应获取session_id
        try:
            login_data = login_response.json()
            session_id = login_data.get('session_id')
            mobile_auth = login_data.get('mobile_auth', False)
            auth_headers = login_data.get('auth_headers', {})
            
            print(f"   Session ID: {session_id}")
            print(f"   移动端认证: {mobile_auth}")
            print(f"   认证头: {auth_headers}")
            
            # 检查响应头中的移动端标识
            print(f"   响应头中的移动端标识:")
            for header, value in login_response.headers.items():
                if 'mobile' in header.lower() or 'auth' in header.lower():
                    print(f"     {header}: {value}")
            
        except json.JSONDecodeError:
            print("   无法解析登录响应")
            return
        
        # 3. 测试Cookie认证
        print("\n3. 测试Cookie认证...")
        profile_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
        print(f"   Status: {profile_response.status_code}")
        print(f"   Request Cookie: {profile_response.request.headers.get('Cookie', '')}")
        
        if profile_response.status_code == 200:
            print("   Cookie认证成功！")
        else:
            print("   Cookie认证失败，尝试请求头认证...")
            
            # 4. 测试请求头认证
            print("\n4. 测试请求头认证...")
            auth_headers = mobile_headers.copy()
            auth_headers['X-Session-ID'] = session_id
            
            profile_response = session.get(f"{base_url}/api/users/profile/me", headers=auth_headers)
            print(f"   Status: {profile_response.status_code}")
            print(f"   X-Session-ID: {auth_headers.get('X-Session-ID', '')}")
            
            if profile_response.status_code == 200:
                print("   请求头认证成功！")
                
                # 5. 测试多次请求
                print("\n5. 测试多次请求...")
                for i in range(3):
                    test_response = session.get(f"{base_url}/api/users/profile/me", headers=auth_headers)
                    print(f"   请求 {i+1}: Status={test_response.status_code}")
            else:
                print("   请求头认证也失败")
    else:
        print("   登录失败")

if __name__ == "__main__":
    test_mobile_auth_with_headers()

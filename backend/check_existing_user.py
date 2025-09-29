"""
检查现有用户并测试登录
"""

import requests
import json

def check_existing_user():
    """检查现有用户"""
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
    
    # 尝试不同的用户凭据
    test_users = [
        {"email": "zixiong316@gmail.com", "password": "123456"},
        {"email": "zixiong316@gmail.com", "password": "password"},
        {"email": "zixiong316@gmail.com", "password": "123456789"},
        {"email": "admin@example.com", "password": "admin123"},
        {"email": "test@example.com", "password": "test123"},
    ]
    
    for i, user_creds in enumerate(test_users):
        print(f"\n测试用户 {i+1}: {user_creds['email']}")
        
        # 1. 获取CSRF token
        csrf_response = session.get(f"{base_url}/api/csrf/token", headers=mobile_headers)
        print(f"   CSRF Status: {csrf_response.status_code}")
        
        if csrf_response.status_code != 200:
            print(f"   CSRF失败，跳过此用户")
            continue
        
        # 2. 尝试登录
        login_response = session.post(
            f"{base_url}/api/secure-auth/login",
            json=user_creds,
            headers=mobile_headers
        )
        
        print(f"   登录Status: {login_response.status_code}")
        print(f"   登录Response: {login_response.text[:200]}")
        print(f"   Cookies: {dict(login_response.cookies)}")
        
        # 检查Set-Cookie头
        set_cookie = login_response.headers.get('Set-Cookie', '')
        if set_cookie:
            print(f"   Set-Cookie: {set_cookie}")
        
        if login_response.status_code == 200:
            print(f"   ✅ 登录成功！")
            
            # 3. 测试认证
            profile_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
            print(f"   认证Status: {profile_response.status_code}")
            print(f"   Request Cookie: {profile_response.request.headers.get('Cookie', '')}")
            
            if profile_response.status_code == 200:
                print(f"   ✅ 认证成功！移动端Cookie工作正常！")
                return True
            else:
                print(f"   ❌ 认证失败，Cookie未持久化")
        else:
            print(f"   ❌ 登录失败")
        
        # 清除cookies，为下一个用户测试做准备
        session.cookies.clear()
    
    print(f"\n所有用户测试完成，未找到可用的用户凭据")
    return False

if __name__ == "__main__":
    check_existing_user()

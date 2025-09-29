"""
最终移动端测试
确认所有功能正常工作
"""

import requests
import json
import time

def final_mobile_test():
    """最终移动端测试"""
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
    
    print("=" * 60)
    print("最终移动端功能测试")
    print("=" * 60)
    
    # 1. 测试完整登录流程
    print("\n1. 测试登录流程...")
    login_response = session.post(
        f"{base_url}/api/secure-auth/login",
        json=user_creds,
        headers=mobile_headers
    )
    
    print(f"   登录状态: {login_response.status_code}")
    if login_response.status_code == 200:
        print("   登录成功")
        
        # 解析响应
        login_data = login_response.json()
        session_id = login_data.get('session_id')
        print(f"   Session ID: {session_id[:8]}...")
        
        # 检查Cookie
        cookies = dict(session.cookies)
        print(f"   Cookie数量: {len(cookies)}")
        for name, value in cookies.items():
            print(f"     {name}: {value[:8]}...")
    else:
        print("   登录失败")
        return
    
    # 2. 测试认证功能
    print("\n2. 测试认证功能...")
    test_endpoints = [
        "/api/users/profile/me",
        "/api/users/notifications/unread/count",
        "/api/tasks?page=1&page_size=6",
        "/api/users/system-settings/public"
    ]
    
    success_count = 0
    for endpoint in test_endpoints:
        response = session.get(f"{base_url}{endpoint}", headers=mobile_headers)
        status = "成功" if response.status_code == 200 else "失败"
        print(f"   {endpoint}: {status} {response.status_code}")
        if response.status_code == 200:
            success_count += 1
    
    print(f"   认证成功率: {success_count}/{len(test_endpoints)}")
    
    # 3. 测试Cookie持久化
    print("\n3. 测试Cookie持久化...")
    for i in range(5):
        response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
        status = "成功" if response.status_code == 200 else "失败"
        cookie_count = len(response.request.headers.get('Cookie', '').split(';')) if response.request.headers.get('Cookie') else 0
        print(f"   请求 {i+1}: {status} Status={response.status_code}, Cookies={cookie_count}")
        time.sleep(0.5)  # 短暂延迟
    
    # 4. 测试刷新令牌
    print("\n4. 测试刷新令牌...")
    refresh_response = session.post(f"{base_url}/api/secure-auth/refresh", headers=mobile_headers)
    print(f"   刷新状态: {refresh_response.status_code}")
    if refresh_response.status_code == 200:
        print("   刷新成功")
    else:
        print("   刷新失败")
    
    # 5. 测试CSRF保护
    print("\n5. 测试CSRF保护...")
    csrf_response = session.get(f"{base_url}/api/csrf/token", headers=mobile_headers)
    print(f"   CSRF状态: {csrf_response.status_code}")
    if csrf_response.status_code == 200:
        print("   CSRF正常")
    else:
        print("   CSRF失败")
    
    # 6. 测试登出
    print("\n6. 测试登出...")
    logout_response = session.post(f"{base_url}/api/secure-auth/logout", headers=mobile_headers)
    print(f"   登出状态: {logout_response.status_code}")
    if logout_response.status_code == 200:
        print("   登出成功")
        
        # 测试登出后是否还能访问
        test_response = session.get(f"{base_url}/api/users/profile/me", headers=mobile_headers)
        if test_response.status_code == 401:
            print("   登出后正确拒绝访问")
        else:
            print("   登出后仍能访问")
    else:
        print("   登出失败")
    
    print("\n" + "=" * 60)
    print("测试完成！")
    print("=" * 60)

if __name__ == "__main__":
    final_mobile_test()

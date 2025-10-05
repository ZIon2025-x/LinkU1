#!/usr/bin/env python3
"""
使用真实用户凭据测试认证功能
"""

import requests
import json
from datetime import datetime

def test_real_user_auth():
    """使用真实用户凭据测试认证功能"""
    print("👤 使用真实用户凭据测试认证功能")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 真实用户凭据
    test_credentials = {
        "email": "zixiong316@gmail.com",
        "password": "123123"
    }
    
    print(f"🔐 测试用户: {test_credentials['email']}")
    print()
    
    # 1. 测试登录
    print("1️⃣ 测试登录")
    print("-" * 40)
    
    try:
        login_url = f"{base_url}/api/secure-auth/login"
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"登录状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 登录成功")
            
            # 分析登录响应
            try:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            except:
                print("响应数据: 非JSON格式")
            
            # 分析Cookie设置
            cookies = response.cookies
            print(f"\n🍪 登录后Cookie数量: {len(cookies)}")
            
            if len(cookies) == 0:
                print("❌ 没有设置任何Cookie！")
                print("🔍 可能的原因:")
                print("  1. Cookie设置逻辑问题")
                print("  2. SameSite设置问题")
                print("  3. Secure设置问题")
                print("  4. Domain设置问题")
            else:
                print("✅ 成功设置了Cookie！")
                for cookie in cookies:
                    print(f"  {cookie.name}: {cookie.value[:20]}...")
                    print(f"    域: {cookie.domain}")
                    print(f"    路径: {cookie.path}")
                    print(f"    安全: {cookie.secure}")
                    print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                    print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print()
                
                # 2. 测试会话验证
                print("2️⃣ 测试会话验证")
                print("-" * 40)
                
                # 创建会话
                session = requests.Session()
                session.cookies.update(cookies)
                
                # 测试受保护的端点
                protected_url = f"{base_url}/api/secure-auth/status"
                protected_response = session.get(protected_url, timeout=10)
                
                print(f"会话验证状态码: {protected_response.status_code}")
                
                if protected_response.status_code == 200:
                    print("✅ 会话验证成功")
                    data = protected_response.json()
                    print(f"认证状态: {data.get('authenticated', 'N/A')}")
                    print(f"用户ID: {data.get('user_id', 'N/A')}")
                    print(f"消息: {data.get('message', 'N/A')}")
                else:
                    print(f"❌ 会话验证失败: {protected_response.status_code}")
                    print(f"响应: {protected_response.text[:200]}...")
                
                # 3. 测试登出
                print("\n3️⃣ 测试登出")
                print("-" * 40)
                
                # 测试登出
                logout_url = f"{base_url}/api/secure-auth/logout"
                logout_response = session.post(logout_url, timeout=10)
                
                print(f"登出状态码: {logout_response.status_code}")
                
                if logout_response.status_code == 200:
                    print("✅ 登出成功")
                    
                    # 分析登出后的Cookie
                    logout_cookies = logout_response.cookies
                    print(f"登出后Cookie数量: {len(logout_cookies)}")
                    
                    if len(logout_cookies) == 0:
                        print("❌ 登出后没有设置清除Cookie的响应")
                    else:
                        print("✅ 登出后设置了清除Cookie的响应")
                        for cookie in logout_cookies:
                            print(f"  {cookie.name}: {cookie.value[:20]}...")
                            print(f"    域: {cookie.domain}")
                            print(f"    路径: {cookie.path}")
                            print(f"    安全: {cookie.secure}")
                            print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                            print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                            print()
                    
                    # 4. 测试登出后的认证状态
                    print("4️⃣ 测试登出后的认证状态")
                    print("-" * 40)
                    
                    # 使用登出后的会话测试受保护的端点
                    protected_url = f"{base_url}/api/secure-auth/status"
                    protected_response = session.get(protected_url, timeout=10)
                    
                    print(f"登出后认证状态码: {protected_response.status_code}")
                    
                    if protected_response.status_code == 200:
                        data = protected_response.json()
                        print(f"认证状态: {data.get('authenticated', 'N/A')}")
                        print(f"用户ID: {data.get('user_id', 'N/A')}")
                        
                        if data.get('authenticated') == False:
                            print("✅ 登出后认证状态正确（未认证）")
                        else:
                            print("❌ 登出后认证状态异常（仍显示已认证）")
                    else:
                        print("✅ 登出后无法访问受保护端点（符合预期）")
                
                else:
                    print(f"❌ 登出失败: {logout_response.status_code}")
                    print(f"响应: {logout_response.text[:200]}...")
                
        elif response.status_code == 401:
            print("❌ 登录失败: 认证失败")
            print("请检查用户名和密码")
        else:
            print(f"❌ 登录失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")

def test_mobile_auth():
    """测试移动端认证"""
    print("\n📱 测试移动端认证")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 真实用户凭据
    test_credentials = {
        "email": "zixiong316@gmail.com",
        "password": "123123"
    }
    
    # 模拟移动端User-Agent
    mobile_user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1"
    
    print(f"📱 移动端User-Agent: {mobile_user_agent[:50]}...")
    print()
    
    try:
        # 测试移动端登录
        login_url = f"{base_url}/api/secure-auth/login"
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={
                "Content-Type": "application/json",
                "User-Agent": mobile_user_agent
            },
            timeout=10
        )
        
        print(f"移动端登录状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 移动端登录成功")
            
            # 分析移动端Cookie设置
            cookies = response.cookies
            print(f"移动端Cookie数量: {len(cookies)}")
            
            for cookie in cookies:
                print(f"  {cookie.name}: {cookie.value[:20]}...")
                print(f"    域: {cookie.domain}")
                print(f"    路径: {cookie.path}")
                print(f"    安全: {cookie.secure}")
                print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                print()
            
            # 测试移动端会话验证
            session = requests.Session()
            session.cookies.update(cookies)
            
            protected_url = f"{base_url}/api/secure-auth/status"
            protected_response = session.get(
                protected_url,
                headers={"User-Agent": mobile_user_agent},
                timeout=10
            )
            
            print(f"移动端会话验证状态码: {protected_response.status_code}")
            
            if protected_response.status_code == 200:
                print("✅ 移动端会话验证成功")
                data = protected_response.json()
                print(f"认证状态: {data.get('authenticated', 'N/A')}")
                print(f"用户ID: {data.get('user_id', 'N/A')}")
            else:
                print(f"❌ 移动端会话验证失败: {protected_response.status_code}")
        
        else:
            print(f"❌ 移动端登录失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 移动端测试异常: {e}")

def main():
    """主函数"""
    print("🚀 真实用户认证测试")
    print("=" * 60)
    
    # 测试真实用户认证
    test_real_user_auth()
    
    # 测试移动端认证
    test_mobile_auth()
    
    print("\n📋 测试总结:")
    print("真实用户认证测试完成")
    print("请查看上述结果，确认Cookie设置和登出功能")

if __name__ == "__main__":
    main()

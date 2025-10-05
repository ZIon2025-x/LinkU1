#!/usr/bin/env python3
"""
测试隐私模式下的Cookie设置
"""

import requests
import json
from datetime import datetime

def test_private_mode_cookies():
    """测试隐私模式Cookie设置"""
    print("🔒 测试隐私模式Cookie设置")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟隐私模式User-Agent
    private_mode_user_agents = [
        # Chrome Incognito
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0",
        # Firefox Private
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0",
        # Safari Private
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"
    ]
    
    # 测试登录端点
    login_url = f"{base_url}/api/secure-auth/login"
    
    # 注意：需要真实的用户凭据
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    for i, user_agent in enumerate(private_mode_user_agents, 1):
        print(f"📤 测试 {i}: {user_agent[:50]}...")
        
        try:
            # 发送登录请求
            response = requests.post(
                login_url,
                json=test_credentials,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": user_agent
                },
                timeout=10
            )
            
            print(f"📥 响应状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("✅ 登录成功")
                
                # 分析Cookie设置
                cookies = response.cookies
                print(f"🍪 Cookie设置:")
                print("-" * 40)
                
                for cookie in cookies:
                    print(f"名称: {cookie.name}")
                    print(f"值: {cookie.value[:20]}...")
                    print(f"域: {cookie.domain}")
                    print(f"路径: {cookie.path}")
                    print(f"安全: {cookie.secure}")
                    print(f"HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                    print(f"SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print("-" * 40)
                
                # 测试后续请求
                print("🔍 测试后续请求...")
                test_protected_endpoint(cookies, user_agent)
                
            elif response.status_code == 401:
                print("❌ 登录失败: 认证失败")
            else:
                print(f"❌ 登录失败: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 测试失败: {e}")
        
        print()

def test_protected_endpoint(cookies, user_agent):
    """测试受保护的端点"""
    base_url = "https://linku1-production.up.railway.app"
    protected_url = f"{base_url}/api/secure-auth/status"
    
    try:
        response = requests.get(
            protected_url,
            cookies=cookies,
            headers={"User-Agent": user_agent},
            timeout=10
        )
        
        print(f"📥 受保护端点响应: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 受保护端点访问成功")
            data = response.json()
            print(f"认证状态: {data.get('authenticated', 'N/A')}")
        else:
            print(f"❌ 受保护端点访问失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 受保护端点测试失败: {e}")

def analyze_private_mode_issues():
    """分析隐私模式问题"""
    print("\n🔍 隐私模式问题分析")
    print("=" * 60)
    
    print("隐私模式下的Cookie限制:")
    print("1. SameSite=none 可能被阻止")
    print("2. 跨域Cookie可能被限制")
    print("3. Secure Cookie可能被阻止")
    print("4. 第三方Cookie通常被阻止")
    print()
    
    print("解决方案:")
    print("1. 使用 SameSite=lax 提高兼容性")
    print("2. 不设置 domain 属性")
    print("3. 使用较短的过期时间")
    print("4. 提供 X-Session-ID 头作为备用")
    print()
    
    print("修复后的Cookie设置:")
    print("- SameSite: lax (隐私模式兼容)")
    print("- Secure: true (HTTPS环境)")
    print("- Domain: None (避免跨域问题)")
    print("- Path: / (根路径)")
    print("- 较短过期时间 (避免隐私模式限制)")

def main():
    """主函数"""
    print("🚀 隐私模式Cookie测试")
    print("=" * 60)
    
    # 注意：这个测试需要真实的用户凭据
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    # 测试隐私模式Cookie设置
    test_private_mode_cookies()
    
    # 分析隐私模式问题
    analyze_private_mode_issues()
    
    print("\n📋 总结:")
    print("隐私模式下的Cookie问题主要是浏览器安全限制导致的。")
    print("通过优化Cookie设置（使用lax、不设置domain等），")
    print("可以提高隐私模式下的兼容性。")
    print("同时，X-Session-ID头作为备用认证方式也很重要。")

if __name__ == "__main__":
    main()

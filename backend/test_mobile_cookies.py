#!/usr/bin/env python3
"""
测试移动端Cookie设置
"""

import requests
import json
from datetime import datetime

def test_mobile_cookies():
    """测试移动端Cookie设置"""
    print("📱 测试移动端Cookie设置")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 测试移动端登录
    print("1️⃣ 测试移动端登录")
    print("-" * 40)
    
    # 移动端用户凭据
    mobile_credentials = {
        "email": "zixiong316@gmail.com",
        "password": "123123"
    }
    
    try:
        # 模拟移动端登录
        login_url = f"{base_url}/api/secure-auth/login"
        
        # 移动端User-Agent
        mobile_headers = {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1"
        }
        
        response = requests.post(
            login_url,
            json=mobile_credentials,
            headers=mobile_headers,
            timeout=10
        )
        
        print(f"移动端登录状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 移动端登录成功")
            
            # 分析响应
            data = response.json()
            print(f"会话ID: {data.get('session_id', 'N/A')}")
            print(f"用户ID: {data.get('user_id', 'N/A')}")
            
            # 检查Cookie设置
            print("\n🍪 检查Cookie设置:")
            cookies = response.cookies
            if cookies:
                print("✅ 服务器设置了Cookie")
                for cookie in cookies:
                    print(f"  Cookie: {cookie.name}={cookie.value[:20]}...")
                    print(f"  Domain: {cookie.domain}")
                    print(f"  Path: {cookie.path}")
                    print(f"  Secure: {cookie.secure}")
                    print(f"  SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print(f"  HttpOnly: {getattr(cookie, 'httponly', 'N/A')}")
                    print()
            else:
                print("❌ 服务器没有设置Cookie")
            
            # 测试会话验证
            print("\n🔍 测试会话验证:")
            session = requests.Session()
            session.cookies.update(response.cookies)
            
            # 使用移动端User-Agent
            session.headers.update(mobile_headers)
            
            # 测试受保护的端点
            protected_url = f"{base_url}/api/secure-auth/status"
            protected_response = session.get(protected_url, timeout=10)
            
            print(f"会话验证状态码: {protected_response.status_code}")
            
            if protected_response.status_code == 200:
                print("✅ 移动端会话验证成功")
                try:
                    data = protected_response.json()
                    print(f"认证状态: {data.get('authenticated', 'N/A')}")
                    print(f"用户ID: {data.get('user_id', 'N/A')}")
                except:
                    print(f"响应: {protected_response.text[:200]}...")
            else:
                print(f"❌ 移动端会话验证失败: {protected_response.status_code}")
                print(f"响应: {protected_response.text[:200]}...")
                
        else:
            print(f"❌ 移动端登录失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 移动端测试异常: {e}")
    
    print()
    
    # 2. 测试桌面端登录对比
    print("2️⃣ 测试桌面端登录对比")
    print("-" * 40)
    
    try:
        # 模拟桌面端登录
        desktop_headers = {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
        }
        
        response = requests.post(
            login_url,
            json=mobile_credentials,
            headers=desktop_headers,
            timeout=10
        )
        
        print(f"桌面端登录状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 桌面端登录成功")
            
            # 检查Cookie设置
            print("\n🍪 检查桌面端Cookie设置:")
            cookies = response.cookies
            if cookies:
                print("✅ 服务器设置了Cookie")
                for cookie in cookies:
                    print(f"  Cookie: {cookie.name}={cookie.value[:20]}...")
                    print(f"  Domain: {cookie.domain}")
                    print(f"  Path: {cookie.path}")
                    print(f"  Secure: {cookie.secure}")
                    print(f"  SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print(f"  HttpOnly: {getattr(cookie, 'httponly', 'N/A')}")
                    print()
            else:
                print("❌ 服务器没有设置Cookie")
                
        else:
            print(f"❌ 桌面端登录失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 桌面端测试异常: {e}")

def analyze_mobile_cookie_issues():
    """分析移动端Cookie问题"""
    print("\n📊 分析移动端Cookie问题")
    print("=" * 60)
    
    print("🔍 可能的问题:")
    print("  1. 移动端浏览器Cookie限制")
    print("  2. 跨域Cookie设置问题")
    print("  3. SameSite设置不兼容")
    print("  4. Secure设置问题")
    print("  5. 域名设置问题")
    print()
    
    print("🔧 修复建议:")
    print("  1. 检查移动端Cookie设置")
    print("  2. 优化SameSite设置")
    print("  3. 检查Secure设置")
    print("  4. 测试不同移动浏览器")
    print("  5. 考虑使用Authorization头作为备选")
    print()
    
    print("🔍 移动端Cookie最佳实践:")
    print("  1. 使用SameSite=lax或none")
    print("  2. 确保Secure=true（HTTPS）")
    print("  3. 设置正确的域名")
    print("  4. 使用HttpOnly=true")
    print("  5. 设置合理的过期时间")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 移动端浏览器对Cookie限制更严格")
    print("  2. 某些移动浏览器可能完全阻止Cookie")
    print("  3. 需要测试多种移动浏览器")
    print("  4. 考虑使用其他认证方式")

def main():
    """主函数"""
    print("🚀 移动端Cookie测试")
    print("=" * 60)
    
    # 测试移动端Cookie设置
    test_mobile_cookies()
    
    # 分析移动端Cookie问题
    analyze_mobile_cookie_issues()
    
    print("\n📋 测试总结:")
    print("移动端Cookie测试完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()
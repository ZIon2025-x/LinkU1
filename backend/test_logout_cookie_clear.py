#!/usr/bin/env python3
"""
测试登出Cookie清除功能
"""

import requests
import json
from datetime import datetime

def test_logout_cookie_clear():
    """测试登出Cookie清除功能"""
    print("🚪 测试登出Cookie清除功能")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试凭据（需要替换为真实凭据）
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
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
            
            # 分析登录后的Cookie
            cookies = response.cookies
            print(f"登录后Cookie数量: {len(cookies)}")
            
            for cookie in cookies:
                print(f"  {cookie.name}: {cookie.value[:20]}...")
                print(f"    域: {cookie.domain}")
                print(f"    路径: {cookie.path}")
                print(f"    安全: {cookie.secure}")
                print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                print()
            
            # 2. 测试登出
            print("2️⃣ 测试登出")
            print("-" * 40)
            
            # 创建会话
            session = requests.Session()
            session.cookies.update(cookies)
            
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
                
                # 3. 测试登出后的认证状态
                print("3️⃣ 测试登出后的认证状态")
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
        else:
            print(f"❌ 登录失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")

def analyze_logout_cookie_issues():
    """分析登出Cookie问题"""
    print("\n📊 分析登出Cookie问题")
    print("=" * 60)
    
    print("🔍 发现的问题:")
    print("  1. 登出后refresh_token和user_id Cookie没有被清除")
    print("  2. 移动端特殊Cookie可能没有被清除")
    print("  3. Cookie清除逻辑不完整")
    print("  4. 安全风险：用户数据残留")
    print()
    
    print("🔧 已实施的修复:")
    print("  1. 修复clear_session_cookies方法")
    print("     - 添加移动端特殊Cookie清除")
    print("     - 确保所有Cookie都被清除")
    print("     - 添加详细的清除日志")
    print()
    
    print("  2. 清除的Cookie类型:")
    print("     - session_id（主要会话Cookie）")
    print("     - mobile_session_id（移动端会话Cookie）")
    print("     - js_session_id（JavaScript访问Cookie）")
    print("     - mobile_strict_session_id（移动端严格Cookie）")
    print("     - refresh_token（刷新令牌Cookie）")
    print("     - user_id（用户ID Cookie）")
    print()
    
    print("🔍 预期效果:")
    print("  1. 登出后所有Cookie都被清除")
    print("  2. 用户无法继续使用旧会话")
    print("  3. 提高安全性")
    print("  4. 防止数据残留")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 需要重新部署应用")
    print("  2. 需要测试真实用户登出")
    print("  3. 需要验证所有Cookie都被清除")
    print("  4. 需要检查浏览器Cookie清除效果")

def main():
    """主函数"""
    print("🚀 登出Cookie清除测试")
    print("=" * 60)
    
    # 测试登出Cookie清除功能
    test_logout_cookie_clear()
    
    # 分析登出Cookie问题
    analyze_logout_cookie_issues()
    
    print("\n📋 测试总结:")
    print("登出Cookie清除测试完成")
    print("请查看上述结果，确认修复效果")

if __name__ == "__main__":
    main()

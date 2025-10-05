#!/usr/bin/env python3
"""
诊断电脑端Cookie问题
"""

import requests
import json
from datetime import datetime

def diagnose_desktop_cookie_issue():
    """诊断电脑端Cookie问题"""
    print("🖥️ 诊断电脑端Cookie问题")
    print("=" * 60)
    print(f"诊断时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟电脑端User-Agent
    desktop_user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0"
    ]
    
    # 测试凭据（需要替换为真实凭据）
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    for i, user_agent in enumerate(desktop_user_agents, 1):
        print(f"🖥️ 测试电脑端 {i}: {user_agent[:50]}...")
        print("-" * 40)
        
        # 1. 测试登录
        print("🔐 测试电脑端登录")
        try:
            login_url = f"{base_url}/api/secure-auth/login"
            response = requests.post(
                login_url,
                json=test_credentials,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": user_agent
                },
                timeout=10
            )
            
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("  ✅ 电脑端登录成功")
                
                # 分析Cookie设置
                cookies = response.cookies
                print(f"  🍪 Cookie数量: {len(cookies)}")
                
                if len(cookies) == 0:
                    print("  ❌ 没有设置任何Cookie！")
                else:
                    for cookie in cookies:
                        print(f"    {cookie.name}: {cookie.value[:20]}...")
                        print(f"      域: {cookie.domain}")
                        print(f"      路径: {cookie.path}")
                        print(f"      安全: {cookie.secure}")
                        print(f"      HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                        print(f"      SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                        print()
                
                # 2. 测试会话验证
                print("🔍 测试电脑端会话验证")
                session = requests.Session()
                session.cookies.update(cookies)
                
                # 测试受保护的端点
                protected_url = f"{base_url}/api/secure-auth/status"
                protected_response = session.get(
                    protected_url,
                    headers={"User-Agent": user_agent},
                    timeout=10
                )
                
                print(f"  状态码: {protected_response.status_code}")
                
                if protected_response.status_code == 200:
                    print("  ✅ 电脑端会话验证成功")
                    data = protected_response.json()
                    print(f"  认证状态: {data.get('authenticated', 'N/A')}")
                    print(f"  用户ID: {data.get('user_id', 'N/A')}")
                else:
                    print(f"  ❌ 电脑端会话验证失败: {protected_response.status_code}")
                    print(f"  响应: {protected_response.text[:200]}...")
                
            elif response.status_code == 401:
                print("  ❌ 电脑端登录失败: 认证失败")
            else:
                print(f"  ❌ 电脑端登录失败: {response.status_code}")
                print(f"  响应: {response.text[:200]}...")
                
        except Exception as e:
            print(f"  ❌ 电脑端测试异常: {e}")
        
        print()

def analyze_desktop_cookie_issues():
    """分析电脑端Cookie问题"""
    print("📊 分析电脑端Cookie问题")
    print("=" * 60)
    
    print("🔍 可能的问题:")
    print("  1. Cookie设置逻辑问题")
    print("  2. SameSite设置问题")
    print("  3. Secure设置问题")
    print("  4. Domain设置问题")
    print("  5. Path设置问题")
    print()
    
    print("🔍 检查Cookie设置逻辑:")
    print("  1. 检查CookieManager.set_session_cookies方法")
    print("  2. 检查桌面端Cookie设置逻辑")
    print("  3. 检查SameSite值计算")
    print("  4. 检查Secure值计算")
    print("  5. 检查Domain和Path设置")
    print()
    
    print("🔍 可能的原因:")
    print("  1. 桌面端Cookie设置被跳过")
    print("  2. SameSite设置导致Cookie被阻止")
    print("  3. Secure设置导致Cookie被阻止")
    print("  4. Domain设置导致Cookie无法设置")
    print("  5. Path设置导致Cookie无法访问")
    print()
    
    print("🔧 修复建议:")
    print("  1. 检查Cookie设置逻辑")
    print("  2. 优化SameSite设置")
    print("  3. 优化Secure设置")
    print("  4. 优化Domain和Path设置")
    print("  5. 添加Cookie设置调试信息")

def check_cookie_manager_logic():
    """检查Cookie管理逻辑"""
    print("\n🔧 检查Cookie管理逻辑")
    print("=" * 60)
    
    print("📝 检查cookie_manager.py:")
    print("  1. 检查set_session_cookies方法")
    print("  2. 检查桌面端Cookie设置逻辑")
    print("  3. 检查SameSite值计算")
    print("  4. 检查Secure值计算")
    print("  5. 检查Domain和Path设置")
    print()
    
    print("📝 检查secure_auth_routes.py:")
    print("  1. 检查登录成功后的Cookie设置")
    print("  2. 检查CookieManager.set_session_cookies调用")
    print("  3. 检查响应对象传递")
    print("  4. 检查User-Agent传递")
    print()
    
    print("📝 检查deps.py:")
    print("  1. 检查Cookie认证逻辑")
    print("  2. 检查Cookie读取逻辑")
    print("  3. 检查认证依赖")
    print("  4. 检查调试信息")
    print()

def main():
    """主函数"""
    print("🚀 电脑端Cookie问题诊断")
    print("=" * 60)
    
    # 诊断电脑端Cookie问题
    diagnose_desktop_cookie_issue()
    
    # 分析电脑端Cookie问题
    analyze_desktop_cookie_issues()
    
    # 检查Cookie管理逻辑
    check_cookie_manager_logic()
    
    print("\n📋 诊断总结:")
    print("电脑端Cookie问题诊断完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()

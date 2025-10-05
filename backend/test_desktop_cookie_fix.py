#!/usr/bin/env python3
"""
测试桌面端Cookie修复效果
"""

import requests
import json
from datetime import datetime

def test_desktop_cookie_fix():
    """测试桌面端Cookie修复效果"""
    print("🖥️ 测试桌面端Cookie修复效果")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟桌面端User-Agent
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
        print(f"🖥️ 测试桌面端 {i}: {user_agent[:50]}...")
        print("-" * 40)
        
        # 1. 测试登录
        print("🔐 测试桌面端登录")
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
                print("  ✅ 桌面端登录成功")
                
                # 分析Cookie设置
                cookies = response.cookies
                print(f"  🍪 Cookie数量: {len(cookies)}")
                
                if len(cookies) == 0:
                    print("  ❌ 没有设置任何Cookie！")
                    print("  🔍 可能的原因:")
                    print("    1. Cookie设置逻辑问题")
                    print("    2. SameSite设置问题")
                    print("    3. Secure设置问题")
                    print("    4. Domain设置问题")
                    print("    5. Path设置问题")
                else:
                    print("  ✅ 成功设置了Cookie！")
                    for cookie in cookies:
                        print(f"    {cookie.name}: {cookie.value[:20]}...")
                        print(f"      域: {cookie.domain}")
                        print(f"      路径: {cookie.path}")
                        print(f"      安全: {cookie.secure}")
                        print(f"      HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                        print(f"      SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                        print()
                
                # 2. 测试会话验证
                print("🔍 测试桌面端会话验证")
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
                    print("  ✅ 桌面端会话验证成功")
                    data = protected_response.json()
                    print(f"  认证状态: {data.get('authenticated', 'N/A')}")
                    print(f"  用户ID: {data.get('user_id', 'N/A')}")
                else:
                    print(f"  ❌ 桌面端会话验证失败: {protected_response.status_code}")
                    print(f"  响应: {protected_response.text[:200]}...")
                
            elif response.status_code == 401:
                print("  ❌ 桌面端登录失败: 认证失败")
            else:
                print(f"  ❌ 桌面端登录失败: {response.status_code}")
                print(f"  响应: {response.text[:200]}...")
                
        except Exception as e:
            print(f"  ❌ 桌面端测试异常: {e}")
        
        print()

def analyze_desktop_cookie_fix():
    """分析桌面端Cookie修复"""
    print("📊 分析桌面端Cookie修复")
    print("=" * 60)
    
    print("🔧 已实施的修复:")
    print("  1. 修复桌面端Cookie设置逻辑")
    print("     - 添加桌面端SameSite值计算")
    print("     - 添加桌面端Secure值计算")
    print("     - 添加桌面端Cookie设置日志")
    print()
    
    print("  2. 修复配置文件")
    print("     - 修复移动端Secure配置")
    print("     - 确保Cookie配置正确")
    print("     - 优化Cookie兼容性")
    print()
    
    print("  3. 添加调试信息")
    print("     - 添加桌面端Cookie设置日志")
    print("     - 添加Cookie参数记录")
    print("     - 添加调试信息")
    print()
    
    print("🔍 预期效果:")
    print("  1. 桌面端Cookie设置成功")
    print("  2. 桌面端会话验证正常")
    print("  3. 桌面端认证流程稳定")
    print("  4. 桌面端调试信息详细")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 需要重新部署应用")
    print("  2. 需要测试真实用户登录")
    print("  3. 需要监控Cookie设置成功率")
    print("  4. 需要检查浏览器Cookie设置")

def main():
    """主函数"""
    print("🚀 桌面端Cookie修复测试")
    print("=" * 60)
    
    # 测试桌面端Cookie修复效果
    test_desktop_cookie_fix()
    
    # 分析桌面端Cookie修复
    analyze_desktop_cookie_fix()
    
    print("\n📋 测试总结:")
    print("桌面端Cookie修复测试完成")
    print("请查看上述结果，确认修复效果")

if __name__ == "__main__":
    main()

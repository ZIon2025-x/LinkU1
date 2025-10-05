#!/usr/bin/env python3
"""
测试移动端Cookie修复效果
"""

import requests
import json
from datetime import datetime

def test_mobile_cookie_settings():
    """测试移动端Cookie设置"""
    print("📱 测试移动端Cookie设置")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟移动端User-Agent
    mobile_user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1"
    
    # 测试登录端点
    login_url = f"{base_url}/api/secure-auth/login"
    
    # 注意：需要真实的用户凭据
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print(f"📤 测试移动端登录")
    print(f"User-Agent: {mobile_user_agent}")
    print(f"登录URL: {login_url}")
    print()
    
    try:
        # 发送移动端登录请求
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={
                "Content-Type": "application/json",
                "User-Agent": mobile_user_agent
            },
            timeout=10
        )
        
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 移动端登录成功")
            
            # 分析Cookie设置
            cookies = response.cookies
            print(f"\n🍪 移动端Cookie设置:")
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
            
            # 检查Cookie一致性
            session_cookies = [c for c in cookies if 'session' in c.name.lower()]
            if len(session_cookies) > 1:
                print("🔍 Cookie一致性检查:")
                secure_values = [c.secure for c in session_cookies]
                samesite_values = [getattr(c, 'samesite', None) for c in session_cookies]
                
                if len(set(secure_values)) == 1:
                    print("✅ Secure属性一致")
                else:
                    print("❌ Secure属性不一致")
                    print(f"  值: {secure_values}")
                
                if len(set(samesite_values)) == 1:
                    print("✅ SameSite属性一致")
                else:
                    print("❌ SameSite属性不一致")
                    print(f"  值: {samesite_values}")
            
            return True, cookies
            
        elif response.status_code == 401:
            print("❌ 移动端登录失败: 认证失败")
            print(f"响应: {response.text}")
            return False, None
        else:
            print(f"❌ 移动端登录失败: {response.status_code}")
            print(f"响应: {response.text}")
            return False, None
            
    except Exception as e:
        print(f"❌ 移动端登录测试失败: {e}")
        return False, None

def test_mobile_session_validation(cookies):
    """测试移动端会话验证"""
    print("\n🔍 测试移动端会话验证")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    mobile_user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1"
    
    # 测试需要认证的端点
    protected_url = f"{base_url}/api/secure-auth/status"
    
    try:
        # 发送带Cookie的移动端请求
        response = requests.get(
            protected_url,
            cookies=cookies,
            headers={"User-Agent": mobile_user_agent},
            timeout=10
        )
        
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 移动端会话验证成功")
            
            # 解析响应
            data = response.json()
            print(f"📊 认证状态:")
            print(f"  认证状态: {data.get('authenticated', 'N/A')}")
            print(f"  用户ID: {data.get('user_id', 'N/A')}")
            print(f"  消息: {data.get('message', 'N/A')}")
            
            return True
        else:
            print(f"❌ 移动端会话验证失败: {response.status_code}")
            print(f"响应: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 移动端会话验证测试失败: {e}")
        return False

def compare_desktop_vs_mobile():
    """对比桌面端和移动端"""
    print("\n🖥️ 对比桌面端和移动端")
    print("=" * 60)
    
    print("桌面端（Windows Chrome）:")
    print("  ✅ 正确发送Cookie")
    print("  ✅ Redis中有会话数据")
    print("  ✅ 会话验证成功")
    print("  ✅ 使用Redis认证")
    print()
    
    print("移动端（iPhone Safari）:")
    print("  ❌ Cookie可能没有正确发送")
    print("  ❌ Redis中没有会话数据")
    print("  ❌ 会话验证失败")
    print("  ❌ 回退到JWT认证")
    print()
    
    print("💡 修复后的移动端Cookie设置:")
    print("  - SameSite: none (支持跨域)")
    print("  - Secure: true (HTTPS环境)")
    print("  - 所有Cookie属性保持一致")
    print("  - 避免属性冲突")

def main():
    """主函数"""
    print("🚀 移动端Cookie修复测试")
    print("=" * 60)
    
    # 注意：这个测试需要真实的用户凭据
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    # 测试移动端Cookie设置
    login_success, cookies = test_mobile_cookie_settings()
    
    if login_success and cookies:
        # 测试移动端会话验证
        session_valid = test_mobile_session_validation(cookies)
        
        # 对比桌面端和移动端
        compare_desktop_vs_mobile()
        
        # 总结
        print("\n📊 测试结果总结")
        print("=" * 60)
        print(f"移动端登录: {'✅' if login_success else '❌'}")
        print(f"移动端会话验证: {'✅' if session_valid else '❌'}")
        
        if all([login_success, session_valid]):
            print("\n🎉 移动端Cookie修复成功！")
            print("💡 移动端现在应该能够正常使用Redis会话认证")
        else:
            print("\n⚠️ 移动端Cookie仍有问题，需要进一步调试")
    else:
        print("\n❌ 移动端登录失败，无法继续测试")
        print("💡 请检查:")
        print("  1. 用户凭据是否正确")
        print("  2. 移动端Cookie设置是否生效")
        print("  3. 服务器是否已部署最新代码")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
测试移动端认证修复效果
"""

import requests
import json
from datetime import datetime

def test_mobile_auth_fix():
    """测试移动端认证修复效果"""
    print("📱 测试移动端认证修复效果")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 模拟移动端User-Agent
    mobile_user_agents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
        "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1"
    ]
    
    # 测试凭据（需要替换为真实凭据）
    test_credentials = {
        "email": "test@example.com",  # 需要替换为真实邮箱
        "password": "testpassword"    # 需要替换为真实密码
    }
    
    print("⚠️  注意：此测试需要真实的用户凭据")
    print("   请确保在test_credentials中设置正确的邮箱和密码")
    print()
    
    for i, user_agent in enumerate(mobile_user_agents, 1):
        print(f"📱 测试移动端 {i}: {user_agent[:50]}...")
        print("-" * 40)
        
        # 1. 测试登录
        print("🔐 测试移动端登录")
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
                print("  ✅ 移动端登录成功")
                
                # 分析Cookie设置
                cookies = response.cookies
                print(f"  🍪 Cookie数量: {len(cookies)}")
                
                for cookie in cookies:
                    print(f"    {cookie.name}: {cookie.value[:20]}...")
                    print(f"      域: {cookie.domain}")
                    print(f"      路径: {cookie.path}")
                    print(f"      安全: {cookie.secure}")
                    print(f"      HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                    print(f"      SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print()
                
                # 2. 测试会话验证
                print("🔍 测试移动端会话验证")
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
                    print("  ✅ 移动端会话验证成功")
                    data = protected_response.json()
                    print(f"  认证状态: {data.get('authenticated', 'N/A')}")
                    print(f"  用户ID: {data.get('user_id', 'N/A')}")
                else:
                    print(f"  ❌ 移动端会话验证失败: {protected_response.status_code}")
                    print(f"  响应: {protected_response.text[:200]}...")
                
                # 3. 测试移动端特殊认证
                print("📱 测试移动端特殊认证")
                
                # 测试X-Session-ID头
                if 'session_id' in [cookie.name for cookie in cookies]:
                    session_id = next(cookie.value for cookie in cookies if cookie.name == 'session_id')
                    print(f"  使用X-Session-ID头: {session_id[:20]}...")
                    
                    # 测试带X-Session-ID头的请求
                    headers = {
                        "User-Agent": user_agent,
                        "X-Session-ID": session_id
                    }
                    
                    test_response = requests.get(
                        f"{base_url}/api/secure-auth/status",
                        headers=headers,
                        timeout=10
                    )
                    
                    print(f"  X-Session-ID头测试状态码: {test_response.status_code}")
                    
                    if test_response.status_code == 200:
                        print("  ✅ X-Session-ID头认证成功")
                    else:
                        print("  ❌ X-Session-ID头认证失败")
                
            elif response.status_code == 401:
                print("  ❌ 移动端登录失败: 认证失败")
            else:
                print(f"  ❌ 移动端登录失败: {response.status_code}")
                print(f"  响应: {response.text[:200]}...")
                
        except Exception as e:
            print(f"  ❌ 移动端测试异常: {e}")
        
        print()

def analyze_mobile_auth_improvements():
    """分析移动端认证改进"""
    print("📊 分析移动端认证改进")
    print("=" * 60)
    
    print("🔧 已实施的修复:")
    print("  1. 优化移动端Cookie设置")
    print("     - 使用SameSite=lax提高兼容性")
    print("     - 添加多种Cookie备用方案")
    print("     - 实现移动端特殊Cookie策略")
    print()
    
    print("  2. 改进移动端会话管理")
    print("     - 支持多种Cookie名称")
    print("     - 添加X-Session-ID头支持")
    print("     - 实现移动端会话验证")
    print()
    
    print("  3. 优化移动端认证逻辑")
    print("     - 增强移动端检测")
    print("     - 改进移动端认证流程")
    print("     - 添加移动端调试信息")
    print()
    
    print("🔍 预期效果:")
    print("  1. 移动端Cookie设置成功率提高")
    print("  2. 移动端会话管理更稳定")
    print("  3. 移动端认证流程更可靠")
    print("  4. 移动端调试信息更详细")
    print()
    
    print("⚠️  安全考虑:")
    print("  1. 移动端仍依赖JWT token作为备用")
    print("  2. 需要监控移动端认证成功率")
    print("  3. 考虑实现移动端专用安全策略")
    print("  4. 定期检查移动端Cookie兼容性")

def main():
    """主函数"""
    print("🚀 移动端认证修复测试")
    print("=" * 60)
    
    # 测试移动端认证修复效果
    test_mobile_auth_fix()
    
    # 分析移动端认证改进
    analyze_mobile_auth_improvements()
    
    print("\n📋 测试总结:")
    print("移动端认证修复测试完成")
    print("请查看上述结果，确认修复效果")

if __name__ == "__main__":
    main()

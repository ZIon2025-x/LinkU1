#!/usr/bin/env python3
"""
测试移动端Cookie修复
"""

import requests
import json
from datetime import datetime

def test_mobile_cookie_fix():
    """测试移动端Cookie修复"""
    print("📱 测试移动端Cookie修复")
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
            print("\n🍪 检查移动端Cookie设置:")
            cookies = response.cookies
            if cookies:
                print("✅ 服务器设置了Cookie")
                for cookie in cookies:
                    print(f"  Cookie: {cookie.name}")
                    print(f"  Value: {cookie.value[:20]}...")
                    print(f"  Domain: {cookie.domain}")
                    print(f"  Path: {cookie.path}")
                    print(f"  Secure: {cookie.secure}")
                    print(f"  SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                    print(f"  HttpOnly: {getattr(cookie, 'httponly', 'N/A')}")
                    print()
                    
                # 检查SameSite设置
                samesite_values = [getattr(cookie, 'samesite', 'N/A') for cookie in cookies]
                print(f"SameSite设置: {samesite_values}")
                
                if 'none' in samesite_values:
                    print("✅ 检测到SameSite=none，适合跨域请求")
                else:
                    print("❌ 没有检测到SameSite=none，可能影响跨域Cookie")
            else:
                print("❌ 服务器没有设置Cookie")
            
            # 测试会话验证
            print("\n🔍 测试移动端会话验证:")
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
    
    # 2. 测试跨域Cookie设置
    print("2️⃣ 测试跨域Cookie设置")
    print("-" * 40)
    
    try:
        # 模拟跨域请求
        cors_headers = {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1",
            "Origin": "https://link-u1.vercel.app",
            "Referer": "https://link-u1.vercel.app/"
        }
        
        # 测试CORS预检请求
        options_response = requests.options(
            f"{base_url}/api/secure-auth/status",
            headers=cors_headers,
            timeout=10
        )
        
        print(f"CORS预检请求状态码: {options_response.status_code}")
        
        if options_response.status_code == 200:
            print("✅ CORS预检请求成功")
            
            # 检查CORS头
            cors_headers_response = options_response.headers
            print(f"CORS头设置:")
            print(f"  Access-Control-Allow-Origin: {cors_headers_response.get('Access-Control-Allow-Origin', 'N/A')}")
            print(f"  Access-Control-Allow-Credentials: {cors_headers_response.get('Access-Control-Allow-Credentials', 'N/A')}")
            print(f"  Access-Control-Allow-Methods: {cors_headers_response.get('Access-Control-Allow-Methods', 'N/A')}")
            print(f"  Access-Control-Allow-Headers: {cors_headers_response.get('Access-Control-Allow-Headers', 'N/A')}")
        else:
            print(f"❌ CORS预检请求失败: {options_response.status_code}")
            
    except Exception as e:
        print(f"❌ CORS测试异常: {e}")

def analyze_mobile_cookie_fix():
    """分析移动端Cookie修复效果"""
    print("\n📊 分析移动端Cookie修复效果")
    print("=" * 60)
    
    print("🔧 修复内容:")
    print("  1. 移动端Cookie使用SameSite=none")
    print("  2. 确保Secure=true（HTTPS环境）")
    print("  3. 统一移动端Cookie设置")
    print("  4. 支持跨域Cookie")
    print()
    
    print("🔍 修复效果:")
    print("  1. 移动端Cookie应该能够跨域工作")
    print("  2. 移动端会话验证应该成功")
    print("  3. 减少对Authorization头的依赖")
    print("  4. 提高移动端安全性")
    print()
    
    print("⚠️  注意事项:")
    print("  1. SameSite=none需要Secure=true")
    print("  2. 需要HTTPS环境")
    print("  3. 某些移动浏览器可能仍有限制")
    print("  4. 需要测试多种移动浏览器")
    print()
    
    print("🔍 验证步骤:")
    print("  1. 重新部署应用")
    print("  2. 测试移动端登录")
    print("  3. 检查Cookie设置")
    print("  4. 测试会话验证")
    print("  5. 测试跨域请求")

def main():
    """主函数"""
    print("🚀 移动端Cookie修复测试")
    print("=" * 60)
    
    # 测试移动端Cookie修复
    test_mobile_cookie_fix()
    
    # 分析移动端Cookie修复效果
    analyze_mobile_cookie_fix()
    
    print("\n📋 测试总结:")
    print("移动端Cookie修复测试完成")
    print("请重新部署应用并测试移动端Cookie功能")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
全面测试认证功能
"""

import requests
import json
from datetime import datetime
import time

def test_login_authentication():
    """测试登录认证流程"""
    print("🔐 测试登录认证流程")
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
    
    # 1. 测试登录端点
    print("1️⃣ 测试登录端点")
    print("-" * 40)
    
    try:
        login_url = f"{base_url}/api/secure-auth/login"
        response = requests.post(
            login_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"📥 登录响应状态码: {response.status_code}")
        print(f"📥 响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ 登录成功")
            
            # 分析响应数据
            try:
                data = response.json()
                print(f"📊 响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            except:
                print("📊 响应数据: 非JSON格式")
            
            # 分析Cookie设置
            cookies = response.cookies
            print(f"🍪 设置的Cookie数量: {len(cookies)}")
            
            for cookie in cookies:
                print(f"  Cookie: {cookie.name}")
                print(f"    值: {cookie.value[:20]}...")
                print(f"    域: {cookie.domain}")
                print(f"    路径: {cookie.path}")
                print(f"    安全: {cookie.secure}")
                print(f"    HttpOnly: {cookie.has_nonstandard_attr('HttpOnly')}")
                print(f"    SameSite: {getattr(cookie, 'samesite', 'N/A')}")
                print()
            
            return cookies, response.json() if response.content else {}
            
        elif response.status_code == 401:
            print("❌ 登录失败: 认证失败")
            print("请检查用户名和密码")
            return None, None
        else:
            print(f"❌ 登录失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            return None, None
            
    except Exception as e:
        print(f"❌ 登录测试异常: {e}")
        return None, None

def test_session_management(cookies):
    """测试会话管理功能"""
    print("\n2️⃣ 测试会话管理功能")
    print("-" * 40)
    
    if not cookies:
        print("❌ 没有有效的Cookie，跳过会话测试")
        return False
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 创建会话
    session = requests.Session()
    session.cookies.update(cookies)
    
    # 测试受保护的端点
    protected_endpoints = [
        "/api/secure-auth/status",
        "/api/secure-auth/redis-status",
        "/api/notifications/with-recent-read?recent_read_limit=10"
    ]
    
    success_count = 0
    
    for endpoint in protected_endpoints:
        print(f"🔍 测试端点: {endpoint}")
        
        try:
            response = session.get(f"{base_url}{endpoint}", timeout=10)
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("  ✅ 访问成功")
                success_count += 1
                
                # 分析响应数据
                try:
                    data = response.json()
                    print(f"  响应数据: {json.dumps(data, indent=2, ensure_ascii=False)[:200]}...")
                except:
                    print("  响应数据: 非JSON格式")
            else:
                print(f"  ❌ 访问失败: {response.status_code}")
                print(f"  错误信息: {response.text[:200]}...")
                
        except Exception as e:
            print(f"  ❌ 测试异常: {e}")
    
    print(f"\n📊 会话测试结果: {success_count}/{len(protected_endpoints)} 成功")
    return success_count == len(protected_endpoints)

def test_cookie_validation(cookies):
    """测试Cookie验证"""
    print("\n3️⃣ 测试Cookie验证")
    print("-" * 40)
    
    if not cookies:
        print("❌ 没有有效的Cookie，跳过Cookie测试")
        return False
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试不同的Cookie组合
    cookie_tests = [
        {"name": "完整Cookie", "cookies": cookies},
        {"name": "仅session_id", "cookies": {k: v for k, v in cookies.items() if 'session_id' in k}},
        {"name": "仅mobile_session_id", "cookies": {k: v for k, v in cookies.items() if 'mobile_session_id' in k}},
        {"name": "仅js_session_id", "cookies": {k: v for k, v in cookies.items() if 'js_session_id' in k}}
    ]
    
    for test in cookie_tests:
        print(f"🔍 测试: {test['name']}")
        
        session = requests.Session()
        session.cookies.update(test['cookies'])
        
        try:
            response = session.get(f"{base_url}/api/secure-auth/status", timeout=10)
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("  ✅ Cookie验证成功")
            else:
                print(f"  ❌ Cookie验证失败: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ Cookie测试异常: {e}")

def test_jwt_authentication():
    """测试JWT认证"""
    print("\n4️⃣ 测试JWT认证")
    print("-" * 40)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试JWT token认证（需要有效的token）
    print("🔍 测试JWT token认证")
    print("  注意：需要有效的JWT token")
    print("  可以通过登录获取token")
    
    # 这里需要实际的JWT token
    # 在实际测试中，应该从登录响应中获取token
    print("  ⚠️  需要实际的JWT token进行测试")

def test_authentication_issues():
    """测试认证问题"""
    print("\n5️⃣ 测试认证问题")
    print("-" * 40)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试各种认证问题
    test_cases = [
        {
            "name": "无效凭据",
            "credentials": {"email": "invalid@example.com", "password": "wrongpassword"},
            "expected_status": 401
        },
        {
            "name": "空凭据",
            "credentials": {"email": "", "password": ""},
            "expected_status": 422
        },
        {
            "name": "缺少字段",
            "credentials": {"email": "test@example.com"},
            "expected_status": 422
        }
    ]
    
    for test_case in test_cases:
        print(f"🔍 测试: {test_case['name']}")
        
        try:
            response = requests.post(
                f"{base_url}/api/secure-auth/login",
                json=test_case['credentials'],
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            
            print(f"  状态码: {response.status_code}")
            print(f"  期望状态码: {test_case['expected_status']}")
            
            if response.status_code == test_case['expected_status']:
                print("  ✅ 认证问题处理正确")
            else:
                print("  ❌ 认证问题处理异常")
                
        except Exception as e:
            print(f"  ❌ 测试异常: {e}")

def analyze_authentication_flow():
    """分析认证流程"""
    print("\n6️⃣ 分析认证流程")
    print("-" * 40)
    
    print("🔍 认证流程分析:")
    print("  1. 用户提交登录凭据")
    print("  2. 服务器验证凭据")
    print("  3. 创建会话和JWT token")
    print("  4. 设置安全Cookie")
    print("  5. 返回认证信息")
    print()
    
    print("🔍 可能的问题:")
    print("  1. Cookie设置问题")
    print("  2. 会话管理问题")
    print("  3. JWT token问题")
    print("  4. Redis连接问题")
    print("  5. 认证逻辑问题")
    print()
    
    print("🔍 修复建议:")
    print("  1. 检查Cookie设置")
    print("  2. 验证会话管理")
    print("  3. 测试JWT token")
    print("  4. 检查Redis连接")
    print("  5. 优化认证逻辑")

def main():
    """主函数"""
    print("🚀 全面认证功能测试")
    print("=" * 60)
    
    # 测试登录认证
    cookies, login_data = test_login_authentication()
    
    # 测试会话管理
    if cookies:
        session_success = test_session_management(cookies)
        
        # 测试Cookie验证
        test_cookie_validation(cookies)
    
    # 测试JWT认证
    test_jwt_authentication()
    
    # 测试认证问题
    test_authentication_issues()
    
    # 分析认证流程
    analyze_authentication_flow()
    
    print("\n📋 测试总结:")
    print("认证功能测试完成，请查看上述结果")
    print("如果发现问题，请根据建议进行修复")

if __name__ == "__main__":
    main()

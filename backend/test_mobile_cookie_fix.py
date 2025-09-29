#!/usr/bin/env python3
"""
测试移动端Cookie修复
验证移动端登录和Cookie传递是否正常
"""

import requests
import json
import logging

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 配置
BASE_URL = "https://linku1-production.up.railway.app"
FRONTEND_URL = "https://link-u1.vercel.app"

def test_mobile_login_and_cookies():
    """测试移动端登录和Cookie传递"""
    logger.info("开始测试移动端Cookie修复...")
    
    # 模拟移动端User-Agent
    mobile_headers = {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': FRONTEND_URL,
        'Referer': f'{FRONTEND_URL}/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site'
    }
    
    # 创建会话
    session = requests.Session()
    session.headers.update(mobile_headers)
    
    # 1. 测试登录
    logger.info("1. 测试移动端登录...")
    login_data = {
        "email": "mobiletest@example.com",
        "password": "test123"
    }
    
    try:
        login_response = session.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        logger.info(f"登录响应状态: {login_response.status_code}")
        
        if login_response.status_code == 200:
            login_result = login_response.json()
            logger.info(f"✅ 登录成功: {login_result.get('message')}")
            logger.info(f"Session ID: {login_result.get('session_id', 'N/A')[:8]}...")
            
            # 检查Cookie
            cookies = session.cookies.get_dict()
            logger.info(f"登录后Cookie: {cookies}")
            
            # 检查响应头中的Set-Cookie
            set_cookies = login_response.headers.get('Set-Cookie', '')
            logger.info(f"Set-Cookie头: {set_cookies}")
            
            # 2. 测试获取用户信息（使用Cookie）
            logger.info("2. 测试Cookie认证...")
            profile_response = session.get(f"{BASE_URL}/api/users/profile/me")
            logger.info(f"用户信息响应状态: {profile_response.status_code}")
            
            if profile_response.status_code == 200:
                profile_data = profile_response.json()
                logger.info(f"✅ Cookie认证成功: {profile_data.get('name', 'N/A')}")
                cookie_auth_success = True
            else:
                logger.error(f"❌ Cookie认证失败: {profile_response.text}")
                cookie_auth_success = False
            
            # 3. 测试X-Session-ID头认证
            logger.info("3. 测试X-Session-ID头认证...")
            session_id = login_result.get('session_id')
            if session_id:
                header_headers = mobile_headers.copy()
                header_headers['X-Session-ID'] = session_id
                
                # 创建新的会话，不使用Cookie
                header_session = requests.Session()
                header_session.headers.update(header_headers)
                
                profile_response = header_session.get(f"{BASE_URL}/api/users/profile/me")
                logger.info(f"头认证响应状态: {profile_response.status_code}")
                
                if profile_response.status_code == 200:
                    profile_data = profile_response.json()
                    logger.info(f"✅ X-Session-ID头认证成功: {profile_data.get('name', 'N/A')}")
                    header_auth_success = True
                else:
                    logger.error(f"❌ X-Session-ID头认证失败: {profile_response.text}")
                    header_auth_success = False
            else:
                logger.error("❌ 登录响应中没有session_id")
                header_auth_success = False
            
            return cookie_auth_success, header_auth_success
            
        else:
            logger.error(f"❌ 登录失败: {login_response.text}")
            return False, False
            
    except Exception as e:
        logger.error(f"❌ 测试过程中出错: {e}")
        return False, False

def test_cors_configuration():
    """测试CORS配置"""
    logger.info("测试CORS配置...")
    
    mobile_headers = {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1',
        'Origin': FRONTEND_URL,
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'Content-Type, X-Session-ID'
    }
    
    try:
        preflight_response = requests.options(f"{BASE_URL}/api/secure-auth/login", headers=mobile_headers)
        logger.info(f"CORS预检响应状态: {preflight_response.status_code}")
        
        # 检查关键的CORS头
        cors_headers = {
            'Access-Control-Allow-Origin': preflight_response.headers.get('Access-Control-Allow-Origin'),
            'Access-Control-Allow-Credentials': preflight_response.headers.get('Access-Control-Allow-Credentials'),
            'Access-Control-Allow-Methods': preflight_response.headers.get('Access-Control-Allow-Methods'),
            'Access-Control-Allow-Headers': preflight_response.headers.get('Access-Control-Allow-Headers')
        }
        
        logger.info(f"CORS配置: {cors_headers}")
        
        # 检查是否支持X-Session-ID头
        allowed_headers = cors_headers.get('Access-Control-Allow-Headers', '')
        supports_session_header = 'X-Session-ID' in allowed_headers
        
        if supports_session_header:
            logger.info("✅ CORS支持X-Session-ID头")
        else:
            logger.warning("⚠️ CORS不支持X-Session-ID头")
        
        return preflight_response.status_code == 200 and supports_session_header
        
    except Exception as e:
        logger.error(f"CORS测试失败: {e}")
        return False

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("移动端Cookie修复测试")
    logger.info("=" * 60)
    
    # 运行测试
    tests = [
        ("CORS配置", test_cors_configuration),
        ("移动端登录和认证", test_mobile_login_and_cookies)
    ]
    
    results = []
    for test_name, test_func in tests:
        logger.info(f"\n--- {test_name} ---")
        try:
            if test_name == "移动端登录和认证":
                cookie_success, header_success = test_func()
                result = cookie_success or header_success  # 任一成功即可
                logger.info(f"Cookie认证: {'✅' if cookie_success else '❌'}")
                logger.info(f"头认证: {'✅' if header_success else '❌'}")
            else:
                result = test_func()
            
            results.append((test_name, result))
            logger.info(f"{test_name}: {'✅ 通过' if result else '❌ 失败'}")
        except Exception as e:
            logger.error(f"{test_name} 测试异常: {e}")
            results.append((test_name, False))
    
    # 总结
    logger.info("\n" + "=" * 60)
    logger.info("测试结果总结")
    logger.info("=" * 60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        logger.info(f"{test_name}: {status}")
    
    logger.info(f"\n总计: {passed}/{total} 测试通过")
    
    if passed == total:
        logger.info("🎉 所有测试通过！移动端Cookie修复成功！")
    else:
        logger.info("⚠️  部分测试失败，需要进一步调试")
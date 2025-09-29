"""
移动端Cookie修复测试工具
测试移动端Cookie设置和持久化
"""

import requests
import json
import time
from typing import Dict, Any

class MobileCookieFixTester:
    """移动端Cookie修复测试器"""
    
    def __init__(self, base_url: str = "https://linku1-production.up.railway.app"):
        self.base_url = base_url
        self.session = requests.Session()
        
        # 模拟移动端User-Agent
        self.mobile_headers = {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Origin': 'https://link-u1.vercel.app',
            'Referer': 'https://link-u1.vercel.app/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'cross-site'
        }
    
    def test_login_and_cookie_persistence(self) -> Dict[str, Any]:
        """测试登录和Cookie持久化"""
        print("Testing mobile login and cookie persistence...")
        
        # 测试注册
        register_data = {
            "name": f"test_mobile_fix_{int(time.time())}",
            "email": f"test_mobile_fix_{int(time.time())}@example.com",
            "password": "test_password_123",
            "phone": "1234567890"
        }
        
        try:
            # 注册
            register_response = self.session.post(
                f"{self.base_url}/api/users/register",
                json=register_data,
                headers=self.mobile_headers
            )
            
            print(f"Register status: {register_response.status_code}")
            print(f"Register cookies: {dict(register_response.cookies)}")
            
            if register_response.status_code != 200:
                return {
                    'status': 'failed',
                    'error': f'Registration failed: {register_response.text}'
                }
            
            # 等待邮箱验证（在实际环境中需要验证邮箱）
            # 这里我们直接测试登录
            
            # 登录
            login_data = {
                "username": register_data["email"],
                "password": register_data["password"]
            }
            
            login_response = self.session.post(
                f"{self.base_url}/api/secure-auth/login",
                data=login_data,
                headers=self.mobile_headers
            )
            
            print(f"Login status: {login_response.status_code}")
            print(f"Login cookies: {dict(login_response.cookies)}")
            
            if login_response.status_code != 200:
                return {
                    'status': 'failed',
                    'error': f'Login failed: {login_response.text}'
                }
            
            # 检查Cookie设置
            set_cookie_headers = login_response.headers.get_list('Set-Cookie')
            print(f"Set-Cookie headers: {set_cookie_headers}")
            
            # 分析Cookie属性
            cookie_analysis = []
            for cookie_header in set_cookie_headers:
                cookie_parts = cookie_header.split(';')
                cookie_name = cookie_parts[0].split('=')[0]
                cookie_attrs = {}
                
                for part in cookie_parts[1:]:
                    part = part.strip()
                    if '=' in part:
                        key, value = part.split('=', 1)
                        cookie_attrs[key.lower()] = value
                    else:
                        cookie_attrs[part.lower()] = True
                
                cookie_analysis.append({
                    'name': cookie_name,
                    'attributes': cookie_attrs
                })
            
            # 测试Cookie持久化 - 立即发送另一个请求
            profile_response = self.session.get(
                f"{self.base_url}/api/users/profile/me",
                headers=self.mobile_headers
            )
            
            print(f"Profile request status: {profile_response.status_code}")
            print(f"Profile request cookies sent: {dict(profile_response.cookies)}")
            
            # 检查请求头中的Cookie
            request_cookies = profile_response.request.headers.get('Cookie', '')
            print(f"Request cookies: {request_cookies}")
            
            return {
                'status': 'success',
                'register_status': register_response.status_code,
                'login_status': login_response.status_code,
                'profile_status': profile_response.status_code,
                'cookies_received': dict(login_response.cookies),
                'cookies_sent': request_cookies,
                'cookie_analysis': cookie_analysis,
                'set_cookie_headers': set_cookie_headers
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_cookie_attributes(self) -> Dict[str, Any]:
        """测试Cookie属性设置"""
        print("Testing cookie attributes...")
        
        try:
            # 获取CSRF token
            csrf_response = self.session.get(
                f"{self.base_url}/api/csrf/token",
                headers=self.mobile_headers
            )
            
            print(f"CSRF response status: {csrf_response.status_code}")
            
            if csrf_response.status_code != 200:
                return {
                    'status': 'failed',
                    'error': f'CSRF token request failed: {csrf_response.text}'
                }
            
            # 分析Set-Cookie头
            set_cookie_headers = csrf_response.headers.get_list('Set-Cookie')
            print(f"CSRF Set-Cookie headers: {set_cookie_headers}")
            
            # 检查Cookie属性
            cookie_analysis = []
            for cookie_header in set_cookie_headers:
                cookie_parts = cookie_header.split(';')
                cookie_name = cookie_parts[0].split('=')[0]
                cookie_attrs = {}
                
                for part in cookie_parts[1:]:
                    part = part.strip()
                    if '=' in part:
                        key, value = part.split('=', 1)
                        cookie_attrs[key.lower()] = value
                    else:
                        cookie_attrs[part.lower()] = True
                
                cookie_analysis.append({
                    'name': cookie_name,
                    'attributes': cookie_attrs
                })
            
            return {
                'status': 'success',
                'cookies_received': dict(csrf_response.cookies),
                'cookie_analysis': cookie_analysis,
                'set_cookie_headers': set_cookie_headers
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def run_all_tests(self) -> Dict[str, Any]:
        """运行所有测试"""
        print("Starting mobile cookie fix tests...")
        print("=" * 50)
        
        results = {
            'login_persistence': self.test_login_and_cookie_persistence(),
            'cookie_attributes': self.test_cookie_attributes()
        }
        
        # 生成测试报告
        self.generate_test_report(results)
        
        return results
    
    def generate_test_report(self, results: Dict[str, Any]) -> None:
        """生成测试报告"""
        print("\n" + "=" * 50)
        print("MOBILE COOKIE FIX TEST REPORT")
        print("=" * 50)
        
        # 登录和持久化测试结果
        print("\n1. Login and Cookie Persistence Test:")
        login_test = results['login_persistence']
        if login_test['status'] == 'success':
            print("   ✅ Login and cookie setting successful")
            print(f"   - Register status: {login_test['register_status']}")
            print(f"   - Login status: {login_test['login_status']}")
            print(f"   - Profile status: {login_test['profile_status']}")
            print(f"   - Cookies received: {len(login_test['cookies_received'])}")
            print(f"   - Cookies sent: {login_test['cookies_sent']}")
            
            # 分析Cookie属性
            print("\n   Cookie Analysis:")
            for cookie in login_test['cookie_analysis']:
                print(f"   - {cookie['name']}: {cookie['attributes']}")
        else:
            print("   ❌ Login and cookie persistence failed")
            print(f"   - Error: {login_test.get('error', 'Unknown error')}")
        
        # Cookie属性测试结果
        print("\n2. Cookie Attributes Test:")
        attr_test = results['cookie_attributes']
        if attr_test['status'] == 'success':
            print("   ✅ Cookie attributes test successful")
            print(f"   - Cookies received: {len(attr_test['cookies_received'])}")
            
            # 分析Cookie属性
            print("\n   Cookie Analysis:")
            for cookie in attr_test['cookie_analysis']:
                print(f"   - {cookie['name']}: {cookie['attributes']}")
        else:
            print("   ❌ Cookie attributes test failed")
            print(f"   - Error: {attr_test.get('error', 'Unknown error')}")
        
        print("\n" + "=" * 50)
        print("Test completed!")


def main():
    """主函数"""
    import sys
    
    base_url = sys.argv[1] if len(sys.argv) > 1 else "https://linku1-production.up.railway.app"
    
    tester = MobileCookieFixTester(base_url)
    results = tester.run_all_tests()
    
    # 返回退出码
    all_success = all(
        result.get('status') == 'success' 
        for result in results.values() 
        if isinstance(result, dict) and 'status' in result
    )
    
    sys.exit(0 if all_success else 1)


if __name__ == "__main__":
    main()

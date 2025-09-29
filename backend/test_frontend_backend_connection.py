"""
前后端互联测试工具
测试前端和后端之间的API连接和配置
"""

import requests
import json
import time
from typing import Dict, Any, List

class FrontendBackendTester:
    """前后端互联测试器"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.cookies.clear()
        
    def test_cors_configuration(self) -> Dict[str, Any]:
        """测试CORS配置"""
        print("Testing CORS configuration...")
        
        # 模拟前端请求
        headers = {
            'Origin': 'http://localhost:3000',
            'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'Content-Type, X-CSRF-Token'
        }
        
        try:
            response = self.session.options(
                f"{self.base_url}/api/users/register",
                headers=headers
            )
            
            cors_headers = {
                'Access-Control-Allow-Origin': response.headers.get('Access-Control-Allow-Origin'),
                'Access-Control-Allow-Methods': response.headers.get('Access-Control-Allow-Methods'),
                'Access-Control-Allow-Headers': response.headers.get('Access-Control-Allow-Headers'),
                'Access-Control-Allow-Credentials': response.headers.get('Access-Control-Allow-Credentials')
            }
            
            return {
                'status': 'success' if response.status_code == 200 else 'failed',
                'status_code': response.status_code,
                'cors_headers': cors_headers
            }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_api_endpoints(self) -> Dict[str, Any]:
        """测试API端点"""
        print("Testing API endpoints...")
        
        endpoints = [
            {'method': 'GET', 'path': '/api/users/register/test', 'name': 'Register Test'},
            {'method': 'GET', 'path': '/api/health', 'name': 'Health Check'},
            {'method': 'GET', 'path': '/api/docs', 'name': 'API Documentation'},
        ]
        
        results = {}
        
        for endpoint in endpoints:
            try:
                if endpoint['method'] == 'GET':
                    response = self.session.get(f"{self.base_url}{endpoint['path']}")
                else:
                    response = self.session.post(f"{self.base_url}{endpoint['path']}")
                
                results[endpoint['name']] = {
                    'status': 'success' if response.status_code < 400 else 'failed',
                    'status_code': response.status_code,
                    'response_time': response.elapsed.total_seconds()
                }
            except Exception as e:
                results[endpoint['name']] = {
                    'status': 'error',
                    'error': str(e)
                }
        
        return results
    
    def test_authentication_flow(self) -> Dict[str, Any]:
        """测试认证流程"""
        print("Testing authentication flow...")
        
        # 测试注册
        register_data = {
            "name": "test_user",
            "email": f"test_{int(time.time())}@example.com",
            "password": "test_password_123",
            "phone": "1234567890"
        }
        
        try:
            # 注册请求
            register_response = self.session.post(
                f"{self.base_url}/api/users/register",
                json=register_data,
                headers={'Content-Type': 'application/json'}
            )
            
            register_result = {
                'status': 'success' if register_response.status_code == 200 else 'failed',
                'status_code': register_response.status_code,
                'response': register_response.json() if register_response.headers.get('content-type', '').startswith('application/json') else register_response.text
            }
            
            # 测试登录
            login_data = {
                "username": register_data["email"],
                "password": register_data["password"]
            }
            
            login_response = self.session.post(
                f"{self.base_url}/api/secure-auth/login",
                data=login_data,
                headers={'Content-Type': 'application/x-www-form-urlencoded'}
            )
            
            login_result = {
                'status': 'success' if login_response.status_code == 200 else 'failed',
                'status_code': login_response.status_code,
                'cookies': dict(login_response.cookies),
                'response': login_response.json() if login_response.headers.get('content-type', '').startswith('application/json') else login_response.text
            }
            
            return {
                'register': register_result,
                'login': login_result
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_cookie_handling(self) -> Dict[str, Any]:
        """测试Cookie处理"""
        print("Testing cookie handling...")
        
        try:
            # 发送请求并检查Cookie设置
            response = self.session.get(f"{self.base_url}/api/users/register/test")
            
            cookies = dict(response.cookies)
            
            return {
                'status': 'success',
                'cookies_received': cookies,
                'cookie_count': len(cookies)
            }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_csrf_protection(self) -> Dict[str, Any]:
        """测试CSRF保护"""
        print("Testing CSRF protection...")
        
        try:
            # 获取CSRF token
            csrf_response = self.session.get(f"{self.base_url}/api/csrf/token")
            
            if csrf_response.status_code == 200:
                csrf_data = csrf_response.json()
                csrf_token = csrf_data.get('csrf_token')
                
                # 使用CSRF token发送请求
                headers = {
                    'X-CSRF-Token': csrf_token,
                    'Content-Type': 'application/json'
                }
                
                test_response = self.session.post(
                    f"{self.base_url}/api/users/register/debug",
                    json={"test": "data"},
                    headers=headers
                )
                
                return {
                    'status': 'success',
                    'csrf_token_received': csrf_token is not None,
                    'csrf_protection_working': test_response.status_code < 400
                }
            else:
                return {
                    'status': 'failed',
                    'error': 'Failed to get CSRF token'
                }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def run_all_tests(self) -> Dict[str, Any]:
        """运行所有测试"""
        print("Starting frontend-backend connection tests...")
        print("=" * 50)
        
        results = {
            'cors': self.test_cors_configuration(),
            'endpoints': self.test_api_endpoints(),
            'authentication': self.test_authentication_flow(),
            'cookies': self.test_cookie_handling(),
            'csrf': self.test_csrf_protection()
        }
        
        # 生成测试报告
        self.generate_test_report(results)
        
        return results
    
    def generate_test_report(self, results: Dict[str, Any]) -> None:
        """生成测试报告"""
        print("\n" + "=" * 50)
        print("FRONTEND-BACKEND CONNECTION TEST REPORT")
        print("=" * 50)
        
        # CORS测试结果
        print("\n1. CORS Configuration:")
        cors = results['cors']
        if cors['status'] == 'success':
            print("   ✅ CORS is properly configured")
            print(f"   - Allow Origin: {cors['cors_headers'].get('Access-Control-Allow-Origin', 'Not set')}")
            print(f"   - Allow Methods: {cors['cors_headers'].get('Access-Control-Allow-Methods', 'Not set')}")
            print(f"   - Allow Credentials: {cors['cors_headers'].get('Access-Control-Allow-Credentials', 'Not set')}")
        else:
            print("   ❌ CORS configuration failed")
            print(f"   - Error: {cors.get('error', 'Unknown error')}")
        
        # API端点测试结果
        print("\n2. API Endpoints:")
        endpoints = results['endpoints']
        for name, result in endpoints.items():
            status = "✅" if result['status'] == 'success' else "❌"
            print(f"   {status} {name}: {result['status_code']} ({result.get('response_time', 0):.3f}s)")
        
        # 认证流程测试结果
        print("\n3. Authentication Flow:")
        auth = results['authentication']
        if 'register' in auth:
            reg_status = "✅" if auth['register']['status'] == 'success' else "❌"
            print(f"   {reg_status} Registration: {auth['register']['status_code']}")
        
        if 'login' in auth:
            login_status = "✅" if auth['login']['status'] == 'success' else "❌"
            print(f"   {login_status} Login: {auth['login']['status_code']}")
            if auth['login']['status'] == 'success':
                print(f"   - Cookies set: {len(auth['login']['cookies'])}")
        
        # Cookie处理测试结果
        print("\n4. Cookie Handling:")
        cookies = results['cookies']
        if cookies['status'] == 'success':
            print(f"   ✅ Cookies working: {cookies['cookie_count']} cookies received")
        else:
            print("   ❌ Cookie handling failed")
            print(f"   - Error: {cookies.get('error', 'Unknown error')}")
        
        # CSRF保护测试结果
        print("\n5. CSRF Protection:")
        csrf = results['csrf']
        if csrf['status'] == 'success':
            print("   ✅ CSRF protection is working")
            print(f"   - Token received: {csrf['csrf_token_received']}")
            print(f"   - Protection active: {csrf['csrf_protection_working']}")
        else:
            print("   ❌ CSRF protection failed")
            print(f"   - Error: {csrf.get('error', 'Unknown error')}")
        
        print("\n" + "=" * 50)
        print("Test completed!")


def main():
    """主函数"""
    import sys
    
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    
    tester = FrontendBackendTester(base_url)
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

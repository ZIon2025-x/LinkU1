"""
移动端Cookie测试工具
测试移动端浏览器的Cookie兼容性
"""

import requests
import json
from typing import Dict, Any

class MobileCookieTester:
    """移动端Cookie测试器"""
    
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
        
        # 模拟桌面端User-Agent
        self.desktop_headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
            'Accept-Encoding': 'gzip, deflate, br, zstd',
            'Origin': 'https://link-u1.vercel.app',
            'Referer': 'https://link-u1.vercel.app/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'cross-site'
        }
    
    def test_cookie_headers(self) -> Dict[str, Any]:
        """测试Cookie头设置"""
        print("Testing cookie headers...")
        
        # 测试注册
        register_data = {
            "name": f"test_mobile_{int(time.time())}",
            "email": f"test_mobile_{int(time.time())}@example.com",
            "password": "test_password_123",
            "phone": "1234567890"
        }
        
        try:
            # 使用移动端headers注册
            register_response = self.session.post(
                f"{self.base_url}/api/users/register",
                json=register_data,
                headers=self.mobile_headers
            )
            
            print(f"Register response status: {register_response.status_code}")
            print(f"Register cookies: {dict(register_response.cookies)}")
            
            # 检查Set-Cookie头
            set_cookie_headers = register_response.headers.get_list('Set-Cookie')
            print(f"Set-Cookie headers: {set_cookie_headers}")
            
            return {
                'status': 'success' if register_response.status_code == 200 else 'failed',
                'status_code': register_response.status_code,
                'cookies_received': dict(register_response.cookies),
                'set_cookie_headers': set_cookie_headers
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_cookie_attributes(self) -> Dict[str, Any]:
        """测试Cookie属性"""
        print("Testing cookie attributes...")
        
        try:
            # 获取CSRF token
            csrf_response = self.session.get(
                f"{self.base_url}/api/csrf/token",
                headers=self.mobile_headers
            )
            
            print(f"CSRF response status: {csrf_response.status_code}")
            print(f"CSRF cookies: {dict(csrf_response.cookies)}")
            
            # 分析Set-Cookie头
            set_cookie_headers = csrf_response.headers.get_list('Set-Cookie')
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
                'status': 'success' if csrf_response.status_code == 200 else 'failed',
                'status_code': csrf_response.status_code,
                'cookies_received': dict(csrf_response.cookies),
                'cookie_analysis': cookie_analysis
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def test_cross_origin_cookies(self) -> Dict[str, Any]:
        """测试跨域Cookie"""
        print("Testing cross-origin cookies...")
        
        try:
            # 模拟预检请求
            preflight_headers = {
                'Origin': 'https://link-u1.vercel.app',
                'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'Content-Type, X-CSRF-Token'
            }
            
            preflight_response = self.session.options(
                f"{self.base_url}/api/users/register",
                headers=preflight_headers
            )
            
            print(f"Preflight response status: {preflight_response.status_code}")
            
            # 检查CORS头
            cors_headers = {
                'Access-Control-Allow-Origin': preflight_response.headers.get('Access-Control-Allow-Origin'),
                'Access-Control-Allow-Methods': preflight_response.headers.get('Access-Control-Allow-Methods'),
                'Access-Control-Allow-Headers': preflight_response.headers.get('Access-Control-Allow-Headers'),
                'Access-Control-Allow-Credentials': preflight_response.headers.get('Access-Control-Allow-Credentials')
            }
            
            return {
                'status': 'success' if preflight_response.status_code == 200 else 'failed',
                'status_code': preflight_response.status_code,
                'cors_headers': cors_headers
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def run_all_tests(self) -> Dict[str, Any]:
        """运行所有测试"""
        print("Starting mobile cookie tests...")
        print("=" * 50)
        
        results = {
            'cookie_headers': self.test_cookie_headers(),
            'cookie_attributes': self.test_cookie_attributes(),
            'cross_origin': self.test_cross_origin_cookies()
        }
        
        # 生成测试报告
        self.generate_test_report(results)
        
        return results
    
    def generate_test_report(self, results: Dict[str, Any]) -> None:
        """生成测试报告"""
        print("\n" + "=" * 50)
        print("MOBILE COOKIE TEST REPORT")
        print("=" * 50)
        
        # Cookie头测试结果
        print("\n1. Cookie Headers Test:")
        headers = results['cookie_headers']
        if headers['status'] == 'success':
            print("   ✅ Cookie headers working")
            print(f"   - Cookies received: {len(headers['cookies_received'])}")
            print(f"   - Set-Cookie headers: {len(headers['set_cookie_headers'])}")
        else:
            print("   ❌ Cookie headers failed")
            print(f"   - Error: {headers.get('error', 'Unknown error')}")
        
        # Cookie属性测试结果
        print("\n2. Cookie Attributes Test:")
        attrs = results['cookie_attributes']
        if attrs['status'] == 'success':
            print("   ✅ Cookie attributes working")
            for cookie in attrs['cookie_analysis']:
                print(f"   - {cookie['name']}: {cookie['attributes']}")
        else:
            print("   ❌ Cookie attributes failed")
            print(f"   - Error: {attrs.get('error', 'Unknown error')}")
        
        # 跨域测试结果
        print("\n3. Cross-Origin Cookies Test:")
        cors = results['cross_origin']
        if cors['status'] == 'success':
            print("   ✅ Cross-origin cookies working")
            print(f"   - Allow Origin: {cors['cors_headers'].get('Access-Control-Allow-Origin', 'Not set')}")
            print(f"   - Allow Credentials: {cors['cors_headers'].get('Access-Control-Allow-Credentials', 'Not set')}")
        else:
            print("   ❌ Cross-origin cookies failed")
            print(f"   - Error: {cors.get('error', 'Unknown error')}")
        
        print("\n" + "=" * 50)
        print("Test completed!")


def main():
    """主函数"""
    import sys
    import time
    
    base_url = sys.argv[1] if len(sys.argv) > 1 else "https://linku1-production.up.railway.app"
    
    tester = MobileCookieTester(base_url)
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

"""
移动端Cookie调试工具
实时监控移动端Cookie设置和接收情况
"""

import requests
import json
import time
from typing import Dict, Any, List

class MobileCookieDebugger:
    """移动端Cookie调试器"""
    
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
    
    def analyze_set_cookie_headers(self, response: requests.Response) -> List[Dict[str, Any]]:
        """分析Set-Cookie响应头"""
        # requests库的headers是CaseInsensitiveDict，需要特殊处理
        set_cookie_headers = []
        if 'Set-Cookie' in response.headers:
            set_cookie_value = response.headers['Set-Cookie']
            if isinstance(set_cookie_value, list):
                set_cookie_headers = set_cookie_value
            else:
                set_cookie_headers = [set_cookie_value]
        
        analysis = []
        
        for cookie_header in set_cookie_headers:
            cookie_parts = cookie_header.split(';')
            cookie_name = cookie_parts[0].split('=')[0]
            cookie_value = cookie_parts[0].split('=')[1] if '=' in cookie_parts[0] else ''
            
            attributes = {}
            for part in cookie_parts[1:]:
                part = part.strip()
                if '=' in part:
                    key, value = part.split('=', 1)
                    attributes[key.lower()] = value
                else:
                    attributes[part.lower()] = True
            
            analysis.append({
                'name': cookie_name,
                'value': cookie_value[:20] + '...' if len(cookie_value) > 20 else cookie_value,
                'attributes': attributes,
                'raw_header': cookie_header
            })
        
        return analysis
    
    def test_login_flow(self) -> Dict[str, Any]:
        """测试登录流程"""
        print("开始移动端登录流程测试...")
        
        # 1. 获取CSRF token
        print("\n1. 获取CSRF token...")
        csrf_response = self.session.get(
            f"{self.base_url}/api/csrf/token",
            headers=self.mobile_headers
        )
        
        print(f"   Status: {csrf_response.status_code}")
        print(f"   Cookies received: {dict(csrf_response.cookies)}")
        
        csrf_analysis = self.analyze_set_cookie_headers(csrf_response)
        print(f"   Set-Cookie headers: {len(csrf_analysis)}")
        for cookie in csrf_analysis:
            print(f"     - {cookie['name']}: {cookie['attributes']}")
        
        # 2. 尝试登录
        print("\n2. 尝试登录...")
        login_data = {
            "username": "zixiong316@gmail.com",
            "password": "123456"
        }
        
        login_response = self.session.post(
            f"{self.base_url}/api/secure-auth/login",
            data=login_data,
            headers=self.mobile_headers
        )
        
        print(f"   Status: {login_response.status_code}")
        print(f"   Cookies received: {dict(login_response.cookies)}")
        
        login_analysis = self.analyze_set_cookie_headers(login_response)
        print(f"   Set-Cookie headers: {len(login_analysis)}")
        for cookie in login_analysis:
            print(f"     - {cookie['name']}: {cookie['attributes']}")
        
        # 3. 测试Cookie持久化
        print("\n3. 测试Cookie持久化...")
        profile_response = self.session.get(
            f"{self.base_url}/api/users/profile/me",
            headers=self.mobile_headers
        )
        
        print(f"   Status: {profile_response.status_code}")
        print(f"   Cookies sent: {dict(profile_response.cookies)}")
        
        # 检查请求头中的Cookie
        request_cookies = profile_response.request.headers.get('Cookie', '')
        print(f"   Request Cookie header: {request_cookies}")
        
        # 4. 分析结果
        success = profile_response.status_code == 200
        cookies_persisted = len(dict(profile_response.cookies)) > 0 or bool(request_cookies)
        
        print(f"\n测试结果:")
        print(f"   - 登录成功: {login_response.status_code == 200}")
        print(f"   - Cookie持久化: {cookies_persisted}")
        print(f"   - 认证成功: {success}")
        
        return {
            'csrf_status': csrf_response.status_code,
            'login_status': login_response.status_code,
            'profile_status': profile_response.status_code,
            'csrf_cookies': dict(csrf_response.cookies),
            'login_cookies': dict(login_response.cookies),
            'profile_cookies': dict(profile_response.cookies),
            'request_cookies': request_cookies,
            'csrf_analysis': csrf_analysis,
            'login_analysis': login_analysis,
            'success': success,
            'cookies_persisted': cookies_persisted
        }
    
    def test_multiple_requests(self) -> Dict[str, Any]:
        """测试多次请求的Cookie持久化"""
        print("\n测试多次请求Cookie持久化...")
        
        results = []
        for i in range(3):
            print(f"\n请求 {i+1}:")
            
            response = self.session.get(
                f"{self.base_url}/api/users/profile/me",
                headers=self.mobile_headers
            )
            
            print(f"   Status: {response.status_code}")
            print(f"   Cookies: {dict(response.cookies)}")
            print(f"   Request Cookie: {response.request.headers.get('Cookie', '')}")
            
            results.append({
                'request_num': i + 1,
                'status': response.status_code,
                'cookies': dict(response.cookies),
                'request_cookie': response.request.headers.get('Cookie', '')
            })
        
        return results
    
    def run_comprehensive_test(self) -> Dict[str, Any]:
        """运行综合测试"""
        print("开始移动端Cookie综合测试")
        print("=" * 60)
        
        # 测试登录流程
        login_result = self.test_login_flow()
        
        # 测试多次请求
        persistence_result = self.test_multiple_requests()
        
        # 生成报告
        self.generate_comprehensive_report(login_result, persistence_result)
        
        return {
            'login_test': login_result,
            'persistence_test': persistence_result
        }
    
    def generate_comprehensive_report(self, login_result: Dict[str, Any], persistence_result: List[Dict[str, Any]]) -> None:
        """生成综合测试报告"""
        print("\n" + "=" * 60)
        print("移动端Cookie综合测试报告")
        print("=" * 60)
        
        # 登录测试结果
        print(f"\n登录测试:")
        print(f"   CSRF Token: {'成功' if login_result['csrf_status'] == 200 else '失败'} ({login_result['csrf_status']})")
        print(f"   登录请求: {'成功' if login_result['login_status'] == 200 else '失败'} ({login_result['login_status']})")
        print(f"   认证请求: {'成功' if login_result['profile_status'] == 200 else '失败'} ({login_result['profile_status']})")
        
        # Cookie分析
        print(f"\nCookie分析:")
        print(f"   CSRF Cookies: {len(login_result['csrf_cookies'])}")
        print(f"   登录Cookies: {len(login_result['login_cookies'])}")
        print(f"   请求Cookie: {'是' if login_result['request_cookies'] else '否'}")
        
        # 详细Cookie信息
        if login_result['login_analysis']:
            print(f"\n登录Cookie详情:")
            for cookie in login_result['login_analysis']:
                print(f"   {cookie['name']}:")
                for attr, value in cookie['attributes'].items():
                    print(f"     - {attr}: {value}")
        
        # 持久化测试结果
        print(f"\n持久化测试:")
        for result in persistence_result:
            status_text = '成功' if result['status'] == 200 else '失败'
            cookie_text = '是' if result['request_cookie'] else '否'
            print(f"   请求{result['request_num']}: {status_text} 状态={result['status']}, Cookie={cookie_text}")
        
        # 总体评估
        overall_success = (
            login_result['success'] and 
            login_result['cookies_persisted'] and
            any(r['status'] == 200 for r in persistence_result)
        )
        
        print(f"\n总体评估: {'成功' if overall_success else '失败'}")
        
        if not overall_success:
            print(f"\n建议修复:")
            if not login_result['cookies_persisted']:
                print("   - Cookie未持久化，检查SameSite和Secure设置")
            if not login_result['success']:
                print("   - 认证失败，检查Cookie名称和值")
            if not any(r['status'] == 200 for r in persistence_result):
                print("   - 后续请求失败，检查Cookie传递")


def main():
    """主函数"""
    import sys
    
    base_url = sys.argv[1] if len(sys.argv) > 1 else "https://linku1-production.up.railway.app"
    
    debugger = MobileCookieDebugger(base_url)
    results = debugger.run_comprehensive_test()
    
    # 返回退出码
    overall_success = results['login_test']['success'] and results['login_test']['cookies_persisted']
    sys.exit(0 if overall_success else 1)


if __name__ == "__main__":
    main()
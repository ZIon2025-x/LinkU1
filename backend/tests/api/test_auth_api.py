"""
认证 API 测试

测试覆盖:
- 用户登录（成功/失败）
- 获取当前用户信息
- 退出登录
- 注册流程（可选）

运行方式:
    pytest tests/api/test_auth_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT


class TestAuthAPI:
    """认证 API 测试类"""

    # 共享的 session cookies（用于需要认证的测试）
    _cookies: dict = {}
    _access_token: str = ""

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    # =========================================================================
    # 登录测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_login_success(self):
        """测试：正确的账号密码应该登录成功"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号 (TEST_USER_EMAIL, TEST_USER_PASSWORD)")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/login",
                json={
                    "email": TEST_USER_EMAIL,
                    "password": TEST_USER_PASSWORD
                }
            )

            # 验证响应
            assert response.status_code == 200, f"登录失败: {response.text}"
            
            data = response.json()
            assert "user" in data or "access_token" in data, f"响应缺少用户信息: {data}"
            
            # 保存 cookies 供后续测试使用
            TestAuthAPI._cookies = dict(response.cookies)
            if "access_token" in data:
                TestAuthAPI._access_token = data["access_token"]
            
            print(f"✅ 登录成功: {TEST_USER_EMAIL}")

    @pytest.mark.api
    @pytest.mark.auth
    def test_login_wrong_password(self):
        """测试：错误密码应该返回 401"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/login",
                json={
                    "email": "test@example.com",
                    "password": "WrongPassword123!"
                }
            )

            # 应该返回 401 或 400
            assert response.status_code in [400, 401, 403], \
                f"错误密码应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 错误密码被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_login_invalid_email(self):
        """测试：无效邮箱格式应该返回错误"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/login",
                json={
                    "email": "not-an-email",
                    "password": "SomePassword123!"
                }
            )

            # 应该返回 400 或 422（验证错误）
            assert response.status_code in [400, 401, 422], \
                f"无效邮箱应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 无效邮箱被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_login_nonexistent_user(self):
        """测试：不存在的用户应该返回错误"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/login",
                json={
                    "email": "nonexistent_user_12345@example.com",
                    "password": "SomePassword123!"
                }
            )

            # 应该返回 401 或 404
            assert response.status_code in [400, 401, 404], \
                f"不存在的用户应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 不存在的用户被正确拒绝")

    # =========================================================================
    # 获取当前用户测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_get_current_user_authenticated(self):
        """测试：已登录用户应该能获取自己的信息"""
        if not TestAuthAPI._cookies and not TestAuthAPI._access_token:
            pytest.skip("需要先运行 test_login_success")

        with httpx.Client(timeout=self.timeout, cookies=TestAuthAPI._cookies) as client:
            headers = {}
            if TestAuthAPI._access_token:
                headers["Authorization"] = f"Bearer {TestAuthAPI._access_token}"
            
            response = client.get(
                f"{self.base_url}/api/users/me",
                headers=headers
            )

            assert response.status_code == 200, f"获取用户信息失败: {response.text}"
            
            data = response.json()
            assert "email" in data or "id" in data, f"响应缺少用户信息: {data}"
            
            print(f"✅ 成功获取用户信息")

    @pytest.mark.api
    @pytest.mark.auth
    def test_get_current_user_unauthenticated(self):
        """测试：未登录用户应该被拒绝"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/users/me")

            # 应该返回 401 或 403
            assert response.status_code in [401, 403], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未认证请求被正确拒绝")

    # =========================================================================
    # CAPTCHA 配置测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_get_captcha_config(self):
        """测试：获取 CAPTCHA 配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/secure-auth/captcha-site-key")

            assert response.status_code == 200, f"获取 CAPTCHA 配置失败: {response.text}"
            
            data = response.json()
            assert "enabled" in data, f"响应缺少 enabled 字段: {data}"
            
            print(f"✅ CAPTCHA 配置: enabled={data.get('enabled')}, type={data.get('type')}")

    # =========================================================================
    # 健康检查
    # =========================================================================

    @pytest.mark.api
    def test_api_health(self):
        """测试：API 健康检查"""
        with httpx.Client(timeout=self.timeout) as client:
            # 尝试几个常见的健康检查端点
            health_endpoints = [
                "/health",
                "/api/health",
                "/",
            ]
            
            for endpoint in health_endpoints:
                try:
                    response = client.get(f"{self.base_url}{endpoint}")
                    if response.status_code == 200:
                        print(f"✅ 健康检查通过: {endpoint}")
                        return
                except Exception:
                    continue
            
            # 如果都失败了，至少确认服务器在响应
            response = client.get(f"{self.base_url}/api/secure-auth/captcha-site-key")
            assert response.status_code == 200, "API 服务不可用"
            print("✅ API 服务正常运行")

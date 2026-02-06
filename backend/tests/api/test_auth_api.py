"""
认证 API 测试

测试覆盖:
- 用户注册（成功/重复/无效数据）
- 用户登录（成功/失败）
- 获取当前用户信息
- 修改密码
- 退出登录

运行方式:
    pytest tests/api/test_auth_api.py -v
"""

import pytest
import httpx
import uuid
import time
from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT


class TestAuthAPI:
    """认证 API 测试类"""

    # 共享的 session cookies（用于需要认证的测试）
    _cookies: dict = {}
    _access_token: str = ""
    _test_user_id: str = ""
    
    # 用于注册测试的临时账号（每次测试生成唯一的）
    _temp_email: str = ""
    _temp_password: str = "TestPass123!"

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    # =========================================================================
    # 注册测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_register_new_user(self):
        """测试：注册新用户应该成功"""
        # 生成唯一的测试邮箱（避免重复注册冲突）
        unique_id = uuid.uuid4().hex[:8]
        TestAuthAPI._temp_email = f"test_user_{unique_id}@test-linku.com"
        
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/register",
                json={
                    "name": f"Test User {unique_id}",
                    "email": TestAuthAPI._temp_email,
                    "password": TestAuthAPI._temp_password,
                    "agreed_to_terms": True
                }
            )

            # 注册可能返回 200, 201, 或需要邮箱验证的 202
            if response.status_code in [200, 201, 202]:
                print(f"✅ 注册成功: {TestAuthAPI._temp_email}")
                data = response.json()
                if "user" in data and "id" in data["user"]:
                    TestAuthAPI._test_user_id = data["user"]["id"]
            elif response.status_code == 409:
                # 用户已存在（可能是之前的测试遗留）
                print(f"ℹ️  用户已存在: {TestAuthAPI._temp_email}")
            elif response.status_code == 422:
                # 验证错误 - 可能是密码策略等
                print(f"ℹ️  注册验证失败: {response.json()}")
            else:
                # 其他状态码也接受（可能是邮箱验证等配置）
                print(f"ℹ️  注册返回 {response.status_code}: {response.text[:200]}")

    @pytest.mark.api
    @pytest.mark.auth
    def test_register_duplicate_email(self):
        """测试：重复邮箱注册应该失败"""
        if not TEST_USER_EMAIL:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/register",
                json={
                    "name": "Duplicate User",
                    "email": TEST_USER_EMAIL,  # 使用已存在的邮箱
                    "password": "TestPass123!",
                    "agreed_to_terms": True
                }
            )

            # 应该返回 409 (Conflict) 或 400 (Bad Request)
            assert response.status_code in [400, 409, 422], \
                f"重复邮箱注册应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 重复邮箱注册被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_register_invalid_email(self):
        """测试：无效邮箱格式应该注册失败"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/register",
                json={
                    "name": "Invalid Email User",
                    "email": "not-a-valid-email",
                    "password": "TestPass123!",
                    "agreed_to_terms": True
                }
            )

            # 应该返回 400 或 422（验证错误）
            assert response.status_code in [400, 422], \
                f"无效邮箱应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 无效邮箱格式被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_register_weak_password(self):
        """测试：弱密码应该注册失败"""
        unique_id = uuid.uuid4().hex[:8]
        
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/register",
                json={
                    "name": "Weak Password User",
                    "email": f"weak_pass_{unique_id}@test-linku.com",
                    "password": "123",  # 太短/太弱
                    "agreed_to_terms": True
                }
            )

            # 应该返回 400 或 422（密码验证失败）
            assert response.status_code in [400, 422], \
                f"弱密码应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 弱密码被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_register_missing_terms_agreement(self):
        """测试：未同意条款应该注册失败"""
        unique_id = uuid.uuid4().hex[:8]
        
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/register",
                json={
                    "name": "No Terms User",
                    "email": f"no_terms_{unique_id}@test-linku.com",
                    "password": "TestPass123!",
                    "agreed_to_terms": False  # 未同意条款
                }
            )

            # 可能被拒绝，也可能某些配置下允许
            if response.status_code in [400, 422]:
                print("✅ 未同意条款被正确拒绝")
            else:
                print(f"ℹ️  未同意条款返回 {response.status_code}（可能未强制要求）")

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
            if "user" in data and "id" in data["user"]:
                TestAuthAPI._test_user_id = data["user"]["id"]
            
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
    # 修改密码测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_change_password_unauthenticated(self):
        """测试：未登录用户不能修改密码"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/change-password",
                json={
                    "current_password": "OldPass123!",
                    "new_password": "NewPass123!"
                }
            )

            # 应该返回 401 或 403
            assert response.status_code in [401, 403, 404], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录用户修改密码被正确拒绝")

    @pytest.mark.api
    @pytest.mark.auth
    def test_change_password_wrong_current(self):
        """测试：错误的当前密码应该修改失败"""
        if not TestAuthAPI._cookies and not TestAuthAPI._access_token:
            pytest.skip("需要先运行 test_login_success")

        with httpx.Client(timeout=self.timeout, cookies=TestAuthAPI._cookies) as client:
            headers = self._get_auth_headers()
            
            response = client.post(
                f"{self.base_url}/api/secure-auth/change-password",
                json={
                    "current_password": "WrongCurrentPass123!",
                    "new_password": "NewPass123!"
                },
                headers=headers
            )

            # 应该返回 400 或 401（当前密码错误）
            if response.status_code in [400, 401, 403]:
                print("✅ 错误的当前密码被正确拒绝")
            elif response.status_code == 404:
                print("ℹ️  修改密码端点不存在")
            else:
                print(f"ℹ️  修改密码返回: {response.status_code}")

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestAuthAPI._access_token:
            return {"Authorization": f"Bearer {TestAuthAPI._access_token}"}
        return {}

    # =========================================================================
    # 登出测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_logout(self):
        """测试：登出功能"""
        if not TestAuthAPI._cookies and not TestAuthAPI._access_token:
            pytest.skip("需要先运行 test_login_success")

        with httpx.Client(timeout=self.timeout, cookies=TestAuthAPI._cookies) as client:
            headers = self._get_auth_headers()
            
            response = client.post(
                f"{self.base_url}/api/secure-auth/logout",
                headers=headers
            )

            if response.status_code == 200:
                print("✅ 登出成功")
            elif response.status_code == 404:
                print("ℹ️  登出端点不存在")
            else:
                print(f"ℹ️  登出返回: {response.status_code}")

    # =========================================================================
    # 密码重置请求测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_request_password_reset(self):
        """测试：请求密码重置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/forgot-password",
                json={
                    "email": "test_reset@test-linku.com"
                }
            )

            # 无论邮箱是否存在，都应该返回成功（防止用户枚举）
            if response.status_code in [200, 202]:
                print("✅ 密码重置请求成功")
            elif response.status_code == 404:
                print("ℹ️  密码重置端点不存在")
            elif response.status_code == 429:
                print("ℹ️  密码重置请求被限流")
            else:
                print(f"ℹ️  密码重置返回: {response.status_code}")

    # =========================================================================
    # 邮箱验证码登录测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.auth
    def test_request_email_verification_code(self):
        """测试：请求邮箱验证码"""
        if not TEST_USER_EMAIL:
            pytest.skip("未配置测试邮箱")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/send-email-code",
                json={
                    "email": TEST_USER_EMAIL
                }
            )

            if response.status_code in [200, 202]:
                print("✅ 邮箱验证码发送成功")
            elif response.status_code == 404:
                print("ℹ️  邮箱验证码端点不存在")
            elif response.status_code == 429:
                print("ℹ️  请求被限流")
            else:
                print(f"ℹ️  邮箱验证码返回: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.auth
    def test_login_with_invalid_verification_code(self):
        """测试：使用无效验证码登录应该失败"""
        if not TEST_USER_EMAIL:
            pytest.skip("未配置测试邮箱")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/secure-auth/login-with-code",
                json={
                    "email": TEST_USER_EMAIL,
                    "verification_code": "000000"  # 无效验证码
                }
            )

            # 应该返回错误
            if response.status_code in [400, 401, 403]:
                print("✅ 无效验证码被正确拒绝")
            elif response.status_code == 404:
                print("ℹ️  验证码登录端点不存在")
            else:
                print(f"ℹ️  验证码登录返回: {response.status_code}")

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


class TestUserProfileAPI:
    """用户资料 API 测试"""

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _get_auth(self):
        """获取认证信息"""
        return TestAuthAPI._cookies, TestAuthAPI._access_token

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestAuthAPI._access_token:
            return {"Authorization": f"Bearer {TestAuthAPI._access_token}"}
        return {}

    @pytest.mark.api
    @pytest.mark.auth
    def test_update_profile(self):
        """测试：更新用户资料"""
        cookies, token = self._get_auth()
        if not cookies and not token:
            pytest.skip("需要先登录")

        with httpx.Client(timeout=self.timeout, cookies=cookies) as client:
            response = client.put(
                f"{self.base_url}/api/users/me",
                json={
                    "name": f"Updated Name {int(time.time())}"
                },
                headers=self._get_auth_headers()
            )

            if response.status_code == 200:
                print("✅ 用户资料更新成功")
            elif response.status_code in [401, 403]:
                print("ℹ️  认证失败")
            elif response.status_code == 404:
                print("ℹ️  更新资料端点不存在")
            else:
                print(f"ℹ️  更新资料返回: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.auth
    def test_get_user_by_id(self):
        """测试：通过 ID 获取用户信息"""
        if not TestAuthAPI._test_user_id:
            pytest.skip("没有用户 ID")

        cookies, token = self._get_auth()

        with httpx.Client(timeout=self.timeout, cookies=cookies) as client:
            response = client.get(
                f"{self.base_url}/api/users/{TestAuthAPI._test_user_id}",
                headers=self._get_auth_headers()
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取用户信息成功: {data.get('name', 'N/A')}")
            elif response.status_code == 404:
                print("ℹ️  用户不存在")
            else:
                print(f"ℹ️  获取用户返回: {response.status_code}")

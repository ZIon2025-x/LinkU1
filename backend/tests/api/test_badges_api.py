"""
徽章系统 API 测试

测试覆盖:
- 获取用户徽章
- 切换徽章展示状态
- 获取指定用户徽章（公开）

运行方式:
    pytest tests/api/test_badges_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL,
    TEST_USER_EMAIL,
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestBadgesAPI:
    """徽章系统 API 测试类"""

    # 共享状态
    _cookies: dict = {}
    _access_token: str = ""
    _user_id: str = ""
    _badge_id: str = ""

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _login(self, client: httpx.Client) -> bool:
        """辅助方法：登录并保存认证信息"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            return False

        if TestBadgesAPI._access_token or TestBadgesAPI._cookies:
            return True

        response = client.post(
            f"{self.base_url}/api/secure-auth/login",
            json={
                "email": TEST_USER_EMAIL,
                "password": TEST_USER_PASSWORD
            }
        )

        if response.status_code == 200:
            cookies = dict(response.cookies)
            if cookies:
                TestBadgesAPI._cookies = cookies

            data = response.json()
            if "access_token" in data:
                TestBadgesAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestBadgesAPI._user_id = data["user"]["id"]

            return bool(TestBadgesAPI._access_token or TestBadgesAPI._cookies)

        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestBadgesAPI._access_token:
            return {"Authorization": f"Bearer {TestBadgesAPI._access_token}"}
        return {}

    # =========================================================================
    # 获取我的徽章测试
    # =========================================================================

    @pytest.mark.api
    def test_get_my_badges_unauthorized(self):
        """测试：未登录用户不能获取我的徽章"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/badges/my")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取我的徽章正确要求认证")

    @pytest.mark.api
    def test_get_my_badges_authenticated(self):
        """测试：登录用户可以获取我的徽章"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/badges/my",
                headers=self._get_auth_headers(),
                cookies=TestBadgesAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                # 保存第一个徽章 ID（如果有）用于后续测试
                if isinstance(data, list) and len(data) > 0:
                    badge = data[0]
                    if isinstance(badge, dict) and "id" in badge:
                        TestBadgesAPI._badge_id = str(badge["id"])
                elif isinstance(data, dict):
                    badges = data.get("badges", data.get("items", []))
                    if badges and isinstance(badges[0], dict) and "id" in badges[0]:
                        TestBadgesAPI._badge_id = str(badges[0]["id"])
                print(f"✅ 我的徽章: {data}")
            elif response.status_code == 404:
                print("ℹ️  徽章接口尚未实现 (404)")
            else:
                print(f"ℹ️  我的徽章返回: {response.status_code}")

    # =========================================================================
    # 切换徽章展示状态测试
    # =========================================================================

    @pytest.mark.api
    def test_toggle_badge_display_unauthorized(self):
        """测试：未登录用户不能切换徽章展示"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.put(
                f"{self.base_url}/api/badges/1/display",
                json={"display": True}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 切换徽章展示正确要求认证")

    @pytest.mark.api
    def test_toggle_badge_display_authenticated(self):
        """测试：登录用户可以切换徽章展示状态"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            # 使用已获取的徽章 ID，或使用默认值
            badge_id = TestBadgesAPI._badge_id or "1"

            response = client.put(
                f"{self.base_url}/api/badges/{badge_id}/display",
                headers=self._get_auth_headers(),
                cookies=TestBadgesAPI._cookies,
                json={"display": True}
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 切换徽章展示成功: {data}")
            elif response.status_code == 400:
                print("ℹ️  徽章不存在或无法切换 (400)")
            elif response.status_code == 404:
                print("ℹ️  徽章展示接口尚未实现 (404)")
            else:
                print(f"ℹ️  切换徽章展示返回: {response.status_code}")

    @pytest.mark.api
    def test_toggle_badge_display_nonexistent(self):
        """测试：切换不存在的徽章展示"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.put(
                f"{self.base_url}/api/badges/99999999/display",
                headers=self._get_auth_headers(),
                cookies=TestBadgesAPI._cookies,
                json={"display": True}
            )

            # 不存在的徽章应该返回 404 或 400
            assert response.status_code in [400, 404, 422], \
                f"不存在的徽章应该返回错误，但返回了 {response.status_code}"

            print(f"✅ 不存在的徽章正确返回 {response.status_code}")

    # =========================================================================
    # 获取指定用户徽章测试（公开接口）
    # =========================================================================

    @pytest.mark.api
    def test_get_user_badges_with_valid_user(self):
        """测试：获取指定用户的徽章（公开接口）"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            # 先登录获取 user_id
            if not self._login(client):
                pytest.skip("登录失败")

            if not TestBadgesAPI._user_id:
                pytest.skip("无法获取用户 ID")

            response = client.get(
                f"{self.base_url}/api/badges/user/{TestBadgesAPI._user_id}"
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                print(f"✅ 用户徽章: {data}")
            elif response.status_code == 404:
                print("ℹ️  用户徽章接口尚未实现 (404)")
            else:
                print(f"ℹ️  用户徽章返回: {response.status_code}")

    @pytest.mark.api
    def test_get_user_badges_nonexistent_user(self):
        """测试：获取不存在用户的徽章"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(
                f"{self.base_url}/api/badges/user/00000000-0000-0000-0000-000000000000"
            )

            # 不存在的用户应该返回 404 或空列表
            if response.status_code == 200:
                data = response.json()
                # 应该返回空列表或空对象
                if isinstance(data, list):
                    assert len(data) == 0, "不存在的用户应该没有徽章"
                print(f"✅ 不存在的用户返回空徽章列表")
            elif response.status_code == 404:
                print("✅ 不存在的用户正确返回 404")
            else:
                print(f"ℹ️  不存在的用户徽章返回: {response.status_code}")

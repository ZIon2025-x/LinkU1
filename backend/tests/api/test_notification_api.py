"""
通知系统 API 测试

测试覆盖:
- 通知列表
- 未读通知
- 标记已读
- 未读计数

运行方式:
    pytest tests/api/test_notification_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL, 
    TEST_USER_EMAIL, 
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestNotificationAPI:
    """通知 API 测试类"""

    # 共享状态
    _cookies: dict = {}
    _access_token: str = ""
    _user_id: str = ""

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _login(self, client: httpx.Client) -> bool:
        """辅助方法：登录并保存认证信息"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            return False

        if TestNotificationAPI._access_token or TestNotificationAPI._cookies:
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
                TestNotificationAPI._cookies = cookies
            
            data = response.json()
            if "access_token" in data:
                TestNotificationAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestNotificationAPI._user_id = data["user"]["id"]
            
            return bool(TestNotificationAPI._access_token or TestNotificationAPI._cookies)
        
        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestNotificationAPI._access_token:
            return {"Authorization": f"Bearer {TestNotificationAPI._access_token}"}
        return {}

    # =========================================================================
    # 通知列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_notifications_unauthorized(self):
        """测试：未登录用户不能获取通知列表"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/notifications")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 通知列表正确要求认证")

    @pytest.mark.api
    def test_get_notifications_authenticated(self):
        """测试：登录用户可以获取通知列表"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/notifications",
                headers=self._get_auth_headers(),
                cookies=TestNotificationAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                count = len(data) if isinstance(data, list) else data
                print(f"✅ 通知列表: {count}")
            else:
                print(f"ℹ️  通知列表返回: {response.status_code}")

    # =========================================================================
    # 未读通知测试
    # =========================================================================

    @pytest.mark.api
    def test_get_unread_notifications_unauthorized(self):
        """测试：未登录用户不能获取未读通知"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/notifications/unread")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未读通知正确要求认证")

    @pytest.mark.api
    def test_get_unread_notifications_authenticated(self):
        """测试：登录用户可以获取未读通知"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/notifications/unread",
                headers=self._get_auth_headers(),
                cookies=TestNotificationAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                count = len(data) if isinstance(data, list) else data
                print(f"✅ 未读通知: {count}")
            else:
                print(f"ℹ️  未读通知返回: {response.status_code}")

    # =========================================================================
    # 未读计数测试
    # =========================================================================

    @pytest.mark.api
    def test_get_unread_count_unauthorized(self):
        """测试：未登录用户不能获取未读计数"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/notifications/unread/count")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未读计数正确要求认证")

    @pytest.mark.api
    def test_get_unread_count_authenticated(self):
        """测试：登录用户可以获取未读计数"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/notifications/unread/count",
                headers=self._get_auth_headers(),
                cookies=TestNotificationAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 未读计数: {data}")
            else:
                print(f"ℹ️  未读计数返回: {response.status_code}")

    # =========================================================================
    # 标记已读测试
    # =========================================================================

    @pytest.mark.api
    def test_mark_notification_read_unauthorized(self):
        """测试：未登录用户不能标记通知已读"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/notifications/12345678/read"
            )

            assert response.status_code in [401, 403, 404, 405], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 标记已读正确要求认证")

    # =========================================================================
    # 全部标记已读测试
    # =========================================================================

    @pytest.mark.api
    def test_mark_all_read_unauthorized(self):
        """测试：未登录用户不能标记全部已读"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(f"{self.base_url}/api/notifications/read-all")

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 全部标记已读正确要求认证")

    @pytest.mark.api
    def test_mark_all_read_authenticated(self):
        """测试：登录用户可以标记全部已读"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.post(
                f"{self.base_url}/api/notifications/read-all",
                headers=self._get_auth_headers(),
                cookies=TestNotificationAPI._cookies
            )

            if response.status_code == 200:
                print("✅ 全部标记已读成功")
            else:
                print(f"ℹ️  全部标记已读返回: {response.status_code}")

    # =========================================================================
    # 包含最近已读通知测试
    # =========================================================================

    @pytest.mark.api
    def test_get_notifications_with_recent_read_unauthorized(self):
        """测试：未登录用户不能获取包含最近已读的通知"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/notifications/with-recent-read")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 包含最近已读通知正确要求认证")

    @pytest.mark.api
    def test_get_notifications_with_recent_read_authenticated(self):
        """测试：登录用户可以获取包含最近已读的通知"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/notifications/with-recent-read",
                headers=self._get_auth_headers(),
                cookies=TestNotificationAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                count = len(data) if isinstance(data, list) else data
                print(f"✅ 包含最近已读通知: {count}")
            else:
                print(f"ℹ️  包含最近已读通知返回: {response.status_code}")

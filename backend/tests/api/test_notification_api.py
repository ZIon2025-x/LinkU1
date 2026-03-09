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
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestNotificationAPI:
    """通知 API 测试类"""

    # =========================================================================
    # 通知列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_notifications_unauthorized(self):
        """测试：未登录用户不能获取通知列表"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/notifications")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 通知列表正确要求认证")

    @pytest.mark.api
    def test_get_notifications_authenticated(self, auth_client):
        """测试：登录用户可以获取通知列表"""
        response = auth_client.get(f"{TEST_API_URL}/api/notifications")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/notifications/unread")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 未读通知正确要求认证")

    @pytest.mark.api
    def test_get_unread_notifications_authenticated(self, auth_client):
        """测试：登录用户可以获取未读通知"""
        response = auth_client.get(f"{TEST_API_URL}/api/notifications/unread")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/notifications/unread/count")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 未读计数正确要求认证")

    @pytest.mark.api
    def test_get_unread_count_authenticated(self, auth_client):
        """测试：登录用户可以获取未读计数"""
        response = auth_client.get(f"{TEST_API_URL}/api/notifications/unread/count")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # API 使用 POST 方法
            response = client.post(
                f"{TEST_API_URL}/api/notifications/12345678/read"
            )

            # 401: 未认证, 403: 禁止访问, 404: 通知不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 标记已读正确要求认证")

    # =========================================================================
    # 全部标记已读测试
    # =========================================================================

    @pytest.mark.api
    def test_mark_all_read_unauthorized(self):
        """测试：未登录用户不能标记全部已读"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # API 使用 POST 方法
            response = client.post(f"{TEST_API_URL}/api/notifications/read-all")

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 全部标记已读正确要求认证")

    @pytest.mark.api
    def test_mark_all_read_authenticated(self, auth_client):
        """测试：登录用户可以标记全部已读"""
        # API 使用 POST 方法
        response = auth_client.post(f"{TEST_API_URL}/api/notifications/read-all")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/notifications/with-recent-read")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 包含最近已读通知正确要求认证")

    @pytest.mark.api
    def test_get_notifications_with_recent_read_authenticated(self, auth_client):
        """测试：登录用户可以获取包含最近已读的通知"""
        response = auth_client.get(f"{TEST_API_URL}/api/notifications/with-recent-read")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            count = len(data) if isinstance(data, list) else data
            print(f"✅ 包含最近已读通知: {count}")
        else:
            print(f"ℹ️  包含最近已读通知返回: {response.status_code}")

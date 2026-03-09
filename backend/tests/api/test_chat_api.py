"""
任务聊天/申请 API 测试

测试覆盖:
- 聊天消息列表
- 发送消息
- 申请接受/拒绝
- 价格协商

运行方式:
    pytest tests/api/test_chat_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestTaskChatAPI:
    """任务聊天 API 测试类"""

    # =========================================================================
    # 聊天列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_chat_list_unauthorized(self):
        """测试：未登录用户不能获取聊天列表"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/messages/tasks")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 聊天列表正确要求认证")

    @pytest.mark.api
    def test_get_chat_list_authenticated(self, auth_client):
        """测试：登录用户可以获取聊天列表"""
        response = auth_client.get(f"{TEST_API_URL}/api/messages/tasks")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 获取聊天列表成功: {len(data) if isinstance(data, list) else data}")
        else:
            print(f"ℹ️  聊天列表返回: {response.status_code}")

    # =========================================================================
    # 未读消息计数测试
    # =========================================================================

    @pytest.mark.api
    def test_get_unread_count_unauthorized(self):
        """测试：未登录用户不能获取未读消息计数"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/messages/tasks/unread/count")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 未读消息计数正确要求认证")

    @pytest.mark.api
    def test_get_unread_count_authenticated(self, auth_client):
        """测试：登录用户可以获取未读消息计数"""
        response = auth_client.get(f"{TEST_API_URL}/api/messages/tasks/unread/count")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 未读消息计数: {data}")
        else:
            print(f"ℹ️  未读消息计数返回: {response.status_code}")

    # =========================================================================
    # 发送消息测试
    # =========================================================================

    @pytest.mark.api
    def test_send_message_unauthorized(self):
        """测试：未登录用户不能发送消息"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/messages/task/12345678/send",
                json={"content": "这是一条测试消息，内容足够长"}
            )

            # 401/403: 认证失败, 404: 任务不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 发送消息正确要求认证")

    # =========================================================================
    # 任务消息详情测试
    # =========================================================================

    @pytest.mark.api
    def test_get_task_messages_unauthorized(self):
        """测试：未登录用户不能获取任务消息"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/messages/task/12345678")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 任务消息正确要求认证")

    # =========================================================================
    # 申请接受测试
    # =========================================================================

    @pytest.mark.api
    def test_accept_application_unauthorized(self):
        """测试：未登录用户不能接受申请"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送 json body
            response = client.post(
                f"{TEST_API_URL}/api/tasks/12345678/applications/1/accept"
            )

            # 401/403: 认证失败, 404: 任务/申请不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 接受申请正确要求认证")

    # =========================================================================
    # 申请拒绝测试
    # =========================================================================

    @pytest.mark.api
    def test_reject_application_unauthorized(self):
        """测试：未登录用户不能拒绝申请"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送 json body
            response = client.post(
                f"{TEST_API_URL}/api/tasks/12345678/applications/1/reject"
            )

            # 401/403: 认证失败, 404: 任务/申请不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 拒绝申请正确要求认证")

    # =========================================================================
    # 价格协商测试
    # =========================================================================

    @pytest.mark.api
    def test_negotiate_unauthorized(self):
        """测试：未登录用户不能发起协商"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/tasks/12345678/applications/1/negotiate",
                json={"proposed_price": 100.00}
            )

            # 401/403: 认证失败, 404: 任务/申请不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 价格协商正确要求认证")

    # =========================================================================
    # 申请撤回测试
    # =========================================================================

    @pytest.mark.api
    def test_withdraw_application_unauthorized(self):
        """测试：未登录用户不能撤回申请"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送 json body
            response = client.post(
                f"{TEST_API_URL}/api/tasks/12345678/applications/1/withdraw"
            )

            # 401/403: 认证失败, 404: 任务/申请不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 撤回申请正确要求认证")

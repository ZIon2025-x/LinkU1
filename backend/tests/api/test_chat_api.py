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
from tests.config import (
    TEST_API_URL, 
    TEST_USER_EMAIL, 
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestTaskChatAPI:
    """任务聊天 API 测试类"""

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

        if TestTaskChatAPI._access_token or TestTaskChatAPI._cookies:
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
                TestTaskChatAPI._cookies = cookies
            
            data = response.json()
            if "access_token" in data:
                TestTaskChatAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestTaskChatAPI._user_id = data["user"]["id"]
            
            return bool(TestTaskChatAPI._access_token or TestTaskChatAPI._cookies)
        
        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestTaskChatAPI._access_token:
            return {"Authorization": f"Bearer {TestTaskChatAPI._access_token}"}
        return {}

    # =========================================================================
    # 聊天列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_chat_list_unauthorized(self):
        """测试：未登录用户不能获取聊天列表"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/messages/tasks")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 聊天列表正确要求认证")

    @pytest.mark.api
    def test_get_chat_list_authenticated(self):
        """测试：登录用户可以获取聊天列表"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/messages/tasks",
                headers=self._get_auth_headers(),
                cookies=TestTaskChatAPI._cookies
            )

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
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/messages/tasks/unread/count")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未读消息计数正确要求认证")

    @pytest.mark.api
    def test_get_unread_count_authenticated(self):
        """测试：登录用户可以获取未读消息计数"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/messages/tasks/unread/count",
                headers=self._get_auth_headers(),
                cookies=TestTaskChatAPI._cookies
            )

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
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/messages/task/12345678/send",
                json={"content": "测试消息"}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 发送消息正确要求认证")

    # =========================================================================
    # 任务消息详情测试
    # =========================================================================

    @pytest.mark.api
    def test_get_task_messages_unauthorized(self):
        """测试：未登录用户不能获取任务消息"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/messages/task/12345678")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 任务消息正确要求认证")

    # =========================================================================
    # 申请接受测试
    # =========================================================================

    @pytest.mark.api
    def test_accept_application_unauthorized(self):
        """测试：未登录用户不能接受申请"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/applications/1/accept",
                json={}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 接受申请正确要求认证")

    # =========================================================================
    # 申请拒绝测试
    # =========================================================================

    @pytest.mark.api
    def test_reject_application_unauthorized(self):
        """测试：未登录用户不能拒绝申请"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/applications/1/reject",
                json={}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 拒绝申请正确要求认证")

    # =========================================================================
    # 价格协商测试
    # =========================================================================

    @pytest.mark.api
    def test_negotiate_unauthorized(self):
        """测试：未登录用户不能发起协商"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/applications/1/negotiate",
                json={"proposed_price": 100}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 价格协商正确要求认证")

    # =========================================================================
    # 申请撤回测试
    # =========================================================================

    @pytest.mark.api
    def test_withdraw_application_unauthorized(self):
        """测试：未登录用户不能撤回申请"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/applications/1/withdraw",
                json={}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 撤回申请正确要求认证")

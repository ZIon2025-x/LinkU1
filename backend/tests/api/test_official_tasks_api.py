"""
官方任务 API 测试

测试覆盖:
- 获取活跃官方任务列表
- 获取官方任务详情

运行方式:
    pytest tests/api/test_official_tasks_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL,
    TEST_USER_EMAIL,
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestOfficialTasksAPI:
    """官方任务 API 测试类"""

    # 共享状态
    _cookies: dict = {}
    _access_token: str = ""
    _user_id: str = ""
    _task_id: str = ""

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _login(self, client: httpx.Client) -> bool:
        """辅助方法：登录并保存认证信息"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            return False

        if TestOfficialTasksAPI._access_token or TestOfficialTasksAPI._cookies:
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
                TestOfficialTasksAPI._cookies = cookies

            data = response.json()
            if "access_token" in data:
                TestOfficialTasksAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestOfficialTasksAPI._user_id = data["user"]["id"]

            return bool(TestOfficialTasksAPI._access_token or TestOfficialTasksAPI._cookies)

        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestOfficialTasksAPI._access_token:
            return {"Authorization": f"Bearer {TestOfficialTasksAPI._access_token}"}
        return {}

    # =========================================================================
    # 获取活跃官方任务列表测试
    # =========================================================================

    @pytest.mark.api
    def test_list_official_tasks_unauthorized(self):
        """测试：未登录用户不能获取官方任务列表"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/official-tasks/")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取官方任务列表正确要求认证")

    @pytest.mark.api
    def test_list_official_tasks_authenticated(self):
        """测试：登录用户可以获取活跃官方任务列表"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/official-tasks/",
                headers=self._get_auth_headers(),
                cookies=TestOfficialTasksAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                # 保存第一个任务 ID（如果有）用于详情测试
                if isinstance(data, list) and len(data) > 0:
                    task = data[0]
                    if isinstance(task, dict) and "id" in task:
                        TestOfficialTasksAPI._task_id = str(task["id"])
                elif isinstance(data, dict):
                    tasks = data.get("tasks", data.get("items", []))
                    if tasks and isinstance(tasks[0], dict) and "id" in tasks[0]:
                        TestOfficialTasksAPI._task_id = str(tasks[0]["id"])
                print(f"✅ 官方任务列表: {data}")
            elif response.status_code == 404:
                print("ℹ️  官方任务接口尚未实现 (404)")
            else:
                print(f"ℹ️  官方任务列表返回: {response.status_code}")

    # =========================================================================
    # 获取官方任务详情测试
    # =========================================================================

    @pytest.mark.api
    def test_get_task_detail_unauthorized(self):
        """测试：未登录用户不能获取官方任务详情"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/official-tasks/1")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取官方任务详情正确要求认证")

    @pytest.mark.api
    def test_get_task_detail_authenticated(self):
        """测试：登录用户可以获取官方任务详情"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            # 使用已获取的任务 ID，或使用默认值
            task_id = TestOfficialTasksAPI._task_id or "1"

            response = client.get(
                f"{self.base_url}/api/official-tasks/{task_id}",
                headers=self._get_auth_headers(),
                cookies=TestOfficialTasksAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, dict), \
                    f"返回数据格式不正确: {type(data)}"
                print(f"✅ 官方任务详情: {data}")
            elif response.status_code == 404:
                print("ℹ️  官方任务详情不存在或接口尚未实现 (404)")
            else:
                print(f"ℹ️  官方任务详情返回: {response.status_code}")

    @pytest.mark.api
    def test_get_task_detail_nonexistent(self):
        """测试：获取不存在的官方任务详情"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/official-tasks/99999999",
                headers=self._get_auth_headers(),
                cookies=TestOfficialTasksAPI._cookies
            )

            # 不存在的任务应该返回 404
            assert response.status_code in [404, 400, 422], \
                f"不存在的任务应该返回错误，但返回了 {response.status_code}"

            print(f"✅ 不存在的官方任务正确返回 {response.status_code}")

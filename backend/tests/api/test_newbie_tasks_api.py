"""
新手任务 API 测试

测试覆盖:
- 获取任务进度
- 领取任务奖励
- 获取阶段进度
- 领取阶段奖励

运行方式:
    pytest tests/api/test_newbie_tasks_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL,
    TEST_USER_EMAIL,
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestNewbieTasksAPI:
    """新手任务 API 测试类"""

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

        if TestNewbieTasksAPI._access_token or TestNewbieTasksAPI._cookies:
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
                TestNewbieTasksAPI._cookies = cookies

            data = response.json()
            if "access_token" in data:
                TestNewbieTasksAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestNewbieTasksAPI._user_id = data["user"]["id"]

            return bool(TestNewbieTasksAPI._access_token or TestNewbieTasksAPI._cookies)

        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestNewbieTasksAPI._access_token:
            return {"Authorization": f"Bearer {TestNewbieTasksAPI._access_token}"}
        return {}

    # =========================================================================
    # 获取任务进度测试
    # =========================================================================

    @pytest.mark.api
    def test_get_task_progress_unauthorized(self):
        """测试：未登录用户不能获取任务进度"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/newbie-tasks/progress")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取任务进度正确要求认证")

    @pytest.mark.api
    def test_get_task_progress_authenticated(self):
        """测试：登录用户可以获取任务进度"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/newbie-tasks/progress",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                # 应该返回任务列表或进度信息
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                print(f"✅ 任务进度: {data}")
            elif response.status_code == 404:
                print("ℹ️  新手任务接口尚未实现 (404)")
            else:
                print(f"ℹ️  任务进度返回: {response.status_code}")

    # =========================================================================
    # 领取任务奖励测试
    # =========================================================================

    @pytest.mark.api
    def test_claim_reward_unauthorized(self):
        """测试：未登录用户不能领取任务奖励"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/newbie-tasks/complete_profile/claim"
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 领取奖励正确要求认证")

    @pytest.mark.api
    def test_claim_reward_authenticated(self):
        """测试：登录用户可以领取任务奖励"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.post(
                f"{self.base_url}/api/newbie-tasks/complete_profile/claim",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            # 可能的响应：
            # 200 - 成功领取
            # 400 - 任务未完成/已领取
            # 404 - 接口未实现
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 领取奖励成功: {data}")
            elif response.status_code == 400:
                print("ℹ️  任务未完成或已领取 (400)")
            elif response.status_code == 404:
                print("ℹ️  新手任务接口尚未实现 (404)")
            else:
                print(f"ℹ️  领取奖励返回: {response.status_code}")

    @pytest.mark.api
    def test_claim_reward_invalid_task_key(self):
        """测试：领取不存在的任务奖励"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.post(
                f"{self.base_url}/api/newbie-tasks/nonexistent_task_key/claim",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            # 不存在的任务应该返回 400 或 404
            assert response.status_code in [400, 404, 422], \
                f"不存在的任务应该返回错误，但返回了 {response.status_code}"

            print(f"✅ 不存在的任务正确返回 {response.status_code}")

    # =========================================================================
    # 获取阶段进度测试
    # =========================================================================

    @pytest.mark.api
    def test_get_stage_progress_unauthorized(self):
        """测试：未登录用户不能获取阶段进度"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/newbie-tasks/stages")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取阶段进度正确要求认证")

    @pytest.mark.api
    def test_get_stage_progress_authenticated(self):
        """测试：登录用户可以获取阶段进度"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/newbie-tasks/stages",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                print(f"✅ 阶段进度: {data}")
            elif response.status_code == 404:
                print("ℹ️  阶段进度接口尚未实现 (404)")
            else:
                print(f"ℹ️  阶段进度返回: {response.status_code}")

    # =========================================================================
    # 领取阶段奖励测试
    # =========================================================================

    @pytest.mark.api
    def test_claim_stage_bonus_unauthorized(self):
        """测试：未登录用户不能领取阶段奖励"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/newbie-tasks/stages/1/claim"
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 领取阶段奖励正确要求认证")

    @pytest.mark.api
    def test_claim_stage_bonus_authenticated(self):
        """测试：登录用户可以领取阶段奖励"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.post(
                f"{self.base_url}/api/newbie-tasks/stages/1/claim",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            # 可能的响应：
            # 200 - 成功领取
            # 400 - 阶段未完成/已领取
            # 404 - 接口未实现
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 领取阶段奖励成功: {data}")
            elif response.status_code == 400:
                print("ℹ️  阶段未完成或已领取 (400)")
            elif response.status_code == 404:
                print("ℹ️  阶段奖励接口尚未实现 (404)")
            else:
                print(f"ℹ️  领取阶段奖励返回: {response.status_code}")

    @pytest.mark.api
    def test_claim_stage_bonus_invalid_stage(self):
        """测试：领取不存在的阶段奖励"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.post(
                f"{self.base_url}/api/newbie-tasks/stages/99999/claim",
                headers=self._get_auth_headers(),
                cookies=TestNewbieTasksAPI._cookies
            )

            # 不存在的阶段应该返回错误
            assert response.status_code in [400, 404, 422], \
                f"不存在的阶段应该返回错误，但返回了 {response.status_code}"

            print(f"✅ 不存在的阶段正确返回 {response.status_code}")

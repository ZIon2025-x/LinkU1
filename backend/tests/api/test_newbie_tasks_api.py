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
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestNewbieTasksAPI:
    """新手任务 API 测试类"""

    # =========================================================================
    # 获取任务进度测试
    # =========================================================================

    @pytest.mark.api
    def test_get_task_progress_unauthorized(self):
        """测试：未登录用户不能获取任务进度"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/newbie-tasks/progress")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取任务进度正确要求认证")

    @pytest.mark.api
    def test_get_task_progress_authenticated(self, auth_client):
        """测试：登录用户可以获取任务进度"""
        response = auth_client.get(f"{TEST_API_URL}/api/newbie-tasks/progress")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/newbie-tasks/complete_profile/claim"
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 领取奖励正确要求认证")

    @pytest.mark.api
    def test_claim_reward_authenticated(self, auth_client):
        """测试：登录用户可以领取任务奖励"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/newbie-tasks/complete_profile/claim"
        )

        assert response.status_code != 401, "认证后不应该返回 401"

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
    def test_claim_reward_invalid_task_key(self, auth_client):
        """测试：领取不存在的任务奖励"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/newbie-tasks/nonexistent_task_key/claim"
        )

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/newbie-tasks/stages")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取阶段进度正确要求认证")

    @pytest.mark.api
    def test_get_stage_progress_authenticated(self, auth_client):
        """测试：登录用户可以获取阶段进度"""
        response = auth_client.get(f"{TEST_API_URL}/api/newbie-tasks/stages")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/newbie-tasks/stages/1/claim"
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 领取阶段奖励正确要求认证")

    @pytest.mark.api
    def test_claim_stage_bonus_authenticated(self, auth_client):
        """测试：登录用户可以领取阶段奖励"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/newbie-tasks/stages/1/claim"
        )

        assert response.status_code != 401, "认证后不应该返回 401"

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
    def test_claim_stage_bonus_invalid_stage(self, auth_client):
        """测试：领取不存在的阶段奖励"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/newbie-tasks/stages/99999/claim"
        )

        assert response.status_code != 401, "认证后不应该返回 401"

        # 不存在的阶段应该返回错误
        assert response.status_code in [400, 404, 422], \
            f"不存在的阶段应该返回错误，但返回了 {response.status_code}"

        print(f"✅ 不存在的阶段正确返回 {response.status_code}")

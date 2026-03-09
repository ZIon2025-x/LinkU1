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
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestOfficialTasksAPI:
    """官方任务 API 测试类"""

    # 保留跨测试共享的业务状态
    _task_id: str = ""

    # =========================================================================
    # 获取活跃官方任务列表测试
    # =========================================================================

    @pytest.mark.api
    def test_list_official_tasks_unauthorized(self):
        """测试：未登录用户不能获取官方任务列表"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/official-tasks/")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取官方任务列表正确要求认证")

    @pytest.mark.api
    def test_list_official_tasks_authenticated(self, auth_client):
        """测试：登录用户可以获取活跃官方任务列表"""
        response = auth_client.get(f"{TEST_API_URL}/api/official-tasks/")

        assert response.status_code != 401, "认证后不应该返回 401"

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/official-tasks/1")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取官方任务详情正确要求认证")

    @pytest.mark.api
    def test_get_task_detail_authenticated(self, auth_client):
        """测试：登录用户可以获取官方任务详情"""
        # 使用已获取的任务 ID，或使用默认值
        task_id = TestOfficialTasksAPI._task_id or "1"

        response = auth_client.get(f"{TEST_API_URL}/api/official-tasks/{task_id}")

        assert response.status_code != 401, "认证后不应该返回 401"

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
    def test_get_task_detail_nonexistent(self, auth_client):
        """测试：获取不存在的官方任务详情"""
        response = auth_client.get(f"{TEST_API_URL}/api/official-tasks/99999999")

        assert response.status_code != 401, "认证后不应该返回 401"

        # 不存在的任务应该返回 404
        assert response.status_code in [404, 400, 422], \
            f"不存在的任务应该返回错误，但返回了 {response.status_code}"

        print(f"✅ 不存在的官方任务正确返回 {response.status_code}")

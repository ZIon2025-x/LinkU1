"""
管理员激励系统 API 测试

测试覆盖:
- 新手任务配置 CRUD
- 阶段奖励配置 CRUD
- 签到奖励配置 CRUD
- 权限控制（未授权访问）

运行方式:
    pytest tests/api/test_admin_incentive_api.py -v
"""

import os
import pytest
import httpx
from tests.config import (
    TEST_API_URL,
    REQUEST_TIMEOUT
)

# 管理员测试凭据（可选）
TEST_ADMIN_USERNAME = os.getenv("TEST_ADMIN_USERNAME", "").strip()
TEST_ADMIN_PASSWORD = os.getenv("TEST_ADMIN_PASSWORD", "").strip()


class TestAdminNewbieTasksAPI:
    """管理员新手任务配置 API 测试类"""

    _session_cookies: dict = {}

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _admin_login(self, client: httpx.Client) -> bool:
        """管理员登录"""
        if not TEST_ADMIN_USERNAME or not TEST_ADMIN_PASSWORD:
            return False

        if TestAdminNewbieTasksAPI._session_cookies:
            return True

        response = client.post(
            f"{self.base_url}/api/auth/admin/login",
            json={
                "username_or_id": TEST_ADMIN_USERNAME,
                "password": TEST_ADMIN_PASSWORD
            }
        )

        if response.status_code == 200:
            cookies = dict(response.cookies)
            if cookies:
                TestAdminNewbieTasksAPI._session_cookies = cookies
            return True

        return False

    # =========================================================================
    # 新手任务配置 - 权限测试
    # =========================================================================

    @pytest.mark.api
    def test_list_newbie_tasks_config_unauthorized(self):
        """测试：未登录不能获取新手任务配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/newbie-tasks/config")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 新手任务配置正确要求管理员认证")

    @pytest.mark.api
    def test_update_newbie_task_config_unauthorized(self):
        """测试：未登录不能修改新手任务配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.put(
                f"{self.base_url}/api/admin/newbie-tasks/config/upload_avatar",
                json={"reward_amount": 999}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 修改新手任务配置正确要求管理员认证")

    # =========================================================================
    # 新手任务配置 - 功能测试（需要管理员账号）
    # =========================================================================

    @pytest.mark.api
    def test_list_newbie_tasks_config_authenticated(self):
        """测试：管理员可以获取新手任务配置列表"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号 (TEST_ADMIN_USERNAME)")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.get(
                f"{self.base_url}/api/admin/newbie-tasks/config",
                cookies=TestAdminNewbieTasksAPI._session_cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list), f"应返回列表，实际: {type(data)}"

                if data:
                    task = data[0]
                    # 验证返回的字段结构
                    assert "task_key" in task, "缺少 task_key 字段"
                    assert "stage" in task, "缺少 stage 字段"
                    assert "title_zh" in task, "缺少 title_zh 字段"
                    assert "title_en" in task, "缺少 title_en 字段"
                    assert "reward_amount" in task, "缺少 reward_amount 字段"
                    assert "is_active" in task, "缺少 is_active 字段"

                print(f"✅ 获取到 {len(data)} 个新手任务配置")
            else:
                print(f"ℹ️  新手任务配置返回: {response.status_code}")

    @pytest.mark.api
    def test_update_nonexistent_task_config(self):
        """测试：修改不存在的任务配置应返回 404"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.put(
                f"{self.base_url}/api/admin/newbie-tasks/config/nonexistent_key_99999",
                json={"reward_amount": 100},
                cookies=TestAdminNewbieTasksAPI._session_cookies
            )

            assert response.status_code in [404, 422], \
                f"不存在的任务应返回 404，但返回了 {response.status_code}"

            print(f"✅ 不存在的任务配置正确返回 {response.status_code}")


class TestAdminStageBonusAPI:
    """管理员阶段奖励配置 API 测试类"""

    _session_cookies: dict = {}

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _admin_login(self, client: httpx.Client) -> bool:
        """管理员登录"""
        if not TEST_ADMIN_USERNAME or not TEST_ADMIN_PASSWORD:
            return False

        if TestAdminStageBonusAPI._session_cookies:
            return True

        response = client.post(
            f"{self.base_url}/api/auth/admin/login",
            json={
                "username_or_id": TEST_ADMIN_USERNAME,
                "password": TEST_ADMIN_PASSWORD
            }
        )

        if response.status_code == 200:
            cookies = dict(response.cookies)
            if cookies:
                TestAdminStageBonusAPI._session_cookies = cookies
            return True

        return False

    # =========================================================================
    # 阶段奖励配置 - 权限测试
    # =========================================================================

    @pytest.mark.api
    def test_list_stage_bonus_config_unauthorized(self):
        """测试：未登录不能获取阶段奖励配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/stage-bonus/config")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 阶段奖励配置正确要求管理员认证")

    @pytest.mark.api
    def test_update_stage_bonus_config_unauthorized(self):
        """测试：未登录不能修改阶段奖励配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.put(
                f"{self.base_url}/api/admin/stage-bonus/config/1",
                json={"reward_amount": 999}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 修改阶段奖励配置正确要求管理员认证")

    # =========================================================================
    # 阶段奖励配置 - 功能测试
    # =========================================================================

    @pytest.mark.api
    def test_list_stage_bonus_config_authenticated(self):
        """测试：管理员可以获取阶段奖励配置列表"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.get(
                f"{self.base_url}/api/admin/stage-bonus/config",
                cookies=TestAdminStageBonusAPI._session_cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list), f"应返回列表，实际: {type(data)}"

                if data:
                    bonus = data[0]
                    assert "stage" in bonus, "缺少 stage 字段"
                    assert "reward_amount" in bonus, "缺少 reward_amount 字段"
                    assert "reward_type" in bonus, "缺少 reward_type 字段"
                    assert "is_active" in bonus, "缺少 is_active 字段"

                print(f"✅ 获取到 {len(data)} 个阶段奖励配置")
            else:
                print(f"ℹ️  阶段奖励配置返回: {response.status_code}")

    @pytest.mark.api
    def test_update_nonexistent_stage_bonus(self):
        """测试：修改不存在的阶段奖励应返回 404"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.put(
                f"{self.base_url}/api/admin/stage-bonus/config/99999",
                json={"reward_amount": 100},
                cookies=TestAdminStageBonusAPI._session_cookies
            )

            assert response.status_code in [404, 422], \
                f"不存在的阶段应返回 404，但返回了 {response.status_code}"

            print(f"✅ 不存在的阶段奖励正确返回 {response.status_code}")


class TestAdminCheckinRewardsAPI:
    """管理员签到奖励配置 API 测试类"""

    _session_cookies: dict = {}

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _admin_login(self, client: httpx.Client) -> bool:
        """管理员登录"""
        if not TEST_ADMIN_USERNAME or not TEST_ADMIN_PASSWORD:
            return False

        if TestAdminCheckinRewardsAPI._session_cookies:
            return True

        response = client.post(
            f"{self.base_url}/api/auth/admin/login",
            json={
                "username_or_id": TEST_ADMIN_USERNAME,
                "password": TEST_ADMIN_PASSWORD
            }
        )

        if response.status_code == 200:
            cookies = dict(response.cookies)
            if cookies:
                TestAdminCheckinRewardsAPI._session_cookies = cookies
            return True

        return False

    @pytest.mark.api
    def test_list_checkin_rewards_unauthorized(self):
        """测试：未登录不能获取签到奖励配置"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/checkin/rewards")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 签到奖励配置正确要求管理员认证")

    @pytest.mark.api
    def test_create_checkin_reward_unauthorized(self):
        """测试：未登录不能创建签到奖励"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/admin/checkin/rewards",
                json={
                    "consecutive_days": 999,
                    "reward_type": "points",
                    "points_reward": 100,
                }
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 创建签到奖励正确要求管理员认证")

    @pytest.mark.api
    def test_list_checkin_rewards_authenticated(self):
        """测试：管理员可以获取签到奖励列表"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.get(
                f"{self.base_url}/api/admin/checkin/rewards",
                cookies=TestAdminCheckinRewardsAPI._session_cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list), f"应返回列表，实际: {type(data)}"

                if data:
                    reward = data[0]
                    assert "consecutive_days" in reward, "缺少 consecutive_days 字段"
                    assert "reward_type" in reward, "缺少 reward_type 字段"
                    assert "is_active" in reward, "缺少 is_active 字段"

                print(f"✅ 获取到 {len(data)} 个签到奖励配置")
            else:
                print(f"ℹ️  签到奖励配置返回: {response.status_code}")


class TestAdminOfficialTasksAPI:
    """管理员官方任务 API 测试类"""

    _session_cookies: dict = {}

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _admin_login(self, client: httpx.Client) -> bool:
        """管理员登录"""
        if not TEST_ADMIN_USERNAME or not TEST_ADMIN_PASSWORD:
            return False

        if TestAdminOfficialTasksAPI._session_cookies:
            return True

        response = client.post(
            f"{self.base_url}/api/auth/admin/login",
            json={
                "username_or_id": TEST_ADMIN_USERNAME,
                "password": TEST_ADMIN_PASSWORD
            }
        )

        if response.status_code == 200:
            cookies = dict(response.cookies)
            if cookies:
                TestAdminOfficialTasksAPI._session_cookies = cookies
            return True

        return False

    @pytest.mark.api
    def test_list_official_tasks_admin_unauthorized(self):
        """测试：未登录不能获取管理员官方任务列表"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/official-tasks")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 管理员官方任务列表正确要求认证")

    @pytest.mark.api
    def test_create_official_task_unauthorized(self):
        """测试：未登录不能创建官方任务"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/admin/official-tasks",
                json={
                    "title_zh": "测试任务",
                    "title_en": "Test Task",
                    "task_type": "forum_post",
                    "reward_type": "points",
                    "reward_amount": 100,
                }
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 创建官方任务正确要求管理员认证")

    @pytest.mark.api
    def test_delete_official_task_unauthorized(self):
        """测试：未登录不能删除官方任务"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.delete(f"{self.base_url}/api/admin/official-tasks/1")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 删除官方任务正确要求管理员认证")

    @pytest.mark.api
    def test_list_official_tasks_admin_authenticated(self):
        """测试：管理员可以获取所有官方任务（含非活跃）"""
        if not TEST_ADMIN_USERNAME:
            pytest.skip("未配置管理员测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._admin_login(client):
                pytest.skip("管理员登录失败")

            response = client.get(
                f"{self.base_url}/api/admin/official-tasks",
                cookies=TestAdminOfficialTasksAPI._session_cookies
            )

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list), f"应返回列表，实际: {type(data)}"

                if data:
                    task = data[0]
                    assert "title_zh" in task, "缺少 title_zh 字段"
                    assert "title_en" in task, "缺少 title_en 字段"
                    assert "reward_type" in task, "缺少 reward_type 字段"
                    assert "is_active" in task, "缺少 is_active 字段"

                print(f"✅ 获取到 {len(data)} 个官方任务")
            else:
                print(f"ℹ️  管理员官方任务返回: {response.status_code}")


class TestAdminRewardsAPI:
    """管理员手动奖励 API 测试类"""

    _session_cookies: dict = {}

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    @pytest.mark.api
    def test_send_reward_unauthorized(self):
        """测试：未登录不能发送手动奖励"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/admin/rewards/send",
                json={
                    "user_id": "12345678",
                    "reward_type": "points",
                    "points_amount": 100,
                    "reason": "test"
                }
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 发送手动奖励正确要求管理员认证")

    @pytest.mark.api
    def test_reward_logs_unauthorized(self):
        """测试：未登录不能查看奖励日志"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/rewards/logs")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 奖励日志正确要求管理员认证")


class TestAdminLeaderboardAPI:
    """管理员排行榜刷新 API 测试类"""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    @pytest.mark.api
    def test_refresh_leaderboard_unauthorized(self):
        """测试：未登录不能刷新排行榜"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(f"{self.base_url}/api/admin/leaderboard/refresh")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 排行榜刷新正确要求管理员认证")


class TestAdminSkillCategoriesAPI:
    """管理员技能分类 API 测试类"""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    @pytest.mark.api
    def test_list_skill_categories_unauthorized(self):
        """测试：未登录不能获取技能分类"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/skill-categories")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 技能分类正确要求管理员认证")

    @pytest.mark.api
    def test_create_skill_category_unauthorized(self):
        """测试：未登录不能创建技能分类"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/admin/skill-categories",
                json={
                    "name_zh": "测试分类",
                    "name_en": "Test Category",
                    "icon": "test_icon",
                    "display_order": 999,
                }
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 创建技能分类正确要求管理员认证")

    @pytest.mark.api
    def test_delete_skill_category_unauthorized(self):
        """测试：未登录不能删除技能分类"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.delete(f"{self.base_url}/api/admin/skill-categories/1")

            assert response.status_code in [401, 403], \
                f"未授权请求应被拒绝，但返回了 {response.status_code}"

            print("✅ 删除技能分类正确要求管理员认证")

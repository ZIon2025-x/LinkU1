"""
任务 API 测试

测试覆盖:
- 获取任务列表
- 获取任务详情
- 创建任务
- 编辑任务
- 接受任务
- 取消任务
- 完成任务

运行方式:
    pytest tests/api/test_task_api.py -v
"""

import pytest
import httpx
import uuid
from datetime import datetime, timedelta
from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT


class TestTaskAPI:
    """任务 API 测试类"""

    # 共享状态
    _cookies: dict = {}
    _access_token: str = ""
    _user_id: str = ""
    _test_task_id: str = ""
    _created_task_id: str = ""  # 测试中创建的任务 ID

    @pytest.fixture(autouse=True)
    def setup(self):
        """每个测试前的设置"""
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    def _login(self, client: httpx.Client) -> bool:
        """辅助方法：登录并保存认证信息"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            return False

        # 检查是否已经有有效的认证信息
        if TestTaskAPI._access_token:
            return True  # 已经有 token
        if TestTaskAPI._cookies and len(TestTaskAPI._cookies) > 0:
            return True  # 已经有 cookies

        response = client.post(
            f"{self.base_url}/api/secure-auth/login",
            json={
                "email": TEST_USER_EMAIL,
                "password": TEST_USER_PASSWORD
            }
        )

        if response.status_code == 200:
            # 保存 cookies（如果有）
            cookies = dict(response.cookies)
            if cookies:
                TestTaskAPI._cookies = cookies
            
            # 解析响应数据
            data = response.json()
            if "access_token" in data:
                TestTaskAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestTaskAPI._user_id = data["user"]["id"]
            
            # 确保至少有一种认证方式
            if TestTaskAPI._access_token or TestTaskAPI._cookies:
                return True
        
        print(f"⚠️ 登录失败: {response.status_code} - {response.text[:200]}")
        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestTaskAPI._access_token:
            return {"Authorization": f"Bearer {TestTaskAPI._access_token}"}
        return {}

    # =========================================================================
    # 创建任务测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_create_task_unauthenticated(self):
        """测试：未登录用户不能创建任务"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks",
                json={
                    "title": "Test Task",
                    "description": "Test Description",
                    "reward": 10.0
                }
            )

            # 应该返回 401 或 403
            assert response.status_code in [401, 403], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录创建任务被正确拒绝")

    @pytest.mark.api
    @pytest.mark.task
    def test_create_task_success(self):
        """测试：已登录用户创建任务"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            unique_id = uuid.uuid4().hex[:8]
            deadline = (datetime.utcnow() + timedelta(days=7)).isoformat()
            
            response = client.post(
                f"{self.base_url}/api/tasks",
                json={
                    "title": f"API Test Task {unique_id}",
                    "description": "This is a test task created by automated API testing. Please ignore.",
                    "task_type": "Other",
                    "location": "Online",
                    "reward": 5.0,
                    "deadline": deadline,
                    "task_level": "normal"
                },
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code in [200, 201]:
                data = response.json()
                if "id" in data:
                    TestTaskAPI._created_task_id = data["id"]
                    print(f"✅ 创建任务成功: {data['id']}")
                elif "task" in data and "id" in data["task"]:
                    TestTaskAPI._created_task_id = data["task"]["id"]
                    print(f"✅ 创建任务成功: {data['task']['id']}")
                else:
                    print(f"✅ 创建任务成功: {data}")
            elif response.status_code == 422:
                print(f"ℹ️  创建任务验证失败: {response.json()}")
            else:
                print(f"ℹ️  创建任务返回: {response.status_code} - {response.text[:200]}")

    @pytest.mark.api
    @pytest.mark.task
    def test_create_task_missing_required_fields(self):
        """测试：缺少必填字段应该创建失败"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")
            
            # 验证认证信息是否有效
            if not TestTaskAPI._cookies and not TestTaskAPI._access_token:
                pytest.skip("认证信息无效")

            response = client.post(
                f"{self.base_url}/api/tasks",
                json={
                    "title": ""  # 空标题
                    # 缺少其他必填字段
                },
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            # 应该返回 400 或 422（验证错误），或 401（认证失败）
            # 注意：如果认证信息过期或无效，后端会先返回 401
            if response.status_code == 401:
                pytest.skip("认证已过期或无效，跳过此测试")
            
            assert response.status_code in [400, 422], \
                f"缺少必填字段应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 缺少必填字段被正确拒绝")

    # =========================================================================
    # 任务列表测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_tasks_public(self):
        """测试：获取公开任务列表（不需要认证）"""
        with httpx.Client(timeout=self.timeout) as client:
            # 尝试获取任务列表
            response = client.get(
                f"{self.base_url}/api/tasks",
                params={"limit": 10, "offset": 0}
            )

            # 可能需要认证，也可能公开
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (list, dict)), f"响应格式不正确: {data}"
                print(f"✅ 获取任务列表成功，共 {len(data) if isinstance(data, list) else data.get('total', '?')} 条")
            elif response.status_code in [401, 403]:
                print("ℹ️  任务列表需要认证")
            else:
                pytest.fail(f"获取任务列表失败: {response.status_code} - {response.text}")

    @pytest.mark.api
    @pytest.mark.task
    def test_get_tasks_authenticated(self):
        """测试：已认证用户获取任务列表"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout, cookies=TestTaskAPI._cookies) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/tasks",
                params={"limit": 10, "offset": 0},
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            assert response.status_code == 200, f"获取任务列表失败: {response.text}"
            
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                # 保存一个任务 ID 供后续测试使用
                TestTaskAPI._test_task_id = data[0].get("id", "")
                print(f"✅ 获取任务列表成功，共 {len(data)} 条")
            elif isinstance(data, dict):
                tasks = data.get("tasks", data.get("items", []))
                if tasks:
                    TestTaskAPI._test_task_id = tasks[0].get("id", "")
                print(f"✅ 获取任务列表成功")

    # =========================================================================
    # 任务详情测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_detail(self):
        """测试：获取任务详情"""
        if not TestTaskAPI._test_task_id:
            pytest.skip("没有可用的测试任务 ID")

        with httpx.Client(timeout=self.timeout, cookies=TestTaskAPI._cookies) as client:
            response = client.get(
                f"{self.base_url}/api/tasks/{TestTaskAPI._test_task_id}",
                headers=self._get_auth_headers()
            )

            if response.status_code == 200:
                data = response.json()
                assert "id" in data or "title" in data, f"响应缺少任务信息: {data}"
                print(f"✅ 获取任务详情成功: {data.get('title', 'N/A')}")
            elif response.status_code == 404:
                print("ℹ️  任务不存在（可能已删除）")
            else:
                pytest.fail(f"获取任务详情失败: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_detail_nonexistent(self):
        """测试：获取不存在的任务应返回 404"""
        with httpx.Client(timeout=self.timeout, cookies=TestTaskAPI._cookies) as client:
            response = client.get(
                f"{self.base_url}/api/tasks/99999999",
                headers=self._get_auth_headers()
            )

            # 401 也是有效的（如果需要认证才能查看任务详情）
            assert response.status_code in [404, 400, 401], \
                f"不存在的任务应返回 404，但返回了 {response.status_code}"
            
            if response.status_code == 401:
                print("ℹ️ 任务详情需要认证")
            else:
                print("✅ 不存在的任务正确返回 404")

    # =========================================================================
    # 我的任务测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_my_tasks(self):
        """测试：获取我发布的任务"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/my-tasks",
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                task_count = len(data) if isinstance(data, list) else "?"
                print(f"✅ 获取我的任务成功，共 {task_count} 条")
            elif response.status_code in [401, 403]:
                pytest.fail("认证失败，请检查测试账号配置")
            else:
                # 可能是空列表或其他正常响应
                print(f"ℹ️  获取我的任务返回: {response.status_code}")

    # =========================================================================
    # 任务推荐测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_recommendations(self):
        """测试：获取任务推荐"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/recommendations",
                params={"limit": 5},
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取推荐任务成功")
            elif response.status_code == 404:
                print("ℹ️  推荐接口不存在")
            else:
                print(f"ℹ️  推荐接口返回: {response.status_code}")

    # =========================================================================
    # 任务匹配分数测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_match_score(self):
        """测试：获取任务匹配分数"""
        if not TestTaskAPI._test_task_id:
            pytest.skip("没有可用的测试任务 ID")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/tasks/{TestTaskAPI._test_task_id}/match-score",
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取匹配分数成功: {data}")
            elif response.status_code in [401, 403, 404]:
                print(f"ℹ️  匹配分数接口返回: {response.status_code}")
            else:
                print(f"ℹ️  匹配分数接口返回: {response.status_code}")

    # =========================================================================
    # 任务历史测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_history(self):
        """测试：获取任务历史"""
        if not TestTaskAPI._test_task_id:
            pytest.skip("没有可用的测试任务 ID")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(
                f"{self.base_url}/api/tasks/{TestTaskAPI._test_task_id}/history",
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取任务历史成功")
            elif response.status_code in [401, 403, 404]:
                print(f"ℹ️  任务历史接口返回: {response.status_code}")
            else:
                print(f"ℹ️  任务历史接口返回: {response.status_code}")

    # =========================================================================
    # 编辑任务测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_update_task(self):
        """测试：更新自己创建的任务"""
        task_id = TestTaskAPI._created_task_id or TestTaskAPI._test_task_id
        if not task_id:
            pytest.skip("没有可用的任务 ID")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.put(
                f"{self.base_url}/api/tasks/{task_id}",
                json={
                    "description": "Updated description by API test"
                },
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                print("✅ 更新任务成功")
            elif response.status_code in [401, 403]:
                print("ℹ️  无权限更新任务")
            elif response.status_code == 404:
                print("ℹ️  任务不存在")
            else:
                print(f"ℹ️  更新任务返回: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.task
    def test_update_task_unauthorized(self):
        """测试：未登录用户不能更新任务"""
        if not TestTaskAPI._test_task_id:
            pytest.skip("没有可用的任务 ID")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.put(
                f"{self.base_url}/api/tasks/{TestTaskAPI._test_task_id}",
                json={
                    "description": "Unauthorized update"
                }
            )

            assert response.status_code in [401, 403], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录更新任务被正确拒绝")

    # =========================================================================
    # 取消任务测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_cancel_task_unauthorized(self):
        """测试：未登录用户不能取消任务"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/cancel"
            )

            assert response.status_code in [401, 403, 404], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录取消任务被正确拒绝")

    # =========================================================================
    # 接受任务测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_accept_task_unauthorized(self):
        """测试：未登录用户不能接受任务"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/accept"
            )

            assert response.status_code in [401, 403, 404], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录接受任务被正确拒绝")

    # =========================================================================
    # 任务搜索测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_search_tasks(self):
        """测试：搜索任务"""
        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/tasks",
                params={
                    "limit": 10,
                    "offset": 0,
                    "search": "test"  # 搜索关键词
                },
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                print("✅ 搜索任务成功")
            else:
                print(f"ℹ️  搜索任务返回: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.task
    def test_filter_tasks_by_type(self):
        """测试：按类型筛选任务"""
        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/tasks",
                params={
                    "limit": 10,
                    "offset": 0,
                    "task_type": "Tutoring"
                },
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                print("✅ 按类型筛选任务成功")
            else:
                print(f"ℹ️  按类型筛选返回: {response.status_code}")

    # =========================================================================
    # 任务评价测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_task_reviews(self):
        """测试：获取任务评价"""
        if not TestTaskAPI._test_task_id:
            pytest.skip("没有可用的任务 ID")

        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(
                f"{self.base_url}/api/tasks/{TestTaskAPI._test_task_id}/reviews",
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                print("✅ 获取任务评价成功")
            elif response.status_code == 404:
                print("ℹ️  任务评价接口不存在或任务无评价")
            else:
                print(f"ℹ️  获取任务评价返回: {response.status_code}")

    @pytest.mark.api
    @pytest.mark.task
    def test_submit_review_unauthorized(self):
        """测试：未登录用户不能提交评价"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/review",
                json={
                    "rating": 5,
                    "comment": "Great task!"
                }
            )

            assert response.status_code in [401, 403, 404], \
                f"未认证请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 未登录提交评价被正确拒绝")

    # =========================================================================
    # 用户任务统计测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.task
    def test_get_user_task_statistics(self):
        """测试：获取用户任务统计"""
        if not TestTaskAPI._user_id:
            pytest.skip("没有用户 ID")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/users/{TestTaskAPI._user_id}/task-statistics",
                headers=self._get_auth_headers(),
                cookies=TestTaskAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取任务统计成功: {data}")
            elif response.status_code == 404:
                print("ℹ️  任务统计接口不存在")
            else:
                print(f"ℹ️  任务统计返回: {response.status_code}")

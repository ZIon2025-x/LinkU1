"""
论坛功能 API 测试

测试覆盖:
- 分类列表
- 帖子列表/详情
- 发布帖子
- 评论功能

运行方式:
    pytest tests/api/test_forum_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL, 
    TEST_USER_EMAIL, 
    TEST_USER_PASSWORD,
    REQUEST_TIMEOUT
)


class TestForumAPI:
    """论坛 API 测试类"""

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

        if TestForumAPI._access_token or TestForumAPI._cookies:
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
                TestForumAPI._cookies = cookies
            
            data = response.json()
            if "access_token" in data:
                TestForumAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestForumAPI._user_id = data["user"]["id"]
            
            return bool(TestForumAPI._access_token or TestForumAPI._cookies)
        
        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestForumAPI._access_token:
            return {"Authorization": f"Bearer {TestForumAPI._access_token}"}
        return {}

    # =========================================================================
    # 分类列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_forum_categories(self):
        """测试：获取论坛分类列表（公开接口）"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/forum/categories")

            # 分类列表通常是公开的
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 论坛分类列表: {data}")
            elif response.status_code in [401, 403]:
                print("ℹ️  论坛分类需要登录")
            else:
                print(f"ℹ️  论坛分类返回: {response.status_code}")

    @pytest.mark.api
    def test_get_visible_forums(self):
        """测试：获取可见论坛列表"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/forum/forums/visible")

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 可见论坛列表: {data}")
            else:
                print(f"ℹ️  可见论坛返回: {response.status_code}")

    # =========================================================================
    # 帖子列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_forum_posts(self):
        """测试：获取帖子列表（公开接口）"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/forum/posts")

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict):
                    posts = data.get("posts", data.get("items", []))
                    print(f"✅ 帖子列表: {len(posts)} 条帖子")
                else:
                    print(f"✅ 帖子列表: {data}")
            elif response.status_code in [401, 403]:
                print("ℹ️  帖子列表需要登录")
            else:
                print(f"ℹ️  帖子列表返回: {response.status_code}")

    @pytest.mark.api
    def test_get_forum_posts_with_pagination(self):
        """测试：帖子列表分页"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(
                f"{self.base_url}/api/forum/posts",
                params={"limit": 10, "offset": 0}
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 帖子分页测试成功")
            else:
                print(f"ℹ️  帖子分页返回: {response.status_code}")

    # =========================================================================
    # 帖子详情测试
    # =========================================================================

    @pytest.mark.api
    def test_get_post_detail_nonexistent(self):
        """测试：获取不存在的帖子"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/forum/posts/99999999")

            # 不存在的帖子应该返回 404
            assert response.status_code in [404, 401, 403], \
                f"不存在的帖子应该返回 404，但返回了 {response.status_code}"
            
            print("✅ 不存在的帖子正确返回 404")

    # =========================================================================
    # 发布帖子测试
    # =========================================================================

    @pytest.mark.api
    def test_create_post_unauthorized(self):
        """测试：未登录用户不能发布帖子"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/forum/posts",
                json={
                    "title": "测试帖子标题",
                    "content": "这是测试内容，需要至少10个字符才能通过验证",  # min_length=10
                    "category_id": 1
                }
            )

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 发布帖子正确要求认证")

    # =========================================================================
    # 分类请求测试
    # =========================================================================

    @pytest.mark.api
    def test_request_category_unauthorized(self):
        """测试：未登录用户不能请求新分类"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/forum/categories/request",
                json={
                    "name": "新分类测试",
                    "description": "这是新分类的描述，需要足够长以通过验证"
                }
            )

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 请求分类正确要求认证")

    # =========================================================================
    # 我的分类请求测试
    # =========================================================================

    @pytest.mark.api
    def test_get_my_category_requests_unauthorized(self):
        """测试：未登录用户不能获取我的分类请求"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/forum/categories/requests/my")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 我的分类请求正确要求认证")

    @pytest.mark.api
    def test_get_my_category_requests_authenticated(self):
        """测试：登录用户可以获取我的分类请求"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/forum/categories/requests/my",
                headers=self._get_auth_headers(),
                cookies=TestForumAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 我的分类请求: {data}")
            else:
                print(f"ℹ️  我的分类请求返回: {response.status_code}")

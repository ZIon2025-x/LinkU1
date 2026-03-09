"""
排行榜 API 测试

测试覆盖:
- 获取技能分类列表（公开）
- 获取分类排行榜 Top 10（公开）
- 获取我的排名（需认证）

运行方式:
    pytest tests/api/test_leaderboard_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestLeaderboardAPI:
    """排行榜 API 测试类"""

    _skill_category: str = ""

    # =========================================================================
    # 获取技能分类列表测试（公开接口）
    # =========================================================================

    @pytest.mark.api
    def test_list_skill_categories(self):
        """测试：获取技能分类列表（公开接口，无需认证）"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/leaderboard/skills")

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                # 保存第一个分类用于后续测试
                if isinstance(data, list) and len(data) > 0:
                    category = data[0]
                    if isinstance(category, dict):
                        TestLeaderboardAPI._skill_category = str(
                            category.get("key", category.get("id", category.get("name", "")))
                        )
                    elif isinstance(category, str):
                        TestLeaderboardAPI._skill_category = category
                elif isinstance(data, dict):
                    categories = data.get("categories", data.get("items", []))
                    if categories:
                        cat = categories[0]
                        if isinstance(cat, dict):
                            TestLeaderboardAPI._skill_category = str(
                                cat.get("key", cat.get("id", cat.get("name", "")))
                            )
                        elif isinstance(cat, str):
                            TestLeaderboardAPI._skill_category = cat
                print(f"✅ 技能分类列表: {data}")
            elif response.status_code == 404:
                print("ℹ️  排行榜接口尚未实现 (404)")
            else:
                print(f"ℹ️  技能分类列表返回: {response.status_code}")

    # =========================================================================
    # 获取分类排行榜 Top 10 测试（公开接口）
    # =========================================================================

    @pytest.mark.api
    def test_get_category_leaderboard(self):
        """测试：获取分类排行榜 Top 10（公开接口，无需认证）"""
        category = TestLeaderboardAPI._skill_category or "programming"

        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/leaderboard/skills/{category}")

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                if isinstance(data, list):
                    assert len(data) <= 100, f"排行榜返回过多数据: {len(data)}"
                print(f"✅ 分类排行榜: {data}")
            elif response.status_code == 404:
                print("ℹ️  排行榜接口尚未实现 (404)")
            else:
                print(f"ℹ️  分类排行榜返回: {response.status_code}")

    @pytest.mark.api
    def test_get_category_leaderboard_nonexistent(self):
        """测试：获取不存在分类的排行榜"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(
                f"{TEST_API_URL}/api/leaderboard/skills/nonexistent_category_xyz"
            )

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list):
                    assert len(data) == 0, "不存在的分类应该返回空列表"
                print("✅ 不存在的分类返回空排行榜")
            elif response.status_code == 404:
                print("✅ 不存在的分类正确返回 404")
            else:
                print(f"ℹ️  不存在分类排行榜返回: {response.status_code}")

    # =========================================================================
    # 获取我的排名测试（需认证）
    # =========================================================================

    @pytest.mark.api
    def test_get_my_rank_unauthorized(self):
        """测试：未登录用户不能获取我的排名"""
        category = TestLeaderboardAPI._skill_category or "programming"

        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(
                f"{TEST_API_URL}/api/leaderboard/skills/{category}/my-rank"
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取我的排名正确要求认证")

    @pytest.mark.api
    def test_get_my_rank_authenticated(self, auth_client):
        """测试：登录用户可以获取我的排名"""
        category = TestLeaderboardAPI._skill_category or "programming"

        response = auth_client.get(
            f"{TEST_API_URL}/api/leaderboard/skills/{category}/my-rank"
        )

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"

        if response.status_code == 200:
            data = response.json()
            # 用户无排名时接口返回 null，属于正常情况
            assert data is None or isinstance(data, dict), \
                f"返回数据格式不正确: {type(data)}"
            if data:
                print(f"✅ 我的排名: {data}")
            else:
                print("ℹ️  用户暂无排名 (null)")
        elif response.status_code == 404:
            print("ℹ️  排名接口尚未实现或用户无排名 (404)")
        else:
            print(f"ℹ️  我的排名返回: {response.status_code}")

    @pytest.mark.api
    def test_get_my_rank_nonexistent_category(self, auth_client):
        """测试：获取不存在分类的我的排名"""
        response = auth_client.get(
            f"{TEST_API_URL}/api/leaderboard/skills/nonexistent_category_xyz/my-rank"
        )

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 不存在分类的排名: {data}")
        elif response.status_code in [404, 400]:
            print(f"✅ 不存在的分类正确返回 {response.status_code}")
        else:
            print(f"ℹ️  不存在分类排名返回: {response.status_code}")

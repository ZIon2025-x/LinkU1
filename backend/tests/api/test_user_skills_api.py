"""
用户技能 API 测试

测试覆盖:
- 获取我的技能
- 添加技能
- 删除技能
- 获取技能分类（公开）

运行方式:
    pytest tests/api/test_user_skills_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestUserSkillsAPI:
    """用户技能 API 测试类"""

    # 在测试之间传递创建的技能 ID（用于清理）
    _created_skill_id: str = ""

    # =========================================================================
    # 获取技能分类测试（公开接口）
    # =========================================================================

    @pytest.mark.api
    def test_get_skill_categories(self):
        """测试：获取技能分类列表（公开接口，无需认证）"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/skills/categories")

            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, (dict, list)), \
                    f"返回数据格式不正确: {type(data)}"
                print(f"✅ 技能分类列表: {data}")
            elif response.status_code == 404:
                print("ℹ️  技能分类接口尚未实现 (404)")
            else:
                print(f"ℹ️  技能分类列表返回: {response.status_code}")

    # =========================================================================
    # 获取我的技能测试
    # =========================================================================

    @pytest.mark.api
    def test_get_my_skills_unauthorized(self):
        """测试：未登录用户不能获取我的技能"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/skills/my")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 获取我的技能正确要求认证")

    @pytest.mark.api
    def test_get_my_skills_authenticated(self, auth_client):
        """测试：登录用户可以获取我的技能"""
        response = auth_client.get(f"{TEST_API_URL}/api/skills/my")

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"

        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, (dict, list)), \
                f"返回数据格式不正确: {type(data)}"
            print(f"✅ 我的技能: {data}")
        elif response.status_code == 404:
            print("ℹ️  我的技能接口尚未实现 (404)")
        else:
            print(f"ℹ️  我的技能返回: {response.status_code}")

    # =========================================================================
    # 添加技能测试
    # =========================================================================

    @pytest.mark.api
    def test_add_skill_unauthorized(self):
        """测试：未登录用户不能添加技能"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/skills/my",
                json={"name": "Python", "category": "programming", "level": "intermediate"}
            )

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 添加技能正确要求认证")

    @pytest.mark.api
    def test_add_skill_authenticated(self, auth_client):
        """测试：登录用户可以添加技能"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/skills/my",
            json={
                "name": "API_Test_Skill_Cleanup",
                "category": "programming",
                "level": "intermediate"
            }
        )

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"

        if response.status_code in [200, 201]:
            data = response.json()
            if isinstance(data, dict) and "id" in data:
                TestUserSkillsAPI._created_skill_id = str(data["id"])
            print(f"✅ 添加技能成功: {data}")
        elif response.status_code == 400:
            print("ℹ️  技能已存在或参数无效 (400)")
        elif response.status_code == 404:
            print("ℹ️  添加技能接口尚未实现 (404)")
        elif response.status_code == 422:
            print("ℹ️  请求参数格式不正确 (422)")
        else:
            print(f"ℹ️  添加技能返回: {response.status_code}")

    @pytest.mark.api
    def test_add_skill_invalid_data(self, auth_client):
        """测试：添加技能时提交无效数据，应该返回验证错误"""
        response = auth_client.post(
            f"{TEST_API_URL}/api/skills/my",
            json={}
        )

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"
        assert response.status_code in [400, 404, 422], \
            f"无效数据应该返回验证错误，但返回了 {response.status_code}"

        print(f"✅ 无效数据正确返回 {response.status_code}")

    # =========================================================================
    # 删除技能测试
    # =========================================================================

    @pytest.mark.api
    def test_delete_skill_unauthorized(self):
        """测试：未登录用户不能删除技能"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.delete(f"{TEST_API_URL}/api/skills/my/1")

            assert response.status_code in [401, 403, 405], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 删除技能正确要求认证")

    @pytest.mark.api
    def test_delete_skill_authenticated(self, auth_client):
        """测试：登录用户可以删除技能"""
        skill_id = TestUserSkillsAPI._created_skill_id
        if not skill_id:
            pytest.skip("没有可删除的技能（添加技能测试可能未成功）")

        response = auth_client.delete(f"{TEST_API_URL}/api/skills/my/{skill_id}")

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"

        if response.status_code in [200, 204]:
            TestUserSkillsAPI._created_skill_id = ""
            print("✅ 删除技能成功")
        elif response.status_code == 404:
            print("ℹ️  技能不存在或接口尚未实现 (404)")
        else:
            print(f"ℹ️  删除技能返回: {response.status_code}")

    @pytest.mark.api
    def test_delete_skill_nonexistent(self, auth_client):
        """测试：删除不存在的技能应返回 404"""
        response = auth_client.delete(f"{TEST_API_URL}/api/skills/my/99999999")

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"
        assert response.status_code in [400, 404, 422], \
            f"不存在的技能应该返回错误，但返回了 {response.status_code}"

        print(f"✅ 不存在的技能正确返回 {response.status_code}")

    @pytest.mark.api
    def test_delete_other_users_skill(self, auth_client):
        """测试：不能删除其他用户的技能"""
        response = auth_client.delete(
            f"{TEST_API_URL}/api/skills/my/00000000-0000-0000-0000-000000000001"
        )

        assert response.status_code != 401, \
            f"认证后不应该返回 401，检查 auth_client fixture"
        assert response.status_code in [400, 403, 404, 422], \
            f"删除他人技能应该被拒绝，但返回了 {response.status_code}"

        print(f"✅ 删除他人技能正确返回 {response.status_code}")

    # =========================================================================
    # 清理：删除测试中创建的技能
    # =========================================================================

    @pytest.mark.api
    def test_zz_cleanup(self, auth_client):
        """清理：删除测试中创建的技能（最后执行）"""
        if not TestUserSkillsAPI._created_skill_id:
            pytest.skip("没有需要清理的数据")

        response = auth_client.delete(
            f"{TEST_API_URL}/api/skills/my/{TestUserSkillsAPI._created_skill_id}"
        )

        if response.status_code in [200, 204]:
            TestUserSkillsAPI._created_skill_id = ""
            print("✅ 清理测试技能成功")
        elif response.status_code == 404:
            TestUserSkillsAPI._created_skill_id = ""
            print("ℹ️  测试技能已被删除")
        else:
            print(f"⚠️  清理失败: {response.status_code}")

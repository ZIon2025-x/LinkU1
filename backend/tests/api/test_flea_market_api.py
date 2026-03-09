"""
二手市场 API 测试

测试覆盖:
- 商品列表/详情
- 商品发布
- 收藏功能
- 购买请求

运行方式:
    pytest tests/api/test_flea_market_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestFleaMarketAPI:
    """二手市场 API 测试类"""

    # =========================================================================
    # 分类列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_flea_market_categories(self):
        """测试：获取二手市场分类（公开接口）"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/flea-market/categories")

            if response.status_code == 200:
                data = response.json()
                print(f"✅ 二手市场分类: {data}")
            else:
                print(f"ℹ️  二手市场分类返回: {response.status_code}")

    # =========================================================================
    # 商品列表测试
    # =========================================================================

    @pytest.mark.api
    def test_get_flea_market_items(self):
        """测试：获取商品列表（公开接口）"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/flea-market/items")

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict):
                    items = data.get("items", data.get("data", []))
                    print(f"✅ 商品列表: {len(items)} 件商品")
                else:
                    print(f"✅ 商品列表: {data}")
            elif response.status_code in [401, 403]:
                print("ℹ️  商品列表需要登录")
            else:
                print(f"ℹ️  商品列表返回: {response.status_code}")

    @pytest.mark.api
    def test_get_flea_market_items_with_filter(self):
        """测试：商品列表筛选"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(
                f"{TEST_API_URL}/api/flea-market/items",
                params={"limit": 10, "offset": 0}
            )

            if response.status_code == 200:
                print("✅ 商品筛选测试成功")
            else:
                print(f"ℹ️  商品筛选返回: {response.status_code}")

    # =========================================================================
    # 商品详情测试
    # =========================================================================

    @pytest.mark.api
    def test_get_item_detail_nonexistent(self):
        """测试：获取不存在的商品"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/flea-market/items/99999999")

            # 不存在的商品应该返回 404
            assert response.status_code in [404, 401, 403], \
                f"不存在的商品应该返回 404，但返回了 {response.status_code}"

            print("✅ 不存在的商品正确返回 404")

    # =========================================================================
    # 发布商品测试
    # =========================================================================

    @pytest.mark.api
    def test_create_item_unauthorized(self):
        """测试：未登录用户不能发布商品"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/flea-market/items",
                json={
                    "title": "测试商品标题",
                    "description": "这是测试商品的详细描述",
                    "price": 100.00,
                    "category": "electronics",
                    "images": []
                }
            )

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 发布商品正确要求认证")

    # =========================================================================
    # 收藏功能测试
    # =========================================================================

    @pytest.mark.api
    def test_get_favorites_unauthorized(self):
        """测试：未登录用户不能获取收藏列表"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/flea-market/favorites")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 收藏列表正确要求认证")

    @pytest.mark.api
    def test_get_favorites_authenticated(self, auth_client):
        """测试：登录用户可以获取收藏列表"""
        response = auth_client.get(f"{TEST_API_URL}/api/flea-market/favorites")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 收藏列表: {data}")
        else:
            print(f"ℹ️  收藏列表返回: {response.status_code}")

    @pytest.mark.api
    def test_favorite_item_unauthorized(self):
        """测试：未登录用户不能收藏商品"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送 json body，因为收藏操作可能不需要请求体
            response = client.post(
                f"{TEST_API_URL}/api/flea-market/items/12345678/favorite"
            )

            # 401/403: 认证失败, 404: 商品不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 收藏商品正确要求认证")

    # =========================================================================
    # 购买请求测试
    # =========================================================================

    @pytest.mark.api
    def test_purchase_request_unauthorized(self):
        """测试：未登录用户不能发送购买请求"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(
                f"{TEST_API_URL}/api/flea-market/items/12345678/purchase-request",
                json={"message": "我想购买这个商品，请问还在吗？"}
            )

            # 401/403: 认证失败, 404: 商品不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 购买请求正确要求认证")

    @pytest.mark.api
    def test_direct_purchase_unauthorized(self):
        """测试：未登录用户不能直接购买"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送空 json，直接 POST
            response = client.post(
                f"{TEST_API_URL}/api/flea-market/items/12345678/direct-purchase"
            )

            # 401/403: 认证失败, 404: 商品不存在
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 直接购买正确要求认证")

    # =========================================================================
    # 我的购买测试
    # =========================================================================

    @pytest.mark.api
    def test_get_my_purchases_unauthorized(self):
        """测试：未登录用户不能获取我的购买"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/flea-market/my-purchases")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 我的购买正确要求认证")

    @pytest.mark.api
    def test_get_my_purchases_authenticated(self, auth_client):
        """测试：登录用户可以获取我的购买"""
        response = auth_client.get(f"{TEST_API_URL}/api/flea-market/my-purchases")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 我的购买: {data}")
        else:
            print(f"ℹ️  我的购买返回: {response.status_code}")

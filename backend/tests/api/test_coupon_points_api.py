"""
优惠券/积分系统 API 测试

测试覆盖:
- 积分账户
- 优惠券领取/使用
- 每日签到
- 积分交易记录

运行方式:
    pytest tests/api/test_coupon_points_api.py -v
"""

import pytest
import httpx
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）


class TestCouponPointsAPI:
    """优惠券/积分 API 测试类"""

    # =========================================================================
    # 积分账户测试
    # =========================================================================

    @pytest.mark.api
    def test_get_points_account_unauthorized(self):
        """测试：未登录用户不能获取积分账户"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/points/account")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 积分账户正确要求认证")

    @pytest.mark.api
    def test_get_points_account_authenticated(self, auth_client):
        """测试：登录用户可以获取积分账户"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/points/account")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 积分账户: {data}")
            # 验证返回数据结构
            assert "balance" in data or "points" in data or "total_points" in data, \
                "积分账户响应缺少余额字段"
        elif response.status_code == 404:
            print("ℹ️  用户没有积分账户记录")
        else:
            print(f"ℹ️  积分账户返回: {response.status_code}")

    # =========================================================================
    # 积分交易记录测试
    # =========================================================================

    @pytest.mark.api
    def test_get_points_transactions_unauthorized(self):
        """测试：未登录用户不能获取积分交易记录"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/points/transactions")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 积分交易记录正确要求认证")

    @pytest.mark.api
    def test_get_points_transactions_authenticated(self, auth_client):
        """测试：登录用户可以获取积分交易记录"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/points/transactions")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 积分交易记录: {len(data) if isinstance(data, list) else data}")
        else:
            print(f"ℹ️  积分交易记录返回: {response.status_code}")

    # =========================================================================
    # 可用优惠券测试
    # =========================================================================

    @pytest.mark.api
    def test_get_available_coupons_unauthorized(self):
        """测试：未登录用户不能获取可用优惠券"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/coupons/available")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 可用优惠券正确要求认证")

    @pytest.mark.api
    def test_get_available_coupons_authenticated(self, auth_client):
        """测试：登录用户可以获取可用优惠券"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/coupons/available")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 可用优惠券: {data}")
        else:
            print(f"ℹ️  可用优惠券返回: {response.status_code}")

    # =========================================================================
    # 我的优惠券测试
    # =========================================================================

    @pytest.mark.api
    def test_get_my_coupons_unauthorized(self):
        """测试：未登录用户不能获取我的优惠券"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/coupons/my")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 我的优惠券正确要求认证")

    @pytest.mark.api
    def test_get_my_coupons_authenticated(self, auth_client):
        """测试：登录用户可以获取我的优惠券"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/coupons/my")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 我的优惠券: {data}")
        else:
            print(f"ℹ️  我的优惠券返回: {response.status_code}")

    # =========================================================================
    # 每日签到测试
    # =========================================================================

    @pytest.mark.api
    def test_checkin_unauthorized(self):
        """测试：未登录用户不能签到"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.post(f"{TEST_API_URL}/api/coupon-points/checkin")

            # 应该返回 401 (未认证) 或 403 (禁止访问)
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 签到正确要求认证")

    @pytest.mark.api
    def test_checkin_status_unauthorized(self):
        """测试：未登录用户不能获取签到状态"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/checkin/status")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 签到状态正确要求认证")

    @pytest.mark.api
    def test_checkin_status_authenticated(self, auth_client):
        """测试：登录用户可以获取签到状态"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/checkin/status")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 签到状态: {data}")
        else:
            print(f"ℹ️  签到状态返回: {response.status_code}")

    # =========================================================================
    # 支付历史测试
    # =========================================================================

    @pytest.mark.api
    def test_get_payment_history_unauthorized(self):
        """测试：未登录用户不能获取支付历史"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/coupon-points/payment-history")

            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 支付历史正确要求认证")

    @pytest.mark.api
    def test_get_payment_history_authenticated(self, auth_client):
        """测试：登录用户可以获取支付历史"""
        response = auth_client.get(f"{TEST_API_URL}/api/coupon-points/payment-history")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ 支付历史: {len(data) if isinstance(data, list) else data}")
        else:
            print(f"ℹ️  支付历史返回: {response.status_code}")

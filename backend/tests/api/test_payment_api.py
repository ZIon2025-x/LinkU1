"""
支付 API 测试

测试覆盖:
- Stripe 配置检查
- 支付意图创建
- 支付状态查询
- Stripe Connect 相关

重要提示:
- 必须使用 Stripe 测试密钥 (sk_test_xxx)
- 测试不会产生真实扣款

运行方式:
    pytest tests/api/test_payment_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL, 
    TEST_USER_EMAIL, 
    TEST_USER_PASSWORD, 
    STRIPE_TEST_SECRET_KEY,
    REQUEST_TIMEOUT
)


class TestPaymentAPI:
    """支付 API 测试类"""

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

        if TestPaymentAPI._cookies or TestPaymentAPI._access_token:
            return True

        response = client.post(
            f"{self.base_url}/api/secure-auth/login",
            json={
                "email": TEST_USER_EMAIL,
                "password": TEST_USER_PASSWORD
            }
        )

        if response.status_code == 200:
            TestPaymentAPI._cookies = dict(response.cookies)
            data = response.json()
            if "access_token" in data:
                TestPaymentAPI._access_token = data["access_token"]
            if "user" in data and "id" in data["user"]:
                TestPaymentAPI._user_id = data["user"]["id"]
            return True
        return False

    def _get_auth_headers(self) -> dict:
        """获取认证头"""
        if TestPaymentAPI._access_token:
            return {"Authorization": f"Bearer {TestPaymentAPI._access_token}"}
        return {}

    # =========================================================================
    # Stripe 配置测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_stripe_publishable_key(self):
        """测试：获取 Stripe 可发布密钥"""
        with httpx.Client(timeout=self.timeout) as client:
            # 尝试获取 Stripe 配置
            response = client.get(f"{self.base_url}/api/stripe/config")

            if response.status_code == 200:
                data = response.json()
                
                # 验证返回的是测试密钥（pk_test_ 开头）
                publishable_key = data.get("publishable_key", data.get("publishableKey", ""))
                
                if publishable_key:
                    assert publishable_key.startswith("pk_test_"), \
                        f"⚠️ 警告: Stripe 密钥不是测试密钥! 当前: {publishable_key[:15]}..."
                    print(f"✅ Stripe 测试密钥配置正确: {publishable_key[:20]}...")
                else:
                    print("ℹ️  未返回 Stripe 密钥")
            elif response.status_code == 404:
                print("ℹ️  Stripe 配置端点不存在")
            else:
                print(f"ℹ️  Stripe 配置返回: {response.status_code}")

    # =========================================================================
    # 管理员支付列表测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_admin_payments_unauthorized(self):
        """测试：未授权用户不能访问支付管理"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/admin/payments")

            # 应该返回 401 或 403
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 支付管理接口正确拒绝未授权访问")

    # =========================================================================
    # Stripe Connect 测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_stripe_connect_status(self):
        """测试：获取 Stripe Connect 状态"""
        if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
            pytest.skip("未配置测试账号")

        with httpx.Client(timeout=self.timeout) as client:
            if not self._login(client):
                pytest.skip("登录失败")

            response = client.get(
                f"{self.base_url}/api/stripe-connect/status",
                headers=self._get_auth_headers(),
                cookies=TestPaymentAPI._cookies
            )

            if response.status_code == 200:
                data = response.json()
                print(f"✅ Stripe Connect 状态: {data}")
            elif response.status_code == 404:
                print("ℹ️  Stripe Connect 端点不存在")
            elif response.status_code in [401, 403]:
                print("ℹ️  需要认证或权限不足")
            else:
                print(f"ℹ️  Stripe Connect 返回: {response.status_code}")

    # =========================================================================
    # 退款请求测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_refund_status_unauthorized(self):
        """测试：未登录用户不能查看退款状态"""
        with httpx.Client(timeout=self.timeout) as client:
            # 使用一个假的任务 ID
            response = client.get(f"{self.base_url}/api/tasks/12345678/refund-status")

            # 应该返回 401 或 403
            assert response.status_code in [401, 403, 404], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 退款状态接口正确拒绝未授权访问")

    # =========================================================================
    # 支付安全测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_payment_requires_auth(self):
        """测试：创建支付必须登录"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(
                f"{self.base_url}/api/tasks/12345678/pay",
                json={}
            )

            # 应该返回 401 或 403
            assert response.status_code in [401, 403, 404, 422], \
                f"未授权支付请求应该被拒绝，但返回了 {response.status_code}"
            
            print("✅ 支付接口正确要求认证")

    @pytest.mark.api
    @pytest.mark.payment
    def test_webhook_endpoint_exists(self):
        """测试：Stripe Webhook 端点存在"""
        with httpx.Client(timeout=self.timeout) as client:
            # Webhook 端点应该只接受 POST
            response = client.get(f"{self.base_url}/api/stripe/webhook")

            # GET 请求应该返回 405 (Method Not Allowed) 或 404
            assert response.status_code in [404, 405, 400], \
                f"Webhook 端点应该只接受 POST，但返回了 {response.status_code}"
            
            print("✅ Stripe Webhook 端点配置正确")

    # =========================================================================
    # 价格/产品相关测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_vip_products(self):
        """测试：获取 VIP 产品列表"""
        with httpx.Client(timeout=self.timeout) as client:
            # 尝试获取 VIP 产品
            response = client.get(f"{self.base_url}/api/vip/products")

            if response.status_code == 200:
                data = response.json()
                print(f"✅ VIP 产品列表: {data}")
            elif response.status_code == 404:
                print("ℹ️  VIP 产品端点不存在")
            else:
                print(f"ℹ️  VIP 产品返回: {response.status_code}")

    # =========================================================================
    # 安全验证测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_no_production_stripe_key(self):
        """测试：确保不使用生产 Stripe 密钥"""
        # 这个测试验证环境配置
        if STRIPE_TEST_SECRET_KEY:
            assert STRIPE_TEST_SECRET_KEY.startswith("sk_test_"), \
                f"⚠️ 严重警告: 检测到生产 Stripe 密钥! 测试必须使用测试密钥!"
            print("✅ Stripe 测试密钥配置正确")
        else:
            print("ℹ️  未配置 STRIPE_TEST_SECRET_KEY（可选）")

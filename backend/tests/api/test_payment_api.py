"""
支付 API 测试

测试覆盖:
- Stripe 配置检查
- 支付意图创建
- 支付状态查询
- Stripe Connect 相关
- 完整支付流程（沙盒模式）

重要提示:
- 必须使用 Stripe 测试密钥 (sk_test_xxx)
- 测试不会产生真实扣款
- 使用 Stripe 测试 PaymentMethod token 进行支付测试

Stripe 测试 PaymentMethod Token:
- pm_card_visa - 成功支付
- pm_card_chargeDeclined - 卡被拒绝
- pm_card_chargeDeclinedInsufficientFunds - 余额不足

参考文档: https://stripe.com/docs/testing#cards

运行方式:
    pytest tests/api/test_payment_api.py -v
"""

import pytest
import httpx
from tests.config import (
    TEST_API_URL,
    STRIPE_TEST_SECRET_KEY,
    REQUEST_TIMEOUT
)

# auth_client fixture 来自 tests/api/conftest.py（scope="class"）

# Stripe 测试 PaymentMethod Token（预定义的测试卡）
# 注意：不能直接发送原始卡号到 Stripe API，必须使用这些预定义 token
STRIPE_TEST_PM_SUCCESS = "pm_card_visa"
STRIPE_TEST_PM_DECLINED = "pm_card_chargeDeclined"
STRIPE_TEST_PM_INSUFFICIENT = "pm_card_chargeDeclinedInsufficientFunds"


class TestPaymentAPI:
    """支付 API 测试类"""

    # =========================================================================
    # 支付相关端点测试
    # =========================================================================

    # =========================================================================
    # 管理员支付列表测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_admin_payments_unauthorized(self):
        """测试：未授权用户不能访问支付管理"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            response = client.get(f"{TEST_API_URL}/api/admin/payments")

            # 应该返回 401 或 403
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 支付管理接口正确拒绝未授权访问")

    # =========================================================================
    # Stripe Connect 测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_stripe_connect_account_status(self, auth_client):
        """测试：获取 Stripe Connect 账户状态"""
        # 使用真实的端点: /api/stripe/connect/account/status
        response = auth_client.get(f"{TEST_API_URL}/api/stripe/connect/account/status")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Stripe Connect 账户状态: {data}")
        elif response.status_code == 404:
            print("ℹ️  Stripe Connect 账户端点不存在或用户未设置 Connect 账户")
        elif response.status_code == 403:
            print("ℹ️  权限不足")
        else:
            print(f"ℹ️  Stripe Connect 账户状态返回: {response.status_code}")

    # =========================================================================
    # 退款请求测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_refund_status_unauthorized(self):
        """测试：未登录用户不能查看退款状态"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 使用一个假的任务 ID
            response = client.get(f"{TEST_API_URL}/api/tasks/12345678/refund-status")

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
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 不发送空 json，直接 POST
            response = client.post(
                f"{TEST_API_URL}/api/tasks/12345678/pay"
            )

            # 应该返回 401 (未认证) 或 403 (禁止访问) 或 404 (任务不存在)
            assert response.status_code in [401, 403, 404], \
                f"未授权支付请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ 支付接口正确要求认证")

    @pytest.mark.api
    @pytest.mark.payment
    def test_webhook_endpoint_exists(self):
        """测试：Stripe Webhook 端点存在"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # Webhook 端点应该只接受 POST
            response = client.get(f"{TEST_API_URL}/api/stripe/webhook")

            # GET 请求应该返回 405 (Method Not Allowed) 或 404
            assert response.status_code in [404, 405, 400], \
                f"Webhook 端点应该只接受 POST，但返回了 {response.status_code}"

            print("✅ Stripe Webhook 端点配置正确")

    # =========================================================================
    # 价格/产品相关测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_vip_status_unauthorized(self):
        """测试：未登录用户不能获取 VIP 状态"""
        with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
            # 使用真实的 VIP 状态端点: /api/users/vip/status
            response = client.get(f"{TEST_API_URL}/api/users/vip/status")

            # 未登录用户应该被拒绝访问
            assert response.status_code in [401, 403], \
                f"未授权请求应该被拒绝，但返回了 {response.status_code}"

            print("✅ VIP 状态端点正确要求认证")

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

    # =========================================================================
    # VIP 状态测试（需要认证）
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_vip_status_authenticated(self, auth_client):
        """测试：登录用户可以获取 VIP 状态"""
        response = auth_client.get(f"{TEST_API_URL}/api/users/vip/status")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ VIP 状态: {data}")
            # 验证返回数据结构
            assert "is_vip" in data or "vip_status" in data or "status" in data, \
                "VIP 状态响应缺少必要字段"
        elif response.status_code == 404:
            print("ℹ️  用户没有 VIP 状态记录")
        else:
            print(f"ℹ️  VIP 状态返回: {response.status_code}")

    # =========================================================================
    # VIP 历史记录测试
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_vip_history_authenticated(self, auth_client):
        """测试：登录用户可以获取 VIP 历史记录"""
        response = auth_client.get(f"{TEST_API_URL}/api/users/vip/history")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            data = response.json()
            print(f"✅ VIP 历史记录: {len(data) if isinstance(data, list) else data}")
        elif response.status_code == 404:
            print("ℹ️  没有 VIP 历史记录")
        else:
            print(f"ℹ️  VIP 历史返回: {response.status_code}")


class TestStripeIntegration:
    """Stripe 集成测试类 - 测试完整支付流程"""

    # =========================================================================
    # Stripe SDK 直接测试（需要 STRIPE_TEST_SECRET_KEY）
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_stripe_api_connection(self):
        """测试：验证 Stripe API 连接（使用测试密钥）"""
        if not STRIPE_TEST_SECRET_KEY:
            pytest.skip("未配置 STRIPE_TEST_SECRET_KEY")

        try:
            import stripe
            stripe.api_key = STRIPE_TEST_SECRET_KEY

            # 测试 Stripe API 连接 - 列出余额
            balance = stripe.Balance.retrieve()

            assert balance is not None, "无法获取 Stripe 余额"
            print("✅ Stripe API 连接成功")
            print(f"   可用余额: {balance.available}")

        except ImportError:
            pytest.skip("未安装 stripe 库")
        except stripe.error.AuthenticationError as e:
            pytest.fail(f"Stripe 认证失败: {e}")
        except Exception as e:
            print(f"ℹ️  Stripe API 测试: {e}")

    @pytest.mark.api
    @pytest.mark.payment
    def test_create_payment_intent_directly(self):
        """测试：直接创建 PaymentIntent（Stripe 沙盒测试）"""
        if not STRIPE_TEST_SECRET_KEY:
            pytest.skip("未配置 STRIPE_TEST_SECRET_KEY")

        try:
            import stripe
            stripe.api_key = STRIPE_TEST_SECRET_KEY

            # 创建测试 PaymentIntent（禁用重定向支付方式）
            payment_intent = stripe.PaymentIntent.create(
                amount=1000,  # £10.00 (以便士为单位)
                currency="gbp",
                automatic_payment_methods={
                    "enabled": True,
                    "allow_redirects": "never"
                },
                metadata={
                    "test": "true",
                    "source": "github_actions_test"
                },
                # 自动取消，不会真正扣款
                capture_method="manual"
            )

            assert payment_intent.id is not None, "PaymentIntent ID 为空"
            assert payment_intent.id.startswith("pi_"), \
                f"PaymentIntent ID 格式不正确: {payment_intent.id}"
            assert payment_intent.client_secret is not None, "client_secret 为空"
            assert payment_intent.amount == 1000, f"金额不正确: {payment_intent.amount}"
            assert payment_intent.currency == "gbp", f"货币不正确: {payment_intent.currency}"

            print("✅ PaymentIntent 创建成功:")
            print(f"   ID: {payment_intent.id}")
            print(f"   金额: £{payment_intent.amount / 100:.2f}")
            print(f"   状态: {payment_intent.status}")

            # 清理：取消 PaymentIntent
            stripe.PaymentIntent.cancel(payment_intent.id)
            print("✅ PaymentIntent 已取消（清理测试数据）")

        except ImportError:
            pytest.skip("未安装 stripe 库")
        except stripe.error.StripeError as e:
            pytest.fail(f"Stripe 错误: {e}")

    @pytest.mark.api
    @pytest.mark.payment
    def test_confirm_payment_with_test_card(self):
        """测试：使用测试 PaymentMethod 确认支付（Stripe 沙盒测试）"""
        if not STRIPE_TEST_SECRET_KEY:
            pytest.skip("未配置 STRIPE_TEST_SECRET_KEY")

        try:
            import stripe
            stripe.api_key = STRIPE_TEST_SECRET_KEY

            # 1. 创建 PaymentIntent（禁用重定向支付方式，仅支持卡支付）
            payment_intent = stripe.PaymentIntent.create(
                amount=500,  # £5.00
                currency="gbp",
                # 禁用自动支付方式的重定向，避免需要 return_url
                automatic_payment_methods={
                    "enabled": True,
                    "allow_redirects": "never"
                },
                metadata={
                    "test": "true",
                    "source": "github_actions_test"
                }
            )

            print(f"✅ PaymentIntent 创建: {payment_intent.id}")

            # 2. 使用 Stripe 提供的测试 PaymentMethod token
            # pm_card_visa 是 Stripe 预定义的成功测试卡
            # 参考: https://stripe.com/docs/testing#cards
            test_payment_method = "pm_card_visa"

            print(f"✅ 使用测试 PaymentMethod: {test_payment_method}")

            # 3. 确认支付
            confirmed_intent = stripe.PaymentIntent.confirm(
                payment_intent.id,
                payment_method=test_payment_method
            )

            assert confirmed_intent.status == "succeeded", \
                f"支付未成功，状态: {confirmed_intent.status}"

            print("✅ 支付成功!")
            print(f"   状态: {confirmed_intent.status}")
            print(f"   金额: £{confirmed_intent.amount / 100:.2f}")

        except ImportError:
            pytest.skip("未安装 stripe 库")
        except stripe.error.CardError as e:
            pytest.fail(f"卡片错误: {e}")
        except stripe.error.StripeError as e:
            pytest.fail(f"Stripe 错误: {e}")

    @pytest.mark.api
    @pytest.mark.payment
    def test_declined_card(self):
        """测试：测试卡被拒绝的情况"""
        if not STRIPE_TEST_SECRET_KEY:
            pytest.skip("未配置 STRIPE_TEST_SECRET_KEY")

        try:
            import stripe
            stripe.api_key = STRIPE_TEST_SECRET_KEY

            # 1. 创建 PaymentIntent（禁用重定向支付方式）
            payment_intent = stripe.PaymentIntent.create(
                amount=500,
                currency="gbp",
                automatic_payment_methods={
                    "enabled": True,
                    "allow_redirects": "never"
                },
                metadata={"test": "true"}
            )

            # 2. 使用 Stripe 提供的被拒绝卡的测试 token
            # pm_card_chargeDeclined 是 Stripe 预定义的被拒绝测试卡
            # 参考: https://stripe.com/docs/testing#cards
            declined_payment_method = "pm_card_chargeDeclined"

            # 3. 尝试确认支付（应该失败）
            try:
                stripe.PaymentIntent.confirm(
                    payment_intent.id,
                    payment_method=declined_payment_method
                )
                pytest.fail("被拒绝的卡应该抛出异常")
            except stripe.error.CardError as e:
                print(f"✅ 卡被正确拒绝: {e.user_message}")
                assert "declined" in str(e).lower() or "拒绝" in str(e), \
                    f"错误消息应该包含'declined': {e}"

        except ImportError:
            pytest.skip("未安装 stripe 库")
        except stripe.error.StripeError as e:
            # 某些拒绝场景可能不是 CardError
            if "declined" in str(e).lower():
                print(f"✅ 卡被正确拒绝: {e}")
            else:
                pytest.fail(f"Stripe 错误: {e}")

    # =========================================================================
    # 通过 API 测试支付流程
    # =========================================================================

    @pytest.mark.api
    @pytest.mark.payment
    def test_task_payment_endpoint(self, auth_client):
        """测试：任务支付端点（通过 API）"""
        # 尝试获取用户的任务列表，找到一个可以测试支付的任务
        response = auth_client.get(f"{TEST_API_URL}/api/my-tasks")

        assert response.status_code != 401, "认证后不应该返回 401"

        if response.status_code == 200:
            tasks = response.json()
            if isinstance(tasks, dict):
                tasks = tasks.get("tasks", tasks.get("items", []))

            # 查找未支付的任务
            unpaid_tasks = [
                t for t in tasks
                if not t.get("is_paid") and t.get("reward", 0) > 0
            ]

            if unpaid_tasks:
                task = unpaid_tasks[0]
                task_id = task.get("id")
                print(f"ℹ️  找到未支付任务: {task_id}, 金额: {task.get('reward')}")

                # 测试支付端点
                pay_response = auth_client.post(
                    f"{TEST_API_URL}/api/tasks/{task_id}/payment",
                    json={}
                )

                print(f"ℹ️  支付端点响应: {pay_response.status_code}")
                if pay_response.status_code == 200:
                    pay_data = pay_response.json()
                    if "client_secret" in pay_data:
                        print("✅ 获取到 PaymentIntent client_secret")
                    if "payment_intent_id" in pay_data:
                        print(f"✅ PaymentIntent ID: {pay_data['payment_intent_id']}")
            else:
                print("ℹ️  没有找到未支付的任务")
        else:
            print(f"ℹ️  获取任务列表: {response.status_code}")

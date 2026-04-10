"""Unit tests for the package refund endpoint logic."""
import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from datetime import datetime, timezone, timedelta


class TestRefundScenarios:
    """Test the 4 refund scenarios: A, B, C1, C2."""

    def _make_package(
        self,
        pkg_id=42,
        status="active",
        used_sessions=0,
        total_sessions=10,
        paid_amount=10.0,
        cooldown_until=None,
        expires_at=None,
    ):
        pkg = MagicMock()
        pkg.id = pkg_id
        pkg.status = status
        pkg.user_id = "16668888"
        pkg.expert_id = "78682901"
        pkg.service_id = 7
        pkg.used_sessions = used_sessions
        pkg.total_sessions = total_sessions
        pkg.paid_amount = paid_amount
        pkg.payment_intent_id = "pi_test"
        pkg.currency = "GBP"
        pkg.unit_price_pence_snapshot = 100
        pkg.bundle_breakdown = None
        pkg.cooldown_until = cooldown_until
        pkg.expires_at = expires_at
        pkg.released_amount_pence = None
        pkg.refunded_amount_pence = None
        pkg.platform_fee_pence = None
        pkg.refunded_at = None
        return pkg

    def _make_db(self):
        db = AsyncMock()
        # db.refresh needs to be AsyncMock (awaitable)
        db.refresh = AsyncMock()
        return db

    @pytest.mark.asyncio
    @patch("app.package_purchase_routes._notify_package_refunded", new_callable=AsyncMock)
    @patch("app.package_purchase_routes._execute_stripe_refund_sync", return_value=(True, "re_test", None))
    async def test_scenario_a_cooldown_never_used_full_refund(self, mock_stripe, mock_notify):
        """< 24h + 0 used → full refund."""
        from app.package_purchase_routes import _process_full_refund

        pkg = self._make_package(used_sessions=0)
        db = self._make_db()

        result = await _process_full_refund(db, pkg, reason="test")

        assert result["refund_type"] == "full"
        assert result["status"] == "refunded"
        assert result["refund_amount_pence"] == 1000
        assert pkg.status == "refunded"
        assert pkg.refunded_amount_pence == 1000
        mock_stripe.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.package_purchase_routes._notify_package_refunded", new_callable=AsyncMock)
    @patch("app.package_purchase_routes._execute_stripe_refund_sync", return_value=(True, "re_test", None))
    async def test_scenario_b_cooldown_used_pro_rata(self, mock_stripe, mock_notify):
        """< 24h + 3 used → pro-rata."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=3)
        db = self._make_db()

        result = await _process_partial_refund(db, pkg, reason="test")

        assert result["refund_type"] == "pro_rata"
        assert result["status"] == "partially_refunded"
        # consumed = 300p, fee = 50p (min), transfer = 250p, refund = 700p
        assert result["refund_amount_pence"] == 700
        assert result["transfer_amount_pence"] == 250
        assert pkg.status == "partially_refunded"
        mock_stripe.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.package_purchase_routes._notify_package_refunded", new_callable=AsyncMock)
    @patch("app.package_purchase_routes._execute_stripe_refund_sync", return_value=(True, "re_test", None))
    async def test_scenario_c1_past_cooldown_never_used_full_refund(self, mock_stripe, mock_notify):
        """≥ 24h + 0 used → falls through to full refund."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=0)
        db = self._make_db()

        result = await _process_partial_refund(db, pkg, reason="test")

        # Should behave as full refund
        assert result["refund_type"] == "full"
        assert result["status"] == "refunded"
        assert pkg.status == "refunded"
        mock_stripe.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.package_purchase_routes._notify_package_refunded", new_callable=AsyncMock)
    @patch("app.package_purchase_routes._execute_stripe_refund_sync", return_value=(True, "re_test", None))
    async def test_scenario_c2_past_cooldown_used_pro_rata(self, mock_stripe, mock_notify):
        """≥ 24h + 5 used → pro-rata."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=5)
        db = self._make_db()

        result = await _process_partial_refund(db, pkg, reason="test")

        assert result["refund_type"] == "pro_rata"
        assert result["status"] == "partially_refunded"
        # consumed = 500p, fee = 50p (min), transfer = 450p, refund = 500p
        assert result["refund_amount_pence"] == 500
        assert result["transfer_amount_pence"] == 450
        mock_stripe.assert_called_once()

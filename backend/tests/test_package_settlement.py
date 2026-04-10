"""Unit tests for package_settlement module (compute_package_split + trigger_package_release)."""
import pytest
from unittest.mock import MagicMock


class TestComputePackageSplit:
    """Test the core bundle/multi split calculation."""

    def _make_package(
        self,
        paid_amount: float,
        total_sessions: int = 0,
        used_sessions: int = 0,
        bundle_breakdown: dict | None = None,
        unit_price_pence_snapshot: int | None = None,
    ):
        pkg = MagicMock()
        pkg.paid_amount = paid_amount
        pkg.total_sessions = total_sessions
        pkg.used_sessions = used_sessions
        pkg.bundle_breakdown = bundle_breakdown
        pkg.unit_price_pence_snapshot = unit_price_pence_snapshot
        return pkg

    def test_bundle_weighted_partial_consumption(self):
        """Bundle A×3 (£10) + B×2 (£20) + C×1 (£30), paid £80 (20% discount).
        Consumed: 2A + 1B + 0C.
        Math:
          unbundled_total = 3*1000 + 2*2000 + 1*3000 = 10000 pence
          consumed_list = 2*1000 + 1*2000 + 0*3000 = 4000 pence
          consumed_fair = 8000 * 4000 // 10000 = 3200 pence
          unconsumed_fair = 8000 - 3200 = 4800 pence
          fee = 3200 * 0.08 = 256 pence (above 50p min)
          transfer = 3200 - 256 = 2944 pence
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=80.0,
            bundle_breakdown={
                "1": {"total": 3, "used": 2, "unit_price_pence": 1000},
                "2": {"total": 2, "used": 1, "unit_price_pence": 2000},
                "3": {"total": 1, "used": 0, "unit_price_pence": 3000},
            },
        )

        result = compute_package_split(pkg)

        assert result["paid_total_pence"] == 8000
        assert result["consumed_value_pence"] == 3200
        assert result["unconsumed_value_pence"] == 4800
        assert result["fee_pence"] == 256
        assert result["transfer_pence"] == 2944
        assert result["refund_pence"] == 0
        assert result["calculation_mode"] == "bundle_weighted"

    def test_multi_uniform_partial_consumption(self):
        """Multi 10 × £1 = £10, used 3.
        Math:
          unbundled_total = 10 * 100 = 1000
          consumed_list = 3 * 100 = 300
          consumed_fair = 1000 * 300 // 1000 = 300 pence
          unconsumed_fair = 700 pence
          fee = max(50, 300*0.08=24) = 50 pence (min)
          transfer = 300 - 50 = 250 pence
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=3,
            bundle_breakdown=None,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["paid_total_pence"] == 1000
        assert result["consumed_value_pence"] == 300
        assert result["unconsumed_value_pence"] == 700
        assert result["fee_pence"] == 50
        assert result["transfer_pence"] == 250
        assert result["calculation_mode"] == "multi_uniform"

    def test_all_consumed_multi(self):
        """Multi 10 × £1 = £10, all used → consumed=£10, unconsumed=0.
        fee = max(50, 1000*0.08=80) = 80 pence
        transfer = 1000 - 80 = 920
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=10,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 1000
        assert result["unconsumed_value_pence"] == 0
        assert result["fee_pence"] == 80
        assert result["transfer_pence"] == 920

    def test_zero_consumed_multi(self):
        """Multi 10 × £1 = £10, used 0.
        consumed=0, fee=0 (because consumed_fair is 0, fee_calculator returns 0),
        transfer=0, refund=0 (caller fills based on scenario).
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=0,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 0
        assert result["unconsumed_value_pence"] == 1000
        assert result["fee_pence"] == 0
        assert result["transfer_pence"] == 0

    def test_legacy_bundle_no_unit_price(self):
        """Bundle breakdown without unit_price_pence falls back to equal weight per session.
        6 total sessions, 3 used → consumed = £60 * 3/6 = £30 = 3000 pence
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=60.0,
            bundle_breakdown={
                "1": {"total": 3, "used": 2},  # No unit_price_pence
                "2": {"total": 3, "used": 1},
            },
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 3000
        assert result["unconsumed_value_pence"] == 3000
        assert result["calculation_mode"] == "legacy_equal"

    def test_zero_unbundled_total_defensive_full_refund(self):
        """Defensive case: if unbundled_total somehow calculates to 0, refund everything."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=0,
            used_sessions=0,
            unit_price_pence_snapshot=None,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 0
        assert result["unconsumed_value_pence"] == 1000
        assert result["fee_pence"] == 0
        assert result["transfer_pence"] == 0
        assert result["refund_pence"] == 1000

    def test_sum_invariant_bundle(self):
        """consumed + unconsumed must always equal paid_total (no rounding loss)."""
        from app.services.package_settlement import compute_package_split

        # Tricky numbers: 9.99 with prime unit prices
        pkg = self._make_package(
            paid_amount=9.99,
            bundle_breakdown={
                "1": {"total": 7, "used": 3, "unit_price_pence": 137},
                "2": {"total": 5, "used": 2, "unit_price_pence": 211},
            },
        )

        result = compute_package_split(pkg)

        assert (
            result["consumed_value_pence"] + result["unconsumed_value_pence"]
            == result["paid_total_pence"]
        )


class TestTriggerPackageRelease:
    """Test the release trigger that creates PaymentTransfer rows."""

    def _make_package_exhausted(self, paid_amount=10.0, pkg_id=42):
        pkg = MagicMock()
        pkg.id = pkg_id
        pkg.status = "exhausted"
        pkg.paid_amount = paid_amount
        pkg.expert_id = "78682901"
        pkg.user_id = "16668888"
        pkg.currency = "GBP"
        pkg.released_amount_pence = None  # Not yet released
        pkg.platform_fee_pence = None
        return pkg

    def test_release_creates_payment_transfer_and_sets_fee(self):
        """Exhausted £10 package: transfer 920p (after 80p fee)."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted(paid_amount=10.0)
        db = MagicMock()

        trigger_package_release(db, pkg, reason="exhausted")

        # Platform fee should be set on package
        assert pkg.platform_fee_pence == 80  # £10 * 8%
        # db.add must be called once with a PaymentTransfer-like object
        assert db.add.call_count == 1
        transfer_arg = db.add.call_args[0][0]
        assert transfer_arg.package_id == 42
        assert transfer_arg.task_id is None
        assert transfer_arg.taker_expert_id == "78682901"
        assert transfer_arg.poster_id == "16668888"
        assert transfer_arg.amount == pytest.approx(9.20)
        assert transfer_arg.currency == "GBP"
        assert transfer_arg.status == "pending"
        assert transfer_arg.idempotency_key == "pkg_42_exhausted"

    def test_release_idempotent_when_already_released(self):
        """If released_amount_pence is already set, trigger_package_release is a no-op."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted()
        pkg.released_amount_pence = 920  # Already released
        db = MagicMock()

        trigger_package_release(db, pkg, reason="exhausted")

        # db.add must NOT be called
        assert db.add.call_count == 0

    def test_release_rejects_invalid_status(self):
        """trigger_package_release only works for exhausted / expired status."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted()
        pkg.status = "active"
        db = MagicMock()

        with pytest.raises(ValueError, match="Invalid status"):
            trigger_package_release(db, pkg, reason="exhausted")

    def test_release_expired_reason_idempotency_key(self):
        """Expired reason produces distinct idempotency key."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted(pkg_id=99)
        pkg.status = "expired"
        db = MagicMock()

        trigger_package_release(db, pkg, reason="expired")

        transfer_arg = db.add.call_args[0][0]
        assert transfer_arg.idempotency_key == "pkg_99_expired"

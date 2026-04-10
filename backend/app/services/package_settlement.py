"""Package settlement module: split/release calculations for UserServicePackage.

All monetary values are in pence (int) unless otherwise noted.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models_expert import UserServicePackage


def compute_package_split(package: "UserServicePackage") -> dict:
    """Compute the fair-value split for a UserServicePackage.

    Returns a dict with:
        paid_total_pence:       Original paid amount in pence
        consumed_value_pence:   Fair value of consumed sessions (bundle-weighted or uniform)
        unconsumed_value_pence: Fair value of unconsumed sessions (sum == paid_total)
        fee_pence:              Platform service fee (8% on consumed, min 50p)
        transfer_pence:         Amount to send to expert (consumed - fee)
        refund_pence:           Default 0; caller fills based on scenario
        calculation_mode:       "bundle_weighted" | "multi_uniform" | "legacy_equal"
    """
    paid = int(round(float(package.paid_amount) * 100))

    if package.bundle_breakdown:
        has_new_format = all(
            isinstance(item, dict) and "unit_price_pence" in item
            for item in package.bundle_breakdown.values()
        )
        if has_new_format:
            unbundled_total = sum(
                int(item["total"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            consumed_list = sum(
                int(item["used"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            mode = "bundle_weighted"
        else:
            # Legacy fallback: equal weight per session
            total_count = sum(int(item["total"]) for item in package.bundle_breakdown.values())
            used_count = sum(int(item["used"]) for item in package.bundle_breakdown.values())
            unbundled_total = total_count
            consumed_list = used_count
            mode = "legacy_equal"
    elif package.unit_price_pence_snapshot:
        # multi 模式: uniform price per session
        unbundled_total = package.total_sessions * package.unit_price_pence_snapshot
        consumed_list = package.used_sessions * package.unit_price_pence_snapshot
        mode = "multi_uniform"
    else:
        # Legacy fallback: pro-rata by session count
        unbundled_total = package.total_sessions
        consumed_list = package.used_sessions
        mode = "legacy_equal"

    if unbundled_total == 0:
        # Defensive: refund everything to buyer
        return {
            "paid_total_pence": paid,
            "consumed_value_pence": 0,
            "unconsumed_value_pence": paid,
            "fee_pence": 0,
            "transfer_pence": 0,
            "refund_pence": paid,
            "calculation_mode": mode,
        }

    consumed_fair = paid * consumed_list // unbundled_total
    unconsumed_fair = paid - consumed_fair  # Preserve sum == paid (no rounding loss)

    from app.utils.fee_calculator import calculate_application_fee_pence
    fee = calculate_application_fee_pence(consumed_fair, "expert_service", None)
    transfer = consumed_fair - fee

    return {
        "paid_total_pence": paid,
        "consumed_value_pence": consumed_fair,
        "unconsumed_value_pence": unconsumed_fair,
        "fee_pence": fee,
        "transfer_pence": transfer,
        "refund_pence": 0,
        "calculation_mode": mode,
    }


def trigger_package_release(db, pkg, reason: str) -> None:
    """Trigger the release of a package's held funds to the expert team.

    Creates a PaymentTransfer row in 'pending' state. The existing
    payment_transfer_service cron will pick it up and execute the Stripe Transfer.

    Args:
        db: SQLAlchemy session (sync or async — only db.add is used)
        pkg: UserServicePackage instance, must have status in ('exhausted', 'expired')
        reason: "exhausted" | "expired" | "partial_transfer" — becomes idempotency key suffix

    Raises:
        ValueError: if pkg.status is not in allowed set

    Idempotency:
        - If pkg.released_amount_pence is already set, this is a no-op
        - The PaymentTransfer.idempotency_key prevents Stripe-level duplicates
    """
    if pkg.status not in ("exhausted", "expired"):
        raise ValueError(f"Invalid status for release: {pkg.status}")

    if pkg.released_amount_pence is not None:
        # Already processed — skip
        return

    from app.utils.fee_calculator import calculate_application_fee_pence
    from app import models

    paid_pence = int(round(float(pkg.paid_amount) * 100))
    fee = calculate_application_fee_pence(paid_pence, "expert_service", None)
    transfer_pence = paid_pence - fee

    pkg.platform_fee_pence = fee
    # Note: released_amount_pence and released_at are written by payment_transfer_service
    # after the Stripe Transfer succeeds.

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_id=None,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=transfer_pence / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_{reason}",
    ))


def compute_package_action_flags(pkg: "UserServicePackage", now) -> dict:
    """Return the UI action flags for a package.

    Returns dict with:
        in_cooldown: bool
        can_refund_full: bool  (in_cooldown AND never_used)
        can_refund_partial: bool  (active AND used > 0)
        can_review: bool  (status in set)
        can_dispute: bool  (active AND used > 0)
        status_display: str  (i18n key)
    """
    from datetime import timezone as _tz

    cooldown_until = pkg.cooldown_until
    if cooldown_until and cooldown_until.tzinfo is None:
        cooldown_until = cooldown_until.replace(tzinfo=_tz.utc)

    in_cooldown = cooldown_until is not None and now < cooldown_until
    never_used = pkg.used_sessions == 0
    has_used = pkg.used_sessions > 0

    # Scenario A: cooldown + never used → full refund
    # Scenario C1: past cooldown + never used → also full refund
    can_refund_full = pkg.status == "active" and never_used
    can_refund_partial = pkg.status == "active" and has_used
    can_review = pkg.status in ("exhausted", "expired", "released", "partially_refunded")
    can_dispute = pkg.status == "active" and has_used

    return {
        "in_cooldown": in_cooldown,
        "can_refund_full": can_refund_full,
        "can_refund_partial": can_refund_partial,
        "can_review": can_review,
        "can_dispute": can_dispute,
        "status_display": f"package_status_{pkg.status}",
    }

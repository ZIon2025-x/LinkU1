"""验证 POST /api/experts/{expert_id}/stripe-connect 在账户存在但 onboarding 未完成时
返回新的 onboarding_url，让前端可以恢复 Stripe 设置流程。

旧实现：账户存在时，无论 details_submitted 与否，返回 dict 都不包含 onboarding_url，
导致 UI 没有恢复入口。
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


@pytest.mark.asyncio
async def test_resume_returns_fresh_onboarding_url_when_account_incomplete():
    """已有 stripe 账户但 details_submitted=False → 响应里必须包含 onboarding_url。"""
    from app.expert_routes import create_expert_stripe_connect

    expert = MagicMock(
        id="11111111",
        name="Test Team",
        stripe_account_id="acct_existing",
        stripe_onboarding_complete=False,
    )
    member = MagicMock(role="owner")
    user = MagicMock(id="u_owner", email="owner@example.com")

    db = AsyncMock()
    request = MagicMock()

    fake_account = MagicMock(details_submitted=False, charges_enabled=False)
    fake_link = MagicMock(url="https://stripe.example/refresh-onboard")

    with patch("app.expert_routes._get_expert_or_404", new=AsyncMock(return_value=expert)), \
         patch("app.expert_routes._get_member_or_403", new=AsyncMock(return_value=member)), \
         patch("stripe.Account.retrieve", return_value=fake_account), \
         patch("stripe.AccountLink.create", return_value=fake_link):

        result = await create_expert_stripe_connect(
            expert_id="11111111",
            request=request,
            country="GB",
            db=db,
            current_user=user,
        )

    assert result["account_id"] == "acct_existing"
    assert result["details_submitted"] is False
    assert result["charges_enabled"] is False
    assert result["onboarding_url"] == "https://stripe.example/refresh-onboard", (
        "已有未完成账户时必须返回新的 onboarding_url，否则 UI 无恢复入口"
    )


@pytest.mark.asyncio
async def test_complete_account_does_not_include_onboarding_url():
    """已有账户且 details_submitted=True → 不需要 onboarding_url。"""
    from app.expert_routes import create_expert_stripe_connect

    expert = MagicMock(
        id="11111111",
        name="Test Team",
        stripe_account_id="acct_existing",
        stripe_onboarding_complete=True,
    )
    member = MagicMock(role="owner")
    user = MagicMock(id="u_owner", email="owner@example.com")
    db = AsyncMock()
    request = MagicMock()

    fake_account = MagicMock(details_submitted=True, charges_enabled=True)

    with patch("app.expert_routes._get_expert_or_404", new=AsyncMock(return_value=expert)), \
         patch("app.expert_routes._get_member_or_403", new=AsyncMock(return_value=member)), \
         patch("stripe.Account.retrieve", return_value=fake_account):

        result = await create_expert_stripe_connect(
            expert_id="11111111",
            request=request,
            country="GB",
            db=db,
            current_user=user,
        )

    assert result["account_id"] == "acct_existing"
    assert result["details_submitted"] is True
    assert "onboarding_url" not in result

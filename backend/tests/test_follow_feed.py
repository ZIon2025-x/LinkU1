"""Follow feed route tests."""
import pytest


def test_follow_feed_routes_importable():
    from app.follow_feed_routes import router
    assert router.prefix == "/api/follow"


def test_follow_feed_endpoint_registered():
    from app.follow_feed_routes import router
    paths = [r.path for r in router.routes]
    # Router stores full paths including prefix: /api/follow/feed
    assert any("/feed" in p for p in paths)


@pytest.mark.asyncio
async def test_follow_feed_empty_when_no_following():
    from unittest.mock import AsyncMock, MagicMock
    from app.follow_feed_routes import get_follow_feed

    user = MagicMock()
    user.id = "user1"
    db = AsyncMock()
    # .all() must be a regular (sync) method returning an empty list
    mock_result = MagicMock()
    mock_result.all.return_value = []
    db.execute.return_value = mock_result

    result = await get_follow_feed(page=1, page_size=20, request=MagicMock(), current_user=user, db=db)
    assert result["items"] == []
    assert result["has_more"] == False

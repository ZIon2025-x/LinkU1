"""
Follow routes tests.
Tests for follow/unfollow and follower/following list endpoints.
"""
import pytest


# ==================== 模块导入测试 ====================


def test_follow_routes_module_imports():
    """Test that the follow_routes module imports correctly."""
    import app.follow_routes as follow_routes

    assert hasattr(follow_routes, "router")
    assert hasattr(follow_routes, "follow_user")
    assert hasattr(follow_routes, "unfollow_user")
    assert hasattr(follow_routes, "get_followers")
    assert hasattr(follow_routes, "get_following")
    assert hasattr(follow_routes, "_invalidate_follow_cache")


def test_router_prefix():
    """Test that the router has the correct prefix."""
    from app.follow_routes import router

    assert router.prefix == "/api/users"


# ==================== 路由注册测试 ====================


def test_follow_endpoints_registered():
    """Test that follow/unfollow/followers/following routes are registered."""
    from app.follow_routes import router

    routes_info = [(r.path, list(r.methods)) for r in router.routes]

    paths = [r[0] for r in routes_info]

    # Verify all four endpoints exist
    assert "/api/users/{user_id}/follow" in paths, (
        f"Follow endpoint missing. Registered paths: {paths}"
    )
    assert "/api/users/{user_id}/followers" in paths, (
        f"Followers endpoint missing. Registered paths: {paths}"
    )
    assert "/api/users/{user_id}/following" in paths, (
        f"Following endpoint missing. Registered paths: {paths}"
    )


def test_follow_methods():
    """Test that follow endpoint has POST and DELETE methods."""
    from app.follow_routes import router

    follow_route_methods = {}
    for r in router.routes:
        if r.path == "/api/users/{user_id}/follow":
            follow_route_methods[r.path] = follow_route_methods.get(r.path, set()) | r.methods

    assert "POST" in follow_route_methods.get("/api/users/{user_id}/follow", set()), (
        "POST method missing from follow endpoint"
    )
    assert "DELETE" in follow_route_methods.get("/api/users/{user_id}/follow", set()), (
        "DELETE method missing from follow endpoint"
    )


# ==================== 自我关注测试 ====================


def test_follow_self_raises_400():
    """Test that following oneself returns HTTP 400."""
    import asyncio
    from unittest.mock import AsyncMock, MagicMock

    from fastapi import HTTPException

    from app.follow_routes import follow_user

    user = MagicMock()
    user.id = "user1"
    db = AsyncMock()

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            follow_user(
                user_id="user1",
                request=MagicMock(),
                current_user=user,
                db=db,
            )
        )
    assert exc_info.value.status_code == 400


# ==================== 缓存失效测试 ====================


def test_invalidate_follow_cache_no_error():
    """Test that _invalidate_follow_cache completes without raising."""
    import asyncio

    from app.follow_routes import _invalidate_follow_cache

    # Should not raise even when Redis is unavailable
    asyncio.run(_invalidate_follow_cache("user1", "user2"))

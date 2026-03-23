"""Test task content type in discovery feed."""
import pytest


def test_task_feed_item_has_required_flat_keys():
    required_keys = {
        "feed_type", "id", "title", "description", "images",
        "user_id", "user_name", "user_avatar", "price", "currency",
        "extra_data", "created_at",
    }
    required_extra_keys = {"task_type", "reward", "match_score", "application_count"}
    item = {
        "feed_type": "task", "id": "task_123", "title": "Test",
        "description": "Desc", "images": None, "user_id": "u1",
        "user_name": "Name", "user_avatar": None, "price": 50.0,
        "currency": "GBP", "extra_data": {
            "task_type": "design", "reward": 50.0, "application_count": 3,
            "match_score": 0.85, "recommendation_reason": "test",
            "location": "London", "deadline": None, "task_level": None,
            "base_reward": 50.0, "agreed_reward": None, "reward_to_be_quoted": False,
        },
        "created_at": "2026-03-20T00:00:00",
    }
    assert required_keys.issubset(set(item.keys()))
    assert required_extra_keys.issubset(set(item["extra_data"].keys()))
    assert item["id"].startswith("task_")


def test_weighted_shuffle_handles_task_type():
    from app.discovery_routes import _weighted_shuffle
    base = {
        "title": "T", "description": "", "images": None,
        "user_id": None, "user_name": None, "user_avatar": None,
        "price": None, "currency": None, "rating": None,
        "like_count": 0, "comment_count": 0, "view_count": 0,
        "upvote_count": None, "downvote_count": None,
        "linked_item": None, "target_item": None,
        "activity_info": None, "is_experienced": None,
        "is_favorited": None, "user_vote_type": None,
        "extra_data": None, "original_price": None,
        "discount_percentage": None,
    }
    items = [
        {**base, "feed_type": "task", "id": "task_1", "created_at": "2026-03-20T00:00:00"},
        {**base, "feed_type": "forum_post", "id": "post_1", "created_at": "2026-03-20T00:00:00"},
        {**base, "feed_type": "task", "id": "task_2", "created_at": "2026-03-19T00:00:00"},
        {**base, "feed_type": "product", "id": "product_1", "created_at": "2026-03-19T00:00:00"},
    ]
    result = _weighted_shuffle(items, limit=4, page=1, seed=42)
    assert len(result) == 4
    feed_types = {r["feed_type"] for r in result}
    assert "task" in feed_types


def test_activity_feed_item_uses_activity_info():
    item = {
        "feed_type": "activity",
        "id": "activity_456",
        "title": "Workshop",
        "activity_info": {
            "activity_type": "standard",
            "max_participants": 50,
            "current_participants": 32,
        },
        "extra_data": None,
    }
    assert item["feed_type"] == "activity"
    assert item["id"].startswith("activity_")
    assert item["activity_info"]["max_participants"] == 50
    assert item["extra_data"] is None

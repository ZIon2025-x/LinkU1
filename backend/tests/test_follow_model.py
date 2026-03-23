"""UserFollow model basic tests."""
import pytest

def test_user_follow_model_exists():
    """Verify UserFollow model can be imported."""
    from app.models import UserFollow
    assert UserFollow.__tablename__ == "user_follows"

def test_user_follow_columns():
    """Verify required columns exist."""
    from app.models import UserFollow
    cols = {c.name for c in UserFollow.__table__.columns}
    assert "follower_id" in cols
    assert "following_id" in cols
    assert "created_at" in cols

def test_user_follow_unique_constraint():
    """Verify unique constraint on (follower_id, following_id)."""
    from app.models import UserFollow
    constraint_names = [c.name for c in UserFollow.__table__.constraints if hasattr(c, 'name') and c.name]
    assert "uq_user_follow" in constraint_names

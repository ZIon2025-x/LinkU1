"""
Admin test fixtures.

Uses FastAPI dependency_overrides to bypass the Redis-backed admin session auth
and the database dependency so smoke tests can run without a live database or
Redis connection.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient

from app.main import app
from app.separate_auth_deps import get_current_admin
from app.deps import get_async_db_dependency
from app import models


def _mock_admin() -> models.AdminUser:
    admin = MagicMock(spec=models.AdminUser)
    admin.id = "test-admin-id"
    admin.is_active = True
    return admin


def _make_mock_db():
    """Return a minimal async mock DB session.

    Supports the patterns used in the admin expert routes:
      - await db.execute(query) -> result with .scalar() / .scalars().all() / .all()
      - await db.commit()
      - await db.rollback()
    """
    # A result object whose scalars().all() and scalar() return empty/None
    mock_result = MagicMock()
    mock_result.scalar.return_value = 0
    mock_result.scalar_one.return_value = 0
    mock_result.scalar_one_or_none.return_value = None
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = []
    mock_result.scalars.return_value = mock_scalars
    mock_result.all.return_value = []

    db = AsyncMock()
    db.execute.return_value = mock_result
    db.commit.return_value = None
    db.rollback.return_value = None
    db.flush.return_value = None
    db.refresh.return_value = None
    return db


async def _get_mock_db():
    yield _make_mock_db()


@pytest.fixture
def admin_auth_headers():
    """
    Override get_current_admin and get_async_db_dependency so TestClient
    requests are authenticated and do not need a real database.

    Returns headers that include Origin: localhost:3001 to pass the admin
    security middleware origin check.
    """
    app.dependency_overrides[get_current_admin] = _mock_admin
    app.dependency_overrides[get_async_db_dependency] = _get_mock_db
    yield {"origin": "http://localhost:3001"}
    app.dependency_overrides.pop(get_current_admin, None)
    app.dependency_overrides.pop(get_async_db_dependency, None)

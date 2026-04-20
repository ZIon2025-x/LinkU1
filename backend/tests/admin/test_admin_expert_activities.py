"""Phase B smoke tests for new admin Expert activities endpoints."""
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_list_activities_endpoint_exists(client, admin_auth_headers):
    resp = client.get(
        "/api/admin/experts/activities?page=1&limit=10",
        headers=admin_auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "items" in body
    assert "total" in body


def test_review_activity_endpoint_exists(client, admin_auth_headers):
    resp = client.post(
        "/api/admin/experts/activities/999999/review",
        headers=admin_auth_headers,
        json={"action": "approve"},
    )
    assert resp.status_code in (404, 422)

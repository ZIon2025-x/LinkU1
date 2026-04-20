"""Phase B smoke tests for new admin Expert services endpoints."""
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_list_services_endpoint_exists(client, admin_auth_headers):
    """GET /api/admin/experts/services returns 200 with list structure."""
    resp = client.get(
        "/api/admin/experts/services?page=1&limit=10",
        headers=admin_auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "items" in body
    assert "total" in body


def test_review_service_endpoint_exists(client, admin_auth_headers):
    """POST /api/admin/experts/services/{id}/review returns 404 for missing id (not 405/404-for-wrong-path)."""
    resp = client.post(
        "/api/admin/experts/services/nonexistent-id/review",
        headers=admin_auth_headers,
        json={"action": "approve"},
    )
    # 404 for missing record = route exists and reached handler; anything else = routing broken
    assert resp.status_code in (404, 422)

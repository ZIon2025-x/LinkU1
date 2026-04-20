"""Phase B C3 regression: old /api/admin/task-expert-* routes must be gone."""
from fastapi.testclient import TestClient
from app.main import app


def test_old_task_expert_services_route_gone(admin_auth_headers):
    client = TestClient(app)
    resp = client.get("/api/admin/task-expert-services", headers=admin_auth_headers)
    assert resp.status_code == 404


def test_old_task_expert_activities_route_gone(admin_auth_headers):
    client = TestClient(app)
    resp = client.get("/api/admin/task-expert-activities", headers=admin_auth_headers)
    assert resp.status_code == 404

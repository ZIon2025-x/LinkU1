"""Tests for user profile API endpoints."""
import pytest


TEST_API_URL = "http://localhost:8000"
REQUEST_TIMEOUT = 10


@pytest.mark.api
class TestUserProfileCapabilities:
    def test_get_capabilities_empty(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_put_capabilities_batch(self, auth_client):
        r = auth_client.put(f"{TEST_API_URL}/api/profile/capabilities", json=[
            {"category_id": 1, "skill_name": "英语沟通", "proficiency": "intermediate"},
            {"category_id": 1, "skill_name": "中文翻译", "proficiency": "expert"},
        ])
        assert r.status_code == 200
        assert r.json()["count"] == 2

    def test_get_capabilities_after_add(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        assert r.status_code == 200
        caps = r.json()
        assert len(caps) >= 2
        names = [c["skill_name"] for c in caps]
        assert "英语沟通" in names

    def test_delete_capability(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        caps = r.json()
        if caps:
            cap_id = caps[0]["id"]
            r = auth_client.delete(f"{TEST_API_URL}/api/profile/capabilities/{cap_id}")
            assert r.status_code == 200

    def test_delete_nonexistent_capability(self, auth_client):
        r = auth_client.delete(f"{TEST_API_URL}/api/profile/capabilities/99999")
        assert r.status_code == 404


@pytest.mark.api
class TestUserProfilePreferences:
    def test_get_preferences_default(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/preferences")
        assert r.status_code == 200
        data = r.json()
        assert "mode" in data

    def test_put_preferences(self, auth_client):
        r = auth_client.put(f"{TEST_API_URL}/api/profile/preferences", json={
            "mode": "online",
            "preferred_categories": [1, 2],
            "preferred_time_slots": ["weekday_evening", "weekend"],
        })
        assert r.status_code == 200

    def test_get_preferences_after_update(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/preferences")
        assert r.status_code == 200
        data = r.json()
        assert data["mode"] == "online"
        assert 1 in data["preferred_categories"]


@pytest.mark.api
class TestUserProfileReadOnly:
    def test_get_reliability(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/reliability")
        assert r.status_code == 200
        data = r.json()
        assert "reliability_score" in data
        assert "insufficient_data" in data

    def test_get_demand(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/demand")
        assert r.status_code == 200
        data = r.json()
        assert "user_stage" in data
        assert "predicted_needs" in data

    def test_get_summary(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/summary")
        assert r.status_code == 200
        data = r.json()
        assert "capabilities" in data
        assert "preference" in data
        assert "reliability" in data
        assert "demand" in data


@pytest.mark.api
class TestOnboarding:
    def test_submit_onboarding(self, auth_client):
        r = auth_client.post(f"{TEST_API_URL}/api/profile/onboarding", json={
            "capabilities": [
                {"category_id": 1, "skill_name": "英语沟通"},
                {"category_id": 3, "skill_name": "搬家"},
            ],
            "mode": "offline",
            "preferred_categories": [1, 3],
        })
        assert r.status_code == 200

    def test_onboarding_creates_demand(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/demand")
        assert r.status_code == 200
        data = r.json()
        assert data["user_stage"] is not None

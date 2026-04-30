"""验证 GET /profile/{user_id} 返回 personal_services 字段。"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import get_db
from app.models import TaskExpertService, User


@pytest.fixture
def client(db: Session) -> TestClient:
    """TestClient with get_db overridden to share fixture session."""
    def _override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = _override_get_db
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.fixture
def user_with_services(db: Session) -> User:
    user = User(
        id="00000099",
        name="测试用户_ps99",
        email="ps_test_99@example.com",
        hashed_password="x",
        user_level="normal",
    )
    db.add(user)
    db.flush()

    db.add(TaskExpertService(
        owner_type="user", owner_id=user.id, user_id=user.id,
        service_type="personal", service_name="家教 · 小学数学",
        description="UCL 在读，可上门或线上",
        category="tutoring", base_price=15.0, currency="GBP",
        pricing_type="fixed", location_type="both",
        status="active", display_order=0,
    ))
    db.add(TaskExpertService(
        owner_type="user", owner_id=user.id, user_id=user.id,
        service_type="personal", service_name="代取快递",
        description="伦敦市内 30 分钟响应",
        category="errand", base_price=8.0, currency="GBP",
        pricing_type="fixed", location_type="in_person",
        status="active", display_order=1,
    ))
    db.add(TaskExpertService(
        owner_type="user", owner_id=user.id, user_id=user.id,
        service_type="personal", service_name="已下架",
        description="should not appear",
        category="other", base_price=10.0, currency="GBP",
        pricing_type="fixed", location_type="online",
        status="inactive", display_order=2,
    ))
    db.flush()
    return user


def test_profile_returns_personal_services(client: TestClient, user_with_services: User):
    resp = client.get(f"/api/profile/{user_with_services.id}")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "personal_services" in data, f"keys: {list(data.keys())}"
    services = data["personal_services"]
    assert isinstance(services, list)
    assert len(services) == 2
    assert services[0]["service_name"] == "家教 · 小学数学"
    assert services[1]["service_name"] == "代取快递"
    first = services[0]
    for key in ("id", "service_name", "category", "base_price", "currency",
                "pricing_type", "location_type", "images", "status"):
        assert key in first, f"missing {key} in {first}"


def test_profile_returns_empty_personal_services_when_user_has_none(
    client: TestClient, db: Session
):
    user = User(
        id="00000098",
        name="无服务用户_ps98",
        email="nops_98@example.com",
        hashed_password="x",
        user_level="normal",
    )
    db.add(user)
    db.flush()

    resp = client.get(f"/api/profile/{user.id}")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["personal_services"] == []

"""
Smoke test for the routers.py split refactor.

For each domain that gets extracted, verify at least one representative route
is still reachable at BOTH /api/ and /api/users/ prefixes. Asserts HTTP status
code only — not business logic.

If a route's auth behavior turns out differently than asserted here during
execution, adjust the expected code inline. The goal is to catch:
  - Router not registered at all (→ 404)
  - Router registered at only one prefix (→ 404 on the other)
  - Import error in the new module (→ 500 or collection error)
"""
from __future__ import annotations

import os
import sys
import pytest
from fastapi.testclient import TestClient

# Ensure app module can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


# (domain, method, path, expected_status_codes)
# Both /api/<p> and /api/users/<p> should be reachable.
SMOKE_PROBES: list[tuple[str, str, str, tuple[int, ...]]] = [
    ("auth_inline", "POST", "/csp-report", (204, 400, 422)),
    ("task", "GET", "/tasks/1/history", (401, 403)),
    ("refund", "GET", "/tasks/1/refund-status", (401, 403)),
    ("profile", "GET", "/profile/me", (401, 403)),
    ("message", "GET", "/messages/unread/count", (401, 403)),
    ("payment_inline", "POST", "/stripe/webhook", (400, 422, 500)),
    ("cs", "GET", "/customer-service/status", (200, 401, 403)),
    ("translation", "GET", "/translate/metrics", (200, 401, 403)),
    ("system", "GET", "/banners", (200,)),
    ("system", "GET", "/faq", (200,)),
    ("upload_inline", "POST", "/upload/image", (401, 403, 422)),
]


@pytest.mark.parametrize("domain,method,path,expected", SMOKE_PROBES)
@pytest.mark.parametrize("prefix", ["/api", "/api/users"])
def test_route_reachable_at_both_prefixes(
    client: TestClient,
    prefix: str,
    domain: str,
    method: str,
    path: str,
    expected: tuple[int, ...],
):
    url = f"{prefix}{path}"
    resp = client.request(method, url)
    assert resp.status_code in expected, (
        f"{method} {url} returned {resp.status_code}, expected one of {expected}. "
        f"Domain={domain}. "
        f"If this is a genuine behavior change, update SMOKE_PROBES inline."
    )

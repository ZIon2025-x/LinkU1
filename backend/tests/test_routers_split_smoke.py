"""
Smoke test for the routers.py split refactor.

For each domain, verify at least one representative route is reachable
at the prefixes that domain is actually mounted under (see _SPLIT_ROUTERS
in app/main.py). After the 2026-04-26 prefix audit, four domains are
single-mounted at /api only — translation, upload_inline, refund,
payment_inline — because no real client (Flutter / React Web) was calling
the /api/users mirror. The smoke test reflects that.

Asserts HTTP status code only — not business logic. The goal is to catch:
  - Router not registered at all (→ 404)
  - Router unexpectedly missing a prefix it should be mounted at
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


_DUAL = ("/api", "/api/users")
_API_ONLY = ("/api",)

# (domain, method, path, expected_status_codes, prefixes_to_probe)
# prefixes_to_probe must match the domain's _SPLIT_ROUTERS configuration.
SMOKE_PROBES: list[tuple[str, str, str, tuple[int, ...], tuple[str, ...]]] = [
    ("auth_inline",    "POST", "/csp-report",            (204, 400, 422), _DUAL),
    ("task",           "GET",  "/tasks/1/history",       (401, 403),       _DUAL),
    ("refund",         "GET",  "/tasks/1/refund-status", (401, 403),       _API_ONLY),
    ("profile",        "GET",  "/profile/me",            (401, 403),       _DUAL),
    ("message",        "GET",  "/messages/unread/count", (401, 403),       _DUAL),
    ("payment_inline", "POST", "/stripe/webhook",        (400, 422, 500),  _API_ONLY),
    ("cs",             "GET",  "/customer-service/status",(200, 401, 403), _DUAL),
    ("translation",    "GET",  "/translate/metrics",     (200, 401, 403),  _API_ONLY),
    ("system",         "GET",  "/banners",               (200,),           _DUAL),
    ("system",         "GET",  "/faq",                   (200,),           _DUAL),
    ("upload_inline",  "POST", "/upload/image",          (401, 403, 422),  _API_ONLY),
]


def _expand(probes):
    for domain, method, path, expected, prefixes in probes:
        for prefix in prefixes:
            yield pytest.param(prefix, domain, method, path, expected,
                               id=f"{prefix}-{domain}-{method}-{path}")


@pytest.mark.parametrize("prefix,domain,method,path,expected", list(_expand(SMOKE_PROBES)))
def test_route_reachable_at_expected_prefixes(
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

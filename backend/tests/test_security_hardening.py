import pytest
from fastapi import HTTPException
from starlette.requests import Request
from starlette.responses import Response


def test_signed_url_manager_rejects_insecure_key_in_production(monkeypatch):
    from app.signed_url import SignedURLManager

    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("SIGNED_URL_SECRET", raising=False)
    monkeypatch.setenv("SECRET_KEY", "change-this-secret-key-in-production")

    with pytest.raises(RuntimeError):
        SignedURLManager()


def test_set_cors_headers_without_request_uses_controlled_origin(monkeypatch):
    from app.config import Config
    from app.error_handlers import set_cors_headers

    monkeypatch.setattr(Config, "ALLOWED_ORIGINS", ["https://safe.example.com"])
    response = Response()
    set_cors_headers(response, None)

    assert response.headers.get("Access-Control-Allow-Origin") == "https://safe.example.com"
    assert response.headers.get("Access-Control-Allow-Origin") != "*"


def test_resolve_legacy_private_file_path_blocks_traversal(tmp_path):
    from app.routers import _resolve_legacy_private_file_path

    base_private_dir = tmp_path / "uploads" / "private"
    base_private_dir.mkdir(parents=True, exist_ok=True)

    allowed = _resolve_legacy_private_file_path(base_private_dir, "files/demo.txt")
    assert str(allowed).startswith(str(base_private_dir.resolve()))

    with pytest.raises(HTTPException) as exc_info:
        _resolve_legacy_private_file_path(base_private_dir, "../secret.txt")
    assert exc_info.value.status_code == 403


def test_rate_limiter_client_ip_handles_none_client(monkeypatch):
    from app.rate_limiting import RateLimiter, settings

    monkeypatch.setattr(settings, "USE_REDIS", False)
    rate_limiter = RateLimiter()

    request = Request(
        {
            "type": "http",
            "method": "GET",
            "path": "/",
            "headers": [],
            "client": None,
        }
    )

    assert rate_limiter._get_client_ip(request) == "unknown"

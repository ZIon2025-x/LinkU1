"""
OAuth 2.0 / OIDC Provider 路由
GET /api/oauth/authorize, POST /api/oauth/consent, POST /api/oauth/token,
GET /api/oauth/userinfo, GET /.well-known/openid-configuration
"""

import base64
import html
import logging
import urllib.parse
from typing import Any, Dict, Optional, Tuple

from fastapi import APIRouter, Depends, Form, Request, Response, status
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from sqlalchemy.orm import Session

from app.config import get_settings
from app.deps import get_sync_db
from app import crud
from app.oauth.oauth_service import (
    get_client,
    validate_redirect_uri,
    validate_client_secret,
    create_authorization_code,
    consume_authorization_code,
    issue_tokens,
    verify_oauth_access_token,
    refresh_tokens,
    parse_scope,
    SUPPORTED_SCOPES,
    SCOPE_OPENID,
)
from app.secure_auth import validate_session
from app.rate_limiting import rate_limit

logger = logging.getLogger(__name__)

oauth_router = APIRouter(tags=["OAuth 2.0 / OIDC Provider"])

ERROR_URI_BASE = "https://docs.link2ur.com/oauth/errors"


def _redirect_uri_has_fragment(redirect_uri: str) -> bool:
    """RFC 6749: redirect_uri 不得包含 fragment"""
    return "#" in redirect_uri


def _parse_basic_auth(auth_header: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    """解析 Authorization: Basic base64(client_id:client_secret)，返回 (client_id, client_secret) 或 (None, None)"""
    if not auth_header or not auth_header.strip().lower().startswith("basic "):
        return None, None
    try:
        b64 = auth_header.strip()[6:].strip()
        raw = base64.b64decode(b64, validate=True).decode("utf-8")
        if ":" not in raw:
            return None, None
        cid, secret = raw.split(":", 1)
        return (cid.strip() or None, secret or None)
    except Exception:
        return None, None


def _redirect_error(redirect_uri: str, error: str, error_description: str, state: Optional[str] = None) -> RedirectResponse:
    q = {"error": error, "error_description": error_description}
    if state:
        q["state"] = state
    loc = redirect_uri + ("&" if "?" in redirect_uri else "?") + urllib.parse.urlencode(q)
    return RedirectResponse(url=loc, status_code=status.HTTP_302_FOUND)


def _token_error(error: str, error_description: str, status_code: int = 400) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "error": error,
            "error_description": error_description,
            "error_uri": f"{ERROR_URI_BASE}#{error}",
        },
    )


@oauth_router.get("/api/oauth/authorize", response_class=HTMLResponse)
@rate_limit("oauth_authorize")
def oauth_authorize(
    request: Request,
    response_type: Optional[str] = None,
    client_id: Optional[str] = None,
    redirect_uri: Optional[str] = None,
    scope: Optional[str] = None,
    state: Optional[str] = None,
    nonce: Optional[str] = None,
    code_challenge: Optional[str] = None,
    code_challenge_method: Optional[str] = None,
    prompt: Optional[str] = None,
    db: Session = Depends(get_sync_db),
):
    """授权端点：校验参数，未登录则重定向到登录页，已登录则展示同意页（HTML）"""
    settings = get_settings()
    if not response_type or response_type != "code":
        return HTMLResponse(
            content="<html><body><p>Invalid request: response_type must be 'code'.</p></body></html>",
            status_code=400,
        )
    if not client_id or not redirect_uri:
        return HTMLResponse(
            content="<html><body><p>Invalid request: client_id and redirect_uri are required.</p></body></html>",
            status_code=400,
        )
    if _redirect_uri_has_fragment(redirect_uri):
        return _redirect_error(redirect_uri, "invalid_request", "redirect_uri must not contain a fragment", state)

    client = get_client(db, client_id)
    if not client:
        logger.warning("OAuth authorize: unknown or inactive client_id=%s", client_id[:8] if client_id else "")
        return HTMLResponse(
            content="<html><body><p>Unknown or disabled application.</p></body></html>",
            status_code=400,
        )
    if not getattr(client, "is_active", True):
        return HTMLResponse(content="<html><body><p>Application is disabled.</p></body></html>", status_code=400)

    if not validate_redirect_uri(client, redirect_uri):
        logger.warning("OAuth authorize: redirect_uri mismatch for client_id=%s", client_id[:8])
        return _redirect_error(redirect_uri, "invalid_request", "redirect_uri mismatch", state)

    scopes = parse_scope(scope or "")
    if scope and SCOPE_OPENID in (scope or "").split() and SCOPE_OPENID not in scopes:
        scopes.insert(0, SCOPE_OPENID)
    if not scopes:
        scopes = [SCOPE_OPENID]
    invalid = [s for s in (scope or "").split() if s.strip() and s.strip() not in SUPPORTED_SCOPES]
    if invalid:
        return _redirect_error(redirect_uri, "invalid_scope", "Unsupported scope(s): " + ",".join(invalid), state)

    session = validate_session(request)
    if not session:
        return_to = str(request.url)
        login_url = f"{settings.FRONTEND_URL}/login?return_to={urllib.parse.quote(return_to)}"
        return RedirectResponse(url=login_url, status_code=status.HTTP_302_FOUND)

    scope_str = " ".join(scopes)
    client_name = getattr(client, "client_name", "Unknown App")
    logo_uri = getattr(client, "logo_uri", None) or ""
    client_uri = getattr(client, "client_uri", None) or ""
    accept_lang = request.headers.get("Accept-Language", "") or ""
    lang = "zh" if "zh" in accept_lang.lower() else "en"
    consent_html = _consent_page_html(
        client_name=client_name,
        scope_str=scope_str,
        state=state or "",
        redirect_uri=redirect_uri,
        client_id=client_id,
        nonce=nonce or "",
        code_challenge=code_challenge or "",
        code_challenge_method=code_challenge_method or "",
        logo_uri=logo_uri,
        client_uri=client_uri,
        lang=lang,
    )
    return HTMLResponse(content=consent_html)


def _consent_page_html(
    client_name: str,
    scope_str: str,
    state: str,
    redirect_uri: str,
    client_id: str,
    nonce: str,
    code_challenge: str,
    code_challenge_method: str,
    logo_uri: str = "",
    client_uri: str = "",
    lang: str = "en",
) -> str:
    scope_descriptions = []
    for s in scope_str.split():
        if s == "openid":
            scope_descriptions.append("验证你的身份" if lang == "zh" else "Verify your identity")
        elif s == "profile":
            scope_descriptions.append("读取你的昵称和头像" if lang == "zh" else "Read your name and profile picture")
        elif s == "email":
            scope_descriptions.append("读取你的邮箱" if lang == "zh" else "Read your email address")
    lines = "<br>".join(scope_descriptions) if scope_descriptions else ("基本身份信息" if lang == "zh" else "Basic identity")
    action = "/api/oauth/consent"
    title = f"{html.escape(client_name)} " + ("请求访问你的 Link²Ur 账号" if lang == "zh" else "wants to access your Link²Ur account")
    intro = "它将可以：" if lang == "zh" else "It will be able to:"
    allow_btn = "同意" if lang == "zh" else "Allow"
    deny_btn = "拒绝" if lang == "zh" else "Deny"
    logo_block = f'<p><img src="{html.escape(logo_uri)}" alt="" width="48" height="48"/></p>' if logo_uri else ""
    link_block = f'<p><a href="{html.escape(client_uri)}" rel="noopener">{html.escape(client_name)}</a></p>' if client_uri else ""
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{html.escape("授权" if lang == "zh" else "Authorize")}</title></head>
<body>
  {logo_block}
  {link_block}
  <h2>{title}</h2>
  <p>{intro}</p>
  <p>{lines}</p>
  <form method="post" action="{action}">
    <input type="hidden" name="state" value="{html.escape(state)}"/>
    <input type="hidden" name="redirect_uri" value="{html.escape(redirect_uri)}"/>
    <input type="hidden" name="client_id" value="{html.escape(client_id)}"/>
    <input type="hidden" name="scope" value="{html.escape(scope_str)}"/>
    <input type="hidden" name="nonce" value="{html.escape(nonce)}"/>
    <input type="hidden" name="code_challenge" value="{html.escape(code_challenge)}"/>
    <input type="hidden" name="code_challenge_method" value="{html.escape(code_challenge_method)}"/>
    <button type="submit" name="confirm" value="yes">{allow_btn}</button>
    <button type="submit" name="confirm" value="no">{deny_btn}</button>
  </form>
</body></html>"""


@oauth_router.post("/api/oauth/consent")
@rate_limit("oauth_consent")
def oauth_consent(
    request: Request,
    state: Optional[str] = Form(None),
    redirect_uri: Optional[str] = Form(None),
    client_id: Optional[str] = Form(None),
    scope: Optional[str] = Form(None),
    nonce: Optional[str] = Form(None),
    code_challenge: Optional[str] = Form(None),
    code_challenge_method: Optional[str] = Form(None),
    confirm: Optional[str] = Form(None),
    db: Session = Depends(get_sync_db),
):
    """同意页提交：同意则生成 code 并重定向到 redirect_uri?code=...&state=...；拒绝则 error=access_denied"""
    session = validate_session(request)
    if not session:
        settings = get_settings()
        return RedirectResponse(
            url=f"{settings.FRONTEND_URL}/login",
            status_code=status.HTTP_302_FOUND,
        )
    if not redirect_uri or not client_id:
        return HTMLResponse(content="<p>Missing redirect_uri or client_id.</p>", status_code=400)
    if _redirect_uri_has_fragment(redirect_uri):
        return _redirect_error(redirect_uri, "invalid_request", "redirect_uri must not contain a fragment", state)

    client = get_client(db, client_id)
    if not client or not validate_redirect_uri(client, redirect_uri):
        return _redirect_error(redirect_uri, "invalid_request", "Invalid client or redirect_uri", state)

    scope_str = (scope or "openid").strip() or "openid"
    if confirm == "no":
        return _redirect_error(redirect_uri, "access_denied", "User denied authorization", state)

    code = create_authorization_code(
        client_id=client_id,
        user_id=session.user_id,
        redirect_uri=redirect_uri,
        scope=scope_str,
        state=state or "",
        nonce=nonce or None,
        code_challenge=code_challenge or None,
        code_challenge_method=code_challenge_method or None,
    )
    loc = redirect_uri + ("&" if "?" in redirect_uri else "?") + urllib.parse.urlencode({"code": code, "state": state or ""})
    return RedirectResponse(url=loc, status_code=status.HTTP_302_FOUND)


@oauth_router.post("/api/oauth/token")
@rate_limit("oauth_token")
async def oauth_token(
    request: Request,
    db: Session = Depends(get_sync_db),
):
    """Token 端点：application/x-www-form-urlencoded，grant_type=authorization_code 或 refresh_token"""
    try:
        body = await request.form()
    except Exception:
        return _token_error("invalid_request", "Request body must be application/x-www-form-urlencoded")

    grant_type = body.get("grant_type")
    basic_id, basic_secret = _parse_basic_auth(request.headers.get("Authorization"))
    client_id = body.get("client_id") or basic_id
    client_secret = body.get("client_secret") or basic_secret
    if not grant_type or not client_id:
        return _token_error("invalid_request", "grant_type and client_id are required")

    client = get_client(db, client_id)
    if not client:
        return _token_error("invalid_client", "Unknown or disabled client", 401)
    if not getattr(client, "is_active", True):
        return _token_error("invalid_client", "Client is disabled", 401)

    if grant_type == "authorization_code":
        code = body.get("code")
        redirect_uri = body.get("redirect_uri")
        if not code or not redirect_uri:
            return _token_error("invalid_request", "code and redirect_uri are required")
        code_verifier = body.get("code_verifier")
        if getattr(client, "is_confidential", True) and not validate_client_secret(client, client_secret or ""):
            return _token_error("invalid_client", "Invalid client_secret", 401)
        result = consume_authorization_code(code, client_id, redirect_uri, code_verifier=code_verifier or None)
        if not result:
            return _token_error("invalid_grant", "The provided authorization grant is invalid, expired, or revoked.")
        user_id, scope, nonce = result
        allowed = getattr(client, "allowed_grant_types", None) or ["authorization_code"]
        if "refresh_token" in allowed:
            out = issue_tokens(user_id, client_id, scope, nonce=nonce, db=db)
        else:
            out = issue_tokens(user_id, client_id, scope, nonce=nonce, db=None)
            out.pop("refresh_token", None)
        return JSONResponse(content=out)
    elif grant_type == "refresh_token":
        refresh_token = body.get("refresh_token")
        if not refresh_token:
            return _token_error("invalid_request", "refresh_token is required")
        allowed = getattr(client, "allowed_grant_types", None) or []
        if "refresh_token" not in allowed:
            return _token_error("unauthorized_client", "Refresh token not allowed for this client")
        if getattr(client, "is_confidential", True) and not validate_client_secret(client, client_secret or ""):
            return _token_error("invalid_client", "Invalid client_secret", 401)
        out = refresh_tokens(refresh_token, client_id, db)
        if not out:
            return _token_error("invalid_grant", "The provided refresh token is invalid or expired.")
        return JSONResponse(content=out)
    else:
        return _token_error("unsupported_grant_type", "Unsupported grant_type")


@oauth_router.get("/api/oauth/userinfo")
def oauth_userinfo(
    request: Request,
    db: Session = Depends(get_sync_db),
):
    """UserInfo 端点：Bearer access_token，返回 OIDC UserInfo claims"""
    auth = request.headers.get("Authorization")
    if not auth or not auth.startswith("Bearer "):
        return JSONResponse(
            status_code=401,
            content={"error": "invalid_token", "error_description": "Missing or invalid Authorization header"},
            headers={"WWW-Authenticate": "Bearer error=\"invalid_token\""},
        )
    token = auth[7:].strip()
    payload = verify_oauth_access_token(token)
    if not payload:
        return JSONResponse(
            status_code=401,
            content={"error": "invalid_token", "error_description": "The access token is invalid or expired."},
            headers={"WWW-Authenticate": "Bearer error=\"invalid_token\""},
        )
    user_id = payload.get("sub")
    scope = (payload.get("scope") or "").split()
    user = crud.get_user_by_id(db, user_id)
    if not user:
        return JSONResponse(status_code=401, content={"error": "invalid_token", "error_description": "User not found"})
    claims = {"sub": user.id}
    if SCOPE_OPENID in scope or "profile" in scope or SCOPE_PROFILE in scope:
        claims["name"] = user.name or ""
        claims["picture"] = user.avatar or ""
        created = getattr(user, "created_at", None)
        name_updated = getattr(user, "name_updated_at", None)
        if created is not None:
            ts = int(created.timestamp()) if hasattr(created, "timestamp") else None
            if name_updated is not None and hasattr(name_updated, "timestamp"):
                ts = max(ts or 0, int(name_updated.timestamp()))
            if ts is not None:
                claims["updated_at"] = ts
    if "email" in scope or SCOPE_EMAIL in scope:
        claims["email"] = user.email or ""
        claims["email_verified"] = bool(getattr(user, "is_verified", 0))
    if "locale" not in claims and getattr(user, "language_preference", None):
        claims["locale"] = (user.language_preference or "en").replace("en", "en").replace("zh", "zh-CN")
    return JSONResponse(content=claims)


@oauth_router.get("/.well-known/openid-configuration")
def openid_configuration(request: Request):
    """OIDC 发现端点"""
    settings = get_settings()
    issuer = (settings.OAUTH_ISSUER or settings.BASE_URL or "").rstrip("/")
    base = issuer
    return JSONResponse(
        content={
            "issuer": issuer,
            "authorization_endpoint": f"{base}/api/oauth/authorize",
            "token_endpoint": f"{base}/api/oauth/token",
            "userinfo_endpoint": f"{base}/api/oauth/userinfo",
            "scopes_supported": ["openid", "profile", "email"],
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "subject_types_supported": ["public"],
            "id_token_signing_alg_values_supported": ["HS256"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["client_secret_post", "client_secret_basic"],
        }
    )

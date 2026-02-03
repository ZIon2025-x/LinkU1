"""
OAuth 2.0 / OIDC Provider 核心逻辑
授权码存 Redis，refresh_token 存表或 Redis，access_token/id_token 为 JWT
"""

import base64
import hashlib
import json
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import jwt
from sqlalchemy.orm import Session

from app.config import get_settings
from app import models
from app.security import verify_password, get_password_hash

logger = logging.getLogger(__name__)

try:
    from app.redis_cache import get_redis_client
    _redis = get_redis_client()
    OAUTH_USE_REDIS = _redis is not None
except Exception:
    _redis = None
    OAUTH_USE_REDIS = False

# 内存 fallback（无 Redis 时授权码仅内存，重启丢失）
_oauth_codes: Dict[str, Dict[str, Any]] = {}
_oauth_refresh: Dict[str, Dict[str, Any]] = {}

SCOPE_OPENID = "openid"
SCOPE_PROFILE = "profile"
SCOPE_EMAIL = "email"
SUPPORTED_SCOPES = {SCOPE_OPENID, SCOPE_PROFILE, SCOPE_EMAIL}

CODE_TTL = 600  # 10 min
CLIENT_CACHE_TTL = 300  # 5 min
OAUTH_CODE_PREFIX = "oauth:code:"
OAUTH_REFRESH_PREFIX = "oauth:refresh:"
OAUTH_CLIENT_CACHE_PREFIX = "oauth:client:"


def _get_issuer() -> str:
    s = get_settings()
    return (s.OAUTH_ISSUER or s.BASE_URL or "").rstrip("/")


def _get_access_token_secret() -> str:
    s = get_settings()
    return s.OAUTH_ACCESS_TOKEN_SECRET or s.SECRET_KEY


def _get_id_token_secret() -> str:
    s = get_settings()
    return s.OAUTH_ID_TOKEN_SECRET or s.OAUTH_ACCESS_TOKEN_SECRET or s.SECRET_KEY


def _redis_get(key: str) -> Optional[str]:
    if not OAUTH_USE_REDIS or not _redis:
        return None
    try:
        val = _redis.get(key)
        if val is None:
            return None
        if isinstance(val, bytes):
            return val.decode("utf-8")
        return str(val)
    except Exception as e:
        logger.warning("OAuth Redis get failed: %s", e)
        return None


def _redis_setex(key: str, ttl: int, value: str) -> bool:
    if not OAUTH_USE_REDIS or not _redis:
        return False
    try:
        _redis.setex(key, ttl, value)
        return True
    except Exception as e:
        logger.warning("OAuth Redis setex failed: %s", e)
        return False


def _redis_delete(key: str) -> bool:
    if not OAUTH_USE_REDIS or not _redis:
        return False
    try:
        _redis.delete(key)
        return True
    except Exception as e:
        logger.warning("OAuth Redis delete failed: %s", e)
        return False


def invalidate_oauth_client_cache(client_id: str) -> None:
    """管理员更新或轮换客户端后使缓存失效，便于立即生效"""
    key = OAUTH_CLIENT_CACHE_PREFIX + client_id
    _redis_delete(key)


def get_client(db: Session, client_id: str) -> Optional[models.OAuthClient]:
    """获取 OAuth 客户端，可选 Redis 缓存"""
    cache_key = OAUTH_CLIENT_CACHE_PREFIX + client_id
    if OAUTH_USE_REDIS and _redis:
        try:
            raw = _redis.get(cache_key)
            if raw is not None:
                data = json.loads(raw.decode("utf-8") if isinstance(raw, bytes) else raw)
                # 返回简单对象，兼容后续 validate_redirect_uri 等（需要 redirect_uris, is_confidential）
                class C:
                    pass
                c = C()
                c.client_id = data["client_id"]
                c.client_secret_hash = data.get("client_secret_hash")
                c.redirect_uris = data["redirect_uris"]
                c.is_confidential = data.get("is_confidential", True)
                c.is_active = data.get("is_active", True)
                c.client_name = data.get("client_name", "")
                c.client_uri = data.get("client_uri") or ""
                c.logo_uri = data.get("logo_uri") or ""
                c.allowed_grant_types = data.get("allowed_grant_types", ["authorization_code"])
                c.scope_default = data.get("scope_default")
                return c
        except Exception:
            pass
    client = db.query(models.OAuthClient).filter(
        models.OAuthClient.client_id == client_id,
        models.OAuthClient.is_active == True,
    ).first()
    if client and OAUTH_USE_REDIS and _redis:
        try:
            payload = {
                "client_id": client.client_id,
                "client_secret_hash": client.client_secret_hash,
                "redirect_uris": client.redirect_uris or [],
                "is_confidential": client.is_confidential,
                "is_active": client.is_active,
                "client_name": client.client_name,
                "client_uri": client.client_uri or "",
                "logo_uri": client.logo_uri or "",
                "allowed_grant_types": list(client.allowed_grant_types) if client.allowed_grant_types else ["authorization_code"],
                "scope_default": client.scope_default,
            }
            _redis.setex(cache_key, CLIENT_CACHE_TTL, json.dumps(payload, default=str))
        except Exception:
            pass
    return client


def validate_redirect_uri(client: Any, redirect_uri: str) -> bool:
    """严格白名单：redirect_uri 必须与注册的某一项完全一致"""
    uris = getattr(client, "redirect_uris", None) or []
    if isinstance(uris, str):
        uris = json.loads(uris) if uris else []
    return redirect_uri in uris


def make_code_challenge(code_verifier: str) -> str:
    """S256: BASE64URL(SHA256(ASCII(code_verifier)))"""
    digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def verify_code_verifier(code_verifier: str, code_challenge: str) -> bool:
    """校验 PKCE code_verifier 与 code_challenge"""
    if not code_verifier or not code_challenge:
        return False
    expected = make_code_challenge(code_verifier)
    return secrets.compare_digest(expected, code_challenge)


def create_authorization_code(
    client_id: str,
    user_id: str,
    redirect_uri: str,
    scope: str,
    state: str,
    nonce: Optional[str] = None,
    code_challenge: Optional[str] = None,
    code_challenge_method: Optional[str] = None,
) -> str:
    """生成授权码并存入 Redis（或内存），返回 code"""
    code = secrets.token_urlsafe(32)
    payload = {
        "client_id": client_id,
        "user_id": user_id,
        "redirect_uri": redirect_uri,
        "scope": scope,
        "state": state,
        "nonce": nonce,
        "code_challenge": code_challenge,
        "code_challenge_method": code_challenge_method,
    }
    ttl = get_settings().OAUTH_AUTHORIZATION_CODE_EXPIRE_SECONDS
    if _redis_setex(OAUTH_CODE_PREFIX + code, ttl, json.dumps(payload)):
        return code
    _oauth_codes[code] = {**payload, "_exp": datetime.now(timezone.utc).timestamp() + ttl}
    return code


def consume_authorization_code(
    code: str,
    client_id: str,
    redirect_uri: str,
    code_verifier: Optional[str] = None,
) -> Optional[Tuple[str, str, Optional[str]]]:
    """
    使用授权码：从 Redis/内存取出并删除，校验 client_id、redirect_uri、PKCE。
    返回 (user_id, scope, nonce) 或 None。
    """
    key = OAUTH_CODE_PREFIX + code
    raw = _redis_get(key)
    if raw:
        _redis_delete(key)
        try:
            data = json.loads(raw)
        except Exception:
            return None
    else:
        data = _oauth_codes.pop(code, None)
        if not data:
            return None
        # 简单过期检查
        exp = data.get("_exp")
        if exp and datetime.now(timezone.utc).timestamp() > exp:
            return None

    if data.get("client_id") != client_id or data.get("redirect_uri") != redirect_uri:
        return None
    if data.get("code_challenge"):
        if not code_verifier or not verify_code_verifier(code_verifier, data["code_challenge"]):
            return None
    return (data["user_id"], data["scope"], data.get("nonce"))


def issue_tokens(
    user_id: str,
    client_id: str,
    scope: str,
    nonce: Optional[str] = None,
    db: Optional[Session] = None,
) -> Dict[str, Any]:
    """签发 access_token（JWT）、id_token（JWT）、refresh_token（随机，存 Redis 或表）"""
    settings = get_settings()
    issuer = _get_issuer()
    now = datetime.now(timezone.utc)
    access_exp = settings.OAUTH_ACCESS_TOKEN_EXPIRE_SECONDS
    access_expires = now + timedelta(seconds=access_exp)
    id_expires = now + timedelta(seconds=access_exp)

    access_payload = {
        "sub": user_id,
        "client_id": client_id,
        "scope": scope,
        "iss": issuer,
        "aud": client_id,
        "exp": int(access_expires.timestamp()),
        "iat": int(now.timestamp()),
        "type": "oauth_access",
    }
    access_token = jwt.encode(
        access_payload,
        _get_access_token_secret(),
        algorithm="HS256",
    )
    if hasattr(access_token, "decode"):
        access_token = access_token.decode("utf-8")

    id_payload = {
        "iss": issuer,
        "sub": user_id,
        "aud": client_id,
        "exp": int(id_expires.timestamp()),
        "iat": int(now.timestamp()),
    }
    if nonce:
        id_payload["nonce"] = nonce
    id_token = jwt.encode(
        id_payload,
        _get_id_token_secret(),
        algorithm="HS256",
    )
    if hasattr(id_token, "decode"):
        id_token = id_token.decode("utf-8")

    refresh_token = secrets.token_urlsafe(32)
    refresh_exp_days = settings.OAUTH_REFRESH_TOKEN_EXPIRE_DAYS
    refresh_expires = now + timedelta(days=refresh_exp_days)
    refresh_ttl = refresh_exp_days * 24 * 3600
    refresh_payload = {
        "user_id": user_id,
        "client_id": client_id,
        "scope": scope,
    }
    if _redis_setex(OAUTH_REFRESH_PREFIX + refresh_token, refresh_ttl, json.dumps(refresh_payload)):
        pass
    else:
        _oauth_refresh[refresh_token] = {**refresh_payload, "_exp": refresh_expires.timestamp()}
        if db:
            rt = models.OAuthRefreshToken(
                token=refresh_token,
                client_id=client_id,
                user_id=user_id,
                scope=scope,
                expires_at=refresh_expires,
            )
            db.add(rt)
            db.commit()

    return {
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": access_exp,
        "refresh_token": refresh_token,
        "scope": scope,
        "id_token": id_token,
    }


def verify_oauth_access_token(token: str) -> Optional[Dict[str, Any]]:
    """验证 OAuth access_token JWT，返回 payload 或 None"""
    try:
        payload = jwt.decode(
            token,
            _get_access_token_secret(),
            algorithms=["HS256"],
            audience=None,
            options={"verify_aud": False},
        )
        if payload.get("type") != "oauth_access":
            return None
        return payload
    except Exception:
        return None


def refresh_tokens(
    refresh_token: str,
    client_id: str,
    db: Session,
) -> Optional[Dict[str, Any]]:
    """用 refresh_token 换取新的 access_token、id_token；可选轮换 refresh_token（当前实现不轮换）"""
    key = OAUTH_REFRESH_PREFIX + refresh_token
    raw = _redis_get(key)
    if raw:
        try:
            data = json.loads(raw)
        except Exception:
            return None
        user_id = data.get("user_id")
        cid = data.get("client_id")
        scope = data.get("scope")
        if cid != client_id or not user_id:
            return None
        return issue_tokens(user_id, client_id, scope, nonce=None, db=db)
    data = _oauth_refresh.get(refresh_token)
    if data:
        if data.get("client_id") != client_id:
            return None
        if data.get("_exp") and datetime.now(timezone.utc).timestamp() > data["_exp"]:
            _oauth_refresh.pop(refresh_token, None)
            return None
        user_id = data["user_id"]
        scope = data["scope"]
        return issue_tokens(user_id, client_id, scope, nonce=None, db=db)
    # 表
    rt = db.query(models.OAuthRefreshToken).filter(
        models.OAuthRefreshToken.token == refresh_token,
        models.OAuthRefreshToken.client_id == client_id,
    ).first()
    if not rt or rt.expires_at <= datetime.now(timezone.utc):
        return None
    return issue_tokens(rt.user_id, rt.client_id, rt.scope, nonce=None, db=db)


def validate_client_secret(client: Any, client_secret: str) -> bool:
    """校验 client_secret（仅机密客户端）"""
    if not getattr(client, "is_confidential", True):
        return True
    h = getattr(client, "client_secret_hash", None)
    if not h:
        return False
    return verify_password(client_secret, h)


def parse_scope(scope_str: str) -> List[str]:
    """解析 scope 字符串为列表，并过滤仅支持项"""
    scopes = [s.strip() for s in (scope_str or "").split() if s.strip()]
    return [s for s in scopes if s in SUPPORTED_SCOPES]

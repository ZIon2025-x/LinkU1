"""
OAuth 2.0 客户端管理（仅管理员）
POST/GET/PATCH /api/admin/oauth/clients, POST .../rotate-secret
"""

import logging
import secrets
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.deps import get_sync_db
from app.security import get_password_hash
from app.separate_auth_deps import get_current_admin
from app.oauth.oauth_service import invalidate_oauth_client_cache

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["管理员-OAuth客户端"])


def _client_to_out(c: models.OAuthClient) -> schemas.OAuthClientOut:
    return schemas.OAuthClientOut(
        client_id=c.client_id,
        client_name=c.client_name,
        client_uri=c.client_uri,
        logo_uri=c.logo_uri,
        redirect_uris=list(c.redirect_uris) if c.redirect_uris else [],
        scope_default=c.scope_default,
        allowed_grant_types=list(c.allowed_grant_types) if c.allowed_grant_types else ["authorization_code"],
        is_confidential=c.is_confidential,
        is_active=c.is_active,
        created_at=c.created_at,
    )


@router.post("/oauth/clients", response_model=schemas.OAuthClientCreateResponse)
def create_oauth_client(
    body: schemas.OAuthClientCreate,
    db: Session = Depends(get_sync_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """创建 OAuth 客户端；返回 client_id 与 client_secret（仅此次）"""
    client_id = secrets.token_urlsafe(24).replace("-", "").replace("_", "")[:32]
    client_secret = secrets.token_urlsafe(32)
    client_secret_hash = get_password_hash(client_secret)
    allowed = body.allowed_grant_types or ["authorization_code", "refresh_token"]
    client = models.OAuthClient(
        client_id=client_id,
        client_secret_hash=client_secret_hash,
        client_name=body.client_name,
        client_uri=body.client_uri,
        logo_uri=body.logo_uri,
        redirect_uris=body.redirect_uris,
        scope_default=body.scope_default or "openid profile email",
        allowed_grant_types=allowed,
        is_confidential=body.is_confidential if body.is_confidential is not None else True,
        is_active=True,
    )
    db.add(client)
    db.commit()
    db.refresh(client)
    logger.info("OAuth client created: client_id=%s by admin=%s", client_id[:8], current_admin.id)
    return schemas.OAuthClientCreateResponse(
        client_id=client.client_id,
        client_secret=client_secret,
        client_name=client.client_name,
        redirect_uris=client.redirect_uris or [],
    )


@router.get("/oauth/clients", response_model=List[schemas.OAuthClientOut])
def list_oauth_clients(
    is_active: Optional[bool] = None,
    db: Session = Depends(get_sync_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """列表 OAuth 客户端，可选按 is_active 过滤"""
    q = db.query(models.OAuthClient)
    if is_active is not None:
        q = q.filter(models.OAuthClient.is_active == is_active)
    clients = q.order_by(models.OAuthClient.created_at.desc()).all()
    return [_client_to_out(c) for c in clients]


@router.get("/oauth/clients/{client_id}", response_model=schemas.OAuthClientOut)
def get_oauth_client(
    client_id: str,
    db: Session = Depends(get_sync_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """获取单个 OAuth 客户端（不含 client_secret）"""
    client = db.query(models.OAuthClient).filter(models.OAuthClient.client_id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    return _client_to_out(client)


@router.patch("/oauth/clients/{client_id}", response_model=schemas.OAuthClientOut)
def update_oauth_client(
    client_id: str,
    body: schemas.OAuthClientUpdate,
    db: Session = Depends(get_sync_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """更新 OAuth 客户端（不可直接改 client_secret，请用 rotate-secret）"""
    client = db.query(models.OAuthClient).filter(models.OAuthClient.client_id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    if body.client_name is not None:
        client.client_name = body.client_name
    if body.redirect_uris is not None:
        client.redirect_uris = body.redirect_uris
    if body.client_uri is not None:
        client.client_uri = body.client_uri
    if body.logo_uri is not None:
        client.logo_uri = body.logo_uri
    if body.is_active is not None:
        client.is_active = body.is_active
    db.commit()
    db.refresh(client)
    invalidate_oauth_client_cache(client_id)
    return _client_to_out(client)


@router.post("/oauth/clients/{client_id}/rotate-secret", response_model=schemas.OAuthClientRotateSecretResponse)
def rotate_oauth_client_secret(
    client_id: str,
    db: Session = Depends(get_sync_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """轮换 client_secret；旧 secret 立即失效，返回新 secret（仅此次）"""
    client = db.query(models.OAuthClient).filter(models.OAuthClient.client_id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    new_secret = secrets.token_urlsafe(32)
    client.client_secret_hash = get_password_hash(new_secret)
    db.commit()
    invalidate_oauth_client_cache(client_id)
    logger.info("OAuth client secret rotated: client_id=%s by admin=%s", client_id[:8], current_admin.id)
    return schemas.OAuthClientRotateSecretResponse(client_secret=new_secret)

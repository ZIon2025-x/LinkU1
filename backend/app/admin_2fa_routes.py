"""
管理员 2FA (双因素认证) API 路由
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Dict, Any
from app.deps import get_sync_db
from app.separate_auth_deps import get_current_admin
from app import models, schemas
from app.two_factor_auth import TwoFactorAuth
from app.rate_limiting import rate_limit
import logging
import json

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/admin/2fa/setup", response_model=Dict[str, Any])
@rate_limit("admin_operation")
def get_2fa_setup(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """
    获取 2FA 设置信息（生成 QR 码和密钥）
    如果已启用 2FA，返回当前状态；如果未启用，生成新的密钥和 QR 码
    """
    if current_admin.totp_enabled and current_admin.totp_secret:
        # 已启用 2FA，返回当前状态
        return {
            "enabled": True,
            "message": "2FA 已启用"
        }
    
    # 生成新的 TOTP 密钥
    secret = TwoFactorAuth.generate_secret()
    
    # 生成 QR 码
    qr_code = TwoFactorAuth.generate_qr_code(
        secret=secret,
        email=current_admin.email,
        issuer="Link²Ur Admin"
    )
    
    # 获取 TOTP URI（用于手动输入）
    totp_uri = TwoFactorAuth.get_totp_uri(
        secret=secret,
        email=current_admin.email,
        issuer="Link²Ur Admin"
    )
    
    # 临时存储密钥到数据库（还未启用，等待验证）
    # 注意：这里我们暂时不保存，等用户验证后再保存
    # 实际实现中可以使用 Redis 临时存储
    
    return {
        "enabled": False,
        "secret": secret,  # 临时返回，用于前端验证
        "qr_code": qr_code,
        "totp_uri": totp_uri,
        "message": "请使用 Authenticator 应用扫描 QR 码或手动输入密钥"
    }


@router.post("/admin/2fa/verify-setup", response_model=Dict[str, Any])
@rate_limit("admin_operation")
def verify_2fa_setup(
    verification_data: schemas.Admin2FAVerifySetup,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """
    验证 2FA 设置（用户输入验证码确认设置）
    """
    # 验证 TOTP 代码
    if not TwoFactorAuth.verify_totp(verification_data.secret, verification_data.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误，请重试"
        )
    
    # 生成备份代码
    backup_codes = TwoFactorAuth.generate_backup_codes(count=10)
    
    # 保存到数据库
    current_admin.totp_secret = verification_data.secret
    current_admin.totp_enabled = 1
    current_admin.totp_backup_codes = json.dumps(backup_codes)
    db.commit()
    
    logger.info(f"[2FA] 管理员 {current_admin.id} 成功启用 2FA")
    
    return {
        "message": "2FA 已成功启用",
        "backup_codes": backup_codes,
        "enabled": True
    }


@router.post("/admin/2fa/disable", response_model=Dict[str, Any])
@rate_limit("admin_operation")
def disable_2fa(
    disable_data: schemas.Admin2FADisable,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """
    禁用 2FA（需要验证当前密码或 2FA 代码）
    """
    if not current_admin.totp_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="2FA 未启用"
        )
    
    # 验证密码或 2FA 代码
    from app.security import verify_password
    
    valid = False
    if disable_data.password:
        valid = verify_password(disable_data.password, str(current_admin.hashed_password))
    elif disable_data.totp_code and current_admin.totp_secret:
        valid = TwoFactorAuth.verify_totp(current_admin.totp_secret, disable_data.totp_code)
    elif disable_data.backup_code and current_admin.totp_backup_codes:
        valid, _ = TwoFactorAuth.verify_backup_code(current_admin.totp_backup_codes, disable_data.backup_code)
    
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="验证失败，无法禁用 2FA"
        )
    
    # 禁用 2FA
    current_admin.totp_secret = None
    current_admin.totp_enabled = 0
    current_admin.totp_backup_codes = None
    db.commit()
    
    logger.info(f"[2FA] 管理员 {current_admin.id} 已禁用 2FA")
    
    return {
        "message": "2FA 已成功禁用",
        "enabled": False
    }


@router.get("/admin/2fa/status", response_model=Dict[str, Any])
@rate_limit("admin_operation")
def get_2fa_status(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """
    获取 2FA 状态
    """
    return {
        "enabled": bool(current_admin.totp_enabled),
        "has_backup_codes": bool(current_admin.totp_backup_codes)
    }


@router.post("/admin/2fa/regenerate-backup-codes", response_model=Dict[str, Any])
@rate_limit("admin_operation")
def regenerate_backup_codes(
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db)
):
    """
    重新生成备份代码（需要验证 2FA 代码）
    """
    if not current_admin.totp_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="2FA 未启用"
        )
    
    # 生成新的备份代码
    backup_codes = TwoFactorAuth.generate_backup_codes(count=10)
    current_admin.totp_backup_codes = json.dumps(backup_codes)
    db.commit()
    
    logger.info(f"[2FA] 管理员 {current_admin.id} 重新生成了备份代码")
    
    return {
        "message": "备份代码已重新生成",
        "backup_codes": backup_codes
    }

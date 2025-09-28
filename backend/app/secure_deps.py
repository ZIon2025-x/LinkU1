"""
安全认证依赖项
"""

from typing import Optional
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app import crud, models
from app.deps import get_sync_db
from app.secure_auth import validate_session, SecureAuthManager

def get_current_user_secure(
    request: Request,
    db: Session = Depends(get_sync_db),
) -> models.User:
    """获取当前用户（安全认证）"""
    # 验证会话
    session = validate_session(request)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="会话无效或已过期，请重新登录"
        )
    
    # 获取用户信息
    user = crud.get_user_by_id(db, session.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在"
        )
    
    # 检查用户状态
    if user.is_suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被暂停"
        )
    
    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被封禁"
        )
    
    return user

def get_current_session(request: Request) -> dict:
    """获取当前会话信息"""
    session = validate_session(request)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="会话无效或已过期"
        )
    
    return {
        "session_id": session.session_id,
        "user_id": session.user_id,
        "device_fingerprint": session.device_fingerprint,
        "ip_address": session.ip_address,
        "created_at": session.created_at,
        "last_activity": session.last_activity
    }

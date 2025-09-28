from typing import Optional

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app import async_crud, crud, models
from app.security import verify_token
from app.database import SessionLocal, get_async_db, get_db
from app.security import (
    cookie_bearer,
    sync_cookie_bearer,
    get_client_ip,
    log_security_event,
    revoke_all_user_tokens,
    revoke_token,
    verify_token,
)
from app.csrf import (
    csrf_cookie_bearer,
    sync_csrf_cookie_bearer,
    cookie_bearer_readonly,
    sync_cookie_bearer_readonly,
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/users/login")


# 同步数据库依赖（向后兼容）
def get_sync_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# 异步数据库依赖
async def get_async_db_dependency():
    async for session in get_async_db():
        yield session


# 同步用户认证（向后兼容）
def get_current_user(
    db: Session = Depends(get_sync_db), token: str = Depends(oauth2_scheme)
):
    payload = verify_token(token, "access")
    if not payload or "user_id" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user = crud.get_user_by_id(db, payload["user_id"])
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )
    return user


# 异步用户认证
async def get_current_user_async(
    db: AsyncSession = Depends(get_async_db_dependency),
    token: str = Depends(oauth2_scheme),
):
    payload = verify_token(token, "access")
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user = await async_crud.async_user_crud.get_user_by_id(db, payload["sub"])
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )
    return user


# 通用会话认证函数
def authenticate_with_session(request: Request, db: Session) -> Optional[models.User]:
    """使用会话认证获取用户"""
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        user = crud.get_user_by_id(db, session.user_id)
        if user:
            # 检查用户状态
            if hasattr(user, "is_suspended") and user.is_suspended:
                client_ip = get_client_ip(request)
                log_security_event(
                    "SUSPENDED_USER_ACCESS", user.id, client_ip, "被暂停用户尝试访问"
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )

            if hasattr(user, "is_banned") and user.is_banned:
                client_ip = get_client_ip(request)
                log_security_event(
                    "BANNED_USER_ACCESS", user.id, client_ip, "被封禁用户尝试访问"
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            
            return user
    return None

# 新的安全认证依赖
async def get_current_user_secure(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(cookie_bearer),
) -> models.User:
    """安全的用户认证（支持Cookie和Header）"""
    # 首先尝试使用会话认证
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            # 检查用户状态
            if hasattr(user, "is_suspended") and user.is_suspended:
                client_ip = get_client_ip(request)
                log_security_event(
                    "SUSPENDED_USER_ACCESS", user.id, client_ip, "被暂停用户尝试访问"
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )

            if hasattr(user, "is_banned") and user.is_banned:
                client_ip = get_client_ip(request)
                log_security_event(
                    "BANNED_USER_ACCESS", user.id, client_ip, "被封禁用户尝试访问"
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            
            return user
    
    # 如果会话认证失败，回退到JWT认证
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
        if not user:
            # 记录安全事件
            client_ip = get_client_ip(request)
            log_security_event(
                "INVALID_USER", user_id, client_ip, "Token中的用户不存在"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        # 检查用户状态
        if hasattr(user, "is_suspended") and user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_ACCESS", user_id, client_ip, "被暂停用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
            )

        if hasattr(user, "is_banned") and user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_ACCESS", user_id, client_ip, "被封禁用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        client_ip = get_client_ip(request)
        log_security_event("AUTH_ERROR", "unknown", client_ip, f"认证错误: {str(e)}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


def get_current_user_secure_sync(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer),
) -> models.User:
    """同步版本的安全用户认证"""
    # 首先尝试使用会话认证
    user = authenticate_with_session(request, db)
    if user:
        return user
    
    # 如果会话认证失败，回退到JWT认证
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = crud.get_user_by_id(db, user_id)
        if not user:
            client_ip = get_client_ip(request)
            log_security_event(
                "INVALID_USER", user_id, client_ip, "Token中的用户不存在"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        # 检查用户状态
        if hasattr(user, "is_suspended") and user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_ACCESS", user_id, client_ip, "被暂停用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
            )

        if hasattr(user, "is_banned") and user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_ACCESS", user_id, client_ip, "被封禁用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        client_ip = get_client_ip(request)
        log_security_event("AUTH_ERROR", "unknown", client_ip, f"认证错误: {str(e)}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


def get_current_user_optional(
    db: Session = Depends(get_db), authorization: Optional[str] = Header(None)
) -> Optional[object]:
    """可选的身份验证依赖，如果token无效或不存在则返回None"""
    if not authorization or not authorization.startswith("Bearer "):
        return None

    token = authorization.replace("Bearer ", "")
    try:
        payload = verify_token(token, "access")
        if not payload or "user_id" not in payload:
            return None
        user = crud.get_user_by_id(db, payload["user_id"])
        if not user:
            return None
        return user
    except:
        return None


def check_user_status(current_user=Depends(get_current_user_secure_sync)):
    import datetime

    now = datetime.datetime.utcnow()
    if current_user.is_banned:
        raise HTTPException(status_code=403, detail="User is banned.")
    if current_user.is_suspended or (
        current_user.suspend_until and current_user.suspend_until > now
    ):
        raise HTTPException(status_code=403, detail="User is suspended.")
    return current_user


def check_super_admin(current_user=Depends(check_user_status)):
    """检查是否为超级管理员"""
    if not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Super admin access required.")
    return current_user


def check_admin(current_user=Depends(check_user_status)):
    """检查是否为管理员（包括超级管理员）"""
    if not current_user.is_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Admin access required.")
    return current_user


def get_current_customer_service(
    request: Request,
    db: Session = Depends(get_db), 
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer)
):
    """获取当前客服用户 - 支持Cookie和Authorization头认证"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息"
        )
    
    token = credentials.credentials
    payload = verify_token(token, "access")
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

    # 检查是否为客服登录（通过role字段或cs_id字段）
    if "role" in payload and payload["role"] == "cs":
        cs = crud.get_customer_service_by_id(db, payload["sub"])
    elif "cs_id" in payload:
        cs = crud.get_customer_service_by_id(db, payload["cs_id"])
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Customer service token required",
        )

    if not cs:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Customer service not found",
        )
    return cs


def get_current_customer_service_or_user(
    request: Request,
    db: Session = Depends(get_db), 
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer)
):
    """获取当前用户（可能是普通用户或客服）- 支持Cookie认证"""
    # 首先尝试使用会话认证
    user = authenticate_with_session(request, db)
    if user:
        return user
    
    # 如果会话认证失败，回退到JWT认证
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )
    
    token = credentials.credentials
    payload = verify_token(token, "access")
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )

    # 检查是否为客服登录（通过role字段或cs_id字段）
    if "role" in payload and payload["role"] == "cs":
        cs = crud.get_customer_service_by_id(db, payload["sub"])
        if not cs:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Customer service not found",
            )
        return cs
    elif "cs_id" in payload:
        cs = crud.get_customer_service_by_id(db, payload["cs_id"])
        if not cs:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Customer service not found",
            )
        return cs
    # 否则为普通用户登录
    elif "sub" in payload:
        user = crud.get_user_by_id(db, payload["sub"])
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
            )
        return user
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )


def get_current_admin_user(
    db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)
):
    """获取当前后台管理员用户"""
    payload = verify_token(token, "access")
    if not payload or "admin_id" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )

    admin = crud.get_admin_user_by_id(db, payload["admin_id"])
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Admin user not found"
        )
    return admin


# CSRF保护的认证依赖
def get_current_user_secure_sync_csrf(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_csrf_cookie_bearer),
) -> models.User:
    """CSRF保护的安全用户认证（同步版本）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = crud.get_user_by_id(db, user_id)
        if not user:
            client_ip = get_client_ip(request)
            log_security_event(
                "INVALID_USER", user_id, client_ip, "Token中的用户不存在"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        # 检查用户状态
        if hasattr(user, "is_suspended") and user.is_suspended:
            client_ip = get_client_ip(request)
            log_security_event(
                "SUSPENDED_USER_ACCESS", user_id, client_ip, "被暂停用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
            )

        if hasattr(user, "is_banned") and user.is_banned:
            client_ip = get_client_ip(request)
            log_security_event(
                "BANNED_USER_ACCESS", user_id, client_ip, "被封禁用户尝试访问"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        client_ip = get_client_ip(request)
        log_security_event(
            "AUTH_ERROR", "unknown", client_ip, f"认证错误: {str(e)}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


def get_current_user_readonly(
    request: Request,
    db: Session = Depends(get_sync_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(sync_cookie_bearer_readonly),
) -> models.User:
    """只读操作的用户认证（不需要CSRF保护）"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
        )

    try:
        # 验证token
        payload = verify_token(credentials.credentials, "access")
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的token"
            )

        # 获取用户信息
        user = crud.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


def check_admin_user_status(current_admin=Depends(get_current_admin_user)):
    """检查后台管理员状态"""
    if not current_admin.is_active:
        raise HTTPException(status_code=403, detail="Admin account is disabled.")
    return current_admin

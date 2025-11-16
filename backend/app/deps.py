from typing import Optional
import logging

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

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


# 旧的JWT认证函数已删除，请使用新的会话认证系统


# 通用会话认证函数
def authenticate_with_session(request: Request, db: Session = Depends(get_sync_db)) -> Optional[models.User]:
    """使用会话认证获取用户"""
    from app.secure_auth import validate_session
    
    # 会话认证中（已移除DEBUG日志以提升性能）
    
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
            
            print(f"[DEBUG] 会话认证成功，返回用户: {user.id}")
            return user
        else:
            print(f"[DEBUG] 用户查询失败，用户ID: {session.user_id}")
    else:
        print(f"[DEBUG] 会话验证失败")
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
    
    print(f"[DEBUG] get_current_user_secure - URL: {request.url}")
    print(f"[DEBUG] get_current_user_secure - Cookies: {dict(request.cookies)}")
    
    session = validate_session(request)
    if session:
        print(f"[DEBUG] 会话认证成功，用户ID: {session.user_id}")
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
    
    # 会话认证失败，拒绝访问
    client_ip = get_client_ip(request)
    log_security_event("SESSION_AUTH_FAILED", "unknown", client_ip, "会话认证失败")
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, 
        detail="认证失败，请重新登录"
    )


# 旧的JWT认证函数已删除，请使用新的会话认证系统


# 旧的JWT认证函数已删除，请使用新的会话认证系统


def check_user_status(current_user=Depends(authenticate_with_session)):
    import datetime

    # ⚠️ 检查current_user是否为None（认证失败的情况）
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Authentication required"
        )
    
    now = datetime.datetime.utcnow()
    if current_user.is_banned:
        raise HTTPException(status_code=403, detail="User is banned.")
    if current_user.is_suspended or (
        current_user.suspend_until and current_user.suspend_until > now
    ):
        raise HTTPException(status_code=403, detail="User is suspended.")
    return current_user

def get_current_user_optional(
    request: Request,
    db: Session = Depends(get_sync_db),
) -> Optional[models.User]:
    """获取当前用户（可选，不强制认证）"""
    try:
        from app.secure_auth import validate_session
        
        session = validate_session(request)
        if session:
            user = crud.get_user_by_id(db, session.user_id)
            if user:
                # 检查用户状态
                if hasattr(user, "is_suspended") and user.is_suspended:
                    return None

                if hasattr(user, "is_banned") and user.is_banned:
                    return None
                
                return user
    except Exception as e:
        logger.warning(f"可选用户认证失败: {e}")
    
    return None


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
    
    # 移动端特殊处理：如果Cookie认证失败，尝试从Authorization头获取token
    user_agent = request.headers.get("user-agent", "")
    is_mobile = any(keyword in user_agent.lower() for keyword in [
        'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
        'windows phone', 'opera mini', 'iemobile'
    ])
    
    if is_mobile:
        print(f"[DEBUG] 移动端检测: {is_mobile}")
        print(f"[DEBUG] 移动端User-Agent: {user_agent}")
        
        # 移动端Cookie缺失时，尝试从Authorization头获取token
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            print(f"[DEBUG] 移动端备用认证 - 从Authorization头获取token: {token[:20]}...")
            
            # 验证token
            try:
                payload = verify_token(token, "access")
                if payload and "sub" in payload:
                    user_id = payload["sub"]
                    user = crud.get_user_by_id(db, user_id)
                    if user:
                        print(f"[DEBUG] 移动端备用认证成功 - 用户: {user.id}")
                        # 记录移动端认证成功
                        print(f"[DEBUG] 移动端认证方式: JWT token (Cookie不可用)")
                        return user
                    else:
                        print(f"[DEBUG] 移动端备用认证失败 - 用户不存在: {user_id}")
                else:
                    print(f"[DEBUG] 移动端备用认证失败 - token无效")
            except Exception as e:
                print(f"[DEBUG] 移动端备用认证异常: {e}")
        else:
            print(f"[DEBUG] 移动端未找到Authorization头")
    else:
        print(f"[DEBUG] 非移动端设备")
    
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
    # 首先尝试使用会话认证
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        user_id = session.user_id
        user = crud.get_user_by_id(db, user_id)
        if user:
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
        log_security_event(
            "AUTH_ERROR", "unknown", client_ip, f"认证错误: {str(e)}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="认证失败")


# 旧的JWT认证函数已删除，请使用新的会话认证系统


def check_admin_user_status(current_admin=Depends(get_current_admin_user)):
    """检查后台管理员状态"""
    if not current_admin.is_active:
        raise HTTPException(status_code=403, detail="Admin account is disabled.")
    return current_admin

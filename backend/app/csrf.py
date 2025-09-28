"""
CSRF保护模块
实现双提交Cookie模式防止CSRF攻击
"""

import secrets
import hashlib
from typing import Optional
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging

logger = logging.getLogger(__name__)

# CSRF配置
CSRF_TOKEN_LENGTH = 32
CSRF_COOKIE_NAME = "csrf_token"
CSRF_HEADER_NAME = "X-CSRF-Token"
CSRF_COOKIE_MAX_AGE = 3600  # 1小时

class CSRFProtection:
    """CSRF保护类"""
    
    @staticmethod
    def generate_csrf_token() -> str:
        """生成CSRF token"""
        return secrets.token_urlsafe(CSRF_TOKEN_LENGTH)
    
    @staticmethod
    def set_csrf_cookie(response: Response, token: str) -> None:
        """设置CSRF token到Cookie"""
        from app.cookie_manager import CookieManager
        CookieManager.set_csrf_cookie(response, token)
    
    @staticmethod
    def get_csrf_token_from_cookie(request: Request) -> Optional[str]:
        """从Cookie获取CSRF token"""
        return request.cookies.get("csrf_token")
    
    @staticmethod
    def get_csrf_token_from_header(request: Request) -> Optional[str]:
        """从Header获取CSRF token"""
        return request.headers.get("X-CSRF-Token")
    
    @staticmethod
    def verify_csrf_token(request: Request) -> bool:
        """验证CSRF token"""
        cookie_token = CSRFProtection.get_csrf_token_from_cookie(request)
        header_token = CSRFProtection.get_csrf_token_from_header(request)
        
        if not cookie_token or not header_token:
            logger.warning("CSRF token missing from cookie or header")
            return False
        
        if cookie_token != header_token:
            logger.warning("CSRF token mismatch between cookie and header")
            return False
        
        return True

class CSRFProtectedHTTPBearer(HTTPBearer):
    """支持CSRF保护的HTTPBearer"""
    
    def __init__(self, auto_error: bool = True, require_csrf: bool = True):
        super().__init__(auto_error=auto_error)
        self.require_csrf = require_csrf
    
    def __call__(
        self, request: Request
    ) -> Optional[HTTPAuthorizationCredentials]:
        # 首先尝试从Authorization头获取
        authorization_header = request.headers.get("Authorization")
        if authorization_header and authorization_header.startswith("Bearer "):
            token = authorization_header.split(" ")[1]
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=token
            )
        
        # 如果从Cookie获取session_id，需要CSRF保护
        session_id = request.cookies.get("session_id")
        if session_id:
            if self.require_csrf and request.method in ["POST", "PUT", "PATCH", "DELETE"]:
                if not CSRFProtection.verify_csrf_token(request):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="CSRF token验证失败"
                    )
            
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        
        if self.auto_error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未提供认证信息"
            )
        
        return None

class SyncCSRFProtectedHTTPBearer(HTTPBearer):
    """同步版本的支持CSRF保护的HTTPBearer"""
    
    def __init__(self, auto_error: bool = True, require_csrf: bool = True):
        super().__init__(auto_error=auto_error)
        self.require_csrf = require_csrf
    
    def __call__(
        self, request: Request
    ) -> Optional[HTTPAuthorizationCredentials]:
        # 首先尝试从Authorization头获取
        authorization_header = request.headers.get("Authorization")
        if authorization_header and authorization_header.startswith("Bearer "):
            token = authorization_header.split(" ")[1]
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=token
            )
        
        # 如果从Cookie获取session_id，需要CSRF保护
        session_id = request.cookies.get("session_id")
        if session_id:
            if self.require_csrf and request.method in ["POST", "PUT", "PATCH", "DELETE"]:
                if not CSRFProtection.verify_csrf_token(request):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="CSRF token验证失败"
                    )
            
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        
        if self.auto_error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未提供认证信息"
            )
        
        return None

# 创建CSRF保护的认证实例
csrf_cookie_bearer = CSRFProtectedHTTPBearer()
sync_csrf_cookie_bearer = SyncCSRFProtectedHTTPBearer()

# 创建不要求CSRF的认证实例（用于只读操作）
cookie_bearer_readonly = CSRFProtectedHTTPBearer(require_csrf=False)
sync_cookie_bearer_readonly = SyncCSRFProtectedHTTPBearer(require_csrf=False)

"""
CSRF保护模块
实现双提交Cookie模式防止CSRF攻击
"""

import secrets
import hashlib
import hmac
import time
from typing import Optional, Tuple
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import logging
import os

logger = logging.getLogger(__name__)

# CSRF配置
CSRF_TOKEN_LENGTH = 32
CSRF_COOKIE_NAME = "csrf_token"
CSRF_HEADER_NAME = "X-CSRF-Token"
CSRF_TOKEN_MAX_AGE = 3600  # CSRF token 最大有效期（秒），默认1小时
CSRF_COOKIE_MAX_AGE = 3600  # 1小时

# 移动端应用签名密钥（用于验证请求来自真正的 App）
# 必须通过环境变量 MOBILE_APP_SECRET 设置，不提供默认值
MOBILE_APP_SECRET = os.environ.get("MOBILE_APP_SECRET")
if not MOBILE_APP_SECRET:
    logger.warning("⚠️ MOBILE_APP_SECRET 环境变量未设置，移动端签名验证将失败！")

# 已知的合法移动端平台和对应的 User-Agent 前缀
VALID_MOBILE_PLATFORMS = {
    "ios": "Link2Ur-iOS",
    "android": "Link2Ur-Android",
}


def verify_mobile_request(request: Request) -> Tuple[bool, str]:
    """
    严格验证移动端请求的合法性
    
    验证条件（必须同时满足）：
    1. X-Platform 头必须是 iOS 或 Android
    2. User-Agent 必须包含对应平台的应用标识
    3. X-App-Signature 头必须是有效的 HMAC 签名（必需）
    4. X-App-Timestamp 时间戳在有效期内（5分钟）
    
    Returns:
        Tuple[bool, str]: (是否验证通过, 平台名称或错误原因)
    """
    # 1. 检查 X-Platform 头
    platform = request.headers.get("X-Platform", "").lower()
    if platform not in VALID_MOBILE_PLATFORMS:
        return False, f"未知平台: {platform}"
    
    # 2. 检查 User-Agent 是否匹配平台
    user_agent = request.headers.get("User-Agent", "").lower()
    expected_ua_prefix = VALID_MOBILE_PLATFORMS[platform].lower()
    if expected_ua_prefix not in user_agent:
        logger.warning(f"移动端验证失败: User-Agent 不匹配 - 平台={platform}, UA={user_agent[:50]}")
        return False, "User-Agent 与平台不匹配"
    
    # 3. 检查应用签名（必需验证）
    # 签名格式: HMAC-SHA256(session_id + timestamp, MOBILE_APP_SECRET)
    app_signature = request.headers.get("X-App-Signature")
    app_timestamp = request.headers.get("X-App-Timestamp")
    session_id = request.headers.get("X-Session-ID", "")
    
    # 签名和时间戳是必需的
    if not app_signature or not app_timestamp:
        logger.warning(f"移动端验证失败: 缺少签名或时间戳 - 平台={platform}")
        return False, "缺少应用签名或时间戳"
    
    # 检查密钥是否已配置
    if not MOBILE_APP_SECRET:
        logger.error("移动端验证失败: MOBILE_APP_SECRET 环境变量未设置")
        return False, "服务器配置错误"
    
    try:
        # 验证时间戳（5分钟有效期）
        import time
        current_time = int(time.time())
        request_time = int(app_timestamp)
        if abs(current_time - request_time) > 300:  # 5分钟
            logger.warning(f"移动端签名验证失败: 时间戳过期 - 当前={current_time}, 请求={request_time}")
            return False, "请求时间戳过期"
        
        # 验证 HMAC 签名
        message = f"{session_id}{app_timestamp}".encode()
        expected_signature = hmac.new(
            MOBILE_APP_SECRET.encode(),
            message,
            hashlib.sha256
        ).hexdigest()
        
        if not hmac.compare_digest(app_signature, expected_signature):
            logger.warning(f"移动端签名验证失败: 签名不匹配 - 平台={platform}")
            return False, "应用签名无效"
            
        logger.debug(f"移动端签名验证通过: 平台={platform}")
    except (ValueError, TypeError) as e:
        logger.warning(f"移动端签名验证异常: {e}")
        return False, "签名验证异常"
    
    # 完整验证通过（平台 + User-Agent + 签名）
    logger.debug(f"移动端请求完整验证通过: 平台={platform}")
    return True, platform


def is_verified_mobile_request(request: Request) -> bool:
    """检查是否为经过验证的移动端请求"""
    is_valid, _ = verify_mobile_request(request)
    return is_valid

class CSRFProtection:
    """CSRF保护类"""
    
    @staticmethod
    def generate_csrf_token() -> str:
        """生成CSRF token（包含时间戳用于过期检查）"""
        random_part = secrets.token_urlsafe(CSRF_TOKEN_LENGTH)
        timestamp = int(time.time())
        # 格式: timestamp.random_part
        token = f"{timestamp}.{random_part}"
        return token
    
    @staticmethod
    def set_csrf_cookie(response: Response, token: str, user_agent: str = "", origin: str = "") -> None:
        """设置CSRF token到Cookie"""
        from app.cookie_manager import CookieManager
        CookieManager.set_csrf_cookie(response, token, user_agent, origin)
    
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
        """验证CSRF token（包含过期检查）"""
        cookie_token = CSRFProtection.get_csrf_token_from_cookie(request)
        header_token = CSRFProtection.get_csrf_token_from_header(request)
        
        logger.debug(f"CSRF验证 - Cookie token: {cookie_token[:8] if cookie_token else None}..., Header token: {header_token[:8] if header_token else None}...")
        
        if not cookie_token or not header_token:
            logger.warning("CSRF token missing from cookie or header")
            return False
        
        if cookie_token != header_token:
            logger.warning("CSRF token mismatch between cookie and header")
            return False
        
        # 🔒 安全修复：检查token是否过期
        try:
            parts = cookie_token.split(".", 1)
            if len(parts) == 2:
                token_timestamp = int(parts[0])
                current_time = int(time.time())
                if current_time - token_timestamp > CSRF_TOKEN_MAX_AGE:
                    logger.warning(f"CSRF token expired: age={current_time - token_timestamp}s, max={CSRF_TOKEN_MAX_AGE}s")
                    return False
        except (ValueError, TypeError):
            # 兼容旧格式token（不含时间戳），允许通过
            pass
        
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
        
        # 尝试从 X-Session-ID 头获取（仅限经过验证的移动端请求）
        # 必须通过严格的移动端验证才能跳过 CSRF 检查
        x_session_id = request.headers.get("X-Session-ID")
        if x_session_id:
            # 严格验证移动端请求
            is_valid_mobile, reason = verify_mobile_request(request)
            if is_valid_mobile:
                # 验证通过，允许使用 X-Session-ID 认证（无需 CSRF）
                return HTTPAuthorizationCredentials(
                    scheme="Bearer", credentials=x_session_id
                )
            else:
                # 验证失败，记录警告并拒绝
                logger.warning(f"移动端验证失败，拒绝 X-Session-ID 认证: {reason}")
                # 不返回，继续尝试其他认证方式
        
        # 如果从Cookie获取session_id，需要CSRF保护
        session_id = request.cookies.get("session_id")
        if session_id:
            if self.require_csrf and request.method in ["POST", "PUT", "PATCH", "DELETE"]:
                if not CSRFProtection.verify_csrf_token(request):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
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
        
        # 尝试从 X-Session-ID 头获取（仅限经过验证的移动端请求）
        # 必须通过严格的移动端验证才能跳过 CSRF 检查
        x_session_id = request.headers.get("X-Session-ID")
        if x_session_id:
            # 严格验证移动端请求
            is_valid_mobile, reason = verify_mobile_request(request)
            if is_valid_mobile:
                # 验证通过，允许使用 X-Session-ID 认证（无需 CSRF）
                return HTTPAuthorizationCredentials(
                    scheme="Bearer", credentials=x_session_id
                )
            else:
                # 验证失败，记录警告并拒绝
                logger.warning(f"移动端验证失败，拒绝 X-Session-ID 认证: {reason}")
                # 不返回，继续尝试其他认证方式
        
        # 如果从Cookie获取session_id，需要CSRF保护
        session_id = request.cookies.get("session_id")
        if session_id:
            if self.require_csrf and request.method in ["POST", "PUT", "PATCH", "DELETE"]:
                if not CSRFProtection.verify_csrf_token(request):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
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

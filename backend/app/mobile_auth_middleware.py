"""
移动端认证中间件
处理移动端特殊的认证需求
"""

import logging
from typing import Optional
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from app.secure_auth import validate_session, SecureAuthManager
from app.cookie_manager import CookieManager

logger = logging.getLogger(__name__)

class MobileAuthMiddleware:
    """移动端认证中间件"""
    
    @staticmethod
    def is_mobile_request(request: Request) -> bool:
        """检测是否为移动端请求"""
        user_agent = request.headers.get("user-agent", "").lower()
        mobile_keywords = [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ]
        return any(keyword in user_agent for keyword in mobile_keywords)
    
    @staticmethod
    def get_session_from_multiple_sources(request: Request) -> Optional[str]:
        """从多个来源获取session_id（移动端兼容性）"""
        # 1. 尝试主要Cookie
        session_id = request.cookies.get("session_id")
        
        if session_id:
            logger.info(f"从Cookie获取session_id: {session_id[:8]}...")
            return session_id
        
        # 2. 尝试请求头
        session_id = request.headers.get("X-Session-ID")
        if session_id:
            logger.info(f"从X-Session-ID头获取session_id: {session_id[:8]}...")
            return session_id
        
        # 3. 尝试Authorization头（仅用于移动端JWT认证）
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            # 这是JWT token，不是session_id，应该通过JWT认证处理
            logger.info(f"检测到Authorization头，但这是JWT token，不是session_id")
            # 不将JWT token当作session_id处理
        
        logger.warning("未找到session_id")
        return None
    
    @staticmethod
    def add_mobile_auth_headers(response: Response, session_id: str, user_id: str) -> None:
        """为移动端添加认证头信息"""
        # 添加自定义头，供前端localStorage使用
        response.headers["X-Session-ID"] = session_id
        response.headers["X-User-ID"] = user_id
        response.headers["X-Auth-Status"] = "authenticated"
    
    @staticmethod
    def handle_mobile_auth_failure(request: Request) -> JSONResponse:
        """处理移动端认证失败"""
        is_mobile = MobileAuthMiddleware.is_mobile_request(request)
        
        if is_mobile:
            return JSONResponse(
                status_code=401,
                content={
                    "error": True,
                    "message": "移动端认证失败，请重新登录",
                    "error_code": "MOBILE_AUTH_FAILED",
                    "status_code": 401,
                    "mobile_specific": True,
                    "suggestions": [
                        "请检查localStorage中的session_id",
                        "尝试清除浏览器缓存后重新登录",
                        "确保网络连接正常"
                    ]
                }
            )
        else:
            return JSONResponse(
                status_code=401,
                content={
                    "error": True,
                    "message": "认证失败，请重新登录",
                    "error_code": "AUTH_FAILED",
                    "status_code": 401
                }
            )

def get_mobile_session(request: Request) -> Optional[dict]:
    """获取移动端会话信息"""
    session_id = MobileAuthMiddleware.get_session_from_multiple_sources(request)
    
    if not session_id:
        return None
    
    session = SecureAuthManager.get_session(session_id)
    if not session:
        return None
    
    return {
        "session_id": session_id,
        "user_id": session.user_id,
        "session": session
    }

"""
统一的Cookie管理器
整合所有Cookie设置和清除逻辑，避免重复代码
"""

from typing import Literal, Optional
from fastapi import Response
from app.config import Config
import logging

logger = logging.getLogger(__name__)


class CookieManager:
    """统一的Cookie管理器"""
    
    @staticmethod
    def _is_mobile_user_agent(user_agent: str) -> bool:
        """检测是否为移动端User-Agent"""
        mobile_keywords = [
            'Mobile', 'iPhone', 'iPad', 'Android', 'BlackBerry', 
            'Windows Phone', 'Opera Mini', 'IEMobile'
        ]
        return any(keyword in user_agent for keyword in mobile_keywords)
    
    @staticmethod
    def _is_private_mode_user_agent(user_agent: str) -> bool:
        """检测是否为隐私模式User-Agent"""
        private_mode_keywords = [
            'Incognito', 'Private', 'InPrivate', 'Private Browsing'
        ]
        return any(keyword in user_agent for keyword in private_mode_keywords)
    
    @staticmethod
    def _get_samesite_value(user_agent: str = "") -> Literal["lax", "strict", "none"]:
        """获取有效的SameSite值，考虑隐私模式兼容性"""
        # 检测移动端
        if CookieManager._is_mobile_user_agent(user_agent):
            return Config.MOBILE_COOKIE_SAMESITE  # type: ignore
        
        # 桌面端：优先使用lax以提高隐私模式兼容性
        samesite_value = Config.COOKIE_SAMESITE
        if samesite_value not in ["lax", "strict", "none"]:
            samesite_value = "lax"
        
        # 隐私模式兼容性：优先使用lax而不是none
        if samesite_value == "none":
            samesite_value = "lax"  # 隐私模式下none可能被阻止
        
        return samesite_value  # type: ignore
    
    @staticmethod
    def _get_secure_value(user_agent: str = "") -> bool:
        """获取Secure值，移动端使用特殊配置"""
        # 检测移动端
        if CookieManager._is_mobile_user_agent(user_agent):
            return Config.MOBILE_COOKIE_SECURE
        
        # 桌面端使用默认配置
        return Config.COOKIE_SECURE
    
    @staticmethod
    def set_auth_cookies(
        response: Response,
        access_token: str,
        refresh_token: str,
        user_id: Optional[str] = None,
        user_agent: str = ""
    ) -> None:
        """设置认证相关的Cookie（兼容旧系统）"""
        samesite_value = CookieManager._get_samesite_value(user_agent)
        secure_value = CookieManager._get_secure_value(user_agent)
        
        # 设置access_token cookie（短期）
        response.set_cookie(
            key="access_token",
            value=access_token,
            max_age=Config.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            httponly=Config.COOKIE_HTTPONLY,
            secure=secure_value,
            samesite=samesite_value,
            path=Config.COOKIE_PATH,
            domain=Config.COOKIE_DOMAIN
        )
        
        # 设置refresh_token cookie（长期）
        response.set_cookie(
            key="refresh_token",
            value=refresh_token,
            max_age=Config.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
            httponly=Config.COOKIE_HTTPONLY,
            secure=secure_value,
            samesite=samesite_value,
            path=Config.COOKIE_PATH,
            domain=Config.COOKIE_DOMAIN
        )
        
        # 如果提供了user_id，设置用户ID Cookie（非敏感，用于前端显示）
        if user_id:
            response.set_cookie(
                key="user_id",
                value=user_id,
                max_age=Config.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
                httponly=False,  # 前端需要访问
                secure=secure_value,
                samesite=samesite_value,
                path=Config.COOKIE_PATH,
                domain=Config.COOKIE_DOMAIN
            )
        
        logger.info(f"设置认证Cookie - user_id: {user_id}")
    
    @staticmethod
    def set_session_cookies(
        response: Response,
        session_id: str,
        refresh_token: str,
        user_id: str,
        user_agent: str = ""
    ) -> None:
        """设置会话相关的Cookie（新安全系统）"""
        samesite_value = CookieManager._get_samesite_value(user_agent)
        secure_value = CookieManager._get_secure_value(user_agent)
        is_mobile = CookieManager._is_mobile_user_agent(user_agent)
        
        # 检测隐私模式
        is_private_mode = CookieManager._is_private_mode_user_agent(user_agent)
        
        # 移动端特殊处理：使用兼容性最好的Cookie设置
        if is_mobile:
            # 移动端：完全移除domain限制，使用根路径
            cookie_domain = None
            cookie_path = "/"
            # 移动端使用更短的过期时间，避免浏览器限制
            session_max_age = min(Config.ACCESS_TOKEN_EXPIRE_MINUTES * 60, 1800)  # 最多30分钟
            refresh_max_age = min(Config.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60, 86400)  # 最多1天
            
            # 移动端Cookie兼容性优化
            # 跨域请求必须使用SameSite=none
            samesite_value = "none"  # 移动端跨域请求必须使用none
            secure_value = True      # 移动端必须使用secure（HTTPS环境）
            
            # 记录移动端Cookie设置
            logger.info(f"移动端Cookie设置: SameSite={samesite_value}, Secure={secure_value}, Domain={cookie_domain}")
        elif is_private_mode:
            # 隐私模式特殊处理：使用最兼容的Cookie设置
            cookie_domain = None  # 隐私模式下不设置domain
            cookie_path = "/"
            # 隐私模式使用更短的过期时间
            session_max_age = min(Config.ACCESS_TOKEN_EXPIRE_MINUTES * 60, 1800)  # 最多30分钟
            refresh_max_age = min(Config.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60, 86400)  # 最多1天
            # 隐私模式使用lax提高兼容性
            samesite_value = "lax"   # 隐私模式下lax兼容性更好
            secure_value = True      # HTTPS环境必须使用secure
        else:
            # 桌面端：开发环境不设置domain，生产环境使用配置的domain
            if Config.IS_PRODUCTION and Config.COOKIE_DOMAIN:
                cookie_domain = Config.COOKIE_DOMAIN
            else:
                cookie_domain = None  # 开发环境不设置domain
            cookie_path = Config.COOKIE_PATH
            session_max_age = Config.ACCESS_TOKEN_EXPIRE_MINUTES * 60
            refresh_max_age = Config.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60
            
            # 桌面端Cookie设置
            samesite_value = CookieManager._get_samesite_value(user_agent)
            secure_value = CookieManager._get_secure_value(user_agent)
            
            # 记录桌面端Cookie设置
            logger.info(f"桌面端Cookie设置: SameSite={samesite_value}, Secure={secure_value}, Domain={cookie_domain}")
        
        # 设置会话ID Cookie（短期，用于API调用）
        response.set_cookie(
            key="session_id",
            value=session_id,
            max_age=session_max_age,
            httponly=Config.COOKIE_HTTPONLY,
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
        
        # 设置刷新令牌Cookie（长期，用于刷新会话）
        response.set_cookie(
            key="refresh_token",
            value=refresh_token,
            max_age=refresh_max_age,
            httponly=Config.COOKIE_HTTPONLY,
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
        
        # 设置用户ID Cookie（非敏感，用于前端显示）
        response.set_cookie(
            key="user_id",
            value=user_id,
            max_age=refresh_max_age,
            httponly=False,  # 前端需要访问
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
        
        # 设置用户身份标识Cookie（前端需要检测）
        response.set_cookie(
            key="user_authenticated",
            value="true",
            max_age=refresh_max_age,
            httponly=False,  # 前端需要访问
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
        
        # 移动端不再需要额外的备用Cookie，主要session_id Cookie已经工作正常
        if is_mobile:
            logger.info(f"移动端Cookie设置完成: 使用主要session_id Cookie")
        
        logger.info(f"设置会话Cookie - session_id: {session_id[:8]}..., user_id: {user_id}, 移动端: {is_mobile}, 隐私模式: {is_private_mode}, SameSite: {samesite_value}, Secure: {secure_value}, Domain: {cookie_domain}, Path: {cookie_path}")
    
    @staticmethod
    def set_csrf_cookie(response: Response, token: str, user_agent: str = "") -> None:
        """设置CSRF token Cookie"""
        samesite_value = CookieManager._get_samesite_value(user_agent)
        secure_value = CookieManager._get_secure_value(user_agent)
        is_mobile = CookieManager._is_mobile_user_agent(user_agent)
        
        # 移动端特殊处理
        if is_mobile:
            cookie_domain = None
            cookie_path = "/"
        else:
            # 开发环境不设置domain，生产环境使用配置的domain
            if Config.IS_PRODUCTION and Config.COOKIE_DOMAIN:
                cookie_domain = Config.COOKIE_DOMAIN
            else:
                cookie_domain = None  # 开发环境不设置domain
            cookie_path = Config.COOKIE_PATH
        
        response.set_cookie(
            key="csrf_token",
            value=token,
            max_age=3600,  # 1小时
            httponly=False,  # 需要JavaScript访问
            secure=secure_value,
            samesite=samesite_value,
            path=cookie_path,
            domain=cookie_domain
        )
        
        logger.info("设置CSRF Cookie")
    
    @staticmethod
    def clear_auth_cookies(response: Response) -> None:
        """清除认证相关的Cookie"""
        samesite_value = CookieManager._get_samesite_value()
        
        # 清除access_token
        response.delete_cookie(
            key="access_token",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/"
        )
        
        # 清除refresh_token
        response.delete_cookie(
            key="refresh_token",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/"
        )
        
        # 清除user_id
        response.delete_cookie(
            key="user_id",
            httponly=False,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/"
        )
        
        logger.info("清除认证Cookie")
    
    @staticmethod
    def clear_session_cookies(response: Response) -> None:
        """清除会话相关的Cookie"""
        samesite_value = CookieManager._get_samesite_value()
        
        # 获取正确的domain设置
        cookie_domain = Config.COOKIE_DOMAIN if Config.IS_PRODUCTION and Config.COOKIE_DOMAIN else None
        
        # 清除主要会话Cookie
        response.delete_cookie(
            key="session_id",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/",
            domain=cookie_domain
        )
        
        # 清除移动端特殊Cookie
        response.delete_cookie(
            key="mobile_session_id",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/",
            domain=cookie_domain
        )
        
        response.delete_cookie(
            key="js_session_id",
            httponly=False,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/",
            domain=cookie_domain
        )
        
        response.delete_cookie(
            key="mobile_strict_session_id",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite="strict",
            path="/",
            domain=cookie_domain
        )
        
        # 清除refresh_token
        response.delete_cookie(
            key="refresh_token",
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/",
            domain=cookie_domain
        )
        
        # 清除user_id
        response.delete_cookie(
            key="user_id",
            httponly=False,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/",
            domain=cookie_domain
        )
        
        logger.info("清除会话Cookie（包括移动端特殊Cookie）")
    
    @staticmethod
    def clear_csrf_cookie(response: Response) -> None:
        """清除CSRF token Cookie"""
        samesite_value = CookieManager._get_samesite_value()
        
        response.delete_cookie(
            key="csrf_token",
            httponly=False,
            secure=Config.COOKIE_SECURE,
            samesite=samesite_value,
            path="/"
        )
        
        logger.info("清除CSRF Cookie")
    
    @staticmethod
    def clear_all_cookies(response: Response) -> None:
        """清除所有Cookie（用于登出）"""
        CookieManager.clear_auth_cookies(response)
        CookieManager.clear_session_cookies(response)
        CookieManager.clear_csrf_cookie(response)
        logger.info("清除所有Cookie")

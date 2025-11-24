"""
日志配置模块
提供统一的日志过滤器和配置
"""
import logging
from typing import Optional


class IgnoreCommon401Filter(logging.Filter):
    """
    过滤常见的 401 认证错误日志，减少日志噪音
    
    这些错误通常是正常的用户行为（未登录访问、会话过期等），
    不需要在生产环境中记录为警告级别
    """
    
    # 需要过滤的常见 401 端点
    FILTERED_ENDPOINTS = [
        "/api/users/profile/me",
        "/api/secure-auth/refresh",
        "/api/secure-auth/refresh-token",
    ]
    
    def filter(self, record: logging.LogRecord) -> bool:
        """
        过滤日志记录
        
        Returns:
            False: 丢弃这条日志
            True: 保留这条日志
        """
        msg = record.getMessage()
        
        # 只处理包含 HTTP异常: 401 的日志
        if "HTTP异常: 401" not in msg:
            return True
        
        # 检查是否是常见的 401 端点
        for endpoint in self.FILTERED_ENDPOINTS:
            if endpoint in msg:
                # 在非调试模式下，丢弃这些常见的 401 日志
                # 调试模式下仍然记录（通过日志级别控制）
                if record.levelno >= logging.WARNING:
                    # 生产环境的警告级别日志，直接丢弃
                    return False
                # DEBUG/INFO 级别的日志保留（用于调试）
                return True
        
        # 其他 401 错误保留（可能是真正的安全问题）
        return True


def configure_logging():
    """配置日志过滤器"""
    # 应用到 error_handlers 模块的日志
    error_handler_logger = logging.getLogger("app.error_handlers")
    error_handler_logger.addFilter(IgnoreCommon401Filter())
    
    logger = logging.getLogger(__name__)
    logger.info("日志过滤器已配置")


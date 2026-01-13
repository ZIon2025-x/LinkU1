"""
翻译错误处理和降级策略
提供优雅的错误处理和降级机制
"""
import logging
from typing import Optional, Dict, Any
from enum import Enum

logger = logging.getLogger(__name__)


class TranslationErrorType(Enum):
    """翻译错误类型"""
    SERVICE_UNAVAILABLE = "service_unavailable"  # 服务不可用
    RATE_LIMIT = "rate_limit"  # 速率限制
    INVALID_TEXT = "invalid_text"  # 无效文本
    TIMEOUT = "timeout"  # 超时
    NETWORK_ERROR = "network_error"  # 网络错误
    UNKNOWN = "unknown"  # 未知错误


class TranslationErrorHandler:
    """翻译错误处理器"""
    
    def __init__(self):
        self.error_counts = {}  # 错误计数
        self.last_error_time = {}  # 最后错误时间
    
    def classify_error(self, error: Exception) -> TranslationErrorType:
        """分类错误类型"""
        error_str = str(error).lower()
        
        if 'rate limit' in error_str or 'quota' in error_str:
            return TranslationErrorType.RATE_LIMIT
        elif 'timeout' in error_str or 'timed out' in error_str:
            return TranslationErrorType.TIMEOUT
        elif 'network' in error_str or 'connection' in error_str:
            return TranslationErrorType.NETWORK_ERROR
        elif 'invalid' in error_str or 'empty' in error_str:
            return TranslationErrorType.INVALID_TEXT
        elif 'unavailable' in error_str or 'service' in error_str:
            return TranslationErrorType.SERVICE_UNAVAILABLE
        else:
            return TranslationErrorType.UNKNOWN
    
    def should_retry(self, error_type: TranslationErrorType, retry_count: int) -> bool:
        """判断是否应该重试"""
        max_retries = {
            TranslationErrorType.RATE_LIMIT: 1,  # 速率限制，少重试
            TranslationErrorType.TIMEOUT: 3,  # 超时，可以多试几次
            TranslationErrorType.NETWORK_ERROR: 3,  # 网络错误，可以重试
            TranslationErrorType.INVALID_TEXT: 0,  # 无效文本，不重试
            TranslationErrorType.SERVICE_UNAVAILABLE: 2,  # 服务不可用，少重试
            TranslationErrorType.UNKNOWN: 2,  # 未知错误，少重试
        }
        
        return retry_count < max_retries.get(error_type, 2)
    
    def get_retry_delay(self, error_type: TranslationErrorType, retry_count: int) -> float:
        """获取重试延迟（秒）"""
        base_delays = {
            TranslationErrorType.RATE_LIMIT: 5.0,  # 速率限制，延迟更长
            TranslationErrorType.TIMEOUT: 1.0,
            TranslationErrorType.NETWORK_ERROR: 2.0,
            TranslationErrorType.SERVICE_UNAVAILABLE: 3.0,
            TranslationErrorType.UNKNOWN: 2.0,
        }
        
        base_delay = base_delays.get(error_type, 2.0)
        # 指数退避
        return base_delay * (2 ** retry_count)
    
    def handle_error(
        self,
        error: Exception,
        service_name: str,
        text: str,
        retry_count: int = 0
    ) -> Dict[str, Any]:
        """处理错误并返回处理建议"""
        error_type = self.classify_error(error)
        
        # 记录错误
        error_key = f"{service_name}:{error_type.value}"
        self.error_counts[error_key] = self.error_counts.get(error_key, 0) + 1
        self.last_error_time[error_key] = time.time()
        
        should_retry = self.should_retry(error_type, retry_count)
        retry_delay = self.get_retry_delay(error_type, retry_count) if should_retry else 0
        
        return {
            "error_type": error_type.value,
            "should_retry": should_retry,
            "retry_delay": retry_delay,
            "error_message": str(error),
            "retry_count": retry_count
        }
    
    def get_error_stats(self) -> Dict[str, Any]:
        """获取错误统计"""
        return {
            "error_counts": self.error_counts.copy(),
            "last_error_time": self.last_error_time.copy()
        }


# 全局错误处理器实例
_error_handler = TranslationErrorHandler()


def get_error_handler() -> TranslationErrorHandler:
    """获取错误处理器单例"""
    return _error_handler


def handle_translation_error(
    error: Exception,
    service_name: str,
    text: str,
    retry_count: int = 0
) -> Dict[str, Any]:
    """处理翻译错误的便捷函数"""
    return _error_handler.handle_error(error, service_name, text, retry_count)

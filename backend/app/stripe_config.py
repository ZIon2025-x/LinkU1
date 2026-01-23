"""
Stripe API 配置模块
统一管理 Stripe API 客户端配置，包括超时设置
"""
import os
import logging
import stripe
from typing import Optional

logger = logging.getLogger(__name__)

# Stripe API 超时配置（秒）
STRIPE_API_TIMEOUT = int(os.getenv("STRIPE_API_TIMEOUT", "10"))  # 默认10秒超时

# 是否已初始化
_stripe_initialized = False


def configure_stripe(timeout: Optional[int] = None):
    """
    配置 Stripe API 客户端，设置超时
    
    Args:
        timeout: 超时时间（秒），如果为None则使用环境变量或默认值
    """
    global _stripe_initialized
    
    if _stripe_initialized:
        return
    
    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    
    if not stripe.api_key:
        logger.warning("STRIPE_SECRET_KEY 未设置，Stripe 功能将不可用")
        return
    
    # 设置超时
    timeout_value = timeout or STRIPE_API_TIMEOUT
    
    try:
        # 使用 RequestsClient 设置超时
        stripe.default_http_client = stripe.http_client.RequestsClient(
            timeout=timeout_value
        )
        logger.info(f"Stripe API 客户端已配置，超时时间: {timeout_value}秒")
        _stripe_initialized = True
    except Exception as e:
        logger.error(f"配置 Stripe API 客户端失败: {e}")
        # 即使配置失败，也标记为已初始化，避免重复尝试
        _stripe_initialized = True


def get_stripe_client():
    """
    获取配置好的 Stripe API 客户端
    
    Returns:
        stripe: Stripe 模块（已配置超时）
    """
    if not _stripe_initialized:
        configure_stripe()
    
    return stripe


def reset_stripe_config():
    """
    重置 Stripe 配置（用于测试）
    """
    global _stripe_initialized
    _stripe_initialized = False

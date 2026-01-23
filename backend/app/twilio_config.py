"""
Twilio API 配置模块
统一管理 Twilio API 客户端配置，包括超时设置
"""
import os
import logging
from typing import Optional
from twilio.rest import Client
from twilio.http.http_client import TwilioHttpClient

logger = logging.getLogger(__name__)

# Twilio API 超时配置（秒）
TWILIO_API_TIMEOUT = int(os.getenv("TWILIO_API_TIMEOUT", "10"))  # 默认10秒超时


def create_twilio_client_with_timeout(timeout: Optional[int] = None) -> Optional[Client]:
    """
    创建带超时设置的 Twilio 客户端
    
    Args:
        timeout: 超时时间（秒），如果为None则使用环境变量或默认值
    
    Returns:
        Client: Twilio 客户端，如果配置不完整则返回 None
    """
    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    
    if not all([account_sid, auth_token]):
        logger.warning("Twilio 配置不完整，SMS 功能将不可用")
        return None
    
    timeout_value = timeout or TWILIO_API_TIMEOUT
    
    try:
        # 创建带超时的 HTTP 客户端
        http_client = TwilioHttpClient(timeout=timeout_value)
        
        # 创建 Twilio 客户端
        client = Client(account_sid, auth_token, http_client=http_client)
        
        logger.info(f"Twilio API 客户端已创建，超时时间: {timeout_value}秒")
        return client
    except Exception as e:
        logger.error(f"创建 Twilio API 客户端失败: {e}")
        return None

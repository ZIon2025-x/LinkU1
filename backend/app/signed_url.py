"""
签名URL生成和验证模块
用于私有文件的访问控制
"""

import hmac
import hashlib
import time
import base64
import json
import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from urllib.parse import quote, unquote
import logging

logger = logging.getLogger(__name__)

class SignedURLManager:
    """签名URL管理器"""
    
    def __init__(self, secret_key: str = None):
        # 密钥优先级：参数 > SIGNED_URL_SECRET > SECRET_KEY
        self.secret_key = self._resolve_secret_key(secret_key)
        self.default_expiry_minutes = None  # 无过期时间

    def _resolve_secret_key(self, provided_key: Optional[str]) -> str:
        """解析签名密钥，生产环境禁止使用默认/空密钥。"""
        if provided_key:
            return provided_key

        signed_secret = os.getenv("SIGNED_URL_SECRET", "").strip()
        app_secret = os.getenv("SECRET_KEY", "").strip()
        is_production = os.getenv("ENVIRONMENT", "development") == "production"

        try:
            from app.config import Config
            if not signed_secret:
                signed_secret = getattr(Config, "SIGNED_URL_SECRET", "").strip()
            if not app_secret:
                app_secret = getattr(Config, "SECRET_KEY", "").strip()
            is_production = is_production or bool(getattr(Config, "IS_PRODUCTION", False))
        except Exception:
            # 配置模块不可用时，回退到环境变量，不中断开发流程
            pass

        resolved = signed_secret or app_secret
        insecure_values = {
            "",
            "your-secret-key-change-in-production",
            "change-this-secret-key-in-production",
            "linku-dev-only-insecure-key-do-not-use-in-production",
        }

        if is_production and resolved in insecure_values:
            raise RuntimeError(
                "SIGNED_URL_SECRET (or SECRET_KEY) must be configured with a secure value in production"
            )

        if not resolved:
            resolved = "linku-signed-url-dev-only-insecure-key"
            logger.warning(
                "SIGNED_URL_SECRET is not configured; using development fallback key."
            )

        return resolved
    
    def generate_signed_url(
        self, 
        file_path: str, 
        user_id: str,
        expiry_minutes: int = None,
        ip_address: str = None,
        one_time: bool = True
    ) -> str:
        """
        生成签名URL
        
        Args:
            file_path: 文件路径（相对于私有目录）
            user_id: 用户ID
            expiry_minutes: 过期时间（分钟）
            ip_address: 限制的IP地址
            one_time: 是否一次性使用
        
        Returns:
            签名URL
        """
        try:
            # 设置过期时间
            if expiry_minutes is None:
                expiry_minutes = self.default_expiry_minutes
            
            current_time = int(time.time())
            # 如果没有设置过期时间，设置为10年后（实际永不过期）
            if expiry_minutes is None:
                expiry_time = current_time + (10 * 365 * 24 * 60 * 60)  # 10年后
            else:
                expiry_time = current_time + (expiry_minutes * 60)
            
            # 构建签名数据
            signature_data = {
                "file_path": file_path,
                "user_id": user_id,
                "expiry": expiry_time,
                "ip": ip_address,
                "one_time": one_time,
                "timestamp": current_time
            }
            
            # 生成签名
            signature = self._generate_signature(signature_data)
            
            # 构建URL参数
            params = {
                "file": file_path,
                "user": user_id,
                "exp": expiry_time,
                "sig": signature,
                "ts": current_time  # 添加时间戳参数
            }
            
            if ip_address:
                params["ip"] = ip_address
            
            if one_time:
                params["ot"] = "1"
            
            # 构建完整URL
            from app.config import Config
            base_url = Config.BASE_URL
            query_string = "&".join([f"{k}={quote(str(v))}" for k, v in params.items()])
            
            return f"{base_url}/api/private-file?{query_string}"
            
        except Exception as e:
            logger.error(f"生成签名URL失败: {e}")
            raise
    
    def verify_signed_url(
        self, 
        file_path: str,
        user_id: str,
        expiry: int,
        signature: str,
        timestamp: int,
        ip_address: str = None,
        one_time: bool = False
    ) -> bool:
        """
        验证签名URL
        
        Args:
            file_path: 文件路径
            user_id: 用户ID
            expiry: 过期时间戳
            signature: 签名
            timestamp: 原始时间戳
            ip_address: 请求IP地址
            one_time: 是否一次性使用
        
        Returns:
            验证是否通过
        """
        try:
            # 检查是否过期
            if int(time.time()) > expiry:
                logger.warning(f"签名URL已过期: {file_path}")
                return False
            
            # 重新生成签名进行验证（使用原始时间戳）
            signature_data = {
                "file_path": file_path,
                "user_id": user_id,
                "expiry": expiry,
                "ip": ip_address,
                "one_time": one_time,
                "timestamp": timestamp
            }
            
            expected_signature = self._generate_signature(signature_data)
            
            # 使用安全的比较方法
            if not hmac.compare_digest(signature, expected_signature):
                logger.warning(f"签名验证失败: {file_path}")
                return False
            
            # 检查IP限制
            if ip_address and signature_data.get("ip") != ip_address:
                logger.warning(f"IP地址不匹配: {file_path}")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"验证签名URL失败: {e}")
            return False
    
    def _generate_signature(self, data: Dict[str, Any]) -> str:
        """生成HMAC签名"""
        # 将数据转换为JSON字符串
        data_str = json.dumps(data, sort_keys=True)
        
        # 使用HMAC-SHA256生成签名
        signature = hmac.new(
            self.secret_key.encode('utf-8'),
            data_str.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        return signature
    
    def parse_signed_url_params(self, query_params: Dict[str, str]) -> Optional[Dict[str, Any]]:
        """解析签名URL参数"""
        try:
            required_params = ["file", "user", "exp", "sig"]
            
            # 检查必需参数
            for param in required_params:
                if param not in query_params:
                    logger.warning(f"缺少必需参数: {param}")
                    return None
            
            # 处理可选的时间戳参数
            timestamp = None
            if "ts" in query_params:
                timestamp = int(query_params["ts"])
            else:
                # 向后兼容：如果没有时间戳，使用过期时间减去15分钟
                timestamp = int(query_params["exp"]) - 900
            
            return {
                "file_path": unquote(query_params["file"]),
                "user_id": unquote(query_params["user"]),
                "expiry": int(query_params["exp"]),
                "signature": query_params["sig"],
                "timestamp": timestamp,
                "ip_address": query_params.get("ip"),
                "one_time": query_params.get("ot") == "1"
            }
            
        except Exception as e:
            logger.error(f"解析签名URL参数失败: {e}")
            return None

# 全局实例
signed_url_manager = SignedURLManager()

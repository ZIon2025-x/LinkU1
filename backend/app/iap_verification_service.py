"""
Apple IAP收据验证服务
使用App Store Server API进行服务器端验证
"""
import os
import json
import base64
import logging
import requests
from typing import Optional, Dict, Any
from datetime import datetime, timezone
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import jwt

from app.apple_webhook_verifier import get_verifier as get_apple_signed_data_verifier

logger = logging.getLogger(__name__)


class IAPVerificationService:
    """Apple IAP验证服务"""

    # App Store Server API端点
    PRODUCTION_API_URL = "https://api.storekit.itunes.apple.com"
    SANDBOX_API_URL = "https://api.storekit-sandbox.itunes.apple.com"

    def __init__(self):
        """初始化验证服务"""
        # 从环境变量获取App Store Connect配置
        self.app_store_connect_key_id = os.getenv("APP_STORE_CONNECT_KEY_ID")
        self.app_store_connect_issuer_id = os.getenv("APP_STORE_CONNECT_ISSUER_ID")
        self.app_store_connect_key_path = os.getenv("APP_STORE_CONNECT_KEY_PATH")
        self.app_store_connect_key_content = os.getenv("APP_STORE_CONNECT_KEY_CONTENT")
        
        # 是否启用完整验证（生产环境应启用）
        self.enable_full_verification = os.getenv("ENABLE_IAP_FULL_VERIFICATION", "true").lower() == "true"
        
        # 是否使用沙盒环境
        self.use_sandbox = os.getenv("IAP_USE_SANDBOX", "false").lower() == "true"
        
        # 🔒 安全检查：非沙盒环境（生产）必须启用完整验证
        if not self.enable_full_verification and not self.use_sandbox:
            logger.critical("IAP signature verification MUST be enabled in production! Forcing enable_full_verification=True")
            self.enable_full_verification = True
        
        self.api_base_url = self.SANDBOX_API_URL if self.use_sandbox else self.PRODUCTION_API_URL
    
    def verify_transaction_jws(self, transaction_jws: str) -> Dict[str, Any]:
        """
        验证并解析交易 JWS。

        启用完整验证时（生产环境强制启用），使用 app-store-server-library 的
        SignedDataVerifier 完整校验 Apple Root CA → 中间证书 → 叶子证书的链路 +
        签名 + bundle_id + environment，杜绝攻击者用自签证书伪造 JWS 的旁路。
        """
        if self.enable_full_verification:
            return self._verify_with_signed_data_verifier(transaction_jws)
        # 仅 sandbox 且显式关闭完整验证时走快路径（仅供本地/CI 测试）
        return self._parse_jws_unverified(transaction_jws)

    def _verify_with_signed_data_verifier(self, transaction_jws: str) -> Dict[str, Any]:
        verifier = get_apple_signed_data_verifier()
        if verifier is None:
            raise ValueError(
                "IAP 验证器未初始化（缺少 Apple root certs 或 app-store-server-library 未安装），"
                "拒绝激活以避免凭据伪造旁路"
            )
        try:
            decoded = verifier.verify_and_decode_signed_transaction(transaction_jws)
        except Exception as e:
            raise ValueError(f"JWS 签名验证失败: {e}")
        return self._decoded_payload_to_dict(decoded)

    @staticmethod
    def _decoded_payload_to_dict(decoded) -> Dict[str, Any]:
        """把 JWSTransactionDecodedPayload 映射成原有调用方期望的 dict 形状。"""
        environment = None
        if getattr(decoded, "rawEnvironment", None):
            environment = decoded.rawEnvironment
        elif getattr(decoded, "environment", None) is not None:
            environment = decoded.environment.value
        # offerType: 1=INTRODUCTORY, 2=PROMOTIONAL, 3=CODE
        offer_type = getattr(decoded, "offerType", None)
        offer_type_value = offer_type.value if offer_type is not None and hasattr(offer_type, "value") else getattr(decoded, "rawOfferType", None)
        is_intro = offer_type_value == 1
        type_val = getattr(decoded, "type", None)
        type_str = type_val.value if type_val is not None and hasattr(type_val, "value") else (getattr(decoded, "rawType", None) or "")
        return {
            "header": None,
            "payload": None,
            "transaction_id": str(getattr(decoded, "transactionId", "") or ""),
            "original_transaction_id": str(getattr(decoded, "originalTransactionId", "") or ""),
            "product_id": getattr(decoded, "productId", "") or "",
            "purchase_date": getattr(decoded, "purchaseDate", 0) or 0,
            "expires_date": getattr(decoded, "expiresDate", 0) or 0,
            "is_trial_period": is_intro,  # JWSTransactionDecodedPayload 不直接给这两个字段，由 offerType 推导
            "is_in_intro_offer_period": is_intro,
            "environment": environment or "Production",
            "type": type_str,
        }

    @staticmethod
    def _parse_jws_unverified(transaction_jws: str) -> Dict[str, Any]:
        """仅 sandbox 且显式关闭完整验证时使用：解析但不验证签名。生产强制启用完整验证（见 __init__）。"""
        parts = transaction_jws.split(".")
        if len(parts) != 3:
            raise ValueError("无效的JWS格式：必须包含header、payload和signature三部分")
        header_b64, payload_b64, _ = parts
        try:
            header_padded = header_b64 + "=" * (-len(header_b64) % 4)
            header = json.loads(base64.urlsafe_b64decode(header_padded))
            payload_padded = payload_b64 + "=" * (-len(payload_b64) % 4)
            transaction_data = json.loads(base64.urlsafe_b64decode(payload_padded))
        except (json.JSONDecodeError, ValueError) as e:
            raise ValueError(f"JWS payload解析失败: {e}")
        return {
            "header": header,
            "payload": transaction_data,
            "transaction_id": str(transaction_data.get("transactionId", "")),
            "original_transaction_id": str(transaction_data.get("originalTransactionId", "")),
            "product_id": transaction_data.get("productId", ""),
            "purchase_date": transaction_data.get("purchaseDate", 0),
            "expires_date": transaction_data.get("expiresDate", 0),
            "is_trial_period": transaction_data.get("isTrialPeriod", False),
            "is_in_intro_offer_period": transaction_data.get("isInIntroOfferPeriod", False),
            "environment": transaction_data.get("environment", "Production"),
            "type": transaction_data.get("type", ""),
        }
    
    def get_transaction_info(self, transaction_id: str, environment: str = "Production") -> Optional[Dict[str, Any]]:
        """
        从Apple获取交易信息（使用App Store Server API）
        
        Args:
            transaction_id: 交易ID
            environment: 环境（Production或Sandbox）
            
        Returns:
            交易信息字典，如果获取失败返回None
        """
        if not self.app_store_connect_key_id or not self.app_store_connect_issuer_id:
            logger.warning("App Store Connect配置不完整，跳过服务器端验证")
            return None
        
        try:
            # 生成JWT token用于认证
            token = self._generate_app_store_connect_token()
            
            # 构建API URL
            api_url = self.SANDBOX_API_URL if environment == "Sandbox" else self.PRODUCTION_API_URL
            url = f"{api_url}/inApps/v1/transactions/{transaction_id}"
            
            # 发送请求
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.warning(f"获取交易信息失败: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"获取交易信息时发生错误: {str(e)}")
            return None
    
    def _generate_app_store_connect_token(self) -> str:
        """
        生成App Store Connect JWT token
        
        Returns:
            JWT token字符串
        """
        if not self.app_store_connect_key_id or not self.app_store_connect_issuer_id:
            raise ValueError("App Store Connect配置不完整")
        
        # 读取私钥
        if self.app_store_connect_key_content:
            key_data = self.app_store_connect_key_content.encode()
        elif self.app_store_connect_key_path:
            with open(self.app_store_connect_key_path, 'r') as f:
                key_data = f.read().encode()
        else:
            raise ValueError("App Store Connect私钥未配置")
        
        # 解析私钥
        private_key = serialization.load_pem_private_key(
            key_data,
            password=None,
            backend=default_backend()
        )
        
        # 生成JWT
        now = datetime.now(timezone.utc)
        payload = {
            "iss": self.app_store_connect_issuer_id,
            "iat": int(now.timestamp()),
            "exp": int((now.timestamp() + 3600)),  # 1小时有效期
            "aud": "appstoreconnect-v1"
        }
        
        headers = {
            "alg": "ES256",
            "kid": self.app_store_connect_key_id,
            "typ": "JWT"
        }
        
        token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
        return token
    
    def validate_product_id(self, product_id: str) -> bool:
        """
        验证产品ID是否有效
        
        Args:
            product_id: 产品ID
            
        Returns:
            如果产品ID有效返回True
        """
        valid_product_ids = [
            "com.link2ur.vip.monthly",
            "com.link2ur.vip.yearly"
        ]
        return product_id in valid_product_ids
    
    def convert_timestamp_to_datetime(self, timestamp_ms: int) -> datetime:
        """
        将Apple时间戳（毫秒）转换为datetime对象
        
        Args:
            timestamp_ms: 毫秒时间戳
            
        Returns:
            datetime对象
        """
        if timestamp_ms == 0:
            return None
        return datetime.fromtimestamp(timestamp_ms / 1000.0, tz=timezone.utc)


# 创建全局实例
iap_verification_service = IAPVerificationService()

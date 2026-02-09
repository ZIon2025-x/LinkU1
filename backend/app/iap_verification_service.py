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
from cryptography import x509
import jwt
from jwt import PyJWKClient

logger = logging.getLogger(__name__)


class IAPVerificationService:
    """Apple IAP验证服务"""
    
    # App Store Server API端点
    PRODUCTION_API_URL = "https://api.storekit.itunes.apple.com"
    SANDBOX_API_URL = "https://api.storekit-sandbox.itunes.apple.com"
    
    # Apple公钥URL（用于验证JWS）
    APPLE_PUBLIC_KEY_URL = "https://api.appstoreconnect.apple.com/v1/certificates"
    
    # JWT密钥ID（从JWS header中获取）
    APPLE_KEY_ID_HEADER = "x5c"
    
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
        验证交易JWS
        
        Args:
            transaction_jws: JWS格式的交易数据
            
        Returns:
            解析后的交易数据
            
        Raises:
            ValueError: 如果JWS格式无效或验证失败
        """
        try:
            # 解析JWS header
            parts = transaction_jws.split('.')
            if len(parts) != 3:
                raise ValueError("无效的JWS格式：必须包含header、payload和signature三部分")
            
            header_b64, payload_b64, signature_b64 = parts
            
            # 解码header
            header_padded = header_b64 + '=' * (4 - len(header_b64) % 4)
            header_data = base64.urlsafe_b64decode(header_padded)
            header = json.loads(header_data)
            
            # 解码payload（不验证签名，仅用于获取信息）
            payload_padded = payload_b64 + '=' * (4 - len(payload_b64) % 4)
            payload_data = base64.urlsafe_b64decode(payload_padded)
            transaction_data = json.loads(payload_data)
            
            # 如果启用完整验证，验证JWS签名
            if self.enable_full_verification:
                self._verify_jws_signature(transaction_jws, header)
            
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
            
        except json.JSONDecodeError as e:
            raise ValueError(f"JWS payload解析失败: {str(e)}")
        except Exception as e:
            raise ValueError(f"JWS验证失败: {str(e)}")
    
    def _verify_jws_signature(self, transaction_jws: str, header: Dict[str, Any]) -> None:
        """
        验证JWS签名（使用Apple公钥）
        
        Apple的JWS交易收据通常包含x5c证书链，应该优先使用x5c进行验证。
        x5c是自包含的，不需要从外部API获取。
        
        Args:
            transaction_jws: JWS格式的交易数据
            header: JWS header
            
        Raises:
            ValueError: 如果签名验证失败
        """
        try:
            # 优先使用x5c证书链（Apple的JWS通常都包含x5c）
            x5c = header.get("x5c")
            if x5c and len(x5c) > 0:
                # 使用证书链中的第一个证书（叶子证书）验证签名
                cert_data = base64.b64decode(x5c[0])
                cert = x509.load_der_x509_certificate(cert_data, default_backend())
                public_key = cert.public_key()
                
                # 验证JWS签名
                jwt.decode(
                    transaction_jws,
                    public_key,
                    algorithms=["ES256"],
                    options={"verify_signature": True}
                )
                logger.debug("JWS签名验证成功（使用x5c证书）")
                return
            
            # 如果没有x5c，尝试使用kid（但Apple的JWS通常都有x5c）
            kid = header.get("kid")
            if kid:
                # 注意：Apple的公开JWKS端点可能不适用于所有情况
                # 如果kid存在但没有x5c，记录警告
                error_msg = f"JWS header包含kid但没有x5c，无法验证签名。kid={kid}"
                logger.warning(error_msg)
                # 如果启用完整验证且不是沙盒环境，抛出异常
                if self.enable_full_verification and not self.use_sandbox:
                    raise ValueError(error_msg)
            else:
                error_msg = "JWS header中缺少x5c和kid，无法验证签名"
                logger.warning(error_msg)
                # 如果启用完整验证且不是沙盒环境，抛出异常
                if self.enable_full_verification and not self.use_sandbox:
                    raise ValueError(error_msg)
                
        except jwt.InvalidSignatureError as e:
            error_msg = f"JWS签名验证失败: 签名无效 - {str(e)}"
            logger.error(error_msg)
            if self.enable_full_verification and not self.use_sandbox:
                raise ValueError(error_msg)
        except Exception as e:
            error_msg = f"JWS签名验证失败: {str(e)}"
            logger.warning(f"{error_msg}（继续处理）")
            # 在生产环境中，如果验证失败应该抛出异常
            # 但在开发环境中，我们可以记录警告并继续
            if self.enable_full_verification and not self.use_sandbox:
                raise ValueError(error_msg)
    
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

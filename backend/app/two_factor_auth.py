"""
双因素认证 (2FA/TOTP) 工具模块
支持 Google Authenticator、Microsoft Authenticator 等 TOTP 应用
"""

import pyotp
import qrcode
import io
import base64
import secrets
import json
import logging
from typing import Optional, Dict, Tuple
from app.config import Config

logger = logging.getLogger(__name__)


class TwoFactorAuth:
    """双因素认证管理器"""
    
    @staticmethod
    def generate_secret() -> str:
        """生成新的 TOTP 密钥（Base32 编码）"""
        return pyotp.random_base32()
    
    @staticmethod
    def generate_qr_code(secret: str, email: str, issuer: str = "Link²Ur Admin") -> str:
        """
        生成 QR 码的 Base64 编码图片
        
        Args:
            secret: TOTP 密钥
            email: 用户邮箱（用于标识）
            issuer: 发行者名称
        
        Returns:
            Base64 编码的 PNG 图片字符串（data URI 格式）
        """
        # 生成 TOTP URI（符合 Google Authenticator 标准）
        totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
            name=email,
            issuer_name=issuer
        )
        
        # 生成 QR 码
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(totp_uri)
        qr.make(fit=True)
        
        # 创建图片
        img = qr.make_image(fill_color="black", back_color="white")
        
        # 转换为 Base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return f"data:image/png;base64,{img_str}"
    
    @staticmethod
    def verify_totp(secret: str, token: str, window: int = 1) -> bool:
        """
        验证 TOTP 代码
        
        Args:
            secret: TOTP 密钥
            token: 用户输入的 6 位验证码
            window: 时间窗口容差（默认 1，即前后各 1 个时间步）
        
        Returns:
            True 如果验证通过，False 否则
        """
        try:
            totp = pyotp.TOTP(secret)
            # 验证代码，允许时间窗口容差
            return totp.verify(token, valid_window=window)
        except Exception as e:
            logger.error(f"TOTP 验证失败: {e}")
            return False
    
    @staticmethod
    def generate_backup_codes(count: int = 10) -> list[str]:
        """
        生成备份代码（用于在无法使用 Authenticator 时恢复账户）
        
        Args:
            count: 生成代码数量（默认 10 个）
        
        Returns:
            备份代码列表（每个代码 8 位数字）
        """
        codes = []
        for _ in range(count):
            # 生成 8 位数字代码
            code = ''.join([str(secrets.randbelow(10)) for _ in range(8)])
            codes.append(code)
        return codes
    
    @staticmethod
    def verify_backup_code(backup_codes_json: Optional[str], code: str) -> Tuple[bool, Optional[str]]:
        """
        验证备份代码
        
        Args:
            backup_codes_json: 存储的备份代码 JSON 字符串
            code: 用户输入的备份代码
        
        Returns:
            (是否验证通过, 更新后的备份代码 JSON 字符串)
        """
        if not backup_codes_json:
            return False, None
        
        try:
            # 解析备份代码列表
            codes = json.loads(backup_codes_json)
            if not isinstance(codes, list):
                return False, None
            
            # 检查代码是否存在
            if code in codes:
                # 移除已使用的代码
                codes.remove(code)
                # 返回更新后的列表
                return True, json.dumps(codes) if codes else None
            else:
                return False, None
        except Exception as e:
            logger.error(f"备份代码验证失败: {e}")
            return False, None
    
    @staticmethod
    def get_totp_uri(secret: str, email: str, issuer: str = "Link²Ur Admin") -> str:
        """
        获取 TOTP URI（用于手动输入到 Authenticator 应用）
        
        Args:
            secret: TOTP 密钥
            email: 用户邮箱
            issuer: 发行者名称
        
        Returns:
            TOTP URI 字符串
        """
        totp = pyotp.totp.TOTP(secret)
        return totp.provisioning_uri(name=email, issuer_name=issuer)

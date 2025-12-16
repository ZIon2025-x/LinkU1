"""
CAPTCHA 验证模块
支持 Google reCAPTCHA v3 和 hCaptcha
"""

import os
import logging
import requests
from typing import Optional, Dict, Any
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


class CaptchaVerifier:
    """CAPTCHA 验证器"""
    
    def __init__(self):
        # Google reCAPTCHA v2 配置（交互式验证）
        self.recaptcha_secret_key = os.getenv("RECAPTCHA_SECRET_KEY", None)
        self.recaptcha_site_key = os.getenv("RECAPTCHA_SITE_KEY", None)
        self.recaptcha_enabled = bool(self.recaptcha_secret_key and self.recaptcha_site_key)
        
        # hCaptcha 配置
        self.hcaptcha_secret_key = os.getenv("HCAPTCHA_SECRET_KEY", None)
        self.hcaptcha_site_key = os.getenv("HCAPTCHA_SITE_KEY", None)
        self.hcaptcha_enabled = bool(self.hcaptcha_secret_key and self.hcaptcha_site_key)
        
        # 默认使用 reCAPTCHA，如果没有配置则使用 hCaptcha
        self.use_recaptcha = self.recaptcha_enabled
        self.use_hcaptcha = self.hcaptcha_enabled and not self.recaptcha_enabled
        
        if self.use_recaptcha:
            logger.info(f"CAPTCHA: 使用 Google reCAPTCHA v2（交互式验证）")
            logger.info(f"CAPTCHA 配置检查: Site Key前10字符={self.recaptcha_site_key[:10] if self.recaptcha_site_key else 'N/A'}, Secret Key前10字符={self.recaptcha_secret_key[:10] if self.recaptcha_secret_key else 'N/A'}")
        elif self.use_hcaptcha:
            logger.info("CAPTCHA: 使用 hCaptcha")
        else:
            logger.warning("CAPTCHA: 未配置，验证码验证将被禁用（仅开发环境）")
    
    def verify_recaptcha(self, token: str, remote_ip: Optional[str] = None) -> Dict[str, Any]:
        """验证 Google reCAPTCHA v2 token（交互式验证）"""
        if not self.recaptcha_secret_key:
            return {"success": False, "error": "reCAPTCHA 未配置"}
        
        try:
            url = "https://www.google.com/recaptcha/api/siteverify"
            data = {
                "secret": self.recaptcha_secret_key,
                "response": token
            }
            if remote_ip:
                data["remoteip"] = remote_ip
            
            response = requests.post(url, data=data, timeout=5.0)
            result = response.json()
            
            logger.info(f"reCAPTCHA 验证请求: token长度={len(token) if token else 0}, IP={remote_ip}, Secret Key前10字符={self.recaptcha_secret_key[:10] if self.recaptcha_secret_key else 'N/A'}, 响应={result}")
            
            if result.get("success"):
                # reCAPTCHA v2 成功即通过（用户已点击"我不是机器人"）
                logger.info(f"reCAPTCHA 验证成功: hostname={result.get('hostname')}, challenge_ts={result.get('challenge_ts')}")
                return {
                    "success": True,
                    "challenge_ts": result.get("challenge_ts"),
                    "hostname": result.get("hostname")
                }
            else:
                error_codes = result.get("error-codes", [])
                error_msg = f"reCAPTCHA 验证失败: {error_codes}, IP: {remote_ip}, token前10字符: {token[:10] if token and len(token) > 10 else 'N/A'}"
                
                # 详细错误信息
                if 'invalid-input-response' in error_codes:
                    error_msg += " (token无效或已过期，请重新完成验证)"
                elif 'invalid-input-secret' in error_codes:
                    error_msg += " (Secret Key配置错误)"
                elif 'missing-input-response' in error_codes:
                    error_msg += " (缺少token)"
                elif 'missing-input-secret' in error_codes:
                    error_msg += " (缺少Secret Key)"
                
                logger.warning(error_msg)
                return {
                    "success": False,
                    "error": "reCAPTCHA 验证失败，请重新验证",
                    "error_codes": error_codes
                }
        except Exception as e:
            logger.error(f"reCAPTCHA 验证请求失败: {e}")
            return {"success": False, "error": f"验证请求失败: {str(e)}"}
    
    def verify_hcaptcha(self, token: str, remote_ip: Optional[str] = None) -> Dict[str, Any]:
        """验证 hCaptcha token"""
        if not self.hcaptcha_secret_key:
            return {"success": False, "error": "hCaptcha 未配置"}
        
        try:
            url = "https://hcaptcha.com/siteverify"
            data = {
                "secret": self.hcaptcha_secret_key,
                "response": token
            }
            if remote_ip:
                data["remoteip"] = remote_ip
            
            response = requests.post(url, data=data, timeout=5.0)
            result = response.json()
            
            if result.get("success"):
                return {
                    "success": True,
                    "challenge_ts": result.get("challenge_ts"),
                    "hostname": result.get("hostname")
                }
            else:
                error_codes = result.get("error-codes", [])
                logger.warning(f"hCaptcha 验证失败: {error_codes}, IP: {remote_ip}")
                return {
                    "success": False,
                    "error": "hCaptcha 验证失败",
                    "error_codes": error_codes
                }
        except Exception as e:
            logger.error(f"hCaptcha 验证请求失败: {e}")
            return {"success": False, "error": f"验证请求失败: {str(e)}"}
    
    def verify(self, token: str, remote_ip: Optional[str] = None) -> Dict[str, Any]:
        """验证 CAPTCHA token（自动选择服务）"""
        # 开发环境：如果没有配置 CAPTCHA，允许通过
        if not self.use_recaptcha and not self.use_hcaptcha:
            env = os.getenv("ENVIRONMENT", "development")
            if env == "development":
                logger.warning("开发环境：跳过 CAPTCHA 验证")
                return {"success": True, "bypass": True}
            else:
                return {"success": False, "error": "CAPTCHA 未配置"}
        
        if not token:
            return {"success": False, "error": "缺少 CAPTCHA token"}
        
        if self.use_recaptcha:
            return self.verify_recaptcha(token, remote_ip)
        elif self.use_hcaptcha:
            return self.verify_hcaptcha(token, remote_ip)
        else:
            return {"success": False, "error": "CAPTCHA 未配置"}
    
    def get_site_key(self) -> Optional[str]:
        """获取前端使用的 site key"""
        if self.use_recaptcha:
            return self.recaptcha_site_key
        elif self.use_hcaptcha:
            return self.hcaptcha_site_key
        return None
    
    def is_enabled(self) -> bool:
        """检查 CAPTCHA 是否已启用"""
        return self.use_recaptcha or self.use_hcaptcha


# 创建全局 CAPTCHA 验证器实例
captcha_verifier = CaptchaVerifier()


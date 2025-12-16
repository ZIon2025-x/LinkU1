"""
Twilio SMS 服务模块
用于发送手机验证码短信
支持两种模式：
1. Messages API（需要购买手机号）
2. Verify API（不需要购买手机号，推荐）
"""

import logging
import os
from typing import Optional
from twilio.rest import Client
from twilio.base.exceptions import TwilioException, TwilioRestException

logger = logging.getLogger(__name__)


class TwilioSMS:
    """Twilio SMS 服务类"""
    
    def __init__(self):
        """初始化 Twilio 客户端"""
        self.account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        self.auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        self.from_number = os.getenv("TWILIO_PHONE_NUMBER")  # Twilio 分配的号码（Messages API）
        self.verify_service_sid = os.getenv("TWILIO_VERIFY_SERVICE_SID")  # Verify Service SID（Verify API）
        
        # 优先使用 Verify API（不需要购买手机号）
        self.use_verify_api = bool(self.verify_service_sid)
        
        # 检查配置是否完整
        if not all([self.account_sid, self.auth_token]):
            logger.warning("Twilio 配置不完整，SMS 功能将不可用")
            self.client = None
            self.verify_client = None
        else:
            try:
                self.client = Client(self.account_sid, self.auth_token)
                if self.use_verify_api:
                    # Verify API 使用相同的 client，但通过 verify.v2.services 访问
                    self.verify_client = self.client.verify.v2.services(self.verify_service_sid)
                    logger.info(f"Twilio Verify API 初始化成功 (Service SID: {self.verify_service_sid})")
                elif self.from_number:
                    logger.info("Twilio Messages API 初始化成功")
                else:
                    logger.warning("Twilio 配置不完整：未配置 TWILIO_PHONE_NUMBER 或 TWILIO_VERIFY_SERVICE_SID")
                    self.client = None
            except Exception as e:
                logger.error(f"Twilio 客户端初始化失败: {e}")
                self.client = None
                self.verify_client = None
    
    def send_verification_code(self, phone: str, code: str = None, language: str = 'zh') -> bool:
        """
        发送验证码短信
        
        Args:
            phone: 手机号（需要包含国家代码，如 +86）
            code: 验证码（仅用于 Messages API，Verify API 会自动生成）
            language: 语言 ('zh' 或 'en')
        
        Returns:
            bool: 发送是否成功
        """
        if not self.client:
            logger.error("Twilio 客户端未初始化，无法发送短信")
            return False
        
        # 格式化手机号（确保包含国家代码）
        formatted_phone = self._format_phone_number(phone)
        if not formatted_phone:
            logger.error(f"手机号格式无效: {phone}")
            return False
        
        # 优先使用 Verify API（不需要购买手机号）
        if self.use_verify_api and self.verify_client:
            try:
                # Verify API 会自动生成验证码，不需要传入 code
                verification = self.verify_client.verifications.create(
                    to=formatted_phone,
                    channel='sms'
                )
                logger.info(f"Verify API 验证码发送成功: phone={formatted_phone}, sid={verification.sid}, status={verification.status}")
                return True
            except TwilioRestException as e:
                error_msg = str(e)
                # 检测特定的错误类型
                if '60220' in error_msg or 'use case vetting' in error_msg.lower() or 'whitelisted' in error_msg.lower():
                    logger.error(f"Twilio Verify API 错误（需要审核）: {e}")
                    # 抛出特殊异常，让调用者知道这是需要审核的错误
                    raise ValueError("CHINA_VETTING_REQUIRED")
                logger.error(f"Twilio Verify API 错误: {e}")
                return False
            except TwilioException as e:
                logger.error(f"Twilio 异常: {e}")
                return False
            except Exception as e:
                logger.error(f"发送验证码失败: {e}")
                return False
        
        # 回退到 Messages API（需要购买手机号）
        if not self.from_number:
            logger.error("未配置 TWILIO_PHONE_NUMBER，无法使用 Messages API")
            return False
        
        if not code:
            logger.error("Messages API 需要提供验证码")
            return False
        
        # 根据语言选择短信内容
        if language == 'zh':
            message = f"您的 Link²Ur 登录验证码是：{code}，有效期5分钟。请勿泄露给他人。"
        else:
            message = f"Your Link²Ur verification code is: {code}. Valid for 5 minutes. Do not share with others."
        
        try:
            message_obj = self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=formatted_phone
            )
            logger.info(f"短信发送成功: phone={formatted_phone}, message_sid={message_obj.sid}")
            return True
        except TwilioRestException as e:
            error_msg = str(e)
            # 检测特定的错误类型（中国手机号需要审核）
            if '60220' in error_msg or 'use case vetting' in error_msg.lower() or 'whitelisted' in error_msg.lower():
                logger.error(f"Twilio Messages API 错误（需要审核）: {e}")
                # 抛出特殊异常，让调用者知道这是需要审核的错误
                raise ValueError("CHINA_VETTING_REQUIRED")
            logger.error(f"Twilio API 错误: {e}")
            return False
        except TwilioException as e:
            logger.error(f"Twilio 异常: {e}")
            return False
        except Exception as e:
            logger.error(f"发送短信失败: {e}")
            return False
    
    def verify_code(self, phone: str, code: str) -> bool:
        """
        验证验证码（仅用于 Verify API）
        
        Args:
            phone: 手机号（需要包含国家代码，如 +86）
            code: 验证码
        
        Returns:
            bool: 验证是否成功
        """
        if not self.use_verify_api or not self.verify_client:
            logger.warning("Verify API 未配置，无法验证验证码")
            return False
        
        formatted_phone = self._format_phone_number(phone)
        if not formatted_phone:
            logger.error(f"手机号格式无效: {phone}")
            return False
        
        try:
            verification_check = self.verify_client.verification_checks.create(
                to=formatted_phone,
                code=code
            )
            is_valid = verification_check.status == 'approved'
            logger.info(f"验证码验证结果: phone={formatted_phone}, status={verification_check.status}, valid={is_valid}")
            return is_valid
        except TwilioRestException as e:
            logger.error(f"Twilio Verify API 验证错误: {e}")
            return False
        except Exception as e:
            logger.error(f"验证验证码失败: {e}")
            return False
    
    def send_update_verification_code(self, phone: str, code: str, language: str = 'zh') -> bool:
        """
        发送修改手机号验证码短信
        
        Args:
            phone: 手机号（需要包含国家代码，如 +86）
            code: 验证码
            language: 语言 ('zh' 或 'en')
        
        Returns:
            bool: 发送是否成功
        """
        if not self.client:
            logger.error("Twilio 客户端未初始化，无法发送短信")
            return False
        
        # 格式化手机号（确保包含国家代码）
        formatted_phone = self._format_phone_number(phone)
        if not formatted_phone:
            logger.error(f"手机号格式无效: {phone}")
            return False
        
        # 根据语言选择短信内容
        if language == 'zh':
            message = f"您的 Link²Ur 手机号修改验证码是：{code}，有效期5分钟。请勿泄露给他人。"
        else:
            message = f"Your Link²Ur phone number update verification code is: {code}. Valid for 5 minutes. Do not share with others."
        
        try:
            message_obj = self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=formatted_phone
            )
            logger.info(f"手机号修改验证码短信发送成功: phone={formatted_phone}, message_sid={message_obj.sid}")
            return True
        except TwilioRestException as e:
            logger.error(f"Twilio API 错误: {e}")
            return False
        except TwilioException as e:
            logger.error(f"Twilio 异常: {e}")
            return False
        except Exception as e:
            logger.error(f"发送短信失败: {e}")
            return False
    
    def _format_phone_number(self, phone: str) -> Optional[str]:
        """
        格式化手机号（简化版：前端已发送完整号码，只需验证格式）
        
        Args:
            phone: 手机号（前端已包含国家代码，如 +447700123456）
        
        Returns:
            str: 格式化后的手机号（如果格式有效），如果格式无效则返回 None
        """
        # 如果已经以 + 开头，直接返回（前端已发送完整号码）
        if phone.startswith('+'):
            # 验证格式：+ 后应该是数字
            import re
            if re.match(r'^\+\d{10,15}$', phone):
                return phone
            else:
                logger.warning(f"手机号格式无效（长度或格式错误）: {phone}")
                return None
        
        # 如果以 00 开头，替换为 +（兼容旧格式）
        if phone.startswith('00'):
            formatted = '+' + phone[2:]
            import re
            if re.match(r'^\+\d{10,15}$', formatted):
                return formatted
        
        # 如果前端没有发送 + 开头的号码，记录警告但尝试格式化（向后兼容）
        import re
        digits = re.sub(r'\D', '', phone)
        
        # 如果以44开头（英国国家代码），添加 +
        if digits.startswith('44') and len(digits) >= 10:
            return '+' + digits
        
        # 如果无法识别，返回 None
        logger.warning(f"手机号格式无效（需要以+开头）: {phone}")
        return None


# 创建全局实例
twilio_sms = TwilioSMS()


"""
Twilio SMS 服务模块
用于发送手机验证码短信
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
        self.from_number = os.getenv("TWILIO_PHONE_NUMBER")  # Twilio 分配的号码
        
        # 检查配置是否完整
        if not all([self.account_sid, self.auth_token, self.from_number]):
            logger.warning("Twilio 配置不完整，SMS 功能将不可用")
            self.client = None
        else:
            try:
                self.client = Client(self.account_sid, self.auth_token)
                logger.info("Twilio 客户端初始化成功")
            except Exception as e:
                logger.error(f"Twilio 客户端初始化失败: {e}")
                self.client = None
    
    def send_verification_code(self, phone: str, code: str, language: str = 'zh') -> bool:
        """
        发送验证码短信
        
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
            logger.error(f"Twilio API 错误: {e}")
            return False
        except TwilioException as e:
            logger.error(f"Twilio 异常: {e}")
            return False
        except Exception as e:
            logger.error(f"发送短信失败: {e}")
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
        格式化手机号，添加国家代码
        
        Args:
            phone: 手机号（可能包含或不包含国家代码）
        
        Returns:
            str: 格式化后的手机号（包含国家代码），如果格式无效则返回 None
        """
        # 移除所有非数字字符
        import re
        digits = re.sub(r'\D', '', phone)
        
        # 如果已经以 + 开头，直接返回
        if phone.startswith('+'):
            return phone
        
        # 如果以 00 开头，替换为 +
        if phone.startswith('00'):
            return '+' + phone[2:]
        
        # 中国手机号：11位数字，添加 +86
        if len(digits) == 11 and digits.startswith('1'):
            return f"+86{digits}"
        
        # 如果已经是国际格式（10-15位数字），假设是中国号码
        if 10 <= len(digits) <= 15:
            # 如果以 86 开头，添加 +
            if digits.startswith('86'):
                return '+' + digits
            # 否则假设是中国号码
            if len(digits) == 11:
                return f"+86{digits}"
        
        # 如果无法识别，返回 None
        logger.warning(f"无法格式化手机号: {phone}")
        return None


# 创建全局实例
twilio_sms = TwilioSMS()


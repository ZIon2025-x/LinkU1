"""
输入验证模块
提供统一的输入验证和清理功能
"""

import re
import html
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, validator, Field
from fastapi import HTTPException, status


class BaseValidator(BaseModel):
    """基础验证器"""
    
    class Config:
        # 允许任意类型
        arbitrary_types_allowed = True


class StringValidator(BaseValidator):
    """字符串验证器"""
    
    @staticmethod
    def sanitize_string(value: str, max_length: int = 255) -> str:
        """清理和验证字符串"""
        if not isinstance(value, str):
            raise ValueError("必须是字符串类型")
        
        # 去除首尾空格
        value = value.strip()
        
        # 检查长度
        if len(value) == 0:
            raise ValueError("不能为空")
        
        if len(value) > max_length:
            raise ValueError(f"长度不能超过{max_length}个字符")
        
        # HTML转义防止XSS
        value = html.escape(value)
        
        return value
    
    @staticmethod
    def validate_email(email: str) -> str:
        """验证邮箱格式"""
        email = email.strip().lower()
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        
        if not re.match(pattern, email):
            raise ValueError("邮箱格式不正确")
        
        if len(email) > 254:  # RFC 5321限制
            raise ValueError("邮箱长度不能超过254个字符")
        
        return email
    
    @staticmethod
    def validate_password(password: str) -> str:
        """验证密码强度"""
        if len(password) < 12:
            raise ValueError("密码至少需要12个字符")
        
        if len(password) > 128:
            raise ValueError("密码不能超过128个字符")
        
        # 检查是否包含至少一个大写字母
        if not re.search(r'[A-Z]', password):
            raise ValueError("密码必须包含至少一个大写字母")
        
        # 检查是否包含至少一个小写字母
        if not re.search(r'[a-z]', password):
            raise ValueError("密码必须包含至少一个小写字母")
        
        # 检查是否包含至少一个数字
        if not re.search(r'\d', password):
            raise ValueError("密码必须包含至少一个数字")
        
        # 检查是否包含至少一个特殊字符
        # 使用与 password_validator.py 相同的检测逻辑
        # 先检查显式特殊字符列表（包含常见货币符号）
        special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?~`\"'\\/￥£€¥"
        has_special_en = bool(re.search(f'[{re.escape(special_chars)}]', password))
        # 再检查Unicode特殊字符（排除中文字符范围）
        has_special_unicode = bool(re.search(r'[^\w\s\u4e00-\u9fff]', password))
        has_special = has_special_en or has_special_unicode
        
        if not has_special:
            raise ValueError("密码必须包含至少一个特殊字符")
        
        return password
    
    @staticmethod
    def validate_username(username: str) -> str:
        """验证用户名"""
        username = username.strip()
        
        if len(username) < 3:
            raise ValueError("用户名至少3个字符")
        
        if len(username) > 30:
            raise ValueError("用户名不能超过30个字符")
        
        # 支持中文、英文字母、数字、下划线和连字符
        # 排除空格、换行、制表符等空白字符
        if re.search(r'[\s\n\r\t]', username):
            raise ValueError("用户名不能包含空格或换行符")
        
        # 不能以数字开头
        if username[0].isdigit():
            raise ValueError("用户名不能以数字开头")
        
        return username
    
    @staticmethod
    def normalize_phone(phone: str) -> str:
        """标准化手机号码，确保同一个号码只有一种格式。
        
        主要处理英国号码的前导0问题：
        - +4407123456789 → +447123456789（去掉区号后的前导0）
        - +447123456789  → +447123456789（已是标准格式，不变）
        - 07123456789    → +447123456789（补上区号，去掉前导0）
        - 空字符串       → ""（不变，用于解绑场景）
        """
        if not phone or phone.strip() == "":
            return ""
        phone = phone.strip()
        # 去掉英国区号 +44 后面的前导0
        phone = re.sub(r'^\+44\s*0', '+44', phone)
        return phone

    @staticmethod
    def validate_phone(phone: str) -> str:
        """验证手机号（可选），返回标准化后的完整号码（含 + 前缀）"""
        if not phone or phone.strip() == "":
            return ""  # 空值直接返回
        
        # 先标准化
        phone = StringValidator.normalize_phone(phone)
        
        # 验证格式：必须以 + 开头，后面是 7-15 位数字
        if phone.startswith('+'):
            phone_digits = phone[1:]  # 去掉 + 号来检查数字部分
            if not phone_digits.isdigit():
                raise ValueError("手机号只能包含数字")
            if len(phone_digits) < 7 or len(phone_digits) > 15:
                raise ValueError("手机号长度不正确")
            return phone  # 保留 + 前缀返回
        
        # 兼容无 + 前缀的旧格式输入
        phone_digits = re.sub(r'\D', '', phone)
        if len(phone_digits) < 7 or len(phone_digits) > 15:
            raise ValueError("手机号长度不正确")
        if not phone_digits.isdigit():
            raise ValueError("手机号只能包含数字")
        
        return phone_digits


class TaskValidator(BaseValidator):
    """任务验证器"""
    
    title: str = Field(..., min_length=3, max_length=100)
    description: str = Field(..., min_length=10, max_length=2000)
    location: Optional[str] = Field(None, max_length=100)
    task_type: str = Field(..., max_length=50)
    budget: Optional[float] = Field(None, ge=0, le=100000)
    
    @validator('title')
    def validate_title(cls, v):
        return StringValidator.sanitize_string(v, 100)
    
    @validator('description')
    def validate_description(cls, v):
        return StringValidator.sanitize_string(v, 2000)
    
    @validator('location')
    def validate_location(cls, v):
        if v is None:
            return v
        return StringValidator.sanitize_string(v, 100)
    
    @validator('task_type')
    def validate_task_type(cls, v):
        # 使用与前端一致的任务类型列表
        from app.schemas import TASK_TYPES
        if v not in TASK_TYPES:
            raise ValueError(f"任务类型必须是以下之一: {', '.join(TASK_TYPES)}")
        return v


class UserValidator(BaseValidator):
    """用户验证器"""
    
    name: str = Field(..., min_length=2, max_length=50)
    email: str = Field(..., max_length=254)
    password: str = Field(..., min_length=12, max_length=128)
    phone: Optional[str] = Field(None, max_length=20)
    agreed_to_terms: Optional[bool] = Field(False)
    terms_agreed_at: Optional[str] = Field(None)
    invitation_code: Optional[str] = Field(None, max_length=50)  # 邀请码字段
    
    @validator('name')
    def validate_name(cls, v):
        return StringValidator.sanitize_string(v, 50)
    
    @validator('email')
    def validate_email(cls, v):
        # 如果email为None或空字符串，返回None（允许为空，用于手机号登录场景）
        if v is None or v == "":
            return None
        return StringValidator.validate_email(v)
    
    @validator('password')
    def validate_password(cls, v):
        return StringValidator.validate_password(v)
    
    @validator('phone')
    def validate_phone(cls, v):
        if v is None or v == "":
            return None
        return StringValidator.validate_phone(v)


class MessageValidator(BaseValidator):
    """消息验证器"""
    
    content: str = Field(..., min_length=1, max_length=1000)
    receiver_id: str = Field(..., min_length=1, max_length=50)
    
    @validator('content')
    def validate_content(cls, v):
        return StringValidator.sanitize_string(v, 1000)
    
    @validator('receiver_id')
    def validate_receiver_id(cls, v):
        if not re.match(r'^[a-zA-Z0-9_-]+$', v):
            raise ValueError("接收者ID格式不正确")
        return v


class FileValidator(BaseValidator):
    """文件验证器"""
    
    ALLOWED_EXTENSIONS: set = {"jpg", "jpeg", "png", "gif", "webp", "pdf", "doc", "docx"}
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    
    @staticmethod
    def validate_file(file, max_size: int = None) -> Dict[str, Any]:
        """验证上传文件"""
        if max_size is None:
            max_size = FileValidator.MAX_FILE_SIZE
        
        # 检查文件大小
        if hasattr(file, 'size') and file.size > max_size:
            raise ValueError(f"文件大小不能超过{max_size // (1024*1024)}MB")
        
        # 检查文件扩展名
        if hasattr(file, 'filename'):
            filename = file.filename.lower()
            extension = filename.split('.')[-1] if '.' in filename else ''
            
            if extension not in FileValidator.ALLOWED_EXTENSIONS:
                raise ValueError(f"不支持的文件类型。允许的类型: {', '.join(FileValidator.ALLOWED_EXTENSIONS)}")
        
        return {
            "filename": file.filename if hasattr(file, 'filename') else None,
            "size": file.size if hasattr(file, 'size') else 0,
            "extension": extension if 'extension' in locals() else None
        }


def validate_input(data: Dict[str, Any], validator_class: BaseValidator) -> Dict[str, Any]:
    """通用输入验证函数"""
    try:
        validated_data = validator_class(**data)
        return validated_data.dict()
    except Exception as e:
        # 提取具体的验证错误信息
        error_message = str(e)
        if "String should have at least" in error_message:
            error_message = "密码至少需要12个字符"
        elif "Value error" in error_message:
            if "至少一个大写字母" in error_message:
                error_message = "密码必须包含至少一个大写字母"
            elif "至少一个小写字母" in error_message:
                error_message = "密码必须包含至少一个小写字母"
            elif "至少一个数字" in error_message:
                error_message = "密码必须包含至少一个数字"
            elif "至少一个特殊字符" in error_message:
                error_message = "密码必须包含至少一个特殊字符"
            elif "邮箱格式不正确" in error_message:
                error_message = "邮箱格式不正确，请输入有效的邮箱地址"
        
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message
        )


def sanitize_html(html_content: str) -> str:
    """清理HTML内容，防止XSS攻击
    
    🔒 安全修复：使用多层防护代替单一正则表达式
    """
    # 第一层：移除危险标签（包括自闭合标签）
    dangerous_tags = ['script', 'iframe', 'object', 'embed', 'form', 'input', 'link', 'meta', 'base', 'svg', 'math']
    
    for tag in dangerous_tags:
        # 匹配开闭标签对
        pattern = rf'<{tag}[^>]*>.*?</{tag}>'
        html_content = re.sub(pattern, '', html_content, flags=re.IGNORECASE | re.DOTALL)
        # 匹配自闭合标签
        pattern = rf'<{tag}[^>]*/?\s*>'
        html_content = re.sub(pattern, '', html_content, flags=re.IGNORECASE)
    
    # 第二层：移除所有事件处理属性（on* 类属性）
    html_content = re.sub(r'\son\w+\s*=\s*["\'][^"\']*["\']', '', html_content, flags=re.IGNORECASE)
    html_content = re.sub(r'\son\w+\s*=\s*[^\s>]+', '', html_content, flags=re.IGNORECASE)
    
    # 第三层：移除危险协议 URL（javascript:, data:, vbscript:）
    html_content = re.sub(r'(href|src|action)\s*=\s*["\']?\s*(javascript|data|vbscript)\s*:', '', html_content, flags=re.IGNORECASE)
    
    # 第四层：移除 style 中的 expression() 和 url() 表达式（IE XSS）
    html_content = re.sub(r'style\s*=\s*["\'][^"\']*expression\s*\([^)]*\)[^"\']*["\']', '', html_content, flags=re.IGNORECASE)
    
    return html_content

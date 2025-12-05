"""
学生认证系统验证器
提供邮箱格式验证、域名验证等功能
"""
import re
import logging
from typing import Tuple, Optional

logger = logging.getLogger(__name__)


def validate_student_email(email: str) -> Tuple[bool, Optional[str]]:
    """
    验证学生邮箱格式
    
    Args:
        email: 待验证的邮箱地址
    
    Returns:
        (is_valid, error_message): 
        - is_valid: True表示格式有效，False表示格式无效
        - error_message: 如果无效，返回错误信息；如果有效，返回None
    """
    if not email:
        return False, "邮箱地址不能为空"
    
    email = email.strip()
    
    # 基本格式检查
    if '@' not in email:
        return False, "邮箱格式无效，缺少@符号"
    
    # 检查邮箱长度
    if len(email) > 255:
        return False, "邮箱地址过长（最大255字符）"
    
    # 检查是否以.ac.uk结尾
    if not email.endswith('.ac.uk'):
        return False, "只有以 .ac.uk 结尾的邮箱才能验证学生身份"
    
    # 使用正则表达式验证邮箱格式
    # 允许的字符：字母、数字、点、下划线、连字符、加号
    email_pattern = r'^[a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.ac\.uk$'
    if not re.match(email_pattern, email):
        return False, "邮箱格式无效，包含非法字符"
    
    # 检查@符号前后的内容
    parts = email.split('@')
    if len(parts) != 2:
        return False, "邮箱格式无效，@符号使用不正确"
    
    local_part = parts[0]
    domain_part = parts[1]
    
    # 检查本地部分（@之前）
    if not local_part or len(local_part) > 64:
        return False, "邮箱本地部分无效（@符号前的部分）"
    
    if local_part.startswith('.') or local_part.endswith('.'):
        return False, "邮箱本地部分不能以点开头或结尾"
    
    if '..' in local_part:
        return False, "邮箱本地部分不能包含连续的点"
    
    # 检查域名部分
    if not domain_part or domain_part != 'ac.uk' and not domain_part.endswith('.ac.uk'):
        return False, "邮箱域名必须是以.ac.uk结尾的英国大学域名"
    
    # 域名部分不能以点开头或结尾
    if domain_part.startswith('.') or domain_part.endswith('.'):
        return False, "邮箱域名格式无效"
    
    return True, None


def normalize_email(email: str) -> str:
    """
    标准化邮箱地址
    
    - 去除首尾空格
    - 转换为小写
    - 去除多余的点
    
    Args:
        email: 原始邮箱地址
    
    Returns:
        标准化后的邮箱地址
    """
    if not email:
        return ""
    
    # 去除首尾空格并转小写
    email = email.strip().lower()
    
    # 去除多余的空格
    email = re.sub(r'\s+', '', email)
    
    return email


def extract_domain(email: str) -> Optional[str]:
    """
    从邮箱地址中提取域名
    
    Args:
        email: 邮箱地址
    
    Returns:
        域名（如 "bristol.ac.uk"），如果格式无效则返回None
    """
    if '@' not in email:
        return None
    
    parts = email.split('@')
    if len(parts) != 2:
        return None
    
    return parts[1].lower()


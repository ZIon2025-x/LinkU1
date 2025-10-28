"""
密码验证模块
实施强密码策略、密码强度检查和常见弱密码检测
"""

import re
import hashlib
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass

@dataclass
class PasswordValidationResult:
    """密码验证结果"""
    is_valid: bool
    score: int  # 0-100
    errors: List[str]
    suggestions: List[str]
    strength: str  # weak, medium, strong, very_strong

class PasswordValidator:
    """密码验证器"""
    
    def __init__(self):
        # 常见弱密码列表
        self.common_passwords = self._load_common_passwords()
        
        # 密码策略配置
        self.min_length = 12
        self.require_uppercase = True
        self.require_lowercase = True
        self.require_digits = True
        self.require_special_chars = True
        self.max_length = 128
        
        # 特殊字符集
        self.special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    def _load_common_passwords(self) -> set:
        """加载常见弱密码列表"""
        # 这里可以加载外部弱密码字典
        # 为了演示，使用一些常见的弱密码
        return {
            "password", "123456", "123456789", "qwerty", "abc123",
            "password123", "admin", "root", "user", "test",
            "12345678", "1234567890", "letmein", "welcome",
            "monkey", "dragon", "master", "hello", "login",
            "princess", "qwertyuiop", "solo", "passw0rd",
            "starwars", "freedom", "whatever", "trustno1",
            "jordan", "harley", "ranger", "hunter", "buster",
            "soccer", "hockey", "killer", "george", "sexy",
            "andrew", "charlie", "superman", "asshole", "fuckyou",
            "dallas", "jessica", "panties", "mike", "mustang",
            "shadow", "merlin", "diamond", "1234", "12345",
            "1234567", "123456789", "1234567890", "qwerty",
            "abc123", "password", "password123", "admin",
            "root", "user", "test", "guest", "demo"
        }
    
    def validate_password(self, password: str, username: str = None, email: str = None) -> PasswordValidationResult:
        """验证密码强度"""
        errors = []
        suggestions = []
        score = 0
        
        # 基本长度检查
        if len(password) < self.min_length:
            errors.append(f"密码长度至少需要{self.min_length}个字符")
            score -= 20
        elif len(password) >= 16:
            score += 10
        
        if len(password) > self.max_length:
            errors.append(f"密码长度不能超过{self.max_length}个字符")
            score -= 10
        
        # 字符类型检查
        has_upper = bool(re.search(r'[A-Z]', password))
        has_lower = bool(re.search(r'[a-z]', password))
        has_digit = bool(re.search(r'\d', password))
        has_special = bool(re.search(f'[{re.escape(self.special_chars)}]', password))
        
        if self.require_uppercase and not has_upper:
            errors.append("密码必须包含至少一个大写字母")
            score -= 15
        
        if self.require_lowercase and not has_lower:
            errors.append("密码必须包含至少一个小写字母")
            score -= 15
        
        if self.require_digits and not has_digit:
            errors.append("密码必须包含至少一个数字")
            score -= 15
        
        if self.require_special_chars and not has_special:
            errors.append("密码必须包含至少一个特殊字符")
            score -= 15
        
        # 字符类型奖励
        char_types = sum([has_upper, has_lower, has_digit, has_special])
        score += char_types * 5
        
        # 常见密码检查
        if password.lower() in self.common_passwords:
            errors.append("密码过于常见，请选择更复杂的密码")
            score -= 30
        
        # 用户名/邮箱相关检查
        if username and password.lower().find(username.lower()) != -1:
            errors.append("密码不能包含用户名")
            score -= 20
        
        if email:
            email_prefix = email.split('@')[0]
            if password.lower().find(email_prefix.lower()) != -1:
                errors.append("密码不能包含邮箱前缀")
                score -= 20
        
        # 重复字符检查（放宽限制）
        if self._has_repeating_chars(password):
            suggestions.append("避免使用重复的字符序列")
            score -= 5
        
        # 计算最终分数
        score = max(0, min(100, score))
        
        # 生成建议（已禁用，因为有自动检测会显示具体错误）
        # if score < 50:
        #     suggestions.extend([
        #         "使用至少12个字符的密码",
        #         "包含大小写字母、数字和特殊字符",
        #         "避免使用个人信息",
        #         "避免使用常见单词"
        #     ])
        # elif score < 80:
        #     suggestions.extend([
        #         "考虑使用更长的密码",
        #         "添加更多特殊字符"
        #     ])
        
        # 确定强度等级
        if score < 30:
            strength = "weak"
        elif score < 60:
            strength = "medium"
        elif score < 80:
            strength = "strong"
        else:
            strength = "very_strong"
        
        return PasswordValidationResult(
            is_valid=len(errors) == 0,
            score=score,
            errors=errors,
            suggestions=suggestions,
            strength=strength
        )
    
    def _has_repeating_chars(self, password: str) -> bool:
        """检查是否有重复字符序列"""
        for i in range(len(password) - 2):
            if password[i] == password[i+1] == password[i+2]:
                return True
        return False
    
    def _has_sequential_chars(self, password: str) -> bool:
        """检查是否有连续字符序列"""
        for i in range(len(password) - 2):
            if (ord(password[i+1]) == ord(password[i]) + 1 and 
                ord(password[i+2]) == ord(password[i]) + 2):
                return True
        return False
    
    def _has_keyboard_pattern(self, password: str) -> bool:
        """检查是否有键盘模式"""
        keyboard_rows = [
            "qwertyuiop",
            "asdfghjkl",
            "zxcvbnm",
            "1234567890"
        ]
        
        password_lower = password.lower()
        for row in keyboard_rows:
            for i in range(len(row) - 2):
                pattern = row[i:i+3]
                if pattern in password_lower:
                    return True
        return False
    
    def get_password_requirements(self) -> Dict[str, any]:
        """获取密码要求"""
        return {
            "min_length": self.min_length,
            "max_length": self.max_length,
            "require_uppercase": self.require_uppercase,
            "require_lowercase": self.require_lowercase,
            "require_digits": self.require_digits,
            "require_special_chars": self.require_special_chars,
            "special_chars": self.special_chars
        }

# 全局密码验证器实例
password_validator = PasswordValidator()

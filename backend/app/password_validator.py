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
    strength: str  # weak, medium, strong
    bars: int = 1  # 密码强度横线数：1=弱，2=中，3=强
    missing_requirements: List[str] = None  # 缺少的要求（带例子）

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
        
        # 特殊字符集（包含常见的中文和英文特殊字符）
        self.special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?~`\"'\\/￥£€¥"
    
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
        # 检查特殊字符（包括中文字符）
        # 先检查英文特殊字符（转义特殊字符）
        has_special_en = bool(re.search(f'[{re.escape(self.special_chars)}]', password))
        # 检查常见的中文货币符号和其他Unicode标点符号
        # 使用简单的非字母数字空格检查（排除中文字符范围）
        has_special_unicode = bool(re.search(r'[^\w\s\u4e00-\u9fff]', password))
        has_special = has_special_en or has_special_unicode
        
        # 收集缺少的要求（用于实时提示）
        missing_requirements = []
        
        if self.require_uppercase and not has_upper:
            errors.append("密码必须包含至少一个大写字母")
            missing_requirements.append("大写字母 (例如: A, B, C)")
            score -= 15
        
        if self.require_lowercase and not has_lower:
            errors.append("密码必须包含至少一个小写字母")
            missing_requirements.append("小写字母 (例如: a, b, c)")
            score -= 15
        
        if self.require_digits and not has_digit:
            errors.append("密码必须包含至少一个数字")
            missing_requirements.append("数字 (例如: 0, 1, 2, 3)")
            score -= 15
        
        if self.require_special_chars and not has_special:
            # 显示特殊字符例子
            special_examples = "!@#$%^&*()_+-=[]{}|;:,.<>?"
            errors.append("密码必须包含至少一个特殊字符")
            missing_requirements.append(f"特殊字符 (例如: {special_examples[:15]}...)")
            score -= 15
        
        # 长度检查（如果长度不够，也添加到缺少的要求中）
        if len(password) < self.min_length:
            missing_requirements.append(f"至少{self.min_length}个字符")
        
        # 字符类型奖励
        char_types = sum([has_upper, has_lower, has_digit, has_special])
        score += char_types * 5
        
        # 注意：已移除常见密码检查、用户名/邮箱前缀检查和重复字符检查
        # 只保留基本要求：长度、大小写字母、数字、特殊字符
        
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
        
        # 确定强度等级（基于新的三条横线规则）
        # 一条横线：弱（只有数字）
        # 两条横线：中（有数字和字母，或者有数字和字符）
        # 三条横线：强（有大小写字母、数字和特殊字符）
        
        # 使用前面已经检查的字符类型
        has_letter = has_upper or has_lower  # 有字母（大小写都可以）
        
        # 根据新的规则判断强度（不考虑密码长度，只根据字符类型）
        # 三条横线：强（有大小写字母、数字和特殊字符）
        if has_upper and has_lower and has_digit and has_special:
            strength = "strong"
            bars = 3
        # 两条横线：中（有数字和字母，或者有数字和特殊字符）
        elif (has_digit and has_letter) or (has_digit and has_special):
            strength = "medium"
            bars = 2
        # 一条横线：弱（只有数字）
        elif has_digit and not has_letter and not has_special:
            strength = "weak"
            bars = 1
        # 其他情况（只有字母、只有特殊字符、空等）归为弱
        else:
            strength = "weak"
            bars = 1
        
        return PasswordValidationResult(
            is_valid=len(errors) == 0,
            score=score,
            errors=errors,
            suggestions=suggestions,
            strength=strength,
            bars=bars,
            missing_requirements=missing_requirements if missing_requirements else []
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

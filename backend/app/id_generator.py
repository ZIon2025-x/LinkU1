"""
ID格式转换模块
- 客服ID: CS + 4位随机数字 (如: CS1234)
- 用户ID: 8位随机数字 (如: 12345678)
- 后台管理ID: A + 4位随机数字 (如: A1234)

注意：数据库仍使用自增ID，这里提供格式转换功能
"""

import random
from typing import Union


def format_customer_service_id(db_id: int) -> str:
    """将数据库ID转换为客服ID格式: CS + 4位数字"""
    # 使用数据库ID生成固定的4位数字
    # 确保每个ID都有唯一的格式
    formatted_id = f"{db_id:04d}"  # 补零到4位
    return f"CS{formatted_id}"


def format_user_id(db_id: int) -> str:
    """将数据库ID转换为用户ID格式: 8位数字"""
    # 使用数据库ID生成8位数字
    # 为了确保唯一性，使用ID + 随机数
    base_id = f"{db_id:06d}"  # 补零到6位
    random_suffix = f"{random.randint(10, 99)}"  # 2位随机数
    return f"{base_id}{random_suffix}"


def format_admin_id(db_id: int) -> str:
    """将数据库ID转换为后台管理ID格式: A + 4位数字"""
    formatted_id = f"{db_id:04d}"  # 补零到4位
    return f"A{formatted_id}"


def parse_customer_service_id(formatted_id: str) -> int:
    """将客服ID格式转换为数据库ID"""
    if formatted_id.startswith("CS"):
        return int(formatted_id[2:])
    return int(formatted_id)


def parse_user_id(formatted_id: str) -> int:
    """将用户ID格式转换为数据库ID"""
    if len(formatted_id) == 8 and formatted_id.isdigit():
        # 取前6位作为数据库ID
        return int(formatted_id[:6])
    return int(formatted_id)


def parse_admin_id(formatted_id: str) -> int:
    """将后台管理ID格式转换为数据库ID"""
    if formatted_id.startswith("A"):
        return int(formatted_id[1:])
    return int(formatted_id)


def get_id_type(user_id: Union[str, int]) -> str:
    """根据ID格式判断用户类型"""
    if isinstance(user_id, int):
        # 如果是数字，需要根据上下文判断
        return "unknown"

    if user_id.startswith("CS"):
        return "customer_service"
    elif user_id.startswith("A"):
        return "admin"
    elif user_id.isdigit() and len(user_id) == 8:
        return "user"
    else:
        return "unknown"


def is_customer_service_id(user_id: Union[str, int]) -> bool:
    """判断是否为客服ID"""
    if isinstance(user_id, int):
        return False
    return user_id.startswith("CS")


def is_admin_id(user_id: Union[str, int]) -> bool:
    """判断是否为后台管理ID"""
    if isinstance(user_id, int):
        return False
    return user_id.startswith("A")


def is_user_id(user_id: Union[str, int]) -> bool:
    """判断是否为用户ID"""
    if isinstance(user_id, int):
        return True  # 数字ID默认为用户ID
    return user_id.isdigit() and len(user_id) == 8


def format_flea_market_id(db_id: int) -> str:
    """将数据库ID转换为跳蚤市场ID格式: S + 数字"""
    formatted_id = f"{db_id:04d}"  # 补零到4位
    return f"S{formatted_id}"


def parse_flea_market_id(formatted_id: str) -> int:
    """将跳蚤市场ID格式转换为数据库ID"""
    if formatted_id.startswith("S"):
        return int(formatted_id[1:])
    return int(formatted_id)
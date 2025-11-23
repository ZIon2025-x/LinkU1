"""
任务ID格式化工具函数
用于处理任务ID的前缀格式（O+数字、E+数字、纯数字）
"""


def parse_task_id(task_id: str | int) -> int:
    """
    解析任务ID，支持格式化ID（O1234、E1234）或纯数字ID（1234）
    
    Args:
        task_id: 任务ID，可以是格式化ID（O1234、E1234）或纯数字ID（1234）
    
    Returns:
        int: 数据库中的数字ID
    
    Examples:
        >>> parse_task_id("O1234")
        1234
        >>> parse_task_id("E5678")
        5678
        >>> parse_task_id(1234)
        1234
        >>> parse_task_id("1234")
        1234
    """
    if isinstance(task_id, int):
        return task_id
    
    if isinstance(task_id, str):
        # 移除前缀（O或E）并提取数字部分
        task_id_clean = task_id.lstrip("OE")
        try:
            return int(task_id_clean)
        except ValueError:
            raise ValueError(f"Invalid task_id format: {task_id}")
    
    raise TypeError(f"task_id must be str or int, got {type(task_id)}")


def format_task_id(db_id: int, is_official: bool = False, is_expert: bool = False) -> str:
    """
    格式化任务ID为带前缀的字符串ID
    
    Args:
        db_id: 数据库中的数字ID
        is_official: 是否为官方任务
        is_expert: 是否为任务达人任务
    
    Returns:
        str: 格式化后的任务ID（O1234、E1234 或 1234）
    
    Examples:
        >>> format_task_id(1234, is_official=True)
        'O1234'
        >>> format_task_id(5678, is_expert=True)
        'E5678'
        >>> format_task_id(9999)
        '9999'
    """
    if is_official:
        return f"O{db_id}"
    elif is_expert:
        return f"E{db_id}"
    else:
        return str(db_id)


def is_multi_participant_task_id(task_id: str | int) -> bool:
    """
    判断任务ID是否为多人任务（通过前缀判断）
    
    Args:
        task_id: 任务ID
    
    Returns:
        bool: 如果是O或E开头，返回True；否则返回False
    """
    if isinstance(task_id, int):
        return False
    
    if isinstance(task_id, str):
        return task_id.startswith("O") or task_id.startswith("E")
    
    return False


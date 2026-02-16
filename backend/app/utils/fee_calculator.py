"""
平台服务费计算工具
统一处理服务费计算逻辑
"""
from decimal import Decimal, ROUND_HALF_UP


def calculate_application_fee_decimal(task_amount: Decimal) -> Decimal:
    """
    计算平台服务费（使用Decimal精确计算，避免浮点精度损失）
    
    规则：
    - 如果任务金额 < 10镑，固定收取1镑
    - 如果任务金额 >= 10镑，按10%费率计算
    
    Args:
        task_amount: 任务金额（英镑，Decimal类型）
    
    Returns:
        平台服务费（英镑，Decimal类型，保留2位小数）
    """
    ten = Decimal('10')
    if task_amount < ten:
        return Decimal('1.00')
    else:
        fee = task_amount * Decimal('0.10')
        return fee.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def calculate_application_fee(task_amount: float) -> float:
    """
    计算平台服务费
    
    规则：
    - 如果任务金额 < 10镑，固定收取1镑
    - 如果任务金额 >= 10镑，按10%费率计算
    
    Args:
        task_amount: 任务金额（英镑）
    
    Returns:
        平台服务费（英镑），保留2位小数
    """
    if task_amount < 10.0:
        return 1.0  # 小于10镑，固定收取1镑
    else:
        # 大于等于10镑，按10%计算，保留2位小数
        return round(task_amount * 0.10, 2)


def calculate_application_fee_pence(task_amount_pence: int) -> int:
    """
    计算平台服务费（便士）
    
    规则：
    - 如果任务金额 < 1000便士（10镑），固定收取100便士（1镑）
    - 如果任务金额 >= 1000便士（10镑），按10%费率计算
    
    Args:
        task_amount_pence: 任务金额（便士）
    
    Returns:
        平台服务费（便士）
    """
    if task_amount_pence < 1000:  # 小于10镑（1000便士）
        return 100  # 固定收取1镑（100便士）
    else:
        return task_amount_pence // 10  # 大于等于10镑，按10%计算（整数除法避免浮点精度问题）


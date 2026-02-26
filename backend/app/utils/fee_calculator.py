"""
平台服务费计算工具
统一处理服务费计算逻辑，支持按任务来源(task_source)和任务类型(task_type)使用不同费率。

规则：服务费 = 任务金额 × 费率，且不低于最低服务费（便士）。例如最低 50 便士表示
按比例算出来若小于 50 便士则按 50 便士收取。服务费不超过任务金额。
"""
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional, Tuple

# 费率配置：task_source -> (费率 0-1, 最低服务费 便士)
# 服务费 = max(最低服务费, round(金额×费率))，且不超过任务金额
FEE_CONFIG_BY_SOURCE = {
    "normal": (0.10, 100),           # 10%，最低 1 镑
    "user_profile": (0.08, 50),      # 指定用户任务 8%，最低 50 便士
    "expert_service": (0.08, 50),   # 达人服务 8%，最低 50 便士
    "expert_activity": (0.05, 50),  # 达人活动 5%，最低 50 便士
    "flea_market": (0.08, 50),       # 跳蚤市场 8%，最低 50 便士
}
DEFAULT_RATE, DEFAULT_MIN_PENCE = FEE_CONFIG_BY_SOURCE["normal"]

# 可选：按 task_type 覆盖 (费率, 最低服务费便士)
FEE_OVERRIDE_BY_TASK_TYPE: dict[str, tuple[float, int]] = {
    # 示例: "Second-hand & Rental": (0.05, 50),
}


def _get_fee_config(
    task_source: Optional[str] = None,
    task_type: Optional[str] = None,
) -> tuple[float, int]:
    """解析 (费率, 最低服务费便士)。优先 task_type 覆盖，否则按 task_source，最后默认。"""
    if task_type and task_type in FEE_OVERRIDE_BY_TASK_TYPE:
        return FEE_OVERRIDE_BY_TASK_TYPE[task_type]
    if task_source and task_source in FEE_CONFIG_BY_SOURCE:
        return FEE_CONFIG_BY_SOURCE[task_source]
    return (DEFAULT_RATE, DEFAULT_MIN_PENCE)


def calculate_application_fee_pence(
    task_amount_pence: int,
    task_source: Optional[str] = None,
    task_type: Optional[str] = None,
) -> int:
    """
    计算平台服务费（便士）

    规则：服务费 = max(最低服务费, round(任务金额×费率))，且不超过任务金额。
    例如最低 50 便士：按比例算得 30 便士则收 50 便士，算得 80 便士则收 80 便士。

    支持按任务来源和任务类型使用不同 (费率, 最低服务费)：
    - normal: 10%，最低 100 便士
    - user_profile: 8%，最低 50 便士
    - expert_service: 8%，最低 50 便士
    - expert_activity: 5%，最低 50 便士
    - flea_market: 10%，最低 100 便士

    Args:
        task_amount_pence: 任务金额（便士）
        task_source: 任务来源
        task_type: 任务类型（可选）

    Returns:
        平台服务费（便士），不超过 task_amount_pence
    """
    if task_amount_pence <= 0:
        return 0
    rate, min_fee_pence = _get_fee_config(task_source, task_type)
    fee_by_rate = int(round(task_amount_pence * rate))
    fee = max(min_fee_pence, fee_by_rate)
    return min(fee, task_amount_pence)


def get_platform_fee_display(
    task_amount: float,
    task_source: Optional[str] = None,
    task_type: Optional[str] = None,
) -> Tuple[Optional[float], Optional[float]]:
    """
    返回用于展示的 (服务费比例, 服务费金额英镑)。
    task_amount <= 0 时返回 (None, None)。
    """
    if task_amount is None or task_amount <= 0:
        return (None, None)
    rate, _ = _get_fee_config(task_source, task_type)
    fee_gbp = calculate_application_fee(task_amount, task_source, task_type)
    return (rate, round(fee_gbp, 2))


def calculate_application_fee(
    task_amount: float,
    task_source: Optional[str] = None,
    task_type: Optional[str] = None,
) -> float:
    """
    计算平台服务费（英镑），规则同 calculate_application_fee_pence。
    """
    pence = int(round(task_amount * 100))
    fee_pence = calculate_application_fee_pence(pence, task_source, task_type)
    return round(fee_pence / 100.0, 2)


def calculate_application_fee_decimal(
    task_amount: Decimal,
    task_source: Optional[str] = None,
    task_type: Optional[str] = None,
) -> Decimal:
    """
    计算平台服务费（Decimal），规则同 calculate_application_fee_pence。
    """
    if task_amount <= 0:
        return Decimal("0")
    rate, min_fee_pence = _get_fee_config(task_source, task_type)
    fee_by_rate = (task_amount * Decimal(str(rate))).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )
    min_fee_gbp = Decimal(min_fee_pence) / Decimal(100)
    fee = max(min_fee_gbp, fee_by_rate)
    return min(fee, task_amount).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

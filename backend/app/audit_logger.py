"""
审计日志模块
记录管理员和关键业务操作的审计日志，用于安全审计和问题追溯
"""

import logging
from typing import Any, Dict, Optional

from fastapi import Request

logger = logging.getLogger("app.audit")


def log_admin_action(
    action: str,
    admin_id: str,
    request: Optional[Request] = None,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    details: Optional[Dict[str, Any]] = None,
    level: str = "info",
):
    """
    记录管理员操作审计日志

    Args:
        action: 操作名称，如 "approve_refund", "ban_user", "update_system_settings"
        admin_id: 管理员ID
        request: FastAPI Request 对象（用于提取IP等信息）
        target_type: 操作对象类型，如 "user", "task", "refund_request"
        target_id: 操作对象ID
        details: 附加详情字典
        level: 日志级别 (info, warning, error)
    """
    client_ip = "-"
    user_agent = "-"
    request_id = "-"

    if request:
        # 提取 IP
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            client_ip = forwarded.split(",")[0].strip()
        else:
            real_ip = request.headers.get("x-real-ip")
            client_ip = real_ip if real_ip else (request.client.host if request.client else "-")

        user_agent = request.headers.get("user-agent", "-")[:100]
        request_id = getattr(request.state, "request_id", "-") if hasattr(request, "state") else "-"

    log_msg = (
        f"[AUDIT] action={action} | admin_id={admin_id} | "
        f"target={target_type}:{target_id} | "
        f"IP={client_ip} | request_id={request_id}"
    )

    if details:
        # 限制详情长度防止日志过大
        details_str = str(details)[:500]
        log_msg += f" | details={details_str}"

    log_func = getattr(logger, level, logger.info)
    log_func(log_msg)


def log_payment_action(
    action: str,
    user_id: str,
    amount: Optional[float] = None,
    currency: str = "GBP",
    task_id: Optional[int] = None,
    request: Optional[Request] = None,
    details: Optional[Dict[str, Any]] = None,
    level: str = "info",
):
    """
    记录支付相关操作审计日志

    Args:
        action: 操作名称，如 "create_payment", "refund", "transfer"
        user_id: 操作用户ID
        amount: 金额
        currency: 币种
        task_id: 相关任务ID
        request: FastAPI Request 对象
        details: 附加详情字典
        level: 日志级别
    """
    request_id = "-"
    client_ip = "-"

    if request:
        forwarded = request.headers.get("x-forwarded-for")
        client_ip = (
            forwarded.split(",")[0].strip()
            if forwarded
            else (request.client.host if request.client else "-")
        )
        request_id = getattr(request.state, "request_id", "-") if hasattr(request, "state") else "-"

    log_msg = (
        f"[PAYMENT_AUDIT] action={action} | user_id={user_id} | "
        f"amount={amount} {currency} | task_id={task_id} | "
        f"IP={client_ip} | request_id={request_id}"
    )

    if details:
        details_str = str(details)[:500]
        log_msg += f" | details={details_str}"

    log_func = getattr(logger, level, logger.info)
    log_func(log_msg)


def log_critical_operation(
    operation: str,
    user_id: str,
    request: Optional[Request] = None,
    details: Optional[Dict[str, Any]] = None,
):
    """
    记录关键业务操作（如账户删除、权限变更等）
    始终使用 WARNING 级别以确保被记录

    Args:
        operation: 操作名称
        user_id: 操作用户ID
        request: FastAPI Request 对象
        details: 附加详情字典
    """
    log_admin_action(
        action=operation,
        admin_id=user_id,
        request=request,
        details=details,
        level="warning",
    )

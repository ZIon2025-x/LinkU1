"""
Stripe 相关工具函数
提供收款账户校验等通用功能
"""

import os
import logging
from typing import Optional
from fastapi import HTTPException

from app.error_handlers import raise_http_error_with_code

logger = logging.getLogger(__name__)


def validate_user_stripe_account_for_receiving(
    user,
    action_description: str = "此操作"
) -> None:
    """
    校验用户是否有可用的收款账户（用于申请任务、发布商品等需要接收付款的场景）
    
    Args:
        user: 当前用户对象，需要有 id 和 stripe_account_id 属性
        action_description: 操作描述，用于错误提示，如 "申请任务"、"发布商品"
    
    Raises:
        HTTPException: 428 - 如果用户没有收款账户或账户未完成设置
    """
    import stripe
    
    # 检查是否有 stripe_account_id
    if not user.stripe_account_id:
        logger.warning(f"用户 {user.id} 尝试{action_description}，但没有收款账户")
        raise_http_error_with_code(
            message=f"{action_description}前需要先注册收款账户。请先完成收款账户设置。",
            status_code=428,
            error_code="STRIPE_SETUP_REQUIRED"
        )
    
    # 验证收款账户是否有效且已完成设置
    try:
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        account = stripe.Account.retrieve(user.stripe_account_id)
        
        # 检查账户是否已完成设置
        if not account.details_submitted:
            logger.warning(f"用户 {user.id} 的收款账户 {user.stripe_account_id} 未完成设置")
            raise_http_error_with_code(
                message="您的收款账户尚未完成设置。请先完成收款账户设置。",
                status_code=428,
                error_code="STRIPE_SETUP_REQUIRED"
            )
            
        # 可选：检查账户是否启用了收款功能
        if not account.charges_enabled:
            logger.warning(f"用户 {user.id} 的收款账户 {user.stripe_account_id} 未启用收款功能")
            raise_http_error_with_code(
                message="您的收款账户尚未启用收款功能。请完成账户验证。",
                status_code=428,
                error_code="STRIPE_ACCOUNT_NOT_VERIFIED"
            )
            
    except HTTPException:
        raise
    except stripe.error.InvalidRequestError as e:
        # 账户不存在或无效
        logger.error(f"用户 {user.id} 的收款账户 {user.stripe_account_id} 无效: {e}")
        raise_http_error_with_code(
            message="收款账户无效。请重新设置收款账户。",
            status_code=428,
            error_code="STRIPE_ACCOUNT_INVALID"
        )
    except stripe.error.StripeError as e:
        logger.error(f"验证用户 {user.id} 的收款账户失败: {e}")
        raise_http_error_with_code(
            message="收款账户验证失败。请检查网络后重试，或重新设置收款账户。",
            status_code=428,
            error_code="STRIPE_VERIFICATION_FAILED"
        )
    except Exception as e:
        logger.error(f"验证收款账户时发生未知错误: {e}")
        raise_http_error_with_code(
            message="收款账户验证失败。请稍后重试。",
            status_code=428,
            error_code="STRIPE_VERIFICATION_FAILED"
        )


def get_user_stripe_account_status(user) -> dict:
    """
    获取用户的 Stripe 账户状态摘要
    
    Returns:
        dict: 包含账户状态的字典
    """
    import stripe
    
    if not user.stripe_account_id:
        return {
            "has_account": False,
            "account_id": None,
            "details_submitted": False,
            "charges_enabled": False,
            "payouts_enabled": False,
            "needs_setup": True
        }
    
    try:
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        account = stripe.Account.retrieve(user.stripe_account_id)
        
        return {
            "has_account": True,
            "account_id": user.stripe_account_id,
            "details_submitted": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "payouts_enabled": account.payouts_enabled,
            "needs_setup": not account.details_submitted
        }
    except stripe.error.StripeError as e:
        logger.warning(f"获取用户 {user.id} 的 Stripe 账户状态失败: {e}")
        return {
            "has_account": True,
            "account_id": user.stripe_account_id,
            "details_submitted": False,
            "charges_enabled": False,
            "payouts_enabled": False,
            "needs_setup": True,
            "error": str(e)
        }

"""
Stripe 相关工具函数
提供收款账户校验等通用功能
"""

import os
import logging
from typing import Optional, Tuple
from fastapi import HTTPException

from app.error_handlers import raise_http_error_with_code

logger = logging.getLogger(__name__)


def _check_account_status_v2(account_id: str) -> Tuple[bool, bool]:
    """
    使用 V2 API 检查账户状态
    
    Returns:
        Tuple[details_submitted, charges_enabled]
    """
    import stripe
    
    # 导入 stripe_connect_routes 中定义的 V2 API 工具
    from app.stripe_connect_routes import stripe_v2
    
    try:
        account = stripe_v2.core.accounts.retrieve(
            account_id,
            include=["requirements", "configuration.recipient"]
        )
        
        # 从 V2 API 响应中提取状态
        requirements = account.get("requirements", {})
        summary = requirements.get("summary", {})
        minimum_deadline = summary.get("minimum_deadline", {})
        
        # 如果没有 minimum_deadline（即没有待完成的必填项），认为 details_submitted
        details_submitted = minimum_deadline is None or len(minimum_deadline) == 0
        
        # 检查 charges_enabled (recipient 配置中的 stripe_transfers)
        configuration = account.get("configuration", {})
        recipient_config = configuration.get("recipient") or {}
        recipient_capabilities = recipient_config.get("capabilities", {})
        stripe_balance = recipient_capabilities.get("stripe_balance", {})
        stripe_transfers = stripe_balance.get("stripe_transfers", {})
        charges_enabled = stripe_transfers.get("status") == "active"
        
        # 如果 recipient 没有，检查 merchant (card_payments)
        if not charges_enabled:
            merchant_config = configuration.get("merchant") or {}
            merchant_capabilities = merchant_config.get("capabilities", {})
            card_payments = merchant_capabilities.get("card_payments", {})
            charges_enabled = card_payments.get("status") == "active"
        
        logger.debug(f"V2 API 账户状态: {account_id}, details_submitted={details_submitted}, charges_enabled={charges_enabled}")
        return (details_submitted, charges_enabled)
        
    except stripe.error.StripeError as e:
        error_msg = str(e)
        # 如果是 V1 账户，回退到 V1 API
        if "v1_account_instead_of_v2_account" in error_msg or "V1 Accounts cannot be used" in error_msg:
            logger.debug(f"账户 {account_id} 是 V1 账户，使用 V1 API")
            account = stripe.Account.retrieve(account_id)
            return (account.details_submitted, account.charges_enabled)
        raise


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
        
        # 优先使用 V2 API（支持 V2 账户），回退到 V1 API
        try:
            details_submitted, charges_enabled = _check_account_status_v2(user.stripe_account_id)
        except Exception as v2_err:
            logger.warning(f"V2 API 检查失败，回退到 V1 API: {v2_err}")
            account = stripe.Account.retrieve(user.stripe_account_id)
            details_submitted = account.details_submitted
            charges_enabled = account.charges_enabled
        
        # 检查账户是否已完成设置
        if not details_submitted:
            logger.warning(f"用户 {user.id} 的收款账户 {user.stripe_account_id} 未完成设置")
            raise_http_error_with_code(
                message="您的收款账户尚未完成设置。请先完成收款账户设置。",
                status_code=428,
                error_code="STRIPE_SETUP_REQUIRED"
            )
            
        # 可选：检查账户是否启用了收款功能
        if not charges_enabled:
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


def get_or_create_stripe_customer(user, db=None) -> str:
    """
    获取或创建 Stripe Customer（用于支付），优先使用数据库缓存的 stripe_customer_id。
    
    解决以下问题：
    1. Stripe Search API 有索引延迟（eventual consistency），导致短时间内重复创建 Customer
    2. 多处代码重复实现相同逻辑
    
    Args:
        user: User 模型对象，需要有 id, name, stripe_customer_id 属性
        db: 数据库 Session（可选，传入则会将 customer_id 保存到用户记录）
    
    Returns:
        str: Stripe Customer ID
    
    Raises:
        Exception: 如果无法创建 Customer
    """
    import stripe
    
    # 1. 优先使用数据库中缓存的 customer_id
    if hasattr(user, 'stripe_customer_id') and user.stripe_customer_id:
        logger.debug(f"使用数据库缓存的 Stripe Customer: user={user.id}, customer={user.stripe_customer_id}")
        return user.stripe_customer_id
    
    # 2. 搜索 Stripe 中是否已有该用户的 Customer（兼容旧数据）
    customer_id = None
    try:
        search_result = stripe.Customer.search(
            query=f"metadata['user_id']:'{user.id}'",
            limit=1
        )
        if search_result.data:
            customer_id = search_result.data[0].id
            logger.info(f"从 Stripe 找到已有 Customer: user={user.id}, customer={customer_id}")
    except Exception as e:
        logger.debug(f"Stripe Customer Search 失败，将创建新 Customer: {e}")
    
    # 3. 未找到则创建新的
    if not customer_id:
        customer = stripe.Customer.create(
            metadata={
                "user_id": str(user.id),
                "user_name": getattr(user, 'name', None) or f"User {user.id}",
            }
        )
        customer_id = customer.id
        logger.info(f"创建新 Stripe Customer: user={user.id}, customer={customer_id}")
    
    # 4. 保存到数据库（避免下次重复查询/创建）
    if db and hasattr(user, 'stripe_customer_id'):
        try:
            user.stripe_customer_id = customer_id
            db.commit()
            logger.info(f"已保存 Stripe Customer ID 到用户记录: user={user.id}, customer={customer_id}")
        except Exception as e:
            logger.warning(f"保存 Stripe Customer ID 失败（不影响支付）: {e}")
            try:
                db.rollback()
            except Exception:
                pass
    
    return customer_id


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
        
        # 优先使用 V2 API，回退到 V1 API
        try:
            details_submitted, charges_enabled = _check_account_status_v2(user.stripe_account_id)
            # V2 API 不直接返回 payouts_enabled，这里假设与 charges_enabled 相同
            payouts_enabled = charges_enabled
        except Exception:
            account = stripe.Account.retrieve(user.stripe_account_id)
            details_submitted = account.details_submitted
            charges_enabled = account.charges_enabled
            payouts_enabled = account.payouts_enabled
        
        return {
            "has_account": True,
            "account_id": user.stripe_account_id,
            "details_submitted": details_submitted,
            "charges_enabled": charges_enabled,
            "payouts_enabled": payouts_enabled,
            "needs_setup": not details_submitted
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

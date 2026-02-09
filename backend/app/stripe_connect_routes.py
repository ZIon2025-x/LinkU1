"""
Stripe Connect 账户管理 API 路由

使用 Stripe Connect Accounts V2 API 创建和管理连接账户。
支持嵌入式 onboarding，用户可以在应用内完成账户设置。

主要功能：
- 创建 Stripe Connect Express 账户（V2 API）
- 创建 AccountSession 用于嵌入式 onboarding
- 处理 webhook 事件（支持 V1 和 V2 事件）
- 验证账户所有权和状态

注意：
- AccountSession API 是 V1 API，但可以与 V2 账户一起使用
- 代码同时支持 V1 和 V2 账户以保持向后兼容
"""
import logging
import os
import requests
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
import stripe

from app import schemas, models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.utils.time_utils import get_utc_time

try:
    from app.celery_tasks import get_redis_distributed_lock, release_redis_distributed_lock
except ImportError:
    get_redis_distributed_lock = lambda k, t=30: True
    release_redis_distributed_lock = lambda k: None

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stripe/connect", tags=["Stripe Connect"])

# 注意：Stripe API配置在应用启动时通过stripe_config模块统一配置（带超时）

# V2 API 辅助函数：由于 Python SDK 可能不支持 v2.core.accounts，
# 我们使用 HTTP 请求直接调用 V2 API
import requests

def stripe_v2_api_request(method: str, endpoint: str, data: dict = None, params: dict = None) -> dict:
    """
    直接使用 HTTP 请求调用 Stripe V2 API（带超时设置）
    
    Args:
        method: HTTP 方法 ('GET', 'POST', 'PUT', 'DELETE')
        endpoint: API 端点（如 'accounts', 'accounts/{id}'）
        data: 请求体数据（字典，用于 POST/PUT）
        params: URL 参数（字典，用于 GET）
    
    Returns:
        API 响应（字典）
    """
    api_key = os.getenv("STRIPE_SECRET_KEY")
    if not api_key:
        raise ValueError("STRIPE_SECRET_KEY not set")
    
    # 获取超时配置（默认10秒）
    timeout = int(os.getenv("STRIPE_API_TIMEOUT", "10"))
    
    url = f"https://api.stripe.com/v2/core/{endpoint}"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Stripe-Version": "2025-04-30.preview",
        "Content-Type": "application/json"
    }
    
    try:
        if method.upper() == "GET":
            # GET 请求使用 params
            query_params = {}
            if params:
                query_params.update(params)
            # 处理 include 参数（支持 data 或 params，retrieve 使用 params）
            # Stripe V2 API 需要精确索引格式：include[0], include[1], etc.
            # 不支持 include[]=value1&include[]=value2 的数组语法
            include_list = None
            if data and "include" in data:
                include_list = data.get("include", [])
            elif "include" in query_params:
                include_list = query_params.pop("include", [])
            if include_list:
                for idx, value in enumerate(include_list):
                    query_params[f"include[{idx}]"] = value
            response = requests.get(url, headers=headers, params=query_params, timeout=timeout)
        elif method.upper() == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=timeout)
        elif method.upper() == "PUT":
            response = requests.put(url, headers=headers, json=data, timeout=timeout)
        elif method.upper() == "DELETE":
            response = requests.delete(url, headers=headers, timeout=timeout)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
        
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        # 检查是否是 400 错误（可能是 V1 账户，不支持 V2 API）
        is_v1_account_error = False
        error_message = str(e)
        if hasattr(e, 'response') and e.response is not None:
            status_code = e.response.status_code
            if status_code == 400:
                try:
                    error_data = e.response.json()
                    error_msg = error_data.get('error', {})
                    if isinstance(error_msg, dict):
                        message = error_msg.get('message', '')
                        code = error_msg.get('code', '')
                        # 检查是否是 V1 账户相关的错误
                        if 'v1' in message.lower() or 'V1' in message or code == 'v1_account_instead_of_v2_account':
                            is_v1_account_error = True
                            error_message = message
                except:
                    pass
        
        # 如果是 V1 账户错误，使用 DEBUG 级别（这是正常的回退情况）
        # 其他错误使用 WARNING 级别（避免过多 ERROR 日志）
        if is_v1_account_error:
            logger.debug(f"Stripe V2 API request failed (V1 account, will fallback to V1 API): {error_message}")
        else:
            logger.warning(f"Stripe V2 API request failed: {error_message}")
        
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                error_msg = error_data.get('error', {})
                if isinstance(error_msg, dict):
                    message = error_msg.get('message', str(e))
                    code = error_msg.get('code', 'api_error')
                else:
                    message = str(error_msg) if error_msg else str(e)
                    code = 'api_error'
                raise stripe.error.StripeError(message=message, code=code)
            except stripe.error.StripeError:
                raise
            except:
                raise stripe.error.StripeError(message=str(e), code='api_error')
        raise


class StripeV2Account:
    """模拟 Stripe V2 Account 对象"""
    def __init__(self, data: dict):
        self._data = data
        for key, value in data.items():
            setattr(self, key, value)
    
    def get(self, key: str, default=None):
        return self._data.get(key, default)
    
    def __getitem__(self, key: str):
        return self._data[key]
    
    def __contains__(self, key: str):
        return key in self._data


class StripeV2Accounts:
    """模拟 Stripe V2 Accounts API"""
    @staticmethod
    def create(**kwargs) -> StripeV2Account:
        """创建账户"""
        account_data = stripe_v2_api_request("POST", "accounts", data=kwargs)
        return StripeV2Account(account_data)
    
    @staticmethod
    def retrieve(account_id: str, include: list = None) -> StripeV2Account:
        """检索账户"""
        params = {}
        if include:
            params["include"] = include
        account_data = stripe_v2_api_request("GET", f"accounts/{account_id}", params=params)
        return StripeV2Account(account_data)


# 创建模拟的 stripe.v2.core.accounts 对象
class StripeV2Core:
    accounts = StripeV2Accounts()


class StripeV2:
    core = StripeV2Core()


# 创建一个兼容的对象，可以像 stripe.v2.core.accounts 一样使用
stripe_v2 = StripeV2()


def detect_account_type(account_id: str) -> str:
    """
    检测 Stripe 账户类型（V1 或 V2）
    
    Returns:
        "v1" 或 "v2"
    """
    try:
        # 尝试使用 V2 API 检索
        account = stripe_v2.core.accounts.retrieve(account_id)
        return "v2"
    except stripe.error.StripeError as v2_err:
        error_message = str(v2_err)
        if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
            return "v1"
        # 如果错误不是 V1 账户错误，尝试 V1 API 确认
        try:
            account = stripe.Account.retrieve(account_id)
            return "v1"
        except:
            # 如果都失败，返回 unknown
            return "unknown"
    except Exception:
        # 如果都失败，尝试 V1 API
        try:
            account = stripe.Account.retrieve(account_id)
            return "v1"
        except:
            return "unknown"


def create_account_session_safe(
    account_id: str, 
    enable_payouts: bool = False,
    enable_account_management: bool = False,
    enable_account_onboarding: bool = False,
    enable_payments: bool = False,
    disable_stripe_user_authentication: bool = False
) -> stripe.AccountSession:
    """
    安全地创建 AccountSession，确保所有布尔值都是正确的类型
    
    这个函数确保 components 配置中的 enabled 字段是 Python 布尔值，
    而不是字符串，避免 "Invalid boolean" 错误
    
    Args:
        account_id: Stripe Connect 账户 ID
        enable_payouts: 是否启用 payouts 组件（用于钱包和设置页面）
        enable_account_management: 是否启用 account_management 组件（用于设置页面管理账户信息）
        enable_account_onboarding: 是否启用 account_onboarding 组件（用于账户入驻）
        enable_payments: 是否启用 payments 组件（用于显示支付列表，支持退款和争议管理）
        disable_stripe_user_authentication: 是否禁用 Stripe 用户认证（仅适用于 Custom 账户且平台负责收集信息）
    """
    # 显式创建 components 配置，确保所有布尔值都是 Python 布尔类型
    components_config = {}
    
    # 确定 disable_stripe_user_authentication 的值
    # 如果 payouts 和 account_onboarding 都启用，它们的 disable_stripe_user_authentication 必须相同
    # 如果 payouts 启用，默认使用 disable_stripe_user_authentication 参数的值
    # 如果只有 account_onboarding 启用，使用 disable_stripe_user_authentication 参数的值
    use_disable_auth = disable_stripe_user_authentication
    
    # 如果启用 payouts，添加 payouts 组件配置
    if enable_payouts:
        components_config["payouts"] = {
            "enabled": bool(True),
            "features": {
                "instant_payouts": bool(True),  # 即时提现
                "standard_payouts": bool(True),  # 标准提现
                "edit_payout_schedule": bool(True),  # 编辑提现计划
                "external_account_collection": bool(True),  # 外部账户收集（银行卡）
                "disable_stripe_user_authentication": bool(use_disable_auth),  # 禁用 Stripe 用户认证（用于自定义账户）
            }
        }
    
    # 如果启用 account_onboarding，添加 account_onboarding 组件配置
    if enable_account_onboarding:
        components_config["account_onboarding"] = {
            "enabled": bool(True),
            "features": {}
        }
        # 如果禁用 Stripe 用户认证，添加此配置
        # 注意：这仅适用于 Custom 账户且平台负责收集信息的情况
        # 如果 payouts 也启用，必须使用相同的值
        if use_disable_auth:
            components_config["account_onboarding"]["features"]["disable_stripe_user_authentication"] = bool(True)
        # 如果 payouts 也启用，确保 account_onboarding 使用相同的 disable_stripe_user_authentication 值
        elif enable_payouts:
            # 如果 payouts 中设置了 disable_stripe_user_authentication，account_onboarding 也必须设置相同的值
            # 从 payouts 配置中获取值（payouts 已经在上面创建了）
            if "payouts" in components_config:
                payouts_features = components_config["payouts"].get("features", {})
                if payouts_features.get("disable_stripe_user_authentication", False):
                    components_config["account_onboarding"]["features"]["disable_stripe_user_authentication"] = bool(True)
        # external_account_collection 默认为 true，如果需要禁用可以添加
        # components_config["account_onboarding"]["features"]["external_account_collection"] = bool(False)
    else:
        # 默认情况下，account_onboarding 总是启用的（用于兼容现有代码）
        # 但如果 payouts 也启用，需要确保 disable_stripe_user_authentication 一致
        components_config["account_onboarding"] = {
            "enabled": bool(True)
        }
        # 如果 payouts 启用且设置了 disable_stripe_user_authentication，account_onboarding 也需要设置相同的值
        if enable_payouts and use_disable_auth:
            components_config["account_onboarding"]["features"] = {
                "disable_stripe_user_authentication": bool(True)
            }
    
    # 如果启用 account_management，添加 account_management 组件配置
    if enable_account_management:
        components_config["account_management"] = {
            "enabled": bool(True),
            "features": {
                "external_account_collection": bool(True),  # 启用银行卡管理功能
                # 注意：disable_stripe_user_authentication 默认值取决于 external_account_collection
                # 如果 external_account_collection 为 true，则 disable_stripe_user_authentication 默认为 false
                # 如果需要禁用 Stripe 用户认证，需要明确设置（仅适用于 Custom 账户且平台负责收集信息）
            }
        }
    
    # 如果启用 payments，添加 payments 组件配置
    if enable_payments:
        components_config["payments"] = {
            "enabled": bool(True),
            "features": {
                "refund_management": bool(True),  # 启用退款管理
                "dispute_management": bool(True),  # 启用争议管理
                "capture_payments": bool(True),  # 启用支付捕获
                "destination_on_behalf_of_charge_management": bool(False),  # 默认禁用，如果需要可以启用
            }
        }
    
    logger.debug(f"Creating AccountSession for account {account_id} with components: {components_config}")
    
    return stripe.AccountSession.create(
        account=account_id,
        components=components_config
    )


def _retrieve_existing_connect_account_for_reuse(account_id: str) -> tuple:
    """
    检索已有 Connect 账户状态（V2 优先，V1 回退），用于复用已有账户。
    返回 (details_submitted, charges_enabled)。
    失败时抛出 stripe.error.StripeError。
    """
    try:
        account = stripe_v2.core.accounts.retrieve(
            account_id,
            include=["requirements", "configuration.recipient"]
        )
        requirements = account.get("requirements") or {}
        summary = requirements.get("summary") or {}
        minimum_deadline = summary.get("minimum_deadline") or {}
        deadline_status = minimum_deadline.get("status") if isinstance(minimum_deadline, dict) else None
        details_submitted = not deadline_status or deadline_status == "eventually_due"
        configuration = account.get("configuration") or {}
        recipient_config = configuration.get("recipient") or {}
        recipient_capabilities = recipient_config.get("capabilities") or {}
        stripe_balance = recipient_capabilities.get("stripe_balance") or {}
        stripe_transfers = stripe_balance.get("stripe_transfers") or {}
        charges_enabled = stripe_transfers.get("status") == "active"
        if not charges_enabled:
            merchant_config = configuration.get("merchant") or {}
            merchant_capabilities = merchant_config.get("capabilities") or {}
            card_payments = merchant_capabilities.get("card_payments") or {}
            charges_enabled = card_payments.get("status") == "active"
        return (details_submitted, charges_enabled)
    except stripe.error.StripeError as v2_err:
        err_msg = str(v2_err)
        if "v1_account_instead_of_v2_account" in err_msg or "V1 Accounts cannot be used" in err_msg:
            account = stripe.Account.retrieve(account_id)
            return (account.details_submitted, account.charges_enabled)
        raise


def check_user_has_stripe_account(user_id: int, db: Session) -> Optional[str]:
    """
    检查用户是否已有 Stripe Connect 账户
    
    通过以下方式检查：
    1. 检查数据库中的 stripe_account_id
    2. 通过 Stripe API 查询是否有该 user_id 的账户（通过 metadata）
    
    返回账户 ID（如果存在），否则返回 None
    """
    # 首先检查数据库
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user and user.stripe_account_id:
        # 验证账户是否真的存在且属于该用户
        # 首先尝试使用 V2 API，如果失败则回退到 V1 API（兼容旧账户）
        account = None
        account_user_id = None
        try:
            # 尝试使用 V2 API 检索
            account = stripe_v2.core.accounts.retrieve(
                user.stripe_account_id,
                include=["identity"]
            )
            account_metadata = account.get("metadata", {})
            account_user_id = account_metadata.get("user_id") if isinstance(account_metadata, dict) else None
            # V2 成功分支：校验 user_id 并返回已有账户（修复重复创建）
            if account_user_id and str(account_user_id) == str(user_id):
                logger.info(f"User {user_id} already has Stripe account {user.stripe_account_id} (verified via metadata, V2)")
                return user.stripe_account_id
            elif account_user_id:
                logger.warning(f"User {user_id} has stripe_account_id {user.stripe_account_id} but metadata.user_id doesn't match")
            else:
                logger.warning(f"User {user_id} has stripe_account_id {user.stripe_account_id} but no user_id in metadata")
        except stripe.error.StripeError as v2_err:
            # 如果 V2 API 失败（可能是 V1 账户），尝试 V1 API
            error_message = str(v2_err)
            if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
                logger.debug(f"Account {user.stripe_account_id} is a V1 account, using V1 API")
            else:
                logger.debug(f"V2 API retrieval failed, trying V1 API: {v2_err}")
            # 回退到 V1 API
            account = stripe.Account.retrieve(user.stripe_account_id)
            account_metadata = getattr(account, 'metadata', {})
            if isinstance(account_metadata, dict):
                account_user_id = account_metadata.get('user_id')
            else:
                account_user_id = getattr(account_metadata, 'user_id', None)
            
            # 检查 metadata 中的 user_id 是否匹配
            if account_user_id and str(account_user_id) == str(user_id):
                logger.info(f"User {user_id} already has Stripe account {user.stripe_account_id} (verified via metadata)")
                return user.stripe_account_id
            else:
                logger.warning(f"User {user_id} has stripe_account_id {user.stripe_account_id} but metadata.user_id doesn't match")
        except stripe.error.StripeError as e:
            logger.warning(f"Stripe account {user.stripe_account_id} for user {user_id} not found in Stripe: {e}")
            # 账户不存在，清除数据库记录
            user.stripe_account_id = None
            db.commit()
            db.refresh(user)
    
    # 通过 Stripe API 查询是否有该 user_id 的账户（通过 metadata）
    # 注意：Stripe API 不支持直接通过 metadata 查询，所以我们需要依赖数据库记录
    # 但我们可以通过列出所有账户来检查（这在生产环境中不推荐，因为账户数量可能很大）
    # 更好的做法是确保数据库记录是准确的，并在创建前检查数据库
    
    return None


def verify_account_ownership(account_id: str, current_user: models.User) -> bool:
    """
    验证 Stripe 账户是否属于当前用户
    
    通过检查账户的 metadata 中的 user_id 来验证账户所有权
    如果 metadata 中没有 user_id 或 user_id 不匹配，返回 False
    支持 V1 和 V2 API
    """
    try:
        # 首先尝试使用 V2 API，如果失败则回退到 V1 API（兼容旧账户）
        account = None
        account_user_id = None
        try:
            account = stripe_v2.core.accounts.retrieve(account_id)
            account_metadata = account.get("metadata", {})
            account_user_id = account_metadata.get('user_id') if isinstance(account_metadata, dict) else None
        except stripe.error.StripeError as v2_err:
            # 如果 V2 API 失败（可能是 V1 账户），尝试 V1 API
            error_message = str(v2_err)
            if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
                logger.debug(f"Account {account_id} is a V1 account, using V1 API")
            else:
                logger.debug(f"V2 API retrieval failed, trying V1 API: {v2_err}")
            # 回退到 V1 API
            account = stripe.Account.retrieve(account_id)
            account_metadata = getattr(account, 'metadata', {})
            if isinstance(account_metadata, dict):
                account_user_id = account_metadata.get('user_id')
            else:
                account_user_id = getattr(account_metadata, 'user_id', None)
        
        if not account_user_id:
            logger.warning(f"Account {account_id} has no user_id in metadata")
            return False
        
        # 验证 user_id 是否匹配
        if str(account_user_id) != str(current_user.id):
            logger.warning(
                f"Account ownership mismatch: account {account_id} metadata.user_id={account_user_id}, "
                f"current_user.id={current_user.id}"
            )
            return False
        
        return True
    except stripe.error.StripeError as e:
        logger.error(f"Error verifying account ownership for account {account_id}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error verifying account ownership: {e}", exc_info=True)
        return False


@router.post("/account/create", response_model=schemas.StripeConnectAccountEmbeddedResponse)
def create_connect_account(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建 Stripe Connect Express Account（使用嵌入式组件）
    
    为当前用户创建 Stripe Connect Express 账户，用于接收任务奖励支付
    返回账户 ID 和 client_secret，前端可以使用 Stripe Connect Embedded Components
    在自己的页面中完成 onboarding，无需跳转到 Stripe 页面
    注意：每个用户只能有一个 Stripe Connect 账户
    """
    try:
        # 检查用户是否已有 Stripe Connect 账户（每个用户只能有一个账户）
        existing_account_id = check_user_has_stripe_account(current_user.id, db)
        if existing_account_id:
            # 沿用已有账户：复用 _retrieve_existing_connect_account_for_reuse，返回已有账户而非 400
            try:
                details_submitted, charges_enabled = _retrieve_existing_connect_account_for_reuse(existing_account_id)
                logger.info(f"User {current_user.id} already has Stripe account {existing_account_id}, returning existing account")
                if details_submitted and charges_enabled:
                    return {
                        "account_id": existing_account_id,
                        "client_secret": None,
                        "account_status": details_submitted,
                        "charges_enabled": charges_enabled,
                        "message": "您已经有一个 Stripe 账户且已完成设置"
                    }
                onboarding_session = create_account_session_safe(
                    existing_account_id, enable_account_onboarding=True
                )
                return {
                    "account_id": existing_account_id,
                    "client_secret": onboarding_session.client_secret,
                    "account_status": details_submitted,
                    "charges_enabled": charges_enabled,
                    "message": "您已经有一个 Stripe 账户，请完成设置"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account {existing_account_id}: {e}")
                if getattr(e, "http_status", None) == 404:
                    db_user_clear = db.query(models.User).filter(models.User.id == current_user.id).first()
                    if db_user_clear:
                        db_user_clear.stripe_account_id = None
                        db.commit()
                        db.refresh(db_user_clear)
                else:
                    raise HTTPException(
                        status_code=503,
                        detail="无法获取 Stripe 账户状态，请稍后重试"
                    )
        
        lock_key = f"stripe_connect:create:{current_user.id}"
        if not get_redis_distributed_lock(lock_key, 30):
            raise HTTPException(status_code=409, detail="操作进行中，请稍后重试")
        try:
            existing2 = check_user_has_stripe_account(current_user.id, db)
            if existing2:
                details_submitted, charges_enabled = _retrieve_existing_connect_account_for_reuse(existing2)
                logger.info(f"User {current_user.id} already has Stripe account {existing2} (double-check), returning")
                if details_submitted and charges_enabled:
                    return {
                        "account_id": existing2,
                        "client_secret": None,
                        "account_status": details_submitted,
                        "charges_enabled": charges_enabled,
                        "message": "您已经有一个 Stripe 账户且已完成设置"
                    }
                onboarding_session = create_account_session_safe(existing2, enable_account_onboarding=True)
                return {
                    "account_id": existing2,
                    "client_secret": onboarding_session.client_secret,
                    "account_status": details_submitted,
                    "charges_enabled": charges_enabled,
                    "message": "您已经有一个 Stripe 账户，请完成设置"
                }
            # 创建 Express Account (使用 V2 API)
            # 参考: 官方文档 https://docs.stripe.com/connect/embedded-onboarding?accounts-namespace=v2
            try:
                # 使用 V2 API 创建账户（通过 HTTP 请求）
                # 根据官方文档，使用 merchant 配置用于接收支付
                account_data = stripe_v2_api_request(
                    "POST",
                    "accounts",
                    data={
                        "contact_email": current_user.email or f"user_{current_user.id}@link2ur.com",
                        "display_name": current_user.name or f"User {current_user.id}",
                        "dashboard": "express",  # Express Dashboard
                        "identity": {
                            "country": "GB",  # 默认使用 GB（与 sample code 一致），用户可以在 onboarding 时更改
                            "entity_type": "individual"  # 默认为个人，用户可以在 onboarding 时更改（sample code 使用 company，但我们使用 individual 更符合任务接受人的场景）
                        },
                        "configuration": {
                            # 使用 recipient 配置用于接收支付（与 sample code 一致）
                            "recipient": {
                                "capabilities": {
                                    "stripe_balance": {
                                        "stripe_transfers": {
                                            "requested": True
                                        }
                                    }
                                }
                            }
                        },
                        "defaults": {
                            "currency": "gbp",
                            "responsibilities": {
                                "fees_collector": "application",  # 平台收取费用
                                "losses_collector": "application"  # 平台承担损失
                            },
                            "locales": ["en-GB"]
                        },
                        "metadata": {
                            "user_id": str(current_user.id),
                            "platform": "Link²Ur",
                            "user_name": current_user.name or f"User {current_user.id}"
                        },
                        "include": [
                            "configuration.recipient",
                            "identity",
                            "requirements"
                        ]
                    }
                )
                account = StripeV2Account(account_data)
                logger.info(f"Created Stripe Connect account {account.id} using V2 API for user {current_user.id}")
            except Exception as e:
                logger.error(f"Error creating Stripe Connect account: {e}")
                raise HTTPException(
                    status_code=400,
                    detail=f"创建 Stripe 账户失败: {str(e)}"
                )
        
            # 再次检查用户是否已有账户（防止并发创建）
            # 重新查询用户以确保对象在当前会话中
            db_user_check = db.query(models.User).filter(models.User.id == current_user.id).first()
            if db_user_check and db_user_check.stripe_account_id:
                logger.warning(f"User {current_user.id} already has a Stripe account {db_user_check.stripe_account_id}, skipping creation of {account.id}")
                # 如果用户已经有账户，返回现有账户信息（使用嵌入式组件）
                try:
                    existing_account = stripe.Account.retrieve(db_user_check.stripe_account_id)
                    
                    # 检查账户状态（V2 API 使用 requirements 字段）
                    # 尝试使用 V2 API 检索账户
                    try:
                        v2_account = stripe_v2.core.accounts.retrieve(
                            existing_account.id,
                            include=["requirements"]
                        )
                        # V2 API: 检查 requirements 中是否有 currently_due 或 eventually_due
                        requirements = v2_account.get("requirements", {})
                        currently_due = requirements.get("currently_due", [])
                        eventually_due = requirements.get("eventually_due", [])
                        is_complete = len(currently_due) == 0 and len(eventually_due) == 0
                        
                        if is_complete:
                            return {
                                "account_id": existing_account.id,
                                "client_secret": None,
                                "account_status": True,
                                "charges_enabled": True,  # V2 API 中需要从其他地方获取
                                "message": "您已经有一个 Stripe 账户且已完成设置"
                            }
                    except stripe.error.StripeError as v2_err:
                        # 如果 V2 API 失败（可能是 V1 账户），使用 V1 API 的结果
                        error_message = str(v2_err)
                        if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
                            logger.debug(f"Account {existing_account.id} is a V1 account, using V1 API result")
                        else:
                            logger.warning(f"Failed to retrieve account using V2 API: {v2_err}, falling back to V1 check")
                        # 回退到 V1 API 检查
                        is_complete = existing_account.details_submitted
                    if is_complete or existing_account.details_submitted:
                        return {
                            "account_id": existing_account.id,
                            "client_secret": None,
                            "account_status": existing_account.details_submitted,
                            "charges_enabled": existing_account.charges_enabled,
                            "message": "您已经有一个 Stripe 账户且已完成设置"
                        }
                    
                    # 如果账户未完成 onboarding，创建 AccountSession 用于嵌入式组件
                    onboarding_session = create_account_session_safe(existing_account.id)
                    
                    return {
                        "account_id": existing_account.id,
                        "client_secret": onboarding_session.client_secret,
                        "account_status": existing_account.details_submitted,
                        "charges_enabled": existing_account.charges_enabled,
                        "message": "您已经有一个 Stripe 账户，请完成设置"
                    }
                except stripe.error.StripeError as e:
                    logger.error(f"Error retrieving existing account: {e}")
                    # 如果现有账户无效，清除记录并继续
                    db_user_clear = db.query(models.User).filter(models.User.id == current_user.id).first()
                    if db_user_clear:
                        db_user_clear.stripe_account_id = None
                        db.commit()
                        db.refresh(db_user_clear)
        
            # 保存账户 ID 到用户记录
            try:
                # 重新查询用户以确保对象在当前会话中
                db_user = db.query(models.User).filter(models.User.id == current_user.id).first()
                if not db_user:
                    raise HTTPException(status_code=404, detail="用户不存在")
                
                db_user.stripe_account_id = account.id
                db.add(db_user)  # 确保对象被添加到会话
                db.commit()
                db.refresh(db_user)  # 刷新对象以确保数据是最新的
                
                # 验证保存是否成功
                if db_user.stripe_account_id == account.id:
                    logger.info(f"✅ Verified: Stripe Connect account {account.id} saved to database for user {current_user.id}")
                else:
                    logger.error(f"❌ Failed to verify: stripe_account_id not saved correctly for user {current_user.id}")
                    # 尝试再次保存
                    if db_user:
                        db_user.stripe_account_id = account.id
                        db.commit()
                        db.refresh(db_user)
                        logger.info(f"Retry: Stripe Connect account {account.id} saved to database for user {current_user.id}")
            except Exception as db_err:
                # 捕获唯一性约束错误（虽然理论上不应该发生，因为我们已经检查过了）
                db.rollback()
                if "unique" in str(db_err).lower() or "duplicate" in str(db_err).lower():
                    logger.warning(f"User {current_user.id} already has a Stripe account (database constraint violation)")
                    raise HTTPException(
                        status_code=400,
                        detail="您已经有一个 Stripe Connect 账户，每个用户只能有一个账户"
                    )
                logger.error(f"Error saving stripe_account_id to database: {db_err}", exc_info=True)
                raise
        
            # 创建 AccountSession 用于嵌入式 onboarding（不使用跳转链接）
            try:
                onboarding_session = create_account_session_safe(account.id)
                logger.info(f"Created AccountSession for account {account.id}")
            except stripe.error.StripeError as session_err:
                logger.error(f"Stripe error creating AccountSession: {session_err}")
                # 即使创建 session 失败，也返回账户信息，让用户可以稍后重试
                return {
                    "account_id": account.id,
                    "client_secret": None,
                    "account_status": account.details_submitted,
                    "charges_enabled": account.charges_enabled,
                    "message": f"账户创建成功，但无法立即创建 onboarding session: {str(session_err)}"
                }
        
            # V2 API 返回的账户对象结构不同，需要从 requirements 判断状态
            # 参考: stripe-sample-code/server.js 的账户状态检查逻辑
            account_status = False
            charges_enabled = False
            payouts_enabled = False
            try:
                # 尝试从 V2 API 获取完整账户信息
                v2_account = stripe_v2.core.accounts.retrieve(
                    account.id,
                    include=["requirements", "configuration.recipient"]  # 与 sample code 一致
                )
                requirements = v2_account.get("requirements", {})
                currently_due = requirements.get("currently_due", [])
                
                # 检查 summary 状态（参考 sample code）
                summary = requirements.get("summary", {})
                minimum_deadline = summary.get("minimum_deadline", {})
                deadline_status = minimum_deadline.get("status")
                # details_submitted 表示没有当前需要提交的要求
                account_status = not deadline_status or deadline_status == "eventually_due"
                
                # 检查 recipient 配置中的 capabilities（用于接收支付）
                configuration = v2_account.get("configuration") or {}
                recipient_config = configuration.get("recipient") or {}
                recipient_capabilities = recipient_config.get("capabilities", {})
                stripe_balance = recipient_capabilities.get("stripe_balance", {})
                stripe_transfers = stripe_balance.get("stripe_transfers", {})
                charges_enabled = stripe_transfers.get("status") == "active"
                
                # 检查 payouts 状态
                payouts = stripe_balance.get("payouts", {})
                payouts_enabled = payouts.get("status") == "active"
                
                # 如果 recipient 不可用，回退到 merchant 配置
                if not charges_enabled:
                    merchant_config = configuration.get("merchant") or {}
                    merchant_capabilities = merchant_config.get("capabilities", {})
                    card_payments = merchant_capabilities.get("card_payments", {})
                    charges_enabled = card_payments.get("status") == "active"
            except stripe.error.StripeError as v2_err:
                # 如果 V2 API 失败（可能是 V1 账户），使用 V1 API 的结果
                error_message = str(v2_err)
                if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
                    logger.debug(f"Account {account.id} is a V1 account, using V1 API result")
                else:
                    logger.warning(f"Failed to get account status from V2 API: {v2_err}, using V1 API result")
                # 使用 V1 API 已经检索的账户信息
                account_status = account.details_submitted
                charges_enabled = account.charges_enabled
                payouts_enabled = account.payouts_enabled
            except Exception as status_err:
                logger.warning(f"Failed to get account status: {status_err}, using defaults")
                # 如果所有 API 都失败，使用默认值
                account_status = False
                charges_enabled = False
                payouts_enabled = False
            
            return {
                "account_id": account.id,
                "client_secret": onboarding_session.client_secret,
                "account_status": account_status,
                "charges_enabled": charges_enabled,
                "message": "账户创建成功，请完成账户设置"
            }
        finally:
            release_redis_distributed_lock(lock_key)
        
    except HTTPException:
        raise
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating account: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建 Stripe 账户失败: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error creating Stripe Connect account: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"服务器错误: {str(e)}"
        )


@router.post("/account/create-embedded", response_model=schemas.StripeConnectAccountEmbeddedResponse)
def create_connect_account_embedded(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建 Stripe Connect Express Account（用于嵌入式 onboarding）
    
    返回账户 ID 和 client_secret，前端可以使用 Stripe Connect Embedded Components
    在自己的页面中完成 onboarding，无需跳转到 Stripe 页面
    注意：每个用户只能有一个 Stripe Connect 账户
    """
    try:
        # 检查 Stripe API Key 是否配置
        if not stripe.api_key:
            logger.error("STRIPE_SECRET_KEY is not set")
            raise HTTPException(
                status_code=500,
                detail="Stripe 配置错误：未设置 API Key"
            )
        
        # 检查用户是否已有 Stripe Connect 账户（每个用户只能有一个账户）
        existing_account_id = check_user_has_stripe_account(current_user.id, db)
        if existing_account_id:
            # 沿用已有账户：复用 _retrieve_existing_connect_account_for_reuse；仅 404 时清空 DB
            try:
                details_submitted, charges_enabled = _retrieve_existing_connect_account_for_reuse(existing_account_id)
                if details_submitted and charges_enabled:
                    return {
                        "account_id": existing_account_id,
                        "client_secret": None,
                        "account_status": details_submitted,
                        "charges_enabled": charges_enabled,
                        "message": "账户已存在且已完成设置"
                    }
                onboarding_session = create_account_session_safe(
                    existing_account_id, enable_account_onboarding=True
                )
                return {
                    "account_id": existing_account_id,
                    "client_secret": onboarding_session.client_secret,
                    "account_status": details_submitted,
                    "charges_enabled": charges_enabled,
                    "message": "账户已存在，请完成设置"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account {existing_account_id}: {e}")
                if getattr(e, "http_status", None) == 404:
                    db_user = db.query(models.User).filter(models.User.id == current_user.id).first()
                    if db_user:
                        db_user.stripe_account_id = None
                        db.commit()
                raise HTTPException(
                    status_code=503,
                    detail="无法获取 Stripe 账户状态，请稍后重试"
                )
        
        lock_key = f"stripe_connect:create:{current_user.id}"
        if not get_redis_distributed_lock(lock_key, 30):
            raise HTTPException(status_code=409, detail="操作进行中，请稍后重试")
        try:
            existing2 = check_user_has_stripe_account(current_user.id, db)
            if existing2:
                details_submitted, charges_enabled = _retrieve_existing_connect_account_for_reuse(existing2)
                logger.info(f"User {current_user.id} already has Stripe account {existing2} (double-check), returning")
                if details_submitted and charges_enabled:
                    return {
                        "account_id": existing2,
                        "client_secret": None,
                        "account_status": details_submitted,
                        "charges_enabled": charges_enabled,
                        "message": "账户已存在且已完成设置"
                    }
                onboarding_session = create_account_session_safe(existing2, enable_account_onboarding=True)
                return {
                    "account_id": existing2,
                    "client_secret": onboarding_session.client_secret,
                    "account_status": details_submitted,
                    "charges_enabled": charges_enabled,
                    "message": "账户已存在，请完成设置"
                }
            # 创建 Express Account (使用 V2 API)
            # 参考: Stripe Connect Embedded Onboarding 官方文档
            # 注意：使用 V2 API 创建账户，但 AccountSession API 是 V1 API（可以与 V2 账户一起使用）
            account = None
            try:
                logger.info(f"使用 V2 API 创建 Stripe Connect 账户 for user {current_user.id}")
                # 使用 V2 API 创建账户（根据官方文档）
                account_data = stripe_v2_api_request(
                    "POST",
                    "accounts",
                    data={
                        "contact_email": current_user.email or f"user_{current_user.id}@link2ur.com",
                        "display_name": current_user.name or f"User {current_user.id}",
                        "dashboard": "express",  # Express Dashboard
                        "identity": {
                            "country": "GB",  # 默认使用 GB（与 sample code 一致），用户可以在 onboarding 时更改
                            "entity_type": "individual"  # 默认为个人，用户可以在 onboarding 时更改（sample code 使用 company，但我们使用 individual 更符合任务接受人的场景）
                        },
                        "configuration": {
                            # 使用 recipient 配置用于接收支付（与 sample code 一致）
                            "recipient": {
                                "capabilities": {
                                    "stripe_balance": {
                                        "stripe_transfers": {
                                            "requested": True
                                        }
                                    }
                                }
                            }
                        },
                        "defaults": {
                            "currency": "gbp",
                            "responsibilities": {
                                "fees_collector": "application",  # 平台收取费用
                                "losses_collector": "application"  # 平台承担损失
                            },
                            "locales": ["en-GB"]
                        },
                        "metadata": {
                            "user_id": str(current_user.id),
                            "platform": "Link²Ur",
                            "user_name": current_user.name or f"User {current_user.id}"
                        },
                        "include": [
                            "configuration.recipient",
                            "identity",
                            "requirements"
                        ]
                    }
                )
                account = StripeV2Account(account_data)
                logger.info(f"Created Stripe Connect account {account.id} using V2 API for user {current_user.id}")
            except stripe.error.StripeError as e:
                logger.error(f"Stripe error creating account: {e}")
                raise HTTPException(
                    status_code=400,
                    detail=f"创建 Stripe 账户失败: {str(e)}"
                )
            except Exception as e:
                logger.error(f"Unexpected error creating Stripe Connect account: {e}", exc_info=True)
                raise HTTPException(
                    status_code=500,
                    detail=f"创建 Stripe 账户失败: {str(e)}"
                )
        
            if not account:
                raise HTTPException(
                    status_code=500,
                    detail="无法创建 Stripe 账户：未知错误"
                )
        
            # 再次检查用户是否已有账户（防止并发创建）
            # 重新查询用户以确保对象在当前会话中
            db_user_check = db.query(models.User).filter(models.User.id == current_user.id).first()
            if db_user_check:
                existing_account_id = check_user_has_stripe_account(db_user_check.id, db)
            else:
                existing_account_id = None
            if existing_account_id and existing_account_id != account.id:
                logger.warning(f"User {current_user.id} already has a Stripe account {existing_account_id}, skipping creation of {account.id}")
                # 如果用户已经有账户，返回现有账户信息
                try:
                    existing_account = stripe.Account.retrieve(existing_account_id)
                    if existing_account.details_submitted:
                        return {
                            "account_id": existing_account.id,
                            "client_secret": None,
                            "account_status": existing_account.details_submitted,
                            "charges_enabled": existing_account.charges_enabled,
                            "message": "您已经有一个 Stripe 账户且已完成设置"
                        }
                    # 如果账户未完成 onboarding，创建 onboarding session
                    onboarding_session = create_account_session_safe(existing_account.id)
                    return {
                        "account_id": existing_account.id,
                        "client_secret": onboarding_session.client_secret,
                        "account_status": existing_account.details_submitted,
                        "charges_enabled": existing_account.charges_enabled,
                        "message": "您已经有一个 Stripe 账户，请完成设置"
                    }
                except stripe.error.StripeError as e:
                    logger.error(f"Error retrieving existing account: {e}")
                    # 如果现有账户无效，清除记录并继续
                    current_user.stripe_account_id = None
                    db.commit()
        
            # 保存账户 ID 到用户记录
            try:
                # 重新查询用户以确保对象在当前会话中
                db_user = db.query(models.User).filter(models.User.id == current_user.id).first()
                if not db_user:
                    raise HTTPException(status_code=404, detail="用户不存在")
                
                db_user.stripe_account_id = account.id
                db.add(db_user)  # 确保对象被添加到会话
                db.commit()
                db.refresh(db_user)  # 刷新对象以确保数据是最新的
                
                # 验证保存是否成功
                if db_user.stripe_account_id == account.id:
                    logger.info(f"✅ Verified: Stripe Connect account {account.id} saved to database for user {current_user.id}")
                else:
                    logger.error(f"❌ Failed to verify: stripe_account_id not saved correctly for user {current_user.id}")
                    # 尝试再次保存
                    db_user.stripe_account_id = account.id
                    db.commit()
                    db.refresh(db_user)
                    logger.info(f"Retry: Stripe Connect account {account.id} saved to database for user {current_user.id}")
            except Exception as db_err:
                # 捕获唯一性约束错误（虽然理论上不应该发生，因为我们已经检查过了）
                db.rollback()
                if "unique" in str(db_err).lower() or "duplicate" in str(db_err).lower():
                    logger.warning(f"User {current_user.id} already has a Stripe account (database constraint violation)")
                    raise HTTPException(
                        status_code=400,
                        detail="您已经有一个 Stripe Connect 账户，每个用户只能有一个账户"
                    )
                logger.error(f"Error saving stripe_account_id to database: {db_err}", exc_info=True)
                raise HTTPException(
                    status_code=500,
                    detail=f"保存账户信息失败: {str(db_err)}"
                )
        
            # 最终验证：确保账户 ID 已保存到数据库
            final_check = db.query(models.User).filter(models.User.id == current_user.id).first()
            if not final_check or final_check.stripe_account_id != account.id:
                logger.error(f"❌ Final check failed: stripe_account_id not saved for user {current_user.id}")
                # 最后一次尝试保存
                if final_check:
                    final_check.stripe_account_id = account.id
                    db.commit()
                    db.refresh(final_check)
                    logger.info(f"Final retry: Stripe Connect account {account.id} saved to database for user {current_user.id}")
                else:
                    logger.error(f"Cannot find user {current_user.id} in database for final check")
        
            # 创建 AccountSession 用于嵌入式 onboarding
            try:
                onboarding_session = create_account_session_safe(account.id)
                logger.info(f"Created AccountSession for account {account.id}")
            except stripe.error.StripeError as session_err:
                logger.error(f"Stripe error creating AccountSession: {session_err}")
                # 即使创建 session 失败，也返回账户信息，让用户可以稍后重试
                return {
                    "account_id": account.id,
                    "client_secret": None,
                    "account_status": getattr(account, 'details_submitted', False),
                    "charges_enabled": getattr(account, 'charges_enabled', False),
                    "message": f"账户创建成功，但无法创建 onboarding session: {str(session_err)}"
                }
        
            return {
                "account_id": account.id,
                "client_secret": onboarding_session.client_secret,
                "account_status": getattr(account, 'details_submitted', False),
                "charges_enabled": getattr(account, 'charges_enabled', False),
                "message": "账户创建成功，请完成账户设置"
            }
        finally:
            release_redis_distributed_lock(lock_key)
        
    except HTTPException:
        raise
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating account: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建 Stripe 账户失败: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error creating Stripe Connect account: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"服务器错误: {str(e)}"
        )


@router.get("/account/status")
def get_account_status(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取 Stripe Connect 账户状态
    如果没有账户，返回空状态而不是 404
    """
    if not current_user.stripe_account_id:
        return {
            "account_id": None,
            "details_submitted": False,
            "charges_enabled": False,
            "payouts_enabled": False,
            "client_secret": None,
            "needs_onboarding": True,
            "requirements": None
        }
    
    try:
        # 优先使用 V2 API，兼容 V1 API
        try:
            account = stripe_v2.core.accounts.retrieve(
                current_user.stripe_account_id,
                include=["requirements", "configuration.recipient"]  # 与 sample code 一致
            )
            
            # 验证账户所有权（通过 metadata 中的 user_id）
            account_metadata = account.get("metadata", {})
            account_user_id = account_metadata.get("user_id") if isinstance(account_metadata, dict) else None
            if not account_user_id or str(account_user_id) != str(current_user.id):
                logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
                raise HTTPException(
                    status_code=403,
                    detail="账户验证失败：账户不属于当前用户"
                )
            
            # 检查账户状态（参考 sample code）
            requirements = account.get("requirements") or {}
            summary = requirements.get("summary") or {}
            minimum_deadline = summary.get("minimum_deadline") or {}
            deadline_status = minimum_deadline.get("status") if isinstance(minimum_deadline, dict) else None
            
            # details_submitted 表示没有当前需要提交的要求
            details_submitted = not deadline_status or deadline_status == "eventually_due"
            
            # 检查 recipient 配置中的 capabilities（用于接收支付）
            configuration = account.get("configuration") or {}
            recipient_config = configuration.get("recipient") or {}
            recipient_capabilities = recipient_config.get("capabilities") or {}
            stripe_balance = recipient_capabilities.get("stripe_balance") or {}
            stripe_transfers = stripe_balance.get("stripe_transfers") or {}
            charges_enabled = stripe_transfers.get("status") == "active"
            
            # 检查 payouts 状态
            payouts = stripe_balance.get("payouts") or {}
            payouts_enabled = payouts.get("status") == "active"
            
            # 如果 recipient 不可用，回退到 merchant 配置
            if not charges_enabled:
                merchant_config = configuration.get("merchant") or {}
                merchant_capabilities = merchant_config.get("capabilities") or {}
                card_payments = merchant_capabilities.get("card_payments") or {}
                charges_enabled = card_payments.get("status") == "active"
            
            needs_onboarding = not details_submitted
            requirements_entries = requirements.get("entries") or []
            account_type = "v2"  # V2 API 成功，账户类型为 V2
            
            # 提取详细的需求信息（V2 格式）
            requirements_detail = {
                "currently_due": [],
                "past_due": [],
                "eventually_due": [],
                "disabled_reason": None
            }
            
            # 解析 V2 requirements entries
            for entry in requirements_entries:
                if not isinstance(entry, dict):
                    continue
                entry_type = entry.get("type", "")
                status = entry.get("status") or {}
                entry_deadline_status = status.get("deadline_status", "") if isinstance(status, dict) else ""
                
                if entry_deadline_status == "past_due":
                    requirements_detail["past_due"].append(entry_type)
                elif entry_deadline_status == "currently_due":
                    requirements_detail["currently_due"].append(entry_type)
                elif entry_deadline_status == "eventually_due":
                    requirements_detail["eventually_due"].append(entry_type)
            
            # 检查是否有禁用原因
            if deadline_status and deadline_status != "eventually_due":
                requirements_detail["disabled_reason"] = deadline_status
            
            logger.info(f"✅ 账户 {current_user.stripe_account_id} 是 V2 账户")
            
        except stripe.error.StripeError as v2_err:
            # 如果 V2 API 失败（可能是 V1 账户），尝试 V1 API
            error_message = str(v2_err)
            if "v1_account_instead_of_v2_account" in error_message or "V1 Accounts cannot be used" in error_message:
                logger.info(f"ℹ️ 账户 {current_user.stripe_account_id} 是 V1 账户（旧账户），使用 V1 API")
            else:
                logger.warning(f"⚠️ V2 API 检索失败，尝试 V1 API: {v2_err}")
            # 回退到 V1 API
            account = stripe.Account.retrieve(current_user.stripe_account_id)
            
            # 验证账户所有权（通过 metadata 中的 user_id）
            if not verify_account_ownership(current_user.stripe_account_id, current_user):
                logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
                raise HTTPException(
                    status_code=403,
                    detail="账户验证失败：账户不属于当前用户"
                )
            
            # V1 API 的账户状态检查
            details_submitted = account.details_submitted
            charges_enabled = account.charges_enabled
            payouts_enabled = account.payouts_enabled
            needs_onboarding = not details_submitted
            requirements_entries = []
            account_type = "v1"  # V2 API 失败，回退到 V1 API，账户类型为 V1
            
            # 从 V1 API 提取详细的需求信息
            v1_requirements = account.requirements or {}
            requirements_detail = {
                "currently_due": list(v1_requirements.get("currently_due", []) or []),
                "past_due": list(v1_requirements.get("past_due", []) or []),
                "eventually_due": list(v1_requirements.get("eventually_due", []) or []),
                "disabled_reason": v1_requirements.get("disabled_reason")
            }
        
        # 使用嵌入式组件，不创建跳转链接
        client_secret = None
        if needs_onboarding:
            try:
                onboarding_session = create_account_session_safe(current_user.stripe_account_id)
                client_secret = onboarding_session.client_secret
            except stripe.error.StripeError as e:
                logger.warning(f"Failed to create AccountSession for onboarding: {e}")
        
        return {
            "account_id": current_user.stripe_account_id,
            "account_type": account_type,  # "v1" 或 "v2"
            "details_submitted": details_submitted,
            "charges_enabled": charges_enabled,
            "payouts_enabled": payouts_enabled,
            "client_secret": client_secret,  # 用于嵌入式组件
            "needs_onboarding": needs_onboarding,
            "requirements": requirements_detail  # 详细的需求信息
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving account: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"获取账户状态失败: {str(e)}"
        )


@router.get("/account/details", response_model=schemas.StripeConnectAccountDetailsResponse)
def get_account_details(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取 Stripe Connect 账户详细信息
    
    返回账户的详细信息，包括账户ID、状态、能力、仪表板登录链接等
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 创建仪表板登录链接（Express 账户）
        dashboard_url = None
        try:
            login_link = stripe.Account.create_login_link(current_user.stripe_account_id)
            dashboard_url = login_link.url
        except stripe.error.StripeError as e:
            logger.warning(f"Failed to create dashboard login link: {e}")
            # 如果无法创建登录链接，仍然返回其他信息
        
        # 获取账户的显示名称和邮箱
        display_name = getattr(account, 'display_name', None) or getattr(account, 'business_profile', {}).get('name', None) if hasattr(account, 'business_profile') else None
        email = getattr(account, 'email', None) or current_user.email
        
        # 获取国家信息
        country = getattr(account, 'country', 'GB')
        
        # 获取账户类型
        account_type = getattr(account, 'type', 'express')
        
        # 获取地址信息
        address_info = None
        business_profile = getattr(account, 'business_profile', None)
        individual = getattr(account, 'individual', None)
        
        # 优先从 business_profile 获取地址，如果没有则从 individual 获取
        if business_profile and hasattr(business_profile, 'address'):
            address = business_profile.address
            if address:
                address_info = {
                    "line1": getattr(address, 'line1', None),
                    "line2": getattr(address, 'line2', None),
                    "city": getattr(address, 'city', None),
                    "state": getattr(address, 'state', None),
                    "postal_code": getattr(address, 'postal_code', None),
                    "country": getattr(address, 'country', country)
                }
        elif individual and hasattr(individual, 'address'):
            address = individual.address
            if address:
                address_info = {
                    "line1": getattr(address, 'line1', None),
                    "line2": getattr(address, 'line2', None),
                    "city": getattr(address, 'city', None),
                    "state": getattr(address, 'state', None),
                    "postal_code": getattr(address, 'postal_code', None),
                    "country": getattr(address, 'country', country)
                }
        
        # 获取个人/企业信息
        individual_info = None
        if individual:
            individual_info = {
                "first_name": getattr(individual, 'first_name', None),
                "last_name": getattr(individual, 'last_name', None),
                "email": getattr(individual, 'email', None),
                "phone": getattr(individual, 'phone', None),
                "dob": {
                    "day": getattr(individual.dob, 'day', None) if hasattr(individual, 'dob') and individual.dob else None,
                    "month": getattr(individual.dob, 'month', None) if hasattr(individual, 'dob') and individual.dob else None,
                    "year": getattr(individual.dob, 'year', None) if hasattr(individual, 'dob') and individual.dob else None,
                } if hasattr(individual, 'dob') and individual.dob else None
            }
        
        return {
            "account_id": account.id,
            "display_name": display_name,
            "email": email,
            "country": country,
            "type": account_type,
            "details_submitted": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "payouts_enabled": account.payouts_enabled,
            "dashboard_url": dashboard_url,
            "address": address_info,
            "individual": individual_info,
            "requirements": {
                "currently_due": account.requirements.currently_due or [],
                "eventually_due": account.requirements.eventually_due or [],
                "past_due": account.requirements.past_due or [],
            } if hasattr(account, 'requirements') else None,
            "capabilities": {
                "card_payments": getattr(account.capabilities, 'card_payments', 'inactive') if hasattr(account, 'capabilities') else 'inactive',
                "transfers": getattr(account.capabilities, 'transfers', 'inactive') if hasattr(account, 'capabilities') else 'inactive',
            } if hasattr(account, 'capabilities') else None
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving account details: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"获取账户详细信息失败: {str(e)}"
        )


@router.get("/account/balance", response_model=schemas.StripeConnectAccountBalanceResponse)
def get_account_balance(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取 Stripe Connect 账户余额
    
    返回账户的可用余额、待处理余额等
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 获取账户余额（需要以账户身份调用）
        balance = stripe.Balance.retrieve(
            stripe_account=current_user.stripe_account_id
        )
        
        # 计算总余额（可用 + 待处理）
        available_amount = sum([b.amount for b in balance.available]) if balance.available else 0
        pending_amount = sum([b.amount for b in balance.pending]) if balance.pending else 0
        total_amount = available_amount + pending_amount
        
        return {
            "available": available_amount / 100,  # 转换为货币单位
            "pending": pending_amount / 100,
            "total": total_amount / 100,
            "currency": balance.available[0].currency.upper() if balance.available else "GBP",
            "available_breakdown": [
                {
                    "amount": b.amount / 100,
                    "currency": b.currency.upper(),
                    "source_types": b.source_types
                }
                for b in balance.available
            ] if balance.available else [],
            "pending_breakdown": [
                {
                    "amount": b.amount / 100,
                    "currency": b.currency.upper(),
                    "source_types": b.source_types
                }
                for b in balance.pending
            ] if balance.pending else []
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving account balance: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"获取账户余额失败: {str(e)}"
        )


@router.get("/account/external-accounts")
def get_external_accounts(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取 Stripe Connect 账户的外部账户（银行卡）信息
    
    返回账户关联的银行卡和银行账户列表
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        # 验证账户所有权
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 获取外部账户列表（银行卡和银行账户）
        try:
            external_accounts = stripe.Account.list_external_accounts(
                current_user.stripe_account_id,
                limit=100
            )
        except stripe.error.InvalidRequestError as e:
            # 如果账户没有外部账户，Stripe 可能返回错误，但我们返回空列表
            if "No such external_account" in str(e) or "does not have" in str(e).lower():
                logger.info(f"No external accounts found for account {current_user.stripe_account_id}")
                return {
                    "external_accounts": [],
                    "total": 0
                }
            raise
        
        accounts_list = []
        if external_accounts and hasattr(external_accounts, 'data'):
            for account in external_accounts.data:
                account_info = {
                    "id": account.id,
                    "object": account.object,  # "bank_account" or "card"
                    "account": account.account if hasattr(account, 'account') else current_user.stripe_account_id,
                }
                
                if account.object == "bank_account":
                    account_info.update({
                        "bank_name": getattr(account, 'bank_name', None),
                        "last4": getattr(account, 'last4', None),
                        "routing_number": getattr(account, 'routing_number', None),
                        "currency": getattr(account, 'currency', 'GBP'),
                        "country": getattr(account, 'country', 'GB'),
                        "account_holder_name": getattr(account, 'account_holder_name', None),
                        "account_holder_type": getattr(account, 'account_holder_type', None),
                        "status": getattr(account, 'status', None),
                    })
                elif account.object == "card":
                    account_info.update({
                        "brand": getattr(account, 'brand', None),
                        "last4": getattr(account, 'last4', None),
                        "exp_month": getattr(account, 'exp_month', None),
                        "exp_year": getattr(account, 'exp_year', None),
                        "country": getattr(account, 'country', 'GB'),
                        "funding": getattr(account, 'funding', None),  # "credit", "debit", etc.
                    })
                
                accounts_list.append(account_info)
        
        return {
            "external_accounts": accounts_list,
            "total": len(accounts_list)
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving external accounts: {e}")
        # 如果是资源不存在错误，返回空列表而不是错误
        if hasattr(e, 'code') and e.code == 'resource_missing':
            return {
                "external_accounts": [],
                "total": 0
            }
        raise HTTPException(
            status_code=400,
            detail=f"获取外部账户信息失败: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Unexpected error retrieving external accounts: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"服务器错误: {str(e)}"
        )


@router.post("/account/payout", response_model=schemas.StripeConnectPayoutResponse)
def create_payout(
    payout_request: schemas.StripeConnectPayoutRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建提现请求
    
    从 Stripe Connect 账户提现到银行账户
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        # 验证账户所有权
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 获取账户余额
        balance = stripe.Balance.retrieve(
            stripe_account=current_user.stripe_account_id
        )
        
        # 计算可用余额
        available_amount = sum([b.amount for b in balance.available]) if balance.available else 0
        available_amount_decimal = available_amount / 100  # 转换为货币单位
        
        # 验证提现金额
        if payout_request.amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="提现金额必须大于 0"
            )
        
        if payout_request.amount > available_amount_decimal:
            raise HTTPException(
                status_code=400,
                detail=f"提现金额超过可用余额。可用余额: {available_amount_decimal:.2f} {balance.available[0].currency.upper() if balance.available else 'GBP'}"
            )
        
        # 创建提现（转换为便士）
        amount_pence = int(payout_request.amount * 100)
        
        payout = stripe.Payout.create(
            amount=amount_pence,
            currency=payout_request.currency.lower(),
            stripe_account=current_user.stripe_account_id,
            description=payout_request.description or "提现到银行账户"
        )
        
        return {
            "id": payout.id,
            "amount": payout.amount / 100,
            "currency": payout.currency.upper(),
            "status": payout.status,
            "created": payout.created,
            "created_at": datetime.fromtimestamp(payout.created, tz=timezone.utc).isoformat(),
            "description": payout.description
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating payout: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建提现失败: {str(e)}"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating payout: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"服务器错误: {str(e)}"
        )


@router.get("/account/transactions", response_model=schemas.StripeConnectTransactionsResponse)
def get_account_transactions(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = Query(20, ge=1, le=100),
    starting_after: Optional[str] = None
):
    """
    获取 Stripe Connect 账户交易记录
    
    返回账户的收入（charges）和支出（transfers/payouts）记录
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        transactions = []
        
        # 获取支付记录（PaymentIntents - 支付意图，包含所有支付信息）
        # 注意：在Stripe Connect中，destination charges和separate charges模式下，
        # 支付记录可能不会直接显示为Charge，而是需要通过PaymentIntent来获取
        try:
            payment_intents = stripe.PaymentIntent.list(
                limit=limit * 2,  # 获取更多记录，因为后面会去重和合并
                starting_after=starting_after,
                stripe_account=current_user.stripe_account_id
            )
            for pi in payment_intents.data:
                # 只处理成功的支付
                if pi.status == 'succeeded' and pi.amount > 0:
                    transactions.append({
                        "id": pi.id,
                        "type": "income",
                        "amount": pi.amount / 100,
                        "currency": pi.currency.upper(),
                        "description": pi.description or f"支付 #{pi.id[:12]}",
                        "status": pi.status,
                        "created": pi.created,
                        "created_at": datetime.fromtimestamp(pi.created, tz=timezone.utc).isoformat(),
                        "source": "payment_intent",
                        "metadata": pi.metadata,
                        "charge_id": pi.latest_charge if hasattr(pi, 'latest_charge') and pi.latest_charge else None
                    })
        except stripe.error.StripeError as e:
            logger.warning(f"Error retrieving payment intents: {e}")
        
        # 获取收入记录（Charges - 作为服务者收到的付款）
        try:
            charges = stripe.Charge.list(
                limit=limit * 2,  # 获取更多记录，因为后面会去重和合并
                starting_after=starting_after,
                stripe_account=current_user.stripe_account_id
            )
            for charge in charges.data:
                # 检查是否已经通过PaymentIntent添加过（避免重复）
                # 如果PaymentIntent已经有对应的charge，就不单独添加charge
                charge_already_added = any(
                    tx.get("charge_id") == charge.id or tx.get("id") == charge.id 
                    for tx in transactions
                )
                if not charge_already_added:
                    transactions.append({
                        "id": charge.id,
                        "type": "income",
                        "amount": charge.amount / 100,
                        "currency": charge.currency.upper(),
                        "description": charge.description or f"收款 #{charge.id[:12]}",
                        "status": charge.status,
                        "created": charge.created,
                        "created_at": datetime.fromtimestamp(charge.created, tz=timezone.utc).isoformat(),
                        "source": "charge",
                        "metadata": charge.metadata
                    })
        except stripe.error.StripeError as e:
            logger.warning(f"Error retrieving charges: {e}")
        
        # 获取转账记录（Transfers - 从平台账户转出的资金）
        # 优先处理 Transfer，因为它们是任务相关的收入记录
        transfer_task_ids = {}  # 存储 transfer_id -> task_id 的映射
        try:
            transfers = stripe.Transfer.list(
                limit=limit,
                starting_after=starting_after,
                destination=current_user.stripe_account_id
            )
            for transfer in transfers.data:
                # 从 metadata 中获取 task_id
                task_id = transfer.metadata.get("task_id") if transfer.metadata else None
                if task_id:
                    transfer_task_ids[transfer.id] = task_id
                
                # 查询任务标题（如果有 task_id）
                task_title = None
                if task_id:
                    try:
                        task = db.query(models.Task).filter(models.Task.id == int(task_id)).first()
                        if task:
                            task_title = task.title
                    except (ValueError, Exception) as e:
                        logger.warning(f"Error fetching task title for task_id {task_id}: {e}")
                
                # 构建描述：如果有任务标题，使用任务标题和"收入"，否则使用默认描述
                if task_title:
                    description = f"{task_title} - 收入"
                elif transfer.description and "任务" in transfer.description:
                    # 如果 description 中包含"任务"，提取任务标题（如果有）
                    # 格式可能是 "任务 #123 奖励 - 任务标题"
                    desc_parts = transfer.description.split(" - ")
                    if len(desc_parts) > 1:
                        description = f"{desc_parts[1]} - 收入"
                    else:
                        # 替换"奖励"为"收入"
                        description = transfer.description.replace("奖励", "收入")
                else:
                    description = transfer.description or f"转账 #{transfer.id[:12]}"
                
                transactions.append({
                    "id": transfer.id,
                    "type": "income",
                    "amount": transfer.amount / 100,
                    "currency": transfer.currency.upper(),
                    "description": description,
                    "status": "succeeded" if transfer.reversed is False else "reversed",
                    "created": transfer.created,
                    "created_at": datetime.fromtimestamp(transfer.created, tz=timezone.utc).isoformat(),
                    "source": "transfer",
                    "metadata": transfer.metadata,
                    "task_id": task_id  # 保存 task_id 用于去重
                })
        except stripe.error.StripeError as e:
            logger.warning(f"Error retrieving transfers: {e}")
        
        # 获取提现记录（Payouts - 从账户提现到银行账户）
        try:
            payouts = stripe.Payout.list(
                limit=limit,
                starting_after=starting_after,
                stripe_account=current_user.stripe_account_id
            )
            for payout in payouts.data:
                # 使用 payout.description 如果有，否则使用默认描述
                payout_description = payout.description if payout.description else f"提现到银行账户 #{payout.id[:12]}"
                transactions.append({
                    "id": payout.id,
                    "type": "expense",
                    "amount": payout.amount / 100,
                    "currency": payout.currency.upper(),
                    "description": payout_description,
                    "status": payout.status,
                    "created": payout.created,
                    "created_at": datetime.fromtimestamp(payout.created, tz=timezone.utc).isoformat(),
                    "source": "payout",
                    "metadata": payout.metadata
                })
        except stripe.error.StripeError as e:
            logger.warning(f"Error retrieving payouts: {e}")
        
        # 去重：优先保留 Transfer 记录（任务相关的收入）
        # 如果同一个任务有 Transfer 记录，则删除对应的 Charge 和 PaymentIntent 记录
        seen_ids = set()
        unique_transactions = []
        transfer_task_map = {}  # task_id -> transfer_id 的映射
        
        # 第一遍：收集所有 Transfer 记录（任务相关的）
        for tx in transactions:
            if tx.get("source") == "transfer" and tx.get("task_id"):
                task_id = tx.get("task_id")
                transfer_task_map[task_id] = tx.get("id")
                seen_ids.add(tx.get("id"))
                unique_transactions.append(tx)
        
        # 第二遍：添加其他记录，但排除与 Transfer 重复的 Charge 和 PaymentIntent
        for tx in transactions:
            tx_id = tx.get("id")
            charge_id = tx.get("charge_id")
            source = tx.get("source")
            
            # 如果这个交易ID已经见过，跳过
            if tx_id in seen_ids:
                continue
            
            # 如果是 Charge 或 PaymentIntent，检查是否与 Transfer 重复
            if source in ["charge", "payment_intent"]:
                # 检查 metadata 中是否有 task_id，如果有且已经有对应的 Transfer，则跳过
                metadata = tx.get("metadata", {})
                if isinstance(metadata, dict):
                    tx_task_id = metadata.get("task_id")
                    if tx_task_id and tx_task_id in transfer_task_map:
                        # 这个 Charge/PaymentIntent 对应的任务已经有 Transfer 记录，跳过
                        continue
                
                # 检查 charge_id 是否已经通过其他方式添加过
                if charge_id and any(
                    (otx.get("id") == charge_id or otx.get("charge_id") == charge_id) 
                    for otx in unique_transactions
                ):
                    continue
            
            seen_ids.add(tx_id)
            if charge_id:
                seen_ids.add(charge_id)
            unique_transactions.append(tx)
        
        # 按时间排序（最新的在前）
        unique_transactions.sort(key=lambda x: x["created"], reverse=True)
        
        # 限制返回数量
        transactions = unique_transactions[:limit]
        
        return {
            "transactions": transactions,
            "total": len(transactions),
            "has_more": len(transactions) >= limit
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving transactions: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"获取交易记录失败: {str(e)}"
        )


@router.post("/account/onboarding-session", response_model=schemas.StripeConnectAccountSessionResponse)
def create_onboarding_session(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建账户 onboarding session（用于嵌入式组件）
    
    用于重新开始或继续账户设置流程，返回 client_secret 用于嵌入式组件
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 创建 AccountSession 用于嵌入式组件
        onboarding_session = create_account_session_safe(account.id)
        
        return {
            "client_secret": onboarding_session.client_secret
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating onboarding link: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建 onboarding 链接失败: {str(e)}"
        )


@router.post("/account_session", response_model=schemas.StripeConnectAccountSessionResponse)
def create_account_session(
    request: schemas.StripeConnectAccountSessionRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建 Account Session（用于嵌入式组件）
    
    参考 stripe-sample-code/server.js 的 /account_session 端点
    返回 client_secret，前端可以使用 Stripe Connect Embedded Components
    
    支持通过 enable_payouts 参数启用 payouts 组件（用于钱包和设置页面）
    """
    try:
        account_id = request.account
        enable_payouts = getattr(request, 'enable_payouts', False)
        enable_account_management = getattr(request, 'enable_account_management', False)
        enable_account_onboarding = getattr(request, 'enable_account_onboarding', False)
        enable_payments = getattr(request, 'enable_payments', False)
        disable_stripe_user_authentication = getattr(request, 'disable_stripe_user_authentication', False)
        
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 验证账户是否属于当前用户
        # 如果用户还没有 stripe_account_id，先更新它（可能刚创建）
        db_user_session = db.query(models.User).filter(models.User.id == current_user.id).first()
        if db_user_session and not db_user_session.stripe_account_id:
            db_user_session.stripe_account_id = account_id
            db.commit()
            db.refresh(db_user_session)  # 刷新对象以确保数据是最新的
            logger.info(f"Updated user {current_user.id} with stripe_account_id: {account_id}")
        elif db_user_session and account_id != db_user_session.stripe_account_id:
            raise HTTPException(
                status_code=403,
                detail="无权访问此账户"
            )
        
        # 创建 AccountSession（完全按照官方示例代码）
        # 参考: stripe-sample-code/server.js line 12-34 和官方文档
        # https://docs.stripe.com/connect/embedded-onboarding
        # 使用辅助函数确保所有布尔值都是正确的类型
        # 如果启用 payouts、account_management 或 account_onboarding，则创建包含相应组件的 session
        account_session = create_account_session_safe(
            account_id, 
            enable_payouts=enable_payouts,
            enable_account_management=enable_account_management,
            enable_account_onboarding=enable_account_onboarding,
            enable_payments=enable_payments,
            disable_stripe_user_authentication=disable_stripe_user_authentication
        )
        
        return {
            "client_secret": account_session.client_secret
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating account session: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"创建 account session 失败: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error creating account session: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"服务器错误: {str(e)}"
        )


@router.post("/account/onboarding-session", response_model=schemas.StripeConnectAccountEmbeddedResponse)
def create_onboarding_session(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建嵌入式 onboarding session
    
    用于在 Web 和 iOS 应用中嵌入 Stripe Connect onboarding 表单
    返回 client_secret，前端可以使用 Stripe Connect Embedded Components
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        # 如果账户已完成 onboarding，返回成功
        if account.details_submitted and account.charges_enabled:
            return {
                "account_id": account.id,
                "client_secret": None,
                "account_status": account.details_submitted,
                "charges_enabled": account.charges_enabled,
                "message": "账户已完成设置"
            }
        
        # 创建 AccountSession 用于嵌入式 onboarding
        onboarding_session = create_account_session_safe(account.id)
        
        return {
            "account_id": account.id,
            "client_secret": onboarding_session.client_secret,
            "account_status": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "message": "请完成账户设置"
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating onboarding session: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建 onboarding session 失败: {str(e)}"
        )


@router.post("/webhook")
async def connect_webhook(request: Request, db: Session = Depends(get_db)):
    """
    处理 Stripe Connect Webhook 事件
    
    监听账户更新、验证等事件
    """
    import logging
    logger = logging.getLogger(__name__)
    
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    # 使用专门的 Stripe Connect Webhook Secret
    # 如果未设置，则回退到通用的 STRIPE_WEBHOOK_SECRET（向后兼容）
    endpoint_secret = os.getenv("STRIPE_CONNECT_WEBHOOK_SECRET") or os.getenv("STRIPE_WEBHOOK_SECRET")
    
    if not endpoint_secret:
        logger.error("STRIPE_CONNECT_WEBHOOK_SECRET or STRIPE_WEBHOOK_SECRET not configured")
        return {"error": "Webhook secret not configured"}, 500
    
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except ValueError as e:
        logger.error(f"Invalid payload: {e}")
        return {"error": "Invalid payload"}, 400
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {e}")
        return {"error": "Invalid signature"}, 400
    
    event_type = event["type"]
    event_data = event["data"]["object"]
    
    logger.info(f"Received Stripe Connect webhook event: {event_type}")
    
    # 处理 ping 事件（用于测试 webhook 端点）
    # ping 事件不需要任何业务逻辑，只需返回成功响应
    if event_type == "v2.core.event_destination.ping" or event_type == "ping":
        logger.info(f"Received ping event, responding with success")
        return {"status": "success", "message": "pong"}
    
    # 使用 try-except 包裹事件处理，确保所有事件都能返回响应
    try:
        # 处理账户创建事件（V1 和 V2）
        if event_type == "account.created" or event_type == "v2.core.account.created":
            account = event_data
            account_id = account.get("id")
            
            if not account_id:
                logger.warning("account.created event missing account ID")
                return {"status": "success"}
            
            # 尝试通过 metadata 查找用户
            metadata = account.get("metadata") or {}
            user_id = metadata.get("user_id")
            if user_id:
                user = db.query(models.User).filter(models.User.id == int(user_id)).first()
                if user:
                    # 如果用户还没有 stripe_account_id，则设置
                    if not user.stripe_account_id:
                        try:
                            user.stripe_account_id = account_id
                            db.add(user)  # 确保对象被添加到会话
                            db.commit()
                            db.refresh(user)  # 刷新对象
                            
                            # 验证保存是否成功
                            db_user = db.query(models.User).filter(models.User.id == user.id).first()
                            if db_user and db_user.stripe_account_id == account_id:
                                logger.info(f"✅ Webhook verified: Account {account_id} saved to database for user {user.id}")
                            else:
                                logger.error(f"❌ Webhook failed to verify: stripe_account_id not saved for user {user.id}")
                                # 尝试再次保存
                                if db_user:
                                    db_user.stripe_account_id = account_id
                                    db.commit()
                                    db.refresh(db_user)
                                    logger.info(f"Webhook retry: Account {account_id} saved to database for user {user.id}")
                        except Exception as e:
                            # 捕获唯一性约束错误（如果账户ID已被其他用户使用）
                            db.rollback()
                            if "unique" in str(e).lower() or "duplicate" in str(e).lower():
                                logger.warning(f"Account {account_id} already assigned to another user, skipping for user {user.id}")
                            else:
                                logger.error(f"Error saving account_id for user {user.id}: {e}", exc_info=True)
                    else:
                        # 用户已经有账户，检查是否是同一个账户
                        if user.stripe_account_id == account_id:
                            logger.info(f"Account created event for user {user.id}, account_id already set: {user.stripe_account_id}")
                        else:
                            logger.warning(
                                f"Account created event for user {user.id}, but user already has different account: "
                                f"{user.stripe_account_id} (new: {account_id}). "
                                f"Rejecting new account creation - each user can only have one Stripe Connect account."
                            )
                            # 不更新，保持现有账户（每个用户只能有一个账户）
                            # 验证现有账户的 metadata 确保它属于该用户
                            try:
                                existing_account = stripe.Account.retrieve(user.stripe_account_id)
                                existing_metadata = getattr(existing_account, 'metadata', {})
                                if isinstance(existing_metadata, dict):
                                    existing_user_id = existing_metadata.get('user_id')
                                else:
                                    existing_user_id = getattr(existing_metadata, 'user_id', None)
                                
                                if existing_user_id and str(existing_user_id) == str(user.id):
                                    logger.info(f"Existing account {user.stripe_account_id} verified to belong to user {user.id}")
                                else:
                                    logger.error(
                                        f"Existing account {user.stripe_account_id} metadata.user_id={existing_user_id} "
                                        f"doesn't match user.id={user.id}. This is a data inconsistency issue."
                                    )
                            except stripe.error.StripeError as e:
                                logger.error(f"Error verifying existing account {user.stripe_account_id}: {e}")
                else:
                    logger.warning(f"Account.created event for account {account_id} with metadata user_id {user_id}, but user not found")
            else:
                logger.warning(f"Account.created event for account {account_id}, but no metadata.user_id found")
        
        # 处理账户更新事件（V1 和 V2）
        elif event_type == "account.updated" or event_type == "v2.core.account.updated":
            account = event_data
            account_id = account.get("id")
            
            if not account_id:
                logger.warning("account.updated event missing account ID")
                return {"status": "success"}
            
            # 通过 stripe_account_id 查找用户（更可靠）
            user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
            
            if user:
                # 判断是 V1 还是 V2 API 事件
                is_v2_event = event_type == "v2.core.account.updated"
                
                if is_v2_event:
                    # V2 API 使用 requirements 和 configuration 字段
                    requirements = account.get("requirements", {})
                    summary = requirements.get("summary", {})
                    minimum_deadline = summary.get("minimum_deadline", {})
                    deadline_status = minimum_deadline.get("status")
                    details_submitted = not deadline_status or deadline_status == "eventually_due"
                    
                    # 检查 merchant 配置中的 capabilities
                    configuration = account.get("configuration", {})
                    merchant = configuration.get("merchant", {})
                    capabilities = merchant.get("capabilities", {})
                    card_payments = capabilities.get("card_payments", {})
                    charges_enabled = card_payments.get("status") == "active"
                    
                    # 检查 recipient 配置中的 payouts
                    recipient = configuration.get("recipient", {})
                    recipient_capabilities = recipient.get("capabilities", {})
                    stripe_balance = recipient_capabilities.get("stripe_balance", {})
                    payouts = stripe_balance.get("payouts", {})
                    payouts_enabled = payouts.get("status") == "active"
                    
                    logger.info(f"Account updated (V2) for user {user.id}: account_id={account_id}, details_submitted={details_submitted}, charges_enabled={charges_enabled}, payouts_enabled={payouts_enabled}")
                else:
                    # V1 API 使用传统字段
                    details_submitted = account.get("details_submitted", False)
                    charges_enabled = account.get("charges_enabled", False)
                    payouts_enabled = account.get("payouts_enabled", False)
                    
                    logger.info(f"Account updated (V1) for user {user.id}: account_id={account_id}, details_submitted={details_submitted}, charges_enabled={charges_enabled}, payouts_enabled={payouts_enabled}")
                
                # 检查状态变化（对 V1 和 V2 都适用）
                event_data = event.get("data") or {}
                previous_attributes = event_data.get("previous_attributes", {})
                was_charges_enabled = previous_attributes.get("charges_enabled", charges_enabled)
                was_payouts_enabled = previous_attributes.get("payouts_enabled", payouts_enabled)
                
                # 如果账户刚刚激活，记录日志
                if not was_charges_enabled and charges_enabled:
                    logger.info(f"Stripe Connect account activated for user {user.id}: account_id={account_id}, charges_enabled={charges_enabled}, payouts_enabled={payouts_enabled}")
                
                # 如果账户刚刚启用提现，记录日志
                if not was_payouts_enabled and payouts_enabled:
                    logger.info(f"Stripe Connect account payouts enabled for user {user.id}: account_id={account_id}")
            else:
                # 如果通过 account_id 找不到，尝试通过 metadata
                metadata = account.get("metadata") or {}
                user_id = metadata.get("user_id")
                if user_id:
                    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
                    if user:
                        # 更新用户的 stripe_account_id（可能之前没有保存）
                        user.stripe_account_id = account_id
                        db.commit()
                        logger.info(f"Updated stripe_account_id for user {user_id} from account.updated webhook")
                    else:
                        logger.warning(f"Account.updated event for account {account_id} with metadata user_id {user_id}, but user not found")
                else:
                    logger.warning(f"Account.updated event for account {account_id}, but no matching user found (no metadata.user_id)")
        
        # 处理账户关闭事件（V2 API）
        elif event_type == "v2.core.account.closed":
            account = event_data
            account_id = account.get("id")
            
            if not account_id:
                logger.warning(f"{event_type} event missing account ID")
                return {"status": "success"}
            
            # 通过 stripe_account_id 查找用户
            user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
            
            if user:
                user.stripe_account_id = None
                db.commit()
                logger.info(f"Stripe Connect account (V2) closed for user {user.id}: account_id={account_id}, cleared stripe_account_id")
            else:
                # 尝试通过 metadata 查找用户（与 deauthorized 一致）
                metadata = account.get("metadata") or {}
                user_id_meta = metadata.get("user_id")
                if user_id_meta:
                    user = db.query(models.User).filter(models.User.id == int(user_id_meta)).first()
                    if user and user.stripe_account_id == account_id:
                        user.stripe_account_id = None
                        db.commit()
                        logger.info(f"Stripe Connect account (V2) closed for user {user.id} (via metadata): account_id={account_id}, cleared stripe_account_id")
                    else:
                        logger.warning(f"{event_type} event for account {account_id}, user_id from metadata {user_id_meta} not found or stripe_account_id mismatch")
                else:
                    logger.warning(f"{event_type} event for account {account_id}, but no matching user found")
        
        # 处理账户要求更新事件（V2 API，支持点号和方括号两种事件名）
        elif event_type == "v2.core.account.requirements.updated" or event_type == "v2.core.account[requirements].updated":
            account = event_data
            account_id = account.get("id")
            
            if not account_id:
                logger.warning(f"{event_type} event missing account ID")
                return {"status": "success"}
            
            # 通过 stripe_account_id 查找用户
            user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
            
            if user:
                # V2 API 使用 requirements 字段
                requirements = account.get("requirements", {})
                currently_due = requirements.get("currently_due", [])
                eventually_due = requirements.get("eventually_due", [])
                past_due = requirements.get("past_due", [])
                
                # 检查是否有最小截止日期状态
                minimum_deadline = requirements.get("minimum_deadline")
                deadline_status = minimum_deadline.get("status") if minimum_deadline else None
                
                # 检查能力状态
                configuration = account.get("configuration") or {}
                merchant = configuration.get("merchant") or {}
                capabilities = merchant.get("capabilities", {})
                card_payments = capabilities.get("card_payments", {})
                charges_enabled = card_payments.get("status") == "active"
                
                # 检查状态变化
                event_data = event.get("data") or {}
                previous_attributes = event_data.get("previous_attributes", {})
                prev_requirements = previous_attributes.get("requirements", {})
                prev_currently_due = prev_requirements.get("currently_due", [])
                
                # 如果账户刚刚完成验证（currently_due 从有到无）
                if prev_currently_due and len(prev_currently_due) > 0 and len(currently_due) == 0:
                    logger.info(f"Stripe Connect account (V2) verification completed for user {user.id}: account_id={account_id}")
                
                # 如果账户有 past_due 要求，记录警告
                if past_due and len(past_due) > 0:
                    logger.warning(f"Stripe Connect account (V2) has past_due requirements for user {user.id}: account_id={account_id}, past_due={past_due}")
                
                # 如果截止日期状态变为 past_due
                if deadline_status == "past_due":
                    logger.warning(f"Stripe Connect account (V2) deadline status is past_due for user {user.id}: account_id={account_id}")
                
                logger.info(
                    f"Account requirements updated (V2) for user {user.id}: account_id={account_id}, "
                    f"currently_due={len(currently_due)}, eventually_due={len(eventually_due)}, "
                    f"past_due={len(past_due)}, charges_enabled={charges_enabled}"
                )
            else:
                # 如果通过 account_id 找不到，尝试通过 metadata
                metadata = account.get("metadata") or {}
                user_id = metadata.get("user_id")  # 从 metadata 获取 user_id
                if user_id:
                    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
                    if user:
                        # 更新用户的 stripe_account_id（可能之前没有保存）
                        user.stripe_account_id = account_id
                        db.commit()
                        logger.info(f"Updated stripe_account_id for user {user_id} from {event_type} webhook")
                    else:
                        logger.warning(f"{event_type} event for account {account_id} with metadata user_id {user_id}, but user not found")
                else:
                    logger.warning(f"{event_type} event for account {account_id}, but no matching user found (no metadata.user_id)")
        
        # 处理账户能力更新事件（如支付能力、提现能力等）
        elif event_type == "capability.updated":
            capability = event_data
            account_id = capability.get("account")
            
            if account_id:
                user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
                if user:
                    status = capability.get("status")
                    capability_type = capability.get("type")
                    logger.info(f"Capability updated for user {user.id}: account_id={account_id}, type={capability_type}, status={status}")
                else:
                    logger.warning(f"Capability.updated event for account {account_id}, but no matching user found")
        
        # 处理外部账户创建事件（银行账户等）
        elif event_type == "account.external_account.created":
            external_account = event_data
            account_id = external_account.get("account")
            
            if account_id:
                user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
                if user:
                    account_type = external_account.get("object")  # "bank_account" or "card"
                    logger.info(f"External account created for user {user.id}: account_id={account_id}, type={account_type}")
        
        # 处理 V2 API 配置更新事件
        elif event_type in [
            "v2.core.account[configuration.merchant].updated",
            "v2.core.account[configuration.merchant].capability_status_updated",
            "v2.core.account[configuration.recipient].updated",
            "v2.core.account[configuration.recipient].capability_status_updated",
            "v2.core.account[configuration.customer].updated",
            "v2.core.account[configuration.customer].capability_status_updated",
            "v2.core.account[defaults].updated",
            "v2.core.account[identity].updated"
        ]:
            account = event_data
            account_id = account.get("id")
            
            if not account_id:
                logger.warning(f"{event_type} event missing account ID")
                return {"status": "success"}
            
            # 通过 stripe_account_id 查找用户
            user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
            
            if user:
                # 根据事件类型记录不同的信息
                if "configuration.merchant" in event_type:
                    configuration = account.get("configuration", {})
                    merchant = configuration.get("merchant", {})
                    capabilities = merchant.get("capabilities", {})
                    logger.info(f"Account merchant configuration updated (V2) for user {user.id}: account_id={account_id}, capabilities={capabilities}")
                elif "configuration.recipient" in event_type:
                    configuration = account.get("configuration", {})
                    recipient = configuration.get("recipient", {})
                    capabilities = recipient.get("capabilities", {})
                    logger.info(f"Account recipient configuration updated (V2) for user {user.id}: account_id={account_id}, capabilities={capabilities}")
                elif "identity" in event_type:
                    identity = account.get("identity", {})
                    logger.info(f"Account identity updated (V2) for user {user.id}: account_id={account_id}")
                else:
                    logger.info(f"Account configuration updated (V2) for user {user.id}: account_id={account_id}, event={event_type}")
            else:
                logger.warning(f"{event_type} event for account {account_id}, but no matching user found")
        
        # 处理账户人员事件（V2 API）
        elif event_type in [
            "v2.core.account_person.created",
            "v2.core.account_person.updated",
            "v2.core.account_person.deleted"
        ]:
            person = event_data
            account_id = person.get("account")
            
            if account_id:
                user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
                if user:
                    person_id = person.get("id")
                    logger.info(f"Account person {event_type} (V2) for user {user.id}: account_id={account_id}, person_id={person_id}")
                else:
                    logger.warning(f"{event_type} event for account {account_id}, but no matching user found")
        
        # 处理账户取消授权事件
        elif event_type == "account.application.deauthorized":
            account = event_data
            account_id = account.get("id")
            
            if account_id:
                # 通过 stripe_account_id 查找用户
                user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
                if user:
                    user.stripe_account_id = None
                    db.commit()
                    logger.info(f"Account deauthorized for user {user.id}: account_id={account_id}")
                else:
                    # 尝试通过 metadata
                    metadata = account.get("metadata") or {}
                    user_id = metadata.get("user_id")
                    if user_id:
                        user = db.query(models.User).filter(models.User.id == int(user_id)).first()
                        if user:
                            user.stripe_account_id = None
                            db.commit()
                            logger.info(f"Account deauthorized for user {user.id} (found via metadata)")
        
        # 对于未明确处理的事件，记录日志但返回成功
        if not any([
            event_type == "account.created" or event_type == "v2.core.account.created",
            event_type == "account.updated" or event_type == "v2.core.account.updated",
            event_type == "v2.core.account.closed",
            event_type == "v2.core.account.requirements.updated",
            event_type == "capability.updated",
            event_type == "account.external_account.created",
            event_type in [
                "v2.core.account[configuration.merchant].updated",
                "v2.core.account[configuration.merchant].capability_status_updated",
                "v2.core.account[configuration.recipient].updated",
                "v2.core.account[configuration.recipient].capability_status_updated",
                "v2.core.account[configuration.customer].updated",
                "v2.core.account[configuration.customer].capability_status_updated",
                "v2.core.account[defaults].updated",
                "v2.core.account[identity].updated"
            ],
            event_type in [
                "v2.core.account_person.created",
                "v2.core.account_person.updated",
                "v2.core.account_person.deleted"
            ],
            event_type == "account.application.deauthorized"
        ]):
            logger.info(f"Unhandled event type: {event_type}, returning success")
    
    except Exception as e:
        # 捕获所有异常，记录错误但返回成功响应，避免 Stripe 重试
        logger.error(f"Error processing webhook event {event_type}: {e}", exc_info=True)
        # 仍然返回成功，避免 Stripe 不断重试
        # 如果业务逻辑失败，应该通过其他方式处理（如后台任务重试）
        return {"status": "success", "error": "Event processing failed but acknowledged"}
    
    return {"status": "success"}

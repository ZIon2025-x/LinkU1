"""
Stripe Connect 账户管理 API 路由
"""
import logging
import os
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
import stripe

from app import schemas, models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stripe/connect", tags=["Stripe Connect"])

# 设置 Stripe API Key
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")


@router.post("/account/create", response_model=schemas.StripeConnectAccountResponse)
def create_connect_account(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建 Stripe Connect Express Account
    
    为当前用户创建 Stripe Connect Express 账户，用于接收任务奖励支付
    """
    try:
        # 检查用户是否已有 Stripe Connect 账户
        if current_user.stripe_account_id:
            # 检查账户状态
            try:
                account = stripe.Account.retrieve(current_user.stripe_account_id)
                return {
                    "account_id": account.id,
                    "onboarding_url": None,
                    "account_status": account.details_submitted,
                    "message": "账户已存在"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account: {e}")
                # 如果账户不存在，清除记录
                current_user.stripe_account_id = None
                db.commit()
        
        # 创建 Express Account
        # 注意：测试环境使用 sk_test_...，生产环境使用 sk_live_...
        account = stripe.Account.create(
            type="express",
            country="GB",  # 英国
            email=current_user.email or f"user_{current_user.id}@link2ur.com",
            capabilities={
                "card_payments": {"requested": True},
                "transfers": {"requested": True},
            },
            metadata={
                "user_id": str(current_user.id),
                "platform": "LinkU",
                "user_name": current_user.name
            }
        )
        
        # 保存账户 ID 到用户记录
        current_user.stripe_account_id = account.id
        db.commit()
        
        logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id}")
        
        # 创建账户链接用于 onboarding
        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
        account_link = stripe.AccountLink.create(
            account=account.id,
            refresh_url=f"{frontend_url}/stripe/connect/refresh",
            return_url=f"{frontend_url}/stripe/connect/success",
            type="account_onboarding",
        )
        
        return {
            "account_id": account.id,
            "onboarding_url": account_link.url,
            "account_status": account.details_submitted,
            "message": "账户创建成功，请完成账户设置"
        }
        
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
    """
    try:
        # 检查用户是否已有 Stripe Connect 账户
        if current_user.stripe_account_id:
            # 检查账户状态
            try:
                account = stripe.Account.retrieve(current_user.stripe_account_id)
                
                # 如果账户已完成 onboarding，返回成功
                if account.details_submitted:
                    return {
                        "account_id": account.id,
                        "client_secret": None,
                        "account_status": account.details_submitted,
                        "charges_enabled": account.charges_enabled,
                        "message": "账户已存在且已完成设置"
                    }
                
                # 如果账户未完成 onboarding，创建 onboarding session
                onboarding_session = stripe.AccountSession.create(
                    account=account.id,
                    components={
                        "account_onboarding": {
                            "enabled": True
                        }
                    }
                )
                
                return {
                    "account_id": account.id,
                    "client_secret": onboarding_session.client_secret,
                    "account_status": account.details_submitted,
                    "charges_enabled": account.charges_enabled,
                    "message": "账户已存在，请完成设置"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account: {e}")
                # 如果账户不存在，清除记录
                current_user.stripe_account_id = None
                db.commit()
        
        # 创建 Express Account
        account = stripe.Account.create(
            type="express",
            country="GB",  # 英国
            email=current_user.email or f"user_{current_user.id}@link2ur.com",
            capabilities={
                "card_payments": {"requested": True},
                "transfers": {"requested": True},
            },
            metadata={
                "user_id": str(current_user.id),
                "platform": "LinkU",
                "user_name": current_user.name
            }
        )
        
        # 保存账户 ID 到用户记录
        current_user.stripe_account_id = account.id
        db.commit()
        
        logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id}")
        
        # 创建 AccountSession 用于嵌入式 onboarding
        onboarding_session = stripe.AccountSession.create(
            account=account.id,
            components={
                "account_onboarding": {
                    "enabled": True
                }
            }
        )
        
        return {
            "account_id": account.id,
            "client_secret": onboarding_session.client_secret,
            "account_status": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "message": "账户创建成功，请完成账户设置"
        }
        
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


@router.get("/account/status", response_model=schemas.StripeConnectAccountStatusResponse)
def get_account_status(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    获取 Stripe Connect 账户状态
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        # 检查是否需要重新 onboarding
        needs_onboarding = not account.details_submitted
        
        onboarding_url = None
        if needs_onboarding:
            frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
            account_link = stripe.AccountLink.create(
                account=account.id,
                refresh_url=f"{frontend_url}/stripe/connect/refresh",
                return_url=f"{frontend_url}/stripe/connect/success",
                type="account_onboarding",
            )
            onboarding_url = account_link.url
        
        return {
            "account_id": account.id,
            "details_submitted": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "payouts_enabled": account.payouts_enabled,
            "onboarding_url": onboarding_url,
            "needs_onboarding": needs_onboarding,
            "requirements": {
                "currently_due": account.requirements.currently_due or [],
                "eventually_due": account.requirements.eventually_due or [],
                "past_due": account.requirements.past_due or [],
            } if hasattr(account, 'requirements') else None
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error retrieving account: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"获取账户状态失败: {str(e)}"
        )


@router.post("/account/onboarding-link", response_model=schemas.StripeConnectAccountLinkResponse)
def create_onboarding_link(
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建账户 onboarding 链接
    
    用于重新开始或继续账户设置流程
    """
    if not current_user.stripe_account_id:
        raise HTTPException(
            status_code=404,
            detail="未找到 Stripe Connect 账户，请先创建账户"
        )
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
        account_link = stripe.AccountLink.create(
            account=account.id,
            refresh_url=f"{frontend_url}/stripe/connect/refresh",
            return_url=f"{frontend_url}/stripe/connect/success",
            type="account_onboarding",
        )
        
        return {
            "onboarding_url": account_link.url,
            "expires_at": account_link.expires_at
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error creating onboarding link: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"创建 onboarding 链接失败: {str(e)}"
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
        onboarding_session = stripe.AccountSession.create(
            account=account.id,
            components={
                "account_onboarding": {
                    "enabled": True
                }
            }
        )
        
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
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    
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
    
    # 处理账户更新事件
    if event_type == "account.updated":
        account = event_data
        user_id = account.get("metadata", {}).get("user_id")
        
        if user_id:
            user = db.query(models.User).filter(models.User.id == user_id).first()
            if user:
                # 可以在这里更新用户的账户状态
                logger.info(f"Account updated for user {user_id}: details_submitted={account.get('details_submitted')}")
    
    # 处理账户验证事件
    elif event_type == "account.application.deauthorized":
        account = event_data
        user_id = account.get("metadata", {}).get("user_id")
        
        if user_id:
            user = db.query(models.User).filter(models.User.id == user_id).first()
            if user:
                user.stripe_account_id = None
                db.commit()
                logger.info(f"Account deauthorized for user {user_id}")
    
    return {"status": "success"}

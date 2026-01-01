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
    注意：每个用户只能有一个 Stripe Connect 账户
    """
    try:
        # 检查用户是否已有 Stripe Connect 账户（每个用户只能有一个账户）
        if current_user.stripe_account_id:
            # 检查账户状态 (使用 Accounts v2 API)
            try:
                try:
                    account = stripe.v2.core.accounts.retrieve(
                        current_user.stripe_account_id,
                        include=['requirements', 'configuration.recipient']
                    )
                    # v2 API 返回的账户状态检查方式不同
                    summary_status = account.requirements.summary.minimum_deadline.status if hasattr(account.requirements, 'summary') else None
                    details_submitted = not summary_status or summary_status == 'eventually_due'
                except AttributeError:
                    # 如果 Stripe SDK 版本不支持 v2 API，回退到旧版 API
                    account = stripe.Account.retrieve(current_user.stripe_account_id)
                    details_submitted = account.details_submitted
                
                return {
                    "account_id": account.id,
                    "onboarding_url": None,
                    "account_status": details_submitted,
                    "message": "账户已存在"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account: {e}")
                # 如果账户不存在，清除记录
                current_user.stripe_account_id = None
                db.commit()
        
        # 创建 Express Account (完全按照官方示例代码)
        # 参考: stripe-sample-code/server.js line 89-114
        try:
            account = stripe.v2.core.accounts.create({
                "display_name": current_user.email or f"user_{current_user.id}@link2ur.com",
                "contact_email": current_user.email or f"user_{current_user.id}@link2ur.com",
                "dashboard": "express",
                "defaults": {
                    "responsibilities": {
                        "fees_collector": "application",
                        "losses_collector": "application",
                    },
                },
                "identity": {
                    "country": "GB",
                    "entity_type": "company",
                },
                "configuration": {
                    "recipient": {
                        "capabilities": {
                            "stripe_balance": {
                                "stripe_transfers": {
                                    "requested": True,
                                },
                            },
                        },
                    },
                },
                "metadata": {
                    "user_id": str(current_user.id),
                    "platform": "LinkU",
                    "user_name": current_user.name
                }
            })
            logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id}")
        except AttributeError:
            # 如果 Stripe SDK 版本不支持 v2 API，回退到旧版 API
            logger.warning("Stripe SDK does not support v2 API, falling back to legacy API")
            account = stripe.Account.create(
                type="express",
                country="GB",
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
            logger.info(f"Created Stripe Connect account {account.id} using legacy API for user {current_user.id}")
        except Exception as e:
            logger.error(f"Error creating Stripe Connect account: {e}")
            raise HTTPException(
                status_code=400,
                detail=f"创建 Stripe 账户失败: {str(e)}"
            )
        
        # 再次检查用户是否已有账户（防止并发创建）
        db.refresh(current_user)
        if current_user.stripe_account_id:
            logger.warning(f"User {current_user.id} already has a Stripe account {current_user.stripe_account_id}, skipping creation of {account.id}")
            # 如果用户已经有账户，返回现有账户信息
            try:
                existing_account = stripe.Account.retrieve(current_user.stripe_account_id)
                frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
                try:
                    account_link = stripe.v2.core.accountLinks.create({
                        "account": existing_account.id,
                        "use_case": {
                            "type": "account_onboarding",
                            "account_onboarding": {
                                "configurations": ["recipient"],
                                "refresh_url": f"{frontend_url}/stripe/connect/refresh",
                                "return_url": f"{frontend_url}/stripe/connect/success?accountId={existing_account.id}",
                            },
                        },
                    })
                except AttributeError:
                    account_link = stripe.AccountLink.create(
                        account=existing_account.id,
                        refresh_url=f"{frontend_url}/stripe/connect/refresh",
                        return_url=f"{frontend_url}/stripe/connect/success",
                        type="account_onboarding",
                    )
                return {
                    "account_id": existing_account.id,
                    "onboarding_url": account_link.url,
                    "account_status": existing_account.details_submitted,
                    "message": "您已经有一个 Stripe 账户，请使用现有账户完成设置"
                }
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving existing account: {e}")
                # 如果现有账户无效，清除记录并继续
                current_user.stripe_account_id = None
                db.commit()
        
        # 保存账户 ID 到用户记录
        try:
            current_user.stripe_account_id = account.id
            db.commit()
            db.refresh(current_user)  # 刷新对象以确保数据是最新的
            logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id}, saved to database")
        except Exception as db_err:
            # 捕获唯一性约束错误（虽然理论上不应该发生，因为我们已经检查过了）
            db.rollback()
            if "unique" in str(db_err).lower() or "duplicate" in str(db_err).lower():
                logger.warning(f"User {current_user.id} already has a Stripe account (database constraint violation)")
                raise HTTPException(
                    status_code=400,
                    detail="您已经有一个 Stripe Connect 账户，每个用户只能有一个账户"
                )
            raise
        
        # 创建账户链接用于 onboarding (完全按照官方示例代码)
        # 参考: stripe-sample-code/server.js line 126-136
        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
        try:
            account_link = stripe.v2.core.accountLinks.create({
                "account": account.id,
                "use_case": {
                    "type": "account_onboarding",
                    "account_onboarding": {
                        "configurations": ["recipient"],
                        "refresh_url": f"{frontend_url}/stripe/connect/refresh",
                        "return_url": f"{frontend_url}/stripe/connect/success?accountId={account.id}",
                    },
                },
            })
        except AttributeError:
            # 如果 Stripe SDK 版本不支持 v2 API，回退到旧版 API
            logger.warning("Stripe SDK does not support v2 AccountLink API, falling back to legacy API")
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
        
        # 创建 Express Account (完全按照官方示例代码)
        # 参考: stripe-sample-code/server.js line 89-114
        account = None
        try:
            # 首先尝试使用 v2 API
            if hasattr(stripe, 'v2') and hasattr(stripe.v2, 'core') and hasattr(stripe.v2.core, 'accounts'):
                try:
                    account = stripe.v2.core.accounts.create({
                        "display_name": current_user.email or f"user_{current_user.id}@link2ur.com",
                        "contact_email": current_user.email or f"user_{current_user.id}@link2ur.com",
                        "dashboard": "express",
                        "defaults": {
                            "responsibilities": {
                                "fees_collector": "application",
                                "losses_collector": "application",
                            },
                        },
                        "identity": {
                            "country": "GB",
                            "entity_type": "company",
                        },
                        "configuration": {
                            "recipient": {
                                "capabilities": {
                                    "stripe_balance": {
                                        "stripe_transfers": {
                                            "requested": True,
                                        },
                                    },
                                },
                            },
                        },
                        "metadata": {
                            "user_id": str(current_user.id),
                            "platform": "LinkU",
                            "user_name": current_user.name
                        }
                    })
                    logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id} using v2 API")
                except stripe.error.StripeError as v2_err:
                    logger.warning(f"v2 API failed: {v2_err}, falling back to legacy API")
                    raise  # 重新抛出，让外层 catch 处理
            else:
                raise AttributeError("v2 API not available")
        except (AttributeError, stripe.error.StripeError) as e:
            # 如果 Stripe SDK 版本不支持 v2 API 或 v2 API 失败，回退到旧版 API
            logger.warning(f"Stripe SDK v2 API not available or failed ({e}), falling back to legacy API")
            try:
                account = stripe.Account.create(
                    type="express",
                    country="GB",
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
                logger.info(f"Created Stripe Connect account {account.id} using legacy API for user {current_user.id}")
            except stripe.error.StripeError as legacy_err:
                logger.error(f"Stripe error creating account with legacy API: {legacy_err}")
                raise HTTPException(
                    status_code=400,
                    detail=f"创建 Stripe 账户失败: {str(legacy_err)}"
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
        db.refresh(current_user)
        if current_user.stripe_account_id:
            logger.warning(f"User {current_user.id} already has a Stripe account {current_user.stripe_account_id}, skipping creation of {account.id}")
            # 如果用户已经有账户，返回现有账户信息
            try:
                existing_account = stripe.Account.retrieve(current_user.stripe_account_id)
                if existing_account.details_submitted:
                    return {
                        "account_id": existing_account.id,
                        "client_secret": None,
                        "account_status": existing_account.details_submitted,
                        "charges_enabled": existing_account.charges_enabled,
                        "message": "您已经有一个 Stripe 账户且已完成设置"
                    }
                # 如果账户未完成 onboarding，创建 onboarding session
                onboarding_session = stripe.AccountSession.create(
                    account=existing_account.id,
                    components={
                        "account_onboarding": {
                            "enabled": True
                        }
                    }
                )
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
            current_user.stripe_account_id = account.id
            db.commit()
            db.refresh(current_user)  # 刷新对象以确保数据是最新的
            logger.info(f"Created Stripe Connect account {account.id} for user {current_user.id}, saved to database")
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
        
        # 创建 AccountSession 用于嵌入式 onboarding
        try:
            onboarding_session = stripe.AccountSession.create(
                account=account.id,
                components={
                    "account_onboarding": {
                        "enabled": True
                    }
                }
            )
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
            "onboarding_url": None,
            "needs_onboarding": True,
            "requirements": None
        }
    
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


@router.post("/account_session", response_model=schemas.StripeConnectAccountSessionResponse)
def create_account_session(
    request: schemas.StripeConnectAccountSessionRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    创建 Account Session（用于嵌入式 onboarding）
    
    参考 stripe-sample-code/server.js 的 /account_session 端点
    返回 client_secret，前端可以使用 Stripe Connect Embedded Components
    """
    try:
        account_id = request.account
        
        # 验证账户是否属于当前用户
        # 如果用户还没有 stripe_account_id，先更新它（可能刚创建）
        if not current_user.stripe_account_id:
            current_user.stripe_account_id = account_id
            db.commit()
            db.refresh(current_user)  # 刷新对象以确保数据是最新的
            logger.info(f"Updated user {current_user.id} with stripe_account_id: {account_id}")
        elif account_id != current_user.stripe_account_id:
            raise HTTPException(
                status_code=403,
                detail="无权访问此账户"
            )
        
        # 创建 AccountSession（完全按照官方示例代码）
        # 参考: stripe-sample-code/server.js line 12-34
        account_session = stripe.AccountSession.create(
            account=account_id,
            components={
                "account_onboarding": {
                    "enabled": True
                }
            }
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
    
    logger.info(f"Received Stripe Connect webhook event: {event_type}")
    
    # 处理账户创建事件
    if event_type == "account.created":
        account = event_data
        account_id = account.get("id")
        
        if not account_id:
            logger.warning("account.created event missing account ID")
            return {"status": "success"}
        
        # 尝试通过 metadata 查找用户
        user_id = account.get("metadata", {}).get("user_id")
        if user_id:
            user = db.query(models.User).filter(models.User.id == int(user_id)).first()
            if user:
                # 如果用户还没有 stripe_account_id，则设置
                if not user.stripe_account_id:
                    try:
                        user.stripe_account_id = account_id
                        db.commit()
                        logger.info(f"Account created for user {user.id}: account_id={account_id}")
                    except Exception as e:
                        # 捕获唯一性约束错误（如果账户ID已被其他用户使用）
                        db.rollback()
                        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
                            logger.warning(f"Account {account_id} already assigned to another user, skipping for user {user.id}")
                        else:
                            logger.error(f"Error saving account_id for user {user.id}: {e}")
                else:
                    # 用户已经有账户，检查是否是同一个账户
                    if user.stripe_account_id == account_id:
                        logger.info(f"Account created event for user {user.id}, account_id already set: {user.stripe_account_id}")
                    else:
                        logger.warning(f"Account created event for user {user.id}, but user already has different account: {user.stripe_account_id} (new: {account_id})")
                        # 不更新，保持现有账户（每个用户只能有一个账户）
            else:
                logger.warning(f"Account.created event for account {account_id} with metadata user_id {user_id}, but user not found")
        else:
            logger.warning(f"Account.created event for account {account_id}, but no metadata.user_id found")
    
    # 处理账户更新事件
    elif event_type == "account.updated":
        account = event_data
        account_id = account.get("id")
        
        if not account_id:
            logger.warning("account.updated event missing account ID")
            return {"status": "success"}
        
        # 通过 stripe_account_id 查找用户（更可靠）
        user = db.query(models.User).filter(models.User.stripe_account_id == account_id).first()
        
        if user:
            details_submitted = account.get("details_submitted", False)
            charges_enabled = account.get("charges_enabled", False)
            payouts_enabled = account.get("payouts_enabled", False)
            
            # 检查状态变化
            previous_attributes = event.get("data", {}).get("previous_attributes", {})
            was_charges_enabled = previous_attributes.get("charges_enabled", charges_enabled)
            was_payouts_enabled = previous_attributes.get("payouts_enabled", payouts_enabled)
            
            # 如果账户刚刚激活，记录日志
            if not was_charges_enabled and charges_enabled:
                logger.info(f"Stripe Connect account activated for user {user.id}: account_id={account_id}, charges_enabled={charges_enabled}, payouts_enabled={payouts_enabled}")
            
            # 如果账户刚刚启用提现，记录日志
            if not was_payouts_enabled and payouts_enabled:
                logger.info(f"Stripe Connect account payouts enabled for user {user.id}: account_id={account_id}")
            
            logger.info(f"Account updated for user {user.id}: account_id={account_id}, details_submitted={details_submitted}, charges_enabled={charges_enabled}, payouts_enabled={payouts_enabled}")
        else:
            # 如果通过 account_id 找不到，尝试通过 metadata
            user_id = account.get("metadata", {}).get("user_id")
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
                user_id = account.get("metadata", {}).get("user_id")
                if user_id:
                    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
                    if user:
                        user.stripe_account_id = None
                        db.commit()
                        logger.info(f"Account deauthorized for user {user.id} (found via metadata)")
    
    return {"status": "success"}

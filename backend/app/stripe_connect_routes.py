"""
Stripe Connect 账户管理 API 路由
"""
import logging
import os
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
import stripe

from app import schemas, models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stripe/connect", tags=["Stripe Connect"])

# 设置 Stripe API Key
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")


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
        try:
            account = stripe.Account.retrieve(user.stripe_account_id)
            account_metadata = getattr(account, 'metadata', {})
            
            # 检查 metadata 中的 user_id 是否匹配
            if isinstance(account_metadata, dict):
                account_user_id = account_metadata.get('user_id')
            else:
                account_user_id = getattr(account_metadata, 'user_id', None)
            
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
    """
    try:
        account = stripe.Account.retrieve(account_id)
        account_metadata = getattr(account, 'metadata', {})
        
        # 如果 metadata 是 dict，直接获取；如果是对象，使用 getattr
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
            # 检查账户状态 (使用 V1 API，与 webhook 保持一致)
            try:
                account = stripe.Account.retrieve(existing_account_id)
                details_submitted = account.details_submitted
                
                logger.info(f"User {current_user.id} already has Stripe account {existing_account_id}, returning existing account")
                raise HTTPException(
                    status_code=400,
                    detail="您已经有一个 Stripe Connect 账户，每个用户只能有一个账户"
                )
            except HTTPException:
                raise
            except stripe.error.StripeError as e:
                logger.error(f"Error retrieving Stripe account: {e}")
                # 如果账户不存在，清除记录并继续创建
                db_user_clear = db.query(models.User).filter(models.User.id == current_user.id).first()
                if db_user_clear:
                    db_user_clear.stripe_account_id = None
                    db.commit()
                    db.refresh(db_user_clear)
        
        # 创建 Express Account (使用 V1 API，与 webhook 保持一致)
        # 参考: stripe-sample-code/server.js line 89-114
        # 注意：统一使用 V1 API，因为 webhook 事件是 V1 格式，AccountSession 也是 V1 API
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
            logger.info(f"Created Stripe Connect account {account.id} using V1 API for user {current_user.id}")
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
                
                # 如果账户已完成 onboarding，返回成功
                if existing_account.details_submitted:
                    return {
                        "account_id": existing_account.id,
                        "client_secret": None,
                        "account_status": existing_account.details_submitted,
                        "charges_enabled": existing_account.charges_enabled,
                        "message": "您已经有一个 Stripe 账户且已完成设置"
                    }
                
                # 如果账户未完成 onboarding，创建 AccountSession 用于嵌入式组件
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
                "account_status": account.details_submitted,
                "charges_enabled": account.charges_enabled,
                "message": f"账户创建成功，但无法立即创建 onboarding session: {str(session_err)}"
            }
        
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
            # 检查账户状态
            try:
                account = stripe.Account.retrieve(existing_account_id)
                
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
        
        # 创建 Express Account (使用 V1 API，与 webhook 保持一致)
        # 参考: stripe-sample-code/server.js line 89-114
        # 注意：统一使用 V1 API，因为 webhook 事件是 V1 格式，AccountSession 也是 V1 API
        account = None
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
            logger.info(f"Created Stripe Connect account {account.id} using V1 API for user {current_user.id}")
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
            "client_secret": None,
            "needs_onboarding": True,
            "requirements": None
        }
    
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        
        # 验证账户所有权（通过 metadata 中的 user_id）
        if not verify_account_ownership(current_user.stripe_account_id, current_user):
            logger.error(f"Account ownership verification failed for user {current_user.id}, account {current_user.stripe_account_id}")
            raise HTTPException(
                status_code=403,
                detail="账户验证失败：账户不属于当前用户"
            )
        
        # 检查是否需要重新 onboarding
        needs_onboarding = not account.details_submitted
        
        # 使用嵌入式组件，不创建跳转链接
        client_secret = None
        if needs_onboarding:
            try:
                onboarding_session = stripe.AccountSession.create(
                    account=account.id,
                    components={
                        "account_onboarding": {
                            "enabled": True
                        }
                    }
                )
                client_secret = onboarding_session.client_secret
            except stripe.error.StripeError as e:
                logger.warning(f"Failed to create AccountSession for onboarding: {e}")
        
        return {
            "account_id": account.id,
            "details_submitted": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "payouts_enabled": account.payouts_enabled,
            "client_secret": client_secret,  # 用于嵌入式组件
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
        
        # 获取收入记录（Charges - 作为服务者收到的付款）
        try:
            charges = stripe.Charge.list(
                limit=limit,
                starting_after=starting_after,
                stripe_account=current_user.stripe_account_id
            )
            for charge in charges.data:
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
        try:
            transfers = stripe.Transfer.list(
                limit=limit,
                starting_after=starting_after,
                destination=current_user.stripe_account_id
            )
            for transfer in transfers.data:
                transactions.append({
                    "id": transfer.id,
                    "type": "income",
                    "amount": transfer.amount / 100,
                    "currency": transfer.currency.upper(),
                    "description": transfer.description or f"转账 #{transfer.id[:12]}",
                    "status": "succeeded" if transfer.reversed is False else "reversed",
                    "created": transfer.created,
                    "created_at": datetime.fromtimestamp(transfer.created, tz=timezone.utc).isoformat(),
                    "source": "transfer",
                    "metadata": transfer.metadata
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
                transactions.append({
                    "id": payout.id,
                    "type": "expense",
                    "amount": payout.amount / 100,
                    "currency": payout.currency.upper(),
                    "description": f"提现到银行账户 #{payout.id[:12]}",
                    "status": payout.status,
                    "created": payout.created,
                    "created_at": datetime.fromtimestamp(payout.created, tz=timezone.utc).isoformat(),
                    "source": "payout",
                    "metadata": payout.metadata
                })
        except stripe.error.StripeError as e:
            logger.warning(f"Error retrieving payouts: {e}")
        
        # 按时间排序（最新的在前）
        transactions.sort(key=lambda x: x["created"], reverse=True)
        
        # 限制返回数量
        transactions = transactions[:limit]
        
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
        onboarding_session = stripe.AccountSession.create(
            account=account.id,
            components={
                "account_onboarding": {
                    "enabled": True
                }
            }
        )
        
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
    创建 Account Session（用于嵌入式 onboarding）
    
    参考 stripe-sample-code/server.js 的 /account_session 端点
    返回 client_secret，前端可以使用 Stripe Connect Embedded Components
    """
    try:
        account_id = request.account
        
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
        account_session = stripe.AccountSession.create(
            account=account_id,
            components={
                "account_onboarding": {
                    "enabled": True,
                    # 确保使用嵌入式组件，不跳转到外部页面
                    # 根据文档，这是默认行为，但明确指定以确保一致性
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

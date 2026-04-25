"""
Payment-inline domain routes — extracted from app/routers.py (Task 13).

7 routes covering task payment, Stripe webhook, post-confirmation, VIP
subscription, and Apple IAP webhook:
  - POST /tasks/{task_id}/pay
  - POST /stripe/webhook
  - POST /tasks/{task_id}/confirm_complete
  - POST /users/vip/activate
  - GET  /users/vip/status
  - GET  /users/vip/history
  - POST /webhooks/apple-iap

Mounts at both /api and /api/users via main.py. URL paths are
unchanged — Stripe webhook signing secret is bound to the
/api/stripe/webhook URL on Stripe Dashboard.

Module-level helpers (_handle_account_updated,
_handle_dispute_team_reversal, _payment_method_types_for_currency,
_safe_int_metadata, _safe_json_loads, _decode_jws_transaction,
_handle_v2_*) stay in app/routers.py and are re-imported here.
"""
import logging
import os
import time
import uuid
from decimal import Decimal
from typing import Optional

import stripe
from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    HTTPException,
    Query,
    Request,
    Response,
    status,
)
from fastapi.responses import JSONResponse
from sqlalchemy import select, update, or_, and_, func
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    check_user_status,
    get_current_user_secure_sync_csrf,
    get_db,
    get_sync_db,
)
from app.rate_limiting import rate_limit
from app.utils.task_guards import load_real_task_or_404_sync
from app.routers import (
    _decode_jws_transaction,
    _handle_account_updated,
    _handle_dispute_team_reversal,
    _handle_v2_cancel,
    _handle_v2_expired,
    _handle_v2_refund,
    _handle_v2_renewal,
    _handle_v2_revoke,
    _payment_method_types_for_currency,
    _safe_int_metadata,
    _safe_json_loads,
)
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/tasks/{task_id}/pay")
def create_payment(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = load_real_task_or_404_sync(db, task_id)
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="任务不存在")  # combined 404 preserves 防探测
    if task.is_paid:
        return {"message": "Task already paid."}
    # 计算任务金额和平台服务费（用于 metadata 交叉校验）
    from app.utils.fee_calculator import calculate_application_fee_pence
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    task_amount_pence = round(task_amount * 100)
    task_source = getattr(task, "task_source", None)
    task_type = getattr(task, "task_type", None)
    application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
    # 创建Stripe支付会话
    session = stripe.checkout.Session.create(
        payment_method_types=_payment_method_types_for_currency((task.currency or "GBP").lower()),
        line_items=[
            {
                "price_data": {
                    "currency": (task.currency or "GBP").lower(),
                    "product_data": {"name": task.title},
                    "unit_amount": task_amount_pence,
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        success_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/success",
        cancel_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/cancel",
        metadata={
            "task_id": task_id,
            "application_fee": application_fee_pence,
            "task_source": task_source or "",
            "task_type": task_type or "",
        },
    )
    return {"checkout_url": session.url}


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    import logging
    import json
    logger = logging.getLogger(__name__)
    
    # 记录请求开始时间
    import time
    start_time = time.time()
    
    # 确保 crud 模块已导入（避免 UnboundLocalError）
    from app import crud
    # 确保 SQLAlchemy 函数已导入（避免 UnboundLocalError）
    from sqlalchemy import and_, func, select
    
    # 获取请求信息
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    content_type = request.headers.get("content-type", "unknown")
    user_agent = request.headers.get("user-agent", "unknown")
    client_ip = request.client.host if request.client else "unknown"
    
    # 记录webhook接收（关键信息保留INFO，详细信息降级为DEBUG）
    logger.info("=" * 80)
    logger.info(f"🔔 [WEBHOOK] 收到 Stripe Webhook 请求")
    logger.debug(f"  - 时间: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())}")
    logger.debug(f"  - 客户端IP: {client_ip}")
    logger.debug(f"  - User-Agent: {user_agent}")
    logger.debug(f"  - Content-Type: {content_type}")
    logger.debug(f"  - Payload 大小: {len(payload)} bytes")
    logger.debug(f"  - Signature 前缀: {sig_header[:30] if sig_header else 'None'}...")
    logger.debug(f"  - Secret 配置: {'✅ 已配置' if endpoint_secret else '❌ 未配置'}")
    
    # 严格验证 Webhook 签名（安全要求）
    # 只有通过 Stripe 签名验证的请求才能处理
    if not endpoint_secret:
        logger.error(f"❌ [WEBHOOK] 安全错误：STRIPE_WEBHOOK_SECRET 未配置")
        return JSONResponse(status_code=500, content={"error": "Webhook secret not configured"})
    
    if not sig_header:
        logger.error(f"❌ [WEBHOOK] 安全错误：缺少 Stripe 签名头")
        return JSONResponse(status_code=400, content={"error": "Missing stripe-signature header"})
    
    try:
        # 严格验证 Webhook 签名
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
        logger.debug(f"✅ [WEBHOOK] 事件验证成功（签名已验证）")
    except ValueError as e:
        logger.error(f"❌ [WEBHOOK] Invalid payload: {e}")
        logger.error(f"  - Payload 内容 (前500字符): {payload[:500].decode('utf-8', errors='ignore')}")
        return JSONResponse(status_code=400, content={"error": "Invalid payload"})
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"❌ [WEBHOOK] 安全错误：签名验证失败: {e}")
        logger.error(f"  - 提供的 Signature: {sig_header[:50]}...")
        logger.error(f"  - 使用的 Secret: ***{endpoint_secret[-4:]}")
        logger.error(f"  - 这可能是恶意请求或配置错误，已拒绝处理")
        return JSONResponse(status_code=400, content={"error": "Invalid signature"})
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 处理错误: {type(e).__name__}: {e}")
        import traceback
        logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
        return JSONResponse(status_code=400, content={"error": str(e)})
    
    event_type = event["type"]
    event_id = event.get("id")
    event_data = event["data"]["object"]
    livemode = event.get("livemode", False)
    created = event.get("created")
    
    # 记录事件关键信息（详细信息降级为DEBUG）
    logger.info(f"📦 [WEBHOOK] 事件: {event_type} (ID: {event_id})")
    logger.debug(f"  - Livemode: {livemode}")
    logger.debug(f"  - 创建时间: {created} ({time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(created)) if created else 'N/A'})")
    
    # Idempotency 检查：防止重复处理同一个 webhook 事件
    import json
    from app.utils.time_utils import get_utc_time
    
    if event_id:
        existing_event = db.query(models.WebhookEvent).filter(
            models.WebhookEvent.event_id == event_id
        ).first()
        
        if existing_event:
            if existing_event.processed:
                logger.warning(f"⚠️ [WEBHOOK] 事件已处理过，跳过: event_id={event_id}, processed_at={existing_event.processed_at}")
                return {"status": "already_processed", "event_id": event_id}
            else:
                logger.info(f"🔄 [WEBHOOK] 事件之前处理失败，重新处理: event_id={event_id}, error={existing_event.processing_error}")
        else:
            # 创建新的事件记录
            webhook_event = models.WebhookEvent(
                event_id=event_id,
                event_type=event_type,
                livemode=livemode,
                processed=False,
                event_data=json.loads(json.dumps(event))  # 保存完整事件数据
            )
            db.add(webhook_event)
            try:
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 已创建事件记录: event_id={event_id}")
            except Exception as e:
                db.rollback()
                logger.error(f"❌ [WEBHOOK] 创建事件记录失败: {e}")
                # 如果是因为重复事件ID导致的错误，可能是并发请求，检查是否已存在
                existing_event = db.query(models.WebhookEvent).filter(
                    models.WebhookEvent.event_id == event_id
                ).first()
                if existing_event and existing_event.processed:
                    logger.warning(f"⚠️ [WEBHOOK] 并发请求，事件已处理: event_id={event_id}")
                    return {"status": "already_processed", "event_id": event_id}
                raise
    else:
        logger.error(f"❌ [WEBHOOK] 事件缺少 event_id，拒绝处理以保证幂等性: event_type={event_type}")
        return JSONResponse(status_code=400, content={"error": "Missing event_id, cannot guarantee idempotency"})
    
    # 标记事件开始处理
    processing_started = False
    try:
        if event_id:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = False  # 重置处理状态
                webhook_event.processing_error = None
                db.commit()
                processing_started = True
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}")
        db.rollback()
    
    # 如果是 payment_intent 相关事件，记录关键信息（详细信息降级为DEBUG）
    if "payment_intent" in event_type:
        payment_intent_id = event_data.get("id")
        payment_status = event_data.get("status")
        amount = event_data.get("amount")
        currency = event_data.get("currency", "unknown")
        metadata = event_data.get("metadata", {})
        logger.info(f"💳 [WEBHOOK] Payment Intent: {payment_intent_id}, 状态: {payment_status}, 金额: {amount / 100 if amount else 0:.2f} {currency.upper()}")
        logger.debug(f"  - Metadata: {json.dumps(metadata, ensure_ascii=False)}")
        logger.debug(f"  - Task ID: {metadata.get('task_id', 'N/A')}, Application ID: {metadata.get('application_id', 'N/A')}, Pending Approval: {metadata.get('pending_approval', 'N/A')}")
    
    # 处理 Payment Intent 事件（用于 Stripe Elements）
    if event_type == "payment_intent.succeeded":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        
        logger.info(f"Payment intent succeeded: {payment_intent_id}, task_id: {task_id}, amount: {payment_intent.get('amount')}")

        # ── Activity apply payment (no task_id, has activity_apply metadata) ──
        metadata = payment_intent.get("metadata", {})
        if metadata.get("activity_apply") == "true" and not task_id:
            _act_id = _safe_int_metadata(payment_intent, "activity_id")
            _act_user_id = metadata.get("user_id")
            _act_expert_id = metadata.get("expert_id")
            _act_expert_user_id = metadata.get("expert_user_id")

            if _act_id and _act_user_id:
                try:
                    # Find payment_pending application
                    _app_row = db.execute(
                        select(models.OfficialActivityApplication).where(
                            models.OfficialActivityApplication.activity_id == _act_id,
                            models.OfficialActivityApplication.user_id == _act_user_id,
                            models.OfficialActivityApplication.payment_intent_id == payment_intent_id,
                            models.OfficialActivityApplication.status == "payment_pending",
                        ).with_for_update()
                    ).scalar_one_or_none()

                    if _app_row:
                        _act = db.execute(
                            select(models.Activity).where(models.Activity.id == _act_id).with_for_update()
                        ).scalar_one_or_none()

                        if _act and _act.activity_type == "first_come":
                            from sqlalchemy import func as _sa_func
                            _attending = db.execute(
                                select(_sa_func.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _act_id,
                                    models.OfficialActivityApplication.status == "attending",
                                )
                            ).scalar() or 0
                            if _attending >= (_act.prize_count or 0):
                                # Full — refund
                                try:
                                    stripe.Refund.create(payment_intent=payment_intent_id)
                                    logger.info(f"Activity {_act_id} full, refunded PI {payment_intent_id}")
                                except Exception as _ref_err:
                                    logger.error(f"Activity refund failed for PI {payment_intent_id}: {_ref_err}")
                                _app_row.status = "refunded"
                            else:
                                _app_row.status = "attending"
                        elif _act and _act.activity_type == "lottery":
                            _app_row.status = "pending"
                        else:
                            _app_row.status = "pending"

                        _app_row.amount_paid = payment_intent.get("amount")

                        # PaymentHistory
                        from app.utils.fee_calculator import calculate_application_fee_pence as _calc_fee
                        _amt = payment_intent.get("amount", 0)
                        _fee = _calc_fee(_amt, task_source="expert_activity", task_type=getattr(_act, "task_type", None) if _act else None)
                        _taker_amt = max(0, _amt - _fee)

                        import uuid as _uuid
                        _ph = models.PaymentHistory(
                            order_no=f"ACT{_act_id}-{_uuid.uuid4().hex[:12]}",
                            user_id=_act_user_id,
                            payment_intent_id=payment_intent_id,
                            payment_method="stripe",
                            total_amount=_amt,
                            stripe_amount=_amt,
                            final_amount=_amt,
                            currency=(_act.currency if _act else "GBP") or "GBP",
                            status="succeeded",
                            application_fee=_fee,
                            escrow_amount=_taker_amt / 100.0,
                            extra_metadata={"activity_id": _act_id, "activity_apply": True},
                        )
                        db.add(_ph)

                        # PaymentTransfer for async payout
                        if _app_row.status != "refunded" and _act_expert_id and _taker_amt > 0:
                            _pt = models.PaymentTransfer(
                                taker_id=_act_expert_user_id or _act_user_id,
                                taker_expert_id=_act_expert_id,
                                poster_id=_act_user_id,
                                amount=_taker_amt / 100.0,
                                currency=(_act.currency if _act else "GBP") or "GBP",
                                status="pending",
                                idempotency_key=f"act-{_act_id}-{payment_intent_id}",
                                extra_metadata={"activity_id": _act_id, "payment_intent_id": payment_intent_id},
                            )
                            db.add(_pt)

                        db.commit()
                        logger.info(f"✅ Activity payment confirmed: activity={_act_id}, user={_act_user_id}, status={_app_row.status}")

                        # by_count trigger (sync) — re-lock activity to prevent race
                        if (
                            _act and _act.activity_type == "lottery"
                            and _act.draw_mode == "auto"
                            and _act.draw_trigger in ("by_count", "both")
                            and _act.draw_participant_count
                        ):
                            from sqlalchemy import func as _sa_func2
                            _pend = db.execute(
                                select(_sa_func2.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _act_id,
                                    models.OfficialActivityApplication.status == "pending",
                                )
                            ).scalar() or 0
                            if _pend >= _act.draw_participant_count:
                                # Re-lock activity after commit to prevent concurrent draws
                                _act_locked = db.execute(
                                    select(models.Activity).where(models.Activity.id == _act_id).with_for_update()
                                ).scalar_one_or_none()
                                if _act_locked and not _act_locked.is_drawn:
                                    from app.draw_logic import perform_draw_sync
                                    try:
                                        perform_draw_sync(db, _act_locked)
                                        logger.info(f"✅ by_count auto-draw triggered for activity {_act_id}")
                                    except Exception as _draw_err:
                                        logger.error(f"by_count auto-draw failed: {_draw_err}")
                    else:
                        logger.warning(f"⚠️ Activity payment: no payment_pending app found for activity={_act_id}, user={_act_user_id}, pi={payment_intent_id}")

                except Exception as _act_err:
                    logger.error(f"❌ Activity payment webhook error: activity={_act_id}, error={_act_err}", exc_info=True)
                    try:
                        db.rollback()
                    except Exception:
                        pass

        if task_id:
            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发webhook更新
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:  # 幂等性检查
                task.is_paid = 1
                task.payment_intent_id = payment_intent_id  # 保存 Payment Intent ID 用于关联
                # spec §3.4a — 团队任务 90 天 Stripe Transfer 时效检查、
                # warn-long-running-team-tasks 60 天告警 Celery 任务都依赖此字段。
                # 不写这一行的话 payment_transfer_service.execute_transfer 的窗口检查
                # 永远是 NULL 跳过，celery beat 任务永远查不到行，整套防御层失效。
                task.payment_completed_at = get_utc_time()
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                
                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额
                # metadata仅作为交叉校验参考；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)

                # 交叉校验metadata中的费用（仅记录差异，不使用metadata值）
                metadata = payment_intent.get("metadata", {})
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数

                # ==================== 钱包混合支付：确认钱包扣款 ====================
                metadata = payment_intent.get("metadata", {})
                _wallet_tx_id = metadata.get("wallet_tx_id")
                if _wallet_tx_id:
                    try:
                        from app.wallet_service import complete_debit
                        complete_debit(db, int(_wallet_tx_id))
                        logger.info(f"✅ [WEBHOOK] 钱包扣款已确认: wallet_tx_id={_wallet_tx_id}, task_id={task_id}")
                    except Exception as wallet_err:
                        logger.error(f"❌ [WEBHOOK] 确认钱包扣款失败: wallet_tx_id={_wallet_tx_id}, error={wallet_err}")
                        # 钱包确认失败不阻塞主流程（交易已经 pending，可后续修复）

                # 检查是否是待确认的批准（pending_approval）
                is_pending_approval = metadata.get("pending_approval") == "true"
                
                # ⚠️ 优化：如果是跳蚤市场购买，支付成功后更新商品状态为 sold
                payment_type = metadata.get("payment_type")
                if payment_type == "flea_market_direct_purchase" or payment_type == "flea_market_purchase_request":
                    flea_market_item_id = metadata.get("flea_market_item_id")
                    if flea_market_item_id:
                        try:
                            from app.models import FleaMarketItem
                            from app.id_generator import parse_flea_market_id
                            db_item_id = parse_flea_market_id(flea_market_item_id)
                            
                            # 更新商品状态为 sold（支付成功后）
                            # ⚠️ 优化：支持 active 或 reserved 状态（reserved 是已关联任务但未支付的状态）
                            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录，防止并发支付重复标记 sold
                            flea_item = db.query(FleaMarketItem).filter(
                                and_(
                                    FleaMarketItem.id == db_item_id,
                                    FleaMarketItem.sold_task_id == task_id,
                                    FleaMarketItem.status.in_(["active", "reserved"])
                                )
                            ).with_for_update().first()

                            if flea_item:
                                flea_item.status = "sold"
                                # 确保 sold_task_id 已设置（双重保险）
                                if flea_item.sold_task_id != task_id:
                                    flea_item.sold_task_id = task_id
                                db.flush()
                                logger.info(f"✅ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 支付成功，状态已更新为 sold (task_id: {task_id})")
                                
                                # 清除商品缓存（invalidate_item_cache 会自动清除列表缓存和详情缓存）
                                from app.flea_market_extensions import invalidate_item_cache
                                invalidate_item_cache(flea_item.id)
                                logger.info(f"✅ [WEBHOOK] 已清除跳蚤市场商品缓存（包括列表和详情）")
                                
                                # ✅ 支付成功后，发送"商品已售出"通知给卖家
                                # 注意：下单时仅发送"商品已被下单"通知，此处才是真正的"已售出"
                                try:
                                    buyer_name = metadata.get("poster_name", "买家")
                                    item_title = flea_item.title or metadata.get("task_title", "商品")
                                    
                                    crud.create_notification(
                                        db=db,
                                        user_id=flea_item.seller_id,
                                        type="flea_market_sold",
                                        title="商品已售出",
                                        content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                    
                                    # 发送推送通知给卖家
                                    try:
                                        from app.id_generator import format_flea_market_id
                                        send_push_notification(
                                            db=db,
                                            user_id=flea_item.seller_id,
                                            title=None,  # 从模板生成（根据用户语言偏好）
                                            body=None,   # 从模板生成
                                            notification_type="flea_market_sold",
                                            data={
                                                "item_id": format_flea_market_id(flea_item.id),
                                                "task_id": task_id
                                            },
                                            template_vars={
                                                "item_title": item_title
                                            }
                                        )
                                    except Exception as push_err:
                                        logger.warning(f"⚠️ [WEBHOOK] 发送商品售出推送通知失败: {push_err}")
                                    
                                    # 同时通知买家：支付成功
                                    buyer_id = metadata.get("poster_id")
                                    if buyer_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="flea_market_payment_success",
                                            title="支付成功",
                                            content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                            related_id=str(task_id),
                                            auto_commit=False,
                                        )
                                    
                                    logger.info(f"✅ [WEBHOOK] 跳蚤市场商品售出通知已创建 (seller_id: {flea_item.seller_id}, task_id: {task_id})")
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建商品售出通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 未找到或状态不匹配 (db_id: {db_item_id}, task_id: {task_id})")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 更新跳蚤市场商品状态失败: {e}", exc_info=True)

                # ⚠️ 跳蚤市场租赁：支付成功后创建 FleaMarketRental 记录
                if payment_type == "flea_market_rental":
                    rental_request_id = metadata.get("rental_request_id")
                    flea_market_item_id_str = metadata.get("flea_market_item_id")
                    if rental_request_id and flea_market_item_id_str:
                        try:
                            from app.models import FleaMarketRentalRequest, FleaMarketRental, FleaMarketItem
                            from datetime import timedelta as _td
                            from app.utils.time_utils import get_utc_time as _get_utc

                            rr = db.query(FleaMarketRentalRequest).filter(
                                FleaMarketRentalRequest.id == int(rental_request_id)
                            ).with_for_update().first()

                            if rr and rr.status == "approved":
                                flea_item = db.query(FleaMarketItem).filter(
                                    FleaMarketItem.id == int(flea_market_item_id_str)
                                ).first()

                                now = _get_utc()
                                unit = flea_item.rental_unit if flea_item else "day"
                                duration = rr.rental_duration
                                if unit == "week":
                                    end_date = now + _td(days=7 * duration)
                                elif unit == "month":
                                    end_date = now + _td(days=30 * duration)
                                else:
                                    end_date = now + _td(days=duration)

                                deposit_pence = int(metadata.get("deposit_amount", "0"))
                                rent_pence = int(metadata.get("rent_amount", "0"))
                                total_pence = deposit_pence + rent_pence

                                new_rental = FleaMarketRental(
                                    item_id=rr.item_id,
                                    renter_id=rr.renter_id,
                                    request_id=rr.id,
                                    rental_duration=duration,
                                    rental_unit=unit,
                                    total_rent=rent_pence / 100.0,
                                    deposit_amount=deposit_pence / 100.0,
                                    total_paid=total_pence / 100.0,
                                    currency=flea_item.currency if flea_item else "GBP",
                                    start_date=now,
                                    end_date=end_date,
                                    status="active",
                                    deposit_status="held",
                                    task_id=task_id,
                                )
                                db.add(new_rental)
                                # 更新租赁申请状态为已完成
                                rr.status = "completed"
                                db.flush()

                                logger.info(f"✅ [WEBHOOK] 跳蚤市场租赁记录已创建: rental_id={new_rental.id}, request_id={rental_request_id}")

                                # 通知物主和租客
                                try:
                                    item_title = flea_item.title if flea_item else "商品"
                                    renter_id = rr.renter_id
                                    seller_id = flea_item.seller_id if flea_item else None

                                    if seller_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=seller_id,
                                            type="flea_market_rental_payment_success",
                                            title="租赁支付成功",
                                            content=f"「{item_title}」的租赁支付已完成，租赁已生效。",
                                            related_id=str(new_rental.id),
                                            auto_commit=False,
                                        )

                                    crud.create_notification(
                                        db=db,
                                        user_id=renter_id,
                                        type="flea_market_rental_payment_success",
                                        title="租赁支付成功",
                                        content=f"您已成功租赁「{item_title}」，租赁已生效。",
                                        related_id=str(new_rental.id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建租赁通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 租赁申请 {rental_request_id} 不存在或状态不匹配")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建跳蚤市场租赁记录失败: {e}", exc_info=True)

                # ==================== 团队服务申请批准的支付完成 ====================
                # expert_consultation_routes.approve_application 创建 Task(status=pending_payment)
                # + ServiceApplication(status=approved) + PaymentIntent。
                # 此处把任务从 pending_payment 翻成 in_progress，并通知申请人。
                if payment_type == "team_service_application_approve":
                    service_application_id_str = metadata.get("service_application_id")
                    if service_application_id_str:
                        try:
                            service_application_id = int(service_application_id_str)
                            sa = db.execute(
                                select(models.ServiceApplication).where(
                                    models.ServiceApplication.id == service_application_id
                                ).with_for_update()
                            ).scalar_one_or_none()

                            if sa is None:
                                logger.warning(
                                    f"⚠️ [WEBHOOK] 团队服务申请 {service_application_id} 不存在"
                                )
                            elif task.status == "pending_payment":
                                task.status = "in_progress"
                                task.accepted_at = task.accepted_at or get_utc_time()
                                # ServiceApplication 在 approve 时已写为 approved，
                                # 这里只需写 task 状态，但确保 task_id 已绑定
                                if sa.task_id is None:
                                    sa.task_id = task_id
                                logger.info(
                                    f"✅ [WEBHOOK] 团队服务任务 {task_id} 进入 in_progress "
                                    f"(service_application_id={service_application_id})"
                                )

                                # 通知申请人 + 团队 owner: 任务已开始 (i18n)
                                try:
                                    from app.utils.notification_templates import get_notification_texts
                                    service_obj = db.query(models.TaskExpertService).filter(
                                        models.TaskExpertService.id == sa.service_id
                                    ).first()
                                    service_name = service_obj.service_name if service_obj else "服务"
                                    # 向 buyer 发通知
                                    started_zh_t, started_zh_c, started_en_t, started_en_c = get_notification_texts(
                                        "team_service_task_started", service_name=service_name
                                    )
                                    crud.create_notification(
                                        db=db,
                                        user_id=sa.applicant_id,
                                        type="team_service_task_started",
                                        title=started_zh_t,
                                        content=started_zh_c,
                                        title_en=started_en_t,
                                        content_en=started_en_c,
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                    # 向 team owner (taker_id) 发通知
                                    if task.taker_id:
                                        recv_zh_t, recv_zh_c, recv_en_t, recv_en_c = get_notification_texts(
                                            "team_service_payment_received", service_name=service_name
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=task.taker_id,
                                            type="team_service_payment_received",
                                            title=recv_zh_t,
                                            content=recv_zh_c,
                                            title_en=recv_en_t,
                                            content_en=recv_en_c,
                                            related_id=str(task_id),
                                            auto_commit=False,
                                        )
                                except Exception as notify_err:
                                    logger.warning(
                                        f"⚠️ [WEBHOOK] 团队服务任务通知发送失败: {notify_err}"
                                    )
                            else:
                                logger.info(
                                    f"ℹ️ [WEBHOOK] 团队服务任务 {task_id} 状态={task.status}, "
                                    f"跳过状态翻转(可能已被处理)"
                                )
                        except Exception as e:
                            logger.error(
                                f"❌ [WEBHOOK] 处理团队服务申请支付失败: {e}",
                                exc_info=True,
                            )

                application_id_str = metadata.get("application_id")
                
                logger.debug(f"🔍 Webhook检查: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                
                if is_pending_approval and application_id_str:
                    # 这是批准申请时的支付，需要确认批准
                    application_id = int(application_id_str)
                    logger.debug(f"🔍 查找申请: application_id={application_id}, task_id={task_id}")
                    
                    # 🔒 安全修复：使用 SELECT FOR UPDATE 防止并发 webhook 重复批准申请
                    # 支持 pending 和 chatting 状态的申请（chatting 来自聊天后支付流程）
                    application = db.execute(
                        select(models.TaskApplication).where(
                            and_(
                                models.TaskApplication.id == application_id,
                                models.TaskApplication.task_id == task_id,
                                models.TaskApplication.status.in_(["pending", "chatting"])
                            )
                        ).with_for_update()
                    ).scalar_one_or_none()
                    
                    logger.debug(f"🔍 找到申请: {application is not None}")
                    
                    if application:
                        logger.info(f"✅ [WEBHOOK] 开始批准申请 {application_id}, applicant_id={application.applicant_id}")
                        # 批准申请
                        application.status = "approved"
                        task.taker_id = application.applicant_id
                        # ⚠️ 新流程：支付成功后，任务状态直接设置为 in_progress（不再使用 pending_payment）
                        task.status = "in_progress"
                        logger.info(f"✅ [WEBHOOK] 申请已批准，任务状态设置为 in_progress, taker_id={task.taker_id}")
                        
                        # 如果申请包含议价，更新 agreed_reward
                        if application.negotiated_price is not None:
                            task.agreed_reward = application.negotiated_price
                            logger.info(f"✅ [WEBHOOK] 更新任务成交价: {application.negotiated_price}")
                        
                        # 自动拒绝所有其他待处理/聊天中的申请
                        other_applications = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.id != application_id,
                                    models.TaskApplication.status.in_(["chatting", "pending"])
                                )
                            )
                        ).scalars().all()

                        for other_app in other_applications:
                            was_chatting = other_app.status == "chatting"
                            other_app.status = "rejected"
                            logger.info(f"✅ [WEBHOOK] 自动拒绝其他申请: application_id={other_app.id}, was_chatting={was_chatting}")
                            # 如果申请者之前在聊天中，发送系统消息通知
                            if was_chatting:
                                content_zh = "发布者已选择了其他申请者完成此任务。"
                                content_en = "The poster has selected another applicant for this task."
                                reject_msg = models.Message(
                                    task_id=task_id,
                                    application_id=other_app.id,
                                    sender_id=None,
                                    content=content_zh,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({"system_action": "application_rejected", "content_en": content_en}),
                                    created_at=get_utc_time(),
                                )
                                db.add(reject_msg)

                        # 往主任务聊天（application_id=NULL）插入一条 deal_closed 系统消息
                        # 作为 poster 和 taker 进入议价记录的入口
                        try:
                            taker_name_for_msg = (
                                applicant.name if (applicant := db.query(models.User).filter(models.User.id == application.applicant_id).first()) and applicant.name
                                else f"User {application.applicant_id}"
                            )
                            final_price_for_msg = (
                                float(application.negotiated_price)
                                if application.negotiated_price is not None
                                else float(task.base_reward) if task.base_reward is not None else 0.0
                            )
                            currency_for_msg = getattr(task, "currency", None) or "GBP"
                            deal_content_zh = f"已选择 {taker_name_for_msg} 达成合作，成交金额 {currency_for_msg} {final_price_for_msg:.2f}"
                            deal_content_en = f"Deal closed with {taker_name_for_msg} at {currency_for_msg} {final_price_for_msg:.2f}"
                            deal_msg = models.Message(
                                task_id=task_id,
                                application_id=None,  # 主任务聊天
                                sender_id=None,       # 系统消息
                                content=deal_content_zh,
                                message_type="system",
                                conversation_type="task",
                                meta=json.dumps({
                                    "system_action": "deal_closed",
                                    "application_id": application_id,
                                    "taker_id": str(application.applicant_id),
                                    "taker_name": taker_name_for_msg,
                                    "price": final_price_for_msg,
                                    "currency": currency_for_msg,
                                    "content_en": deal_content_en,
                                }),
                                created_at=get_utc_time(),
                            )
                            db.add(deal_msg)
                            logger.info(f"✅ [WEBHOOK] 已写入 deal_closed 主聊天系统消息 task_id={task_id}, app_id={application_id}")
                        except Exception as deal_msg_exc:
                            # 消息写入失败不应阻断主流程
                            logger.warning(f"⚠️ [WEBHOOK] 写入 deal_closed 系统消息失败: {deal_msg_exc}")

                        # 咨询合并批准(consult-approve 路径):归档 T2 / 关闭 TA2
                        _consult_t2_id = metadata.get("consultation_task_id")
                        _consult_ta2_id = metadata.get("consultation_application_id")
                        if _consult_t2_id and _consult_ta2_id:
                            try:
                                from app.consultation.approval import (
                                    finalize_consultation_on_payment_success,
                                )
                                finalize_consultation_on_payment_success(
                                    db,
                                    consultation_task_id=int(_consult_t2_id),
                                    consultation_application_id=int(_consult_ta2_id),
                                )
                            except Exception as _cf_err:
                                logger.warning(
                                    f"⚠️ [WEBHOOK] 咨询归档失败(不阻断主流程): "
                                    f"T2={_consult_t2_id} TA2={_consult_ta2_id} err={_cf_err}"
                                )

                        # 原任务 T 已确定接单人,把其他指向 T 的咨询占位全部归档
                        # (一个申请者被选中 → 其他申请者的咨询聊天自动关闭,避免挂着假状态)
                        # 同时覆盖两条入口:consult-approve(上面已跳过刚归档的 T2) 和普通 accept_application
                        try:
                            from app.consultation.approval import (
                                close_placeholders_for_task,
                            )
                            close_placeholders_for_task(
                                db,
                                original_task_id=task_id,
                                exclude_t2_id=(
                                    int(_consult_t2_id) if _consult_t2_id else None
                                ),
                            )
                        except Exception as _cp_err:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 批量归档其他咨询占位失败(不阻断主流程): "
                                f"task_id={task_id} err={_cp_err}"
                            )

                        # 写入操作日志
                        from app.utils.time_utils import get_utc_time
                        log_entry = models.NegotiationResponseLog(
                            task_id=task_id,
                            application_id=application_id,
                            user_id=task.poster_id,
                            action="accept",
                            negotiated_price=application.negotiated_price,
                            responded_at=get_utc_time()
                        )
                        db.add(log_entry)
                        logger.debug(f"✅ [WEBHOOK] 已添加操作日志")
                        
                        # 发送通知给申请者（支付成功后，任务已进入 in_progress 状态）
                        try:
                            from app import crud
                            from app.task_notifications import send_task_approval_notification
                            
                            # 获取申请者信息
                            applicant = db.query(models.User).filter(models.User.id == application.applicant_id).first()
                            if applicant:
                                # 使用 send_task_approval_notification 发送通知
                                # 注意：此时任务状态已经是 in_progress，所以不会显示支付提醒（这是正确的）
                                # background_tasks 可以为 None，因为通知会立即发送
                                send_task_approval_notification(
                                    db=db,
                                    background_tasks=None,  # webhook 中不需要后台任务
                                    task=task,
                                    applicant=applicant
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送接受申请通知给申请者 {application.applicant_id}")
                            else:
                                # 如果无法获取申请者信息，使用简单通知
                                crud.create_notification(
                                    db,
                                    application.applicant_id,
                                    "application_accepted",
                                    "您的申请已被接受",
                                    f"您的任务申请已被接受：{task.title}",
                                    task.id,
                                    auto_commit=False,
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送简单接受申请通知给申请者 {application.applicant_id}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 发送接受申请通知失败: {e}")
                        
                        logger.info(f"✅ [WEBHOOK] 支付成功，申请 {application_id} 已批准")
                        
                        # 增强支付审计信息：记录申请批准相关的支付信息
                        try:
                            # 创建或更新 PaymentHistory（如果不存在）
                            payment_history = db.query(models.PaymentHistory).filter(
                                models.PaymentHistory.payment_intent_id == payment_intent_id
                            ).first()
                            
                            if payment_history:
                                # 更新现有记录（状态机保护）
                                try:
                                    payment_history.transition_status("succeeded")
                                except ValueError as e:
                                    logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                                payment_history.escrow_amount = task.escrow_amount
                                # 增强 metadata（用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更）
                                payment_history.extra_metadata = {
                                    **(payment_history.extra_metadata or {}),
                                    "application_id": str(application_id),
                                    "taker_id": str(application.applicant_id),
                                    "taker_name": application.applicant.name if hasattr(application, 'applicant') and application.applicant else None,
                                    "pending_approval": "true",
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                                logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录: payment_history_id={payment_history.id}")
                            else:
                                # 创建新的支付历史记录（用于审计）
                                from decimal import Decimal
                                payment_history = models.PaymentHistory(
                                    order_no=models.PaymentHistory.generate_order_no(),
                                    task_id=task_id,
                                    user_id=task.poster_id,
                                    payment_intent_id=payment_intent_id,
                                    payment_method="stripe",
                                    total_amount=int(task_amount * 100),
                                    stripe_amount=int(task_amount * 100),
                                    final_amount=int(task_amount * 100),
                                    currency=task.currency or "GBP",
                                    status="succeeded",
                                    application_fee=application_fee_pence,
                                    escrow_amount=Decimal(str(task.escrow_amount)),
                                    extra_metadata={
                                        "application_id": str(application_id),
                                        "taker_id": str(application.applicant_id),
                                        "pending_approval": "true",
                                        "approved_via_webhook": True,
                                        "webhook_event_id": event_id,
                                        "approved_at": get_utc_time().isoformat()
                                    }
                                )
                                db.add(payment_history)
                                logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录: order_no={payment_history.order_no}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败: {e}", exc_info=True)
                            # 支付历史记录失败不影响主流程
                    else:
                        # Application not in expected status — check if it was withdrawn (race condition)
                        withdrawn_application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status == "withdrawn"
                                )
                            )
                        ).scalar_one_or_none()

                        if withdrawn_application:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 申请人已撤回申请，支付成功但需退款: "
                                f"application_id={application_id_str}, task_id={task_id}, "
                                f"payment_intent_id={payment_intent_id}"
                            )
                            # Revert task paid status since we will refund
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请撤回退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（撤回）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, application_id={application_id_str}"
                                )
                                # Notify the poster that payment was refunded
                                try:
                                    crud.create_notification(
                                        db=db,
                                        user_id=task.poster_id,
                                        type="payment_refunded",
                                        title="支付已退款",
                                        content=f"申请人在支付处理期间撤回了申请，您的付款已自动退款：{task.title}",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建退款通知失败: {notify_err}")
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, error={refund_err}",
                                    exc_info=True
                                )
                        else:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 未找到匹配的申请: application_id={application_id_str}, "
                                f"task_id={task_id}, status not in [pending, chatting, withdrawn]. "
                                f"Attempting refund for payment_intent_id={payment_intent_id}"
                            )
                            # Application not found at all or in unexpected status — refund to be safe
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请未找到退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（未找到）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款（申请未找到）: payment_intent_id={payment_intent_id}"
                                )
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"error={refund_err}",
                                    exc_info=True
                                )
                else:
                    logger.info(f"ℹ️ 不是待确认的批准支付: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                    # 即使不是 pending_approval，也要记录支付历史
                    try:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.payment_intent_id == payment_intent_id
                        ).first()
                        
                        if not payment_history:
                            # 创建新的支付历史记录
                            from decimal import Decimal
                            payment_history = models.PaymentHistory(
                                order_no=models.PaymentHistory.generate_order_no(),
                                task_id=task_id,
                                user_id=task.poster_id,
                                payment_intent_id=payment_intent_id,
                                payment_method="stripe",
                                total_amount=int(task_amount * 100),
                                stripe_amount=int(task_amount * 100),
                                final_amount=int(task_amount * 100),
                                currency=task.currency or "GBP",
                                status="succeeded",
                                application_fee=application_fee_pence,
                                escrow_amount=Decimal(str(task.escrow_amount)),
                                extra_metadata={
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                            )
                            db.add(payment_history)
                            logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                        else:
                            # 更新现有记录（状态机保护）
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.escrow_amount = task.escrow_amount
                            # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                            payment_history.extra_metadata = {
                                **(payment_history.extra_metadata or {}),
                                "approved_via_webhook": True,
                                "webhook_event_id": event_id,
                                "approved_at": get_utc_time().isoformat()
                            }
                            logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败（非 pending_approval）: {e}", exc_info=True)
                        # 支付历史记录失败不影响主流程
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                logger.info(f"🔍 检查任务状态: 当前状态={task.status}, is_paid={task.is_paid}")

                # 预加载关联服务（一次查询，后续复用）
                _act_service = None
                _is_package_activity = False
                if getattr(task, 'parent_activity_id', None) and getattr(task, 'expert_service_id', None):
                    _act_service = db.query(models.TaskExpertService).filter(
                        models.TaskExpertService.id == task.expert_service_id
                    ).first()
                    _is_package_activity = _act_service and _act_service.package_type in ("multi", "bundle")

                # 支付成功后更新任务状态
                if task.status == "pending_payment":
                    if _is_package_activity:
                        # 套餐活动的 Task 仅作为购买凭证，无实际服务交付环节。
                        # 直接 completed，不触发普通任务的完成回调（统计/积分等），
                        # 因为套餐的价值体现在 UserServicePackage 的 sessions 核销中。
                        task.status = "completed"
                        logger.info(f"✅ 套餐活动任务直接标记 completed（无需交付流程）")
                    else:
                        task.status = "in_progress"
                        logger.info(f"✅ 任务状态从 pending_payment 更新为 in_progress")
                else:
                    logger.info(f"⚠️ 任务状态不是 pending_payment，当前状态: {task.status}，跳过状态更新")

                # ====== 活动→套餐自动创建 ======
                # 如果任务来自活动，且关联的服务是套餐类型(multi/bundle)，
                # 自动为买家创建 UserServicePackage 记录
                if _is_package_activity and _act_service:
                    act_service = _act_service
                    try:
                        from sqlalchemy.exc import IntegrityError
                        from app.models_expert import UserServicePackage
                        from app.package_purchase_routes import _build_bundle_breakdown, _bundle_total_sessions

                        # 幂等: 同一 payment_intent 不重复创建 (with_for_update 与 A1 路径一致)
                        existing_pkg = db.query(UserServicePackage).filter(
                            UserServicePackage.payment_intent_id == payment_intent_id
                        ).with_for_update().first()
                        if existing_pkg:
                            logger.info(f"✅ [WEBHOOK] 活动套餐已存在 (pi={payment_intent_id})，幂等跳过")
                        else:
                            # 计算总课时和 breakdown
                            breakdown = None
                            if act_service.package_type == "bundle":
                                breakdown = _build_bundle_breakdown(act_service.bundle_service_ids, db=db)
                                final_total = _bundle_total_sessions(breakdown) if breakdown else 0
                            else:
                                final_total = act_service.total_sessions or 0

                            if final_total <= 0:
                                logger.warning(f"⚠️ [WEBHOOK] 活动套餐 total_sessions=0，跳过创建")
                            else:
                                # 确定买家 ID（originating_user_id 是报名者，poster_id 是发布者兜底）
                                buyer_id = task.originating_user_id or task.poster_id
                                if not task.originating_user_id:
                                    logger.warning(
                                        f"⚠️ [WEBHOOK] 活动套餐 task {task.id} originating_user_id 为空，"
                                        f"回退到 poster_id={task.poster_id}"
                                    )
                                # 确定团队 ID
                                pkg_expert_id = act_service.owner_id if act_service.owner_type == 'expert' else None

                                # 过期时间
                                exp_at = None
                                if act_service.validity_days and act_service.validity_days > 0:
                                    exp_at = get_utc_time() + timedelta(days=act_service.validity_days)

                                # 单价快照
                                unit_snapshot = None
                                if act_service.package_type == "multi":
                                    unit_snapshot = int(round(float(act_service.base_price) * 100))

                                # 实付金额 (pounds，与 A1 直接购买路径一致)
                                paid_amount = float(task.reward or 0)

                                new_pkg = UserServicePackage(
                                    user_id=buyer_id,
                                    service_id=act_service.id,
                                    expert_id=pkg_expert_id,
                                    total_sessions=final_total,
                                    used_sessions=0,
                                    status="active",
                                    purchased_at=get_utc_time(),
                                    cooldown_until=get_utc_time() + timedelta(hours=24),
                                    expires_at=exp_at,
                                    payment_intent_id=payment_intent_id,
                                    paid_amount=paid_amount,
                                    currency="GBP",
                                    bundle_breakdown=breakdown,
                                    unit_price_pence_snapshot=unit_snapshot,
                                )
                                db.add(new_pkg)
                                try:
                                    db.commit()
                                    db.refresh(new_pkg)
                                    logger.info(
                                        f"✅ [WEBHOOK] 活动套餐 {new_pkg.id} 已创建 "
                                        f"(buyer={buyer_id} service={act_service.id} "
                                        f"type={act_service.package_type} total={final_total})"
                                    )

                                    # 通知买家
                                    try:
                                        from app.utils.notification_templates import get_notification_texts
                                        buyer_t_zh, buyer_c_zh, buyer_t_en, buyer_c_en = get_notification_texts(
                                            "package_purchased",
                                            service_name=act_service.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="package_purchased",
                                            title=buyer_t_zh,
                                            content=buyer_c_zh,
                                            title_en=buyer_t_en,
                                            content_en=buyer_c_en,
                                            related_id=str(new_pkg.id),
                                        )
                                    except Exception as notify_err:
                                        logger.warning(f"⚠️ [WEBHOOK] 活动套餐购买通知失败: {notify_err}")
                                except IntegrityError:
                                    db.rollback()
                                    logger.info(f"✅ [WEBHOOK] 活动套餐并发已创建 (pi={payment_intent_id})，幂等跳过")
                    except Exception as pkg_err:
                        logger.error(f"❌ [WEBHOOK] 活动→套餐创建失败: {pkg_err}", exc_info=True)
                        # 不影响主流程（Task 已正常处理）

            elif task and task.is_paid == 1:
                # ====== 补差价支付（top_up）：任务已付款，此次为追加支付 ======
                metadata = payment_intent.get("metadata", {})
                if metadata.get("payment_type") == "top_up" and metadata.get("pending_approval") == "true":
                    top_up_pence = payment_intent.get("amount", 0)
                    logger.info(f"✅ [WEBHOOK] 补差价支付成功: task_id={task_id}, top_up={top_up_pence}p")

                    # 更新 escrow：累加补差价金额（扣除补差价部分的服务费）
                    from app.utils.fee_calculator import calculate_application_fee_pence
                    task_source = getattr(task, "task_source", None)
                    task_type_val = getattr(task, "task_type", None)
                    top_up_fee = calculate_application_fee_pence(top_up_pence, task_source, task_type_val)
                    top_up_net = (top_up_pence - top_up_fee) / 100.0
                    task.escrow_amount = float(task.escrow_amount or 0) + max(0.0, top_up_net)

                    # 更新 agreed_reward 为新总价
                    if metadata.get("negotiated_price"):
                        try:
                            from decimal import Decimal
                            task.agreed_reward = Decimal(metadata["negotiated_price"])
                        except Exception:
                            pass

                    # 保存最新的 payment_intent_id
                    task.payment_intent_id = payment_intent_id

                    # 批准申请（复用与上面相同的逻辑）
                    application_id_str = metadata.get("application_id")
                    if application_id_str:
                        application_id = int(application_id_str)
                        application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status.in_(["pending", "chatting"])
                                )
                            ).with_for_update()
                        ).scalar_one_or_none()

                        if application:
                            application.status = "approved"
                            task.taker_id = application.applicant_id
                            task.status = "in_progress"
                            logger.info(f"✅ [WEBHOOK] 补差价后批准申请 {application_id}")

                            # 自动拒绝其他申请
                            other_apps = db.execute(
                                select(models.TaskApplication).where(
                                    and_(
                                        models.TaskApplication.task_id == task_id,
                                        models.TaskApplication.id != application_id,
                                        models.TaskApplication.status.in_(["chatting", "pending"])
                                    )
                                )
                            ).scalars().all()
                            for other_app in other_apps:
                                was_chatting = other_app.status == "chatting"
                                other_app.status = "rejected"
                                if was_chatting:
                                    reject_msg = models.Message(
                                        task_id=task_id, application_id=other_app.id,
                                        sender_id=None, receiver_id=None,
                                        content="发布者已选择了其他申请者完成此任务。",
                                        message_type="system", conversation_type="task",
                                        meta=json.dumps({"system_action": "auto_rejected",
                                                         "content_en": "The poster has selected another applicant for this task."}),
                                        created_at=get_utc_time(),
                                    )
                                    db.add(reject_msg)

                            # 通知申请人
                            try:
                                crud.create_notification(
                                    db, application.applicant_id,
                                    "application_accepted", "申请已通过",
                                    f"您的任务申请已被接受：{task.title}",
                                    related_id=str(task_id), auto_commit=False,
                                )
                            except Exception as e:
                                logger.warning(f"⚠️ [WEBHOOK] 通知失败: {e}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 补差价支付成功但未找到申请 {application_id_str}")
                else:
                    logger.info(f"ℹ️ [WEBHOOK] 已付款任务收到支付，非 top_up 类型，跳过")
                
                # 支付历史记录已在上面更新（如果存在待确认的批准支付）
                
                # 提交数据库更改
                try:
                    # 在提交前记录更新前的状态（DEBUG级别）
                    logger.debug(f"📝 [WEBHOOK] 提交前任务状态: is_paid={task.is_paid}, status={task.status}, payment_intent_id={task.payment_intent_id}, escrow_amount={task.escrow_amount}, taker_id={task.taker_id}")
                    
                    db.commit()
                    logger.debug(f"✅ [WEBHOOK] 数据库提交成功")
                    
                    # 刷新任务对象以获取最新状态
                    db.refresh(task)
                    
                    # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        logger.debug(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                    
                    # 清除任务列表缓存（因为任务状态已改变）
                    try:
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.debug(f"✅ [WEBHOOK] 已清除任务列表缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    
                    # 验证更新是否成功（关键信息保留INFO）
                    logger.info(f"✅ [WEBHOOK] 任务 {task_id} 支付完成: status={task.status}, is_paid={task.is_paid}, taker_id={task.taker_id}")
                    logger.debug(f"  - Payment Intent ID: {task.payment_intent_id}, Escrow 金额: {task.escrow_amount}")
                    
                    # 如果 is_paid 没有正确更新，记录警告
                    if task.is_paid != 1:
                        logger.error(f"❌ [WEBHOOK] 警告：任务 {task_id} 的 is_paid 字段未正确更新！当前值: {task.is_paid}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    import traceback
                    logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
                    db.rollback()
                    raise
            else:
                logger.warning(f"⚠️ [WEBHOOK] 任务 {task_id} 已支付或不存在")
                if task:
                    logger.warning(f"  - 任务已支付状态: {task.is_paid}")
                    logger.warning(f"  - 任务当前状态: {task.status}")
        else:
            # 没有 task_id 的 PI: 检查是不是套餐购买 (A1)
            metadata = payment_intent.get("metadata", {}) or {}
            pmt_type = metadata.get("payment_type")
            if pmt_type == "package_purchase":
                # ==================== A1: 套餐购买完成 ====================
                # buyer 完成套餐支付,创建 UserServicePackage 记录
                try:
                    from app.models_expert import UserServicePackage
                    from datetime import timedelta as _td
                    from sqlalchemy.exc import IntegrityError
                    service_id_meta = metadata.get("service_id")
                    buyer_id = metadata.get("buyer_id")
                    expert_id_meta = metadata.get("expert_id")
                    package_type_meta = metadata.get("package_type")
                    total_sessions_meta = int(metadata.get("total_sessions", 0))
                    package_price_meta = float(metadata.get("package_price", 0))
                    validity_days_meta = int(metadata.get("validity_days", 0))

                    if not (service_id_meta and buyer_id and expert_id_meta):
                        logger.error(
                            f"❌ [WEBHOOK] package_purchase metadata 不完整: {metadata}"
                        )
                    else:
                        # 幂等性检查 — 同 PI 是否已创建 package
                        # 注意: DB 层有 partial unique index uq_user_service_packages_pi (migration 187),
                        # 即便 query 后并发 add 也会被 IntegrityError 拦下,见下方 except。
                        existing_pkg = db.query(UserServicePackage).filter(
                            UserServicePackage.payment_intent_id == payment_intent_id
                        ).with_for_update().first()
                        if existing_pkg:
                            logger.info(
                                f"✅ [WEBHOOK] 套餐 {existing_pkg.id} 已存在,跳过 (idempotent)"
                            )
                        else:
                            # 加载 service 拿 bundle_breakdown 配置
                            from app.models import TaskExpertService
                            service_obj = db.query(TaskExpertService).filter(
                                TaskExpertService.id == int(service_id_meta)
                            ).first()
                            if not service_obj:
                                logger.error(
                                    f"❌ [WEBHOOK] package_purchase: service {service_id_meta} 不存在"
                                )
                            else:
                                # 构建 bundle_breakdown
                                from app.package_purchase_routes import (
                                    _build_bundle_breakdown,
                                    _bundle_total_sessions,
                                )
                                breakdown = None
                                final_total = total_sessions_meta
                                if package_type_meta == "bundle":
                                    breakdown = _build_bundle_breakdown(service_obj.bundle_service_ids, db)
                                    final_total = _bundle_total_sessions(breakdown)

                                if final_total <= 0:
                                    logger.error(
                                        f"❌ [WEBHOOK] package_purchase: total_sessions={final_total}, "
                                        f"无法创建空套餐,跳过 (metadata={metadata})"
                                    )
                                    raise ValueError(f"total_sessions={final_total}, 无法创建套餐")

                                # 计算 expires_at
                                exp_at = None
                                if validity_days_meta > 0:
                                    exp_at = get_utc_time() + _td(days=validity_days_meta)

                                # 计算 unit_price_pence_snapshot (multi 套餐专用; bundle 价格已内嵌在 breakdown)
                                # 防御: service.base_price 理论上 multi 非空 (schema validator 强制),
                                # 但历史数据 / 不规范 PATCH 可能产生 NULL,fallback 到 0 避免 webhook 崩
                                unit_snapshot = None
                                if package_type_meta == "multi" and service_obj is not None:
                                    unit_snapshot = int(round(float(service_obj.base_price or 0) * 100))

                                new_pkg = UserServicePackage(
                                    user_id=buyer_id,
                                    service_id=int(service_id_meta),
                                    expert_id=expert_id_meta,
                                    total_sessions=final_total,
                                    used_sessions=0,
                                    status="active",
                                    purchased_at=get_utc_time(),
                                    cooldown_until=get_utc_time() + timedelta(hours=24),  # NEW: 24h 冷却期
                                    expires_at=exp_at,
                                    payment_intent_id=payment_intent_id,
                                    paid_amount=package_price_meta,
                                    currency="GBP",
                                    bundle_breakdown=breakdown,
                                    unit_price_pence_snapshot=unit_snapshot,  # NEW: 单价快照
                                )
                                db.add(new_pkg)
                                idempotent_skipped = False
                                try:
                                    db.commit()
                                except IntegrityError:
                                    # 并发兜底: unique index uq_user_service_packages_pi (migration 187)
                                    # 命中 → 已被另一 webhook 创建,幂等跳过通知
                                    db.rollback()
                                    logger.info(
                                        f"✅ [WEBHOOK] 套餐 {payment_intent_id} 并发已创建,幂等跳过"
                                    )
                                    idempotent_skipped = True

                                if not idempotent_skipped:
                                    db.refresh(new_pkg)
                                    logger.info(
                                        f"✅ [WEBHOOK] 套餐 {new_pkg.id} 已创建 "
                                        f"(buyer={buyer_id} expert={expert_id_meta} type={package_type_meta} total={final_total})"
                                    )

                                    # 通知 buyer + 团队所有 admin (i18n 模板)
                                    try:
                                        from app.utils.notification_templates import get_notification_texts
                                        from app.models_expert import ExpertMember as _EM

                                        buyer_t_zh, buyer_c_zh, buyer_t_en, buyer_c_en = get_notification_texts(
                                            "package_purchased",
                                            service_name=service_obj.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="package_purchased",
                                            title=buyer_t_zh,
                                            content=buyer_c_zh,
                                            title_en=buyer_t_en,
                                            content_en=buyer_c_en,
                                            related_id=str(new_pkg.id),
                                            auto_commit=False,
                                        )
                                        admin_t_zh, admin_c_zh, admin_t_en, admin_c_en = get_notification_texts(
                                            "package_sold",
                                            service_name=service_obj.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        managers = db.query(_EM.user_id).filter(
                                            _EM.expert_id == expert_id_meta,
                                            _EM.status == "active",
                                            _EM.role.in_(["owner", "admin"]),
                                        ).all()
                                        for (mid,) in managers:
                                            crud.create_notification(
                                                db=db,
                                                user_id=mid,
                                                type="package_sold",
                                                title=admin_t_zh,
                                                content=admin_c_zh,
                                                title_en=admin_t_en,
                                                content_en=admin_c_en,
                                                related_id=str(new_pkg.id),
                                                auto_commit=False,
                                            )
                                        db.commit()
                                    except Exception as notify_err:
                                        logger.warning(
                                            f"⚠️ [WEBHOOK] 套餐购买通知失败: {notify_err}"
                                        )
                                        db.rollback()
                except Exception as e:
                    logger.error(
                        f"❌ [WEBHOOK] 处理 package_purchase 失败: {e}",
                        exc_info=True,
                    )
            else:
                logger.warning(f"⚠️ [WEBHOOK] Payment Intent 成功但 metadata 中没有 task_id")
                logger.warning(f"  - Metadata: {json.dumps(payment_intent.get('metadata', {}), ensure_ascii=False)}")
                logger.warning(f"  - Payment Intent ID: {payment_intent_id}")

    elif event_type == "payment_intent.payment_failed":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        application_id_str = payment_intent.get("metadata", {}).get("application_id")
        error_message = payment_intent.get('last_payment_error', {}).get('message', 'Unknown error')
        
        logger.warning(f"❌ [WEBHOOK] Payment Intent 支付失败:")
        logger.warning(f"  - Payment Intent ID: {payment_intent_id}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - Application ID: {application_id_str}")
        logger.warning(f"  - 错误信息: {error_message}")
        logger.warning(f"  - 完整错误: {json.dumps(payment_intent.get('last_payment_error', {}), ensure_ascii=False)}")

        # 咨询合并批准(consult-approve)路径:TA2 从 price_locked 回到 price_agreed
        _failed_metadata_consult = payment_intent.get("metadata", {})
        _consult_t2_fail = _failed_metadata_consult.get("consultation_task_id")
        _consult_ta2_fail = _failed_metadata_consult.get("consultation_application_id")
        if _consult_t2_fail and _consult_ta2_fail:
            try:
                from app.consultation.approval import (
                    unlock_consultation_on_payment_failure,
                )
                unlock_consultation_on_payment_failure(
                    db,
                    consultation_task_id=int(_consult_t2_fail),
                    consultation_application_id=int(_consult_ta2_fail),
                )
                db.commit()
            except Exception as _cu_err:
                logger.warning(
                    f"⚠️ [WEBHOOK] 咨询解锁失败(失败路径): T2={_consult_t2_fail} "
                    f"TA2={_consult_ta2_fail} err={_cu_err}"
                )
                db.rollback()

        # 更新支付历史记录状态为失败
        if payment_intent_id:
            try:
                payment_history = db.query(models.PaymentHistory).filter(
                    models.PaymentHistory.payment_intent_id == payment_intent_id
                ).first()
                if payment_history:
                    try:
                        payment_history.transition_status("failed")
                    except ValueError as e:
                        logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                    # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                    payment_history.extra_metadata = {
                        **(payment_history.extra_metadata or {}),
                        "payment_failed": True,
                        "error_message": error_message,
                        "webhook_event_id": event_id,
                        "failed_at": get_utc_time().isoformat()
                    }
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已更新支付历史记录状态为失败: order_no={payment_history.order_no}")
            except Exception as e:
                logger.error(f"❌ [WEBHOOK] 更新支付历史记录失败: {e}", exc_info=True)

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _failed_metadata = payment_intent.get("metadata", {})
        _failed_wallet_tx_id = _failed_metadata.get("wallet_tx_id")
        _failed_wallet_deduction = _failed_metadata.get("wallet_deduction")
        if _failed_wallet_tx_id and _failed_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _failed_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_failed_wallet_deduction) / Decimal("100")
                _wcur = _failed_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_failed_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付失败，钱包扣款已退还: "
                    f"wallet_tx_id={_failed_wallet_tx_id}, amount={_failed_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_failed_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # 支付失败时，清除 payment_intent_id（申请状态保持为 pending，可以重新尝试）
        if task_id and application_id_str:
            application_id = int(application_id_str)
            task = crud.get_task(db, task_id)
            
            if task and task.status == "pending_payment" and task.taker_id:
                # 查找已批准的申请
                application = db.execute(
                    select(models.TaskApplication).where(
                        and_(
                            models.TaskApplication.id == application_id,
                            models.TaskApplication.task_id == task_id,
                            models.TaskApplication.status == "approved"
                        )
                    )
                ).scalar_one_or_none()
                
                if application:
                    logger.info(f"🔄 [WEBHOOK] 撤销申请批准: application_id={application_id}")
                    application.status = "pending"
                    task.taker_id = None
                    task.status = "open"
                    task.is_paid = 0
                    task.payment_intent_id = None
                    
                    # 发送通知
                    try:
                        from app import crud
                        crud.create_notification(
                            db,
                            application.applicant_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败，申请已撤销：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        crud.create_notification(
                            db,
                            task.poster_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        logger.info(f"✅ [WEBHOOK] 已发送支付失败通知")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 发送支付失败通知失败: {e}")
                    
                    try:
                        db.commit()
                        logger.info(f"✅ [WEBHOOK] 已撤销申请批准并恢复任务状态")
                        logger.info(f"  - 申请状态: pending")
                        logger.info(f"  - 任务状态: {task.status}")
                        logger.info(f"  - Taker ID: {task.taker_id}")
                        
                        # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                        try:
                            from app.services.task_service import TaskService
                            TaskService.invalidate_cache(task_id)
                            logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                        
                        # 清除任务列表缓存
                        try:
                            from app.redis_cache import invalidate_tasks_cache
                            invalidate_tasks_cache()
                            logger.info(f"✅ [WEBHOOK] 已清除任务列表缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                        db.rollback()
                else:
                    logger.warning(f"⚠️ [WEBHOOK] 未找到已批准的申请: application_id={application_id}")
            elif task:
                task.payment_intent_id = None
                try:
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id")
                    
                    # ⚠️ 优化：清除任务缓存
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.info(f"✅ [WEBHOOK] 已清除任务缓存（支付失败-无申请）")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    db.rollback()
    
    # 处理退款事件
    elif event_type == "charge.refunded":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        refund_request_id = charge.get("metadata", {}).get("refund_request_id")
        
        if task_id:
            task = crud.get_task(db, task_id)
            if task:
                # ✅ 安全修复：验证任务仍然已支付
                if not task.is_paid:
                    logger.warning(f"任务 {task_id} 已不再支付，跳过webhook退款处理")
                    return {"status": "skipped", "reason": "task_not_paid"}
                
                # ✅ 安全修复：验证退款申请状态（如果有关联的退款申请）
                if refund_request_id:
                    try:
                        refund_request_check = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        if refund_request_check and refund_request_check.status != "processing":
                            logger.warning(f"退款申请 {refund_request_id} 状态为 {refund_request_check.status}，不是processing，跳过webhook处理")
                            return {"status": "skipped", "reason": "refund_request_not_processing"}
                    except Exception as e:
                        logger.warning(f"检查退款申请状态时发生错误: {e}")
                
                # ✅ 修复金额精度：使用Decimal计算退款金额
                from decimal import Decimal
                refund_amount = Decimal(str(charge.get("amount_refunded", 0))) / Decimal('100')
                refund_amount_float = float(refund_amount)  # 用于显示和日志
                
                # 如果有关联的退款申请，更新退款申请状态
                if refund_request_id:
                    try:
                        refund_request = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        
                        if refund_request and refund_request.status == "processing":
                            # 更新退款申请状态为已完成
                            refund_request.status = "completed"
                            refund_request.completed_at = get_utc_time()
                            
                            # 发送系统消息通知用户
                            try:
                                from app.models import Message
                                import json
                                
                                content_zh = f"您的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}。退款将在5-10个工作日内退回您的原支付方式。"
                                content_en = f"Your refund request has been processed. Refund amount: £{refund_amount_float:.2f}. The refund will be returned to your original payment method within 5-10 business days."
                                
                                system_message = Message(
                                    sender_id=None,
                                    receiver_id=None,
                                    content=content_zh,
                                    task_id=task.id,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({
                                        "system_action": "refund_completed",
                                        "refund_request_id": refund_request.id,
                                        "refund_amount": float(refund_amount),
                                        "content_en": content_en
                                    }),
                                    created_at=get_utc_time()
                                )
                                db.add(system_message)
                                
                                # 发送通知给发布者
                                crud.create_notification(
                                    db=db,
                                    user_id=refund_request.poster_id,
                                    type="refund_completed",
                                    title="退款已完成",
                                    content=f"您的任务「{task.title}」的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}",
                                    related_id=str(task.id),
                                    auto_commit=False
                                )
                            except Exception as e:
                                logger.error(f"Failed to send refund completion notification: {e}")
                    except Exception as e:
                        logger.error(f"Failed to update refund request status: {e}")
                
                # ✅ 修复金额精度：使用Decimal进行金额比较
                # ✅ 支持部分退款：更新任务状态和托管金额
                task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
                
                if refund_amount >= task_amount:
                    # 全额退款
                    task.is_paid = 0
                    task.payment_intent_id = None
                    task.escrow_amount = 0.0
                    logger.info(f"✅ 全额退款，已更新任务支付状态")
                else:
                    # 部分退款：更新托管金额
                    # ✅ 计算退款后的剩余金额（最终成交金额）
                    remaining_amount = task_amount - refund_amount
                    
                    # ✅ 计算已转账的总金额
                    from sqlalchemy import func, and_
                    total_transferred = db.query(
                        func.sum(models.PaymentTransfer.amount).label('total_transferred')
                    ).filter(
                        and_(
                            models.PaymentTransfer.task_id == task.id,
                            models.PaymentTransfer.status == "succeeded"
                        )
                    ).scalar() or Decimal('0')
                    total_transferred = Decimal(str(total_transferred)) if total_transferred else Decimal('0')
                    
                    # ✅ 基于剩余金额重新计算平台服务费（按任务来源/类型取费率）
                    from app.utils.fee_calculator import calculate_application_fee
                    _ts = getattr(task, "task_source", None)
                    _tt = getattr(task, "task_type", None)
                    application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
                    
                    # ✅ 如果已经进行了部分转账，需要从剩余金额中扣除已转账部分
                    if total_transferred > 0:
                        remaining_after_transfer = remaining_amount - total_transferred
                        if remaining_after_transfer > 0:
                            remaining_application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                            new_escrow_amount = remaining_amount - Decimal(str(remaining_application_fee)) - total_transferred
                        else:
                            # 如果剩余金额已经全部转账，escrow为0
                            new_escrow_amount = Decimal('0')
                    
                    # 更新托管金额（确保不为负数）
                    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
                    logger.info(f"✅ 部分退款：退款金额 £{refund_amount_float:.2f}，剩余任务金额 £{remaining_amount:.2f}，已转账 £{total_transferred:.2f}，服务费 £{application_fee:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
                
                db.commit()
                logger.info(f"Task {task_id} refunded: £{refund_amount_float:.2f}")
    
    # 处理争议事件
    elif event_type == "charge.dispute.created":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        reason = dispute.get("reason", "unknown")
        amount = (dispute.get("amount") or 0) / 100.0
        logger.warning(f"Stripe 争议 charge.dispute.created: charge={charge_id}, task_id={task_id}, reason={reason}, amount={amount}")
        try:
            # 通知 poster、taker、管理员，并冻结任务状态
            if task_id:
                task = crud.get_task(db, task_id)
                if task:
                    # ✅ Stripe争议冻结：冻结任务状态，防止资金继续流出
                    if not hasattr(task, 'stripe_dispute_frozen') or task.stripe_dispute_frozen != 1:
                        task.stripe_dispute_frozen = 1
                        logger.warning(f"⚠️ 任务 {task_id} 因Stripe争议已冻结，防止资金继续流出")
                        
                        # 发送系统消息
                        try:
                            from app.models import Message
                            import json
                            
                            content_zh = f"⚠️ 此任务的支付发生Stripe争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}。在争议解决前，所有资金操作将被暂停。"
                            content_en = f"⚠️ A Stripe dispute has been raised for this task's payment. Task status is now frozen. Reason: {reason}, amount: £{amount:.2f}. All fund operations are suspended until the dispute is resolved."
                            system_message = Message(
                                sender_id=None,
                                receiver_id=None,
                                content=content_zh,
                                task_id=task.id,
                                message_type="system",
                                conversation_type="task",
                                meta=json.dumps({
                                    "system_action": "stripe_dispute_frozen",
                                    "charge_id": charge_id,
                                    "reason": reason,
                                    "amount": amount,
                                    "content_en": content_en
                                }),
                                created_at=get_utc_time()
                            )
                            db.add(system_message)
                        except Exception as e:
                            logger.error(f"Failed to send system message for dispute freeze: {e}")
                    
                    # 通知发布者
                    crud.create_notification(
                        db, str(task.poster_id),
                        "stripe_dispute", "Stripe 支付争议",
                        f"您的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                        related_id=str(task_id), auto_commit=False
                    )
                    # 通知接受者（如有）
                    if task.taker_id:
                        crud.create_notification(
                            db, str(task.taker_id),
                            "stripe_dispute", "Stripe 支付争议",
                            f"您参与的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                            related_id=str(task_id), auto_commit=False
                        )
            admins = db.query(models.AdminUser.id).filter(models.AdminUser.is_active == True).all()
            admin_content = f"Stripe 争议: charge={charge_id}, task_id={task_id or 'N/A'}, reason={reason}, amount=£{amount:.2f}"
            related = str(task_id) if task_id else (charge_id or "")
            for (admin_id,) in admins:
                crud.create_notification(
                    db, admin_id, "stripe_dispute", "Stripe 支付争议", admin_content,
                    related_id=related, auto_commit=False
                )
        except Exception as e:
            logger.error(f"charge.dispute.created 通知处理失败: {e}", exc_info=True)

        # Phase 7: 达人团队任务自动反转 Transfer
        if task_id:
            try:
                _handle_dispute_team_reversal(db, task_id)
            except Exception as e:
                logger.error(
                    f"_handle_dispute_team_reversal failed for task {task_id}: {e}",
                    exc_info=True,
                )
                # 不让 webhook 失败 —— 冻结与通知已经完成

    elif event_type == "charge.dispute.updated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        status = dispute.get("status")
        logger.info(f"Dispute updated for charge {charge_id}, task {task_id}: status={status}")
    
    elif event_type == "charge.dispute.closed":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        status = dispute.get("status")
        logger.info(f"Dispute closed for charge {charge_id}, task {task_id}: status={status}")
        
        # ✅ Stripe争议解冻：争议关闭后解冻任务状态
        if task_id:
            task = crud.get_task(db, task_id)
            if task and hasattr(task, 'stripe_dispute_frozen') and task.stripe_dispute_frozen == 1:
                task.stripe_dispute_frozen = 0
                logger.info(f"✅ 任务 {task_id} 的Stripe争议已关闭，已解冻任务状态")
                
                # 发送系统消息
                try:
                    from app.models import Message
                    import json
                    
                    content_zh = f"✅ Stripe争议已关闭（状态: {status}），任务状态已解冻，资金操作已恢复正常。"
                    content_en = f"✅ Stripe dispute has been closed (status: {status}). Task status is now unfrozen and fund operations have resumed."
                    system_message = Message(
                        sender_id=None,
                        receiver_id=None,
                        content=content_zh,
                        task_id=task.id,
                        message_type="system",
                        conversation_type="task",
                        meta=json.dumps({
                            "system_action": "stripe_dispute_unfrozen",
                            "charge_id": charge_id,
                            "status": status,
                            "content_en": content_en
                        }),
                        created_at=get_utc_time()
                    )
                    db.add(system_message)
                    db.commit()
                except Exception as e:
                    logger.error(f"Failed to send system message for dispute unfreeze: {e}")
                    db.rollback()
    
    elif event_type == "charge.dispute.funds_withdrawn":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        logger.warning(f"Dispute funds withdrawn for charge {charge_id}, task {task_id}")
    
    elif event_type == "charge.dispute.funds_reinstated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        logger.info(f"Dispute funds reinstated for charge {charge_id}, task {task_id}")

    # Connect 账户状态同步：专家团队 stripe_onboarding_complete + 服务冻结
    elif event_type == "account.updated":
        try:
            _handle_account_updated(db, event_data)
            db.commit()
        except Exception as e:
            logger.error(f"account.updated 处理失败: {e}", exc_info=True)
            db.rollback()

    # 处理其他 charge 事件
    elif event_type == "charge.succeeded":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        if task_id:
            logger.info(f"Charge succeeded for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.failed":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        logger.warning(f"Charge failed for task {task_id}: {charge.get('failure_message', 'Unknown error')}")
    
    elif event_type == "charge.captured":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        logger.info(f"Charge captured for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.refund.updated":
        refund = event_data
        charge_id = refund.get("charge")
        task_id = _safe_int_metadata(refund, "task_id")
        status = refund.get("status")
        logger.info(f"Refund updated for charge {charge_id}, task {task_id}: status={status}")
    
    # 处理 Payment Intent 其他事件
    elif event_type == "payment_intent.created":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent created for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.canceled":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.warning(f"⚠️ [WEBHOOK] Payment intent canceled: payment_intent_id={payment_intent_id}, task_id={task_id}")

        # 咨询合并批准(consult-approve)路径:TA2 从 price_locked 回到 price_agreed
        _canceled_consult_metadata = payment_intent.get("metadata", {})
        _consult_t2_cancel = _canceled_consult_metadata.get("consultation_task_id")
        _consult_ta2_cancel = _canceled_consult_metadata.get("consultation_application_id")
        if _consult_t2_cancel and _consult_ta2_cancel:
            try:
                from app.consultation.approval import (
                    unlock_consultation_on_payment_failure,
                )
                unlock_consultation_on_payment_failure(
                    db,
                    consultation_task_id=int(_consult_t2_cancel),
                    consultation_application_id=int(_consult_ta2_cancel),
                )
                db.commit()
            except Exception as _cu_err:
                logger.warning(
                    f"⚠️ [WEBHOOK] 咨询解锁失败(取消路径): T2={_consult_t2_cancel} "
                    f"TA2={_consult_ta2_cancel} err={_cu_err}"
                )
                db.rollback()

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _canceled_metadata = payment_intent.get("metadata", {})
        _canceled_wallet_tx_id = _canceled_metadata.get("wallet_tx_id")
        _canceled_wallet_deduction = _canceled_metadata.get("wallet_deduction")
        if _canceled_wallet_tx_id and _canceled_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _canceled_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_canceled_wallet_deduction) / Decimal("100")
                _wcur = _canceled_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_canceled_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付取消，钱包扣款已退还: "
                    f"wallet_tx_id={_canceled_wallet_tx_id}, amount={_canceled_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_canceled_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # ⚠️ 处理 PaymentIntent 取消事件
        # 新流程：任务保持 open 状态，支付取消时只需清除 payment_intent_id
        # 这样用户可以继续批准其他申请者或重新批准同一个申请者
        if task_id:
            task = crud.get_task(db, task_id)
            # 检查任务状态：open 或 pending_payment（兼容旧流程）
            if task and task.payment_intent_id == payment_intent_id and task.status in ["open", "pending_payment"]:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 的 PaymentIntent 已取消，"
                    f"任务状态: {task.status}，清除 payment_intent_id，允许用户重新创建支付"
                )
                # 清除 payment_intent_id，允许用户重新创建支付
                task.payment_intent_id = None
                db.commit()
                logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id，允许重新创建支付")
            else:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 状态不匹配或 payment_intent_id 不匹配，"
                    f"当前状态: {task.status if task else 'N/A'}, payment_intent_id: {task.payment_intent_id if task else 'N/A'}"
                )
    
    elif event_type == "payment_intent.requires_action":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent requires action for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.processing":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent processing for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    # 处理 Invoice 事件（用于订阅）
    elif event_type == "invoice.paid":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.info(f"Invoice paid: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.payment_failed":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.warning(f"Invoice payment failed: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.finalized":
        invoice = event_data
        logger.info(f"Invoice finalized: invoice_id={invoice.get('id')}")
    
    # 保留对 Checkout Session 的兼容性（包括 iOS 微信支付二维码）
    elif event_type == "checkout.session.completed":
        session = event_data
        metadata = session.get("metadata", {})
        task_id = _safe_int_metadata(session, "task_id")
        payment_type = metadata.get("payment_type", "")
        
        logger.info(f"[WEBHOOK] Checkout Session 完成: session_id={session.get('id')}, task_id={task_id}, payment_type={payment_type}")
        
        if task_id:
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:
                task.is_paid = 1
                # 存储 PaymentIntent ID（用于后续退款），Checkout Session 内部创建了 PaymentIntent
                session_pi = session.get("payment_intent")
                if session_pi and not task.payment_intent_id:
                    task.payment_intent_id = session_pi
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0

                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
                
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ Checkout session 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                if task.status == "pending_payment":
                    task.status = "in_progress"
                
                # 更新支付历史记录状态
                try:
                    checkout_session_id = session.get("id")
                    if checkout_session_id:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.task_id == task_id,
                            models.PaymentHistory.status == "pending"
                        ).order_by(models.PaymentHistory.created_at.desc()).first()
                        
                        if payment_history:
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.payment_intent_id = session.get("payment_intent") or checkout_session_id
                            logger.info(f"[WEBHOOK] 更新支付历史记录状态为 succeeded: order_no={payment_history.order_no}")
                except Exception as e:
                    logger.warning(f"[WEBHOOK] 更新支付历史记录失败: {e}")
                
                # 跳蚤市场：Checkout Session 完成时更新商品状态为 sold（微信支付等）
                flea_market_item_id = metadata.get("flea_market_item_id")
                if flea_market_item_id:
                    try:
                        from app.models import FleaMarketItem
                        from app.id_generator import parse_flea_market_id
                        db_item_id = parse_flea_market_id(flea_market_item_id)
                        # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录
                        flea_item = db.query(FleaMarketItem).filter(
                            and_(
                                FleaMarketItem.id == db_item_id,
                                FleaMarketItem.sold_task_id == task_id,
                                FleaMarketItem.status.in_(["active", "reserved"])
                            )
                        ).with_for_update().first()
                        if flea_item:
                            flea_item.status = "sold"
                            if flea_item.sold_task_id != task_id:
                                flea_item.sold_task_id = task_id
                            db.flush()
                            logger.info(f"✅ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 状态已更新为 sold (task_id: {task_id})")
                            from app.flea_market_extensions import invalidate_item_cache
                            invalidate_item_cache(flea_item.id)
                            # 发送商品已售出通知
                            try:
                                item_title = flea_item.title or metadata.get("task_title", "商品")
                                crud.create_notification(
                                    db=db,
                                    user_id=flea_item.seller_id,
                                    type="flea_market_sold",
                                    title="商品已售出",
                                    content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                    related_id=str(task_id),
                                    auto_commit=False,
                                )
                                buyer_id = metadata.get("user_id")
                                if buyer_id:
                                    crud.create_notification(
                                        db=db,
                                        user_id=str(buyer_id),
                                        type="flea_market_payment_success",
                                        title="支付成功",
                                        content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                            except Exception as notify_err:
                                logger.warning(f"⚠️ [WEBHOOK] 创建跳蚤市场售出通知失败: {notify_err}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 未找到 (task_id: {task_id})")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 微信支付更新跳蚤市场商品状态失败: {e}", exc_info=True)
                
                db.commit()
                
                # 记录微信支付完成（用于调试）
                if payment_type == "wechat_checkout":
                    logger.info(f"✅ [WEBHOOK] 微信支付完成 (iOS WebView): task_id={task_id}, escrow_amount={task.escrow_amount}")
                else:
                    logger.info(f"Task {task_id} payment completed via Stripe Checkout Session, status updated to in_progress, escrow_amount: {task.escrow_amount}")
    
    # 处理 Transfer 事件（转账给任务接受人）
    elif event_type == "transfer.paid":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = _safe_int_metadata(transfer, "task_id")
        
        logger.info(f"✅ [WEBHOOK] Transfer 支付成功:")
        logger.info(f"  - Transfer ID: {transfer_id}")
        logger.info(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.info(f"  - Task ID: {task_id}")
        logger.info(f"  - Amount: {transfer.get('amount')} {transfer.get('currency')}")
        
        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()
            
            if transfer_record:
                # 防止重复处理：检查是否已经成功
                if transfer_record.status == "succeeded":
                    logger.warning(f"⚠️ [WEBHOOK] Transfer 记录已成功，跳过重复处理: transfer_record_id={transfer_record_id}")
                else:
                    # 更新转账记录状态
                    from decimal import Decimal
                    transfer_record.status = "succeeded"
                    transfer_record.succeeded_at = get_utc_time()
                    transfer_record.last_error = None
                    transfer_record.next_retry_at = None
                    
                    # 更新任务状态
                    task = crud.get_task(db, transfer_record.task_id)
                    if task:
                        task.is_confirmed = 1
                        task.paid_to_user_id = transfer_record.taker_id
                        task.escrow_amount = Decimal('0.0')  # 转账后清空托管金额
                        logger.info(f"✅ [WEBHOOK] 任务 {task.id} 转账完成，金额已转给接受人 {transfer_record.taker_id}")
                        
                        # 发送通知给任务接收人：任务金已发放
                        try:
                            # 格式化金额（从 Decimal 转换为字符串，保留两位小数）
                            amount_display = f"£{float(transfer_record.amount):.2f}"
                            task_title = task.title or f"任务 #{task.id}"
                            
                            # 创建通知内容：任务金已发放（金额 - 任务标题）
                            notification_content = f"任务金已发放：{amount_display} - {task_title}"
                            
                            # 创建通知
                            crud.create_notification(
                                db=db,
                                user_id=transfer_record.taker_id,
                                type="task_reward_paid",  # 任务奖励已支付
                                title="任务金已发放",
                                content=notification_content,
                                related_id=str(task.id),  # 关联任务ID，方便前端跳转
                                auto_commit=False  # 不自动提交，等待下面的 db.commit()
                            )
                            
                            # 发送推送通知
                            try:
                                send_push_notification(
                                    db=db,
                                    user_id=transfer_record.taker_id,
                                    notification_type="task_reward_paid",
                                    data={"task_id": task.id, "amount": str(transfer_record.amount)},
                                    template_vars={"task_title": task.title, "task_id": task.id}
                                )
                            except Exception as e:
                                logger.warning(f"发送任务金发放推送通知失败: {e}")
                                # 推送通知失败不影响主流程
                            
                            logger.info(f"✅ [WEBHOOK] 已发送任务金发放通知给用户 {transfer_record.taker_id}")
                        except Exception as e:
                            # 通知发送失败不影响转账流程
                            logger.error(f"❌ [WEBHOOK] 发送任务金发放通知失败: {e}", exc_info=True)
                    
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为成功: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer（metadata 含 wallet_tx_id）
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _w_tx_id = transfer["metadata"]["wallet_tx_id"]
            _w_user_id = transfer["metadata"].get("user_id", "")
            logger.info(
                f"✅ [WEBHOOK] 钱包提现 Transfer 成功: "
                f"transfer_id={transfer_id}, wallet_tx_id={_w_tx_id}, user={_w_user_id}"
            )
            try:
                from app.wallet_service import complete_withdrawal as _cw
                from app.wallet_models import WalletTransaction as _WT
                # 幂等：仅 pending 状态才更新
                _existing = db.query(_WT).filter(_WT.id == int(_w_tx_id)).first()
                if _existing and _existing.status == "pending":
                    _cw(db, int(_w_tx_id), transfer_id)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现已确认: wallet_tx_id={_w_tx_id}")
                elif _existing:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_existing.status}，跳过: wallet_tx_id={_w_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_w_tx_id}")
            except Exception as _w_err:
                logger.error(f"❌ [WEBHOOK] 确认钱包提现失败: wallet_tx_id={_w_tx_id}, error={_w_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")

    elif event_type == "transfer.failed":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = _safe_int_metadata(transfer, "task_id")
        failure_code = transfer.get("failure_code", "unknown")
        failure_message = transfer.get("failure_message", "Unknown error")

        logger.warning(f"❌ [WEBHOOK] Transfer 支付失败:")
        logger.warning(f"  - Transfer ID: {transfer_id}")
        logger.warning(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - 失败代码: {failure_code}")
        logger.warning(f"  - 失败信息: {failure_message}")

        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()

            if transfer_record:
                # 更新转账记录状态为失败
                transfer_record.status = "failed"
                transfer_record.last_error = f"{failure_code}: {failure_message}"
                transfer_record.next_retry_at = None

                # 不更新任务状态，保持原状

                db.commit()
                logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为失败: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer 失败
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _wf_tx_id = transfer["metadata"]["wallet_tx_id"]
            _wf_user_id = transfer["metadata"].get("user_id", "")
            logger.warning(
                f"❌ [WEBHOOK] 钱包提现 Transfer 失败: "
                f"transfer_id={transfer_id}, wallet_tx_id={_wf_tx_id}, user={_wf_user_id}, "
                f"failure={failure_code}: {failure_message}"
            )
            try:
                from app.wallet_service import fail_withdrawal as _fw
                from app.wallet_models import WalletTransaction as _WT2
                from decimal import Decimal as _Dec
                _fail_tx = db.query(_WT2).filter(_WT2.id == int(_wf_tx_id)).first()
                if _fail_tx and _fail_tx.status == "pending":
                    _refund_amount = abs(_fail_tx.amount)
                    # 用 DB 记录的 user_id，不信任 metadata（防御性）
                    _fw(db, int(_wf_tx_id), _fail_tx.user_id, _refund_amount, currency=_fail_tx.currency)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现失败，余额已退还: wallet_tx_id={_wf_tx_id}, amount={_refund_amount}")
                elif _fail_tx:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_fail_tx.status}，跳过: wallet_tx_id={_wf_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_wf_tx_id}")
            except Exception as _wf_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包提现余额失败: wallet_tx_id={_wf_tx_id}, error={_wf_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")
    
    else:
        logger.info(f"ℹ️ [WEBHOOK] 未处理的事件类型: {event_type}")
        logger.info(f"  - 事件ID: {event_id}")
        # 只记录关键字段，避免日志过长
        event_summary = {}
        if isinstance(event_data, dict):
            for key in ['id', 'object', 'status', 'amount', 'currency']:
                if key in event_data:
                    event_summary[key] = event_data[key]
        logger.info(f"  - 事件数据摘要: {json.dumps(event_summary, ensure_ascii=False)}")
    
    # 标记事件处理完成
    if event_id:
        try:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = True
                webhook_event.processed_at = get_utc_time()
                webhook_event.processing_error = None
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 事件处理完成，已标记: event_id={event_id}")
        except Exception as e:
            logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}", exc_info=True)
            db.rollback()
    
    # 记录处理耗时和总结
    processing_time = time.time() - start_time
    logger.debug(f"⏱️ [WEBHOOK] 处理耗时: {processing_time:.3f} 秒")
    logger.info(f"✅ [WEBHOOK] Webhook 处理完成: {event_type}")
    logger.debug("=" * 80)
    
    return {"status": "success"}


@router.post("/tasks/{task_id}/confirm_complete")
def confirm_task_complete(
    task_id: int, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    [已弃用] 确认任务完成并通过 Stripe Transfer 直接转账给接受人的 Connect 账户。

    前端已切换到 POST /tasks/{task_id}/confirm_completion（钱包入账模式）。
    此端点仅供管理后台或特殊场景使用（如接受人要求直接 Stripe 到账）。
    自动结算由 auto_transfer_expired_tasks 定时任务处理。

    要求：
    1. 任务必须已支付
    2. 任务状态必须为 completed
    3. 任务接受人必须有 Stripe Connect 账户且已完成 onboarding
    """
    import logging

    logger = logging.getLogger(__name__)

    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if not task.is_paid or task.status != "completed" or task.is_confirmed:
        raise HTTPException(
            status_code=400, detail="Task not eligible for confirmation."
        )
    
    if not task.taker_id:
        raise HTTPException(
            status_code=400, detail="Task has no taker."
        )
    
    # 获取任务接受人信息
    taker = crud.get_user_by_id(db, task.taker_id)
    if not taker:
        raise HTTPException(
            status_code=404, detail="Task taker not found."
        )
    
    # 检查 escrow_amount 是否大于0
    if task.escrow_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="任务托管金额为0，无需转账。"
        )

    # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
    try:
        # 确保 escrow_amount 正确（任务金额 - 平台服务费）
        # I8: 使用 Decimal 保精度，避免浮点累加误差
        if task.escrow_amount <= 0:
            task_amount_dec = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else (
                Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
            )
            from app.utils.fee_calculator import calculate_application_fee
            task_source = getattr(task, "task_source", None)
            task_type = getattr(task, "task_type", None)
            # calculate_application_fee 返回 float — 用 str 中转以避免二进制浮点误差
            application_fee_dec = Decimal(str(calculate_application_fee(float(task_amount_dec), task_source, task_type)))
            task.escrow_amount = max(Decimal('0'), task_amount_dec - application_fee_dec)
            logger.info(f"重新计算 escrow_amount: 任务金额={task_amount_dec}, 服务费={application_fee_dec}, escrow={task.escrow_amount}")

        escrow_amount = Decimal(str(task.escrow_amount))
        currency = (task.currency or "GBP").upper()
        payout_idempotency_key = f"earning:task:{task_id}:user:{taker.id}"

        # Team-aware destination: 团队任务 → experts.stripe_account_id,
        # 个人任务 → taker.stripe_account_id. spec §3.2 (v2)
        from app.services.expert_task_resolver import resolve_payout_destination
        is_team_task = bool(task.taker_expert_id)
        destination_stripe_id = resolve_payout_destination(db, task)

        if destination_stripe_id:
            # 有 Stripe Connect 账户 → 尝试直接转账
            amount_minor = int(escrow_amount * 100)
            try:
                stripe_transfer = stripe.Transfer.create(
                    amount=amount_minor,
                    currency=currency.lower(),
                    destination=destination_stripe_id,
                    description=f"Task #{task_id} payout",
                    metadata={
                        "task_id": str(task_id),
                        "taker_id": str(taker.id),
                        "taker_expert_id": str(task.taker_expert_id) if task.taker_expert_id else "",
                    },
                    idempotency_key=payout_idempotency_key,
                )
                logger.info(f"✅ 直接 Stripe Transfer: task={task_id}, transfer={stripe_transfer.id}, amount=£{escrow_amount:.2f}")
                payout_method = "stripe_transfer"
            except stripe.error.StripeError as stripe_err:
                if is_team_task:
                    # 团队任务不回退钱包
                    logger.error(f"任务 {task_id} 团队 Stripe Transfer 失败: {stripe_err}")
                    db.rollback()
                    raise HTTPException(status_code=500, detail={
                        "error_code": "team_payout_failed",
                        "message": f"Team Stripe transfer failed: {stripe_err}",
                    })
                # Stripe 明确拒绝 → 回退到钱包
                logger.warning(f"任务 {task_id} Stripe Transfer 被拒绝，回退到钱包入账: {stripe_err}")
                from app.wallet_service import credit_wallet
                credit_wallet(
                    db,
                    user_id=taker.id,
                    amount=escrow_amount,
                    source="task_earning",
                    related_id=str(task_id),
                    related_type="task",
                    description=f"任务 #{task_id} 收入（Stripe失败回退）",
                    currency=currency,
                    idempotency_key=payout_idempotency_key,
                )
                payout_method = "wallet_fallback"
        else:
            if is_team_task:
                # 防御性：团队任务必须走 Stripe，无 destination 视为错误
                logger.error(f"任务 {task_id} 团队任务无 Stripe 目的地")
                db.rollback()
                raise HTTPException(status_code=500, detail={
                    "error_code": "team_payout_failed",
                    "message": "Team task has no Stripe destination",
                })
            # 无 Stripe Connect 账户 → 入本地钱包
            from app.wallet_service import credit_wallet
            credit_wallet(
                db,
                user_id=taker.id,
                amount=escrow_amount,
                source="task_earning",
                related_id=str(task_id),
                related_type="task",
                description=f"任务 #{task_id} 收入 - {task.title}",
                currency=currency,
                idempotency_key=payout_idempotency_key,
            )
            logger.info(f"✅ 钱包入账: task={task_id}, amount=£{escrow_amount:.2f}（用户无 Stripe Connect）")
            payout_method = "wallet"

        # 更新任务状态
        task.is_confirmed = 1
        task.paid_to_user_id = task.taker_id
        transfer_amount = task.escrow_amount  # 先保存转账金额
        task.escrow_amount = 0.0  # 入账后清空托管金额

        db.commit()

        return {
            "message": f"Payment sent via {payout_method}.",
            "amount": transfer_amount,
            "currency": currency
        }

    except HTTPException:
        # 团队任务 payout 失败的结构化错误 → 原样抛出 (spec §3.2 v2)
        raise
    except Exception as e:
        logger.error(f"Error confirming task {task_id}: {e}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="确认任务完成时发生错误，请重试。"
        )


# 已迁移到 admin_task_management_routes.py: /admin/tasks, /admin/tasks/{task_id}, /admin/tasks/batch-update, /admin/tasks/batch-delete


# 管理员处理客服请求相关API
@router.post("/users/vip/activate")
@rate_limit("vip_activate")
def activate_vip(
    http_request: Request,
    activation_request: schemas.VIPActivationRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """激活VIP会员（通过IAP购买）- 生产级实现"""
    from app.iap_verification_service import iap_verification_service
    from datetime import datetime, timezone

    request = activation_request
    try:
        # 1. 验证产品ID
        if not iap_verification_service.validate_product_id(request.product_id):
            raise HTTPException(status_code=400, detail="无效的产品ID")
        
        # 2. 验证交易JWS
        try:
            transaction_info = iap_verification_service.verify_transaction_jws(request.transaction_jws)
        except ValueError as e:
            logger.error(f"JWS验证失败: {str(e)}")
            raise HTTPException(status_code=400, detail=f"交易验证失败: {str(e)}")
        
        # 3. 验证交易ID是否匹配
        if transaction_info["transaction_id"] != request.transaction_id:
            raise HTTPException(status_code=400, detail="交易ID不匹配")
        
        # 4. 验证产品ID是否匹配
        if transaction_info["product_id"] != request.product_id:
            raise HTTPException(status_code=400, detail="产品ID不匹配")
        
        # 5. 检查是否已经处理过这个交易（防止重复激活）
        existing_subscription = crud.get_vip_subscription_by_transaction_id(db, request.transaction_id)
        if existing_subscription:
            logger.warning(f"交易 {request.transaction_id} 已被处理过，用户: {existing_subscription.user_id}")
            # 如果交易已存在，检查是否是同一用户
            if existing_subscription.user_id != current_user.id:
                raise HTTPException(status_code=400, detail="该交易已被其他用户使用")
            # 如果是同一用户，返回现有订阅信息
            return {
                "message": "VIP已激活（重复请求）",
                "user_level": current_user.user_level,
                "product_id": request.product_id,
                "subscription_id": existing_subscription.id
            }
        
        # 6. 从Apple服务器获取交易信息（可选，用于额外验证）
        server_transaction_info = None
        try:
            server_transaction_info = iap_verification_service.get_transaction_info(
                request.transaction_id,
                transaction_info["environment"]
            )
            if server_transaction_info:
                logger.info(f"从Apple服务器获取交易信息成功: {request.transaction_id}")
        except Exception as e:
            logger.warning(f"从Apple服务器获取交易信息失败（继续处理）: {str(e)}")
        
        # 7. 转换时间戳
        purchase_date = iap_verification_service.convert_timestamp_to_datetime(
            transaction_info["purchase_date"]
        )
        expires_date = None
        if transaction_info["expires_date"]:
            expires_date = iap_verification_service.convert_timestamp_to_datetime(
                transaction_info["expires_date"]
            )
        
        # 8. 创建VIP订阅记录
        subscription = crud.create_vip_subscription(
            db=db,
            user_id=current_user.id,
            product_id=request.product_id,
            transaction_id=request.transaction_id,
            original_transaction_id=transaction_info.get("original_transaction_id"),
            transaction_jws=request.transaction_jws,
            purchase_date=purchase_date,
            expires_date=expires_date,
            is_trial_period=transaction_info["is_trial_period"],
            is_in_intro_offer_period=transaction_info["is_in_intro_offer_period"],
            environment=transaction_info["environment"],
            status="active"
        )
        
        # 8.1 若为同一条订阅线升级（如月订→年订），将旧订阅标记为 replaced，与 Apple 状态一致
        otid = transaction_info.get("original_transaction_id")
        if otid:
            crud.mark_replaced_by_upgrade(
                db, current_user.id, otid, request.transaction_id
            )
        
        # 9. 更新用户VIP状态
        # 根据产品ID确定VIP类型
        user_level = "vip"
        if request.product_id == "com.link2ur.vip.yearly":
            # 年度订阅可以设置为super VIP（根据业务需求）
            user_level = "vip"  # 或 "super"
        
        crud.update_user_vip_status(db, current_user.id, user_level)
        try:
            from app.vip_subscription_service import vip_subscription_service
            vip_subscription_service.invalidate_vip_cache(current_user.id)
        except Exception as e:
            logger.debug("VIP cache invalidate: %s", e)

        # 10. 记录日志
        logger.info(
            f"用户 {current_user.id} 通过IAP激活VIP成功: "
            f"产品ID={request.product_id}, "
            f"交易ID={request.transaction_id}, "
            f"订阅ID={subscription.id}, "
            f"环境={transaction_info['environment']}"
        )
        
        # 11. 发送通知（可选）
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=current_user.id,
                notification_type="vip_activated",
                data={"type": "vip_activated", "subscription_id": subscription.id}
            )
        except Exception as e:
            logger.warning(f"发送VIP激活通知失败: {str(e)}")
        
        return {
            "message": "VIP激活成功",
            "user_level": user_level,
            "product_id": request.product_id,
            "subscription_id": subscription.id,
            "expires_date": expires_date.isoformat() if expires_date else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"激活VIP失败: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"激活VIP失败: {str(e)}")


@router.get("/users/vip/status")
def get_vip_status(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取当前用户的VIP订阅状态（带缓存）"""
    from app.vip_subscription_service import vip_subscription_service

    subscription_status = vip_subscription_service.check_subscription_status_cached(
        db, current_user.id
    )
    return {
        "user_level": current_user.user_level,
        "is_vip": current_user.user_level in ["vip", "super"],
        "subscription": subscription_status
    }


@router.get("/users/vip/history")
def get_vip_history(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0, le=100000)
):
    """获取当前用户的VIP订阅历史"""
    rows = crud.get_vip_subscription_history(db, current_user.id, limit=limit, offset=offset)
    total = crud.count_vip_subscriptions_by_user(db, current_user.id)
    items = []
    for s in rows:
        items.append({
            "id": s.id,
            "product_id": s.product_id,
            "transaction_id": s.transaction_id,
            "purchase_date": s.purchase_date.isoformat() if s.purchase_date else None,
            "expires_date": s.expires_date.isoformat() if s.expires_date else None,
            "status": s.status,
            "environment": s.environment,
            "is_trial_period": s.is_trial_period,
            "is_in_intro_offer_period": s.is_in_intro_offer_period,
            "auto_renew_status": s.auto_renew_status,
        })
    return {"items": items, "total": total}


@router.post("/webhooks/apple-iap")
async def apple_iap_webhook(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Apple IAP Webhook端点
    处理 App Store Server Notifications V2（signedPayload 验证）及 V1 兼容。
    """
    from app.vip_subscription_service import vip_subscription_service
    from app.apple_webhook_verifier import verify_and_decode_notification

    try:
        body = await request.json()
    except Exception as e:
        logger.warning("Apple IAP Webhook 无效 JSON: %s", e)
        return JSONResponse(status_code=400, content={"status": "error", "message": "Invalid JSON"})

    reject_v1 = os.getenv("APPLE_IAP_WEBHOOK_REJECT_V1", "true").lower() == "true"

    try:
        if "signedPayload" in body:
            signed_payload = body["signedPayload"]
            decoded = verify_and_decode_notification(signed_payload)
            if not decoded:
                logger.warning("Apple IAP Webhook V2 签名验证失败或未配置")
                return JSONResponse(
                    status_code=401,
                    content={"status": "error", "message": "Verification failed"},
                )
            notification_type = decoded.get("notificationType") or ""
            data = decoded.get("data") or {}
            logger.info("Apple IAP Webhook V2 已验证: %s", notification_type)

            if notification_type == "SUBSCRIBED":
                logger.info("V2 新订阅通知（激活由 /users/vip/activate 处理）")
            elif notification_type == "DID_RENEW":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_renewal(db, vip_subscription_service, jws)
                else:
                    logger.warning("V2 DID_RENEW 缺少 signedTransactionInfo")
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V2 订阅续费失败")
            elif notification_type == "CANCEL":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_cancel(db, vip_subscription_service, jws)
            elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
                logger.info("V2 续订状态变更")
            elif notification_type == "EXPIRED":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_expired(db, vip_subscription_service, jws)
            elif notification_type == "REFUND":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_refund(db, vip_subscription_service, jws)
            elif notification_type == "REVOKE":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_revoke(db, vip_subscription_service, jws)
            elif notification_type == "GRACE_PERIOD_EXPIRED":
                logger.warning("V2 宽限期已过期")
            elif notification_type == "OFFER_REDEEMED":
                logger.info("V2 优惠兑换")
            elif notification_type == "DID_CHANGE_RENEWAL_PREF":
                logger.info("V2 续订偏好变更")
            elif notification_type == "RENEWAL_EXTENDED":
                logger.info("V2 续订已延长")
            elif notification_type == "TEST":
                logger.info("V2 测试通知")
            else:
                logger.info("V2 未处理类型: %s", notification_type)
            return {"status": "success"}

        notification_type = body.get("notification_type")
        if notification_type is not None:
            if reject_v1:
                logger.warning("拒绝未验证的 V1 Webhook（APPLE_IAP_WEBHOOK_REJECT_V1=true）")
                return JSONResponse(
                    status_code=400,
                    content={"status": "error", "message": "V1 notifications rejected"},
                )
            unified_receipt = body.get("unified_receipt", {})
            latest_receipt_info = unified_receipt.get("latest_receipt_info", [])
            logger.info("Apple IAP Webhook V1（未验证）: %s", notification_type)

            if notification_type == "INITIAL_BUY":
                logger.info("V1 初始购买")
            elif notification_type == "DID_RENEW" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                orig = lt.get("original_transaction_id")
                tid = lt.get("transaction_id")
                logger.info("V1 续费: %s -> %s（无 JWS，仅记录）", orig, tid)
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V1 续费失败")
            elif notification_type == "CANCEL" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                reason = lt.get("cancellation_reason")
                if tid:
                    vip_subscription_service.cancel_subscription(db, tid, reason)
            elif notification_type == "REFUND" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                if tid:
                    vip_subscription_service.process_refund(db, tid, "Apple退款")

            return {"status": "success"}

        logger.warning("Apple IAP Webhook 无法识别格式（无 signedPayload 且无 notification_type）")
        return JSONResponse(status_code=400, content={"status": "error", "message": "Unknown payload"})
    except Exception as e:
        logger.error("处理Apple IAP Webhook失败: %s", e, exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)},
        )



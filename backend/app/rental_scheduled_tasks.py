"""
租赁定时任务
- 逾期检测
- pending_return 超时自动完成
- 已批准申请支付过期
"""

import logging
from datetime import timedelta
from decimal import Decimal

from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_overdue_rentals(db: Session):
    """
    检查逾期租赁：status == 'active' 且 end_date < now()
    标记为 overdue，通知双方（仅通知，不罚款）
    """
    now = get_utc_time()
    count = 0

    rentals = (
        db.query(models.FleaMarketRental)
        .filter(
            models.FleaMarketRental.status == "active",
            models.FleaMarketRental.end_date < now,
        )
        .limit(200)
        .all()
    )

    for rental in rentals:
        try:
            rental.status = "overdue"
            rental.updated_at = now

            # 获取物品信息
            item = (
                db.query(models.FleaMarketItem)
                .filter(models.FleaMarketItem.id == rental.item_id)
                .first()
            )
            item_title = item.title if item else f"物品#{rental.item_id}"
            seller_id = item.seller_id if item else None

            # 通知租客
            notification_renter = models.Notification(
                user_id=rental.renter_id,
                type="flea_market_rental_overdue",
                title="租赁已逾期",
                content=f"您租借的「{item_title}」已超过归还日期，请尽快归还。",
                related_id=str(rental.id),
            )
            db.add(notification_renter)
            db.flush()

            # 通知物主
            if seller_id:
                notification_seller = models.Notification(
                    user_id=seller_id,
                    type="flea_market_rental_overdue",
                    title="租赁已逾期",
                    content=f"您出租的「{item_title}」已超过归还日期，租客尚未归还。",
                    related_id=str(rental.id),
                )
                db.add(notification_seller)
                db.flush()

            count += 1
        except Exception as e:
            logger.error(f"处理逾期租赁 {rental.id} 失败: {e}", exc_info=True)

    if count > 0:
        db.commit()
        logger.info(f"逾期租赁检查完成，标记 {count} 条为 overdue")

    return count


def check_pending_return_timeout(db: Session):
    """
    检查 pending_return 超时：status == 'pending_return' 且 updated_at 距今 > 7 天
    自动完成：设 status='returned'，退押金，租金入账物主钱包，通知双方
    """
    now = get_utc_time()
    timeout_threshold = now - timedelta(days=7)
    count = 0

    rentals = (
        db.query(models.FleaMarketRental)
        .filter(
            models.FleaMarketRental.status == "pending_return",
            models.FleaMarketRental.updated_at < timeout_threshold,
        )
        .limit(200)
        .all()
    )

    for rental in rentals:
        try:
            # 获取物品信息
            item = (
                db.query(models.FleaMarketItem)
                .filter(models.FleaMarketItem.id == rental.item_id)
                .first()
            )
            item_title = item.title if item else f"物品#{rental.item_id}"
            seller_id = item.seller_id if item else None

            # 退还押金（Stripe Partial Refund）
            stripe_refund_id = None
            deposit_pence = int(float(rental.deposit_amount) * 100)
            if deposit_pence > 0 and rental.task_id:
                try:
                    import stripe
                    task = (
                        db.query(models.Task)
                        .filter(models.Task.id == rental.task_id)
                        .first()
                    )
                    if task and task.payment_intent_id:
                        refund = stripe.Refund.create(
                            payment_intent=task.payment_intent_id,
                            amount=deposit_pence,
                        )
                        stripe_refund_id = refund.id
                        logger.info(
                            f"租赁 {rental.id} 超时自动退押金成功: {stripe_refund_id}, amount={deposit_pence}"
                        )
                except Exception as e:
                    logger.error(f"租赁 {rental.id} 超时自动退押金失败: {e}", exc_info=True)
                    # 押金退款失败不阻塞流程，继续处理

            # 租金入账到物主钱包（扣除平台服务费）
            wallet_credited = False
            if seller_id:
                gross_rent = Decimal(str(rental.total_rent))
                if gross_rent > 0:
                    try:
                        from app.utils.fee_calculator import calculate_application_fee_decimal
                        from app.wallet_service import credit_wallet

                        fee_amount = calculate_application_fee_decimal(
                            gross_rent, task_source="flea_market_rental"
                        )
                        net_rent = gross_rent - fee_amount

                        credit_wallet(
                            db=db,
                            user_id=seller_id,
                            amount=net_rent,
                            source="flea_market_rental",
                            related_id=str(rental.id),
                            related_type="rental",
                            description=f"租赁 #{rental.id} 租金收入（超时自动完成） — {item_title}",
                            fee_amount=fee_amount,
                            gross_amount=gross_rent,
                            currency=rental.currency or "GBP",
                            idempotency_key=f"earning:rental:{rental.id}:owner:{seller_id}",
                        )
                        wallet_credited = True
                        logger.info(
                            f"租赁 {rental.id} 超时自动入账: 总额={float(gross_rent)}, "
                            f"服务费={float(fee_amount)}, 净额={float(net_rent)}"
                        )
                    except Exception as e:
                        logger.error(f"租赁 {rental.id} 超时自动入账失败: {e}", exc_info=True)

            # 更新租赁状态
            rental.status = "returned"
            rental.returned_at = now
            rental.updated_at = now
            rental.deposit_status = "refunded" if stripe_refund_id else rental.deposit_status
            if stripe_refund_id:
                rental.stripe_refund_id = stripe_refund_id

            # 通知租客
            notification_renter = models.Notification(
                user_id=rental.renter_id,
                type="flea_market_rental_auto_completed",
                title="租赁已自动完成",
                content=f"您租借的「{item_title}」归还确认已超时 7 天，系统已自动完成租赁。"
                        + (f"\n押金已退还。" if stripe_refund_id else ""),
                related_id=str(rental.id),
            )
            db.add(notification_renter)
            db.flush()

            # 通知物主
            if seller_id:
                notification_seller = models.Notification(
                    user_id=seller_id,
                    type="flea_market_rental_auto_completed",
                    title="租赁已自动完成",
                    content=f"「{item_title}」的租赁归还确认已超时 7 天，系统已自动完成。"
                            + (f"\n租金已入账您的钱包。" if wallet_credited else ""),
                    related_id=str(rental.id),
                )
                db.add(notification_seller)
                db.flush()

            count += 1
        except Exception as e:
            logger.error(f"处理 pending_return 超时租赁 {rental.id} 失败: {e}", exc_info=True)

    if count > 0:
        db.commit()
        logger.info(f"pending_return 超时检查完成，自动完成 {count} 条")

    return count


def check_expired_rental_approvals(db: Session):
    """
    检查已批准但支付过期的租赁申请：
    status == 'approved' 且 payment_expires_at < now()
    标记为 expired，通知租客
    """
    now = get_utc_time()
    count = 0

    requests = (
        db.query(models.FleaMarketRentalRequest)
        .filter(
            models.FleaMarketRentalRequest.status == "approved",
            models.FleaMarketRentalRequest.payment_expires_at < now,
        )
        .limit(200)
        .all()
    )

    for req in requests:
        try:
            req.status = "expired"
            req.updated_at = now

            # 获取物品信息
            item = (
                db.query(models.FleaMarketItem)
                .filter(models.FleaMarketItem.id == req.item_id)
                .first()
            )
            item_title = item.title if item else f"物品#{req.item_id}"

            # 通知租客
            notification = models.Notification(
                user_id=req.renter_id,
                type="flea_market_rental_request_expired",
                title="租赁申请已过期",
                content=f"您对「{item_title}」的租赁申请已获批准，但支付已超时过期。如仍需租借，请重新申请。",
                related_id=str(req.id),
            )
            db.add(notification)
            db.flush()

            count += 1
        except Exception as e:
            logger.error(f"处理过期租赁申请 {req.id} 失败: {e}", exc_info=True)

    if count > 0:
        db.commit()
        logger.info(f"过期租赁申请检查完成，标记 {count} 条为 expired")

    return count

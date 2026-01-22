"""
定时任务
"""
import logging
from datetime import datetime, timedelta, timezone as tz
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app import models
from app.database import SessionLocal
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_expired_coupons(db: Session):
    """检查并更新过期优惠券"""
    try:
        now = get_utc_time()
        
        # 更新优惠券状态
        expired_coupons = db.query(models.Coupon).filter(
            and_(
                models.Coupon.valid_until < now,
                models.Coupon.status == "active"
            )
        ).all()
        
        for coupon in expired_coupons:
            coupon.status = "expired"
            logger.info(f"优惠券 {coupon.id} ({coupon.code}) 已过期")
        
        # 更新用户优惠券状态
        expired_user_coupons = db.query(models.UserCoupon).filter(
            and_(
                models.UserCoupon.status == "unused",
                models.UserCoupon.coupon_id.in_(
                    db.query(models.Coupon.id).filter(
                        models.Coupon.valid_until < now
                    )
                )
            )
        ).all()
        
        for user_coupon in expired_user_coupons:
            user_coupon.status = "expired"
            logger.info(f"用户优惠券 {user_coupon.id} 已过期")
        
        db.commit()
        
        logger.info(f"已处理 {len(expired_coupons)} 个过期优惠券和 {len(expired_user_coupons)} 个过期用户优惠券")
    except Exception as e:
        db.rollback()
        logger.error(f"检查过期优惠券失败: {e}", exc_info=True)
        raise


def check_expired_invitation_codes(db: Session):
    """检查并更新过期邀请码"""
    try:
        now = get_utc_time()
        
        expired_codes = db.query(models.InvitationCode).filter(
            and_(
                models.InvitationCode.valid_until < now,
                models.InvitationCode.is_active == True
            )
        ).all()
        
        for code in expired_codes:
            code.is_active = False
            logger.info(f"邀请码 {code.id} ({code.code}) 已过期")
        
        db.commit()
        
        logger.info(f"已处理 {len(expired_codes)} 个过期邀请码")
    except Exception as e:
        db.rollback()
        logger.error(f"检查过期邀请码失败: {e}", exc_info=True)
        raise


def check_expired_points(db: Session):
    """检查并处理过期积分（如果启用）"""
    try:
        from app.crud import get_system_setting
        
        expire_days_setting = get_system_setting(db, "points_expire_days")
        expire_days = int(expire_days_setting.setting_value) if expire_days_setting else 0
        
        if expire_days <= 0:
            return  # 永不过期，不处理
        
        # 查找过期的积分交易
        expire_date = get_utc_time() - timedelta(days=expire_days)
        
        expired_transactions = db.query(models.PointsTransaction).filter(
            and_(
                models.PointsTransaction.type == "earn",
                models.PointsTransaction.expires_at.isnot(None),
                models.PointsTransaction.expires_at < get_utc_time(),
                models.PointsTransaction.expired == False
            )
        ).all()
        
        for transaction in expired_transactions:
            # 扣除过期积分
            points_account = db.query(models.PointsAccount).filter(
                models.PointsAccount.user_id == transaction.user_id
            ).first()
            
            if points_account and points_account.balance >= transaction.amount:
                points_account.balance -= transaction.amount
                transaction.expired = True
                
                # 创建过期记录
                expire_transaction = models.PointsTransaction(
                    user_id=transaction.user_id,
                    type="expire",
                    amount=transaction.amount,
                    balance_after=points_account.balance,
                    source="points_expire",
                    description=f"积分过期（原始交易ID: {transaction.id}）",
                    batch_id=transaction.batch_id,
                    related_type="points_transaction",
                    related_id=transaction.id
                )
                db.add(expire_transaction)
                logger.info(f"用户 {transaction.user_id} 的 {transaction.amount} 积分已过期")
        
        db.commit()
        
        logger.info(f"已处理 {len(expired_transactions)} 个过期积分交易")
    except Exception as e:
        db.rollback()
        logger.error(f"检查过期积分失败: {e}", exc_info=True)
        raise


def auto_complete_expired_time_slot_tasks(db: Session):
    """
    自动完成已过期时间段的任务
    只处理达人类型的任务（expert_service_id 不为空）且有时间段的任务
    
    如果时间段已过期且任务状态为 in_progress、taken 或 pending_confirmation，则自动标记为 completed
    
    支持两种情况：
    1. 单个任务：通过 TaskTimeSlotRelation 直接关联时间段
    2. 多人任务：通过父活动（Activity）的 ActivityTimeSlotRelation 关联时间段
    """
    try:
        from sqlalchemy.orm import selectinload
        
        current_time = get_utc_time()
        completed_count = 0
        
        logger.info("开始检查已过期时间段的达人任务...")
        
        # 查询所有状态为 in_progress、taken 或 pending_confirmation 的达人类型任务（expert_service_id 不为空）
        # 加载时间段关联和父活动关联
        tasks_query = db.query(models.Task).filter(
            models.Task.status.in_(["in_progress", "taken", "pending_confirmation"]),
            models.Task.expert_service_id.isnot(None)  # 只处理达人类型的任务
        ).options(
            selectinload(models.Task.time_slot_relations).selectinload(models.TaskTimeSlotRelation.time_slot),
            selectinload(models.Task.parent_activity).selectinload(models.Activity.time_slot_relations).selectinload(models.ActivityTimeSlotRelation.time_slot)
        )
        
        tasks = tasks_query.all()
        logger.info(f"找到 {len(tasks)} 个状态为 in_progress、taken 或 pending_confirmation 的达人任务")
        
        for task in tasks:
            max_end_time = None
            
            # 优先检查：任务直接关联的时间段（TaskTimeSlotRelation）
            # TaskTimeSlotRelation 表中有冗余字段 slot_end_datetime，优先使用
            # 如果没有，则通过 time_slot_id 关联到 ServiceTimeSlot 表获取
            if task.time_slot_relations and len(task.time_slot_relations) > 0:
                for relation in task.time_slot_relations:
                    end_time = None
                    # 优先使用冗余字段
                    if relation.slot_end_datetime:
                        end_time = relation.slot_end_datetime
                    # 如果冗余字段为空，尝试从关联的 ServiceTimeSlot 获取
                    elif relation.time_slot_id and relation.time_slot:
                        end_time = relation.time_slot.slot_end_datetime
                    
                    if end_time:
                        if max_end_time is None or end_time > max_end_time:
                            max_end_time = end_time
            
            # 备用检查：只有在任务直接关联的时间段不存在时，才检查父活动关联的时间段
            # 这样可以确保优先使用任务自己的时间段，而不是父活动的时间段
            if max_end_time is None and task.parent_activity and task.parent_activity.time_slot_relations:
                for relation in task.parent_activity.time_slot_relations:
                    end_time = None
                    # 优先使用冗余字段
                    if relation.slot_end_datetime:
                        end_time = relation.slot_end_datetime
                    # 如果冗余字段为空，尝试从关联的 ServiceTimeSlot 获取
                    elif relation.time_slot_id and relation.time_slot:
                        end_time = relation.time_slot.slot_end_datetime
                    
                    if end_time:
                        if max_end_time is None or end_time > max_end_time:
                            max_end_time = end_time
            
            # 如果找到了时间段结束时间，且已过期，则自动完成
            # ⚠️ 安全修复：只有已支付的任务才能自动完成
            if max_end_time and max_end_time < current_time:
                # 检查支付状态
                if not task.is_paid:
                    logger.warning(
                        f"⚠️ 安全警告：达人任务 {task.id} 时间段已过期但未支付，跳过自动完成。"
                        f"expert_service_id={task.expert_service_id}, is_paid={task.is_paid}"
                    )
                    continue
                
                logger.info(
                    f"达人任务 {task.id} (expert_service_id: {task.expert_service_id}) "
                    f"的时间段已过期（结束时间: {max_end_time}），自动标记为已完成"
                )
                task.status = "completed"
                task.completed_at = current_time
                completed_count += 1
        
        if completed_count > 0:
            db.commit()
            logger.info(f"✅ 自动完成了 {completed_count} 个已过期时间段的达人任务")
        else:
            logger.info(f"✓ 检查完成，没有需要自动完成的达人任务（共检查了 {len(tasks)} 个任务）")
        
        return completed_count
        
    except Exception as e:
        logger.error(f"自动完成过期时间段任务失败: {e}", exc_info=True)
        db.rollback()
        return 0


def check_and_end_activities_sync(db: Session):
    """
    检查活动是否应该结束（最后一个时间段结束或达到截至日期），并自动结束活动（同步版本）
    在后台线程中调用，真正的异步逻辑仍然跑在主事件循环里
    使用 run_coroutine_threadsafe 将协程提交到主事件循环执行
    """
    import asyncio
    from concurrent.futures import TimeoutError as FutureTimeoutError
    from app.database import AsyncSessionLocal
    from app.task_expert_routes import check_and_end_activities
    from app.state import is_app_shutting_down, get_main_event_loop
    
    # 检查应用是否正在关停
    if is_app_shutting_down():
        logger.debug("应用正在关停，跳过活动结束检查")
        return 0
    
    # 获取主事件循环
    loop = get_main_event_loop()
    if loop is None or AsyncSessionLocal is None:
        logger.debug("异步环境未就绪，跳过活动结束检查")
        return 0
    
    async def run_check():
        """在主事件循环中执行的异步检查逻辑"""
        if is_app_shutting_down():
            return 0
        
        async with AsyncSessionLocal() as async_db:
            try:
                return await check_and_end_activities(async_db)
            except Exception as e:
                if is_app_shutting_down():
                    logger.debug("应用正在关停，跳过活动结束检查（run_check）")
                    return 0
                logger.error(f"活动结束检查失败: {e}", exc_info=True)
                return 0
    
    try:
        # 将协程提交到主事件循环执行
        future = asyncio.run_coroutine_threadsafe(run_check(), loop)
        # 适当设个超时，避免任务卡死
        return future.result(timeout=30)
    except FutureTimeoutError:
        logger.warning("活动结束检查超时（30秒）")
        return 0
    except RuntimeError as e:
        # 例如 loop 已关闭
        if is_app_shutting_down():
            logger.debug(f"事件循环已关闭，跳过活动结束检查: {e}")
            return 0
        logger.warning(f"事件循环错误: {e}")
        return 0
    except Exception as e:
        if is_app_shutting_down():
            logger.debug(f"应用关停过程中的活动检查异常: {e}")
            return 0
        logger.error(f"活动结束检查执行失败: {e}", exc_info=True)
        return 0


def process_expired_verifications(db: Session):
    """
    批量处理过期的认证（兜底任务）
    
    重要说明：此任务仅作为兜底和批量处理，不用于实现"立即释放"机制。
    真正的"立即释放"在 check_email_uniqueness 函数中实现，每次操作时实时检查过期。
    
    执行频率：每小时执行一次
    
    作用：
    - 批量处理可能遗漏的过期记录（兜底机制）
    - 批量更新过期记录的状态为 expired（用于统计和审计）
    - 清理历史数据
    
    幂等性保证：
    - 只处理状态为 'verified' 且已过期的记录
    - 如果因为宕机漏跑，下次执行时只会处理仍过期的记录
    - 已处理为 'expired' 状态的记录不会重复处理
    - 确保任务可以安全地重复执行
    
    注意：即使此任务不运行，过期邮箱也会在下次操作时被实时释放（通过 check_email_uniqueness）
    """
    try:
        now = get_utc_time()
        
        # 查询所有已过期但状态仍为verified的记录（幂等性：只处理verified状态）
        expired_verifications = db.query(models.StudentVerification).filter(
            models.StudentVerification.status == 'verified',
            models.StudentVerification.expires_at <= now
        ).all()
        
        for verification in expired_verifications:
            # 更新状态
            verification.status = 'expired'
            verification.updated_at = now
            
            # 清除用户的论坛可见板块缓存（认证状态变更）
            try:
                from app.forum_routes import invalidate_forum_visibility_cache
                invalidate_forum_visibility_cache(verification.user_id)
            except Exception as e:
                # 缓存失效失败不影响主流程
                logger.warning(f"清除用户 {verification.user_id} 的论坛可见板块缓存失败: {e}")
            
            # 记录历史
            history = models.VerificationHistory(
                verification_id=verification.id,
                user_id=verification.user_id,
                university_id=verification.university_id,
                email=verification.email,
                action='expired',
                previous_status='verified',
                new_status='expired'
            )
            db.add(history)
        
        db.commit()
        logger.info(f"处理了 {len(expired_verifications)} 个过期认证")
        
    except Exception as e:
        db.rollback()
        logger.error(f"处理过期认证失败: {e}", exc_info=True)
        raise


def send_expiry_reminders(db: Session, days_before: int):
    """
    发送过期提醒邮件
    
    Args:
        db: 数据库会话
        days_before: 过期前多少天发送提醒（30、7、1）
    """
    try:
        from datetime import timedelta
        from app.utils.time_utils import format_iso_utc
        from app.student_verification_utils import calculate_renewable_from, calculate_days_remaining
        from app.email_templates_student_verification import get_student_expiry_reminder_email
        from app.email_utils import send_email
        from app.config import Config
        
        now = get_utc_time()
        target_date = now + timedelta(days=days_before)
        
        # 查询即将在指定天数后过期的已验证认证
        # 使用日期范围查询（当天0点到23:59:59）
        start_of_day = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = target_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        expiring_verifications = db.query(models.StudentVerification).filter(
            models.StudentVerification.status == 'verified',
            models.StudentVerification.expires_at >= start_of_day,
            models.StudentVerification.expires_at <= end_of_day
        ).all()
        
        sent_count = 0
        failed_count = 0
        
        for verification in expiring_verifications:
            try:
                # 计算剩余天数和续期开始时间
                days_remaining = calculate_days_remaining(verification.expires_at, now)
                renewable_from = calculate_renewable_from(verification.expires_at)
                
                # 获取用户信息（用于语言偏好）
                user = db.query(models.User).filter(models.User.id == verification.user_id).first()
                language = 'zh' if user and user.language == 'zh' else 'en'
                
                # 生成续期URL
                renewal_url = f"{Config.FRONTEND_URL}/student-verification/renew" if Config.FRONTEND_URL else None
                
                # 生成邮件
                subject, body = get_student_expiry_reminder_email(
                    language=language,
                    days_remaining=days_remaining,
                    expires_at=format_iso_utc(verification.expires_at),
                    renewable_from=format_iso_utc(renewable_from),
                    renewal_url=renewal_url
                )
                
                # 发送邮件
                send_email(verification.email, subject, body)
                sent_count += 1
                logger.info(f"已发送过期提醒邮件给 {verification.email}（{days_remaining}天后过期）")
                
            except Exception as e:
                failed_count += 1
                logger.error(f"发送过期提醒邮件失败 {verification.email}: {e}", exc_info=True)
        
        logger.info(f"过期提醒邮件发送完成：成功 {sent_count}，失败 {failed_count}（{days_before}天前提醒）")
        
    except Exception as e:
        logger.error(f"发送过期提醒邮件失败: {e}", exc_info=True)
        raise


def send_expiry_notifications(db: Session):
    """
    发送过期通知邮件（过期当天）
    """
    try:
        from datetime import timedelta
        from app.utils.time_utils import format_iso_utc
        from app.email_templates_student_verification import get_student_expiry_notification_email
        from app.email_utils import send_email
        from app.config import Config
        
        now = get_utc_time()
        
        # 查询今天过期的已验证认证
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = now.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        expired_today = db.query(models.StudentVerification).filter(
            models.StudentVerification.status == 'verified',
            models.StudentVerification.expires_at >= start_of_day,
            models.StudentVerification.expires_at <= end_of_day
        ).all()
        
        sent_count = 0
        failed_count = 0
        
        for verification in expired_today:
            try:
                # 获取用户信息（用于语言偏好）
                user = db.query(models.User).filter(models.User.id == verification.user_id).first()
                language = 'zh' if user and user.language == 'zh' else 'en'
                
                # 生成续期URL
                renewal_url = f"{Config.FRONTEND_URL}/student-verification/renew" if Config.FRONTEND_URL else None
                
                # 生成邮件
                subject, body = get_student_expiry_notification_email(
                    language=language,
                    expires_at=format_iso_utc(verification.expires_at),
                    renewal_url=renewal_url
                )
                
                # 发送邮件
                send_email(verification.email, subject, body)
                sent_count += 1
                logger.info(f"已发送过期通知邮件给 {verification.email}")
                
            except Exception as e:
                failed_count += 1
                logger.error(f"发送过期通知邮件失败 {verification.email}: {e}", exc_info=True)
        
        logger.info(f"过期通知邮件发送完成：成功 {sent_count}，失败 {failed_count}")
        
    except Exception as e:
        logger.error(f"发送过期通知邮件失败: {e}", exc_info=True)
        raise


def check_expired_payment_tasks(db: Session):
    """检查并取消支付过期的任务"""
    try:
        current_time = get_utc_time()
        
        # 查询所有待支付且已过期的任务
        expired_tasks = db.query(models.Task).filter(
            and_(
                models.Task.status == "pending_payment",
                models.Task.is_paid == 0,
                models.Task.payment_expires_at.isnot(None),
                models.Task.payment_expires_at < current_time
            )
        ).all()
        
        cancelled_count = 0
        for task in expired_tasks:
            try:
                logger.info(f"任务 {task.id} 支付已过期（过期时间: {task.payment_expires_at}），自动取消")
                task.status = "cancelled"
                cancelled_count += 1
                
                # 如果是服务申请创建的任务，更新申请状态
                if task.expert_service_id:
                    from sqlalchemy import select
                    application = db.execute(
                        select(models.ServiceApplication).where(
                            models.ServiceApplication.task_id == task.id
                        )
                    ).scalar_one_or_none()
                    if application:
                        application.status = "cancelled"
                
                # 如果是活动申请创建的任务，更新参与者状态
                if task.is_multi_participant:
                    participants = db.query(models.TaskParticipant).filter(
                        models.TaskParticipant.task_id == task.id,
                        models.TaskParticipant.status.in_(["pending", "accepted", "in_progress"])
                    ).all()
                    for participant in participants:
                        participant.status = "cancelled"
                        participant.cancelled_at = current_time
                
                # ⚠️ 优化：如果是跳蚤市场购买，需要恢复商品状态为 active
                if task.task_type == "Second-hand & Rental":
                    flea_item = db.query(models.FleaMarketItem).filter(
                        models.FleaMarketItem.sold_task_id == task.id
                    ).first()
                    
                    if flea_item:
                        # 恢复商品状态为 active，清除任务关联
                        flea_item.status = "active"
                        flea_item.sold_task_id = None
                        logger.info(f"✅ 已恢复跳蚤市场商品 {flea_item.id} 状态为 active（支付过期）")
                        
                        # 清除商品缓存
                        try:
                            from app.flea_market_extensions import invalidate_item_cache
                            invalidate_item_cache(flea_item.id)
                        except Exception as e:
                            logger.warning(f"清除商品缓存失败: {e}")
                
                # 发送通知给任务发布者（需要支付的人）
                if task.poster_id:
                    try:
                        from app import crud
                        crud.create_notification(
                            db=db,
                            user_id=task.poster_id,
                            type="task_cancelled",
                            title="任务支付已过期",
                            content=f'您的任务"{task.title}"因支付超时已自动取消。请在24小时内完成支付以避免任务被取消。',
                            related_id=str(task.id),
                            auto_commit=False
                        )
                        
                        # 发送推送通知
                        try:
                            from app.push_notification_service import send_push_notification
                            send_push_notification(
                                db=db,
                                user_id=task.poster_id,
                                title="任务支付已过期",
                                body=f'您的任务"{task.title}"因支付超时已自动取消',
                                notification_type="task_cancelled",
                                data={"task_id": task.id, "reason": "payment_expired"}
                            )
                        except Exception as e:
                            logger.warning(f"发送支付过期取消推送通知失败（任务 {task.id}，用户 {task.poster_id}）: {e}")
                    except Exception as e:
                        logger.error(f"创建支付过期取消通知失败（任务 {task.id}，用户 {task.poster_id}）: {e}")
                
                # 如果任务有接受者，也通知接受者
                if task.taker_id and task.taker_id != task.poster_id:
                    try:
                        from app import crud
                        crud.create_notification(
                            db=db,
                            user_id=task.taker_id,
                            type="task_cancelled",
                            title="任务已取消",
                            content=f'您接受的任务"{task.title}"因支付超时已自动取消',
                            related_id=str(task.id),
                            auto_commit=False
                        )
                        
                        # 发送推送通知
                        try:
                            from app.push_notification_service import send_push_notification
                            send_push_notification(
                                db=db,
                                user_id=task.taker_id,
                                title="任务已取消",
                                body=f'您接受的任务"{task.title}"因支付超时已自动取消',
                                notification_type="task_cancelled",
                                data={"task_id": task.id, "reason": "payment_expired"}
                            )
                        except Exception as e:
                            logger.warning(f"发送支付过期取消推送通知失败（任务 {task.id}，用户 {task.taker_id}）: {e}")
                    except Exception as e:
                        logger.error(f"创建支付过期取消通知失败（任务 {task.id}，用户 {task.taker_id}）: {e}")
                
                # 记录任务历史
                try:
                    from app.crud import add_task_history
                    add_task_history(
                        db=db,
                        task_id=task.id,
                        user_id=task.poster_id or "system",
                        status="cancelled",
                        note="任务因支付超时自动取消",
                        auto_commit=False
                    )
                except Exception as e:
                    logger.warning(f"记录任务历史失败（任务 {task.id}）: {e}")
                
            except Exception as e:
                logger.error(f"处理支付过期任务 {task.id} 时出错: {e}", exc_info=True)
                # 继续处理其他任务，不中断整个流程
                continue
        
        if cancelled_count > 0:
            try:
                db.commit()
                logger.info(f"✅ 已取消 {cancelled_count} 个支付过期的任务，并发送了相关通知")
            except Exception as e:
                db.rollback()
                logger.error(f"提交支付过期任务取消失败: {e}", exc_info=True)
                return 0
        
        return cancelled_count
    except Exception as e:
        db.rollback()
        logger.error(f"检查支付过期任务失败: {e}", exc_info=True)
        return 0


def send_payment_reminders(db: Session, hours_before: int):
    """
    发送支付提醒通知
    
    Args:
        db: 数据库会话
        hours_before: 过期前多少小时发送提醒（12、6、1）
    """
    try:
        from app.task_notifications import send_payment_reminder_notification
        
        current_time = get_utc_time()
        reminder_time = current_time + timedelta(hours=hours_before)
        
        # 查询即将在指定小时后过期的待支付任务
        # 使用时间范围查询（±5分钟窗口，避免重复发送）
        start_time = reminder_time - timedelta(minutes=5)
        end_time = reminder_time + timedelta(minutes=5)
        
        tasks_to_remind = db.query(models.Task).filter(
            and_(
                models.Task.status == "pending_payment",
                models.Task.is_paid == 0,
                models.Task.payment_expires_at.isnot(None),
                models.Task.payment_expires_at >= start_time,
                models.Task.payment_expires_at <= end_time
            )
        ).all()
        
        sent_count = 0
        failed_count = 0
        skipped_count = 0
        
        for task in tasks_to_remind:
            try:
                # 检查是否已经发送过相同时间的提醒（避免重复发送）
                # 检查最近1小时内是否已有相同类型的提醒通知
                from datetime import timedelta
                recent_reminder = db.query(models.Notification).filter(
                    and_(
                        models.Notification.user_id == task.poster_id,
                        models.Notification.type == "payment_reminder",
                        models.Notification.related_id == str(task.id),
                        models.Notification.created_at >= current_time - timedelta(hours=1)
                    )
                ).first()
                
                if recent_reminder:
                    # 最近1小时内已发送过提醒，跳过（避免重复）
                    skipped_count += 1
                    logger.debug(f"跳过任务 {task.id} 的支付提醒（最近1小时内已发送过）")
                    continue
                
                # 发送通知给任务发布者（需要支付的人）
                if task.poster_id:
                    send_payment_reminder_notification(
                        db=db,
                        user_id=task.poster_id,
                        task_id=task.id,
                        task_title=task.title,
                        hours_remaining=hours_before,
                        expires_at=task.payment_expires_at
                    )
                    sent_count += 1
                    logger.info(f"已发送支付提醒通知给用户 {task.poster_id}（任务 {task.id}，{hours_before}小时后过期）")
                else:
                    logger.warning(f"任务 {task.id} 没有发布者ID，无法发送支付提醒")
            except Exception as e:
                failed_count += 1
                logger.error(f"发送支付提醒通知失败（任务 {task.id}）: {e}", exc_info=True)
        
        logger.info(f"支付提醒通知发送完成：成功 {sent_count}，失败 {failed_count}，跳过 {skipped_count}（{hours_before}小时前提醒）")
        
    except Exception as e:
        logger.error(f"发送支付提醒通知失败: {e}", exc_info=True)
        raise


def run_scheduled_tasks():
    """运行所有定时任务"""
    from app.state import is_app_shutting_down
    
    # 检查应用是否正在关停
    if is_app_shutting_down():
        logger.debug("应用正在关停，跳过定时任务执行")
        return
    
    db = SessionLocal()
    try:
        logger.info("开始执行定时任务...")
        
        # 再次检查关停状态（在执行任务前）
        if is_app_shutting_down():
            logger.debug("应用正在关停，跳过定时任务执行")
            return
        
        check_expired_coupons(db)
        check_expired_invitation_codes(db)
        check_expired_points(db)
        
        # 检查支付过期的任务
        try:
            cancelled_count = check_expired_payment_tasks(db)
            if cancelled_count > 0:
                logger.info(f"支付过期任务检查: 取消了 {cancelled_count} 个任务")
        except Exception as e:
            logger.error(f"支付过期任务检查失败: {e}", exc_info=True)
        
        # 发送支付提醒（12小时前、6小时前、1小时前）
        try:
            send_payment_reminders(db, hours_before=12)
            send_payment_reminders(db, hours_before=6)
            send_payment_reminders(db, hours_before=1)
        except Exception as e:
            logger.error(f"发送支付提醒失败: {e}", exc_info=True)
        
        # 处理过期认证（每小时执行一次，这里作为兜底）
        try:
            process_expired_verifications(db)
        except Exception as e:
            logger.error(f"处理过期认证失败: {e}", exc_info=True)
        
        # 检查并结束活动
        try:
            # 再次检查关停状态
            if is_app_shutting_down():
                logger.debug("应用正在关停，跳过活动结束检查")
            else:
                ended_count = check_and_end_activities_sync(db)
                if ended_count > 0:
                    logger.info(f"活动结束检查: 结束了 {ended_count} 个活动")
        except Exception as e:
            # 检查是否是关停相关的错误
            error_str = str(e)
            if is_app_shutting_down() and (
                "Event loop is closed" in error_str or 
                "loop is closed" in error_str or
                "attached to a different loop" in error_str
            ):
                logger.debug("应用正在关停，跳过活动结束检查错误")
            else:
                logger.error(f"活动结束检查执行失败: {e}", exc_info=True)
        
        # 客服系统定时任务（每5分钟执行一次）
        try:
            from app.customer_service_tasks import (
                process_customer_service_queue,
                auto_end_timeout_chats,
                send_timeout_warnings,
                cleanup_long_inactive_chats
            )
            # 处理客服排队
            queue_result = process_customer_service_queue(db)
            logger.info(f"客服排队处理: {queue_result}")
            
            # 自动结束超时对话
            timeout_result = auto_end_timeout_chats(db, timeout_minutes=2)
            logger.info(f"超时对话处理: {timeout_result}")
            
            # 发送超时预警
            warning_result = send_timeout_warnings(db, warning_minutes=1)
            logger.info(f"超时预警: {warning_result}")
            
            # 清理长期无活动对话（每天执行一次，在定时任务中每天第一次运行时执行）
            # 每天凌晨2点执行清理（简化：每小时检查一次，如果是2点则执行）
            current_hour = get_utc_time().hour
            if current_hour == 2:
                cleanup_result = cleanup_long_inactive_chats(db, inactive_days=30)
                logger.info(f"清理长期无活动对话: {cleanup_result}")
        except Exception as e:
            logger.error(f"客服系统定时任务执行失败: {e}", exc_info=True)
        
        logger.info("定时任务执行完成")
    except Exception as e:
        logger.error(f"定时任务执行失败: {e}", exc_info=True)
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    # 可以直接运行此脚本执行定时任务
    run_scheduled_tasks()


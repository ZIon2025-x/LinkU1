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


def check_expired_invitation_codes(db: Session):
    """检查并更新过期邀请码"""
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


def check_expired_points(db: Session):
    """检查并处理过期积分（如果启用）"""
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


def check_and_end_activities_sync(db: Session):
    """
    检查活动是否应该结束（最后一个时间段结束或达到截至日期），并自动结束活动（同步版本）
    使用新的 Activity 模型，调用异步函数 check_and_end_activities
    """
    import asyncio
    from app.database import AsyncSessionLocal
    from app.task_expert_routes import check_and_end_activities
    
    # 检查异步支持
    if AsyncSessionLocal is None:
        logger.warning("异步数据库不可用，跳过活动结束检查")
        return 0
    
    # 创建异步数据库会话并调用异步函数
    async def run_check():
        async with AsyncSessionLocal() as async_db:
            try:
                return await check_and_end_activities(async_db)
            except Exception as e:
                logger.error(f"活动结束检查失败: {e}", exc_info=True)
                return 0
    
    # 在同步函数中运行异步函数
    # 使用 asyncio.run() 创建新的事件循环，避免事件循环冲突
    try:
        # 检查是否已有运行中的事件循环
        try:
            loop = asyncio.get_running_loop()
            # 如果有运行中的循环，说明我们在异步上下文中
            # 这种情况下，我们不能使用 asyncio.run()，需要使用其他方法
            # 由于这是在后台线程中运行，应该不会有运行中的循环
            logger.warning("检测到运行中的事件循环，这不应该发生在后台线程中")
            return 0
        except RuntimeError:
            # 没有运行中的循环，使用 asyncio.run()
            # 设置超时，避免在应用关闭时卡住
            try:
                return asyncio.run(run_check())
            except RuntimeError as e:
                # 如果事件循环已关闭，这是正常的（应用正在关闭）
                if "Event loop is closed" in str(e) or "loop is closed" in str(e):
                    logger.debug("事件循环已关闭，跳过活动结束检查")
                    return 0
                raise
    except Exception as e:
        # 检查是否是事件循环关闭相关的错误
        if "Event loop is closed" in str(e) or "loop is closed" in str(e):
            logger.debug("事件循环已关闭，跳过活动结束检查")
            return 0
        logger.error(f"活动结束检查执行失败: {e}", exc_info=True)
        return 0
    
    # 过滤出只有时间段服务的活动（非时间段服务的活动在截止日期之前一直存在）
    tasks_with_time_slots = []
    non_time_slot_ended_count = 0
    for task in open_tasks:
        if task.expert_service_id:
            service = db.query(TaskExpertService).filter(
                TaskExpertService.id == task.expert_service_id
            ).first()
            if service and service.has_time_slots:
                tasks_with_time_slots.append(task)
            elif not service or not service.has_time_slots:
                # 非时间段服务：只检查截止日期
                if task.deadline:
                    current_time = dt_datetime.now(timezone.utc)
                    if current_time > task.deadline:
                        # 超过截止日期，结束活动
                        task.status = "completed"
                        from app.models import TaskAuditLog
                        audit_log = TaskAuditLog(
                            task_id=task.id,
                            action_type="task_auto_completed",
                            action_description=f"活动自动结束：已达到截止日期 {task.deadline}",
                            user_id=None,
                            new_status="completed",
                        )
                        db.add(audit_log)
                        non_time_slot_ended_count += 1
                        logger.info(f"非时间段服务活动 {task.id} 自动结束：已达到截止日期")
    
    # 提交非时间段服务的活动结束
    if non_time_slot_ended_count > 0:
        db.commit()
        logger.info(f"自动结束了 {non_time_slot_ended_count} 个非时间段服务活动")
    
    # 处理时间段服务的活动
    ended_count = 0
    current_time = dt_datetime.now(timezone.utc)
    
    for task in tasks_with_time_slots:
        should_end = False
        end_reason = ""
        
        # 查询活动的所有时间段关联
        from app.models import TaskTimeSlotRelation
        fixed_relations = db.query(TaskTimeSlotRelation).filter(
            TaskTimeSlotRelation.task_id == task.id,
            TaskTimeSlotRelation.relation_mode == "fixed"
        ).all()
        
        # 查询重复规则关联
        recurring_relation = db.query(TaskTimeSlotRelation).filter(
            TaskTimeSlotRelation.task_id == task.id,
            TaskTimeSlotRelation.relation_mode == "recurring"
        ).first()
        
        # 检查是否达到截至日期
        if recurring_relation and recurring_relation.activity_end_date:
            today = date.today()
            if today > recurring_relation.activity_end_date:
                should_end = True
                end_reason = f"已达到活动截至日期 {recurring_relation.activity_end_date}"
        
        # 检查最后一个时间段是否已结束
        if not should_end and fixed_relations:
            # 获取所有关联的时间段
            time_slot_ids = [r.time_slot_id for r in fixed_relations if r.time_slot_id]
            if time_slot_ids:
                from app.models import ServiceTimeSlot
                time_slots = db.query(ServiceTimeSlot).filter(
                    ServiceTimeSlot.id.in_(time_slot_ids)
                ).order_by(ServiceTimeSlot.slot_end_datetime.desc()).all()
                
                if time_slots:
                    # 获取最后一个时间段
                    last_slot = time_slots[0]
                    
                    # 检查最后一个时间段是否已结束
                    if last_slot.slot_end_datetime < current_time:
                        # 如果活动有重复规则且auto_add_new_slots为True，不结束活动
                        if recurring_relation and recurring_relation.auto_add_new_slots:
                            # 检查是否还有未到期的匹配时间段（未来30天内）
                            from app.utils.time_utils import parse_local_as_utc, LONDON
                            future_date = date.today() + timedelta(days=30)
                            future_utc = parse_local_as_utc(
                                dt_datetime.combine(future_date, dt_time(23, 59, 59)),
                                LONDON
                            )
                            
                            # 查询服务是否有未来的时间段
                            from app.models import TaskExpertService
                            service = db.query(TaskExpertService).filter(
                                TaskExpertService.id == task.expert_service_id
                            ).first()
                            
                            if service:
                                future_slots = db.query(ServiceTimeSlot).filter(
                                    ServiceTimeSlot.service_id == service.id,
                                    ServiceTimeSlot.slot_start_datetime > current_time,
                                    ServiceTimeSlot.slot_start_datetime <= future_utc,
                                    ServiceTimeSlot.is_manually_deleted == False
                                ).limit(1).first()
                                
                                if not future_slots:
                                    # 没有未来的时间段，结束活动
                                    should_end = True
                                    end_reason = "最后一个时间段已结束，且没有未来的匹配时间段"
                        else:
                            # 没有重复规则或auto_add_new_slots为False，最后一个时间段结束就结束活动
                            should_end = True
                            end_reason = f"最后一个时间段已结束（{last_slot.slot_end_datetime}）"
        
        if should_end:
            # 更新活动状态为已完成
            task.status = "completed"
            
            # 记录审计日志
            from app.models import TaskAuditLog
            audit_log = TaskAuditLog(
                task_id=task.id,
                action_type="task_auto_completed",
                action_description=f"活动自动结束：{end_reason}",
                user_id=None,  # 系统自动操作
                new_status="completed",
            )
            db.add(audit_log)
            
            ended_count += 1
            logger.info(f"活动 {task.id} 自动结束：{end_reason}")
    
    if ended_count > 0:
        db.commit()
        logger.info(f"自动结束了 {ended_count} 个活动")
    
    return ended_count


def run_scheduled_tasks():
    """运行所有定时任务"""
    db = SessionLocal()
    try:
        logger.info("开始执行定时任务...")
        
        check_expired_coupons(db)
        check_expired_invitation_codes(db)
        check_expired_points(db)
        
        # 检查并结束活动
        try:
            ended_count = check_and_end_activities_sync(db)
            if ended_count > 0:
                logger.info(f"活动结束检查: 结束了 {ended_count} 个活动")
        except Exception as e:
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


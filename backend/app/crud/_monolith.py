import datetime
import logging
from datetime import timezone
from typing import Optional
from dateutil.relativedelta import relativedelta

from sqlalchemy import and_, func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models, schemas
from app.crud.system import (
    get_system_setting,
    get_all_system_settings,
    create_system_setting,
    update_system_setting,
    upsert_system_setting,
    bulk_update_system_settings,
    get_system_settings_dict,
)
from app.crud.notification import (
    create_notification,
    get_user_notifications,
    get_unread_notifications,
    get_unread_notification_count,
    get_notifications_with_recent_read,
    mark_notification_read,
    mark_all_notifications_read,
)
from app.crud.user import (
    get_user_by_email,
    get_user_by_phone,
    get_user_by_id,
    get_all_users,
    update_user_statistics,
    create_user,
)
from app.crud.task import (
    add_task_history,
    get_user_tasks,
    create_task,
    list_all_tasks,
    get_task,
    accept_task,
    update_task_reward,
    cleanup_task_files,
    cancel_task,
    get_task_history,
    delete_task_safely,
)
from app.crud.review import (
    get_user_reviews,
    get_reviews_received_by_user,
    get_user_reviews_with_reviewer_info,
    calculate_user_avg_rating,
    create_review,
    get_task_reviews,
    get_user_received_reviews,
)
from app.crud.message import (
    send_message,
    get_chat_history,
    get_unread_messages,
    mark_message_read,
    get_admin_messages,
)
from app.crud.task_expert import (
    update_task_expert_bio,
    update_all_task_experts_bio,
    update_all_featured_task_experts_response_time,
)
from app.crud.task_listing import list_tasks, count_tasks
from app.crud.task_cancel_request import (
    delete_user_task,
    create_task_cancel_request,
    get_task_cancel_requests,
    get_task_cancel_request_by_id,
    update_task_cancel_request,
)
from app.crud.admin_ops import (
    get_users_for_admin,
    get_admin_users_for_admin,
    delete_admin_user_by_super_admin,
    update_user_by_admin,
)
from app.crud.task_translation import (
    get_task_translation,
    create_or_update_task_translation,
    cleanup_stale_task_translations,
    get_task_translations_batch,
)
from app.crud.device_token import (
    cleanup_duplicate_device_tokens,
    delete_old_inactive_device_tokens,
    cleanup_inactive_device_tokens,
)
from app.crud.vip import (
    check_and_upgrade_vip_to_super,
    get_vip_subscription_by_transaction_id,
    get_active_vip_subscription,
    get_vip_subscription_history,
    count_vip_subscriptions_by_user,
    get_all_vip_subscriptions,
    create_vip_subscription,
    update_vip_subscription_status,
    update_user_vip_status,
    check_and_update_expired_subscriptions,
)
from app.crud.customer_service import (
    update_customer_service_online_status,
    create_customer_service_by_admin,
    delete_customer_service_by_admin,
    get_customer_services_for_admin,
    get_customer_service_by_id,
    get_customer_service_by_email,
    authenticate_customer_service,
    create_customer_service_with_login,
    generate_customer_service_chat_id,
    create_customer_service_chat,
    get_customer_service_chat,
    get_user_customer_service_chats,
    get_service_customer_service_chats,
    cleanup_old_ended_chats,
    add_user_to_customer_service_queue,
    calculate_estimated_wait_time,
    get_user_queue_status,
    end_customer_service_chat,
    rate_customer_service_chat,
    mark_customer_service_message_delivered,
    mark_customer_service_message_read,
    save_customer_service_message,
    get_customer_service_messages,
    mark_customer_service_messages_read,
    get_unread_customer_service_messages_count,
)
from app.crud.admin_task_notify import (
    send_admin_notification,
    get_dashboard_stats,
    update_task_by_admin,
    delete_task_by_admin,
)
from app.crud.job_position import (
    create_job_position,
    get_job_position,
    get_job_positions,
    update_job_position,
    delete_job_position,
    toggle_job_position_status,
)
from app.crud.staff_notification import (
    create_staff_notification,
    get_staff_notifications,
    get_unread_staff_notifications,
    get_unread_staff_notification_count,
    mark_staff_notification_read,
    mark_all_staff_notifications_read,
)
from app.crud.admin_user import (
    get_admin_user_by_username,
    get_admin_user_by_id,
    get_admin_user_by_email,
    authenticate_admin_user,
    create_admin_user,
    update_admin_last_login,
)
from app.crud.audit import create_audit_log

logger = logging.getLogger(__name__)
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc
from app.flea_market_constants import AUTO_DELETE_DAYS
from app.push_notification_service import send_push_notification

# 密码加密上下文已移至 app.security 模块
# 请使用: from app.security import pwd_context


# ⚠️ 已删除：get_utc_time() 函数
# 请使用: from app.utils.time_utils import get_utc_time


# 密码哈希函数已移至 app.security 模块
# 请使用: from app.security import get_password_hash


# 密码验证函数已移至 app.security 模块
# 请使用: from app.security import verify_password


def cancel_expired_tasks(db: Session):
    """自动取消已过期的未接受任务 - 使用UTC时间进行比较，并同步更新参与者状态"""
    from datetime import datetime, timedelta, timezone
    import logging
    from sqlalchemy import text

    from app.models import Task, User

    logger = logging.getLogger(__name__)
    
    try:
        # 获取当前UTC时间
        now_utc = get_utc_time()

        # 使用数据库查询直接找到过期的任务，避免逐个检查
        # 处理两种情况：deadline有时区信息和没有时区信息
        from sqlalchemy import and_, or_
        
        expired_tasks = db.query(Task).filter(
            and_(
                Task.status == "open",
                or_(
                    # 情况1：deadline有时区信息，直接比较
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline <= now_utc
                    ),
                    # 情况2：deadline没有时区信息，假设是UTC时间
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline <= now_utc.replace(tzinfo=None)
                    )
                )
            )
        ).all()

        # 优化：只在发现过期任务时才记录日志，减少每分钟的日志噪音
        if not expired_tasks:
            logger.debug(f"没有过期任务需要处理")
            return 0
        
        logger.info(f"检查过期任务：找到 {len(expired_tasks)} 个过期任务")

        cancelled_count = 0
        for task in expired_tasks:
            try:
                logger.info(f"取消过期任务 {task.id}: {task.title}")
                
                # 将任务状态更新为已取消
                task.status = "cancelled"

                # 同步更新所有申请者的状态为 rejected（任务取消时，申请应该被拒绝）
                # 先查询需要更新的申请者（用于后续通知）
                applicant_user_ids = []
                try:
                    # 使用 savepoint 来隔离可能失败的操作
                    # 这样即使 task_applications 表查询失败，也不会影响主事务
                    savepoint = db.begin_nested()
                    try:
                        # 先查询需要更新的申请者（状态为 pending 或 approved 的申请）
                        query_applicants_sql = text("""
                            SELECT DISTINCT applicant_id 
                            FROM task_applications 
                            WHERE task_id = :task_id 
                              AND status NOT IN ('rejected')
                        """)
                        applicants_result = db.execute(query_applicants_sql, {"task_id": task.id})
                        applicant_user_ids = [row[0] for row in applicants_result.fetchall()]
                        
                        # 更新 task_applications 表中所有非 rejected 状态的申请
                        if applicant_user_ids:
                            update_applicants_sql = text("""
                                UPDATE task_applications 
                                SET status = 'rejected'
                                WHERE task_id = :task_id 
                                  AND status NOT IN ('rejected')
                            """)
                            result = db.execute(update_applicants_sql, {"task_id": task.id})
                            applicants_updated = result.rowcount
                            if applicants_updated > 0:
                                logger.info(f"任务 {task.id} 已同步更新 {applicants_updated} 个申请状态为 rejected")
                        
                        # 如果是多人任务，同步更新 task_participants 表中的参与者状态
                        if task.is_multi_participant:
                            # 先查询需要更新的参与者（用于后续通知）
                            query_participants_sql = text("""
                                SELECT DISTINCT user_id 
                                FROM task_participants 
                                WHERE task_id = :task_id 
                                  AND status NOT IN ('cancelled', 'exited', 'completed')
                            """)
                            participants_result = db.execute(query_participants_sql, {"task_id": task.id})
                            multi_participant_user_ids = [row[0] for row in participants_result.fetchall()]
                            
                            # 更新 task_participants 表中所有非终态的参与者状态为 cancelled
                            if multi_participant_user_ids:
                                update_participants_sql = text("""
                                    UPDATE task_participants 
                                    SET status = 'cancelled', 
                                        cancelled_at = :now_utc,
                                        updated_at = :now_utc
                                    WHERE task_id = :task_id 
                                      AND status NOT IN ('cancelled', 'exited', 'completed')
                                """)
                                result = db.execute(update_participants_sql, {"task_id": task.id, "now_utc": now_utc})
                                participants_updated = result.rowcount
                                if participants_updated > 0:
                                    logger.info(f"任务 {task.id} 已同步更新 {participants_updated} 个多人任务参与者状态为 cancelled")
                                
                                # 将多人任务参与者也加入通知列表
                                for uid in multi_participant_user_ids:
                                    if uid not in applicant_user_ids:
                                        applicant_user_ids.append(uid)
                        
                        # 提交 savepoint
                        savepoint.commit()
                    except Exception as e:
                        # 回滚 savepoint，不影响主事务
                        savepoint.rollback()
                        # 如果 task_applications 表查询失败，记录警告但继续处理
                        logger.warning(f"更新任务 {task.id} 的申请状态时出错（可能表不存在）: {e}")
                except Exception as e:
                    # 外层异常处理（savepoint 创建失败等）
                    logger.warning(f"更新任务 {task.id} 的申请状态时出错: {e}")
                
                # 使用申请者列表作为参与者列表（用于通知）
                participant_user_ids = applicant_user_ids

                # 记录任务历史
                add_task_history(
                    db,
                    task.id,
                    task.poster_id,
                    "cancelled",
                    "任务因超过截止日期自动取消",
                )

                # 创建通知给任务发布者（不自动提交）
                create_notification(
                    db,
                    task.poster_id,
                    "task_cancelled",
                    "任务自动取消",
                    f'您的任务"{task.title}"因超过截止日期已自动取消',
                    task.id,
                    title_en="Task Auto-Cancelled",
                    content_en=f'Your task"{task.title}"has been automatically cancelled due to exceeding the deadline',
                    auto_commit=False,
                )

                # 通知所有参与者
                for user_id in participant_user_ids:
                    if user_id != task.poster_id:  # 避免重复通知发布者
                        try:
                            create_notification(
                                db,
                                user_id,
                                "task_cancelled",
                                "任务自动取消",
                                f'您申请的任务"{task.title}"因超过截止日期已自动取消',
                                task.id,
                                title_en="Task Auto-Cancelled",
                                content_en=f'The task you applied for"{task.title}"has been automatically cancelled due to exceeding the deadline',
                                auto_commit=False,
                            )
                        except Exception as e:
                            logger.warning(f"通知参与者 {user_id} 任务 {task.id} 取消时出错: {e}")
                
                # 批量发送推送通知（优化：收集所有需要通知的用户，批量发送）
                users_to_notify = [task.poster_id] + [uid for uid in participant_user_ids if uid != task.poster_id]
                if users_to_notify:
                    try:
                        from app.push_notification_service import send_batch_push_notifications
                        success_count = send_batch_push_notifications(
                            db=db,
                            user_ids=users_to_notify,
                            title="任务自动取消",
                            body=f'任务"{task.title}"因超过截止日期已自动取消',
                            notification_type="task_cancelled",
                            data={"task_id": task.id}
                        )
                        if success_count < len(users_to_notify):
                            logger.warning(f"任务 {task.id} 批量推送通知部分失败: {success_count}/{len(users_to_notify)} 成功")
                    except Exception as e:
                        logger.warning(f"批量发送任务自动取消推送通知失败: {e}")
                        # 推送通知失败不影响主流程

                cancelled_count += 1
                logger.info(f"任务 {task.id} 已成功取消")

            except Exception as e:
                logger.error(f"处理任务 {task.id} 时出错: {e}")
                # 记录错误但继续处理其他任务
                continue

        # 提交所有更改
        db.commit()
        if cancelled_count > 0:
            logger.info(f"成功取消 {cancelled_count} 个过期任务")
        return cancelled_count
        
    except Exception as e:
        logger.error(f"取消过期任务时出错: {e}")
        db.rollback()
        return 0


def revert_unpaid_application_approvals(db: Session):
    """
    撤销超时未支付的申请批准
    如果任务在 pending_payment 状态超过24小时，自动撤销申请批准
    """
    from datetime import timedelta
    from sqlalchemy import select
    
    logger.info("开始检查超时未支付的申请批准")
    
    try:
        # 获取当前UTC时间
        now_utc = get_utc_time()
        # 24小时前的时间
        timeout_threshold = now_utc - timedelta(hours=24)
        
        # 查找所有 pending_payment 状态超过24小时的任务
        # 需要检查任务的更新时间或创建时间
        from app.models import Task, TaskApplication
        
        # 查找超时的 pending_payment 任务
        # 注意：这里使用 updated_at 字段，如果没有则使用 created_at
        timeout_tasks = db.query(Task).filter(
            and_(
                Task.status == "pending_payment",
                Task.taker_id.isnot(None),
                Task.is_paid == 0,
                # 如果 updated_at 存在且超过24小时，或者 created_at 超过24小时
                or_(
                    and_(
                        Task.updated_at.isnot(None),
                        Task.updated_at <= timeout_threshold
                    ),
                    and_(
                        Task.updated_at.is_(None),
                        Task.created_at <= timeout_threshold
                    )
                )
            )
        ).all()
        
        logger.info(f"找到 {len(timeout_tasks)} 个超时未支付的任务")
        
        reverted_count = 0
        for task in timeout_tasks:
            try:
                # 查找已批准的申请
                application = db.execute(
                    select(TaskApplication).where(
                        and_(
                            TaskApplication.task_id == task.id,
                            TaskApplication.applicant_id == task.taker_id,
                            TaskApplication.status == "approved"
                        )
                    )
                ).scalar_one_or_none()
                
                if application:
                    # 撤销申请批准：将申请状态改回 pending
                    application.status = "pending"
                    
                    # 回滚任务状态：清除接受者，状态改回 open
                    task.taker_id = None
                    task.status = "open"
                    task.is_paid = 0
                    task.payment_intent_id = None
                    
                    # 发送通知给申请者
                    try:
                        create_notification(
                            db,
                            application.applicant_id,
                            "application_payment_timeout",
                            "支付超时，申请已撤销",
                            f'任务 "{task.title}" 的支付超时（超过24小时），您的申请已撤销，可以重新申请。',
                            task.id,
                            auto_commit=False,
                        )
                    except Exception as e:
                        logger.warning(f"发送超时通知失败: {e}")
                    
                    # 发送通知给发布者
                    try:
                        create_notification(
                            db,
                            task.poster_id,
                            "application_payment_timeout",
                            "支付超时，申请已撤销",
                            f'任务 "{task.title}" 的支付超时（超过24小时），已接受的申请已撤销，任务已重新开放。',
                            task.id,
                            auto_commit=False,
                        )
                    except Exception as e:
                        logger.warning(f"发送超时通知给发布者失败: {e}")
                    
                    reverted_count += 1
                    logger.info(f"✅ 已撤销任务 {task.id} 的超时未支付申请批准，申请 {application.id} 状态已改回 pending")
                else:
                    # 如果没有找到申请（可能是跳蚤市场直接购买），直接回滚任务状态
                    # ⚠️ 注意：跳蚤市场直接购买没有申请记录，需要特殊处理
                    # ⚠️ 优化：如果是跳蚤市场购买，需要恢复商品状态为 active
                    if task.task_type == "Second-hand & Rental" and task.sold_task_id is None:
                        # 查找关联的跳蚤市场商品
                        from app.models import FleaMarketItem
                        flea_item = db.query(FleaMarketItem).filter(
                            FleaMarketItem.sold_task_id == task.id
                        ).first()
                        
                        if flea_item:
                            # 恢复商品状态为 active，清除任务关联
                            flea_item.status = "active"
                            flea_item.sold_task_id = None
                            logger.info(f"✅ 已恢复跳蚤市场商品 {flea_item.id} 状态为 active（支付超时）")
                            
                            # 清除商品缓存
                            try:
                                from app.flea_market_extensions import invalidate_item_cache
                                invalidate_item_cache(flea_item.id)
                            except Exception as e:
                                logger.warning(f"清除商品缓存失败: {e}")
                    task.taker_id = None
                    task.status = "open"
                    task.is_paid = 0
                    task.payment_intent_id = None
                    
                    # 检查是否是跳蚤市场任务（通过 task_type 判断）
                    is_flea_market_task = task.task_type == "Second-hand & Rental"
                    if is_flea_market_task:
                        # ⚠️ 安全修复：回滚跳蚤市场商品状态
                        # 查找关联的商品并回滚状态
                        from app.models import FleaMarketItem
                        flea_market_item = db.query(FleaMarketItem).filter(
                            FleaMarketItem.sold_task_id == task.id
                        ).first()
                        
                        if flea_market_item:
                            # 回滚商品状态：从 sold 改回 active
                            flea_market_item.status = "active"
                            flea_market_item.sold_task_id = None
                            logger.info(
                                f"✅ 跳蚤市场任务 {task.id} 超时未支付，已回滚任务状态和商品状态。"
                                f"商品 {flea_market_item.id} 状态已从 sold 改回 active"
                            )
                        else:
                            logger.warning(
                                f"⚠️ 跳蚤市场任务 {task.id} 超时未支付，但未找到关联的商品"
                            )
                    else:
                        logger.warning(
                            f"⚠️ 任务 {task.id} 处于 pending_payment 状态但未找到对应的已批准申请，已直接回滚任务状态"
                        )
                    reverted_count += 1
                    
            except Exception as e:
                logger.error(f"处理任务 {task.id} 时出错: {e}", exc_info=True)
                continue
        
        # 提交所有更改
        db.commit()
        logger.info(f"成功撤销 {reverted_count} 个超时未支付的申请批准")
        return reverted_count
        
    except Exception as e:
        logger.error(f"撤销超时未支付申请批准时出错: {e}", exc_info=True)
        db.rollback()
        return 0


def cleanup_cancelled_tasks(db: Session):
    """清理已取消的任务"""
    from app.models import Task

    # 查找所有状态为'cancelled'的任务
    cancelled_tasks = db.query(Task).filter(Task.status == "cancelled").all()

    deleted_count = 0
    for task in cancelled_tasks:
        try:
            # 记录任务历史
            add_task_history(
                db, task.id, task.poster_id, "deleted", "已取消任务被清理删除"
            )

            # 创建通知给任务发布者
            create_notification(
                db,
                task.poster_id,
                "task_deleted",
                "任务已删除",
                f'您的已取消任务"{task.title}"已被系统清理删除',
                task.id,
            )

            # 使用安全删除方法
            if delete_task_safely(db, task.id):
                deleted_count += 1

        except Exception as e:
            # 记录错误但继续处理其他任务
            continue

    return deleted_count


def cleanup_completed_tasks_files(db: Session):
    """清理已完成超过3天的任务的图片和文件（公开和私密）
    
    优化：只处理有图片的任务，清理后将images字段设为空，避免重复处理
    """
    import os
    from app.models import Task
    from datetime import timedelta
    from sqlalchemy import or_, and_
    import logging

    logger = logging.getLogger(__name__)
    days = int(os.getenv("CLEANUP_COMPLETED_TASK_DAYS", "3"))
    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=days)
    
    # 处理时区：将 three_days_ago 转换为 naive datetime（与数据库中的 completed_at 格式一致）
    three_days_ago_naive = three_days_ago.replace(tzinfo=None) if three_days_ago.tzinfo else three_days_ago
    
    # 查找已完成超过3天且有图片的任务（优化：跳过已清理过的任务）
    # images 字段不为空、不为 null、不为 "[]" 才需要处理
    completed_tasks = (
        db.query(Task)
        .filter(
            Task.status == "completed",
            Task.completed_at.isnot(None),
            Task.completed_at <= three_days_ago_naive,
            # 只处理有图片的任务
            Task.images.isnot(None),
            Task.images != "",
            Task.images != "[]",
            Task.images != "null"
        )
        .all()
    )
    
    if not completed_tasks:
        logger.debug("没有需要清理的已完成任务")
        return 0
    
    logger.info(f"找到 {len(completed_tasks)} 个已完成超过3天且有图片的任务，开始清理")
    
    cleaned_count = 0
    for task in completed_tasks:
        try:
            deleted_files = cleanup_task_files(db, task.id)
            # 同时清理关联的商品图片（如果是跳蚤市场任务）
            if task.task_type == "Second-hand & Rental":
                cleanup_flea_market_item_files_for_task(db, task.id)
            
            # 清理后将 images 字段设为空，避免下次重复处理
            task.images = "[]"
            db.commit()
            
            cleaned_count += 1
            if deleted_files > 0:
                logger.info(f"任务 {task.id} 清理了 {deleted_files} 个文件")
        except Exception as e:
            logger.error(f"清理任务 {task.id} 文件失败: {e}")
            db.rollback()
            continue
    
    if cleaned_count > 0:
        logger.info(f"完成清理，共处理 {cleaned_count} 个已完成任务")
    return cleaned_count


def cleanup_expired_tasks_files(db: Session):
    """清理过期任务（已取消或deadline已过超过3天）的图片和文件
    
    优化：只处理有图片的任务，清理后将images字段设为空，避免重复处理
    """
    import os
    from app.models import Task, TaskHistory
    from datetime import timedelta, datetime as dt, timezone
    from app.utils.time_utils import get_utc_time
    from sqlalchemy import or_, and_, func
    from sqlalchemy.orm import selectinload
    import logging

    logger = logging.getLogger(__name__)
    days = int(os.getenv("CLEANUP_EXPIRED_TASK_DAYS", "3"))
    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=days)
    
    # 优化：只查询有图片的已取消任务
    # 1. 先获取所有已取消且有图片的任务ID
    cancelled_task_ids = db.query(Task.id).filter(
        Task.status == "cancelled",
        Task.images.isnot(None),
        Task.images != "",
        Task.images != "[]",
        Task.images != "null"
    ).all()
    cancelled_task_ids = [tid[0] for tid in cancelled_task_ids]
    
    # 2. 批量查询这些任务的最新取消时间（一次性查询，避免 N+1）
    cancel_times_map = {}
    if cancelled_task_ids:
        # 使用窗口函数或子查询获取每个任务的最新取消时间
        from sqlalchemy import desc
        
        # 方法1：使用子查询获取每个任务的最新取消时间
        latest_cancels = (
            db.query(
                TaskHistory.task_id,
                func.max(TaskHistory.timestamp).label('cancel_time')
            )
            .filter(
                TaskHistory.task_id.in_(cancelled_task_ids),
                TaskHistory.action == "cancelled"
            )
            .group_by(TaskHistory.task_id)
            .all()
        )
        
        # 构建 task_id -> cancel_time 的映射
        for task_id, cancel_time in latest_cancels:
            cancel_times_map[task_id] = cancel_time
    
    # 3. 批量加载已取消的任务对象
    expired_tasks = []
    if cancelled_task_ids:
        cancelled_tasks = db.query(Task).filter(Task.id.in_(cancelled_task_ids)).all()
        
        for task in cancelled_tasks:
            # 从映射中获取取消时间，如果没有则使用 created_at
            cancel_time = cancel_times_map.get(task.id) or task.created_at
            if cancel_time:
                # 确保 cancel_time 是带时区的
                if cancel_time.tzinfo is None:
                    cancel_time = cancel_time.replace(tzinfo=timezone.utc)
                if cancel_time <= three_days_ago:
                    expired_tasks.append(task)
    
    # 2. 查找deadline已过超过3天且有图片的open任务
    deadline_expired_tasks = (
        db.query(Task)
        .filter(
            Task.status == "open",
            Task.deadline.isnot(None),
            Task.deadline <= three_days_ago,
            # 只处理有图片的任务
            Task.images.isnot(None),
            Task.images != "",
            Task.images != "[]",
            Task.images != "null"
        )
        .all()
    )
    
    # 合并结果（去重）
    task_ids = {task.id for task in expired_tasks}
    for task in deadline_expired_tasks:
        if task.id not in task_ids:
            expired_tasks.append(task)
    
    if not expired_tasks:
        logger.debug("没有需要清理的过期任务")
        return 0
    
    logger.info(f"找到 {len(expired_tasks)} 个过期超过3天且有图片的任务，开始清理")
    
    cleaned_count = 0
    total_files_deleted = 0
    for task in expired_tasks:
        try:
            deleted_files = cleanup_task_files(db, task.id)
            total_files_deleted += deleted_files
            
            # 清理后将 images 字段设为空，避免下次重复处理
            task.images = "[]"
            db.commit()
            
            cleaned_count += 1
            if deleted_files > 0:
                logger.info(f"过期任务 {task.id} 清理了 {deleted_files} 个文件")
        except Exception as e:
            logger.error(f"清理过期任务 {task.id} 文件失败: {e}")
            db.rollback()
            continue
    
    if cleaned_count > 0:
        logger.info(f"完成清理，共处理 {cleaned_count} 个过期任务，删除 {total_files_deleted} 个文件")
    return cleaned_count


def cleanup_all_old_tasks_files(db: Session):
    """清理所有已完成和过期任务的图片和文件（超过3天）"""
    import logging
    
    logger = logging.getLogger(__name__)
    
    logger.info("开始清理所有已完成和过期任务的文件...")
    
    # 清理已完成任务的文件
    completed_count = cleanup_completed_tasks_files(db)
    
    # 清理过期任务的文件
    expired_count = cleanup_expired_tasks_files(db)
    
    total_count = completed_count + expired_count
    
    logger.info(f"清理完成：已完成任务 {completed_count} 个，过期任务 {expired_count} 个，总计 {total_count} 个")
    
    return {
        "completed_count": completed_count,
        "expired_count": expired_count,
        "total_count": total_count
    }


def cleanup_expired_time_slots(db: Session) -> int:
    """
    清理过期的时间段（保留期限方案）
    每天执行一次，删除超过保留期限的过期时间段
    优化：只清理对应任务已完成/取消的时间段，或保留最近30天的时间段（用于历史记录）
    """
    from datetime import timedelta, datetime as dt_datetime, time as dt_time
    from app.utils.time_utils import get_utc_time, parse_local_as_utc, LONDON
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        current_utc = get_utc_time()
        # 保留最近30天的时间段（用于历史记录和审计）
        # 计算30天前的23:59:59（英国时间）转换为UTC
        thirty_days_ago = current_utc.date() - timedelta(days=30)
        cutoff_local = dt_datetime.combine(thirty_days_ago, dt_time(23, 59, 59))
        cutoff_time = parse_local_as_utc(cutoff_local, LONDON)
        
        # 查找超过保留期限的时间段
        # 优先清理：对应任务已完成/取消的时间段
        # 其次清理：没有关联任务的时间段
        expired_slots = db.query(models.ServiceTimeSlot).filter(
            models.ServiceTimeSlot.slot_start_datetime < cutoff_time,
            models.ServiceTimeSlot.is_manually_deleted == False,  # 不删除手动删除的（它们已经被标记为删除）
        ).all()
        
        # 检查时间段关联的任务状态
        from app.models import Task, TaskTimeSlotRelation
        slots_to_delete = []
        slots_with_active_tasks = 0
        
        for slot in expired_slots:
            # 检查是否有关联的任务
            task_relations = db.query(TaskTimeSlotRelation).filter(
                TaskTimeSlotRelation.time_slot_id == slot.id
            ).all()
            
            if task_relations:
                # 检查关联的任务状态
                task_ids = [rel.task_id for rel in task_relations]
                tasks = db.query(Task).filter(Task.id.in_(task_ids)).all()
                
                # 如果所有任务都是已完成或已取消状态，可以删除时间段
                all_finished = all(task.status in ['completed', 'cancelled'] for task in tasks)
                
                if all_finished:
                    slots_to_delete.append(slot)
                else:
                    slots_with_active_tasks += 1
                    logger.debug(f"时间段 {slot.id} 有未完成的任务，保留")
            else:
                # 没有关联任务的时间段，可以删除
                slots_to_delete.append(slot)
        
        # 删除符合条件的时间段
        
        deleted_count = 0
        slots_with_participants = 0
        for slot in slots_to_delete:
            try:
                # 记录有参与者的时间段数量（用于日志）
                if slot.current_participants > 0:
                    slots_with_participants += 1
                db.delete(slot)
                deleted_count += 1
            except Exception as e:
                logger.error(f"删除过期时间段失败 {slot.id}: {e}")
        
        if deleted_count > 0:
            db.commit()
            if slots_with_participants > 0:
                logger.info(f"清理了 {deleted_count} 个过期时间段（超过30天且任务已完成/取消），其中 {slots_with_participants} 个有参与者，保留了 {slots_with_active_tasks} 个有未完成任务的时间段")
            else:
                logger.info(f"清理了 {deleted_count} 个过期时间段（超过30天且任务已完成/取消），保留了 {slots_with_active_tasks} 个有未完成任务的时间段")
        elif slots_with_active_tasks > 0:
            logger.info(f"检查完成，保留了 {slots_with_active_tasks} 个有未完成任务的时间段（超过30天但任务未完成）")
        
        return deleted_count
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"清理过期时间段失败: {e}")
        db.rollback()
        return 0


def auto_generate_future_time_slots(db: Session) -> int:
    """
    自动为所有启用了时间段功能的服务生成下个月的今天的时间段
    每天执行一次，只生成新的一天，保持从今天到下个月的今天的时间段（一个月）
    """
    from datetime import date, timedelta, time as dt_time, datetime as dt_datetime
    from decimal import Decimal
    from app.utils.time_utils import parse_local_as_utc, LONDON
    
    try:
        # 获取所有启用了时间段功能且状态为active的服务
        services = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.has_time_slots == True,
            models.TaskExpertService.status == 'active',
        ).all()
        
        if not services:
            return 0
        
        total_created = 0
        today = date.today()
        # 只生成下个月的今天的时间段（保持一个月）
        target_date = today + relativedelta(months=1)
        
        for service in services:
            try:
                # 检查配置
                has_weekly_config = service.weekly_time_slot_config and isinstance(service.weekly_time_slot_config, dict)
                
                if not has_weekly_config:
                    # 使用旧的统一配置
                    if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
                        continue
                else:
                    # 使用新的按周几配置
                    if not service.time_slot_duration_minutes or not service.participants_per_slot:
                        continue
                
                # 使用服务的base_price作为默认价格
                price_per_participant = Decimal(str(service.base_price))
                
                # 周几名称映射
                weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                
                created_count = 0
                duration_minutes = service.time_slot_duration_minutes
                
                # 只处理目标日期（未来第30天）
                current_date = target_date
                
                # 获取当前日期是周几
                weekday = current_date.weekday()
                weekday_name = weekday_names[weekday]
                
                # 确定该日期的时间段配置
                if has_weekly_config:
                    day_config = service.weekly_time_slot_config.get(weekday_name, {})
                    if not day_config.get('enabled', False):
                        # 该周几未启用，跳过这个服务
                        continue
                    
                    slot_start_time_str = day_config.get('start_time', '09:00:00')
                    slot_end_time_str = day_config.get('end_time', '18:00:00')
                    
                    try:
                        slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                        slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                    except ValueError:
                        if len(slot_start_time_str) == 5:
                            slot_start_time_str += ':00'
                        if len(slot_end_time_str) == 5:
                            slot_end_time_str += ':00'
                        slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                        slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                else:
                    slot_start_time = service.time_slot_start_time
                    slot_end_time = service.time_slot_end_time
                
                # 检查该日期是否被手动删除
                from datetime import datetime as dt_datetime
                start_local = dt_datetime.combine(current_date, dt_time(0, 0, 0))
                end_local = dt_datetime.combine(current_date, dt_time(23, 59, 59))
                start_utc = parse_local_as_utc(start_local, LONDON)
                end_utc = parse_local_as_utc(end_local, LONDON)
                
                deleted_check = db.query(models.ServiceTimeSlot).filter(
                    models.ServiceTimeSlot.service_id == service.id,
                    models.ServiceTimeSlot.slot_start_datetime >= start_utc,
                    models.ServiceTimeSlot.slot_start_datetime <= end_utc,
                    models.ServiceTimeSlot.is_manually_deleted == True,
                ).first()
                
                if deleted_check:
                    # 该日期已被手动删除，跳过
                    continue
                
                # 计算该日期的时间段
                current_time = slot_start_time
                while current_time < slot_end_time:
                    # 计算结束时间
                    total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                    end_hour = total_minutes // 60
                    end_minute = total_minutes % 60
                    if end_hour >= 24:
                        break
                    
                    slot_end = dt_time(end_hour, end_minute)
                    if slot_end > slot_end_time:
                        break
                    
                    # 转换为UTC时间
                    slot_start_local = dt_datetime.combine(current_date, current_time)
                    slot_end_local = dt_datetime.combine(current_date, slot_end)
                    slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
                    slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
                    
                    # 检查是否已存在且未被手动删除
                    existing = db.query(models.ServiceTimeSlot).filter(
                        models.ServiceTimeSlot.service_id == service.id,
                        models.ServiceTimeSlot.slot_start_datetime == slot_start_utc,
                        models.ServiceTimeSlot.slot_end_datetime == slot_end_utc,
                        models.ServiceTimeSlot.is_manually_deleted == False,
                    ).first()
                    
                    if not existing:
                        # 创建新时间段
                        new_slot = models.ServiceTimeSlot(
                            service_id=service.id,
                            slot_start_datetime=slot_start_utc,
                            slot_end_datetime=slot_end_utc,
                            price_per_participant=price_per_participant,
                            max_participants=service.participants_per_slot,
                            current_participants=0,
                            is_available=True,
                            is_manually_deleted=False,
                        )
                        db.add(new_slot)
                        created_count += 1
                    
                    # 移动到下一个时间段
                    total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                    next_hour = total_minutes // 60
                    next_minute = total_minutes % 60
                    if next_hour >= 24:
                        break
                    current_time = dt_time(next_hour, next_minute)
                
                if created_count > 0:
                    db.commit()
                    total_created += created_count
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.info(f"为服务 {service.id} ({service.service_name}) 自动生成了 {created_count} 个时间段（{target_date}）")
                
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"为服务 {service.id} 自动生成时间段失败: {e}")
                db.rollback()
                continue
        
        if total_created > 0:
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"总共自动生成了 {total_created} 个时间段（下个月的今天）")
        
        return total_created
        
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"自动生成时间段失败: {e}", exc_info=True)
        db.rollback()
        return 0


def cleanup_expired_flea_market_items(db: Session):
    """清理超过 AUTO_DELETE_DAYS 天未刷新的跳蚤市场商品（自动删除，当前为10天）"""
    from app.models import FleaMarketItem
    from datetime import timedelta
    import logging
    import json
    import os
    import shutil
    from pathlib import Path
    from urllib.parse import urlparse
    
    logger = logging.getLogger(__name__)
    
    # 计算 AUTO_DELETE_DAYS 天前的时间（使用常量，当前为10天）
    now_utc = get_utc_time()
    ten_days_ago = now_utc - timedelta(days=AUTO_DELETE_DAYS)
    
    # 查找超过 AUTO_DELETE_DAYS 天未刷新且状态为active的商品
    expired_items = (
        db.query(FleaMarketItem)
        .filter(
            FleaMarketItem.status == "active",
            FleaMarketItem.refreshed_at <= ten_days_ago
        )
        .all()
    )
    
    if not expired_items:
        logger.debug(f"没有超过{AUTO_DELETE_DAYS}天未刷新的商品需要清理")
        return 0
    
    logger.info(f"找到 {len(expired_items)} 个超过{AUTO_DELETE_DAYS}天未刷新的商品，开始清理")
    
    # 检测部署环境
    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
    if RAILWAY_ENVIRONMENT:
        base_dir = Path("/data/uploads")
    else:
        base_dir = Path("uploads")
    
    deleted_count = 0
    for item in expired_items:
        try:
            # 删除商品图片文件
            if item.images:
                try:
                    images = json.loads(item.images) if isinstance(item.images, str) else item.images
                    
                    # 方法1：删除商品图片目录（标准路径）
                    flea_market_dir = base_dir / "flea_market" / str(item.id)
                    if flea_market_dir.exists():
                        shutil.rmtree(flea_market_dir)
                        logger.info(f"删除商品 {item.id} 的图片目录: {flea_market_dir}")
                    
                    # 方法2：从URL中提取路径并删除（兼容其他存储位置）
                    for image_url in images:
                        try:
                            # 解析URL，提取路径
                            parsed = urlparse(image_url)
                            path = parsed.path
                            
                            # 如果URL包含 /uploads/flea_market/，尝试删除对应文件
                            if "/uploads/flea_market/" in path:
                                # 提取相对路径
                                if path.startswith("/uploads/"):
                                    relative_path = path[len("/uploads/"):]
                                    file_path = base_dir / relative_path
                                    if file_path.exists():
                                        if file_path.is_file():
                                            file_path.unlink()
                                            logger.info(f"删除图片文件: {file_path}")
                                        elif file_path.is_dir():
                                            shutil.rmtree(file_path)
                                            logger.info(f"删除图片目录: {file_path}")
                        except Exception as e:
                            logger.warning(f"删除图片URL {image_url} 对应的文件失败: {e}")
                            
                except Exception as e:
                    logger.error(f"删除商品 {item.id} 图片文件失败: {e}")
            
            # 更新商品状态为deleted（软删除）
            item.status = "deleted"
            db.commit()
            
            deleted_count += 1
            logger.info(f"成功删除商品 {item.id}")
        except Exception as e:
            logger.error(f"删除商品 {item.id} 失败: {e}")
            db.rollback()
            continue
    
    logger.info(f"完成清理，共删除 {deleted_count} 个过期商品")
    return deleted_count


def cleanup_flea_market_item_files_for_task(db: Session, task_id: int):
    """清理任务关联的商品图片（任务完成后清理）"""
    from app.models import FleaMarketItem
    import json
    import os
    import shutil
    import logging
    from pathlib import Path
    from urllib.parse import urlparse
    
    logger = logging.getLogger(__name__)
    
    # 查找关联的商品
    item = db.query(FleaMarketItem).filter(
        FleaMarketItem.sold_task_id == task_id
    ).first()
    
    if not item:
        return
    
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads")
        else:
            base_dir = Path("uploads")
        
        # 删除商品图片文件
        if item.images:
            try:
                images = json.loads(item.images) if isinstance(item.images, str) else item.images
                
                # 方法1：删除商品图片目录（标准路径）
                flea_market_dir = base_dir / "flea_market" / str(item.id)
                if flea_market_dir.exists():
                    shutil.rmtree(flea_market_dir)
                    logger.info(f"删除任务 {task_id} 关联的商品 {item.id} 的图片目录: {flea_market_dir}")
                
                # 方法2：从URL中提取路径并删除（兼容其他存储位置）
                for image_url in images:
                    try:
                        parsed = urlparse(image_url)
                        path = parsed.path
                        if "/uploads/flea_market/" in path:
                            if path.startswith("/uploads/"):
                                relative_path = path[len("/uploads/"):]
                                file_path = base_dir / relative_path
                                if file_path.exists():
                                    if file_path.is_file():
                                        file_path.unlink()
                                    elif file_path.is_dir():
                                        shutil.rmtree(file_path)
                    except Exception as e:
                        logger.warning(f"删除图片URL {image_url} 对应的文件失败: {e}")
                        
            except Exception as e:
                logger.error(f"删除商品 {item.id} 图片文件失败: {e}")
    except Exception as e:
        logger.error(f"清理任务 {task_id} 关联的商品图片失败: {e}")


def cleanup_all_completed_and_cancelled_tasks_files(db: Session):
    """清理所有已完成或已取消的任务的图片和文件（不检查时间限制，管理员手动清理）"""
    from app.models import Task
    from sqlalchemy import or_
    import logging
    
    logger = logging.getLogger(__name__)
    
    logger.info("开始清理所有已完成或已取消任务的文件（不检查时间限制）...")
    
    # 查找所有已完成或已取消的任务
    tasks_to_clean = (
        db.query(Task)
        .filter(
            or_(
                Task.status == "completed",
                Task.status == "cancelled"
            )
        )
        .all()
    )
    
    logger.info(f"找到 {len(tasks_to_clean)} 个已完成或已取消的任务，开始清理文件（公开和私密）")
    
    completed_count = 0
    cancelled_count = 0
    
    for task in tasks_to_clean:
        try:
            cleanup_task_files(db, task.id)
            if task.status == "completed":
                completed_count += 1
            elif task.status == "cancelled":
                cancelled_count += 1
            logger.info(f"成功清理任务 {task.id} 的文件（状态：{task.status}）")
        except Exception as e:
            logger.error(f"清理任务 {task.id} 文件失败: {e}")
            continue
    
    total_count = completed_count + cancelled_count
    
    logger.info(f"清理完成：已完成任务 {completed_count} 个，已取消任务 {cancelled_count} 个，总计 {total_count} 个")
    
    return {
        "completed_count": completed_count,
        "cancelled_count": cancelled_count,
        "total_count": total_count
    }

def get_user_task_statistics(db: Session, user_id: str):
    """获取用户的任务统计信息"""
    from app.models import Task

    # 发布任务数量
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()

    # 接受任务数量
    accepted_tasks = db.query(Task).filter(Task.taker_id == user_id).count()

    # 完成任务数量
    completed_tasks = (
        db.query(Task)
        .filter(Task.taker_id == user_id, Task.status == "completed")
        .count()
    )

    # 计算完成率
    completion_rate = completed_tasks / accepted_tasks if accepted_tasks > 0 else 0

    return {
        "posted_tasks": posted_tasks,
        "accepted_tasks": accepted_tasks,
        "completed_tasks": completed_tasks,
        "total_tasks": posted_tasks + accepted_tasks,
        "completion_rate": round(completion_rate, 2),
    }



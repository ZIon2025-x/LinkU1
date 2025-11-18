"""
客服系统定时任务模块
⚠️ 重要：这些任务应通过Celery定时任务触发，不应暴露为HTTP端点
"""

import logging
from typing import Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func
from sqlalchemy.orm import with_for_update

from app.models import (
    CustomerServiceChat,
    CustomerServiceQueue,
    CustomerService,
    CustomerServiceMessage,
)
from app.utils.time_utils import get_utc_time
from app import crud

logger = logging.getLogger(__name__)


def process_customer_service_queue(db: Session) -> Dict[str, Any]:
    """
    处理客服队列 - 批量分配，带事务和锁保护
    防止并发分配导致"双分配"
    内部任务：通过Celery定时任务每30秒执行一次
    """
    BATCH_SIZE = 10
    
    # 开启事务
    try:
        # 1. 批量获取待分配记录（按queued_at升序，限制批量大小）
        waiting_queue = (
            db.query(CustomerServiceQueue)
            .filter(CustomerServiceQueue.status == "waiting")
            .order_by(CustomerServiceQueue.queued_at.asc())
            .with_for_update(skip_locked=True)  # 行级锁，跳过已锁定的行
            .limit(BATCH_SIZE)
            .all()
        )
        
        if not waiting_queue:
            return {"message": "No waiting users", "assigned_count": 0}
        
        assigned_count = 0
        
        for queue_entry in waiting_queue:
            # 2. 在事务内查找可用客服（带锁）
            available_services = (
                db.query(CustomerService)
                .filter(CustomerService.is_online == 1)
                .with_for_update()  # 锁定客服记录，防止并发修改
                .all()
            )
            
            if not available_services:
                # 没有可用客服，跳过
                continue
            
            # 3. 计算每个客服的当前负载
            service_loads = []
            for service in available_services:
                # 统计该客服当前进行中的对话数
                current_chats = (
                    db.query(func.count(CustomerServiceChat.id))
                    .filter(
                        CustomerServiceChat.service_id == service.id,
                        CustomerServiceChat.is_ended == 0
                    )
                    .scalar()
                )
                
                max_concurrent = getattr(service, 'max_concurrent_chats', 5) or 5
                remaining_capacity = max(0, max_concurrent - current_chats)
                
                service_loads.append({
                    "service": service,
                    "current_load": current_chats,
                    "remaining_capacity": remaining_capacity,
                    "avg_rating": getattr(service, 'avg_rating', 0) or 0
                })
            
            # 4. 选择负载最低且有余量的客服
            available_services_with_capacity = [
                sl for sl in service_loads 
                if sl["remaining_capacity"] > 0
            ]
            
            if not available_services_with_capacity:
                # 所有客服都满载，跳过
                continue
            
            # 按剩余容量和评分排序
            best_service = max(
                available_services_with_capacity,
                key=lambda x: (x["remaining_capacity"], x["avg_rating"])
            )["service"]
            
            # 5. 再次检查容量（双重检查，防止竞态）
            final_load_check = (
                db.query(func.count(CustomerServiceChat.id))
                .filter(
                    CustomerServiceChat.service_id == best_service.id,
                    CustomerServiceChat.is_ended == 0
                )
                .scalar()
            )
            
            max_concurrent = getattr(best_service, 'max_concurrent_chats', 5) or 5
            if final_load_check >= max_concurrent:
                # 容量已满，跳过
                continue
            
            # 6. 分配对话（在同一事务内）
            try:
                chat = crud.create_customer_service_chat(
                    db,
                    user_id=queue_entry.user_id,
                    service_id=best_service.id
                )
                
                # 7. 更新队列状态
                queue_entry.status = "assigned"
                queue_entry.assigned_service_id = best_service.id
                queue_entry.assigned_at = get_utc_time()
                
                assigned_count += 1
                logger.info(
                    f"Assigned user {queue_entry.user_id} to service {best_service.id}"
                )
            except Exception as e:
                logger.error(f"Failed to assign user {queue_entry.user_id}: {e}")
                continue
        
        # 8. 提交事务
        db.commit()
        
        return {
            "message": f"Assigned {assigned_count} users",
            "assigned_count": assigned_count
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error processing customer service queue: {e}", exc_info=True)
        return {"message": f"Error: {str(e)}", "assigned_count": 0}


def auto_end_timeout_chats(db: Session, timeout_minutes: int = 2) -> Dict[str, Any]:
    """
    自动结束超时对话
    内部任务：通过Celery定时任务每30秒执行一次
    """
    from datetime import timedelta
    
    try:
        # 计算超时时间点
        timeout_threshold = get_utc_time() - timedelta(minutes=timeout_minutes)
        
        # 查找超时的对话
        timeout_chats = (
            db.query(CustomerServiceChat)
            .filter(
                CustomerServiceChat.is_ended == 0,
                CustomerServiceChat.last_message_at < timeout_threshold
            )
            .all()
        )
        
        ended_count = 0
        
        for chat in timeout_chats:
            # 判断超时类型（用户不活跃还是客服不活跃）
            # 获取最后一条消息
            last_message = (
                db.query(CustomerServiceMessage)
                .filter(CustomerServiceMessage.chat_id == chat.chat_id)
                .order_by(CustomerServiceMessage.created_at.desc())
                .first()
            )
            
            if last_message and last_message.sender_type == "user":
                # 最后消息是用户发的，说明客服不活跃
                timeout_type = "service_inactive"
            else:
                # 最后消息是客服发的或没有消息，说明用户不活跃
                timeout_type = "user_inactive"
            
            # 结束对话，记录原因
            crud.end_customer_service_chat(
                db,
                chat.chat_id,
                reason="timeout",
                ended_by="system",
                ended_type=timeout_type
            )
            ended_count += 1
            logger.info(f"Auto-ended timeout chat {chat.chat_id}, type: {timeout_type}")
        
        db.commit()
        
        return {
            "message": f"Ended {ended_count} timeout chats",
            "ended_count": ended_count
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error auto-ending timeout chats: {e}", exc_info=True)
        return {"message": f"Error: {str(e)}", "ended_count": 0}


def send_timeout_warnings(db: Session, warning_minutes: int = 1) -> Dict[str, Any]:
    """
    发送超时预警
    内部任务：通过Celery定时任务每30秒执行一次
    """
    from datetime import timedelta
    
    try:
        # 计算预警时间点（距离超时还有warning_minutes分钟）
        timeout_minutes = 2  # 默认超时时间
        warning_threshold = get_utc_time() - timedelta(minutes=timeout_minutes - warning_minutes)
        
        # 查找即将超时的对话
        warning_chats = (
            db.query(CustomerServiceChat)
            .filter(
                CustomerServiceChat.is_ended == 0,
                CustomerServiceChat.last_message_at < warning_threshold,
                CustomerServiceChat.last_message_at > get_utc_time() - timedelta(minutes=timeout_minutes)
            )
            .all()
        )
        
        # TODO: 实现WebSocket通知或推送通知
        # 这里可以发送通知给用户或客服，提醒对话即将超时
        
        warning_count = len(warning_chats)
        logger.info(f"Sent {warning_count} timeout warnings")
        
        return {
            "message": f"Sent {warning_count} timeout warnings",
            "warning_count": warning_count
        }
    except Exception as e:
        logger.error(f"Error sending timeout warnings: {e}", exc_info=True)
        return {"message": f"Error: {str(e)}", "warning_count": 0}


def cleanup_long_inactive_chats(
    db: Session, 
    inactive_days: int = 30
) -> Dict[str, Any]:
    """
    清理长期无活动对话
    内部任务：通过Celery定时任务每天执行一次
    """
    from datetime import timedelta
    
    try:
        # 计算清理时间点
        cleanup_threshold = get_utc_time() - timedelta(days=inactive_days)
        
        # 查找长期无活动的已结束对话
        inactive_chats = (
            db.query(CustomerServiceChat)
            .filter(
                CustomerServiceChat.is_ended == 1,
                CustomerServiceChat.ended_at < cleanup_threshold
            )
            .all()
        )
        
        cleaned_count = 0
        
        for chat in inactive_chats:
            # 删除对话相关的消息
            db.query(CustomerServiceMessage).filter(
                CustomerServiceMessage.chat_id == chat.chat_id
            ).delete()
            
            # 删除对话记录
            db.delete(chat)
            cleaned_count += 1
        
        db.commit()
        
        logger.info(f"Cleaned up {cleaned_count} long inactive chats")
        
        return {
            "message": f"Cleaned up {cleaned_count} long inactive chats",
            "cleaned_count": cleaned_count
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error cleaning up long inactive chats: {e}", exc_info=True)
        return {"message": f"Error: {str(e)}", "cleaned_count": 0}


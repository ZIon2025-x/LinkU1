"""
推送通知服务
支持 iOS (APNs) 和 Android (FCM) 推送通知
"""
import os
import logging
import json
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# APNs 配置
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_BUNDLE_ID = os.getenv("APNS_BUNDLE_ID", "com.link2ur.app")
APNS_KEY_FILE = os.getenv("APNS_KEY_FILE")  # APNs 密钥文件路径
APNS_USE_SANDBOX = os.getenv("APNS_USE_SANDBOX", "false").lower() == "true"  # 是否使用沙盒环境


def send_push_notification(
    db: Session,
    user_id: str,
    title: str,
    body: str,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None,
    sound: str = "default"
) -> bool:
    """
    发送推送通知给指定用户的所有设备
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        title: 通知标题
        body: 通知内容
        notification_type: 通知类型（task_application, task_completed, forum_reply等）
        data: 额外的通知数据
        badge: 应用徽章数字
        sound: 通知声音
        
    Returns:
        bool: 是否成功发送
    """
    try:
        from app import models
        
        # 获取用户的所有激活的设备令牌
        device_tokens = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id == user_id,
            models.DeviceToken.is_active == True
        ).all()
        
        if not device_tokens:
            logger.debug(f"用户 {user_id} 没有注册的设备令牌")
            return False
        
        success_count = 0
        failed_tokens = []
        from app.utils.time_utils import get_utc_time
        
        for device_token in device_tokens:
            try:
                if device_token.platform == "ios":
                    result = send_apns_notification(
                        device_token.device_token,
                        title=title,
                        body=body,
                        notification_type=notification_type,
                        data=data,
                        badge=badge,
                        sound=sound
                    )
                elif device_token.platform == "android":
                    # TODO: 实现 FCM 推送
                    logger.warning("Android FCM 推送尚未实现")
                    result = False
                else:
                    logger.warning(f"未知平台: {device_token.platform}")
                    result = False
                
                if result:
                    success_count += 1
                    # 更新最后使用时间
                    device_token.last_used_at = get_utc_time()
                else:
                    # 如果推送失败，可能是 token 失效，标记为不活跃
                    logger.warning(f"推送失败，标记设备令牌为不活跃: {device_token.id}")
                    failed_tokens.append(device_token)
                    
            except Exception as e:
                logger.warning(f"发送推送通知到设备 {device_token.device_token[:20]}... 失败: {e}")
                failed_tokens.append(device_token)
                continue
        
        # 批量更新失败令牌和提交（性能优化：只提交一次）
        if failed_tokens:
            for token in failed_tokens:
                token.is_active = False
        if success_count > 0 or failed_tokens:
            db.commit()
        
        logger.info(f"向用户 {user_id} 发送推送通知: {success_count}/{len(device_tokens)} 成功")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"发送推送通知失败: {e}")
        return False


def send_apns_notification(
    device_token: str,
    title: str,
    body: str,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None,
    sound: str = "default"
) -> bool:
    """
    发送 APNs 推送通知
    
    Args:
        device_token: iOS 设备令牌
        title: 通知标题
        body: 通知内容
        notification_type: 通知类型
        data: 额外的通知数据
        badge: 应用徽章数字
        sound: 通知声音
        
    Returns:
        bool: 是否成功发送
    """
    try:
        # 检查 APNs 配置
        if not APNS_KEY_ID or not APNS_TEAM_ID or not APNS_KEY_FILE:
            logger.warning("APNs 配置不完整，跳过推送通知")
            return False
        
        # 尝试导入 PyAPNs2
        try:
            from apns2 import APNsClient, NotificationRequest, PushType
            from apns2.payload import Payload
        except ImportError:
            logger.error("PyAPNs2 未安装，无法发送推送通知。请运行: pip install apns2")
            return False
        
        # 构建通知负载
        payload_data = {
            "type": notification_type
        }
        if data:
            payload_data.update(data)
        
        payload = Payload(
            alert={"title": title, "body": body},
            badge=badge,
            sound=sound,
            custom=payload_data
        )
        
        # 创建 APNs 客户端
        apns_client = APNsClient(
            credentials=APNS_KEY_FILE,
            use_sandbox=APNS_USE_SANDBOX,
            use_alternative_port=False
        )
        
        # 发送通知
        topic = APNS_BUNDLE_ID
        request = NotificationRequest(
            device_token=device_token,
            message=payload,
            push_type=PushType.ALERT
        )
        
        apns_client.send_notification(request, topic=topic)
        logger.info(f"APNs 推送通知已发送: {device_token[:20]}...")
        return True
        
    except Exception as e:
        logger.error(f"发送 APNs 推送通知失败: {e}")
        return False


def send_push_notification_async_safe(
    async_db,
    user_id: str,
    title: str,
    body: str,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    在异步环境中安全地发送推送通知
    自动处理同步/异步数据库会话转换
    
    Args:
        async_db: 异步数据库会话（AsyncSession，实际不使用，仅为类型提示）
        user_id: 用户ID
        title: 通知标题
        body: 通知内容
        notification_type: 通知类型
        data: 额外的通知数据
        
    Returns:
        bool: 是否成功发送
    """
    try:
        from app.database import SessionLocal
        sync_db = SessionLocal()
        try:
            return send_push_notification(
                db=sync_db,
                user_id=user_id,
                title=title,
                body=body,
                notification_type=notification_type,
                data=data
            )
        finally:
            sync_db.close()
    except Exception as e:
        logger.error(f"发送推送通知失败（异步环境）: {e}")
        return False


def send_batch_push_notifications(
    db: Session,
    user_ids: List[str],
    title: str,
    body: str,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None
) -> int:
    """
    批量发送推送通知给多个用户
    
    Args:
        db: 数据库会话
        user_ids: 用户ID列表
        title: 通知标题
        body: 通知内容
        notification_type: 通知类型
        data: 额外的通知数据
        
    Returns:
        int: 成功发送的数量
    """
    if not user_ids:
        return 0
    
    success_count = 0
    failed_count = 0
    
    for user_id in user_ids:
        try:
            if send_push_notification(db, user_id, title, body, notification_type, data):
                success_count += 1
            else:
                failed_count += 1
        except Exception as e:
            logger.warning(f"批量推送通知失败（用户 {user_id}）: {e}")
            failed_count += 1
    
    if failed_count > 0:
        logger.warning(f"批量推送通知部分失败: {success_count}/{len(user_ids)} 成功")
    
    return success_count


# 从 time_utils 导入 get_utc_time
from app.utils.time_utils import get_utc_time

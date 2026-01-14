"""
推送通知服务
支持 iOS (APNs) 和 Android (FCM) 推送通知
"""
import os
import logging
import json
import base64
import tempfile
from pathlib import Path
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# APNs 配置
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_BUNDLE_ID = os.getenv("APNS_BUNDLE_ID", "com.link2ur.app")
APNS_KEY_FILE = os.getenv("APNS_KEY_FILE")  # APNs 密钥文件路径（本地开发使用）
APNS_KEY_CONTENT = os.getenv("APNS_KEY_CONTENT")  # APNs 密钥内容（Base64编码，Railway等云平台使用）
APNS_USE_SANDBOX = os.getenv("APNS_USE_SANDBOX", "false").lower() == "true"  # 是否使用沙盒环境

# 临时文件路径（用于存储从环境变量读取的密钥）
_temp_key_file: Optional[str] = None


def get_apns_key_file() -> Optional[str]:
    """
    获取 APNs 密钥文件路径
    优先使用环境变量中的密钥内容（Base64编码），如果不存在则使用文件路径
    
    Returns:
        str: 密钥文件路径，如果配置不完整则返回 None
    """
    global _temp_key_file
    
    # 优先使用环境变量中的密钥内容（适合 Railway 等云平台）
    if APNS_KEY_CONTENT:
        try:
            # 解码 Base64 密钥内容
            key_content = base64.b64decode(APNS_KEY_CONTENT).decode('utf-8')
            
            # 如果临时文件已存在，直接返回
            if _temp_key_file and Path(_temp_key_file).exists():
                return _temp_key_file
            
            # 创建临时文件存储密钥
            temp_dir = Path(tempfile.gettempdir())
            temp_key_file = temp_dir / "apns_key.p8"
            
            # 写入密钥内容
            with open(temp_key_file, 'w') as f:
                f.write(key_content)
            
            # 设置文件权限（仅所有者可读）
            os.chmod(temp_key_file, 0o600)
            
            _temp_key_file = str(temp_key_file)
            logger.info("已从环境变量加载 APNs 密钥")
            return _temp_key_file
            
        except Exception as e:
            logger.error(f"从环境变量加载 APNs 密钥失败: {e}")
            return None
    
    # 如果没有环境变量密钥，使用文件路径（本地开发）
    if APNS_KEY_FILE and Path(APNS_KEY_FILE).exists():
        return APNS_KEY_FILE
    
    return None


def send_push_notification(
    db: Session,
    user_id: str,
    title: Optional[str] = None,
    body: Optional[str] = None,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None,
    sound: str = "default",
    template_vars: Optional[Dict[str, Any]] = None
) -> bool:
    """
    发送推送通知给指定用户的所有设备
    推送通知会在 payload 中包含多语言内容，iOS 端通过 Notification Service Extension 根据设备系统语言选择显示
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        title: 通知标题（如果为 None，将从模板生成所有语言）
        body: 通知内容（如果为 None，将从模板生成所有语言）
        notification_type: 通知类型（task_application, task_completed, forum_reply等）
        data: 额外的通知数据
        badge: 应用徽章数字
        sound: 通知声音
        template_vars: 模板变量字典（用于国际化模板，如 applicant_name, task_title 等）
        
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
        
        # 准备模板变量
        template_vars = template_vars or {}
        if data:
            template_vars.update(data)
        
        # 如果 title 或 body 为 None，生成所有语言的本地化内容
        localized_content = None
        if title is None or body is None:
            from app.push_notification_templates import get_push_notification_text
            
            # 生成英文和中文的本地化内容
            localized_content = {}
            for lang in ["en", "zh"]:
                template_title, template_body = get_push_notification_text(
                    notification_type=notification_type,
                    language=lang,
                    **template_vars
                )
                localized_content[lang] = {
                    "title": template_title,
                    "body": template_body
                }
        
        for device_token in device_tokens:
            try:
                # 如果提供了本地化内容，直接使用；否则使用传入的 title 和 body
                if device_token.platform == "ios":
                    result = send_apns_notification(
                        device_token.device_token,
                        title=title,
                        body=body,
                        notification_type=notification_type,
                        data=data,
                        badge=badge,
                        sound=sound,
                        localized_content=localized_content
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
    title: Optional[str] = None,
    body: Optional[str] = None,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None,
    sound: str = "default",
    localized_content: Optional[Dict[str, Dict[str, str]]] = None
) -> bool:
    """
    发送 APNs 推送通知
    
    Args:
        device_token: iOS 设备令牌
        title: 通知标题（如果提供了 localized_content，此参数将被忽略）
        body: 通知内容（如果提供了 localized_content，此参数将被忽略）
        notification_type: 通知类型
        data: 额外的通知数据
        badge: 应用徽章数字
        sound: 通知声音
        localized_content: 本地化内容字典，格式为 {"en": {"title": "...", "body": "..."}, "zh": {...}}
                          如果提供，iOS端会根据系统语言选择显示
        
    Returns:
        bool: 是否成功发送
    """
    try:
        # 检查 APNs 配置
        if not APNS_KEY_ID or not APNS_TEAM_ID:
            logger.warning("APNs 配置不完整（缺少 KEY_ID 或 TEAM_ID），跳过推送通知")
            return False
        
        # 获取密钥文件路径
        key_file = get_apns_key_file()
        if not key_file:
            logger.warning("APNs 密钥文件不存在或无法加载，跳过推送通知")
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
        
        # 如果提供了本地化内容，将其添加到 payload_data 中
        if localized_content:
            payload_data["localized"] = localized_content
            # 使用默认语言（英文）作为 alert 的 fallback
            default_content = localized_content.get("en", {})
            alert_title = default_content.get("title", title or "Notification")
            alert_body = default_content.get("body", body or "")
        else:
            # 如果没有本地化内容，使用传入的 title 和 body
            alert_title = title or "Notification"
            alert_body = body or ""
        
        payload = Payload(
            alert={"title": alert_title, "body": alert_body},
            badge=badge,
            sound=sound,
            custom=payload_data
        )
        
        # 创建 APNs 客户端
        apns_client = APNsClient(
            credentials=key_file,
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
    title: Optional[str] = None,
    body: Optional[str] = None,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    template_vars: Optional[Dict[str, Any]] = None
) -> bool:
    """
    在异步环境中安全地发送推送通知
    自动处理同步/异步数据库会话转换
    
    Args:
        async_db: 异步数据库会话（AsyncSession，实际不使用，仅为类型提示）
        user_id: 用户ID
        title: 通知标题（如果为 None，将从模板生成所有语言）
        body: 通知内容（如果为 None，将从模板生成所有语言）
        notification_type: 通知类型
        data: 额外的通知数据
        template_vars: 模板变量字典（用于国际化模板，如 applicant_name, task_title 等）
        
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
                data=data,
                template_vars=template_vars
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

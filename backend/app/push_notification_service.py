"""
推送通知服务
支持 iOS (APNs) 和 Android (FCM) 推送通知
"""
import os
import sys
import logging
import json
import base64
import tempfile
from pathlib import Path
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

# Python 3.10+ 兼容性补丁：修复 apns2 的 collections.Iterable 导入问题
# 在 Python 3.10+ 中，collections.Iterable 已移至 collections.abc.Iterable
if sys.version_info >= (3, 10):
    import collections
    import collections.abc
    # 重新添加已移除的别名，以兼容旧版本的 apns2
    if not hasattr(collections, 'Iterable'):
        collections.Iterable = collections.abc.Iterable
    if not hasattr(collections, 'Mapping'):
        collections.Mapping = collections.abc.Mapping
    if not hasattr(collections, 'MutableMapping'):
        collections.MutableMapping = collections.abc.MutableMapping
    if not hasattr(collections, 'MutableSet'):
        collections.MutableSet = collections.abc.MutableSet

logger = logging.getLogger(__name__)

# 尝试导入 apns2（优先使用 compat-fork-apns2，它支持 Python 3.11 和 PyJWT 2.x）
APNS2_ERRORS = None
try:
    # 优先尝试导入 compat-fork-apns2（兼容 Python 3.11 和 PyJWT 2.x）
    try:
        from compat_fork_apns2.client import APNsClient
        from compat_fork_apns2.payload import Payload
        from compat_fork_apns2.credentials import TokenCredentials
        from compat_fork_apns2 import errors as apns2_errors
        APNS2_AVAILABLE = True
        APNS2_IMPORT_ERROR = None
        APNS2_LIBRARY = "compat-fork-apns2"
        APNS2_ERRORS = apns2_errors
    except ImportError:
        # 回退到原始的 apns2（可能不兼容 Python 3.11 + PyJWT 2.x）
        from apns2.client import APNsClient
        from apns2.payload import Payload
        from apns2.credentials import TokenCredentials
        from apns2 import errors as apns2_errors
        APNS2_AVAILABLE = True
        APNS2_IMPORT_ERROR = None
        APNS2_LIBRARY = "apns2"
        APNS2_ERRORS = apns2_errors
except ImportError as e:
    APNS2_AVAILABLE = False
    APNS2_IMPORT_ERROR = str(e)
    APNS2_LIBRARY = None
    logger.warning(f"apns2 未安装，推送通知功能将不可用。错误: {e}")
    logger.warning("请确保已安装 apns2 或 compat-fork-apns2: pip install compat-fork-apns2")

# APNs 配置
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_BUNDLE_ID = os.getenv("APNS_BUNDLE_ID", "com.link2ur")
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
    根据用户的 language_preference 生成对应语言的推送内容
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        title: 通知标题（如果为 None，将从模板生成）
        body: 通知内容（如果为 None，将从模板生成）
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
        
        # 获取用户信息（用于验证用户存在）
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            logger.warning(f"用户 {user_id} 不存在，无法发送推送通知")
            return False
        
        # 获取用户的所有激活的设备令牌
        device_tokens = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id == user_id,
            models.DeviceToken.is_active == True
        ).all()
        
        if not device_tokens:
            logger.warning(f"用户 {user_id} 没有注册的设备令牌，无法发送推送通知")
            return False
        
        logger.info(f"找到 {len(device_tokens)} 个设备令牌，准备发送推送通知给用户 {user_id}")
        
        success_count = 0
        failed_tokens = []
        from app.utils.time_utils import get_utc_time
        
        # 准备模板变量（所有设备共享）
        template_vars = template_vars or {}
        if data:
            template_vars.update(data)
        
        # 为每个设备生成对应语言的推送内容
        for device_token in device_tokens:
            try:
                # 获取设备语言（默认为英文）
                # 只有中文使用中文推送，其他所有语言都使用英文推送
                device_language = getattr(device_token, 'device_language', 'en') or 'en'
                device_language = device_language.strip().lower()
                if device_language.startswith('zh'):
                    device_language = 'zh'  # 中文
                else:
                    device_language = 'en'  # 其他所有语言都使用英文
                
                logger.debug(f"[推送通知] 设备 {device_token.id} 的语言: {device_language}")
                
                # 准备该设备的模板变量（可能需要翻译任务标题）
                device_template_vars = template_vars.copy()
                
                # 处理任务标题翻译（如果 template_vars 中包含 task_title 和 task_id）
                if 'task_title' in device_template_vars and 'task_id' in device_template_vars:
                    task_id = device_template_vars.get('task_id')
                    original_task_title = device_template_vars.get('task_title')
                    
                    # 尝试从翻译表获取任务标题的翻译
                    if task_id and original_task_title:
                        try:
                            from app.crud import get_task_translation
                            # 确保 task_id 是整数类型
                            task_id_int = int(task_id) if isinstance(task_id, str) else task_id
                            
                            translation = get_task_translation(
                                db=db,
                                task_id=task_id_int,
                                field_type='title',
                                target_language=device_language
                            )
                            if translation and translation.translated_text:
                                # 使用翻译后的标题
                                device_template_vars['task_title'] = translation.translated_text
                                logger.debug(f"设备 {device_token.id} 使用翻译后的任务标题（{device_language}）: {translation.translated_text[:50]}...")
                            else:
                                logger.debug(f"任务 {task_id_int} 没有 {device_language} 语言的翻译，使用原始标题")
                        except (ValueError, TypeError) as e:
                            logger.warning(f"task_id 类型错误: {e}，使用原始标题")
                        except Exception as e:
                            logger.warning(f"获取任务翻译失败: {e}，使用原始标题")
                
                # 生成该设备的推送通知标题和内容（根据设备语言）
                if title is None or body is None:
                    from app.push_notification_templates import get_push_notification_text
                    
                    # 根据设备语言生成推送内容
                    device_push_title, device_push_body = get_push_notification_text(
                        notification_type=notification_type,
                        language=device_language,
                        **device_template_vars
                    )
                    
                    # 如果 title 或 body 已提供，使用提供的值
                    if title is not None:
                        device_push_title = title
                    if body is not None:
                        device_push_body = body
                else:
                    # 如果 title 和 body 都已提供，直接使用
                    device_push_title = title
                    device_push_body = body
                
                logger.debug(f"[推送通知] 设备 {device_token.id} 语言: {device_language}, 标题: {device_push_title[:50]}..., 内容: {device_push_body[:100]}...")
                
                # 记录设备令牌信息（用于诊断 BadDeviceToken 错误）
                logger.info(f"[推送诊断] 准备发送到设备: token_id={device_token.id}, device_token长度={len(device_token.device_token)}, device_id={device_token.device_id or '未设置'}, platform={device_token.platform}, device_language={device_language}, is_active={device_token.is_active}")
                
                # 发送推送通知（使用根据设备语言生成的内容）
                if device_token.platform == "ios":
                    result = send_apns_notification(
                        device_token.device_token,
                        title=device_push_title,
                        body=device_push_body,
                        notification_type=notification_type,
                        data=data,
                        badge=badge,
                        sound=sound,
                        localized_content=None  # 不再使用多语言 payload
                    )
                elif device_token.platform == "android":
                    # TODO: 实现 FCM 推送
                    logger.warning("Android FCM 推送尚未实现")
                    result = False
                else:
                    logger.warning(f"未知平台: {device_token.platform}")
                    result = False
                
                if result is True:
                    success_count += 1
                    # 更新最后使用时间
                    device_token.last_used_at = get_utc_time()
                elif result is False:
                    # result 为 False 表示推送失败且设备令牌无效，应该标记为不活跃
                    logger.warning(f"推送失败且设备令牌无效，标记设备令牌为不活跃: {device_token.id}")
                    failed_tokens.append(device_token)
                elif result is None:
                    # result 为 None 表示系统错误（如 apns2 未安装、配置错误等），不应该标记令牌为不活跃
                    logger.warning(f"推送失败（系统错误），不标记设备令牌为不活跃: {device_token.id}")
                    # 不添加到 failed_tokens，保持令牌为活跃状态
                    
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
) -> Optional[bool]:
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
        True: 推送成功
        False: 推送失败且设备令牌无效（应标记为不活跃）
        None: 系统错误（如配置错误、apns2 未安装等，不应标记令牌为不活跃）
    """
    try:
        # 检查 APNs 配置
        if not APNS_KEY_ID or not APNS_TEAM_ID:
            logger.error("APNs 配置不完整（缺少 KEY_ID 或 TEAM_ID），跳过推送通知")
            logger.error(f"APNS_KEY_ID: {APNS_KEY_ID is not None}, APNS_TEAM_ID: {APNS_TEAM_ID is not None}")
            return None  # None 表示系统错误，不应该标记令牌为不活跃
        
        # 获取密钥文件路径
        key_file = get_apns_key_file()
        if not key_file:
            logger.error("APNs 密钥文件不存在或无法加载，跳过推送通知")
            logger.error(f"APNS_KEY_FILE: {APNS_KEY_FILE}, APNS_KEY_CONTENT: {APNS_KEY_CONTENT is not None}")
            return None  # None 表示系统错误，不应该标记令牌为不活跃
        
        logger.info(f"APNs 配置检查通过，使用密钥文件: {key_file}")
        
        # 检查 apns2 是否可用
        if not APNS2_AVAILABLE:
            logger.error(f"apns2 未安装，无法发送推送通知。导入错误: {APNS2_IMPORT_ERROR}")
            logger.error("请确保已安装 compat-fork-apns2: pip install compat-fork-apns2")
            logger.error("如果已安装，请检查 Python 环境和依赖是否正确加载")
            logger.error("在 Railway 环境中，请确保 requirements.txt 中的 compat-fork-apns2>=0.7.0 已正确安装")
            # 系统错误，不应该标记令牌为不活跃（返回特殊值表示系统错误）
            return None  # None 表示系统错误，不应该标记令牌为不活跃
        
        # 记录使用的库版本（用于调试）
        if APNS2_LIBRARY:
            logger.debug(f"使用 {APNS2_LIBRARY} 库发送推送通知")
        
        # 构建通知负载
        payload_data = {
            "type": notification_type
        }
        if data:
            payload_data.update(data)
        
        # 使用传入的 title 和 body（已经根据用户语言偏好生成）
        alert_title = title or "Notification"
        alert_body = body or ""
        
        logger.debug(f"[推送通知] 标题: {alert_title[:50]}..., 内容: {alert_body[:100]}...")
        
        # 构建 payload
        payload = Payload(
            alert={"title": alert_title, "body": alert_body},
            badge=badge,
            sound=sound,
            custom=payload_data
        )
        
        # 创建 Token 凭证（使用 .p8 密钥文件）
        credentials = TokenCredentials(
            auth_key_path=key_file,
            auth_key_id=APNS_KEY_ID,
            team_id=APNS_TEAM_ID
        )
        
        # 创建 APNs 客户端
        apns_client = APNsClient(
            credentials=credentials,
            use_sandbox=APNS_USE_SANDBOX,
            use_alternative_port=False
        )
        
        # 发送通知
        topic = APNS_BUNDLE_ID
        
        # 记录详细的诊断信息（用于调试 BadDeviceToken 错误）
        logger.info(f"[APNs诊断] 准备发送推送: device_token长度={len(device_token)}, device_token前32字符={device_token[:32] if len(device_token) >= 32 else device_token}, topic={topic}, use_sandbox={APNS_USE_SANDBOX}, bundle_id={APNS_BUNDLE_ID}, key_id={APNS_KEY_ID}, team_id={APNS_TEAM_ID}")
        
        # 验证设备令牌格式（APNs 设备令牌应该是 64 个十六进制字符）
        if len(device_token) != 64:
            logger.warning(f"[APNs诊断] 设备令牌长度异常: 期望64字符，实际{len(device_token)}字符")
        if not all(c in '0123456789abcdefABCDEF' for c in device_token):
            logger.warning(f"[APNs诊断] 设备令牌格式异常: 包含非十六进制字符")
        
        response = apns_client.send_notification(device_token, payload, topic)
        
        # 检查响应是否为 None（某些情况下 apns2 可能返回 None）
        if response is None:
            logger.warning(f"[APNs诊断] send_notification 返回 None，可能是异步发送或配置问题")
            # 对于异步发送，可能需要等待响应，这里先返回 None（系统错误，不标记令牌为不活跃）
            return None
        
        # 检查响应
        if response.is_successful:
            logger.info(f"APNs 推送通知已发送: device_token={device_token[:20]}..., topic={topic}, title={alert_title[:30] if alert_title else 'None'}...")
            return True
        else:
            # APNs 返回的错误，需要根据错误类型决定是否标记令牌为不活跃
            logger.warning(f"APNs 推送通知失败: reason={response.reason}, status={response.status_code}")
            
            # 以下错误表示设备令牌无效，应该标记为不活跃：
            # - BadDeviceToken (400): 设备令牌格式错误或无效
            # - Unregistered (410): 设备令牌已失效（应用已卸载或令牌过期）
            # - DeviceTokenNotForTopic (400): 设备令牌不属于此应用
            should_deactivate = response.status_code in [400, 410] or \
                               response.reason in ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic']
            
            if should_deactivate:
                logger.warning(f"设备令牌无效，应标记为不活跃: reason={response.reason}, status={response.status_code}")
                return False  # False 表示推送失败且应该标记令牌为不活跃
            else:
                # 其他错误（如 PayloadTooLarge, TopicDisallowed 等）不应该标记令牌为不活跃
                logger.warning(f"推送失败但令牌可能有效，不标记为不活跃: reason={response.reason}, status={response.status_code}")
                return None  # None 表示系统/配置错误，不应该标记令牌为不活跃
        
    except Exception as e:
        # 检查异常类型名称（更健壮的方法，不依赖于具体的模块路径）
        exception_type_name = type(e).__name__
        exception_module = type(e).__module__
        
        logger.debug(f"捕获到异常: {exception_type_name} (模块: {exception_module})")
        
        # 检查是否是 apns2 库抛出的特定异常（表示设备令牌无效）
        # 使用异常类型名称检查，因为模块路径可能不同（apns2.errors 或 compat_fork_apns2.errors）
        if 'apns2' in exception_module.lower() or 'compat_fork_apns2' in exception_module.lower():
            # 以下异常表示设备令牌无效，应该标记为不活跃
            if exception_type_name in ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic']:
                logger.warning(f"设备令牌无效（异常类型: {exception_type_name}），应标记为不活跃: {e}")
                return False  # False 表示推送失败且应该标记令牌为不活跃
            
            # 其他 apns2 异常（如 PayloadTooLarge, TopicDisallowed 等）不应该标记令牌为不活跃
            if exception_type_name in ['PayloadTooLarge', 'TopicDisallowed', 'BadCollapseId',
                                      'BadExpirationDate', 'BadMessageId', 'BadPriority',
                                      'BadTopic', 'ExpiredProviderToken', 'Forbidden',
                                      'InvalidProviderToken', 'MissingDeviceToken',
                                      'MissingTopic', 'ServiceUnavailable', 'Shutdown',
                                      'TooManyProviderTokenUpdates', 'TooManyRequests',
                                      'UnknownError']:
                logger.warning(f"推送失败但令牌可能有效（异常类型: {exception_type_name}），不标记为不活跃: {e}")
                return None  # None 表示系统/配置错误，不应该标记令牌为不活跃
        
        # 如果 APNS2_ERRORS 可用，也尝试使用 isinstance 检查（更精确）
        if APNS2_ERRORS is not None:
            try:
                # 以下异常表示设备令牌无效，应该标记为不活跃
                if isinstance(e, (APNS2_ERRORS.BadDeviceToken, 
                                 APNS2_ERRORS.Unregistered,
                                 APNS2_ERRORS.DeviceTokenNotForTopic)):
                    logger.warning(f"设备令牌无效（异常类型: {exception_type_name}），应标记为不活跃: {e}")
                    return False  # False 表示推送失败且应该标记令牌为不活跃
                
                # 其他 apns2 异常不应该标记令牌为不活跃
                if hasattr(APNS2_ERRORS, exception_type_name):
                    logger.warning(f"推送失败但令牌可能有效（异常类型: {exception_type_name}），不标记为不活跃: {e}")
                    return None  # None 表示系统/配置错误，不应该标记令牌为不活跃
            except (AttributeError, TypeError):
                # 如果 APNS2_ERRORS 中没有对应的异常类，继续使用类型名称检查的结果
                pass
        
        # 其他未预期的异常（网络错误、超时等）不应该标记令牌为不活跃
        logger.error(f"发送 APNs 推送通知失败: {e}", exc_info=True)
        import traceback
        logger.error(f"详细错误信息: {traceback.format_exc()}")
        return None  # None 表示系统错误，不应该标记令牌为不活跃


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

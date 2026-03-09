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
import time
from pathlib import Path
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# APNs HTTP/2 直接实现（使用 httpx + PyJWT，不再依赖 compat-fork-apns2）
APNS_HTTPX_AVAILABLE = False
try:
    import httpx
    import jwt  # PyJWT
    APNS_HTTPX_AVAILABLE = True
except ImportError as e:
    logger.warning(f"httpx 或 PyJWT 未安装，iOS 推送不可用: {e}")

# APNs JWT token 缓存（有效期 50 分钟，Apple 最长 60 分钟）
_apns_jwt_token: Optional[str] = None
_apns_jwt_expires_at: float = 0
_APNS_JWT_LIFETIME = 50 * 60  # 50 分钟

# APNs 配置
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_BUNDLE_ID = os.getenv("APNS_BUNDLE_ID", "com.link2ur")
APNS_KEY_FILE = os.getenv("APNS_KEY_FILE")  # APNs 密钥文件路径（本地开发使用）
APNS_KEY_CONTENT = os.getenv("APNS_KEY_CONTENT")  # APNs 密钥内容（Base64编码，Railway等云平台使用）
APNS_USE_SANDBOX = os.getenv("APNS_USE_SANDBOX", "false").lower() == "true"  # 是否使用沙盒环境

# 临时文件路径（用于存储从环境变量读取的密钥）
_temp_key_file: Optional[str] = None

# ===== FCM (Firebase Cloud Messaging) 配置 =====
FCM_AVAILABLE = False
FCM_IMPORT_ERROR = None
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS")  # Base64 编码的 service account JSON
FIREBASE_CREDENTIALS_FILE = os.getenv("FIREBASE_CREDENTIALS_FILE")  # 本地开发用文件路径

try:
    import firebase_admin
    from firebase_admin import credentials as firebase_credentials, messaging as firebase_messaging
    FCM_AVAILABLE = True
except ImportError as e:
    FCM_IMPORT_ERROR = str(e)
    logger.warning(f"firebase-admin 未安装，Android 推送通知不可用。错误: {e}")
    logger.warning("请安装: pip install firebase-admin")

_firebase_initialized = False


def _init_firebase():
    """
    初始化 Firebase Admin SDK（延迟初始化，仅在首次发送 FCM 时调用）
    """
    global _firebase_initialized
    if _firebase_initialized:
        return True

    if not FCM_AVAILABLE:
        logger.error(f"firebase-admin 未安装: {FCM_IMPORT_ERROR}")
        return False

    try:
        # 检查是否已经被其他模块初始化
        firebase_admin.get_app()
        _firebase_initialized = True
        return True
    except ValueError:
        pass  # 未初始化，继续

    try:
        cred = None

        # 方式1: 从环境变量加载 Base64 编码的 service account JSON（适合 Railway 等云平台）
        if FIREBASE_CREDENTIALS:
            cred_json = json.loads(base64.b64decode(FIREBASE_CREDENTIALS).decode('utf-8'))
            cred = firebase_credentials.Certificate(cred_json)
            logger.info("从环境变量 FIREBASE_CREDENTIALS 加载 Firebase 凭证")

        # 方式2: 从文件路径加载（本地开发）
        elif FIREBASE_CREDENTIALS_FILE and Path(FIREBASE_CREDENTIALS_FILE).exists():
            cred = firebase_credentials.Certificate(FIREBASE_CREDENTIALS_FILE)
            logger.info(f"从文件加载 Firebase 凭证: {FIREBASE_CREDENTIALS_FILE}")

        if cred is None:
            logger.error("Firebase 凭证未配置（需要 FIREBASE_CREDENTIALS 或 FIREBASE_CREDENTIALS_FILE）")
            return False

        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK 初始化成功")
        return True

    except Exception as e:
        logger.error(f"Firebase Admin SDK 初始化失败: {e}")
        return False


def normalize_device_token(device_token: str) -> Optional[str]:
    """
    规范化设备令牌格式
    
    APNs 设备令牌通常是 32 字节（64 十六进制字符），iOS 13+ 可能为 64 字节（128 字符）。
    Apple 文档指出令牌长度可能变化，本函数支持多种格式：
    - 64 字符十六进制（标准格式）
    - 128 字符十六进制（iOS 13+）
    - Base64 编码的令牌
    - 包含空格或连字符的令牌
    - 超长字符串中提取前 64 或 128 字符（处理客户端拼接错误）
    
    Args:
        device_token: 原始设备令牌字符串
        
    Returns:
        规范化后的十六进制字符串（64 或 128 字符），如果无法解析则返回 None
    """
    if not device_token:
        return None
    
    # 移除空格和连字符
    token = device_token.replace(" ", "").replace("-", "").replace("_", "")
    hex_chars = set('0123456789abcdefABCDEF')
    
    def is_valid_hex(s: str) -> bool:
        return len(s) > 0 and all(c in hex_chars for c in s)
    
    # 标准格式：64 字符十六进制
    if len(token) == 64 and is_valid_hex(token):
        return token.lower()
    
    # iOS 13+ 格式：128 字符十六进制（64 字节）
    if len(token) == 128 and is_valid_hex(token):
        return token.lower()
    
    # 尝试 Base64 解码（某些客户端可能发送 Base64）
    if len(token) >= 40:  # Base64(32 bytes) ≈ 44 字符
        try:
            decoded = base64.b64decode(token, validate=True)
            if len(decoded) in (32, 64):
                return decoded.hex().lower()
        except Exception:
            pass
    
    # 超长字符串：提取前 64 或 128 字符（处理客户端拼接/重复发送）
    if len(token) > 64 and is_valid_hex(token):
        for extract_len in (64, 128):
            if len(token) >= extract_len:
                extracted = token[:extract_len]
                if is_valid_hex(extracted):
                    logger.info(
                        f"设备令牌长度异常({len(token)}字符)，已提取前{extract_len}字符用于推送"
                    )
                    return extracted.lower()
    
    # 无法解析
    logger.warning(
        f"无法规范化设备令牌格式: 长度={len(device_token)}, 前32字符={device_token[:32]}"
    )
    return None


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
            
            # 🔒 安全修复：使用 mkstemp 创建不可预测的临时文件路径
            # 避免使用固定文件名（如 apns_key.p8），防止竞态条件和路径猜测攻击
            fd, temp_key_file = tempfile.mkstemp(suffix='.p8', prefix='apns_')
            fd_owned = True  # 跟踪 fd 所有权，避免 double-close
            try:
                os.chmod(temp_key_file, 0o600)
                f = os.fdopen(fd, 'w')
                fd_owned = False  # os.fdopen 成功后，fd 由文件对象管理
                try:
                    f.write(key_content)
                finally:
                    f.close()
            except Exception:
                if fd_owned:
                    os.close(fd)
                raise
            
            # 注册退出时清理临时文件
            import atexit
            atexit.register(lambda p=temp_key_file: os.path.exists(p) and os.unlink(p))
            
            _temp_key_file = temp_key_file
            logger.info("已从环境变量加载 APNs 密钥（使用安全临时文件）")
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
        
        # 获取用户的所有激活的设备令牌，按更新时间倒序（新令牌更可能有效，优先发送）
        # 限制每用户最多尝试的令牌数，避免资源浪费（同一用户大量旧令牌时）
        max_tokens_per_user = int(os.getenv("PUSH_MAX_TOKENS_PER_USER", "5"))
        device_tokens = (
            db.query(models.DeviceToken)
            .filter(
                models.DeviceToken.user_id == user_id,
                models.DeviceToken.is_active == True,
            )
            .order_by(models.DeviceToken.updated_at.desc())
            .limit(max_tokens_per_user)
            .all()
        )
        
        if not device_tokens:
            logger.warning(f"用户 {user_id} 没有注册的设备令牌，无法发送推送通知")
            return False
        
        logger.info(f"找到 {len(device_tokens)} 个设备令牌，准备发送推送通知给用户 {user_id}")
        
        # 按 device_id 分组，同一设备只需要成功发送一次
        # 这样可以避免同一设备的多个旧令牌都尝试发送
        device_id_success = set()  # 已成功发送的 device_id 集合
        
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
                # 检查该 device_id 是否已成功发送，避免同一设备发送多次
                current_device_id = getattr(device_token, 'device_id', None)
                if current_device_id and current_device_id in device_id_success:
                    logger.debug(f"[推送通知] 设备 {device_token.id} 的 device_id={current_device_id} 已成功发送，跳过")
                    continue
                
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
                    
                    # 从任务表双语列读取标题（任务翻译表已停用）
                    if task_id and original_task_title:
                        try:
                            from app import crud
                            task_id_int = int(task_id) if isinstance(task_id, str) else task_id
                            task = crud.get_task(db, task_id_int)
                            if task:
                                is_zh = device_language and (device_language == 'zh-CN' or str(device_language).lower() == 'zh')
                                col = 'title_zh' if is_zh else 'title_en'
                                text = getattr(task, col, None)
                                if text:
                                    device_template_vars['task_title'] = text
                                    logger.debug(f"设备 {device_token.id} 使用双语标题（{device_language}）: {text[:50]}...")
                                else:
                                    logger.debug(f"任务 {task_id_int} 没有 {device_language} 列，使用原始标题")
                        except (ValueError, TypeError) as e:
                            logger.warning(f"task_id 类型错误: {e}，使用原始标题")
                        except Exception as e:
                            logger.warning(f"获取任务双语标题失败: {e}，使用原始标题")
                
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
                
                # 发送推送通知（使用根据设备语言生成的内容）
                if device_token.platform == "ios":
                    # 规范化设备令牌格式
                    normalized_token = normalize_device_token(device_token.device_token)
                    if not normalized_token:
                        logger.warning(f"设备令牌格式无效，跳过推送: token_id={device_token.id}, 原始长度={len(device_token.device_token)}, 原始前32字符={device_token.device_token[:32]}")
                        failed_tokens.append(device_token)
                        continue
                    
                    # 记录设备令牌信息（用于诊断 BadDeviceToken 错误）
                    logger.info(f"[推送诊断] 准备发送到设备: token_id={device_token.id}, 原始长度={len(device_token.device_token)}, 规范化后长度={len(normalized_token)}, device_id={device_token.device_id or '未设置'}, platform={device_token.platform}, device_language={device_language}, is_active={device_token.is_active}")
                    
                    result = send_apns_notification(
                        normalized_token,
                        title=device_push_title,
                        body=device_push_body,
                        notification_type=notification_type,
                        data=data,
                        badge=badge,
                        sound=sound,
                        localized_content=None  # 不再使用多语言 payload
                    )
                elif device_token.platform == "android":
                    result = send_fcm_notification(
                        device_token.device_token,
                        title=device_push_title,
                        body=device_push_body,
                        notification_type=notification_type,
                        data=data,
                        badge=badge,
                        sound=sound,
                    )
                else:
                    logger.warning(f"未知平台: {device_token.platform}")
                    result = False
                
                if result is True:
                    success_count += 1
                    # 更新最后使用时间
                    device_token.last_used_at = get_utc_time()
                    # 记录已成功发送的 device_id，避免同一设备发送多次
                    if current_device_id:
                        device_id_success.add(current_device_id)
                        logger.debug(f"[推送通知] device_id={current_device_id} 已记录为成功")
                elif result is False:
                    # result 为 False 表示推送失败且设备令牌无效，应该标记为不活跃
                    logger.warning(f"推送失败且设备令牌无效，标记设备令牌为不活跃: {device_token.id}")
                    failed_tokens.append(device_token)
                elif result is None:
                    # result 为 None 表示系统错误（如 apns2 未安装、配置错误等），不应该标记令牌为不活跃
                    logger.warning(f"推送失败（系统错误），不标记设备令牌为不活跃: {device_token.id}")
                    # 不添加到 failed_tokens，保持令牌为活跃状态
                    
            except Exception as e:
                logger.error(f"发送推送通知到设备 {device_token.device_token[:20]}... 失败: {e}", exc_info=True)
                # 🔒 安全修复：不添加到 failed_tokens，避免因非 token 原因的异常导致误停用
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


def _get_apns_jwt() -> Optional[str]:
    """
    获取或刷新 APNs JWT token（缓存 50 分钟，Apple 最长允许 60 分钟）
    """
    global _apns_jwt_token, _apns_jwt_expires_at

    now = time.time()
    if _apns_jwt_token and now < _apns_jwt_expires_at:
        return _apns_jwt_token

    key_file = get_apns_key_file()
    if not key_file:
        logger.error("APNs 密钥文件不存在或无法加载")
        return None

    try:
        with open(key_file, 'r') as f:
            auth_key = f.read()

        _apns_jwt_token = jwt.encode(
            {"iss": APNS_TEAM_ID, "iat": int(now)},
            auth_key,
            algorithm="ES256",
            headers={"kid": APNS_KEY_ID},
        )
        _apns_jwt_expires_at = now + _APNS_JWT_LIFETIME
        return _apns_jwt_token
    except Exception as e:
        logger.error(f"生成 APNs JWT 失败: {e}")
        return None


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
    通过 httpx HTTP/2 直接调用 APNs API 发送推送通知

    Returns:
        True: 推送成功
        False: 推送失败且设备令牌无效（应标记为不活跃）
        None: 系统错误（不应标记令牌为不活跃）
    """
    if not APNS_HTTPX_AVAILABLE:
        logger.error("httpx 或 PyJWT 未安装，无法发送 APNs 推送")
        return None

    if not APNS_KEY_ID or not APNS_TEAM_ID:
        logger.error(f"APNs 配置不完整: KEY_ID={APNS_KEY_ID is not None}, TEAM_ID={APNS_TEAM_ID is not None}")
        return None

    token = _get_apns_jwt()
    if not token:
        return None

    # 构建 APNs payload
    aps = {
        "alert": {"title": title or "Notification", "body": body or ""},
        "sound": sound,
    }
    if badge is not None:
        aps["badge"] = badge

    payload = {"aps": aps}
    if notification_type:
        payload["type"] = notification_type
    if data:
        payload.update(data)

    # APNs URL
    host = "https://api.development.push.apple.com" if APNS_USE_SANDBOX else "https://api.push.apple.com"
    url = f"{host}/3/device/{device_token}"

    headers = {
        "authorization": f"bearer {token}",
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
    }

    logger.info(f"[APNs] 发送推送: token={device_token[:20]}..., topic={APNS_BUNDLE_ID}, sandbox={APNS_USE_SANDBOX}")

    _MAX_RETRIES = 2
    _RETRY_DELAYS = [1, 3]

    for attempt in range(_MAX_RETRIES + 1):
        try:
            with httpx.Client(http2=True, timeout=10.0) as client:
                response = client.post(url, json=payload, headers=headers)

            status = response.status_code

            if status == 200:
                logger.info(f"[APNs] 推送成功: token={device_token[:20]}..., apns-id={response.headers.get('apns-id', 'N/A')}")
                return True

            # 解析错误原因
            reason = ""
            try:
                reason = response.json().get("reason", "")
            except Exception:
                pass

            logger.warning(f"[APNs] 推送失败: status={status}, reason={reason}")

            # 令牌无效 → 标记不活跃
            if status == 410 or reason in ("BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"):
                return False

            # 服务端临时错误 → 重试
            if status in (500, 503) and attempt < _MAX_RETRIES:
                time.sleep(_RETRY_DELAYS[attempt])
                continue

            # 其他错误（403 ExpiredProviderToken 等）→ 系统错误
            # 如果是 JWT 过期，清除缓存以便下次重新生成
            if reason == "ExpiredProviderToken":
                global _apns_jwt_token, _apns_jwt_expires_at
                _apns_jwt_token = None
                _apns_jwt_expires_at = 0
            return None

        except (httpx.ConnectError, httpx.TimeoutException, ConnectionError, TimeoutError) as e:
            if attempt < _MAX_RETRIES:
                logger.warning(f"[APNs] 网络错误（第{attempt+1}次），{_RETRY_DELAYS[attempt]}秒后重试: {e}")
                time.sleep(_RETRY_DELAYS[attempt])
                continue
            logger.error(f"[APNs] 重试{_MAX_RETRIES}次后仍失败: {e}")
            return None
        except Exception as e:
            logger.error(f"[APNs] 未预期错误: {e}", exc_info=True)
            return None

    return None


def send_fcm_notification(
    device_token: str,
    title: Optional[str] = None,
    body: Optional[str] = None,
    notification_type: str = "general",
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None,
    sound: str = "default",
) -> Optional[bool]:
    """
    发送 FCM 推送通知 (Android)

    Returns:
        True: 推送成功
        False: 推送失败且设备令牌无效（应标记为不活跃）
        None: 系统错误（不应标记令牌为不活跃）
    """
    if not FCM_AVAILABLE:
        logger.error(f"firebase-admin 未安装: {FCM_IMPORT_ERROR}")
        return None

    if not _init_firebase():
        return None

    try:
        # 构建 data payload（FCM data 值必须是字符串）
        fcm_data = {"type": notification_type}
        if data:
            for k, v in data.items():
                fcm_data[k] = str(v) if v is not None else ""

        if badge is not None:
            fcm_data["badge"] = str(badge)

        # 构建 FCM 消息
        message = firebase_messaging.Message(
            token=device_token,
            notification=firebase_messaging.Notification(
                title=title or "Notification",
                body=body or "",
            ),
            android=firebase_messaging.AndroidConfig(
                priority="high",
                notification=firebase_messaging.AndroidNotification(
                    sound=sound if sound != "default" else "default",
                    channel_id="link2ur_notifications",
                ),
            ),
            data=fcm_data,
        )

        # 发送
        response = firebase_messaging.send(message)
        logger.info(f"FCM 推送成功: device_token={device_token[:20]}..., message_id={response}")
        return True

    except Exception as e:
        error_str = str(e).lower()
        exc_name = type(e).__name__

        # 令牌无效的错误
        # firebase_admin.messaging 抛出的异常：
        # - UNREGISTERED: app 已卸载或 token 过期
        # - INVALID_ARGUMENT: token 格式错误
        # - NOT_FOUND: token 不存在
        token_invalid_keywords = [
            'unregistered', 'not-registered',
            'invalid-registration-token', 'invalid-argument',
            'registration-token-not-registered',
            'missingregistration', 'invalidregistration',
        ]
        if any(kw in error_str for kw in token_invalid_keywords):
            logger.warning(f"FCM 设备令牌无效 ({exc_name}): {e}")
            return False

        # 其他错误（配额、服务端错误等）不停用令牌
        logger.error(f"FCM 推送失败 ({exc_name}): {e}")
        return None


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

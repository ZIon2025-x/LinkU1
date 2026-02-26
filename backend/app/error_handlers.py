"""
统一错误处理模块
提供标准化的错误响应和安全错误信息
"""

import logging
from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse, Response
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException


logger = logging.getLogger(__name__)


def set_cors_headers(response: Response, request: Request = None):
    """设置CORS响应头"""
    from app.config import Config
    
    if request:
        origin = request.headers.get("origin")
        # 使用 Config.ALLOWED_ORIGINS（从环境变量读取）
        allowed_origins = Config.ALLOWED_ORIGINS
        if origin and any(origin == allowed or origin.startswith(allowed.rstrip('/')) for allowed in allowed_origins):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, Expires, X-CSRF-Token, X-Session-ID"
    else:
        # 如果没有request，回退到受控来源（避免 "*"）
        default_origin = Config.ALLOWED_ORIGINS[0] if Config.ALLOWED_ORIGINS else None
        if default_origin:
            response.headers["Access-Control-Allow-Origin"] = default_origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Cache-Control, Pragma, X-CSRF-Token, X-Session-ID"


class SecurityError(Exception):
    """安全相关错误"""
    def __init__(self, message: str, error_code: str = "SECURITY_ERROR"):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class ValidationError(Exception):
    """验证错误"""
    def __init__(self, message: str, field: str = None):
        self.message = message
        self.field = field
        super().__init__(self.message)


class BusinessError(Exception):
    """业务逻辑错误"""
    def __init__(self, message: str, error_code: str = "BUSINESS_ERROR"):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class ReadOnlyModeError(Exception):
    """只读模式错误 — 系统处于维护/只读状态，写操作被拒绝"""
    def __init__(self, message: str = "系统维护中，暂时无法执行此操作，请稍后再试"):
        self.message = message
        super().__init__(self.message)


# 标准错误响应格式
def create_error_response(
    message: str,
    status_code: int = 400,
    error_code: str = "GENERAL_ERROR",
    details: Optional[Dict[str, Any]] = None,
    request_id: Optional[str] = None,
) -> Dict[str, Any]:
    """创建标准错误响应（含 request_id 便于排查与日志关联）"""
    response = {
        "error": True,
        "message": message,
        "error_code": error_code,
        "status_code": status_code,
    }
    if request_id:
        response["request_id"] = request_id
    if details:
        response["details"] = details
    return response


def _get_request_id(request: Request) -> Optional[str]:
    """从 request.state 安全获取 request_id（由 RequestLoggingMiddleware 注入）"""
    return getattr(request.state, "request_id", None) if request else None


# 安全错误信息映射（避免泄露敏感信息）
SECURITY_ERROR_MESSAGES = {
    "INVALID_CREDENTIALS": "用户名或密码错误",
    "ACCOUNT_LOCKED": "账户已被锁定",
    "TOKEN_EXPIRED": "登录已过期，请重新登录",
    "TOKEN_INVALID": "无效的认证令牌",
    "ACCESS_DENIED": "访问被拒绝",
    "CSRF_TOKEN_MISSING": "缺少CSRF令牌",
    "CSRF_TOKEN_INVALID": "CSRF令牌验证失败",
    "RATE_LIMIT_EXCEEDED": "请求过于频繁，请稍后再试",
    "INVALID_INPUT": "输入数据无效",
    "FILE_TOO_LARGE": "文件过大",
    "INVALID_FILE_TYPE": "不支持的文件类型",
    "UNAUTHORIZED_ACCESS": "未授权访问",
    "RESOURCE_NOT_FOUND": "请求的资源不存在",
    "DUPLICATE_RESOURCE": "资源已存在",
    "OPERATION_FAILED": "操作失败",
    "SERVER_ERROR": "服务器内部错误",
    "SERVICE_UNAVAILABLE": "服务暂时不可用，请稍后重试",
    "MAINTENANCE": "系统维护中，暂时无法执行此操作，请稍后再试",
    # 注册相关错误
    "EMAIL_ALREADY_EXISTS": "该邮箱已被注册，请使用其他邮箱或直接登录",
    "USERNAME_ALREADY_EXISTS": "该用户名已被使用，请选择其他用户名",
    "PASSWORD_TOO_WEAK": "密码强度不够，请确保密码至少8个字符且包含字母和数字",
    "INVALID_EMAIL_FORMAT": "邮箱格式不正确，请输入有效的邮箱地址",
    "INVALID_USERNAME_FORMAT": "用户名格式不正确，只能包含字母、数字、下划线和连字符，且不能以数字开头",
    "USERNAME_CONTAINS_KEYWORDS": "用户名不能包含客服相关关键词",
    "VALIDATION_ERROR": "输入数据验证失败"
}


def get_safe_error_message(error_code: str, original_message=None) -> str:
    """获取安全的错误信息。original_message 可为 str、list（FastAPI 校验错误）或 dict（含 message 键）。"""
    if isinstance(original_message, dict):
        msg_str = str(original_message.get("message", ""))
    elif isinstance(original_message, list):
        msg_str = (original_message[0].get("msg", str(original_message[0]))
                   if original_message and isinstance(original_message[0], dict)
                   else str(original_message[0]) if original_message else "")
    else:
        msg_str = str(original_message) if original_message else ""

    if error_code in SECURITY_ERROR_MESSAGES:
        return SECURITY_ERROR_MESSAGES[error_code]

    import os
    if os.getenv("ENVIRONMENT", "development") == "development":
        return msg_str or "未知错误"

    # 用户注册/资料/验证码类：保留具体原因，便于用户修改后重试
    if msg_str and any(keyword in msg_str for keyword in [
        "该邮箱已被注册", "该邮箱已被其他用户使用", "该手机号已被", "该用户名已被使用",
        "用户名不能包含", "密码至少需要", "密码必须包含", "邮箱格式不正确", "用户名至少", "用户名不能超过",
        "用户名不能以数字开头", "用户名不能包含空格", "手机号格式不正确", "手机验证码错误或已过期",
        "发送验证码失败", "不能使用临时邮箱", "修改邮箱需要验证码", "修改手机号需要验证码",
        "验证码错误或已过期", "您必须同意用户协议", "语言偏好只能是", "短信服务未配置",
    ]):
        return msg_str

    # 任务/申请类业务提示：保留原文
    if msg_str and any(k in msg_str for k in [
        "已经申请过", "already applied", "You have already applied",
        "您已经提交过争议", "已经提交过反驳", "无法重复提交",
    ]):
        return msg_str

    # 权限/登录类：保留原文便于区分原因
    if msg_str and any(k in msg_str for k in [
        "需要登录", "无权限查看", "登录才能查看", "客服账号不能",
        "Only task poster", "Only the task taker", "Only task participants",
        "Not authorized", "don't have permission",
    ]):
        return msg_str

    # 支付/退款/任务状态类：保留具体原因
    if msg_str and any(k in msg_str for k in [
        "任务尚未支付", "无法批准", "无法完成", "无法进入进行中", "无需退款",
        "已不再支付", "Stripe争议已冻结", "退款类型必须", "退款金额必须", "退款比例必须",
        "证据文件数量不能超过", "转账金额必须", "文字证据说明不能超过",
        "Task is not", "Task cannot be cancelled", "cancel request is already pending",
        "Task deadline has passed", "Cannot create review", "Dispute is not pending",
    ]):
        return msg_str

    # 收款账户/Stripe Connect 类：保留原文，便于用户完成设置或联系对方
    if msg_str and any(k in msg_str for k in [
        "收款账户", "Stripe Connect", "payout account", "payment account",
        "请通知接受人", "请联系卖家", "请联系任务达人", "请联系申请者",
    ]):
        return msg_str

    # 账户/密码重置等：保留原文
    if msg_str and any(k in msg_str for k in [
        "临时邮箱", "无法接收密码重置", "无法删除账户", "进行中的任务",
        "未找到待验证的用户", "订阅记录不存在", "Refund request not found",
    ]):
        return msg_str

    return "操作失败，请稍后重试"


# 根据异常详情返回稳定 error_code，供客户端做国际化（i18n）展示
def get_error_code_from_detail(detail) -> str:
    """从 exc.detail 推断稳定错误码，客户端用此 key 查多语言文案。
    支持 detail 为 dict：{"error_code": "STRIPE_SETUP_REQUIRED", "message": "..."} 显式传递，便于 iOS 等客户端做 i18n。
    """
    if detail is None:
        return "HTTP_ERROR"
    # 显式传递的 error_code（适配前端 i18n）
    if isinstance(detail, dict) and detail.get("error_code"):
        return str(detail["error_code"])
    if isinstance(detail, list):
        msg = (detail[0].get("msg", "") if detail and isinstance(detail[0], dict) else str(detail[0]) if detail else "")
    else:
        msg = str(detail)
    if not msg:
        return "HTTP_ERROR"
    msg_lower = msg.lower()
    # 注册/登录/资料
    if "该邮箱已被其他用户使用" in msg or "email already used" in msg_lower:
        return "EMAIL_ALREADY_USED"
    if "该邮箱已被注册" in msg or "email already exists" in msg_lower:
        return "EMAIL_ALREADY_EXISTS"
    if "该手机号已被其他用户使用" in msg:
        return "PHONE_ALREADY_USED"
    if "该手机号已被注册" in msg:
        return "PHONE_ALREADY_EXISTS"
    if "该用户名已被使用" in msg or "username already" in msg_lower:
        return "USERNAME_ALREADY_EXISTS"
    if "验证码错误或已过期" in msg or "invalid or expired token" in msg_lower or "verification code" in msg_lower and "expired" in msg_lower:
        return "CODE_INVALID_OR_EXPIRED"
    if "发送验证码失败" in msg:
        return "SEND_CODE_FAILED"
    if "修改邮箱需要验证码" in msg:
        return "EMAIL_UPDATE_NEED_CODE"
    if "修改手机号需要验证码" in msg:
        return "PHONE_UPDATE_NEED_CODE"
    if "不能使用临时邮箱" in msg:
        return "TEMP_EMAIL_NOT_ALLOWED"
    if "需要登录" in msg or "login" in msg_lower and "view" in msg_lower:
        return "LOGIN_REQUIRED"
    if "无权限查看" in msg or "not authorized" in msg_lower or "don't have permission" in msg_lower:
        return "FORBIDDEN_VIEW"
    # 任务/申请
    if "已经申请过" in msg or "already applied" in msg_lower:
        return "TASK_ALREADY_APPLIED"
    if "您已经提交过争议" in msg:
        return "DISPUTE_ALREADY_SUBMITTED"
    if "已经提交过反驳" in msg:
        return "REBUTTAL_ALREADY_SUBMITTED"
    # 支付/任务状态
    if "任务尚未支付" in msg:
        return "TASK_NOT_PAID"
    if "已不再支付" in msg or "无法处理退款" in msg:
        return "TASK_PAYMENT_UNAVAILABLE"
    if "Stripe争议已冻结" in msg:
        return "STRIPE_DISPUTE_FROZEN"
    if "退款金额必须" in msg or "退款比例必须" in msg:
        return "REFUND_AMOUNT_REQUIRED"
    if "证据文件数量不能超过" in msg:
        return "EVIDENCE_FILES_LIMIT"
    if "文字证据说明不能超过" in msg:
        return "EVIDENCE_TEXT_LIMIT"
    if "无法删除账户" in msg and "进行中的任务" in msg:
        return "ACCOUNT_HAS_ACTIVE_TASKS"
    if "临时邮箱" in msg and "密码重置" in msg:
        return "TEMP_EMAIL_NO_PASSWORD_RESET"
    # 收款账户/Stripe Connect：区分当前用户需设置 vs 对方（接受人/卖家/达人）需设置
    if "请通知" in msg or "请联系" in msg:
        if "stripe" in msg_lower or "收款" in msg:
            return "STRIPE_OTHER_PARTY_NOT_SETUP"
    if "任务接受人" in msg or "卖家" in msg or "任务达人" in msg or "申请者" in msg or "申请人" in msg:
        if ("尚未创建" in msg or "尚未设置" in msg) and ("stripe" in msg_lower or "收款" in msg):
            return "STRIPE_OTHER_PARTY_NOT_SETUP"
    if "收款账户" in msg or "stripe connect" in msg_lower or "payout account" in msg_lower:
        return "STRIPE_SETUP_REQUIRED"
    return "HTTP_ERROR"


# 全局异常处理器
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """HTTP异常处理器。返回带 error_code 的响应，便于客户端做错误文案国际化。"""
    error_code = getattr(exc, 'error_code', None) or get_error_code_from_detail(exc.detail)
    safe_message = get_safe_error_message(error_code, exc.detail)
    
    # 记录错误日志（不包含敏感信息）
    # 401 错误在非调试模式下使用 debug 级别，减少日志噪音
    # 日志过滤器会进一步过滤常见的 401 端点
    if exc.status_code == 401:
        import os
        if os.getenv("ENVIRONMENT", "development") == "development":
            logger.warning(f"HTTP异常: {exc.status_code} - {error_code} - {request.url}")
        else:
            logger.debug(f"认证失败: {request.url}")
    else:
        # 记录错误详情以便调试（对于400错误特别重要）
        error_detail = str(exc.detail) if hasattr(exc, 'detail') and exc.detail else "无详情"
        logger.warning(f"HTTP异常: {exc.status_code} - {error_code} - {request.url} - 详情: {error_detail}")
    
    response = JSONResponse(
        status_code=exc.status_code,
        content=create_error_response(
            message=safe_message,
            status_code=exc.status_code,
            error_code=error_code,
            request_id=_get_request_id(request),
        )
    )
    # 确保设置CORS头
    set_cors_headers(response, request)
    return response


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """验证异常处理器 - 确保CORS头被设置"""
    # 提取验证错误详情
    errors = []
    for error in exc.errors():
        # 记录完整的位置信息以便调试
        full_loc = error.get("loc", [])
        field = ".".join(str(x) for x in full_loc[1:]) if len(full_loc) > 1 else str(full_loc[0]) if full_loc else "unknown"
        message = error.get("msg", "Unknown error")
        error_type = error.get("type", "unknown")
        errors.append({"field": field, "message": message, "type": error_type, "full_location": full_loc})
    
    logger.warning(f"验证错误: {len(errors)}个错误 - {request.url}")
    logger.warning(f"验证错误详情: {errors}")  # 添加详细错误信息
    # 记录完整的错误对象以便调试
    for error in exc.errors():
        logger.warning(f"完整错误对象: {error}")
    
    response = JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=create_error_response(
            message="输入数据验证失败",
            status_code=422,
            error_code="VALIDATION_ERROR",
            details={"errors": errors},
            request_id=_get_request_id(request),
        )
    )
    # 确保设置CORS头
    set_cors_headers(response, request)
    return response


async def security_exception_handler(request: Request, exc: SecurityError) -> JSONResponse:
    """安全异常处理器"""
    safe_message = get_safe_error_message(exc.error_code, exc.message)
    
    # 记录安全事件
    from app.security import get_client_ip
    client_ip = get_client_ip(request)
    logger.warning(f"安全异常: {exc.error_code} - {request.url} - IP: {client_ip}")
    
    response = JSONResponse(
        status_code=status.HTTP_403_FORBIDDEN,
        content=create_error_response(
            message=safe_message,
            status_code=403,
            error_code=exc.error_code,
            request_id=_get_request_id(request),
        )
    )
    # 设置CORS头
    set_cors_headers(response, request)
    return response


async def business_exception_handler(request: Request, exc: BusinessError) -> JSONResponse:
    """业务异常处理器"""
    safe_message = get_safe_error_message(exc.error_code, exc.message)
    
    logger.info(f"业务异常: {exc.error_code} - {exc.message}")
    
    response = JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=create_error_response(
            message=safe_message,
            status_code=400,
            error_code=exc.error_code,
            request_id=_get_request_id(request),
        )
    )
    # 设置CORS头
    set_cors_headers(response, request)
    return response


async def read_only_mode_handler(request: Request, exc: ReadOnlyModeError) -> JSONResponse:
    """只读模式异常处理器 — 返回 503 + MAINTENANCE"""
    response = JSONResponse(
        status_code=503,
        content=create_error_response(
            message=exc.message,
            status_code=503,
            error_code="MAINTENANCE",
            request_id=_get_request_id(request),
        ),
        headers={"Retry-After": "60"}
    )
    set_cors_headers(response, request)
    return response


def _is_db_unavailable_error(exc: Exception) -> bool:
    """判断异常是否为数据库不可用错误（连接超时/拒绝/池耗尽等）"""
    try:
        from sqlalchemy.exc import OperationalError, InvalidatePoolError, TimeoutError as SATimeoutError
        if isinstance(exc, (OperationalError, InvalidatePoolError, SATimeoutError)):
            return True
    except ImportError:
        pass
    
    error_msg = str(exc).lower()
    return any(keyword in error_msg for keyword in [
        "connection refused",
        "connection timed out",
        "could not connect",
        "connection reset",
        "server closed the connection unexpectedly",
        "connection is closed",
        "ssl connection has been closed unexpectedly",
        "queuepool limit",
    ])


# DB 不可用日志限流 — 避免请求级别的刷屏
import time as _time
_db_error_last_logged: float = 0.0
_DB_ERROR_LOG_COOLDOWN = 30  # 秒


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """通用异常处理器 — 区分 DB 不可用（503）和其他服务端错误（500）"""
    global _db_error_last_logged
    
    # 检测数据库不可用 → 返回 503 + Retry-After，而非 500
    if _is_db_unavailable_error(exc):
        now = _time.time()
        if now - _db_error_last_logged > _DB_ERROR_LOG_COOLDOWN:
            _db_error_last_logged = now
            logger.error(f"数据库不可用: {type(exc).__name__} - {str(exc)}")
        
        response = JSONResponse(
            status_code=503,
            content=create_error_response(
                message="服务暂时不可用，请稍后重试",
                status_code=503,
                error_code="SERVICE_UNAVAILABLE",
                request_id=_get_request_id(request),
            ),
            headers={"Retry-After": "30"}
        )
        set_cors_headers(response, request)
        return response

    # 其他未处理异常 → 500
    logger.error(f"未处理的异常: {type(exc).__name__} - {str(exc)}", exc_info=True)

    safe_message = get_safe_error_message("SERVER_ERROR")

    response = JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=create_error_response(
            message=safe_message,
            status_code=500,
            error_code="SERVER_ERROR",
            request_id=_get_request_id(request),
        )
    )
    
    # 设置CORS头
    set_cors_headers(response, request)
    return response


# 便捷的错误抛出函数
def raise_security_error(message: str, error_code: str = "SECURITY_ERROR"):
    """抛出安全错误"""
    raise SecurityError(message, error_code)


def raise_validation_error(message: str, field: str = None):
    """抛出验证错误"""
    raise ValidationError(message, field)


def raise_business_error(message: str, error_code: str = "BUSINESS_ERROR"):
    """抛出业务错误"""
    raise BusinessError(message, error_code)


def raise_http_error(message: str, status_code: int = 400, error_code: str = "HTTP_ERROR"):
    """抛出HTTP错误"""
    raise HTTPException(status_code=status_code, detail=message)


def raise_http_error_with_code(message: str, status_code: int, error_code: str):
    """抛出带显式 error_code 的 HTTP 错误，便于 iOS 等客户端做国际化（i18n）。"""
    raise HTTPException(
        status_code=status_code,
        detail={"error_code": error_code, "message": message}
    )

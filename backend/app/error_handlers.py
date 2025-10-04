"""
统一错误处理模块
提供标准化的错误响应和安全错误信息
"""

import logging
from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import traceback

logger = logging.getLogger(__name__)


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


# 标准错误响应格式
def create_error_response(
    message: str,
    status_code: int = 400,
    error_code: str = "GENERAL_ERROR",
    details: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """创建标准错误响应"""
    response = {
        "error": True,
        "message": message,
        "error_code": error_code,
        "status_code": status_code
    }
    
    if details:
        response["details"] = details
    
    return response


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
    # 注册相关错误
    "EMAIL_ALREADY_EXISTS": "该邮箱已被注册，请使用其他邮箱或直接登录",
    "USERNAME_ALREADY_EXISTS": "该用户名已被使用，请选择其他用户名",
    "PASSWORD_TOO_WEAK": "密码强度不够，请确保密码至少8个字符且包含字母和数字",
    "INVALID_EMAIL_FORMAT": "邮箱格式不正确，请输入有效的邮箱地址",
    "INVALID_USERNAME_FORMAT": "用户名格式不正确，只能包含字母、数字、下划线和连字符，且不能以数字开头",
    "USERNAME_CONTAINS_KEYWORDS": "用户名不能包含客服相关关键词",
    "VALIDATION_ERROR": "输入数据验证失败"
}


def get_safe_error_message(error_code: str, original_message: str = None) -> str:
    """获取安全的错误信息"""
    # 如果是已知的安全错误代码，返回安全信息
    if error_code in SECURITY_ERROR_MESSAGES:
        return SECURITY_ERROR_MESSAGES[error_code]
    
    # 如果是开发环境，返回原始信息
    import os
    if os.getenv("ENVIRONMENT", "development") == "development":
        return original_message or "未知错误"
    
    # 生产环境返回通用错误信息
    return "操作失败，请稍后重试"


# 全局异常处理器
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """HTTP异常处理器"""
    error_code = getattr(exc, 'error_code', 'HTTP_ERROR')
    safe_message = get_safe_error_message(error_code, exc.detail)
    
    # 记录错误日志（不包含敏感信息）
    logger.warning(f"HTTP异常: {exc.status_code} - {error_code} - {request.url}")
    
    return JSONResponse(
        status_code=exc.status_code,
        content=create_error_response(
            message=safe_message,
            status_code=exc.status_code,
            error_code=error_code
        )
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """验证异常处理器"""
    # 提取验证错误详情
    errors = []
    for error in exc.errors():
        field = ".".join(str(x) for x in error["loc"][1:])  # 跳过body
        message = error["msg"]
        errors.append({"field": field, "message": message})
    
    logger.warning(f"验证错误: {len(errors)}个错误 - {request.url}")
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=create_error_response(
            message="输入数据验证失败",
            status_code=422,
            error_code="VALIDATION_ERROR",
            details={"errors": errors}
        )
    )


async def security_exception_handler(request: Request, exc: SecurityError) -> JSONResponse:
    """安全异常处理器"""
    safe_message = get_safe_error_message(exc.error_code, exc.message)
    
    # 记录安全事件
    logger.warning(f"安全异常: {exc.error_code} - {request.url} - IP: {request.client.host}")
    
    return JSONResponse(
        status_code=status.HTTP_403_FORBIDDEN,
        content=create_error_response(
            message=safe_message,
            status_code=403,
            error_code=exc.error_code
        )
    )


async def business_exception_handler(request: Request, exc: BusinessError) -> JSONResponse:
    """业务异常处理器"""
    safe_message = get_safe_error_message(exc.error_code, exc.message)
    
    logger.info(f"业务异常: {exc.error_code} - {exc.message}")
    
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=create_error_response(
            message=safe_message,
            status_code=400,
            error_code=exc.error_code
        )
    )


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """通用异常处理器"""
    # 记录详细错误信息到日志
    logger.error(f"未处理的异常: {type(exc).__name__} - {str(exc)} - {traceback.format_exc()}")
    
    # 返回通用错误信息
    safe_message = get_safe_error_message("SERVER_ERROR")
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=create_error_response(
            message=safe_message,
            status_code=500,
            error_code="SERVER_ERROR"
        )
    )


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
    raise HTTPException(
        status_code=status_code,
        detail=message,
        error_code=error_code
    )

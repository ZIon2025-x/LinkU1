"""
日志配置模块
提供统一的日志过滤器、结构化日志格式和日志轮转配置
"""
import json
import logging
import logging.handlers
import os
import sys
from datetime import datetime, timezone
from typing import Optional


class IgnoreCommon401Filter(logging.Filter):
    """
    过滤常见的 401 认证错误日志，减少日志噪音
    
    这些错误通常是正常的用户行为（未登录访问、会话过期等），
    不需要在生产环境中记录为警告级别
    """
    
    # 需要过滤的常见 401 端点
    FILTERED_ENDPOINTS = [
        "/api/users/profile/me",
        "/api/secure-auth/refresh",
        "/api/secure-auth/refresh-token",
    ]
    
    def filter(self, record: logging.LogRecord) -> bool:
        """
        过滤日志记录
        
        Returns:
            False: 丢弃这条日志
            True: 保留这条日志
        """
        msg = record.getMessage()
        
        # 只处理包含 HTTP异常: 401 的日志
        if "HTTP异常: 401" not in msg:
            return True
        
        # 检查是否是常见的 401 端点
        for endpoint in self.FILTERED_ENDPOINTS:
            if endpoint in msg:
                # 在非调试模式下，丢弃这些常见的 401 日志
                # 调试模式下仍然记录（通过日志级别控制）
                if record.levelno >= logging.WARNING:
                    # 生产环境的警告级别日志，直接丢弃
                    return False
                # DEBUG/INFO 级别的日志保留（用于调试）
                return True
        
        # 其他 401 错误保留（可能是真正的安全问题）
        return True


class StructuredFormatter(logging.Formatter):
    """
    结构化 JSON 日志格式化器
    生产环境输出 JSON 格式日志，便于 ELK / CloudWatch 等聚合系统解析
    """

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": getattr(record, "request_id", "-"),
        }

        # 如果有异常信息，加入 traceback
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)

        # 添加调用位置（仅 WARNING 及以上）
        if record.levelno >= logging.WARNING:
            log_entry["location"] = f"{record.pathname}:{record.lineno}"

        return json.dumps(log_entry, ensure_ascii=False, default=str)


class ReadableFormatter(logging.Formatter):
    """
    可读的文本格式化器（包含 request_id）
    开发环境使用
    """

    def __init__(self):
        super().__init__(
            fmt="%(asctime)s [%(levelname)s] [%(request_id)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

    def format(self, record: logging.LogRecord) -> str:
        # 确保 request_id 属性存在
        if not hasattr(record, "request_id"):
            record.request_id = "-"
        return super().format(record)


def configure_logging():
    """
    配置日志系统
    - 根据环境选择格式化器（JSON / 可读文本）
    - 配置日志轮转（文件处理器）
    - 安装 RequestID 过滤器和 401 降噪过滤器
    """
    from app.request_logging_middleware import RequestIDFilter

    is_production = os.getenv("ENVIRONMENT", "development") == "production"
    log_level_str = os.getenv("LOG_LEVEL", "INFO" if is_production else "DEBUG").upper()
    log_level = getattr(logging, log_level_str, logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # 清除默认处理器，避免重复输出
    root_logger.handlers.clear()

    # ---- 1. RequestID 过滤器（全局） ----
    request_id_filter = RequestIDFilter()
    root_logger.addFilter(request_id_filter)

    # ---- 2. 控制台处理器 ----
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)

    if is_production:
        console_handler.setFormatter(StructuredFormatter())
    else:
        console_handler.setFormatter(ReadableFormatter())

    root_logger.addHandler(console_handler)

    # ---- 3. 文件处理器（带轮转） ----
    log_dir = os.getenv("LOG_DIR", "logs")
    try:
        os.makedirs(log_dir, exist_ok=True)

        # 应用日志文件（10MB 轮转，保留 5 个备份）
        app_file_handler = logging.handlers.RotatingFileHandler(
            filename=os.path.join(log_dir, "app.log"),
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5,
            encoding="utf-8",
        )
        app_file_handler.setLevel(logging.INFO)
        app_file_handler.setFormatter(StructuredFormatter())
        root_logger.addHandler(app_file_handler)

        # 错误日志文件（单独记录 WARNING 及以上）
        error_file_handler = logging.handlers.RotatingFileHandler(
            filename=os.path.join(log_dir, "error.log"),
            maxBytes=10 * 1024 * 1024,
            backupCount=5,
            encoding="utf-8",
        )
        error_file_handler.setLevel(logging.WARNING)
        error_file_handler.setFormatter(StructuredFormatter())
        root_logger.addHandler(error_file_handler)

    except (OSError, PermissionError) as e:
        # 如果无法创建日志目录/文件（如 Railway 只读文件系统），只用控制台
        console_logger = logging.getLogger(__name__)
        console_logger.warning(f"无法创建日志文件，仅使用控制台输出: {e}")

    # ---- 4. 安全日志文件轮转（替代原始 security.log） ----
    try:
        security_logger = logging.getLogger("security")
        # 移除旧的无轮转 FileHandler
        for handler in security_logger.handlers[:]:
            security_logger.removeHandler(handler)

        security_handler = logging.handlers.RotatingFileHandler(
            filename=os.path.join(log_dir, "security.log"),
            maxBytes=10 * 1024 * 1024,
            backupCount=10,  # 安全日志保留更多备份
            encoding="utf-8",
        )
        security_handler.setLevel(logging.INFO)
        security_handler.setFormatter(StructuredFormatter())
        security_logger.addHandler(security_handler)
        security_logger.setLevel(logging.INFO)
    except (OSError, PermissionError):
        pass  # 安全日志文件创建失败，使用默认输出

    # ---- 5. 401 降噪过滤器 ----
    error_handler_logger = logging.getLogger("app.error_handlers")
    error_handler_logger.addFilter(IgnoreCommon401Filter())

    # ---- 6. 降低第三方库日志级别 ----
    for noisy_logger in [
        "uvicorn.access",
        "uvicorn.error",
        "sqlalchemy.engine",
        "httpcore",
        "httpx",
        "stripe",
    ]:
        logging.getLogger(noisy_logger).setLevel(logging.WARNING)

    logger = logging.getLogger(__name__)
    logger.info(
        f"日志系统已配置 (级别={log_level_str}, "
        f"格式={'JSON' if is_production else '可读文本'}, "
        f"轮转=已启用)"
    )


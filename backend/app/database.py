import asyncio
import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv

logger = logging.getLogger(__name__)
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

load_dotenv()

# 从统一配置导入数据库URL，避免重复定义
from app.config import Config
DATABASE_URL = Config.DATABASE_URL
ASYNC_DATABASE_URL = Config.ASYNC_DATABASE_URL

# 检查asyncpg是否可用
try:
    import asyncpg

    ASYNC_AVAILABLE = True
except ImportError:
    ASYNC_AVAILABLE = False
    logger.warning("asyncpg not available, using sync mode only")

# 连接池配置 - 根据环境优化
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
IS_PRODUCTION = ENVIRONMENT == "production"

# ⚠️ 由于混合使用同步/异步操作，增加了连接池大小
if IS_PRODUCTION:
    # 生产环境配置 - 增加以支持混合使用
    # POOL_RECYCLE 建议小于 Railway/代理的空闲超时，避免使用已被代理关闭的连接（默认 10 分钟）
    POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "30"))  # 从20增加到30
    MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "40"))  # 从30增加到40
    POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))
    POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "600"))  # 10 分钟，适配代理空闲断开
    POOL_PRE_PING = os.getenv("DB_POOL_PRE_PING", "true").lower() == "true"
    QUERY_TIMEOUT = int(os.getenv("DB_QUERY_TIMEOUT", "30"))
else:
    # 开发环境配置 - 增加以支持混合使用
    POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))  # 从5增加到10
    MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))  # 从10增加到20
    POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))
    POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "3600"))  # 1小时
    POOL_PRE_PING = os.getenv("DB_POOL_PRE_PING", "true").lower() == "true"
    QUERY_TIMEOUT = int(os.getenv("DB_QUERY_TIMEOUT", "30"))

# 创建异步引擎（仅在asyncpg可用时）
if ASYNC_AVAILABLE:
    async_engine = create_async_engine(
        ASYNC_DATABASE_URL,
        echo=False,
        future=True,
        pool_size=POOL_SIZE,
        max_overflow=MAX_OVERFLOW,
        pool_timeout=POOL_TIMEOUT,
        pool_recycle=POOL_RECYCLE,
        pool_pre_ping=POOL_PRE_PING,
        # 优化连接池关闭行为，减少事件循环冲突
        pool_reset_on_return='commit',  # 在返回连接池时重置连接状态
        connect_args={
            "command_timeout": QUERY_TIMEOUT,
            "server_settings": {
                "application_name": "linku_app",
                "jit": "off",  # 禁用JIT以提高小查询性能
                # P2 优化：连接级查询超时配置（毫秒）
                # 在连接创建时一次性设置，避免每次查询都执行 SET statement_timeout
                "statement_timeout": str(QUERY_TIMEOUT * 1000),  # 转换为毫秒
            },
        },
    )
else:
    async_engine = None

# 创建异步会话工厂（仅在asyncpg可用时）
if ASYNC_AVAILABLE:
    AsyncSessionLocal = async_sessionmaker(
        async_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
else:
    AsyncSessionLocal = None

# 为了向后兼容，保留同步引擎（用于数据库迁移等工具）
# 优化同步引擎连接池配置
# P2 优化：查询超时配置在连接级设置（一次性配置，减少额外往返）
# 使用 connect_args 中的 options 参数在连接创建时设置 statement_timeout
# 这比在 before_cursor_execute 中每次 SET statement_timeout 更高效
sync_engine = create_engine(
    DATABASE_URL,
    echo=False,
    future=True,
    pool_size=POOL_SIZE,
    max_overflow=MAX_OVERFLOW,
    pool_timeout=POOL_TIMEOUT,
    pool_recycle=POOL_RECYCLE,
    pool_pre_ping=POOL_PRE_PING,
    connect_args={
        # P2 优化：连接级查询超时配置（毫秒）
        # 在连接创建时一次性设置，避免每次查询都执行 SET statement_timeout
        "options": f"-c statement_timeout={QUERY_TIMEOUT * 1000}"  # 转换为毫秒
    }
)
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=sync_engine,
    expire_on_commit=False  # 提高性能，避免不必要的session刷新
)

# ⚠️ 弃用警告：SessionLocal (同步数据库) 已标记为弃用
# 请在新代码中使用 AsyncSessionLocal (异步数据库)
# 老接口将逐步迁移到异步模式
import warnings
warnings.warn(
    "SessionLocal (sync DB) 已标记为弃用，请在新代码中使用 AsyncSessionLocal",
    DeprecationWarning,
    stacklevel=2
)


# 异步数据库依赖
async def get_async_db():
    """获取异步数据库会话（异常时自动回滚）"""
    if not ASYNC_AVAILABLE or not AsyncSessionLocal:
        raise RuntimeError("Async database not available. Please install asyncpg.")

    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# 同步数据库依赖（向后兼容）
def get_db():
    """获取同步数据库会话（异常时自动回滚）
    
    🔒 安全机制：当请求处理中发生未捕获的异常时，
    自动回滚所有未提交的数据库更改，防止部分提交导致数据不一致。
    """
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


# 异步上下文管理器
@asynccontextmanager
async def get_async_db_context():
    """异步数据库会话上下文管理器"""
    if not ASYNC_AVAILABLE or not AsyncSessionLocal:
        raise RuntimeError("Async database not available. Please install asyncpg.")

    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# 数据库健康检查
async def check_database_health():
    """检查数据库连接健康状态"""
    if not ASYNC_AVAILABLE or not AsyncSessionLocal:
        return False

    try:
        from sqlalchemy import text

        async with AsyncSessionLocal() as session:
            result = await session.execute(text("SELECT 1"))
            return True
    except Exception as e:
        logger.warning("Database health check failed: %s", e)
        return False


# 连接池状态监控
async def get_pool_status():
    """获取连接池状态信息"""
    if not ASYNC_AVAILABLE or not async_engine:
        return {"error": "Async database not available"}

    pool = async_engine.pool
    return {
        "pool_size": pool.size(),
        "checked_in": pool.checkedin(),
        "checked_out": pool.checkedout(),
        "overflow": pool.overflow(),
        # 注意：QueuePool 没有 invalid() 方法，移除该调用
        # "invalid": pool.invalid(),
    }


# 连接池监控任务
_pool_monitor_task = None


async def monitor_pool_state():
    """监控连接池状态，如果压力偏高则记录警告日志"""
    import logging
    logger = logging.getLogger(__name__)
    
    from app.state import is_app_shutting_down
    
    while not is_app_shutting_down():
        try:
            if not ASYNC_AVAILABLE or not async_engine:
                await asyncio.sleep(60)
                continue
            
            pool = async_engine.pool
            pool_size = pool.size()
            checked_out = pool.checkedout()
            overflow = pool.overflow()
            
            # 检查连接池压力
            # 1. 如果有溢出连接，说明连接池可能不够大
            # 2. 如果已签出连接超过池大小的80%，说明压力较高
            if overflow > 0:
                logger.warning(
                    "数据库连接池压力偏高: overflow=%d, checked_out=%d, pool_size=%d",
                    overflow, checked_out, pool_size
                )
            elif checked_out > pool_size * 0.8:
                logger.warning(
                    "数据库连接池使用率较高: checked_out=%d, pool_size=%d (使用率: %.1f%%)",
                    checked_out, pool_size, (checked_out / pool_size * 100) if pool_size > 0 else 0
                )
            
            # 每分钟检查一次
            await asyncio.sleep(60)
        except asyncio.CancelledError:
            logger.debug("连接池监控任务已取消")
            break
        except Exception as e:
            # 如果应用正在关停，忽略错误
            if is_app_shutting_down():
                break
            logger.error(f"连接池监控任务出错: {e}", exc_info=True)
            # 出错时等待更长时间再重试
            await asyncio.sleep(60)


def start_pool_monitor():
    """启动连接池监控任务"""
    global _pool_monitor_task
    if _pool_monitor_task is None or _pool_monitor_task.done():
        import asyncio
        _pool_monitor_task = asyncio.create_task(monitor_pool_state())


def stop_pool_monitor():
    """停止连接池监控任务"""
    global _pool_monitor_task
    if _pool_monitor_task and not _pool_monitor_task.done():
        _pool_monitor_task.cancel()


# 安全关闭数据库连接池
async def close_database_pools():
    """
    在 shutdown 事件里调用，安全关闭数据库连接池
    必须在事件循环还活着的时候调用
    """
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # 先处理异步引擎（因为它依赖事件循环）
        if ASYNC_AVAILABLE and async_engine:
            try:
                # 可以视情况留一点时间给 in-flight query
                await asyncio.sleep(0.1)
                await async_engine.dispose(close=True)
                logger.info("异步数据库引擎已关闭")
            except RuntimeError as e:
                # 如果此时 loop 已经被关闭，就不要再强行处理
                if "Event loop is closed" in str(e):
                    logger.debug("事件循环已关闭，跳过异步引擎关闭")
                else:
                    logger.warning(f"关闭异步引擎时出错: {e}")
            except Exception as e:
                logger.warning(f"关闭异步引擎时出错: {e}")
        
        # 再处理同步引擎
        if sync_engine:
            try:
                sync_engine.dispose()
                logger.info("同步数据库引擎已关闭")
            except Exception as e:
                logger.warning(f"关闭同步引擎时出错: {e}")
    except Exception as e:
        logger.warning(f"关闭数据库连接池时出错: {e}")
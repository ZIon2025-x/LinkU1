import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

load_dotenv()

# 异步数据库URL
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql+psycopg2://postgres:password@localhost:5432/linku_db"
)
ASYNC_DATABASE_URL = os.getenv(
    "ASYNC_DATABASE_URL", "postgresql+asyncpg://postgres:password@localhost:5432/linku_db"
)

# 检查asyncpg是否可用
try:
    import asyncpg

    ASYNC_AVAILABLE = True
except ImportError:
    ASYNC_AVAILABLE = False
    print("⚠️  asyncpg not available, using sync mode only")

# 连接池配置 - 根据环境优化
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
IS_PRODUCTION = ENVIRONMENT == "production"

# ⚠️ 由于混合使用同步/异步操作，增加了连接池大小
if IS_PRODUCTION:
    # 生产环境配置 - 增加以支持混合使用
    POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "30"))  # 从20增加到30
    MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "40"))  # 从30增加到40
    POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))
    POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "1800"))  # 30分钟
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


# 异步数据库依赖
async def get_async_db():
    """获取异步数据库会话"""
    if not ASYNC_AVAILABLE or not AsyncSessionLocal:
        raise RuntimeError("Async database not available. Please install asyncpg.")

    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


# 同步数据库依赖（向后兼容）
def get_db():
    """获取同步数据库会话（向后兼容）"""
    db = SessionLocal()
    try:
        yield db
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
        print(f"Database health check failed: {e}")
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
        "invalid": pool.invalid(),
    }

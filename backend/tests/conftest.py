"""
pytest 配置与公共 fixture

单元测试 (test_*.py):
- db: 提供可回滚的 Session，测试后自动 rollback，不污染数据库
- 需设置 DATABASE_URL（CI 中由 PostgreSQL 服务提供）

API 集成测试 (tests/api/):
- 不需要本地数据库，通过 HTTP 请求测试远程 Railway 环境
- 有独立的 conftest.py
"""

import os
import pytest

# =============================================================================
# 尝试导入 sqlalchemy（API 测试不需要，单元测试需要）
# =============================================================================
try:
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session, sessionmaker
    from sqlalchemy.pool import StaticPool
    SQLALCHEMY_AVAILABLE = True
except ImportError:
    SQLALCHEMY_AVAILABLE = False
    print("ℹ️  sqlalchemy 未安装，数据库相关 fixture 不可用（API 测试不需要）")


# 测试用 DATABASE_URL：优先从环境读取，CI 中应指向 PostgreSQL 服务
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:password@localhost:5432/linku_db"),
)


def _get_engine():
    """获取测试用引擎。若为 SQLite（本地快速试跑）则用内存库；否则用 PostgreSQL。"""
    if not SQLALCHEMY_AVAILABLE:
        return None
    
    if TEST_DATABASE_URL and "sqlite" in TEST_DATABASE_URL:
        return create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
    # PostgreSQL：测试环境简化配置，不设置 statement_timeout
    return create_engine(
        TEST_DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
    )


@pytest.fixture(scope="session")
def _engine():
    """Session 级引擎，用于建表。"""
    if not SQLALCHEMY_AVAILABLE:
        pytest.skip("sqlalchemy 不可用")
    return _get_engine()


@pytest.fixture(scope="session")
def _tables(_engine):
    """创建所有表（仅一次）。需先导入 models 以注册到 Base.metadata。"""
    if not SQLALCHEMY_AVAILABLE:
        pytest.skip("sqlalchemy 不可用")
    
    from app.models import Base

    Base.metadata.create_all(bind=_engine)
    return _engine


@pytest.fixture
def db(_tables):
    """
    提供可回滚的 Session。
    每个测试在独立事务中运行，结束后 rollback，不落盘，不污染数据库。
    """
    if not SQLALCHEMY_AVAILABLE:
        pytest.skip("sqlalchemy 不可用")
    
    from app.models import Base

    connection = _tables.connect()
    transaction = connection.begin()
    SessionLocal = sessionmaker(
        bind=connection,
        autocommit=False,
        autoflush=False,
        expire_on_commit=False,
    )
    session = SessionLocal()

    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()

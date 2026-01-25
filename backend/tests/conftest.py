"""
pytest 配置与公共 fixture
- db: 提供可回滚的 Session，测试后自动 rollback，不污染数据库
- 需设置 DATABASE_URL（CI 中由 PostgreSQL 服务提供）
"""

import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

# 测试用 DATABASE_URL：优先从环境读取，CI 中应指向 PostgreSQL 服务
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:password@localhost:5432/linku_db"),
)


def _get_engine():
    """获取测试用引擎。若为 SQLite（本地快速试跑）则用内存库；否则用 PostgreSQL。"""
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
    return _get_engine()


@pytest.fixture(scope="session")
def _tables(_engine):
    """创建所有表（仅一次）。需先导入 models 以注册到 Base.metadata。"""
    from app.models import Base

    Base.metadata.create_all(bind=_engine)
    return _engine


@pytest.fixture
def db(_tables):
    """
    提供可回滚的 Session。
    每个测试在独立事务中运行，结束后 rollback，不落盘，不污染数据库。
    """
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

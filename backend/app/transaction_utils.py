"""
事务管理工具
提供安全的事务处理和错误回滚
"""

import logging
from typing import Callable, TypeVar, Optional
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from contextlib import contextmanager
from functools import wraps

logger = logging.getLogger(__name__)

T = TypeVar('T')


@contextmanager
def db_transaction(db: Session):
    """
    同步数据库事务上下文管理器
    
    使用示例:
        with db_transaction(db) as session:
            session.add(new_object)
            # 自动提交，异常时自动回滚
    """
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"数据库事务失败，已回滚: {e}", exc_info=True)
        raise


def with_transaction(func: Callable[..., T]) -> Callable[..., T]:
    """
    装饰器：为函数添加事务管理
    
    使用示例:
        @with_transaction
        def my_function(db: Session, ...):
            db.add(new_object)
            # 自动提交，异常时自动回滚
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        # 查找db参数
        db = None
        for arg in args:
            if isinstance(arg, Session):
                db = arg
                break
        
        if 'db' in kwargs and isinstance(kwargs['db'], Session):
            db = kwargs['db']
        
        if not db:
            # 如果没有找到db，直接执行函数
            return func(*args, **kwargs)
        
        try:
            result = func(*args, **kwargs)
            db.commit()
            return result
        except Exception as e:
            db.rollback()
            logger.error(f"函数 {func.__name__} 执行失败，已回滚: {e}", exc_info=True)
            raise
    
    return wrapper


async def async_db_transaction(db: AsyncSession):
    """
    异步数据库事务上下文管理器
    
    使用示例:
        async with async_db_transaction(db) as session:
            session.add(new_object)
            await session.commit()
            # 异常时自动回滚
    """
    try:
        yield db
        await db.commit()
    except Exception as e:
        await db.rollback()
        logger.error(f"异步数据库事务失败，已回滚: {e}", exc_info=True)
        raise


def safe_commit(db: Session, operation_name: str = "操作") -> bool:
    """
    安全提交数据库更改，带错误处理和回滚
    
    Args:
        db: 数据库会话
        operation_name: 操作名称（用于日志）
    
    Returns:
        bool: 是否成功提交
    """
    try:
        db.commit()
        return True
    except Exception as e:
        db.rollback()
        logger.error(f"{operation_name}提交失败，已回滚: {e}", exc_info=True)
        return False


async def safe_commit_async(db: AsyncSession, operation_name: str = "操作") -> bool:
    """
    安全提交异步数据库更改，带错误处理和回滚
    
    Args:
        db: 异步数据库会话
        operation_name: 操作名称（用于日志）
    
    Returns:
        bool: 是否成功提交
    """
    try:
        await db.commit()
        return True
    except Exception as e:
        await db.rollback()
        logger.error(f"{operation_name}提交失败，已回滚: {e}", exc_info=True)
        return False

"""
同步到异步的适配器模块
用于在异步路由中安全地调用同步CRUD操作
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from functools import wraps
from typing import Any, Callable, TypeVar

from sqlalchemy.orm import Session

# 创建线程池用于执行同步数据库操作
# 注意：这会创建新线程，但允许我们在异步上下文中安全地调用同步代码
executor = ThreadPoolExecutor(max_workers=20, thread_name_prefix="db_sync")

T = TypeVar('T')


def async_wrapper(func: Callable[..., T]) -> Callable[..., Any]:
    """将同步函数包装为异步函数"""
    @wraps(func)
    async def wrapper(*args: Any, **kwargs: Any) -> T:
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            executor, 
            lambda: func(*args, **kwargs)
        )
    return wrapper


class SyncToAsyncAdapter:
    """同步CRUD操作到异步的适配器"""
    
    @staticmethod
    @async_wrapper
    def get_user_by_id(db: Session, user_id: str):
        """在异步上下文中获取用户"""
        from app import crud
        return crud.get_user_by_id(db, user_id)
    
    @staticmethod
    @async_wrapper
    def create_task(db: Session, user_id: str, task):
        """在异步上下文中创建任务"""
        from app import crud
        return crud.create_task(db, user_id, task)
    
    @staticmethod
    @async_wrapper
    def list_tasks(db: Session, **kwargs):
        """在异步上下文中列出任务"""
        from app import crud
        return crud.list_tasks(db, **kwargs)
    
    @staticmethod
    @async_wrapper
    def send_message(db: Session, **kwargs):
        """在异步上下文中发送消息"""
        from app import crud
        return crud.send_message(db, **kwargs)
    
    @staticmethod
    @async_wrapper
    def create_user(db: Session, user):
        """在异步上下文中创建用户"""
        from app import crud
        return crud.create_user(db, user)
    
    @staticmethod
    @async_wrapper
    def get_user_by_email(db: Session, email: str):
        """在异步上下文中通过邮箱获取用户"""
        from app import crud
        return crud.get_user_by_email(db, email)
    
    @staticmethod
    @async_wrapper
    def update_user(db: Session, user_id: str, user_data):
        """在异步上下文中更新用户"""
        from app import crud
        user = crud.get_user_by_id(db, user_id)
        if user:
            for key, value in user_data.dict().items():
                setattr(user, key, value)
            db.commit()
            db.refresh(user)
        return user


# 创建全局实例
sync_to_async = SyncToAsyncAdapter()


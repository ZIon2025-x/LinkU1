"""
任务服务层
提供带缓存的任务查询服务，避免装饰器重复创建
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app import crud, schemas
from app.cache_decorators import cache_task_detail_sync, invalidate_task_cache


class TaskService:
    """任务服务类 - 使用静态方法避免装饰器重复创建"""
    
    @staticmethod
    @cache_task_detail_sync(ttl=300)  # 装饰器在类定义时初始化，只执行一次
    def get_task_cached(task_id: int, db: Session) -> schemas.TaskOut:
        """带缓存的任务查询服务"""
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        return task
    
    @staticmethod
    def invalidate_cache(task_id: int):
        """使任务缓存失效"""
        invalidate_task_cache(task_id)


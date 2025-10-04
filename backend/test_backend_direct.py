#!/usr/bin/env python3
"""
直接测试后端函数
"""

import asyncio
import sys
import os

# 添加项目路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.deps import get_async_db_dependency
from app import async_crud
from app import models
from sqlalchemy import select

async def test_apply_for_task():
    """直接测试apply_for_task函数"""
    print("Testing apply_for_task function directly...")
    
    # 获取数据库会话
    async for db in get_async_db_dependency():
        try:
            # 查找一个任务
            task_query = select(models.Task).where(models.Task.status == "open").limit(1)
            task_result = await db.execute(task_query)
            task = task_result.scalar_one_or_none()
            
            if not task:
                print("ERROR: No open tasks found")
                return
            
            print(f"Found task: {task.id} - {task.title}")
            print(f"Task level: {task.task_level}")
            
            # 查找一个用户
            user_query = select(models.User).limit(1)
            user_result = await db.execute(user_query)
            user = user_result.scalar_one_or_none()
            
            if not user:
                print("ERROR: No users found")
                return
            
            print(f"Found user: {user.id} - {user.name}")
            print(f"User level: {user.user_level}")
            
            # 测试申请任务
            print("\nTesting apply_for_task...")
            application = await async_crud.async_task_crud.apply_for_task(
                db, task.id, user.id, "Test application message"
            )
            
            if application:
                print(f"SUCCESS: Application created with ID: {application.id}")
            else:
                print("ERROR: Application creation failed")
                
        except Exception as e:
            print(f"ERROR: Exception during test: {e}")
            import traceback
            traceback.print_exc()
        finally:
            break

if __name__ == "__main__":
    asyncio.run(test_apply_for_task())

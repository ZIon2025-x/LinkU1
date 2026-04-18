"""Task 级 API 的通用守卫:拒绝对咨询占位 task 的业务操作。"""

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app import models


async def load_real_task_or_404(db: AsyncSession, task_id: int) -> models.Task:
    """加载 Task,并确保它不是咨询占位。

    占位 task 不应出现在任何 task-level 业务 API 上(支付/评价/取消/完成/
    退款/争议等),即使 task_id 合法。返回 404 伪装成"任务不存在",避免泄露
    占位 id 的存在(防探测)。

    使用场景:所有 /api/tasks/{task_id}/* 端点开头替换 `db.get(Task, task_id)`。
    """
    task = await db.get(models.Task, task_id)
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")
    if task.is_consultation_placeholder:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")
    return task

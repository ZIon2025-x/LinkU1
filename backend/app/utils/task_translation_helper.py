"""
任务双语展示辅助：从任务表 title_zh/title_en、description_zh/description_en 列读取。
任务翻译表（task_translations）已停用，不再读写。
"""
import logging
from typing import Dict, List, Tuple, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app import models

logger = logging.getLogger(__name__)


async def get_task_translations_batch(
    db: AsyncSession,
    task_ids: List[int],
    field_type: str = "title",
) -> Dict[Tuple[int, str], str]:
    """
    批量从任务表双语列读取。键 (task_id, target_language)，值为对应列内容（可能为空）。
    field_type: 'title' 或 'description'。
    """
    if not task_ids:
        return {}

    if field_type == "title":
        cols = [models.Task.id, models.Task.title_zh, models.Task.title_en]
    else:
        cols = [models.Task.id, models.Task.description_zh, models.Task.description_en]

    q = select(*cols).where(models.Task.id.in_(task_ids))
    result = await db.execute(q)
    rows = result.all()

    out: Dict[Tuple[int, str], str] = {}
    for row in rows:
        tid = row[0]
        if field_type == "title":
            zh_val, en_val = row[1], row[2]
        else:
            zh_val, en_val = row[1], row[2]
        if zh_val:
            out[(tid, "zh-CN")] = zh_val
        if en_val:
            out[(tid, "en")] = en_val
    return out


def get_task_title_translations(
    translations_dict: Dict[Tuple[int, str], str],
    task_id: int,
) -> Tuple[Optional[str], Optional[str]]:
    """从字典中取 (title_en, title_zh)。"""
    title_en = translations_dict.get((task_id, "en"))
    title_zh = translations_dict.get((task_id, "zh-CN"))
    return title_en, title_zh


def get_task_description_translations(
    translations_dict: Dict[Tuple[int, str], str],
    task_id: int,
) -> Tuple[Optional[str], Optional[str]]:
    """从字典中取 (description_en, description_zh)。"""
    description_en = translations_dict.get((task_id, "en"))
    description_zh = translations_dict.get((task_id, "zh-CN"))
    return description_en, description_zh

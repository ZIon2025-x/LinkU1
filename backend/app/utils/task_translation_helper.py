"""
任务翻译辅助函数
用于批量获取任务翻译，如果没有翻译则自动翻译并保存
"""
import logging
import threading
from typing import Dict, List, Tuple, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from app import models
from app.deps import get_db
from app.utils.translation_prefetch import prefetch_task_by_id

logger = logging.getLogger(__name__)


async def get_task_translations_batch(
    db: AsyncSession,
    task_ids: List[int],
    field_type: str = 'title'
) -> Dict[Tuple[int, str], str]:
    """
    批量获取任务翻译
    
    Args:
        db: 异步数据库会话
        task_ids: 任务ID列表
        field_type: 字段类型（'title' 或 'description'）
    
    Returns:
        字典，键为 (task_id, target_language)，值为翻译后的文本
    """
    if not task_ids:
        return {}
    
    # 批量查询任务翻译
    translations_query = select(models.TaskTranslation).where(
        and_(
            models.TaskTranslation.task_id.in_(task_ids),
            models.TaskTranslation.field_type == field_type,
            models.TaskTranslation.target_language.in_(['en', 'zh-CN'])
        )
    )
    translations_result = await db.execute(translations_query)
    translations_dict = {}
    for trans in translations_result.scalars().all():
        key = (trans.task_id, trans.target_language)
        translations_dict[key] = trans.translated_text
    
    # 对于没有翻译的任务，在后台异步翻译并保存（不阻塞响应）
    missing_translations = []
    for task_id in task_ids:
        if (task_id, 'en') not in translations_dict:
            missing_translations.append((task_id, 'en'))
        if (task_id, 'zh-CN') not in translations_dict:
            missing_translations.append((task_id, 'zh-CN'))
    
    # 在后台触发翻译任务（不等待结果）
    if missing_translations:
        def trigger_translations_sync():
            """在后台线程中触发翻译任务（使用同步数据库会话）"""
            try:
                # 为每个需要翻译的任务触发预翻译
                task_ids_to_translate = set()
                for task_id, _ in missing_translations:
                    task_ids_to_translate.add(task_id)
                
                # 创建同步数据库会话
                sync_db = next(get_db())
                try:
                    for task_id in task_ids_to_translate:
                        try:
                            # prefetch_task_by_id 是异步函数，需要在事件循环中运行
                            # 但由于我们在后台线程中，需要创建新的事件循环
                            import asyncio as async_io
                            loop = async_io.new_event_loop()
                            async_io.set_event_loop(loop)
                            try:
                                loop.run_until_complete(
                                    prefetch_task_by_id(sync_db, task_id, target_languages=['en', 'zh-CN'])
                                )
                            finally:
                                loop.close()
                        except Exception as e:
                            logger.warning(f"后台翻译任务 {task_id} {field_type}失败: {e}")
                finally:
                    sync_db.close()
            except Exception as e:
                logger.error(f"后台翻译任务{field_type}失败: {e}")
        
        # 在后台线程中执行翻译（不阻塞响应）
        thread = threading.Thread(target=trigger_translations_sync, daemon=True)
        thread.start()
    
    return translations_dict


def get_task_title_translations(
    translations_dict: Dict[Tuple[int, str], str],
    task_id: int
) -> Tuple[Optional[str], Optional[str]]:
    """
    从翻译字典中获取任务的标题翻译
    
    Args:
        translations_dict: 翻译字典，键为 (task_id, target_language)
        task_id: 任务ID
    
    Returns:
        (title_en, title_zh) 元组
    """
    title_en = translations_dict.get((task_id, 'en'))
    title_zh = translations_dict.get((task_id, 'zh-CN'))
    return title_en, title_zh


def get_task_description_translations(
    translations_dict: Dict[Tuple[int, str], str],
    task_id: int
) -> Tuple[Optional[str], Optional[str]]:
    """
    从翻译字典中获取任务的描述翻译
    
    Args:
        translations_dict: 翻译字典，键为 (task_id, target_language)
        task_id: 任务ID
    
    Returns:
        (description_en, description_zh) 元组
    """
    description_en = translations_dict.get((task_id, 'en'))
    description_zh = translations_dict.get((task_id, 'zh-CN'))
    return description_en, description_zh

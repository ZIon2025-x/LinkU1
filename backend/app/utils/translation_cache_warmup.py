"""
翻译缓存预热工具
在系统启动或任务列表加载时，预热热门任务的翻译缓存
"""
import logging
from typing import List, Optional
from app.utils.task_translation_cache import cache_task_translation, get_cached_task_translation
from app import crud

logger = logging.getLogger(__name__)


def warmup_task_translations(
    db,
    task_ids: List[int],
    languages: List[str] = None,
    field_types: List[str] = None
) -> dict:
    """
    预热任务翻译缓存
    
    参数:
    - db: 数据库会话
    - task_ids: 任务ID列表
    - languages: 目标语言列表，默认为 ['en', 'zh-CN']
    - field_types: 字段类型列表，默认为 ['title', 'description']
    
    返回:
    - dict: 预热统计信息 {cached: int, missed: int, errors: int}
    """
    if not task_ids:
        return {"cached": 0, "missed": 0, "errors": 0}
    
    languages = languages or ['en', 'zh-CN']
    field_types = field_types or ['title']
    
    stats = {"cached": 0, "missed": 0, "errors": 0}
    
    try:
        for task_id in task_ids:
            for field_type in field_types:
                for target_lang in languages:
                    try:
                        # 检查缓存是否已存在
                        cached = get_cached_task_translation(task_id, field_type, target_lang)
                        if cached:
                            continue  # 已缓存，跳过
                        
                        # 从数据库获取翻译
                        translation = crud.get_task_translation(
                            db, task_id, field_type, target_lang, validate=False
                        )
                        
                        if translation:
                            # 缓存到Redis
                            success = cache_task_translation(
                                task_id, field_type, target_lang,
                                translation.translated_text,
                                translation.source_language
                            )
                            if success:
                                stats["cached"] += 1
                            else:
                                stats["errors"] += 1
                        else:
                            stats["missed"] += 1
                    except Exception as e:
                        logger.warning(f"预热任务翻译失败: task_id={task_id}, field={field_type}, lang={target_lang}, error={e}")
                        stats["errors"] += 1
        
        if stats["cached"] > 0:
            logger.info(f"翻译缓存预热完成: 缓存{stats['cached']}条, 缺失{stats['missed']}条, 错误{stats['errors']}条")
        
        return stats
    except Exception as e:
        logger.error(f"翻译缓存预热失败: {e}")
        return stats


def warmup_hot_tasks(db, limit: int = 50) -> dict:
    """
    预热热门任务的翻译缓存
    
    参数:
    - db: 数据库会话
    - limit: 预热的任务数量
    
    返回:
    - dict: 预热统计信息
    """
    try:
        # 获取最近创建或更新的热门任务
        from app.models import Task
        hot_tasks = db.query(Task.id).filter(
            Task.status == 'open'
        ).order_by(
            Task.created_at.desc()
        ).limit(limit).all()
        
        task_ids = [task.id for task in hot_tasks]
        
        if task_ids:
            return warmup_task_translations(db, task_ids)
        else:
            return {"cached": 0, "missed": 0, "errors": 0}
    except Exception as e:
        logger.error(f"预热热门任务翻译失败: {e}")
        return {"cached": 0, "missed": 0, "errors": 0}

"""
翻译缓存预热工具
在系统启动或任务列表加载时，预热热门任务的翻译缓存
支持智能预热策略：根据用户语言偏好、任务类型等
"""
import logging
from typing import List, Optional, Dict
from app.utils.task_translation_cache import cache_task_translation, get_cached_task_translation
from app import crud

logger = logging.getLogger(__name__)

# 常用语言优先级（根据用户使用频率）
LANGUAGE_PRIORITY = {
    'en': 1,  # 最高优先级
    'zh-CN': 2,
    'zh-TW': 3,
    'es': 4,
    'fr': 5,
    'de': 6,
    'ja': 7,
    'ko': 8,
}


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


def warmup_hot_tasks(
    db,
    limit: int = 50,
    user_language: Optional[str] = None,
    task_type: Optional[str] = None
) -> dict:
    """
    预热热门任务的翻译缓存（智能策略）
    
    参数:
    - db: 数据库会话
    - limit: 预热的任务数量
    - user_language: 用户语言偏好（用于优先预热该语言的翻译）
    - task_type: 任务类型（用于筛选特定类型的任务）
    
    返回:
    - dict: 预热统计信息
    """
    try:
        # 获取最近创建或更新的热门任务
        from app.models import Task
        from sqlalchemy import desc
        
        query = db.query(Task.id).filter(
            Task.status == 'open'
        )
        
        # 如果指定了任务类型，添加过滤条件
        if task_type:
            query = query.filter(Task.task_type == task_type)
        
        hot_tasks = query.order_by(
            desc(Task.created_at)
        ).limit(limit).all()
        
        task_ids = [task.id for task in hot_tasks]
        
        if not task_ids:
            return {"cached": 0, "missed": 0, "errors": 0}
        
        # 根据用户语言偏好确定目标语言列表
        if user_language:
            # 用户语言优先级最高，然后是常用语言
            languages = [user_language] + [
                lang for lang, _ in sorted(
                    LANGUAGE_PRIORITY.items(),
                    key=lambda x: x[1]
                ) if lang != user_language
            ][:2]  # 最多3种语言
        else:
            # 默认使用最常用的语言
            languages = [
                lang for lang, _ in sorted(
                    LANGUAGE_PRIORITY.items(),
                    key=lambda x: x[1]
                )
            ][:3]  # 最多3种语言
        
        return warmup_task_translations(db, task_ids, languages=languages)
    except Exception as e:
        logger.error(f"预热热门任务翻译失败: {e}")
        return {"cached": 0, "missed": 0, "errors": 0}


def warmup_by_user_preference(
    db,
    user_id: Optional[str] = None,
    user_language: Optional[str] = None,
    limit: int = 30
) -> dict:
    """
    根据用户偏好预热翻译缓存
    
    参数:
    - db: 数据库会话
    - user_id: 用户ID（可选，用于获取用户历史偏好）
    - user_language: 用户语言偏好
    - limit: 预热的任务数量
    
    返回:
    - dict: 预热统计信息
    """
    try:
        # 如果提供了用户ID，可以从用户历史记录中获取偏好
        # 这里简化处理，直接使用提供的语言偏好
        
        # 获取用户可能感兴趣的任务（可以根据用户历史、收藏等）
        from app.models import Task
        from sqlalchemy import desc
        
        # 简化：获取最近的任务
        tasks = db.query(Task.id).filter(
            Task.status == 'open'
        ).order_by(
            desc(Task.created_at)
        ).limit(limit).all()
        
        task_ids = [task.id for task in tasks]
        
        if not task_ids:
            return {"cached": 0, "missed": 0, "errors": 0}
        
        # 根据用户语言偏好确定目标语言
        if user_language:
            languages = [user_language]
        else:
            languages = ['en', 'zh-CN']  # 默认语言
        
        return warmup_task_translations(db, task_ids, languages=languages)
    except Exception as e:
        logger.error(f"根据用户偏好预热翻译失败: {e}")
        return {"cached": 0, "missed": 0, "errors": 0}

"""
翻译预取工具
预翻译热门任务，提升用户体验
"""
import logging
import asyncio
from typing import List, Dict, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# 常用目标语言（按优先级排序）
COMMON_TARGET_LANGUAGES = ['en', 'zh-CN', 'zh-TW']


async def prefetch_popular_tasks(
    db,
    limit: int = 50,
    target_languages: Optional[List[str]] = None,
    min_views: int = 10
):
    """
    预翻译热门任务
    
    参数:
    - db: 数据库会话
    - limit: 预翻译的任务数量
    - target_languages: 目标语言列表（默认使用常用语言）
    - min_views: 最小浏览量（用于筛选热门任务）
    
    返回:
    - 预翻译的任务数量
    """
    from app import crud, models
    from app.translation_manager import get_translation_manager
    from app.utils.translation_async import translate_async
    from sqlalchemy import desc
    
    if target_languages is None:
        target_languages = COMMON_TARGET_LANGUAGES
    
    try:
        # 获取热门任务（根据浏览量、收藏数等指标）
        # 这里简化处理，可以根据实际需求调整排序逻辑
        popular_tasks = db.query(models.Task).filter(
            models.Task.status == 'open'
        ).order_by(
            desc(models.Task.created_at)  # 可以改为按浏览量、收藏数等排序
        ).limit(limit).all()
        
        if not popular_tasks:
            logger.info("没有找到热门任务")
            return 0
        
        translation_manager = get_translation_manager()
        prefetched_count = 0
        
        # 并发预翻译（限制并发数）
        semaphore = asyncio.Semaphore(5)  # 最多5个并发
        
        async def prefetch_task_translation(task, field_type, target_lang):
            async with semaphore:
                try:
                    # 检查是否已有翻译
                    existing = crud.get_task_translation(
                        db, task.id, field_type, target_lang, validate=False
                    )
                    if existing:
                        return False  # 已有翻译，跳过
                    
                    # 获取原始文本
                    original_text = getattr(task, field_type, None)
                    if not original_text:
                        return False
                    
                    # 执行翻译
                    translated_text = await translate_async(
                        translation_manager,
                        text=original_text,
                        target_lang=target_lang,
                        source_lang='auto',
                        max_retries=2
                    )
                    
                    if translated_text:
                        # 保存到数据库
                        crud.create_or_update_task_translation(
                            db,
                            task_id=task.id,
                            field_type=field_type,
                            original_text=original_text,
                            translated_text=translated_text,
                            source_language='auto',
                            target_language=target_lang
                        )
                        return True
                    
                    return False
                except Exception as e:
                    logger.error(f"预翻译失败: task_id={task.id}, field={field_type}, lang={target_lang}, error={e}")
                    return False
        
        # 为每个任务和每个语言创建预翻译任务
        tasks_to_prefetch = []
        for task in popular_tasks:
            for field_type in ['title', 'description']:
                for target_lang in target_languages:
                    tasks_to_prefetch.append(
                        prefetch_task_translation(task, field_type, target_lang)
                    )
        
        # 并发执行所有预翻译任务
        results = await asyncio.gather(*tasks_to_prefetch, return_exceptions=True)
        
        # 统计成功数量
        for result in results:
            if isinstance(result, bool) and result:
                prefetched_count += 1
        
        logger.info(f"预翻译完成: 处理了 {len(popular_tasks)} 个任务，成功预翻译 {prefetched_count} 条")
        return prefetched_count
        
    except Exception as e:
        logger.error(f"预翻译热门任务失败: {e}", exc_info=True)
        return 0


async def prefetch_task_by_id(
    db,
    task_id: int,
    target_languages: Optional[List[str]] = None
):
    """
    预翻译指定任务
    
    参数:
    - db: 数据库会话
    - task_id: 任务ID
    - target_languages: 目标语言列表
    
    返回:
    - 预翻译的数量
    """
    from app import crud, models
    from app.translation_manager import get_translation_manager
    from app.utils.translation_async import translate_async
    
    if target_languages is None:
        target_languages = COMMON_TARGET_LANGUAGES
    
    try:
        task = crud.get_task(db, task_id)
        if not task:
            logger.warning(f"任务不存在: {task_id}")
            return 0
        
        translation_manager = get_translation_manager()
        prefetched_count = 0
        
        for field_type in ['title', 'description']:
            original_text = getattr(task, field_type, None)
            if not original_text:
                continue
            
            for target_lang in target_languages:
                # 检查是否已有翻译
                existing = crud.get_task_translation(
                    db, task_id, field_type, target_lang, validate=False
                )
                if existing:
                    continue
                
                # 执行翻译
                translated_text = await translate_async(
                    translation_manager,
                    text=original_text,
                    target_lang=target_lang,
                    source_lang='auto',
                    max_retries=2
                )
                
                if translated_text:
                    # 保存到数据库
                    crud.create_or_update_task_translation(
                        db,
                        task_id=task_id,
                        field_type=field_type,
                        original_text=original_text,
                        translated_text=translated_text,
                        source_language='auto',
                        target_language=target_lang
                    )
                    prefetched_count += 1
        
        logger.info(f"预翻译任务完成: task_id={task_id}, 预翻译了 {prefetched_count} 条")
        return prefetched_count
        
    except Exception as e:
        logger.error(f"预翻译任务失败: {e}", exc_info=True)
        try:
            db.rollback()
        except Exception:
            pass
        return 0

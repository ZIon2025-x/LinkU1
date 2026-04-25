"""
Translation domain routes — extracted from app/routers.py (Task 6 of routers split).

Mounts at both /api and /api/users via main.py (same as the original main_router).
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.deps import get_db
from app.utils.translation_metrics import TranslationTimer
# Module-level helper still lives in app/routers.py — re-imported here so /translate/tasks/batch
# can dispatch the background fill (see Task 6 plan).
from app.routers import _translate_missing_tasks_async

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/translate")
async def translate_text(
    request: Request,
):
    """
    翻译文本（优化版：支持缓存、去重、文本预处理）

    参数:
    - text: 要翻译的文本
    - target_language: 目标语言代码 (如 'en', 'zh', 'zh-cn')
    - source_language: 源语言代码 (可选, 如果不提供则自动检测)

    返回:
    - translated_text: 翻译后的文本
    - source_language: 检测到的源语言
    """
    import hashlib
    import asyncio
    import time
    from app.redis_cache import redis_cache

    try:
        # 获取请求体
        body = await request.json()

        text = body.get('text', '').strip()
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')

        if not text:
            raise HTTPException(status_code=400, detail="缺少text参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")

        # 转换语言代码格式 (zh -> zh-CN, en -> en)
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'

        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translated_text": text,
                "source_language": source_lang,
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }

        # 长文本优化：如果文本超过5000字符，分段翻译（提高翻译质量和速度）
        MAX_TEXT_LENGTH = 5000
        if len(text) > MAX_TEXT_LENGTH:
            # 使用翻译管理器（支持多个服务自动降级）
            from app.translation_manager import get_translation_manager

            # 按段落分段（优先保留换行符和段落格式）
            import re
            # 先按双换行符（段落分隔）分段
            paragraphs = re.split(r'(\n\s*\n)', text)

            # 重新组合段落，保持段落分隔符
            segments = []
            segment_separators = []  # 记录每个分段之间的分隔符
            current_segment = ""

            for i in range(0, len(paragraphs), 2):
                paragraph = paragraphs[i] + (paragraphs[i+1] if i+1 < len(paragraphs) else "")
                if len(current_segment) + len(paragraph) > MAX_TEXT_LENGTH and current_segment:
                    segments.append(current_segment)
                    # 记录分段之间的分隔符（段落分隔符或空字符串）
                    segment_separators.append(paragraphs[i-1] if i > 0 and i-1 < len(paragraphs) else "")
                    current_segment = paragraph
                else:
                    current_segment += paragraph

            if current_segment:
                segments.append(current_segment)
                segment_separators.append("")  # 最后一段没有后续分隔符

            # 如果分段后仍然有超长段，按单换行符或句子分段
            final_segments = []
            final_separators = []
            for seg_idx, seg in enumerate(segments):
                if len(seg) > MAX_TEXT_LENGTH:
                    # 按单换行符分段
                    lines = re.split(r'(\n)', seg)
                    current_chunk = ""
                    for i in range(0, len(lines), 2):
                        line = lines[i] + (lines[i+1] if i+1 < len(lines) else "")
                        if len(current_chunk) + len(line) > MAX_TEXT_LENGTH and current_chunk:
                            final_segments.append(current_chunk)
                            final_separators.append(lines[i-1] if i > 0 and i-1 < len(lines) else "")
                            current_chunk = line
                        else:
                            current_chunk += line
                    if current_chunk:
                        final_segments.append(current_chunk)
                        final_separators.append("")
                else:
                    final_segments.append(seg)
                    final_separators.append(segment_separators[seg_idx] if seg_idx < len(segment_separators) else "")

            # 检查分段后的缓存
            segment_cache_key = f"translation_segments:{hashlib.md5(f'{text}|{source_lang}|{target_lang}'.encode('utf-8')).hexdigest()}"
            segment_separators_key = f"translation_separators:{hashlib.md5(f'{text}|{source_lang}|{target_lang}'.encode('utf-8')).hexdigest()}"
            if redis_cache and redis_cache.enabled:
                cached_segments = redis_cache.get(segment_cache_key)
                cached_separators = redis_cache.get(segment_separators_key)
                if cached_segments and isinstance(cached_segments, list) and len(cached_segments) == len(final_segments):
                    logger.debug(f"长文本分段翻译缓存命中: {len(final_segments)}段")
                    # 合并时保留分隔符
                    if cached_separators and isinstance(cached_separators, list) and len(cached_separators) == len(final_separators):
                        translated_text = ""
                        for i, seg in enumerate(cached_segments):
                            translated_text += seg
                            if i < len(cached_separators):
                                translated_text += cached_separators[i]
                    else:
                        # 兼容旧缓存格式（没有分隔符信息）
                        translated_text = "".join(cached_segments)
                    return {
                        "translated_text": translated_text,
                        "source_language": source_lang if source_lang != 'auto' else 'auto',
                        "target_language": target_lang,
                        "original_text": text,
                        "cached": True
                    }

            # 使用异步批量翻译（并发处理多个分段）
            from app.translation_manager import get_translation_manager
            from app.utils.translation_async import translate_batch_async
            translation_manager = get_translation_manager()

            translated_segments_list = await translate_batch_async(
                translation_manager,
                texts=final_segments,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=2,
                max_concurrent=3  # 限制并发数，避免触发限流
            )

            # 处理翻译结果（失败的使用原文），并保留分段分隔符
            translated_segments = []
            for i, translated_seg in enumerate(translated_segments_list):
                if translated_seg:
                    translated_segments.append(translated_seg)
                else:
                    logger.warning(f"分段 {i} 翻译失败，使用原文")
                    translated_segments.append(final_segments[i])

            # 合并翻译结果，保留原始的分段分隔符
            translated_text = ""
            for i, seg in enumerate(translated_segments):
                translated_text += seg
                # 添加分段之间的分隔符（保留换行符和段落格式）
                if i < len(final_separators):
                    translated_text += final_separators[i]

            # 缓存分段翻译结果和分隔符
            if redis_cache and redis_cache.enabled:
                try:
                    redis_cache.set(segment_cache_key, translated_segments, ttl=7 * 24 * 60 * 60)
                    redis_cache.set(segment_separators_key, final_separators, ttl=7 * 24 * 60 * 60)
                except Exception as e:
                    logger.warning(f"保存分段翻译缓存失败: {e}")

            return {
                "translated_text": translated_text,
                "source_language": source_lang if source_lang != 'auto' else 'auto',
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }

        # 生成缓存键（使用文本内容、源语言、目标语言）
        cache_key_data = f"{text}|{source_lang}|{target_lang}"
        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
        cache_key = f"translation:{cache_key_hash}"

        # 1. 先检查Redis缓存
        if redis_cache and redis_cache.enabled:
            cached_result = redis_cache.get(cache_key)
            if cached_result:
                logger.debug(f"翻译缓存命中: {text[:30]}...")
                return {
                    "translated_text": cached_result.get("translated_text"),
                    "source_language": cached_result.get("source_language", source_lang),
                    "target_language": target_lang,
                    "original_text": text,
                    "cached": True
                }

        # 2. 检查是否有正在进行的翻译请求（防止重复翻译）
        lock_key = f"translation_lock:{cache_key_hash}"
        if redis_cache and redis_cache.enabled:
            # 尝试获取锁（5秒过期，防止死锁）
            lock_acquired = False
            try:
                # 使用SET NX EX实现分布式锁
                lock_value = str(time.time())
                lock_acquired = redis_cache.redis_client.set(
                    lock_key,
                    lock_value.encode('utf-8'),
                    ex=5,  # 5秒过期
                    nx=True  # 只在不存在时设置
                )

                if not lock_acquired:
                    # 有其他请求正在翻译，等待并重试缓存
                    await asyncio.sleep(0.5)  # 等待500ms
                    cached_result = redis_cache.get(cache_key)
                    if cached_result:
                        logger.debug(f"翻译缓存命中（等待后）: {text[:30]}...")
                        return {
                            "translated_text": cached_result.get("translated_text"),
                            "source_language": cached_result.get("source_language", source_lang),
                            "target_language": target_lang,
                            "original_text": text,
                            "cached": True
                        }
            except Exception as e:
                logger.warning(f"获取翻译锁失败: {e}")

        try:
            # 3. 执行翻译（使用翻译管理器，支持多个服务自动降级）
            from app.translation_manager import get_translation_manager

            logger.debug(f"开始翻译: text={text[:50]}..., target={target_lang}, source={source_lang}")

            translation_manager = get_translation_manager()
            # 使用带换行保护的翻译（自动分段处理含换行的文本）
            from app.utils.bilingual_helper import _translate_with_encoding_protection
            translated_text = await _translate_with_encoding_protection(
                translation_manager,
                text=text,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=3
            )

            if translated_text is None:
                raise Exception("所有翻译服务都失败，无法翻译文本")

            logger.debug(f"翻译完成: {translated_text[:50]}...")

            # 检测源语言（如果未提供）
            detected_source = source_lang if source_lang != 'auto' else 'auto'

            result = {
                "translated_text": translated_text,
                "source_language": detected_source,
                "target_language": target_lang,
                "original_text": text,
                "cached": False
            }

            # 4. 保存到Redis缓存（7天过期）
            if redis_cache and redis_cache.enabled:
                try:
                    cache_data = {
                        "translated_text": translated_text,
                        "source_language": detected_source,
                        "target_language": target_lang
                    }
                    redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
                except Exception as e:
                    logger.warning(f"保存翻译缓存失败: {e}")

            return result

        finally:
            # 释放锁
            if lock_acquired and redis_cache and redis_cache.enabled:
                try:
                    redis_cache.redis_client.delete(lock_key)
                except Exception as e:
                    logger.warning(f"释放翻译锁失败: {e}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"翻译失败: {str(e)}")


@router.post("/translate/batch")
async def translate_batch(
    request: Request,
):
    """
    批量翻译文本（优化版：支持缓存、去重、复用translator实例）

    参数:
    - texts: 要翻译的文本列表
    - target_language: 目标语言代码
    - source_language: 源语言代码 (可选)

    返回:
    - translations: 翻译结果列表
    """
    import hashlib
    from app.redis_cache import redis_cache

    try:
        # 获取请求体
        body = await request.json()

        texts = body.get('texts', [])
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')

        if not texts:
            raise HTTPException(status_code=400, detail="缺少texts参数")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")

        # 限制单次批量翻译的最大文本数量，防止内存溢出
        MAX_BATCH_SIZE = 500
        if len(texts) > MAX_BATCH_SIZE:
            logger.warning(f"批量翻译文本数量过多 ({len(texts)})，限制为 {MAX_BATCH_SIZE} 个")
            texts = texts[:MAX_BATCH_SIZE]

        # 预处理：去除空白、去重
        processed_texts = []
        text_to_index = {}  # 用于去重，保留第一个出现的索引
        for i, text in enumerate(texts):
            cleaned_text = text.strip() if isinstance(text, str) else str(text).strip()
            if cleaned_text and cleaned_text not in text_to_index:
                text_to_index[cleaned_text] = len(processed_texts)
                processed_texts.append(cleaned_text)

        if not processed_texts:
            return {
                "translations": [{"original_text": t, "translated_text": t, "source_language": "auto"} for t in texts],
                "target_language": target_language
            }

        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'

        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translations": [{"original_text": t, "translated_text": t, "source_language": source_lang} for t in texts],
                "target_language": target_lang
            }

        # 使用翻译管理器（支持多个服务自动降级）
        from app.translation_manager import get_translation_manager
        translation_manager = get_translation_manager()

        # 批量处理：先检查缓存，再翻译未缓存的文本
        translations_map = {}  # 存储翻译结果
        texts_to_translate = []  # 需要翻译的文本列表
        text_indices = []  # 对应的索引

        for i, text in enumerate(processed_texts):
            # 生成缓存键
            cache_key_data = f"{text}|{source_lang}|{target_lang}"
            cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
            cache_key = f"translation:{cache_key_hash}"

            # 检查缓存
            cached_result = None
            if redis_cache and redis_cache.enabled:
                cached_result = redis_cache.get(cache_key)

            if cached_result:
                translations_map[text] = cached_result.get("translated_text")
            else:
                texts_to_translate.append(text)
                text_indices.append(i)

        # 批量翻译未缓存的文本（分批处理，每批最多50个，避免API限制）
        if texts_to_translate:
            logger.debug(f"批量翻译: {len(texts_to_translate)}个文本需要翻译")

            batch_size = 50  # 每批最多50个文本
            for batch_start in range(0, len(texts_to_translate), batch_size):
                batch_texts = texts_to_translate[batch_start:batch_start + batch_size]

                for text in batch_texts:
                    try:
                        # 生成缓存键
                        cache_key_data = f"{text}|{source_lang}|{target_lang}"
                        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
                        cache_key = f"translation:{cache_key_hash}"

                        # 使用翻译管理器执行翻译（自动降级）
                        translated_text = translation_manager.translate(
                            text=text,
                            target_lang=target_lang,
                            source_lang=source_lang,
                            max_retries=2  # 批量翻译时减少重试次数
                        )

                        if translated_text:
                            translations_map[text] = translated_text

                            # 保存到缓存
                            if redis_cache and redis_cache.enabled:
                                try:
                                    cache_data = {
                                        "translated_text": translated_text,
                                        "source_language": source_lang if source_lang != 'auto' else 'auto',
                                        "target_language": target_lang
                                    }
                                    redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
                                except Exception as e:
                                    logger.warning(f"保存翻译缓存失败: {e}")
                        else:
                            # 翻译失败时返回原文
                            logger.error(f"翻译文本失败: {text[:50]}...")
                            translations_map[text] = text

                        # 批量处理时添加小延迟，避免API限流
                        if len(batch_texts) > 10:
                            await asyncio.sleep(0.1)

                    except Exception as e:
                        logger.error(f"翻译文本失败: {text[:50]}... - {e}")
                        translations_map[text] = text  # 翻译失败时返回原文

        # 构建返回结果（保持原始顺序和重复）
        result_translations = []
        for original_text in texts:
            cleaned_text = original_text.strip() if isinstance(original_text, str) else str(original_text).strip()
            if cleaned_text in translations_map:
                translated = translations_map[cleaned_text]
            else:
                # 如果不在map中（可能是空文本），返回原文
                translated = original_text

            result_translations.append({
                "original_text": original_text,
                "translated_text": translated,
                "source_language": source_lang if source_lang != 'auto' else 'auto',
            })

        logger.debug(f"批量翻译完成: 总数={len(texts)}, 缓存命中={len(processed_texts) - len(texts_to_translate)}, 新翻译={len(texts_to_translate)}")

        return {
            "translations": result_translations,
            "target_language": target_lang
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"批量翻译失败: {str(e)}")


# 任务翻译API - 从任务表 zh/en 列读取（任务翻译表已停用）
@router.get("/translate/task/{task_id}")
def get_task_translation(
    task_id: int,
    field_type: str = Query(..., description="字段类型：title 或 description"),
    target_language: str = Query(..., description="目标语言代码"),
    db: Session = Depends(get_db),
):
    """
    获取任务翻译（从任务表 title_zh/title_en、description_zh/description_en 读取）
    """
    try:
        from app import crud

        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")

        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="任务不存在")

        # 映射到任务表列：en -> *_en, zh-CN/zh -> *_zh
        is_zh = target_language and (target_language == 'zh-CN' or target_language.lower() == 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        translated_text = getattr(task, col, None)

        if translated_text:
            return {
                "translated_text": translated_text,
                "exists": True,
                "source_language": "auto",
                "target_language": target_language or (is_zh and "zh-CN" or "en"),
            }
        return {"translated_text": None, "exists": False}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取任务翻译失败: {str(e)}")


@router.post("/translate/task/{task_id}")
async def translate_and_save_task(
    task_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    翻译任务内容并保存到数据库（供所有用户共享使用）

    参数:
    - task_id: 任务ID
    - field_type: 字段类型（title 或 description）
    - target_language: 目标语言代码
    - source_language: 源语言代码（可选）

    返回:
    - translated_text: 翻译后的文本
    - saved: 是否保存到数据库
    """
    import hashlib
    import asyncio
    import time
    from app import crud
    from app.redis_cache import redis_cache

    try:
        # 获取请求体
        body = await request.json()

        field_type = body.get('field_type')
        target_language = body.get('target_language', 'en')
        source_language = body.get('source_language')

        if not field_type:
            raise HTTPException(status_code=400, detail="缺少field_type参数")
        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")

        # 检查任务是否存在
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="任务不存在")

        # 获取原始文本
        if field_type == 'title':
            original_text = task.title
        else:
            original_text = task.description

        if not original_text:
            raise HTTPException(status_code=400, detail=f"任务的{field_type}为空")

        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)
        source_lang = lang_map.get(source_language.lower(), source_language) if source_language else 'auto'

        # 如果源语言和目标语言相同，直接返回原文
        if source_lang != 'auto' and source_lang == target_lang:
            return {
                "translated_text": original_text,
                "saved": False,
                "source_language": source_lang,
                "target_language": target_lang
            }

        # 1. 先检查任务翻译专用缓存（优先级最高）
        from app.utils.task_translation_cache import (
            get_cached_task_translation,
            cache_task_translation
        )

        cached_translation = get_cached_task_translation(task_id, field_type, target_lang)
        if cached_translation:
            logger.debug(f"任务翻译缓存命中: task_id={task_id}, field={field_type}, lang={target_lang}")
            return {
                "translated_text": cached_translation.get("translated_text"),
                "saved": True,
                "source_language": cached_translation.get("source_language", source_lang),
                "target_language": cached_translation.get("target_language", target_lang),
                "from_cache": True
            }

        # 2. 检查任务表列是否已有翻译（任务翻译表已停用）
        is_zh = target_lang in ('zh-CN', 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        existing_text = getattr(task, col, None)
        if existing_text:
            logger.debug(f"任务翻译列命中: task_id={task_id}, field={field_type}, lang={target_lang}")
            cache_task_translation(task_id, field_type, target_lang, existing_text, "auto")
            return {
                "translated_text": existing_text,
                "saved": True,
                "source_language": "auto",
                "target_language": target_lang,
                "from_cache": False,
            }

        # 3. 检查通用翻译缓存（基于文本内容）
        cache_key_data = f"{original_text}|{source_lang}|{target_lang}"
        cache_key_hash = hashlib.md5(cache_key_data.encode('utf-8')).hexdigest()
        cache_key = f"translation:{cache_key_hash}"

        cached_result = None
        if redis_cache and redis_cache.enabled:
            cached_result = redis_cache.get(cache_key)

        if cached_result:
            translated_text = cached_result.get("translated_text")
            setattr(task, col, translated_text)
            db.commit()
            # 缓存到任务翻译专用缓存
            cache_task_translation(
                task_id, field_type, target_lang,
                translated_text,
                cached_result.get("source_language", source_lang)
            )
            logger.debug(f"任务翻译保存到数据库: task_id={task_id}, field={field_type}")
            return {
                "translated_text": translated_text,
                "saved": True,
                "source_language": cached_result.get("source_language", source_lang),
                "target_language": target_lang,
                "from_cache": True
            }

        # 3. 执行翻译（使用翻译管理器，支持多个服务自动降级）
        from app.translation_manager import get_translation_manager

        logger.debug(f"开始翻译任务内容: task_id={task_id}, field={field_type}, target={target_lang}")

        translation_manager = get_translation_manager()
        with TranslationTimer('task_translation', source_lang, target_lang, cached=False):
            # 使用异步翻译（在线程池中执行，不阻塞事件循环）
            from app.utils.translation_async import translate_async
            translated_text = await translate_async(
                translation_manager,
                text=original_text,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=3
            )

        if translated_text is None:
            raise Exception("所有翻译服务都失败，无法翻译文本")

        logger.debug(f"翻译完成: {translated_text[:50]}...")

        detected_source = source_lang if source_lang != 'auto' else 'auto'
        setattr(task, col, translated_text)
        db.commit()
        logger.debug(f"任务翻译已写入任务表列: task_id={task_id}, field={field_type}")

        # 5. 保存到缓存（任务翻译专用缓存 + 通用翻译缓存）
        # 5.1 任务翻译专用缓存
        cache_task_translation(
            task_id, field_type, target_lang,
            translated_text, detected_source
        )

        # 5.2 通用翻译缓存（基于文本内容）
        if redis_cache and redis_cache.enabled:
            try:
                cache_data = {
                    "translated_text": translated_text,
                    "source_language": detected_source,
                    "target_language": target_lang
                }
                redis_cache.set(cache_key, cache_data, ttl=7 * 24 * 60 * 60)  # 7天
            except Exception as e:
                logger.warning(f"保存通用翻译缓存失败: {e}")

        return {
            "translated_text": translated_text,
            "saved": True,
            "source_language": detected_source,
            "target_language": target_lang,
            "from_cache": False
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"翻译并保存任务失败: {e}")
        raise HTTPException(status_code=500, detail=f"翻译并保存任务失败: {str(e)}")


# 批量获取任务翻译API
@router.post("/translate/tasks/batch")
async def get_task_translations_batch(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    批量获取任务翻译（用于优化任务列表加载）

    参数:
    - task_ids: 任务ID列表
    - field_type: 字段类型（title 或 description）
    - target_language: 目标语言代码

    返回:
    - translations: 翻译结果字典 {task_id: translated_text}
    """
    try:
        from app import crud

        body = await request.json()
        task_ids = body.get('task_ids', [])
        field_type = body.get('field_type')
        target_language = body.get('target_language', 'en')

        if not task_ids:
            return {"translations": {}}

        if not field_type:
            raise HTTPException(status_code=400, detail="缺少field_type参数")
        if field_type not in ['title', 'description']:
            raise HTTPException(status_code=400, detail="field_type必须是'title'或'description'")
        if not target_language:
            raise HTTPException(status_code=400, detail="缺少target_language参数")

        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang = lang_map.get(target_language.lower(), target_language)

        # 1. 先检查批量查询缓存
        from app.utils.task_translation_cache import (
            get_cached_batch_translations,
            cache_batch_translations
        )

        cached_batch = get_cached_batch_translations(task_ids, field_type, target_lang)
        if cached_batch:
            logger.debug(f"批量翻译查询缓存命中: {len(cached_batch)} 条")
            return {
                "translations": cached_batch,
                "target_language": target_lang,
                "from_cache": True
            }

        # 2. 从任务表列批量读取（任务翻译表已停用）
        MAX_BATCH_SIZE = 1000
        if len(task_ids) > MAX_BATCH_SIZE:
            logger.warning(f"批量查询任务翻译数量过大: {len(task_ids)}，限制为{MAX_BATCH_SIZE}")
            task_ids = task_ids[:MAX_BATCH_SIZE]

        from app.models import Task
        is_zh = target_lang in ('zh-CN', 'zh')
        col = (field_type + '_zh') if is_zh else (field_type + '_en')
        tasks_batch = db.query(Task).filter(Task.id.in_(task_ids), Task.is_visible == True).all()
        task_map = {t.id: t for t in tasks_batch}

        result = {}
        missing_task_ids = []
        for task_id in task_ids:
            task = task_map.get(task_id)
            text = getattr(task, col, None) if task else None
            if text:
                result[task_id] = {
                    "translated_text": text,
                    "source_language": "auto",
                    "target_language": target_lang,
                }
            else:
                missing_task_ids.append(task_id)

        # 4. 如果有缺少翻译的任务，尝试异步翻译（不阻塞，后台处理）
        if missing_task_ids:
            logger.debug(f"发现 {len(missing_task_ids)} 个任务缺少翻译，将在后台处理")
            # 在后台异步翻译缺少的任务（不等待结果）
            try:
                asyncio.create_task(
                    _translate_missing_tasks_async(
                        db, missing_task_ids, field_type, target_lang
                    )
                )
            except Exception as e:
                logger.warning(f"启动后台翻译任务失败: {e}")

        # 5. 缓存批量查询结果（只缓存已有的翻译）
        if result:
            cache_batch_translations(task_ids, field_type, target_lang, result)

        logger.debug(f"批量获取任务翻译: 请求{len(task_ids)}个，返回{len(result)}个，缺少{len(missing_task_ids)}个")

        return {
            "translations": result,
            "target_language": target_lang,
            "from_cache": False,
            "missing_count": len(missing_task_ids),  # 返回缺少翻译的数量
            "partial": len(missing_task_ids) > 0  # 是否部分成功
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量获取任务翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"批量获取任务翻译失败: {str(e)}")


# 翻译性能指标API
@router.get("/translate/metrics")
def get_translation_metrics():
    """
    获取翻译性能指标

    返回:
    - metrics: 性能指标摘要
    - cache_stats: 缓存统计信息
    """
    try:
        from app.utils.translation_metrics import get_metrics_summary
        from app.utils.cache_eviction import get_cache_stats

        metrics = get_metrics_summary()
        cache_stats = get_cache_stats()

        return {
            "metrics": metrics,
            "cache_stats": cache_stats,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"获取翻译性能指标失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译性能指标失败: {str(e)}")


# 翻译服务状态API
@router.get("/translate/services/status")
def get_translation_services_status():
    """
    获取翻译服务状态

    返回:
    - available_services: 可用服务列表
    - failed_services: 失败服务列表
    - stats: 服务统计信息
    """
    try:
        from app.translation_manager import get_translation_manager

        manager = get_translation_manager()
        available = manager.get_available_services()
        all_services = manager.get_all_services()
        stats = manager.get_service_stats()
        failed = [s.value for s in manager.failed_services]

        # 构建统计信息
        stats_result = {}
        for service_name in all_services:
            # 找到对应的服务枚举
            service_enum = None
            for s, _ in manager.services:
                if s.value == service_name:
                    service_enum = s
                    break

            if service_enum:
                stats_result[service_name] = {
                    "success": stats.get(service_enum, {}).get('success', 0),
                    "failure": stats.get(service_enum, {}).get('failure', 0),
                    "is_available": service_name in available
                }

        return {
            "available_services": available,
            "failed_services": failed,
            "all_services": all_services,
            "stats": stats_result
        }
    except Exception as e:
        logger.error(f"获取翻译服务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译服务状态失败: {str(e)}")


# 重置翻译服务状态API
@router.post("/translate/services/reset")
def reset_translation_services(
    service_name: Optional[str] = Query(None, description="要重置的服务名称，如果为空则重置所有")
):
    """
    重置翻译服务失败记录

    参数:
    - service_name: 要重置的服务名称（可选），如果为空则重置所有

    返回:
    - success: 是否成功
    - message: 消息
    """
    try:
        from app.translation_manager import get_translation_manager, TranslationService

        manager = get_translation_manager()

        if service_name:
            # 重置指定服务
            try:
                service = TranslationService(service_name.lower())
                manager.reset_failed_service(service)
                return {
                    "success": True,
                    "message": f"翻译服务 {service_name} 的失败记录已重置"
                }
            except ValueError:
                raise HTTPException(status_code=400, detail=f"无效的服务名称: {service_name}")
        else:
            # 重置所有服务
            manager.reset_failed_services()
            return {
                "success": True,
                "message": "所有翻译服务失败记录已重置"
            }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"重置翻译服务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"重置翻译服务状态失败: {str(e)}")


# 获取失败服务信息API
@router.get("/translate/services/failed")
def get_failed_services_info():
    """
    获取失败服务的详细信息

    返回:
    - failed_services: 失败服务信息
    """
    try:
        from app.translation_manager import get_translation_manager

        manager = get_translation_manager()
        failed_info = manager.get_failed_services_info()

        return {
            "failed_services": failed_info,
            "count": len(failed_info)
        }
    except Exception as e:
        logger.error(f"获取失败服务信息失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败服务信息失败: {str(e)}")


# 翻译告警API
@router.get("/translate/alerts")
def get_translation_alerts(
    service_name: Optional[str] = Query(None, description="服务名称过滤"),
    severity: Optional[str] = Query(None, description="严重程度过滤（info/warning/error/critical）"),
    limit: int = Query(50, ge=1, le=200, description="返回数量限制")
):
    """
    获取翻译服务告警信息

    返回:
    - alerts: 告警列表
    - stats: 告警统计
    """
    try:
        from app.utils.translation_alert import get_recent_alerts, get_alert_stats

        alerts = get_recent_alerts(
            service_name=service_name,
            severity=severity,
            limit=limit
        )
        stats = get_alert_stats()

        return {
            "alerts": alerts,
            "stats": stats,
            "count": len(alerts)
        }
    except Exception as e:
        logger.error(f"获取翻译告警失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取翻译告警失败: {str(e)}")


# 预翻译API
@router.post("/translate/prefetch")
async def prefetch_translations(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    预翻译热门任务或指定任务

    参数:
    - task_ids: 任务ID列表（可选，如果提供则翻译指定任务，否则翻译热门任务）
    - target_languages: 目标语言列表（可选，默认使用常用语言）
    - limit: 预翻译的任务数量（仅当task_ids为空时有效）

    返回:
    - prefetched_count: 预翻译的数量
    """
    try:
        from app.utils.translation_prefetch import (
            prefetch_popular_tasks,
            prefetch_task_by_id
        )

        body = await request.json()
        task_ids = body.get('task_ids', [])
        target_languages = body.get('target_languages')
        limit = body.get('limit', 50)

        if task_ids:
            # 翻译指定任务
            total_count = 0
            for task_id in task_ids[:100]:  # 限制最多100个任务
                count = await prefetch_task_by_id(
                    db, task_id, target_languages
                )
                total_count += count

            return {
                "prefetched_count": total_count,
                "task_count": len(task_ids)
            }
        else:
            # 翻译热门任务
            count = await prefetch_popular_tasks(
                db, limit=limit, target_languages=target_languages
            )

            return {
                "prefetched_count": count,
                "limit": limit
            }
    except Exception as e:
        logger.error(f"预翻译失败: {e}")
        raise HTTPException(status_code=500, detail=f"预翻译失败: {str(e)}")


# 智能缓存预热API
@router.post("/translate/warmup")
async def warmup_translations(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    智能缓存预热（根据用户偏好和任务类型）

    参数:
    - task_ids: 任务ID列表（可选）
    - user_language: 用户语言偏好（可选）
    - task_type: 任务类型（可选）
    - limit: 预热的任务数量（默认50）

    返回:
    - stats: 预热统计信息
    """
    try:
        from app.utils.translation_cache_warmup import (
            warmup_hot_tasks,
            warmup_by_user_preference,
            warmup_task_translations
        )

        body = await request.json()
        task_ids = body.get('task_ids', [])
        user_language = body.get('user_language')
        task_type = body.get('task_type')
        limit = body.get('limit', 50)

        if task_ids:
            # 预热指定任务
            stats = warmup_task_translations(
                db,
                task_ids=task_ids,
                languages=[user_language] if user_language else None
            )
        elif user_language:
            # 根据用户偏好预热
            stats = warmup_by_user_preference(
                db,
                user_language=user_language,
                limit=limit
            )
        else:
            # 预热热门任务
            stats = warmup_hot_tasks(
                db,
                limit=limit,
                user_language=user_language,
                task_type=task_type
            )

        return {
            "stats": stats,
            "success": True
        }
    except Exception as e:
        logger.error(f"缓存预热失败: {e}")
        raise HTTPException(status_code=500, detail=f"缓存预热失败: {str(e)}")

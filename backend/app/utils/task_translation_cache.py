"""
任务翻译缓存工具
优化任务翻译的Redis缓存策略
"""
import hashlib
import logging
from typing import Optional, Dict, List
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)

# 任务翻译缓存键前缀
TASK_TRANSLATION_CACHE_PREFIX = "task_translation"
# 批量查询缓存键前缀
BATCH_TRANSLATION_CACHE_PREFIX = "task_translations_batch"

# 缓存TTL配置（秒）
CACHE_TTL = {
    'task_translation': 7 * 24 * 60 * 60,  # 7天（任务翻译）
    'batch_query': 60 * 60,  # 1小时（批量查询结果）
    'hot_task': 30 * 24 * 60 * 60,  # 30天（热门任务）
}


def get_task_translation_cache_key(task_id: int, field_type: str, target_lang: str) -> str:
    """生成任务翻译缓存键"""
    return f"{TASK_TRANSLATION_CACHE_PREFIX}:{task_id}:{field_type}:{target_lang}"


def get_batch_translation_cache_key(task_ids: List[int], field_type: str, target_lang: str) -> str:
    """生成批量翻译查询缓存键"""
    # 对task_ids排序并生成哈希，确保相同查询使用相同键
    sorted_ids = sorted(task_ids)
    ids_str = ','.join(map(str, sorted_ids))
    ids_hash = hashlib.md5(ids_str.encode('utf-8')).hexdigest()[:16]
    return f"{BATCH_TRANSLATION_CACHE_PREFIX}:{field_type}:{target_lang}:{ids_hash}"


def cache_task_translation(
    task_id: int,
    field_type: str,
    target_lang: str,
    translated_text: str,
    source_lang: str = 'auto',
    ttl: Optional[int] = None
) -> bool:
    """
    缓存任务翻译（带LRU跟踪）
    
    参数:
    - task_id: 任务ID
    - field_type: 字段类型（title/description）
    - target_lang: 目标语言
    - translated_text: 翻译后的文本
    - source_lang: 源语言
    - ttl: 缓存过期时间（秒），如果为None则使用默认值
    """
    if not redis_cache or not redis_cache.enabled:
        return False
    
    try:
        cache_key = get_task_translation_cache_key(task_id, field_type, target_lang)
        cache_data = {
            "translated_text": translated_text,
            "source_language": source_lang,
            "target_language": target_lang
        }
        
        ttl = ttl or CACHE_TTL['task_translation']
        redis_cache.set(cache_key, cache_data, ttl=ttl)
        
        # 跟踪缓存访问（用于LRU淘汰）
        try:
            from app.utils.cache_eviction import track_cache_access
            track_cache_access('task_translation', cache_key)
        except Exception:
            pass  # LRU跟踪失败不影响缓存功能
        
        return True
    except Exception as e:
        logger.warning(f"缓存任务翻译失败: {e}")
        return False


def get_cached_task_translation(
    task_id: int,
    field_type: str,
    target_lang: str
) -> Optional[Dict]:
    """
    从缓存获取任务翻译（带LRU跟踪）
    
    返回:
    - 如果找到，返回包含翻译信息的字典
    - 如果未找到，返回None
    """
    if not redis_cache or not redis_cache.enabled:
        return None
    
    try:
        cache_key = get_task_translation_cache_key(task_id, field_type, target_lang)
        cached_data = redis_cache.get(cache_key)
        
        # 跟踪缓存访问（用于LRU淘汰）
        if cached_data:
            try:
                from app.utils.cache_eviction import track_cache_access
                track_cache_access('task_translation', cache_key)
            except Exception:
                pass  # LRU跟踪失败不影响缓存功能
        
        return cached_data
    except Exception as e:
        logger.warning(f"获取任务翻译缓存失败: {e}")
        return None


def invalidate_task_translation_cache(
    task_id: int,
    field_type: Optional[str] = None
) -> int:
    """
    清除任务翻译缓存
    
    参数:
    - task_id: 任务ID
    - field_type: 字段类型，如果为None则清除所有字段的缓存
    
    返回:
    - 清除的缓存数量
    """
    if not redis_cache or not redis_cache.enabled:
        return 0
    
    try:
        deleted_count = 0
        
        if field_type:
            # 清除特定字段的缓存（所有语言）
            for lang in ['en', 'zh-CN', 'zh-TW']:
                cache_key = get_task_translation_cache_key(task_id, field_type, lang)
                if redis_cache.delete(cache_key):
                    deleted_count += 1
        else:
            # 清除所有字段的缓存（所有语言）
            for field in ['title', 'description']:
                for lang in ['en', 'zh-CN', 'zh-TW']:
                    cache_key = get_task_translation_cache_key(task_id, field, lang)
                    if redis_cache.delete(cache_key):
                        deleted_count += 1
        
        # 清除批量查询缓存（使用模式匹配）
        # 注意：keys() 操作在生产环境中可能影响性能，建议使用更精确的缓存键
        # 这里暂时跳过批量缓存的清除，因为批量查询缓存TTL较短（1小时），会自动过期
        # 如果需要精确清除，可以维护一个任务ID到批量缓存键的映射
        
        if deleted_count > 0:
            logger.debug(f"已清除任务 {task_id} 的翻译缓存: {deleted_count} 条")
        
        return deleted_count
    except Exception as e:
        logger.warning(f"清除任务翻译缓存失败: {e}")
        return 0


def cache_batch_translations(
    task_ids: List[int],
    field_type: str,
    target_lang: str,
    translations: Dict[int, Dict],
    ttl: Optional[int] = None
) -> bool:
    """
    缓存批量翻译查询结果
    
    参数:
    - task_ids: 任务ID列表
    - field_type: 字段类型
    - target_lang: 目标语言
    - translations: 翻译结果字典 {task_id: {translated_text, ...}}
    - ttl: 缓存过期时间（秒）
    """
    if not redis_cache or not redis_cache.enabled:
        return False
    
    try:
        cache_key = get_batch_translation_cache_key(task_ids, field_type, target_lang)
        cache_data = {
            "translations": translations,
            "task_ids": task_ids,
            "field_type": field_type,
            "target_language": target_lang
        }
        
        ttl = ttl or CACHE_TTL['batch_query']
        redis_cache.set(cache_key, cache_data, ttl=ttl)
        return True
    except Exception as e:
        logger.warning(f"缓存批量翻译查询失败: {e}")
        return False


def get_cached_batch_translations(
    task_ids: List[int],
    field_type: str,
    target_lang: str
) -> Optional[Dict]:
    """
    从缓存获取批量翻译查询结果
    
    返回:
    - 如果找到，返回包含翻译信息的字典
    - 如果未找到，返回None
    """
    if not redis_cache or not redis_cache.enabled:
        return None
    
    try:
        cache_key = get_batch_translation_cache_key(task_ids, field_type, target_lang)
        cached_data = redis_cache.get(cache_key)
        
        if cached_data:
            # 验证缓存的task_ids是否匹配（防止部分匹配问题）
            cached_task_ids = cached_data.get('task_ids', [])
            if set(cached_task_ids) == set(task_ids):
                return cached_data.get('translations', {})
        
        return None
    except Exception as e:
        logger.warning(f"获取批量翻译缓存失败: {e}")
        return None

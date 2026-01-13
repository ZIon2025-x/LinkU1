"""
翻译内容验证工具
用于检测翻译是否过期（原始内容是否已更改）
"""
import hashlib
import logging

logger = logging.getLogger(__name__)


def calculate_content_hash(text: str) -> str:
    """
    计算文本内容的哈希值
    
    参数:
    - text: 要计算哈希的文本
    
    返回:
    - 64字符的SHA256哈希值
    """
    if not text:
        return ""
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def is_translation_valid(translation, current_text: str) -> bool:
    """
    检查翻译是否仍然有效（原始内容是否未更改）
    
    参数:
    - translation: TaskTranslation对象或包含original_text和content_hash的字典
    - current_text: 当前任务的文本内容
    
    返回:
    - True: 翻译仍然有效
    - False: 翻译已过期
    """
    if not translation:
        return False
    
    # 如果翻译对象有content_hash字段，使用哈希比较（更快）
    if hasattr(translation, 'content_hash') and translation.content_hash:
        current_hash = calculate_content_hash(current_text)
        return translation.content_hash == current_hash
    
    # 否则，比较原始文本（向后兼容）
    if hasattr(translation, 'original_text'):
        return translation.original_text == current_text
    
    # 如果是字典
    if isinstance(translation, dict):
        if 'content_hash' in translation and translation['content_hash']:
            current_hash = calculate_content_hash(current_text)
            return translation['content_hash'] == current_hash
        if 'original_text' in translation:
            return translation['original_text'] == current_text
    
    return False


def invalidate_task_translations(db, task_id: int, field_type: str = None):
    """
    使任务翻译失效（删除或标记为过期）
    
    参数:
    - db: 数据库会话
    - task_id: 任务ID
    - field_type: 字段类型（'title'或'description'），如果为None则清理所有字段
    """
    from app import models
    
    try:
        query = db.query(models.TaskTranslation).filter(
            models.TaskTranslation.task_id == task_id
        )
        
        if field_type:
            query = query.filter(models.TaskTranslation.field_type == field_type)
        
        # 删除过时的翻译（简单直接的方式）
        count = query.delete(synchronize_session=False)
        db.commit()
        
        if count > 0:
            logger.info(f"已清理任务 {task_id} 的过期翻译: {count} 条")
        
        return count
    except Exception as e:
        logger.error(f"清理任务翻译失败: {e}")
        db.rollback()
        return 0

"""任务翻译相关 CRUD，独立模块便于维护与测试。"""
import logging
from typing import Optional

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models
from app.crud.task import get_task
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def get_task_translation(
    db: Session,
    task_id: int,
    field_type: str,
    target_language: str,
    validate: bool = True
) -> Optional[models.TaskTranslation]:
    """
    获取任务翻译
    
    参数:
    - validate: 是否验证翻译是否过期（需要传入task对象或current_text）
    """
    translation = db.query(models.TaskTranslation).filter(
        models.TaskTranslation.task_id == task_id,
        models.TaskTranslation.field_type == field_type,
        models.TaskTranslation.target_language == target_language
    ).first()
    
    # 如果启用验证且翻译存在，检查是否过期
    if validate and translation:
        # 获取当前任务内容
        task = get_task(db, task_id)
        if task:
            current_text = getattr(task, field_type, None)
            if current_text:
                from app.utils.translation_validator import is_translation_valid
                if not is_translation_valid(translation, current_text):
                    # 翻译已过期，返回None（让调用者重新翻译）
                    logger.debug(f"任务 {task_id} 的 {field_type} 翻译已过期，需要重新翻译")
                    return None
    
    return translation


def create_or_update_task_translation(
    db: Session,
    task_id: int,
    field_type: str,
    original_text: str,
    translated_text: str,
    source_language: str,
    target_language: str
) -> models.TaskTranslation:
    """创建或更新任务翻译"""
    from app.utils.translation_validator import calculate_content_hash
    
    # 先查找是否已存在
    existing = get_task_translation(db, task_id, field_type, target_language)
    
    # 计算内容哈希
    content_hash = calculate_content_hash(original_text)
    
    if existing:
        # 更新现有翻译
        existing.original_text = original_text
        existing.translated_text = translated_text
        existing.source_language = source_language
        # 如果表中有content_hash字段，更新它
        if hasattr(existing, 'content_hash'):
            existing.content_hash = content_hash
        existing.updated_at = get_utc_time()
        db.commit()
        db.refresh(existing)
        return existing
    else:
        # 创建新翻译（并发时可能发生唯一约束冲突，捕获后改为更新）
        translation_data = {
            'task_id': task_id,
            'field_type': field_type,
            'original_text': original_text,
            'translated_text': translated_text,
            'source_language': source_language,
            'target_language': target_language
        }
        # 如果表中有content_hash字段，添加它
        if hasattr(models.TaskTranslation, 'content_hash'):
            translation_data['content_hash'] = content_hash

        try:
            new_translation = models.TaskTranslation(**translation_data)
            db.add(new_translation)
            db.commit()
            db.refresh(new_translation)
            return new_translation
        except IntegrityError as e:
            db.rollback()
            # PostgreSQL 23505 = unique_violation；并发插入冲突时改为查询并更新
            if getattr(getattr(e, "orig", None), "pgcode", None) == "23505":
                existing = get_task_translation(db, task_id, field_type, target_language)
                if existing:
                    existing.original_text = original_text
                    existing.translated_text = translated_text
                    existing.source_language = source_language
                    if hasattr(existing, 'content_hash'):
                        existing.content_hash = content_hash
                    existing.updated_at = get_utc_time()
                    db.commit()
                    db.refresh(existing)
                    return existing
            raise


def cleanup_stale_task_translations(db: Session, batch_size: int = 100) -> int:
    """
    清理过期的任务翻译（通过content_hash验证）
    
    优化：批量加载任务文本字段，避免 N+1 查询（每批 1 次 tasks 查询替代每条约 7 次）
    
    参数:
    - db: 数据库会话
    - batch_size: 每批处理的翻译数量（避免一次性处理太多）
    
    返回:
    - 清理的翻译数量
    """
    from sqlalchemy.orm import load_only

    from app.utils.translation_validator import is_translation_valid

    try:
        total_cleaned = 0
        offset = 0

        while True:
            translations = db.query(models.TaskTranslation).offset(offset).limit(batch_size).all()

            if not translations:
                break

            # 批量加载本批翻译涉及的任务（仅加载文本字段，避免加载 poster/taker/participants 等）
            task_ids = list({t.task_id for t in translations})
            tasks = (
                db.query(models.Task)
                .options(
                    load_only(
                        models.Task.id,
                        models.Task.title,
                        models.Task.title_zh,
                        models.Task.title_en,
                        models.Task.description,
                        models.Task.description_zh,
                        models.Task.description_en,
                    )
                )
                .filter(models.Task.id.in_(task_ids))
                .all()
            )
            task_map = {t.id: t for t in tasks}

            stale_translations = []
            for translation in translations:
                task = task_map.get(translation.task_id)
                if not task:
                    # 任务已删除，翻译也应删除
                    stale_translations.append(translation.id)
                    continue

                current_text = getattr(task, translation.field_type, None)
                if not current_text:
                    stale_translations.append(translation.id)
                    continue

                if not is_translation_valid(translation, current_text):
                    stale_translations.append(translation.id)

            if stale_translations:
                deleted_count = db.query(models.TaskTranslation).filter(
                    models.TaskTranslation.id.in_(stale_translations)
                ).delete(synchronize_session=False)
                total_cleaned += deleted_count
                logger.debug(f"清理了 {deleted_count} 条过期翻译")

            if len(translations) < batch_size:
                break

            offset += batch_size

        if total_cleaned > 0:
            db.commit()
            logger.info(f"清理过期翻译完成，共清理 {total_cleaned} 条")
        else:
            logger.debug("未发现需要清理的过期翻译")

        return total_cleaned

    except Exception as e:
        logger.error(f"清理过期翻译失败: {e}", exc_info=True)
        db.rollback()
        return 0


def get_task_translations_batch(
    db: Session,
    task_ids: list[int],
    field_type: str,
    target_language: str
) -> dict[int, models.TaskTranslation]:
    """批量获取任务翻译（优化版：分批查询避免IN子句过大）
    
    返回:
    - dict: {task_id: TaskTranslation} 的字典，只包含存在翻译的任务
    """
    if not task_ids:
        return {}
    
    # 去重并排序
    unique_task_ids = sorted(list(set(task_ids)))
    
    # 如果任务ID数量很大，分批查询（避免IN子句过大导致性能问题）
    # PostgreSQL的IN子句建议不超过1000个值
    BATCH_SIZE = 500
    result = {}
    
    # 优化：只查询需要的字段，减少数据传输
    # 只查询 task_id, translated_text, source_language, target_language
    # 不查询 original_text（减少数据传输，原始文本可以从tasks表获取）
    
    if len(unique_task_ids) <= BATCH_SIZE:
        # 小批量，直接查询
        query = select(
            models.TaskTranslation.task_id,
            models.TaskTranslation.translated_text,
            models.TaskTranslation.source_language,
            models.TaskTranslation.target_language
        ).where(
            models.TaskTranslation.task_id.in_(unique_task_ids),
            models.TaskTranslation.field_type == field_type,
            models.TaskTranslation.target_language == target_language
        )
        
        rows = db.execute(query).all()
        
        # 转换为字典格式
        for row in rows:
            # 创建简化对象
            class SimpleTranslation:
                def __init__(self, task_id, translated_text, source_language, target_language):
                    self.task_id = task_id
                    self.translated_text = translated_text
                    self.source_language = source_language
                    self.target_language = target_language
            
            result[row.task_id] = SimpleTranslation(
                row.task_id,
                row.translated_text,
                row.source_language,
                row.target_language
            )
    else:
        # 大批量，分批查询
        for i in range(0, len(unique_task_ids), BATCH_SIZE):
            batch_ids = unique_task_ids[i:i + BATCH_SIZE]
            query = select(
                models.TaskTranslation.task_id,
                models.TaskTranslation.translated_text,
                models.TaskTranslation.source_language,
                models.TaskTranslation.target_language
            ).where(
                models.TaskTranslation.task_id.in_(batch_ids),
                models.TaskTranslation.field_type == field_type,
                models.TaskTranslation.target_language == target_language
            )
            
            rows = db.execute(query).all()
            
            # 转换为字典格式
            for row in rows:
                class SimpleTranslation:
                    def __init__(self, task_id, translated_text, source_language, target_language):
                        self.task_id = task_id
                        self.translated_text = translated_text
                        self.source_language = source_language
                        self.target_language = target_language
                
                result[row.task_id] = SimpleTranslation(
                    row.task_id,
                    row.translated_text,
                    row.source_language,
                    row.target_language
                )
    
    return result

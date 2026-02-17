"""
任务与活动的双语展示：从主表 zh/en 列读取，缺失时翻译并写入对应列后返回。
任务翻译表（task_translations）已停用，不再读写。
"""
import logging
from typing import Optional, Tuple, List

from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.translation_manager import get_translation_manager
from app.utils.translation_async import translate_async

logger = logging.getLogger(__name__)

# 展示用语言 'zh'/'en' 与翻译 API 的 target_language 映射
def _api_target_lang(lang: str) -> str:
    return "zh-CN" if lang == "zh" else "en"


async def ensure_task_title_for_lang(db: AsyncSession, task: models.Task, lang: str) -> str:
    """返回任务标题在 lang 下的展示文案；若对应列为空则翻译 title 并写入该列后返回。"""
    if lang == "zh":
        if getattr(task, "title_zh", None):
            return task.title_zh
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=task.title or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            task.title_zh = text
        return text or task.title or ""
    else:
        if getattr(task, "title_en", None):
            return task.title_en
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=task.title or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            task.title_en = text
        return text or task.title or ""


async def ensure_task_description_for_lang(db: AsyncSession, task: models.Task, lang: str) -> str:
    """返回任务描述在 lang 下的展示文案；若对应列为空则翻译 description 并写入该列后返回。"""
    if lang == "zh":
        if getattr(task, "description_zh", None):
            return task.description_zh
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=task.description or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            task.description_zh = text
        return text or task.description or ""
    else:
        if getattr(task, "description_en", None):
            return task.description_en
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=task.description or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            task.description_en = text
        return text or task.description or ""


async def get_task_title_description_for_lang(
    db: AsyncSession, task: models.Task, lang: str
) -> Tuple[str, str]:
    """返回 (title, description) 在 lang 下的展示文案，缺则翻译并写入。"""
    title = await ensure_task_title_for_lang(db, task, lang)
    desc = await ensure_task_description_for_lang(db, task, lang)
    return title, desc


def get_task_title_for_lang_from_columns(task: models.Task, lang: str) -> Optional[str]:
    """仅从列读取，不翻译。用于列表等先读列、缺时用主字段兜底。"""
    if lang == "zh":
        return getattr(task, "title_zh", None)
    return getattr(task, "title_en", None)


def get_task_description_for_lang_from_columns(task: models.Task, lang: str) -> Optional[str]:
    """仅从列读取，不翻译。"""
    if lang == "zh":
        return getattr(task, "description_zh", None)
    return getattr(task, "description_en", None)


def get_task_display_title(task: models.Task, lang: str) -> str:
    """从列或主字段取标题，不触发翻译。列表等场景用。"""
    col = get_task_title_for_lang_from_columns(task, lang)
    return col if col else (task.title or "")


def get_task_display_description(task: models.Task, lang: str) -> str:
    """从列或主字段取描述，不触发翻译。"""
    col = get_task_description_for_lang_from_columns(task, lang)
    return col if col else (task.description or "")


# ---------- Activity ----------


async def ensure_activity_title_for_lang(db: AsyncSession, activity: models.Activity, lang: str) -> str:
    """返回活动标题在 lang 下的展示文案；若对应列为空则翻译并写入后返回。"""
    if lang == "zh":
        if getattr(activity, "title_zh", None):
            return activity.title_zh
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=activity.title or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            activity.title_zh = text
        return text or activity.title or ""
    else:
        if getattr(activity, "title_en", None):
            return activity.title_en
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=activity.title or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            activity.title_en = text
        return text or activity.title or ""


async def ensure_activity_description_for_lang(db: AsyncSession, activity: models.Activity, lang: str) -> str:
    """返回活动描述在 lang 下的展示文案；若对应列为空则翻译并写入后返回。"""
    if lang == "zh":
        if getattr(activity, "description_zh", None):
            return activity.description_zh
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=activity.description or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            activity.description_zh = text
        return text or activity.description or ""
    else:
        if getattr(activity, "description_en", None):
            return activity.description_en
        target = _api_target_lang(lang)
        text = await translate_async(
            get_translation_manager(),
            text=activity.description or "",
            target_lang=target,
            source_lang="auto",
            max_retries=2,
        )
        if text:
            activity.description_en = text
        return text or activity.description or ""


def get_activity_display_title(activity: models.Activity, lang: str) -> str:
    """从列或主字段取活动标题，不触发翻译。"""
    if lang == "zh":
        col = getattr(activity, "title_zh", None)
    else:
        col = getattr(activity, "title_en", None)
    return col if col else (activity.title or "")


def get_activity_display_description(activity: models.Activity, lang: str) -> str:
    """从列或主字段取活动描述，不触发翻译。"""
    if lang == "zh":
        col = getattr(activity, "description_zh", None)
    else:
        col = getattr(activity, "description_en", None)
    return col if col else (activity.description or "")

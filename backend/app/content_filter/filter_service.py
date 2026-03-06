"""
Singleton service that loads keywords/homophones from DB,
and provides a global ContentFilter instance.
"""
import logging
import time
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.content_filter.content_filter import ContentFilter, FilterResult

logger = logging.getLogger(__name__)

_filter_instance: Optional[ContentFilter] = None
_last_refresh: float = 0
_REFRESH_INTERVAL = 300  # 5 minutes


async def get_content_filter(db: AsyncSession) -> ContentFilter:
    """Get or refresh the global ContentFilter singleton."""
    global _filter_instance, _last_refresh
    now = time.time()
    if _filter_instance is None or (now - _last_refresh) > _REFRESH_INTERVAL:
        await _refresh_filter(db)
        _last_refresh = now
    return _filter_instance


async def _refresh_filter(db: AsyncSession):
    """Load keywords and homophones from DB, rebuild filter."""
    global _filter_instance

    result = await db.execute(
        select(models.SensitiveWord).where(models.SensitiveWord.is_active == True)
    )
    words = result.scalars().all()
    keywords = [
        {"word": w.word, "category": w.category, "level": w.level}
        for w in words
    ]

    result = await db.execute(
        select(models.HomophoneMapping).where(models.HomophoneMapping.is_active == True)
    )
    mappings = result.scalars().all()
    homophones = {m.variant: m.standard for m in mappings}

    if _filter_instance is None:
        _filter_instance = ContentFilter(keywords=keywords, homophones=homophones)
    else:
        _filter_instance.update_keywords(keywords)
        _filter_instance.update_homophones(homophones)

    logger.info(f"Content filter refreshed: {len(keywords)} keywords, {len(homophones)} homophones")


def force_refresh():
    """Force next call to get_content_filter to reload from DB."""
    global _last_refresh
    _last_refresh = 0


async def check_content(
    db: AsyncSession,
    text: Optional[str],
    content_type: str,
    user_id: str,
) -> FilterResult:
    """Check text and log the result."""
    content_filter = await get_content_filter(db)
    result = content_filter.check(text)

    if result.action != "pass":
        log_entry = models.FilterLog(
            user_id=user_id,
            content_type=content_type,
            action=result.action,
            matched_words=[{"word": m["word"], "category": m["category"]} for m in result.matched_words],
        )
        db.add(log_entry)

    return result


async def create_review(
    db: AsyncSession,
    content_type: str,
    content_id: int,
    user_id: str,
    original_text: str,
    matched_words: list,
):
    """Create a content review entry."""
    review = models.ContentReview(
        content_type=content_type,
        content_id=content_id,
        user_id=user_id,
        original_text=original_text,
        matched_words=[{"word": m["word"], "category": m["category"]} for m in matched_words],
        status="pending",
    )
    db.add(review)

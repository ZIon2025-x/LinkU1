"""
管理员 - 内容审核管理
敏感词 CRUD、谐音映射、审核队列、过滤日志
"""
import json
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.content_filter.filter_service import force_refresh
from app.deps import get_async_db_dependency
from app.utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/admin/content-moderation",
    tags=["管理员-内容审核"],
)


# ── 管理员认证依赖 ──────────────────────────
async def get_current_admin_async(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.AdminUser:
    """获取当前管理员（异步版本）"""
    from app.admin_auth import validate_admin_session

    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败，请重新登录",
        )

    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在",
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用",
        )

    return admin


# ── Pydantic 请求 / 响应 schemas ──────────────

class SensitiveWordCreate(BaseModel):
    word: str = Field(..., min_length=1, max_length=100)
    category: str = Field(..., min_length=1, max_length=20)
    level: str = Field("review", pattern=r"^(mask|review)$")
    is_active: bool = True


class SensitiveWordUpdate(BaseModel):
    word: Optional[str] = Field(None, min_length=1, max_length=100)
    category: Optional[str] = Field(None, min_length=1, max_length=20)
    level: Optional[str] = Field(None, pattern=r"^(mask|review)$")
    is_active: Optional[bool] = None


class SensitiveWordBatchImport(BaseModel):
    words: List[SensitiveWordCreate]


class HomophoneMappingCreate(BaseModel):
    variant: str = Field(..., min_length=1, max_length=50)
    standard: str = Field(..., min_length=1, max_length=50)
    is_active: bool = True


class ReviewAction(BaseModel):
    action: str = Field(..., pattern=r"^(approved|rejected|restored)$")
    reason: Optional[str] = None


# ── 敏感词 CRUD ───────────────────────────────

@router.get("/sensitive-words")
async def list_sensitive_words(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    category: Optional[str] = None,
    is_active: Optional[bool] = None,
    keyword: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出敏感词（分页，可按分类/启用状态筛选）"""
    query = select(models.SensitiveWord)

    if category:
        query = query.where(models.SensitiveWord.category == category)
    if is_active is not None:
        query = query.where(models.SensitiveWord.is_active == is_active)
    if keyword:
        query = query.where(models.SensitiveWord.word.ilike(f"%{keyword}%"))

    # 总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    # 分页
    query = query.order_by(desc(models.SensitiveWord.created_at)).offset(skip).limit(limit)
    result = await db.execute(query)
    words = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": w.id,
                "word": w.word,
                "category": w.category,
                "level": w.level,
                "is_active": w.is_active,
                "created_by": w.created_by,
                "created_at": w.created_at.isoformat() if w.created_at else None,
            }
            for w in words
        ],
    }


@router.post("/sensitive-words", status_code=status.HTTP_201_CREATED)
async def create_sensitive_word(
    body: SensitiveWordCreate,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """添加一个敏感词"""
    # 检查重复
    existing = await db.execute(
        select(models.SensitiveWord).where(models.SensitiveWord.word == body.word)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail=f"敏感词 '{body.word}' 已存在")

    word = models.SensitiveWord(
        word=body.word,
        category=body.category,
        level=body.level,
        is_active=body.is_active,
        created_by=admin.id,
    )
    db.add(word)
    await db.commit()
    await db.refresh(word)

    force_refresh()
    logger.info(f"Admin {admin.id} created sensitive word: {body.word}")

    return {
        "id": word.id,
        "word": word.word,
        "category": word.category,
        "level": word.level,
        "is_active": word.is_active,
        "created_by": word.created_by,
        "created_at": word.created_at.isoformat() if word.created_at else None,
    }


@router.put("/sensitive-words/{word_id}")
async def update_sensitive_word(
    word_id: int,
    body: SensitiveWordUpdate,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新一个敏感词"""
    result = await db.execute(
        select(models.SensitiveWord).where(models.SensitiveWord.id == word_id)
    )
    word = result.scalar_one_or_none()
    if not word:
        raise HTTPException(status_code=404, detail="敏感词不存在")

    if body.word is not None:
        # 检查新词是否和其他记录重复
        dup = await db.execute(
            select(models.SensitiveWord).where(
                models.SensitiveWord.word == body.word,
                models.SensitiveWord.id != word_id,
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=400, detail=f"敏感词 '{body.word}' 已存在")
        word.word = body.word

    if body.category is not None:
        word.category = body.category
    if body.level is not None:
        word.level = body.level
    if body.is_active is not None:
        word.is_active = body.is_active

    await db.commit()
    await db.refresh(word)

    force_refresh()
    logger.info(f"Admin {admin.id} updated sensitive word {word_id}")

    return {
        "id": word.id,
        "word": word.word,
        "category": word.category,
        "level": word.level,
        "is_active": word.is_active,
        "created_by": word.created_by,
        "created_at": word.created_at.isoformat() if word.created_at else None,
    }


@router.delete("/sensitive-words/{word_id}")
async def delete_sensitive_word(
    word_id: int,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除一个敏感词"""
    result = await db.execute(
        select(models.SensitiveWord).where(models.SensitiveWord.id == word_id)
    )
    word = result.scalar_one_or_none()
    if not word:
        raise HTTPException(status_code=404, detail="敏感词不存在")

    await db.delete(word)
    await db.commit()

    force_refresh()
    logger.info(f"Admin {admin.id} deleted sensitive word {word_id}: {word.word}")

    return {"detail": "已删除"}


@router.post("/sensitive-words/batch", status_code=status.HTTP_201_CREATED)
async def batch_import_sensitive_words(
    body: SensitiveWordBatchImport,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """批量导入敏感词"""
    # 获取已有敏感词集合
    existing_result = await db.execute(select(models.SensitiveWord.word))
    existing_words = {row[0] for row in existing_result.all()}

    created = []
    skipped = []
    for item in body.words:
        if item.word in existing_words:
            skipped.append(item.word)
            continue
        word = models.SensitiveWord(
            word=item.word,
            category=item.category,
            level=item.level,
            is_active=item.is_active,
            created_by=admin.id,
        )
        db.add(word)
        existing_words.add(item.word)
        created.append(item.word)

    await db.commit()

    force_refresh()
    logger.info(f"Admin {admin.id} batch imported {len(created)} words, skipped {len(skipped)}")

    return {
        "created_count": len(created),
        "skipped_count": len(skipped),
        "skipped_words": skipped,
    }


# ── 谐音映射 ──────────────────────────────────

@router.get("/homophone-mappings")
async def list_homophone_mappings(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    keyword: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出谐音映射（分页）"""
    query = select(models.HomophoneMapping)

    if keyword:
        query = query.where(
            models.HomophoneMapping.variant.ilike(f"%{keyword}%")
            | models.HomophoneMapping.standard.ilike(f"%{keyword}%")
        )

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    query = query.order_by(models.HomophoneMapping.id.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    mappings = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": m.id,
                "variant": m.variant,
                "standard": m.standard,
                "is_active": m.is_active,
            }
            for m in mappings
        ],
    }


@router.post("/homophone-mappings", status_code=status.HTTP_201_CREATED)
async def create_homophone_mapping(
    body: HomophoneMappingCreate,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """添加一个谐音映射"""
    existing = await db.execute(
        select(models.HomophoneMapping).where(models.HomophoneMapping.variant == body.variant)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail=f"变体 '{body.variant}' 的映射已存在")

    mapping = models.HomophoneMapping(
        variant=body.variant,
        standard=body.standard,
        is_active=body.is_active,
    )
    db.add(mapping)
    await db.commit()
    await db.refresh(mapping)

    force_refresh()
    logger.info(f"Admin {admin.id} created homophone mapping: {body.variant} -> {body.standard}")

    return {
        "id": mapping.id,
        "variant": mapping.variant,
        "standard": mapping.standard,
        "is_active": mapping.is_active,
    }


@router.delete("/homophone-mappings/{mapping_id}")
async def delete_homophone_mapping(
    mapping_id: int,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除一个谐音映射"""
    result = await db.execute(
        select(models.HomophoneMapping).where(models.HomophoneMapping.id == mapping_id)
    )
    mapping = result.scalar_one_or_none()
    if not mapping:
        raise HTTPException(status_code=404, detail="谐音映射不存在")

    await db.delete(mapping)
    await db.commit()

    force_refresh()
    logger.info(f"Admin {admin.id} deleted homophone mapping {mapping_id}")

    return {"detail": "已删除"}


# ── 审核队列 ──────────────────────────────────

@router.get("/content-reviews")
async def list_content_reviews(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None, alias="status"),
    content_type: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """列出审核队列（分页，可按状态/内容类型筛选）"""
    query = select(models.ContentReview)

    if status_filter:
        query = query.where(models.ContentReview.status == status_filter)
    if content_type:
        query = query.where(models.ContentReview.content_type == content_type)

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    query = query.order_by(desc(models.ContentReview.created_at)).offset(skip).limit(limit)
    result = await db.execute(query)
    reviews = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": r.id,
                "content_type": r.content_type,
                "content_id": r.content_id,
                "user_id": r.user_id,
                "original_text": r.original_text,
                "matched_words": r.matched_words,
                "status": r.status,
                "reviewed_by": r.reviewed_by,
                "reviewed_at": r.reviewed_at.isoformat() if r.reviewed_at else None,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in reviews
        ],
    }


@router.put("/content-reviews/{review_id}")
async def review_content(
    review_id: int,
    body: ReviewAction,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审批、拒绝或恢复一条审核记录"""
    result = await db.execute(
        select(models.ContentReview).where(models.ContentReview.id == review_id)
    )
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="审核记录不存在")

    # pending 记录可以 approved/rejected；masked 记录可以 restored
    if review.status == "pending" and body.action in ("approved", "rejected"):
        pass  # allowed
    elif review.status == "masked" and body.action == "restored":
        pass  # allowed
    else:
        raise HTTPException(status_code=400, detail="该记录当前状态不支持此操作")

    review.status = body.action
    review.reviewed_by = admin.id
    review.reviewed_at = get_utc_time()

    model_map = {
        "task": models.Task,
        "forum_post": models.ForumPost,
        "forum_reply": models.ForumReply,
        "flea_market": models.FleaMarketItem,
    }

    # 审核通过 → 恢复内容可见性
    if body.action == "approved":
        model_cls = model_map.get(review.content_type)
        if model_cls:
            content_result = await db.execute(
                select(model_cls).where(model_cls.id == review.content_id)
            )
            content = content_result.scalar_one_or_none()
            if content:
                content.is_visible = True

    # 恢复屏蔽 → 用原文覆盖当前内容,并重新生成翻译
    elif body.action == "restored":
        model_cls = model_map.get(review.content_type)
        if model_cls:
            content_result = await db.execute(
                select(model_cls).where(model_cls.id == review.content_id)
            )
            content = content_result.scalar_one_or_none()
            if content:
                # original_text is JSON dict: {"title": "...", "content": "...", ...}
                try:
                    fields = json.loads(review.original_text)
                except (json.JSONDecodeError, TypeError):
                    fields = None

                if isinstance(fields, dict):
                    for field_name, field_value in fields.items():
                        if hasattr(content, field_name):
                            setattr(content, field_name, field_value)
                else:
                    # Fallback for legacy plain-text records
                    if hasattr(content, "content"):
                        content.content = review.original_text
                    elif hasattr(content, "description"):
                        content.description = review.original_text

                # 翻译字段处理:打码时翻译跟着被污染,恢复原文后需要清空/重译
                #   - forum_post: 发帖时后台异步翻译 → 同步重译并写回
                #   - task: 懒翻译(读取时按需翻译) → 清空,下次读自动重译
                #   - flea_market / forum_reply: 无翻译字段,无需处理
                if review.content_type == "forum_post":
                    from app.utils.bilingual_helper import auto_fill_bilingual_fields
                    try:
                        _, t_en, t_zh, c_en, c_zh = await auto_fill_bilingual_fields(
                            name=content.title,
                            description=content.content,
                        )
                        content.title_en = t_en
                        content.title_zh = t_zh
                        content.content_en = c_en
                        content.content_zh = c_zh
                    except Exception as e:
                        logger.warning(
                            f"恢复 forum_post {review.content_id} 时重译失败,清空翻译字段交给读取时重试: {e}"
                        )
                        content.title_en = None
                        content.title_zh = None
                        content.content_en = None
                        content.content_zh = None
                elif review.content_type == "task":
                    content.title_en = None
                    content.title_zh = None
                    content.description_en = None
                    content.description_zh = None

    await db.commit()

    logger.info(
        f"Admin {admin.id} {body.action} content review {review_id} "
        f"(type={review.content_type}, content_id={review.content_id})"
    )

    return {
        "id": review.id,
        "status": review.status,
        "reviewed_by": review.reviewed_by,
        "reviewed_at": review.reviewed_at.isoformat() if review.reviewed_at else None,
    }


# ── 过滤日志 ──────────────────────────────────

@router.get("/filter-logs")
async def list_filter_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    action: Optional[str] = None,
    content_type: Optional[str] = None,
    user_id: Optional[str] = None,
    admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """查询过滤日志（分页，可按动作/内容类型筛选）"""
    query = select(models.FilterLog)

    if action:
        query = query.where(models.FilterLog.action == action)
    if content_type:
        query = query.where(models.FilterLog.content_type == content_type)
    if user_id:
        query = query.where(models.FilterLog.user_id == user_id)

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    query = query.order_by(desc(models.FilterLog.created_at)).offset(skip).limit(limit)
    result = await db.execute(query)
    logs = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": log.id,
                "user_id": log.user_id,
                "content_type": log.content_type,
                "action": log.action,
                "matched_words": log.matched_words,
                "created_at": log.created_at.isoformat() if log.created_at else None,
            }
            for log in logs
        ],
    }

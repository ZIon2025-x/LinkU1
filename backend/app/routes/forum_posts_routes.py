"""
论坛-帖子 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from typing import Optional
from datetime import datetime, timezone, timedelta
import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.database import get_db  # sync session for points transaction
from app.coupon_points_crud import add_points_transaction
from app.utils.time_utils import get_utc_time
from app.performance_monitor import measure_api_performance
from app.content_filter.filter_service import check_content, create_review, create_mask_record
from app.expert_forum_helpers import (
    is_expert_board,
    check_expert_board_post_permission,
    check_expert_board_manage_permission,
)

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    assert_forum_visible,
    preload_badge_cache,
    get_post_author_info,
    get_post_with_permissions,
    _batch_get_post_display_view_counts,
    _batch_get_user_liked_favorited_posts,
    _parse_attachments,
    _resolve_linked_item_name,
    strip_markdown,
    log_admin_operation,
    update_category_stats,
    _bg_translate_post,
    _post_identity,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ==================== 帖子 API ====================

@router.get("/posts", response_model=schemas.ForumPostListResponse)
@measure_api_performance("list_forum_posts")
async def get_posts(
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort: str = Query("last_reply", pattern="^(latest|last_reply|hot|replies|likes)$"),
    q: Optional[str] = Query(None),
    is_deleted: Optional[bool] = Query(None, description="是否已删除（管理员筛选）"),
    is_visible: Optional[bool] = Query(None, description="是否可见（管理员筛选）"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子列表（包含Redis增量的浏览量）"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 构建基础查询
    query = select(models.ForumPost)

    # 如果不是管理员，只显示未删除且可见的帖子
    if not is_admin:
        query = query.where(
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True
        )
    else:
        # 管理员可以根据参数筛选
        if is_deleted is not None:
            query = query.where(models.ForumPost.is_deleted == is_deleted)
        else:
            # 默认不显示已删除的帖子
            query = query.where(models.ForumPost.is_deleted == False)

        if is_visible is not None:
            query = query.where(models.ForumPost.is_visible == is_visible)
        # 如果 is_visible 为 None，显示所有可见性状态的帖子

    # 板块筛选
    if category_id:
        # 检查板块可见性（学校板块需要权限）
        await assert_forum_visible(current_user, category_id, db, raise_exception=True)
        query = query.where(models.ForumPost.category_id == category_id)

    # 搜索关键词（支持中英文字段，双语扩展）
    if q:
        from app.utils.search_expander import build_keyword_filter
        keyword_expr = build_keyword_filter(
            columns=[
                models.ForumPost.title,
                models.ForumPost.content,
                models.ForumPost.title_en,
                models.ForumPost.title_zh,
                models.ForumPost.content_en,
                models.ForumPost.content_zh,
            ],
            keyword=q,
            use_similarity=False,
        )
        if keyword_expr is not None:
            query = query.where(keyword_expr)

    # 排序
    # 注意：只有置顶帖子需要优先显示，加精帖子不改变排序顺序
    # 排序优先级：置顶帖子 > 普通帖子（包括加精帖子）
    # 非置顶帖子按照综合热度排序，考虑点赞、收藏、评论和最近活跃度

    # 改进的热度算法：综合考虑点赞、收藏、评论和最近活跃度
    # 使用 last_reply_at 作为时间因子（如果存在），否则使用 created_at
    # 时间衰减：最近活跃的帖子权重更高
    active_time = func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at)
    hours_since_active = func.extract('epoch', func.now() - active_time) / 3600.0

    # 综合热度分数 = (点赞数*权重 + 收藏数*权重 + 评论数*权重 + 浏览量*权重) / 时间衰减因子
    # 时间衰减：使用对数衰减，让最近活跃的帖子有更高的权重
    # 公式：score = interaction_score / (1 + hours_since_active / decay_factor)^decay_power
    # 其中 decay_factor 控制衰减速度，decay_power 控制衰减曲线
    hot_score = (
        models.ForumPost.like_count * 5.0 +      # 点赞权重：5
        models.ForumPost.favorite_count * 4.0 +  # 收藏权重：4（收藏表示深度兴趣）
        models.ForumPost.reply_count * 3.0 +     # 评论权重：3
        models.ForumPost.view_count * 0.1        # 浏览量权重：0.1（较低，因为浏览不代表互动）
    ) / func.pow(
        (hours_since_active / 24.0) + 1.0,  # 以天为单位，+1避免除零
        1.2  # 衰减指数，值越大衰减越快
    )

    if sort == "latest":
        # 置顶优先，然后按创建时间降序
        query = query.order_by(
            models.ForumPost.is_pinned.desc(),  # 置顶帖子优先
            models.ForumPost.created_at.desc()  # 最后按创建时间
        )
    elif sort == "last_reply":
        # 置顶优先，然后按最后回复时间降序
        query = query.order_by(
            models.ForumPost.is_pinned.desc(),  # 置顶帖子优先
            func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at).desc()  # 最后按最后回复时间
        )
    else:
        # 其他排序方式（hot, replies, likes）都使用综合热度排序
        # 置顶优先，然后按综合热度排序
        query = query.order_by(
            models.ForumPost.is_pinned.desc(),  # 置顶帖子优先
            hot_score.desc()  # 最后按综合热度排序
        )

    # 先获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )

    result = await db.execute(query)
    posts = result.scalars().all()

    # 批量加载点赞/收藏状态与浏览量，避免 N+1 查询
    post_ids = [p.id for p in posts]
    liked_ids, favorited_ids = await _batch_get_user_liked_favorited_posts(
        db, current_user.id if current_user else "", post_ids
    )
    view_counts = await _batch_get_post_display_view_counts(posts)

    _author_ids = list({p.author_id for p in posts if p.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    from app.services.display_identity import batch_resolve_async
    _identities = [_post_identity(p) for p in posts]
    _identity_map = await batch_resolve_async(db, _identities)

    post_items = []
    for post in posts:
        is_liked = post.id in liked_ids
        is_favorited = post.id in favorited_ids
        display_view_count = view_counts.get(post.id, post.view_count or 0)

        content_preview = strip_markdown(post.content)
        content_preview_en = None
        content_preview_zh = None
        if hasattr(post, 'content_en') and post.content_en:
            content_preview_en = strip_markdown(post.content_en)
        if hasattr(post, 'content_zh') and post.content_zh:
            content_preview_zh = strip_markdown(post.content_zh)

        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))

        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            title_en=getattr(post, 'title_en', None),
            title_zh=getattr(post, 'title_zh', None),
            content_preview=content_preview,
            content_preview_en=content_preview_en,
            content_preview_zh=content_preview_zh,
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
            author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
            view_count=display_view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            is_visible=post.is_visible,
            is_deleted=post.is_deleted,
            images=post.images,
            attachments=_parse_attachments(post.attachments),
            linked_item_type=post.linked_item_type,
            linked_item_id=post.linked_item_id,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at,
            is_liked=post.id in liked_ids,
            is_favorited=post.id in favorited_ids,
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/posts/{post_id}", response_model=schemas.ForumPostOut)
@measure_api_performance("get_forum_post")
async def get_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子详情"""
    # 尝试获取当前用户（可选）
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 检查是否为管理员
    is_admin = False
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 获取帖子
    post = await get_post_with_permissions(post_id, current_user, is_admin, db, current_admin)

    # 检查帖子所属板块的可见性（学校板块需要权限）
    await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

    # 增加浏览次数
    # 优化方案：使用 Redis 累加，定时批量落库（由 Celery 任务处理）
    # 当前实现：如果 Redis 可用则使用 Redis，否则直接更新数据库
    redis_view_count = 0
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()

        if redis_client:
            # 使用 Redis 累加浏览数（存储增量）
            redis_key = f"forum:post:view_count:{post_id}"
            # incr 返回增加后的值（如果 key 不存在则创建并设置为1）
            redis_client.incr(redis_key)
            # 获取 Redis 中的总值（包括本次增加的1）
            redis_view_count = int(redis_client.get(redis_key) or 0)
            # 设置过期时间（7天），防止 key 无限增长
            redis_client.expire(redis_key, 7 * 24 * 3600)
            # 注意：Redis 中的增量会由后台任务定期同步到数据库
            # 这里不更新数据库，减少数据库写入压力
        else:
            # Redis 不可用，直接更新数据库
            post.view_count += 1
            await db.flush()
    except Exception as e:
        # Redis 操作失败，回退到直接更新数据库
        logger.debug(f"Redis view count increment failed, falling back to DB: {e}")
        post.view_count += 1
        await db.flush()

    await db.commit()

    # 计算返回给用户的浏览量（数据库值 + Redis中的增量）
    display_view_count = post.view_count
    if redis_view_count > 0:
        # 如果使用了 Redis，返回数据库值 + Redis 中的增量
        display_view_count = post.view_count + redis_view_count

    # 检查当前用户是否已点赞/收藏
    is_liked = False
    is_favorited = False
    if current_user:
        like_result = await db.execute(
            select(models.ForumLike).where(
                models.ForumLike.target_type == "post",
                models.ForumLike.target_id == post.id,
                models.ForumLike.user_id == current_user.id
            )
        )
        is_liked = like_result.scalar_one_or_none() is not None

        favorite_result = await db.execute(
            select(models.ForumFavorite).where(
                models.ForumFavorite.post_id == post.id,
                models.ForumFavorite.user_id == current_user.id
            )
        )
        is_favorited = favorite_result.scalar_one_or_none() is not None

    linked_name = await _resolve_linked_item_name(db, post.linked_item_type, post.linked_item_id)

    _badge_cache = await preload_badge_cache(db, [post.author_id] if post.author_id else [])

    from app.services.display_identity import resolve_async
    _otype, _oid = _post_identity(post)
    _dname, _davatar = await resolve_async(db, _otype, _oid)

    return schemas.ForumPostOut(
        id=post.id,
        title=post.title,
        title_en=getattr(post, 'title_en', None),
        title_zh=getattr(post, 'title_zh', None),
        content=post.content,
        content_en=getattr(post, 'content_en', None),
        content_zh=getattr(post, 'content_zh', None),
        category=schemas.CategoryInfo(id=post.category.id, name=post.category.name, name_en=post.category.name_en, name_zh=post.category.name_zh),
        author=await get_post_author_info(db, post, request, _badge_cache=_badge_cache),
        view_count=display_view_count,  # 使用包含 Redis 增量的浏览量
        reply_count=post.reply_count,
        like_count=post.like_count,
        favorite_count=post.favorite_count,
        is_pinned=post.is_pinned,
        is_featured=post.is_featured,
        is_locked=post.is_locked,
        is_liked=is_liked,
        is_favorited=is_favorited,
        images=post.images,
        attachments=_parse_attachments(post.attachments),
        linked_item_type=post.linked_item_type,
        linked_item_id=post.linked_item_id,
        linked_item_name=linked_name,
        created_at=post.created_at,
        updated_at=post.updated_at,
        last_reply_at=post.last_reply_at,
        owner_type=_otype,
        owner_id=_oid or None,
        display_name=_dname,
        display_avatar=_davatar,
    )


@router.post("/posts", response_model=schemas.ForumPostOut)
async def create_post(
    post: schemas.ForumPostCreate,
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建帖子（支持管理员和普通用户）"""
    # 首先尝试获取普通用户会话
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 检查是否有管理员会话（在管理员页面操作时）
    admin_user = None
    is_admin_user = False
    try:
        admin_user = await get_current_admin_async(request, db)
        if admin_user:
            is_admin_user = True
    except HTTPException:
        pass

    # 如果既没有普通用户会话也没有管理员会话，返回401
    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息",
            headers={"X-Error-Code": "UNAUTHORIZED"}
        )

    # 频率限制：检查用户最近1分钟内是否发过帖子
    one_minute_ago = datetime.now(timezone.utc) - timedelta(minutes=1)
    if admin_user:
        # 管理员发帖：检查管理员最近1分钟内是否发过帖子
        recent_post_result = await db.execute(
            select(func.count(models.ForumPost.id))
            .where(
                models.ForumPost.admin_author_id == admin_user.id,
                models.ForumPost.created_at >= one_minute_ago
            )
        )
    else:
        # 普通用户发帖：检查用户最近1分钟内是否发过帖子
        recent_post_result = await db.execute(
            select(func.count(models.ForumPost.id))
            .where(
                models.ForumPost.author_id == current_user.id,
                models.ForumPost.created_at >= one_minute_ago
            )
        )
    recent_post_count = recent_post_result.scalar() or 0
    if recent_post_count > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="发帖频率限制：最多1条/分钟",
            headers={"X-Error-Code": "RATE_LIMIT_EXCEEDED"}
        )

    # 重复内容检测：检查用户最近5分钟内是否发过相同标题的帖子
    five_minutes_ago = datetime.now(timezone.utc) - timedelta(minutes=5)
    if admin_user:
        # 管理员发帖：检查管理员最近5分钟内是否发过相同标题的帖子
        duplicate_post_result = await db.execute(
            select(models.ForumPost)
            .where(
                models.ForumPost.admin_author_id == admin_user.id,
                models.ForumPost.title == post.title,
                models.ForumPost.created_at >= five_minutes_ago
            )
            .limit(1)
        )
    else:
        # 普通用户发帖：检查用户最近5分钟内是否发过相同标题的帖子
        duplicate_post_result = await db.execute(
            select(models.ForumPost)
            .where(
                models.ForumPost.author_id == current_user.id,
                models.ForumPost.title == post.title,
                models.ForumPost.created_at >= five_minutes_ago
            )
            .limit(1)
        )
    duplicate_post = duplicate_post_result.scalar_one_or_none()
    if duplicate_post:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您最近5分钟内已发布过相同标题的帖子，请勿重复发布",
            headers={"X-Error-Code": "DUPLICATE_POST"}
        )

    # Content filtering
    filter_user_id = current_user.id if current_user else admin_user.id
    title_result = await check_content(db, post.title, "forum_post", filter_user_id)
    content_result = await check_content(db, post.content, "forum_post", filter_user_id)

    filter_actions = [title_result.action, content_result.action]
    final_action = "review" if "review" in filter_actions else ("mask" if "mask" in filter_actions else "pass")

    # 保存原文(用于 mask_record),mask 会改写 post.title/post.content
    original_title = post.title
    original_content = post.content

    if title_result.action == "mask":
        post.title = title_result.cleaned_text
    if content_result.action == "mask":
        post.content = content_result.cleaned_text

    # 验证板块是否存在并检查权限（仅当 category_id 提供时）
    # 对于学校板块，需要学生认证；对于普通板块，所有用户都可以发帖
    # 当 category_id 为 None（未分类发帖）时，跳过所有板块相关校验
    expert_id = None
    is_expert = False
    if post.category_id is not None:
        category_result = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.id == post.category_id)
        )
        category = category_result.scalar_one_or_none()
        if not category:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="板块不存在",
                headers={"X-Error-Code": "CATEGORY_NOT_FOUND"}
            )

        # 检查板块可见性（学校板块需要权限）
        # 管理员可以绕过权限检查
        if not is_admin_user:
            await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

        # 检查板块是否可见
        if not category.is_visible:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="该板块已隐藏",
                headers={"X-Error-Code": "CATEGORY_HIDDEN"}
            )

        # 检查板块是否禁止用户发帖
        if category.is_admin_only:
            if not is_admin_user:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="该板块只允许管理员发帖",
                    headers={"X-Error-Code": "ADMIN_ONLY_CATEGORY"}
                )

        # 达人板块发帖权限检查
        is_expert, expert_id = await is_expert_board(db, post.category_id)
        if is_expert:
            if not current_user:
                raise HTTPException(status_code=401, detail="达人板块需要登录后发帖")
            can_post = await check_expert_board_post_permission(db, expert_id, current_user.id)
            if not can_post:
                raise HTTPException(status_code=403, detail="只有达人团队成员才能在此板块发帖")

    # 翻译字段由后台任务异步填充，发帖先存 None 立即返回
    normalized_content = post.content.strip() if post.content else None

    # 创建帖子（包含图片/附件和关联内容）
    post_images = post.images if hasattr(post, 'images') else None
    post_attachments = [a.model_dump() for a in post.attachments] if hasattr(post, 'attachments') and post.attachments else None
    post_linked_type = post.linked_item_type if hasattr(post, 'linked_item_type') else None
    post_linked_id = post.linked_item_id if hasattr(post, 'linked_item_id') else None

    # 达人板块帖子：挂到团队身份，让 follow feed / 列表展示团队名/头像
    post_expert_id = expert_id if is_expert else None

    if admin_user:
        # 管理员发帖：使用 admin_author_id
        db_post = models.ForumPost(
            title=post.title,
            title_en=None,
            title_zh=None,
            content=post.content,
            content_en=None,
            content_zh=None,
            category_id=post.category_id,
            admin_author_id=admin_user.id,
            author_id=None,
            expert_id=post_expert_id,
            images=post_images,
            attachments=post_attachments,
            linked_item_type=post_linked_type,
            linked_item_id=post_linked_id,
        )
    else:
        # 普通用户发帖：使用 author_id
        db_post = models.ForumPost(
            title=post.title,
            title_en=None,
            title_zh=None,
            content=post.content,
            content_en=None,
            content_zh=None,
            category_id=post.category_id,
            author_id=current_user.id,
            admin_author_id=None,
            expert_id=post_expert_id,
            images=post_images,
            attachments=post_attachments,
            linked_item_type=post_linked_type,
            linked_item_id=post_linked_id,
        )
    db.add(db_post)
    await db.flush()

    # Content filter: handle review / visibility
    if final_action == "review":
        db_post.is_visible = False
        combined_matched = title_result.matched_words + content_result.matched_words
        await create_review(db, "forum_post", db_post.id, filter_user_id,
                           f"[title]{post.title}[content]{post.content}", combined_matched)
        await db.flush()
    elif final_action == "mask":
        combined_matched = title_result.matched_words + content_result.matched_words
        await create_mask_record(db, "forum_post", db_post.id, filter_user_id,
                                {"title": original_title, "content": original_content}, combined_matched)
        await db.flush()

    # 如果有图片，移动临时图片到永久路径
    if post_images:
        try:
            from app.services.image_upload_service import ImageUploadService, ImageCategory
            upload_service = ImageUploadService()
            uploader_id = admin_user.id if admin_user else current_user.id
            moved_urls = upload_service.move_from_temp(
                ImageCategory.FORUM_POST, uploader_id, str(db_post.id), post_images
            )
            if moved_urls:
                db_post.images = moved_urls
                await db.flush()
        except Exception as e:
            logger.warning(f"Failed to move forum post images: {e}")

    # 如果有附件，移动临时文件到永久路径
    if post_attachments:
        try:
            from app.services.image_upload_service import ImageUploadService, ImageCategory
            upload_service = ImageUploadService()
            uploader_id = admin_user.id if admin_user else current_user.id
            att_urls = [a["url"] for a in post_attachments if a.get("url")]
            if att_urls:
                moved_att_urls = upload_service.move_from_temp(
                    ImageCategory.FORUM_POST_FILE, uploader_id, str(db_post.id), att_urls
                )
                if moved_att_urls:
                    url_map = dict(zip(att_urls, moved_att_urls))
                    updated_atts = []
                    for att in post_attachments:
                        new_att = dict(att)
                        if new_att.get("url") in url_map:
                            new_att["url"] = url_map[new_att["url"]]
                        updated_atts.append(new_att)
                    # 必须用新列表赋值，否则 SQLAlchemy 不检测 JSONB 变更（同引用）
                    db_post.attachments = updated_atts
                    await db.flush()
        except Exception as e:
            logger.warning(f"Failed to move forum post files: {e}")

    # 更新板块统计（仅当帖子可见时）
    if db_post.is_deleted == False and db_post.is_visible == True:
        category.post_count += 1
        category.last_post_at = get_utc_time()
        await db.flush()

    await db.commit()
    await db.refresh(db_post)

    # 异步翻译（响应返回后执行，不阻塞用户）
    background_tasks.add_task(
        _bg_translate_post,
        post_id=db_post.id,
        title=post.title,
        content=normalized_content,
        title_en=post.title_en.strip() if getattr(post, 'title_en', None) else None,
        title_zh=post.title_zh.strip() if getattr(post, 'title_zh', None) else None,
        content_en=post.content_en.strip() if getattr(post, 'content_en', None) else None,
        content_zh=post.content_zh.strip() if getattr(post, 'content_zh', None) else None,
    )

    # 失效帖子列表 + 发现页缓存
    from app.redis_cache import invalidate_forum_cache, invalidate_discovery_cache
    invalidate_forum_cache()
    invalidate_discovery_cache()

    # === Official Task: submit + claim reward ===
    official_task_reward = None
    if post.official_task_id is not None and db_post.author_id:
        try:
            # Use sync session for add_points_transaction compatibility
            sync_db = next(get_db())
            try:
                # Validate official task
                task = sync_db.query(models.OfficialTask).filter(
                    models.OfficialTask.id == post.official_task_id,
                    models.OfficialTask.is_active == True,
                    models.OfficialTask.task_type == "forum_post",
                ).first()

                if task is None:
                    logger.warning(f"Official task {post.official_task_id} not found or inactive")
                elif task.valid_until and task.valid_until < get_utc_time():
                    logger.warning(f"Official task {post.official_task_id} has expired")
                elif task.valid_from and task.valid_from > get_utc_time():
                    logger.warning(f"Official task {post.official_task_id} not yet started")
                else:
                    # Check max_per_user with FOR UPDATE lock
                    submission_count = sync_db.query(
                        func.count(models.OfficialTaskSubmission.id)
                    ).filter(
                        models.OfficialTaskSubmission.user_id == db_post.author_id,
                        models.OfficialTaskSubmission.official_task_id == task.id,
                    ).with_for_update().scalar() or 0

                    if submission_count >= task.max_per_user:
                        logger.warning(f"User {db_post.author_id} reached max submissions for task {task.id}")
                    else:
                        # Create submission with status=claimed
                        now = get_utc_time()
                        submission = models.OfficialTaskSubmission(
                            user_id=db_post.author_id,
                            official_task_id=task.id,
                            forum_post_id=db_post.id,
                            status="claimed",
                            submitted_at=now,
                            claimed_at=now,
                            reward_amount=task.reward_amount,
                        )
                        sync_db.add(submission)

                        # Award points
                        if task.reward_type == "points" and task.reward_amount > 0:
                            add_points_transaction(
                                db=sync_db,
                                user_id=db_post.author_id,
                                type="earn",
                                amount=task.reward_amount,
                                source="official_task",
                                related_id=task.id,
                                related_type="official_task",
                                description=f"Official task reward: {task.title_zh or task.title_en}",
                                idempotency_key=f"official_task_{task.id}_user_{db_post.author_id}_post_{db_post.id}",
                            )

                        sync_db.commit()
                        official_task_reward = schemas.OfficialTaskRewardInfo(
                            reward_type=task.reward_type,
                            reward_amount=task.reward_amount,
                        )
                        logger.info(f"Official task {task.id} completed by user {db_post.author_id}, reward: {task.reward_amount} {task.reward_type}")
            except Exception as e:
                logger.error(f"Failed to process official task {post.official_task_id}: {e}")
                try:
                    sync_db.rollback()
                except Exception:
                    pass
            finally:
                try:
                    sync_db.close()
                except Exception:
                    pass
        except Exception as e:
            logger.error(f"Failed to get sync db session for official task: {e}")

    # 加载关联数据
    await db.refresh(db_post, ["category"])
    if db_post.author_id:
        await db.refresh(db_post, ["author"])
    if db_post.admin_author_id:
        await db.refresh(db_post, ["admin_author"])

    # 构建作者信息（使用统一的函数，支持管理员和普通用户）
    _badge_cache = await preload_badge_cache(db, [db_post.author_id] if db_post.author_id else [])
    author_info = await get_post_author_info(db, db_post, request, _badge_cache=_badge_cache)

    from app.services.display_identity import resolve_async
    _otype, _oid = _post_identity(db_post)
    _dname, _davatar = await resolve_async(db, _otype, _oid)

    return schemas.ForumPostOut(
        id=db_post.id,
        title=db_post.title,
        title_en=getattr(db_post, 'title_en', None),
        title_zh=getattr(db_post, 'title_zh', None),
        content=db_post.content,
        content_en=getattr(db_post, 'content_en', None),
        content_zh=getattr(db_post, 'content_zh', None),
        category=schemas.CategoryInfo(id=db_post.category.id, name=db_post.category.name, name_en=db_post.category.name_en, name_zh=db_post.category.name_zh),
        author=author_info,
        view_count=db_post.view_count,
        reply_count=db_post.reply_count,
        like_count=db_post.like_count,
        favorite_count=db_post.favorite_count,
        is_pinned=db_post.is_pinned,
        is_featured=db_post.is_featured,
        is_locked=db_post.is_locked,
        is_liked=False,
        is_favorited=False,
        images=db_post.images,
        attachments=_parse_attachments(db_post.attachments),
        linked_item_type=db_post.linked_item_type,
        linked_item_id=db_post.linked_item_id,
        linked_item_name=await _resolve_linked_item_name(db, db_post.linked_item_type, db_post.linked_item_id),
        created_at=db_post.created_at,
        updated_at=db_post.updated_at,
        last_reply_at=db_post.last_reply_at,
        official_task_reward=official_task_reward,
        owner_type=_otype,
        owner_id=_oid or None,
        display_name=_dname,
        display_avatar=_davatar,
    )


@router.put("/posts/{post_id}", response_model=schemas.ForumPostOut)
async def update_post(
    post_id: int,
    post: schemas.ForumPostUpdate,
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新帖子（支持管理员和普通用户）"""
    # 尝试获取普通用户会话
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 检查是否有管理员会话
    admin_user = None
    is_admin_user = False
    try:
        admin_user = await get_current_admin_async(request, db)
        if admin_user:
            is_admin_user = True
    except HTTPException:
        pass

    # 如果既没有普通用户会话也没有管理员会话，返回401
    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息",
            headers={"X-Error-Code": "UNAUTHORIZED"}
        )

    # 获取帖子
    result = await db.execute(
        select(models.ForumPost)
        .options(
            selectinload(models.ForumPost.category),
            selectinload(models.ForumPost.author),
            selectinload(models.ForumPost.admin_author)
        )
        .where(models.ForumPost.id == post_id)
    )
    db_post = result.scalar_one_or_none()

    if not db_post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    # 检查权限：只有作者可以编辑
    if admin_user:
        # 管理员可以编辑自己发的帖子
        if db_post.admin_author_id != admin_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能编辑自己的帖子"
            )
    else:
        # 普通用户只能编辑自己发的帖子
        if db_post.author_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能编辑自己的帖子"
            )

    # 检查是否已删除
    if db_post.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子已删除"
        )

    # 更新字段
    update_data = post.model_dump(exclude_unset=True)
    old_category_id = db_post.category_id
    old_is_visible = db_post.is_visible
    # 保存旧的图片和附件 URL，用于后续对比删除被移除的文件
    old_image_urls = list(db_post.images) if db_post.images else []
    old_attachment_urls = [a["url"] for a in db_post.attachments if a.get("url")] if db_post.attachments else []

    # 仅当 title 或 content 实际发生变化时才调用翻译，避免浪费翻译次数
    updated_title = update_data.get("title", db_post.title) if "title" in update_data else db_post.title
    updated_content_raw = update_data.get("content", db_post.content) or db_post.content
    normalized_updated_content = (updated_content_raw.strip() if updated_content_raw else None)
    existing_content_normalized = (db_post.content or "").strip() if db_post.content else ""
    title_changed = "title" in update_data and (updated_title or "").strip() != (db_post.title or "").strip()
    content_changed = "content" in update_data and normalized_updated_content != existing_content_normalized

    # 为后台翻译任务记录需要的信息
    _bg_translate_kwargs = None
    if title_changed or content_changed:
        # 保留用户显式提供的翻译（未改动字段沿用现有翻译）
        _bg_translate_kwargs = dict(
            title_en=update_data.get("title_en") or (db_post.title_en if not title_changed else None),
            title_zh=update_data.get("title_zh") or (db_post.title_zh if not title_changed else None),
            content_en=update_data.get("content_en") or (db_post.content_en if not content_changed else None),
            content_zh=update_data.get("content_zh") or (db_post.content_zh if not content_changed else None),
        )
        # 先清空翻译字段，由后台任务填充
        if title_changed:
            update_data["title_en"] = None
            update_data["title_zh"] = None
        if content_changed:
            update_data["content_en"] = None
            update_data["content_zh"] = None

    # 如果更新了板块，需要检查新板块的权限（学校板块需要权限）
    # 当 category_id 显式置为 None（清空分类）时，跳过所有板块相关校验
    if "category_id" in update_data and update_data["category_id"] != old_category_id:
        new_category_id = update_data["category_id"]
        if new_category_id is not None:
            # 验证新板块是否存在
            new_category_result = await db.execute(
                select(models.ForumCategory).where(models.ForumCategory.id == new_category_id)
            )
            new_category = new_category_result.scalar_one_or_none()
            if not new_category:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="目标板块不存在",
                    headers={"X-Error-Code": "CATEGORY_NOT_FOUND"}
                )

            # 检查新板块的可见性（学校板块需要权限）
            # 管理员可以绕过权限检查
            if not is_admin_user:
                await assert_forum_visible(current_user, new_category_id, db, raise_exception=True)

            # 检查新板块是否可见
            if not new_category.is_visible:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="目标板块已隐藏",
                    headers={"X-Error-Code": "CATEGORY_HIDDEN"}
                )

            # 检查新板块是否禁止用户发帖
            if new_category.is_admin_only:
                if not is_admin_user:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="目标板块只允许管理员发帖",
                        headers={"X-Error-Code": "ADMIN_ONLY_CATEGORY"}
                    )

    # 序列化 attachments（Pydantic 对象列表 → dict 列表；空列表视为清空）
    if "attachments" in update_data:
        att_list = update_data["attachments"]
        if att_list:
            update_data["attachments"] = [
                a.model_dump() if hasattr(a, 'model_dump') else a
                for a in att_list
            ]
        else:
            update_data["attachments"] = None

    for field, value in update_data.items():
        setattr(db_post, field, value)

    db_post.updated_at = get_utc_time()
    await db.flush()

    # 如果更新了图片，将临时图片移动到永久存储
    if "images" in update_data and update_data["images"]:
        try:
            from app.services.image_upload_service import ImageUploadService, ImageCategory
            upload_service = ImageUploadService()
            uploader_id = admin_user.id if admin_user else current_user.id
            moved_urls = upload_service.move_from_temp(
                ImageCategory.FORUM_POST, uploader_id, str(db_post.id), update_data["images"]
            )
            if moved_urls:
                db_post.images = moved_urls
                await db.flush()
        except Exception as e:
            logger.warning(f"Failed to move updated forum post images: {e}")

    # 如果更新了附件，将临时文件移动到永久存储
    if "attachments" in update_data and update_data["attachments"]:
        try:
            from app.services.image_upload_service import ImageUploadService, ImageCategory
            upload_service = ImageUploadService()
            uploader_id = admin_user.id if admin_user else current_user.id
            att_urls = [a["url"] for a in update_data["attachments"] if isinstance(a, dict) and a.get("url")]
            if att_urls:
                moved_att_urls = upload_service.move_from_temp(
                    ImageCategory.FORUM_POST_FILE, uploader_id, str(db_post.id), att_urls
                )
                if moved_att_urls:
                    url_map = dict(zip(att_urls, moved_att_urls))
                    updated_atts = []
                    for att in update_data["attachments"]:
                        if isinstance(att, dict):
                            new_att = dict(att)
                            if new_att.get("url") in url_map:
                                new_att["url"] = url_map[new_att["url"]]
                            updated_atts.append(new_att)
                    # 用新列表赋值，确保 SQLAlchemy 检测到 JSONB 变更
                    db_post.attachments = updated_atts
                    await db.flush()
        except Exception as e:
            logger.warning(f"Failed to move updated forum post files: {e}")

    # 删除被移除的旧图片和附件文件
    try:
        from app.services.image_upload_service import ImageUploadService, ImageCategory
        upload_service = ImageUploadService()
        # 删除被移除的旧图片
        if "images" in update_data:
            new_image_urls = set(db_post.images) if db_post.images else set()
            removed_images = [url for url in old_image_urls if url not in new_image_urls]
            if removed_images:
                upload_service.delete(ImageCategory.FORUM_POST, str(db_post.id), removed_images)
                logger.info(f"Deleted {len(removed_images)} removed images for post {db_post.id}")
        # 删除被移除的旧附件
        if "attachments" in update_data:
            new_att_urls = set()
            if db_post.attachments:
                new_att_urls = {a["url"] for a in db_post.attachments if isinstance(a, dict) and a.get("url")}
            removed_atts = [url for url in old_attachment_urls if url not in new_att_urls]
            if removed_atts:
                upload_service.delete(ImageCategory.FORUM_POST_FILE, str(db_post.id), removed_atts)
                logger.info(f"Deleted {len(removed_atts)} removed attachments for post {db_post.id}")
    except Exception as e:
        logger.warning(f"Failed to delete removed files for post {db_post.id}: {e}")

    # 如果板块改变或可见性改变，更新统计
    if "category_id" in update_data or "is_visible" in update_data:
        # 更新旧板块统计
        if old_category_id:
            await update_category_stats(old_category_id, db)
        # 更新新板块统计
        if db_post.category_id:
            await update_category_stats(db_post.category_id, db)

    await db.commit()
    await db.refresh(db_post, ["category"])
    if db_post.author_id:
        await db.refresh(db_post, ["author"])
    if db_post.admin_author_id:
        await db.refresh(db_post, ["admin_author"])

    # 异步翻译（响应返回后执行，不阻塞用户）
    if _bg_translate_kwargs is not None:
        background_tasks.add_task(
            _bg_translate_post,
            post_id=db_post.id,
            title=updated_title,
            content=normalized_updated_content,
            **_bg_translate_kwargs,
        )

    # 检查是否已点赞/收藏（只有普通用户可以点赞/收藏）
    is_liked = False
    is_favorited = False
    if current_user:
        like_result = await db.execute(
            select(models.ForumLike).where(
                models.ForumLike.target_type == "post",
                models.ForumLike.target_id == db_post.id,
                models.ForumLike.user_id == current_user.id
            )
        )
        is_liked = like_result.scalar_one_or_none() is not None

        favorite_result = await db.execute(
            select(models.ForumFavorite).where(
                models.ForumFavorite.post_id == db_post.id,
                models.ForumFavorite.user_id == current_user.id
            )
        )
        is_favorited = favorite_result.scalar_one_or_none() is not None

    _badge_cache = await preload_badge_cache(db, [db_post.author_id] if db_post.author_id else [])

    from app.services.display_identity import resolve_async
    _otype, _oid = _post_identity(db_post)
    _dname, _davatar = await resolve_async(db, _otype, _oid)

    return schemas.ForumPostOut(
        id=db_post.id,
        title=db_post.title,
        title_en=getattr(db_post, 'title_en', None),
        title_zh=getattr(db_post, 'title_zh', None),
        content=db_post.content,
        content_en=getattr(db_post, 'content_en', None),
        content_zh=getattr(db_post, 'content_zh', None),
        category=schemas.CategoryInfo(id=db_post.category.id, name=db_post.category.name, name_en=db_post.category.name_en, name_zh=db_post.category.name_zh),
        author=await get_post_author_info(db, db_post, request, _badge_cache=_badge_cache),
        view_count=db_post.view_count,
        reply_count=db_post.reply_count,
        like_count=db_post.like_count,
        favorite_count=db_post.favorite_count,
        is_pinned=db_post.is_pinned,
        is_featured=db_post.is_featured,
        is_locked=db_post.is_locked,
        is_liked=is_liked,
        is_favorited=is_favorited,
        images=db_post.images,
        attachments=_parse_attachments(db_post.attachments),
        linked_item_type=db_post.linked_item_type,
        linked_item_id=db_post.linked_item_id,
        linked_item_name=await _resolve_linked_item_name(db, db_post.linked_item_type, db_post.linked_item_id),
        created_at=db_post.created_at,
        updated_at=db_post.updated_at,
        last_reply_at=db_post.last_reply_at,
        owner_type=_otype,
        owner_id=_oid or None,
        display_name=_dname,
        display_avatar=_davatar,
    )


@router.delete("/posts/{post_id}")
async def delete_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除帖子（软删除，支持管理员和普通用户）"""
    # 尝试获取普通用户会话
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 检查是否有管理员会话
    admin_user = None
    try:
        admin_user = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 如果既没有普通用户会话也没有管理员会话，返回401
    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息",
            headers={"X-Error-Code": "UNAUTHORIZED"}
        )

    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    db_post = result.scalar_one_or_none()

    if not db_post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    # 检查权限：只有作者可以删除
    if admin_user:
        # 管理员可以删除自己发的帖子
        if db_post.admin_author_id != admin_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能删除自己的帖子"
            )
    else:
        # 普通用户只能删除自己发的帖子
        if db_post.author_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能删除自己的帖子"
            )

    # 检查是否已删除
    if db_post.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="帖子已删除"
        )

    # 软删除
    old_is_visible = db_post.is_visible
    db_post.is_deleted = True
    db_post.updated_at = get_utc_time()
    await db.flush()

    # 更新板块统计（仅当原帖子可见时）
    if old_is_visible:
        await update_category_stats(db_post.category_id, db)

    await db.commit()

    from app.redis_cache import invalidate_forum_cache, invalidate_discovery_cache
    invalidate_forum_cache()
    invalidate_discovery_cache()

    return {"message": "帖子删除成功"}


# ==================== 帖子管理 API（管理员）====================

@router.post("/posts/{post_id}/pin")
async def pin_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """置顶帖子（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_pinned = True
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="pin_post",
            target_type="post",
            target_id=post_id,
            action="pin",
            request=request,
            db=db
        )

    # 发送通知给帖子作者（只通知普通用户作者，管理员作者不接收通知）
    if post.author_id:
        notification = models.ForumNotification(
            notification_type="pin_post",
            target_type="post",
            target_id=post.id,
            from_user_id=None,  # 系统操作
            to_user_id=post.author_id
        )
        db.add(notification)

    await db.commit()

    return {"id": post.id, "is_pinned": True, "message": "帖子已置顶"}


@router.delete("/posts/{post_id}/pin")
async def unpin_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消置顶（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_pinned = False
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="unpin_post",
            target_type="post",
            target_id=post_id,
            action="unpin",
            request=request,
            db=db
        )

    await db.commit()

    return {"id": post.id, "is_pinned": False, "message": "已取消置顶"}


@router.post("/posts/{post_id}/feature")
async def feature_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """加精帖子（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_featured = True
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="feature_post",
            target_type="post",
            target_id=post_id,
            action="feature",
            request=request,
            db=db
        )

    # 发送通知给帖子作者
    if post.author_id:
        notification = models.ForumNotification(
            notification_type="feature_post",
            target_type="post",
            target_id=post.id,
            from_user_id=None,  # 系统操作
            to_user_id=post.author_id
        )
        db.add(notification)

    await db.commit()

    return {"id": post.id, "is_featured": True, "message": "帖子已加精"}


@router.delete("/posts/{post_id}/feature")
async def unfeature_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消加精（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_featured = False
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="unfeature_post",
            target_type="post",
            target_id=post_id,
            action="unfeature",
            request=request,
            db=db
        )

    await db.commit()

    return {"id": post.id, "is_featured": False, "message": "已取消加精"}


@router.post("/posts/{post_id}/lock")
async def lock_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """锁定帖子（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_locked = True
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="lock_post",
            target_type="post",
            target_id=post_id,
            action="lock",
            request=request,
            db=db
        )

    await db.commit()

    return {"id": post.id, "is_locked": True, "message": "帖子已锁定"}


@router.delete("/posts/{post_id}/lock")
async def unlock_post(
    post_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """解锁帖子（管理员或达人板块 Owner/Admin）"""
    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 达人板块管理权限：Owner/Admin 也可以操作
    current_user = None
    post = None
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        post_result = await db.execute(select(models.ForumPost).where(models.ForumPost.id == post_id))
        post = post_result.scalar_one_or_none()
        if post:
            is_expert, expert_id = await is_expert_board(db, post.category_id)
            if is_expert and current_user:
                can_manage = await check_expert_board_manage_permission(db, expert_id, current_user.id)
                if not can_manage:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权限操作此板块")
            elif not is_expert:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="需要管理员权限")
        if not current_admin and not current_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息")

    if post is None:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    post.is_locked = False
    post.updated_at = get_utc_time()
    await db.flush()

    # 记录管理员操作日志（仅管理员操作时记录）
    if current_admin:
        await log_admin_operation(
            operator_id=current_admin.id,
            operation_type="unlock_post",
            target_type="post",
            target_id=post_id,
            action="unlock",
            request=request,
            db=db
        )

    await db.commit()

    return {"id": post.id, "is_locked": False, "message": "帖子已解锁"}


@router.post("/posts/{post_id}/restore")
async def restore_post(
    post_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """恢复帖子（管理员）"""
    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    if not post.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="帖子未被删除"
        )

    # 恢复帖子
    old_is_visible = post.is_visible
    post.is_deleted = False
    post.updated_at = get_utc_time()
    await db.flush()

    # 更新板块统计（仅当恢复后可见时）
    if post.is_visible:
        await update_category_stats(post.category_id, db)

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="restore_post",
        target_type="post",
        target_id=post_id,
        action="restore",
        request=request,
        db=db
    )

    await db.commit()

    return {"id": post.id, "is_deleted": False, "message": "帖子已恢复"}


@router.post("/posts/{post_id}/unhide")
async def unhide_post(
    post_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消隐藏帖子（管理员）"""
    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    if post.is_visible:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="帖子未被隐藏"
        )

    # 取消隐藏
    post.is_visible = True
    post.updated_at = get_utc_time()
    await db.flush()

    # 更新板块统计（仅当帖子未被删除时）
    if not post.is_deleted:
        await update_category_stats(post.category_id, db)

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="unhide_post",
        target_type="post",
        target_id=post_id,
        action="unhide",
        request=request,
        db=db
    )

    await db.commit()

    return {"id": post.id, "is_visible": True, "message": "帖子已取消隐藏"}


@router.post("/posts/{post_id}/hide")
async def hide_post(
    post_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """隐藏帖子（管理员）"""
    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    post = result.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在"
        )

    if not post.is_visible:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="帖子已被隐藏"
        )

    # 隐藏帖子
    post.is_visible = False
    post.updated_at = get_utc_time()
    await db.flush()

    # 更新板块统计（仅当帖子未被删除时）
    if not post.is_deleted:
        await update_category_stats(post.category_id, db)

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="hide_post",
        target_type="post",
        target_id=post_id,
        action="hide",
        request=request,
        db=db
    )

    await db.commit()

    return {"id": post.id, "is_visible": False, "message": "帖子已隐藏"}

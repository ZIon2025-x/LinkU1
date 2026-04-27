"""
论坛-回复 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from typing import Optional
from datetime import datetime, timezone, timedelta
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time
from app.performance_monitor import measure_api_performance
from app.push_notification_service import send_push_notification_async_safe
from app.content_filter.filter_service import check_content, create_review, create_mask_record

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    assert_forum_visible,
    get_reply_author_info,
    preload_badge_cache,
    get_post_with_permissions,
    log_admin_operation,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/posts/{post_id}/replies", response_model=schemas.ForumReplyListResponse)
@measure_api_performance("get_forum_replies")
async def get_replies(
    post_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取回复列表"""
    # 尝试获取当前用户（可选）
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        pass

    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 尝试获取管理员会话
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    # 验证帖子存在且可见
    post = await get_post_with_permissions(post_id, current_user, is_admin, db, current_admin)

    # 构建查询：只获取可见回复
    query = select(models.ForumReply).where(
        models.ForumReply.post_id == post_id,
        models.ForumReply.is_deleted == False
    )

    # 如果不是管理员且不是作者，过滤隐藏的回复
    # 检查是否是作者（普通用户或管理员）
    is_author = False
    if current_user and post.author_id == current_user.id:
        is_author = True
    if current_admin and post.admin_author_id == current_admin.id:
        is_author = True

    if not is_admin and not is_author:
        query = query.where(models.ForumReply.is_visible == True)

    query = query.order_by(models.ForumReply.created_at.asc())

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 帖子详情页需要完整回复树，避免「回复别人的回复」因分页被截断不显示。
    # 一次拉取最多 500 条回复并构建完整树，不再按页 offset。
    max_replies = min(500, max(page_size, 100))
    query = query.limit(max_replies)

    # 加载关联数据
    query = query.options(
        selectinload(models.ForumReply.author),
        selectinload(models.ForumReply.admin_author),
        selectinload(models.ForumReply.parent_reply),
        selectinload(models.ForumReply.child_replies)
    )

    result = await db.execute(query)
    replies = result.scalars().all()

    # 构建嵌套回复结构
    def build_reply_tree(replies_list):
        """构建回复树结构"""
        reply_dict = {}
        root_replies = []

        # 第一遍：创建所有回复的字典
        for reply in replies_list:
            reply_dict[reply.id] = {
                "reply": reply,
                "children": []
            }

        # 第二遍：构建树结构
        for reply in replies_list:
            reply_data = reply_dict[reply.id]
            if reply.parent_reply_id:
                if reply.parent_reply_id in reply_dict:
                    reply_dict[reply.parent_reply_id]["children"].append(reply_data)
            else:
                root_replies.append(reply_data)

        return root_replies

    reply_tree = build_reply_tree(replies)

    # 转换为输出格式（先批量查询所有点赞状态）
    reply_ids = [r.id for r in replies]
    user_liked_replies = set()
    if current_user and reply_ids:
        like_result = await db.execute(
            select(models.ForumLike.target_id)
            .where(
                models.ForumLike.target_type == "reply",
                models.ForumLike.target_id.in_(reply_ids),
                models.ForumLike.user_id == current_user.id
            )
        )
        user_liked_replies = {row[0] for row in like_result.all()}

    # 预加载所有回复作者的勋章缓存
    _reply_author_ids = list({r.author_id for r in replies if r.author_id})
    _badge_cache = await preload_badge_cache(db, _reply_author_ids)

    async def convert_reply(reply_data, liked_set):
        """递归转换回复为扁平 ForumReplyOut 列表（self + 所有子孙）"""
        reply = reply_data["reply"]
        is_liked = reply.id in liked_set
        parent_author = None
        if reply.parent_reply_id and getattr(reply, "parent_reply", None):
            parent_author = await get_reply_author_info(db, reply.parent_reply, request, _badge_cache=_badge_cache)

        reply_out = schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, request, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            parent_reply_author=parent_author,
            like_count=reply.like_count,
            is_liked=is_liked,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
        )

        # 扁平化模型：返回 [self] + 所有子孙的扁平列表
        result = [reply_out]
        for child_data in reply_data["children"]:
            result.extend(await convert_reply(child_data, liked_set))
        return result

    reply_list = []
    for item in reply_tree:
        reply_list.extend(await convert_reply(item, user_liked_replies))

    return {
        "replies": reply_list,
        "total": total,
        "page": 1,
        "page_size": len(replies),
    }


@router.post("/posts/{post_id}/replies", response_model=schemas.ForumReplyOut)
async def create_reply(
    post_id: int,
    reply: schemas.ForumReplyCreate,
    request: Request,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建回复"""
    # 尝试获取管理员会话（用于后台官方回复）
    admin_user = None
    is_admin_user = False
    try:
        admin_user = await get_current_admin_async(request, db)
        if admin_user:
            is_admin_user = True
    except HTTPException:
        pass

    # 如果既没有普通用户也没有管理员，拒绝
    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息",
            headers={"X-Error-Code": "UNAUTHORIZED"}
        )

    # 频率限制：检查用户最近30秒内是否发过回复
    thirty_seconds_ago = datetime.now(timezone.utc) - timedelta(seconds=30)
    if current_user:
        recent_reply_result = await db.execute(
            select(func.count(models.ForumReply.id))
            .where(
                models.ForumReply.author_id == current_user.id,
                models.ForumReply.created_at >= thirty_seconds_ago
            )
        )
    else:
        recent_reply_result = await db.execute(
            select(func.count(models.ForumReply.id))
            .where(
                models.ForumReply.admin_author_id == admin_user.id,
                models.ForumReply.created_at >= thirty_seconds_ago
            )
        )
    recent_reply_count = recent_reply_result.scalar() or 0
    if recent_reply_count > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="回复频率限制：最多1条/30秒",
            headers={"X-Error-Code": "RATE_LIMIT_EXCEEDED"}
        )

    # 重复内容检测：检查用户最近2分钟内是否在同一帖子下发过相同内容的回复
    two_minutes_ago = datetime.now(timezone.utc) - timedelta(minutes=2)
    if current_user:
        duplicate_reply_result = await db.execute(
            select(models.ForumReply)
            .where(
                models.ForumReply.author_id == current_user.id,
                models.ForumReply.post_id == post_id,
                models.ForumReply.content == reply.content,
                models.ForumReply.created_at >= two_minutes_ago
            )
            .limit(1)
        )
    else:
        duplicate_reply_result = await db.execute(
            select(models.ForumReply)
            .where(
                models.ForumReply.admin_author_id == admin_user.id,
                models.ForumReply.post_id == post_id,
                models.ForumReply.content == reply.content,
                models.ForumReply.created_at >= two_minutes_ago
            )
            .limit(1)
        )
    duplicate_reply = duplicate_reply_result.scalar_one_or_none()
    if duplicate_reply:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您最近2分钟内已在该帖子下发过相同内容的回复，请勿重复发布",
            headers={"X-Error-Code": "DUPLICATE_REPLY"}
        )

    # Content filtering
    reply_filter_user_id = current_user.id if current_user else admin_user.id
    content_result = await check_content(db, reply.content, "forum_reply", reply_filter_user_id)

    # 保存原文(用于 mask_record),mask 会改写 reply.content
    original_reply_content = reply.content

    if content_result.action == "mask":
        reply.content = content_result.cleaned_text

    # 获取帖子（使用权限检查函数）
    post = await get_post_with_permissions(post_id, current_user, is_admin_user, db, admin_user)

    # 检查帖子所属板块的可见性（学校板块需要权限）
    # 管理员可以绕过权限检查
    if not is_admin_user:
        await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

    # 检查帖子是否锁定
    if post.is_locked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="帖子已锁定，无法回复",
            headers={"X-Error-Code": "POST_LOCKED"}
        )

    # 校验父回复存在性 + 同帖归属（扁平化模型下不再有层级上限）
    if reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
        )
        parent_reply = parent_result.scalar_one_or_none()

        if not parent_reply:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="父回复不存在"
            )

        if parent_reply.post_id != post_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="父回复不属于该帖子"
            )

    # 创建回复
    db_reply = models.ForumReply(
        post_id=post_id,
        content=reply.content,
        parent_reply_id=reply.parent_reply_id,
        author_id=current_user.id if current_user else None,
        admin_author_id=admin_user.id if admin_user else None
    )
    db.add(db_reply)
    await db.flush()

    # Content filter: handle review / visibility
    if content_result.action == "review":
        db_reply.is_visible = False
        await create_review(db, "forum_reply", db_reply.id, reply_filter_user_id,
                           reply.content, content_result.matched_words)
        await db.flush()
    elif content_result.action == "mask":
        await create_mask_record(db, "forum_reply", db_reply.id, reply_filter_user_id,
                                {"content": original_reply_content}, content_result.matched_words)
        await db.flush()

    # 更新帖子统计（仅当回复可见时）
    if db_reply.is_deleted == False and db_reply.is_visible == True:
        post.reply_count += 1
        post.last_reply_at = get_utc_time()
        await db.flush()

    await db.commit()
    await db.refresh(db_reply, ["author", "admin_author"])

    try:
        from app.cache import invalidate_cache
        invalidate_cache("forum_replies*")
    except Exception as e:
        logger.warning("invalidate forum_replies cache: %s", e)

    # 发送通知给帖子作者和父回复作者
    notifications_to_create = []

    # 通知帖子作者（如果回复者不是帖子作者）
    # 注意：只通知普通用户作者，管理员作者不接收通知（因为通知系统只支持普通用户）
    if post.author_id and (not current_user or post.author_id != current_user.id):
        notifications_to_create.append(
            models.ForumNotification(
                notification_type="reply_post",
                target_type="reply",
                target_id=db_reply.id,
                from_user_id=current_user.id if current_user else None,
                to_user_id=post.author_id
            )
        )

    # 通知父回复作者（如果有父回复，且回复者不是父回复作者）
    if reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
        )
        parent_reply = parent_result.scalar_one()
        # 只通知普通用户作者，管理员作者不接收通知
        if (parent_reply.author_id and
            (not current_user or parent_reply.author_id != current_user.id) and
            parent_reply.author_id != post.author_id):
            notifications_to_create.append(
                models.ForumNotification(
                    notification_type="reply_reply",
                    target_type="reply",
                    target_id=db_reply.id,
                    from_user_id=current_user.id if current_user else None,
                    to_user_id=parent_reply.author_id
                )
            )

    # 批量创建通知
    if notifications_to_create:
        for notification in notifications_to_create:
            db.add(notification)
        await db.commit()

        # 发送推送通知
        for notification in notifications_to_create:
            # 获取通知类型对应的标题和内容
            # 使用模板生成推送通知
            user_name = current_user.name if current_user else "用户"
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=notification.to_user_id,
                    title=None,  # 从模板生成
                    body=None,  # 从模板生成
                    notification_type=notification.notification_type,
                    data={
                        "post_id": post_id,
                        "reply_id": db_reply.id
                    },
                    template_vars={"user_name": user_name}
                )
            except Exception as e:
                logger.warning(f"发送论坛回复推送通知失败: {e}")
                # 推送通知失败不影响主流程

    # 预加载勋章缓存（包含当前回复作者和可能的父回复作者）
    _reply_badge_ids = [db_reply.author_id] if db_reply.author_id else []
    parent_reply_author = None
    if db_reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply)
            .where(models.ForumReply.id == db_reply.parent_reply_id)
            .options(
                selectinload(models.ForumReply.author),
                selectinload(models.ForumReply.admin_author),
            )
        )
        parent_reply = parent_result.scalar_one_or_none()
        if parent_reply:
            if parent_reply.author_id:
                _reply_badge_ids.append(parent_reply.author_id)
            _badge_cache = await preload_badge_cache(db, list(set(_reply_badge_ids)))
            parent_reply_author = await get_reply_author_info(db, parent_reply, request, _badge_cache=_badge_cache)
        else:
            _badge_cache = await preload_badge_cache(db, _reply_badge_ids)
    else:
        _badge_cache = await preload_badge_cache(db, _reply_badge_ids)

    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        parent_reply_author=parent_reply_author,
        like_count=db_reply.like_count,
        is_liked=False,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
    )


@router.put("/replies/{reply_id}", response_model=schemas.ForumReplyOut)
async def update_reply(
    reply_id: int,
    reply: schemas.ForumReplyUpdate,
    request: Request,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新回复"""
    result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply_id)
    )
    db_reply = result.scalar_one_or_none()

    if not db_reply:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复不存在"
        )

    # 尝试获取管理员会话
    admin_user = None
    is_admin_user = False
    try:
        admin_user = await get_current_admin_async(request, db)
        if admin_user:
            is_admin_user = True
    except HTTPException:
        pass

    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息"
        )

    # 检查权限：作者或对应管理员可以编辑
    is_author = current_user and db_reply.author_id == current_user.id
    is_admin_author = admin_user and db_reply.admin_author_id == admin_user.id
    if not is_author and not is_admin_author:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="只能编辑自己的回复"
        )

    # 检查是否已删除
    if db_reply.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复已删除"
        )

    # 检查回复所属帖子所属板块的可见性（学校板块需要权限）
    # 确保用户有权限访问该回复所属的板块
    post_result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == db_reply.post_id)
    )
    post = post_result.scalar_one_or_none()

    if post:
        # 检查是否有管理员会话
        # 检查帖子所属板块的可见性（学校板块需要权限）
        # 管理员可以绕过权限检查
        if not is_admin_user and current_user:
            await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

    # 更新内容
    db_reply.content = reply.content
    db_reply.updated_at = get_utc_time()

    await db.commit()
    await db.refresh(db_reply, ["author", "admin_author"])

    # 检查是否已点赞
    is_liked = False
    if current_user:
        like_result = await db.execute(
            select(models.ForumLike).where(
                models.ForumLike.target_type == "reply",
                models.ForumLike.target_id == db_reply.id,
                models.ForumLike.user_id == current_user.id
            )
        )
        is_liked = like_result.scalar_one_or_none() is not None

    _badge_cache = await preload_badge_cache(db, [db_reply.author_id] if db_reply.author_id else [])
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        like_count=db_reply.like_count,
        is_liked=is_liked,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
    )


@router.delete("/replies/{reply_id}")
async def delete_reply(
    reply_id: int,
    request: Request,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除回复（软删除）"""
    result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply_id)
    )
    db_reply = result.scalar_one_or_none()

    if not db_reply:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复不存在"
        )

    # 获取管理员会话（用于管理员回复）
    admin_user = None
    try:
        admin_user = await get_current_admin_async(request, db)
    except HTTPException:
        pass

    if not current_user and not admin_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的认证信息"
        )

    # 检查权限：作者或管理员作者可以删除
    is_author = current_user and db_reply.author_id == current_user.id
    is_admin_author = admin_user and db_reply.admin_author_id == admin_user.id
    if not is_author and not is_admin_author:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="只能删除自己的回复"
        )

    # 检查是否已删除
    if db_reply.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="回复已删除"
        )

    # 获取帖子
    post_result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == db_reply.post_id)
    )
    post = post_result.scalar_one()

    # 软删除
    old_is_visible = db_reply.is_visible
    db_reply.is_deleted = True
    db_reply.updated_at = get_utc_time()
    await db.flush()

    # 更新帖子统计（仅当原回复可见时）
    if old_is_visible:
        post.reply_count = max(0, post.reply_count - 1)
        # 重新计算 last_reply_at
        last_reply_result = await db.execute(
            select(models.ForumReply.created_at)
            .where(models.ForumReply.post_id == post.id)
            .where(models.ForumReply.is_deleted == False)
            .where(models.ForumReply.is_visible == True)
            .order_by(models.ForumReply.created_at.desc())
            .limit(1)
        )
        last_reply = last_reply_result.scalar_one_or_none()
        post.last_reply_at = last_reply if last_reply else post.created_at
        await db.flush()

    await db.commit()

    return {"message": "回复删除成功"}


@router.post("/replies/{reply_id}/restore")
async def restore_reply(
    reply_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """恢复回复（管理员）"""
    result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply_id)
    )
    reply = result.scalar_one_or_none()

    if not reply:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复不存在"
        )

    if not reply.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="回复未被删除"
        )

    # 恢复回复
    old_is_visible = reply.is_visible
    reply.is_deleted = False
    reply.updated_at = get_utc_time()
    await db.flush()

    # 更新帖子统计（仅当恢复后可见时）
    if reply.is_visible:
        post_result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == reply.post_id)
        )
        post = post_result.scalar_one()
        post.reply_count += 1
        # 重新计算 last_reply_at
        last_reply_result = await db.execute(
            select(models.ForumReply.created_at)
            .where(models.ForumReply.post_id == post.id)
            .where(models.ForumReply.is_deleted == False)
            .where(models.ForumReply.is_visible == True)
            .order_by(models.ForumReply.created_at.desc())
            .limit(1)
        )
        last_reply = last_reply_result.scalar_one_or_none()
        post.last_reply_at = last_reply if last_reply else post.created_at
        await db.flush()

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="restore_reply",
        target_type="reply",
        target_id=reply_id,
        action="restore",
        request=request,
        db=db
    )

    await db.commit()

    return {"id": reply.id, "is_deleted": False, "message": "回复已恢复"}

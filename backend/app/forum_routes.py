"""
论坛功能路由
实现论坛板块、帖子、回复、点赞、收藏、搜索、通知、举报等功能
"""

from typing import List, Optional
from datetime import datetime, timezone, timedelta
import re
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func, or_, and_, desc, asc, case, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


# ==================== 辅助函数 ====================

async def log_admin_operation(
    operator_id: str,
    operation_type: str,
    target_type: str,
    target_id: int,
    action: str,
    reason: Optional[str] = None,
    request: Optional[Request] = None,
    db: Optional[AsyncSession] = None
):
    """记录管理员操作日志"""
    if not db:
        return
    
    # 获取目标标题（用于日志查询）
    target_title = None
    if target_type == 'post':
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == target_id)
        )
        post = result.scalar_one_or_none()
        target_title = post.title if post else None
    elif target_type == 'reply':
        result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == target_id)
        )
        reply = result.scalar_one_or_none()
        target_title = reply.content[:100] if reply else None  # 截取前100字符
    
    # 获取IP和User-Agent
    ip_address = None
    user_agent = None
    if request:
        ip_address = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent")
    
    # 创建日志记录
    log = models.ForumAdminOperationLog(
        operator_id=operator_id,
        operation_type=operation_type,
        target_type=target_type,
        target_id=target_id,
        target_title=target_title,
        action=action,
        reason=reason,
        ip_address=ip_address,
        user_agent=user_agent
    )
    db.add(log)
    await db.flush()


async def check_and_trigger_risk_control(
    target_type: str,
    target_id: int,
    db: AsyncSession
):
    """检查并触发风控（当举报达到阈值时自动执行）"""
    # 1. 查找匹配的规则
    rule_result = await db.execute(
        select(models.ForumRiskControlRule)
        .where(
            models.ForumRiskControlRule.target_type == target_type,
            models.ForumRiskControlRule.is_enabled == True
        )
        .order_by(models.ForumRiskControlRule.trigger_count.desc())
        .limit(1)
    )
    rule = rule_result.scalar_one_or_none()
    
    if not rule:
        return  # 没有启用的规则
    
    # 2. 使用规则中配置的时间窗口（小时）
    time_window = timedelta(hours=rule.trigger_time_window)
    cutoff_time = datetime.now(timezone.utc) - time_window
    
    # 3. 统计时间窗口内的举报数
    report_count_result = await db.execute(
        select(func.count(models.ForumReport.id))
        .where(
            models.ForumReport.target_type == target_type,
            models.ForumReport.target_id == target_id,
            models.ForumReport.status == 'pending',
            models.ForumReport.created_at >= cutoff_time
        )
    )
    report_count = report_count_result.scalar() or 0
    
    # 4. 检查是否达到规则阈值
    if report_count < rule.trigger_count:
        return  # 未达到触发阈值
    
    # 5. 执行风控动作
    action_result = "success"
    try:
        if rule.action_type == 'hide':
            if target_type == 'post':
                # 获取帖子信息以更新统计
                post_result = await db.execute(
                    select(models.ForumPost).where(models.ForumPost.id == target_id)
                )
                post = post_result.scalar_one_or_none()
                if post and not post.is_deleted:
                    # 更新帖子可见性
                    await db.execute(
                        update(models.ForumPost)
                        .where(models.ForumPost.id == target_id)
                        .values(is_visible=False)
                    )
                    # 更新板块统计
                    await update_category_stats(post.category_id, db)
            else:  # reply
                # 获取回复信息以更新统计
                reply_result = await db.execute(
                    select(models.ForumReply).where(models.ForumReply.id == target_id)
                )
                reply = reply_result.scalar_one_or_none()
                if reply and not reply.is_deleted:
                    # 更新回复可见性
                    await db.execute(
                        update(models.ForumReply)
                        .where(models.ForumReply.id == target_id)
                        .values(is_visible=False)
                    )
                    # 更新帖子统计
                    post_result = await db.execute(
                        select(models.ForumPost).where(models.ForumPost.id == reply.post_id)
                    )
                    post = post_result.scalar_one_or_none()
                    if post:
                        post.reply_count = max(0, post.reply_count - 1)
                        await db.flush()
        
        elif rule.action_type == 'lock':
            if target_type == 'post':
                await db.execute(
                    update(models.ForumPost)
                    .where(models.ForumPost.id == target_id)
                    .values(is_locked=True)
                )
            # 回复不支持锁定
        
        elif rule.action_type == 'soft_delete':
            if target_type == 'post':
                # 获取帖子信息以更新统计
                post_result = await db.execute(
                    select(models.ForumPost).where(models.ForumPost.id == target_id)
                )
                post = post_result.scalar_one_or_none()
                if post and post.is_visible and not post.is_deleted:
                    # 更新帖子删除状态
                    await db.execute(
                        update(models.ForumPost)
                        .where(models.ForumPost.id == target_id)
                        .values(is_deleted=True)
                    )
                    # 更新板块统计
                    await update_category_stats(post.category_id, db)
            else:  # reply
                # 获取回复信息以更新统计
                reply_result = await db.execute(
                    select(models.ForumReply).where(models.ForumReply.id == target_id)
                )
                reply = reply_result.scalar_one_or_none()
                if reply and reply.is_visible and not reply.is_deleted:
                    # 更新回复删除状态
                    await db.execute(
                        update(models.ForumReply)
                        .where(models.ForumReply.id == target_id)
                        .values(is_deleted=True)
                    )
                    # 更新帖子统计
                    post_result = await db.execute(
                        select(models.ForumPost).where(models.ForumPost.id == reply.post_id)
                    )
                    post = post_result.scalar_one_or_none()
                    if post:
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
        
        elif rule.action_type == 'notify_admin':
            # 仅通知管理员，不自动处理
            # 这里可以发送通知给管理员，暂时只记录日志
            pass
        
        await db.flush()
        
    except Exception as e:
        logger.error(f"风控动作执行失败: {e}")
        action_result = "failed"
    
    # 6. 记录执行日志
    log = models.ForumRiskControlLog(
        target_type=target_type,
        target_id=target_id,
        rule_id=rule.id,
        trigger_count=report_count,
        action_type=rule.action_type,
        action_result=action_result,
        executed_by=None  # 系统自动执行
    )
    db.add(log)
    await db.flush()

router = APIRouter(prefix="/api/forum", tags=["论坛"])


# ==================== 认证依赖 ====================

async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


async def get_current_user_optional(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> Optional[models.User]:
    """可选用户认证（异步版本）"""
    try:
        return await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        return None


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
            detail="管理员认证失败，请重新登录"
        )
    
    # 获取管理员信息（异步）
    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在"
        )
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    return admin


# ==================== 工具函数 ====================

def strip_markdown(text: str, max_length: int = 200) -> str:
    """去除 Markdown 标记并截断文本"""
    # 简单的 Markdown 去除（移除常见标记）
    text = re.sub(r'#{1,6}\s+', '', text)  # 标题
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # 粗体
    text = re.sub(r'\*([^*]+)\*', r'\1', text)  # 斜体
    text = re.sub(r'`([^`]+)`', r'\1', text)  # 行内代码
    text = re.sub(r'```[\s\S]*?```', '', text)  # 代码块
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)  # 链接
    text = re.sub(r'!\[([^\]]*)\]\([^\)]+\)', '', text)  # 图片
    text = re.sub(r'\n+', ' ', text)  # 换行符
    text = text.strip()
    
    if len(text) > max_length:
        return text[:max_length] + "..."
    return text


async def get_post_with_permissions(
    post_id: int,
    current_user: Optional[models.User],
    is_admin: bool,
    db: AsyncSession
) -> models.ForumPost:
    """获取帖子并检查权限（处理软删除和隐藏）"""
    result = await db.execute(
        select(models.ForumPost)
        .options(
            selectinload(models.ForumPost.category),
            selectinload(models.ForumPost.author)
        )
        .where(models.ForumPost.id == post_id)
        .where(models.ForumPost.is_deleted == False)
    )
    post = result.scalar_one_or_none()
    
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在或已删除",
            headers={"X-Error-Code": "POST_DELETED"}
        )
    
    # 检查风控隐藏：普通用户不可见，但作者和管理员可见
    if not post.is_visible:
        if not is_admin and (not current_user or post.author_id != current_user.id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在或已被隐藏",
                headers={"X-Error-Code": "POST_HIDDEN"}
            )
    
    return post


async def update_category_stats(category_id: int, db: AsyncSession):
    """更新板块统计信息"""
    # 统计可见帖子数
    post_count_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(models.ForumPost.category_id == category_id)
        .where(models.ForumPost.is_deleted == False)
        .where(models.ForumPost.is_visible == True)
    )
    post_count = post_count_result.scalar() or 0
    
    # 获取最新帖子时间
    last_post_result = await db.execute(
        select(
            func.coalesce(
                models.ForumPost.last_reply_at,
                models.ForumPost.created_at
            ).label("last_activity")
        )
        .where(models.ForumPost.category_id == category_id)
        .where(models.ForumPost.is_deleted == False)
        .where(models.ForumPost.is_visible == True)
        .order_by(
            func.coalesce(
                models.ForumPost.last_reply_at,
                models.ForumPost.created_at
            ).desc()
        )
        .limit(1)
    )
    last_post_row = last_post_result.first()
    last_post_at = last_post_row[0] if last_post_row else None
    
    # 更新板块统计
    category_result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = category_result.scalar_one()
    category.post_count = post_count
    category.last_post_at = last_post_at
    await db.flush()


# ==================== 板块 API ====================

@router.get("/categories", response_model=schemas.ForumCategoryListResponse)
async def get_categories(
    include_latest_post: bool = Query(False, description="是否包含每个板块的最新帖子信息"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块列表
    
    可选参数：
    - include_latest_post: 如果为 True，每个板块会包含最新帖子的简要信息（标题、作者、最后回复时间等）
    """
    result = await db.execute(
        select(models.ForumCategory)
        .where(models.ForumCategory.is_visible == True)
        .order_by(models.ForumCategory.sort_order.asc(), models.ForumCategory.id.asc())
    )
    categories = result.scalars().all()
    
    # 如果需要包含最新帖子信息，需要手动构建响应
    if include_latest_post:
        category_list = []
        for category in categories:
            # 实时统计可见帖子数（确保与 latest_post 查询条件一致）
            post_count_result = await db.execute(
                select(func.count(models.ForumPost.id))
                .where(
                    models.ForumPost.category_id == category.id,
                    models.ForumPost.is_deleted == False,
                    models.ForumPost.is_visible == True
                )
            )
            real_post_count = post_count_result.scalar() or 0
            
            # 获取该板块的最新帖子
            latest_post_result = await db.execute(
                select(models.ForumPost)
                .where(
                    models.ForumPost.category_id == category.id,
                    models.ForumPost.is_deleted == False,
                    models.ForumPost.is_visible == True
                )
                .order_by(
                    func.coalesce(
                        models.ForumPost.last_reply_at,
                        models.ForumPost.created_at
                    ).desc()
                )
                .limit(1)
                .options(
                    selectinload(models.ForumPost.author)
                )
            )
            latest_post = latest_post_result.scalar_one_or_none()
            
            # 构建板块信息（使用 Pydantic 模型）
            category_out = schemas.ForumCategoryOut(
                id=category.id,
                name=category.name,
                description=category.description,
                icon=category.icon,
                sort_order=category.sort_order,
                is_visible=category.is_visible,
                post_count=real_post_count,  # 使用实时统计的帖子数
                last_post_at=category.last_post_at,
                created_at=category.created_at,
                updated_at=category.updated_at
            )
            
            # 将 Pydantic 模型转换为字典，以便添加额外字段
            category_dict = category_out.model_dump()
            
            # 添加最新帖子信息（如果存在）
            if latest_post:
                category_dict["latest_post"] = {
                    "id": latest_post.id,
                    "title": latest_post.title,
                    "author": {
                        "id": latest_post.author.id,
                        "name": latest_post.author.name,
                        "avatar": latest_post.author.avatar or None
                    } if latest_post.author else None,
                    "last_reply_at": latest_post.last_reply_at or latest_post.created_at,
                    "reply_count": latest_post.reply_count,
                    "view_count": latest_post.view_count
                }
            else:
                category_dict["latest_post"] = None
            
            category_list.append(category_dict)
        
        # 返回包含最新帖子信息的列表（注意：这会改变响应模型，但为了功能完整性暂时这样实现）
        return {"categories": category_list}
    
    # 标准返回（不包含最新帖子信息）
    return {"categories": categories}


@router.get("/categories/{category_id}", response_model=schemas.ForumCategoryOut)
async def get_category(
    category_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块详情"""
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()
    
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )
    
    return category


@router.post("/categories", response_model=schemas.ForumCategoryOut)
async def create_category(
    category: schemas.ForumCategoryCreate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建板块（管理员）"""
    # 检查名称是否已存在
    existing = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.name == category.name)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="板块名称已存在"
        )
    
    db_category = models.ForumCategory(**category.model_dump())
    db.add(db_category)
    await db.flush()
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
        operation_type="create_category",
        target_type="category",
        target_id=db_category.id,
        action="create",
        request=request,
        db=db
    )
    
    await db.commit()
    await db.refresh(db_category)
    
    return db_category


@router.put("/categories/{category_id}", response_model=schemas.ForumCategoryOut)
async def update_category(
    category_id: int,
    category: schemas.ForumCategoryUpdate,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新板块（管理员）"""
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    db_category = result.scalar_one_or_none()
    
    if not db_category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )
    
    # 如果更新名称，检查是否重复
    if category.name and category.name != db_category.name:
        existing = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.name == category.name)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="板块名称已存在"
            )
    
    # 更新字段
    update_data = category.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_category, field, value)
    
    db_category.updated_at = get_utc_time()
    await db.flush()
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
        operation_type="update_category",
        target_type="category",
        target_id=category_id,
        action="update",
        request=request,
        db=db
    )
    
    await db.commit()
    await db.refresh(db_category)
    
    return db_category


@router.delete("/categories/{category_id}")
async def delete_category(
    category_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除板块（管理员）"""
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()
    
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )
    
    # 记录管理员操作日志（在删除前记录）
    await log_admin_operation(
        operator_id=current_admin.user_id,
        operation_type="delete_category",
        target_type="category",
        target_id=category_id,
        action="delete",
        request=request,
        db=db
    )
    
    await db.delete(category)
    await db.commit()
    
    return {"message": "板块删除成功"}


# ==================== 帖子 API ====================

@router.get("/posts", response_model=schemas.ForumPostListResponse)
async def get_posts(
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort: str = Query("last_reply", regex="^(latest|last_reply|hot|replies|likes)$"),
    q: Optional[str] = Query(None),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子列表"""
    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 板块筛选
    if category_id:
        query = query.where(models.ForumPost.category_id == category_id)
    
    # 搜索关键词（简单 LIKE 查询）
    if q:
        query = query.where(
            or_(
                models.ForumPost.title.ilike(f"%{q}%"),
                models.ForumPost.content.ilike(f"%{q}%")
            )
        )
    
    # 排序
    if sort == "latest":
        query = query.order_by(models.ForumPost.created_at.desc())
    elif sort == "last_reply":
        query = query.order_by(
            func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at).desc()
        )
    elif sort == "hot":
        # 热度排序：综合评分公式
        hot_score = (
            models.ForumPost.like_count * 5.0 +
            models.ForumPost.reply_count * 3.0 +
            models.ForumPost.view_count * 0.1
        ) / func.pow(
            func.extract('epoch', func.now() - models.ForumPost.created_at) / 3600.0 + 2.0,
            1.5
        )
        query = query.order_by(hot_score.desc())
    elif sort == "replies":
        query = query.order_by(models.ForumPost.reply_count.desc())
    elif sort == "likes":
        query = query.order_by(models.ForumPost.like_count.desc())
    
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
        selectinload(models.ForumPost.author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()
    
    # 转换为列表项格式
    post_items = []
    for post in posts:
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
        
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
            author=schemas.UserInfo(
                id=post.author.id,
                name=post.author.name,
                avatar=post.author.avatar or None
            ),
            view_count=post.view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at
        ))
    
    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/posts/{post_id}", response_model=schemas.ForumPostOut)
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
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    # 获取帖子
    post = await get_post_with_permissions(post_id, current_user, is_admin, db)
    
    # 增加浏览次数
    # 优化方案：使用 Redis 累加，定时批量落库（由 Celery 任务处理）
    # 当前实现：如果 Redis 可用则使用 Redis，否则直接更新数据库
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            # 使用 Redis 累加浏览数（存储增量）
            redis_key = f"forum:post:view_count:{post_id}"
            redis_client.incr(redis_key)
            # 设置过期时间（7天），防止 key 无限增长
            redis_client.expire(redis_key, 7 * 24 * 3600)
            # 注意：返回给用户的浏览数使用数据库中的值
            # Redis 中的增量会由后台任务定期同步到数据库
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
    
    return schemas.ForumPostOut(
        id=post.id,
        title=post.title,
        content=post.content,
        category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
        author=schemas.UserInfo(
            id=post.author.id,
            name=post.author.name,
            avatar=post.author.avatar or None
        ),
        view_count=post.view_count,
        reply_count=post.reply_count,
        like_count=post.like_count,
        favorite_count=post.favorite_count,
        is_pinned=post.is_pinned,
        is_featured=post.is_featured,
        is_locked=post.is_locked,
        is_liked=is_liked,
        is_favorited=is_favorited,
        created_at=post.created_at,
        updated_at=post.updated_at,
        last_reply_at=post.last_reply_at
    )


@router.post("/posts", response_model=schemas.ForumPostOut)
async def create_post(
    post: schemas.ForumPostCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建帖子"""
    # 频率限制：检查用户最近1分钟内是否发过帖子
    one_minute_ago = datetime.now(timezone.utc) - timedelta(minutes=1)
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
    
    # 验证板块是否存在
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
    
    # 检查板块是否可见
    if not category.is_visible:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="该板块已隐藏",
            headers={"X-Error-Code": "CATEGORY_HIDDEN"}
        )
    
    # 检查板块是否禁止用户发帖
    if category.is_admin_only:
        # 检查用户是否为管理员
        is_admin = False
        try:
            admin_user = await get_current_admin_async(request, db)
            if admin_user:
                is_admin = True
        except HTTPException:
            pass
        
        if not is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="该板块只允许管理员发帖",
                headers={"X-Error-Code": "ADMIN_ONLY_CATEGORY"}
            )
    
    # 创建帖子
    db_post = models.ForumPost(
        title=post.title,
        content=post.content,
        category_id=post.category_id,
        author_id=current_user.id
    )
    db.add(db_post)
    await db.flush()
    
    # 更新板块统计（仅当帖子可见时）
    if db_post.is_deleted == False and db_post.is_visible == True:
        category.post_count += 1
        category.last_post_at = get_utc_time()
        await db.flush()
    
    await db.commit()
    await db.refresh(db_post)
    
    # 加载关联数据
    await db.refresh(db_post, ["category", "author"])
    
    return schemas.ForumPostOut(
        id=db_post.id,
        title=db_post.title,
        content=db_post.content,
        category=schemas.CategoryInfo(id=db_post.category.id, name=db_post.category.name),
        author=schemas.UserInfo(
            id=db_post.author.id,
            name=db_post.author.name,
            avatar=db_post.author.avatar or None
        ),
        view_count=db_post.view_count,
        reply_count=db_post.reply_count,
        like_count=db_post.like_count,
        favorite_count=db_post.favorite_count,
        is_pinned=db_post.is_pinned,
        is_featured=db_post.is_featured,
        is_locked=db_post.is_locked,
        is_liked=False,
        is_favorited=False,
        created_at=db_post.created_at,
        updated_at=db_post.updated_at,
        last_reply_at=db_post.last_reply_at
    )


@router.put("/posts/{post_id}", response_model=schemas.ForumPostOut)
async def update_post(
    post_id: int,
    post: schemas.ForumPostUpdate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """更新帖子"""
    # 获取帖子
    result = await db.execute(
        select(models.ForumPost)
        .options(
            selectinload(models.ForumPost.category),
            selectinload(models.ForumPost.author)
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
    
    for field, value in update_data.items():
        setattr(db_post, field, value)
    
    db_post.updated_at = get_utc_time()
    await db.flush()
    
    # 如果板块改变或可见性改变，更新统计
    if "category_id" in update_data or "is_visible" in update_data:
        # 更新旧板块统计
        if old_category_id:
            await update_category_stats(old_category_id, db)
        # 更新新板块统计
        if db_post.category_id:
            await update_category_stats(db_post.category_id, db)
    
    await db.commit()
    await db.refresh(db_post, ["category", "author"])
    
    # 检查是否已点赞/收藏
    is_liked = False
    is_favorited = False
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
    
    return schemas.ForumPostOut(
        id=db_post.id,
        title=db_post.title,
        content=db_post.content,
        category=schemas.CategoryInfo(id=db_post.category.id, name=db_post.category.name),
        author=schemas.UserInfo(
            id=db_post.author.id,
            name=db_post.author.name,
            avatar=db_post.author.avatar or None
        ),
        view_count=db_post.view_count,
        reply_count=db_post.reply_count,
        like_count=db_post.like_count,
        favorite_count=db_post.favorite_count,
        is_pinned=db_post.is_pinned,
        is_featured=db_post.is_featured,
        is_locked=db_post.is_locked,
        is_liked=is_liked,
        is_favorited=is_favorited,
        created_at=db_post.created_at,
        updated_at=db_post.updated_at,
        last_reply_at=db_post.last_reply_at
    )


@router.delete("/posts/{post_id}")
async def delete_post(
    post_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除帖子（软删除）"""
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
    
    return {"message": "帖子删除成功"}


# ==================== 帖子管理 API（管理员）====================

@router.post("/posts/{post_id}/pin")
async def pin_post(
    post_id: int,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """置顶帖子（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
        operation_type="pin_post",
        target_type="post",
        target_id=post_id,
        action="pin",
        request=request,
        db=db
    )
    
    # 发送通知给帖子作者
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
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消置顶（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
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
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """加精帖子（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
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
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消加精（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
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
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """锁定帖子（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
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
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """解锁帖子（管理员）"""
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
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
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
        operator_id=current_admin.user_id,
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
        operator_id=current_admin.user_id,
        operation_type="unhide_post",
        target_type="post",
        target_id=post_id,
        action="unhide",
        request=request,
        db=db
    )
    
    await db.commit()
    
    return {"id": post.id, "is_visible": True, "message": "帖子已取消隐藏"}


# ==================== 回复 API ====================

@router.get("/posts/{post_id}/replies", response_model=schemas.ForumReplyListResponse)
async def get_replies(
    post_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    request: Request = None,
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
    
    # 验证帖子存在且可见
    post = await get_post_with_permissions(post_id, current_user, is_admin, db)
    
    # 构建查询：只获取可见回复
    query = select(models.ForumReply).where(
        models.ForumReply.post_id == post_id,
        models.ForumReply.is_deleted == False
    )
    
    # 如果不是管理员且不是作者，过滤隐藏的回复
    if not is_admin and (not current_user or post.author_id != current_user.id):
        query = query.where(models.ForumReply.is_visible == True)
    
    query = query.order_by(models.ForumReply.created_at.asc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumReply.author),
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
    
    def convert_reply(reply_data, liked_set):
        """递归转换回复为输出格式"""
        reply = reply_data["reply"]
        is_liked = reply.id in liked_set
        
        reply_out = schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=schemas.UserInfo(
                id=reply.author.id,
                name=reply.author.name,
                avatar=reply.author.avatar or None
            ),
            parent_reply_id=reply.parent_reply_id,
            reply_level=reply.reply_level,
            like_count=reply.like_count,
            is_liked=is_liked,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
            replies=[]
        )
        
        # 递归处理子回复
        for child_data in reply_data["children"]:
            reply_out.replies.append(convert_reply(child_data, liked_set))
        
        return reply_out
    
    reply_list = [convert_reply(item, user_liked_replies) for item in reply_tree]
    
    return {
        "replies": reply_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.post("/posts/{post_id}/replies", response_model=schemas.ForumReplyOut)
async def create_reply(
    post_id: int,
    reply: schemas.ForumReplyCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建回复"""
    # 频率限制：检查用户最近30秒内是否发过回复
    thirty_seconds_ago = datetime.now(timezone.utc) - timedelta(seconds=30)
    recent_reply_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(
            models.ForumReply.author_id == current_user.id,
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
    duplicate_reply = duplicate_reply_result.scalar_one_or_none()
    if duplicate_reply:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您最近2分钟内已在该帖子下发过相同内容的回复，请勿重复发布",
            headers={"X-Error-Code": "DUPLICATE_REPLY"}
        )
    
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    # 获取帖子（使用权限检查函数）
    post = await get_post_with_permissions(post_id, current_user, is_admin, db)
    
    # 检查帖子是否锁定
    if post.is_locked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="帖子已锁定，无法回复",
            headers={"X-Error-Code": "POST_LOCKED"}
        )
    
    # 如果是指定父回复，检查层级
    reply_level = 1
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
        
        if parent_reply.reply_level >= 3:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="回复层级最多三层",
                headers={"X-Error-Code": "REPLY_LEVEL_LIMIT"}
            )
        
        reply_level = parent_reply.reply_level + 1
    
    # 创建回复
    db_reply = models.ForumReply(
        post_id=post_id,
        content=reply.content,
        parent_reply_id=reply.parent_reply_id,
        reply_level=reply_level,
        author_id=current_user.id
    )
    db.add(db_reply)
    await db.flush()
    
    # 更新帖子统计（仅当回复可见时）
    if db_reply.is_deleted == False and db_reply.is_visible == True:
        post.reply_count += 1
        post.last_reply_at = get_utc_time()
        await db.flush()
    
    await db.commit()
    await db.refresh(db_reply, ["author"])
    
    # 发送通知给帖子作者和父回复作者
    notifications_to_create = []
    
    # 通知帖子作者（如果回复者不是帖子作者）
    if post.author_id != current_user.id:
        notifications_to_create.append(
            models.ForumNotification(
                notification_type="reply_post",
                target_type="reply",
                target_id=db_reply.id,
                from_user_id=current_user.id,
                to_user_id=post.author_id
            )
        )
    
    # 通知父回复作者（如果有父回复，且回复者不是父回复作者）
    if reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
        )
        parent_reply = parent_result.scalar_one()
        if parent_reply.author_id != current_user.id and parent_reply.author_id != post.author_id:
            notifications_to_create.append(
                models.ForumNotification(
                    notification_type="reply_reply",
                    target_type="reply",
                    target_id=db_reply.id,
                    from_user_id=current_user.id,
                    to_user_id=parent_reply.author_id
                )
            )
    
    # 批量创建通知
    if notifications_to_create:
        for notification in notifications_to_create:
            db.add(notification)
        await db.commit()
    
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=schemas.UserInfo(
            id=db_reply.author.id,
            name=db_reply.author.name,
            avatar=db_reply.author.avatar or None
        ),
        parent_reply_id=db_reply.parent_reply_id,
        reply_level=db_reply.reply_level,
        like_count=db_reply.like_count,
        is_liked=False,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
        replies=[]
    )


@router.put("/replies/{reply_id}", response_model=schemas.ForumReplyOut)
async def update_reply(
    reply_id: int,
    reply: schemas.ForumReplyUpdate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    
    # 检查权限：只有作者可以编辑
    if db_reply.author_id != current_user.id:
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
    
    # 更新内容
    db_reply.content = reply.content
    db_reply.updated_at = get_utc_time()
    await db.commit()
    await db.refresh(db_reply, ["author"])
    
    # 检查是否已点赞
    is_liked = False
    like_result = await db.execute(
        select(models.ForumLike).where(
            models.ForumLike.target_type == "reply",
            models.ForumLike.target_id == db_reply.id,
            models.ForumLike.user_id == current_user.id
        )
    )
    is_liked = like_result.scalar_one_or_none() is not None
    
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=schemas.UserInfo(
            id=db_reply.author.id,
            name=db_reply.author.name,
            avatar=db_reply.author.avatar or None
        ),
        parent_reply_id=db_reply.parent_reply_id,
        reply_level=db_reply.reply_level,
        like_count=db_reply.like_count,
        is_liked=is_liked,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
        replies=[]
    )


@router.delete("/replies/{reply_id}")
async def delete_reply(
    reply_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
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
    
    # 检查权限：只有作者可以删除
    if db_reply.author_id != current_user.id:
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
        operator_id=current_admin.user_id,
        operation_type="restore_reply",
        target_type="reply",
        target_id=reply_id,
        action="restore",
        request=request,
        db=db
    )
    
    await db.commit()
    
    return {"id": reply.id, "is_deleted": False, "message": "回复已恢复"}


# ==================== 点赞 API ====================

@router.post("/likes", response_model=schemas.ForumLikeResponse)
async def toggle_like(
    like: schemas.ForumLikeRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """点赞/取消点赞"""
    # 验证目标存在
    if like.target_type == "post":
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == like.target_id)
        )
        target = result.scalar_one_or_none()
        if not target or target.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在或已删除"
            )
    else:  # reply
        result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == like.target_id)
        )
        target = result.scalar_one_or_none()
        if not target or target.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="回复不存在或已删除"
            )
    
    # 检查是否已点赞
    existing_like = await db.execute(
        select(models.ForumLike).where(
            models.ForumLike.target_type == like.target_type,
            models.ForumLike.target_id == like.target_id,
            models.ForumLike.user_id == current_user.id
        )
    )
    existing = existing_like.scalar_one_or_none()
    
    if existing:
        # 取消点赞
        await db.delete(existing)
        # 更新点赞数
        if like.target_type == "post":
            target.like_count = max(0, target.like_count - 1)
        else:
            target.like_count = max(0, target.like_count - 1)
        liked = False
    else:
        # 添加点赞
        new_like = models.ForumLike(
            target_type=like.target_type,
            target_id=like.target_id,
            user_id=current_user.id
        )
        db.add(new_like)
        # 更新点赞数
        if like.target_type == "post":
            target.like_count += 1
            # 发送通知给帖子作者（如果点赞者不是作者本人）
            if target.author_id and target.author_id != current_user.id:
                notification = models.ForumNotification(
                    notification_type="like_post",
                    target_type="post",
                    target_id=target.id,
                    from_user_id=current_user.id,
                    to_user_id=target.author_id
                )
                db.add(notification)
        else:
            target.like_count += 1
            # 注意：根据文档，回复点赞不发送通知
        liked = True
    
    await db.commit()
    
    return {
        "liked": liked,
        "like_count": target.like_count
    }


@router.get("/posts/{post_id}/likes", response_model=schemas.ForumLikeListResponse)
async def get_post_likes(
    post_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子点赞列表"""
    # 验证帖子存在
    post_result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == post_id)
    )
    post = post_result.scalar_one_or_none()
    if not post or post.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在或已删除"
        )
    
    # 查询点赞列表
    query = select(models.ForumLike).where(
        models.ForumLike.target_type == "post",
        models.ForumLike.target_id == post_id
    )
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.order_by(models.ForumLike.created_at.desc())
    query = query.offset(offset).limit(page_size)
    
    # 加载用户信息
    query = query.options(selectinload(models.ForumLike.user))
    
    result = await db.execute(query)
    likes = result.scalars().all()
    
    # 转换为输出格式
    like_list = []
    for like in likes:
        like_list.append(schemas.ForumLikeListItem(
            user=schemas.UserInfo(
                id=like.user.id,
                name=like.user.name,
                avatar=like.user.avatar or None
            ),
            created_at=like.created_at
        ))
    
    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/replies/{reply_id}/likes", response_model=schemas.ForumLikeListResponse)
async def get_reply_likes(
    reply_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取回复点赞列表"""
    # 验证回复存在
    reply_result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply_id)
    )
    reply = reply_result.scalar_one_or_none()
    if not reply or reply.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="回复不存在或已删除"
        )
    
    # 查询点赞列表
    query = select(models.ForumLike).where(
        models.ForumLike.target_type == "reply",
        models.ForumLike.target_id == reply_id
    )
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.order_by(models.ForumLike.created_at.desc())
    query = query.offset(offset).limit(page_size)
    
    # 加载用户信息
    query = query.options(selectinload(models.ForumLike.user))
    
    result = await db.execute(query)
    likes = result.scalars().all()
    
    # 转换为输出格式
    like_list = []
    for like in likes:
        like_list.append(schemas.ForumLikeListItem(
            user=schemas.UserInfo(
                id=like.user.id,
                name=like.user.name,
                avatar=like.user.avatar or None
            ),
            created_at=like.created_at
        ))
    
    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 收藏 API ====================

@router.post("/favorites", response_model=schemas.ForumFavoriteResponse)
async def toggle_favorite(
    favorite: schemas.ForumFavoriteRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """收藏/取消收藏"""
    # 验证帖子存在
    result = await db.execute(
        select(models.ForumPost).where(models.ForumPost.id == favorite.post_id)
    )
    post = result.scalar_one_or_none()
    
    if not post or post.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="帖子不存在或已删除"
        )
    
    # 检查是否已收藏
    existing_favorite = await db.execute(
        select(models.ForumFavorite).where(
            models.ForumFavorite.post_id == favorite.post_id,
            models.ForumFavorite.user_id == current_user.id
        )
    )
    existing = existing_favorite.scalar_one_or_none()
    
    if existing:
        # 取消收藏
        await db.delete(existing)
        post.favorite_count = max(0, post.favorite_count - 1)
        favorited = False
    else:
        # 添加收藏
        new_favorite = models.ForumFavorite(
            post_id=favorite.post_id,
            user_id=current_user.id
        )
        db.add(new_favorite)
        post.favorite_count += 1
        favorited = True
    
    await db.commit()
    
    return {
        "favorited": favorited,
        "favorite_count": post.favorite_count
    }


# ==================== 搜索 API ====================

@router.get("/search", response_model=schemas.ForumSearchResponse)
async def search_posts(
    q: str = Query(..., min_length=1, max_length=100),
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索帖子（使用 pg_trgm 相似度搜索，支持中文）"""
    from app.config import Config
    
    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 板块筛选
    if category_id:
        query = query.where(models.ForumPost.category_id == category_id)
    
    # 搜索条件（使用 pg_trgm 相似度搜索）
    if Config.USE_PG_TRGM:
        # 使用 pg_trgm 相似度搜索（对中文支持更好）
        # similarity 阈值设为 0.2，可以根据需要调整（0.1-0.3 之间）
        search_condition = or_(
            func.similarity(models.ForumPost.title, q) > 0.2,
            func.similarity(models.ForumPost.content, q) > 0.2,
            # 同时保留 ILIKE 作为兜底，确保能匹配到结果
            models.ForumPost.title.ilike(f"%{q}%"),
            models.ForumPost.content.ilike(f"%{q}%")
        )
        query = query.where(search_condition)
        
        # 按相似度排序（标题相似度优先，然后是内容相似度）
        query = query.order_by(
            func.similarity(models.ForumPost.title, q).desc(),
            func.similarity(models.ForumPost.content, q).desc(),
            models.ForumPost.created_at.desc()  # 相似度相同时按时间倒序
        )
    else:
        # 降级方案：使用 ILIKE 模糊搜索（如果未启用 pg_trgm）
        search_condition = or_(
            models.ForumPost.title.ilike(f"%{q}%"),
            models.ForumPost.content.ilike(f"%{q}%")
        )
        query = query.where(search_condition)
        query = query.order_by(models.ForumPost.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()
    
    # 转换为列表项格式
    post_items = []
    for post in posts:
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
        
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
            author=schemas.UserInfo(
                id=post.author.id,
                name=post.author.name,
                avatar=post.author.avatar or None
            ),
            view_count=post.view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at
        ))
    
    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 举报 API ====================

@router.post("/reports", response_model=schemas.ForumReportOut)
async def create_report(
    report: schemas.ForumReportCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建举报"""
    # 验证目标存在
    if report.target_type == "post":
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == report.target_id)
        )
        target = result.scalar_one_or_none()
        if not target:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在"
            )
    else:  # reply
        result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == report.target_id)
        )
        target = result.scalar_one_or_none()
        if not target:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="回复不存在"
            )
    
    # 检查是否已举报（pending 状态）
    existing_report = await db.execute(
        select(models.ForumReport).where(
            models.ForumReport.target_type == report.target_type,
            models.ForumReport.target_id == report.target_id,
            models.ForumReport.reporter_id == current_user.id,
            models.ForumReport.status == "pending"
        )
    )
    if existing_report.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="您已举报过该内容，请等待处理"
        )
    
    # 创建举报
    db_report = models.ForumReport(
        target_type=report.target_type,
        target_id=report.target_id,
        reporter_id=current_user.id,
        reason=report.reason,
        description=report.description,
        status="pending"
    )
    db.add(db_report)
    await db.flush()
    
    # 触发风控检查
    try:
        await check_and_trigger_risk_control(
            target_type=report.target_type,
            target_id=report.target_id,
            db=db
        )
    except Exception as e:
        # 风控检查失败不影响举报创建，记录日志即可
        logger.warning(f"风控检查失败: {e}", exc_info=True)
    
    await db.commit()
    await db.refresh(db_report)
    
    return schemas.ForumReportOut(
        id=db_report.id,
        target_type=db_report.target_type,
        target_id=db_report.target_id,
        reason=db_report.reason,
        description=db_report.description,
        status=db_report.status,
        created_at=db_report.created_at
    )


@router.get("/reports", response_model=schemas.ForumReportListResponse)
async def get_reports(
    status_filter: Optional[str] = Query(None, regex="^(pending|processed|rejected)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取举报列表（管理员）"""
    query = select(models.ForumReport)
    
    if status_filter:
        query = query.where(models.ForumReport.status == status_filter)
    
    query = query.order_by(models.ForumReport.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    result = await db.execute(query)
    reports = result.scalars().all()
    
    report_list = [
        schemas.ForumReportOut(
            id=r.id,
            target_type=r.target_type,
            target_id=r.target_id,
            reason=r.reason,
            description=r.description,
            status=r.status,
            created_at=r.created_at
        )
        for r in reports
    ]
    
    return {
        "reports": report_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.put("/admin/reports/{report_id}/process", response_model=schemas.ForumReportOut)
async def process_report(
    report_id: int,
    process: schemas.ForumReportProcess,
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """处理举报（管理员）"""
    result = await db.execute(
        select(models.ForumReport).where(models.ForumReport.id == report_id)
    )
    report = result.scalar_one_or_none()
    
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="举报不存在"
        )
    
    if report.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该举报已处理"
        )
    
    # 更新举报状态
    report.status = process.status
    report.processor_id = current_admin.user_id
    report.processed_at = get_utc_time()
    report.action = process.action
    await db.flush()
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.user_id,
        operation_type="process_report",
        target_type="report",
        target_id=report_id,
        action=process.action or process.status,
        reason=process.action,
        request=request,
        db=db
    )
    
    await db.commit()
    await db.refresh(report)
    
    return schemas.ForumReportOut(
        id=report.id,
        target_type=report.target_type,
        target_id=report.target_id,
        reason=report.reason,
        description=report.description,
        status=report.status,
        created_at=report.created_at
    )


# ==================== 通知 API ====================

@router.get("/notifications", response_model=schemas.ForumNotificationListResponse)
async def get_notifications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    is_read: Optional[bool] = Query(None),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取通知列表"""
    query = select(models.ForumNotification).where(
        models.ForumNotification.to_user_id == current_user.id
    )
    
    if is_read is not None:
        query = query.where(models.ForumNotification.is_read == is_read)
    
    query = query.order_by(models.ForumNotification.created_at.desc())
    
    # 获取总数和未读数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    unread_count_result = await db.execute(
        select(func.count(models.ForumNotification.id))
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
    )
    unread_count = unread_count_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumNotification.from_user)
    )
    
    result = await db.execute(query)
    notifications = result.scalars().all()
    
    notification_list = [
        schemas.ForumNotificationOut(
            id=n.id,
            notification_type=n.notification_type,
            target_type=n.target_type,
            target_id=n.target_id,
            from_user=schemas.UserInfo(
                id=n.from_user.id,
                name=n.from_user.name,
                avatar=n.from_user.avatar or None
            ) if n.from_user else None,
            is_read=n.is_read,
            created_at=n.created_at
        )
        for n in notifications
    ]
    
    return {
        "notifications": notification_list,
        "total": total,
        "unread_count": unread_count,
        "page": page,
        "page_size": page_size
    }


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """标记通知为已读"""
    result = await db.execute(
        select(models.ForumNotification).where(
            models.ForumNotification.id == notification_id,
            models.ForumNotification.to_user_id == current_user.id
        )
    )
    notification = result.scalar_one_or_none()
    
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="通知不存在"
        )
    
    notification.is_read = True
    await db.commit()
    
    return {"message": "通知已标记为已读"}


@router.put("/notifications/read-all")
async def mark_all_notifications_read(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """标记所有通知为已读"""
    await db.execute(
        update(models.ForumNotification)
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
        .values(is_read=True)
    )
    await db.commit()
    
    return {"message": "所有通知已标记为已读"}


@router.get("/notifications/unread-count")
async def get_unread_notification_count(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取未读通知数量"""
    unread_count_result = await db.execute(
        select(func.count(models.ForumNotification.id))
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
    )
    unread_count = unread_count_result.scalar() or 0
    
    return {"unread_count": unread_count}


# ==================== 我的内容 API ====================

@router.get("/my/posts", response_model=schemas.ForumPostListResponse)
async def get_my_posts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的帖子"""
    query = select(models.ForumPost).where(
        models.ForumPost.author_id == current_user.id,
        models.ForumPost.is_deleted == False
    )
    
    query = query.order_by(models.ForumPost.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()
    
    # 转换为列表项格式
    post_items = []
    for post in posts:
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
            author=schemas.UserInfo(
                id=post.author.id,
                name=post.author.name,
                avatar=post.author.avatar or None
            ),
            view_count=post.view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at
        ))
    
    return {
        "posts": post_items,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/my/replies", response_model=schemas.ForumReplyListResponse)
async def get_my_replies(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的回复"""
    query = select(models.ForumReply).where(
        models.ForumReply.author_id == current_user.id,
        models.ForumReply.is_deleted == False
    )
    
    query = query.order_by(models.ForumReply.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumReply.post).selectinload(models.ForumPost.category),
        selectinload(models.ForumReply.author)
    )
    
    result = await db.execute(query)
    replies = result.scalars().all()
    
    # 转换为输出格式
    reply_list = []
    for reply in replies:
        reply_list.append(schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=schemas.UserInfo(
                id=reply.author.id,
                name=reply.author.name,
                avatar=reply.author.avatar or None
            ),
            parent_reply_id=reply.parent_reply_id,
            reply_level=reply.reply_level,
            like_count=reply.like_count,
            is_liked=False,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
            replies=[]
        ))
    
    return {
        "replies": reply_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/favorites", response_model=schemas.ForumFavoriteListResponse)
async def get_my_favorites(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的收藏"""
    query = select(models.ForumFavorite).where(
        models.ForumFavorite.user_id == current_user.id
    )
    
    query = query.order_by(models.ForumFavorite.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumFavorite.post).selectinload(models.ForumPost.category),
        selectinload(models.ForumFavorite.post).selectinload(models.ForumPost.author)
    )
    
    result = await db.execute(query)
    favorites = result.scalars().all()
    
    # 转换为输出格式
    favorite_list = []
    for favorite in favorites:
        post = favorite.post
        # 只返回可见的帖子
        if post.is_deleted == False and post.is_visible == True:
            favorite_list.append(schemas.ForumFavoriteOut(
                id=favorite.id,
                post=schemas.ForumPostListItem(
                    id=post.id,
                    title=post.title,
                    content_preview=strip_markdown(post.content),
                    category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
                    author=schemas.UserInfo(
                        id=post.author.id,
                        name=post.author.name,
                        avatar=post.author.avatar or None
                    ),
                    view_count=post.view_count,
                    reply_count=post.reply_count,
                    like_count=post.like_count,
                    is_pinned=post.is_pinned,
                    is_featured=post.is_featured,
                    is_locked=post.is_locked,
                    created_at=post.created_at,
                    last_reply_at=post.last_reply_at
                ),
                created_at=favorite.created_at
            ))
    
    return {
        "favorites": favorite_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/my/likes")
async def get_my_likes(
    target_type: Optional[str] = Query(None, regex="^(post|reply)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我赞过的内容"""
    query = select(models.ForumLike).where(
        models.ForumLike.user_id == current_user.id
    )
    
    if target_type:
        query = query.where(models.ForumLike.target_type == target_type)
    
    query = query.order_by(models.ForumLike.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    if target_type == "post" or target_type is None:
        query = query.options(
            selectinload(models.ForumLike.post).selectinload(models.ForumPost.category),
            selectinload(models.ForumLike.post).selectinload(models.ForumPost.author)
        )
    if target_type == "reply" or target_type is None:
        query = query.options(
            selectinload(models.ForumLike.reply).selectinload(models.ForumReply.post),
            selectinload(models.ForumLike.reply).selectinload(models.ForumReply.author)
        )
    
    result = await db.execute(query)
    likes = result.scalars().all()
    
    # 转换为输出格式
    like_list = []
    for like in likes:
        if like.target_type == "post" and like.post:
            post = like.post
            if post.is_deleted == False and post.is_visible == True:
                like_list.append({
                    "target_type": "post",
                    "post": {
                        "id": post.id,
                        "title": post.title,
                        "content_preview": strip_markdown(post.content),
                        "category": {
                            "id": post.category.id,
                            "name": post.category.name
                        },
                        "author": {
                            "id": post.author.id,
                            "name": post.author.name,
                            "avatar": post.author.avatar or None
                        },
                        "view_count": post.view_count,
                        "reply_count": post.reply_count,
                        "like_count": post.like_count,
                        "created_at": post.created_at,
                        "last_reply_at": post.last_reply_at
                    },
                    "created_at": like.created_at
                })
        elif like.target_type == "reply" and like.reply:
            reply = like.reply
            if reply.is_deleted == False and reply.is_visible == True:
                like_list.append({
                    "target_type": "reply",
                    "reply": {
                        "id": reply.id,
                        "content": reply.content,
                        "post": {
                            "id": reply.post.id,
                            "title": reply.post.title
                        },
                        "author": {
                            "id": reply.author.id,
                            "name": reply.author.name,
                            "avatar": reply.author.avatar or None
                        },
                        "like_count": reply.like_count,
                        "created_at": reply.created_at
                    },
                    "created_at": like.created_at
                })
    
    return {
        "likes": like_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 管理员操作日志 API ====================

@router.get("/admin/operation-logs", response_model=schemas.ForumAdminOperationLogListResponse)
async def get_admin_operation_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    operator_id: Optional[str] = Query(None),
    operation_type: Optional[str] = Query(None),
    target_type: Optional[str] = Query(None),
    target_id: Optional[int] = Query(None),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取管理员操作日志（管理员）"""
    query = select(models.ForumAdminOperationLog)
    
    # 筛选条件
    if operator_id:
        query = query.where(models.ForumAdminOperationLog.operator_id == operator_id)
    if operation_type:
        query = query.where(models.ForumAdminOperationLog.operation_type == operation_type)
    if target_type:
        query = query.where(models.ForumAdminOperationLog.target_type == target_type)
    if target_id:
        query = query.where(models.ForumAdminOperationLog.target_id == target_id)
    
    query = query.order_by(models.ForumAdminOperationLog.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    result = await db.execute(query)
    logs = result.scalars().all()
    
    # 转换为输出格式
    log_list = []
    for log in logs:
        log_list.append(schemas.ForumAdminOperationLogOut(
            id=log.id,
            operator_id=log.operator_id,
            operation_type=log.operation_type,
            target_type=log.target_type,
            target_id=log.target_id,
            target_title=log.target_title,
            action=log.action,
            reason=log.reason,
            ip_address=log.ip_address,
            created_at=log.created_at
        ))
    
    return {
        "logs": log_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


# ==================== 论坛统计 API（管理员）====================

@router.get("/admin/stats", response_model=schemas.ForumStatsResponse)
async def get_forum_stats(
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取论坛统计数据（管理员）"""
    now = datetime.now(timezone.utc)
    today_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)
    
    # 基础统计
    total_categories = await db.execute(
        select(func.count(models.ForumCategory.id))
    )
    total_categories_count = total_categories.scalar() or 0
    
    total_posts = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(models.ForumPost.is_deleted == False)
    )
    total_posts_count = total_posts.scalar() or 0
    
    total_replies = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(models.ForumReply.is_deleted == False)
    )
    total_replies_count = total_replies.scalar() or 0
    
    total_likes = await db.execute(
        select(func.count(models.ForumLike.id))
    )
    total_likes_count = total_likes.scalar() or 0
    
    total_favorites = await db.execute(
        select(func.count(models.ForumFavorite.id))
    )
    total_favorites_count = total_favorites.scalar() or 0
    
    total_reports = await db.execute(
        select(func.count(models.ForumReport.id))
    )
    total_reports_count = total_reports.scalar() or 0
    
    pending_reports = await db.execute(
        select(func.count(models.ForumReport.id))
        .where(models.ForumReport.status == "pending")
    )
    pending_reports_count = pending_reports.scalar() or 0
    
    # 参与论坛的用户数（发过帖子或回复的用户）
    # 使用 UNION 获取所有参与用户（去重）
    total_users_subquery = select(models.ForumPost.author_id).distinct().union(
        select(models.ForumReply.author_id).distinct()
    ).subquery()
    total_users_result = await db.execute(
        select(func.count()).select_from(total_users_subquery)
    )
    total_users_count = total_users_result.scalar() or 0
    
    # 最近7天活跃用户（发过帖子或回复）
    active_users_7d_subquery = select(models.ForumPost.author_id).distinct().where(
        models.ForumPost.created_at >= seven_days_ago
    ).union(
        select(models.ForumReply.author_id).distinct().where(
            models.ForumReply.created_at >= seven_days_ago
        )
    ).subquery()
    active_users_7d_result = await db.execute(
        select(func.count()).select_from(active_users_7d_subquery)
    )
    active_users_7d_count = active_users_7d_result.scalar() or 0
    
    # 最近30天活跃用户
    active_users_30d_subquery = select(models.ForumPost.author_id).distinct().where(
        models.ForumPost.created_at >= thirty_days_ago
    ).union(
        select(models.ForumReply.author_id).distinct().where(
            models.ForumReply.created_at >= thirty_days_ago
        )
    ).subquery()
    active_users_30d_result = await db.execute(
        select(func.count()).select_from(active_users_30d_subquery)
    )
    active_users_30d_count = active_users_30d_result.scalar() or 0
    
    # 今日帖子数
    posts_today_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(models.ForumPost.created_at >= today_start)
        .where(models.ForumPost.is_deleted == False)
    )
    posts_today_count = posts_today_result.scalar() or 0
    
    # 最近7天帖子数
    posts_7d_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(models.ForumPost.created_at >= seven_days_ago)
        .where(models.ForumPost.is_deleted == False)
    )
    posts_7d_count = posts_7d_result.scalar() or 0
    
    # 最近30天帖子数
    posts_30d_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(models.ForumPost.created_at >= thirty_days_ago)
        .where(models.ForumPost.is_deleted == False)
    )
    posts_30d_count = posts_30d_result.scalar() or 0
    
    # 今日回复数
    replies_today_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(models.ForumReply.created_at >= today_start)
        .where(models.ForumReply.is_deleted == False)
    )
    replies_today_count = replies_today_result.scalar() or 0
    
    # 最近7天回复数
    replies_7d_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(models.ForumReply.created_at >= seven_days_ago)
        .where(models.ForumReply.is_deleted == False)
    )
    replies_7d_count = replies_7d_result.scalar() or 0
    
    # 最近30天回复数
    replies_30d_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(models.ForumReply.created_at >= thirty_days_ago)
        .where(models.ForumReply.is_deleted == False)
    )
    replies_30d_count = replies_30d_result.scalar() or 0
    
    return {
        "total_categories": total_categories_count,
        "total_posts": total_posts_count,
        "total_replies": total_replies_count,
        "total_likes": total_likes_count,
        "total_favorites": total_favorites_count,
        "total_reports": total_reports_count,
        "pending_reports": pending_reports_count,
        "total_users": total_users_count,
        "active_users_7d": active_users_7d_count,
        "active_users_30d": active_users_30d_count,
        "posts_today": posts_today_count,
        "posts_7d": posts_7d_count,
        "posts_30d": posts_30d_count,
        "replies_today": replies_today_count,
        "replies_7d": replies_7d_count,
        "replies_30d": replies_30d_count
    }


@router.post("/admin/fix-statistics")
async def fix_forum_statistics(
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """修复论坛统计字段（管理员）"""
    try:
        # 修复所有板块的统计
        categories_result = await db.execute(
            select(models.ForumCategory)
        )
        categories = categories_result.scalars().all()
        
        fixed_categories = 0
        for category in categories:
            await update_category_stats(category.id, db)
            fixed_categories += 1
        
        # 修复所有帖子的回复数统计
        posts_result = await db.execute(
            select(models.ForumPost)
        )
        posts = posts_result.scalars().all()
        
        fixed_posts = 0
        for post in posts:
            # 统计可见回复数
            reply_count_result = await db.execute(
                select(func.count(models.ForumReply.id))
                .where(models.ForumReply.post_id == post.id)
                .where(models.ForumReply.is_deleted == False)
                .where(models.ForumReply.is_visible == True)
            )
            correct_reply_count = reply_count_result.scalar() or 0
            
            if post.reply_count != correct_reply_count:
                post.reply_count = correct_reply_count
                fixed_posts += 1
            
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
        
        await db.commit()
        
        return {
            "message": "统计字段修复完成",
            "fixed_categories": fixed_categories,
            "fixed_posts": fixed_posts
        }
    except Exception as e:
        await db.rollback()
        logger.error(f"修复论坛统计字段失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"修复统计字段失败: {str(e)}"
        )


# ==================== 热门内容 API ====================

@router.get("/hot-posts", response_model=schemas.ForumPostListResponse)
async def get_hot_posts(
    category_id: Optional[int] = Query(None, description="板块ID（可选）"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取热门帖子（按热度排序）"""
    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 板块筛选
    if category_id:
        query = query.where(models.ForumPost.category_id == category_id)
    
    # 热度排序：综合评分公式
    hot_score = (
        models.ForumPost.like_count * 5.0 +
        models.ForumPost.reply_count * 3.0 +
        models.ForumPost.view_count * 0.1
    ) / func.pow(
        func.extract('epoch', func.now() - models.ForumPost.created_at) / 3600.0 + 2.0,
        1.5
    )
    query = query.order_by(hot_score.desc())
    
    # 限制数量
    query = query.limit(limit)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()
    
    # 转换为列表项格式
    post_items = []
    for post in posts:
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
        
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
            category=schemas.CategoryInfo(id=post.category.id, name=post.category.name),
            author=schemas.UserInfo(
                id=post.author.id,
                name=post.author.name,
                avatar=post.author.avatar or None
            ),
            view_count=post.view_count,
            reply_count=post.reply_count,
            like_count=post.like_count,
            is_pinned=post.is_pinned,
            is_featured=post.is_featured,
            is_locked=post.is_locked,
            created_at=post.created_at,
            last_reply_at=post.last_reply_at
        ))
    
    return {
        "posts": post_items,
        "total": len(post_items),
        "page": 1,
        "page_size": limit
    }


# ==================== 用户论坛统计 API ====================

@router.get("/users/{user_id}/stats")
async def get_user_forum_stats(
    user_id: str,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户论坛统计信息"""
    # 检查权限：只能查看自己的统计或公开统计
    if current_user and current_user.id != user_id:
        # 非本人只能查看公开统计
        pass  # 允许查看公开统计
    
    # 统计帖子数
    posts_count_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(
            models.ForumPost.author_id == user_id,
            models.ForumPost.is_deleted == False
        )
    )
    posts_count = posts_count_result.scalar() or 0
    
    # 统计回复数
    replies_count_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .where(
            models.ForumReply.author_id == user_id,
            models.ForumReply.is_deleted == False
        )
    )
    replies_count = replies_count_result.scalar() or 0
    
    # 统计获得的点赞数（分别统计帖子和回复的点赞）
    post_likes_result = await db.execute(
        select(func.sum(models.ForumPost.like_count))
        .where(
            models.ForumPost.author_id == user_id,
            models.ForumPost.is_deleted == False
        )
    )
    post_likes = post_likes_result.scalar() or 0
    
    reply_likes_result = await db.execute(
        select(func.sum(models.ForumReply.like_count))
        .where(
            models.ForumReply.author_id == user_id,
            models.ForumReply.is_deleted == False
        )
    )
    reply_likes = reply_likes_result.scalar() or 0
    likes_received = post_likes + reply_likes
    
    # 统计收藏数
    favorites_count_result = await db.execute(
        select(func.count(models.ForumFavorite.id))
        .where(models.ForumFavorite.user_id == user_id)
    )
    favorites_count = favorites_count_result.scalar() or 0
    
    return {
        "user_id": user_id,
        "posts_count": posts_count,
        "replies_count": replies_count,
        "likes_received": likes_received,
        "favorites_count": favorites_count
    }


# ==================== 排行榜 API ====================

@router.get("/leaderboard/posts")
async def get_top_posts_leaderboard(
    period: str = Query("all", regex="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取发帖排行榜"""
    now = datetime.now(timezone.utc)
    
    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None
    
    # 构建查询
    query = select(
        models.ForumPost.author_id,
        func.count(models.ForumPost.id).label("post_count")
    ).where(
        models.ForumPost.is_deleted == False
    )
    
    if start_time:
        query = query.where(models.ForumPost.created_at >= start_time)
    
    query = query.group_by(models.ForumPost.author_id).order_by(func.count(models.ForumPost.id).desc()).limit(limit)
    
    result = await db.execute(query)
    top_users = result.all()
    
    # 获取用户信息
    user_list = []
    for user_id, post_count in top_users:
        user_result = await db.execute(
            select(models.User).where(models.User.id == user_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "post_count": post_count
            })
    
    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/replies")
async def get_top_replies_leaderboard(
    period: str = Query("all", regex="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取回复排行榜"""
    now = datetime.now(timezone.utc)
    
    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None
    
    # 构建查询
    query = select(
        models.ForumReply.author_id,
        func.count(models.ForumReply.id).label("reply_count")
    ).where(
        models.ForumReply.is_deleted == False
    )
    
    if start_time:
        query = query.where(models.ForumReply.created_at >= start_time)
    
    query = query.group_by(models.ForumReply.author_id).order_by(func.count(models.ForumReply.id).desc()).limit(limit)
    
    result = await db.execute(query)
    top_users = result.all()
    
    # 获取用户信息
    user_list = []
    for user_id, reply_count in top_users:
        user_result = await db.execute(
            select(models.User).where(models.User.id == user_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "reply_count": reply_count
            })
    
    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/likes")
async def get_top_likes_leaderboard(
    period: str = Query("all", regex="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取获赞排行榜（统计用户发布的帖子和回复获得的点赞数）"""
    now = datetime.now(timezone.utc)
    
    # 根据周期设置时间范围
    if period == "today":
        start_time = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    elif period == "week":
        start_time = now - timedelta(days=7)
    elif period == "month":
        start_time = now - timedelta(days=30)
    else:  # all
        start_time = None
    
    # 统计帖子获得的点赞数
    post_likes_query = select(
        models.ForumPost.author_id,
        func.sum(models.ForumPost.like_count).label("likes")
    ).where(
        models.ForumPost.is_deleted == False
    )
    if start_time:
        post_likes_query = post_likes_query.where(models.ForumPost.created_at >= start_time)
    post_likes_query = post_likes_query.group_by(models.ForumPost.author_id)
    
    # 统计回复获得的点赞数
    reply_likes_query = select(
        models.ForumReply.author_id,
        func.sum(models.ForumReply.like_count).label("likes")
    ).where(
        models.ForumReply.is_deleted == False
    )
    if start_time:
        reply_likes_query = reply_likes_query.where(models.ForumReply.created_at >= start_time)
    reply_likes_query = reply_likes_query.group_by(models.ForumReply.author_id)
    
    # 合并结果（简化处理：分别查询后合并）
    post_result = await db.execute(post_likes_query)
    post_likes_data = {row[0]: row[1] or 0 for row in post_result.all()}
    
    reply_result = await db.execute(reply_likes_query)
    reply_likes_data = {row[0]: row[1] or 0 for row in reply_result.all()}
    
    # 合并统计
    total_likes = {}
    for user_id, likes in post_likes_data.items():
        total_likes[user_id] = total_likes.get(user_id, 0) + likes
    for user_id, likes in reply_likes_data.items():
        total_likes[user_id] = total_likes.get(user_id, 0) + likes
    
    # 排序并取前N名
    sorted_users = sorted(total_likes.items(), key=lambda x: x[1], reverse=True)[:limit]
    
    # 获取用户信息
    user_list = []
    for user_id, likes_count in sorted_users:
        user_result = await db.execute(
            select(models.User).where(models.User.id == user_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "likes_received": likes_count
            })
    
    return {
        "period": period,
        "users": user_list
    }


# ==================== 板块统计 API ====================

@router.get("/categories/{category_id}/stats")
async def get_category_stats(
    category_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块详细统计信息"""
    # 验证板块存在
    category_result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = category_result.scalar_one_or_none()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在",
            headers={"X-Error-Code": "CATEGORY_NOT_FOUND"}
        )
    
    # 统计可见帖子数
    post_count_result = await db.execute(
        select(func.count(models.ForumPost.id))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True
        )
    )
    post_count = post_count_result.scalar() or 0
    
    # 统计总回复数（可见帖子下的可见回复）
    reply_count_result = await db.execute(
        select(func.count(models.ForumReply.id))
        .join(models.ForumPost)
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
            models.ForumReply.is_deleted == False,
            models.ForumReply.is_visible == True
        )
    )
    reply_count = reply_count_result.scalar() or 0
    
    # 统计总点赞数（可见帖子下的点赞）
    like_count_result = await db.execute(
        select(func.count(models.ForumLike.id))
        .join(models.ForumPost, and_(
            models.ForumLike.target_type == "post",
            models.ForumLike.target_id == models.ForumPost.id
        ))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True
        )
    )
    like_count = like_count_result.scalar() or 0
    
    # 统计参与用户数（在该板块发过帖子或回复的用户）
    post_authors = select(models.ForumPost.author_id).distinct().where(
        models.ForumPost.category_id == category_id,
        models.ForumPost.is_deleted == False
    )
    reply_authors = select(models.ForumReply.author_id).distinct().join(models.ForumPost).where(
        models.ForumPost.category_id == category_id,
        models.ForumReply.is_deleted == False
    )
    users_subquery = post_authors.union(reply_authors).subquery()
    users_count_result = await db.execute(
        select(func.count()).select_from(users_subquery)
    )
    users_count = users_count_result.scalar() or 0
    
    return {
        "category_id": category_id,
        "category_name": category.name,
        "post_count": post_count,
        "reply_count": reply_count,
        "like_count": like_count,
        "users_count": users_count,
        "last_post_at": category.last_post_at
    }


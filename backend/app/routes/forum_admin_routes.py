"""
论坛-管理 routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from datetime import datetime, timezone, timedelta
from typing import Optional
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_admin_async,
    assert_forum_visible,
    check_and_trigger_risk_control,
    log_admin_operation,
    update_category_stats,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ==================== 举报 API ====================

@router.post("/reports", response_model=schemas.ForumReportOut)
async def create_report(
    report: schemas.ForumReportCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    request: Request = None,  # FastAPI injects; Optional[Request] breaks Pydantic field detection
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建举报"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    # 验证目标存在并检查权限
    if report.target_type == "post":
        result = await db.execute(
            select(models.ForumPost)
            .options(selectinload(models.ForumPost.category))
            .where(models.ForumPost.id == report.target_id)
        )
        target = result.scalar_one_or_none()
        if not target:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在"
            )
        # 检查用户是否有权限访问该帖子所属的板块（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, target.category_id, db, raise_exception=True)
    else:  # reply
        result = await db.execute(
            select(models.ForumReply)
            .options(selectinload(models.ForumReply.post).selectinload(models.ForumPost.category))
            .where(models.ForumReply.id == report.target_id)
        )
        target = result.scalar_one_or_none()
        if not target:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="回复不存在"
            )
        # 检查用户是否有权限访问该回复所属帖子所属的板块（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, target.post.category_id, db, raise_exception=True)

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
    status_filter: Optional[str] = Query(None, pattern="^(pending|processed|rejected)$"),
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
    # processor_id 是外键到 users.id，但管理员ID是 admin_users.id，类型不匹配
    # 因此设置为 NULL，管理员信息通过操作日志追踪
    report.processor_id = None
    report.processed_at = get_utc_time()
    report.action = process.action
    await db.flush()

    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
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


@router.get("/admin/categories")
async def get_admin_categories(
    request: Request,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取所有板块列表（管理员，包含隐藏板块）"""
    result = await db.execute(
        select(models.ForumCategory)
        .order_by(models.ForumCategory.sort_order.asc(), models.ForumCategory.id.asc())
    )
    categories = result.scalars().all()

    category_list = []
    for category in categories:
        category_out = schemas.ForumCategoryOut(
            id=category.id,
            name=category.name,
            name_en=getattr(category, 'name_en', None),
            name_zh=getattr(category, 'name_zh', None),
            description=category.description,
            description_en=getattr(category, 'description_en', None),
            description_zh=getattr(category, 'description_zh', None),
            icon=category.icon,
            sort_order=category.sort_order,
            is_visible=category.is_visible,
            is_admin_only=getattr(category, 'is_admin_only', False),
            type=getattr(category, 'type', 'general'),
            country=getattr(category, 'country', None),
            university_code=getattr(category, 'university_code', None),
            skill_type=getattr(category, 'skill_type', None),
            post_count=category.post_count,
            service_count=getattr(category, 'service_count', 0),
            task_count=getattr(category, 'task_count', 0),
            last_post_at=category.last_post_at,
            created_at=category.created_at,
            updated_at=category.updated_at
        )
        category_list.append(category_out)

    return {"categories": category_list}


@router.get("/admin/pending-requests/count")
async def get_pending_requests_count(
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取待审核申请数量统计（管理员）"""
    # 统计待审核的板块申请
    pending_category_requests = await db.execute(
        select(func.count(models.ForumCategoryRequest.id))
        .where(models.ForumCategoryRequest.status == "pending")
    )
    pending_category_count = pending_category_requests.scalar() or 0

    return {
        "pending_category_requests": pending_category_count,
        "total_pending": pending_category_count
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

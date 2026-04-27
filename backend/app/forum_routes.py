"""
论坛功能路由
实现论坛板块、帖子、回复、点赞、收藏、搜索、通知、举报等功能
"""

from typing import List, Optional
from datetime import datetime, timezone, timedelta
import json
import re
import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status, Request, Body
from sqlalchemy import select, func, or_, and_, desc, asc, case, update, inspect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload
from sqlalchemy.orm.attributes import NO_VALUE

from app import models, schemas
from app.deps import get_async_db_dependency
from app.database import get_db  # sync session for points transaction
from app.coupon_points_crud import add_points_transaction
from app.utils.time_utils import get_utc_time
from app.performance_monitor import measure_api_performance
from app.cache import cache_response
from app.push_notification_service import send_push_notification_async_safe
from app.content_filter.filter_service import check_content, create_review, create_mask_record

logger = logging.getLogger(__name__)


def _post_identity(post) -> tuple[str, str]:
    """Synthesize (owner_type, owner_id) for a forum post.

    forum_posts doesn't have native owner_type/owner_id columns, so derive them
    from expert_id (team post) / author_id (regular user post).
    """
    if getattr(post, "expert_id", None):
        return ("expert", post.expert_id)
    author_id = getattr(post, "author_id", None) or ""
    return ("user", author_id)


async def _bg_translate_post(
    post_id: int,
    title: str,
    content: Optional[str],
    title_en: Optional[str] = None,
    title_zh: Optional[str] = None,
    content_en: Optional[str] = None,
    content_zh: Optional[str] = None,
) -> None:
    """返回响应后异步翻译帖子，更新双语字段。"""
    from app.database import AsyncSessionLocal
    from app.utils.bilingual_helper import auto_fill_bilingual_fields
    try:
        _, t_en, t_zh, c_en, c_zh = await auto_fill_bilingual_fields(
            name=title,
            description=content,
            name_en=title_en,
            name_zh=title_zh,
            description_en=content_en,
            description_zh=content_zh,
        )
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(models.ForumPost).where(models.ForumPost.id == post_id)
            )
            db_post = result.scalar_one_or_none()
            if db_post:
                db_post.title_en = t_en
                db_post.title_zh = t_zh
                db_post.content_en = c_en
                db_post.content_zh = c_zh
                await db.commit()
    except Exception as e:
        logger.warning(f"后台翻译帖子 {post_id} 失败: {e}")



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


# ==================== 学校板块访问控制函数 ====================

def invalidate_forum_visibility_cache(user_id: str):
    """
    清除用户可见板块的缓存
    
    当学生认证状态变更时（verified -> expired/revoked，或大学变更），
    需要清除该用户的可见板块缓存，确保下次查询时获取最新数据。
    
    缓存键格式：visible_forums:v2:{user_id}
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            cache_key = f"visible_forums:v2:{user_id}"
            redis_client.delete(cache_key)
            logger.debug(f"已清除用户 {user_id} 的可见板块缓存: {cache_key}")
    except Exception as e:
        # 缓存失效失败不影响主流程，只记录日志
        logger.warning(f"清除用户 {user_id} 的可见板块缓存失败: {e}")


def clear_all_forum_visibility_cache(reason: str = "板块信息变更"):
    """
    清除所有用户的可见板块缓存
    
    当板块信息发生变更（创建、更新、删除）时，需要清除所有用户的缓存，
    确保所有用户下次查询时获取最新的板块可见性信息。
    
    注意：此操作在生产环境中可能影响性能，应谨慎使用。
    对于大量用户的情况，考虑使用更细粒度的缓存清理策略。
    
    参数:
        reason: 清理原因（用于日志记录）
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if not redis_client:
            return
        
        # 使用 SCAN 命令替代 KEYS 命令，避免阻塞 Redis
        # SCAN 是游标迭代，不会阻塞 Redis 服务器
        pattern = "visible_forums:v2:*"
        deleted_count = 0
        
        # 使用 SCAN 迭代所有匹配的键
        cursor = 0
        while True:
            cursor, keys = redis_client.scan(cursor, match=pattern, count=100)
            if keys:
                # 批量删除，提高效率
                redis_client.delete(*keys)
                deleted_count += len(keys)
            
            # 如果游标为 0，说明已经扫描完所有键
            if cursor == 0:
                break
        
        if deleted_count > 0:
            logger.info(f"已清理 {deleted_count} 个用户的可见板块缓存（原因：{reason}）")
        else:
            logger.debug(f"没有找到需要清理的可见板块缓存（原因：{reason}）")
            
    except Exception as e:
        # 缓存清理失败不影响主流程，只记录警告日志
        logger.warning(f"清理所有用户的可见板块缓存失败（原因：{reason}）: {e}")


def is_uk_university(university: models.University) -> bool:
    """
    判断是否为英国大学
    
    实现方式（按优先级）：
    1. 如果 universities 表有 country 字段：return university.country == 'UK'
    2. 否则通过 email_domain 判断：return university.email_domain.endswith('.ac.uk')
    
    重要：必须与《英国留学生认证系统文档》中"判断是否英国大学"的逻辑 100% 保持一致。
    任何修改都需要同步更新认证系统的判断逻辑，避免权限判断不一致。
    """
    # 方案1：使用 country 字段（推荐）
    if hasattr(university, 'country') and university.country:
        return university.country == 'UK'
    
    # 方案2：通过 email_domain 判断（备用方案）
    if hasattr(university, 'email_domain') and university.email_domain:
        return university.email_domain.endswith('.ac.uk')
    
    return False


async def visible_forums(user: Optional[models.User], db: AsyncSession) -> List[int]:
    """
    获取用户可见的【学校相关板块】ID 列表（不包含 type='general' 的普通板块）
    
    返回值：
    - 已认证英国留学生：返回 [英国留学生大板块ID, 自己大学的板块ID]
    - 其他用户（包括非 UK 大学认证用户）：返回空列表 []
    
    注意：
    - 此函数不返回 type='general' 的普通板块，调用方需自行合并。
    - 重要：此函数应在 require_student_verified(country="UK") 依赖之后调用，或确保传入的用户已通过 UK 学生认证。
    """
    if not user:
        return []
    
    # 先尝试从缓存读取
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            cache_key = f"visible_forums:v2:{user.id}"
            cached_data = redis_client.get(cache_key)
            if cached_data:
                import json
                forums = json.loads(cached_data)
                logger.debug(f"从缓存读取用户 {user.id} 的可见板块: {forums}")
                return forums
    except Exception as e:
        # 缓存读取失败不影响主流程，继续查询数据库
        logger.debug(f"读取可见板块缓存失败: {e}")
    
    # 缓存未命中，查询数据库
    # 获取用户认证信息（一次性查询，避免重复）
    # 注意：这里只查询 verified 状态，UK 判断在下方显式进行
    # 使用 selectinload 预加载 university 关系，避免额外的查询
    verification_result = await db.execute(
        select(models.StudentVerification)
        .options(selectinload(models.StudentVerification.university))
        .join(models.University)
        .where(
            models.StudentVerification.user_id == user.id,
            models.StudentVerification.status == 'verified',
            models.StudentVerification.expires_at > func.now(),
            models.University.is_active == True
        )
    )
    verification = verification_result.scalar_one_or_none()
    
    if not verification:
        # 非学生是正常状态，不是异常；降到 debug 避免日志刷屏
        logger.debug(f"用户 {user.id} 没有有效的学生认证记录（需 status='verified' 且未过期且大学 is_active）")
        # 缓存空结果，避免每次调用都重查 DB
        try:
            from app.redis_cache import get_redis_client
            redis_client = get_redis_client()
            if redis_client:
                import json
                redis_client.setex(f"visible_forums:v2:{user.id}", 300, json.dumps([]))
        except Exception as e:
            logger.debug(f"写入可见板块空缓存失败: {e}")
        return []

    university = verification.university
    logger.info(f"用户 {user.id} 学生认证: university={university.name}, country={getattr(university, 'country', None)}, email_domain={getattr(university, 'email_domain', None)}, code={getattr(university, 'code', None)}, expires_at={verification.expires_at}")

    # 显式判断：是否为英国大学，非 UK 大学认证用户不开放学校板块访问
    # 防御性编程：即使调用方没走 require_student_verified，也要在这里二次判断非UK大学
    # 这是最后一道防线，确保非 UK 大学认证用户无法访问学校板块
    if not is_uk_university(university):
        logger.warning(f"用户 {user.id} 的大学 {university.name} 不是UK大学，不展示学校板块")
        return []
    
    # 获取 university_code
    university_code = None
    if hasattr(university, 'code') and university.code:
        university_code = university.code
        logger.debug(f"用户 {user.id} 的大学 {university.name} 编码: {university_code}")
    else:
        logger.warning(f"用户 {user.id} 的大学 {university.name} ({university.email_domain}) 缺少 code 字段，无法显示大学板块。请运行 init_forum_school_categories.py 脚本初始化大学编码。")
    # 如果没有 code 字段，可通过 email_domain 映射（需实现映射函数）
    # 当前版本暂不支持，需要先填充 universities.code 字段
    
    forums = []
    # 1. 添加英国留学生大板块（type='root', country='UK'）
    # 注意：同一国家只应有一个 root 板块，使用 scalar_one_or_none() 确保唯一性
    root_forum_result = await db.execute(
        select(models.ForumCategory.id)
        .where(
            models.ForumCategory.type == 'root',
            models.ForumCategory.country == 'UK',
            models.ForumCategory.is_visible == True
        )
    )
    root_id = root_forum_result.scalar_one_or_none()
    if root_id:
        forums.append(root_id)
        logger.debug(f"添加英国留学生大板块 ID: {root_id}")
    
    # 2. 添加用户所属大学的板块
    if university_code:
        university_forum_result = await db.execute(
            select(models.ForumCategory.id)
            .where(
                models.ForumCategory.type == 'university',
                models.ForumCategory.university_code == university_code,
                models.ForumCategory.is_visible == True
            )
        )
        uni_id = university_forum_result.scalar_one_or_none()
        if uni_id:
            forums.append(uni_id)
            logger.debug(f"添加大学板块 ID: {uni_id} (university_code: {university_code})")
        else:
            logger.warning(f"未找到 university_code='{university_code}' 的大学板块。请运行 init_forum_school_categories.py 脚本创建大学板块。")
    else:
        logger.debug(f"用户 {user.id} 的大学没有编码，跳过大学板块查询")
    
    # 缓存结果（默认启用缓存）
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            cache_key = f"visible_forums:v2:{user.id}"
            import json
            # 缓存5分钟（300秒）
            redis_client.setex(cache_key, 300, json.dumps(forums))
            logger.debug(f"已缓存用户 {user.id} 的可见板块: {forums}")
    except Exception as e:
        # 缓存写入失败不影响主流程
        logger.debug(f"写入可见板块缓存失败: {e}")
    
    return forums


async def assert_forum_visible(
    user: Optional[models.User], 
    forum_id: int, 
    db: AsyncSession,
    raise_exception: bool = True
) -> bool:
    """
    校验用户是否有权限访问指定板块
    
    注意：此函数应在 require_student_verified(country="UK") 依赖之后调用，
    或确保传入的用户已通过 UK 学生认证。否则非 UK 大学认证用户也会被允许访问。
    """
    # 当前版本：管理员/版主全局越权；如需细分，改为"版主-板块映射"校验
    # 检查是否为管理员（通过检查是否有管理员会话）
    # 注意：这里简化处理，实际应该检查用户是否为管理员
    # 由于 User 模型没有直接的 is_admin 属性，这里暂时跳过管理员检查
    # 管理员权限检查应在调用此函数之前完成
    
    # 获取板块信息
    forum_result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == forum_id)
    )
    forum = forum_result.scalar_one_or_none()
    
    if not forum:
        if raise_exception:
            raise HTTPException(status_code=404, detail="Forum not found")
        return False
    
    # 普通板块、技能板块、达人板块所有用户都可访问
    if forum.type in ('general', 'skill', 'expert'):
        return True
    
    # 学校板块（type='root' 或 type='university'）需要权限校验
    if not user:
        if raise_exception:
            raise HTTPException(status_code=401, detail="Unauthorized")
        return False
    
    visible_ids = await visible_forums(user, db)
    if forum_id in visible_ids:
        return True
    
    if raise_exception:
        # 对外默认 404 隐藏存在性；内部/管理接口可配置为 403
        raise HTTPException(status_code=404, detail="Forum not found")
    return False


async def require_student_verified(
    country: str = "UK",
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency)
) -> models.User:
    """
    确保用户已通过指定国家的学生认证
    
    重要：此依赖用于学校板块相关接口，确保只允许 UK 学生访问。
    """
    verification_result = await db.execute(
        select(models.StudentVerification)
        .join(models.University)
        .where(
            models.StudentVerification.user_id == current_user.id,
            models.StudentVerification.status == 'verified',
            models.StudentVerification.expires_at > func.now(),
            models.University.is_active == True
        )
    )
    verification = verification_result.scalar_one_or_none()
    
    if not verification:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Student verification required"
        )
    
    # 检查国家
    university = verification.university
    if country == "UK" and not is_uk_university(university):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: UK student verification required"
        )
    
    return current_user


async def check_forum_visibility(
    forum_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency)
) -> int:
    """
    FastAPI 依赖：校验板块可见性
    
    注意：对于学校板块（type='root' 或 type='university'），
    应配合 require_student_verified(country="UK") 使用，确保只允许 UK 学生访问。
    """
    await assert_forum_visible(current_user, forum_id, db, raise_exception=True)
    return forum_id


# ==================== 工具函数 ====================

async def build_user_info(
    db: AsyncSession,
    user: Optional[models.User],
    request: Optional[Request] = None,
    force_admin: bool = False,
    _badge_cache: Optional[dict] = None,
) -> schemas.UserInfo:
    """构建用户信息（包含管理员标识）

    Args:
        db: 数据库会话
        user: 用户对象（可为None）
        request: 请求对象（用于检查管理员会话）
        force_admin: 强制标记为管理员（用于管理员发帖的情况，在管理员页面操作时）
    """
    if not user:
        return schemas.UserInfo(
            id="unknown",
            name="已删除用户",
            avatar=None,
            is_admin=False,
            user_level=None,
        )
    
    # 如果强制标记为管理员（管理员在后台页面发帖/回复），直接返回
    if force_admin:
        return schemas.UserInfo(
            id=user.id,
            name=user.name,
            avatar=user.avatar or None,
            is_admin=True,
            user_level=getattr(user, "user_level", None),
        )
    
    # 注意：普通用户永远不是管理员
    # 只有通过 build_admin_user_info 或 force_admin=True 才会标记为管理员
    # 这里不再检查管理员会话，因为普通用户和管理员是独立的身份系统

    # 展示勋章：优先使用预加载数据，否则不查询（避免 N+1）
    displayed_badge_dict = None
    if _badge_cache is not None:
        displayed_badge_dict = _badge_cache.get(user.id)

    return schemas.UserInfo(
        id=user.id,
        name=user.name,
        avatar=user.avatar or None,
        is_admin=False,
        user_level=getattr(user, "user_level", None),
        displayed_badge=displayed_badge_dict,
    )


async def preload_badge_cache(db: AsyncSession, user_ids: list[str]) -> dict:
    """预加载一批用户的展示勋章，返回 {user_id: badge_dict} 映射。
    供列表端点在构建 UserInfo 前调用，传给 build_user_info._badge_cache。
    """
    from app.utils.badge_helpers import enrich_displayed_badges_async
    return await enrich_displayed_badges_async(db, user_ids)


async def build_admin_user_info(admin_user: models.AdminUser) -> schemas.UserInfo:
    """构建管理员用户信息
    
    Args:
        admin_user: 管理员对象
    """
    return schemas.UserInfo(
        id=admin_user.id,  # 保留管理员ID用于内部识别
        name="Link²Ur",  # 统一显示名称
        avatar="/static/logo.png",  # 统一使用logo作为头像
        is_admin=True,  # 官方标识
        user_level=None,  # 管理员不展示会员等级
    )


async def get_post_author_info(
    db: AsyncSession,
    post: models.ForumPost,
    request: Optional[Request] = None,
    _badge_cache: Optional[dict] = None,
) -> schemas.UserInfo:
    """获取帖子作者信息（支持普通用户和管理员）

    Args:
        db: 数据库会话
        post: 帖子对象
        request: 请求对象（可选）
        _badge_cache: 预加载的勋章缓存（避免 N+1）
    """
    # 如果是管理员发帖
    if post.admin_author_id:
        # 检查 admin_author 关系是否已加载
        post_inspect = inspect(post)
        admin_author_attr = post_inspect.attrs.admin_author
        
        # 如果关系已加载（loaded_value 不等于 NO_VALUE），直接使用
        if admin_author_attr.loaded_value is not NO_VALUE:
            admin_author = admin_author_attr.loaded_value
            if admin_author:
                return await build_admin_user_info(admin_author)
        else:
            # 如果关系未加载，从数据库查询
            admin_author_result = await db.execute(
                select(models.AdminUser).where(models.AdminUser.id == post.admin_author_id)
            )
            admin_author = admin_author_result.scalar_one_or_none()
            if admin_author:
                return await build_admin_user_info(admin_author)
    
    # 如果是普通用户发帖
    if post.author_id:
        # 检查 author 关系是否已加载
        post_inspect = inspect(post)
        author_attr = post_inspect.attrs.author
        
        # 如果关系已加载（loaded_value 不等于 NO_VALUE），直接使用
        if author_attr.loaded_value is not NO_VALUE:
            author = author_attr.loaded_value
            if author:
                return await build_user_info(db, author, request, force_admin=False, _badge_cache=_badge_cache)
        else:
            # 如果关系未加载，从数据库查询
            author_result = await db.execute(
                select(models.User).where(models.User.id == post.author_id)
            )
            author = author_result.scalar_one_or_none()
            if author:
                return await build_user_info(db, author, request, force_admin=False, _badge_cache=_badge_cache)

    # 作者不存在
    return schemas.UserInfo(
        id="unknown",
        name="已删除用户",
        avatar=None,
        is_admin=False,
        user_level=None,
    )


async def get_reply_author_info(
    db: AsyncSession,
    reply: models.ForumReply,
    request: Optional[Request] = None,
    _badge_cache: Optional[dict] = None,
) -> schemas.UserInfo:
    """获取回复作者信息（支持管理员回复）"""
    # 管理员回复
    if reply.admin_author_id:
        reply_inspect = inspect(reply)
        admin_attr = reply_inspect.attrs.admin_author
        if admin_attr.loaded_value is not NO_VALUE:
            admin_author = admin_attr.loaded_value
            if admin_author:
                return await build_admin_user_info(admin_author)
        else:
            admin_result = await db.execute(
                select(models.AdminUser).where(models.AdminUser.id == reply.admin_author_id)
            )
            admin_author = admin_result.scalar_one_or_none()
            if admin_author:
                return await build_admin_user_info(admin_author)
    
    # 普通用户回复
    if reply.author_id:
        reply_inspect = inspect(reply)
        author_attr = reply_inspect.attrs.author
        if author_attr.loaded_value is not NO_VALUE:
            author = author_attr.loaded_value
            if author:
                return await build_user_info(db, author, request, force_admin=False, _badge_cache=_badge_cache)
        else:
            author_result = await db.execute(
                select(models.User).where(models.User.id == reply.author_id)
            )
            author = author_result.scalar_one_or_none()
            if author:
                return await build_user_info(db, author, request, force_admin=False, _badge_cache=_badge_cache)
    
    return schemas.UserInfo(
        id="unknown",
        name="已删除用户",
        avatar=None,
        is_admin=False,
        user_level=None,
    )


def get_user_language_preference(
    current_user: Optional[models.User] = None,
    request: Optional[Request] = None
) -> str:
    """
    获取用户语言偏好
    优先级：用户设置 > Accept-Language 请求头 > 默认英文
    """
    # 1. 优先使用用户设置的语言偏好
    if current_user:
        language = getattr(current_user, 'language_preference', None)
        if language and isinstance(language, str):
            language = language.strip().lower()
            if language in ['zh', 'zh-cn', 'chinese']:
                return 'zh'
            elif language in ['en', 'en-us', 'english']:
                return 'en'
    
    # 2. 如果没有用户设置，尝试从请求头获取
    if request:
        accept_language = request.headers.get("Accept-Language", "")
        if accept_language:
            # 解析 Accept-Language 头（例如：zh-CN,zh;q=0.9,en;q=0.8）
            languages = accept_language.split(',')
            for lang in languages:
                lang = lang.split(';')[0].strip().lower()
                if lang.startswith('zh'):
                    return 'zh'
                elif lang.startswith('en'):
                    return 'en'
    
    # 3. 默认返回英文
    return 'en'


async def create_latest_post_info(
    latest_post: models.ForumPost,
    db: AsyncSession,
    request: Optional[Request] = None,
    current_user: Optional[models.User] = None
) -> schemas.LatestPostInfo:
    """
    创建最新帖子信息，根据用户语言选择正确的标题和预览内容
    """
    _badge_cache = await preload_badge_cache(db, [latest_post.author_id] if latest_post.author_id else [])
    author_info = await get_post_author_info(db, latest_post, request, _badge_cache=_badge_cache)
    display_view_count = await get_post_display_view_count(latest_post.id, latest_post.view_count)
    
    # 获取用户语言偏好
    user_lang = get_user_language_preference(current_user, request)
    
    # 根据用户语言选择标题
    display_title = latest_post.title
    title_en = getattr(latest_post, 'title_en', None)
    title_zh = getattr(latest_post, 'title_zh', None)
    if user_lang == 'zh' and title_zh:
        display_title = title_zh
    elif user_lang == 'en' and title_en:
        display_title = title_en
    
    # 生成内容预览（支持双语）
    content_preview = None
    content_preview_en = None
    content_preview_zh = None
    
    # 先解码内容，再生成预览
    from app.utils.bilingual_helper import _restore_encoding_markers
    content = latest_post.content
    if content:
        # 解码编码标记
        decoded_content = _restore_encoding_markers(content)
        content_preview = strip_markdown(decoded_content)
    
    if hasattr(latest_post, 'content_en') and latest_post.content_en:
        decoded_content_en = _restore_encoding_markers(latest_post.content_en)
        content_preview_en = strip_markdown(decoded_content_en)
    if hasattr(latest_post, 'content_zh') and latest_post.content_zh:
        decoded_content_zh = _restore_encoding_markers(latest_post.content_zh)
        content_preview_zh = strip_markdown(decoded_content_zh)
    
    # 根据用户语言选择预览内容
    display_preview = content_preview
    if user_lang == 'zh' and content_preview_zh:
        display_preview = content_preview_zh
    elif user_lang == 'en' and content_preview_en:
        display_preview = content_preview_en
    
    return schemas.LatestPostInfo(
        id=latest_post.id,
        title=display_title,
        title_en=title_en,
        title_zh=title_zh,
        content_preview=display_preview,
        content_preview_en=content_preview_en,
        content_preview_zh=content_preview_zh,
        author=author_info,
        last_reply_at=latest_post.last_reply_at or latest_post.created_at,
        reply_count=latest_post.reply_count,
        view_count=display_view_count
    )


def strip_markdown(text: str, max_length: int = 200) -> str:
    """去除 Markdown 标记并截断文本"""
    if not text:
        return ""
    
    # 如果内容是编码格式（包含 \n 或 \c 标记），先解码
    # 向后兼容：如果包含编码标记，先解码；否则直接处理
    if '\\n' in text or '\\c' in text:
        # 解码编码标记
        text = text.replace('\\n', '\n').replace('\\c', ' ')
    
    # 简单的 Markdown 去除（移除常见标记）
    text = re.sub(r'#{1,6}\s+', '', text)  # 标题
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # 粗体
    text = re.sub(r'\*([^*]+)\*', r'\1', text)  # 斜体
    text = re.sub(r'`([^`]+)`', r'\1', text)  # 行内代码
    text = re.sub(r'```[\s\S]*?```', '', text)  # 代码块
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)  # 链接
    text = re.sub(r'!\[([^\]]*)\]\([^\)]+\)', '', text)  # 图片
    text = re.sub(r'\n+', ' ', text)  # 换行符替换为空格
    text = text.strip()
    
    if len(text) > max_length:
        return text[:max_length] + "..."
    return text


def _parse_attachments(raw):
    """将 DB 中的 attachments JSON 转为 schema 对象列表（兼容 None / 空）"""
    if not raw:
        return None
    try:
        return [schemas.ForumPostAttachment(**a) for a in raw]
    except Exception:
        return None


async def _resolve_linked_item_name(db: AsyncSession, item_type: Optional[str], item_id: Optional[str]) -> Optional[str]:
    """根据 linked_item_type/id 查询关联内容的名称"""
    if not item_type or not item_id:
        return None
    try:
        if item_type == "service":
            sid = int(item_id)
            row = await db.execute(
                select(models.TaskExpertService.service_name)
                .where(models.TaskExpertService.id == sid)
            )
            return row.scalar_one_or_none()
        elif item_type == "product":
            pid = int(item_id)
            row = await db.execute(
                select(models.FleaMarketItem.title)
                .where(models.FleaMarketItem.id == pid, models.FleaMarketItem.is_visible == True)
            )
            return row.scalar_one_or_none()
        elif item_type == "expert":
            row = await db.execute(
                select(models.User.name)
                .where(models.User.id == item_id)
            )
            return row.scalar_one_or_none()
        elif item_type == "activity":
            aid = int(item_id)
            row = await db.execute(
                select(models.Activity.title)
                .where(models.Activity.id == aid)
            )
            return row.scalar_one_or_none()
        elif item_type == "ranking":
            rid = int(item_id)
            row = await db.execute(
                select(models.CustomLeaderboard.name)
                .where(models.CustomLeaderboard.id == rid)
            )
            return row.scalar_one_or_none()
        elif item_type == "forum_post":
            fid = int(item_id)
            row = await db.execute(
                select(models.ForumPost.title)
                .where(models.ForumPost.id == fid)
            )
            return row.scalar_one_or_none()
    except (ValueError, Exception):
        return None
    return None


async def get_post_with_permissions(
    post_id: int,
    current_user: Optional[models.User],
    is_admin: bool,
    db: AsyncSession,
    current_admin: Optional[models.AdminUser] = None
) -> models.ForumPost:
    """获取帖子并检查权限（处理软删除和隐藏，支持管理员作者）"""
    result = await db.execute(
        select(models.ForumPost)
        .options(
            selectinload(models.ForumPost.category),
            selectinload(models.ForumPost.author),
            selectinload(models.ForumPost.admin_author)
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
        # 检查是否是作者（普通用户或管理员）
        is_author = False
        if current_user and post.author_id == current_user.id:
            is_author = True
        if current_admin and post.admin_author_id == current_admin.id:
            is_author = True
        
        if not is_admin and not is_author:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="帖子不存在或已被隐藏",
                headers={"X-Error-Code": "POST_HIDDEN"}
            )
    
    return post


async def get_post_display_view_count(post_id: int, db_view_count: int) -> int:
    """获取帖子的显示浏览量（数据库值 + Redis增量）"""
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            redis_key = f"forum:post:view_count:{post_id}"
            redis_view_count = int(redis_client.get(redis_key) or 0)
            if redis_view_count > 0:
                return db_view_count + redis_view_count
    except Exception as e:
        logger.debug(f"Redis view count query failed for post {post_id}: {e}")
    return db_view_count


async def _batch_get_user_liked_favorited_posts(
    db: AsyncSession,
    user_id: str,
    post_ids: list[int],
) -> tuple[set[int], set[int]]:
    """
    批量获取当前用户对帖子的点赞/收藏状态，避免 N+1 查询。
    返回 (liked_post_ids, favorited_post_ids)
    """
    if not post_ids or not user_id:
        return set(), set()

    liked_result = await db.execute(
        select(models.ForumLike.target_id).where(
            models.ForumLike.target_type == "post",
            models.ForumLike.target_id.in_(post_ids),
            models.ForumLike.user_id == user_id,
        )
    )
    liked_ids = {row[0] for row in liked_result.all()}

    favorited_result = await db.execute(
        select(models.ForumFavorite.post_id).where(
            models.ForumFavorite.post_id.in_(post_ids),
            models.ForumFavorite.user_id == user_id,
        )
    )
    favorited_ids = {row[0] for row in favorited_result.all()}

    return liked_ids, favorited_ids


async def _batch_get_users_by_ids_async(db: AsyncSession, user_ids: list[str]) -> dict[str, models.User]:
    """批量获取用户，避免 N+1 查询"""
    if not user_ids:
        return {}
    user_ids = list(set(uid for uid in user_ids if uid))
    if not user_ids:
        return {}
    result_query = await db.execute(
        select(models.User).where(models.User.id.in_(user_ids))
    )
    users = result_query.scalars().all()
    return {u.id: u for u in users}


async def _batch_get_post_display_view_counts(
    posts: list,
) -> dict[int, int]:
    """
    批量获取帖子的显示浏览量（数据库值 + Redis 增量），避免多次 Redis 调用。
    返回 {post_id: display_count}
    """
    if not posts:
        return {}

    result = {p.id: (p.view_count or 0) for p in posts}
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            keys = [f"forum:post:view_count:{p.id}" for p in posts]
            redis_values = redis_client.mget(keys)
            for post, val in zip(posts, redis_values or []):
                redis_count = int(val or 0)
                if redis_count > 0:
                    result[post.id] = (post.view_count or 0) + redis_count
    except Exception as e:
        logger.debug(f"Redis MGET for view counts failed: {e}")
    return result


async def _batch_get_category_post_counts_and_latest_posts(
    db: AsyncSession,
    category_ids: list[int],
) -> tuple[dict[int, int], dict[int, models.ForumPost]]:
    """
    批量获取板块的帖子数和最新帖子，避免 N+1 查询。
    返回 (post_counts: {category_id: count}, latest_posts: {category_id: ForumPost})
    """
    if not category_ids:
        return {}, {}

    # 1. 批量获取帖子数
    count_result = await db.execute(
        select(models.ForumPost.category_id, func.count(models.ForumPost.id).label("cnt"))
        .where(
            models.ForumPost.category_id.in_(category_ids),
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
        )
        .group_by(models.ForumPost.category_id)
    )
    post_counts = {row[0]: row[1] for row in count_result.all()}

    # 2. 使用 ROW_NUMBER 批量获取每个板块的最新帖子
    rank = (
        func.row_number()
        .over(
            partition_by=models.ForumPost.category_id,
            order_by=func.coalesce(
                models.ForumPost.last_reply_at,
                models.ForumPost.created_at,
            ).desc(),
        )
        .label("rn")
    )
    subq = (
        select(models.ForumPost.id, models.ForumPost.category_id, rank)
        .where(
            models.ForumPost.category_id.in_(category_ids),
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
        )
    ).subquery()
    latest_ids_stmt = select(subq.c.id).where(subq.c.rn == 1)
    latest_posts_result = await db.execute(
        select(models.ForumPost)
        .where(models.ForumPost.id.in_(latest_ids_stmt))
        .options(
            selectinload(models.ForumPost.author),
            selectinload(models.ForumPost.admin_author),
        )
    )
    latest_posts = {p.category_id: p for p in latest_posts_result.scalars().all()}

    return post_counts, latest_posts


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

@router.get("/forums/visible", response_model=schemas.ForumCategoryListResponse)
async def get_visible_forums(
    include_all: bool = Query(False, description="管理员查看全部板块"),
    view_as: Optional[str] = Query(None, description="管理员以指定用户视角查看（需管理员权限）"),
    include_latest_post: bool = Query(False, description="是否包含每个板块的最新帖子信息"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    获取当前用户可见的板块列表
    
    参数说明：
    - include_all: 管理员查看全部板块（带 can_manage=true 字段）
    - view_as: 管理员以指定用户ID视角查看可见板块（用于客服/排错场景）
    
    重要：前端必须使用此接口获取板块列表，禁止硬编码或直接查询所有板块。
    """
    # 管理员特殊处理：以指定用户视角查看
    if view_as:
        # 检查是否为管理员
        try:
            admin_user = await get_current_admin_async(request, db)
            if admin_user:
                target_user_result = await db.execute(
                    select(models.User).where(models.User.id == view_as)
                )
                target_user = target_user_result.scalar_one_or_none()
                if not target_user:
                    raise HTTPException(status_code=404, detail="User not found")
                
                visible_ids = await visible_forums(target_user, db)
                if not visible_ids:
                    # 返回普通板块（用户可以查看，但不能发帖）
                    forums_result = await db.execute(
                        select(models.ForumCategory)
                        .where(
                            models.ForumCategory.type.in_(['general', 'skill']),
                            models.ForumCategory.is_visible == True
                        )
                        .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
                    )
                    forums = forums_result.scalars().all()

                    # 如果需要包含最新帖子信息
                    if include_latest_post:
                        category_ids = [c.id for c in forums]
                        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                            db, category_ids
                        )
                        category_list = []
                        for category in forums:
                            real_post_count = post_counts.get(category.id, 0)
                            latest_post = latest_posts.get(category.id)
                            latest_post_info = None
                            if latest_post:
                                latest_post_info = await create_latest_post_info(
                                    latest_post, db, request, current_user
                                )
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
                                post_count=real_post_count,
                                service_count=getattr(category, 'service_count', 0),
                                task_count=getattr(category, 'task_count', 0),
                                latest_post=latest_post_info,
                                created_at=category.created_at,
                                updated_at=category.updated_at
                            )
                            category_list.append(category_out)

                        return {"categories": category_list}

                    return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

                # 返回该用户可见的板块（用户可以查看，但不能发帖）
                school_forums_result = await db.execute(
                    select(models.ForumCategory).where(
                        models.ForumCategory.id.in_(visible_ids),
                        models.ForumCategory.is_visible == True
                    )
                )
                general_forums_result = await db.execute(
                    select(models.ForumCategory).where(
                        models.ForumCategory.type.in_(['general', 'skill']),
                        models.ForumCategory.is_visible == True
                    )
                )
                school_forums = school_forums_result.scalars().all()
                general_forums = general_forums_result.scalars().all()
                
                # 合并并排序
                all_forums = list(school_forums) + list(general_forums)
                all_forums.sort(key=lambda x: (x.sort_order, x.created_at))
                
                # 如果需要包含最新帖子信息
                if include_latest_post:
                    category_ids = [c.id for c in all_forums]
                    post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                        db, category_ids
                    )
                    category_list = []
                    for category in all_forums:
                        real_post_count = post_counts.get(category.id, 0)
                        latest_post = latest_posts.get(category.id)
                        latest_post_info = None
                        if latest_post:
                            latest_post_info = await create_latest_post_info(
                                latest_post, db, request, current_user
                            )
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
                            post_count=real_post_count,
                            service_count=getattr(category, 'service_count', 0),
                            task_count=getattr(category, 'task_count', 0),
                            latest_post=latest_post_info,
                            created_at=category.created_at,
                            updated_at=category.updated_at
                        )
                        category_list.append(category_out)

                    return {"categories": category_list}
                
                return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in all_forums]}
        except HTTPException:
            # 非管理员使用 view_as 参数应被忽略
            pass
    
    # 管理员特殊处理：查看全部板块
    if include_all:
        try:
            admin_user = await get_current_admin_async(request, db)
            if admin_user:
                forums_result = await db.execute(
                    select(models.ForumCategory)
                    .where(models.ForumCategory.is_visible == True)
                    .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
                )
                forums = forums_result.scalars().all()
                
                # 如果需要包含最新帖子信息
                if include_latest_post:
                    category_ids = [c.id for c in forums]
                    post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                        db, category_ids
                    )
                    category_list = []
                    for category in forums:
                        real_post_count = post_counts.get(category.id, 0)
                        latest_post = latest_posts.get(category.id)
                        latest_post_info = None
                        if latest_post:
                            latest_post_info = await create_latest_post_info(
                                latest_post, db, request, current_user
                            )
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
                            post_count=real_post_count,
                            service_count=getattr(category, 'service_count', 0),
                            task_count=getattr(category, 'task_count', 0),
                            latest_post=latest_post_info,
                            created_at=category.created_at,
                            updated_at=category.updated_at
                        )
                        category_dict = category_out.model_dump()
                        category_dict["can_manage"] = True
                        category_list.append(category_dict)
                    
                    return {"categories": category_list}
                
                # 不需要最新帖子信息，直接返回
                categories = []
                for forum in forums:
                    forum_dict = schemas.ForumCategoryOut.model_validate(forum).model_dump()
                    forum_dict["can_manage"] = True
                    categories.append(forum_dict)
                return {"categories": categories}
        except HTTPException:
            # 非管理员使用 include_all 参数应被忽略
            pass
    
    # 普通用户：根据身份返回可见板块
    # 注意：is_admin_only 只控制发帖权限，不影响查看权限，所以这里不过滤 is_admin_only
    if not current_user:
        # 未登录：返回普通板块和技能板块（用户可以查看，但不能发帖）
        forums_result = await db.execute(
            select(models.ForumCategory)
            .where(
                models.ForumCategory.type.in_(['general', 'skill']),
                models.ForumCategory.is_visible == True
            )
            .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
        )
        forums = forums_result.scalars().all()
        
        # 如果需要包含最新帖子信息
        if include_latest_post:
            category_ids = [c.id for c in forums]
            post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                db, category_ids
            )
            category_list = []
            for category in forums:
                real_post_count = post_counts.get(category.id, 0)
                latest_post = latest_posts.get(category.id)
                latest_post_info = None
                if latest_post:
                    latest_post_info = await create_latest_post_info(
                        latest_post, db, request, current_user
                    )
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
                    post_count=real_post_count,
                    service_count=getattr(category, 'service_count', 0),
                    task_count=getattr(category, 'task_count', 0),
                    latest_post=latest_post_info,
                    created_at=category.created_at,
                    updated_at=category.updated_at
                )
                category_list.append(category_out)

            return {"categories": category_list}

        return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

    # 检查是否为学生认证用户
    logger.info(f"get_visible_forums: current_user={current_user.id if current_user else None}")
    visible_ids = await visible_forums(current_user, db)
    logger.info(f"get_visible_forums: visible_ids={visible_ids}")

    if not visible_ids:
        # 未学生认证：返回普通板块和技能板块（用户可以查看，但不能发帖）
        forums_result = await db.execute(
            select(models.ForumCategory)
            .where(
                models.ForumCategory.type.in_(['general', 'skill']),
                models.ForumCategory.is_visible == True
            )
            .order_by(models.ForumCategory.sort_order, models.ForumCategory.created_at)
        )
        forums = forums_result.scalars().all()
        
        # 如果需要包含最新帖子信息
        if include_latest_post:
            category_ids = [c.id for c in forums]
            post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
                db, category_ids
            )
            category_list = []
            for category in forums:
                real_post_count = post_counts.get(category.id, 0)
                latest_post = latest_posts.get(category.id)
                latest_post_info = None
                if latest_post:
                    latest_post_info = await create_latest_post_info(
                        latest_post, db, request, current_user
                    )
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
                    post_count=real_post_count,
                    service_count=getattr(category, 'service_count', 0),
                    task_count=getattr(category, 'task_count', 0),
                    latest_post=latest_post_info,
                    created_at=category.created_at,
                    updated_at=category.updated_at
                )
                category_list.append(category_out)

            return {"categories": category_list}

        return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in forums]}

    # 已认证学生：返回普通板块 + 技能板块 + 可见的学校板块（用户可以查看，但不能发帖）
    school_forums_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.id.in_(visible_ids),
            models.ForumCategory.is_visible == True
        )
    )
    general_forums_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.type.in_(['general', 'skill']),
            models.ForumCategory.is_visible == True
        )
    )
    school_forums = school_forums_result.scalars().all()
    general_forums = general_forums_result.scalars().all()
    
    # 合并并排序
    all_forums = list(school_forums) + list(general_forums)
    all_forums.sort(key=lambda x: (x.sort_order, x.created_at))
    
    # 如果需要包含最新帖子信息
    if include_latest_post:
        category_ids = [c.id for c in all_forums]
        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
            db, category_ids
        )
        category_list = []
        for category in all_forums:
            real_post_count = post_counts.get(category.id, 0)
            latest_post = latest_posts.get(category.id)
            latest_post_info = None
            if latest_post:
                latest_post_info = await create_latest_post_info(
                    latest_post, db, request, None
                )
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
                post_count=real_post_count,
                service_count=getattr(category, 'service_count', 0),
                task_count=getattr(category, 'task_count', 0),
                latest_post=latest_post_info,
                created_at=category.created_at,
                updated_at=category.updated_at
            )
            category_list.append(category_out)
        return {"categories": category_list}
    return {"categories": [schemas.ForumCategoryOut.model_validate(f) for f in all_forums]}


@router.get("/categories", response_model=schemas.ForumCategoryListResponse)
@measure_api_performance("get_categories")
@cache_response(ttl=300, key_prefix="forum_categories")  # 缓存5分钟
async def get_categories(
    request: Request,
    include_latest_post: bool = Query(False, description="是否包含每个板块的最新帖子信息"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块列表（已应用缓存和性能监控）
    
    可选参数：
    - include_latest_post: 如果为 True，每个板块会包含最新帖子的简要信息（标题、作者、最后回复时间等）
    注意：分类列表只显示对普通用户可见的最新帖子（is_visible == True）
    """
    result = await db.execute(
        select(models.ForumCategory)
        .where(models.ForumCategory.is_visible == True)
        .order_by(models.ForumCategory.sort_order.asc(), models.ForumCategory.id.asc())
    )
    categories = result.scalars().all()
    
    # 如果需要包含最新帖子信息，需要手动构建响应
    if include_latest_post:
        category_ids = [c.id for c in categories]
        post_counts, latest_posts = await _batch_get_category_post_counts_and_latest_posts(
            db, category_ids
        )
        category_list = []
        for category in categories:
            real_post_count = post_counts.get(category.id, 0)
            latest_post = latest_posts.get(category.id)
            latest_post_info = None
            if latest_post:
                latest_post_info = await create_latest_post_info(
                    latest_post, db, request, None
                )
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
                post_count=real_post_count,
                service_count=getattr(category, 'service_count', 0),
                task_count=getattr(category, 'task_count', 0),
                last_post_at=category.last_post_at,
                created_at=category.created_at,
                updated_at=category.updated_at,
                latest_post=latest_post_info
            )

            category_list.append(category_out)
        
        return {"categories": category_list}
    
    # 标准返回（不包含最新帖子信息）- 需要显式序列化以包含多语言字段
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


# ==================== 板块申请相关路由（必须在 /categories/{category_id} 之前） ====================

@router.post("/categories/request", response_model=schemas.ForumCategoryRequestResponse)
async def request_new_category(
    request_data: schemas.ForumCategoryRequestCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请新建板块（普通用户）"""
    try:
        # 规范化输入：去除首尾空格
        normalized_name = request_data.name.strip()
        
        # 检查板块名称是否已存在（包括已存在的板块和已通过的申请）
        existing_category = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.name == normalized_name)
        )
        if existing_category.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="板块名称已存在，请选择其他名称"
            )
        
        # 检查是否有已通过的申请使用了相同名称
        approved_request = await db.execute(
            select(models.ForumCategoryRequest).where(
                and_(
                    models.ForumCategoryRequest.name == normalized_name,
                    models.ForumCategoryRequest.status == "approved"
                )
            )
        )
        if approved_request.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="该板块名称已被其他申请使用，请选择其他名称"
            )
        
        # 检查用户是否已有相同名称的待审核申请
        existing_request = await db.execute(
            select(models.ForumCategoryRequest).where(
                and_(
                    models.ForumCategoryRequest.requester_id == current_user.id,
                    models.ForumCategoryRequest.name == normalized_name,
                    models.ForumCategoryRequest.status == "pending"
                )
            )
        )
        if existing_request.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="您已提交过相同名称的申请，请等待审核"
            )
        
        # 自动填充双语字段
        from app.utils.bilingual_helper import auto_fill_bilingual_fields
        
        normalized_description = request_data.description.strip() if request_data.description else None
        _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
            name=normalized_name,
            description=normalized_description,
            name_en=request_data.name_en.strip() if request_data.name_en else None,
            name_zh=request_data.name_zh.strip() if request_data.name_zh else None,
            description_en=request_data.description_en.strip() if request_data.description_en else None,
            description_zh=request_data.description_zh.strip() if request_data.description_zh else None,
        )
        
        # 创建申请
        new_request = models.ForumCategoryRequest(
            requester_id=current_user.id,
            name=normalized_name,
            name_en=name_en,
            name_zh=name_zh,
            description=normalized_description,
            description_en=description_en,
            description_zh=description_zh,
            icon=request_data.icon.strip() if request_data.icon else None,
            type=request_data.type,
            country=request_data.country,
            university_code=request_data.university_code,
            status="pending"
        )
        
        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)
        
        logger.info(f"用户 {current_user.id} 提交了板块申请: {normalized_name}")
        
        return {
            "message": "申请已提交，等待管理员审核",
            "id": new_request.id,
            "request": {
                "id": new_request.id,
                "name": new_request.name,
                "status": new_request.status,
                "created_at": new_request.created_at
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"提交板块申请失败: {e}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="提交申请时发生错误，请稍后重试"
        )


@router.get("/categories/requests", response_model=schemas.ForumCategoryRequestListOut)
async def get_category_requests(
    status: Optional[str] = Query(None, pattern="^(pending|approved|rejected)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="搜索板块名称或申请人"),
    sort_by: Optional[str] = Query("created_at", pattern="^(created_at|reviewed_at|status)$"),
    sort_order: Optional[str] = Query("desc", pattern="^(asc|desc)$"),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块申请列表（管理员）"""
    # 总数（与列表相同筛选条件）
    count_query = select(func.count()).select_from(models.ForumCategoryRequest)
    if status:
        count_query = count_query.where(models.ForumCategoryRequest.status == status)
    if search:
        search_term = f"%{search.strip()}%"
        count_query = count_query.where(
            or_(
                models.ForumCategoryRequest.name.ilike(search_term),
                models.ForumCategoryRequest.requester_id.ilike(search_term)
            )
        )
    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0
    # 列表查询（带 options、排序、分页）
    query = select(models.ForumCategoryRequest).options(
        selectinload(models.ForumCategoryRequest.requester),
        selectinload(models.ForumCategoryRequest.admin)
    )
    if status:
        query = query.where(models.ForumCategoryRequest.status == status)
    if search:
        search_term = f"%{search.strip()}%"
        query = query.where(
            or_(
                models.ForumCategoryRequest.name.ilike(search_term),
                models.ForumCategoryRequest.requester_id.ilike(search_term)
            )
        )
    if sort_by == "reviewed_at":
        order_col = models.ForumCategoryRequest.reviewed_at
    elif sort_by == "status":
        order_col = models.ForumCategoryRequest.status
    else:
        order_col = models.ForumCategoryRequest.created_at
    if sort_order == "asc":
        query = query.order_by(asc(order_col))
    else:
        query = query.order_by(desc(order_col))
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    result = await db.execute(query)
    requests = result.scalars().all()
    items = []
    for req in requests:
        request_dict = {
            "id": req.id,
            "requester_id": req.requester_id,
            "requester_name": req.requester.name if req.requester else None,
            "requester_avatar": req.requester.avatar if req.requester else None,
            "name": req.name,
            "description": req.description,
            "icon": req.icon,
            "type": req.type,
            "country": req.country,
            "university_code": req.university_code,
            "status": req.status,
            "admin_id": req.admin_id,
            "admin_name": req.admin.name if req.admin else None,
            "reviewed_at": req.reviewed_at,
            "review_comment": req.review_comment,
            "created_at": req.created_at,
            "updated_at": req.updated_at
        }
        items.append(schemas.ForumCategoryRequestOut(**request_dict))
    return schemas.ForumCategoryRequestListOut(items=items, total=total)


@router.get("/categories/requests/my", response_model=List[schemas.ForumCategoryRequestOut])
async def get_my_category_requests(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None, pattern="^(pending|approved|rejected)$"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的板块申请列表（普通用户）"""
    query = select(models.ForumCategoryRequest).options(
        selectinload(models.ForumCategoryRequest.requester),
        selectinload(models.ForumCategoryRequest.admin)
    ).where(models.ForumCategoryRequest.requester_id == current_user.id)
    
    # 状态筛选
    if status:
        query = query.where(models.ForumCategoryRequest.status == status)
    
    query = query.order_by(desc(models.ForumCategoryRequest.created_at))
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    result = await db.execute(query)
    requests = result.scalars().all()
    
    # 构建响应
    response = []
    for req in requests:
        request_dict = {
            "id": req.id,
            "requester_id": req.requester_id,
            "requester_name": req.requester.name if req.requester else None,
            "requester_avatar": req.requester.avatar if req.requester else None,
            "name": req.name,
            "description": req.description,
            "icon": req.icon,
            "type": req.type,
            "country": req.country,
            "university_code": req.university_code,
            "status": req.status,
            "admin_id": req.admin_id,
            "admin_name": req.admin.name if req.admin else None,
            "reviewed_at": req.reviewed_at,
            "review_comment": req.review_comment,
            "created_at": req.created_at,
            "updated_at": req.updated_at
        }
        response.append(schemas.ForumCategoryRequestOut(**request_dict))
    
    return response


@router.put("/categories/requests/{request_id}/review")
async def review_category_request(
    request_id: int,
    action: str = Query(..., pattern="^(approve|reject)$"),
    review_comment: Optional[str] = None,
    request: Request = None,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核板块申请（管理员）"""
    result = await db.execute(
        select(models.ForumCategoryRequest).where(models.ForumCategoryRequest.id == request_id)
    )
    category_request = result.scalar_one_or_none()
    
    if not category_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="申请不存在"
        )
    
    if category_request.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该申请已被审核"
        )
    
    if action == "approve":
        # 批准申请，创建新板块
        # 如果申请中没有双语字段，自动填充
        if not category_request.name_en or not category_request.name_zh:
            from app.utils.bilingual_helper import auto_fill_bilingual_fields
            _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
                name=category_request.name,
                description=category_request.description,
                name_en=category_request.name_en,
                name_zh=category_request.name_zh,
                description_en=category_request.description_en,
                description_zh=category_request.description_zh,
            )
        else:
            name_en = category_request.name_en
            name_zh = category_request.name_zh
            description_en = category_request.description_en
            description_zh = category_request.description_zh
        
        new_category = models.ForumCategory(
            name=category_request.name,
            name_en=name_en,
            name_zh=name_zh,
            description=category_request.description,
            description_en=description_en,
            description_zh=description_zh,
            icon=category_request.icon,
            type=category_request.type,
            country=category_request.country,
            university_code=category_request.university_code,
            is_visible=True,
            sort_order=0
        )
        db.add(new_category)
        
        category_request.status = "approved"
        category_request.admin_id = current_admin.id
        category_request.reviewed_at = get_utc_time()
        category_request.review_comment = review_comment
        
        await db.commit()
        await db.refresh(new_category)
        await db.refresh(category_request)
        
        logger.info(f"管理员 {current_admin.id} 批准了板块申请 {request_id}，创建了板块 {new_category.id}")
        
        # 发送批准通知给申请人
        try:
            from app import async_crud
            
            title = "板块申请已通过"
            title_en = "Forum Category Application Approved"
            content = f"恭喜！您申请的板块「{category_request.name}」已通过审核，现已创建。"
            content_en = f"Congratulations! Your forum category application '{category_request.name}' has been approved and is now created."
            
            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=category_request.requester_id,
                notification_type="forum_category_approved",
                title=title,
                content=content,
                title_en=title_en,
                content_en=content_en,
                related_id=str(new_category.id),
                related_type="forum_category"
            )
            
            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    db=db,
                    user_id=category_request.requester_id,
                    notification_type="forum_category_approved",
                    data={"category_id": new_category.id},
                    template_vars={
                        "category_name": category_request.name
                    }
                )
            except Exception as e:
                logger.warning(f"发送板块批准推送通知失败: {e}")
            
            logger.info(f"板块申请批准通知已发送给申请人: {category_request.requester_id}")
        except Exception as e:
            logger.error(f"发送板块申请批准通知失败: {e}")
            # 通知失败不影响审核流程
        
        # 清理板块列表缓存
        try:
            from app.cache import invalidate_cache
            invalidate_cache("forum_categories*")
            clear_all_forum_visibility_cache(f"新板块 {new_category.id} 已创建")
        except Exception as e:
            logger.warning(f"清理板块缓存失败: {e}")
        
        return {
            "message": "申请已批准，新板块已创建",
            "category": schemas.ForumCategoryOut.model_validate(new_category),
            "request": schemas.ForumCategoryRequestOut.model_validate(category_request)
        }
    else:
        # 拒绝申请
        category_request.status = "rejected"
        category_request.admin_id = current_admin.id
        category_request.reviewed_at = get_utc_time()
        category_request.review_comment = review_comment
        
        await db.commit()
        await db.refresh(category_request)
        
        logger.info(f"管理员 {current_admin.id} 拒绝了板块申请 {request_id}")
        
        # 发送拒绝通知给申请人
        try:
            from app import async_crud
            
            title = "板块申请未通过"
            title_en = "Forum Category Application Rejected"
            content = f"很抱歉，您申请的板块「{category_request.name}」未通过审核。"
            if review_comment:
                content += f"\n审核意见：{review_comment}"
            content_en = f"Sorry, your forum category application '{category_request.name}' has been rejected."
            if review_comment:
                content_en += f"\nReview comment: {review_comment}"
            
            await async_crud.async_notification_crud.create_notification(
                db=db,
                user_id=category_request.requester_id,
                notification_type="forum_category_rejected",
                title=title,
                content=content,
                title_en=title_en,
                content_en=content_en,
                related_id=None,
                related_type="forum_category_request"
            )
            
            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    db=db,
                    user_id=category_request.requester_id,
                    notification_type="forum_category_rejected",
                    data={"request_id": request_id},
                    template_vars={
                        "category_name": category_request.name
                    }
                )
            except Exception as e:
                logger.warning(f"发送板块拒绝推送通知失败: {e}")
            
            logger.info(f"板块申请拒绝通知已发送给申请人: {category_request.requester_id}")
        except Exception as e:
            logger.error(f"发送板块申请拒绝通知失败: {e}")
            # 通知失败不影响审核流程
        
        return {
            "message": "申请已拒绝",
            "request": schemas.ForumCategoryRequestOut.model_validate(category_request)
        }


# ==================== 板块详情路由（必须在 /categories/requests 之后） ====================

@router.get("/categories/{category_id}", response_model=schemas.ForumCategoryOut)
@measure_api_performance("get_forum_category")
async def get_category(
    category_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取板块详情"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    result = await db.execute(
        select(models.ForumCategory).where(models.ForumCategory.id == category_id)
    )
    category = result.scalar_one_or_none()
    
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="板块不存在"
        )
    
    # 检查板块可见性（学校板块需要权限，管理员可以绕过）
    if not is_admin:
        await assert_forum_visible(current_user, category_id, db, raise_exception=True)
    
    # 记录浏览量（Redis 累加，定时同步到 DB）
    try:
        from app.redis_cache import get_redis_client
        _rc = get_redis_client()
        if _rc:
            _rk = f"forum:category:view_count:{category_id}"
            _rc.incr(_rk)
            _rc.expire(_rk, 7 * 24 * 3600)
        else:
            category.view_count += 1
            await db.flush()
    except Exception:
        category.view_count += 1
        await db.flush()

    # 显式创建 ForumCategoryOut 对象，确保包含双语字段
    return schemas.ForumCategoryOut(
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
    
    # 验证学校板块字段
    category_type = category.type or 'general'
    if category_type == 'university':
        if not category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块必须提供university_code"
            )
        # 验证大学编码是否存在
        university = await db.execute(
            select(models.University).where(models.University.code == category.university_code)
        )
        if not university.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"大学编码 '{category.university_code}' 不存在"
            )
        # university类型板块不应有country字段
        if category.country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块不应设置country字段"
            )
    elif category_type == 'root':
        if not category.country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块必须提供country字段"
            )
        # root类型板块不应有university_code字段
        if category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块不应设置university_code字段"
            )
    else:  # general
        # general类型板块不应有country和university_code字段
        if category.country or category.university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="general类型板块不应设置country或university_code字段"
            )
    
    # 自动填充双语字段
    from app.utils.bilingual_helper import auto_fill_bilingual_fields
    
    normalized_description = category.description.strip() if category.description else None
    _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
        name=category.name,
        description=normalized_description,
        name_en=category.name_en.strip() if category.name_en else None,
        name_zh=category.name_zh.strip() if category.name_zh else None,
        description_en=category.description_en.strip() if category.description_en else None,
        description_zh=category.description_zh.strip() if category.description_zh else None,
    )
    
    # 创建板块对象，包含双语字段
    category_dict = category.model_dump()
    category_dict['name_en'] = name_en
    category_dict['name_zh'] = name_zh
    category_dict['description_en'] = description_en
    category_dict['description_zh'] = description_zh
    
    db_category = models.ForumCategory(**category_dict)
    db.add(db_category)
    await db.flush()
    
    # 如果创建的是学校板块或 is_admin_only 板块，清理所有用户的可见板块缓存
    if (db_category.type in ('root', 'university') or db_category.is_admin_only):
        clear_all_forum_visibility_cache(f"新板块 {db_category.id} 已创建")
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="create_category",
        target_type="category",
        target_id=db_category.id,
        action="create",
        request=request,
        db=db
    )
    
    await db.commit()
    await db.refresh(db_category)
    
    # 清理板块列表缓存
    try:
        from app.cache import invalidate_cache
        invalidate_cache("forum_categories*")
    except Exception as e:
        logger.warning(f"清理板块缓存失败: {e}")
    
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
    
    # 确定板块类型（如果更新了type，使用新值；否则使用当前值）
    category_type = category.type if category.type is not None else db_category.type
    
    # 验证学校板块字段
    if category_type == 'university':
        university_code = category.university_code if category.university_code is not None else db_category.university_code
        if not university_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块必须提供university_code"
            )
        # 验证大学编码是否存在
        university = await db.execute(
            select(models.University).where(models.University.code == university_code)
        )
        if not university.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"大学编码 '{university_code}' 不存在"
            )
        # university类型板块不应有country字段
        if category.country is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university类型板块不应设置country字段"
            )
    elif category_type == 'root':
        country = category.country if category.country is not None else db_category.country
        if not country:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块必须提供country字段"
            )
        # root类型板块不应有university_code字段
        if category.university_code is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="root类型板块不应设置university_code字段"
            )
    else:  # general
        # general类型板块不应有country和university_code字段
        if category.country is not None or category.university_code is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="general类型板块不应设置country或university_code字段"
            )
    
    # 记录更新前的类型、is_admin_only 和 is_visible（用于判断是否需要清理缓存）
    old_type = db_category.type
    old_university_code = db_category.university_code
    old_country = db_category.country
    old_is_admin_only = db_category.is_admin_only
    old_is_visible = db_category.is_visible
    
    # 更新字段
    update_data = category.model_dump(exclude_unset=True)
    
    # 若客户端提交了双语字段则直接使用；否则若更新了 name/description 则用 auto_fill 填充
    if any(k in update_data for k in ('name_en', 'name_zh', 'description_en', 'description_zh')):
        # 直接使用管理员填写的双语字段，不覆盖
        pass
    elif 'name' in update_data or 'description' in update_data:
        from app.utils.bilingual_helper import auto_fill_bilingual_fields
        
        updated_name = update_data.get('name', db_category.name)
        updated_description = update_data.get('description', db_category.description)
        
        _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
            name=updated_name,
            description=updated_description,
            name_en=db_category.name_en,
            name_zh=db_category.name_zh,
            description_en=db_category.description_en,
            description_zh=db_category.description_zh,
        )
        update_data['name_en'] = name_en
        update_data['name_zh'] = name_zh
        update_data['description_en'] = description_en
        update_data['description_zh'] = description_zh
    
    for field, value in update_data.items():
        setattr(db_category, field, value)
    
    db_category.updated_at = get_utc_time()
    await db.flush()
    
    # 如果板块类型、关联信息、is_admin_only 或 is_visible 发生变化，需要清理所有相关用户的缓存
    new_type = db_category.type
    new_university_code = db_category.university_code
    new_country = db_category.country
    new_is_admin_only = db_category.is_admin_only
    new_is_visible = db_category.is_visible
    
    if (old_type != new_type or 
        old_university_code != new_university_code or 
        old_country != new_country or
        old_is_admin_only != new_is_admin_only or
        old_is_visible != new_is_visible):
        # 清理所有用户的可见板块缓存（因为板块可见性可能已改变）
        clear_all_forum_visibility_cache(f"板块 {category_id} 信息变更")
    
    # 记录管理员操作日志
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="update_category",
        target_type="category",
        target_id=category_id,
        action="update",
        request=request,
        db=db
    )
    
    await db.commit()
    await db.refresh(db_category)
    
    # 清理板块列表缓存
    try:
        from app.cache import invalidate_cache
        invalidate_cache("forum_categories*")
        invalidate_cache(f"forum_category:{category_id}*")
        # 如果可见性相关字段发生变化，清理所有用户的可见板块缓存
        if (old_type != new_type or 
            old_university_code != new_university_code or 
            old_country != new_country or
            old_is_admin_only != new_is_admin_only or
            old_is_visible != new_is_visible):
            clear_all_forum_visibility_cache(f"板块 {category_id} 信息更新")
    except Exception as e:
        logger.warning(f"清理板块缓存失败: {e}")
    
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
    
    # 记录删除前的类型和 is_admin_only（用于判断是否需要清理缓存）
    category_type = category.type
    category_is_admin_only = category.is_admin_only
    
    # 记录管理员操作日志（在删除前记录）
    await log_admin_operation(
        operator_id=current_admin.id,
        operation_type="delete_category",
        target_type="category",
        target_id=category_id,
        action="delete",
        request=request,
        db=db
    )
    
    await db.delete(category)
    await db.commit()
    
    # 如果删除的是学校板块或 is_admin_only 板块，清理所有用户的可见板块缓存
    if category_type in ('root', 'university') or category_is_admin_only:
        clear_all_forum_visibility_cache(f"板块 {category_id} 已删除")
    
    return {"message": "板块删除成功"}


# ==================== Skill Feed Helpers ====================

def _parse_json_field(value) -> list:
    """Parse a JSON text field into a list, returning [] on failure."""
    import json as _json
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            parsed = _json.loads(value)
            return parsed if isinstance(parsed, list) else []
        except (ValueError, TypeError):
            return []
    return []


def _post_to_feed_data(post: models.ForumPost) -> dict:
    """Convert a ForumPost to feed data dict."""
    author_data = None
    if hasattr(post, 'author') and post.author:
        author_data = {
            "id": post.author.id,
            "name": post.author.name,
            "avatar": getattr(post.author, 'avatar', None),
        }
    elif hasattr(post, 'author_id'):
        author_data = {"id": post.author_id, "name": "", "avatar": None}
    return {
        "id": post.id,
        "title": post.title,
        "title_en": post.title_en,
        "title_zh": post.title_zh,
        "content_preview": (post.content or "")[:200],
        "content_preview_en": (post.content_en or "")[:200] if post.content_en else None,
        "content_preview_zh": (post.content_zh or "")[:200] if post.content_zh else None,
        "author": author_data,
        "view_count": post.view_count or 0,
        "reply_count": post.reply_count or 0,
        "like_count": post.like_count or 0,
        "is_pinned": post.is_pinned or False,
        "images": _parse_json_field(post.images),
        "created_at": post.created_at.isoformat() if post.created_at else None,
        "last_reply_at": post.last_reply_at.isoformat() if post.last_reply_at else None,
    }


def _task_to_feed_data(task: models.Task) -> dict:
    """Convert a Task to feed data dict."""
    poster_data = None
    if hasattr(task, 'poster') and task.poster:
        poster_data = {
            "id": task.poster.id,
            "name": task.poster.name,
            "avatar": getattr(task.poster, 'avatar', None),
        }
    elif hasattr(task, 'poster_id'):
        poster_data = {"id": task.poster_id, "name": "", "avatar": None}
    return {
        "id": task.id,
        "title": task.title,
        "title_en": task.title_en,
        "title_zh": task.title_zh,
        "task_type": task.task_type,
        "reward": float(task.reward) if task.reward else 0,
        "currency": task.currency or "GBP",
        "status": task.status,
        "pricing_type": task.pricing_type,
        "location": task.location,
        "deadline": task.deadline.isoformat() if task.deadline else None,
        "poster": poster_data,
        "images": _parse_json_field(task.images),
        "required_skills": _parse_json_field(task.required_skills),
        "created_at": task.created_at.isoformat() if task.created_at else None,
    }


def _service_to_feed_data(service: models.TaskExpertService) -> dict:
    """Convert a TaskExpertService to feed data dict."""
    return {
        "id": service.id,
        "service_name": service.service_name,
        "service_name_en": getattr(service, 'service_name_en', None),
        "service_name_zh": getattr(service, 'service_name_zh', None),
        "description": (service.description or "")[:200],
        "description_en": ((service.description_en or "")[:200]) if getattr(service, 'description_en', None) else None,
        "description_zh": ((service.description_zh or "")[:200]) if getattr(service, 'description_zh', None) else None,
        "base_price": float(service.base_price) if service.base_price else 0,
        "currency": service.currency or "GBP",
        "pricing_type": service.pricing_type,
        "location_type": service.location_type,
        "images": service.images if isinstance(service.images, list) else [],
        "skills": service.skills if isinstance(service.skills, list) else [],
        "status": service.status,
        "view_count": service.view_count or 0,
        "application_count": service.application_count or 0,
        "owner_name": getattr(service, 'owner_name', None),
        "owner_avatar": getattr(service, 'owner_avatar', None),
        "owner_rating": float(service.owner_rating) if getattr(service, 'owner_rating', None) else None,
        "expert_id": service.expert_id,
        "service_type": service.service_type,
        "created_at": service.created_at.isoformat() if service.created_at else None,
    }


# ==================== Skill Feed Endpoint ====================

@router.get("/categories/{category_id}/feed", response_model=schemas.SkillFeedResponse)
async def get_skill_feed(
    category_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str = Query("weight", pattern="^(weight|time)$"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取技能板块的混合 feed（帖子 + 任务 + 服务）"""
    import datetime as _datetime

    # 1. Validate category exists and is a skill type
    cat_result = await db.execute(
        select(models.ForumCategory).where(
            models.ForumCategory.id == category_id,
            models.ForumCategory.is_visible == True,
        )
    )
    category = cat_result.scalar_one_or_none()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    if category.type != "skill" or not category.skill_type:
        raise HTTPException(status_code=400, detail="Not a skill category")

    skill_type = category.skill_type
    now = get_utc_time()
    twenty_four_hours_ago = now - _datetime.timedelta(hours=24)

    # 2. Query posts for this category
    posts_query = (
        select(models.ForumPost)
        .options(selectinload(models.ForumPost.author))
        .where(
            models.ForumPost.category_id == category_id,
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
        )
    )
    posts_result = await db.execute(posts_query)
    posts = posts_result.scalars().all()

    # 3. Query open tasks matching skill_type
    tasks_query = (
        select(models.Task)
        .options(selectinload(models.Task.poster))
        .where(
            models.Task.task_type == skill_type,
            models.Task.status == "open",
            models.Task.is_visible == True,
        )
    )
    tasks_result = await db.execute(tasks_query)
    tasks = tasks_result.scalars().all()

    # 4. Query active services matching skill_type (by category field)
    services_query = (
        select(models.TaskExpertService)
        .where(
            models.TaskExpertService.category == skill_type,
            models.TaskExpertService.status == "active",
        )
    )
    services_result = await db.execute(services_query)
    services = services_result.scalars().all()

    # 5. Build feed items with sort scores
    feed_items = []

    for post in posts:
        created = post.created_at or now
        if post.is_pinned:
            score = 10000.0
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "post",
            "data": _post_to_feed_data(post),
            "sort_score": score,
            "created_at": created,
        })

    for task in tasks:
        created = task.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 5000.0 + (24 - age_hours) * 200
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "task",
            "data": _task_to_feed_data(task),
            "sort_score": score,
            "created_at": created,
        })

    for service in services:
        created = service.created_at or now
        if created >= twenty_four_hours_ago:
            age_hours = (now - created).total_seconds() / 3600
            score = 4000.0 + (24 - age_hours) * 160
        else:
            score = created.timestamp()
        feed_items.append({
            "item_type": "service",
            "data": _service_to_feed_data(service),
            "sort_score": score,
            "created_at": created,
        })

    # 6. Sort
    if sort_by == "weight":
        feed_items.sort(key=lambda x: (-x["sort_score"], -x["created_at"].timestamp()))
    else:
        feed_items.sort(key=lambda x: -x["created_at"].timestamp())

    # 7. Paginate
    total = len(feed_items)
    start = (page - 1) * page_size
    end = start + page_size
    page_items = feed_items[start:end]
    has_more = end < total

    return schemas.SkillFeedResponse(
        items=[schemas.FeedItem(**item) for item in page_items],
        total=total,
        page=page,
        page_size=page_size,
        has_more=has_more,
    )


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
    request: Request = None,
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

    # 验证板块是否存在并检查权限
    # 对于学校板块，需要学生认证；对于普通板块，所有用户都可以发帖
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
    from app.expert_forum_helpers import is_expert_board, check_expert_board_post_permission
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
    if "category_id" in update_data and update_data["category_id"] != old_category_id:
        new_category_id = update_data["category_id"]
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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
    if not current_admin:
        try:
            current_user = await get_current_user_secure_async_csrf(request, db)
        except HTTPException:
            pass
        from app.expert_forum_helpers import is_expert_board, check_expert_board_manage_permission
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


# ==================== 回复 API ====================
# Routes moved to app/routes/forum_replies_routes.py (2026-04-26 split)


# ==================== 点赞 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)




# ==================== 收藏 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)

# ==================== 板块收藏 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)

# ==================== 搜索 API ====================

@router.get("/search", response_model=schemas.ForumSearchResponse)
@measure_api_performance("search_forum_posts")
async def search_posts(
    q: str = Query(..., min_length=1, max_length=100),
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索帖子（使用 pg_trgm 相似度搜索，支持中文）"""

    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 板块筛选和权限检查
    if category_id:
        # 检查板块可见性（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, category_id, db, raise_exception=True)
        query = query.where(models.ForumPost.category_id == category_id)
    else:
        # 如果没有指定板块，需要过滤掉用户无权限访问的学校板块
        if not is_admin:
            # 获取用户可见的板块ID列表
            visible_category_ids = []
            
            # 1. 添加所有普通板块
            general_forums_result = await db.execute(
                select(models.ForumCategory.id).where(
                    models.ForumCategory.type == 'general',
                    models.ForumCategory.is_visible == True
                )
            )
            general_ids = [row[0] for row in general_forums_result.all()]
            visible_category_ids.extend(general_ids)
            
            # 2. 如果用户已登录，添加可见的学校板块
            if current_user:
                school_ids = await visible_forums(current_user, db)
                visible_category_ids.extend(school_ids)
            
            # 3. 只搜索可见板块的帖子
            if visible_category_ids:
                query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
            else:
                # 如果用户没有任何可见板块（理论上不应该发生），返回空结果
                query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID
    
    # 搜索条件（双语扩展 + pg_trgm 相似度搜索）
    from app.utils.search_expander import build_keyword_filter
    forum_columns = [
        models.ForumPost.title,
        models.ForumPost.content,
        models.ForumPost.title_en,
        models.ForumPost.title_zh,
        models.ForumPost.content_en,
        models.ForumPost.content_zh,
    ]
    keyword_expr = build_keyword_filter(
        columns=forum_columns,
        keyword=q,
        use_similarity=True,
    )
    if keyword_expr is not None:
        query = query.where(keyword_expr)

    # 按相似度排序（标题相似度优先，然后是内容相似度）
    query = query.order_by(
        func.similarity(models.ForumPost.title, q).desc(),
        func.similarity(models.ForumPost.content, q).desc(),
        models.ForumPost.created_at.desc()  # 相似度相同时按时间倒序
    )
    
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
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()

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
        display_view_count = view_counts.get(post.id, post.view_count or 0)
        _otype, _oid = _post_identity(post)
        _dname, _davatar = _identity_map.get((_otype, _oid), ("", None))
        post_items.append(schemas.ForumPostListItem(
            id=post.id,
            title=post.title,
            content_preview=strip_markdown(post.content),
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
    
    # 注意：总数和未读数会在过滤后重新计算，因为需要过滤学校板块
    # 这里先查询原始数据，实际统计会在过滤后重新计算
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumNotification.from_user)
    )
    
    result = await db.execute(query)
    notifications = result.scalars().all()
    
    # 获取用户可见的板块ID列表（用于过滤学校板块的通知）
    visible_category_ids = []
    general_forums_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    general_ids = [row[0] for row in general_forums_result.all()]
    visible_category_ids.extend(general_ids)
    
    # 添加可见的学校板块
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)
    
    # 过滤通知：只返回用户有权限访问的板块的通知
    # 优化：批量查询所有通知目标的 category_id，避免 N+1 查询问题
    notification_list = []
    
    if notifications:
        # 分离 post 和 reply 类型的通知
        post_notifications = [n for n in notifications if n.target_type == "post"]
        reply_notifications = [n for n in notifications if n.target_type == "reply"]
        
        # 批量查询所有 post 的 category_id
        post_category_map = {}
        if post_notifications:
            post_ids = [n.target_id for n in post_notifications]
            post_category_result = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(post_ids))
            )
            post_category_map = {row[0]: row[1] for row in post_category_result.all()}
        
        # 批量查询所有 reply 的 post_id，然后批量查询 post 的 category_id
        reply_post_map = {}
        reply_category_map = {}
        if reply_notifications:
            reply_ids = [n.target_id for n in reply_notifications]
            reply_post_result = await db.execute(
                select(models.ForumReply.id, models.ForumReply.post_id)
                .where(models.ForumReply.id.in_(reply_ids))
            )
            reply_post_map = {row[0]: row[1] for row in reply_post_result.all()}
            
            # 批量查询这些 post 的 category_id
            if reply_post_map:
                post_ids_from_replies = list(reply_post_map.values())
                reply_post_category_result = await db.execute(
                    select(models.ForumPost.id, models.ForumPost.category_id)
                    .where(models.ForumPost.id.in_(post_ids_from_replies))
                )
                post_id_to_category = {row[0]: row[1] for row in reply_post_category_result.all()}
                # 构建 reply_id -> category_id 映射
                reply_category_map = {
                    reply_id: post_id_to_category.get(post_id)
                    for reply_id, post_id in reply_post_map.items()
                    if post_id in post_id_to_category
                }
        
        # 过滤通知
        for n in notifications:
            has_permission = False
            
            if n.target_type == "post":
                category_id = post_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            elif n.target_type == "reply":
                category_id = reply_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            
            # 只添加有权限访问的通知
            if has_permission:
                # 如果是回复类型的通知，需要添加帖子ID
                post_id = None
                if n.target_type == "reply":
                    post_id = reply_post_map.get(n.target_id)
                elif n.target_type == "post":
                    post_id = n.target_id
                
                notification_list.append(schemas.ForumNotificationOut(
                    id=n.id,
                    notification_type=n.notification_type,
                    target_type=n.target_type,
                    target_id=n.target_id,
                    post_id=post_id,
                    from_user=schemas.UserInfo(
                        id=n.from_user.id,
                        name=n.from_user.name,
                        avatar=n.from_user.avatar or None
                    ) if n.from_user else None,
                    is_read=n.is_read,
                    created_at=n.created_at
                ))
    
    # 重新计算总数和未读数（因为过滤了部分通知）
    total = len(notification_list)
    unread_count = sum(1 for n in notification_list if not n.is_read)
    
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
    """
    标记论坛通知系统的所有通知为已读
    
    注意：此端点仅处理论坛通知系统（ForumNotification 模型）。
    主通知系统（Notification 模型）有独立的端点：
    POST /api/notifications/read-all（定义在 routers.py）
    
    两个通知系统是独立设计的，请勿合并。
    """
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
    """获取未读通知数量（只统计用户有权限访问的板块的通知）"""
    # 获取用户可见的板块ID列表
    visible_category_ids = []
    general_forums_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    general_ids = [row[0] for row in general_forums_result.all()]
    visible_category_ids.extend(general_ids)
    
    # 添加可见的学校板块
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)
    
    # 查询未读通知
    notifications_result = await db.execute(
        select(models.ForumNotification)
        .where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False
        )
    )
    notifications = notifications_result.scalars().all()
    
    # 过滤：只统计用户有权限访问的板块的通知
    # 优化：批量查询所有通知目标的 category_id，避免 N+1 查询问题
    unread_count = 0
    
    if notifications:
        # 分离 post 和 reply 类型的通知
        post_notifications = [n for n in notifications if n.target_type == "post"]
        reply_notifications = [n for n in notifications if n.target_type == "reply"]
        
        # 批量查询所有 post 的 category_id
        post_category_map = {}
        if post_notifications:
            post_ids = [n.target_id for n in post_notifications]
            post_category_result = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(post_ids))
            )
            post_category_map = {row[0]: row[1] for row in post_category_result.all()}
        
        # 批量查询所有 reply 的 post_id，然后批量查询 post 的 category_id
        reply_post_map = {}
        reply_category_map = {}
        if reply_notifications:
            reply_ids = [n.target_id for n in reply_notifications]
            reply_post_result = await db.execute(
                select(models.ForumReply.id, models.ForumReply.post_id)
                .where(models.ForumReply.id.in_(reply_ids))
            )
            reply_post_map = {row[0]: row[1] for row in reply_post_result.all()}
            
            # 批量查询这些 post 的 category_id
            if reply_post_map:
                post_ids_from_replies = list(reply_post_map.values())
                reply_post_category_result = await db.execute(
                    select(models.ForumPost.id, models.ForumPost.category_id)
                    .where(models.ForumPost.id.in_(post_ids_from_replies))
                )
                post_id_to_category = {row[0]: row[1] for row in reply_post_category_result.all()}
                # 构建 reply_id -> category_id 映射
                reply_category_map = {
                    reply_id: post_id_to_category.get(post_id)
                    for reply_id, post_id in reply_post_map.items()
                    if post_id in post_id_to_category
                }
        
        # 统计有权限的通知数量
        for n in notifications:
            has_permission = False
            
            if n.target_type == "post":
                category_id = post_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            elif n.target_type == "reply":
                category_id = reply_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
                    has_permission = True
            
            if has_permission:
                unread_count += 1
    
    return {"unread_count": unread_count}


# ==================== 热门内容 API ====================

@router.get("/hot-posts", response_model=schemas.ForumPostListResponse)
@measure_api_performance("get_hot_posts")
@cache_response(ttl=180, key_prefix="forum_hot_posts")  # 缓存3分钟
async def get_hot_posts(
    category_id: Optional[int] = Query(None, description="板块ID（可选）"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取热门帖子（按热度排序）"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    # 构建基础查询
    query = select(models.ForumPost).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 板块筛选和权限检查
    if category_id:
        # 检查板块可见性（学校板块需要权限）
        if not is_admin:
            await assert_forum_visible(current_user, category_id, db, raise_exception=True)
        query = query.where(models.ForumPost.category_id == category_id)
    else:
        # 如果没有指定板块，需要过滤掉用户无权限访问的学校板块
        if not is_admin:
            # 获取用户可见的板块ID列表
            visible_category_ids = []
            
            # 1. 添加所有普通板块
            general_forums_result = await db.execute(
                select(models.ForumCategory.id).where(
                    models.ForumCategory.type == 'general',
                    models.ForumCategory.is_visible == True
                )
            )
            general_ids = [row[0] for row in general_forums_result.all()]
            visible_category_ids.extend(general_ids)
            
            # 2. 如果用户已登录，添加可见的学校板块
            if current_user:
                school_ids = await visible_forums(current_user, db)
                visible_category_ids.extend(school_ids)
            
            # 3. 只搜索可见板块的帖子
            if visible_category_ids:
                query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
            else:
                # 如果用户没有任何可见板块，返回空结果
                query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID
    
    # 改进的热度算法：综合考虑点赞、收藏、评论和最近活跃度
    # 使用 last_reply_at 作为时间因子（如果存在），否则使用 created_at
    active_time = func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at)
    hours_since_active = func.extract('epoch', func.now() - active_time) / 3600.0
    
    # 综合热度分数 = (点赞数*权重 + 收藏数*权重 + 评论数*权重 + 浏览量*权重) / 时间衰减因子
    hot_score = (
        models.ForumPost.like_count * 5.0 +      # 点赞权重：5
        models.ForumPost.favorite_count * 4.0 +  # 收藏权重：4（收藏表示深度兴趣）
        models.ForumPost.reply_count * 3.0 +     # 评论权重：3
        models.ForumPost.view_count * 0.1        # 浏览量权重：0.1（较低，因为浏览不代表互动）
    ) / func.pow(
        (hours_since_active / 24.0) + 1.0,  # 以天为单位，+1避免除零
        1.2  # 衰减指数，值越大衰减越快
    )
    
    # 置顶优先，然后按热度排序
    query = query.order_by(
        models.ForumPost.is_pinned.desc(),  # 置顶帖子优先
        hot_score.desc()  # 最后按热度
    )
    
    # 限制数量
    query = query.limit(limit)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()

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
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": len(post_items),
        "page": 1,
        "page_size": limit
    }


# ==================== 用户论坛统计 API ====================

@router.get("/users/{user_id}/stats")
@measure_api_performance("get_user_forum_stats")
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


@router.get("/users/{user_id}/hot-posts", response_model=schemas.ForumPostListResponse)
async def get_user_hot_posts(
    user_id: str,
    limit: int = Query(3, ge=1, le=10, description="返回数量"),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户发布的最热门帖子"""
    # 检查是否为管理员
    is_admin = False
    try:
        await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    
    # 构建查询：获取指定用户的帖子
    query = select(models.ForumPost).where(
        models.ForumPost.author_id == user_id,
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True
    )
    
    # 如果不是管理员，需要过滤掉用户无权限访问的学校板块
    if not is_admin:
        # 获取用户可见的板块ID列表
        visible_category_ids = []
        
        # 1. 添加所有普通板块
        general_forums_result = await db.execute(
            select(models.ForumCategory.id).where(
                models.ForumCategory.type == 'general',
                models.ForumCategory.is_visible == True
            )
        )
        general_ids = [row[0] for row in general_forums_result.all()]
        visible_category_ids.extend(general_ids)
        
        # 2. 如果用户已登录，添加可见的学校板块
        if current_user:
            school_ids = await visible_forums(current_user, db)
            visible_category_ids.extend(school_ids)
        
        # 3. 只返回可见板块的帖子
        if visible_category_ids:
            query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
        else:
            # 如果用户没有任何可见板块，返回空结果
            query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID
    
    # 改进的热度算法：综合考虑点赞、收藏、评论和最近活跃度
    # 使用 last_reply_at 作为时间因子（如果存在），否则使用 created_at
    active_time = func.coalesce(models.ForumPost.last_reply_at, models.ForumPost.created_at)
    hours_since_active = func.extract('epoch', func.now() - active_time) / 3600.0
    
    # 综合热度分数 = (点赞数*权重 + 收藏数*权重 + 评论数*权重 + 浏览量*权重) / 时间衰减因子
    hot_score = (
        models.ForumPost.like_count * 5.0 +      # 点赞权重：5
        models.ForumPost.favorite_count * 4.0 +  # 收藏权重：4（收藏表示深度兴趣）
        models.ForumPost.reply_count * 3.0 +     # 评论权重：3
        models.ForumPost.view_count * 0.1        # 浏览量权重：0.1（较低，因为浏览不代表互动）
    ) / func.pow(
        (hours_since_active / 24.0) + 1.0,  # 以天为单位，+1避免除零
        1.2  # 衰减指数，值越大衰减越快
    )
    query = query.order_by(hot_score.desc())
    
    # 限制数量
    query = query.limit(limit)
    
    # 加载关联数据
    query = query.options(
        selectinload(models.ForumPost.category),
        selectinload(models.ForumPost.author),
        selectinload(models.ForumPost.admin_author)
    )
    
    result = await db.execute(query)
    posts = result.scalars().all()

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
            owner_type=_otype,
            owner_id=_oid or None,
            display_name=_dname,
            display_avatar=_davatar,
        ))

    return {
        "posts": post_items,
        "total": len(post_items),
        "page": 1,
        "page_size": limit
    }


# ==================== 排行榜 API ====================

@router.get("/leaderboard/posts")
async def get_top_posts_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
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
    # 只统计普通板块（type='general'）的帖子，确保公平性
    query = select(
        models.ForumPost.author_id,
        func.count(models.ForumPost.id).label("post_count")
    ).join(
        models.ForumCategory,
        models.ForumPost.category_id == models.ForumCategory.id
    ).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True,
        models.ForumCategory.type == 'general'  # 只统计普通板块
    )
    
    if start_time:
        query = query.where(models.ForumPost.created_at >= start_time)
    
    query = query.group_by(models.ForumPost.author_id).order_by(func.count(models.ForumPost.id).desc()).limit(limit)
    
    result = await db.execute(query)
    top_users = result.all()

    user_ids = [uid for uid, _ in top_users if uid]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, post_count in top_users:
        user = user_map.get(user_id)
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "count": post_count,
                "rank": rank
            })
            rank += 1

    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/favorites")
async def get_top_favorites_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取收藏排行榜（统计用户发布的帖子被收藏的总数）"""
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
    
    # 构建查询：统计用户发布的帖子被收藏的总数
    # 只统计普通板块（type='general'）的帖子，确保公平性
    query = select(
        models.ForumPost.author_id,
        func.sum(models.ForumPost.favorite_count).label("favorite_count")
    ).join(
        models.ForumCategory,
        models.ForumPost.category_id == models.ForumCategory.id
    ).where(
        models.ForumPost.is_deleted == False,
        models.ForumPost.is_visible == True,
        models.ForumCategory.type == 'general'  # 只统计普通板块
    )
    
    if start_time:
        query = query.where(models.ForumPost.created_at >= start_time)
    
    query = query.group_by(models.ForumPost.author_id).order_by(func.sum(models.ForumPost.favorite_count).desc()).limit(limit)
    
    result = await db.execute(query)
    top_users = result.all()

    user_ids = [uid for uid, _ in top_users if uid]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, favorite_count in top_users:
        if user_id:
            user = user_map.get(user_id)
            if user:
                user_list.append({
                    "user": schemas.UserInfo(
                        id=user.id,
                        name=user.name,
                        avatar=user.avatar or None
                    ),
                    "count": favorite_count or 0,
                    "rank": rank
                })
                rank += 1

    return {
        "period": period,
        "users": user_list
    }


@router.get("/leaderboard/likes")
async def get_top_likes_leaderboard(
    period: str = Query("all", pattern="^(all|today|week|month)$", description="统计周期：all/today/week/month"),
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

    user_ids = [uid for uid, _ in sorted_users]
    user_map = await _batch_get_users_by_ids_async(db, user_ids)

    user_list = []
    rank = 1
    for user_id, likes_count in sorted_users:
        user = user_map.get(user_id)
        if user:
            user_list.append({
                "user": schemas.UserInfo(
                    id=user.id,
                    name=user.name,
                    avatar=user.avatar or None
                ),
                "count": likes_count,
                "rank": rank
            })
            rank += 1

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


# ==================== 关联内容搜索（Discovery Feed） ====================

@router.get("/search-linkable")
async def search_linkable_content(
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    type: str = Query("all", description="内容类型: all/service/expert/activity/product/ranking/forum_post"),
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索可关联的公开内容（用于帖子关联功能）
    
    混合方案：所有公开内容都可搜索，但标注用户是否参与过
    """
    # 获取当前用户（用于判断 is_experienced）
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except Exception:
        pass
    
    results = []
    from app.utils.search_expander import build_keyword_filter
    limit_per_type = 5
    
    # 搜索服务（包含达人服务和个人服务）
    if type in ("all", "service"):
        # 服务所有者：个人服务用 user_id，达人服务用 expert_id（与 users.id 同空间）
        owner_user_id_expr = func.coalesce(
            models.TaskExpertService.user_id,
            models.TaskExpertService.expert_id,
        )
        service_query = (
            select(
                models.TaskExpertService.id,
                models.TaskExpertService.service_name,
                models.TaskExpertService.description,
                models.TaskExpertService.images,
                models.TaskExpertService.service_type,
                models.User.name.label("owner_name"),
            )
            .join(models.User, models.User.id == owner_user_id_expr)
            .where(
                models.TaskExpertService.status == "active",
            )
        )
        svc_keyword_expr = build_keyword_filter(
            columns=[
                models.TaskExpertService.service_name,
                models.TaskExpertService.description,
            ],
            keyword=q,
            use_similarity=False,
        )
        if svc_keyword_expr is not None:
            service_query = service_query.where(svc_keyword_expr)
        service_query = (
            service_query
            .limit(limit_per_type)
        )
        service_result = await db.execute(service_query)
        for row in service_result:
            is_experienced = False
            if current_user:
                exp_check = await db.execute(
                    select(func.count(models.Task.id)).where(
                        models.Task.expert_service_id == row.id,
                        or_(models.Task.poster_id == current_user.id, models.Task.taker_id == current_user.id),
                        models.Task.status == "completed",
                    )
                )
                is_experienced = (exp_check.scalar() or 0) > 0
            # 解析 images JSONB 获取第一张图
            svc_images = row.images
            svc_thumb = None
            if svc_images:
                if isinstance(svc_images, list):
                    svc_thumb = svc_images[0] if svc_images else None
                elif isinstance(svc_images, str):
                    try:
                        parsed = json.loads(svc_images)
                        svc_thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            owner_label = "个人" if row.service_type == "personal" else "达人"
            svc_subtitle = f"{owner_label} · {row.owner_name}" if row.owner_name else owner_label
            results.append({
                "item_type": "service",
                "item_id": str(row.id),
                "title": row.service_name,
                "subtitle": svc_subtitle,
                "thumbnail": svc_thumb,
                "is_experienced": is_experienced,
            })
    
    # 搜索跳蚤市场商品
    if type in ("all", "product"):
        product_query = (
            select(
                models.FleaMarketItem.id,
                models.FleaMarketItem.title,
                models.FleaMarketItem.price,
                models.FleaMarketItem.images,
                models.FleaMarketItem.currency,
            )
            .where(
                models.FleaMarketItem.status == "active",
                models.FleaMarketItem.is_visible == True,
            )
        )
        prod_keyword_expr = build_keyword_filter(
            columns=[
                models.FleaMarketItem.title,
                models.FleaMarketItem.description,
                models.FleaMarketItem.location,
                models.FleaMarketItem.category,
            ],
            keyword=q,
            use_similarity=False,
        )
        if prod_keyword_expr is not None:
            product_query = product_query.where(prod_keyword_expr)
        product_query = product_query.limit(limit_per_type)
        product_result = await db.execute(product_query)
        for row in product_result:
            prod_images = row.images
            first_image = None
            if prod_images:
                if isinstance(prod_images, list):
                    first_image = prod_images[0] if prod_images else None
                elif isinstance(prod_images, str):
                    try:
                        parsed = json.loads(prod_images)
                        first_image = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            is_experienced = False
            if current_user:
                fav_check = await db.execute(
                    select(func.count()).select_from(models.FleaMarketFavorite).where(
                        models.FleaMarketFavorite.item_id == row.id,
                        models.FleaMarketFavorite.user_id == current_user.id,
                    )
                )
                is_experienced = (fav_check.scalar() or 0) > 0
            results.append({
                "item_type": "product",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": f"{row.currency} {row.price:.2f}" if row.price else None,
                "thumbnail": first_image,
                "is_experienced": is_experienced,
            })
    
        # 搜索活动（含 location，支持按地址/城市搜索）
    if type in ("all", "activity"):
        activity_query = (
            select(
                models.Activity.id,
                models.Activity.title,
                models.Activity.images.label("activity_images"),
                models.User.name.label("expert_name"),
            )
            .join(models.User, models.Activity.expert_id == models.User.id)
            .where(
                models.Activity.status.in_(["published", "registration_open"]),
            )
        )
        act_keyword_expr = build_keyword_filter(
            columns=[
                models.Activity.title,
                models.Activity.description,
                models.Activity.location,
            ],
            keyword=q,
            use_similarity=False,
        )
        if act_keyword_expr is not None:
            activity_query = activity_query.where(act_keyword_expr)
        activity_query = activity_query.limit(limit_per_type)
        activity_result = await db.execute(activity_query)
        for row in activity_result:
            is_experienced = False
            if current_user:
                exp_check = await db.execute(
                    select(func.count(models.Task.id)).where(
                        models.Task.parent_activity_id == row.id,
                        or_(models.Task.poster_id == current_user.id, models.Task.taker_id == current_user.id),
                    )
                )
                is_experienced = (exp_check.scalar() or 0) > 0
            act_images = row.activity_images
            act_thumb = None
            if act_images:
                if isinstance(act_images, list):
                    act_thumb = act_images[0] if act_images else None
                elif isinstance(act_images, str):
                    try:
                        parsed = json.loads(act_images)
                        act_thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                    except Exception:
                        pass
            results.append({
                "item_type": "activity",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": row.expert_name,
                "thumbnail": act_thumb,
                "is_experienced": is_experienced,
            })
    
    # 搜索排行榜
    if type in ("all", "ranking"):
        ranking_query = (
            select(
                models.CustomLeaderboard.id,
                models.CustomLeaderboard.name,
                models.CustomLeaderboard.cover_image,
            )
            .where(
                models.CustomLeaderboard.status == "active",
            )
        )
        rank_keyword_expr = build_keyword_filter(
            columns=[
                models.CustomLeaderboard.name,
                models.CustomLeaderboard.name_en,
                models.CustomLeaderboard.name_zh,
                models.CustomLeaderboard.description,
                models.CustomLeaderboard.description_en,
                models.CustomLeaderboard.description_zh,
            ],
            keyword=q,
            use_similarity=False,
        )
        if rank_keyword_expr is not None:
            ranking_query = ranking_query.where(rank_keyword_expr)
        ranking_query = ranking_query.limit(limit_per_type)
        ranking_result = await db.execute(ranking_query)
        for row in ranking_result:
            results.append({
                "item_type": "ranking",
                "item_id": str(row.id),
                "title": row.name,
                "subtitle": "排行榜",
                "thumbnail": row.cover_image,
                "is_experienced": False,
            })
    
    # 搜索帖子
    if type in ("all", "forum_post"):
        post_query = (
            select(
                models.ForumPost.id,
                models.ForumPost.title,
            )
            .where(
                models.ForumPost.is_deleted == False,
                models.ForumPost.is_visible == True,
            )
        )
        post_keyword_expr = build_keyword_filter(
            columns=[
                models.ForumPost.title,
                models.ForumPost.title_en,
                models.ForumPost.title_zh,
                models.ForumPost.content,
                models.ForumPost.content_en,
                models.ForumPost.content_zh,
            ],
            keyword=q,
            use_similarity=False,
        )
        if post_keyword_expr is not None:
            post_query = post_query.where(post_keyword_expr)
        post_query = post_query.order_by(desc(models.ForumPost.created_at)).limit(limit_per_type)
        post_result = await db.execute(post_query)
        for row in post_result:
            results.append({
                "item_type": "forum_post",
                "item_id": str(row.id),
                "title": row.title,
                "subtitle": "帖子",
                "thumbnail": None,
                "is_experienced": False,
            })
    
    # 排序：已体验的排前面
    results.sort(key=lambda x: (not x["is_experienced"], x["item_type"]))
    
    return {"results": results}


@router.get("/linkable-for-user")
async def get_linkable_content_for_user(
    request: Request = None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取与当前用户相关的可关联内容（发帖关联时在搜索框下方展示）
    - 未登录返回空列表
    - 已登录：我的服务、我的活动、我收藏的商品、我申请的排行榜等
    """
    current_user = None
    try:
        current_user = await get_current_user_secure_async_csrf(request, db)
    except Exception:
        pass
    if not current_user:
        return {"results": []}

    results = []
    limit_per_type = 5

    # 我的服务（达人服务 + 个人服务）
    my_svc_query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.images,
            models.TaskExpertService.service_type,
        )
        .where(
            or_(
                models.TaskExpertService.user_id == current_user.id,
                models.TaskExpertService.expert_id == current_user.id,
            ),
            models.TaskExpertService.status == "active",
        )
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit_per_type)
    )
    for row in (await db.execute(my_svc_query)).all():
        thumb = None
        if row.images:
            if isinstance(row.images, list):
                thumb = row.images[0] if row.images else None
            elif isinstance(row.images, str):
                try:
                    parsed = json.loads(row.images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        my_label = "我的个人服务" if row.service_type == "personal" else "我的达人服务"
        results.append({
            "item_type": "service",
            "item_id": str(row.id),
            "name": row.service_name,
            "title": row.service_name,
            "subtitle": my_label,
            "thumbnail": thumb,
        })

    # 我的活动（我发布的）
    act_query = (
        select(
            models.Activity.id,
            models.Activity.title,
            models.Activity.images.label("activity_images"),
        )
        .where(
            models.Activity.expert_id == current_user.id,
            models.Activity.status.in_(["published", "registration_open"]),
        )
        .order_by(desc(models.Activity.created_at))
        .limit(limit_per_type)
    )
    for row in (await db.execute(act_query)).all():
        thumb = None
        if row.activity_images:
            if isinstance(row.activity_images, list):
                thumb = row.activity_images[0] if row.activity_images else None
            elif isinstance(row.activity_images, str):
                try:
                    parsed = json.loads(row.activity_images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        results.append({
            "item_type": "activity",
            "item_id": str(row.id),
            "name": row.title,
            "title": row.title,
            "subtitle": "我的活动",
            "thumbnail": thumb,
        })

    # 我收藏的跳蚤市场商品
    fav_query = (
        select(
            models.FleaMarketItem.id,
            models.FleaMarketItem.title,
            models.FleaMarketItem.images,
            models.FleaMarketItem.price,
            models.FleaMarketItem.currency,
        )
        .join(models.FleaMarketFavorite, models.FleaMarketFavorite.item_id == models.FleaMarketItem.id)
        .where(
            models.FleaMarketFavorite.user_id == current_user.id,
            models.FleaMarketItem.status == "active",
            models.FleaMarketItem.is_visible == True,
        )
        .limit(limit_per_type)
    )
    for row in (await db.execute(fav_query)).all():
        thumb = None
        if row.images:
            if isinstance(row.images, list):
                thumb = row.images[0] if row.images else None
            elif isinstance(row.images, str):
                try:
                    parsed = json.loads(row.images)
                    thumb = parsed[0] if isinstance(parsed, list) and parsed else None
                except Exception:
                    pass
        results.append({
            "item_type": "product",
            "item_id": str(row.id),
            "name": row.title,
            "title": row.title,
            "subtitle": f"{row.currency} {row.price:.2f}" if row.price else "收藏",
            "thumbnail": thumb,
        })

    # 我申请的排行榜（已通过）
    lb_query = (
        select(
            models.CustomLeaderboard.id,
            models.CustomLeaderboard.name,
            models.CustomLeaderboard.cover_image,
        )
        .where(
            models.CustomLeaderboard.applicant_id == current_user.id,
            models.CustomLeaderboard.status == "active",
        )
        .limit(limit_per_type)
    )
    for row in (await db.execute(lb_query)).all():
        results.append({
            "item_type": "ranking",
            "item_id": str(row.id),
            "name": row.name,
            "title": row.name,
            "subtitle": "排行榜",
            "thumbnail": row.cover_image,
        })

    return {"results": results}


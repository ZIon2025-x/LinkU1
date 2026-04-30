"""
Shared helpers for forum route modules (extraction completed 2026-04-30).

Routes have been migrated to:
  - app/routes/forum_categories_routes.py
  - app/routes/forum_posts_routes.py
  - app/routes/forum_replies_routes.py
  - app/routes/forum_interactions_routes.py
  - app/routes/forum_my_routes.py
  - app/routes/forum_discovery_routes.py
  - app/routes/forum_admin_routes.py

This module retains 30+ module-level helpers (visible_forums,
build_user_info, preload_badge_cache, invalidate_forum_visibility_cache,
assert_forum_visible, get_current_user_optional, get_current_admin_async,
batch query helpers, feed-data converters, etc.) which are imported by
the route modules above and by 18 external call-sites across the backend.

Do not add new routes here. If you need a new endpoint, create it in the
appropriate app/routes/forum_*_routes.py.

See docs/superpowers/specs/2026-04-26-forum-routes-split-design.md
"""

from typing import List, Optional
from datetime import datetime, timezone, timedelta
import json
import re
import logging

from fastapi import Depends, HTTPException, status, Request
from sqlalchemy import select, func, desc, update, inspect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import NO_VALUE

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time

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
# Routes moved to app/routes/forum_categories_routes.py (2026-04-26 split)

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


# ==================== 帖子 API ====================
# Routes moved to app/routes/forum_posts_routes.py (2026-04-26 split)

# ==================== 回复 API ====================
# Routes moved to app/routes/forum_replies_routes.py (2026-04-26 split)


# ==================== 点赞 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)




# ==================== 收藏 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)

# ==================== 板块收藏 API ====================
# Routes moved to app/routes/forum_interactions_routes.py (2026-04-26 split)

# ==================== 搜索 API ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

# ==================== 通知 API ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

# ==================== 热门内容 API ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

# ==================== 用户论坛统计 API ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

# ==================== 排行榜 API ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

# ==================== 板块统计 API ====================
# Routes moved to app/routes/forum_categories_routes.py (2026-04-26 split)


# ==================== 关联内容搜索（Discovery Feed） ====================
# Routes moved to app/routes/forum_discovery_routes.py (2026-04-26 split)

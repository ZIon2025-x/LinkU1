"""
异步API路由模块
展示如何使用异步数据库操作
"""

import json
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status, BackgroundTasks, Body
from fastapi.security import HTTPAuthorizationCredentials
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, update

from app import async_crud, models, schemas
from app.database import check_database_health, get_pool_status
from app.deps import get_async_db_dependency
from app.csrf import csrf_cookie_bearer
from app.security import cookie_bearer
from app.rate_limiting import rate_limit
from app.utils.time_utils import format_iso_utc

logger = logging.getLogger(__name__)

# 创建异步路由器
async_router = APIRouter()


# 创建任务专用的认证依赖（支持Cookie + CSRF保护）
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(csrf_cookie_bearer),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    # 首先尝试使用会话认证
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            # 检查用户状态
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )

            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            
            return user
    
    # 如果会话认证失败，抛出认证错误
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


# 异步用户路由
@async_router.get("/users/me", response_model=schemas.UserOut)
async def get_current_user_info(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取当前用户信息（异步版本）"""
    return current_user


@async_router.get("/users/{user_id}", response_model=schemas.UserOut)
async def get_user_by_id(
    user_id: str, db: AsyncSession = Depends(get_async_db_dependency)
):
    """根据ID获取用户信息（异步版本）"""
    user = await async_crud.async_user_crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@async_router.get("/users", response_model=List[schemas.UserOut])
async def get_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户列表（异步版本）"""
    users = await async_crud.async_user_crud.get_users(db, skip=skip, limit=limit)
    return users


# 异步任务路由
@async_router.get("/tasks")
async def get_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    task_type: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    sort_by: Optional[str] = Query("latest"),
    expert_creator_id: Optional[str] = Query(None),
    is_multi_participant: Optional[bool] = Query(None),
    parent_activity_id: Optional[int] = Query(None),
    user_latitude: Optional[float] = Query(None, ge=-90, le=90, description="用户纬度（用于距离排序）"),
    user_longitude: Optional[float] = Query(None, ge=-180, le=180, description="用户经度（用于距离排序）"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取任务列表（异步版本）
    
    分页策略：
    - 时间排序（latest/oldest）且提供了 cursor：使用游标分页
    - 其他情况：使用 offset/limit + total
    """
    # 时间排序：用游标分页
    if sort_by in ("latest", "oldest") and cursor is not None:
        tasks, next_cursor = await async_crud.async_task_crud.get_tasks_cursor(
            db=db,
            cursor=cursor,
            limit=limit,
            task_type=task_type,
            location=location,
            keyword=keyword,
            sort_by=sort_by,
            expert_creator_id=expert_creator_id,
            is_multi_participant=is_multi_participant,
            parent_activity_id=parent_activity_id,
        )
        
        # 任务双语标题直接从任务表列读取（title_zh, title_en）
        # 批量获取发布者会员等级（用于「会员发布」角标）
        poster_ids = list({task.poster_id for task in tasks if task.poster_id})
        poster_levels = {}
        if poster_ids:
            from sqlalchemy import select
            result = await db.execute(select(models.User.id, models.User.user_level).where(models.User.id.in_(poster_ids)))
            for row in result.all():
                uid = row[0] if len(row) else None
                if uid is not None:
                    poster_levels[uid] = (row[1] if len(row) > 1 else None) or 'normal'
        
        # 格式化任务列表（与下面的格式化逻辑保持一致）
        formatted_tasks = []
        for task in tasks:
            images_list = []
            if task.images:
                try:
                    if isinstance(task.images, str):
                        images_list = json.loads(task.images)
                    elif isinstance(task.images, list):
                        images_list = task.images
                except (json.JSONDecodeError, TypeError):
                    images_list = []
            
            # 使用 obfuscate_location 模糊化位置信息
            from app.utils.location_utils import obfuscate_location
            obfuscated_location = obfuscate_location(
                task.location,
                float(task.latitude) if task.latitude is not None else None,
                float(task.longitude) if task.longitude is not None else None
            )
            
            # 双语标题从任务表列读取
            title_en = getattr(task, "title_en", None)
            title_zh = getattr(task, "title_zh", None)
            task_data = {
                "id": task.id,
                "title": task.title,
                "title_en": title_en,
                "title_zh": title_zh,
                "description": task.description,
                "deadline": format_iso_utc(task.deadline) if task.deadline else None,
                "is_flexible": task.is_flexible or 0,
            "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
            "base_reward": float(task.base_reward) if task.base_reward else None,
            "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
            "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
            "currency": task.currency or "GBP",
            "location": obfuscated_location,  # 使用模糊化的位置
                "latitude": float(task.latitude) if task.latitude is not None else None,
                "longitude": float(task.longitude) if task.longitude is not None else None,
                "task_type": task.task_type,
                "poster_id": task.poster_id,
                "taker_id": task.taker_id,
                "status": task.status,
                "task_level": task.task_level,
                "created_at": format_iso_utc(task.created_at) if task.created_at else None,
                "is_public": int(task.is_public) if task.is_public is not None else 1,
                "images": images_list,
                "points_reward": int(task.points_reward) if task.points_reward else None,
                # 多人任务相关字段
                "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
                "max_participants": int(task.max_participants) if hasattr(task, 'max_participants') and task.max_participants else None,
                "min_participants": int(task.min_participants) if hasattr(task, 'min_participants') and task.min_participants else None,
                "current_participants": int(task.current_participants) if hasattr(task, 'current_participants') and task.current_participants is not None else 0,
                "task_source": getattr(task, 'task_source', 'normal'),  # 任务来源
                "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False,
                "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
                "expert_service_id": int(task.expert_service_id) if hasattr(task, 'expert_service_id') and task.expert_service_id else None,
                # 折扣相关字段
                "original_price_per_participant": float(task.original_price_per_participant) if hasattr(task, 'original_price_per_participant') and task.original_price_per_participant is not None else None,
                "discount_percentage": float(task.discount_percentage) if hasattr(task, 'discount_percentage') and task.discount_percentage is not None else None,
                "discounted_price_per_participant": float(task.discounted_price_per_participant) if hasattr(task, 'discounted_price_per_participant') and task.discounted_price_per_participant is not None else None,
                "poster_user_level": poster_levels.get(task.poster_id) if task.poster_id else None,
            }
            
            # 如果有距离信息，添加到返回数据中
            if hasattr(task, '_distance_km') and task._distance_km is not None:
                task_data["distance_km"] = round(task._distance_km, 2)
            
            formatted_tasks.append(task_data)
        
        return {
            "tasks": formatted_tasks,
            "next_cursor": next_cursor,
        }
    
    # 其他排序或初次加载：用 offset/limit + total
    # 支持page/page_size参数，向后兼容skip/limit
    if page > 1 or page_size != 20:
        skip = (page - 1) * page_size
        limit = page_size
    
    # 不再自动设置距离排序，只有明确传递 sort_by="distance" 或 "nearby" 时才使用距离排序
    # 推荐任务和任务大厅不使用距离排序，也不隐藏 online 任务
    
    tasks, total = await async_crud.async_task_crud.get_tasks_with_total(
        db,
        skip=skip,
        limit=limit,
        task_type=task_type,
        location=location,
        status=status,
        keyword=keyword,
        sort_by=sort_by,
        expert_creator_id=expert_creator_id,
        is_multi_participant=is_multi_participant,
        parent_activity_id=parent_activity_id,
        user_latitude=user_latitude,
        user_longitude=user_longitude,
    )
    
    # 任务双语标题直接从任务表列读取（title_zh, title_en）
    # 批量获取发布者会员等级（用于「会员发布」角标）
    poster_ids = list({task.poster_id for task in tasks if task.poster_id})
    poster_levels = {}
    if poster_ids:
        from sqlalchemy import select
        result = await db.execute(select(models.User.id, models.User.user_level).where(models.User.id.in_(poster_ids)))
        for row in result.all():
            uid = row[0] if len(row) else None
            if uid is not None:
                poster_levels[uid] = (row[1] if len(row) > 1 else None) or 'normal'
    
    # 格式化任务列表，确保所有时间字段使用 format_iso_utc()
    # format_iso_utc 已在文件顶部导入
    
    formatted_tasks = []
    for task in tasks:
        # 解析图片字段
        images_list = []
        if task.images:
            try:
                if isinstance(task.images, str):
                    images_list = json.loads(task.images)
                elif isinstance(task.images, list):
                    images_list = task.images
            except (json.JSONDecodeError, TypeError):
                images_list = []
        
        # 双语标题从任务表列读取
        title_en = getattr(task, "title_en", None)
        title_zh = getattr(task, "title_zh", None)
        task_data = {
            "id": task.id,
            "title": task.title,
            "title_en": title_en,
            "title_zh": title_zh,
            "description": task.description,
            "deadline": format_iso_utc(task.deadline) if task.deadline else None,
            "is_flexible": task.is_flexible or 0,
            "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
            "base_reward": float(task.base_reward) if task.base_reward else None,
            "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
            "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
            "currency": task.currency or "GBP",
            "location": task.location,
            "latitude": float(task.latitude) if task.latitude is not None else None,
            "longitude": float(task.longitude) if task.longitude is not None else None,
            "task_type": task.task_type,
            "poster_id": task.poster_id,
            "taker_id": task.taker_id,
            "status": task.status,
            "task_level": task.task_level,
            "created_at": format_iso_utc(task.created_at) if task.created_at else None,
            "is_public": int(task.is_public) if task.is_public is not None else 1,
            "images": images_list,
            "points_reward": int(task.points_reward) if task.points_reward else None,
            # 多人任务相关字段
            "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
            "max_participants": int(task.max_participants) if hasattr(task, 'max_participants') and task.max_participants else None,
            "min_participants": int(task.min_participants) if hasattr(task, 'min_participants') and task.min_participants else None,
            "current_participants": int(task.current_participants) if hasattr(task, 'current_participants') and task.current_participants is not None else 0,
            "task_source": getattr(task, 'task_source', 'normal'),  # 任务来源
            "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False,
            "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
            "expert_service_id": int(task.expert_service_id) if hasattr(task, 'expert_service_id') and task.expert_service_id else None,
            # 折扣相关字段
            "original_price_per_participant": float(task.original_price_per_participant) if hasattr(task, 'original_price_per_participant') and task.original_price_per_participant is not None else None,
            "discount_percentage": float(task.discount_percentage) if hasattr(task, 'discount_percentage') and task.discount_percentage is not None else None,
            "discounted_price_per_participant": float(task.discounted_price_per_participant) if hasattr(task, 'discounted_price_per_participant') and task.discounted_price_per_participant is not None else None,
            "poster_user_level": poster_levels.get(task.poster_id) if task.poster_id else None,
        }
        
        # 如果有距离信息，添加到返回数据中
        if hasattr(task, '_distance_km') and task._distance_km is not None:
            task_data["distance_km"] = round(task._distance_km, 2)
        
        formatted_tasks.append(task_data)
    
    # 返回与前端期望的数据结构兼容的格式
    return {
        "tasks": formatted_tasks,
        "total": total,
        "page": page,
        "page_size": page_size
    }


def _request_lang(request: Request, current_user: Optional[models.User]) -> str:
    """展示语言：登录用户用 language_preference，游客用 query lang 或 Accept-Language。"""
    if current_user and (current_user.language_preference or "").strip().lower().startswith("zh"):
        return "zh"
    q = (request.query_params.get("lang") or "").strip().lower()
    if q in ("zh", "zh-cn", "zh_cn"):
        return "zh"
    accept = request.headers.get("accept-language") or ""
    # 简单取第一个偏好：zh 优先于 en
    for part in accept.split(","):
        part = part.split(";")[0].strip().lower()
        if part.startswith("zh"):
            return "zh"
        if part.startswith("en"):
            return "en"
    return "en"


@async_router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
async def get_task_by_id(
    task_id: int,
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """根据ID获取任务信息（异步版本）；按请求语言 ensure 双语列，缺则翻译并写入后返回。"""
    task = await async_crud.async_task_crud.get_task_by_id(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 权限检查：除了 open 状态的任务，其他状态的任务只有任务相关人才能看到详情
    # 未登录用户（含搜索引擎爬虫）可看到公开摘要，便于 SEO 索引
    _is_summary_only = False
    if task.status != "open":
        if not current_user:
            _is_summary_only = True
        else:
            user_id_str = str(current_user.id)
            is_poster = task.poster_id is not None and (str(task.poster_id) == user_id_str)
            is_taker = task.taker_id is not None and (str(task.taker_id) == user_id_str)
            is_participant = False
            is_applicant = False
            
            if task.is_multi_participant:
                if task.created_by_expert and task.expert_creator_id and str(task.expert_creator_id) == user_id_str:
                    is_participant = True
                else:
                    participant_query = select(models.TaskParticipant).where(
                        and_(
                            models.TaskParticipant.task_id == task_id,
                            models.TaskParticipant.user_id == user_id_str,
                            models.TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    )
                    participant_result = await db.execute(participant_query)
                    is_participant = participant_result.scalar_one_or_none() is not None
            
            if not is_poster and not is_taker and not is_participant:
                application_query = select(models.TaskApplication).where(
                    and_(
                        models.TaskApplication.task_id == task_id,
                        models.TaskApplication.applicant_id == user_id_str
                    )
                )
                application_result = await db.execute(application_query)
                is_applicant = application_result.scalar_one_or_none() is not None
            
            if not is_poster and not is_taker and not is_participant and not is_applicant:
                raise HTTPException(status_code=403, detail="无权限查看此任务")

    # 未登录用户看摘要：返回公开字段，隐藏敏感字段
    if _is_summary_only:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
        task.taker_id = None
        task.poster_id = None
        return task

    # view_count 移到后台任务，不阻塞响应
    def _bg_view_count(t_id: int):
        from app.database import SessionLocal
        bg_db = SessionLocal()
        try:
            bg_db.execute(update(models.Task).where(models.Task.id == t_id).values(view_count=models.Task.view_count + 1))
            bg_db.commit()
        except Exception as e:
            logger.warning("增加任务浏览量失败: %s", e)
            bg_db.rollback()
        finally:
            bg_db.close()
    background_tasks.add_task(_bg_view_count, task_id)
    
    # 按请求语言确保标题/描述有对应语种（缺则翻译并写入任务表列）；游客用 query lang 或 Accept-Language
    from app.utils.task_activity_display import (
        ensure_task_title_for_lang,
        ensure_task_description_for_lang,
    )
    lang = _request_lang(request, current_user)
    await ensure_task_title_for_lang(db, task, lang)
    await ensure_task_description_for_lang(db, task, lang)
    await db.commit()
    task.title_en = getattr(task, "title_en", None)
    task.title_zh = getattr(task, "title_zh", None)
    task.description_en = getattr(task, "description_en", None)
    task.description_zh = getattr(task, "description_zh", None)
    
    # 与活动详情一致：在详情响应中带上「当前用户是否已申请」及申请状态，便于客户端直接显示「已申请」按钮而不依赖单独接口
    if current_user:
        user_id_str = str(current_user.id)
        app_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == user_id_str,
            )
        )
        app_result = await db.execute(app_query)
        user_app = app_result.scalar_one_or_none()
        if user_app:
            setattr(task, "has_applied", True)
            setattr(task, "user_application_status", user_app.status)
        else:
            setattr(task, "has_applied", False)
            setattr(task, "user_application_status", None)
    else:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
    
    return task


# 简化的测试路由
@async_router.get("/test")
async def test_simple_route():
    """简单的测试路由"""
    return {"message": "测试路由正常工作", "status": "success"}

@async_router.post("/test")
async def test_simple_route_post():
    """简单的测试路由POST"""
    return {"message": "测试路由POST正常工作", "status": "success"}

# 异步任务创建端点（支持CSRF保护）
@async_router.post("/tasks", response_model=schemas.TaskOut)
@rate_limit("create_task")
async def create_task_async(
    task: schemas.TaskCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务（异步版本，支持CSRF保护）"""
    try:
        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能发布任务")

        # 权限检查：只有学生用户才能发布"校园生活"类型的任务
        if task.task_type == "Campus Life":
            from sqlalchemy import select
            from app.models import StudentVerification
            
            # 查询用户是否有已验证的学生认证
            verification_result = await db.execute(
                select(StudentVerification)
                .where(StudentVerification.user_id == current_user.id)
                .where(StudentVerification.status == 'verified')
                .order_by(StudentVerification.created_at.desc())
            )
            verification = verification_result.scalar_one_or_none()
            
            if not verification:
                raise HTTPException(
                    status_code=403,
                    detail='只有已通过学生认证的用户才能发布"校园生活"类型的任务，请先完成学生认证'
                )
            
            # 检查认证是否过期
            from app.utils import get_utc_time
            now = get_utc_time()
            if verification.expires_at and verification.expires_at < now:
                raise HTTPException(
                    status_code=403,
                    detail='您的学生认证已过期，请先续期后再发布"校园生活"类型的任务'
                )

        logger.debug("开始创建任务，用户ID: %s", current_user.id)
        logger.debug("任务数据: %s", task)
        
        db_task = await async_crud.async_task_crud.create_task(
            db, task, current_user.id
        )
        
        logger.debug("任务创建成功，任务ID: %s", db_task.id)
        
        # 迁移临时图片到正式的任务ID文件夹（使用图片上传服务）
        if task.images and len(task.images) > 0:
            try:
                from app.services import ImageCategory, get_image_upload_service
                import json
                
                service = get_image_upload_service()
                
                # 使用服务移动临时图片
                updated_images = service.move_from_temp(
                    category=ImageCategory.TASK,
                    user_id=current_user.id,
                    resource_id=str(db_task.id),
                    image_urls=list(task.images)
                )
                
                # 如果有图片被迁移，更新数据库中的图片URL
                if updated_images != list(task.images):
                    images_json = json.dumps(updated_images)
                    db_task.images = images_json
                    await db.commit()
                    await db.refresh(db_task)
                    logger.info(f"已更新任务 {db_task.id} 的图片URL")
                
                # 尝试删除临时目录
                service.delete_temp(category=ImageCategory.TASK, user_id=current_user.id)
                    
            except Exception as e:
                # 迁移失败不影响任务创建，只记录错误
                logger.warning(f"迁移临时图片失败: {e}")
        
        # 清除用户任务缓存，确保新任务能立即显示
        try:
            from app.redis_cache import invalidate_user_cache, invalidate_tasks_cache
            invalidate_user_cache(current_user.id)
            invalidate_tasks_cache()
            logger.debug("已清除用户 %s 的任务缓存", current_user.id)
        except Exception as e:
            logger.debug("清除缓存失败: %s", e)
        
        # 额外清除特定格式的缓存键
        try:
            from app.redis_cache import redis_cache
            # 清除所有可能的用户任务缓存键格式
            patterns = [
                f"user_tasks:{current_user.id}*",
                f"{current_user.id}_*",
                f"user_tasks:{current_user.id}_*"
            ]
            for pattern in patterns:
                deleted = redis_cache.delete_pattern(pattern)
                if deleted > 0:
                    logger.debug("清除模式 %s，删除了 %s 个键", pattern, deleted)
        except Exception as e:
            logger.debug("额外清除缓存失败: %s", e)
        
        # 处理图片字段：将JSON字符串解析为列表（使用迁移后的URL）
        import json
        images_list = None
        if db_task.images:
            try:
                images_list = json.loads(db_task.images)
            except (json.JSONDecodeError, TypeError):
                images_list = []
        
        # 返回简单的成功响应，避免序列化问题
        result = {
            "id": db_task.id,
            "title": db_task.title,
            "description": db_task.description,
            "deadline": format_iso_utc(db_task.deadline) if db_task.deadline else None,
            "reward": float(db_task.agreed_reward) if db_task.agreed_reward is not None else float(db_task.base_reward) if db_task.base_reward is not None else 0.0,
            "base_reward": float(db_task.base_reward) if db_task.base_reward else None,
            "agreed_reward": float(db_task.agreed_reward) if db_task.agreed_reward else None,
            "reward_to_be_quoted": getattr(db_task, "reward_to_be_quoted", False),
            "currency": db_task.currency or "GBP",
            "location": db_task.location,
            "task_type": db_task.task_type,
            "poster_id": db_task.poster_id,
            "taker_id": db_task.taker_id,
            "status": db_task.status,
            "task_level": db_task.task_level,
            "created_at": format_iso_utc(db_task.created_at) if db_task.created_at else None,
            "is_public": int(db_task.is_public) if db_task.is_public is not None else 1,
            "images": images_list  # 返回图片列表
        }
        
        logger.debug("准备返回结果: %s", result)
        return result
        
    except HTTPException as e:
        # Re-raise HTTPExceptions to preserve error details
        logger.debug("HTTPException in task creation: %s", e.detail)
        logger.error(f"HTTPException in task creation: {e.detail}")
        raise
    except Exception as e:
        logger.debug("Exception in task creation: %s", e)
        logger.error(f"Error creating task: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to create task")


@async_router.post("/tasks/{task_id}/apply-test", response_model=dict)
async def apply_for_task_test(
    task_id: int,
    request_data: dict = Body({}),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请任务测试端点（简化版本）"""
    try:
        message = request_data.get('message', None)
        logger.debug("测试申请任务，任务ID: %s, 用户ID: %s, message: %s", task_id, current_user.id, message)
        
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        logger.debug("任务存在: %s", task.title)
        
        return {
            "message": "测试成功",
            "task_id": task_id,
            "user_id": str(current_user.id),
            "task_title": task.title
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Test error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")


@async_router.post("/tasks/{task_id}/apply", response_model=dict)
async def apply_for_task(
    task_id: int,
    request_data: dict = Body({}),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """申请任务（异步版本，支持议价价格）"""
    try:
        from app.utils.stripe_utils import validate_user_stripe_account_for_receiving
        
        # 0. 检查用户是否有可用的收款账户
        validate_user_stripe_account_for_receiving(current_user, "申请任务")
        
        message = request_data.get('message', None)
        negotiated_price = request_data.get('negotiated_price', None)
        currency = request_data.get('currency', None)
        
        logger.info(f"开始申请任务 - 任务ID: {task_id}, 用户ID: {current_user.id}, message: {message}, negotiated_price: {negotiated_price}, currency: {currency}")
        logger.debug("开始申请任务，任务ID: %s, 用户ID: %s, message: %s, negotiated_price: %s", task_id, current_user.id, message, negotiated_price)
        
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            error_msg = "任务不存在"
            logger.warning(f"申请任务失败: {error_msg}")
            raise HTTPException(status_code=404, detail=error_msg)
        
        logger.info(f"任务检查 - 任务ID: {task_id}, 状态: {task.status}, 货币: {task.currency}")
        
        # 检查任务状态：必须是 open
        if task.status != "open":
            error_msg = f"任务状态为 {task.status}，不允许申请"
            logger.warning(f"申请任务失败: {error_msg}")
            raise HTTPException(
                status_code=400,
                detail=error_msg
            )
        
        # 检查是否已经申请过（无论状态）
        applicant_id = str(current_user.id) if current_user.id else None
        if not applicant_id:
            raise HTTPException(status_code=400, detail="Invalid user ID")
        
        existing_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == applicant_id
            )
        )
        existing_result = await db.execute(existing_query)
        existing = existing_result.scalar_one_or_none()
        
        if existing:
            raise HTTPException(
                status_code=400,
                detail="您已经申请过此任务"
            )
        
        # 校验货币一致性
        if currency and task.currency:
            if currency != task.currency:
                raise HTTPException(
                    status_code=400,
                    detail=f"货币不一致：任务使用 {task.currency}，申请使用 {currency}"
                )
        
        # 待报价任务必须议价，且议价金额必须大于 1 镑
        if getattr(task, "reward_to_be_quoted", False):
            if negotiated_price is None:
                raise HTTPException(
                    status_code=400,
                    detail="该任务为待报价任务，申请时必须填写报价金额（议价金额需大于 £1）"
                )
            try:
                price_val = float(negotiated_price)
            except (TypeError, ValueError):
                raise HTTPException(
                    status_code=400,
                    detail="报价金额格式无效，请填写大于 £1 的金额"
                )
            if price_val <= 1.0:
                raise HTTPException(
                    status_code=400,
                    detail="待报价任务的报价金额必须大于 £1"
                )
        
        # 所有用户均可申请任意等级任务（任务等级仅按赏金划分，用于展示与推荐，不限制接单权限）
        
        # 创建申请记录
        from app.utils.time_utils import get_utc_time, format_iso_utc
        from decimal import Decimal
        
        current_time = get_utc_time()
        new_application = models.TaskApplication(
            task_id=task_id,
            applicant_id=applicant_id,
            message=message,
            negotiated_price=Decimal(str(negotiated_price)) if negotiated_price is not None else None,
            currency=currency or task.currency or "GBP",
            status="pending",
            created_at=current_time
        )
        
        db.add(new_application)
        await db.flush()
        await db.commit()
        await db.refresh(new_application)
        
        # 发送通知和邮件给发布者（在申请记录提交后单独处理，避免影响申请流程）
        try:
            from app.task_notifications import send_task_application_notification
            from app.database import get_db
            
            # 创建同步数据库会话用于通知和邮件发送
            sync_db = next(get_db())
            try:
                # 获取申请者信息（用于邮件）
                applicant_query = select(models.User).where(models.User.id == applicant_id)
                applicant_result = await db.execute(applicant_query)
                applicant = applicant_result.scalar_one_or_none()
                
                if applicant:
                    # 使用同步会话发送通知和邮件
                    # 注意：这里需要重新查询任务和申请者，因为使用的是同步会话
                    from app import crud
                    sync_task = crud.get_task(sync_db, task_id)
                    sync_applicant = crud.get_user_by_id(sync_db, applicant_id)
                    
                    if sync_task and sync_applicant:
                        send_task_application_notification(
                            db=sync_db,
                            background_tasks=background_tasks,
                            task=sync_task,
                            applicant=sync_applicant,
                            application_message=message,
                            negotiated_price=float(negotiated_price) if negotiated_price else None,
                            currency=currency or task.currency or "GBP",
                            application_id=new_application.id
                        )
                        logger.info(f"已发送申请通知和邮件，任务ID: {task_id}, 申请ID: {new_application.id}")
                    else:
                        logger.warning(f"无法获取任务或申请者信息，跳过通知发送，任务ID: {task_id}")
                else:
                    logger.warning(f"申请者信息不存在，跳过通知发送，申请者ID: {applicant_id}")
            finally:
                sync_db.close()
        except Exception as e:
            logger.error(f"发送申请通知和邮件失败: {e}", exc_info=True)
            # 通知和邮件发送失败不影响申请流程，申请记录已经成功提交
        
        return {
            "message": "申请成功，请等待发布者审核",
            "application_id": new_application.id,
            "status": new_application.status
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"申请任务失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="申请任务失败")



@async_router.get("/my-applications", response_model=List[dict])
async def get_user_applications(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """获取当前用户的申请记录（优化版本：使用selectinload避免N+1查询）"""
    try:
        from sqlalchemy.orm import selectinload
        
        # 使用 selectinload 预加载任务信息，避免N+1查询
        applications_query = (
            select(models.TaskApplication)
            .options(selectinload(models.TaskApplication.task))  # 预加载任务
            .where(models.TaskApplication.applicant_id == current_user.id)
            .order_by(models.TaskApplication.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        
        applications_result = await db.execute(applications_query)
        applications = applications_result.scalars().all()
        
        # 直接使用关联数据，任务双语标题从任务表列读取
        result = []
        for app in applications:
            task = app.task  # 已预加载，无需查询
            if task:
                title_en = getattr(task, "title_en", None)
                title_zh = getattr(task, "title_zh", None)
                result.append({
                    "id": app.id,
                    "task_id": app.task_id,
                    "task_title": task.title,
                    "task_title_en": title_en,
                    "task_title_zh": title_zh,
                    "task_reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
                    "task_location": task.location,
                    "status": app.status,
                    "message": app.message,
                    "created_at": format_iso_utc(app.created_at),
                    "task_poster_id": task.poster_id,
                    "task_status": task.status,  # 添加任务状态，用于前端过滤已取消的任务
                    "task_deadline": format_iso_utc(task.deadline) if task.deadline else None  # 添加任务截止日期
                })
        
        return result
    except Exception as e:
        logger.error(f"Error getting user applications: {e}")
        raise HTTPException(status_code=500, detail="Failed to get applications")

def _format_application_item(app, user):
    """将 TaskApplication 格式化为 API 返回的 dict（共用给发布者列表与申请者查看自己的申请）"""
    negotiated_price_value = None
    if app.negotiated_price is not None:
        try:
            from decimal import Decimal
            if isinstance(app.negotiated_price, Decimal):
                negotiated_price_value = float(app.negotiated_price)
            elif isinstance(app.negotiated_price, (int, float)):
                negotiated_price_value = float(app.negotiated_price)
            else:
                negotiated_price_value = float(str(app.negotiated_price))
        except (ValueError, TypeError, AttributeError):
            negotiated_price_value = None
    return {
        "id": app.id,
        "applicant_id": app.applicant_id,
        "applicant_name": user.name if user else None,
        "applicant_avatar": user.avatar if user and hasattr(user, 'avatar') else None,
        "applicant_user_level": getattr(user, 'user_level', None) if user else None,
        "message": app.message,
        "negotiated_price": negotiated_price_value,
        "currency": app.currency or "GBP",
        "created_at": format_iso_utc(app.created_at) if app.created_at else None,
        "status": app.status,
    }


@async_router.get("/tasks/{task_id}/applications", response_model=List[dict])
async def get_task_applications(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """获取任务的申请者列表。发布者/达人可见全部；非发布者仅返回当前用户自己的申请（用于详情页显示「已申请」状态）"""
    try:
        from sqlalchemy.orm import selectinload

        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(status_code=404, detail="Task not found")

        user_id_str = str(current_user.id)
        is_poster = task.poster_id is not None and str(task.poster_id) == user_id_str
        is_expert_creator = (
            getattr(task, "is_multi_participant", False)
            and getattr(task, "expert_creator_id", None) is not None
            and str(task.expert_creator_id) == user_id_str
        )

        # 非发布者且非达人：只返回当前用户自己在该任务下的申请（任意状态），便于详情页显示「已申请/等待确认」
        if not is_poster and not is_expert_creator:
            own_query = (
                select(models.TaskApplication)
                .options(selectinload(models.TaskApplication.applicant))
                .where(models.TaskApplication.task_id == task_id)
                .where(models.TaskApplication.applicant_id == user_id_str)
                .order_by(models.TaskApplication.created_at.desc())
                .limit(1)
            )
            own_result = await db.execute(own_query)
            own_app = own_result.scalar_one_or_none()
            if not own_app:
                return []
            return [_format_application_item(own_app, own_app.applicant)]

        # 发布者/达人：返回待处理申请列表（与原有行为一致）
        applications_query = (
            select(models.TaskApplication)
            .options(selectinload(models.TaskApplication.applicant))
            .where(models.TaskApplication.task_id == task_id)
            .where(models.TaskApplication.status == "pending")
            .order_by(models.TaskApplication.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        applications_result = await db.execute(applications_query)
        applications = applications_result.scalars().all()

        result = []
        for app in applications:
            result.append(_format_application_item(app, app.applicant))

        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting task applications for {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get applications: {str(e)}")


@async_router.post("/tasks/{task_id}/approve/{applicant_id}", response_model=schemas.TaskOut)
async def approve_application(
    task_id: int,
    applicant_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """批准申请者（仅任务发布者可操作）"""
    # 检查是否为任务发布者
    task = await db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )
    task = task.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task poster can approve applications")
    
    # 🔒 安全修复：审批前验证任务是否已支付
    if not task.is_paid:
        raise HTTPException(status_code=400, detail="Task must be paid before approving applications")
    
    approved_task = await async_crud.async_task_crud.approve_application(
        db, task_id, applicant_id
    )
    
    if not approved_task:
        raise HTTPException(
            status_code=400, detail="Failed to approve application"
        )
    
    # 批准成功后发送通知和邮件给接收者
    try:
        # 获取接收者信息
        applicant_query = select(models.User).where(models.User.id == applicant_id)
        applicant_result = await db.execute(applicant_query)
        applicant = applicant_result.scalar_one_or_none()
        
        if applicant:
            # 发送通知和邮件
            from app.task_notifications import send_task_approval_notification
            from app.database import get_db
            
            # 创建同步数据库会话用于通知
            sync_db = next(get_db())
            try:
                send_task_approval_notification(
                    db=sync_db,
                    background_tasks=background_tasks,
                    task=approved_task,
                    applicant=applicant
                )
            finally:
                sync_db.close()
                
    except Exception as e:
        # 通知发送失败不影响批准流程
        logger.error(f"Failed to send task approval notification: {e}")
    
    return approved_task


@async_router.get("/users/{user_id}/tasks", response_model=dict)
async def get_user_tasks(
    user_id: str,
    task_type: str = Query("all"),
    posted_skip: int = Query(0, ge=0),
    posted_limit: int = Query(25, ge=1, le=100),
    taken_skip: int = Query(0, ge=0),
    taken_limit: int = Query(25, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的任务（异步版本，支持分页）"""
    tasks = await async_crud.async_task_crud.get_user_tasks(
        db, user_id, task_type, 
        posted_skip=posted_skip, posted_limit=posted_limit,
        taken_skip=taken_skip, taken_limit=taken_limit
    )
    
    # 任务双语标题已由查询加载在任务表列（title_zh, title_en），无需再查
    return tasks


# 异步消息路由
@async_router.post("/messages", response_model=schemas.MessageOut)
async def send_message(
    message: schemas.MessageCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """发送消息（异步版本）"""
    try:
        db_message = await async_crud.async_message_crud.create_message(
            db, current_user.id, message.receiver_id, message.content
        )
        return db_message
    except Exception as e:
        logger.error(f"Error sending message: {e}")
        raise HTTPException(status_code=500, detail="Failed to send message")


@async_router.get("/messages", response_model=List[schemas.MessageOut])
async def get_messages(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取用户的消息（异步版本）"""
    messages = await async_crud.async_message_crud.get_messages(
        db, current_user.id, skip=skip, limit=limit
    )
    return messages


@async_router.get(
    "/messages/conversation/{user_id}", response_model=List[schemas.MessageOut]
)
async def get_conversation_messages(
    user_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取与指定用户的对话消息（异步版本）"""
    messages = await async_crud.async_message_crud.get_conversation_messages(
        db, current_user.id, user_id, skip=skip, limit=limit
    )
    return messages


# 通知路由已迁移至 routers.py（GET/POST /api/notifications、/api/users/notifications）


# 系统监控路由
@async_router.get("/system/health")
async def system_health_check():
    """系统健康检查（异步版本）"""
    db_health = await check_database_health()
    return {
        "status": "healthy" if db_health else "unhealthy",
        "database": "connected" if db_health else "disconnected",
        "timestamp": "2025-01-01T00:00:00Z",  # 实际应该使用当前时间
    }


@async_router.get("/system/database/stats")
async def get_database_stats(db: AsyncSession = Depends(get_async_db_dependency)):
    """获取数据库统计信息（异步版本）"""
    stats = await async_crud.async_performance_monitor.get_database_stats(db)
    return stats


@async_router.get("/system/database/pool")
async def get_database_pool_status():
    """获取数据库连接池状态（异步版本）"""
    pool_status = await get_pool_status()
    return pool_status


@async_router.get("/tasks/{task_id}/reviews", response_model=List[schemas.ReviewOut])
async def get_task_reviews_async(
    task_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务评价（异步版本）"""
    try:
        # 先获取所有评价（用于当前用户自己的评价检查）
        all_reviews_query = select(models.Review).where(
            models.Review.task_id == task_id
        )
        all_reviews_result = await db.execute(all_reviews_query)
        all_reviews = all_reviews_result.scalars().all()
        
        # 尝试获取当前用户
        current_user = None
        logger.debug("Cookie headers: %s", request.headers.get('cookie'))
        logger.debug("请求Cookie: %s", request.cookies)
        try:
            # 尝试从Cookie中获取用户
            session_id = request.cookies.get("session_id")
            logger.debug("从Cookie获取的session_id: %s", session_id)
            if session_id:
                from app.secure_auth import validate_session
                session_info = validate_session(request)
                logger.debug("验证session结果: %s", session_info)
                if session_info:
                    user_query = select(models.User).where(models.User.id == session_info.user_id)
                    user_result = await db.execute(user_query)
                    current_user = user_result.scalar_one_or_none()
                    logger.debug("获取到当前用户: %s", current_user.id if current_user else None)
        except Exception as e:
            logger.debug("获取用户失败: %s", e, exc_info=True)
            pass  # 未登录用户
        
        logger.debug("所有评价数量: %s", len(all_reviews))
        logger.debug("当前用户ID: %s", current_user.id if current_user else None)
        
        # 过滤出非匿名评价供公开显示
        # 如果当前用户已评价，也要返回他们自己的评价（包括匿名）
        public_reviews = []
        
        if current_user:
            logger.debug("当前用户已登录: %s", current_user.id)
            for review in all_reviews:
                logger.debug("检查评价 - review.user_id: %s, is_anonymous: %s, current_user.id: %s", review.user_id, review.is_anonymous, current_user.id)
                is_current_user_review = str(review.user_id) == str(current_user.id)
                logger.debug("是否当前用户评价: %s", is_current_user_review)
                if is_current_user_review:
                    # 始终包含当前用户自己的评价，即使是匿名的
                    logger.debug("包含当前用户自己的评价: %s", review.id)
                    public_reviews.append(review)
                elif review.is_anonymous == 0:
                    # 只包含非匿名的其他用户评价
                    logger.debug("包含非匿名评价: %s", review.id)
                    public_reviews.append(review)
        else:
            # 未登录用户只看到非匿名评价
            logger.debug("用户未登录，只返回非匿名评价")
            for review in all_reviews:
                if review.is_anonymous == 0:
                    public_reviews.append(review)
        
        logger.debug("返回评价数量: %s", len(public_reviews))
        logger.debug("返回的评价ID: %s", [r.id for r in public_reviews])
        logger.debug("返回的评价用户ID: %s", [r.user_id for r in public_reviews])
        return [schemas.ReviewOut.model_validate(r) for r in public_reviews]
    except Exception as e:
        logger.error(f"Error getting task reviews for {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get task reviews: {str(e)}")


@async_router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
async def create_review_async(
    task_id: int,
    review: schemas.ReviewCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务评价（异步版本）"""
    try:
        # 检查任务是否存在且已确认完成
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        if task.status != "completed":
            raise HTTPException(status_code=400, detail="Task must be completed to create review")
        
        # 检查用户是否是任务的参与者
        # 对于单人任务：检查是否是发布者或接受者
        # 对于多人任务：检查是否是发布者、接受者或 task_participants 表中的参与者
        is_participant = False
        if task.poster_id == current_user.id or task.taker_id == current_user.id:
            is_participant = True
        elif task.is_multi_participant:
            # 检查是否是 task_participants 表中的参与者
            from sqlalchemy import select
            participant_query = select(models.TaskParticipant).where(
                models.TaskParticipant.task_id == task_id,
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(['accepted', 'in_progress', 'completed'])
            )
            participant_result = await db.execute(participant_query)
            participant = participant_result.scalar_one_or_none()
            if participant:
                is_participant = True
        
        if not is_participant:
            raise HTTPException(status_code=403, detail="Only task participants can create reviews")
        
        # 检查用户是否已经评价过这个任务
        existing_review_query = select(models.Review).where(
            models.Review.task_id == task_id,
            models.Review.user_id == current_user.id
        )
        existing_review_result = await db.execute(existing_review_query)
        existing_review = existing_review_result.scalar_one_or_none()
        
        if existing_review:
            raise HTTPException(status_code=400, detail="You have already reviewed this task")
        
        # 清理评价内容（防止XSS攻击）
        cleaned_comment = None
        if review.comment:
            from html import escape
            cleaned_comment = escape(review.comment.strip())
            # 限制长度（虽然schema已经验证，但这里再次确保）
            if len(cleaned_comment) > 500:
                cleaned_comment = cleaned_comment[:500]
        
        # 创建评价
        db_review = models.Review(
            user_id=current_user.id,
            task_id=task_id,
            rating=review.rating,
            comment=cleaned_comment,
            is_anonymous=1 if review.is_anonymous else 0,
        )
        
        db.add(db_review)
        await db.commit()
        await db.refresh(db_review)
        
        # 清除评价列表缓存，确保新评价立即显示
        try:
            from app.cache import invalidate_cache
            # 清除该任务的所有评价缓存（使用通配符匹配所有可能的缓存键）
            invalidate_cache(f"task_reviews:get_task_reviews:*")
            logger.info(f"已清除任务 {task_id} 的评价列表缓存（异步路由）")
        except Exception as e:
            logger.warning(f"清除评价缓存失败（异步路由）: {e}")
        
        # 更新被评价用户的统计信息（使用同步数据库会话）
        # 确定被评价的用户（不是评价者）
        # 对于单人任务：发布者评价接受者，接受者评价发布者
        # 对于多人任务（达人创建的活动）：
        #   - 参与者评价达人（expert_creator_id）
        #   - 达人评价第一个参与者（originating_user_id，即第一个申请者）
        reviewed_user_id = None
        if task.is_multi_participant:
            # 多人任务
            if task.created_by_expert and task.expert_creator_id:
                # 如果评价者是参与者（不是达人），被评价者是达人
                if current_user.id != task.expert_creator_id:
                    reviewed_user_id = task.expert_creator_id
                # 如果评价者是达人，被评价者是第一个参与者（originating_user_id）
                elif task.originating_user_id:
                    reviewed_user_id = task.originating_user_id
            elif task.taker_id and current_user.id != task.taker_id:
                # 如果taker_id存在且不是评价者，则被评价者是taker_id
                reviewed_user_id = task.taker_id
        else:
            # 单人任务：发布者评价接受者，接受者评价发布者
            reviewed_user_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
        
        if reviewed_user_id:
            # 使用同步数据库会话更新统计信息
            try:
                from app.database import SessionLocal
                sync_db = SessionLocal()
                try:
                    from app import crud
                    crud.update_user_statistics(sync_db, reviewed_user_id)
                finally:
                    sync_db.close()
            except Exception as e:
                logger.warning(f"更新用户统计信息失败（异步路由）: {e}，将通过定时任务更新")
        
        return db_review
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating review for task {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create review: {str(e)}")


@async_router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
async def confirm_task_completion_async(
    task_id: int,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务发布者确认任务完成（异步版本）"""
    try:
        # 获取任务信息
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # 检查权限
        if task.poster_id != current_user.id:
            raise HTTPException(status_code=403, detail="Only task poster can confirm completion")
        
        # 检查任务状态
        if task.status != "pending_confirmation":
            raise HTTPException(status_code=400, detail="Task is not pending confirmation")
        
        # 更新任务状态为已完成
        task.status = "completed"
        await db.commit()
        
        # 添加任务历史记录
        from app import crud
        from app.database import get_db
        sync_db = next(get_db())
        try:
            crud.add_task_history(sync_db, task_id, current_user.id, "confirmed_completion")
        finally:
            sync_db.close()
        
        # 重新查询任务以确保获取最新状态（refresh 在异步会话中可能不可靠）
        await db.refresh(task)
        # 如果 refresh 失败，重新查询
        if task.status != "completed":
            task_query = select(models.Task).where(models.Task.id == task_id)
            task_result = await db.execute(task_query)
            task = task_result.scalar_one_or_none()
            if not task:
                raise HTTPException(status_code=404, detail="Task not found after update")
        
        # 发送任务确认完成通知和邮件给接收者
        if task.taker_id:
            try:
                # 获取接收者信息
                taker_query = select(models.User).where(models.User.id == task.taker_id)
                taker_result = await db.execute(taker_query)
                taker = taker_result.scalar_one_or_none()
                
                if taker:
                    # 发送通知和邮件
                    from app.task_notifications import send_task_confirmation_notification
                    from app.database import get_db
                    from fastapi import BackgroundTasks
                    
                    # 确保 background_tasks 存在，如果为 None 则创建新实例
                    if background_tasks is None:
                        background_tasks = BackgroundTasks()
                    
                    # 创建同步数据库会话用于通知
                    sync_db = next(get_db())
                    try:
                        send_task_confirmation_notification(
                            db=sync_db,
                            background_tasks=background_tasks,
                            task=task,
                            taker=taker
                        )
                    finally:
                        sync_db.close()
            except Exception as e:
                # 通知发送失败不影响确认流程
                logger.error(f"Failed to send task confirmation notification: {e}")
        
        # 注意：统计信息更新暂时跳过，避免异步/同步混用问题
        # 统计信息可以通过后台任务或定时任务更新
        
        return task
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error confirming task completion: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to confirm task completion: {str(e)}")


# ---------- 活动详情（异步，按语言 ensure 双语列）----------
@async_router.get("/activities/{activity_id}/i18n", response_model=schemas.ActivityOut)
async def get_activity_detail_async(
    activity_id: int,
    request: Request,
    lang: str = Query("en", description="展示语言: en 或 zh"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取活动详情（异步）。根据 lang 确保 title/description 的对应语言列有值，缺则翻译并写入后返回。
    路径为 /api/activities/{activity_id}/i18n?lang=en|zh，与 sync 的 GET /api/activities/{activity_id} 并存。
    """
    from sqlalchemy.orm import selectinload

    # 规范 lang：仅支持 zh / en
    if lang and (lang.startswith("zh") or lang.lower() == "zh-cn"):
        lang = "zh"
    else:
        lang = "en"

    # 加载活动及关联服务
    stmt = (
        select(models.Activity)
        .options(selectinload(models.Activity.service))
        .where(models.Activity.id == activity_id)
    )
    result = await db.execute(stmt)
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")

    # 按需翻译并写入双语列
    from app.utils.task_activity_display import (
        ensure_activity_title_for_lang,
        ensure_activity_description_for_lang,
    )
    await ensure_activity_title_for_lang(db, activity, lang)
    await ensure_activity_description_for_lang(db, activity, lang)
    await db.commit()

    # 参与者数量：多人任务参与者 + 单任务数
    multi_stmt = (
        select(func.count(models.TaskParticipant.id))
        .select_from(models.TaskParticipant)
        .join(models.Task, models.TaskParticipant.task_id == models.Task.id)
        .where(
            models.Task.parent_activity_id == activity_id,
            models.Task.is_multi_participant == True,
            models.Task.status != "cancelled",
            models.TaskParticipant.status.in_(["accepted", "in_progress", "completed"]),
        )
    )
    multi_result = await db.execute(multi_stmt)
    multi_count = multi_result.scalar() or 0
    single_stmt = (
        select(func.count(models.Task.id))
        .where(
            models.Task.parent_activity_id == activity_id,
            models.Task.is_multi_participant == False,
            models.Task.status.in_(["open", "taken", "in_progress"]),
        )
    )
    single_result = await db.execute(single_stmt)
    single_count = single_result.scalar() or 0
    current_count = multi_count + single_count

    # 当前用户是否已申请
    has_applied = None
    user_task_id = None
    user_task_status = None
    user_task_is_paid = None
    user_task_has_negotiation = None
    try:
        current_user = await get_current_user_optional(request, db)
    except HTTPException:
        current_user = None
    if current_user:
        multi_task_stmt = (
            select(models.Task)
            .join(models.TaskParticipant, models.Task.id == models.TaskParticipant.task_id)
            .where(
                models.Task.parent_activity_id == activity_id,
                models.Task.is_multi_participant == True,
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["pending", "accepted", "in_progress", "completed"]),
            )
        )
        single_task_stmt = (
            select(models.Task)
            .where(
                models.Task.parent_activity_id == activity_id,
                models.Task.is_multi_participant == False,
                models.Task.originating_user_id == current_user.id,
                models.Task.status.in_(["open", "taken", "in_progress", "pending_payment", "completed"]),
            )
        )
        multi_task_result = await db.execute(multi_task_stmt)
        multi_task = multi_task_result.scalar_one_or_none()
        single_task_result = await db.execute(single_task_stmt)
        single_task = single_task_result.scalar_one_or_none()
        user_task = single_task if single_task else multi_task
        has_applied = user_task is not None
        if user_task:
            user_task_id = user_task.id
            user_task_status = user_task.status
            user_task_is_paid = bool(user_task.is_paid)
            user_task_has_negotiation = (
                user_task.agreed_reward is not None
                and user_task.base_reward is not None
                and float(user_task.agreed_reward) != float(user_task.base_reward)
            )

    return schemas.ActivityOut.from_orm_with_participants(
        activity,
        current_count,
        has_applied=has_applied,
        user_task_id=user_task_id,
        user_task_status=user_task_status,
        user_task_is_paid=user_task_is_paid,
        user_task_has_negotiation=user_task_has_negotiation,
    )


# 批量操作路由
@async_router.post("/notifications/batch")
async def batch_create_notifications(
    notifications: List[schemas.NotificationCreate],
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """批量创建通知（异步版本）"""
    try:
        notification_data = [
            {
                "user_id": current_user.id,
                "type": notification.type,
                "title": notification.title,
                "content": notification.content,
                "related_id": notification.related_id,
            }
            for notification in notifications
        ]

        db_notifications = await async_crud.async_batch_ops.batch_create_notifications(
            db, notification_data
        )
        return db_notifications
    except Exception as e:
        logger.error(f"Error batch creating notifications: {e}")
        raise HTTPException(status_code=500, detail="Failed to create notifications")

"""
异步CRUD操作模块
提供高性能的异步数据库操作
"""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi import HTTPException

from app import models, schemas
from app.security import get_password_hash
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc
import uuid

logger = logging.getLogger(__name__)


# 异步用户操作
class AsyncUserCRUD:
    """异步用户CRUD操作"""

    @staticmethod
    async def get_user_by_id(db: AsyncSession, user_id: str) -> Optional[models.User]:
        """根据ID获取用户"""
        try:
            result = await db.execute(
                select(models.User).where(models.User.id == user_id)
            )
            return result.scalar_one_or_none()
        except RuntimeError as e:
            # 只在确认应用正在关停时才优雅降级
            from app.state import is_app_shutting_down
            error_str = str(e)
            
            if is_app_shutting_down() and (
                "Event loop is closed" in error_str or "loop is closed" in error_str
            ):
                logger.debug(f"事件循环已关闭，跳过查询用户 {user_id}（应用正在关闭）")
                return None
            
            # 其它 RuntimeError 应该继续抛出，避免吞掉真正的问题
            logger.error(f"Error getting user by ID {user_id}: {e}")
            raise
        except Exception as e:
            # 检查是否是事件循环关闭的错误（仅在关停时）
            from app.state import is_app_shutting_down
            error_str = str(e)
            
            if is_app_shutting_down() and (
                "Event loop is closed" in error_str or "loop is closed" in error_str
            ):
                logger.debug(f"事件循环已关闭，跳过查询用户 {user_id}（应用正在关闭）")
                return None
            
            logger.error(f"Error getting user by ID {user_id}: {e}")
            return None

    @staticmethod
    async def get_user_by_email(db: AsyncSession, email: str) -> Optional[models.User]:
        """根据邮箱获取用户"""
        try:
            result = await db.execute(
                select(models.User).where(models.User.email == email)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Error getting user by email {email}: {e}")
            return None

    @staticmethod
    async def get_user_by_phone(db: AsyncSession, phone: str) -> Optional[models.User]:
        """根据手机号获取用户"""
        try:
            # 先尝试直接匹配（完整格式）
            result = await db.execute(
                select(models.User).where(models.User.phone == phone)
            )
            user = result.scalar_one_or_none()
            if user:
                return user
            
            # 如果直接匹配失败，尝试格式化后匹配
            import re
            digits = re.sub(r'\D', '', phone)
            
            # 如果是11位数字以07开头（英国号码），转换为 +44 格式
            if len(digits) == 11 and digits.startswith('07'):
                uk_number = digits[1:]  # 去掉开头的0
                formatted_phone = f"+44{uk_number}"
                result = await db.execute(
                    select(models.User).where(models.User.phone == formatted_phone)
                )
                user = result.scalar_one_or_none()
                if user:
                    return user
            
            # 尝试清理格式后匹配（向后兼容）
            result = await db.execute(
                select(models.User).where(models.User.phone == digits)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Error getting user by phone {phone}: {e}")
            return None

    @staticmethod
    async def get_user_by_name(db: AsyncSession, name: str) -> Optional[models.User]:
        """根据用户名获取用户"""
        try:
            result = await db.execute(
                select(models.User).where(models.User.name == name)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Error getting user by name {name}: {e}")
            return None

    @staticmethod
    async def create_user(db: AsyncSession, user: schemas.UserCreate) -> models.User:
        """创建用户"""
        try:
            # 生成用户ID
            user_id = str(uuid.uuid4())[:8]
            
            # 哈希密码
            hashed_password = get_password_hash(user.password)
            
            # 处理同意时间
            terms_agreed_at = None
            if user.terms_agreed_at:
                terms_agreed_at = parse_iso_utc(user.terms_agreed_at.replace('Z', '+00:00') if user.terms_agreed_at.endswith('Z') else user.terms_agreed_at)
            
            db_user = models.User(
                id=user_id,
                name=user.name,
                email=user.email,
                hashed_password=hashed_password,
                phone=user.phone,
                avatar=user.avatar or "",
                user_level="normal",
                timezone="Europe/London",
                agreed_to_terms=1 if user.agreed_to_terms else 0,
                terms_agreed_at=terms_agreed_at,
            )
            db.add(db_user)
            await db.commit()
            await db.refresh(db_user)
            return db_user
        except IntegrityError as e:
            await db.rollback()
            logger.error(f"Integrity error creating user: {e}")
            raise
        except Exception as e:
            await db.rollback()
            logger.error(f"Error creating user: {e}")
            raise

    @staticmethod
    async def update_user(
        db: AsyncSession, user_id: str, user_update: schemas.UserUpdate
    ) -> Optional[models.User]:
        """更新用户信息"""
        try:
            result = await db.execute(
                update(models.User)
                .where(models.User.id == user_id)
                .values(**user_update.dict(exclude_unset=True))
                .returning(models.User)
            )
            updated_user = result.scalar_one_or_none()
            if updated_user:
                await db.commit()
                await db.refresh(updated_user)
            return updated_user
        except Exception as e:
            await db.rollback()
            logger.error(f"Error updating user {user_id}: {e}")
            return None

    @staticmethod
    async def get_users(
        db: AsyncSession, skip: int = 0, limit: int = 100
    ) -> List[models.User]:
        """获取用户列表"""
        try:
            result = await db.execute(
                select(models.User)
                .offset(skip)
                .limit(limit)
                .order_by(models.User.created_at.desc())
            )
            return list(result.scalars().all())
        except Exception as e:
            logger.error(f"Error getting users: {e}")
            return []


# 异步任务操作
class AsyncTaskCRUD:
    """异步任务CRUD操作"""

    @staticmethod
    async def get_task_by_id(db: AsyncSession, task_id: int) -> Optional[models.Task]:
        """根据ID获取任务"""
        try:
            result = await db.execute(
                select(models.Task)
                .options(selectinload(models.Task.poster))
                .options(selectinload(models.Task.taker))
                .options(selectinload(models.Task.time_slot_relations).selectinload(models.TaskTimeSlotRelation.time_slot))
                .options(selectinload(models.Task.participants))  # 加载参与者关系，用于动态计算current_participants
                .options(selectinload(models.Task.parent_activity))  # 预加载父活动，供 TaskOut.from_orm 在任务无图片时回退使用活动图片
                .options(selectinload(models.Task.expert_service))  # 预加载达人服务，供 TaskOut.from_orm 在任务无图时回退 service.images
                .options(selectinload(models.Task.flea_market_item))  # 预加载跳蚤市场商品，供 TaskOut.from_orm 在任务无图时回退 item.images
                .where(models.Task.id == task_id)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Error getting task by ID {task_id}: {e}")
            return None

    @staticmethod
    async def create_task(
        db: AsyncSession, task: schemas.TaskCreate, poster_id: str
    ) -> models.Task:
        """创建任务"""
        try:
            # 获取用户信息以确定任务等级
            from app.models import User
            
            user_result = await db.execute(
                select(User).where(User.id == poster_id)
            )
            user = user_result.scalar_one_or_none()
            
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            
            # 获取系统设置中的价格阈值
            settings = await AsyncTaskCRUD.get_system_settings_dict(db)
            vip_price_threshold = float(settings.get("vip_price_threshold", 10.0))
            super_vip_price_threshold = float(settings.get("super_vip_price_threshold", 50.0))
            
            # 处理价格字段：base_reward 是发布时的价格（先处理价格，用于后续判断）
            from decimal import Decimal
            base_reward_value = Decimal(str(task.reward)) if task.reward is not None else Decimal('0')
            
            # 任务等级分配逻辑（使用base_reward判断）
            user_level = str(user.user_level) if user.user_level is not None else "normal"
            # 获取价格用于等级判断（使用base_reward_value，即从task.reward转换来的值）
            task_price = float(base_reward_value)
            if user_level == "super":
                task_level = "vip"
            elif task_price >= super_vip_price_threshold:
                task_level = "super"
            elif task_price >= vip_price_threshold:
                task_level = "vip"
            else:
                task_level = "normal"
            
            # 处理灵活时间和截止日期的一致性
            is_flexible = getattr(task, "is_flexible", 0) or 0
            deadline = None
            
            if is_flexible == 1:
                # 灵活模式：deadline 必须为 None
                deadline = None
            elif task.deadline is not None:
                # 非灵活模式：确保 deadline 是 timezone-naive 的 datetime
                from datetime import timezone
                if task.deadline.tzinfo is not None:
                    # 如果deadline有时区信息，转换为UTC然后移除时区信息
                    deadline = task.deadline.astimezone(timezone.utc).replace(tzinfo=None)
                else:
                    deadline = task.deadline
                is_flexible = 0  # 有截止日期，确保 is_flexible=0
            else:
                # 如果没有提供 deadline 且不是灵活模式，需要设置一个默认值
                # 这里可以根据业务需求设置默认值，或者抛出错误
                from datetime import timedelta
                from app.utils.time_utils import get_utc_time
                deadline = get_utc_time() + timedelta(days=7)
                is_flexible = 0
            
            # 处理图片字段：将列表转为JSON字符串
            import json
            images_json = None
            if task.images and len(task.images) > 0:
                images_json = json.dumps(task.images)
            
            db_task = models.Task(
                title=task.title,
                description=task.description,
                task_type=task.task_type,
                location=task.location,
                latitude=getattr(task, "latitude", None),  # 纬度（可选）
                longitude=getattr(task, "longitude", None),  # 经度（可选）
                reward=task.reward,  # 与base_reward同步
                base_reward=base_reward_value,  # 原始标价（发布时的价格）
                agreed_reward=None,  # 初始为空，如果有议价才会设置
                currency=getattr(task, "currency", "GBP") or "GBP",  # 货币类型
                deadline=deadline,
                is_flexible=is_flexible,  # 设置灵活时间标识
                poster_id=poster_id,
                status="open",
                task_level=task_level,
                is_public=getattr(task, "is_public", 1),  # 默认为公开
                images=images_json,  # 存储为JSON字符串
            )
            
            db.add(db_task)
            await db.commit()
            await db.refresh(db_task)
            return db_task
        except Exception as e:
            await db.rollback()
            logger.error(f"Error creating task: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create task: {str(e)}")

    @staticmethod
    async def get_tasks(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 100,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        status: Optional[str] = None,
        keyword: Optional[str] = None,
        sort_by: Optional[str] = "latest",
    ) -> List[models.Task]:
        """获取任务列表（带过滤条件，带Redis缓存）"""
        try:
            # 尝试从Redis缓存获取
            from app.redis_cache import get_tasks_list, cache_tasks_list
            
            cache_params = {
                'skip': skip,
                'limit': limit,
                'task_type': task_type,
                'location': location,
                'status': status,
                'keyword': keyword,
                'sort_by': sort_by
            }
            
            cached_tasks = get_tasks_list(cache_params)
            if cached_tasks:
                return cached_tasks
            
            # 缓存未命中，从数据库查询
            from sqlalchemy import or_
            
            query = (
                select(models.Task)
                .options(selectinload(models.Task.poster))
                .where(models.Task.status == "open")
            )

            if task_type and task_type not in ['全部类型', '全部', 'all']:
                query = query.where(models.Task.task_type == task_type)
            if location and location not in ['全部城市', '全部', 'all']:
                if location.lower() == 'other':
                    # "Other" 筛选：排除所有预定义城市和 Online（支持中英文地址）
                    from sqlalchemy import not_
                    from app.utils.city_filter_utils import build_other_exclusion_filter
                    exclusion_expr = build_other_exclusion_filter(models.Task.location)
                    if exclusion_expr is not None:
                        query = query.where(not_(exclusion_expr))
                elif location.lower() == 'online':
                    # Online 精确匹配
                    query = query.where(models.Task.location.ilike("%online%"))
                else:
                    from app.utils.city_filter_utils import build_city_location_filter
                    city_expr = build_city_location_filter(models.Task.location, location)
                    if city_expr is not None:
                        query = query.where(city_expr)
            if status and status not in ['全部状态', '全部', 'all']:
                query = query.where(models.Task.status == status)
            
            # 添加关键词搜索（支持pg_trgm或全文搜索，根据配置选择）
            has_keyword_sort = False
            if keyword:
                keyword = keyword.strip()
                from app.config import Config
                
                if Config.USE_PG_TRGM:
                    # 方案1: pg_trgm（适合需要容错搜索的场景，中英文都适用）
                    query = query.where(
                        or_(
                            func.similarity(models.Task.title, keyword) > 0.2,
                            func.similarity(models.Task.description, keyword) > 0.2,
                        )
                    )
                    # 如果使用关键词搜索，默认按相似度排序（除非指定了其他排序方式）
                    if sort_by == "latest" or sort_by is None:
                        query = query.order_by(
                            func.similarity(models.Task.title, keyword).desc(),
                            func.similarity(models.Task.description, keyword).desc(),
                            # 添加稳定的 tie-breaker，避免相似度接近时顺序抖动
                            models.Task.created_at.desc(),
                            models.Task.id.desc()
                        )
                        has_keyword_sort = True
                else:
                    # 方案2: 全文搜索（适合精确搜索，主要针对英文）
                    ts_vector = func.to_tsvector(
                        Config.SEARCH_LANGUAGE,
                        models.Task.title + ' ' + models.Task.description
                    )
                    ts_query = func.plainto_tsquery(Config.SEARCH_LANGUAGE, keyword)
                    query = query.where(ts_vector.op('@@')(ts_query))
                    # 可选：按相关性排序
                    # query = query.order_by(func.ts_rank(ts_vector, ts_query).desc())

            # 排序（如果关键词搜索已经设置了排序，则跳过）
            if not has_keyword_sort:
                if sort_by == "latest":
                    # 优先显示新任务（24小时内）
                    from datetime import timedelta
                    from sqlalchemy import case
                    recent_24h = now_utc - timedelta(hours=24)
                    sort_weight = case(
                        (models.Task.created_at >= recent_24h, 2),  # 新任务权重=2
                        else_=1  # 普通任务权重=1
                    )
                    query = query.order_by(
                        sort_weight.desc(),  # 先按权重排序（新任务在前）
                        models.Task.created_at.desc()  # 再按创建时间排序
                    )
                elif sort_by == "oldest":
                    query = query.order_by(models.Task.created_at.asc())
                elif sort_by == "reward_high" or sort_by == "reward_desc":
                    # 使用base_reward排序
                    query = query.order_by(models.Task.base_reward.desc())
                elif sort_by == "reward_low" or sort_by == "reward_asc":
                    # 使用base_reward排序
                    query = query.order_by(models.Task.base_reward.asc())
                elif sort_by == "deadline_asc":
                    query = query.order_by(models.Task.deadline.asc())
                elif sort_by == "deadline_desc":
                    query = query.order_by(models.Task.deadline.desc())
                else:
                    # 默认也支持新任务优先
                    from datetime import timedelta
                    from sqlalchemy import case
                    recent_24h = now_utc - timedelta(hours=24)
                    sort_weight = case(
                        (models.Task.created_at >= recent_24h, 2),
                        else_=1
                    )
                    query = query.order_by(sort_weight.desc(), models.Task.created_at.desc())

            result = await db.execute(
                query.offset(skip).limit(limit)
            )
            tasks = list(result.scalars().all())
            
            # 缓存查询结果
            cache_tasks_list(cache_params, tasks)
            return tasks
        except Exception as e:
            logger.error(f"Error getting tasks: {e}")
            return []

    @staticmethod
    async def get_tasks_with_total(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 100,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        status: Optional[str] = None,
        keyword: Optional[str] = None,
        sort_by: Optional[str] = "latest",
        expert_creator_id: Optional[str] = None,
        is_multi_participant: Optional[bool] = None,
        parent_activity_id: Optional[int] = None,
        user_latitude: Optional[float] = None,
        user_longitude: Optional[float] = None,
    ) -> tuple[List[models.Task], int]:
        """
        获取任务列表 + 总数（使用缓存 + 精确 count，不用 reltuples 估算）
        
        规则约束：
        - 即使 status 为 None，也默认视为 status='open'，这也算"有筛选"
        - 只要 status / task_type / location / keyword 任一有值，就视为"有筛选"
        - 本函数统一使用缓存 + 精确 count，不再使用 reltuples 估算
        """
        try:
            from sqlalchemy import or_, func
            from app.utils.time_utils import get_utc_time
            from app.redis_cache import get_tasks_count_cache_key
            from app.config import Config
            
            # 获取当前UTC时间
            now_utc = get_utc_time()
            
            # 1. 构建 base_query（列表 & 总数共用）
            # 如果指定了 parent_activity_id，显示所有状态的任务（用于统计活动关联的任务）
            if parent_activity_id is not None:
                actual_status = None
                base_query = select(models.Task)
            elif expert_creator_id:
                # 达人查看自己的活动时，显示所有状态
                actual_status = status or None
                base_query = select(models.Task)
                if status and status != "all":
                    base_query = base_query.where(models.Task.status == status)
            else:
                # 公开任务列表：只显示开放中的任务
                actual_status = status or "open"
                if actual_status == "all":
                    # status='all' 时，显示所有状态的任务
                    base_query = select(models.Task)
                else:
                    base_query = select(models.Task).where(
                        or_(
                            models.Task.status == "open",
                            models.Task.status == "taken"
                        )
                    ).where(
                        or_(
                            models.Task.deadline > now_utc,  # 有截止日期且未过期
                            models.Task.deadline.is_(None)  # 灵活模式（无截止日期）
                        )
                    )

            # 任务类型筛选
            if task_type and task_type not in ["全部类型", "全部", "all"]:
                base_query = base_query.where(models.Task.task_type == task_type)
            
            # 地点筛选（使用精确城市匹配）
            if location and location not in ["全部城市", "全部", "all"]:
                if location.lower() == 'other':
                    # "Other" 筛选：排除所有预定义城市和 Online（支持中英文地址）
                    from sqlalchemy import not_
                    from app.utils.city_filter_utils import build_other_exclusion_filter
                    exclusion_expr = build_other_exclusion_filter(models.Task.location)
                    if exclusion_expr is not None:
                        base_query = base_query.where(not_(exclusion_expr))
                elif location.lower() == 'online':
                    base_query = base_query.where(models.Task.location.ilike("%online%"))
                else:
                    from app.utils.city_filter_utils import build_city_location_filter
                    city_expr = build_city_location_filter(models.Task.location, location)
                    if city_expr is not None:
                        base_query = base_query.where(city_expr)
            
            # 关键词筛选（和 /tasks 的实现保持一致）
            if keyword:
                keyword = keyword.strip()
                from app.config import Config
                
                if Config.USE_PG_TRGM:
                    # pg_trgm 相似度搜索
                    base_query = base_query.where(
                        or_(
                            func.similarity(models.Task.title, keyword) > 0.2,
                            func.similarity(models.Task.description, keyword) > 0.2,
                        )
                    )
                else:
                    # 全文搜索
                    ts_vector = func.to_tsvector(
                        Config.SEARCH_LANGUAGE,
                        models.Task.title + " " + models.Task.description,
                    )
                    ts_query = func.plainto_tsquery(Config.SEARCH_LANGUAGE, keyword)
                    base_query = base_query.where(ts_vector.op("@@")(ts_query))
            
            # 达人创建者筛选
            if expert_creator_id:
                base_query = base_query.where(models.Task.expert_creator_id == expert_creator_id)
            
            # 多人任务筛选
            if is_multi_participant is not None:
                base_query = base_query.where(models.Task.is_multi_participant == is_multi_participant)
            
            if parent_activity_id is not None:
                base_query = base_query.where(models.Task.parent_activity_id == parent_activity_id)
            
            # 只有明确使用距离排序时，才过滤掉"Online"任务（用于"附近"功能）
            # 推荐任务和任务大厅不使用距离排序，也不隐藏 online 任务
            if user_latitude is not None and user_longitude is not None and sort_by in ("distance", "nearby"):
                base_query = base_query.where(
                    ~models.Task.location.ilike("%online%")
                )
            
            # 2. 先算 total（缓存 + 精确 count）
            # 如果有用户位置且使用距离排序，total计算需要过滤掉没有坐标的任务
            # 这样 total 才能和实际返回的任务数量匹配
            count_query_for_total = base_query
            if user_latitude is not None and user_longitude is not None and sort_by in ("distance", "nearby"):
                # 对于距离排序，total 应该只计算有坐标的任务（和 list_query 保持一致）
                count_query_for_total = count_query_for_total.where(
                    (models.Task.latitude.isnot(None)) & 
                    (models.Task.longitude.isnot(None))
                )
            
            cache_key = get_tasks_count_cache_key(
                task_type=task_type,
                location=location,
                status=actual_status,  # 包含默认 'open'
                keyword=keyword,
            )
            
            # 如果有用户位置，修改缓存键以区分
            if user_latitude is not None and user_longitude is not None:
                # 将位置信息四舍五入到小数点后2位（约1km精度），用于缓存分组
                lat_rounded = round(user_latitude, 2)
                lon_rounded = round(user_longitude, 2)
                cache_key = f"{cache_key}:nearby:{lat_rounded}:{lon_rounded}"
                # 如果使用距离排序，在缓存键中标记
                if sort_by in ("distance", "nearby"):
                    cache_key = f"{cache_key}:distance"
            
            # 尝试从缓存获取总数
            try:
                # 使用异步Redis客户端（使用上下文管理器确保正确关闭）
                import redis.asyncio as aioredis
                redis_url = Config.REDIS_URL or f"redis://{Config.REDIS_HOST}:{Config.REDIS_PORT}/{Config.REDIS_DB}"
                
                async with aioredis.from_url(redis_url, decode_responses=True) as async_redis:
                    cached_total = await async_redis.get(cache_key)
                    if cached_total is not None:
                        try:
                            total = int(cached_total)
                        except ValueError:
                            total = 0
                    else:
                        # 缓存未命中，执行精确 count
                        count_query = select(func.count()).select_from(count_query_for_total.subquery())
                        total_result = await db.execute(count_query)
                        total = total_result.scalar() or 0
                        # 缓存总数（TTL 可以按需调整）
                        await async_redis.setex(cache_key, 300, str(total))
            except Exception as e:
                # Redis 不可用时，直接执行 count
                logger.warning(f"Redis缓存失败，直接执行count: {e}")
                count_query = select(func.count()).select_from(count_query_for_total.subquery())
                total_result = await db.execute(count_query)
                total = total_result.scalar() or 0
            
            # 3. 列表查询（基于同一个 base_query）
            list_query = base_query.options(
                selectinload(models.Task.poster)
            )
            
            # 排序：注意和 get_tasks_cursor 的约束保持一致
            # 如果提供了用户位置，先获取更多任务（用于距离计算），然后在Python中排序
            # 性能优化：限制查询范围，只处理有坐标的任务，并使用粗略的距离过滤
            use_distance_sorting = False
            if user_latitude is not None and user_longitude is not None and sort_by in ("distance", "nearby"):
                use_distance_sorting = True
                
                # 粗略的距离过滤：使用简单的经纬度范围过滤（扩大范围以确保有结果）
                # 1度纬度 ≈ 111km，所以 ±1度 ≈ ±111km
                # 1度经度在UK纬度（约51度）≈ 111km * cos(51°) ≈ 70km，所以 ±1.5度 ≈ ±105km
                lat_range = 1.0  # 约111km（扩大范围）
                lon_range = 1.5  # 约105km（在UK纬度，扩大范围）
                
                # 获取有坐标的任务（在粗略范围内）和没有坐标但同城的任务（用于城市匹配）
                # 使用 OR 条件：有坐标且在范围内 OR 没有坐标但同城
                from sqlalchemy import or_, and_
                
                # 如果已经按城市过滤（location参数不为空），则只获取同城的无坐标任务
                # 如果没有按城市过滤，则获取所有无坐标任务（将在Python中按城市匹配）
                if location and location not in ["全部城市", "全部", "all"]:
                    # 已经按城市过滤，只获取同城的任务（有坐标或在范围内，或无坐标但同城）
                    list_query = list_query.where(
                        or_(
                            # 有坐标且在粗略范围内
                            and_(
                                models.Task.latitude.isnot(None),
                                models.Task.longitude.isnot(None),
                                models.Task.latitude >= user_latitude - lat_range,
                                models.Task.latitude <= user_latitude + lat_range,
                                models.Task.longitude >= user_longitude - lon_range,
                                models.Task.longitude <= user_longitude + lon_range
                            ),
                            # 没有坐标的任务（已经通过location参数过滤为同城）
                            and_(
                                or_(
                                    models.Task.latitude.is_(None),
                                    models.Task.longitude.is_(None)
                                )
                            )
                        )
                    )
                else:
                    # 没有按城市过滤，获取有坐标的任务和所有无坐标的任务（将在Python中按城市匹配）
                    list_query = list_query.where(
                        or_(
                            # 有坐标且在粗略范围内
                            and_(
                                models.Task.latitude.isnot(None),
                                models.Task.longitude.isnot(None),
                                models.Task.latitude >= user_latitude - lat_range,
                                models.Task.latitude <= user_latitude + lat_range,
                                models.Task.longitude >= user_longitude - lon_range,
                                models.Task.longitude <= user_longitude + lon_range
                            ),
                            # 没有坐标的任务（将在后续按城市匹配排序）
                            and_(
                                or_(
                                    models.Task.latitude.is_(None),
                                    models.Task.longitude.is_(None)
                                )
                            )
                        )
                    )
                
                list_query = list_query.order_by(
                    models.Task.created_at.desc(), models.Task.id.desc()
                )
                
                # 增加获取数量（用于距离计算和城市匹配），但限制在合理范围内
                # 例如：如果用户请求20条，我们获取200条来计算距离，然后返回最近的20条
                max_fetch_for_distance = min(limit * 10, 500)  # 最多500条
                list_query = list_query.limit(max_fetch_for_distance)
            elif sort_by == "latest":
                # 优先显示新任务（24小时内）
                from datetime import timedelta
                from sqlalchemy import case
                recent_24h = now_utc - timedelta(hours=24)
                sort_weight = case(
                    (models.Task.created_at >= recent_24h, 2),  # 新任务权重=2
                    else_=1  # 普通任务权重=1
                )
                list_query = list_query.order_by(
                    sort_weight.desc(),  # 先按权重排序
                    models.Task.created_at.desc(),  # 再按创建时间
                    models.Task.id.desc()  # 最后按ID
                )
            elif sort_by == "oldest":
                list_query = list_query.order_by(
                    models.Task.created_at.asc(), models.Task.id.asc()
                )
            elif sort_by == "reward_high" or sort_by == "reward_desc":
                list_query = list_query.order_by(
                    models.Task.base_reward.desc(), models.Task.created_at.desc()
                )
            elif sort_by == "reward_low" or sort_by == "reward_asc":
                list_query = list_query.order_by(
                    models.Task.base_reward.asc(), models.Task.created_at.asc()
                )
            elif sort_by == "deadline_asc":
                list_query = list_query.order_by(
                    models.Task.deadline.asc().nulls_last(),
                    models.Task.created_at.desc(),
                )
            elif sort_by == "deadline_desc":
                list_query = list_query.order_by(
                    models.Task.deadline.desc().nulls_last(),
                    models.Task.created_at.desc(),
                )
            else:
                # 默认按最新
                list_query = list_query.order_by(
                    models.Task.created_at.desc(), models.Task.id.desc()
                )
            
            # 如果不是距离排序，才应用offset和limit（距离排序在Python中处理）
            if not use_distance_sorting:
                list_query = list_query.offset(skip).limit(limit)
            
            result = await db.execute(list_query)
            tasks = list(result.scalars().all())
            
            # 如果有用户位置，计算距离并按距离排序
            if user_latitude is not None and user_longitude is not None:
                from app.utils.location_utils import calculate_distance
                
                # 根据用户坐标判断大致城市（用于匹配没有坐标的任务）
                def get_user_city_from_coords(lat: float, lon: float) -> list:
                    """根据坐标判断用户可能所在的城市列表"""
                    # UK主要城市的坐标范围（粗略判断）
                    city_ranges = {
                        "London": (51.3, 51.7, -0.5, 0.3),
                        "Birmingham": (52.3, 52.6, -2.0, -1.7),
                        "Manchester": (53.3, 53.6, -2.4, -2.0),
                        "Edinburgh": (55.8, 56.0, -3.3, -3.0),
                        "Glasgow": (55.7, 55.9, -4.4, -4.1),
                        "Bristol": (51.4, 51.5, -2.7, -2.5),
                        "Sheffield": (53.3, 53.4, -1.6, -1.4),
                        "Leeds": (53.7, 53.9, -1.7, -1.4),
                        "Nottingham": (52.9, 53.0, -1.3, -1.1),
                        "Newcastle": (54.9, 55.0, -1.7, -1.5),
                        "Southampton": (50.8, 51.0, -1.5, -1.3),
                        "Liverpool": (53.3, 53.5, -3.0, -2.8),
                        "Cardiff": (51.4, 51.5, -3.3, -3.1),
                        "Coventry": (52.3, 52.5, -1.6, -1.4),
                        "Exeter": (50.7, 50.8, -3.6, -3.4),
                        "Leicester": (52.6, 52.7, -1.2, -1.0),
                        "York": (53.9, 54.0, -1.1, -0.9),
                        "Aberdeen": (57.1, 57.2, -2.2, -2.0),
                        "Bath": (51.3, 51.4, -2.4, -2.3),
                        "Dundee": (56.4, 56.5, -3.0, -2.9),
                        "Reading": (51.4, 51.5, -1.0, -0.9),
                        "St Andrews": (56.3, 56.4, -2.8, -2.7),
                        "Belfast": (54.5, 54.7, -6.0, -5.8),
                        "Brighton": (50.8, 50.9, -0.2, 0.0),
                        "Durham": (54.7, 54.8, -1.6, -1.5),
                        "Norwich": (52.6, 52.7, 1.2, 1.3),
                        "Swansea": (51.6, 51.7, -4.0, -3.9),
                        "Loughborough": (52.7, 52.8, -1.2, -1.1),
                        "Lancaster": (54.0, 54.1, -2.8, -2.7),
                        "Warwick": (52.2, 52.3, -1.6, -1.5),
                        "Cambridge": (52.2, 52.3, 0.0, 0.2),
                        "Oxford": (51.7, 51.8, -1.3, -1.2),
                    }
                    
                    matched_cities = []
                    for city, (min_lat, max_lat, min_lon, max_lon) in city_ranges.items():
                        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
                            matched_cities.append(city)
                    return matched_cities
                
                # 获取用户可能所在的城市列表
                user_cities = get_user_city_from_coords(user_latitude, user_longitude)
                
                # 计算每个任务的距离或城市匹配度
                tasks_with_distance = []
                for task in tasks:
                    if task.latitude is not None and task.longitude is not None:
                        # 有坐标：计算精确距离
                        distance = calculate_distance(
                            user_latitude, user_longitude,
                            float(task.latitude), float(task.longitude)
                        )
                        task._distance_km = distance
                        tasks_with_distance.append((distance, task, True))  # True表示有坐标
                    else:
                        # 没有坐标：根据位置字符串匹配城市
                        task._distance_km = None
                        location_lower = (task.location or "").lower()
                        
                        # 检查任务位置是否包含用户所在城市
                        city_match = False
                        for city in user_cities:
                            if city.lower() in location_lower:
                                city_match = True
                                break
                        
                        if city_match:
                            # 匹配用户城市，给予一个较大的距离值（排在有坐标任务之后）
                            tasks_with_distance.append((50000.0, task, False))  # False表示无坐标但匹配城市
                        else:
                            # 不匹配，给予更大的距离值（排在最后）
                            tasks_with_distance.append((999999.0, task, False))
                
                # 如果按距离排序，重新排序并限制距离范围
                if sort_by in ("distance", "nearby"):
                    # 排序：先按距离，然后按是否有坐标（有坐标优先）
                    tasks_with_distance.sort(key=lambda x: (x[0], not x[2]))
                    
                    # 如果已经按城市过滤（location参数不为空），只返回同城的任务
                    # 否则，按距离过滤
                    if location and location not in ["全部城市", "全部", "all"]:
                        # 已经按城市过滤，返回所有同城任务（有坐标的按距离排序，无坐标的排在后面）
                        # 只排除完全不匹配的任务（距离为999999.0）
                        nearby_tasks = [
                            (d, t) for d, t, has_coords in tasks_with_distance 
                            if d < 999999.0  # 排除完全不匹配的
                        ]
                    else:
                        # 没有按城市过滤，使用距离过滤
                        # 可选：限制距离范围（只返回50km内的任务，提升用户体验）
                        # 但如果50km内没有任务，返回最近的几个任务（最多100km）
                        max_distance_km = 50.0  # 首选最大距离50km
                        nearby_tasks = [
                            (d, t) for d, t, has_coords in tasks_with_distance 
                            if d <= max_distance_km
                        ]
                        
                        # 如果50km内没有任务，放宽到100km
                        if not nearby_tasks and tasks_with_distance:
                            max_distance_km = 100.0
                            nearby_tasks = [
                                (d, t) for d, t, has_coords in tasks_with_distance 
                                if d <= max_distance_km
                            ]
                        
                        # 如果100km内还是没有，返回最近的几个任务（包括匹配城市的无坐标任务）
                        if not nearby_tasks and tasks_with_distance:
                            # 优先返回有坐标的任务，然后是匹配城市的无坐标任务
                            nearby_tasks = [
                                (d, t) for d, t, has_coords in tasks_with_distance 
                                if d < 999999.0  # 排除完全不匹配的
                            ][:min(limit * 2, 20)]  # 最多返回20个
                    
                    # 更新 total 为实际可以返回的任务数量（距离过滤后）
                    total = len(nearby_tasks)
                    
                    # 应用分页：只返回请求的数量
                    start_idx = skip
                    end_idx = skip + limit
                    tasks = [task for _, task in nearby_tasks[start_idx:end_idx]]
                else:
                    # 不按距离排序，只计算距离值用于显示
                    tasks = [task for _, task, _ in tasks_with_distance]
            
            return tasks, total
        except RuntimeError as e:
            # 处理事件循环相关的错误（连接池关闭时的常见问题）
            error_str = str(e)
            # 检查是否是事件循环关闭的错误（应用正在关闭）
            if "Event loop is closed" in error_str or "loop is closed" in error_str:
                logger.debug(f"事件循环已关闭，跳过查询（应用正在关闭）: {e}")
                return [], 0
            # 检查是否是事件循环冲突的错误
            elif "different loop" in error_str or "attached to a different loop" in error_str:
                logger.warning(f"数据库连接池事件循环冲突（可忽略）: {e}")
                # 尝试重新执行查询
                try:
                    # 重新构建简单查询
                    simple_query = select(models.Task).where(
                        or_(
                            models.Task.status == "open",
                            models.Task.status == "taken"
                        )
                    ).order_by(models.Task.created_at.desc()).offset(skip).limit(limit)
                    result = await db.execute(simple_query)
                    tasks = list(result.scalars().all())
                    # 简单计数
                    count_result = await db.execute(select(func.count(models.Task.id)).where(
                        or_(
                            models.Task.status == "open",
                            models.Task.status == "taken"
                        )
                    ))
                    total = count_result.scalar() or 0
                    return tasks, total
                except Exception as retry_error:
                    # 检查重试时是否也是事件循环关闭错误
                    if "Event loop is closed" in str(retry_error) or "loop is closed" in str(retry_error):
                        logger.debug("事件循环已关闭，跳过重试查询")
                        return [], 0
                    logger.error(f"重试查询失败: {retry_error}")
                    return [], 0
            else:
                logger.error(f"Error getting tasks with total: {e}")
                return [], 0
        except Exception as e:
            # 检查是否是事件循环关闭的错误
            error_str = str(e)
            if "Event loop is closed" in error_str or "loop is closed" in error_str:
                logger.debug(f"事件循环已关闭，跳过查询（应用正在关闭）: {e}")
                return [], 0
            logger.error(f"Error getting tasks with total: {e}")
            return [], 0

    @staticmethod
    async def get_tasks_cursor(
        db: AsyncSession,
        cursor: Optional[str] = None,
        limit: int = 20,
        task_type: Optional[str] = None,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        sort_by: str = "latest",  # 只支持 latest / oldest
        expert_creator_id: Optional[str] = None,
        is_multi_participant: Optional[bool] = None,
        parent_activity_id: Optional[int] = None,
    ) -> tuple[List[models.Task], Optional[str]]:
        """
        使用游标分页获取任务列表。
        
        约束：
        - 只在 sort_by 为 "latest" / "oldest" 时使用
        - 游标格式: "<ISO8601时间>_<id>"，例如 "2025-01-27T12:00:00Z_123"
        """
        from app.utils.time_utils import parse_iso_utc, format_iso_utc
        from sqlalchemy import and_
        
        # 1. 仅对时间排序场景启用，其他排序请用 offset/limit
        if sort_by not in ("latest", "oldest"):
            raise ValueError("get_tasks_cursor 仅支持 sort_by=latest/oldest")
        
        # 获取当前UTC时间（用于过滤过期任务）
        from app.utils.time_utils import get_utc_time
        now_utc = get_utc_time()
        
        # 如果指定了 expert_creator_id，不过滤状态和截止日期（显示所有状态的活动）
        if expert_creator_id:
            query = (
                select(models.Task)
                .options(selectinload(models.Task.poster))
            )
        else:
            query = (
                select(models.Task)
                .options(selectinload(models.Task.poster))
                .where(
                    or_(
                        models.Task.status == "open",
                        models.Task.status == "taken"
                    )
                )
                .where(
                    or_(
                        models.Task.deadline > now_utc,  # 有截止日期且未过期
                        models.Task.deadline.is_(None)  # 灵活模式（无截止日期）
                    )
                )
            )
        
        # 筛选条件：和 /tasks 保持一致
        if task_type and task_type not in ["全部类型", "全部", "all"]:
            query = query.where(models.Task.task_type == task_type)
        
        if location and location not in ["全部城市", "全部", "all"]:
            if location.lower() == 'other':
                # "Other" 筛选：排除所有预定义城市和 Online（支持中英文地址）
                from sqlalchemy import not_
                from app.utils.city_filter_utils import build_other_exclusion_filter
                exclusion_expr = build_other_exclusion_filter(models.Task.location)
                if exclusion_expr is not None:
                    query = query.where(not_(exclusion_expr))
            elif location.lower() == 'online':
                query = query.where(models.Task.location.ilike("%online%"))
            else:
                from app.utils.city_filter_utils import build_city_location_filter
                city_expr = build_city_location_filter(models.Task.location, location)
                if city_expr is not None:
                    query = query.where(city_expr)
        
        if keyword:
            keyword = keyword.strip()
            from app.config import Config
            
            if Config.USE_PG_TRGM:
                query = query.where(
                    or_(
                        func.similarity(models.Task.title, keyword) > 0.2,
                        func.similarity(models.Task.description, keyword) > 0.2,
                    )
                )
            else:
                ts_vector = func.to_tsvector(
                    Config.SEARCH_LANGUAGE,
                    models.Task.title + " " + models.Task.description,
                )
                ts_query = func.plainto_tsquery(Config.SEARCH_LANGUAGE, keyword)
                query = query.where(ts_vector.op("@@")(ts_query))
        
        # 达人创建者筛选
        if expert_creator_id:
            query = query.where(models.Task.expert_creator_id == expert_creator_id)
        
        # 多人任务筛选
        if is_multi_participant is not None:
            query = query.where(models.Task.is_multi_participant == is_multi_participant)
        
        # 活动关联筛选
        if parent_activity_id is not None:
            query = query.where(models.Task.parent_activity_id == parent_activity_id)
        
        # 2. 应用游标条件（基于 created_at + id）
        if cursor:
            try:
                ts, id_str = cursor.split("_", 1)
                cursor_time = parse_iso_utc(ts.replace("Z", "+00:00"))
                cursor_id = int(id_str)
                
                if sort_by == "latest":
                    # 向后翻页：更旧的数据
                    query = query.where(
                        or_(
                            models.Task.created_at < cursor_time,
                            and_(
                                models.Task.created_at == cursor_time,
                                models.Task.id < cursor_id,
                            ),
                        )
                    )
                else:
                    # sort_by == "oldest"，向后翻页：更"新"的数据
                    query = query.where(
                        or_(
                            models.Task.created_at > cursor_time,
                            and_(
                                models.Task.created_at == cursor_time,
                                models.Task.id > cursor_id,
                            ),
                        )
                    )
            except Exception as e:
                logger.warning("Invalid cursor for tasks: %s, error: %s", cursor, e)
        
        # 3. 排序（必须与游标条件一致）
        if sort_by == "latest":
            query = query.order_by(
                models.Task.created_at.desc(), models.Task.id.desc()
            )
        else:  # oldest
            query = query.order_by(
                models.Task.created_at.asc(), models.Task.id.asc()
            )
        
        # 4. 查询 limit + 1 条，用于判断是否有更多
        result = await db.execute(query.limit(limit + 1))
        tasks = list(result.scalars().all())
        
        has_more = len(tasks) > limit
        if has_more:
            tasks = tasks[:limit]
        
        # 5. 生成下一页游标
        next_cursor = None
        if has_more and tasks:
            last = tasks[-1]
            next_cursor = f"{format_iso_utc(last.created_at)}_{last.id}"
        
        return tasks, next_cursor

    @staticmethod
    async def get_user_tasks(
        db: AsyncSession, 
        user_id: str, 
        task_type: str = "all",
        posted_skip: int = 0,
        posted_limit: int = 25,
        taken_skip: int = 0,
        taken_limit: int = 25,
        with_reviews: bool = False  # 列表接口默认不加载 reviews，减少数据量
    ) -> Dict[str, Any]:
        """获取用户的任务（发布的和接受的），支持筛选和分页（优化版本：使用selectinload避免N+1）"""
        try:
            # 构建发布任务查询
            posted_query = (
                select(models.Task)
                .options(
                    selectinload(models.Task.poster),
                    selectinload(models.Task.taker),
                    selectinload(models.Task.time_slot_relations).selectinload(models.TaskTimeSlotRelation.time_slot),
                    selectinload(models.Task.participants)  # 预加载参与者，用于动态计算current_participants
                )
                .where(models.Task.poster_id == user_id)
            )
            
            # 构建接受任务查询
            taken_query = (
                select(models.Task)
                .options(
                    selectinload(models.Task.poster),
                    selectinload(models.Task.taker),
                    selectinload(models.Task.time_slot_relations).selectinload(models.TaskTimeSlotRelation.time_slot),
                    selectinload(models.Task.participants)  # 预加载参与者，用于动态计算current_participants
                )
                .where(models.Task.taker_id == user_id)
            )
            
            # 构建多人任务参与者查询
            # 先查询参与者任务ID，然后过滤出多人任务（避免在join中使用布尔字段比较）
            participant_task_ids_query = select(models.TaskParticipant.task_id).where(
                models.TaskParticipant.user_id == user_id
            )
            participant_task_ids_result = await db.execute(participant_task_ids_query)
            participant_task_ids = [row[0] for row in participant_task_ids_result.all()]
            
            participant_query = None
            if participant_task_ids:
                participant_query = (
                    select(models.Task)
                    .options(
                        selectinload(models.Task.poster),
                        selectinload(models.Task.taker),
                        selectinload(models.Task.time_slot_relations).selectinload(models.TaskTimeSlotRelation.time_slot),
                        selectinload(models.Task.participants)  # 预加载参与者，用于动态计算current_participants
                    )
                    .where(
                        and_(
                            models.Task.id.in_(participant_task_ids),
                            models.Task.is_multi_participant.is_(True)  # 使用 is_() 而不是 ==
                        )
                    )
                )
            
            # 列表接口默认不加载 reviews（详情接口才需要）
            if with_reviews:
                posted_query = posted_query.options(selectinload(models.Task.reviews))
                taken_query = taken_query.options(selectinload(models.Task.reviews))
            
            # 应用任务类型筛选
            if task_type and task_type != "all":
                posted_query = posted_query.where(models.Task.task_type == task_type)
                taken_query = taken_query.where(models.Task.task_type == task_type)
            
            # 分别执行查询并应用分页
            posted_result = await db.execute(
                posted_query.order_by(models.Task.created_at.desc())
                           .offset(posted_skip)
                           .limit(posted_limit)
            )
            taken_result = await db.execute(
                taken_query.order_by(models.Task.created_at.desc())
                          .offset(taken_skip)
                          .limit(taken_limit)
            )
            
            # 只有当 participant_query 不为 None 时才执行查询
            participant_tasks = []
            if participant_query is not None:
                participant_result = await db.execute(
                    participant_query.order_by(models.Task.created_at.desc())
                )
                participant_tasks = list(participant_result.scalars().all())
            
            posted_tasks = list(posted_result.scalars().all())
            taken_tasks = list(taken_result.scalars().all())
            
            # 合并taken_tasks和participant_tasks，去重（按任务ID）
            taken_task_ids = {task.id for task in taken_tasks}
            for task in participant_tasks:
                if task.id not in taken_task_ids:
                    taken_tasks.append(task)
                    taken_task_ids.add(task.id)
            
            # 重新排序taken_tasks
            taken_tasks.sort(key=lambda t: t.created_at, reverse=True)
            # 应用分页
            taken_tasks = taken_tasks[taken_skip:taken_skip + taken_limit]
            
            # 获取总数（可选，如果前端需要）
            from sqlalchemy import func
            posted_count_query = select(func.count()).select_from(
                posted_query.subquery()
            )
            # taken总数需要包含participant任务，但要去重
            # 先获取所有taken和participant任务的ID集合
            all_taken_result = await db.execute(
                taken_query.order_by(models.Task.created_at.desc())
            )
            all_participant_result = await db.execute(
                participant_query.order_by(models.Task.created_at.desc())
            )
            all_taken_tasks = list(all_taken_result.scalars().all())
            all_participant_tasks = list(all_participant_result.scalars().all())
            taken_task_ids_set = {task.id for task in all_taken_tasks}
            for task in all_participant_tasks:
                taken_task_ids_set.add(task.id)
            taken_total = len(taken_task_ids_set)
            
            posted_total = (await db.execute(posted_count_query)).scalar() or 0
            
            return {
                "posted": posted_tasks,
                "taken": taken_tasks,
                "total_posted": posted_total,
                "total_taken": taken_total,
                "posted_has_more": len(posted_tasks) == posted_limit,
                "taken_has_more": len(taken_tasks) == taken_limit
            }
        except Exception as e:
            logger.error(f"Error getting user tasks for {user_id}: {e}")
            return {"posted": [], "taken": [], "total_posted": 0, "total_taken": 0, "posted_has_more": False, "taken_has_more": False}

    @staticmethod
    async def apply_for_task(
        db: AsyncSession, task_id: int, applicant_id: str, message: Optional[str] = None
    ) -> Optional[models.TaskApplication]:
        """申请任务"""
        try:
            # 首先检查任务是否存在
            task_query = select(models.Task).where(models.Task.id == task_id)
            existing_task = await db.execute(task_query)
            task = existing_task.scalar_one_or_none()
            
            if not task:
                logger.debug(f"任务 {task_id} 不存在")
                return None
            
            logger.debug(f"任务 {task_id} 当前状态: {task.status}")
            
            # 检查任务状态是否允许申请
            if task.status not in ["open", "taken"]:
                logger.debug(f"任务 {task_id} 状态 {task.status} 不允许申请")
                return None
            

            # 检查用户等级是否满足任务等级要求
            user_query = select(models.User).where(models.User.id == applicant_id)
            user_result = await db.execute(user_query)
            user = user_result.scalar_one_or_none()
            
            if not user:
                logger.debug(f"用户 {applicant_id} 不存在")
                return None
            
            # 所有用户均可申请任意等级任务（任务等级仅按赏金划分，不限制接单权限）
            
            # 检查是否已经申请过
            existing_application = await db.execute(
                select(models.TaskApplication)
                .where(
                    and_(
                        models.TaskApplication.task_id == task_id,
                        models.TaskApplication.applicant_id == applicant_id
                    )
                )
            )
            if existing_application.scalar_one_or_none():
                logger.debug(f"用户 {applicant_id} 已经申请过任务 {task_id}")
                return None
            
            # 创建申请记录
            application = models.TaskApplication(
                task_id=task_id,
                applicant_id=applicant_id,
                message=message,
                status="pending"
            )
            db.add(application)
            await db.commit()
            await db.refresh(application)
            logger.debug(f"成功创建申请记录，ID: {application.id}")
            
            # 注意：新流程中，申请后任务保持 open 状态
            # 只有发布者批准申请后，任务才变为 in_progress 状态
            # 不再在申请时将任务状态更新为 taken
            
            # 自动发送消息给任务发布者
            try:
                from app.models import Message
                from app.utils.time_utils import get_utc_time
                
                # 获取任务发布者 ID（确保是字符串）
                poster_id = str(getattr(task, 'poster_id', ''))
                logger.debug(f"发布者 ID: {poster_id}")
                
                # 创建自动消息
                auto_message = Message(
                    sender_id=applicant_id,
                    receiver_id=poster_id,
                    content=f"我申请了您的任务：{task.title}。{f'申请留言：{message}' if message else ''}"
                )
                db.add(auto_message)
                await db.commit()
                logger.debug(f"已添加申请消息到数据库")
            except Exception as e:
                logger.debug(f"添加自动消息失败（不影响申请流程）: {e}")
                logger.error(f"Failed to add auto message for task application: {e}")
            
            logger.debug(f"成功申请任务 {task_id}，申请者: {applicant_id}")
            
            return application
            
        except Exception as e:
            logger.error(f"申请任务时发生错误: {e}")
            await db.rollback()
            logger.error(f"Error applying for task {task_id}: {e}")
            return None

    @staticmethod
    async def get_task_applications(
        db: AsyncSession, task_id: int
    ) -> List[models.TaskApplication]:
        """获取任务的申请者列表"""
        try:
            result = await db.execute(
                select(models.TaskApplication)
                .where(models.TaskApplication.task_id == task_id)
                .where(models.TaskApplication.status == "pending")
                .order_by(models.TaskApplication.created_at.desc())
            )
            return list(result.scalars().all())
        except Exception as e:
            logger.error(f"Error getting task applications for {task_id}: {e}")
            return []

    @staticmethod
    async def approve_application(
        db: AsyncSession, task_id: int, applicant_id: str
    ) -> Optional[models.Task]:
        """批准申请者"""
        try:
            # 获取申请记录
            application = await db.execute(
                select(models.TaskApplication)
                .where(
                    and_(
                        models.TaskApplication.task_id == task_id,
                        models.TaskApplication.applicant_id == applicant_id,
                        models.TaskApplication.status == "pending"
                    )
                )
            )
            application = application.scalar_one_or_none()
            
            if not application:
                logger.debug(f"申请记录不存在: task_id={task_id}, applicant_id={applicant_id}")
                return None
            
            # ⚠️ 安全修复：检查任务支付状态
            # 获取任务以检查支付状态
            task_result = await db.execute(
                select(models.Task).where(models.Task.id == task_id)
            )
            task = task_result.scalar_one_or_none()
            
            if not task:
                logger.debug(f"任务不存在: task_id={task_id}")
                return None
            
            # ⚠️ 安全修复：只有已支付的任务才能批准申请
            if not task.is_paid:
                logger.debug(f"任务 {task_id} 尚未支付，无法批准申请")
                # 注意：此方法可能已废弃，新的流程使用 accept_application
                # 但为了安全，仍然添加支付检查
                return None
            
            # 更新申请状态为已批准
            setattr(application, 'status', "approved")
            
            # 更新任务状态和接收者（只有已支付的任务才能进入 in_progress）
            result = await db.execute(
                update(models.Task)
                .where(models.Task.id == task_id)
                .values(
                    taker_id=applicant_id,
                    status="in_progress",
                    accepted_at=get_utc_time()
                )
                .returning(models.Task)
            )
            task = result.scalar_one_or_none()
            
            if task:
                # 拒绝其他申请
                await db.execute(
                    update(models.TaskApplication)
                    .where(
                        and_(
                            models.TaskApplication.task_id == task_id,
                            models.TaskApplication.applicant_id != applicant_id,
                            models.TaskApplication.status == "pending"
                        )
                    )
                    .values(status="rejected")
                )
                
                await db.commit()
                await db.refresh(task)
                logger.debug(f"成功批准申请: task_id={task_id}, applicant_id={applicant_id}")
                return task
            else:
                logger.debug(f"更新任务失败: task_id={task_id}")
                return None
                
        except Exception as e:
            logger.error(f"批准申请时发生错误: {e}")
            await db.rollback()
            logger.error(f"Error approving application: {e}")
            return None

    @staticmethod
    async def get_system_settings_dict(db: AsyncSession) -> Dict[str, Any]:
        """异步获取系统设置字典"""
        try:
            result = await db.execute(select(models.SystemSettings))
            settings = result.scalars().all()
            
            settings_dict = {}
            for setting in settings:
                # 获取字段值，确保是字符串类型
                setting_type = str(getattr(setting, 'setting_type', 'string'))  # type: ignore
                setting_value = str(getattr(setting, 'setting_value', ''))  # type: ignore
                setting_key = str(getattr(setting, 'setting_key', ''))  # type: ignore
                
                if setting_type == "boolean":
                    settings_dict[setting_key] = setting_value.lower() == "true"
                elif setting_type == "number":
                    try:
                        # 尝试解析为浮点数，如果是整数则返回整数
                        float_val = float(setting_value)  # type: ignore
                        if float_val.is_integer():
                            settings_dict[setting_key] = int(float_val)
                        else:
                            settings_dict[setting_key] = float_val
                    except ValueError:
                        settings_dict[setting_key] = 0
                else:
                    settings_dict[setting_key] = setting_value
            return settings_dict
        except Exception as e:
            logger.error(f"Error getting system settings: {e}")
            # 返回默认设置
            return {
                "vip_enabled": True,
                "super_vip_enabled": True,
                "vip_price_threshold": 10.0,
                "super_vip_price_threshold": 50.0,
                "vip_task_threshold": 5,
                "super_vip_task_threshold": 20,
            }


# 异步消息操作
class AsyncMessageCRUD:
    """异步消息CRUD操作"""

    @staticmethod
    async def create_message(
        db: AsyncSession, sender_id: str, receiver_id: str, content: str
    ) -> models.Message:
        """创建消息"""
        try:
            db_message = models.Message(
                sender_id=sender_id, receiver_id=receiver_id, content=content
            )
            db.add(db_message)
            await db.commit()
            await db.refresh(db_message)
            return db_message
        except Exception as e:
            await db.rollback()
            logger.error(f"Error creating message: {e}")
            raise

    @staticmethod
    async def get_messages(
        db: AsyncSession, user_id: str, skip: int = 0, limit: int = 50
    ) -> List[models.Message]:
        """获取用户的消息"""
        try:
            result = await db.execute(
                select(models.Message)
                .where(
                    or_(
                        models.Message.sender_id == user_id,
                        models.Message.receiver_id == user_id,
                    )
                )
                .order_by(models.Message.created_at.desc())
                .offset(skip)
                .limit(limit)
            )
            return list(result.scalars().all())
        except Exception as e:
            logger.error(f"Error getting messages for user {user_id}: {e}")
            return []

    @staticmethod
    async def get_conversation_messages(
        db: AsyncSession, user1_id: str, user2_id: str, skip: int = 0, limit: int = 50
    ) -> List[models.Message]:
        """
        获取两个用户之间的对话消息（优化版本：使用conversation_key）
        
        注意：如果conversation_key字段不存在，会回退到原来的查询方式
        """
        try:
            # 构建 conversation_key（与数据库触发器逻辑保持一致）
            # 使用 LEAST/GREATEST 确保无论 sender/receiver 如何交换，key 都一致
            ids = [str(user1_id), str(user2_id)]
            conversation_key = f"{min(ids)}-{max(ids)}"
            
            # 尝试使用 conversation_key 查询（高效走索引）
            # 如果字段不存在，会抛出异常，我们捕获后使用旧方式
            try:
                result = await db.execute(
                    select(models.Message)
                    .where(models.Message.conversation_key == conversation_key)
                    .order_by(models.Message.created_at.asc())
                    .offset(skip)
                    .limit(limit)
                )
                return list(result.scalars().all())
            except Exception:
                # conversation_key 字段可能不存在，回退到原来的查询方式
                logger.warning("conversation_key字段不存在，使用旧查询方式")
                result = await db.execute(
                    select(models.Message)
                    .where(
                        or_(
                            and_(
                                models.Message.sender_id == user1_id,
                                models.Message.receiver_id == user2_id,
                            ),
                            and_(
                                models.Message.sender_id == user2_id,
                                models.Message.receiver_id == user1_id,
                            ),
                        )
                    )
                    .order_by(models.Message.created_at.asc())
                    .offset(skip)
                    .limit(limit)
                )
                return list(result.scalars().all())
        except Exception as e:
            logger.error(f"Error getting conversation messages: {e}")
            return []


# 异步通知操作
class AsyncNotificationCRUD:
    """异步通知CRUD操作"""

    @staticmethod
    async def create_notification(
        db: AsyncSession,
        user_id: str,
        notification_type: str,
        title: str,
        content: str,
        related_id: Optional[str] = None,
    ) -> models.Notification:
        """创建通知（如果已存在则更新）"""
        from sqlalchemy.exc import IntegrityError
        from app.utils.time_utils import get_utc_time
        
        try:
            # ⚠️ 将related_id从字符串转换为整数（数据库字段是Integer类型）
            related_id_int = None
            if related_id is not None:
                try:
                    related_id_int = int(related_id)
                except (ValueError, TypeError):
                    logger.warning(f"Invalid related_id format: {related_id}, setting to None")
                    related_id_int = None
            
            db_notification = models.Notification(
                user_id=user_id,
                type=notification_type,
                title=title,
                content=content,
                related_id=related_id_int,
            )
            db.add(db_notification)
            await db.commit()
            await db.refresh(db_notification)
            return db_notification
        except IntegrityError:
            # 如果违反唯一约束（uix_user_type_related），更新现有通知
            await db.rollback()
            
            # 查询现有通知
            existing_result = await db.execute(
                select(models.Notification)
                .where(models.Notification.user_id == user_id)
                .where(models.Notification.type == notification_type)
                .where(models.Notification.related_id == (int(related_id) if related_id else None))
            )
            existing_notification = existing_result.scalar_one_or_none()
            
            if existing_notification:
                # 更新现有通知的内容和时间
                existing_notification.content = content
                existing_notification.title = title
                existing_notification.created_at = get_utc_time()
                existing_notification.is_read = 0  # 重置为未读
                existing_notification.read_at = None  # 清除已读时间
                await db.commit()
                await db.refresh(existing_notification)
                return existing_notification
            else:
                # 如果找不到现有通知，重新抛出异常
                logger.error(f"IntegrityError but existing notification not found: user_id={user_id}, type={notification_type}, related_id={related_id}")
                raise
        except Exception as e:
            await db.rollback()
            logger.error(f"Error creating notification: {e}")
            raise

    @staticmethod
    async def get_user_notifications(
        db: AsyncSession,
        user_id: str,
        skip: int = 0,
        limit: int = 20,
        unread_only: bool = False,
    ) -> List[models.Notification]:
        """获取用户通知"""
        try:
            query = select(models.Notification).where(
                models.Notification.user_id == user_id
            )

            if unread_only:
                query = query.where(models.Notification.is_read == 0)

            result = await db.execute(
                query.order_by(models.Notification.created_at.desc())
                .offset(skip)
                .limit(limit)
            )
            return list(result.scalars().all())
        except Exception as e:
            logger.error(f"Error getting notifications for user {user_id}: {e}")
            return []

    @staticmethod
    async def mark_notification_as_read(
        db: AsyncSession, notification_id: int
    ) -> Optional[models.Notification]:
        """标记通知为已读"""
        try:
            result = await db.execute(
                update(models.Notification)
                .where(models.Notification.id == notification_id)
                .values(is_read=1, read_at=get_utc_time())
                .returning(models.Notification)
            )
            notification = result.scalar_one_or_none()
            if notification:
                await db.commit()
                await db.refresh(notification)
            return notification
        except Exception as e:
            await db.rollback()
            logger.error(f"Error marking notification as read: {e}")
            return None


# 批量操作工具
class AsyncBatchOperations:
    """异步批量操作工具"""

    @staticmethod
    async def batch_create_notifications(
        db: AsyncSession, notifications: List[Dict[str, Any]], batch_size: int = 100
    ) -> List[models.Notification]:
        """
        批量创建通知（优化版：分批处理避免单次事务过大）
        
        Args:
            db: 异步数据库会话
            notifications: 通知数据列表
            batch_size: 每批处理的数量（默认100）
        
        Returns:
            创建的通知列表
        """
        if not notifications:
            return []
        
        all_notifications = []
        
        try:
            # 分批处理，避免单次事务过大
            for i in range(0, len(notifications), batch_size):
                batch = notifications[i:i + batch_size]
                db_notifications = [
                    models.Notification(**notification) for notification in batch
                ]
                db.add_all(db_notifications)
                await db.flush()  # 刷新以获取ID，但不提交
                all_notifications.extend(db_notifications)
            
            # 一次性提交所有批次
            await db.commit()
            
            # 刷新所有通知以获取完整数据
            for notification in all_notifications:
                await db.refresh(notification)
            
            return all_notifications
        except Exception as e:
            await db.rollback()
            logger.error(f"批量创建通知失败: {e}", exc_info=True)
            raise

    @staticmethod
    async def batch_update_tasks(
        db: AsyncSession, task_updates: List[Dict[str, Any]], batch_size: int = 50
    ) -> int:
        """
        批量更新任务（优化版：分批处理避免单次事务过大）
        
        Args:
            db: 异步数据库会话
            task_updates: 更新数据列表，每个字典包含 'id' 和要更新的字段
            batch_size: 每批处理的数量（默认50）
        
        Returns:
            更新的记录数
        """
        if not task_updates:
            return 0
        
        from sqlalchemy import update
        
        try:
            updated_count = 0
            
            # 分批处理，避免单次事务过大
            for i in range(0, len(task_updates), batch_size):
                batch = task_updates[i:i + batch_size]
                
                # 按任务ID分组，相同ID的更新合并
                updates_by_id = {}
                for update_data in batch:
                    task_id = update_data.pop("id")
                    if task_id in updates_by_id:
                        updates_by_id[task_id].update(update_data)
                    else:
                        updates_by_id[task_id] = update_data
                
                # 执行批量更新
                for task_id, update_data in updates_by_id.items():
                    result = await db.execute(
                        update(models.Task)
                        .where(models.Task.id == task_id)
                        .values(**update_data)
                    )
                    updated_count += result.rowcount
                
                # 每批刷新一次，但不提交
                await db.flush()
            
            # 一次性提交所有批次
            await db.commit()
            return updated_count
        except Exception as e:
            await db.rollback()
            logger.error(f"批量更新任务失败: {e}", exc_info=True)
            raise


# 性能监控工具
class AsyncPerformanceMonitor:
    """异步性能监控工具"""

    @staticmethod
    async def get_database_stats(db: AsyncSession) -> Dict[str, Any]:
        """获取数据库统计信息"""
        try:
            # 用户统计
            user_count_result = await db.execute(select(func.count(models.User.id)))
            user_count = user_count_result.scalar()

            # 任务统计
            task_count_result = await db.execute(select(func.count(models.Task.id)))
            task_count = task_count_result.scalar()

            # 消息统计
            message_count_result = await db.execute(
                select(func.count(models.Message.id))
            )
            message_count = message_count_result.scalar()

            return {
                "users": user_count,
                "tasks": task_count,
                "messages": message_count,
                "timestamp": format_iso_utc(get_utc_time()),
            }
        except Exception as e:
            logger.error(f"Error getting database stats: {e}")
            return {}


# 创建CRUD实例
async_user_crud = AsyncUserCRUD()
async_task_crud = AsyncTaskCRUD()
async_message_crud = AsyncMessageCRUD()
async_notification_crud = AsyncNotificationCRUD()
async_batch_ops = AsyncBatchOperations()
async_performance_monitor = AsyncPerformanceMonitor()

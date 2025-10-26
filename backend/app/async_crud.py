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
        except Exception as e:
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
            if hasattr(user, 'terms_agreed_at') and user.terms_agreed_at:
                terms_agreed_at = datetime.fromisoformat(user.terms_agreed_at.replace('Z', '+00:00'))
            
            db_user = models.User(
                id=user_id,
                name=user.name,
                email=user.email,
                hashed_password=hashed_password,
                phone=user.phone,
                avatar=user.avatar or "",
                user_level="normal",
                timezone="Europe/London",
                agreed_to_terms=1 if getattr(user, "agreed_to_terms", False) else 0,
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
            
            # 任务等级分配逻辑
            user_level = str(user.user_level) if user.user_level is not None else "normal"
            if user_level == "super":
                task_level = "vip"
            elif task.reward >= super_vip_price_threshold:
                task_level = "super"
            elif task.reward >= vip_price_threshold:
                task_level = "vip"
            else:
                task_level = "normal"
            
            # 确保deadline是timezone-naive的datetime（数据库期望的是TIMESTAMP WITHOUT TIME ZONE）
            from datetime import timezone
            if task.deadline.tzinfo is not None:
                # 如果deadline有时区信息，转换为UTC然后移除时区信息
                deadline = task.deadline.astimezone(timezone.utc).replace(tzinfo=None)
            else:
                deadline = task.deadline
            
            db_task = models.Task(
                title=task.title,
                description=task.description,
                task_type=task.task_type,
                location=task.location,
                reward=task.reward,
                deadline=deadline,
                poster_id=poster_id,
                status="open",
                task_level=task_level,
                is_public=getattr(task, "is_public", 1),  # 默认为公开
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
                query = query.where(models.Task.location == location)
            if status and status not in ['全部状态', '全部', 'all']:
                query = query.where(models.Task.status == status)
            
            # 添加关键词搜索
            if keyword:
                keyword = keyword.strip()
                query = query.where(
                    or_(
                        models.Task.title.ilike(f"%{keyword}%"),
                        models.Task.description.ilike(f"%{keyword}%"),
                        models.Task.task_type.ilike(f"%{keyword}%"),
                        models.Task.location.ilike(f"%{keyword}%"),
                    )
                )

            # 排序
            if sort_by == "latest":
                query = query.order_by(models.Task.created_at.desc())
            elif sort_by == "oldest":
                query = query.order_by(models.Task.created_at.asc())
            elif sort_by == "reward_high" or sort_by == "reward_desc":
                query = query.order_by(models.Task.reward.desc())
            elif sort_by == "reward_low" or sort_by == "reward_asc":
                query = query.order_by(models.Task.reward.asc())
            elif sort_by == "deadline_asc":
                query = query.order_by(models.Task.deadline.asc())
            elif sort_by == "deadline_desc":
                query = query.order_by(models.Task.deadline.desc())
            else:
                query = query.order_by(models.Task.created_at.desc())

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
    ) -> tuple[List[models.Task], int]:
        """获取任务列表和总数（带过滤条件）"""
        try:
            from sqlalchemy import or_, func
            from datetime import datetime
            import pytz
            
            # 获取当前英国时间并转换为UTC时间进行比较
            uk_tz = pytz.timezone('Europe/London')
            now_local = datetime.now(uk_tz)
            now_utc = now_local.astimezone(pytz.UTC).replace(tzinfo=None)  # 转换为UTC naive datetime
            
            # 构建基础查询 - 显示开放和已接收但未同意的任务，且未过期
            base_query = select(models.Task).where(
                or_(
                    models.Task.status == "open",
                    models.Task.status == "taken"
                )
            ).where(
                models.Task.deadline > now_utc  # 使用UTC时间进行比较
            )

            if task_type and task_type not in ['全部类型', '全部']:
                base_query = base_query.where(models.Task.task_type == task_type)
            if location and location not in ['全部城市', '全部']:
                base_query = base_query.where(models.Task.location == location)
            if status and status not in ['全部状态', '全部']:
                base_query = base_query.where(models.Task.status == status)
            
            # 添加关键词搜索
            if keyword:
                keyword = keyword.strip()
                base_query = base_query.where(
                    or_(
                        models.Task.title.ilike(f"%{keyword}%"),
                        models.Task.description.ilike(f"%{keyword}%"),
                        models.Task.task_type.ilike(f"%{keyword}%"),
                        models.Task.location.ilike(f"%{keyword}%"),
                    )
                )

            # 获取总数
            count_query = select(func.count()).select_from(base_query.subquery())
            total_result = await db.execute(count_query)
            total = total_result.scalar()

            # 获取任务列表
            query = (
                base_query
                .options(selectinload(models.Task.poster))
            )

            # 排序
            if sort_by == "latest":
                query = query.order_by(models.Task.created_at.desc())
            elif sort_by == "oldest":
                query = query.order_by(models.Task.created_at.asc())
            elif sort_by == "reward_high" or sort_by == "reward_desc":
                query = query.order_by(models.Task.reward.desc())
            elif sort_by == "reward_low" or sort_by == "reward_asc":
                query = query.order_by(models.Task.reward.asc())
            elif sort_by == "deadline_asc":
                query = query.order_by(models.Task.deadline.asc())
            elif sort_by == "deadline_desc":
                query = query.order_by(models.Task.deadline.desc())
            else:
                query = query.order_by(models.Task.created_at.desc())

            result = await db.execute(
                query.offset(skip).limit(limit)
            )
            tasks = list(result.scalars().all())
            
            return tasks, total or 0
        except Exception as e:
            logger.error(f"Error getting tasks with total: {e}")
            return [], 0

    @staticmethod
    async def get_user_tasks(
        db: AsyncSession, user_id: str, task_type: str = "all"
    ) -> Dict[str, List[models.Task]]:
        """获取用户的任务（发布的和接受的）"""
        try:
            # 发布的任务
            posted_result = await db.execute(
                select(models.Task)
                .where(models.Task.poster_id == user_id)
                .order_by(models.Task.created_at.desc())
            )
            posted_tasks = posted_result.scalars().all()

            # 接受的任务
            taken_result = await db.execute(
                select(models.Task)
                .where(models.Task.taker_id == user_id)
                .order_by(models.Task.created_at.desc())
            )
            taken_tasks = list(taken_result.scalars().all())

            return {"posted": list(posted_tasks), "taken": taken_tasks}
        except Exception as e:
            logger.error(f"Error getting user tasks for {user_id}: {e}")
            return {"posted": [], "taken": []}

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
                print(f"DEBUG: 任务 {task_id} 不存在")
                return None
            
            print(f"DEBUG: 任务 {task_id} 当前状态: {task.status}")
            
            # 检查任务状态是否允许申请
            if task.status not in ["open", "taken"]:
                print(f"DEBUG: 任务 {task_id} 状态 {task.status} 不允许申请")
                return None
            

            # 检查用户等级是否满足任务等级要求
            user_query = select(models.User).where(models.User.id == applicant_id)
            user_result = await db.execute(user_query)
            user = user_result.scalar_one_or_none()
            
            if not user:
                print(f"DEBUG: 用户 {applicant_id} 不存在")
                return None
            
            # 等级匹配检查
            level_hierarchy = {'normal': 1, 'vip': 2, 'super': 3}
            # 从 SQLAlchemy 对象中获取实际值
            user_level_actual = getattr(user, 'user_level', None)
            task_level_actual = getattr(task, 'task_level', None)
            
            user_level_str = str(user_level_actual) if user_level_actual is not None else "normal"
            task_level_str = str(task_level_actual) if task_level_actual is not None else "normal"
            user_level_value = level_hierarchy.get(user_level_str, 1)
            task_level_value = level_hierarchy.get(task_level_str, 1)
            
            if user_level_value < task_level_value:
                print(f"DEBUG: 用户等级 {user.user_level} 不足以申请 {task.task_level} 任务")
                return None
            
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
                print(f"DEBUG: 用户 {applicant_id} 已经申请过任务 {task_id}")
                return None
            
            # 创建申请记录
            application = models.TaskApplication(
                task_id=task_id,
                applicant_id=applicant_id,
                message=message,
                status="pending"
            )
            db.add(application)
            
            # 更新任务状态为taken（如果有申请者）
            await db.execute(
                update(models.Task)
                .where(models.Task.id == task_id)
                .values(status="taken")
            )
            
            # 自动发送消息给任务发布者
            try:
                from app.models import Message
                
                # 创建自动消息
                auto_message = Message(
                    sender_id=applicant_id,
                    receiver_id=str(task.poster_id),
                    content=f"我申请了您的任务：{task.title}。{f'申请留言：{message}' if message else ''}"
                )
                db.add(auto_message)
                print(f"DEBUG: 已添加申请消息到数据库")
            except Exception as e:
                print(f"DEBUG: 添加自动消息失败: {e}")
                # 不影响申请流程，只记录错误
                logger.error(f"Failed to add auto message for task application: {e}")
            
            await db.commit()
            await db.refresh(application)
            print(f"DEBUG: 成功申请任务 {task_id}，申请者: {applicant_id}")
            
            return application
            
        except Exception as e:
            print(f"DEBUG: 申请任务时发生错误: {e}")
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
                print(f"DEBUG: 申请记录不存在: task_id={task_id}, applicant_id={applicant_id}")
                return None
            
            # 更新申请状态为已批准
            setattr(application, 'status', "approved")
            
            # 更新任务状态和接收者
            result = await db.execute(
                update(models.Task)
                .where(models.Task.id == task_id)
                .values(
                    taker_id=applicant_id,
                    status="in_progress",
                    accepted_at=datetime.utcnow()
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
                print(f"DEBUG: 成功批准申请: task_id={task_id}, applicant_id={applicant_id}")
                return task
            else:
                print(f"DEBUG: 更新任务失败: task_id={task_id}")
                return None
                
        except Exception as e:
            print(f"DEBUG: 批准申请时发生错误: {e}")
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
        """获取两个用户之间的对话消息"""
        try:
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
        """创建通知"""
        try:
            db_notification = models.Notification(
                user_id=user_id,
                type=notification_type,
                title=title,
                content=content,
                related_id=related_id,
            )
            db.add(db_notification)
            await db.commit()
            await db.refresh(db_notification)
            return db_notification
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
                .values(is_read=1, read_at=datetime.utcnow())
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
        db: AsyncSession, notifications: List[Dict[str, Any]]
    ) -> List[models.Notification]:
        """批量创建通知"""
        try:
            db_notifications = [
                models.Notification(**notification) for notification in notifications
            ]
            db.add_all(db_notifications)
            await db.commit()

            for notification in db_notifications:
                await db.refresh(notification)

            return db_notifications
        except Exception as e:
            await db.rollback()
            logger.error(f"Error batch creating notifications: {e}")
            raise

    @staticmethod
    async def batch_update_tasks(
        db: AsyncSession, task_updates: List[Dict[str, Any]]
    ) -> int:
        """批量更新任务"""
        try:
            updated_count = 0
            for update_data in task_updates:
                task_id = update_data.pop("id")
                result = await db.execute(
                    update(models.Task)
                    .where(models.Task.id == task_id)
                    .values(**update_data)
                )
                updated_count += result.rowcount

            await db.commit()
            return updated_count
        except Exception as e:
            await db.rollback()
            logger.error(f"Error batch updating tasks: {e}")
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
                "timestamp": datetime.utcnow().isoformat(),
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

"""
任务聊天业务逻辑模块
实现任务聊天相关的核心业务逻辑
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple
from decimal import Decimal

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models

logger = logging.getLogger(__name__)


class TaskStatusLogic:
    """任务状态判断逻辑"""
    
    @staticmethod
    def get_task_status(task: models.Task) -> str:
        """
        获取任务状态
        基于 taker_id 和 status 字段判断，TaskApplication 仅作为候选参考
        """
        # 如果任务有接受者，状态应该是 in_progress 或 completed
        if task.taker_id:
            if task.status == "completed":
                return "completed"
            elif task.status == "in_progress":
                return "in_progress"
            elif task.status == "pending_confirmation":
                return "pending_confirmation"
            else:
                # 有接受者但状态异常，返回 in_progress 作为默认值
                return "in_progress"
        
        # 如果没有接受者，状态应该是 open
        if task.status == "open":
            return "open"
        
        # 其他状态（如 cancelled）直接返回
        return task.status or "open"
    
    @staticmethod
    def is_task_available_for_application(task: models.Task) -> bool:
        """
        判断任务是否可以申请
        条件：status = "open" 且 taker_id 为空
        """
        return task.status == "open" and task.taker_id is None
    
    @staticmethod
    def is_task_in_progress(task: models.Task) -> bool:
        """
        判断任务是否进行中
        条件：taker_id 不为空 且 status = "in_progress"
        """
        return task.taker_id is not None and task.status == "in_progress"


class ApplicationStorageStrategy:
    """
    申请信息存储策略
    以 TaskApplication 为唯一真相源，不在 Message 表存储
    """
    
    @staticmethod
    async def get_applications_for_task(
        db: AsyncSession,
        task_id: int,
        user_id: str,
        is_poster: bool
    ) -> list[models.TaskApplication]:
        """
        获取任务的申请列表
        发布者可以看到所有申请，申请者只能看到自己的申请
        """
        query = select(models.TaskApplication).where(
            models.TaskApplication.task_id == task_id
        )
        
        # 如果不是发布者，只能看到自己的申请
        if not is_poster:
            query = query.where(
                models.TaskApplication.applicant_id == user_id
            )
        
        query = query.order_by(models.TaskApplication.created_at.desc())
        
        result = await db.execute(query)
        return result.scalars().all()
    
    @staticmethod
    async def has_user_applied(
        db: AsyncSession,
        task_id: int,
        user_id: str
    ) -> bool:
        """检查用户是否已申请过此任务（无论状态）"""
        query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == user_id
            )
        )
        result = await db.execute(query)
        return result.scalar_one_or_none() is not None


class AcceptApplicationLogic:
    """接受申请的业务逻辑"""
    
    @staticmethod
    async def accept_application_with_lock(
        db: AsyncSession,
        task_id: int,
        application_id: int,
        current_user_id: str
    ) -> Tuple[bool, Optional[str]]:
        """
        接受申请（带并发控制）
        返回：(success, error_message)
        """
        try:
            # 使用 SELECT FOR UPDATE 锁定任务行
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            
            locked_task_result = await db.execute(locked_task_query)
            locked_task = locked_task_result.scalar_one_or_none()
            
            if not locked_task:
                return False, "任务不存在"
            
            # 权限检查：必须是发布者
            if locked_task.poster_id != current_user_id:
                return False, "只有发布者可以接受申请"
            
            # 检查申请是否存在
            application_query = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.id == application_id,
                    models.TaskApplication.task_id == task_id
                )
            )
            application_result = await db.execute(application_query)
            application = application_result.scalar_one_or_none()
            
            if not application:
                return False, "申请不存在"
            
            # 幂等性检查：如果申请已经是 approved，直接返回成功
            if application.status == "approved":
                return True, None
            
            # 检查任务是否还有名额
            if locked_task.taker_id is not None:
                return False, "任务已被接受"
            
            # 获取当前时间
            from app.models import get_uk_time_naive
            current_time = get_uk_time_naive()
            
            # 更新任务
            locked_task.taker_id = application.applicant_id
            locked_task.status = "in_progress"
            
            # 如果申请包含议价，更新 agreed_reward（不覆盖 base_reward）
            if application.negotiated_price is not None:
                locked_task.agreed_reward = application.negotiated_price
            
            # 更新申请状态
            application.status = "approved"
            
            # 自动拒绝所有其他待处理的申请
            await AcceptApplicationLogic._reject_other_applications(
                db, task_id, application_id
            )
            
            # 写入操作日志
            log_entry = models.NegotiationResponseLog(
                task_id=task_id,
                application_id=application_id,
                user_id=current_user_id,
                action="accept",
                negotiated_price=application.negotiated_price,
                responded_at=current_time
            )
            db.add(log_entry)
            
            await db.commit()
            return True, None
            
        except Exception as e:
            await db.rollback()
            logger.error(f"接受申请失败: {e}")
            return False, f"接受申请失败: {str(e)}"
    
    @staticmethod
    async def _reject_other_applications(
        db: AsyncSession,
        task_id: int,
        accepted_application_id: int
    ):
        """自动拒绝所有其他待处理的申请"""
        other_applications_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.id != accepted_application_id,
                models.TaskApplication.status == "pending"
            )
        )
        other_apps_result = await db.execute(other_applications_query)
        other_applications = other_apps_result.scalars().all()
        
        for other_app in other_applications:
            other_app.status = "rejected"


class NegotiationPriceLogic:
    """议价价格处理逻辑"""
    
    @staticmethod
    def update_agreed_reward(
        task: models.Task,
        negotiated_price: Optional[Decimal]
    ):
        """
        更新任务的 agreed_reward
        不覆盖 base_reward，保持原始标价
        """
        if negotiated_price is not None:
            task.agreed_reward = negotiated_price
            # 注意：不更新 reward 字段，保持历史兼容性
    
    @staticmethod
    def get_display_reward(task: models.Task) -> Optional[float]:
        """
        获取显示价格
        规则：agreed_reward ?? base_reward
        """
        if task.agreed_reward is not None:
            return float(task.agreed_reward)
        elif task.base_reward is not None:
            return float(task.base_reward)
        else:
            return None


class MessagePermissionLogic:
    """消息发送权限控制逻辑"""
    
    @staticmethod
    def can_send_message(
        task: models.Task,
        user_id: str,
        is_prenote: bool = False
    ) -> Tuple[bool, Optional[str]]:
        """
        判断用户是否可以发送消息
        返回：(can_send, error_message)
        """
        is_poster = task.poster_id == user_id
        is_taker = task.taker_id == user_id
        
        # 必须是任务的参与者
        if not is_poster and not is_taker:
            return False, "无权限发送消息"
        
        # 如果任务进行中，可以发送普通消息
        if TaskStatusLogic.is_task_in_progress(task):
            return True, None
        
        # 如果任务未开始且是说明类消息
        if is_prenote and task.status == "open" and is_poster:
            return True, None
        
        # 如果任务未开始且用户是申请者，不能发送消息
        if task.status == "open" and not is_poster:
            return False, "任务未开始时，只有发布者可以发送说明类消息"
        
        return False, "当前任务状态不允许发送消息"


class MessageReadLogic:
    """消息已读状态管理逻辑"""
    
    @staticmethod
    async def mark_messages_read(
        db: AsyncSession,
        task_id: int,
        user_id: str,
        upto_message_id: Optional[int] = None,
        message_ids: Optional[list[int]] = None
    ) -> int:
        """
        标记消息为已读
        返回标记的消息数量
        """
        from app.models import get_uk_time_naive
        current_time = get_uk_time_naive()
        
        marked_count = 0
        
        if upto_message_id:
            # 方式1：标记到指定消息ID为止的所有消息
            upto_msg_query = select(models.Message).where(
                and_(
                    models.Message.id == upto_message_id,
                    models.Message.task_id == task_id
                )
            )
            upto_msg_result = await db.execute(upto_msg_query)
            upto_message = upto_msg_result.scalar_one_or_none()
            
            if upto_message:
                # 查询需要标记的消息（排除自己发送的消息）
                messages_to_mark_query = select(models.Message).where(
                    and_(
                        models.Message.task_id == task_id,
                        models.Message.sender_id != user_id,
                        or_(
                            models.Message.created_at < upto_message.created_at,
                            and_(
                                models.Message.created_at == upto_message.created_at,
                                models.Message.id <= upto_message.id
                            )
                        )
                    )
                )
                messages_to_mark_result = await db.execute(messages_to_mark_query)
                messages_to_mark = messages_to_mark_result.scalars().all()
                
                # 批量标记为已读
                for msg in messages_to_mark:
                    existing_read_query = select(models.MessageRead).where(
                        and_(
                            models.MessageRead.message_id == msg.id,
                            models.MessageRead.user_id == user_id
                        )
                    )
                    existing_read_result = await db.execute(existing_read_query)
                    existing_read = existing_read_result.scalar_one_or_none()
                    
                    if not existing_read:
                        new_read = models.MessageRead(
                            message_id=msg.id,
                            user_id=user_id,
                            read_at=current_time
                        )
                        db.add(new_read)
                        marked_count += 1
                
                # 更新或创建游标
                await MessageReadLogic._update_read_cursor(
                    db, task_id, user_id, upto_message.id, current_time
                )
        
        elif message_ids:
            # 方式2：标记指定消息ID列表
            messages_to_mark_query = select(models.Message).where(
                and_(
                    models.Message.id.in_(message_ids),
                    models.Message.task_id == task_id,
                    models.Message.sender_id != user_id
                )
            )
            messages_to_mark_result = await db.execute(messages_to_mark_query)
            messages_to_mark = messages_to_mark_result.scalars().all()
            
            # 批量标记为已读
            for msg in messages_to_mark:
                existing_read_query = select(models.MessageRead).where(
                    and_(
                        models.MessageRead.message_id == msg.id,
                        models.MessageRead.user_id == user_id
                    )
                )
                existing_read_result = await db.execute(existing_read_query)
                existing_read = existing_read_result.scalar_one_or_none()
                
                if not existing_read:
                    new_read = models.MessageRead(
                        message_id=msg.id,
                        user_id=user_id,
                        read_at=current_time
                    )
                    db.add(new_read)
                    marked_count += 1
            
            # 更新游标（使用最大的消息ID）
            if messages_to_mark:
                max_message_id = max([msg.id for msg in messages_to_mark])
                await MessageReadLogic._update_read_cursor(
                    db, task_id, user_id, max_message_id, current_time
                )
        
        return marked_count
    
    @staticmethod
    async def _update_read_cursor(
        db: AsyncSession,
        task_id: int,
        user_id: str,
        last_read_message_id: int,
        current_time: datetime
    ):
        """更新或创建已读游标"""
        cursor_query = select(models.MessageReadCursor).where(
            and_(
                models.MessageReadCursor.task_id == task_id,
                models.MessageReadCursor.user_id == user_id
            )
        )
        cursor_result = await db.execute(cursor_query)
        cursor = cursor_result.scalar_one_or_none()
        
        if cursor:
            if last_read_message_id > cursor.last_read_message_id:
                cursor.last_read_message_id = last_read_message_id
                cursor.updated_at = current_time
        else:
            new_cursor = models.MessageReadCursor(
                task_id=task_id,
                user_id=user_id,
                last_read_message_id=last_read_message_id,
                updated_at=current_time
            )
            db.add(new_cursor)


class UnreadCountLogic:
    """未读计数聚合逻辑"""
    
    @staticmethod
    async def get_unread_count(
        db: AsyncSession,
        task_id: int,
        user_id: str
    ) -> int:
        """
        获取任务的未读消息数
        统一口径：排除自己发送的消息
        """
        # 方案1：使用游标模式（更快）
        cursor_query = select(models.MessageReadCursor).where(
            and_(
                models.MessageReadCursor.task_id == task_id,
                models.MessageReadCursor.user_id == user_id
            )
        )
        cursor_result = await db.execute(cursor_query)
        cursor = cursor_result.scalar_one_or_none()
        
        if cursor:
            # 使用游标计算未读数
            unread_query = select(func.count(models.Message.id)).where(
                and_(
                    models.Message.task_id == task_id,
                    models.Message.id > cursor.last_read_message_id,
                    models.Message.sender_id != user_id,
                    models.Message.conversation_type == 'task'
                )
            )
        else:
            # 没有游标，使用 message_reads 表兜底
            unread_query = select(func.count(models.Message.id)).where(
                and_(
                    models.Message.task_id == task_id,
                    models.Message.sender_id != user_id,
                    models.Message.conversation_type == 'task',
                    ~select(1).where(
                        and_(
                            models.MessageRead.message_id == models.Message.id,
                            models.MessageRead.user_id == user_id
                        )
                    ).exists()
                )
            )
        
        unread_result = await db.execute(unread_query)
        return unread_result.scalar() or 0


class PrenoteFrequencyLimitLogic:
    """说明类消息频率限制逻辑"""
    
    @staticmethod
    async def check_prenote_frequency_limit(
        db: AsyncSession,
        task_id: int,
        user_id: str
    ) -> Tuple[bool, Optional[str]]:
        """
        检查说明类消息频率限制
        限制：1条/分钟，日上限20条
        返回：(can_send, error_message)
        """
        now = datetime.now(timezone.utc)
        one_minute_ago = now - timedelta(minutes=1)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        
        # 检查1分钟内是否发送过
        recent_query = select(func.count(models.Message.id)).where(
            and_(
                models.Message.task_id == task_id,
                models.Message.sender_id == user_id,
                models.Message.created_at >= one_minute_ago,
                models.Message.meta.like('%"is_prestart_note": true%')
            )
        )
        recent_result = await db.execute(recent_query)
        recent_count = recent_result.scalar() or 0
        
        if recent_count > 0:
            return False, "说明类消息发送频率限制：最多1条/分钟"
        
        # 检查今日是否超过20条
        today_query = select(func.count(models.Message.id)).where(
            and_(
                models.Message.task_id == task_id,
                models.Message.sender_id == user_id,
                models.Message.created_at >= today_start,
                models.Message.meta.like('%"is_prestart_note": true%')
            )
        )
        today_result = await db.execute(today_query)
        today_count = today_result.scalar() or 0
        
        if today_count >= 20:
            return False, "说明类消息日上限：最多20条/天"
        
        return True, None


class CurrencyValidationLogic:
    """货币一致性校验逻辑"""
    
    @staticmethod
    def validate_currency_consistency(
        task_currency: Optional[str],
        application_currency: Optional[str]
    ) -> Tuple[bool, Optional[str]]:
        """
        校验货币一致性
        返回：(is_valid, error_message)
        """
        # 如果任务和申请都有货币，必须一致
        if task_currency and application_currency:
            if task_currency != application_currency:
                return False, f"货币不一致：任务使用 {task_currency}，申请使用 {application_currency}"
        
        return True, None


class NegotiationTokenLogic:
    """一次性签名 token 生成和验证逻辑"""
    
    @staticmethod
    def generate_negotiation_tokens(
        application_id: int,
        task_id: int,
        applicant_id: str
    ) -> Tuple[str, str, dict, dict]:
        """
        生成议价响应 token（accept 和 reject）
        返回：(token_accept, token_reject, token_accept_data, token_reject_data)
        """
        import secrets
        import time
        
        # 生成两个token
        token_accept = secrets.token_urlsafe(32)
        token_reject = secrets.token_urlsafe(32)
        
        # 获取当前时间戳
        current_timestamp = int(time.time())
        expires_at = current_timestamp + 300  # 5分钟后过期
        
        # 生成nonce（防重放）
        nonce_accept = secrets.token_urlsafe(16)
        nonce_reject = secrets.token_urlsafe(16)
        
        # Token payload
        token_data_accept = {
            "user_id": applicant_id,
            "action": "accept",
            "application_id": application_id,
            "task_id": task_id,
            "nonce": nonce_accept,
            "exp": expires_at,
            "expires_at": datetime.fromtimestamp(expires_at, tz=timezone.utc).isoformat()
        }
        
        token_data_reject = {
            "user_id": applicant_id,
            "action": "reject",
            "application_id": application_id,
            "task_id": task_id,
            "nonce": nonce_reject,
            "exp": expires_at,
            "expires_at": datetime.fromtimestamp(expires_at, tz=timezone.utc).isoformat()
        }
        
        return token_accept, token_reject, token_data_accept, token_data_reject
    
    @staticmethod
    def store_tokens_in_redis(
        token_accept: str,
        token_reject: str,
        token_data_accept: dict,
        token_data_reject: dict
    ) -> bool:
        """
        将token存储到Redis
        返回：是否成功
        """
        import json
        from app.redis_cache import get_redis_client
        
        redis_client = get_redis_client()
        if not redis_client:
            return False
        
        try:
            # 存储到Redis，5分钟过期
            redis_client.setex(
                f"negotiation_token:{token_accept}",
                300,  # 5分钟
                json.dumps(token_data_accept)
            )
            
            redis_client.setex(
                f"negotiation_token:{token_reject}",
                300,  # 5分钟
                json.dumps(token_data_reject)
            )
            
            return True
        except Exception as e:
            logger.error(f"存储token到Redis失败: {e}")
            return False
    
    @staticmethod
    def verify_and_consume_token(
        token: str,
        expected_user_id: str,
        expected_action: str,
        expected_task_id: int,
        expected_application_id: int
    ) -> Tuple[bool, Optional[dict], Optional[str]]:
        """
        验证并消费token（原子操作）
        返回：(is_valid, token_data, error_message)
        """
        import json
        import time
        from app.redis_cache import get_redis_client
        
        redis_client = get_redis_client()
        if not redis_client:
            return False, None, "Redis不可用"
        
        token_key = f"negotiation_token:{token}"
        
        # 使用GETDEL原子操作（Redis 6.2+）
        # 如果Redis版本不支持GETDEL，使用Lua脚本
        try:
            token_data_str = redis_client.getdel(token_key)
        except AttributeError:
            # Redis版本不支持GETDEL，使用Lua脚本
            lua_script = """
            local key = KEYS[1]
            local value = redis.call('GET', key)
            if value then
                redis.call('DEL', key)
            end
            return value
            """
            token_data_str = redis_client.eval(lua_script, 1, token_key)
        
        if not token_data_str:
            return False, None, "Token无效或已使用"
        
        # 解析token数据
        if isinstance(token_data_str, bytes):
            token_data_str = token_data_str.decode('utf-8')
        
        try:
            token_data = json.loads(token_data_str)
        except json.JSONDecodeError:
            return False, None, "Token格式错误"
        
        # 验证过期时间
        current_timestamp = int(time.time())
        if token_data.get("exp", 0) < current_timestamp:
            return False, None, "Token已过期"
        
        # 验证用户ID
        if token_data.get("user_id") != expected_user_id:
            return False, None, "Token用户不匹配"
        
        # 验证action
        if token_data.get("action") != expected_action:
            return False, None, "Token action不匹配"
        
        # 验证task_id和application_id
        if (token_data.get("task_id") != expected_task_id or 
            token_data.get("application_id") != expected_application_id):
            return False, None, "Token参数不匹配"
        
        return True, token_data, None


class NegotiationResponseLogLogic:
    """议价响应操作日志记录逻辑"""
    
    @staticmethod
    async def log_negotiation_response(
        db: AsyncSession,
        task_id: int,
        application_id: int,
        user_id: str,
        action: str,
        negotiated_price: Optional[Decimal] = None
    ):
        """
        记录议价响应操作日志
        与业务事务一起提交
        """
        from app.models import get_uk_time_naive
        current_time = get_uk_time_naive()
        
        log_entry = models.NegotiationResponseLog(
            task_id=task_id,
            application_id=application_id,
            user_id=user_id,
            action=action,
            negotiated_price=negotiated_price,
            responded_at=current_time
        )
        db.add(log_entry)
        # 注意：不在这里commit，由调用方统一提交事务


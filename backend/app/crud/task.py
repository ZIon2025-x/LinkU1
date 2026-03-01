"""任务相关 CRUD，独立模块便于维护与测试。"""
import json
import logging
import os
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app import models, schemas
from app.crud.notification import create_notification
from app.crud.system import get_system_settings_dict
from app.crud.user import update_user_statistics
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def add_task_history(
    db: Session, task_id: int, user_id: str | None, action: str, remark: str = None
):
    """添加任务历史记录。user_id 可为 None（如管理员操作）。"""
    history = models.TaskHistory(
        task_id=task_id, user_id=user_id, action=action, remark=remark
    )
    db.add(history)
    db.commit()
    db.refresh(history)
    return history


def get_task_history(db: Session, task_id: int):
    return (
        db.query(models.TaskHistory)
        .filter(models.TaskHistory.task_id == task_id)
        .order_by(models.TaskHistory.timestamp)
        .all()
    )


def get_user_tasks(
    db: Session,
    user_id: str,
    limit: int = 50,
    offset: int = 0,
    role: str | None = None,
    status: str | None = None,
):
    """
    获取当前用户的任务（发布的、接受的、或参与的），支持按 role/status 筛选与分页。
    role: 'poster' 仅发布, 'taker' 仅接取/参与, None 全部。
    返回 (tasks_slice, total_count)。
    """
    from sqlalchemy import and_, or_

    from app.models import Task, TaskParticipant, TaskTimeSlotRelation

    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=3)

    tasks_query = (
        db.query(models.Task)
        .options(
            selectinload(models.Task.poster),
            selectinload(models.Task.taker),
            selectinload(models.Task.reviews),
            selectinload(models.Task.time_slot_relations).selectinload(
                TaskTimeSlotRelation.time_slot
            ),
            selectinload(models.Task.participants),
        )
        .filter(
            or_(
                models.Task.poster_id == user_id,
                models.Task.taker_id == user_id,
                models.Task.originating_user_id == user_id,
            ),
            or_(
                models.Task.status != "completed",
                and_(
                    models.Task.status == "completed",
                    models.Task.completed_at.isnot(None),
                    models.Task.completed_at
                    > three_days_ago.replace(tzinfo=None)
                    if three_days_ago.tzinfo
                    else models.Task.completed_at > three_days_ago,
                ),
            ),
        )
    )

    participant_tasks_query = (
        db.query(models.Task)
        .join(TaskParticipant, models.Task.id == TaskParticipant.task_id)
        .options(
            selectinload(models.Task.poster),
            selectinload(models.Task.taker),
            selectinload(models.Task.reviews),
            selectinload(models.Task.time_slot_relations).selectinload(
                TaskTimeSlotRelation.time_slot
            ),
            selectinload(models.Task.participants),
        )
        .filter(
            and_(
                TaskParticipant.user_id == user_id,
                models.Task.is_multi_participant == True,
                or_(
                    models.Task.status != "completed",
                    and_(
                        models.Task.status == "completed",
                        models.Task.completed_at.isnot(None),
                        models.Task.completed_at
                        > three_days_ago.replace(tzinfo=None)
                        if three_days_ago.tzinfo
                        else models.Task.completed_at > three_days_ago,
                    ),
                ),
            )
        )
    )

    tasks_from_poster_taker = tasks_query.all()
    tasks_from_participant = participant_tasks_query.all()
    tasks_dict = {}
    for task in tasks_from_poster_taker + tasks_from_participant:
        tasks_dict[task.id] = task
    tasks = list(tasks_dict.values())

    if role == "poster":
        tasks = [t for t in tasks if t.poster_id == user_id]
    elif role == "taker":
        tasks = [t for t in tasks if t.poster_id != user_id]
    if status:
        tasks = [t for t in tasks if t.status == status]

    tasks.sort(key=lambda t: t.created_at, reverse=True)
    total = len(tasks)
    tasks = tasks[offset : offset + limit]
    return tasks, total


def create_task(db: Session, user_id: str, task: schemas.TaskCreate):
    from app.models import Task, User

    user = db.query(User).filter(User.id == user_id).first()
    settings = get_system_settings_dict(db)
    vip_price_threshold = float(settings.get("vip_price_threshold", 10.0))
    super_vip_price_threshold = float(settings.get("super_vip_price_threshold", 50.0))

    reward_to_be_quoted = task.reward is None
    base_reward_value = (
        Decimal(str(task.reward)) if task.reward is not None else Decimal("0")
    )
    reward_value = task.reward if task.reward is not None else 0
    if user.user_level == "super":
        task_level = "vip"
    elif float(base_reward_value) >= super_vip_price_threshold:
        task_level = "super"
    elif float(base_reward_value) >= vip_price_threshold:
        task_level = "vip"
    else:
        task_level = "normal"

    is_flexible = getattr(task, "is_flexible", 0) or 0
    deadline = None
    if is_flexible == 1:
        deadline = None
    elif task.deadline is not None:
        deadline = task.deadline
        is_flexible = 0
    else:
        deadline = task.deadline if task.deadline else (get_utc_time() + timedelta(days=7))
        is_flexible = 0

    images_json = None
    if task.images and len(task.images) > 0:
        images_json = json.dumps(task.images)

    db_task = models.Task(
        title=task.title,
        description=task.description,
        deadline=deadline,
        is_flexible=is_flexible,
        reward=reward_value,
        base_reward=base_reward_value,
        agreed_reward=None,
        reward_to_be_quoted=reward_to_be_quoted,
        currency=getattr(task, "currency", "GBP") or "GBP",
        location=task.location,
        latitude=getattr(task, "latitude", None),
        longitude=getattr(task, "longitude", None),
        task_type=task.task_type,
        poster_id=user_id,
        status="open",
        task_level=task_level,
        is_public=getattr(task, "is_public", 1),
        images=images_json,
    )
    designated_taker_id = getattr(task, "designated_taker_id", None)
    task_source = getattr(task, "task_source", "normal") or "normal"
    if designated_taker_id:
        db_task.taker_id = designated_taker_id
        db_task.status = "pending_acceptance"
        db_task.task_source = task_source

    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    if designated_taker_id:
        try:
            from app.models import TaskApplication

            auto_application = TaskApplication(
                task_id=db_task.id,
                applicant_id=designated_taker_id,
                status="pending",
                message="来自用户资料页的任务请求",
                negotiated_price=Decimal(str(task.reward)) if task.reward is not None else None,
                currency=getattr(task, "currency", "GBP") or "GBP",
            )
            db.add(auto_application)
            db.commit()
            create_notification(
                db,
                user_id=designated_taker_id,
                type="task_direct_request",
                title="有用户向你发送了任务请求",
                title_en="You received a task request",
                content=f"「{task.title}」- {'待报价' if reward_to_be_quoted else f'£{task.reward}'}",
                content_en=f'"{task.title}" - {"Price to be quoted" if reward_to_be_quoted else f"£{task.reward}"}',
                related_id=str(db_task.id),
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"创建指定任务申请/通知失败: {e}")

    update_user_statistics(db, user_id)

    try:
        from app.redis_cache import (
            invalidate_tasks_cache,
            invalidate_user_cache,
            redis_cache,
        )

        invalidate_user_cache(user_id)
        invalidate_tasks_cache()
        for pattern in [
            f"user_tasks:{user_id}*",
            f"{user_id}_*",
            f"user_tasks:{user_id}_*",
        ]:
            deleted = redis_cache.delete_pattern(pattern)
            if deleted > 0:
                logger.debug(f"清除模式 {pattern}，删除了 {deleted} 个键")
        for pattern in ["recommendations:*", "popular_tasks:*"]:
            try:
                deleted = redis_cache.delete_pattern(pattern)
                if deleted > 0:
                    logger.info(f"清除推荐缓存模式 {pattern}，删除了 {deleted} 个键")
            except Exception as e:
                logger.warning(f"清除推荐缓存失败 {pattern}: {e}")
        user_created_at = user.created_at if user.created_at else get_utc_time()
        is_new_user = (
            (get_utc_time() - user_created_at).days <= 7
            if hasattr((get_utc_time() - user_created_at), "days")
            else False
        )
        if is_new_user:
            try:
                from app.recommendation_tasks import update_popular_tasks_async

                update_popular_tasks_async()
            except Exception as e:
                logger.warning(f"异步更新热门任务失败: {e}")
    except Exception as e:
        logger.warning(f"清除缓存失败: {e}")

    return db_task


def list_all_tasks(db: Session, skip: int = 0, limit: int = 1000):
    """获取所有任务（用于客服管理，不进行状态过滤）"""
    from app.models import Task

    tasks = (
        db.query(Task)
        .options(selectinload(Task.poster))
        .order_by(Task.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    for task in tasks:
        if task.poster:
            task.poster_timezone = task.poster.timezone or "UTC"
        else:
            task.poster_timezone = "UTC"
    return tasks


def get_task(db: Session, task_id: int):
    """获取任务详情 - 优化 N+1 查询"""
    from app.models import (
        Activity,
        ActivityTimeSlotRelation,
        Task,
        TaskTimeSlotRelation,
    )

    task = (
        db.query(Task)
        .options(
            selectinload(Task.poster),
            selectinload(Task.taker),
            selectinload(Task.participants),
            selectinload(Task.time_slot_relations).selectinload(
                TaskTimeSlotRelation.time_slot
            ),
            selectinload(Task.parent_activity)
            .selectinload(Activity.time_slot_relations)
            .selectinload(ActivityTimeSlotRelation.time_slot),
            selectinload(Task.expert_service),
            selectinload(Task.flea_market_item),
        )
        .filter(Task.id == task_id)
        .first()
    )
    if task:
        if task.poster:
            task.poster_timezone = task.poster.timezone or "UTC"
        else:
            task.poster_timezone = "UTC"
    return task


def accept_task(db: Session, task_id: int, taker_id: str):
    """接受任务（带并发控制，SELECT FOR UPDATE）"""
    from datetime import timezone as tz

    from app.models import Task, User
    from app.transaction_utils import safe_commit
    from app.utils.time_utils import get_utc_time as _get_utc

    try:
        task_query = select(Task).where(Task.id == task_id).with_for_update()
        task = db.execute(task_query).scalar_one_or_none()
        if not task:
            logger.warning(f"任务 {task_id} 不存在")
            return None
        taker = db.query(User).filter(User.id == taker_id).first()
        if not taker:
            logger.warning(f"用户 {taker_id} 不存在")
            return None

        if task.status == "pending_acceptance":
            if task.taker_id != taker_id:
                logger.warning(
                    f"任务 {task_id} 指定给 {task.taker_id}，但 {taker_id} 尝试接受"
                )
                return None
        elif task.status != "open":
            logger.warning(f"任务 {task_id} 状态为 {task.status}，不是 open")
            return None
        elif task.taker_id is not None:
            logger.warning(f"任务 {task_id} 已被用户 {task.taker_id} 接受")
            return None

        if task.deadline:
            current_time = _get_utc()
            deadline_utc = (
                task.deadline
                if task.deadline.tzinfo
                else task.deadline.replace(tzinfo=tz.utc)
            )
            if deadline_utc < current_time:
                logger.warning(
                    f"任务 {task_id} 已过期: deadline={deadline_utc}, now={current_time}"
                )
                return None

        task.taker_id = str(taker_id)
        task.status = "taken"
        if not safe_commit(db, f"接受任务 {task_id}"):
            return None
        db.refresh(task)
        logger.info(f"成功接受任务 {task_id}，接收者: {taker_id}")
        return task
    except Exception as e:
        logger.error(f"接受任务 {task_id} 失败: {e}", exc_info=True)
        db.rollback()
        return None


def update_task_reward(db: Session, task_id: int, poster_id: int, new_reward: float):
    from app.models import Task

    task = (
        db.query(Task)
        .filter(Task.id == task_id, Task.poster_id == poster_id)
        .first()
    )
    if not task or task.status != "open":
        return None
    task.reward = new_reward
    task.base_reward = Decimal(str(new_reward))
    # 发布者后续填写金额后，不再视为待报价
    if getattr(task, "reward_to_be_quoted", False) and new_reward > 0:
        task.reward_to_be_quoted = False
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"更新任务价格失败 task_id={task_id}: {e}", exc_info=True)
        raise
    db.refresh(task)
    return task


def cleanup_task_files(db: Session, task_id: int):
    """清理任务相关的所有图片和文件（公开和私密）。返回删除的文件数量。"""
    from app.image_cleanup import delete_task_images

    try:
        deleted_count = delete_task_images(task_id, include_private=True)
        if deleted_count > 0:
            logger.info(f"任务 {task_id} 已清理 {deleted_count} 个文件")
        return deleted_count
    except Exception as e:
        logger.error(f"清理任务文件失败 {task_id}: {e}")
        return 0


def cancel_task(
    db: Session, task_id: int, user_id: str, is_admin_review: bool = False
):
    """取消任务 - 支持管理员审核后的取消，并清理相关文件"""
    from app.models import (
        ServiceTimeSlot,
        Task,
        TaskParticipant,
        TaskTimeSlotRelation,
    )
    from app.push_notification_service import send_push_notification

    locked_query = select(Task).where(Task.id == task_id).with_for_update()
    task = db.execute(locked_query).scalar_one_or_none()
    if not task:
        return None

    if not is_admin_review:
        if task.status == "pending_acceptance" and task.taker_id == user_id:
            pass
        elif task.poster_id == user_id and task.status in (
            "open",
            "pending_acceptance",
        ):
            pass
        else:
            return None
    else:
        if task.poster_id != user_id and task.taker_id != user_id:
            return None

    task.status = "cancelled"

    task_time_slot_relation = (
        db.query(TaskTimeSlotRelation)
        .filter(TaskTimeSlotRelation.task_id == task_id)
        .first()
    )
    if task_time_slot_relation and task_time_slot_relation.time_slot_id:
        if not task.is_multi_participant:
            time_slot = (
                db.query(ServiceTimeSlot)
                .filter(
                    ServiceTimeSlot.id == task_time_slot_relation.time_slot_id
                )
                .with_for_update()
                .first()
            )
            if time_slot and time_slot.current_participants > 0:
                time_slot.current_participants -= 1
                if time_slot.current_participants < time_slot.max_participants:
                    time_slot.is_available = True
                db.add(time_slot)
        else:
            participants = (
                db.query(TaskParticipant)
                .filter(
                    TaskParticipant.task_id == task_id,
                    TaskParticipant.status.in_(["accepted", "in_progress"]),
                )
                .all()
                )
            participants_to_decrement = len(participants)
            if participants_to_decrement > 0:
                time_slot = (
                    db.query(ServiceTimeSlot)
                    .filter(
                        ServiceTimeSlot.id
                        == task_time_slot_relation.time_slot_id
                    )
                    .with_for_update()
                    .first()
                )
                if time_slot:
                    time_slot.current_participants = max(
                        0,
                        time_slot.current_participants - participants_to_decrement,
                    )
                    if time_slot.current_participants < time_slot.max_participants:
                        time_slot.is_available = True
                    db.add(time_slot)

    if is_admin_review:
        add_task_history(db, task.id, user_id, "cancelled", "管理员审核通过后取消")
    else:
        add_task_history(db, task.id, task.poster_id, "cancelled", "任务发布者手动取消")

    create_notification(
        db,
        task.poster_id,
        "task_cancelled",
        "任务已取消",
        f'您的任务"{task.title}"已被取消',
        related_id=str(task.id),
        title_en="Task Cancelled",
        content_en=f'Your task"{task.title}"has been cancelled',
    )
    try:
        send_push_notification(
            db=db,
            user_id=task.poster_id,
            notification_type="task_cancelled",
            data={"task_id": task.id},
            template_vars={"task_title": task.title, "task_id": task.id},
        )
    except Exception as e:
        logger.warning(f"发送任务取消推送通知失败（发布者）: {e}")

    if task.taker_id and task.taker_id != task.poster_id:
        create_notification(
            db,
            task.taker_id,
            "task_cancelled",
            "任务已取消",
            f'您接受的任务"{task.title}"已被取消',
            related_id=str(task.id),
            title_en="Task Cancelled",
            content_en=f'The task you accepted"{task.title}"has been cancelled',
        )
        try:
            send_push_notification(
                db=db,
                user_id=task.taker_id,
                notification_type="task_cancelled",
                data={"task_id": task.id},
                template_vars={"task_title": task.title, "task_id": task.id},
            )
        except Exception as e:
            logger.warning(f"发送任务取消推送通知失败（接受者）: {e}")

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"取消任务提交失败 task_id={task_id}: {e}", exc_info=True)
        raise
    db.refresh(task)

    try:
        cleanup_task_files(db, task_id)
    except Exception as e:
        logger.error(f"清理任务文件失败 {task_id}: {e}")

    update_user_statistics(db, task.poster_id)
    if task.taker_id:
        update_user_statistics(db, task.taker_id)
    return task


def delete_task_safely(db: Session, task_id: int):
    """安全删除任务及其所有相关记录，包括图片和文件"""
    from app.models import (
        Message,
        MessageAttachment,
        MessageRead,
        MessageReadCursor,
        NegotiationResponseLog,
        Notification,
        Review,
        Task,
        TaskApplication,
        TaskAuditLog,
        TaskCancelRequest,
        TaskHistory,
        TaskParticipant,
        TaskParticipantReward,
        TaskTimeSlotRelation,
    )

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return False
    poster_id = task.poster_id
    taker_id = task.taker_id

    try:
        application_ids = [
            app.id
            for app in db.query(TaskApplication.id)
            .filter(TaskApplication.task_id == task_id)
            .all()
        ]
        if application_ids:
            db.query(NegotiationResponseLog).filter(
                NegotiationResponseLog.application_id.in_(application_ids)
            ).delete(synchronize_session=False)

        db.query(TaskApplication).filter(
            TaskApplication.task_id == task_id
        ).delete(synchronize_session=False)
        db.query(Notification).filter(
            Notification.related_id == task_id
        ).delete(synchronize_session=False)
        db.query(Review).filter(Review.task_id == task_id).delete(
            synchronize_session=False
        )
        db.query(TaskHistory).filter(TaskHistory.task_id == task_id).delete(
            synchronize_session=False
        )
        db.query(TaskCancelRequest).filter(
            TaskCancelRequest.task_id == task_id
        ).delete(synchronize_session=False)
        db.query(TaskParticipantReward).filter(
            TaskParticipantReward.task_id == task_id
        ).delete(synchronize_session=False)
        db.query(TaskAuditLog).filter(TaskAuditLog.task_id == task_id).delete(
            synchronize_session=False
        )
        db.query(TaskParticipant).filter(
            TaskParticipant.task_id == task_id
        ).delete(synchronize_session=False)

        db.flush()
        relations = (
            db.query(TaskTimeSlotRelation)
            .filter(TaskTimeSlotRelation.task_id == task_id)
            .all()
        )
        for relation in relations:
            db.delete(relation)
        db.flush()

        task_messages = (
            db.query(Message).filter(Message.task_id == task_id).all()
        )
        image_ids = []
        message_ids = []
        for msg in task_messages:
            message_ids.append(msg.id)
            if msg.image_id:
                image_ids.append(msg.image_id)

        if message_ids:
            db.query(MessageRead).filter(
                MessageRead.message_id.in_(message_ids)
            ).delete(synchronize_session=False)
            db.query(MessageReadCursor).filter(
                MessageReadCursor.task_id == task_id
            ).delete(synchronize_session=False)
            db.query(MessageReadCursor).filter(
                MessageReadCursor.last_read_message_id.in_(message_ids)
            ).delete(synchronize_session=False)

        if message_ids:
            attachments = (
                db.query(MessageAttachment)
                .filter(MessageAttachment.message_id.in_(message_ids))
                .all()
            )
            for attachment in attachments:
                if attachment.blob_id:
                    try:
                        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
                        file_dir = (
                            Path("/data/uploads/private/files")
                            if railway_env
                            else Path("uploads/private/files")
                        )
                        for file_path in file_dir.glob(f"{attachment.blob_id}.*"):
                            file_path.unlink()
                            logger.info(f"删除任务附件文件: {file_path}")
                    except Exception as e:
                        logger.error(
                            f"删除附件文件失败 {attachment.blob_id}: {e}"
                        )
            db.query(MessageAttachment).filter(
                MessageAttachment.message_id.in_(message_ids)
            ).delete(synchronize_session=False)

        for image_id in image_ids:
            try:
                railway_env = os.getenv("RAILWAY_ENVIRONMENT")
                image_dir = (
                    Path("/data/uploads/private_images")
                    if railway_env
                    else Path("uploads/private_images")
                )
                for img_path in image_dir.glob(f"{image_id}.*"):
                    img_path.unlink()
                    logger.info(f"删除任务图片: {img_path}")
            except Exception as e:
                logger.error(f"删除图片失败 {image_id}: {e}")

        db.query(Message).filter(Message.task_id == task_id).delete()
        db.delete(task)
        db.commit()

        update_user_statistics(db, poster_id)
        if taker_id:
            update_user_statistics(db, taker_id)
        logger.info(
            f"成功删除任务 {task_id}，包括 {len(image_ids)} 张图片和相关附件"
        )
        return True
    except Exception as e:
        db.rollback()
        logger.error(f"删除任务失败 {task_id}: {e}")
        raise

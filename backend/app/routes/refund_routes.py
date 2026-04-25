"""
Refund / dispute domain routes — extracted from app/routers.py (Task 10).

Includes 8 routes covering disputes, refund requests, refund history,
rebuttal, and the post-confirmation payout/reward flow:
  - POST /tasks/{task_id}/dispute
  - POST /tasks/{task_id}/refund-request
  - GET  /tasks/{task_id}/refund-status
  - GET  /tasks/{task_id}/dispute-timeline
  - GET  /tasks/{task_id}/refund-history
  - POST /tasks/{task_id}/refund-request/{refund_id}/cancel
  - POST /tasks/{task_id}/refund-request/{refund_id}/rebuttal
  - POST /tasks/{task_id}/confirm_completion   ← `confirm_task_completion`,
        re-exported back into app.routers for async_routers consumer.

Mounts at both /api and /api/users via main.py.
"""
import logging
from decimal import Decimal
from typing import List, Optional

import stripe
from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    HTTPException,
)
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    check_user_status,
    get_current_user_secure_sync_csrf,
    get_db,
)
from app.rate_limiting import rate_limit
# Module-level helper stays in app/routers.py per the split plan.
from app.routers import _safe_json_loads
from app.utils.task_guards import load_real_task_or_404_sync
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/tasks/{task_id}/dispute", response_model=schemas.TaskDisputeOut)
@rate_limit("create_dispute")
def create_task_dispute(
    task_id: int,
    dispute_data: schemas.TaskDisputeCreate,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者提交争议（未正确完成）"""
    task = load_real_task_or_404_sync(db, task_id)
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="任务不存在")  # combined 404 preserves 防探测
    if task.status != "pending_confirmation":
        raise HTTPException(status_code=400, detail="Task is not pending confirmation")

    # 检查是否已经提交过争议
    existing_dispute = db.query(models.TaskDispute).filter(
        models.TaskDispute.task_id == task_id,
        models.TaskDispute.poster_id == current_user.id,
        models.TaskDispute.status == "pending"
    ).first()

    if existing_dispute:
        raise HTTPException(status_code=400, detail="您已经提交过争议，请等待管理员处理")

    # ✅ 验证证据文件（如果提供）
    validated_evidence_files = []
    if dispute_data.evidence_files:
        if len(dispute_data.evidence_files) > 10:
            raise HTTPException(
                status_code=400,
                detail="证据文件数量不能超过10个"
            )

        # 验证文件是否属于当前任务
        from app.models import MessageAttachment, Message
        for file_id in dispute_data.evidence_files:
            # 检查文件是否存在于MessageAttachment中，且与当前任务相关
            attachment = db.query(MessageAttachment).filter(
                MessageAttachment.blob_id == file_id
            ).first()

            if attachment:
                # 通过附件找到消息，验证是否属于当前任务
                task_message = db.query(Message).filter(
                    Message.id == attachment.message_id,
                    Message.task_id == task_id
                ).first()

                if task_message:
                    validated_evidence_files.append(file_id)
                else:
                    logger.warning(f"证据文件 {file_id} 不属于任务 {task_id}，已忽略")
            else:
                logger.warning(f"证据文件 {file_id} 不存在，已忽略")

    # 创建争议记录
    import json
    evidence_files_json = json.dumps(validated_evidence_files) if validated_evidence_files else None

    dispute = models.TaskDispute(
        task_id=task_id,
        poster_id=current_user.id,
        reason=dispute_data.reason,
        evidence_files=evidence_files_json,
        status="pending",
        created_at=get_utc_time()
    )
    db.add(dispute)
    db.flush()

    # 更新可靠度画像（taker 被投诉）
    try:
        from app.services.reliability_calculator import on_complaint_created
        on_complaint_created(db, task.taker_id)
    except Exception as e:
        logger.warning(f"更新可靠度失败(complaint_created): {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json

        poster_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{poster_name} 对任务完成状态有异议。"
        content_en = f"{poster_name} has raised a dispute about the task completion status."

        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_dispute_created", "dispute_id": dispute.id, "content_en": content_en}),
            created_at=get_utc_time()
        )
        db.add(system_message)
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响争议提交流程

    # 通知管理员（后台任务）
    if background_tasks:
        try:
            from app.task_notifications import send_dispute_notification_to_admin
            send_dispute_notification_to_admin(
                db=db,  # 虽然后台任务会创建新会话，但这里保留参数以保持接口一致性
                background_tasks=background_tasks,
                task=task,
                dispute=dispute,
                poster=current_user
            )
        except Exception as e:
            logger.error(f"Failed to send dispute notification to admin: {e}")

    db.commit()
    db.refresh(dispute)

    return dispute


# ==================== 退款申请API ====================

@router.post("/tasks/{task_id}/refund-request", response_model=schemas.RefundRequestOut)
@rate_limit("refund_request")
def create_refund_request(
    task_id: int,
    refund_data: schemas.RefundRequestCreate,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    任务发布者申请退款（任务未完成）
    只有在任务状态为 pending_confirmation 时才能申请退款
    """
    from sqlalchemy import select
    from decimal import Decimal

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务记录
    task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
    task_result = db.execute(task_query)
    task = task_result.scalar_one_or_none()

    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")
    if task.is_consultation_placeholder:
        raise HTTPException(status_code=404, detail="任务不存在")  # 防探测:同 404 遮掩占位 task 存在

    # 检查任务状态：必须是 pending_confirmation
    if task.status != "pending_confirmation":
        raise HTTPException(
            status_code=400,
            detail=f"任务状态不正确，无法申请退款。当前状态: {task.status}。只有在任务待确认状态时才能申请退款。"
        )

    # 检查任务是否已支付
    if not task.is_paid:
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无需退款。"
        )

    # 🔒 并发安全：检查是否已经提交过退款申请（pending 或 processing 状态）
    existing_refund = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
        models.RefundRequest.poster_id == current_user.id,
        models.RefundRequest.status.in_(["pending", "processing"])
    ).first()

    if existing_refund:
        raise HTTPException(
            status_code=400,
            detail=f"您已经提交过退款申请（状态: {existing_refund.status}），请等待管理员处理"
        )

    # ✅ 验证退款类型和金额
    if refund_data.refund_type not in ["full", "partial"]:
        raise HTTPException(
            status_code=400,
            detail="退款类型必须是 'full'（全额退款）或 'partial'（部分退款）"
        )

    # 验证退款原因类型
    valid_reason_types = ["completion_time_unsatisfactory", "not_completed", "quality_issue", "other"]
    if refund_data.reason_type not in valid_reason_types:
        raise HTTPException(
            status_code=400,
            detail=f"退款原因类型无效，必须是以下之一：{', '.join(valid_reason_types)}"
        )

    # ✅ 修复金额精度：使用Decimal进行金额计算
    task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')

    if refund_data.refund_type == "partial":
        # 部分退款：必须提供退款金额或退款比例
        if refund_data.refund_amount is None and refund_data.refund_percentage is None:
            raise HTTPException(
                status_code=400,
                detail="部分退款必须提供退款金额（refund_amount）或退款比例（refund_percentage）"
            )

        # 计算退款金额
        if refund_data.refund_percentage is not None:
            # 使用退款比例计算
            refund_percentage = Decimal(str(refund_data.refund_percentage))
            if refund_percentage <= 0 or refund_percentage > 100:
                raise HTTPException(
                    status_code=400,
                    detail="退款比例必须在0-100之间"
                )
            calculated_amount = task_amount * refund_percentage / Decimal('100')
            # 安全：当提供了退款比例时，始终以服务端计算的金额为准，忽略前端传入的金额
            if refund_data.refund_amount is not None and refund_data.refund_amount != calculated_amount:
                logger.warning(f"退款金额（£{refund_data.refund_amount}）与退款比例计算出的金额（£{calculated_amount}）不一致，使用服务端计算的金额")
            final_refund_amount = calculated_amount
        else:
            # 只提供了金额
            final_refund_amount = Decimal(str(refund_data.refund_amount))

        if final_refund_amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="退款金额必须大于0"
            )

        if final_refund_amount >= task_amount:
            raise HTTPException(
                status_code=400,
                detail=f"部分退款金额（£{final_refund_amount:.2f}）不能大于或等于任务金额（£{task_amount:.2f}），请选择全额退款"
            )

        # 更新refund_data中的金额
        refund_data.refund_amount = final_refund_amount
    else:
        # 全额退款：refund_amount应该为空或等于任务金额
        if refund_data.refund_amount is not None:
            refund_amount_decimal = Decimal(str(refund_data.refund_amount))
            if refund_amount_decimal != task_amount:
                logger.warning(f"全额退款时提供的金额（£{refund_amount_decimal}）与任务金额（£{task_amount}）不一致，使用任务金额")
        refund_data.refund_amount = task_amount

    # ✅ 修复文件ID验证：验证证据文件ID是否属于当前用户或任务
    validated_evidence_files = []
    if refund_data.evidence_files:
        from app.models import MessageAttachment
        from app.file_system import PrivateFileSystem
        from app.file_utils import is_safe_file_id

        file_system = PrivateFileSystem()
        for file_id in refund_data.evidence_files:
            # 🔒 安全检查：防止路径遍历攻击
            if not is_safe_file_id(file_id):
                logger.warning(f"文件ID包含非法字符，跳过: {file_id[:50]}")
                continue
            try:
                # 检查文件是否存在于MessageAttachment中，且与当前任务相关
                attachment = db.query(MessageAttachment).filter(
                    MessageAttachment.blob_id == file_id
                ).first()

                if attachment:
                    # 通过附件找到消息，验证是否属于当前任务
                    from app.models import Message
                    task_message = db.query(Message).filter(
                        Message.id == attachment.message_id,
                        Message.task_id == task_id
                    ).first()

                    if task_message:
                        # 文件属于当前任务，验证通过
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不属于任务 {task_id}，跳过")
                else:
                    # 文件不在MessageAttachment中，可能是新上传的文件
                    # 检查文件是否存在于任务文件夹中（通过文件系统验证）
                    task_dir = file_system.base_dir / "tasks" / str(task_id)
                    file_exists = False
                    if task_dir.exists():
                        for ext_file in task_dir.glob(f"{file_id}.*"):
                            if ext_file.is_file():
                                file_exists = True
                                break

                    if file_exists:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不存在或不属于任务 {task_id}，跳过")
            except Exception as file_error:
                logger.warning(f"验证文件 {file_id} 时发生错误: {file_error}，跳过")

        if not validated_evidence_files and refund_data.evidence_files:
            logger.warning(f"所有证据文件验证失败，但继续处理退款申请")

    # 处理证据文件（JSON数组）
    evidence_files_json = None
    if validated_evidence_files:
        import json
        evidence_files_json = json.dumps(validated_evidence_files)

    # 创建退款申请记录
    # 将退款原因类型和退款类型存储到reason字段（格式：reason_type|refund_type|reason）
    # 或者可以扩展RefundRequest模型添加新字段，这里先使用reason字段存储
    reason_with_metadata = f"{refund_data.reason_type}|{refund_data.refund_type}|{refund_data.reason}"

    refund_request = models.RefundRequest(
        task_id=task_id,
        poster_id=current_user.id,
        reason=reason_with_metadata,  # 包含原因类型和退款类型
        evidence_files=evidence_files_json,
        refund_amount=refund_data.refund_amount,
        status="pending",
        created_at=get_utc_time()
    )
    db.add(refund_request)
    db.flush()

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json

        poster_name = current_user.name or f"用户{current_user.id}"
        # 退款原因类型的中文显示
        reason_type_names = {
            "completion_time_unsatisfactory": "对完成时间不满意",
            "not_completed": "接单者完全未完成",
            "quality_issue": "质量问题",
            "other": "其他"
        }
        reason_type_display = reason_type_names.get(refund_data.reason_type, refund_data.reason_type)
        refund_type_display = "全额退款" if refund_data.refund_type == "full" else f"部分退款（£{refund_data.refund_amount:.2f}）"

        content_zh = f"{poster_name} 申请退款（{reason_type_display}，{refund_type_display}）：{refund_data.reason[:100]}"
        content_en = f"{poster_name} has requested a refund ({refund_data.refund_type}): {refund_data.reason[:100]}"

        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_request_created",
                "refund_request_id": refund_request.id,
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID

        # 如果有证据文件，创建附件（使用验证后的文件列表）
        if validated_evidence_files:
            from app.models import MessageAttachment
            from app.file_system import PrivateFileSystem

            file_system = PrivateFileSystem()
            for file_id in validated_evidence_files:
                try:
                    # 生成文件访问URL（需要用户ID和任务参与者）
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"

                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",  # 可能是文件，不只是图片
                        url=file_url,
                        blob_id=file_id,  # 存储文件ID
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
                    # 即使文件处理失败，也继续处理其他文件
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")

    # 通知接单者（如果有接单者）
    if task.taker_id:
        try:
            # 创建应用内通知
            crud.create_notification(
                db=db,
                user_id=task.taker_id,
                type="refund_request",
                title="退款申请通知",
                content=f"任务「{task.title}」的发布者申请退款。原因：{reason_type_display}。请查看详情并可以提交反驳证据。",
                related_id=str(task_id),
                related_type="task_id",
                auto_commit=False
            )

            # 发送推送通知（后台任务）
            if background_tasks:
                from app.push_notification_service import send_push_notification
                def _send_taker_notification():
                    try:
                        from app.database import SessionLocal
                        db_session = SessionLocal()
                        try:
                            send_push_notification(
                                db=db_session,
                                user_id=task.taker_id,
                                title=None,  # 从模板生成
                                body=None,  # 从模板生成
                                notification_type="refund_request",
                                data={
                                    "task_id": task_id,
                                    "refund_request_id": refund_request.id,
                                    "poster_id": current_user.id
                                },
                                template_vars={
                                    "poster_name": poster_name,
                                    "task_title": task.title,
                                    "reason_type": reason_type_display,
                                    "refund_type": refund_type_display,
                                    "task_id": task_id,
                                    "refund_request_id": refund_request.id
                                }
                            )
                        finally:
                            db_session.close()
                    except Exception as e:
                        logger.error(f"Failed to send push notification to taker: {e}")

                background_tasks.add_task(_send_taker_notification)
        except Exception as e:
            logger.error(f"Failed to send refund request notification to taker: {e}")

    # 通知管理员（后台任务）
    if background_tasks:
        try:
            from app.task_notifications import send_refund_request_notification_to_admin
            send_refund_request_notification_to_admin(
                db=db,
                background_tasks=background_tasks,
                task=task,
                refund_request=refund_request,
                poster=current_user
            )
        except Exception as e:
            logger.error(f"Failed to send refund request notification to admin: {e}")

    db.commit()
    db.refresh(refund_request)

    return refund_request


@router.get("/tasks/{task_id}/refund-status", response_model=Optional[schemas.RefundRequestOut])
def get_refund_status(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """查询任务的退款申请状态（返回最新的退款申请）"""
    task = load_real_task_or_404_sync(db, task_id)
    # 发布者和接单人都可以查看退款状态
    uid = str(current_user.id)
    if str(task.poster_id) != uid and str(task.taker_id or "") != uid:
        raise HTTPException(status_code=404, detail="Task not found or no permission")

    refund_request = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
    ).order_by(models.RefundRequest.created_at.desc()).first()

    if not refund_request:
        return None

    # 获取任务信息（用于计算退款比例）
    task = crud.get_task(db, task_id)

    # 处理证据文件（JSON数组转List）
    evidence_files = None
    if refund_request.evidence_files:
        import json
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []

    # 解析退款原因字段（格式：reason_type|refund_type|reason）
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None

    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]
        elif len(parts) == 2:
            # 兼容旧格式
            reason_text = refund_request.reason

    # 计算退款比例（如果有任务金额和退款金额）
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)

    # 创建输出对象
    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=_safe_json_loads(refund_request.rebuttal_evidence_files) if refund_request.rebuttal_evidence_files else None,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at,
    )


@router.get("/tasks/{task_id}/dispute-timeline")
def get_task_dispute_timeline(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    获取任务的完整争议时间线
    包括：任务完成时间线、退款申请、反驳、管理员裁定等所有相关信息
    """
    task = load_real_task_or_404_sync(db, task_id)

    # 验证用户权限：必须是任务参与者（发布者或接单者）
    if task.poster_id != current_user.id and (not task.taker_id or task.taker_id != current_user.id):
        raise HTTPException(status_code=403, detail="Only task participants can view dispute timeline")

    timeline_items = []
    import json
    from decimal import Decimal

    # 1. 任务完成时间线（从系统消息中获取）
    completion_message = db.query(models.Message).filter(
        models.Message.task_id == task_id,
        models.Message.message_type == "system",
        models.Message.meta.contains("task_completed_by_taker")
    ).order_by(models.Message.created_at.asc()).first()

    if completion_message:
        # 获取完成证据（附件和文字），需为私密图片/文件生成可访问 URL（与任务详情一致）
        completion_evidence = []
        if completion_message.id:
            evidence_participants = []
            if task.poster_id:
                evidence_participants.append(str(task.poster_id))
            if task.taker_id:
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants and current_user:
                evidence_participants.append(str(current_user.id))
            viewer_id = str(current_user.id) if current_user else (str(task.poster_id) if task.poster_id else (str(task.taker_id) if task.taker_id else None))

            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == completion_message.id
            ).all()
            for att in attachments:
                url = att.url or ""
                is_private_image = att.blob_id and (
                    (att.attachment_type == "image") or (url and "/api/private-image/" in str(url))
                )
                if is_private_image and viewer_id and evidence_participants:
                    try:
                        from app.image_system import private_image_system
                        url = private_image_system.generate_image_url(
                            att.blob_id, viewer_id, evidence_participants
                        )
                    except Exception as e:
                        logger.debug(f"争议时间线完成证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    try:
                        from app.file_utils import is_safe_file_id
                        from app.file_system import private_file_system
                        from app.signed_url import signed_url_manager
                        if is_safe_file_id(url):
                            task_dir = private_file_system.base_dir / "tasks" / str(task_id)
                            if task_dir.exists():
                                for f in task_dir.glob(f"{url}.*"):
                                    if f.is_file():
                                        file_path_for_url = f"files/{f.name}"
                                        if viewer_id:
                                            url = signed_url_manager.generate_signed_url(
                                                file_path=file_path_for_url,
                                                user_id=viewer_id,
                                                expiry_minutes=60,
                                                one_time=False,
                                            )
                                        break
                    except Exception as e:
                        logger.debug(f"争议时间线完成证据文件签名 URL 失败 file_id={url}: {e}")
                completion_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id
                })

        # 从meta字段中提取文字证据
        if completion_message.meta:
            try:
                meta_data = json.loads(completion_message.meta)
                if "evidence_text" in meta_data and meta_data["evidence_text"]:
                    completion_evidence.append({
                        "type": "text",
                        "content": meta_data["evidence_text"]
                    })
            except (json.JSONDecodeError, KeyError):
                pass  # 如果meta解析失败，忽略

        timeline_items.append({
            "type": "task_completed",
            "title": "任务标记完成",
            "description": completion_message.content,
            "timestamp": completion_message.created_at.isoformat() if completion_message.created_at else None,
            "actor": "taker",
            "evidence": completion_evidence
        })

    # 2. 确认完成时间线（如果有）
    if task.completed_at and task.is_confirmed:
        confirmation_message = db.query(models.Message).filter(
            models.Message.task_id == task_id,
            models.Message.message_type == "system",
            models.Message.meta.contains("task_confirmed_by_poster")
        ).order_by(models.Message.created_at.asc()).first()

        confirmation_evidence = []
        if confirmation_message and confirmation_message.id:
            evidence_participants = []
            if task.poster_id:
                evidence_participants.append(str(task.poster_id))
            if task.taker_id:
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants and current_user:
                evidence_participants.append(str(current_user.id))
            viewer_id = str(current_user.id) if current_user else (str(task.poster_id) if task.poster_id else (str(task.taker_id) if task.taker_id else None))

            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == confirmation_message.id
            ).all()
            for att in attachments:
                url = att.url or ""
                is_private_image = att.blob_id and (
                    (att.attachment_type == "image") or (url and "/api/private-image/" in str(url))
                )
                if is_private_image and viewer_id and evidence_participants:
                    try:
                        from app.image_system import private_image_system
                        url = private_image_system.generate_image_url(
                            att.blob_id, viewer_id, evidence_participants
                        )
                    except Exception as e:
                        logger.debug(f"争议时间线确认证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    try:
                        from app.file_utils import is_safe_file_id
                        from app.file_system import private_file_system
                        from app.signed_url import signed_url_manager
                        if is_safe_file_id(url):
                            task_dir = private_file_system.base_dir / "tasks" / str(task_id)
                            if task_dir.exists():
                                for f in task_dir.glob(f"{url}.*"):
                                    if f.is_file():
                                        file_path_for_url = f"files/{f.name}"
                                        if viewer_id:
                                            url = signed_url_manager.generate_signed_url(
                                                file_path=file_path_for_url,
                                                user_id=viewer_id,
                                                expiry_minutes=60,
                                                one_time=False,
                                            )
                                        break
                    except Exception as e:
                        logger.debug(f"争议时间线确认证据文件签名 URL 失败 file_id={url}: {e}")
                confirmation_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id
                })

        timeline_items.append({
            "type": "task_confirmed",
            "title": "发布者确认完成",
            "description": confirmation_message.content if confirmation_message else "发布者已确认任务完成",
            "timestamp": task.completed_at.isoformat() if task.completed_at else None,
            "actor": "poster",
            "evidence": confirmation_evidence
        })

    # 3. 退款申请时间线
    refund_requests = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id
    ).order_by(models.RefundRequest.created_at.asc()).all()

    # Batch-load all evidence attachments to avoid N+1 queries
    all_evidence_file_ids = set()
    for rr in refund_requests:
        for field in (rr.evidence_files, rr.rebuttal_evidence_files):
            if field:
                try:
                    all_evidence_file_ids.update(json.loads(field))
                except Exception:
                    pass
    attachment_map = {}
    if all_evidence_file_ids:
        attachments = db.query(models.MessageAttachment).filter(
            models.MessageAttachment.blob_id.in_(list(all_evidence_file_ids))
        ).all()
        attachment_map = {att.blob_id: att for att in attachments}

    for refund_request in refund_requests:
        reason_type = None
        refund_type = None
        reason_text = refund_request.reason

        if "|" in refund_request.reason:
            parts = refund_request.reason.split("|", 2)
            if len(parts) >= 3:
                reason_type = parts[0]
                refund_type = parts[1]
                reason_text = parts[2]

        refund_evidence = []
        if refund_request.evidence_files:
            try:
                evidence_file_ids = json.loads(refund_request.evidence_files)
                for file_id in evidence_file_ids:
                    att = attachment_map.get(file_id)
                    if att:
                        refund_evidence.append({
                            "type": att.attachment_type,
                            "url": att.url,
                            "file_id": att.blob_id
                        })
            except Exception as e:
                logger.warning(f"解析退款证据附件失败: {e}")

        timeline_items.append({
            "type": "refund_request",
            "title": "退款申请",
            "description": reason_text,
            "reason_type": reason_type,
            "refund_type": refund_type,
            "refund_amount": float(refund_request.refund_amount) if refund_request.refund_amount else None,
            "status": refund_request.status,
            "timestamp": refund_request.created_at.isoformat() if refund_request.created_at else None,
            "actor": "poster",
            "evidence": refund_evidence,
            "refund_request_id": refund_request.id
        })

        # 4. 反驳时间线（如果有）
        if refund_request.rebuttal_text:
            rebuttal_evidence = []
            if refund_request.rebuttal_evidence_files:
                try:
                    rebuttal_file_ids = json.loads(refund_request.rebuttal_evidence_files)
                    for file_id in rebuttal_file_ids:
                        att = attachment_map.get(file_id)
                        if att:
                            rebuttal_evidence.append({
                                "type": att.attachment_type,
                                "url": att.url,
                                "file_id": att.blob_id
                            })
                except Exception as e:
                    logger.warning(f"解析反驳证据附件失败: {e}")

            timeline_items.append({
                "type": "rebuttal",
                "title": "接单者反驳",
                "description": refund_request.rebuttal_text,
                "timestamp": refund_request.rebuttal_submitted_at.isoformat() if refund_request.rebuttal_submitted_at else None,
                "actor": "taker",
                "evidence": rebuttal_evidence,
                "refund_request_id": refund_request.id
            })

        # 5. 管理员裁定时间线（如果有）
        if refund_request.reviewed_at:
            reviewer_name = None
            if refund_request.reviewed_by:
                reviewer = crud.get_user_by_id(db, refund_request.reviewed_by)
                if reviewer:
                    reviewer_name = reviewer.name

            timeline_items.append({
                "type": "admin_review",
                "title": "管理员裁定",
                "description": refund_request.admin_comment or f"管理员已{refund_request.status}退款申请",
                "status": refund_request.status,
                "timestamp": refund_request.reviewed_at.isoformat() if refund_request.reviewed_at else None,
                "actor": "admin",
                "reviewer_name": reviewer_name,
                "refund_request_id": refund_request.id
            })

    # 6. 任务争议时间线（如果有）
    disputes = db.query(models.TaskDispute).filter(
        models.TaskDispute.task_id == task_id
    ).order_by(models.TaskDispute.created_at.asc()).all()

    for dispute in disputes:
        timeline_items.append({
            "type": "dispute",
            "title": "任务争议",
            "description": dispute.reason,
            "status": dispute.status,
            "timestamp": dispute.created_at.isoformat() if dispute.created_at else None,
            "actor": "poster",
            "dispute_id": dispute.id
        })

        # 如果有管理员处理结果
        if dispute.resolved_at:
            resolver_name = None
            if dispute.resolved_by:
                resolver = crud.get_user_by_id(db, dispute.resolved_by)
                if resolver:
                    resolver_name = resolver.name

            timeline_items.append({
                "type": "dispute_resolution",
                "title": "争议处理结果",
                "description": dispute.resolution_note or f"争议已{dispute.status}",
                "status": dispute.status,
                "timestamp": dispute.resolved_at.isoformat() if dispute.resolved_at else None,
                "actor": "admin",
                "resolver_name": resolver_name,
                "dispute_id": dispute.id
            })

    # 按时间排序
    timeline_items.sort(key=lambda x: x.get("timestamp") or "")

    return {
        "task_id": task_id,
        "task_title": task.title,
        "timeline": timeline_items
    }


@router.get("/tasks/{task_id}/refund-history", response_model=List[schemas.RefundRequestOut])
def get_refund_history(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """获取任务的退款申请历史记录（所有退款申请）"""
    task = load_real_task_or_404_sync(db, task_id)
    # 发布者和接单人都可以查看退款历史
    uid = str(current_user.id)
    if str(task.poster_id) != uid and str(task.taker_id or "") != uid:
        raise HTTPException(status_code=404, detail="Task not found or no permission")

    refund_requests = db.query(models.RefundRequest).filter(
        models.RefundRequest.task_id == task_id,
    ).order_by(models.RefundRequest.created_at.desc()).all()

    if not refund_requests:
        return []

    # 获取任务信息（用于计算退款比例）
    task = crud.get_task(db, task_id)

    result_list = []
    for refund_request in refund_requests:
        # 处理证据文件（JSON数组转List）
        evidence_files = None
        if refund_request.evidence_files:
            import json
            try:
                evidence_files = json.loads(refund_request.evidence_files)
            except (json.JSONDecodeError, TypeError, ValueError) as e:
                logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
                evidence_files = []

        # 解析退款原因字段（格式：reason_type|refund_type|reason）
        reason_type = None
        refund_type = None
        reason_text = refund_request.reason
        refund_percentage = None

        if "|" in refund_request.reason:
            parts = refund_request.reason.split("|", 2)
            if len(parts) >= 3:
                reason_type = parts[0]
                refund_type = parts[1]
                reason_text = parts[2]

        # 计算退款比例（如果有任务金额和退款金额）
        if refund_request.refund_amount and task:
            task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
            if task_amount > 0:
                refund_percentage = float((refund_request.refund_amount / task_amount) * 100)

        # 处理反驳证据文件
        rebuttal_evidence_files = None
        if refund_request.rebuttal_evidence_files:
            try:
                rebuttal_evidence_files = json.loads(refund_request.rebuttal_evidence_files)
            except (json.JSONDecodeError, TypeError, ValueError) as e:
                logger.warning(f"解析反驳证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
                rebuttal_evidence_files = []

        # 创建输出对象
        from app.schemas import RefundRequestOut
        result_list.append(RefundRequestOut(
            id=refund_request.id,
            task_id=refund_request.task_id,
            poster_id=refund_request.poster_id,
            reason_type=reason_type,
            refund_type=refund_type,
            reason=reason_text,
            evidence_files=evidence_files,
            refund_amount=refund_request.refund_amount,
            refund_percentage=refund_percentage,
            status=refund_request.status,
            admin_comment=refund_request.admin_comment,
            reviewed_by=refund_request.reviewed_by,
            reviewed_at=refund_request.reviewed_at,
            refund_intent_id=refund_request.refund_intent_id,
            refund_transfer_id=refund_request.refund_transfer_id,
            processed_at=refund_request.processed_at,
            completed_at=refund_request.completed_at,
            rebuttal_text=refund_request.rebuttal_text,
            rebuttal_evidence_files=rebuttal_evidence_files,
            rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
            rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
            created_at=refund_request.created_at,
            updated_at=refund_request.updated_at,
        ))

    return result_list


@router.post("/tasks/{task_id}/refund-request/{refund_id}/cancel", response_model=schemas.RefundRequestOut)
def cancel_refund_request(
    task_id: int,
    refund_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """撤销退款申请（只能在pending状态时撤销）"""
    from sqlalchemy import select
    from decimal import Decimal

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.task_id == task_id,
        models.RefundRequest.poster_id == current_user.id,
        models.RefundRequest.status == "pending"  # 只能撤销pending状态的申请
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()

    if not refund_request:
        # 检查是否存在但状态不是pending
        existing = db.query(models.RefundRequest).filter(
            models.RefundRequest.id == refund_id,
            models.RefundRequest.task_id == task_id,
            models.RefundRequest.poster_id == current_user.id
        ).first()
        if existing:
            raise HTTPException(
                status_code=400,
                detail=f"退款申请状态不正确，无法撤销。当前状态: {existing.status}。只有待审核（pending）状态的退款申请可以撤销。"
            )
        raise HTTPException(status_code=404, detail="Refund request not found")

    # 更新退款申请状态为cancelled
    refund_request.status = "cancelled"
    refund_request.updated_at = get_utc_time()

    # 获取任务信息
    task = crud.get_task(db, task_id)

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json

        poster_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{poster_name} 已撤销退款申请"
        content_en = f"{poster_name} has cancelled the refund request"

        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_request_cancelled",
                "refund_request_id": refund_request.id,
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")

    db.commit()
    db.refresh(refund_request)

    # 处理输出格式（解析reason字段等）
    evidence_files = None
    if refund_request.evidence_files:
        import json
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []

    # 解析退款原因字段
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None

    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]

    # 计算退款比例
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)

    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=_safe_json_loads(refund_request.rebuttal_evidence_files) if refund_request.rebuttal_evidence_files else None,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at,
    )


@router.post("/tasks/{task_id}/refund-request/{refund_id}/rebuttal", response_model=schemas.RefundRequestOut)
def submit_refund_rebuttal(
    task_id: int,
    refund_id: int,
    rebuttal_data: schemas.RefundRequestRebuttal,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    接单者提交退款申请的反驳
    允许接单者上传完成证据和文字说明来反驳退款申请
    """
    from sqlalchemy import select
    from decimal import Decimal
    import json

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
    refund_query = select(models.RefundRequest).where(
        models.RefundRequest.id == refund_id,
        models.RefundRequest.task_id == task_id
    ).with_for_update()
    refund_result = db.execute(refund_query)
    refund_request = refund_result.scalar_one_or_none()

    if not refund_request:
        raise HTTPException(status_code=404, detail="Refund request not found")

    # 获取任务
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 验证用户是接单者
    if not task.taker_id or task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the task taker can submit a rebuttal")

    # 验证退款申请状态：只有在pending状态时才能提交反驳
    if refund_request.status != "pending":
        raise HTTPException(
            status_code=400,
            detail=f"只能对pending状态的退款申请提交反驳。当前状态: {refund_request.status}"
        )

    # 检查是否已经提交过反驳
    if refund_request.rebuttal_submitted_at is not None:
        raise HTTPException(
            status_code=400,
            detail="您已经提交过反驳，无法重复提交"
        )

    # 验证证据文件数量（最多5个）
    validated_evidence_files = []
    if rebuttal_data.evidence_files:
        if len(rebuttal_data.evidence_files) > 5:
            raise HTTPException(
                status_code=400,
                detail="证据文件数量不能超过5个"
            )

        from app.models import MessageAttachment
        from app.file_system import PrivateFileSystem
        from app.file_utils import is_safe_file_id

        file_system = PrivateFileSystem()
        for file_id in rebuttal_data.evidence_files:
            # 🔒 安全检查：防止路径遍历攻击
            if not is_safe_file_id(file_id):
                logger.warning(f"文件ID包含非法字符，跳过: {file_id[:50]}")
                continue
            try:
                # 检查文件是否存在于MessageAttachment中，且与当前任务相关
                attachment = db.query(MessageAttachment).filter(
                    MessageAttachment.blob_id == file_id
                ).first()

                if attachment:
                    # 通过附件找到消息，验证是否属于当前任务
                    from app.models import Message
                    task_message = db.query(Message).filter(
                        Message.id == attachment.message_id,
                        Message.task_id == task_id
                    ).first()

                    if task_message:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不属于任务 {task_id}，跳过")
                else:
                    # 检查文件是否存在于任务文件夹中
                    task_dir = file_system.base_dir / "tasks" / str(task_id)
                    file_exists = False
                    if task_dir.exists():
                        for ext_file in task_dir.glob(f"{file_id}.*"):
                            if ext_file.is_file():
                                file_exists = True
                                break

                    if file_exists:
                        validated_evidence_files.append(file_id)
                    else:
                        logger.warning(f"文件 {file_id} 不存在或不属于任务 {task_id}，跳过")
            except Exception as file_error:
                logger.warning(f"验证文件 {file_id} 时发生错误: {file_error}，跳过")

    # 处理证据文件（JSON数组）
    rebuttal_evidence_files_json = None
    if validated_evidence_files:
        rebuttal_evidence_files_json = json.dumps(validated_evidence_files)

    # 更新退款申请记录
    refund_request.rebuttal_text = rebuttal_data.rebuttal_text
    refund_request.rebuttal_evidence_files = rebuttal_evidence_files_json
    refund_request.rebuttal_submitted_at = get_utc_time()
    refund_request.rebuttal_submitted_by = current_user.id
    refund_request.updated_at = get_utc_time()

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        import json

        taker_name = current_user.name or f"用户{current_user.id}"
        content_zh = f"{taker_name} 提交了反驳证据：{rebuttal_data.rebuttal_text[:100]}"
        content_en = f"{taker_name} has submitted rebuttal evidence: {rebuttal_data.rebuttal_text[:100]}"

        system_message = Message(
            sender_id=None,  # 系统消息
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({
                "system_action": "refund_rebuttal_submitted",
                "refund_request_id": refund_request.id,
                "content_en": content_en
            }),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()

        # 如果有证据文件，创建附件
        if validated_evidence_files:
            from app.models import MessageAttachment
            from app.file_system import PrivateFileSystem

            file_system = PrivateFileSystem()
            for file_id in validated_evidence_files:
                try:
                    # 生成文件访问URL
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"

                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",
                        url=file_url,
                        blob_id=file_id,
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
    except Exception as e:
        logger.error(f"Failed to send system message: {e}")

    # 通知发布者和管理员（后台任务）
    try:
        # 通知发布者
        crud.create_notification(
            db=db,
            user_id=task.poster_id,
            type="refund_rebuttal",
            title="收到反驳证据",
            content=f"任务「{task.title}」的接单者提交了反驳证据，请查看详情。",
            related_id=str(task_id),
            related_type="task_id",
            auto_commit=False
        )

        # 通知管理员（后台任务）
        if background_tasks:
            try:
                from app.task_notifications import send_refund_rebuttal_notification_to_admin
                send_refund_rebuttal_notification_to_admin(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    refund_request=refund_request,
                    taker=current_user
                )
            except Exception as e:
                logger.error(f"Failed to send rebuttal notification to admin: {e}")
    except Exception as e:
        logger.error(f"Failed to send notifications: {e}")

    db.commit()
    db.refresh(refund_request)

    # 处理输出格式（解析reason字段等）
    evidence_files = None
    if refund_request.evidence_files:
        try:
            evidence_files = json.loads(refund_request.evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析退款请求证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            evidence_files = []

    # 处理反驳证据文件
    rebuttal_evidence_files = None
    if refund_request.rebuttal_evidence_files:
        try:
            rebuttal_evidence_files = json.loads(refund_request.rebuttal_evidence_files)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning(f"解析反驳证据文件JSON失败 (refund_request_id={refund_request.id}): {e}")
            rebuttal_evidence_files = []

    # 解析退款原因字段
    reason_type = None
    refund_type = None
    reason_text = refund_request.reason
    refund_percentage = None

    if "|" in refund_request.reason:
        parts = refund_request.reason.split("|", 2)
        if len(parts) >= 3:
            reason_type = parts[0]
            refund_type = parts[1]
            reason_text = parts[2]

    # 计算退款比例
    if refund_request.refund_amount and task:
        task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
        if task_amount > 0:
            refund_percentage = float((refund_request.refund_amount / task_amount) * 100)

    from app.schemas import RefundRequestOut
    return RefundRequestOut(
        id=refund_request.id,
        task_id=refund_request.task_id,
        poster_id=refund_request.poster_id,
        reason_type=reason_type,
        refund_type=refund_type,
        reason=reason_text,
        evidence_files=evidence_files,
        refund_amount=refund_request.refund_amount,
        refund_percentage=refund_percentage,
        status=refund_request.status,
        admin_comment=refund_request.admin_comment,
        reviewed_by=refund_request.reviewed_by,
        reviewed_at=refund_request.reviewed_at,
        refund_intent_id=refund_request.refund_intent_id,
        refund_transfer_id=refund_request.refund_transfer_id,
        processed_at=refund_request.processed_at,
        completed_at=refund_request.completed_at,
        rebuttal_text=refund_request.rebuttal_text,
        rebuttal_evidence_files=rebuttal_evidence_files,
        rebuttal_submitted_at=refund_request.rebuttal_submitted_at,
        rebuttal_submitted_by=refund_request.rebuttal_submitted_by,
        created_at=refund_request.created_at,
        updated_at=refund_request.updated_at
    )


@router.post("/tasks/{task_id}/confirm_completion", response_model=schemas.TaskOut)
def confirm_task_completion(
    task_id: int,
    evidence_files: Optional[List[str]] = Body(None, description="完成证据文件ID列表（可选）"),
    partial_transfer: Optional[schemas.PartialTransferRequest] = Body(None, description="部分转账请求（可选，用于部分完成的任务）"),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """任务发布者确认任务完成，可上传完成证据文件"""
    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发确认
    locked_task_query = select(models.Task).where(
        models.Task.id == task_id
    ).with_for_update()
    task = db.execute(locked_task_query).scalar_one_or_none()

    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission")

    # ⚠️ 安全修复：更严格的状态检查，防止绕过支付
    # 检查任务状态：只允许 pending_confirmation 状态，或已支付且正常进行中的任务
    if task.status != "pending_confirmation":
        # 只允许 in_progress 状态的任务（已支付且正常进行中）
        # 不允许 pending_payment 状态的任务确认完成（即使 is_paid 被错误设置）
        if task.is_paid == 1 and task.taker_id and task.status == "in_progress":
            logger.warning(
                f"⚠️ 任务 {task_id} 状态为 {task.status}，但已支付且有接受者，允许确认完成"
            )
            # 将状态更新为 pending_confirmation 以便后续处理
            task.status = "pending_confirmation"
            db.flush()  # flush而不是commit，保持在同一事务中
        else:
            # 如果 is_paid 被错误设置，记录安全警告
            if task.is_paid == 1 and task.status == "pending_payment":
                logger.error(
                    f"🔴 安全警告：任务 {task_id} 状态为 pending_payment 但 is_paid=1，"
                    f"可能存在数据不一致或安全漏洞"
                )
            raise HTTPException(
                status_code=400,
                detail=f"任务状态不正确，无法确认完成。当前状态: {task.status}, is_paid: {task.is_paid}。"
                      f"任务必须处于 pending_confirmation 状态，或已支付且处于 in_progress 状态。"
            )

    # 将任务状态改为已完成
    task.status = "completed"
    task.confirmed_at = get_utc_time()  # 记录确认时间
    task.auto_confirmed = 0  # 手动确认
    # 付费任务：is_confirmed 在钱包入账成功后才设为 1，避免入账失败时任务被跳过
    # 免费任务：直接确认
    if not (task.is_paid == 1 and task.taker_id and task.escrow_amount and task.escrow_amount > 0):
        task.is_confirmed = 1
    # 更新可靠度画像
    try:
        from app.services.reliability_calculator import on_task_completed
        was_on_time = bool(task.deadline and task.completed_at and task.completed_at <= task.deadline)
        on_task_completed(db, task.taker_id, was_on_time)
    except Exception as e:
        logger.warning(f"更新可靠度失败(task_completed): {e}")
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"确认任务完成提交失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="确认任务完成失败，请重试")
    crud.add_task_history(db, task_id, current_user.id, "confirmed_completion")
    db.refresh(task)

    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（确认任务完成）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message
        from app.utils.notification_templates import get_notification_texts
        import json

        poster_name = current_user.name or f"用户{current_user.id}"
        _, content_zh, _, content_en = get_notification_texts(
            "task_confirmed",
            poster_name=poster_name,
            task_title=task.title
        )
        # 如果没有对应的模板，使用默认文本
        if not content_zh:
            content_zh = f"发布者 {poster_name} 已确认任务完成。"
        if not content_en:
            content_en = f"Poster {poster_name} has confirmed task completion."

        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "task_confirmed_by_poster", "content_en": content_en}),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID

        # 如果有完成证据文件，创建附件
        if evidence_files:
            from app.models import MessageAttachment
            for file_id in evidence_files:
                # 生成文件访问URL（使用私有文件系统）
                from app.file_system import PrivateFileSystem
                file_system = PrivateFileSystem()
                try:
                    # 生成访问URL（需要用户ID和任务参与者）
                    participants = [task.poster_id]
                    if task.taker_id:
                        participants.append(task.taker_id)
                    access_token = file_system.generate_access_token(
                        file_id=file_id,
                        user_id=current_user.id,
                        chat_participants=participants
                    )
                    file_url = f"/api/private-file?file={file_id}&token={access_token}"

                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="file",  # 可能是文件，不只是图片
                        url=file_url,
                        blob_id=file_id,  # 存储文件ID
                        meta=json.dumps({"file_id": file_id}),
                        created_at=get_utc_time()
                    )
                    db.add(attachment)
                except Exception as file_error:
                    logger.warning(f"Failed to create attachment for file {file_id}: {file_error}")
                    # 即使文件处理失败，也继续处理其他文件

        db.commit()
    except Exception as e:
        db.rollback()
        logger.warning(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务确认流程

    # 查询一次 taker，后续通知/奖励/入账复用
    taker = crud.get_user_by_id(db, task.taker_id) if task.taker_id else None

    # 发送任务确认完成通知和邮件给接收者
    if taker:
        try:
            from app.task_notifications import send_task_confirmation_notification
            from fastapi import BackgroundTasks

            # 确保 background_tasks 存在，如果为 None 则创建新实例
            if background_tasks is None:
                background_tasks = BackgroundTasks()

            if taker:
                send_task_confirmation_notification(
                    db=db,
                    background_tasks=background_tasks,
                    task=task,
                    taker=taker
                )
        except Exception as e:
            logger.warning(f"Failed to send task confirmation notification: {e}")
            # 通知发送失败不影响任务确认流程

    # 自动更新相关用户的统计信息（后台执行，不阻塞响应）
    def _bg_update_stats(poster_id, taker_id):
        from app.database import SessionLocal
        bg_db = SessionLocal()
        try:
            crud.update_user_statistics(bg_db, poster_id)
            if taker_id:
                crud.update_user_statistics(bg_db, taker_id)
        except Exception as e:
            logger.warning(f"后台更新用户统计失败: {e}")
        finally:
            bg_db.close()
    if background_tasks is None:
        background_tasks = BackgroundTasks()
    background_tasks.add_task(_bg_update_stats, task.poster_id, task.taker_id)

    # 🔒 使用 SAVEPOINT 包装所有奖励发放操作，确保原子性
    # 任务完成时自动发放积分奖励（平台赠送，非任务报酬）
    if task.taker_id:
        rewards_savepoint = db.begin_nested()
        try:
            from app.coupon_points_crud import (
                get_or_create_points_account,
                add_points_transaction
            )
            from app.crud import get_system_setting
            from datetime import datetime, timezone as tz, timedelta
            import uuid

            # 获取任务完成奖励积分（优先使用任务级别的积分，否则使用系统设置，默认0）
            points_amount = 0
            if hasattr(task, 'points_reward') and task.points_reward is not None:
                # 使用任务级别的积分设置
                points_amount = int(task.points_reward)
            else:
                # 使用系统设置（默认0）
                task_bonus_setting = get_system_setting(db, "points_task_complete_bonus")
                points_amount = int(task_bonus_setting.setting_value) if task_bonus_setting else 0  # 默认0积分

            if points_amount > 0:
                # 生成批次ID（季度格式：2025Q1-COMP）
                now = get_utc_time()
                quarter = (now.month - 1) // 3 + 1
                batch_id = f"{now.year}Q{quarter}-COMP"

                # 计算过期时间（如果启用积分过期）
                expire_days_setting = get_system_setting(db, "points_expire_days")
                expire_days = int(expire_days_setting.setting_value) if expire_days_setting else 0
                expires_at = None
                if expire_days > 0:
                    expires_at = now + timedelta(days=expire_days)

                # 生成幂等键（防止重复发放）- 必须是确定性的以确保幂等性
                idempotency_key = f"task_complete_{task_id}_{task.taker_id}"

                # 检查是否已发放（通过幂等键）
                from app.models import PointsTransaction
                existing = db.query(PointsTransaction).filter(
                    PointsTransaction.idempotency_key == idempotency_key
                ).first()

                if not existing:
                    # 发放积分奖励
                    add_points_transaction(
                        db,
                        task.taker_id,
                        type="earn",
                        amount=points_amount,
                        source="task_complete_bonus",
                        related_id=task_id,
                        related_type="task",
                        description=f"完成任务 #{task_id} 获得平台赠送积分（非任务报酬）",
                        batch_id=batch_id,
                        expires_at=expires_at,
                        idempotency_key=idempotency_key
                    )

                    logger.info(f"任务完成积分奖励已发放: 用户 {task.taker_id}, 任务 {task_id}, 积分 {points_amount}")
            rewards_savepoint.commit()
        except Exception as e:
            rewards_savepoint.rollback()
            logger.error(f"发放任务完成积分奖励失败，已回滚SAVEPOINT: {e}", exc_info=True)
            # 积分发放失败不影响任务完成流程

    # 检查任务是否关联活动，如果活动设置了奖励申请者，则发放奖励（积分和/或现金）
    if task.taker_id and task.parent_activity_id:
        activity_rewards_savepoint = db.begin_nested()
        try:
            from app.coupon_points_crud import add_points_transaction
            from app.models import Activity
            import stripe
            import os

            # 查询关联的活动
            activity = db.query(Activity).filter(Activity.id == task.parent_activity_id).first()

            if activity and activity.reward_applicants:
                # 活动设置了奖励申请者

                # 1. 发放积分奖励（如果有）
                if activity.applicant_points_reward and activity.applicant_points_reward > 0:
                    points_to_give = activity.applicant_points_reward

                    # 生成幂等键（防止重复发放）
                    activity_reward_idempotency_key = f"activity_reward_points_{task.parent_activity_id}_{task_id}_{task.taker_id}"

                    # 检查是否已发放（通过幂等键）
                    from app.models import PointsTransaction
                    existing_activity_reward = db.query(PointsTransaction).filter(
                        PointsTransaction.idempotency_key == activity_reward_idempotency_key
                    ).first()

                    if not existing_activity_reward:
                        # 发放活动奖励积分给申请者
                        add_points_transaction(
                            db,
                            task.taker_id,
                            type="earn",
                            amount=points_to_give,
                            source="activity_applicant_reward",
                            related_id=task.parent_activity_id,
                            related_type="activity",
                            description=f"完成活动 #{task.parent_activity_id} 任务获得达人奖励积分",
                            idempotency_key=activity_reward_idempotency_key
                        )

                        # 更新活动的已发放积分总额
                        activity.distributed_points_total = (activity.distributed_points_total or 0) + points_to_give

                        logger.info(f"活动奖励积分已发放: 用户 {task.taker_id}, 活动 {task.parent_activity_id}, 积分 {points_to_give}")

                        # 发送通知给申请者
                        try:
                            crud.create_notification(
                                db=db,
                                user_id=task.taker_id,
                                type="activity_reward_points",
                                title="活动奖励积分已发放",
                                content=f"您完成活动「{activity.title}」的任务，获得 {points_to_give} 积分奖励",
                                related_id=str(task.parent_activity_id),
                                auto_commit=False
                            )

                            # 发送推送通知
                            try:
                                from app.push_notification_service import send_push_notification
                                send_push_notification(
                                    db=db,
                                    user_id=task.taker_id,
                                    notification_type="activity_reward_points",
                                    data={"activity_id": task.parent_activity_id, "task_id": task_id, "points": points_to_give},
                                    template_vars={"activity_title": activity.title, "points": points_to_give}
                                )
                            except Exception as e:
                                logger.warning(f"发送活动奖励积分推送通知失败: {e}")
                        except Exception as e:
                            logger.warning(f"创建活动奖励积分通知失败: {e}")

                # 2. 发放现金奖励（如果有）
                if activity.applicant_reward_amount and activity.applicant_reward_amount > 0:
                    cash_amount = float(activity.applicant_reward_amount)

                    # 生成幂等键（防止重复发放）
                    activity_cash_reward_idempotency_key = f"activity_reward_cash_{task.parent_activity_id}_{task_id}_{task.taker_id}"

                    # 检查是否已发放（通过检查 PaymentTransfer 记录）
                    from app.models import PaymentTransfer
                    existing_cash_reward = db.query(PaymentTransfer).filter(
                        PaymentTransfer.idempotency_key == activity_cash_reward_idempotency_key
                    ).first()

                    if not existing_cash_reward and taker:
                        try:
                            from app.wallet_service import credit_wallet
                            from decimal import Decimal

                            wallet_tx = credit_wallet(
                                db,
                                user_id=taker.id,
                                amount=Decimal(str(cash_amount)),
                                source="activity_cash_reward",
                                related_id=str(task_id),
                                related_type="task",
                                description=f"活动 #{task.parent_activity_id} 现金奖励",
                                currency=(task.currency or "GBP").upper(),
                                idempotency_key=activity_cash_reward_idempotency_key,
                            )

                            if wallet_tx:
                                logger.info(f"活动现金奖励已入账钱包: 用户 {task.taker_id}, 活动 {task.parent_activity_id}, 金额 £{cash_amount:.2f}")
                            else:
                                logger.info(f"活动现金奖励已处理过（幂等跳过）: task_id={task_id}")

                            # 发送通知给申请者
                            try:
                                crud.create_notification(
                                    db=db,
                                    user_id=task.taker_id,
                                    type="activity_reward_cash",
                                    title="活动现金奖励已发放",
                                    content=f"您完成活动「{activity.title}」的任务，获得 £{cash_amount:.2f} 现金奖励（已入账钱包）",
                                    related_id=str(task.parent_activity_id),
                                    auto_commit=False
                                )

                                try:
                                    from app.push_notification_service import send_push_notification
                                    send_push_notification(
                                        db=db,
                                        user_id=task.taker_id,
                                        notification_type="activity_reward_cash",
                                        data={"activity_id": task.parent_activity_id, "task_id": task_id, "amount": cash_amount},
                                        template_vars={"activity_title": activity.title, "amount": cash_amount}
                                    )
                                except Exception as e:
                                    logger.warning(f"发送活动现金奖励推送通知失败: {e}")
                            except Exception as e:
                                logger.warning(f"创建活动现金奖励通知失败: {e}")
                        except Exception as e:
                            logger.error(f"发放活动现金奖励失败: {e}", exc_info=True)
                            # 现金奖励发放失败不影响任务完成流程
                    elif not existing_cash_reward and not taker:
                        logger.warning(f"用户 {task.taker_id} 不存在，无法发放现金奖励")

                # 提交SAVEPOINT内的所有奖励发放更改
                activity_rewards_savepoint.commit()

        except Exception as e:
            activity_rewards_savepoint.rollback()
            logger.error(f"发放活动奖励失败，已回滚SAVEPOINT: {e}", exc_info=True)
            # 奖励发放失败不影响任务完成流程

    # 如果任务已支付，将托管金额转给接受人
    # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
    if task.is_paid == 1 and task.taker_id and task.escrow_amount > 0:
        payout_savepoint = db.begin_nested()
        try:
            from decimal import Decimal

            net_amount = Decimal(str(task.escrow_amount))
            currency = (task.currency or "GBP").upper()

            # Determine gross amount: agreed_reward > base_reward > reward (fallback to net)
            _raw_gross = task.agreed_reward if task.agreed_reward is not None else (
                task.base_reward if task.base_reward is not None else task.reward
            )
            gross_amount = Decimal(str(_raw_gross)) if _raw_gross is not None else net_amount
            fee_amount = gross_amount - net_amount if gross_amount > net_amount else Decimal("0")

            # Determine source: flea market sale or task earning
            source = "flea_market_sale" if getattr(task, "task_source", "normal") in ("flea_market", "flea_market_rental") else "task_earning"

            idempotency_key = f"earning:task:{task.id}:user:{task.taker_id}"

            # Team-aware destination: 团队任务 → experts.stripe_account_id,
            # 个人任务 → taker.stripe_account_id (保持原行为)
            # spec §3.2 (v2 — payout site team-awareness)
            from app.services.expert_task_resolver import resolve_payout_destination
            is_team_task = bool(task.taker_expert_id)
            destination_stripe_id = resolve_payout_destination(db, task)

            if destination_stripe_id:
                # 有 Stripe Connect 账户 → 尝试直接转账
                amount_minor = int(net_amount * 100)  # 转为最小货币单位（便士/分）
                try:
                    transfer = stripe.Transfer.create(
                        amount=amount_minor,
                        currency=currency.lower(),
                        destination=destination_stripe_id,
                        description=f"Task #{task.id} payout",
                        metadata={
                            "task_id": str(task.id),
                            "taker_id": str(task.taker_id),
                            "taker_expert_id": str(task.taker_expert_id) if task.taker_expert_id else "",
                            "source": source,
                        },
                        idempotency_key=idempotency_key,
                    )
                    logger.info(
                        f"✅ 任务 {task_id} 奖励 £{net_amount:.2f} 已直接转账至 "
                        f"{'团队' if is_team_task else '用户'} "
                        f"Stripe 账户 {destination_stripe_id} (transfer={transfer.id})"
                    )
                except stripe.error.StripeError as stripe_err:
                    if is_team_task:
                        # 团队任务：不回退钱包，资金只能流向团队 Stripe
                        logger.error(
                            f"任务 {task_id} 团队 Stripe Transfer 失败，不回退钱包: {stripe_err}"
                        )
                        payout_savepoint.rollback()
                        raise HTTPException(status_code=500, detail={
                            "error_code": "team_payout_failed",
                            "message": f"Team Stripe transfer failed: {stripe_err}",
                        })
                    # 个人任务：Stripe 明确拒绝 → 回退到钱包入账（不会双重支付）
                    logger.warning(
                        f"任务 {task_id} Stripe Transfer 被拒绝，回退到钱包入账: {stripe_err}"
                    )
                    from app.wallet_service import credit_wallet
                    credit_wallet(
                        db=db,
                        user_id=task.taker_id,
                        amount=net_amount,
                        source=source,
                        related_id=str(task.id),
                        related_type="task",
                        description=f"任务 #{task.id} 奖励（Stripe转账失败，入钱包）",
                        fee_amount=fee_amount,
                        gross_amount=gross_amount,
                        idempotency_key=idempotency_key,
                        currency=currency,
                    )
                except Exception as unexpected_err:
                    # 网络超时等不确定异常 → 不回退钱包（Stripe 可能已成功）
                    # 抛出让外层 savepoint rollback，由 auto_transfer 定时任务后续处理
                    logger.error(
                        f"任务 {task_id} Stripe Transfer 异常（可能已成功），不回退钱包: {unexpected_err}"
                    )
                    raise
            else:
                if is_team_task:
                    # 团队任务不应走到此分支（resolve_payout_destination 会抛 HTTPException）
                    # 防御性编程：若到这里，说明 helper 返回了 None 但没抛异常，视为错误
                    logger.error(
                        f"任务 {task_id} 团队任务无 Stripe 目的地，不回退钱包"
                    )
                    payout_savepoint.rollback()
                    raise HTTPException(status_code=500, detail={
                        "error_code": "team_payout_failed",
                        "message": "Team task has no Stripe destination",
                    })
                # 个人任务无 Stripe Connect 账户 → 入本地钱包（用户后续可绑定 Stripe 后提现）
                from app.wallet_service import credit_wallet
                credit_wallet(
                    db=db,
                    user_id=task.taker_id,
                    amount=net_amount,
                    source=source,
                    related_id=str(task.id),
                    related_type="task",
                    description=f"任务 #{task.id} 奖励",
                    fee_amount=fee_amount,
                    gross_amount=gross_amount,
                    idempotency_key=idempotency_key,
                    currency=currency,
                )
                logger.info(
                    f"✅ 任务 {task_id} 奖励 £{net_amount:.2f} 已记入用户 {task.taker_id} 本地钱包"
                    f"（用户无 Stripe Connect 账户）"
                )

            # Clear escrow and mark as paid
            task.escrow_amount = Decimal("0.00")
            task.paid_to_user_id = task.taker_id
            task.is_confirmed = 1

            payout_savepoint.commit()
        except HTTPException:
            # 团队任务 payout 失败 → 抛给客户端，不静默吞掉 (spec §3.2 v2)
            # savepoint 已在内部 rollback
            raise
        except Exception as e:
            payout_savepoint.rollback()
            logger.error(f"任务报酬支付失败 for task {task_id}: {e}", exc_info=True)
            # 支付失败不影响任务完成确认流程（仅个人任务路径）

    # 提交所有 savepoint 内的变更（积分奖励、活动奖励、钱包入账）
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"提交奖励/钱包变更失败 for task {task_id}: {e}", exc_info=True)

    return task

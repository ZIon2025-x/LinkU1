import asyncio
import json
import logging
import os
import uuid
from decimal import Decimal
from pathlib import Path
from urllib.parse import quote

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.security import OAuth2PasswordRequestForm, HTTPAuthorizationCredentials
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.database import get_async_db
from app.rate_limiting import rate_limit
from app.deps import get_current_user_secure_sync_csrf
from app.performance_monitor import measure_api_performance
from app.cache import cache_response
from app.push_notification_service import send_push_notification
from app.task_recommendation import get_task_recommendations, calculate_task_match_score
from app.user_behavior_tracker import UserBehaviorTracker, record_task_view, record_task_click
from app.recommendation_monitor import get_recommendation_metrics, RecommendationMonitor
from app.utils.translation_metrics import TranslationTimer
from app.utils.task_guards import load_real_task_or_404_sync

logger = logging.getLogger(__name__)
import os
from datetime import datetime, timedelta, time, timezone
from app.utils.time_utils import get_utc_time, format_iso_utc

import stripe
from pydantic import BaseModel, Field
from sqlalchemy import or_, and_, select, func, update

from app.security import verify_password
from app.security import create_access_token
from app.deps import (
    check_admin_user_status,
    check_user_status,
    get_current_admin_user,
    get_current_customer_service_or_user,
    get_current_user_secure_sync_csrf,
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_db,
    get_sync_db,
    get_async_db_dependency,
)
from app.separate_auth_deps import (
    get_current_admin,
    get_current_service,
    get_current_admin_or_service,
    get_current_user,
    get_current_admin_optional,
    get_current_service_optional,
    get_current_user_optional as get_current_user_optional_new,
)
from app.security import sync_cookie_bearer
from app.email_utils import (
    confirm_reset_token,
    confirm_token,
    generate_confirmation_token,
    generate_reset_token,
    send_confirmation_email,
    send_reset_email,
    send_task_update_email,
    send_email_with_attachment,
)
from app.models import CustomerService, User
from app.config import Config

# 注意：Stripe API配置在应用启动时通过stripe_config模块统一配置（带超时）

router = APIRouter()


def _payment_method_types_for_currency(currency: str) -> list:
    """根据货币动态返回 Stripe 支持的支付方式列表"""
    c = currency.lower()
    methods = ["card"]
    if c in ("gbp", "cny"):
        methods.extend(["wechat_pay", "alipay"])
    return methods


def _safe_json_loads(s, default=None):
    """安全的 JSON 解析，失败时返回默认值而非抛出异常"""
    if not s:
        return default
    try:
        return json.loads(s)
    except (json.JSONDecodeError, TypeError, ValueError):
        return default


from app.file_utils import _resolve_legacy_private_file_path  # noqa: F401  (re-export)


async def _translate_missing_tasks_async(
    db: Session,
    task_ids: List[int],
    field_type: str,
    target_lang: str,
) -> None:
    """后台补齐缺失翻译（best-effort，不阻塞主请求）。"""
    if not task_ids:
        return

    from app.utils.translation_prefetch import prefetch_task_by_id

    db_gen = None
    worker_db = db
    using_fresh_session = False

    # 优先使用独立会话，避免请求结束后 session 失效。
    try:
        db_gen = get_db()
        worker_db = next(db_gen)
        using_fresh_session = True
    except Exception as e:
        logger.debug("后台翻译获取独立数据库会话失败，回退当前会话: %s", e)

    try:
        for task_id in task_ids:
            try:
                await prefetch_task_by_id(worker_db, task_id, target_languages=[target_lang])
            except Exception as e:
                logger.warning(
                    "后台翻译任务失败: task_id=%s, field=%s, target=%s, error=%s",
                    task_id,
                    field_type,
                    target_lang,
                    e,
                )
    finally:
        if using_fresh_session and db_gen is not None:
            try:
                db_gen.close()
            except Exception:
                try:
                    worker_db.close()
                except Exception:
                    pass


def _trigger_background_translation_prefetch(
    task_ids: List[int],
    target_languages: Optional[List[str]] = None,
    label: str = "后台翻译任务",
) -> None:
    """在线程中预翻译任务（best-effort，不阻塞主流程）。"""
    if not task_ids:
        return

    import threading
    from app.utils.translation_prefetch import prefetch_task_by_id

    targets = target_languages or ["en", "zh-CN"]

    def _worker():
        db_gen = None
        try:
            db_gen = get_db()
            sync_db = next(db_gen)
            try:
                for task_id in task_ids:
                    try:
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        try:
                            loop.run_until_complete(
                                prefetch_task_by_id(sync_db, task_id, target_languages=targets)
                            )
                        finally:
                            loop.close()
                    except Exception as e:
                        logger.warning("%s %s 失败: %s", label, task_id, e)
            finally:
                try:
                    db_gen.close()
                except Exception:
                    try:
                        sync_db.close()
                    except Exception:
                        pass
        except Exception as e:
            logger.error("%s失败: %s", label, e)

    thread = threading.Thread(target=_worker, daemon=True)
    thread.start()




# 同步发布任务路由已禁用，使用异步版本
# @router.post("/tasks", response_model=schemas.TaskOut)
# @rate_limit("create_task")
# def create_task(
#     task: schemas.TaskCreate,
#     current_user=Depends(get_current_user_secure_sync_csrf),
#     db: Session = Depends(get_db),
# ):
#     # 检查用户是否为客服账号
#     if False:  # 普通用户不再有客服权限
#         raise HTTPException(status_code=403, detail="客服账号不能发布任务")
#
#     try:
#         db_task = crud.create_task(db, current_user.id, task)
#         # 手动序列化Task对象，避免关系字段问题
#         return {
#             "id": db_task.id,
#             "title": db_task.title,
#             "description": db_task.description,
#             "deadline": db_task.deadline,
#             "reward": db_task.reward,
#             "location": db_task.location,
#             "task_type": db_task.task_type,
#             "poster_id": db_task.poster_id,
#             "taker_id": db_task.taker_id,
#             "status": db_task.status,
#             "task_level": db_task.task_level,
#             "created_at": db_task.created_at,
#             "is_public": db_task.is_public
#         }
#     except Exception as e:
#         print(f"Error creating task: {e}")
#         raise HTTPException(status_code=500, detail=f"创建任务失败: {str(e)}")




# 同步任务列表路由已禁用，使用异步版本
# @router.get("/tasks")
# def list_tasks(
#     page: int = 1,
#     page_size: int = 20,
#     task_type: str = None,
#     location: str = None,
#     keyword: str = None,
#     sort_by: str = "latest",
#     db: Session = Depends(get_db),
# ):
#     skip = (page - 1) * page_size
#     tasks = crud.list_tasks(db, skip, page_size, task_type, location, keyword, sort_by)
#     total = crud.count_tasks(db, task_type, location, keyword)
#
#     return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}


def _request_lang_sync(request: Request, current_user: Optional[models.User]) -> str:
    """展示语言：登录用户用 language_preference，游客用 query lang 或 Accept-Language。与 async_routers._request_lang 一致。"""
    if current_user and (getattr(current_user, "language_preference", None) or "").strip().lower().startswith("zh"):
        return "zh"
    q = (request.query_params.get("lang") or "").strip().lower()
    if q in ("zh", "zh-cn", "zh_cn"):
        return "zh"
    accept = request.headers.get("accept-language") or ""
    for part in accept.split(","):
        part = part.split(";")[0].strip().lower()
        if part.startswith("zh"):
            return "zh"
        if part.startswith("en"):
            return "en"
    return "en"


# NOTE: 此同步版本已被 async_routers.py 中的异步版本取代。
# 保留代码但注释掉路由装饰器，避免 /api/tasks/{task_id} 路由重复注册。
# @router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def _get_task_detail_legacy(
    task_id: int,
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取任务详情 - 使用服务层缓存（避免装饰器重复创建）"""
    from app.services.task_service import TaskService
    from app.models import TaskApplication, TaskParticipant
    from sqlalchemy import and_
    from app.utils.task_activity_display import (
        ensure_task_title_for_lang_sync,
        ensure_task_description_for_lang_sync,
    )

    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 内容审核检查：被隐藏的任务只有发布者本人可以看到
    if not task.is_visible:
        if not current_user or str(current_user.id) != str(task.poster_id):
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
                    participant = db.query(TaskParticipant).filter(
                        and_(
                            TaskParticipant.task_id == task_id,
                            TaskParticipant.user_id == user_id_str,
                            TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    ).first()
                    is_participant = participant is not None
            
            if not is_poster and not is_taker and not is_participant:
                application = db.query(TaskApplication).filter(
                    and_(
                        TaskApplication.task_id == task_id,
                        TaskApplication.applicant_id == user_id_str
                    )
                ).first()
                is_applicant = application is not None
            
            # 咨询/服务类任务：服务所有者通过 expert_service_id 或 ServiceApplication 反查
            is_service_owner = False
            if not is_poster and not is_taker and not is_participant and not is_applicant:
                from app.models_expert import ExpertMember
                # 路径 1: task.expert_service_id → 服务表
                if task.expert_service_id:
                    svc = db.query(models.TaskExpertService).filter(
                        models.TaskExpertService.id == task.expert_service_id
                    ).first()
                    if svc:
                        if svc.user_id and str(svc.user_id) == user_id_str:
                            is_service_owner = True
                        elif svc.expert_id:
                            member = db.query(ExpertMember).filter(and_(
                                ExpertMember.expert_id == svc.expert_id,
                                ExpertMember.user_id == user_id_str,
                                ExpertMember.status == "active",
                            )).first()
                            if member:
                                is_service_owner = True

                # 路径 2: ServiceApplication.task_id 反查（兼容旧数据无 expert_service_id）
                if not is_service_owner:
                    app = db.query(models.ServiceApplication).filter(
                        models.ServiceApplication.task_id == task_id
                    ).first()
                    if app:
                        if app.service_owner_id and str(app.service_owner_id) == user_id_str:
                            is_service_owner = True
                        elif app.new_expert_id:
                            member = db.query(ExpertMember).filter(and_(
                                ExpertMember.expert_id == app.new_expert_id,
                                ExpertMember.user_id == user_id_str,
                                ExpertMember.status == "active",
                            )).first()
                            if member:
                                is_service_owner = True

            if not is_poster and not is_taker and not is_participant and not is_applicant and not is_service_owner:
                # 已完成/已取消的任务对外展示摘要（有利于 SEO），其他敏感状态仍返回 403
                if task.status in ("completed", "cancelled"):
                    _is_summary_only = True
                else:
                    raise HTTPException(status_code=403, detail="无权限查看此任务")
    
    # 未登录用户看摘要：返回公开字段（标题、描述、状态、类型、图片等），隐藏敏感字段
    if _is_summary_only:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
        setattr(task, "user_application_id", None)
        setattr(task, "completion_evidence", None)
        task.taker_id = None
        task.poster_id = None
        return schemas.TaskOut.from_orm(task, full_location_access=True)

    # 判断当前用户是否为任务相关人（发布者/接单者/参与者/申请者），决定是否返回完整地址和坐标
    _full_location_access = False
    if current_user:
        _uid = str(current_user.id)
        if task.status == "open":
            _full_location_access = task.poster_id is not None and str(task.poster_id) == _uid
        else:
            # 非 open 状态：复用上面已判断的变量
            _full_location_access = is_poster or is_taker or is_participant or is_applicant
    
    # view_count + 用户行为记录 移到后台任务，不阻塞响应
    user_id_for_bg = current_user.id if current_user else None
    ua_for_bg = request.headers.get("User-Agent", "") if hasattr(request, 'headers') else ""

    def _bg_view_count_and_track(t_id: int, uid, ua: str):
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        if redis_client:
            try:
                redis_client.incr(f"task:view_count:{t_id}")
            except Exception as e:
                logger.warning("Redis 增加任务浏览量失败, 回退到直写: %s", e)
                redis_client = None

        if not redis_client:
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

        if uid:
            from app.database import SessionLocal
            bg_db = SessionLocal()
            try:
                from app.user_behavior_tracker import UserBehaviorTracker
                tracker = UserBehaviorTracker(bg_db)
                ua_lower = ua.lower()
                if "mobile" in ua_lower or "android" in ua_lower or "iphone" in ua_lower:
                    device_type = "mobile"
                elif "tablet" in ua_lower or "ipad" in ua_lower:
                    device_type = "tablet"
                else:
                    device_type = "desktop"
                tracker.record_view(user_id=uid, task_id=t_id, device_type=device_type)
            except Exception as e:
                logger.warning(f"记录用户浏览行为失败: {e}")
            finally:
                bg_db.close()

    background_tasks.add_task(_bg_view_count_and_track, task_id, user_id_for_bg, ua_for_bg)
    
    # 按展示语言补齐双语（缺则翻译），放到后台任务避免阻塞
    lang = _request_lang_sync(request, current_user)
    needs_ensure = (
        (lang == "zh" and not getattr(task, "title_zh", None))
        or (lang == "en" and not getattr(task, "title_en", None))
        or (lang == "zh" and not getattr(task, "description_zh", None))
        or (lang == "en" and not getattr(task, "description_en", None))
    )
    if needs_ensure:
        def _bg_ensure_translation(t_id: int, target_lang: str):
            from app.database import SessionLocal
            bg_db = SessionLocal()
            try:
                bg_task = crud.get_task(bg_db, t_id)
                if bg_task:
                    ensure_task_title_for_lang_sync(bg_task, target_lang)
                    ensure_task_description_for_lang_sync(bg_task, target_lang)
                    bg_db.commit()
                    TaskService.invalidate_cache(t_id)
            except Exception as e:
                logger.warning(f"后台任务双语补齐失败 task_id=%s: %s", t_id, e)
                bg_db.rollback()
            finally:
                bg_db.close()
        background_tasks.add_task(_bg_ensure_translation, task_id, lang)

    # 直接使用已加载的 task ORM 对象构建响应，不再重复查询
    # 与活动详情一致：在详情响应中带上「当前用户是否已申请」及申请状态，便于客户端直接显示「已申请」状态
    if current_user:
        user_id_str = str(current_user.id)
        application = db.query(TaskApplication).filter(
            and_(
                TaskApplication.task_id == task_id,
                TaskApplication.applicant_id == user_id_str,
            )
        ).first()
        if application:
            setattr(task, "has_applied", True)
            setattr(task, "user_application_status", application.status)
            setattr(task, "user_application_id", application.id)
        else:
            setattr(task, "has_applied", False)
            setattr(task, "user_application_status", None)
            setattr(task, "user_application_id", None)
    else:
        setattr(task, "has_applied", None)
        setattr(task, "user_application_status", None)
        setattr(task, "user_application_id", None)

    # 任务完成证据：当任务已标记完成时，从系统消息中取出证据（图片/文件 + 文字说明）供详情页展示
    completion_evidence = []
    if task.status in ("pending_confirmation", "completed") and task.completed_at:
        # 先按 meta 包含 task_completed_by_taker 查；若无结果则取该任务所有系统消息在 Python 里按 meta JSON 匹配（兼容不同数据库）
        completion_message = db.query(models.Message).filter(
            models.Message.task_id == task_id,
            models.Message.message_type == "system",
            models.Message.meta.contains("task_completed_by_taker"),
        ).order_by(models.Message.created_at.asc()).first()
        if not completion_message:
            all_system = (
                db.query(models.Message)
                .filter(
                    models.Message.task_id == task_id,
                    models.Message.message_type == "system",
                    models.Message.meta.isnot(None),
                )
                .order_by(models.Message.created_at.asc())
                .all()
            )
            for msg in all_system:
                try:
                    if msg.meta and json.loads(msg.meta).get("system_action") == "task_completed_by_taker":
                        completion_message = msg
                        break
                except (json.JSONDecodeError, TypeError):
                    continue
        if completion_message and completion_message.id:
            attachments = db.query(models.MessageAttachment).filter(
                models.MessageAttachment.message_id == completion_message.id
            ).all()
            # 用于生成私密图片 URL 的参与者（发布者、接单者）
            evidence_participants = []
            if getattr(task, "poster_id", None):
                evidence_participants.append(str(task.poster_id))
            if getattr(task, "taker_id", None):
                evidence_participants.append(str(task.taker_id))
            if current_user and str(current_user.id) not in evidence_participants:
                evidence_participants.append(str(current_user.id))
            if not evidence_participants:
                evidence_participants = [str(current_user.id)] if current_user else []
            viewer_id = str(current_user.id) if current_user else (getattr(task, "poster_id") or getattr(task, "taker_id"))
            viewer_id = str(viewer_id) if viewer_id else None
            for att in attachments:
                url = att.url or ""
                # 证据图片：若有 blob_id（即 private-image 的 image_id），统一生成新的 private-image URL，便于详情页展示且不过期
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
                        logger.debug(f"生成完成证据 private-image URL 失败 blob_id={att.blob_id}: {e}")
                elif url and not url.startswith("http"):
                    # 若存的是 file_id（私密文件），生成可访问的签名 URL
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
                        logger.debug(f"生成完成证据文件签名 URL 失败 file_id={url}: {e}")
                completion_evidence.append({
                    "type": att.attachment_type or "file",
                    "url": url,
                    "file_id": att.blob_id,
                })
            if completion_message.meta:
                try:
                    meta_data = json.loads(completion_message.meta)
                    if meta_data.get("evidence_text"):
                        completion_evidence.append({
                            "type": "text",
                            "content": meta_data["evidence_text"],
                        })
                except (json.JSONDecodeError, KeyError):
                    pass
    setattr(task, "completion_evidence", completion_evidence if completion_evidence else None)
    
    # 使用 TaskOut.from_orm 确保所有字段（包括 task_source）都被正确序列化
    # full_location_access=True: 地址不再隐藏，所有人可见完整地址
    task_dict = schemas.TaskOut.from_orm(task, full_location_access=True).model_dump()

    # 注入展示勋章
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_user_ids = []
    if task.poster is not None:
        _badge_user_ids.append(task.poster.id)
    if task.taker is not None:
        _badge_user_ids.append(task.taker.id)
    _badge_cache = enrich_displayed_badges_sync(db, _badge_user_ids)

    # 任务相关方可以看到 poster/taker 信息
    if task.poster is not None:
        task_dict["poster"] = schemas.UserBrief.model_validate(task.poster).model_dump()
        task_dict["poster"]["displayed_badge"] = _badge_cache.get(task.poster.id)
    if task.taker is not None:
        task_dict["taker"] = schemas.UserBrief.model_validate(task.taker).model_dump()
        task_dict["taker"]["displayed_badge"] = _badge_cache.get(task.taker.id)
    return task_dict


def _safe_parse_images(images_value):
    """安全解析图片字段（Text/JSON列存储兼容）"""
    if not images_value:
        return []
    if isinstance(images_value, list):
        return images_value
    if isinstance(images_value, str):
        try:
            parsed = json.loads(images_value)
            return parsed if isinstance(parsed, list) else []
        except (json.JSONDecodeError, ValueError):
            return []
    return []


def _handle_dispute_team_reversal(db, task_id: int) -> None:
    """Phase 7: 达人团队任务争议时自动反转 Stripe Transfer。

    当客户对达人团队任务发起 Stripe 争议时，资金已经通过 Transfer
    划拨到团队的 Connect 账户。此函数调用 stripe.Transfer.create_reversal
    将资金拉回平台账户（争议金额将从该处扣除）。

    个人任务（``taker_expert_id=None``）不在此处理：沿用旧的冻结 +
    credit_wallet 退款流程。

    spec §3.5 + §1.3（PaymentTransfer 审计字段）
    """
    import logging
    logger = logging.getLogger(__name__)

    # 查找该任务对应的 PaymentTransfer 记录
    pt = db.query(models.PaymentTransfer).filter(
        models.PaymentTransfer.task_id == task_id
    ).first()

    if not pt:
        # 没有转账记录 —— 说明尚未结算，争议在结算前触发，无需反转
        logger.info(
            f"Dispute on task {task_id}: no PaymentTransfer record yet, "
            f"no reversal needed"
        )
        return

    if not pt.taker_expert_id:
        # 个人任务，由原冻结流程处理，此处早退
        return

    if pt.status != "succeeded":
        # 已反转 / 从未成功 / 仍在重试 —— 幂等保护
        logger.info(
            f"Dispute on task {task_id}: PaymentTransfer status is {pt.status}, "
            f"no reversal action (idempotent)"
        )
        return

    if not pt.transfer_id:
        logger.warning(
            f"Dispute on task {task_id}: PaymentTransfer marked succeeded "
            f"but has no transfer_id"
        )
        return

    try:
        reversal = stripe.Transfer.create_reversal(
            pt.transfer_id,
            amount=int(float(pt.amount) * 100),  # decimal 英镑 -> 便士
            metadata={
                "task_id": str(task_id),
                "reason": "dispute",
                "payment_transfer_id": str(pt.id),
            },
        )
        # 填充审计字段（spec §1.3）
        pt.stripe_reversal_id = reversal.id
        pt.status = "reversed"
        pt.reversed_at = datetime.utcnow()
        pt.reversed_reason = "dispute"
        db.commit()
        logger.warning(
            f"✅ 达人团队任务 {task_id} 因争议已反转 Stripe Transfer: "
            f"reversal_id={reversal.id}"
        )
    except stripe.error.StripeError as e:
        # 常见原因：团队 Stripe 余额不足。不更新 pt.status，保持 succeeded，
        # 便于管理员介入手动处理。
        logger.error(
            f"❌ 反转达人团队争议任务 {task_id} 的转账失败: {e}",
            exc_info=True,
        )


def _handle_account_updated(db, acct):
    """Handle Stripe ``account.updated`` events for expert team Connect accounts.

    Sync function (matches the webhook handler's sync session style). Keeps
    ``experts.stripe_onboarding_complete`` aligned with Stripe's view of the
    account, and freezes / unfreezes owned team services accordingly.

    Args:
        db: sync SQLAlchemy Session.
        acct: Stripe account object (dict or ``stripe.Account``).
    """
    import logging
    logger = logging.getLogger(__name__)
    from app import models
    from app.models_expert import Expert

    # Extract acct id + charges_enabled regardless of dict vs object form
    if isinstance(acct, dict):
        acct_id = acct.get("id")
        charges_enabled = acct.get("charges_enabled")
    else:
        acct_id = getattr(acct, "id", None)
        charges_enabled = getattr(acct, "charges_enabled", None)

    if not acct_id:
        logger.debug("[WEBHOOK] account.updated: missing account id, ignoring")
        return

    expert = db.query(Expert).filter(Expert.stripe_account_id == acct_id).first()
    if expert is None:
        logger.debug(
            f"[WEBHOOK] account.updated: no expert team matches stripe_account_id={acct_id}, ignoring"
        )
        return

    new_state = bool(charges_enabled)
    if expert.stripe_onboarding_complete == new_state:
        logger.info(
            f"[WEBHOOK] account.updated: expert={expert.id} already in desired "
            f"stripe_onboarding_complete={new_state}, no-op"
        )
        return

    expert.stripe_onboarding_complete = new_state

    if not new_state:
        # Freeze any active team-owned services when charges are disabled
        db.query(models.TaskExpertService).filter(
            models.TaskExpertService.owner_type == 'expert',
            models.TaskExpertService.owner_id == expert.id,
            models.TaskExpertService.status == 'active',
        ).update({"status": "inactive"}, synchronize_session=False)
        logger.info(
            f"[WEBHOOK] account.updated: expert={expert.id} charges_enabled=False, "
            f"stripe_onboarding_complete=False, active team services suspended"
        )
    else:
        logger.info(
            f"[WEBHOOK] account.updated: expert={expert.id} charges_enabled=True, "
            f"stripe_onboarding_complete=True"
        )


def _safe_int_metadata(obj, key: str, default: int = 0) -> int:
    """从 Stripe 对象 metadata 安全提取整数. 解析失败返回 default,
    防止伪造或异常 metadata 击穿整个 webhook (Stripe 会无限重试)."""
    try:
        if not isinstance(obj, dict):
            return default
        meta = obj.get("metadata")
        if not isinstance(meta, dict):
            return default
        v = meta.get(key, default)
        if v is None or v == "":
            return default
        return int(v)
    except (TypeError, ValueError):
        return default


@router.get("/admin/customer-service-requests")
@cache_response(ttl=60, key_prefix="admin_cs_requests")
def admin_get_customer_service_requests(
    status: str = None,
    priority: str = None,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员获取客服请求列表"""
    from app.models import AdminRequest, CustomerService

    query = db.query(AdminRequest)

    # 添加状态筛选
    if status and status.strip():
        query = query.filter(AdminRequest.status == status)

    # 添加优先级筛选
    if priority and priority.strip():
        query = query.filter(AdminRequest.priority == priority)

    requests = query.order_by(AdminRequest.created_at.desc()).all()

    requester_ids = {r.requester_id for r in requests if r.requester_id}
    cs_map = {}
    if requester_ids:
        cs_list = db.query(CustomerService).filter(CustomerService.id.in_(requester_ids)).all()
        cs_map = {cs.id: cs for cs in cs_list}

    result = []
    for request in requests:
        cs = cs_map.get(request.requester_id)
        request_dict = {
            "id": request.id,
            "requester_id": request.requester_id,
            "requester_name": cs.name if cs else "未知客服",
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
        }
        result.append(request_dict)

    return {"requests": result, "total": len(result)}


@router.get("/admin/customer-service-requests/{request_id}")
def admin_get_customer_service_request_detail(
    request_id: int, current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取客服请求详情"""
    from app.models import AdminRequest, CustomerService

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    customer_service = (
        db.query(CustomerService)
        .filter(CustomerService.id == request.requester_id)
        .first()
    )

    return {
        "request": {
            "id": request.id,
            "requester_id": request.requester_id,
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
        },
        "customer_service": {
            "id": customer_service.id if customer_service else None,
            "name": customer_service.name if customer_service else "未知客服",
        },
    }


@router.put("/admin/customer-service-requests/{request_id}")
def admin_update_customer_service_request(
    request_id: int,
    request_update: dict,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员更新客服请求状态和回复"""
    from datetime import datetime

    from app.models import AdminRequest

    request = db.query(AdminRequest).filter(AdminRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    # 更新请求信息
    if "status" in request_update:
        request.status = request_update["status"]
    if "admin_response" in request_update:
        request.admin_response = request_update["admin_response"]
    if "priority" in request_update:
        request.priority = request_update["priority"]

    request.admin_id = current_user.id
    request.updated_at = get_utc_time()

    db.commit()
    db.refresh(request)

    return {
        "message": "Request updated successfully",
        "request": {
            "id": request.id,
            "requester_id": request.requester_id,
            "type": request.type,
            "title": request.title,
            "description": request.description,
            "priority": request.priority,
            "status": request.status,
            "admin_response": request.admin_response,
            "admin_id": request.admin_id,
            "created_at": format_iso_utc(request.created_at) if request.created_at else None,
            "updated_at": format_iso_utc(request.updated_at) if request.updated_at else None,
        },
    }


@router.get("/admin/customer-service-chat")
def admin_get_customer_service_chat_messages(
    current_user=Depends(get_current_admin), db: Session = Depends(get_db)
):
    """管理员获取与客服的聊天记录"""
    from app.models import AdminChatMessage, CustomerService

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )

    cs_sender_ids = {m.sender_id for m in messages if m.sender_type == "customer_service" and m.sender_id}
    cs_map = {}
    if cs_sender_ids:
        cs_list = db.query(CustomerService).filter(CustomerService.id.in_(cs_sender_ids)).all()
        cs_map = {cs.id: cs for cs in cs_list}

    result = []
    for message in messages:
        sender_name = None
        if message.sender_type == "customer_service" and message.sender_id:
            cs = cs_map.get(message.sender_id)
            sender_name = cs.name if cs else "未知客服"
        elif message.sender_type == "admin" and message.sender_id:
            sender_name = "管理员"

        message_dict = {
            "id": message.id,
            "sender_id": message.sender_id,
            "sender_type": message.sender_type,
            "sender_name": sender_name,
            "content": message.content,
            "created_at": format_iso_utc(message.created_at) if message.created_at else None,
        }
        result.append(message_dict)

    return {"messages": result, "total": len(result)}


@router.post("/admin/customer-service-chat")
def admin_send_customer_service_chat_message(
    message_data: dict,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """管理员发送消息给客服"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id, sender_type="admin", content=message_data["content"]
    )

    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)

    return {
        "message": "Message sent successfully",
        "chat_message": {
            "id": chat_message.id,
            "sender_id": chat_message.sender_id,
            "sender_type": chat_message.sender_type,
            "content": chat_message.content,
            "created_at": format_iso_utc(chat_message.created_at) if chat_message.created_at else None,
        },
    }


# 已迁移到 admin_payment_routes.py: /admin/payments


@router.post("/user/customer-service/assign")
def assign_customer_service(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """用户分配客服（使用排队系统）"""
    try:
        from app.models import CustomerService, CustomerServiceChat, CustomerServiceQueue
        from app.utils.time_utils import get_utc_time, format_iso_utc
        
        # 1. 检查用户是否已有未结束的对话
        existing_chat = (
            db.query(CustomerServiceChat)
            .filter(
                CustomerServiceChat.user_id == current_user.id,
                CustomerServiceChat.is_ended == 0
            )
            .first()
        )
        
        if existing_chat:
            # 返回现有对话
            service = db.query(CustomerService).filter(
                CustomerService.id == existing_chat.service_id
            ).first()
            
            if service:
                return {
                    "service": {
                        "id": service.id,
                        "name": service.name,
                        "avatar": "/static/service.png",
                        "avg_rating": service.avg_rating,
                        "total_ratings": service.total_ratings,
                    },
                    "chat": {
                        "chat_id": existing_chat.chat_id,
                        "user_id": existing_chat.user_id,
                        "service_id": existing_chat.service_id,
                        "is_ended": existing_chat.is_ended,
                        "created_at": format_iso_utc(existing_chat.created_at) if existing_chat.created_at else None,
                        "total_messages": existing_chat.total_messages or 0,
                    },
                }
        
        # 2. 检查是否有在线客服
        # 使用类型转换确保正确匹配，兼容数据库中可能存在的不同类型
        from sqlalchemy import cast, Integer
        services = (
            db.query(CustomerService)
            .filter(cast(CustomerService.is_online, Integer) == 1)
            .all()
        )
        
        # 如果数据库查询没有结果，使用备用方法：在Python层面检查
        if not services:
            # 限制查询数量，防止内存溢出（最多查询1000个客服）
            all_services = db.query(CustomerService).limit(1000).all()
            logger.info(f"[CUSTOMER_SERVICE] 数据库查询无结果，使用Python层面检查，总客服数量={len(all_services)}")
            # 在Python层面检查在线客服（兼容不同的数据类型）
            services = []
            for s in all_services:
                if s.is_online:
                    # 转换为整数进行比较
                    is_online_value = int(s.is_online) if s.is_online else 0
                    if is_online_value == 1:
                        services.append(s)
                        logger.info(f"[CUSTOMER_SERVICE] 发现在线客服（Python层面）: {s.id}, is_online={s.is_online}")
        
        if not services:
            # 没有可用客服时，将用户加入排队队列
            queue_info = crud.add_user_to_customer_service_queue(db, current_user.id)
            return {
                "error": "no_available_service",
                "message": "暂无在线客服，已加入排队队列",
                "queue_status": queue_info,
                "system_message": {
                    "content": "目前没有可用的客服，您已加入排队队列。系统将尽快为您分配客服，请稍候。"
                },
            }
        
        # 3. 尝试立即分配（如果有可用客服且负载未满）
        import random
        from sqlalchemy import func
        
        # 计算每个客服的当前负载
        service_loads = []
        for service in services:
            active_chats = (
                db.query(func.count(CustomerServiceChat.chat_id))
                .filter(
                    CustomerServiceChat.service_id == service.id,
                    CustomerServiceChat.is_ended == 0
                )
                .scalar() or 0
            )
            max_concurrent = getattr(service, 'max_concurrent_chats', 5) or 5
            if active_chats < max_concurrent:
                service_loads.append((service, active_chats))
        
        if service_loads:
            # 选择负载最低的客服
            service_loads.sort(key=lambda x: x[1])
            service = service_loads[0][0]
            
            # 创建对话
            chat_data = crud.create_customer_service_chat(db, current_user.id, service.id)
            
            # 向客服发送用户连接通知
            try:
                import asyncio
                from app.websocket_manager import get_ws_manager
                
                ws_manager = get_ws_manager()
                notification_message = {
                    "type": "user_connected",
                    "user_info": {
                        "id": current_user.id,
                        "name": current_user.name or f"用户{current_user.id}",
                    },
                    "chat_id": chat_data["chat_id"],
                    "timestamp": format_iso_utc(get_utc_time()),
                }
                # 使用 WebSocketManager 发送消息
                asyncio.create_task(
                    ws_manager.send_to_user(service.id, notification_message)
                )
            except Exception as e:
                logger.error(f"发送客服通知失败: {e}")
            
            return {
                "service": {
                    "id": service.id,
                    "name": service.name,
                    "avatar": "/static/service.png",
                    "avg_rating": service.avg_rating,
                    "total_ratings": service.total_ratings,
                },
                "chat": {
                    "chat_id": chat_data["chat_id"],
                    "user_id": chat_data["user_id"],
                    "service_id": chat_data["service_id"],
                    "is_ended": chat_data["is_ended"],
                    "created_at": chat_data["created_at"],
                    "total_messages": chat_data["total_messages"],
                },
            }
        else:
            # 所有客服都满载，加入排队队列
            queue_info = crud.add_user_to_customer_service_queue(db, current_user.id)
            return {
                "error": "all_services_busy",
                "message": "所有客服都在忙碌中，已加入排队队列",
                "queue_status": queue_info,
                "system_message": {
                    "content": "所有客服都在忙碌中，您已加入排队队列。系统将尽快为您分配客服，请稍候。"
                },
            }
            
    except Exception as e:
        logger.error(f"客服会话分配错误: {e}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"客服会话分配失败: {str(e)}")


@router.get("/user/customer-service/queue-status")
def get_customer_service_queue_status(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取用户在客服排队队列中的状态"""
    queue_status = crud.get_user_queue_status(db, current_user.id)
    return queue_status


@router.get("/user/customer-service/availability")
def check_customer_service_availability(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """检查人工客服是否有在线的"""
    from app.models import CustomerService
    from sqlalchemy import cast, Integer
    online_count = db.query(func.count(CustomerService.id)).filter(
        cast(CustomerService.is_online, Integer) == 1
    ).scalar() or 0
    return {"available": online_count > 0, "online_count": online_count}


# 客服在线状态管理
@router.post("/customer-service/online")
def set_customer_service_online(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """设置客服为在线状态"""
    logger.info(f"[CUSTOMER_SERVICE] 设置客服在线状态: {current_user.id}")
    logger.info(f"[CUSTOMER_SERVICE] 当前在线状态: {current_user.is_online}")
    
    try:
        current_user.is_online = 1
        db.commit()
        logger.info(f"[CUSTOMER_SERVICE] 客服在线状态设置成功: {current_user.id}")
        
        # 验证更新是否成功
        db.refresh(current_user)
        logger.info(f"[CUSTOMER_SERVICE] 验证更新后状态: {current_user.is_online}")
        
        # 清理僵尸对话：自动结束那些创建时间超过10分钟且只有系统消息的对话
        try:
            from app.models import CustomerServiceChat, CustomerServiceMessage
            from app.utils.time_utils import get_utc_time
            from datetime import timedelta
            from sqlalchemy import func
            
            now = get_utc_time()
            threshold_time = now - timedelta(minutes=10)  # 10分钟阈值
            
            # 查找所有进行中的对话
            active_chats = (
                db.query(CustomerServiceChat)
                .filter(
                    CustomerServiceChat.service_id == current_user.id,
                    CustomerServiceChat.is_ended == 0,
                    CustomerServiceChat.created_at < threshold_time
                )
                .all()
            )
            
            cleaned_count = 0
            for chat in active_chats:
                # 检查是否有非系统消息
                has_real_message = (
                    db.query(CustomerServiceMessage)
                    .filter(
                        CustomerServiceMessage.chat_id == chat.chat_id,
                        CustomerServiceMessage.sender_type != 'system'
                    )
                    .first()
                ) is not None
                
                # 如果只有系统消息，自动结束对话
                if not has_real_message:
                    chat.is_ended = 1
                    chat.ended_at = now
                    chat.ended_reason = "auto_cleanup"
                    chat.ended_by = "system"
                    chat.ended_type = "auto"
                    cleaned_count += 1
                    logger.info(f"[CUSTOMER_SERVICE] 自动清理僵尸对话: {chat.chat_id}")
            
            if cleaned_count > 0:
                db.commit()
                logger.info(f"[CUSTOMER_SERVICE] 客服上线时清理了 {cleaned_count} 个僵尸对话")
        except Exception as cleanup_error:
            logger.warning(f"[CUSTOMER_SERVICE] 清理僵尸对话时出错: {cleanup_error}")
            # 不影响上线操作，继续执行
        
        return {"message": "客服已设置为在线状态", "is_online": current_user.is_online}
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 设置在线状态失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"设置在线状态失败: {str(e)}")


@router.post("/customer-service/offline")
def set_customer_service_offline(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """设置客服为离线状态"""
    logger.info(f"[CUSTOMER_SERVICE] 设置客服离线状态: {current_user.id}")
    logger.info(f"[CUSTOMER_SERVICE] 当前在线状态: {current_user.is_online}")
    
    try:
        current_user.is_online = 0
        db.commit()
        logger.info(f"[CUSTOMER_SERVICE] 客服离线状态设置成功: {current_user.id}")
        
        # 验证更新是否成功
        db.refresh(current_user)
        logger.info(f"[CUSTOMER_SERVICE] 验证更新后状态: {current_user.is_online}")
        
        return {"message": "客服已设置为离线状态", "is_online": current_user.is_online}
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 设置离线状态失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"设置离线状态失败: {str(e)}")


# 旧的客服登出路由已删除，请使用 /api/customer-service/logout (在 cs_auth_routes.py 中)

@router.get("/customer-service/status")
def get_customer_service_status(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取客服在线状态和名字"""
    # 使用新的客服对话系统获取评分数据
    from sqlalchemy import func

    from app.models import CustomerServiceChat

    ratings_result = (
        db.query(
            func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
            func.count(CustomerServiceChat.user_rating).label("total_ratings"),
        )
        .filter(
            CustomerServiceChat.service_id == current_user.id,
            CustomerServiceChat.user_rating.isnot(None),
        )
        .first()
    )

    # 获取实时评分数据
    real_time_avg_rating = (
        float(ratings_result.avg_rating)
        if ratings_result and ratings_result.avg_rating is not None
        else 0.0
    )
    real_time_total_ratings = (
        int(ratings_result.total_ratings)
        if ratings_result and ratings_result.total_ratings is not None
        else 0
    )

    # 更新数据库中的评分数据
    current_user.avg_rating = real_time_avg_rating
    current_user.total_ratings = real_time_total_ratings
    db.commit()

    return {
        "is_online": current_user.is_online == 1,
        "service": {
            "id": current_user.id,  # 数据库已经存储格式化ID
            "name": current_user.name,
            "avg_rating": real_time_avg_rating,
            "total_ratings": real_time_total_ratings,
        },
    }


@router.get("/customer-service/check-availability")
def check_customer_service_availability(db: Session = Depends(get_sync_db)):
    """检查是否有在线客服可用"""
    from app.models import CustomerService

    # 查询在线客服数量
    try:
        # 使用类型转换确保正确匹配，兼容数据库中可能存在的不同类型
        from sqlalchemy import cast, Integer
        online_services = (
            db.query(CustomerService)
            .filter(cast(CustomerService.is_online, Integer) == 1)
            .count()
        )
        
        # 添加调试日志
        logger.info(f"[CUSTOMER_SERVICE] 查询在线客服: 标准查询结果={online_services}")
        
        # 如果查询结果为0，使用备用方法：在Python层面检查
        if online_services == 0:
            all_services = db.query(CustomerService).all()
            logger.info(f"[CUSTOMER_SERVICE] 调试信息: 总客服数量={len(all_services)}")
            # 在Python层面检查在线客服（兼容不同的数据类型）
            python_online_count = 0
            for s in all_services:
                logger.info(f"[CUSTOMER_SERVICE] 客服 {s.id}: is_online={s.is_online} (type: {type(s.is_online).__name__})")
                # 检查is_online是否为真值（兼容1, '1', True等）
                if s.is_online:
                    # 转换为整数进行比较
                    is_online_value = int(s.is_online) if s.is_online else 0
                    if is_online_value == 1:
                        python_online_count += 1
                        logger.info(f"[CUSTOMER_SERVICE] 发现在线客服（Python层面）: {s.id}, is_online={s.is_online}")
            
            # 如果Python层面发现有在线客服，使用该结果
            if python_online_count > 0:
                logger.warning(f"[CUSTOMER_SERVICE] 数据库查询返回0，但Python层面发现{python_online_count}个在线客服，使用Python层面结果")
                online_services = python_online_count
    except Exception as e:
        logger.error(f"[CUSTOMER_SERVICE] 查询客服可用性失败: {e}", exc_info=True)
        online_services = 0

    return {
        "available": online_services > 0,
        "online_count": online_services,
        "message": (
            f"当前有 {online_services} 个客服在线"
            if online_services > 0
            else "当前无客服在线"
        ),
    }


# 客服管理相关接口
@router.get("/customer-service/chats")
def get_customer_service_chats(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取分配给当前客服的用户对话列表"""
    chats = crud.get_service_customer_service_chats(db, current_user.id)

    # 获取用户信息和未读消息数量
    user_chats = []
    for chat in chats:
        user = db.query(User).filter(User.id == chat["user_id"]).first()
        if user:
            # 计算未读消息数量
            unread_count = crud.get_unread_customer_service_messages_count(
                db, chat["chat_id"], current_user.id
            )

            user_chats.append(
                {
                    "chat_id": chat["chat_id"],
                    "user_id": user.id,
                    "user_name": user.name,
                    "user_avatar": user.avatar or "/static/avatar1.png",
                    "created_at": chat["created_at"],  # 已经在 crud 中格式化了
                    "last_message_at": chat["last_message_at"],  # 已经在 crud 中格式化了
                    "is_ended": chat["is_ended"],
                    "total_messages": chat["total_messages"],
                    "unread_count": unread_count,
                    "user_rating": chat["user_rating"],
                    "user_comment": chat["user_comment"],
                }
            )

    return user_chats


@router.get("/customer-service/chats/{chat_id}/messages")
def get_customer_service_messages(
    chat_id: str,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """获取客服对话消息（仅限分配给该客服的对话）"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/user/customer-service/chats/{chat_id}/messages/{message_id}/mark-read")
def mark_customer_service_message_read(
    chat_id: str,
    message_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """标记单条消息为已读"""
    # 验证chat_id是否属于当前用户
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    # 标记消息为已读
    success = crud.mark_customer_service_message_read(db, message_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to mark message as read")
    
    return {"message": "Message marked as read", "message_id": message_id}


@router.post("/customer-service/chats/{chat_id}/mark-read")
def mark_customer_service_messages_read(
    chat_id: str,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """标记客服对话消息为已读"""
    # 验证chat_id是否属于当前客服
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 标记消息为已读
    marked_count = crud.mark_customer_service_messages_read(
        db, chat_id, current_user.id
    )

    return {"message": "Messages marked as read", "marked_count": marked_count}


@router.post("/customer-service/chats/{chat_id}/messages")
@rate_limit("send_message")
def send_customer_service_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_service),
    request: Request = None,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """客服发送消息给用户"""
    # 验证chat_id是否属于当前客服且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db,
        chat_id,
        current_user.id,
        "customer_service",
        message_data.get("content", ""),
    )

    # 通过WebSocket实时推送给用户（使用后台任务异步发送）
    async def send_websocket_message():
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()
            
            # 构建消息响应
            message_response = {
                "type": "cs_message",
                "from": current_user.id,
                "receiver_id": chat["user_id"],
                "content": message["content"],
                "created_at": str(message["created_at"]),
                "sender_type": "customer_service",
                "original_sender_id": current_user.id,
                "chat_id": chat_id,
                "message_id": message["id"],
            }
            
            # 使用 WebSocketManager 发送消息
            success = await ws_manager.send_to_user(chat["user_id"], message_response)
            if success:
                logger.info(f"Customer service message sent to user {chat['user_id']} via WebSocket")
            else:
                logger.debug(f"User {chat['user_id']} not connected via WebSocket")
        except Exception as e:
            # WebSocket推送失败不应该影响消息发送
            logger.error(f"Failed to push message via WebSocket: {e}")
    
    background_tasks.add_task(send_websocket_message)

    # 注意：不再在每次发送消息时创建通知
    # 通知只在用户快被自动超时结束的时候才创建（在send_timeout_warnings中实现）

    return message


# 结束对话和评分相关接口
@router.post("/user/customer-service/chats/{chat_id}/end")
@rate_limit("end_chat")
def end_customer_service_chat_user(
    chat_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """用户结束客服对话"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户可以结束对话
    if chat["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to end this chat")

    # 检查对话状态
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat already ended")

    # 结束对话，记录结束原因
    success = crud.end_customer_service_chat(
        db, 
        chat_id,
        reason="user_ended",
        ended_by=current_user.id,
        ended_type="manual"
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to end chat")

    return {"message": "Chat ended successfully"}

@router.post("/customer-service/chats/{chat_id}/end")
@rate_limit("end_chat")
def end_customer_service_chat(
    chat_id: str, current_user=Depends(get_current_customer_service_or_user), db: Session = Depends(get_db)
):
    """结束客服对话"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户或客服可以结束对话
    if chat["user_id"] != current_user.id and chat["service_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to end this chat")

    # 检查对话状态
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat already ended")

    # 判断结束者类型
    if chat["service_id"] == current_user.id:
        # 客服结束
        ended_by = f"service_{current_user.id}"
        reason = "service_ended"
    else:
        # 用户结束
        ended_by = current_user.id
        reason = "user_ended"

    # 结束对话，记录结束原因
    success = crud.end_customer_service_chat(
        db, 
        chat_id,
        reason=reason,
        ended_by=ended_by,
        ended_type="manual"
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to end chat")

    return {"message": "Chat ended successfully"}


@router.post("/user/customer-service/chats/{chat_id}/rate")
@rate_limit("rate_service")
def rate_customer_service(
    chat_id: str,
    rating_data: schemas.CustomerServiceRating,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """用户对客服评分"""
    # 验证chat_id是否存在且用户有权限
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # 检查权限：只有对话的用户可以评分
    if chat["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to rate this chat")

    # 检查对话状态
    if chat["is_ended"] != 1:
        raise HTTPException(status_code=400, detail="Can only rate ended chats")

    # 检查是否已经评分
    if chat["user_rating"] is not None:
        raise HTTPException(status_code=400, detail="Chat already rated")

    # 保存评分
    success = crud.rate_customer_service_chat(
        db, chat_id, rating_data.rating, rating_data.comment
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to save rating")

    # 更新客服的平均评分
    service = (
        db.query(CustomerService)
        .filter(CustomerService.id == chat["service_id"])
        .first()
    )
    if service:
        # 计算该客服的所有评分
        from sqlalchemy import func

        from app.models import CustomerServiceChat

        ratings_result = (
            db.query(
                func.avg(CustomerServiceChat.user_rating).label("avg_rating"),
                func.count(CustomerServiceChat.user_rating).label("total_ratings"),
            )
            .filter(
                CustomerServiceChat.service_id == chat["service_id"],
                CustomerServiceChat.user_rating.isnot(None),
            )
            .first()
        )

        if ratings_result and ratings_result.avg_rating is not None:
            # 更新客服的平均评分和总评分数量
            service.avg_rating = float(ratings_result.avg_rating)
            service.total_ratings = int(ratings_result.total_ratings)
            db.commit()

    return {"message": "Rating submitted successfully"}


@router.get("/user/customer-service/chats")
def get_my_customer_service_chats(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取用户的客服对话历史"""
    chats = crud.get_user_customer_service_chats(db, current_user.id)
    return chats


@router.get("/user/customer-service/chats/{chat_id}/messages")
def get_customer_service_chat_messages(
    chat_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """获取客服对话消息（用户端）"""
    # 验证chat_id是否属于当前用户
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    # 获取对话消息
    messages = crud.get_customer_service_messages(db, chat_id)

    return messages


@router.post("/user/customer-service/chats/{chat_id}/messages")
@rate_limit("send_message")
def send_customer_service_chat_message(
    chat_id: str,
    message_data: dict = Body(...),
    current_user=Depends(get_current_user_secure_sync_csrf),
    request: Request = None,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """用户发送消息到客服对话"""
    # 验证chat_id是否属于当前用户且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")

    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")

    # 保存消息
    message = crud.save_customer_service_message(
        db, chat_id, current_user.id, "user", message_data.get("content", "")
    )

    # 通过WebSocket实时推送给客服（使用后台任务异步发送）
    async def send_websocket_message():
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()

            message_response = {
                "id": message["id"],
                "type": "cs_message",
                "from": current_user.id,
                "receiver_id": chat["service_id"],
                "content": message["content"],
                "created_at": str(message["created_at"]),
                "sender_type": "user",
                "original_sender_id": current_user.id,
                "chat_id": chat_id,
                "message_id": message["id"],
            }

            success = await ws_manager.send_to_user(chat["service_id"], message_response)
            if success:
                logger.info(f"User message sent to CS {chat['service_id']} via WebSocket")
            else:
                logger.debug(f"CS {chat['service_id']} not connected via WebSocket")
        except Exception as e:
            logger.error(f"Failed to push user message to CS via WebSocket: {e}")

    background_tasks.add_task(send_websocket_message)

    return message


# 客服对话文件上传接口
@router.post("/user/customer-service/chats/{chat_id}/files")
@rate_limit("upload_file")
async def upload_customer_service_chat_file(
    chat_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    用户上传文件到客服对话
    支持图片和文档文件
    - 图片：jpg, jpeg, png, gif, webp（最大5MB）
    - 文档：pdf, doc, docx, txt（最大10MB）
    """
    # 验证chat_id是否属于当前用户且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["user_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")
    
    try:
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 优化：先尝试从Content-Type检测文件类型（最快，不需要读取文件）
        # 这对于iOS上传特别有用，因为iOS会设置正确的Content-Type
        content_type = (file.content_type or "").lower()
        is_image_from_type = any(ext in content_type for ext in ['jpeg', 'jpg', 'png', 'gif', 'webp'])
        is_document_from_type = any(ext in content_type for ext in ['pdf', 'msword', 'word', 'plain'])
        
        # 从filename检测（如果filename存在）
        from app.file_utils import get_file_extension_from_filename
        file_ext = get_file_extension_from_filename(file.filename)
        is_image = file_ext in ALLOWED_EXTENSIONS or is_image_from_type
        is_document = file_ext in {".pdf", ".doc", ".docx", ".txt"} or is_document_from_type
        
        # 如果还是无法确定，先读取少量内容用于magic bytes检测
        # 注意：FastAPI的UploadFile不支持seek，所以我们需要在流式读取时处理
        # 这里先不读取，等流式读取时再检测
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 确定最大文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
        # 最终验证：使用完整内容再次检测（确保准确性）
        from app.file_utils import get_file_extension_from_upload
        file_ext = get_file_extension_from_upload(file, content=content)
        
        # 如果无法检测到扩展名
        if not file_ext:
            raise HTTPException(
                status_code=400,
                detail="无法检测文件类型，请确保上传的是有效的文件（图片或文档）"
            )
        
        # 检查是否为危险文件类型
        if file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 使用私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(
            content, 
            file.filename, 
            current_user.id, 
            db, 
            task_id=None, 
            chat_id=chat_id,
            content_type=file.content_type
        )
        
        # 生成签名URL
        from app.signed_url import signed_url_manager
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=current_user.id,
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )
        
        return {
            "success": True,
            "url": file_url,
            "file_id": result["file_id"],
            "filename": result["filename"],
            "size": result["size"],
            "original_name": result["original_filename"],
            "file_type": "image" if is_image else "document",
            "chat_id": chat_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服对话文件上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/customer-service/chats/{chat_id}/files")
@rate_limit("upload_file")
async def upload_customer_service_file(
    chat_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """
    客服上传文件到对话
    支持图片和文档文件
    - 图片：jpg, jpeg, png, gif, webp（最大5MB）
    - 文档：pdf, doc, docx, txt（最大10MB）
    """
    # 验证chat_id是否属于当前客服且未结束
    chat = crud.get_customer_service_chat(db, chat_id)
    if not chat or chat["service_id"] != current_user.id:
        raise HTTPException(status_code=404, detail="Chat not found or not authorized")
    
    if chat["is_ended"] == 1:
        raise HTTPException(status_code=400, detail="Chat has ended")
    
    try:
        # 优化：先尝试从Content-Type检测文件类型（最快，不需要读取文件）
        # 这对于iOS上传特别有用，因为iOS会设置正确的Content-Type
        content_type = (file.content_type or "").lower()
        is_image_from_type = any(ext in content_type for ext in ['jpeg', 'jpg', 'png', 'gif', 'webp'])
        is_document_from_type = any(ext in content_type for ext in ['pdf', 'msword', 'word', 'plain'])
        
        # 从filename检测（如果filename存在）
        file_ext = None
        if file.filename:
            file_ext = Path(file.filename).suffix.lower()
        else:
            # 如果没有filename，尝试从Content-Type推断
            if is_image_from_type:
                file_ext = ".jpg"  # 默认使用jpg
            elif is_document_from_type:
                file_ext = ".pdf"  # 默认使用pdf
        
        # 检查是否为危险文件类型
        if file_ext and file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 判断文件类型（图片或文档）
        is_image = (file_ext and file_ext in ALLOWED_EXTENSIONS) or is_image_from_type
        is_document = (file_ext and file_ext in {".pdf", ".doc", ".docx", ".txt"}) or is_document_from_type
        
        if not (is_image or is_document):
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。允许的类型: 图片({', '.join(ALLOWED_EXTENSIONS)}), 文档(pdf, doc, docx, txt)"
            )
        
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check
        
        # 确定最大文件大小
        max_size = MAX_FILE_SIZE if is_image else MAX_FILE_SIZE_LARGE
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
        # 最终验证：使用完整内容再次检测（确保准确性）
        from app.file_utils import get_file_extension_from_upload
        file_ext = get_file_extension_from_upload(file, content=content)
        
        # 如果无法检测到扩展名
        if not file_ext:
            raise HTTPException(
                status_code=400,
                detail="无法检测文件类型，请确保上传的是有效的文件（图片或文档）"
            )
        
        # 再次检查是否为危险文件类型（使用最终检测结果）
        if file_ext in DANGEROUS_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"不允许上传 {file_ext} 类型的文件")
        
        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, max_size)
        
        # 使用私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(
            content, 
            file.filename, 
            current_user.id, 
            db, 
            task_id=None, 
            chat_id=chat_id,
            content_type=file.content_type
        )
        
        # 生成签名URL
        from app.signed_url import signed_url_manager
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=chat["user_id"],  # 使用用户ID生成URL，因为客服ID不在users表中
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )
        
        return {
            "success": True,
            "url": file_url,
            "file_id": result["file_id"],
            "filename": result["filename"],
            "size": result["size"],
            "original_name": result["original_filename"],
            "file_type": "image" if is_image else "document",
            "chat_id": chat_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"客服文件上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.get("/customer-service/{service_id}/rating")
@measure_api_performance("get_customer_service_rating")
@cache_response(ttl=300, key_prefix="cs_rating")  # 缓存5分钟
def get_customer_service_rating(service_id: str, db: Session = Depends(get_db)):
    """获取客服的平均评分信息"""
    service = db.query(CustomerService).filter(CustomerService.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Customer service not found")

    return {
        "service_id": service.id,
        "service_name": service.name,
        "avg_rating": service.avg_rating,
        "total_ratings": service.total_ratings,
    }


@router.get("/customer-service/all-ratings")
@measure_api_performance("get_all_customer_service_ratings")
@cache_response(ttl=300, key_prefix="cs_all_ratings")  # 缓存5分钟
def get_all_customer_service_ratings(db: Session = Depends(get_db)):
    """获取所有客服的平均评分信息"""
    services = db.query(CustomerService).all()

    return [
        {
            "service_id": service.id,
            "service_name": service.name,
            "avg_rating": service.avg_rating,
            "total_ratings": service.total_ratings,
            "is_online": service.is_online == 1,
        }
        for service in services
    ]


@router.get("/customer-service/cancel-requests")
def cs_get_cancel_requests(
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
    status: str = None,
):
    """
    客服获取任务取消请求列表
    
    权限说明：客服只能审核任务取消请求，这是客服的唯一管理权限。
    其他管理操作需要通过 /customer-service/admin-requests 向管理员请求。
    """
    from app.models import TaskCancelRequest, Task, User

    requests = crud.get_task_cancel_requests(db, status)

    # 批量加载任务和用户，避免 N+1 查询
    task_ids = list({r.task_id for r in requests})
    requester_ids = list({r.requester_id for r in requests})
    task_map = {t.id: t for t in db.query(Task).filter(Task.id.in_(task_ids)).all()} if task_ids else {}
    user_map = {u.id: u for u in db.query(User).filter(User.id.in_(requester_ids)).all()} if requester_ids else {}

    result = []
    for req in requests:
        task = task_map.get(req.task_id)
        requester = user_map.get(req.requester_id)

        is_poster = task and task.poster_id == req.requester_id
        is_taker = task and task.taker_id == req.requester_id

        result.append({
            "id": req.id,
            "task_id": req.task_id,
            "requester_id": req.requester_id,
            "requester_name": requester.name if requester else "未知用户",
            "reason": req.reason,
            "status": req.status,
            "admin_id": req.admin_id,  # 管理员ID（格式：A0001）
            "service_id": req.service_id,  # 客服ID（格式：CS8888）
            "admin_comment": req.admin_comment,
            "created_at": format_iso_utc(req.created_at) if req.created_at else None,
            "reviewed_at": format_iso_utc(req.reviewed_at) if req.reviewed_at else None,
            "task": {
                "id": task.id if task else None,
                "title": task.title if task else "任务已删除",
                "status": task.status if task else "deleted",
                "poster_id": task.poster_id if task else None,
                "taker_id": task.taker_id if task else None,
            },
            "user_role": "发布者" if is_poster else ("接收者" if is_taker else "未知")
        })
    
    return result


@router.post("/customer-service/cancel-requests/{request_id}/review")
def cs_review_cancel_request(
    request_id: int,
    review: schemas.TaskCancelRequestReview,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """
    客服审核任务取消请求
    
    权限说明：
    - 这是客服的唯一管理权限，可以审核通过或拒绝任务取消请求
    - 客服不能直接操作任务（删除、修改等）
    - 客服不能操作用户账户（封禁、暂停等）
    - 其他管理操作需要通过 /customer-service/admin-requests 向管理员请求
    """
    cancel_request = crud.get_task_cancel_request_by_id(db, request_id)
    if not cancel_request:
        raise HTTPException(status_code=404, detail="Cancel request not found")

    if cancel_request.status != "pending":
        raise HTTPException(status_code=400, detail="Request has already been reviewed")

    # 更新请求状态（客服审核）
    updated_request = crud.update_task_cancel_request(
        db, request_id, review.status, current_user.id, review.admin_comment, reviewer_type='service'
    )

    if review.status == "approved":
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            # 实际取消任务
            crud.cancel_task(
                db,
                cancel_request.task_id,
                cancel_request.requester_id,
                is_admin_review=True,
            )
            
            # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
            try:
                from app.services.task_service import TaskService
                TaskService.invalidate_cache(cancel_request.task_id)
                from app.redis_cache import invalidate_tasks_cache
                invalidate_tasks_cache()
                logger.info(f"✅ 已清除任务 {cancel_request.task_id} 的缓存（客服审核取消）")
            except Exception as e:
                logger.warning(f"⚠️ 清除任务缓存失败: {e}")

            # 通知请求者
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_approved",
                "取消请求已通过",
                f'您的任务 "{task.title}" 取消请求已通过审核',
                task.id,
            )
            
            # 发送推送通知给请求者
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_approved",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id}
                )
            except Exception as e:
                logger.warning(f"发送取消请求通过推送通知失败: {e}")
                # 推送通知失败不影响主流程

            # 通知另一方（发布者或接受者）
            other_user_id = (
                task.poster_id
                if cancel_request.requester_id == task.taker_id
                else task.taker_id
            )
            if other_user_id:
                crud.create_notification(
                    db,
                    other_user_id,
                    "task_cancelled",
                    "任务已取消",
                    f'任务 "{task.title}" 已被取消',
                    task.id,
                )
                
                # 发送推送通知给另一方
                try:
                    send_push_notification(
                        db=db,
                        user_id=other_user_id,
                        notification_type="task_cancelled",
                        data={"task_id": task.id},
                        template_vars={"task_title": task.title, "task_id": task.id}
                    )
                except Exception as e:
                    logger.warning(f"发送任务取消推送通知失败: {e}")
                    # 推送通知失败不影响主流程

    elif review.status == "rejected":
        # 通知请求者
        task = crud.get_task(db, cancel_request.task_id)
        if task:
            crud.create_notification(
                db,
                cancel_request.requester_id,
                "cancel_request_rejected",
                "取消请求被拒绝",
                f'您的任务 "{task.title}" 取消请求被拒绝，原因：{review.admin_comment or "无"}',
                task.id,
            )
            
            # 发送推送通知给请求者
            try:
                send_push_notification(
                    db=db,
                    user_id=cancel_request.requester_id,
                    notification_type="cancel_request_rejected",
                    data={"task_id": task.id},
                    template_vars={"task_title": task.title, "task_id": task.id}
                )
            except Exception as e:
                logger.warning(f"发送取消请求拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程

    return {
        "message": f"Cancel request {review.status}",
        "request": {
            "id": updated_request.id,
            "task_id": updated_request.task_id,
            "requester_id": updated_request.requester_id,
            "reason": updated_request.reason,
            "status": updated_request.status,
            "admin_id": updated_request.admin_id,
            "service_id": updated_request.service_id,
            "admin_comment": updated_request.admin_comment,
            "created_at": format_iso_utc(updated_request.created_at) if updated_request.created_at else None,
            "reviewed_at": format_iso_utc(updated_request.reviewed_at) if updated_request.reviewed_at else None,
        },
    }


# 管理请求相关API
@router.get(
    "/customer-service/admin-requests", response_model=list[schemas.AdminRequestOut]
)
def get_admin_requests(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取客服提交的管理请求列表"""
    from app.models import AdminRequest

    requests = (
        db.query(AdminRequest)
        .filter(AdminRequest.requester_id == current_user.id)
        .order_by(AdminRequest.created_at.desc())
        .all()
    )
    return requests


@router.post("/customer-service/admin-requests", response_model=schemas.AdminRequestOut)
def create_admin_request(
    request_data: schemas.AdminRequestCreate,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_sync_db),
):
    """
    客服提交管理请求
    
    权限说明：
    - 客服只有审核取消任务请求的权限
    - 对于其他管理操作（如删除任务、封禁用户等），客服必须通过此接口向管理员请求
    - 管理员会在后台处理这些请求
    """
    from app.models import AdminRequest

    admin_request = AdminRequest(
        requester_id=current_user.id,
        type=request_data.type,
        title=request_data.title,
        description=request_data.description,
        priority=request_data.priority,
    )
    db.add(admin_request)
    db.commit()
    db.refresh(admin_request)
    return admin_request


@router.get(
    "/customer-service/admin-chat", response_model=list[schemas.AdminChatMessageOut]
)
def get_admin_chat_messages(
    current_user=Depends(get_current_service), db: Session = Depends(get_sync_db)
):
    """获取与后台工作人员的聊天记录"""
    from app.models import AdminChatMessage

    messages = (
        db.query(AdminChatMessage).order_by(AdminChatMessage.created_at.asc()).all()
    )
    return messages


@router.post("/customer-service/admin-chat", response_model=schemas.AdminChatMessageOut)
def send_admin_chat_message(
    message_data: schemas.AdminChatMessageCreate,
    current_user=Depends(get_current_service),
    db: Session = Depends(get_sync_db),
):
    """客服发送消息给后台工作人员"""
    from app.models import AdminChatMessage

    chat_message = AdminChatMessage(
        sender_id=current_user.id,
        sender_type="customer_service",
        content=message_data.content,
    )
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    return chat_message


# 清理过期会话的后台任务（不自动结束超时对话）


# 管理后台相关API接口
from app.deps import check_admin, check_admin_user_status, check_super_admin




# 已迁移到 admin_user_management_routes.py: /admin/dashboard/stats, /admin/users, /admin/users/{user_id}, /admin/admin-users, /admin/admin-user
# 已迁移到 admin_notification_routes.py: /admin/staff-notification, /staff/notifications, /admin/notifications/send
# 已迁移到 admin_customer_service_routes.py: /admin/customer-service, /admin/customer-service/{cs_id}/notify
# 已迁移到 admin_task_management_routes.py: /admin/tasks/{task_id}
# 已迁移到 admin_system_routes.py: /admin/system-settings



def _decode_jws_transaction(jws: str):
    """解析 JWS 获取 transactionId、originalTransactionId。"""
    from app.iap_verification_service import iap_verification_service
    try:
        info = iap_verification_service.verify_transaction_jws(jws)
        return info
    except Exception:
        return None


def _handle_v2_renewal(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        logger.warning("V2 DID_RENEW 解析 JWS 失败")
        return
    otid = info.get("original_transaction_id") or info.get("transaction_id")
    tid = info.get("transaction_id")
    vip_subscription_service.process_subscription_renewal(db, otid, tid, jws)


def _handle_v2_cancel(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    if tid:
        vip_subscription_service.cancel_subscription(db, tid, "Apple 取消")


def _handle_v2_expired(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    sub = crud.get_vip_subscription_by_transaction_id(db, tid)
    if sub and sub.status == "active":
        crud.update_vip_subscription_status(db, sub.id, "expired")
        active = crud.get_active_vip_subscription(db, sub.user_id)
        if not active:
            crud.update_user_vip_status(db, sub.user_id, "normal")
        vip_subscription_service.invalidate_vip_cache(sub.user_id)


def _handle_v2_refund(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    vip_subscription_service.process_refund(db, tid, "Apple退款")


def _handle_v2_revoke(db, vip_subscription_service, jws: str):
    info = _decode_jws_transaction(jws)
    if not info:
        return
    tid = info.get("transaction_id")
    vip_subscription_service.process_refund(db, tid, "Apple撤销")


@router.post("/customer-service/cleanup-old-chats/{service_id}")
def cleanup_old_customer_service_chats(
    service_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """清理客服的旧已结束对话"""
    if current_user.id != service_id:
        raise HTTPException(status_code=403, detail="无权限清理其他客服的对话")

    try:
        deleted_count = crud.cleanup_old_ended_chats(db, service_id)
        return {
            "message": f"成功清理 {deleted_count} 个旧对话",
            "deleted_count": deleted_count,
        }
    except Exception as e:
        logger.error(f"清理旧对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


@router.post("/customer-service/chats/{chat_id}/timeout-end")
async def timeout_end_customer_service_chat(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """超时结束客服对话"""
    try:
        logger.info(f"客服 {current_user.id} 尝试超时结束对话 {chat_id}")
        
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            logger.warning(f"对话 {chat_id} 不存在")
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            logger.warning(f"客服 {current_user.id} 无权限操作对话 {chat_id}，对话属于客服 {chat['service_id']}")
            raise HTTPException(status_code=403, detail="无权限操作此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            logger.info(f"对话 {chat_id} 已经结束")
            raise HTTPException(status_code=400, detail="对话已结束")

        # 先发送系统消息给用户 - 由于长时间没有收到你的信息，本次对话已结束
        logger.info(f"为用户 {chat['user_id']} 发送系统消息")
        try:
            crud.save_customer_service_message(
                db=db,
                chat_id=chat_id,
                sender_id="system",  # 系统消息
                sender_type="system",
                content="由于长时间没有收到你的信息，本次对话已结束"
            )
            logger.info(f"已发送系统消息到对话 {chat_id}")
        except Exception as e:
            logger.error(f"发送系统消息失败: {e}")
            # 不影响流程继续

        # 结束对话（在发送消息后再结束）
        logger.info(f"正在结束对话 {chat_id}")
        success = crud.end_customer_service_chat(db, chat_id)
        if not success:
            logger.error(f"结束对话 {chat_id} 失败")
            raise HTTPException(status_code=500, detail="结束对话失败")

        # 发送超时通知给用户
        logger.info(f"为用户 {chat['user_id']} 创建超时通知")
        crud.create_notification(
            db=db,
            user_id=chat["user_id"],
            type="chat_timeout",
            title="对话超时结束",
            content="您的客服对话因超时（2分钟无活动）已自动结束。如需继续咨询，请重新联系客服。",
            related_id=chat["id"],
        )

        # 通过WebSocket通知用户对话已结束
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()
            
            timeout_message = {
                "type": "chat_timeout",
                "chat_id": chat_id,
                "content": "由于长时间没有收到你的信息，本次对话已结束"
            }
            
            success = await ws_manager.send_to_user(chat["user_id"], timeout_message)
            if success:
                logger.info(f"已通过WebSocket发送超时消息给用户 {chat['user_id']}")
            else:
                logger.info(f"用户 {chat['user_id']} 不在线，无法通过WebSocket发送")
        except Exception as e:
            logger.error(f"WebSocket通知失败: {e}")

        logger.info(f"对话 {chat_id} 超时结束成功")
        return {"message": "对话已超时结束", "chat_id": chat_id, "user_notified": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"超时结束对话失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")



@router.get("/customer-service/chats/{chat_id}/timeout-status")
def get_chat_timeout_status(
    chat_id: str,
    current_user: models.CustomerService = Depends(get_current_service),
    db: Session = Depends(get_db),
):
    """获取对话超时状态"""
    try:
        logger.info(f"客服 {current_user.id} 检查对话 {chat_id} 的超时状态")
        
        # 获取对话信息
        chat = crud.get_customer_service_chat(db, chat_id)
        if not chat:
            logger.warning(f"对话 {chat_id} 不存在")
            raise HTTPException(status_code=404, detail="对话不存在")

        # 检查权限
        if chat["service_id"] != current_user.id:
            logger.warning(f"客服 {current_user.id} 无权限查看对话 {chat_id}")
            raise HTTPException(status_code=403, detail="无权限查看此对话")

        # 检查对话是否已结束
        if chat["is_ended"] == 1:
            logger.info(f"对话 {chat_id} 已结束")
            return {"is_ended": True, "is_timeout": False, "timeout_available": False}

        # 计算最后消息时间到现在的时间差
        from datetime import datetime, timedelta, timezone

        last_message_time = chat["last_message_at"]

        # 统一处理时间格式 - 使用UTC时间
        from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone, parse_iso_utc

        current_time = get_utc_time()

        if isinstance(last_message_time, str):
            # 处理字符串格式的时间，统一使用 parse_iso_utc 确保返回 aware datetime
            last_message_time = parse_iso_utc(last_message_time.replace("Z", "+00:00") if last_message_time.endswith("Z") else last_message_time)
        elif hasattr(last_message_time, "replace"):
            # 如果是datetime对象但没有时区信息，假设是UTC
            if last_message_time.tzinfo is None:
                last_message_time = last_message_time.replace(tzinfo=timezone.utc)
                logger.info(f"为datetime对象添加UTC时区: {last_message_time}")
        else:
            # 如果是其他类型，使用当前UTC时间
            logger.warning(
                f"Unexpected time type: {type(last_message_time)}, value: {last_message_time}"
            )
            last_message_time = current_time

        # 计算时间差（都是UTC时间）
        time_diff = current_time - last_message_time

        # 调试信息
        logger.info(
            f"Current time: {current_time}, Last message time: {last_message_time}, Diff: {time_diff.total_seconds()} seconds"
        )
        logger.info(
            f"Current time type: {type(current_time)}, Last message time type: {type(last_message_time)}"
        )
        logger.info(
            f"Current time tzinfo: {current_time.tzinfo}, Last message time tzinfo: {last_message_time.tzinfo}"
        )

        # 2分钟 = 120秒
        is_timeout = time_diff.total_seconds() > 120
        
        result = {
            "is_ended": False,
            "is_timeout": is_timeout,
            "timeout_available": is_timeout,
            "last_message_time": chat["last_message_at"],
            "time_since_last_message": int(time_diff.total_seconds()),
        }
        
        logger.info(f"对话 {chat_id} 超时状态: {result}")
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取对话超时状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")


# 文件上传配置 - 支持Railway部署
import os
from app.config import Config

# 检测部署环境
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
USE_CLOUD_STORAGE = os.getenv("USE_CLOUD_STORAGE", "false").lower() == "true"

# 图片上传相关配置 - 使用私有存储
if RAILWAY_ENVIRONMENT and not USE_CLOUD_STORAGE:
    # Railway环境：使用私有目录
    PRIVATE_IMAGE_DIR = Path("/data/uploads/private/images")
    PRIVATE_FILE_DIR = Path("/data/uploads/private/files")
else:
    # 本地开发环境：使用私有目录
    PRIVATE_IMAGE_DIR = Path("uploads/private/images")
    PRIVATE_FILE_DIR = Path("uploads/private/files")

# 确保私有目录存在
PRIVATE_IMAGE_DIR.mkdir(parents=True, exist_ok=True)
PRIVATE_FILE_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

# 危险文件扩展名（不允许上传）
DANGEROUS_EXTENSIONS = {".exe", ".bat", ".cmd", ".com", ".pif", ".scr", ".vbs", ".js", ".jar", ".sh", ".ps1"}
MAX_FILE_SIZE_LARGE = 10 * 1024 * 1024  # 10MB



# 旧的图片存储优化API已删除 - 现在使用私密图片系统
# 旧的图片存储优化API已删除 - 现在使用私密图片系统


# 已迁移到 admin_system_routes.py: /admin/job-positions, /admin/job-positions/{position_id}


# ==================== 任务达人管理 API ====================



# 公开 API - 获取任务达人列表（已迁移到 task_expert_routes.py）
# @router.get("/task-experts")
# @measure_api_performance("get_task_experts")
# @cache_response(ttl=600, key_prefix="public_task_experts")
def _deprecated_get_public_task_experts(
    category: Optional[str] = None,
    location: Optional[str] = Query(None, description="城市筛选"),
    keyword: Optional[str] = Query(None, max_length=200, description="关键词搜索（搜索名称、简介、技能）"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="返回数量限制"),
    db: Session = Depends(get_db),
):
    """获取任务达人列表（公开）"""
    try:
        query = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.is_active == 1
        )
        
        # 关键词搜索（支持中英文：同时匹配中文字段和英文字段）
        if keyword:
            keyword_pattern = f"%{keyword}%"
            query = query.filter(
                or_(
                    models.FeaturedTaskExpert.name.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.bio.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.bio_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.expertise_areas.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.expertise_areas_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.featured_skills.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.featured_skills_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.achievements.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.achievements_en.ilike(keyword_pattern),
                    models.FeaturedTaskExpert.category.ilike(keyword_pattern),
                )
            )
        
        if category:
            query = query.filter(models.FeaturedTaskExpert.category == category)
        
        if location and location != 'all':
            # 处理location筛选：支持精确匹配，同时处理NULL和空字符串的情况
            # 如果筛选"Online"，也要匹配NULL和空字符串的记录（因为后端返回时会将它们转换为"Online"）
            if location == 'Online':
                query = query.filter(
                    or_(
                        models.FeaturedTaskExpert.location == 'Online',
                        models.FeaturedTaskExpert.location == None,
                        models.FeaturedTaskExpert.location == '',
                        models.FeaturedTaskExpert.location.is_(None)  # 使用is_()检查NULL
                    )
                )
            else:
                # 对于其他城市，进行精确匹配
                # 注意：数据库中的location值应该与筛选器中的值完全匹配
                query = query.filter(models.FeaturedTaskExpert.location == location)
        
        # 排序
        query = query.order_by(
            models.FeaturedTaskExpert.display_order,
            models.FeaturedTaskExpert.created_at.desc()
        )
        
        # 限制返回数量
        if limit:
            query = query.limit(limit)
        
        experts = query.all()
        
        # 批量计算完成率为0的专家（只读，不写回数据库）
        from app.models import Task
        zero_rate_ids = [e.id for e in experts if e.completion_rate == 0.0]
        completion_rate_map = {}
        if zero_rate_ids:
            from sqlalchemy import case
            stats = db.query(
                Task.taker_id,
                func.count(Task.id).label('total'),
                func.count(case((Task.status == 'completed', 1))).label('completed')
            ).filter(
                Task.taker_id.in_(zero_rate_ids)
            ).group_by(Task.taker_id).all()

            for taker_id, total, completed in stats:
                if total > 0:
                    completion_rate_map[taker_id] = (completed / total) * 100.0

        result_experts = []
        for expert in experts:
            completion_rate = completion_rate_map.get(expert.id, expert.completion_rate)
            
            result_experts.append({
                "id": expert.id,  # id 现在就是 user_id
                "name": expert.name,
                "avatar": expert.avatar,
                "user_level": expert.user_level,
                "avg_rating": expert.avg_rating,
                "completed_tasks": expert.completed_tasks,
                "total_tasks": expert.total_tasks,
                "completion_rate": round(completion_rate, 1),
                "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
                "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
                "achievements": json.loads(expert.achievements) if expert.achievements else [],
                "is_verified": bool(expert.is_verified),
                "bio": expert.bio,
                "response_time": expert.response_time,
                "success_rate": expert.success_rate,
                "location": expert.location if expert.location and expert.location.strip() else "Online",  # 添加城市字段，处理NULL和空字符串
                "category": expert.category if hasattr(expert, 'category') else None,  # 添加类别字段
            })
        
        return {
            "task_experts": result_experts
        }
    except Exception as e:
        logger.error(f"获取任务达人列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取任务达人列表失败")


# 已迁移到 admin_system_routes.py: /admin/cleanup/completed-tasks, /admin/cleanup/all-old-tasks, /admin/cleanup/duplicate-device-tokens, /admin/cleanup/old-inactive-device-tokens


def _parse_semver(version_str: str) -> tuple:
    """将版本字符串解析为 (major, minor, patch) 元组用于比较"""
    try:
        parts = version_str.strip().split(".")
        return tuple(int(p) for p in parts[:3])
    except (ValueError, AttributeError):
        return (0, 0, 0)


# === Re-exports for backward compat with external importers ===
# async_routers.py imports confirm_task_completion via:
#   from app.routers import confirm_task_completion as sync_confirm
# The function moved to app.routes.refund_routes in the routers split.
from app.routes.refund_routes import confirm_task_completion  # noqa: F401

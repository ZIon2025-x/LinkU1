"""
Shared helpers for split route modules (extraction completed 2026-04-25).

Routes have been migrated to app/routes/*_routes.py. This module now retains:
  - module-level helper functions (_handle_*, _payment_method_types_*,
    _safe_json_loads, _decode_jws_*, _handle_v2_*, _safe_parse_images,
    _request_lang_sync, _get_task_detail_legacy, _trigger_background_*,
    _translate_missing_tasks_async, _parse_semver, _deprecated_*)
  - One re-export shim (confirm_task_completion from refund_routes) for
    backward compat with async_routers.py.

Do not add new routes here. If you need a new endpoint, create it in the
appropriate app/routes/<domain>_routes.py.

See docs/superpowers/specs/2026-04-25-routers-py-split-design.md
"""
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

# Routes have been migrated to app/routes/*_routes.py (split completed
# 2026-04-25). This module no longer registers any APIRoute — it only
# retains module-level helper functions and a re-export shim. See the
# module docstring at the top of the file.


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

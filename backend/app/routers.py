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


@router.get("/recommendations")
def get_recommendations(
    current_user=Depends(get_current_user_secure_sync_csrf),
    limit: int = Query(20, ge=1, le=50),
    algorithm: str = Query("hybrid", pattern="^(content_based|collaborative|hybrid)$"),
    task_type: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None, max_length=200),
    latitude: Optional[float] = Query(None, ge=-90, le=90),
    longitude: Optional[float] = Query(None, ge=-180, le=180),
    db: Session = Depends(get_db),
):
    """
    获取个性化任务推荐（支持筛选条件和GPS位置）
    
    Args:
        limit: 返回任务数量（1-50）
        algorithm: 推荐算法类型
            - content_based: 基于内容的推荐
            - collaborative: 协同过滤推荐
            - hybrid: 混合推荐（推荐）
        task_type: 任务类型筛选
        location: 地点筛选
        keyword: 关键词筛选
        latitude: 用户当前纬度（用于基于位置的推荐）
        longitude: 用户当前经度（用于基于位置的推荐）
    """
    try:
        # 将GPS位置直接传递给推荐算法（无需存储到数据库）
        recommendations = get_task_recommendations(
            db=db,
            user_id=current_user.id,
            limit=limit,
            algorithm=algorithm,
            task_type=task_type,
            location=location,
            keyword=keyword,
            latitude=latitude,
            longitude=longitude
        )
        
        # 任务双语标题从任务表列读取；缺失时后台触发预取
        task_ids = [item["task"].id for item in recommendations]
        missing_task_ids = []
        for item in recommendations:
            t = item["task"]
            if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None):
                missing_task_ids.append(t.id)
        if missing_task_ids:
            _trigger_background_translation_prefetch(
                missing_task_ids,
                target_languages=["en", "zh"],
                label="后台翻译任务标题",
            )

        result = []
        from app.utils.location_utils import obfuscate_location
        for item in recommendations:
            task = item["task"]
            title_en = getattr(task, "title_en", None)
            title_zh = getattr(task, "title_zh", None)

            # 解析图片字段
            images_list = []
            if task.images:
                try:
                    import json
                    if isinstance(task.images, str):
                        images_list = json.loads(task.images)
                    elif isinstance(task.images, list):
                        images_list = task.images
                except (json.JSONDecodeError, TypeError):
                    images_list = []

            result.append({
                "id": task.id,
                "task_id": task.id,
                "title": task.title,
                "title_en": title_en,
                "title_zh": title_zh,
                "description": task.description,
                "task_type": task.task_type,
                "location": obfuscate_location(task.location),
                "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else (float(task.reward) if task.reward else 0.0),
                "base_reward": float(task.base_reward) if task.base_reward else None,
                "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
                "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
                "deadline": task.deadline.isoformat() if task.deadline else None,
                "task_level": task.task_level,
                "match_score": round(item["score"], 3),
                "recommendation_reason": item["reason"],
                "created_at": task.created_at.isoformat() if task.created_at else None,
                "images": images_list,  # 添加图片字段
            })
        
        return {
            "recommendations": result,
            "total": len(result),
            "algorithm": algorithm
        }
    except Exception as e:
        logger.error(f"获取推荐失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐失败")


@router.get("/tasks/{task_id}/match-score")
def get_task_match_score(
    task_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    获取任务对当前用户的匹配分数
    
    用于在任务详情页显示匹配度
    """
    try:
        task = crud.get_task(db, task_id)
        if not task or not task.is_visible:
            raise HTTPException(status_code=404, detail="Task not found")
        score = calculate_task_match_score(
            db=db,
            user_id=current_user.id,
            task_id=task_id
        )

        return {
            "task_id": task_id,
            "match_score": round(score, 3),
            "match_percentage": round(score * 100, 1)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"计算匹配分数失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="计算匹配分数失败")


@router.post("/tasks/{task_id}/interaction")
def record_task_interaction(
    task_id: int,
    interaction_type: str = Body(..., pattern="^(view|click|apply|skip)$"),
    duration_seconds: Optional[int] = Body(None),
    device_type: Optional[str] = Body(None),
    is_recommended: Optional[bool] = Body(None),
    metadata: Optional[dict] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    记录用户对任务的交互行为
    
    Args:
        interaction_type: 交互类型 (view, click, apply, skip)
        duration_seconds: 浏览时长（秒），仅用于view类型
        device_type: 设备类型 (mobile, desktop, tablet)
        is_recommended: 是否为推荐任务
        metadata: 额外元数据（设备信息、推荐信息等）
    """
    try:
        # 优化：先验证任务是否存在，避免记录不存在的任务交互
        task = crud.get_task(db, task_id)
        if not task:
            logger.warning(
                f"尝试记录交互时任务不存在: user_id={current_user.id}, "
                f"task_id={task_id}, interaction_type={interaction_type}"
            )
            raise HTTPException(status_code=404, detail="Task not found")
        
        tracker = UserBehaviorTracker(db)
        is_rec = is_recommended if is_recommended is not None else False
        
        # 合并metadata，确保包含推荐信息
        final_metadata = metadata or {}
        final_metadata["is_recommended"] = is_rec
        
        if interaction_type == "view":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="view",
                duration_seconds=duration_seconds,
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "click":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="click",
                device_type=device_type,
                metadata=final_metadata,
                is_recommended=is_rec
            )
        elif interaction_type == "apply":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="apply",
                device_type=device_type,
                metadata=final_metadata
            )
        elif interaction_type == "skip":
            tracker.record_interaction(
                user_id=current_user.id,
                task_id=task_id,
                interaction_type="skip",
                device_type=device_type,
                metadata=final_metadata
            )
        
        # 记录Prometheus指标
        try:
            from app.recommendation_metrics import record_user_interaction
            record_user_interaction(interaction_type, is_rec)
        except Exception as e:
            logger.debug(f"记录Prometheus推荐指标失败: {e}")
        
        return {"status": "success", "message": "交互记录成功"}
    except Exception as e:
        logger.error(f"记录交互失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录交互失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-metrics

@router.get("/user/recommendation-stats")
def get_user_recommendation_stats(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户的推荐统计"""
    try:
        monitor = RecommendationMonitor(db)
        stats = monitor.get_user_recommendation_stats(current_user.id)
        return stats
    except Exception as e:
        logger.error(f"获取用户推荐统计失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取用户推荐统计失败")


# 已迁移到 admin_recommendation_routes.py: /admin/recommendation-analytics, /admin/top-recommended-tasks, /admin/recommendation-health, /admin/recommendation-optimization

@router.post("/recommendations/{task_id}/feedback")
def submit_recommendation_feedback(
    task_id: int,
    feedback_type: str = Body(..., pattern="^(like|dislike|not_interested|helpful)$"),
    recommendation_id: Optional[str] = Body(None),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    提交推荐反馈
    
    Args:
        feedback_type: 反馈类型 (like, dislike, not_interested, helpful)
        recommendation_id: 推荐批次ID（可选）
    """
    try:
        from app.recommendation_feedback import RecommendationFeedbackManager
        manager = RecommendationFeedbackManager(db)
        
        # 获取任务的推荐信息（如果有）
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        manager.record_feedback(
            user_id=current_user.id,
            task_id=task_id,
            feedback_type=feedback_type,
            recommendation_id=recommendation_id
        )
        
        return {"status": "success", "message": "反馈已记录"}
    except Exception as e:
        logger.error(f"记录推荐反馈失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="记录推荐反馈失败")


@router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
def accept_task(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 接收任务处理中（已移除DEBUG日志以提升性能）
    
    # 如果current_user为None，说明认证失败
    if not current_user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    try:

        # 检查用户是否为客服账号
        if False:  # 普通用户不再有客服权限
            raise HTTPException(status_code=403, detail="客服账号不能接受任务")

        db_task = load_real_task_or_404_sync(db, task_id)

        if db_task.status != "open":
            raise HTTPException(
                status_code=400, detail="Task is not available for acceptance"
            )

        if db_task.poster_id == current_user.id:
            raise HTTPException(
                status_code=400, detail="You cannot accept your own task"
            )

        # 所有用户均可接受任意等级任务（任务等级仅按赏金划分，由数据库配置的阈值决定，不限制接单权限）

        # 检查任务是否已过期
        from datetime import datetime, timezone
        from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone

        current_time = get_utc_time()

        # 如果deadline是naive datetime，假设它是UTC时间（数据库迁移后应该都是带时区的）
        if db_task.deadline.tzinfo is None:
            # 旧数据兼容：假设是UTC时间
            deadline_utc = db_task.deadline.replace(tzinfo=timezone.utc)
        else:
            deadline_utc = db_task.deadline.astimezone(timezone.utc)

        if deadline_utc < current_time:
            raise HTTPException(status_code=400, detail="Task deadline has passed")

        result = crud.accept_task(db, task_id, current_user.id)
        if isinstance(result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "user_not_found": "User not found.",
                "not_designated_taker": "This task is designated for another user.",
                "task_not_open": "Task is not available for acceptance.",
                "task_already_taken": "Task has already been taken by another user.",
                "task_deadline_passed": "Task deadline has passed.",
                "commit_failed": "Failed to save, please try again.",
                "internal_error": "An internal error occurred, please try again.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(result, result),
            )
        updated_task = result

        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（接受任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")

        # 发送通知给任务发布者
        if background_tasks:
            try:
                crud.create_notification(
                    db,
                    db_task.poster_id,
                    "task_accepted",
                    "任务已被接受",
                    f"用户 {current_user.name} 接受了您的任务 '{db_task.title}'",
                    current_user.id,
                )
            except Exception as e:
                logger.warning(f"Failed to create notification: {e}")
                # 不要因为通知失败而影响任务接受

        return updated_task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/tasks/{task_id}/approve", response_model=schemas.TaskOut)
def approve_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """
    任务发布者同意接受者进行任务
    
    ⚠️ 安全修复：添加支付验证，防止绕过支付
    注意：此端点可能已废弃，新的流程使用 accept_application 端点
    """
    import logging
    logger = logging.getLogger(__name__)
    
    db_task = crud.get_task(db, task_id)
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can approve the taker"
        )

    # ⚠️ 安全修复：检查支付状态，防止绕过支付
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试批准未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400, 
            detail="任务尚未支付，无法批准。请先完成支付。"
        )

    # 检查任务状态：必须是 pending_payment 或 in_progress 状态
    # 注意：旧的 "taken" 状态已废弃，新流程使用 pending_payment
    if db_task.status not in ["pending_payment", "in_progress", "taken"]:
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法批准。当前状态: {db_task.status}"
        )

    # 更新任务状态为进行中（如果还不是）
    # ⚠️ 安全修复：确保只有已支付的任务才能进入 in_progress 状态
    if db_task.status == "pending_payment":
        # 再次确认支付状态（双重检查）
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 pending_payment 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 pending_payment 更新为 in_progress（已确认支付）")
    elif db_task.status == "taken":
        # 兼容旧流程：如果状态是 taken，也更新为 in_progress
        # ⚠️ 安全修复：确保已支付
        if db_task.is_paid != 1:
            logger.error(
                f"🔴 安全错误：任务 {task_id} 状态为 taken 但 is_paid={db_task.is_paid}，"
                f"不允许进入 in_progress 状态"
            )
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进入进行中状态。请先完成支付。"
            )
        db_task.status = "in_progress"
        db.commit()
        logger.info(f"✅ 任务 {task_id} 状态从 taken 更新为 in_progress（旧流程兼容，已确认支付）")
    # 如果已经是 in_progress，不需要更新
    
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（批准任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 创建通知给任务接受者
    if background_tasks and db_task.taker_id:
        try:
            crud.create_notification(
                db,
                db_task.taker_id,
                "task_approved",
                "任务已批准",
                f"您的任务申请 '{db_task.title}' 已被发布者批准，可以开始工作了",
                current_user.id,
            )
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")

    return db_task


@router.post("/tasks/{task_id}/reject", response_model=schemas.TaskOut)
def reject_task_taker(
    task_id: int,
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """任务发布者拒绝接受者，任务重新变为open状态"""
    db_task = load_real_task_or_404_sync(db, task_id)

    # 检查权限：只有任务发布者可以拒绝
    if db_task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can reject the taker"
        )

    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(status_code=400, detail="Task is not in taken status")

    # 记录被拒绝的接受者ID
    rejected_taker_id = db_task.taker_id

    # 重置任务状态为open，清除接受者
    db_task.status = "open"
    db_task.taker_id = None
    db.commit()
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（拒绝任务接受者）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 创建通知给被拒绝的接受者
    if background_tasks and rejected_taker_id:
        try:
            crud.create_notification(
                db,
                rejected_taker_id,
                "task_rejected",
                "任务申请被拒绝",
                f"您的任务申请 '{db_task.title}' 已被发布者拒绝，任务已重新开放",
                current_user.id,
            )
            
            # 发送推送通知
            try:
                send_push_notification(
                    db=db,
                    user_id=rejected_taker_id,
                    notification_type="task_rejected",
                    data={"task_id": task_id},
                    template_vars={"task_title": db_task.title, "task_id": task_id}
                )
            except Exception as e:
                logger.warning(f"发送任务拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")

    return db_task


@router.patch("/tasks/{task_id}/reward", response_model=schemas.TaskOut)
def update_task_reward(
    task_id: int,
    task_update: schemas.TaskUpdate,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务价格（仅任务发布者可见）"""
    result = crud.update_task_reward(db, task_id, current_user.id, task_update.reward)
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "You don't have permission to update this task.",
            "task_not_open": "Task can only be updated while in open status.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    return result


class VisibilityUpdate(BaseModel):
    is_public: int = Field(..., ge=0, le=1, description="0=私密, 1=公开")


@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: VisibilityUpdate = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（发布者更新 is_public，接单者更新 taker_public）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    is_public = visibility_update.is_public

    if task.poster_id == current_user.id:
        task.is_public = is_public
    elif task.taker_id == current_user.id:
        task.taker_public = is_public
    else:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    db.commit()
    db.refresh(task)
    return task


@router.post("/tasks/{task_id}/review", response_model=schemas.ReviewOut)
@rate_limit("api_write", limit=10, window=60)  # 限制：10次/分钟，防止刷评价
def create_review(
    task_id: int,
    review: schemas.ReviewCreate = Body(...),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能创建评价")

    result = crud.create_review(db, current_user.id, task_id, review)
    if isinstance(result, str):
        error_messages = {
            "task_not_completed": "Task is not completed yet.",
            "not_participant": "You are not a participant of this task.",
            "already_reviewed": "You have already reviewed this task.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )
    db_review = result
    
    # 清除评价列表缓存，确保新评价立即显示
    try:
        from app.cache import invalidate_cache
        # 清除该任务的所有评价缓存（使用通配符匹配所有可能的缓存键）
        invalidate_cache(f"task_reviews:get_task_reviews:*")
        logger.info(f"已清除任务 {task_id} 的评价列表缓存")
    except Exception as e:
        logger.warning(f"清除评价缓存失败: {e}")
    
    # P2 优化：异步处理非关键操作（发送通知等）
    if background_tasks:
        def send_review_notification():
            """后台发送评价通知（非关键操作）"""
            try:
                # 获取任务信息
                task = crud.get_task(db, task_id)
                if not task:
                    return
                
                # 确定被评价的用户（不是评价者）
                reviewed_user_id = None
                if task.is_multi_participant:
                    # 多人任务：参与者评价达人，达人评价第一个参与者
                    if task.created_by_expert and task.expert_creator_id:
                        if current_user.id != task.expert_creator_id:
                            reviewed_user_id = task.expert_creator_id
                        elif task.originating_user_id:
                            reviewed_user_id = task.originating_user_id
                    elif task.taker_id and current_user.id != task.taker_id:
                        reviewed_user_id = task.taker_id
                else:
                    # 单人任务：发布者评价接受者，接受者评价发布者
                    reviewed_user_id = task.taker_id if current_user.id == task.poster_id else task.poster_id
                
                # 通知被评价的用户
                if reviewed_user_id and reviewed_user_id != current_user.id:
                    crud.create_notification(
                        db,
                        reviewed_user_id,
                        "review_created",
                        "收到新评价",
                        f"任务 '{task.title}' 收到了新评价",
                        related_id=str(task_id),
                        related_type="task_id",
                        title_en="New Review Received",
                        content_en=f"New review received for task '{task.title}'",
                    )
            except Exception as e:
                logger.warning(f"发送评价通知失败: {e}")
        
        background_tasks.add_task(send_review_notification)
    
    return db_review


@router.get("/tasks/{task_id}/reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_task_reviews")
def get_task_reviews(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    # 内容审核检查：隐藏的任务不返回评价
    task = load_real_task_or_404_sync(db, task_id)
    if not task.is_visible:
        raise HTTPException(status_code=404, detail="Task not found")
    current_user_id = current_user.id if current_user else None
    reviews = crud.get_task_reviews(db, task_id, current_user_id=current_user_id)
    return [schemas.ReviewOut.model_validate(r) for r in reviews]


@router.get("/users/{user_id}/received-reviews", response_model=list[schemas.ReviewOut])
@measure_api_performance("get_user_received_reviews")
@cache_response(ttl=300, key_prefix="user_reviews")  # 缓存5分钟
def get_user_received_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    return crud.get_user_received_reviews(db, user_id)


@router.get("/{user_id}/reviews")
@measure_api_performance("get_user_reviews")
@cache_response(ttl=300, key_prefix="user_reviews_alt")  # 缓存5分钟
def get_user_reviews(user_id: str, db: Session = Depends(get_db)):
    """获取用户收到的评价（用于个人主页显示）"""
    try:
        reviews = crud.get_user_reviews_with_reviewer_info(db, user_id)
        return reviews
    except Exception as e:
        import traceback
        logger.error(f"获取用户评价失败: {e}")
        logger.error(traceback.format_exc())
        return []


@router.post("/tasks/{task_id}/complete", response_model=schemas.TaskOut)
def complete_task(
    task_id: int,
    evidence_images: Optional[List[str]] = Body(None, description="证据图片URL列表"),
    evidence_text: Optional[str] = Body(None, description="文字证据说明（可选）"),
    background_tasks: BackgroundTasks = None,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 检查用户是否为客服账号
    if False:  # 普通用户不再有客服权限
        raise HTTPException(status_code=403, detail="客服账号不能完成任务")

    # 验证文字证据长度
    if evidence_text and len(evidence_text.strip()) > 500:
        raise HTTPException(
            status_code=400,
            detail="文字证据说明不能超过500字符"
        )

    # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发完成
    locked_task_query = select(models.Task).where(
        models.Task.id == task_id
    ).with_for_update()
    db_task = db.execute(locked_task_query).scalar_one_or_none()
    
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    if db_task.is_consultation_placeholder:
        raise HTTPException(status_code=404, detail="任务不存在")  # 防探测:同 404 遮掩占位 task 存在

    if db_task.status != "in_progress":
        raise HTTPException(status_code=400, detail="Task is not in progress")

    # 权限检查: 单人任务只有 taker 能完成；
    # 团队任务 (taker_expert_id 非空) 允许 owner/admin 任意一人完成。
    if db_task.taker_id != current_user.id:
        if db_task.taker_expert_id:
            from app.permissions.expert_permissions import require_team_role_sync
            require_team_role_sync(
                db, db_task.taker_expert_id, current_user.id, minimum="admin"
            )
        else:
            raise HTTPException(
                status_code=403, detail="Only the task taker can complete the task"
            )

    # ⚠️ 安全修复：检查支付状态，确保只有已支付的任务才能完成
    if not db_task.is_paid:
        logger.warning(
            f"⚠️ 安全警告：用户 {current_user.id} 尝试完成未支付的任务 {task_id}"
        )
        raise HTTPException(
            status_code=400,
            detail="任务尚未支付，无法完成。请联系发布者完成支付。"
        )

    # 更新任务状态为等待确认
    from datetime import timedelta
    now = get_utc_time()
    db_task.status = "pending_confirmation"
    db_task.completed_at = now
    # 设置确认截止时间：completed_at + 5天
    db_task.confirmation_deadline = now + timedelta(days=5)
    # 清除之前的提醒状态
    db_task.confirmation_reminder_sent = 0
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"完成任务状态更新失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="任务状态更新失败，请重试")
    db.refresh(db_task)
    
    # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
    try:
        from app.services.task_service import TaskService
        TaskService.invalidate_cache(task_id)
        from app.redis_cache import invalidate_tasks_cache
        invalidate_tasks_cache()
        logger.info(f"✅ 已清除任务 {task_id} 的缓存（完成任务）")
    except Exception as e:
        logger.warning(f"⚠️ 清除任务缓存失败: {e}")

    # 发送系统消息到任务聊天框
    try:
        from app.models import Message, MessageAttachment
        from app.utils.notification_templates import get_notification_texts
        import json
        
        taker_name = current_user.name or f"用户{current_user.id}"
        # 根据是否有证据（图片或文字）显示不同的消息内容
        has_evidence = (evidence_images and len(evidence_images) > 0) or (evidence_text and evidence_text.strip())
        if has_evidence:
            # 使用国际化模板
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=True
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                if evidence_text and evidence_text.strip():
                    content_zh = f"任务已完成。{evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_zh = "任务已完成，请查看证据图片。"
            if not content_en:
                if evidence_text and evidence_text.strip():
                    content_en = f"Task completed. {evidence_text[:50]}{'...' if len(evidence_text) > 50 else ''}"
                else:
                    content_en = "Task completed. Please check the evidence images."
        else:
            _, content_zh, _, content_en = get_notification_texts(
                "task_completed",
                taker_name=taker_name,
                task_title=db_task.title,
                has_evidence=False
            )
            # 如果没有对应的模板，使用默认文本
            if not content_zh:
                content_zh = f"接收者 {taker_name} 已确认完成任务，等待发布者确认。"
            if not content_en:
                content_en = f"Recipient {taker_name} has confirmed task completion, waiting for poster confirmation."
        
        # 构建meta信息，包含证据信息
        meta_data = {
            "system_action": "task_completed_by_taker",
            "content_en": content_en
        }
        if evidence_text and evidence_text.strip():
            meta_data["evidence_text"] = evidence_text
        if evidence_images and len(evidence_images) > 0:
            meta_data["evidence_images_count"] = len(evidence_images)
        
        system_message = Message(
            sender_id=None,  # 系统消息，sender_id为None
            receiver_id=None,
            content=content_zh,  # 中文内容（英文存于 meta.content_en 供客户端本地化）
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps(meta_data),
            created_at=get_utc_time()
        )
        db.add(system_message)
        db.flush()  # 获取消息ID
        
        # 如果有证据图片，创建附件（满足 ck_message_attachments_url_blob：url 与 blob_id 二选一）
        if evidence_images:
            for image_url in evidence_images:
                # 从URL中提取image_id（如果URL格式为 {base_url}/api/private-image/{image_id}?user=...&token=...）
                image_id = None
                if image_url and '/api/private-image/' in image_url:
                    try:
                        from urllib.parse import urlparse
                        parsed_url = urlparse(image_url)
                        if '/api/private-image/' in parsed_url.path:
                            path_parts = parsed_url.path.split('/api/private-image/')
                            if len(path_parts) > 1:
                                image_id = path_parts[1].split('?')[0]
                                logger.debug(f"Extracted image_id {image_id} from URL {image_url}")
                    except Exception as e:
                        logger.warning(f"Failed to extract image_id from URL {image_url}: {e}")
                # 约束要求 (url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL)
                if image_id:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=None,
                        blob_id=image_id,
                        meta=None,
                        created_at=get_utc_time()
                    )
                else:
                    attachment = MessageAttachment(
                        message_id=system_message.id,
                        attachment_type="image",
                        url=image_url,
                        blob_id=None,
                        meta=None,
                        created_at=get_utc_time()
                    )
                db.add(attachment)
        
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to send system message: {e}")
        # 系统消息发送失败不影响任务完成流程

    # 发送任务完成通知和邮件给发布者（始终创建通知，让发布者知道完成情况与证据）
    try:
        from app.task_notifications import send_task_completion_notification
        from fastapi import BackgroundTasks
        
        # 确保 background_tasks 存在，如果为 None 则创建新实例
        if background_tasks is None:
            background_tasks = BackgroundTasks()
        
        # 只要任务有发布者就发送通知（不依赖 poster 对象是否存在）
        if db_task.poster_id:
            send_task_completion_notification(
                db=db,
                background_tasks=background_tasks,
                task=db_task,
                taker=current_user,
                evidence_images=evidence_images,
                evidence_text=evidence_text,
            )
    except Exception as e:
        logger.warning(f"Failed to send task completion notification: {e}")
        # 通知发送失败不影响任务完成流程

    # 检查任务接受者是否满足VIP晋升条件
    try:
        crud.check_and_upgrade_vip_to_super(db, current_user.id)
    except Exception as e:
        logger.warning(f"Failed to check VIP upgrade: {e}")

    return db_task


@router.post("/tasks/{task_id}/cancel")
def cancel_task(
    task_id: int,
    cancel_data: schemas.TaskCancelRequest = Body(default=schemas.TaskCancelRequest()),
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """取消任务 - 如果任务已被接受，需要客服审核"""
    task = load_real_task_or_404_sync(db, task_id)

    # 检查权限：只有任务发布者或接受者可以取消任务
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster or taker can cancel the task"
        )

    # 如果任务状态是 'open'，直接取消
    if task.status == "open":
        cancel_result = crud.cancel_task(db, task_id, current_user.id)
        if isinstance(cancel_result, str):
            error_messages = {
                "task_not_found": "Task not found.",
                "cancel_not_permitted": "You don't have permission to cancel this task.",
                "not_participant": "Only task participants can cancel.",
            }
            raise HTTPException(
                status_code=400,
                detail=error_messages.get(cancel_result, cancel_result),
            )
        cancelled_task = cancel_result
        
        # ⚠️ 清除任务缓存，确保前端立即看到更新后的状态
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
            from app.redis_cache import invalidate_tasks_cache
            invalidate_tasks_cache()
            logger.info(f"✅ 已清除任务 {task_id} 的缓存（取消任务）")
        except Exception as e:
            logger.warning(f"⚠️ 清除任务缓存失败: {e}")
        
        return cancelled_task

    # pending_payment 状态: buyer 在支付前可以自助取消(无需客服审核)
    # 场景: 团队服务被 owner approve 后,Task 进入 pending_payment 等支付,
    # buyer 反悔不想付。需要 cancel PaymentIntent + 回滚 ServiceApplication。
    elif task.status == "pending_payment":
        # 仅 poster (买家) 能在 pending_payment 自助取消;接单方也可以(代取消)
        if task.poster_id != current_user.id and task.taker_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail="Only the buyer or assignee can cancel a pending payment task",
            )

        # 1) Cancel Stripe PaymentIntent (best-effort)
        if task.payment_intent_id:
            try:
                import stripe
                from app.stripe_config import ensure_stripe_configured
                ensure_stripe_configured()
                pi = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                # 仅当 PI 还可以取消的状态才 cancel(已 succeeded 走 refund 路径,不在这里处理)
                if pi.status in (
                    "requires_payment_method",
                    "requires_confirmation",
                    "requires_action",
                    "processing",
                ):
                    stripe.PaymentIntent.cancel(task.payment_intent_id)
                    logger.info(f"PaymentIntent {task.payment_intent_id} cancelled by user")
                elif pi.status == "succeeded":
                    # PI 已 succeeded 但 webhook 还没处理,这是窗口期。拒绝自助取消,
                    # 让 webhook 流转完成后走标准退款流程
                    raise HTTPException(
                        status_code=409,
                        detail="支付已完成,请刷新页面后通过取消任务流程申请退款",
                    )
            except HTTPException:
                raise
            except Exception as e:
                logger.warning(f"Stripe PI cancel 失败 (不阻塞任务取消): {e}")

        # 2) 回滚 ServiceApplication 到 cancelled (如果是团队服务流程)
        try:
            sa = db.query(models.ServiceApplication).filter(
                models.ServiceApplication.task_id == task_id
            ).first()
            if sa:
                sa.status = "cancelled"
                sa.updated_at = get_utc_time()
                # 回退时间段参与者占位 (与 user_service_application_routes 一致)
                if sa.time_slot_id:
                    db.execute(
                        update(models.ServiceTimeSlot)
                        .where(models.ServiceTimeSlot.id == sa.time_slot_id)
                        .where(models.ServiceTimeSlot.current_participants > 0)
                        .values(
                            current_participants=models.ServiceTimeSlot.current_participants - 1
                        )
                    )
        except Exception as e:
            logger.warning(f"回滚 ServiceApplication 失败: {e}")

        # 3) 任务标记为 cancelled
        task.status = "cancelled"
        task.cancelled_at = get_utc_time()

        # 原任务取消 → 所有指向它的咨询占位一并归档
        try:
            from app.consultation.approval import close_placeholders_for_task
            close_placeholders_for_task(
                db,
                original_task_id=task_id,
                reason_zh="任务已被取消,咨询自动关闭",
                reason_en="Task cancelled. Consultation auto-closed.",
                system_action="consultation_auto_closed_on_task_cancelled",
            )
        except Exception as _cp_err:
            logger.warning(
                f"⚠️ [cancel-task] 批量归档咨询占位失败(不阻断主流程): "
                f"task_id={task_id} err={_cp_err}"
            )

        db.commit()

        # 4) 通知双方
        try:
            from app.utils.notification_templates import get_notification_texts
            crud.create_notification(
                db=db,
                user_id=task.poster_id,
                type="task_cancelled",
                title="任务已取消",
                content=f"任务「{task.title}」已取消,如已扣款将自动退回。",
                related_id=str(task_id),
                auto_commit=False,
            )
            if task.taker_id and task.taker_id != task.poster_id:
                crud.create_notification(
                    db=db,
                    user_id=task.taker_id,
                    type="task_cancelled",
                    title="订单已被取消",
                    content=f"任务「{task.title}」已被买家取消。",
                    related_id=str(task_id),
                    auto_commit=False,
                )
            db.commit()
        except Exception as e:
            logger.warning(f"取消通知发送失败: {e}")

        # 清缓存
        try:
            from app.services.task_service import TaskService
            TaskService.invalidate_cache(task_id)
        except Exception:
            pass

        return {"message": "任务已取消", "status": "cancelled"}

    # 如果任务已被接受或正在进行中，创建取消请求等待客服审核
    elif task.status in ["taken", "in_progress"]:
        # 检查是否已有待审核的取消请求
        existing_request = crud.get_task_cancel_requests(db, "pending")
        existing_request = next(
            (req for req in existing_request if req.task_id == task_id), None
        )

        if existing_request:
            raise HTTPException(
                status_code=400,
                detail="A cancel request is already pending for this task",
            )

        # 创建取消请求
        cancel_request = crud.create_task_cancel_request(
            db, task_id, current_user.id, cancel_data.reason
        )

        # 注意：不发送通知到 notifications 表，因为客服不在 users 表中
        # 客服可以通过客服面板的取消请求列表查看待审核的请求
        # 如果需要通知功能，应该使用 staff_notifications 表通知所有在线客服

        return {
            "message": "Cancel request submitted for admin review",
            "request_id": cancel_request.id,
        }

    else:
        raise HTTPException(
            status_code=400, detail="Task cannot be cancelled in current status"
        )


@router.delete("/tasks/{task_id}/delete")
def delete_cancelled_task(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    """删除已取消的任务"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # 只有任务发布者可以删除任务
    if task.poster_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only task poster can delete the task"
        )

    # 只有已取消的任务可以删除
    if task.status != "cancelled":
        raise HTTPException(
            status_code=400, detail="Only cancelled tasks can be deleted"
        )

    # 使用新的安全删除函数
    result = crud.delete_user_task(db, task_id, current_user.id)
    if isinstance(result, str):
        error_messages = {
            "task_not_found": "Task not found.",
            "not_task_poster": "Only the task poster can delete this task.",
            "task_not_cancelled": "Only cancelled tasks can be deleted.",
            "delete_failed": "Failed to delete task, please try again.",
        }
        raise HTTPException(
            status_code=400,
            detail=error_messages.get(result, result),
        )

    return result


@router.get("/tasks/{task_id}/history")
@measure_api_performance("get_task_history")
@cache_response(ttl=180, key_prefix="task_history")  # 缓存3分钟
def get_task_history(
    task_id: int,
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    # 安全校验：只允许任务参与者查看任务历史
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.poster_id != current_user.id and task.taker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this task's history")
    
    history = crud.get_task_history(db, task_id)
    return [
        {
            "id": h.id,
            "user_id": h.user_id,
            "action": h.action,
            "timestamp": h.timestamp,
            "remark": h.remark,
        }
        for h in history
    ]


@router.get("/my-tasks")
@measure_api_performance("get_my_tasks")
def get_my_tasks(
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, description="页码，从 1 开始"),
    page_size: int = Query(20, ge=1, le=100, description="每页条数"),
    role: str | None = Query(None, description="角色筛选: poster=我发布的, taker=我接取的"),
    status: str | None = Query(None, description="状态筛选: open, in_progress, completed, cancelled 等"),
):
    """获取当前用户的任务（支持按 role/status 筛选与分页）。返回 { tasks, total, page, page_size }。"""
    offset = (page - 1) * page_size
    tasks, total = crud.get_user_tasks(
        db, current_user.id,
        limit=page_size, offset=offset,
        role=role, status=status,
    )

    # 任务双语字段已由 ORM 从任务表列加载；缺失时后台触发预取
    task_ids = [task.id for task in tasks]
    missing_task_ids = [
        t.id for t in tasks
        if not getattr(t, "title_en", None) or not getattr(t, "title_zh", None)
        or not getattr(t, "description_en", None) or not getattr(t, "description_zh", None)
    ]
    if missing_task_ids:
        _trigger_background_translation_prefetch(
            missing_task_ids,
            target_languages=["en", "zh"],
            label="后台翻译任务",
        )

    # 批量加载展示勋章
    from app.utils.badge_helpers import enrich_displayed_badges_sync
    _badge_user_ids = set()
    for t in tasks:
        if t.poster is not None:
            _badge_user_ids.add(t.poster.id)
        if t.taker is not None:
            _badge_user_ids.add(t.taker.id)
    _badge_cache = enrich_displayed_badges_sync(db, list(_badge_user_ids))

    # 序列化任务，并附带相关用户简要信息（当前用户是任务相关方）
    task_list = []
    for t in tasks:
        task_dict = schemas.TaskOut.model_validate(t).model_dump()
        if t.poster is not None:
            task_dict["poster"] = schemas.UserBrief.model_validate(t.poster).model_dump()
            task_dict["poster"]["displayed_badge"] = _badge_cache.get(t.poster.id)
        if t.taker is not None:
            task_dict["taker"] = schemas.UserBrief.model_validate(t.taker).model_dump()
            task_dict["taker"]["displayed_badge"] = _badge_cache.get(t.taker.id)
        task_list.append(task_dict)

    return {
        "tasks": task_list,
        "total": total,
        "page": page,
        "page_size": page_size,
    }


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


@router.post("/tasks/{task_id}/pay")
def create_payment(
    task_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    task = load_real_task_or_404_sync(db, task_id)
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="任务不存在")  # combined 404 preserves 防探测
    if task.is_paid:
        return {"message": "Task already paid."}
    # 计算任务金额和平台服务费（用于 metadata 交叉校验）
    from app.utils.fee_calculator import calculate_application_fee_pence
    task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
    task_amount_pence = round(task_amount * 100)
    task_source = getattr(task, "task_source", None)
    task_type = getattr(task, "task_type", None)
    application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
    # 创建Stripe支付会话
    session = stripe.checkout.Session.create(
        payment_method_types=_payment_method_types_for_currency((task.currency or "GBP").lower()),
        line_items=[
            {
                "price_data": {
                    "currency": (task.currency or "GBP").lower(),
                    "product_data": {"name": task.title},
                    "unit_amount": task_amount_pence,
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        success_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/success",
        cancel_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/cancel",
        metadata={
            "task_id": task_id,
            "application_fee": application_fee_pence,
            "task_source": task_source or "",
            "task_type": task_type or "",
        },
    )
    return {"checkout_url": session.url}


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


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    import logging
    import json
    logger = logging.getLogger(__name__)
    
    # 记录请求开始时间
    import time
    start_time = time.time()
    
    # 确保 crud 模块已导入（避免 UnboundLocalError）
    from app import crud
    # 确保 SQLAlchemy 函数已导入（避免 UnboundLocalError）
    from sqlalchemy import and_, func, select
    
    # 获取请求信息
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    content_type = request.headers.get("content-type", "unknown")
    user_agent = request.headers.get("user-agent", "unknown")
    client_ip = request.client.host if request.client else "unknown"
    
    # 记录webhook接收（关键信息保留INFO，详细信息降级为DEBUG）
    logger.info("=" * 80)
    logger.info(f"🔔 [WEBHOOK] 收到 Stripe Webhook 请求")
    logger.debug(f"  - 时间: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())}")
    logger.debug(f"  - 客户端IP: {client_ip}")
    logger.debug(f"  - User-Agent: {user_agent}")
    logger.debug(f"  - Content-Type: {content_type}")
    logger.debug(f"  - Payload 大小: {len(payload)} bytes")
    logger.debug(f"  - Signature 前缀: {sig_header[:30] if sig_header else 'None'}...")
    logger.debug(f"  - Secret 配置: {'✅ 已配置' if endpoint_secret else '❌ 未配置'}")
    
    # 严格验证 Webhook 签名（安全要求）
    # 只有通过 Stripe 签名验证的请求才能处理
    if not endpoint_secret:
        logger.error(f"❌ [WEBHOOK] 安全错误：STRIPE_WEBHOOK_SECRET 未配置")
        return JSONResponse(status_code=500, content={"error": "Webhook secret not configured"})
    
    if not sig_header:
        logger.error(f"❌ [WEBHOOK] 安全错误：缺少 Stripe 签名头")
        return JSONResponse(status_code=400, content={"error": "Missing stripe-signature header"})
    
    try:
        # 严格验证 Webhook 签名
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
        logger.debug(f"✅ [WEBHOOK] 事件验证成功（签名已验证）")
    except ValueError as e:
        logger.error(f"❌ [WEBHOOK] Invalid payload: {e}")
        logger.error(f"  - Payload 内容 (前500字符): {payload[:500].decode('utf-8', errors='ignore')}")
        return JSONResponse(status_code=400, content={"error": "Invalid payload"})
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"❌ [WEBHOOK] 安全错误：签名验证失败: {e}")
        logger.error(f"  - 提供的 Signature: {sig_header[:50]}...")
        logger.error(f"  - 使用的 Secret: ***{endpoint_secret[-4:]}")
        logger.error(f"  - 这可能是恶意请求或配置错误，已拒绝处理")
        return JSONResponse(status_code=400, content={"error": "Invalid signature"})
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 处理错误: {type(e).__name__}: {e}")
        import traceback
        logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
        return JSONResponse(status_code=400, content={"error": str(e)})
    
    event_type = event["type"]
    event_id = event.get("id")
    event_data = event["data"]["object"]
    livemode = event.get("livemode", False)
    created = event.get("created")
    
    # 记录事件关键信息（详细信息降级为DEBUG）
    logger.info(f"📦 [WEBHOOK] 事件: {event_type} (ID: {event_id})")
    logger.debug(f"  - Livemode: {livemode}")
    logger.debug(f"  - 创建时间: {created} ({time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(created)) if created else 'N/A'})")
    
    # Idempotency 检查：防止重复处理同一个 webhook 事件
    import json
    from app.utils.time_utils import get_utc_time
    
    if event_id:
        existing_event = db.query(models.WebhookEvent).filter(
            models.WebhookEvent.event_id == event_id
        ).first()
        
        if existing_event:
            if existing_event.processed:
                logger.warning(f"⚠️ [WEBHOOK] 事件已处理过，跳过: event_id={event_id}, processed_at={existing_event.processed_at}")
                return {"status": "already_processed", "event_id": event_id}
            else:
                logger.info(f"🔄 [WEBHOOK] 事件之前处理失败，重新处理: event_id={event_id}, error={existing_event.processing_error}")
        else:
            # 创建新的事件记录
            webhook_event = models.WebhookEvent(
                event_id=event_id,
                event_type=event_type,
                livemode=livemode,
                processed=False,
                event_data=json.loads(json.dumps(event))  # 保存完整事件数据
            )
            db.add(webhook_event)
            try:
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 已创建事件记录: event_id={event_id}")
            except Exception as e:
                db.rollback()
                logger.error(f"❌ [WEBHOOK] 创建事件记录失败: {e}")
                # 如果是因为重复事件ID导致的错误，可能是并发请求，检查是否已存在
                existing_event = db.query(models.WebhookEvent).filter(
                    models.WebhookEvent.event_id == event_id
                ).first()
                if existing_event and existing_event.processed:
                    logger.warning(f"⚠️ [WEBHOOK] 并发请求，事件已处理: event_id={event_id}")
                    return {"status": "already_processed", "event_id": event_id}
                raise
    else:
        logger.error(f"❌ [WEBHOOK] 事件缺少 event_id，拒绝处理以保证幂等性: event_type={event_type}")
        return JSONResponse(status_code=400, content={"error": "Missing event_id, cannot guarantee idempotency"})
    
    # 标记事件开始处理
    processing_started = False
    try:
        if event_id:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = False  # 重置处理状态
                webhook_event.processing_error = None
                db.commit()
                processing_started = True
    except Exception as e:
        logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}")
        db.rollback()
    
    # 如果是 payment_intent 相关事件，记录关键信息（详细信息降级为DEBUG）
    if "payment_intent" in event_type:
        payment_intent_id = event_data.get("id")
        payment_status = event_data.get("status")
        amount = event_data.get("amount")
        currency = event_data.get("currency", "unknown")
        metadata = event_data.get("metadata", {})
        logger.info(f"💳 [WEBHOOK] Payment Intent: {payment_intent_id}, 状态: {payment_status}, 金额: {amount / 100 if amount else 0:.2f} {currency.upper()}")
        logger.debug(f"  - Metadata: {json.dumps(metadata, ensure_ascii=False)}")
        logger.debug(f"  - Task ID: {metadata.get('task_id', 'N/A')}, Application ID: {metadata.get('application_id', 'N/A')}, Pending Approval: {metadata.get('pending_approval', 'N/A')}")
    
    # 处理 Payment Intent 事件（用于 Stripe Elements）
    if event_type == "payment_intent.succeeded":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        
        logger.info(f"Payment intent succeeded: {payment_intent_id}, task_id: {task_id}, amount: {payment_intent.get('amount')}")

        # ── Activity apply payment (no task_id, has activity_apply metadata) ──
        metadata = payment_intent.get("metadata", {})
        if metadata.get("activity_apply") == "true" and not task_id:
            _act_id = _safe_int_metadata(payment_intent, "activity_id")
            _act_user_id = metadata.get("user_id")
            _act_expert_id = metadata.get("expert_id")
            _act_expert_user_id = metadata.get("expert_user_id")

            if _act_id and _act_user_id:
                try:
                    # Find payment_pending application
                    _app_row = db.execute(
                        select(models.OfficialActivityApplication).where(
                            models.OfficialActivityApplication.activity_id == _act_id,
                            models.OfficialActivityApplication.user_id == _act_user_id,
                            models.OfficialActivityApplication.payment_intent_id == payment_intent_id,
                            models.OfficialActivityApplication.status == "payment_pending",
                        ).with_for_update()
                    ).scalar_one_or_none()

                    if _app_row:
                        _act = db.execute(
                            select(models.Activity).where(models.Activity.id == _act_id).with_for_update()
                        ).scalar_one_or_none()

                        if _act and _act.activity_type == "first_come":
                            from sqlalchemy import func as _sa_func
                            _attending = db.execute(
                                select(_sa_func.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _act_id,
                                    models.OfficialActivityApplication.status == "attending",
                                )
                            ).scalar() or 0
                            if _attending >= (_act.prize_count or 0):
                                # Full — refund
                                try:
                                    stripe.Refund.create(payment_intent=payment_intent_id)
                                    logger.info(f"Activity {_act_id} full, refunded PI {payment_intent_id}")
                                except Exception as _ref_err:
                                    logger.error(f"Activity refund failed for PI {payment_intent_id}: {_ref_err}")
                                _app_row.status = "refunded"
                            else:
                                _app_row.status = "attending"
                        elif _act and _act.activity_type == "lottery":
                            _app_row.status = "pending"
                        else:
                            _app_row.status = "pending"

                        _app_row.amount_paid = payment_intent.get("amount")

                        # PaymentHistory
                        from app.utils.fee_calculator import calculate_application_fee_pence as _calc_fee
                        _amt = payment_intent.get("amount", 0)
                        _fee = _calc_fee(_amt, task_source="expert_activity", task_type=getattr(_act, "task_type", None) if _act else None)
                        _taker_amt = max(0, _amt - _fee)

                        import uuid as _uuid
                        _ph = models.PaymentHistory(
                            order_no=f"ACT{_act_id}-{_uuid.uuid4().hex[:12]}",
                            user_id=_act_user_id,
                            payment_intent_id=payment_intent_id,
                            payment_method="stripe",
                            total_amount=_amt,
                            stripe_amount=_amt,
                            final_amount=_amt,
                            currency=(_act.currency if _act else "GBP") or "GBP",
                            status="succeeded",
                            application_fee=_fee,
                            escrow_amount=_taker_amt / 100.0,
                            extra_metadata={"activity_id": _act_id, "activity_apply": True},
                        )
                        db.add(_ph)

                        # PaymentTransfer for async payout
                        if _app_row.status != "refunded" and _act_expert_id and _taker_amt > 0:
                            _pt = models.PaymentTransfer(
                                taker_id=_act_expert_user_id or _act_user_id,
                                taker_expert_id=_act_expert_id,
                                poster_id=_act_user_id,
                                amount=_taker_amt / 100.0,
                                currency=(_act.currency if _act else "GBP") or "GBP",
                                status="pending",
                                idempotency_key=f"act-{_act_id}-{payment_intent_id}",
                                extra_metadata={"activity_id": _act_id, "payment_intent_id": payment_intent_id},
                            )
                            db.add(_pt)

                        db.commit()
                        logger.info(f"✅ Activity payment confirmed: activity={_act_id}, user={_act_user_id}, status={_app_row.status}")

                        # by_count trigger (sync) — re-lock activity to prevent race
                        if (
                            _act and _act.activity_type == "lottery"
                            and _act.draw_mode == "auto"
                            and _act.draw_trigger in ("by_count", "both")
                            and _act.draw_participant_count
                        ):
                            from sqlalchemy import func as _sa_func2
                            _pend = db.execute(
                                select(_sa_func2.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _act_id,
                                    models.OfficialActivityApplication.status == "pending",
                                )
                            ).scalar() or 0
                            if _pend >= _act.draw_participant_count:
                                # Re-lock activity after commit to prevent concurrent draws
                                _act_locked = db.execute(
                                    select(models.Activity).where(models.Activity.id == _act_id).with_for_update()
                                ).scalar_one_or_none()
                                if _act_locked and not _act_locked.is_drawn:
                                    from app.draw_logic import perform_draw_sync
                                    try:
                                        perform_draw_sync(db, _act_locked)
                                        logger.info(f"✅ by_count auto-draw triggered for activity {_act_id}")
                                    except Exception as _draw_err:
                                        logger.error(f"by_count auto-draw failed: {_draw_err}")
                    else:
                        logger.warning(f"⚠️ Activity payment: no payment_pending app found for activity={_act_id}, user={_act_user_id}, pi={payment_intent_id}")

                except Exception as _act_err:
                    logger.error(f"❌ Activity payment webhook error: activity={_act_id}, error={_act_err}", exc_info=True)
                    try:
                        db.rollback()
                    except Exception:
                        pass

        if task_id:
            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务，防止并发webhook更新
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:  # 幂等性检查
                task.is_paid = 1
                task.payment_intent_id = payment_intent_id  # 保存 Payment Intent ID 用于关联
                # spec §3.4a — 团队任务 90 天 Stripe Transfer 时效检查、
                # warn-long-running-team-tasks 60 天告警 Celery 任务都依赖此字段。
                # 不写这一行的话 payment_transfer_service.execute_transfer 的窗口检查
                # 永远是 NULL 跳过，celery beat 任务永远查不到行，整套防御层失效。
                task.payment_completed_at = get_utc_time()
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
                
                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额
                # metadata仅作为交叉校验参考；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)

                # 交叉校验metadata中的费用（仅记录差异，不使用metadata值）
                metadata = payment_intent.get("metadata", {})
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数

                # ==================== 钱包混合支付：确认钱包扣款 ====================
                metadata = payment_intent.get("metadata", {})
                _wallet_tx_id = metadata.get("wallet_tx_id")
                if _wallet_tx_id:
                    try:
                        from app.wallet_service import complete_debit
                        complete_debit(db, int(_wallet_tx_id))
                        logger.info(f"✅ [WEBHOOK] 钱包扣款已确认: wallet_tx_id={_wallet_tx_id}, task_id={task_id}")
                    except Exception as wallet_err:
                        logger.error(f"❌ [WEBHOOK] 确认钱包扣款失败: wallet_tx_id={_wallet_tx_id}, error={wallet_err}")
                        # 钱包确认失败不阻塞主流程（交易已经 pending，可后续修复）

                # 检查是否是待确认的批准（pending_approval）
                is_pending_approval = metadata.get("pending_approval") == "true"
                
                # ⚠️ 优化：如果是跳蚤市场购买，支付成功后更新商品状态为 sold
                payment_type = metadata.get("payment_type")
                if payment_type == "flea_market_direct_purchase" or payment_type == "flea_market_purchase_request":
                    flea_market_item_id = metadata.get("flea_market_item_id")
                    if flea_market_item_id:
                        try:
                            from app.models import FleaMarketItem
                            from app.id_generator import parse_flea_market_id
                            db_item_id = parse_flea_market_id(flea_market_item_id)
                            
                            # 更新商品状态为 sold（支付成功后）
                            # ⚠️ 优化：支持 active 或 reserved 状态（reserved 是已关联任务但未支付的状态）
                            # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录，防止并发支付重复标记 sold
                            flea_item = db.query(FleaMarketItem).filter(
                                and_(
                                    FleaMarketItem.id == db_item_id,
                                    FleaMarketItem.sold_task_id == task_id,
                                    FleaMarketItem.status.in_(["active", "reserved"])
                                )
                            ).with_for_update().first()

                            if flea_item:
                                flea_item.status = "sold"
                                # 确保 sold_task_id 已设置（双重保险）
                                if flea_item.sold_task_id != task_id:
                                    flea_item.sold_task_id = task_id
                                db.flush()
                                logger.info(f"✅ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 支付成功，状态已更新为 sold (task_id: {task_id})")
                                
                                # 清除商品缓存（invalidate_item_cache 会自动清除列表缓存和详情缓存）
                                from app.flea_market_extensions import invalidate_item_cache
                                invalidate_item_cache(flea_item.id)
                                logger.info(f"✅ [WEBHOOK] 已清除跳蚤市场商品缓存（包括列表和详情）")
                                
                                # ✅ 支付成功后，发送"商品已售出"通知给卖家
                                # 注意：下单时仅发送"商品已被下单"通知，此处才是真正的"已售出"
                                try:
                                    buyer_name = metadata.get("poster_name", "买家")
                                    item_title = flea_item.title or metadata.get("task_title", "商品")
                                    
                                    crud.create_notification(
                                        db=db,
                                        user_id=flea_item.seller_id,
                                        type="flea_market_sold",
                                        title="商品已售出",
                                        content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                    
                                    # 发送推送通知给卖家
                                    try:
                                        from app.id_generator import format_flea_market_id
                                        send_push_notification(
                                            db=db,
                                            user_id=flea_item.seller_id,
                                            title=None,  # 从模板生成（根据用户语言偏好）
                                            body=None,   # 从模板生成
                                            notification_type="flea_market_sold",
                                            data={
                                                "item_id": format_flea_market_id(flea_item.id),
                                                "task_id": task_id
                                            },
                                            template_vars={
                                                "item_title": item_title
                                            }
                                        )
                                    except Exception as push_err:
                                        logger.warning(f"⚠️ [WEBHOOK] 发送商品售出推送通知失败: {push_err}")
                                    
                                    # 同时通知买家：支付成功
                                    buyer_id = metadata.get("poster_id")
                                    if buyer_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="flea_market_payment_success",
                                            title="支付成功",
                                            content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                            related_id=str(task_id),
                                            auto_commit=False,
                                        )
                                    
                                    logger.info(f"✅ [WEBHOOK] 跳蚤市场商品售出通知已创建 (seller_id: {flea_item.seller_id}, task_id: {task_id})")
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建商品售出通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 跳蚤市场商品 {flea_market_item_id} 未找到或状态不匹配 (db_id: {db_item_id}, task_id: {task_id})")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 更新跳蚤市场商品状态失败: {e}", exc_info=True)

                # ⚠️ 跳蚤市场租赁：支付成功后创建 FleaMarketRental 记录
                if payment_type == "flea_market_rental":
                    rental_request_id = metadata.get("rental_request_id")
                    flea_market_item_id_str = metadata.get("flea_market_item_id")
                    if rental_request_id and flea_market_item_id_str:
                        try:
                            from app.models import FleaMarketRentalRequest, FleaMarketRental, FleaMarketItem
                            from datetime import timedelta as _td
                            from app.utils.time_utils import get_utc_time as _get_utc

                            rr = db.query(FleaMarketRentalRequest).filter(
                                FleaMarketRentalRequest.id == int(rental_request_id)
                            ).with_for_update().first()

                            if rr and rr.status == "approved":
                                flea_item = db.query(FleaMarketItem).filter(
                                    FleaMarketItem.id == int(flea_market_item_id_str)
                                ).first()

                                now = _get_utc()
                                unit = flea_item.rental_unit if flea_item else "day"
                                duration = rr.rental_duration
                                if unit == "week":
                                    end_date = now + _td(days=7 * duration)
                                elif unit == "month":
                                    end_date = now + _td(days=30 * duration)
                                else:
                                    end_date = now + _td(days=duration)

                                deposit_pence = int(metadata.get("deposit_amount", "0"))
                                rent_pence = int(metadata.get("rent_amount", "0"))
                                total_pence = deposit_pence + rent_pence

                                new_rental = FleaMarketRental(
                                    item_id=rr.item_id,
                                    renter_id=rr.renter_id,
                                    request_id=rr.id,
                                    rental_duration=duration,
                                    rental_unit=unit,
                                    total_rent=rent_pence / 100.0,
                                    deposit_amount=deposit_pence / 100.0,
                                    total_paid=total_pence / 100.0,
                                    currency=flea_item.currency if flea_item else "GBP",
                                    start_date=now,
                                    end_date=end_date,
                                    status="active",
                                    deposit_status="held",
                                    task_id=task_id,
                                )
                                db.add(new_rental)
                                # 更新租赁申请状态为已完成
                                rr.status = "completed"
                                db.flush()

                                logger.info(f"✅ [WEBHOOK] 跳蚤市场租赁记录已创建: rental_id={new_rental.id}, request_id={rental_request_id}")

                                # 通知物主和租客
                                try:
                                    item_title = flea_item.title if flea_item else "商品"
                                    renter_id = rr.renter_id
                                    seller_id = flea_item.seller_id if flea_item else None

                                    if seller_id:
                                        crud.create_notification(
                                            db=db,
                                            user_id=seller_id,
                                            type="flea_market_rental_payment_success",
                                            title="租赁支付成功",
                                            content=f"「{item_title}」的租赁支付已完成，租赁已生效。",
                                            related_id=str(new_rental.id),
                                            auto_commit=False,
                                        )

                                    crud.create_notification(
                                        db=db,
                                        user_id=renter_id,
                                        type="flea_market_rental_payment_success",
                                        title="租赁支付成功",
                                        content=f"您已成功租赁「{item_title}」，租赁已生效。",
                                        related_id=str(new_rental.id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建租赁通知失败: {notify_err}")
                            else:
                                logger.warning(f"⚠️ [WEBHOOK] 租赁申请 {rental_request_id} 不存在或状态不匹配")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建跳蚤市场租赁记录失败: {e}", exc_info=True)

                # ==================== 团队服务申请批准的支付完成 ====================
                # expert_consultation_routes.approve_application 创建 Task(status=pending_payment)
                # + ServiceApplication(status=approved) + PaymentIntent。
                # 此处把任务从 pending_payment 翻成 in_progress，并通知申请人。
                if payment_type == "team_service_application_approve":
                    service_application_id_str = metadata.get("service_application_id")
                    if service_application_id_str:
                        try:
                            service_application_id = int(service_application_id_str)
                            sa = db.execute(
                                select(models.ServiceApplication).where(
                                    models.ServiceApplication.id == service_application_id
                                ).with_for_update()
                            ).scalar_one_or_none()

                            if sa is None:
                                logger.warning(
                                    f"⚠️ [WEBHOOK] 团队服务申请 {service_application_id} 不存在"
                                )
                            elif task.status == "pending_payment":
                                task.status = "in_progress"
                                task.accepted_at = task.accepted_at or get_utc_time()
                                # ServiceApplication 在 approve 时已写为 approved，
                                # 这里只需写 task 状态，但确保 task_id 已绑定
                                if sa.task_id is None:
                                    sa.task_id = task_id
                                logger.info(
                                    f"✅ [WEBHOOK] 团队服务任务 {task_id} 进入 in_progress "
                                    f"(service_application_id={service_application_id})"
                                )

                                # 通知申请人 + 团队 owner: 任务已开始 (i18n)
                                try:
                                    from app.utils.notification_templates import get_notification_texts
                                    service_obj = db.query(models.TaskExpertService).filter(
                                        models.TaskExpertService.id == sa.service_id
                                    ).first()
                                    service_name = service_obj.service_name if service_obj else "服务"
                                    # 向 buyer 发通知
                                    started_zh_t, started_zh_c, started_en_t, started_en_c = get_notification_texts(
                                        "team_service_task_started", service_name=service_name
                                    )
                                    crud.create_notification(
                                        db=db,
                                        user_id=sa.applicant_id,
                                        type="team_service_task_started",
                                        title=started_zh_t,
                                        content=started_zh_c,
                                        title_en=started_en_t,
                                        content_en=started_en_c,
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                    # 向 team owner (taker_id) 发通知
                                    if task.taker_id:
                                        recv_zh_t, recv_zh_c, recv_en_t, recv_en_c = get_notification_texts(
                                            "team_service_payment_received", service_name=service_name
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=task.taker_id,
                                            type="team_service_payment_received",
                                            title=recv_zh_t,
                                            content=recv_zh_c,
                                            title_en=recv_en_t,
                                            content_en=recv_en_c,
                                            related_id=str(task_id),
                                            auto_commit=False,
                                        )
                                except Exception as notify_err:
                                    logger.warning(
                                        f"⚠️ [WEBHOOK] 团队服务任务通知发送失败: {notify_err}"
                                    )
                            else:
                                logger.info(
                                    f"ℹ️ [WEBHOOK] 团队服务任务 {task_id} 状态={task.status}, "
                                    f"跳过状态翻转(可能已被处理)"
                                )
                        except Exception as e:
                            logger.error(
                                f"❌ [WEBHOOK] 处理团队服务申请支付失败: {e}",
                                exc_info=True,
                            )

                application_id_str = metadata.get("application_id")
                
                logger.debug(f"🔍 Webhook检查: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                
                if is_pending_approval and application_id_str:
                    # 这是批准申请时的支付，需要确认批准
                    application_id = int(application_id_str)
                    logger.debug(f"🔍 查找申请: application_id={application_id}, task_id={task_id}")
                    
                    # 🔒 安全修复：使用 SELECT FOR UPDATE 防止并发 webhook 重复批准申请
                    # 支持 pending 和 chatting 状态的申请（chatting 来自聊天后支付流程）
                    application = db.execute(
                        select(models.TaskApplication).where(
                            and_(
                                models.TaskApplication.id == application_id,
                                models.TaskApplication.task_id == task_id,
                                models.TaskApplication.status.in_(["pending", "chatting"])
                            )
                        ).with_for_update()
                    ).scalar_one_or_none()
                    
                    logger.debug(f"🔍 找到申请: {application is not None}")
                    
                    if application:
                        logger.info(f"✅ [WEBHOOK] 开始批准申请 {application_id}, applicant_id={application.applicant_id}")
                        # 批准申请
                        application.status = "approved"
                        task.taker_id = application.applicant_id
                        # ⚠️ 新流程：支付成功后，任务状态直接设置为 in_progress（不再使用 pending_payment）
                        task.status = "in_progress"
                        logger.info(f"✅ [WEBHOOK] 申请已批准，任务状态设置为 in_progress, taker_id={task.taker_id}")
                        
                        # 如果申请包含议价，更新 agreed_reward
                        if application.negotiated_price is not None:
                            task.agreed_reward = application.negotiated_price
                            logger.info(f"✅ [WEBHOOK] 更新任务成交价: {application.negotiated_price}")
                        
                        # 自动拒绝所有其他待处理/聊天中的申请
                        other_applications = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.id != application_id,
                                    models.TaskApplication.status.in_(["chatting", "pending"])
                                )
                            )
                        ).scalars().all()

                        for other_app in other_applications:
                            was_chatting = other_app.status == "chatting"
                            other_app.status = "rejected"
                            logger.info(f"✅ [WEBHOOK] 自动拒绝其他申请: application_id={other_app.id}, was_chatting={was_chatting}")
                            # 如果申请者之前在聊天中，发送系统消息通知
                            if was_chatting:
                                content_zh = "发布者已选择了其他申请者完成此任务。"
                                content_en = "The poster has selected another applicant for this task."
                                reject_msg = models.Message(
                                    task_id=task_id,
                                    application_id=other_app.id,
                                    sender_id=None,
                                    content=content_zh,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({"system_action": "application_rejected", "content_en": content_en}),
                                    created_at=get_utc_time(),
                                )
                                db.add(reject_msg)

                        # 往主任务聊天（application_id=NULL）插入一条 deal_closed 系统消息
                        # 作为 poster 和 taker 进入议价记录的入口
                        try:
                            taker_name_for_msg = (
                                applicant.name if (applicant := db.query(models.User).filter(models.User.id == application.applicant_id).first()) and applicant.name
                                else f"User {application.applicant_id}"
                            )
                            final_price_for_msg = (
                                float(application.negotiated_price)
                                if application.negotiated_price is not None
                                else float(task.base_reward) if task.base_reward is not None else 0.0
                            )
                            currency_for_msg = getattr(task, "currency", None) or "GBP"
                            deal_content_zh = f"已选择 {taker_name_for_msg} 达成合作，成交金额 {currency_for_msg} {final_price_for_msg:.2f}"
                            deal_content_en = f"Deal closed with {taker_name_for_msg} at {currency_for_msg} {final_price_for_msg:.2f}"
                            deal_msg = models.Message(
                                task_id=task_id,
                                application_id=None,  # 主任务聊天
                                sender_id=None,       # 系统消息
                                content=deal_content_zh,
                                message_type="system",
                                conversation_type="task",
                                meta=json.dumps({
                                    "system_action": "deal_closed",
                                    "application_id": application_id,
                                    "taker_id": str(application.applicant_id),
                                    "taker_name": taker_name_for_msg,
                                    "price": final_price_for_msg,
                                    "currency": currency_for_msg,
                                    "content_en": deal_content_en,
                                }),
                                created_at=get_utc_time(),
                            )
                            db.add(deal_msg)
                            logger.info(f"✅ [WEBHOOK] 已写入 deal_closed 主聊天系统消息 task_id={task_id}, app_id={application_id}")
                        except Exception as deal_msg_exc:
                            # 消息写入失败不应阻断主流程
                            logger.warning(f"⚠️ [WEBHOOK] 写入 deal_closed 系统消息失败: {deal_msg_exc}")

                        # 咨询合并批准(consult-approve 路径):归档 T2 / 关闭 TA2
                        _consult_t2_id = metadata.get("consultation_task_id")
                        _consult_ta2_id = metadata.get("consultation_application_id")
                        if _consult_t2_id and _consult_ta2_id:
                            try:
                                from app.consultation.approval import (
                                    finalize_consultation_on_payment_success,
                                )
                                finalize_consultation_on_payment_success(
                                    db,
                                    consultation_task_id=int(_consult_t2_id),
                                    consultation_application_id=int(_consult_ta2_id),
                                )
                            except Exception as _cf_err:
                                logger.warning(
                                    f"⚠️ [WEBHOOK] 咨询归档失败(不阻断主流程): "
                                    f"T2={_consult_t2_id} TA2={_consult_ta2_id} err={_cf_err}"
                                )

                        # 原任务 T 已确定接单人,把其他指向 T 的咨询占位全部归档
                        # (一个申请者被选中 → 其他申请者的咨询聊天自动关闭,避免挂着假状态)
                        # 同时覆盖两条入口:consult-approve(上面已跳过刚归档的 T2) 和普通 accept_application
                        try:
                            from app.consultation.approval import (
                                close_placeholders_for_task,
                            )
                            close_placeholders_for_task(
                                db,
                                original_task_id=task_id,
                                exclude_t2_id=(
                                    int(_consult_t2_id) if _consult_t2_id else None
                                ),
                            )
                        except Exception as _cp_err:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 批量归档其他咨询占位失败(不阻断主流程): "
                                f"task_id={task_id} err={_cp_err}"
                            )

                        # 写入操作日志
                        from app.utils.time_utils import get_utc_time
                        log_entry = models.NegotiationResponseLog(
                            task_id=task_id,
                            application_id=application_id,
                            user_id=task.poster_id,
                            action="accept",
                            negotiated_price=application.negotiated_price,
                            responded_at=get_utc_time()
                        )
                        db.add(log_entry)
                        logger.debug(f"✅ [WEBHOOK] 已添加操作日志")
                        
                        # 发送通知给申请者（支付成功后，任务已进入 in_progress 状态）
                        try:
                            from app import crud
                            from app.task_notifications import send_task_approval_notification
                            
                            # 获取申请者信息
                            applicant = db.query(models.User).filter(models.User.id == application.applicant_id).first()
                            if applicant:
                                # 使用 send_task_approval_notification 发送通知
                                # 注意：此时任务状态已经是 in_progress，所以不会显示支付提醒（这是正确的）
                                # background_tasks 可以为 None，因为通知会立即发送
                                send_task_approval_notification(
                                    db=db,
                                    background_tasks=None,  # webhook 中不需要后台任务
                                    task=task,
                                    applicant=applicant
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送接受申请通知给申请者 {application.applicant_id}")
                            else:
                                # 如果无法获取申请者信息，使用简单通知
                                crud.create_notification(
                                    db,
                                    application.applicant_id,
                                    "application_accepted",
                                    "您的申请已被接受",
                                    f"您的任务申请已被接受：{task.title}",
                                    task.id,
                                    auto_commit=False,
                                )
                                logger.debug(f"✅ [WEBHOOK] 已发送简单接受申请通知给申请者 {application.applicant_id}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 发送接受申请通知失败: {e}")
                        
                        logger.info(f"✅ [WEBHOOK] 支付成功，申请 {application_id} 已批准")
                        
                        # 增强支付审计信息：记录申请批准相关的支付信息
                        try:
                            # 创建或更新 PaymentHistory（如果不存在）
                            payment_history = db.query(models.PaymentHistory).filter(
                                models.PaymentHistory.payment_intent_id == payment_intent_id
                            ).first()
                            
                            if payment_history:
                                # 更新现有记录（状态机保护）
                                try:
                                    payment_history.transition_status("succeeded")
                                except ValueError as e:
                                    logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                                payment_history.escrow_amount = task.escrow_amount
                                # 增强 metadata（用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更）
                                payment_history.extra_metadata = {
                                    **(payment_history.extra_metadata or {}),
                                    "application_id": str(application_id),
                                    "taker_id": str(application.applicant_id),
                                    "taker_name": application.applicant.name if hasattr(application, 'applicant') and application.applicant else None,
                                    "pending_approval": "true",
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                                logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录: payment_history_id={payment_history.id}")
                            else:
                                # 创建新的支付历史记录（用于审计）
                                from decimal import Decimal
                                payment_history = models.PaymentHistory(
                                    order_no=models.PaymentHistory.generate_order_no(),
                                    task_id=task_id,
                                    user_id=task.poster_id,
                                    payment_intent_id=payment_intent_id,
                                    payment_method="stripe",
                                    total_amount=int(task_amount * 100),
                                    stripe_amount=int(task_amount * 100),
                                    final_amount=int(task_amount * 100),
                                    currency=task.currency or "GBP",
                                    status="succeeded",
                                    application_fee=application_fee_pence,
                                    escrow_amount=Decimal(str(task.escrow_amount)),
                                    extra_metadata={
                                        "application_id": str(application_id),
                                        "taker_id": str(application.applicant_id),
                                        "pending_approval": "true",
                                        "approved_via_webhook": True,
                                        "webhook_event_id": event_id,
                                        "approved_at": get_utc_time().isoformat()
                                    }
                                )
                                db.add(payment_history)
                                logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录: order_no={payment_history.order_no}")
                        except Exception as e:
                            logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败: {e}", exc_info=True)
                            # 支付历史记录失败不影响主流程
                    else:
                        # Application not in expected status — check if it was withdrawn (race condition)
                        withdrawn_application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status == "withdrawn"
                                )
                            )
                        ).scalar_one_or_none()

                        if withdrawn_application:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 申请人已撤回申请，支付成功但需退款: "
                                f"application_id={application_id_str}, task_id={task_id}, "
                                f"payment_intent_id={payment_intent_id}"
                            )
                            # Revert task paid status since we will refund
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请撤回退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（撤回）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, application_id={application_id_str}"
                                )
                                # Notify the poster that payment was refunded
                                try:
                                    crud.create_notification(
                                        db=db,
                                        user_id=task.poster_id,
                                        type="payment_refunded",
                                        title="支付已退款",
                                        content=f"申请人在支付处理期间撤回了申请，您的付款已自动退款：{task.title}",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                                except Exception as notify_err:
                                    logger.warning(f"⚠️ [WEBHOOK] 创建退款通知失败: {notify_err}")
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"task_id={task_id}, error={refund_err}",
                                    exc_info=True
                                )
                        else:
                            logger.warning(
                                f"⚠️ [WEBHOOK] 未找到匹配的申请: application_id={application_id_str}, "
                                f"task_id={task_id}, status not in [pending, chatting, withdrawn]. "
                                f"Attempting refund for payment_intent_id={payment_intent_id}"
                            )
                            # Application not found at all or in unexpected status — refund to be safe
                            task.is_paid = 0
                            task.payment_intent_id = None
                            task.escrow_amount = None
                            # 退还钱包扣款（如果有）
                            if _wallet_tx_id:
                                try:
                                    from app.wallet_service import reverse_debit
                                    _wd = metadata.get("wallet_deduction")
                                    if _wd:
                                        from decimal import Decimal
                                        _wcur = metadata.get("wallet_currency", "GBP")
                                        reverse_debit(db, int(_wallet_tx_id), metadata.get("user_id", ""), Decimal(_wd) / Decimal("100"), currency=_wcur)
                                        logger.info(f"✅ [WEBHOOK] 申请未找到退款，钱包扣款已退还: wallet_tx_id={_wallet_tx_id}")
                                except Exception as w_err:
                                    logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败（未找到）: {w_err}")
                            try:
                                stripe.Refund.create(payment_intent=payment_intent_id)
                                logger.info(
                                    f"✅ [WEBHOOK] 已发起退款（申请未找到）: payment_intent_id={payment_intent_id}"
                                )
                            except Exception as refund_err:
                                logger.error(
                                    f"❌ [WEBHOOK] 退款失败，需人工处理: payment_intent_id={payment_intent_id}, "
                                    f"error={refund_err}",
                                    exc_info=True
                                )
                else:
                    logger.info(f"ℹ️ 不是待确认的批准支付: is_pending_approval={is_pending_approval}, application_id={application_id_str}")
                    # 即使不是 pending_approval，也要记录支付历史
                    try:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.payment_intent_id == payment_intent_id
                        ).first()
                        
                        if not payment_history:
                            # 创建新的支付历史记录
                            from decimal import Decimal
                            payment_history = models.PaymentHistory(
                                order_no=models.PaymentHistory.generate_order_no(),
                                task_id=task_id,
                                user_id=task.poster_id,
                                payment_intent_id=payment_intent_id,
                                payment_method="stripe",
                                total_amount=int(task_amount * 100),
                                stripe_amount=int(task_amount * 100),
                                final_amount=int(task_amount * 100),
                                currency=task.currency or "GBP",
                                status="succeeded",
                                application_fee=application_fee_pence,
                                escrow_amount=Decimal(str(task.escrow_amount)),
                                extra_metadata={
                                    "approved_via_webhook": True,
                                    "webhook_event_id": event_id,
                                    "approved_at": get_utc_time().isoformat()
                                }
                            )
                            db.add(payment_history)
                            logger.debug(f"✅ [WEBHOOK] 已创建支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                        else:
                            # 更新现有记录（状态机保护）
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.escrow_amount = task.escrow_amount
                            # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                            payment_history.extra_metadata = {
                                **(payment_history.extra_metadata or {}),
                                "approved_via_webhook": True,
                                "webhook_event_id": event_id,
                                "approved_at": get_utc_time().isoformat()
                            }
                            logger.debug(f"✅ [WEBHOOK] 已更新支付历史记录（非 pending_approval）: order_no={payment_history.order_no}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 创建/更新支付历史记录失败（非 pending_approval）: {e}", exc_info=True)
                        # 支付历史记录失败不影响主流程
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                logger.info(f"🔍 检查任务状态: 当前状态={task.status}, is_paid={task.is_paid}")

                # 预加载关联服务（一次查询，后续复用）
                _act_service = None
                _is_package_activity = False
                if getattr(task, 'parent_activity_id', None) and getattr(task, 'expert_service_id', None):
                    _act_service = db.query(models.TaskExpertService).filter(
                        models.TaskExpertService.id == task.expert_service_id
                    ).first()
                    _is_package_activity = _act_service and _act_service.package_type in ("multi", "bundle")

                # 支付成功后更新任务状态
                if task.status == "pending_payment":
                    if _is_package_activity:
                        # 套餐活动的 Task 仅作为购买凭证，无实际服务交付环节。
                        # 直接 completed，不触发普通任务的完成回调（统计/积分等），
                        # 因为套餐的价值体现在 UserServicePackage 的 sessions 核销中。
                        task.status = "completed"
                        logger.info(f"✅ 套餐活动任务直接标记 completed（无需交付流程）")
                    else:
                        task.status = "in_progress"
                        logger.info(f"✅ 任务状态从 pending_payment 更新为 in_progress")
                else:
                    logger.info(f"⚠️ 任务状态不是 pending_payment，当前状态: {task.status}，跳过状态更新")

                # ====== 活动→套餐自动创建 ======
                # 如果任务来自活动，且关联的服务是套餐类型(multi/bundle)，
                # 自动为买家创建 UserServicePackage 记录
                if _is_package_activity and _act_service:
                    act_service = _act_service
                    try:
                        from sqlalchemy.exc import IntegrityError
                        from app.models_expert import UserServicePackage
                        from app.package_purchase_routes import _build_bundle_breakdown, _bundle_total_sessions

                        # 幂等: 同一 payment_intent 不重复创建 (with_for_update 与 A1 路径一致)
                        existing_pkg = db.query(UserServicePackage).filter(
                            UserServicePackage.payment_intent_id == payment_intent_id
                        ).with_for_update().first()
                        if existing_pkg:
                            logger.info(f"✅ [WEBHOOK] 活动套餐已存在 (pi={payment_intent_id})，幂等跳过")
                        else:
                            # 计算总课时和 breakdown
                            breakdown = None
                            if act_service.package_type == "bundle":
                                breakdown = _build_bundle_breakdown(act_service.bundle_service_ids, db=db)
                                final_total = _bundle_total_sessions(breakdown) if breakdown else 0
                            else:
                                final_total = act_service.total_sessions or 0

                            if final_total <= 0:
                                logger.warning(f"⚠️ [WEBHOOK] 活动套餐 total_sessions=0，跳过创建")
                            else:
                                # 确定买家 ID（originating_user_id 是报名者，poster_id 是发布者兜底）
                                buyer_id = task.originating_user_id or task.poster_id
                                if not task.originating_user_id:
                                    logger.warning(
                                        f"⚠️ [WEBHOOK] 活动套餐 task {task.id} originating_user_id 为空，"
                                        f"回退到 poster_id={task.poster_id}"
                                    )
                                # 确定团队 ID
                                pkg_expert_id = act_service.owner_id if act_service.owner_type == 'expert' else None

                                # 过期时间
                                exp_at = None
                                if act_service.validity_days and act_service.validity_days > 0:
                                    exp_at = get_utc_time() + timedelta(days=act_service.validity_days)

                                # 单价快照
                                unit_snapshot = None
                                if act_service.package_type == "multi":
                                    unit_snapshot = int(round(float(act_service.base_price) * 100))

                                # 实付金额 (pounds，与 A1 直接购买路径一致)
                                paid_amount = float(task.reward or 0)

                                new_pkg = UserServicePackage(
                                    user_id=buyer_id,
                                    service_id=act_service.id,
                                    expert_id=pkg_expert_id,
                                    total_sessions=final_total,
                                    used_sessions=0,
                                    status="active",
                                    purchased_at=get_utc_time(),
                                    cooldown_until=get_utc_time() + timedelta(hours=24),
                                    expires_at=exp_at,
                                    payment_intent_id=payment_intent_id,
                                    paid_amount=paid_amount,
                                    currency="GBP",
                                    bundle_breakdown=breakdown,
                                    unit_price_pence_snapshot=unit_snapshot,
                                )
                                db.add(new_pkg)
                                try:
                                    db.commit()
                                    db.refresh(new_pkg)
                                    logger.info(
                                        f"✅ [WEBHOOK] 活动套餐 {new_pkg.id} 已创建 "
                                        f"(buyer={buyer_id} service={act_service.id} "
                                        f"type={act_service.package_type} total={final_total})"
                                    )

                                    # 通知买家
                                    try:
                                        from app.utils.notification_templates import get_notification_texts
                                        buyer_t_zh, buyer_c_zh, buyer_t_en, buyer_c_en = get_notification_texts(
                                            "package_purchased",
                                            service_name=act_service.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="package_purchased",
                                            title=buyer_t_zh,
                                            content=buyer_c_zh,
                                            title_en=buyer_t_en,
                                            content_en=buyer_c_en,
                                            related_id=str(new_pkg.id),
                                        )
                                    except Exception as notify_err:
                                        logger.warning(f"⚠️ [WEBHOOK] 活动套餐购买通知失败: {notify_err}")
                                except IntegrityError:
                                    db.rollback()
                                    logger.info(f"✅ [WEBHOOK] 活动套餐并发已创建 (pi={payment_intent_id})，幂等跳过")
                    except Exception as pkg_err:
                        logger.error(f"❌ [WEBHOOK] 活动→套餐创建失败: {pkg_err}", exc_info=True)
                        # 不影响主流程（Task 已正常处理）

            elif task and task.is_paid == 1:
                # ====== 补差价支付（top_up）：任务已付款，此次为追加支付 ======
                metadata = payment_intent.get("metadata", {})
                if metadata.get("payment_type") == "top_up" and metadata.get("pending_approval") == "true":
                    top_up_pence = payment_intent.get("amount", 0)
                    logger.info(f"✅ [WEBHOOK] 补差价支付成功: task_id={task_id}, top_up={top_up_pence}p")

                    # 更新 escrow：累加补差价金额（扣除补差价部分的服务费）
                    from app.utils.fee_calculator import calculate_application_fee_pence
                    task_source = getattr(task, "task_source", None)
                    task_type_val = getattr(task, "task_type", None)
                    top_up_fee = calculate_application_fee_pence(top_up_pence, task_source, task_type_val)
                    top_up_net = (top_up_pence - top_up_fee) / 100.0
                    task.escrow_amount = float(task.escrow_amount or 0) + max(0.0, top_up_net)

                    # 更新 agreed_reward 为新总价
                    if metadata.get("negotiated_price"):
                        try:
                            from decimal import Decimal
                            task.agreed_reward = Decimal(metadata["negotiated_price"])
                        except Exception:
                            pass

                    # 保存最新的 payment_intent_id
                    task.payment_intent_id = payment_intent_id

                    # 批准申请（复用与上面相同的逻辑）
                    application_id_str = metadata.get("application_id")
                    if application_id_str:
                        application_id = int(application_id_str)
                        application = db.execute(
                            select(models.TaskApplication).where(
                                and_(
                                    models.TaskApplication.id == application_id,
                                    models.TaskApplication.task_id == task_id,
                                    models.TaskApplication.status.in_(["pending", "chatting"])
                                )
                            ).with_for_update()
                        ).scalar_one_or_none()

                        if application:
                            application.status = "approved"
                            task.taker_id = application.applicant_id
                            task.status = "in_progress"
                            logger.info(f"✅ [WEBHOOK] 补差价后批准申请 {application_id}")

                            # 自动拒绝其他申请
                            other_apps = db.execute(
                                select(models.TaskApplication).where(
                                    and_(
                                        models.TaskApplication.task_id == task_id,
                                        models.TaskApplication.id != application_id,
                                        models.TaskApplication.status.in_(["chatting", "pending"])
                                    )
                                )
                            ).scalars().all()
                            for other_app in other_apps:
                                was_chatting = other_app.status == "chatting"
                                other_app.status = "rejected"
                                if was_chatting:
                                    reject_msg = models.Message(
                                        task_id=task_id, application_id=other_app.id,
                                        sender_id=None, receiver_id=None,
                                        content="发布者已选择了其他申请者完成此任务。",
                                        message_type="system", conversation_type="task",
                                        meta=json.dumps({"system_action": "auto_rejected",
                                                         "content_en": "The poster has selected another applicant for this task."}),
                                        created_at=get_utc_time(),
                                    )
                                    db.add(reject_msg)

                            # 通知申请人
                            try:
                                crud.create_notification(
                                    db, application.applicant_id,
                                    "application_accepted", "申请已通过",
                                    f"您的任务申请已被接受：{task.title}",
                                    related_id=str(task_id), auto_commit=False,
                                )
                            except Exception as e:
                                logger.warning(f"⚠️ [WEBHOOK] 通知失败: {e}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 补差价支付成功但未找到申请 {application_id_str}")
                else:
                    logger.info(f"ℹ️ [WEBHOOK] 已付款任务收到支付，非 top_up 类型，跳过")
                
                # 支付历史记录已在上面更新（如果存在待确认的批准支付）
                
                # 提交数据库更改
                try:
                    # 在提交前记录更新前的状态（DEBUG级别）
                    logger.debug(f"📝 [WEBHOOK] 提交前任务状态: is_paid={task.is_paid}, status={task.status}, payment_intent_id={task.payment_intent_id}, escrow_amount={task.escrow_amount}, taker_id={task.taker_id}")
                    
                    db.commit()
                    logger.debug(f"✅ [WEBHOOK] 数据库提交成功")
                    
                    # 刷新任务对象以获取最新状态
                    db.refresh(task)
                    
                    # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        logger.debug(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                    
                    # 清除任务列表缓存（因为任务状态已改变）
                    try:
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.debug(f"✅ [WEBHOOK] 已清除任务列表缓存")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    
                    # 验证更新是否成功（关键信息保留INFO）
                    logger.info(f"✅ [WEBHOOK] 任务 {task_id} 支付完成: status={task.status}, is_paid={task.is_paid}, taker_id={task.taker_id}")
                    logger.debug(f"  - Payment Intent ID: {task.payment_intent_id}, Escrow 金额: {task.escrow_amount}")
                    
                    # 如果 is_paid 没有正确更新，记录警告
                    if task.is_paid != 1:
                        logger.error(f"❌ [WEBHOOK] 警告：任务 {task_id} 的 is_paid 字段未正确更新！当前值: {task.is_paid}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    import traceback
                    logger.error(f"  - 错误堆栈: {traceback.format_exc()}")
                    db.rollback()
                    raise
            else:
                logger.warning(f"⚠️ [WEBHOOK] 任务 {task_id} 已支付或不存在")
                if task:
                    logger.warning(f"  - 任务已支付状态: {task.is_paid}")
                    logger.warning(f"  - 任务当前状态: {task.status}")
        else:
            # 没有 task_id 的 PI: 检查是不是套餐购买 (A1)
            metadata = payment_intent.get("metadata", {}) or {}
            pmt_type = metadata.get("payment_type")
            if pmt_type == "package_purchase":
                # ==================== A1: 套餐购买完成 ====================
                # buyer 完成套餐支付,创建 UserServicePackage 记录
                try:
                    from app.models_expert import UserServicePackage
                    from datetime import timedelta as _td
                    from sqlalchemy.exc import IntegrityError
                    service_id_meta = metadata.get("service_id")
                    buyer_id = metadata.get("buyer_id")
                    expert_id_meta = metadata.get("expert_id")
                    package_type_meta = metadata.get("package_type")
                    total_sessions_meta = int(metadata.get("total_sessions", 0))
                    package_price_meta = float(metadata.get("package_price", 0))
                    validity_days_meta = int(metadata.get("validity_days", 0))

                    if not (service_id_meta and buyer_id and expert_id_meta):
                        logger.error(
                            f"❌ [WEBHOOK] package_purchase metadata 不完整: {metadata}"
                        )
                    else:
                        # 幂等性检查 — 同 PI 是否已创建 package
                        # 注意: DB 层有 partial unique index uq_user_service_packages_pi (migration 187),
                        # 即便 query 后并发 add 也会被 IntegrityError 拦下,见下方 except。
                        existing_pkg = db.query(UserServicePackage).filter(
                            UserServicePackage.payment_intent_id == payment_intent_id
                        ).with_for_update().first()
                        if existing_pkg:
                            logger.info(
                                f"✅ [WEBHOOK] 套餐 {existing_pkg.id} 已存在,跳过 (idempotent)"
                            )
                        else:
                            # 加载 service 拿 bundle_breakdown 配置
                            from app.models import TaskExpertService
                            service_obj = db.query(TaskExpertService).filter(
                                TaskExpertService.id == int(service_id_meta)
                            ).first()
                            if not service_obj:
                                logger.error(
                                    f"❌ [WEBHOOK] package_purchase: service {service_id_meta} 不存在"
                                )
                            else:
                                # 构建 bundle_breakdown
                                from app.package_purchase_routes import (
                                    _build_bundle_breakdown,
                                    _bundle_total_sessions,
                                )
                                breakdown = None
                                final_total = total_sessions_meta
                                if package_type_meta == "bundle":
                                    breakdown = _build_bundle_breakdown(service_obj.bundle_service_ids, db)
                                    final_total = _bundle_total_sessions(breakdown)

                                if final_total <= 0:
                                    logger.error(
                                        f"❌ [WEBHOOK] package_purchase: total_sessions={final_total}, "
                                        f"无法创建空套餐,跳过 (metadata={metadata})"
                                    )
                                    raise ValueError(f"total_sessions={final_total}, 无法创建套餐")

                                # 计算 expires_at
                                exp_at = None
                                if validity_days_meta > 0:
                                    exp_at = get_utc_time() + _td(days=validity_days_meta)

                                # 计算 unit_price_pence_snapshot (multi 套餐专用; bundle 价格已内嵌在 breakdown)
                                # 防御: service.base_price 理论上 multi 非空 (schema validator 强制),
                                # 但历史数据 / 不规范 PATCH 可能产生 NULL,fallback 到 0 避免 webhook 崩
                                unit_snapshot = None
                                if package_type_meta == "multi" and service_obj is not None:
                                    unit_snapshot = int(round(float(service_obj.base_price or 0) * 100))

                                new_pkg = UserServicePackage(
                                    user_id=buyer_id,
                                    service_id=int(service_id_meta),
                                    expert_id=expert_id_meta,
                                    total_sessions=final_total,
                                    used_sessions=0,
                                    status="active",
                                    purchased_at=get_utc_time(),
                                    cooldown_until=get_utc_time() + timedelta(hours=24),  # NEW: 24h 冷却期
                                    expires_at=exp_at,
                                    payment_intent_id=payment_intent_id,
                                    paid_amount=package_price_meta,
                                    currency="GBP",
                                    bundle_breakdown=breakdown,
                                    unit_price_pence_snapshot=unit_snapshot,  # NEW: 单价快照
                                )
                                db.add(new_pkg)
                                idempotent_skipped = False
                                try:
                                    db.commit()
                                except IntegrityError:
                                    # 并发兜底: unique index uq_user_service_packages_pi (migration 187)
                                    # 命中 → 已被另一 webhook 创建,幂等跳过通知
                                    db.rollback()
                                    logger.info(
                                        f"✅ [WEBHOOK] 套餐 {payment_intent_id} 并发已创建,幂等跳过"
                                    )
                                    idempotent_skipped = True

                                if not idempotent_skipped:
                                    db.refresh(new_pkg)
                                    logger.info(
                                        f"✅ [WEBHOOK] 套餐 {new_pkg.id} 已创建 "
                                        f"(buyer={buyer_id} expert={expert_id_meta} type={package_type_meta} total={final_total})"
                                    )

                                    # 通知 buyer + 团队所有 admin (i18n 模板)
                                    try:
                                        from app.utils.notification_templates import get_notification_texts
                                        from app.models_expert import ExpertMember as _EM

                                        buyer_t_zh, buyer_c_zh, buyer_t_en, buyer_c_en = get_notification_texts(
                                            "package_purchased",
                                            service_name=service_obj.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        crud.create_notification(
                                            db=db,
                                            user_id=buyer_id,
                                            type="package_purchased",
                                            title=buyer_t_zh,
                                            content=buyer_c_zh,
                                            title_en=buyer_t_en,
                                            content_en=buyer_c_en,
                                            related_id=str(new_pkg.id),
                                            auto_commit=False,
                                        )
                                        admin_t_zh, admin_c_zh, admin_t_en, admin_c_en = get_notification_texts(
                                            "package_sold",
                                            service_name=service_obj.service_name or "",
                                            total_sessions=final_total,
                                        )
                                        managers = db.query(_EM.user_id).filter(
                                            _EM.expert_id == expert_id_meta,
                                            _EM.status == "active",
                                            _EM.role.in_(["owner", "admin"]),
                                        ).all()
                                        for (mid,) in managers:
                                            crud.create_notification(
                                                db=db,
                                                user_id=mid,
                                                type="package_sold",
                                                title=admin_t_zh,
                                                content=admin_c_zh,
                                                title_en=admin_t_en,
                                                content_en=admin_c_en,
                                                related_id=str(new_pkg.id),
                                                auto_commit=False,
                                            )
                                        db.commit()
                                    except Exception as notify_err:
                                        logger.warning(
                                            f"⚠️ [WEBHOOK] 套餐购买通知失败: {notify_err}"
                                        )
                                        db.rollback()
                except Exception as e:
                    logger.error(
                        f"❌ [WEBHOOK] 处理 package_purchase 失败: {e}",
                        exc_info=True,
                    )
            else:
                logger.warning(f"⚠️ [WEBHOOK] Payment Intent 成功但 metadata 中没有 task_id")
                logger.warning(f"  - Metadata: {json.dumps(payment_intent.get('metadata', {}), ensure_ascii=False)}")
                logger.warning(f"  - Payment Intent ID: {payment_intent_id}")

    elif event_type == "payment_intent.payment_failed":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        application_id_str = payment_intent.get("metadata", {}).get("application_id")
        error_message = payment_intent.get('last_payment_error', {}).get('message', 'Unknown error')
        
        logger.warning(f"❌ [WEBHOOK] Payment Intent 支付失败:")
        logger.warning(f"  - Payment Intent ID: {payment_intent_id}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - Application ID: {application_id_str}")
        logger.warning(f"  - 错误信息: {error_message}")
        logger.warning(f"  - 完整错误: {json.dumps(payment_intent.get('last_payment_error', {}), ensure_ascii=False)}")

        # 咨询合并批准(consult-approve)路径:TA2 从 price_locked 回到 price_agreed
        _failed_metadata_consult = payment_intent.get("metadata", {})
        _consult_t2_fail = _failed_metadata_consult.get("consultation_task_id")
        _consult_ta2_fail = _failed_metadata_consult.get("consultation_application_id")
        if _consult_t2_fail and _consult_ta2_fail:
            try:
                from app.consultation.approval import (
                    unlock_consultation_on_payment_failure,
                )
                unlock_consultation_on_payment_failure(
                    db,
                    consultation_task_id=int(_consult_t2_fail),
                    consultation_application_id=int(_consult_ta2_fail),
                )
                db.commit()
            except Exception as _cu_err:
                logger.warning(
                    f"⚠️ [WEBHOOK] 咨询解锁失败(失败路径): T2={_consult_t2_fail} "
                    f"TA2={_consult_ta2_fail} err={_cu_err}"
                )
                db.rollback()

        # 更新支付历史记录状态为失败
        if payment_intent_id:
            try:
                payment_history = db.query(models.PaymentHistory).filter(
                    models.PaymentHistory.payment_intent_id == payment_intent_id
                ).first()
                if payment_history:
                    try:
                        payment_history.transition_status("failed")
                    except ValueError as e:
                        logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                    # 用新 dict 赋值，确保 SQLAlchemy 检测 JSONB 变更
                    payment_history.extra_metadata = {
                        **(payment_history.extra_metadata or {}),
                        "payment_failed": True,
                        "error_message": error_message,
                        "webhook_event_id": event_id,
                        "failed_at": get_utc_time().isoformat()
                    }
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已更新支付历史记录状态为失败: order_no={payment_history.order_no}")
            except Exception as e:
                logger.error(f"❌ [WEBHOOK] 更新支付历史记录失败: {e}", exc_info=True)

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _failed_metadata = payment_intent.get("metadata", {})
        _failed_wallet_tx_id = _failed_metadata.get("wallet_tx_id")
        _failed_wallet_deduction = _failed_metadata.get("wallet_deduction")
        if _failed_wallet_tx_id and _failed_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _failed_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_failed_wallet_deduction) / Decimal("100")
                _wcur = _failed_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_failed_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付失败，钱包扣款已退还: "
                    f"wallet_tx_id={_failed_wallet_tx_id}, amount={_failed_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_failed_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # 支付失败时，清除 payment_intent_id（申请状态保持为 pending，可以重新尝试）
        if task_id and application_id_str:
            application_id = int(application_id_str)
            task = crud.get_task(db, task_id)
            
            if task and task.status == "pending_payment" and task.taker_id:
                # 查找已批准的申请
                application = db.execute(
                    select(models.TaskApplication).where(
                        and_(
                            models.TaskApplication.id == application_id,
                            models.TaskApplication.task_id == task_id,
                            models.TaskApplication.status == "approved"
                        )
                    )
                ).scalar_one_or_none()
                
                if application:
                    logger.info(f"🔄 [WEBHOOK] 撤销申请批准: application_id={application_id}")
                    application.status = "pending"
                    task.taker_id = None
                    task.status = "open"
                    task.is_paid = 0
                    task.payment_intent_id = None
                    
                    # 发送通知
                    try:
                        from app import crud
                        crud.create_notification(
                            db,
                            application.applicant_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败，申请已撤销：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        crud.create_notification(
                            db,
                            task.poster_id,
                            "payment_failed",
                            "支付失败",
                            f"任务支付失败：{task.title}",
                            task.id,
                            auto_commit=False,
                        )
                        logger.info(f"✅ [WEBHOOK] 已发送支付失败通知")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 发送支付失败通知失败: {e}")
                    
                    try:
                        db.commit()
                        logger.info(f"✅ [WEBHOOK] 已撤销申请批准并恢复任务状态")
                        logger.info(f"  - 申请状态: pending")
                        logger.info(f"  - 任务状态: {task.status}")
                        logger.info(f"  - Taker ID: {task.taker_id}")
                        
                        # ⚠️ 优化：清除任务缓存，确保前端立即看到更新后的状态
                        try:
                            from app.services.task_service import TaskService
                            TaskService.invalidate_cache(task_id)
                            logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                        
                        # 清除任务列表缓存
                        try:
                            from app.redis_cache import invalidate_tasks_cache
                            invalidate_tasks_cache()
                            logger.info(f"✅ [WEBHOOK] 已清除任务列表缓存（支付失败）")
                        except Exception as e:
                            logger.warning(f"⚠️ [WEBHOOK] 清除任务列表缓存失败: {e}")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                        db.rollback()
                else:
                    logger.warning(f"⚠️ [WEBHOOK] 未找到已批准的申请: application_id={application_id}")
            elif task:
                task.payment_intent_id = None
                try:
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id")
                    
                    # ⚠️ 优化：清除任务缓存
                    try:
                        from app.services.task_service import TaskService
                        TaskService.invalidate_cache(task_id)
                        from app.redis_cache import invalidate_tasks_cache
                        invalidate_tasks_cache()
                        logger.info(f"✅ [WEBHOOK] 已清除任务缓存（支付失败-无申请）")
                    except Exception as e:
                        logger.warning(f"⚠️ [WEBHOOK] 清除任务缓存失败: {e}")
                except Exception as e:
                    logger.error(f"❌ [WEBHOOK] 数据库提交失败: {e}")
                    db.rollback()
    
    # 处理退款事件
    elif event_type == "charge.refunded":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        refund_request_id = charge.get("metadata", {}).get("refund_request_id")
        
        if task_id:
            task = crud.get_task(db, task_id)
            if task:
                # ✅ 安全修复：验证任务仍然已支付
                if not task.is_paid:
                    logger.warning(f"任务 {task_id} 已不再支付，跳过webhook退款处理")
                    return {"status": "skipped", "reason": "task_not_paid"}
                
                # ✅ 安全修复：验证退款申请状态（如果有关联的退款申请）
                if refund_request_id:
                    try:
                        refund_request_check = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        if refund_request_check and refund_request_check.status != "processing":
                            logger.warning(f"退款申请 {refund_request_id} 状态为 {refund_request_check.status}，不是processing，跳过webhook处理")
                            return {"status": "skipped", "reason": "refund_request_not_processing"}
                    except Exception as e:
                        logger.warning(f"检查退款申请状态时发生错误: {e}")
                
                # ✅ 修复金额精度：使用Decimal计算退款金额
                from decimal import Decimal
                refund_amount = Decimal(str(charge.get("amount_refunded", 0))) / Decimal('100')
                refund_amount_float = float(refund_amount)  # 用于显示和日志
                
                # 如果有关联的退款申请，更新退款申请状态
                if refund_request_id:
                    try:
                        refund_request = db.query(models.RefundRequest).filter(
                            models.RefundRequest.id == int(refund_request_id)
                        ).first()
                        
                        if refund_request and refund_request.status == "processing":
                            # 更新退款申请状态为已完成
                            refund_request.status = "completed"
                            refund_request.completed_at = get_utc_time()
                            
                            # 发送系统消息通知用户
                            try:
                                from app.models import Message
                                import json
                                
                                content_zh = f"您的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}。退款将在5-10个工作日内退回您的原支付方式。"
                                content_en = f"Your refund request has been processed. Refund amount: £{refund_amount_float:.2f}. The refund will be returned to your original payment method within 5-10 business days."
                                
                                system_message = Message(
                                    sender_id=None,
                                    receiver_id=None,
                                    content=content_zh,
                                    task_id=task.id,
                                    message_type="system",
                                    conversation_type="task",
                                    meta=json.dumps({
                                        "system_action": "refund_completed",
                                        "refund_request_id": refund_request.id,
                                        "refund_amount": float(refund_amount),
                                        "content_en": content_en
                                    }),
                                    created_at=get_utc_time()
                                )
                                db.add(system_message)
                                
                                # 发送通知给发布者
                                crud.create_notification(
                                    db=db,
                                    user_id=refund_request.poster_id,
                                    type="refund_completed",
                                    title="退款已完成",
                                    content=f"您的任务「{task.title}」的退款申请已处理完成，退款金额：£{refund_amount_float:.2f}",
                                    related_id=str(task.id),
                                    auto_commit=False
                                )
                            except Exception as e:
                                logger.error(f"Failed to send refund completion notification: {e}")
                    except Exception as e:
                        logger.error(f"Failed to update refund request status: {e}")
                
                # ✅ 修复金额精度：使用Decimal进行金额比较
                # ✅ 支持部分退款：更新任务状态和托管金额
                task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
                
                if refund_amount >= task_amount:
                    # 全额退款
                    task.is_paid = 0
                    task.payment_intent_id = None
                    task.escrow_amount = 0.0
                    logger.info(f"✅ 全额退款，已更新任务支付状态")
                else:
                    # 部分退款：更新托管金额
                    # ✅ 计算退款后的剩余金额（最终成交金额）
                    remaining_amount = task_amount - refund_amount
                    
                    # ✅ 计算已转账的总金额
                    from sqlalchemy import func, and_
                    total_transferred = db.query(
                        func.sum(models.PaymentTransfer.amount).label('total_transferred')
                    ).filter(
                        and_(
                            models.PaymentTransfer.task_id == task.id,
                            models.PaymentTransfer.status == "succeeded"
                        )
                    ).scalar() or Decimal('0')
                    total_transferred = Decimal(str(total_transferred)) if total_transferred else Decimal('0')
                    
                    # ✅ 基于剩余金额重新计算平台服务费（按任务来源/类型取费率）
                    from app.utils.fee_calculator import calculate_application_fee
                    _ts = getattr(task, "task_source", None)
                    _tt = getattr(task, "task_type", None)
                    application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
                    
                    # ✅ 如果已经进行了部分转账，需要从剩余金额中扣除已转账部分
                    if total_transferred > 0:
                        remaining_after_transfer = remaining_amount - total_transferred
                        if remaining_after_transfer > 0:
                            remaining_application_fee = calculate_application_fee(float(remaining_amount), _ts, _tt)
                            new_escrow_amount = remaining_amount - Decimal(str(remaining_application_fee)) - total_transferred
                        else:
                            # 如果剩余金额已经全部转账，escrow为0
                            new_escrow_amount = Decimal('0')
                    
                    # 更新托管金额（确保不为负数）
                    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
                    logger.info(f"✅ 部分退款：退款金额 £{refund_amount_float:.2f}，剩余任务金额 £{remaining_amount:.2f}，已转账 £{total_transferred:.2f}，服务费 £{application_fee:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
                
                db.commit()
                logger.info(f"Task {task_id} refunded: £{refund_amount_float:.2f}")
    
    # 处理争议事件
    elif event_type == "charge.dispute.created":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        reason = dispute.get("reason", "unknown")
        amount = (dispute.get("amount") or 0) / 100.0
        logger.warning(f"Stripe 争议 charge.dispute.created: charge={charge_id}, task_id={task_id}, reason={reason}, amount={amount}")
        try:
            # 通知 poster、taker、管理员，并冻结任务状态
            if task_id:
                task = crud.get_task(db, task_id)
                if task:
                    # ✅ Stripe争议冻结：冻结任务状态，防止资金继续流出
                    if not hasattr(task, 'stripe_dispute_frozen') or task.stripe_dispute_frozen != 1:
                        task.stripe_dispute_frozen = 1
                        logger.warning(f"⚠️ 任务 {task_id} 因Stripe争议已冻结，防止资金继续流出")
                        
                        # 发送系统消息
                        try:
                            from app.models import Message
                            import json
                            
                            content_zh = f"⚠️ 此任务的支付发生Stripe争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}。在争议解决前，所有资金操作将被暂停。"
                            content_en = f"⚠️ A Stripe dispute has been raised for this task's payment. Task status is now frozen. Reason: {reason}, amount: £{amount:.2f}. All fund operations are suspended until the dispute is resolved."
                            system_message = Message(
                                sender_id=None,
                                receiver_id=None,
                                content=content_zh,
                                task_id=task.id,
                                message_type="system",
                                conversation_type="task",
                                meta=json.dumps({
                                    "system_action": "stripe_dispute_frozen",
                                    "charge_id": charge_id,
                                    "reason": reason,
                                    "amount": amount,
                                    "content_en": content_en
                                }),
                                created_at=get_utc_time()
                            )
                            db.add(system_message)
                        except Exception as e:
                            logger.error(f"Failed to send system message for dispute freeze: {e}")
                    
                    # 通知发布者
                    crud.create_notification(
                        db, str(task.poster_id),
                        "stripe_dispute", "Stripe 支付争议",
                        f"您的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                        related_id=str(task_id), auto_commit=False
                    )
                    # 通知接受者（如有）
                    if task.taker_id:
                        crud.create_notification(
                            db, str(task.taker_id),
                            "stripe_dispute", "Stripe 支付争议",
                            f"您参与的任务「{task.title}」（ID: {task_id}）的支付发生 Stripe 争议，任务状态已冻结。原因: {reason}，金额: £{amount:.2f}",
                            related_id=str(task_id), auto_commit=False
                        )
            admins = db.query(models.AdminUser.id).filter(models.AdminUser.is_active == True).all()
            admin_content = f"Stripe 争议: charge={charge_id}, task_id={task_id or 'N/A'}, reason={reason}, amount=£{amount:.2f}"
            related = str(task_id) if task_id else (charge_id or "")
            for (admin_id,) in admins:
                crud.create_notification(
                    db, admin_id, "stripe_dispute", "Stripe 支付争议", admin_content,
                    related_id=related, auto_commit=False
                )
        except Exception as e:
            logger.error(f"charge.dispute.created 通知处理失败: {e}", exc_info=True)

        # Phase 7: 达人团队任务自动反转 Transfer
        if task_id:
            try:
                _handle_dispute_team_reversal(db, task_id)
            except Exception as e:
                logger.error(
                    f"_handle_dispute_team_reversal failed for task {task_id}: {e}",
                    exc_info=True,
                )
                # 不让 webhook 失败 —— 冻结与通知已经完成

    elif event_type == "charge.dispute.updated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        status = dispute.get("status")
        logger.info(f"Dispute updated for charge {charge_id}, task {task_id}: status={status}")
    
    elif event_type == "charge.dispute.closed":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        status = dispute.get("status")
        logger.info(f"Dispute closed for charge {charge_id}, task {task_id}: status={status}")
        
        # ✅ Stripe争议解冻：争议关闭后解冻任务状态
        if task_id:
            task = crud.get_task(db, task_id)
            if task and hasattr(task, 'stripe_dispute_frozen') and task.stripe_dispute_frozen == 1:
                task.stripe_dispute_frozen = 0
                logger.info(f"✅ 任务 {task_id} 的Stripe争议已关闭，已解冻任务状态")
                
                # 发送系统消息
                try:
                    from app.models import Message
                    import json
                    
                    content_zh = f"✅ Stripe争议已关闭（状态: {status}），任务状态已解冻，资金操作已恢复正常。"
                    content_en = f"✅ Stripe dispute has been closed (status: {status}). Task status is now unfrozen and fund operations have resumed."
                    system_message = Message(
                        sender_id=None,
                        receiver_id=None,
                        content=content_zh,
                        task_id=task.id,
                        message_type="system",
                        conversation_type="task",
                        meta=json.dumps({
                            "system_action": "stripe_dispute_unfrozen",
                            "charge_id": charge_id,
                            "status": status,
                            "content_en": content_en
                        }),
                        created_at=get_utc_time()
                    )
                    db.add(system_message)
                    db.commit()
                except Exception as e:
                    logger.error(f"Failed to send system message for dispute unfreeze: {e}")
                    db.rollback()
    
    elif event_type == "charge.dispute.funds_withdrawn":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        logger.warning(f"Dispute funds withdrawn for charge {charge_id}, task {task_id}")
    
    elif event_type == "charge.dispute.funds_reinstated":
        dispute = event_data
        charge_id = dispute.get("charge")
        task_id = _safe_int_metadata(dispute, "task_id")
        logger.info(f"Dispute funds reinstated for charge {charge_id}, task {task_id}")

    # Connect 账户状态同步：专家团队 stripe_onboarding_complete + 服务冻结
    elif event_type == "account.updated":
        try:
            _handle_account_updated(db, event_data)
            db.commit()
        except Exception as e:
            logger.error(f"account.updated 处理失败: {e}", exc_info=True)
            db.rollback()

    # 处理其他 charge 事件
    elif event_type == "charge.succeeded":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        if task_id:
            logger.info(f"Charge succeeded for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.failed":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        logger.warning(f"Charge failed for task {task_id}: {charge.get('failure_message', 'Unknown error')}")
    
    elif event_type == "charge.captured":
        charge = event_data
        task_id = _safe_int_metadata(charge, "task_id")
        logger.info(f"Charge captured for task {task_id}: charge_id={charge.get('id')}")
    
    elif event_type == "charge.refund.updated":
        refund = event_data
        charge_id = refund.get("charge")
        task_id = _safe_int_metadata(refund, "task_id")
        status = refund.get("status")
        logger.info(f"Refund updated for charge {charge_id}, task {task_id}: status={status}")
    
    # 处理 Payment Intent 其他事件
    elif event_type == "payment_intent.created":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent created for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.canceled":
        payment_intent = event_data
        payment_intent_id = payment_intent.get("id")
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.warning(f"⚠️ [WEBHOOK] Payment intent canceled: payment_intent_id={payment_intent_id}, task_id={task_id}")

        # 咨询合并批准(consult-approve)路径:TA2 从 price_locked 回到 price_agreed
        _canceled_consult_metadata = payment_intent.get("metadata", {})
        _consult_t2_cancel = _canceled_consult_metadata.get("consultation_task_id")
        _consult_ta2_cancel = _canceled_consult_metadata.get("consultation_application_id")
        if _consult_t2_cancel and _consult_ta2_cancel:
            try:
                from app.consultation.approval import (
                    unlock_consultation_on_payment_failure,
                )
                unlock_consultation_on_payment_failure(
                    db,
                    consultation_task_id=int(_consult_t2_cancel),
                    consultation_application_id=int(_consult_ta2_cancel),
                )
                db.commit()
            except Exception as _cu_err:
                logger.warning(
                    f"⚠️ [WEBHOOK] 咨询解锁失败(取消路径): T2={_consult_t2_cancel} "
                    f"TA2={_consult_ta2_cancel} err={_cu_err}"
                )
                db.rollback()

        # ==================== 钱包混合支付：退还钱包扣款 ====================
        _canceled_metadata = payment_intent.get("metadata", {})
        _canceled_wallet_tx_id = _canceled_metadata.get("wallet_tx_id")
        _canceled_wallet_deduction = _canceled_metadata.get("wallet_deduction")
        if _canceled_wallet_tx_id and _canceled_wallet_deduction:
            try:
                from app.wallet_service import reverse_debit
                from decimal import Decimal
                _user_id = _canceled_metadata.get("user_id", "")
                _deduction_pounds = Decimal(_canceled_wallet_deduction) / Decimal("100")
                _wcur = _canceled_metadata.get("wallet_currency", "GBP")
                reverse_debit(db, int(_canceled_wallet_tx_id), _user_id, _deduction_pounds, currency=_wcur)
                db.commit()
                logger.info(
                    f"✅ [WEBHOOK] 支付取消，钱包扣款已退还: "
                    f"wallet_tx_id={_canceled_wallet_tx_id}, amount={_canceled_wallet_deduction}p, task_id={task_id}"
                )
            except Exception as wallet_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包扣款失败: wallet_tx_id={_canceled_wallet_tx_id}, error={wallet_err}")
                db.rollback()

        # ⚠️ 处理 PaymentIntent 取消事件
        # 新流程：任务保持 open 状态，支付取消时只需清除 payment_intent_id
        # 这样用户可以继续批准其他申请者或重新批准同一个申请者
        if task_id:
            task = crud.get_task(db, task_id)
            # 检查任务状态：open 或 pending_payment（兼容旧流程）
            if task and task.payment_intent_id == payment_intent_id and task.status in ["open", "pending_payment"]:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 的 PaymentIntent 已取消，"
                    f"任务状态: {task.status}，清除 payment_intent_id，允许用户重新创建支付"
                )
                # 清除 payment_intent_id，允许用户重新创建支付
                task.payment_intent_id = None
                db.commit()
                logger.info(f"✅ [WEBHOOK] 已清除任务 {task_id} 的 payment_intent_id，允许重新创建支付")
            else:
                logger.info(
                    f"ℹ️ [WEBHOOK] 任务 {task_id} 状态不匹配或 payment_intent_id 不匹配，"
                    f"当前状态: {task.status if task else 'N/A'}, payment_intent_id: {task.payment_intent_id if task else 'N/A'}"
                )
    
    elif event_type == "payment_intent.requires_action":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent requires action for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    elif event_type == "payment_intent.processing":
        payment_intent = event_data
        task_id = _safe_int_metadata(payment_intent, "task_id")
        logger.info(f"Payment intent processing for task {task_id}: payment_intent_id={payment_intent.get('id')}")
    
    # 处理 Invoice 事件（用于订阅）
    elif event_type == "invoice.paid":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.info(f"Invoice paid: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.payment_failed":
        invoice = event_data
        subscription_id = invoice.get("subscription")
        logger.warning(f"Invoice payment failed: invoice_id={invoice.get('id')}, subscription_id={subscription_id}")
    
    elif event_type == "invoice.finalized":
        invoice = event_data
        logger.info(f"Invoice finalized: invoice_id={invoice.get('id')}")
    
    # 保留对 Checkout Session 的兼容性（包括 iOS 微信支付二维码）
    elif event_type == "checkout.session.completed":
        session = event_data
        metadata = session.get("metadata", {})
        task_id = _safe_int_metadata(session, "task_id")
        payment_type = metadata.get("payment_type", "")
        
        logger.info(f"[WEBHOOK] Checkout Session 完成: session_id={session.get('id')}, task_id={task_id}, payment_type={payment_type}")
        
        if task_id:
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            task = db.execute(locked_task_query).scalar_one_or_none()
            if task and not task.is_paid:
                task.is_paid = 1
                # 存储 PaymentIntent ID（用于后续退款），Checkout Session 内部创建了 PaymentIntent
                session_pi = session.get("payment_intent")
                if session_pi and not task.payment_intent_id:
                    task.payment_intent_id = session_pi
                # 获取任务金额（使用最终成交价或原始标价）
                task_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0

                # 🔒 安全修复：始终使用后端计算的服务费，不信任metadata中的金额；按任务来源/类型取费率
                from app.utils.fee_calculator import calculate_application_fee_pence
                task_amount_pence = round(task_amount * 100)
                task_source = getattr(task, "task_source", None)
                task_type = getattr(task, "task_type", None)
                application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
                
                metadata_fee = int(metadata.get("application_fee", 0))
                if metadata_fee > 0 and metadata_fee != application_fee_pence:
                    logger.warning(f"⚠️ Checkout session 服务费不一致: metadata={metadata_fee}, calculated={application_fee_pence}, task_id={task_id}")
                
                # escrow_amount = 任务金额 - 平台服务费（任务接受人获得的金额）
                application_fee = application_fee_pence / 100.0
                taker_amount = task_amount - application_fee
                task.escrow_amount = max(0.0, taker_amount)  # 确保不为负数
                
                # 支付成功后，将任务状态从 pending_payment 更新为 in_progress
                if task.status == "pending_payment":
                    task.status = "in_progress"
                
                # 更新支付历史记录状态
                try:
                    checkout_session_id = session.get("id")
                    if checkout_session_id:
                        payment_history = db.query(models.PaymentHistory).filter(
                            models.PaymentHistory.task_id == task_id,
                            models.PaymentHistory.status == "pending"
                        ).order_by(models.PaymentHistory.created_at.desc()).first()
                        
                        if payment_history:
                            try:
                                payment_history.transition_status("succeeded")
                            except ValueError as e:
                                logger.warning(f"⚠️ [WEBHOOK] 状态转换被拒绝: {e}")
                            payment_history.payment_intent_id = session.get("payment_intent") or checkout_session_id
                            logger.info(f"[WEBHOOK] 更新支付历史记录状态为 succeeded: order_no={payment_history.order_no}")
                except Exception as e:
                    logger.warning(f"[WEBHOOK] 更新支付历史记录失败: {e}")
                
                # 跳蚤市场：Checkout Session 完成时更新商品状态为 sold（微信支付等）
                flea_market_item_id = metadata.get("flea_market_item_id")
                if flea_market_item_id:
                    try:
                        from app.models import FleaMarketItem
                        from app.id_generator import parse_flea_market_id
                        db_item_id = parse_flea_market_id(flea_market_item_id)
                        # 🔒 并发安全：使用 SELECT FOR UPDATE 锁定商品记录
                        flea_item = db.query(FleaMarketItem).filter(
                            and_(
                                FleaMarketItem.id == db_item_id,
                                FleaMarketItem.sold_task_id == task_id,
                                FleaMarketItem.status.in_(["active", "reserved"])
                            )
                        ).with_for_update().first()
                        if flea_item:
                            flea_item.status = "sold"
                            if flea_item.sold_task_id != task_id:
                                flea_item.sold_task_id = task_id
                            db.flush()
                            logger.info(f"✅ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 状态已更新为 sold (task_id: {task_id})")
                            from app.flea_market_extensions import invalidate_item_cache
                            invalidate_item_cache(flea_item.id)
                            # 发送商品已售出通知
                            try:
                                item_title = flea_item.title or metadata.get("task_title", "商品")
                                crud.create_notification(
                                    db=db,
                                    user_id=flea_item.seller_id,
                                    type="flea_market_sold",
                                    title="商品已售出",
                                    content=f"「{item_title}」已售出！买家已完成付款，可以开始交易了",
                                    related_id=str(task_id),
                                    auto_commit=False,
                                )
                                buyer_id = metadata.get("user_id")
                                if buyer_id:
                                    crud.create_notification(
                                        db=db,
                                        user_id=str(buyer_id),
                                        type="flea_market_payment_success",
                                        title="支付成功",
                                        content=f"您已成功购买「{item_title}」，可以联系卖家进行交易",
                                        related_id=str(task_id),
                                        auto_commit=False,
                                    )
                            except Exception as notify_err:
                                logger.warning(f"⚠️ [WEBHOOK] 创建跳蚤市场售出通知失败: {notify_err}")
                        else:
                            logger.warning(f"⚠️ [WEBHOOK] 微信支付跳蚤市场商品 {flea_market_item_id} 未找到 (task_id: {task_id})")
                    except Exception as e:
                        logger.error(f"❌ [WEBHOOK] 微信支付更新跳蚤市场商品状态失败: {e}", exc_info=True)
                
                db.commit()
                
                # 记录微信支付完成（用于调试）
                if payment_type == "wechat_checkout":
                    logger.info(f"✅ [WEBHOOK] 微信支付完成 (iOS WebView): task_id={task_id}, escrow_amount={task.escrow_amount}")
                else:
                    logger.info(f"Task {task_id} payment completed via Stripe Checkout Session, status updated to in_progress, escrow_amount: {task.escrow_amount}")
    
    # 处理 Transfer 事件（转账给任务接受人）
    elif event_type == "transfer.paid":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = _safe_int_metadata(transfer, "task_id")
        
        logger.info(f"✅ [WEBHOOK] Transfer 支付成功:")
        logger.info(f"  - Transfer ID: {transfer_id}")
        logger.info(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.info(f"  - Task ID: {task_id}")
        logger.info(f"  - Amount: {transfer.get('amount')} {transfer.get('currency')}")
        
        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()
            
            if transfer_record:
                # 防止重复处理：检查是否已经成功
                if transfer_record.status == "succeeded":
                    logger.warning(f"⚠️ [WEBHOOK] Transfer 记录已成功，跳过重复处理: transfer_record_id={transfer_record_id}")
                else:
                    # 更新转账记录状态
                    from decimal import Decimal
                    transfer_record.status = "succeeded"
                    transfer_record.succeeded_at = get_utc_time()
                    transfer_record.last_error = None
                    transfer_record.next_retry_at = None
                    
                    # 更新任务状态
                    task = crud.get_task(db, transfer_record.task_id)
                    if task:
                        task.is_confirmed = 1
                        task.paid_to_user_id = transfer_record.taker_id
                        task.escrow_amount = Decimal('0.0')  # 转账后清空托管金额
                        logger.info(f"✅ [WEBHOOK] 任务 {task.id} 转账完成，金额已转给接受人 {transfer_record.taker_id}")
                        
                        # 发送通知给任务接收人：任务金已发放
                        try:
                            # 格式化金额（从 Decimal 转换为字符串，保留两位小数）
                            amount_display = f"£{float(transfer_record.amount):.2f}"
                            task_title = task.title or f"任务 #{task.id}"
                            
                            # 创建通知内容：任务金已发放（金额 - 任务标题）
                            notification_content = f"任务金已发放：{amount_display} - {task_title}"
                            
                            # 创建通知
                            crud.create_notification(
                                db=db,
                                user_id=transfer_record.taker_id,
                                type="task_reward_paid",  # 任务奖励已支付
                                title="任务金已发放",
                                content=notification_content,
                                related_id=str(task.id),  # 关联任务ID，方便前端跳转
                                auto_commit=False  # 不自动提交，等待下面的 db.commit()
                            )
                            
                            # 发送推送通知
                            try:
                                send_push_notification(
                                    db=db,
                                    user_id=transfer_record.taker_id,
                                    notification_type="task_reward_paid",
                                    data={"task_id": task.id, "amount": str(transfer_record.amount)},
                                    template_vars={"task_title": task.title, "task_id": task.id}
                                )
                            except Exception as e:
                                logger.warning(f"发送任务金发放推送通知失败: {e}")
                                # 推送通知失败不影响主流程
                            
                            logger.info(f"✅ [WEBHOOK] 已发送任务金发放通知给用户 {transfer_record.taker_id}")
                        except Exception as e:
                            # 通知发送失败不影响转账流程
                            logger.error(f"❌ [WEBHOOK] 发送任务金发放通知失败: {e}", exc_info=True)
                    
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为成功: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer（metadata 含 wallet_tx_id）
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _w_tx_id = transfer["metadata"]["wallet_tx_id"]
            _w_user_id = transfer["metadata"].get("user_id", "")
            logger.info(
                f"✅ [WEBHOOK] 钱包提现 Transfer 成功: "
                f"transfer_id={transfer_id}, wallet_tx_id={_w_tx_id}, user={_w_user_id}"
            )
            try:
                from app.wallet_service import complete_withdrawal as _cw
                from app.wallet_models import WalletTransaction as _WT
                # 幂等：仅 pending 状态才更新
                _existing = db.query(_WT).filter(_WT.id == int(_w_tx_id)).first()
                if _existing and _existing.status == "pending":
                    _cw(db, int(_w_tx_id), transfer_id)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现已确认: wallet_tx_id={_w_tx_id}")
                elif _existing:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_existing.status}，跳过: wallet_tx_id={_w_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_w_tx_id}")
            except Exception as _w_err:
                logger.error(f"❌ [WEBHOOK] 确认钱包提现失败: wallet_tx_id={_w_tx_id}, error={_w_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")

    elif event_type == "transfer.failed":
        transfer = event_data
        transfer_id = transfer.get("id")
        transfer_record_id_str = transfer.get("metadata", {}).get("transfer_record_id")
        task_id = _safe_int_metadata(transfer, "task_id")
        failure_code = transfer.get("failure_code", "unknown")
        failure_message = transfer.get("failure_message", "Unknown error")

        logger.warning(f"❌ [WEBHOOK] Transfer 支付失败:")
        logger.warning(f"  - Transfer ID: {transfer_id}")
        logger.warning(f"  - Transfer Record ID: {transfer_record_id_str}")
        logger.warning(f"  - Task ID: {task_id}")
        logger.warning(f"  - 失败代码: {failure_code}")
        logger.warning(f"  - 失败信息: {failure_message}")

        if transfer_record_id_str:
            transfer_record_id = int(transfer_record_id_str)
            transfer_record = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.id == transfer_record_id
            ).first()

            if transfer_record:
                # 更新转账记录状态为失败
                transfer_record.status = "failed"
                transfer_record.last_error = f"{failure_code}: {failure_message}"
                transfer_record.next_retry_at = None

                # 不更新任务状态，保持原状

                db.commit()
                logger.info(f"✅ [WEBHOOK] Transfer 记录已更新为失败: transfer_record_id={transfer_record_id}")
            else:
                logger.warning(f"⚠️ [WEBHOOK] 未找到转账记录: transfer_record_id={transfer_record_id_str}")
        # 🔒 Fix W1: 处理钱包提现 Transfer 失败
        elif transfer.get("metadata", {}).get("wallet_tx_id"):
            _wf_tx_id = transfer["metadata"]["wallet_tx_id"]
            _wf_user_id = transfer["metadata"].get("user_id", "")
            logger.warning(
                f"❌ [WEBHOOK] 钱包提现 Transfer 失败: "
                f"transfer_id={transfer_id}, wallet_tx_id={_wf_tx_id}, user={_wf_user_id}, "
                f"failure={failure_code}: {failure_message}"
            )
            try:
                from app.wallet_service import fail_withdrawal as _fw
                from app.wallet_models import WalletTransaction as _WT2
                from decimal import Decimal as _Dec
                _fail_tx = db.query(_WT2).filter(_WT2.id == int(_wf_tx_id)).first()
                if _fail_tx and _fail_tx.status == "pending":
                    _refund_amount = abs(_fail_tx.amount)
                    # 用 DB 记录的 user_id，不信任 metadata（防御性）
                    _fw(db, int(_wf_tx_id), _fail_tx.user_id, _refund_amount, currency=_fail_tx.currency)
                    db.commit()
                    logger.info(f"✅ [WEBHOOK] 钱包提现失败，余额已退还: wallet_tx_id={_wf_tx_id}, amount={_refund_amount}")
                elif _fail_tx:
                    logger.info(f"ℹ️ [WEBHOOK] 钱包提现 tx 已是 {_fail_tx.status}，跳过: wallet_tx_id={_wf_tx_id}")
                else:
                    logger.error(f"❌ [WEBHOOK] 钱包提现 tx 不存在: wallet_tx_id={_wf_tx_id}")
            except Exception as _wf_err:
                logger.error(f"❌ [WEBHOOK] 退还钱包提现余额失败: wallet_tx_id={_wf_tx_id}, error={_wf_err}")
                db.rollback()
        else:
            logger.warning(f"⚠️ [WEBHOOK] Transfer metadata 中没有 transfer_record_id 或 wallet_tx_id")
    
    else:
        logger.info(f"ℹ️ [WEBHOOK] 未处理的事件类型: {event_type}")
        logger.info(f"  - 事件ID: {event_id}")
        # 只记录关键字段，避免日志过长
        event_summary = {}
        if isinstance(event_data, dict):
            for key in ['id', 'object', 'status', 'amount', 'currency']:
                if key in event_data:
                    event_summary[key] = event_data[key]
        logger.info(f"  - 事件数据摘要: {json.dumps(event_summary, ensure_ascii=False)}")
    
    # 标记事件处理完成
    if event_id:
        try:
            webhook_event = db.query(models.WebhookEvent).filter(
                models.WebhookEvent.event_id == event_id
            ).first()
            if webhook_event:
                webhook_event.processed = True
                webhook_event.processed_at = get_utc_time()
                webhook_event.processing_error = None
                db.commit()
                logger.debug(f"✅ [WEBHOOK] 事件处理完成，已标记: event_id={event_id}")
        except Exception as e:
            logger.error(f"❌ [WEBHOOK] 更新事件处理状态失败: {e}", exc_info=True)
            db.rollback()
    
    # 记录处理耗时和总结
    processing_time = time.time() - start_time
    logger.debug(f"⏱️ [WEBHOOK] 处理耗时: {processing_time:.3f} 秒")
    logger.info(f"✅ [WEBHOOK] Webhook 处理完成: {event_type}")
    logger.debug("=" * 80)
    
    return {"status": "success"}


@router.post("/tasks/{task_id}/confirm_complete")
def confirm_task_complete(
    task_id: int, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    [已弃用] 确认任务完成并通过 Stripe Transfer 直接转账给接受人的 Connect 账户。

    前端已切换到 POST /tasks/{task_id}/confirm_completion（钱包入账模式）。
    此端点仅供管理后台或特殊场景使用（如接受人要求直接 Stripe 到账）。
    自动结算由 auto_transfer_expired_tasks 定时任务处理。

    要求：
    1. 任务必须已支付
    2. 任务状态必须为 completed
    3. 任务接受人必须有 Stripe Connect 账户且已完成 onboarding
    """
    import logging

    logger = logging.getLogger(__name__)

    task = crud.get_task(db, task_id)
    if not task or task.poster_id != current_user.id:
        raise HTTPException(status_code=404, detail="Task not found or no permission.")
    if not task.is_paid or task.status != "completed" or task.is_confirmed:
        raise HTTPException(
            status_code=400, detail="Task not eligible for confirmation."
        )
    
    if not task.taker_id:
        raise HTTPException(
            status_code=400, detail="Task has no taker."
        )
    
    # 获取任务接受人信息
    taker = crud.get_user_by_id(db, task.taker_id)
    if not taker:
        raise HTTPException(
            status_code=404, detail="Task taker not found."
        )
    
    # 检查 escrow_amount 是否大于0
    if task.escrow_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="任务托管金额为0，无需转账。"
        )

    # 优先直接 Stripe Transfer（接单者有 Connect 账户时），否则入本地钱包
    try:
        # 确保 escrow_amount 正确（任务金额 - 平台服务费）
        # I8: 使用 Decimal 保精度，避免浮点累加误差
        if task.escrow_amount <= 0:
            task_amount_dec = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else (
                Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
            )
            from app.utils.fee_calculator import calculate_application_fee
            task_source = getattr(task, "task_source", None)
            task_type = getattr(task, "task_type", None)
            # calculate_application_fee 返回 float — 用 str 中转以避免二进制浮点误差
            application_fee_dec = Decimal(str(calculate_application_fee(float(task_amount_dec), task_source, task_type)))
            task.escrow_amount = max(Decimal('0'), task_amount_dec - application_fee_dec)
            logger.info(f"重新计算 escrow_amount: 任务金额={task_amount_dec}, 服务费={application_fee_dec}, escrow={task.escrow_amount}")

        escrow_amount = Decimal(str(task.escrow_amount))
        currency = (task.currency or "GBP").upper()
        payout_idempotency_key = f"earning:task:{task_id}:user:{taker.id}"

        # Team-aware destination: 团队任务 → experts.stripe_account_id,
        # 个人任务 → taker.stripe_account_id. spec §3.2 (v2)
        from app.services.expert_task_resolver import resolve_payout_destination
        is_team_task = bool(task.taker_expert_id)
        destination_stripe_id = resolve_payout_destination(db, task)

        if destination_stripe_id:
            # 有 Stripe Connect 账户 → 尝试直接转账
            amount_minor = int(escrow_amount * 100)
            try:
                stripe_transfer = stripe.Transfer.create(
                    amount=amount_minor,
                    currency=currency.lower(),
                    destination=destination_stripe_id,
                    description=f"Task #{task_id} payout",
                    metadata={
                        "task_id": str(task_id),
                        "taker_id": str(taker.id),
                        "taker_expert_id": str(task.taker_expert_id) if task.taker_expert_id else "",
                    },
                    idempotency_key=payout_idempotency_key,
                )
                logger.info(f"✅ 直接 Stripe Transfer: task={task_id}, transfer={stripe_transfer.id}, amount=£{escrow_amount:.2f}")
                payout_method = "stripe_transfer"
            except stripe.error.StripeError as stripe_err:
                if is_team_task:
                    # 团队任务不回退钱包
                    logger.error(f"任务 {task_id} 团队 Stripe Transfer 失败: {stripe_err}")
                    db.rollback()
                    raise HTTPException(status_code=500, detail={
                        "error_code": "team_payout_failed",
                        "message": f"Team Stripe transfer failed: {stripe_err}",
                    })
                # Stripe 明确拒绝 → 回退到钱包
                logger.warning(f"任务 {task_id} Stripe Transfer 被拒绝，回退到钱包入账: {stripe_err}")
                from app.wallet_service import credit_wallet
                credit_wallet(
                    db,
                    user_id=taker.id,
                    amount=escrow_amount,
                    source="task_earning",
                    related_id=str(task_id),
                    related_type="task",
                    description=f"任务 #{task_id} 收入（Stripe失败回退）",
                    currency=currency,
                    idempotency_key=payout_idempotency_key,
                )
                payout_method = "wallet_fallback"
        else:
            if is_team_task:
                # 防御性：团队任务必须走 Stripe，无 destination 视为错误
                logger.error(f"任务 {task_id} 团队任务无 Stripe 目的地")
                db.rollback()
                raise HTTPException(status_code=500, detail={
                    "error_code": "team_payout_failed",
                    "message": "Team task has no Stripe destination",
                })
            # 无 Stripe Connect 账户 → 入本地钱包
            from app.wallet_service import credit_wallet
            credit_wallet(
                db,
                user_id=taker.id,
                amount=escrow_amount,
                source="task_earning",
                related_id=str(task_id),
                related_type="task",
                description=f"任务 #{task_id} 收入 - {task.title}",
                currency=currency,
                idempotency_key=payout_idempotency_key,
            )
            logger.info(f"✅ 钱包入账: task={task_id}, amount=£{escrow_amount:.2f}（用户无 Stripe Connect）")
            payout_method = "wallet"

        # 更新任务状态
        task.is_confirmed = 1
        task.paid_to_user_id = task.taker_id
        transfer_amount = task.escrow_amount  # 先保存转账金额
        task.escrow_amount = 0.0  # 入账后清空托管金额

        db.commit()

        return {
            "message": f"Payment sent via {payout_method}.",
            "amount": transfer_amount,
            "currency": currency
        }

    except HTTPException:
        # 团队任务 payout 失败的结构化错误 → 原样抛出 (spec §3.2 v2)
        raise
    except Exception as e:
        logger.error(f"Error confirming task {task_id}: {e}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="确认任务完成时发生错误，请重试。"
        )


# 已迁移到 admin_task_management_routes.py: /admin/tasks, /admin/tasks/{task_id}, /admin/tasks/batch-update, /admin/tasks/batch-delete


# 管理员处理客服请求相关API
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



@router.post("/users/vip/activate")
@rate_limit("vip_activate")
def activate_vip(
    http_request: Request,
    activation_request: schemas.VIPActivationRequest,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """激活VIP会员（通过IAP购买）- 生产级实现"""
    from app.iap_verification_service import iap_verification_service
    from datetime import datetime, timezone

    request = activation_request
    try:
        # 1. 验证产品ID
        if not iap_verification_service.validate_product_id(request.product_id):
            raise HTTPException(status_code=400, detail="无效的产品ID")
        
        # 2. 验证交易JWS
        try:
            transaction_info = iap_verification_service.verify_transaction_jws(request.transaction_jws)
        except ValueError as e:
            logger.error(f"JWS验证失败: {str(e)}")
            raise HTTPException(status_code=400, detail=f"交易验证失败: {str(e)}")
        
        # 3. 验证交易ID是否匹配
        if transaction_info["transaction_id"] != request.transaction_id:
            raise HTTPException(status_code=400, detail="交易ID不匹配")
        
        # 4. 验证产品ID是否匹配
        if transaction_info["product_id"] != request.product_id:
            raise HTTPException(status_code=400, detail="产品ID不匹配")
        
        # 5. 检查是否已经处理过这个交易（防止重复激活）
        existing_subscription = crud.get_vip_subscription_by_transaction_id(db, request.transaction_id)
        if existing_subscription:
            logger.warning(f"交易 {request.transaction_id} 已被处理过，用户: {existing_subscription.user_id}")
            # 如果交易已存在，检查是否是同一用户
            if existing_subscription.user_id != current_user.id:
                raise HTTPException(status_code=400, detail="该交易已被其他用户使用")
            # 如果是同一用户，返回现有订阅信息
            return {
                "message": "VIP已激活（重复请求）",
                "user_level": current_user.user_level,
                "product_id": request.product_id,
                "subscription_id": existing_subscription.id
            }
        
        # 6. 从Apple服务器获取交易信息（可选，用于额外验证）
        server_transaction_info = None
        try:
            server_transaction_info = iap_verification_service.get_transaction_info(
                request.transaction_id,
                transaction_info["environment"]
            )
            if server_transaction_info:
                logger.info(f"从Apple服务器获取交易信息成功: {request.transaction_id}")
        except Exception as e:
            logger.warning(f"从Apple服务器获取交易信息失败（继续处理）: {str(e)}")
        
        # 7. 转换时间戳
        purchase_date = iap_verification_service.convert_timestamp_to_datetime(
            transaction_info["purchase_date"]
        )
        expires_date = None
        if transaction_info["expires_date"]:
            expires_date = iap_verification_service.convert_timestamp_to_datetime(
                transaction_info["expires_date"]
            )
        
        # 8. 创建VIP订阅记录
        subscription = crud.create_vip_subscription(
            db=db,
            user_id=current_user.id,
            product_id=request.product_id,
            transaction_id=request.transaction_id,
            original_transaction_id=transaction_info.get("original_transaction_id"),
            transaction_jws=request.transaction_jws,
            purchase_date=purchase_date,
            expires_date=expires_date,
            is_trial_period=transaction_info["is_trial_period"],
            is_in_intro_offer_period=transaction_info["is_in_intro_offer_period"],
            environment=transaction_info["environment"],
            status="active"
        )
        
        # 8.1 若为同一条订阅线升级（如月订→年订），将旧订阅标记为 replaced，与 Apple 状态一致
        otid = transaction_info.get("original_transaction_id")
        if otid:
            crud.mark_replaced_by_upgrade(
                db, current_user.id, otid, request.transaction_id
            )
        
        # 9. 更新用户VIP状态
        # 根据产品ID确定VIP类型
        user_level = "vip"
        if request.product_id == "com.link2ur.vip.yearly":
            # 年度订阅可以设置为super VIP（根据业务需求）
            user_level = "vip"  # 或 "super"
        
        crud.update_user_vip_status(db, current_user.id, user_level)
        try:
            from app.vip_subscription_service import vip_subscription_service
            vip_subscription_service.invalidate_vip_cache(current_user.id)
        except Exception as e:
            logger.debug("VIP cache invalidate: %s", e)

        # 10. 记录日志
        logger.info(
            f"用户 {current_user.id} 通过IAP激活VIP成功: "
            f"产品ID={request.product_id}, "
            f"交易ID={request.transaction_id}, "
            f"订阅ID={subscription.id}, "
            f"环境={transaction_info['environment']}"
        )
        
        # 11. 发送通知（可选）
        try:
            from app.push_notification_service import send_push_notification
            send_push_notification(
                db=db,
                user_id=current_user.id,
                notification_type="vip_activated",
                data={"type": "vip_activated", "subscription_id": subscription.id}
            )
        except Exception as e:
            logger.warning(f"发送VIP激活通知失败: {str(e)}")
        
        return {
            "message": "VIP激活成功",
            "user_level": user_level,
            "product_id": request.product_id,
            "subscription_id": subscription.id,
            "expires_date": expires_date.isoformat() if expires_date else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"激活VIP失败: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"激活VIP失败: {str(e)}")


@router.get("/users/vip/status")
def get_vip_status(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取当前用户的VIP订阅状态（带缓存）"""
    from app.vip_subscription_service import vip_subscription_service

    subscription_status = vip_subscription_service.check_subscription_status_cached(
        db, current_user.id
    )
    return {
        "user_level": current_user.user_level,
        "is_vip": current_user.user_level in ["vip", "super"],
        "subscription": subscription_status
    }


@router.get("/users/vip/history")
def get_vip_history(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0, le=100000)
):
    """获取当前用户的VIP订阅历史"""
    rows = crud.get_vip_subscription_history(db, current_user.id, limit=limit, offset=offset)
    total = crud.count_vip_subscriptions_by_user(db, current_user.id)
    items = []
    for s in rows:
        items.append({
            "id": s.id,
            "product_id": s.product_id,
            "transaction_id": s.transaction_id,
            "purchase_date": s.purchase_date.isoformat() if s.purchase_date else None,
            "expires_date": s.expires_date.isoformat() if s.expires_date else None,
            "status": s.status,
            "environment": s.environment,
            "is_trial_period": s.is_trial_period,
            "is_in_intro_offer_period": s.is_in_intro_offer_period,
            "auto_renew_status": s.auto_renew_status,
        })
    return {"items": items, "total": total}


@router.post("/webhooks/apple-iap")
async def apple_iap_webhook(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Apple IAP Webhook端点
    处理 App Store Server Notifications V2（signedPayload 验证）及 V1 兼容。
    """
    from app.vip_subscription_service import vip_subscription_service
    from app.apple_webhook_verifier import verify_and_decode_notification

    try:
        body = await request.json()
    except Exception as e:
        logger.warning("Apple IAP Webhook 无效 JSON: %s", e)
        return JSONResponse(status_code=400, content={"status": "error", "message": "Invalid JSON"})

    reject_v1 = os.getenv("APPLE_IAP_WEBHOOK_REJECT_V1", "true").lower() == "true"

    try:
        if "signedPayload" in body:
            signed_payload = body["signedPayload"]
            decoded = verify_and_decode_notification(signed_payload)
            if not decoded:
                logger.warning("Apple IAP Webhook V2 签名验证失败或未配置")
                return JSONResponse(
                    status_code=401,
                    content={"status": "error", "message": "Verification failed"},
                )
            notification_type = decoded.get("notificationType") or ""
            data = decoded.get("data") or {}
            logger.info("Apple IAP Webhook V2 已验证: %s", notification_type)

            if notification_type == "SUBSCRIBED":
                logger.info("V2 新订阅通知（激活由 /users/vip/activate 处理）")
            elif notification_type == "DID_RENEW":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_renewal(db, vip_subscription_service, jws)
                else:
                    logger.warning("V2 DID_RENEW 缺少 signedTransactionInfo")
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V2 订阅续费失败")
            elif notification_type == "CANCEL":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_cancel(db, vip_subscription_service, jws)
            elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
                logger.info("V2 续订状态变更")
            elif notification_type == "EXPIRED":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_expired(db, vip_subscription_service, jws)
            elif notification_type == "REFUND":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_refund(db, vip_subscription_service, jws)
            elif notification_type == "REVOKE":
                jws = data.get("signedTransactionInfo")
                if jws:
                    _handle_v2_revoke(db, vip_subscription_service, jws)
            elif notification_type == "GRACE_PERIOD_EXPIRED":
                logger.warning("V2 宽限期已过期")
            elif notification_type == "OFFER_REDEEMED":
                logger.info("V2 优惠兑换")
            elif notification_type == "DID_CHANGE_RENEWAL_PREF":
                logger.info("V2 续订偏好变更")
            elif notification_type == "RENEWAL_EXTENDED":
                logger.info("V2 续订已延长")
            elif notification_type == "TEST":
                logger.info("V2 测试通知")
            else:
                logger.info("V2 未处理类型: %s", notification_type)
            return {"status": "success"}

        notification_type = body.get("notification_type")
        if notification_type is not None:
            if reject_v1:
                logger.warning("拒绝未验证的 V1 Webhook（APPLE_IAP_WEBHOOK_REJECT_V1=true）")
                return JSONResponse(
                    status_code=400,
                    content={"status": "error", "message": "V1 notifications rejected"},
                )
            unified_receipt = body.get("unified_receipt", {})
            latest_receipt_info = unified_receipt.get("latest_receipt_info", [])
            logger.info("Apple IAP Webhook V1（未验证）: %s", notification_type)

            if notification_type == "INITIAL_BUY":
                logger.info("V1 初始购买")
            elif notification_type == "DID_RENEW" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                orig = lt.get("original_transaction_id")
                tid = lt.get("transaction_id")
                logger.info("V1 续费: %s -> %s（无 JWS，仅记录）", orig, tid)
            elif notification_type == "DID_FAIL_TO_RENEW":
                logger.warning("V1 续费失败")
            elif notification_type == "CANCEL" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                reason = lt.get("cancellation_reason")
                if tid:
                    vip_subscription_service.cancel_subscription(db, tid, reason)
            elif notification_type == "REFUND" and latest_receipt_info:
                lt = latest_receipt_info[-1]
                tid = lt.get("transaction_id")
                if tid:
                    vip_subscription_service.process_refund(db, tid, "Apple退款")

            return {"status": "success"}

        logger.warning("Apple IAP Webhook 无法识别格式（无 signedPayload 且无 notification_type）")
        return JSONResponse(status_code=400, content={"status": "error", "message": "Unknown payload"})
    except Exception as e:
        logger.error("处理Apple IAP Webhook失败: %s", e, exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)},
        )


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

@router.get("/admin/task-experts")
def get_task_experts(
    page: int = 1,
    size: int = 20,
    category: Optional[str] = None,
    is_active: Optional[int] = None,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人列表（管理员）"""
    try:
        query = db.query(models.FeaturedTaskExpert)
        
        # 筛选
        if category:
            query = query.filter(models.FeaturedTaskExpert.category == category)
        if is_active is not None:
            query = query.filter(models.FeaturedTaskExpert.is_active == is_active)
        
        # 排序
        query = query.order_by(
            models.FeaturedTaskExpert.display_order,
            models.FeaturedTaskExpert.created_at.desc()
        )
        
        total = query.count()
        skip = (page - 1) * size
        experts = query.offset(skip).limit(size).all()
        
        return {
            "task_experts": [
                {
                    "id": expert.id,
                    "user_id": expert.user_id,
                    "name": expert.name,
                    "avatar": expert.avatar,
                    "user_level": expert.user_level,
                    "bio": expert.bio,
                    "bio_en": expert.bio_en,
                    "avg_rating": expert.avg_rating,
                    "completed_tasks": expert.completed_tasks,
                    "total_tasks": expert.total_tasks,
                    "completion_rate": expert.completion_rate,
                    "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
                    "expertise_areas_en": json.loads(expert.expertise_areas_en) if expert.expertise_areas_en else [],
                    "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
                    "featured_skills_en": json.loads(expert.featured_skills_en) if expert.featured_skills_en else [],
                    "achievements": json.loads(expert.achievements) if expert.achievements else [],
                    "achievements_en": json.loads(expert.achievements_en) if expert.achievements_en else [],
                    "response_time": expert.response_time,
                    "response_time_en": expert.response_time_en,
                    "success_rate": expert.success_rate,
                    "is_verified": bool(expert.is_verified),
                    "is_active": bool(expert.is_active),
                    "is_featured": bool(expert.is_featured),
                    "display_order": expert.display_order,
                    "category": expert.category,
                    "location": expert.location,  # 添加城市字段
                    "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
                    "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
                }
                for expert in experts
            ],
            "total": total,
            "page": page,
            "size": size
        }
    except Exception as e:
        logger.error(f"获取任务达人列表失败: {e}")
        raise HTTPException(status_code=500, detail="获取任务达人列表失败")


@router.get("/admin/task-expert/{expert_id}")
def get_task_expert(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取单个任务达人详情（管理员）"""
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).first()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        return {
            "id": expert.id,
            "user_id": expert.user_id,
            "name": expert.name,
            "avatar": expert.avatar,
            "user_level": expert.user_level,
            "bio": expert.bio,
            "bio_en": expert.bio_en,
            "avg_rating": expert.avg_rating,
            "completed_tasks": expert.completed_tasks,
            "total_tasks": expert.total_tasks,
            "completion_rate": expert.completion_rate,
            "expertise_areas": json.loads(expert.expertise_areas) if expert.expertise_areas else [],
            "expertise_areas_en": json.loads(expert.expertise_areas_en) if expert.expertise_areas_en else [],
            "featured_skills": json.loads(expert.featured_skills) if expert.featured_skills else [],
            "featured_skills_en": json.loads(expert.featured_skills_en) if expert.featured_skills_en else [],
            "achievements": json.loads(expert.achievements) if expert.achievements else [],
            "achievements_en": json.loads(expert.achievements_en) if expert.achievements_en else [],
            "response_time": expert.response_time,
            "response_time_en": expert.response_time_en,
            "success_rate": expert.success_rate,
            "is_verified": bool(expert.is_verified),
            "is_active": expert.is_active if expert.is_active is not None else 1,
            "is_featured": expert.is_featured if expert.is_featured is not None else 1,
            "display_order": expert.display_order,
            "category": expert.category,
            "location": expert.location,
            "created_at": format_iso_utc(expert.created_at) if expert.created_at else None,
            "updated_at": format_iso_utc(expert.updated_at) if expert.updated_at else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人详情失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取任务达人详情失败: {str(e)}")


@router.post("/admin/task-expert")
def create_task_expert(
    expert_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """创建任务达人（管理员）"""
    from sqlalchemy.exc import IntegrityError
    
    # 1. 确保 expert_data 包含 user_id，并且 id 和 user_id 相同
    if 'user_id' not in expert_data:
        raise HTTPException(status_code=400, detail="必须提供 user_id")
    
    user_id = expert_data['user_id']
    
    # 2. 验证 user_id 格式（应该是8位字符串）
    if not isinstance(user_id, str) or len(user_id) != 8:
        raise HTTPException(status_code=400, detail="user_id 必须是8位字符串")
    
    # 3. 验证用户是否存在
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 4. 检查用户是否已经是基础任务达人（TaskExpert）
    existing_task_expert = db.query(models.TaskExpert).filter(
        models.TaskExpert.id == user_id
    ).first()
    if not existing_task_expert:
        raise HTTPException(status_code=400, detail="该用户还不是任务达人，请先批准任务达人申请")
    
    # 5. 检查用户是否已经是特色任务达人（FeaturedTaskExpert）
    existing_featured = db.query(models.FeaturedTaskExpert).filter(
        models.FeaturedTaskExpert.id == user_id
    ).first()
    if existing_featured:
        raise HTTPException(status_code=400, detail="该用户已经是特色任务达人")
    
    # 设置 id 为 user_id
    expert_data['id'] = user_id
    
    # 重要：头像永远不要自动从用户表同步，必须由管理员手动设置
    # 如果 expert_data 中没有提供 avatar，确保使用空字符串而不是用户头像
    if 'avatar' not in expert_data:
        expert_data['avatar'] = ""
    
    try:
        # 将数组字段转换为 JSON
        for field in ['expertise_areas', 'expertise_areas_en', 'featured_skills', 'featured_skills_en', 'achievements', 'achievements_en']:
            if field in expert_data and isinstance(expert_data[field], list):
                expert_data[field] = json.dumps(expert_data[field])
        
        new_expert = models.FeaturedTaskExpert(
            **expert_data,
            created_by=current_admin.id
        )
        db.add(new_expert)
        db.commit()
        db.refresh(new_expert)
        
        logger.info(f"创建任务达人成功: {new_expert.id}")
        
        return {
            "message": "创建任务达人成功",
            "task_expert": {
                "id": new_expert.id,
                "name": new_expert.name,
            }
        }
    except IntegrityError as e:
        db.rollback()
        logger.error(f"创建任务达人失败（完整性错误）: {e}")
        # 检查是否是主键冲突
        if "duplicate key" in str(e).lower() or "unique constraint" in str(e).lower():
            raise HTTPException(status_code=409, detail="该用户已经是特色任务达人（并发冲突）")
        raise HTTPException(status_code=400, detail=f"数据完整性错误: {str(e)}")
    except Exception as e:
        logger.error(f"创建任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"创建任务达人失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}")
def update_task_expert(
    expert_id: str,  # 改为字符串类型
    expert_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人（管理员）"""
    from sqlalchemy.exc import IntegrityError
    
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).with_for_update().first()

        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")

        # 1. 禁止修改 user_id 和 id（主键不能修改）
        if 'user_id' in expert_data and expert_data['user_id'] != expert.user_id:
            raise HTTPException(status_code=400, detail="不允许修改 user_id，如需更换用户请删除后重新创建")
        
        if 'id' in expert_data and expert_data['id'] != expert.id:
            raise HTTPException(status_code=400, detail="不允许修改 id（主键），如需更换用户请删除后重新创建")
        
        # 2. 如果提供了 user_id，验证用户是否存在
        if 'user_id' in expert_data:
            user_id = expert_data['user_id']
            if not isinstance(user_id, str) or len(user_id) != 8:
                raise HTTPException(status_code=400, detail="user_id 必须是8位字符串")
            
            user = db.query(models.User).filter(models.User.id == user_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="用户不存在")
        
        # 将数组字段转换为 JSON
        for field in ['expertise_areas', 'expertise_areas_en', 'featured_skills', 'featured_skills_en', 'achievements', 'achievements_en']:
            if field in expert_data and isinstance(expert_data[field], list):
                expert_data[field] = json.dumps(expert_data[field])
        
        # 从 expert_data 中移除 id 和 user_id（不允许更新）
        expert_data.pop('id', None)
        expert_data.pop('user_id', None)
        
        # 保存旧头像URL，用于后续删除（仅在新头像有效时才删除旧头像）
        old_avatar_url = expert.avatar if 'avatar' in expert_data else None
        
        # 记录要更新的字段（用于调试）
        logger.info(f"更新任务达人 {expert_id}，接收到的字段: {list(expert_data.keys())}")
        if 'location' in expert_data:
            logger.info(f"location 字段值: {expert_data['location']}")
        
        # 更新字段（排除主键 id，因为它不应该被更新）
        # 注意：id 和 user_id 的同步已经在上面处理过了，这里只需要更新其他字段
        excluded_fields = {'id', 'user_id'}  # 主键和关联字段不应该通过循环更新
        # 需要特殊处理的字段：如果值为空字符串或None，且原值存在，则跳过更新（避免覆盖原有数据）
        preserve_if_empty_fields = {'avatar'}  # 头像字段：如果新值为空且原值存在，则保留原值
        updated_fields = []
        for key, value in expert_data.items():
            if key not in excluded_fields and hasattr(expert, key):
                # 跳过只读字段或不应该更新的字段
                if key not in ['created_at', 'created_by']:  # 创建时间和创建者不应该被更新
                    old_value = getattr(expert, key, None)
                    # 对于需要保留的字段，如果新值为空且原值存在，则跳过更新
                    if key in preserve_if_empty_fields:
                        if (value is None or value == '') and old_value:
                            logger.info(f"跳过更新字段 {key}：新值为空，保留原值 {old_value}")
                            continue
                    setattr(expert, key, value)
                    updated_fields.append(f"{key}: {old_value} -> {value}")
        
        logger.info(f"更新的字段: {updated_fields}")
        
        # 如果更新了名字，同步更新 TaskExpert 表中的 expert_name
        # 检查 name 是否在 expert_data 中且不在排除字段中（说明会被更新）
        if 'name' in expert_data and 'name' not in excluded_fields:
            # 重要：预加载 services 关系，避免级联删除问题
            from sqlalchemy.orm import joinedload
            task_expert = db.query(models.TaskExpert).options(
                joinedload(models.TaskExpert.services)
            ).filter(
                models.TaskExpert.id == expert.user_id
            ).first()
            if task_expert:
                # 使用更新后的 expert.name（在 commit 前已经通过 setattr 更新）
                task_expert.expert_name = expert.name
                task_expert.updated_at = get_utc_time()
                logger.info(f"同步更新 TaskExpert.expert_name: {task_expert.expert_name} (来自 FeaturedTaskExpert.name: {expert.name})")
            else:
                logger.warning(f"未找到对应的 TaskExpert 记录 (user_id: {expert.user_id})")
        
        # 如果更新了头像，同步更新 TaskExpert 表中的 avatar
        # 检查 avatar 是否在 expert_data 中且不在排除字段中（说明会被更新）
        if 'avatar' in expert_data and 'avatar' not in excluded_fields:
            # 直接检查传入的 avatar 值，只有当传入的是有效的非空 URL 时才同步更新
            # 不能传递空值，只能传递更新有 url 的头像值
            avatar_value = expert_data.get('avatar')
            if avatar_value and avatar_value.strip():  # 确保不是 None、空字符串或只有空白字符
                # 重要：预加载 services 关系，避免级联删除问题
                from sqlalchemy.orm import joinedload
                task_expert = db.query(models.TaskExpert).options(
                    joinedload(models.TaskExpert.services)
                ).filter(
                    models.TaskExpert.id == expert.user_id
                ).first()
                if task_expert:
                    # 使用传入的有效头像 URL（expert.avatar 已经通过 setattr 更新）
                    task_expert.avatar = expert.avatar
                    task_expert.updated_at = get_utc_time()
                    logger.info(f"同步更新 TaskExpert.avatar: {task_expert.avatar} (来自 FeaturedTaskExpert.avatar: {expert.avatar})")
                else:
                    logger.warning(f"未找到对应的 TaskExpert 记录 (user_id: {expert.user_id})")
            else:
                logger.info(f"跳过同步更新头像：传入的 avatar 值为空或无效 (user_id: {expert.user_id})")
        
        expert.updated_at = get_utc_time()
        db.commit()
        db.refresh(expert)
        
        # 验证 location 是否已更新
        logger.info(f"更新后的 location 值: {expert.location}")
        
        # 如果更换了头像，删除旧头像
        # 注意：只有当头像实际被更新（expert.avatar 不再等于旧值）时才删除旧文件
        if old_avatar_url and 'avatar' in expert_data and expert.avatar != old_avatar_url:
            from app.image_cleanup import delete_expert_avatar
            try:
                delete_expert_avatar(expert_id, old_avatar_url)
            except Exception as e:
                logger.warning(f"删除旧头像失败: {e}")
        
        logger.info(f"更新任务达人成功: {expert_id}")

        # 同步更新到新 experts 表（Phase 2a 兼容）
        try:
            from app.models_expert import Expert
            from sqlalchemy import text as sa_text
            map_result = db.execute(
                sa_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
                {"old_id": expert.user_id}
            ).first()
            if map_result:
                new_expert_id = map_result[0]
                new_expert = db.query(Expert).filter(Expert.id == new_expert_id).first()
                if new_expert:
                    if 'name' in expert_data:
                        new_expert.name = expert.name
                    if 'bio' in expert_data:
                        new_expert.bio = expert.bio
                    if 'bio_en' in expert_data:
                        new_expert.bio_en = expert.bio_en
                    if 'avatar' in expert_data and expert.avatar:
                        new_expert.avatar = expert.avatar
                    if 'is_official' in expert_data:
                        new_expert.is_official = bool(expert_data.get('is_official'))
                    if hasattr(expert, 'category') and 'category' in expert_data:
                        pass  # experts 表没有 category 字段，category 在 featured_experts_v2
                    new_expert.updated_at = get_utc_time()
                    db.commit()
                    logger.info(f"同步更新新 experts 表: {new_expert_id}")
        except Exception as sync_err:
            logger.warning(f"同步更新新 experts 表失败（不影响主流程）: {sync_err}")

        return {
            "message": "更新任务达人成功",
            "task_expert": {"id": expert.id, "name": expert.name}
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新任务达人失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}")
def delete_task_expert(
    expert_id: str,  # 改为字符串类型
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除任务达人（管理员）"""
    try:
        expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == expert_id
        ).first()
        
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        db.delete(expert)
        db.commit()
        
        logger.info(f"删除任务达人成功: {expert_id}")
        
        return {"message": "删除任务达人成功"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除任务达人失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"删除任务达人失败: {str(e)}")


# ==================== 管理员管理任务达人服务和活动 API ====================
# 注：GET /api/admin/experts/services 与 GET /api/admin/experts/activities 在 admin_expert_routes.py

@router.get("/admin/task-expert/{expert_id}/services")
def get_expert_services_admin(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人的服务列表（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        services = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.expert_id == expert_id
        ).order_by(models.TaskExpertService.display_order, models.TaskExpertService.created_at.desc()).all()
        
        return {
            "services": [
                {
                    "id": s.id,
                    "expert_id": s.expert_id,
                    "service_name": s.service_name,
                    "service_name_en": s.service_name_en,
                    "service_name_zh": s.service_name_zh,
                    "description": s.description,
                    "description_en": s.description_en,
                    "description_zh": s.description_zh,
                    "images": s.images,
                    "base_price": float(s.base_price) if s.base_price else 0,
                    "currency": s.currency,
                    "status": s.status,
                    "display_order": s.display_order,
                    "view_count": s.view_count,
                    "application_count": s.application_count,
                    "has_time_slots": s.has_time_slots,
                    "time_slot_duration_minutes": s.time_slot_duration_minutes,
                    "time_slot_start_time": str(s.time_slot_start_time) if s.time_slot_start_time else None,
                    "time_slot_end_time": str(s.time_slot_end_time) if s.time_slot_end_time else None,
                    "participants_per_slot": s.participants_per_slot,
                    "weekly_time_slot_config": s.weekly_time_slot_config,
                    "created_at": s.created_at.isoformat() if s.created_at else None,
                    "updated_at": s.updated_at.isoformat() if s.updated_at else None,
                }
                for s in services
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人服务列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取服务列表失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}/services/{service_id}")
def update_expert_service_admin(
    expert_id: str,
    service_id: int,
    service_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人的服务（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 更新服务字段
        for key, value in service_data.items():
            if hasattr(service, key) and key not in ['id', 'expert_id', 'created_at']:
                if key == 'base_price' and value is not None:
                    from decimal import Decimal
                    setattr(service, key, Decimal(str(value)))
                elif key in ['time_slot_start_time', 'time_slot_end_time'] and value:
                    from datetime import time as dt_time
                    setattr(service, key, dt_time.fromisoformat(value))
                elif key == 'weekly_time_slot_config':
                    # weekly_time_slot_config是JSONB字段，直接设置
                    setattr(service, key, value)
                else:
                    setattr(service, key, value)
        
        service.updated_at = get_utc_time()
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 更新任务达人 {expert_id} 的服务 {service_id}")
        
        return {"message": "服务更新成功", "service_id": service_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新服务失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新服务失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}/services/{service_id}")
def delete_expert_service_admin(
    expert_id: str,
    service_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """删除任务达人的服务（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 检查是否有任务正在使用这个服务
        tasks_using_service = db.query(models.Task).filter(
            models.Task.expert_service_id == service_id
        ).count()
        
        # 检查是否有活动正在使用这个服务
        activities_using_service = db.query(models.Activity).filter(
            models.Activity.expert_service_id == service_id
        ).count()
        
        # 检查是否有进行中的服务申请
        pending_applications = db.query(models.ServiceApplication).filter(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.status.in_(["pending", "negotiating", "price_agreed"])
        ).count()

        if tasks_using_service > 0 or activities_using_service > 0 or pending_applications > 0:
            error_msg = "无法删除服务，因为"
            reasons = []
            if tasks_using_service > 0:
                reasons.append(f"有 {tasks_using_service} 个任务正在使用此服务")
            if activities_using_service > 0:
                reasons.append(f"有 {activities_using_service} 个活动正在使用此服务")
            if pending_applications > 0:
                reasons.append(f"有 {pending_applications} 个待处理的服务申请")
            error_msg += "、" .join(reasons) + "。请先处理相关任务和活动后再删除。"
            raise HTTPException(status_code=400, detail=error_msg)

        # 检查是否有未过期且仍有参与者的时间段
        from app.utils.time_utils import get_utc_time
        current_utc = get_utc_time()
        
        future_slots_with_participants = db.query(models.ServiceTimeSlot).filter(
            models.ServiceTimeSlot.service_id == service_id,
            models.ServiceTimeSlot.slot_start_datetime >= current_utc,
            models.ServiceTimeSlot.current_participants > 0
        ).count()
        
        if future_slots_with_participants > 0:
            raise HTTPException(
                status_code=400,
                detail=f"无法删除服务，因为有 {future_slots_with_participants} 个未过期的时间段仍有参与者。请等待时间段过期或处理相关参与者后再删除。"
            )
        
        # 查找所有相关的 ServiceTimeSlot IDs
        time_slots = db.query(models.ServiceTimeSlot.id).filter(
            models.ServiceTimeSlot.service_id == service_id
        ).all()
        time_slot_ids = [row[0] for row in time_slots]
        
        if time_slot_ids:
            # 删除所有 TaskTimeSlotRelation 记录
            db.query(models.TaskTimeSlotRelation).filter(
                models.TaskTimeSlotRelation.time_slot_id.in_(time_slot_ids)
            ).delete(synchronize_session=False)
            
            # 删除所有 ActivityTimeSlotRelation 记录
            db.query(models.ActivityTimeSlotRelation).filter(
                models.ActivityTimeSlotRelation.time_slot_id.in_(time_slot_ids)
            ).delete(synchronize_session=False)
        
        # 删除服务图片（如果存在）
        service_images = service.images if hasattr(service, 'images') and service.images else []
        if service_images:
            from app.image_cleanup import delete_service_images
            try:
                import json
                if isinstance(service_images, str):
                    image_urls = json.loads(service_images)
                elif isinstance(service_images, list):
                    image_urls = service_images
                else:
                    image_urls = []
                
                delete_service_images(expert_id, service_id, image_urls)
            except Exception as e:
                logger.warning(f"删除服务图片失败: {e}")
        
        # 更新任务达人的服务数量
        expert.total_services = max(0, expert.total_services - 1)
        
        # 现在安全地删除服务（cascades 到 ServiceTimeSlot）
        db.delete(service)
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 删除任务达人 {expert_id} 的服务 {service_id}")
        
        return {"message": "服务删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除服务失败: {e}")
        db.rollback()
        # 如果是外键约束错误，提供更友好的错误消息
        if "foreign key constraint" in str(e).lower() or "referenced" in str(e).lower():
            raise HTTPException(
                status_code=400,
                detail="无法删除服务，因为有任务或活动正在使用此服务。请先处理相关任务和活动后再删除。"
            )
        raise HTTPException(status_code=500, detail=f"删除服务失败: {str(e)}")


@router.get("/admin/task-expert/{expert_id}/activities")
def get_expert_activities_admin(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取任务达人的活动列表（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        activities = db.query(models.Activity).filter(
            models.Activity.expert_id == expert_id
        ).order_by(models.Activity.created_at.desc()).all()
        
        return {
            "activities": [
                {
                    "id": a.id,
                    "title": a.title,
                    "description": a.description,
                    "expert_id": a.expert_id,
                    "expert_service_id": a.expert_service_id,
                    "location": a.location,
                    "task_type": a.task_type,
                    "reward_type": a.reward_type,
                    "original_price_per_participant": float(a.original_price_per_participant) if a.original_price_per_participant else None,
                    "discount_percentage": float(a.discount_percentage) if a.discount_percentage else None,
                    "discounted_price_per_participant": float(a.discounted_price_per_participant) if a.discounted_price_per_participant else None,
                    "currency": a.currency,
                    "points_reward": a.points_reward,
                    "max_participants": a.max_participants,
                    "min_participants": a.min_participants,
                    "completion_rule": a.completion_rule,
                    "reward_distribution": a.reward_distribution,
                    "status": a.status,
                    "is_public": a.is_public,
                    "visibility": a.visibility,
                    "deadline": a.deadline.isoformat() if a.deadline else None,
                    "activity_end_date": a.activity_end_date.isoformat() if a.activity_end_date else None,
                    "images": a.images,
                    "has_time_slots": a.has_time_slots,
                    "created_at": a.created_at.isoformat() if a.created_at else None,
                }
                for a in activities
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务达人活动列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取活动列表失败: {str(e)}")


@router.put("/admin/task-expert/{expert_id}/activities/{activity_id}")
def update_expert_activity_admin(
    expert_id: str,
    activity_id: int,
    activity_data: dict,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """更新任务达人的活动（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证活动是否存在且属于该任务达人
        activity = db.query(models.Activity).filter(
            models.Activity.id == activity_id,
            models.Activity.expert_id == expert_id
        ).first()
        if not activity:
            raise HTTPException(status_code=404, detail="活动不存在")
        
        # 更新活动字段
        for key, value in activity_data.items():
            if hasattr(activity, key) and key not in ['id', 'expert_id', 'created_at']:
                if key in ['original_price_per_participant', 'discount_percentage', 'discounted_price_per_participant'] and value is not None:
                    from decimal import Decimal
                    setattr(activity, key, Decimal(str(value)))
                elif key in ['deadline'] and value:
                    from datetime import datetime
                    setattr(activity, key, datetime.fromisoformat(value.replace('Z', '+00:00')))
                elif key in ['activity_end_date'] and value:
                    from datetime import date
                    setattr(activity, key, date.fromisoformat(value))
                else:
                    setattr(activity, key, value)
        
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 更新任务达人 {expert_id} 的活动 {activity_id}")
        
        return {"message": "活动更新成功", "activity_id": activity_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新活动失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"更新活动失败: {str(e)}")


@router.delete("/admin/task-expert/{expert_id}/activities/{activity_id}")
def delete_expert_activity_admin(
    expert_id: str,
    activity_id: int,
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    删除任务达人的活动（管理员）- 级联删除
    
    管理员权限：
    - 可以删除任何状态的活动
    - 级联删除：会自动删除该活动关联的所有任务（无论任务状态如何）
    """
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 🔒 安全修复：使用 SELECT FOR UPDATE 锁定活动记录，防止并发删除导致重复积分退款
        activity = db.query(models.Activity).filter(
            models.Activity.id == activity_id,
            models.Activity.expert_id == expert_id
        ).with_for_update().first()
        if not activity:
            raise HTTPException(status_code=404, detail="活动不存在")
        
        # 级联删除逻辑：先删除所有关联的任务
        # 注意：Task.participants 和 Task.time_slot_relations 配置了 cascade="all, delete-orphan"，会自动删除
        related_tasks = db.query(models.Task).filter(
            models.Task.parent_activity_id == activity_id
        ).all()
        
        deleted_tasks_count = len(related_tasks)
        if related_tasks:
            # 先删除任务的时间段关联，避免 task_id 置空触发 NOT NULL 约束
            task_ids = [t.id for t in related_tasks]
            
            # 清理任务相关的历史/审计/奖励/参与者，防止外键约束阻止删除
            db.query(models.TaskHistory).filter(
                models.TaskHistory.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskAuditLog).filter(
                models.TaskAuditLog.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskParticipantReward).filter(
                models.TaskParticipantReward.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskParticipant).filter(
                models.TaskParticipant.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            db.query(models.TaskTimeSlotRelation).filter(
                models.TaskTimeSlotRelation.task_id.in_(task_ids)
            ).delete(synchronize_session=False)
            
            # 确保子表删除语句立即执行，避免后续删除任务时触发外键约束
            db.flush()
            
            for task in related_tasks:
                db.delete(task)
            logger.info(f"管理员 {current_admin.id} 删除活动 {activity_id} 时级联删除了 {deleted_tasks_count} 个关联任务（含时间段关联）")
        
        # 删除活动与时间段的关联关系（虽然外键有CASCADE，但显式删除更清晰）
        # 注意：这里只删除关联关系，不会删除时间段本身（ServiceTimeSlot），因为时间段是服务的资源
        db.query(models.ActivityTimeSlotRelation).filter(
            models.ActivityTimeSlotRelation.activity_id == activity_id
        ).delete(synchronize_session=False)
        
        # ⚠️ 优化：返还未使用的预扣积分（如果有）
        refund_points = 0
        if activity.reserved_points_total and activity.reserved_points_total > 0:
            # 计算应返还的积分 = 预扣积分 - 已发放积分
            distributed = activity.distributed_points_total or 0
            refund_points = activity.reserved_points_total - distributed
            
            if refund_points > 0:
                from app.coupon_points_crud import add_points_transaction
                try:
                    add_points_transaction(
                        db=db,
                        user_id=activity.expert_id,
                        type="refund",
                        amount=refund_points,  # 正数表示返还
                        source="activity_points_refund",
                        related_id=activity_id,
                        related_type="activity",
                        description=f"管理员删除活动，返还未使用的预扣积分（预扣 {activity.reserved_points_total}，已发放 {distributed}，返还 {refund_points}）",
                        idempotency_key=f"activity_admin_refund_{activity_id}_{refund_points}"
                    )
                    logger.info(f"管理员删除活动 {activity_id}，返还积分 {refund_points} 给用户 {activity.expert_id}")
                except Exception as e:
                    logger.error(f"管理员删除活动 {activity_id}，返还积分失败: {e}")
                    # 不抛出异常，继续删除活动
        
        # 删除活动（ActivityTimeSlotRelation 会通过外键 CASCADE 自动删除，但上面已经显式删除）
        db.delete(activity)
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 删除任务达人 {expert_id} 的活动 {activity_id}")
        
        return {
            "message": "活动及关联任务删除成功",
            "deleted_tasks_count": deleted_tasks_count
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除活动失败: {e}")
        db.rollback()
        # 如果是外键约束错误，提供更友好的错误消息
        if "foreign key constraint" in str(e).lower() or "referenced" in str(e).lower():
            raise HTTPException(
                status_code=400,
                detail=f"删除失败（外键约束）：{str(e)}"
            )
        raise HTTPException(status_code=500, detail=f"删除活动失败: {str(e)}")


@router.post("/admin/task-expert/{expert_id}/services/{service_id}/time-slots/batch-create")
def batch_create_service_time_slots_admin(
    expert_id: str,
    service_id: int,
    start_date: str = Query(..., description="开始日期，格式：YYYY-MM-DD"),
    end_date: str = Query(..., description="结束日期，格式：YYYY-MM-DD"),
    price_per_participant: float = Query(..., description="每个参与者的价格"),
    current_admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """批量创建服务时间段（管理员）"""
    try:
        # 验证任务达人是否存在
        expert = db.query(models.TaskExpert).filter(models.TaskExpert.id == expert_id).first()
        if not expert:
            raise HTTPException(status_code=404, detail="任务达人不存在")
        
        # 验证服务是否存在且属于该任务达人
        service = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.expert_id == expert_id
        ).first()
        if not service:
            raise HTTPException(status_code=404, detail="服务不存在")
        
        # 验证服务是否启用了时间段
        if not service.has_time_slots:
            raise HTTPException(status_code=400, detail="该服务未启用时间段功能")
        
        # 检查配置：优先使用 weekly_time_slot_config，否则使用旧的 time_slot_start_time/time_slot_end_time
        has_weekly_config = service.weekly_time_slot_config and isinstance(service.weekly_time_slot_config, dict)
        
        if not has_weekly_config:
            # 使用旧的配置方式（向后兼容）
            if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
                raise HTTPException(status_code=400, detail="服务的时间段配置不完整")
        else:
            # 使用新的按周几配置
            if not service.time_slot_duration_minutes or not service.participants_per_slot:
                raise HTTPException(status_code=400, detail="服务的时间段配置不完整（缺少时间段时长或参与者数量）")
        
        # 解析日期
        from datetime import date, timedelta, time as dt_time, datetime as dt_datetime
        from decimal import Decimal
        from app.utils.time_utils import parse_local_as_utc, LONDON
        
        try:
            start = date.fromisoformat(start_date)
            end = date.fromisoformat(end_date)
            if start > end:
                raise HTTPException(status_code=400, detail="开始日期必须早于或等于结束日期")
        except ValueError:
            raise HTTPException(status_code=400, detail="日期格式错误，应为YYYY-MM-DD")
        
        # 生成时间段（使用UTC时间存储）
        created_slots = []
        current_date = start
        duration_minutes = service.time_slot_duration_minutes
        price_decimal = Decimal(str(price_per_participant))
        
        # 周几名称映射（Python的weekday(): 0=Monday, 6=Sunday）
        weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        
        while current_date <= end:
            # 获取当前日期是周几（0=Monday, 6=Sunday）
            weekday = current_date.weekday()
            weekday_name = weekday_names[weekday]
            
            # 确定该日期的时间段配置
            if has_weekly_config:
                # 使用按周几配置
                day_config = service.weekly_time_slot_config.get(weekday_name, {})
                if not day_config.get('enabled', False):
                    # 该周几未启用，跳过
                    current_date += timedelta(days=1)
                    continue
                
                slot_start_time_str = day_config.get('start_time', '09:00:00')
                slot_end_time_str = day_config.get('end_time', '18:00:00')
                
                # 解析时间字符串
                try:
                    slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                    slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                except ValueError:
                    # 如果格式不对，尝试添加秒数
                    if len(slot_start_time_str) == 5:  # HH:MM
                        slot_start_time_str += ':00'
                    if len(slot_end_time_str) == 5:  # HH:MM
                        slot_end_time_str += ':00'
                    slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                    slot_end_time = dt_time.fromisoformat(slot_end_time_str)
            else:
                # 使用旧的统一配置
                slot_start_time = service.time_slot_start_time
                slot_end_time = service.time_slot_end_time
            
            # 检查该日期是否被手动删除（跳过手动删除的日期）
            start_local = dt_datetime.combine(current_date, dt_time(0, 0, 0))
            end_local = dt_datetime.combine(current_date, dt_time(23, 59, 59))
            start_utc = parse_local_as_utc(start_local, LONDON)
            end_utc = parse_local_as_utc(end_local, LONDON)
            
            # 检查该日期是否有手动删除的时间段
            deleted_check = db.query(models.ServiceTimeSlot).filter(
                models.ServiceTimeSlot.service_id == service_id,
                models.ServiceTimeSlot.slot_start_datetime >= start_utc,
                models.ServiceTimeSlot.slot_start_datetime <= end_utc,
                models.ServiceTimeSlot.is_manually_deleted == True,
            ).first()
            if deleted_check:
                # 该日期已被手动删除，跳过
                current_date += timedelta(days=1)
                continue
            
            # 计算该日期的时间段
            current_time = slot_start_time
            while current_time < slot_end_time:
                # 计算结束时间
                total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                end_hour = total_minutes // 60
                end_minute = total_minutes % 60
                if end_hour >= 24:
                    break  # 超出一天，跳过
                
                slot_end = dt_time(end_hour, end_minute)
                if slot_end > slot_end_time:
                    break  # 超出服务允许的结束时间
                
                # 将英国时间的日期+时间组合，然后转换为UTC
                slot_start_local = dt_datetime.combine(current_date, current_time)
                slot_end_local = dt_datetime.combine(current_date, slot_end)
                
                # 转换为UTC时间
                slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
                slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
                
                # 检查是否已存在且未被手动删除
                existing = db.query(models.ServiceTimeSlot).filter(
                    models.ServiceTimeSlot.service_id == service_id,
                    models.ServiceTimeSlot.slot_start_datetime == slot_start_utc,
                    models.ServiceTimeSlot.slot_end_datetime == slot_end_utc,
                    models.ServiceTimeSlot.is_manually_deleted == False,
                ).first()
                if not existing:
                    # 创建新时间段（使用UTC时间）
                    new_slot = models.ServiceTimeSlot(
                        service_id=service_id,
                        slot_start_datetime=slot_start_utc,
                        slot_end_datetime=slot_end_utc,
                        price_per_participant=price_decimal,
                        max_participants=service.participants_per_slot,
                        current_participants=0,
                        is_available=True,
                        is_manually_deleted=False,
                    )
                    db.add(new_slot)
                    created_slots.append(new_slot)
                
                # 移动到下一个时间段
                total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                next_hour = total_minutes // 60
                next_minute = total_minutes % 60
                if next_hour >= 24:
                    break
                current_time = dt_time(next_hour, next_minute)
            
            # 移动到下一天
            current_date += timedelta(days=1)
        
        db.commit()
        
        logger.info(f"管理员 {current_admin.id} 为任务达人 {expert_id} 的服务 {service_id} 批量创建了 {len(created_slots)} 个时间段")
        
        return {
            "message": f"成功创建 {len(created_slots)} 个时间段",
            "created_count": len(created_slots),
            "service_id": service_id,
            "expert_id": expert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量创建时间段失败: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"批量创建时间段失败: {str(e)}")


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

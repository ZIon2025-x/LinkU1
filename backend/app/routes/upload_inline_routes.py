"""
Upload-inline domain routes — extracted from app/routers.py (Task 8).

Contains the 7 inline upload + private-asset endpoints that historically
lived in routers.py:
  - POST /upload/image
  - POST /upload/public-image (deprecated)
  - POST /refresh-image-url
  - GET  /private-image/{image_id}
  - POST /messages/generate-image-url
  - POST /upload/file
  - GET  /private-file

Note: this is the legacy "inline" upload surface. The newer
`upload_routes.py` / `upload_v2_router` registration in main.py is unrelated
and unaffected by this split.

Mounts at both /api and /api/users via main.py (same as the original main_router).
"""
import logging
import os
from pathlib import Path
from typing import Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    Request,
    UploadFile,
)
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app import crud, models
from app.deps import get_current_user_secure_sync_csrf, get_db
from app.file_utils import _resolve_legacy_private_file_path
from app.rate_limiting import rate_limit

# Upload env detection — duplicated in cs_routes.py (cs routes also use
# RAILWAY_ENVIRONMENT/USE_CLOUD_STORAGE for legacy private-file fallback).
# Cheap two-line definition; kept inline rather than introducing a new
# shared utils module.
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
USE_CLOUD_STORAGE = os.getenv("USE_CLOUD_STORAGE", "false").lower() == "true"

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/upload/image")
@rate_limit("upload_file")
async def upload_image(
    image: UploadFile = File(...),
    task_id: Optional[int] = Query(None, description="任务ID（任务聊天时提供）"),
    chat_id: Optional[str] = Query(None, description="聊天ID（客服聊天时提供）"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    上传私密图片文件
    支持按任务ID或聊天ID分类存储
    - task_id: 任务聊天时提供，图片会存储在 tasks/{task_id}/ 文件夹
    - chat_id: 客服聊天时提供，图片会存储在 chats/{chat_id}/ 文件夹
    """
    try:
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check

        # 图片最大大小：5MB
        MAX_IMAGE_SIZE = 5 * 1024 * 1024

        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(image, MAX_IMAGE_SIZE)

        # 使用新的私密图片系统上传
        from app.image_system import private_image_system
        result = private_image_system.upload_image(content, image.filename, current_user.id, db, task_id=task_id, chat_id=chat_id, content_type=image.content_type)

        # 生成图片访问 URL（确保总是返回 URL，否则 iOS 无法解析并继续发送消息）
        if result.get("success") and result.get("image_id"):
            participants = []
            try:
                # 如果有 task_id，获取任务参与者
                if task_id:
                    task = crud.get_task(db, task_id)
                    if task:
                        if task.poster_id:
                            participants.append(str(task.poster_id))
                        if task.taker_id:
                            participants.append(str(task.taker_id))
                        # 多人任务：加入 TaskParticipant 及 expert_creator_id，确保接收方能加载私密图片
                        if getattr(task, "is_multi_participant", False):
                            if getattr(task, "expert_creator_id", None):
                                expert_id = str(task.expert_creator_id)
                                if expert_id not in participants:
                                    participants.append(expert_id)
                            for p in db.query(models.TaskParticipant).filter(
                                models.TaskParticipant.task_id == task_id,
                                models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                            ).all():
                                if p.user_id:
                                    user_id_str = str(p.user_id)
                                    if user_id_str not in participants:
                                        participants.append(user_id_str)

                # 添加当前用户（如果不在列表中）
                current_user_id_str = str(current_user.id)
                if current_user_id_str not in participants:
                    participants.append(current_user_id_str)

                # 如果没有参与者（不应该发生），至少包含当前用户
                if not participants:
                    participants = [current_user_id_str]

                # 生成图片访问 URL
                image_url = private_image_system.generate_image_url(
                    result["image_id"],
                    current_user_id_str,
                    participants
                )
                result["url"] = image_url
                logger.debug("upload/image: 已写入 result[url], image_id=%s", result.get("image_id"))
            except Exception as e:
                logger.warning("upload/image: 构建 participants 或 generate_image_url 失败: %s，使用仅当前用户生成 url", e)
                participants = [str(current_user.id)]
                image_url = private_image_system.generate_image_url(
                    result["image_id"],
                    str(current_user.id),
                    participants
                )
                result["url"] = image_url

        if result.get("image_id") and "url" not in result:
            logger.error("upload/image: image_id 存在但 result 中无 url，iOS 将无法解析。result keys=%s", list(result.keys()))
        return JSONResponse(content=result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/upload/public-image", deprecated=True)
@rate_limit("upload_file")
async def upload_public_image(
    request: Request,
    image: UploadFile = File(...),
    category: str = Query("public", description="图片类型：expert_avatar、service_image、public、leaderboard_item、leaderboard_cover、flea_market、forum_post（论坛帖子图片）"),
    resource_id: str = Query(None, description="资源ID：expert_avatar时传expert_id，service_image时传expert_id，public时传task_id（任务ID，发布新任务时可省略）"),
    db: Session = Depends(get_db),
):
    """
    ⚠️ 已废弃 — 请使用 /api/v2/upload/image（upload_routes.py）。
    V2 额外支持批量上传、temp 清理、论坛文件上传。Flutter 端已全部迁移至 V2。
    本接口保留仅为兼容旧版 iOS/Web 调用，后续将移除。

    ---
    上传公开图片文件（所有人可访问）
    用于头像等需要公开访问的图片
    支持管理员和普通用户上传

    参数:
    - category: 图片类型
      - expert_avatar: 任务达人头像
      - service_image: 服务图片
      - public: 其他公开图片（默认）
      - leaderboard_item: 竞品图片
      - leaderboard_cover: 榜单封面
      - flea_market: 跳蚤市场商品图片
    - resource_id: 资源ID，用于创建子文件夹
      - expert_avatar: 任务达人ID（expert_id）
      - service_image: 任务达人ID（expert_id），不是service_id
      - public: 任务ID（task_id），用于任务相关的图片
      - flea_market: 商品ID（item_id）

    优化功能：
    - 自动压缩图片（节省存储空间）
    - 自动旋转（根据 EXIF）
    - 移除隐私元数据
    - 限制最大尺寸
    """
    try:
        # 导入图片上传服务
        from app.services import ImageCategory, get_image_upload_service

        # 尝试获取管理员或用户ID
        user_id = None
        user_type = None

        # 首先尝试管理员认证
        from app.admin_auth import validate_admin_session
        admin_session = validate_admin_session(request)
        if admin_session:
            user_id = admin_session.admin_id
            user_type = "管理员"
        else:
            # 尝试普通用户认证
            from app.secure_auth import validate_session
            user_session = validate_session(request)
            if user_session:
                user_id = user_session.user_id
                user_type = "用户"
            else:
                raise HTTPException(status_code=401, detail="认证失败，请先登录")

        if not user_id:
            raise HTTPException(status_code=401, detail="认证失败，请先登录")

        # 类别映射
        category_map = {
            "expert_avatar": ImageCategory.EXPERT_AVATAR,
            "service_image": ImageCategory.SERVICE_IMAGE,
            "public": ImageCategory.TASK,
            "leaderboard_item": ImageCategory.LEADERBOARD_ITEM,
            "leaderboard_cover": ImageCategory.LEADERBOARD_COVER,
            "flea_market": ImageCategory.FLEA_MARKET,
            "forum_post": ImageCategory.FORUM_POST,
        }

        if category not in category_map:
            raise HTTPException(
                status_code=400,
                detail=f"无效的图片类型。允许的类型: {', '.join(category_map.keys())}"
            )

        image_category = category_map[category]

        # 确定是否使用临时目录
        is_temp = False
        actual_resource_id = resource_id

        if not resource_id:
            if category in ("expert_avatar", "service_image"):
                # 管理员上传时必须传 resource_id（达人 user_id），否则会存到 expert_avatars/{管理员id}/，孤儿清理会误删
                if admin_session:
                    raise HTTPException(
                        status_code=400,
                        detail="管理员上传达人头像或服务图片时请在 URL 中提供 resource_id（达人 user_id）",
                    )
                # 普通用户：头像/服务图使用当前用户 id
                actual_resource_id = user_id
            else:
                # 其他类别使用临时目录
                is_temp = True
        elif resource_id.startswith("temp_"):
            is_temp = True
            actual_resource_id = None  # 服务会自动使用 user_id 构建临时目录

        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check

        # 公开图片最大大小：5MB
        MAX_PUBLIC_IMAGE_SIZE = 5 * 1024 * 1024

        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(image, MAX_PUBLIC_IMAGE_SIZE)

        # 使用图片上传服务
        service = get_image_upload_service()
        result = service.upload(
            content=content,
            category=image_category,
            resource_id=actual_resource_id,
            user_id=user_id,
            filename=image.filename,
            is_temp=is_temp
        )

        if not result.success:
            raise HTTPException(status_code=400, detail=result.error)

        logger.info(
            f"{user_type} {user_id} 上传公开图片 [{category}]: "
            f"size={result.original_size}->{result.size}, "
            f"resource_id={actual_resource_id or 'temp'}"
        )

        # 返回响应（保持与原 API 兼容的格式）
        response_data = {
            "success": True,
            "url": result.url,
            "filename": result.filename,
            "size": result.size,
            "category": category,
            "resource_id": resource_id or f"temp_{user_id}",
            "message": "图片上传成功"
        }

        # 添加压缩信息
        if result.original_size != result.size:
            response_data["original_size"] = result.original_size
            response_data["compression_saved"] = result.original_size - result.size

        return JSONResponse(content=response_data)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"公开图片上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/refresh-image-url")
async def refresh_image_url(
    request: dict,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf)
):
    """
    刷新过期的图片URL
    """
    try:
        original_url = request.get("original_url")
        if not original_url:
            raise HTTPException(status_code=400, detail="缺少original_url参数")

        # 从URL中提取文件名
        from urllib.parse import urlparse, parse_qs
        parsed_url = urlparse(original_url)
        query_params = parse_qs(parsed_url.query)

        if 'file' not in query_params:
            raise HTTPException(status_code=400, detail="无法从URL中提取文件名")

        filename = query_params['file'][0]

        # 生成新的签名URL（无过期时间）
        from app.signed_url import signed_url_manager
        new_url = signed_url_manager.generate_signed_url(
            file_path=f"images/{filename}",
            user_id=current_user.id,
            expiry_minutes=None,  # 无过期时间
            one_time=False
        )

        logger.info(f"用户 {current_user.id} 刷新图片URL: {filename}")

        return JSONResponse(content={
            "success": True,
            "url": new_url,
            "filename": filename
        })

    except Exception as e:
        logger.error(f"刷新图片URL失败: {e}")
        raise HTTPException(status_code=500, detail=f"刷新失败: {str(e)}")


@router.get("/private-image/{image_id}")
async def get_private_image(
    image_id: str,
    user: str = Query(..., description="用户ID"),
    token: str = Query(..., description="访问令牌"),
    db: Session = Depends(get_db)
):
    """
    获取私密图片（需要验证访问权限）
    """
    try:
        from app.image_system import private_image_system
        return private_image_system.get_image(image_id, user, token, db)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取私密图片失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取图片失败: {str(e)}")


@router.post("/messages/generate-image-url")
def generate_image_url(
    request_data: dict,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    为聊天参与者生成图片访问URL
    """
    try:
        from app.image_system import private_image_system
        from urllib.parse import urlparse, parse_qs
        import re

        # 从请求数据中获取image_id
        raw_image_id = request_data.get('image_id')
        if not raw_image_id:
            raise HTTPException(status_code=400, detail="缺少image_id参数")

        logger.info(f"尝试生成图片URL，原始image_id: {raw_image_id}")

        # 处理不同格式的image_id
        image_id = raw_image_id

        # 如果是base64数据（旧格式），直接返回错误
        if raw_image_id.startswith('data:image/'):
            logger.error(f"检测到旧的base64格式图片数据，不支持")
            raise HTTPException(status_code=400, detail="此图片使用旧格式存储，请重新发送图片")

        # 如果是完整的URL，尝试提取图片ID
        if raw_image_id.startswith('http'):
            try:
                parsed_url = urlparse(raw_image_id)
                if '/api/private-file' in parsed_url.path:
                    # 从private-file URL中提取file参数
                    query_params = parse_qs(parsed_url.query)
                    if 'file' in query_params:
                        file_path = query_params['file'][0]
                        # 提取文件名（去掉images/前缀）
                        if file_path.startswith('images/'):
                            image_id = file_path[7:]  # 去掉'images/'前缀
                            # 去掉文件扩展名
                            image_id = image_id.rsplit('.', 1)[0]
                        else:
                            image_id = file_path.rsplit('.', 1)[0]
                        logger.info(f"从URL提取image_id: {image_id}")
                elif '/private-image/' in parsed_url.path:
                    # 从private-image URL中提取image_id
                    image_id = parsed_url.path.split('/private-image/')[-1]
                    logger.info(f"从private-image URL提取image_id: {image_id}")
            except Exception as e:
                logger.warning(f"URL解析失败: {e}")
                # 如果URL解析失败，尝试从URL中提取可能的ID
                uuid_match = re.search(r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})', raw_image_id)
                if uuid_match:
                    image_id = uuid_match.group(1)
                    logger.info(f"从URL中提取UUID: {image_id}")

        # 如果是新格式的image_id（user_timestamp_random），直接使用
        elif '_' in raw_image_id and len(raw_image_id.split('_')) >= 3:
            image_id = raw_image_id
            logger.info(f"使用新格式image_id: {image_id}")

        # 如果是旧格式的UUID，也直接使用
        else:
            image_id = raw_image_id
            logger.info(f"使用原始image_id: {image_id}")

        logger.info(f"最终image_id: {image_id}")

        # 查找包含此图片的消息
        message = None

        # 首先尝试通过image_id字段查找（如果字段存在）
        try:
            if hasattr(models.Message, 'image_id'):
                message = db.query(models.Message).filter(models.Message.image_id == image_id).first()
                if message:
                    logger.info(f"通过image_id找到消息: {message.id}")
        except Exception as e:
            logger.warning(f"image_id字段查询失败: {e}")

        # 如果通过image_id找不到，尝试通过content查找
        if not message:
            message = db.query(models.Message).filter(models.Message.content.like(f'%[图片] {image_id}%')).first()
            if message:
                logger.info(f"通过content找到消息: {message.id}")

        # 如果还是找不到，尝试查找原始image_id
        if not message and raw_image_id != image_id:
            logger.info(f"尝试通过原始image_id查找")
            if hasattr(models.Message, 'image_id'):
                message = db.query(models.Message).filter(models.Message.image_id == raw_image_id).first()
            if not message:
                message = db.query(models.Message).filter(models.Message.content.like(f'%[图片] {raw_image_id}%')).first()
            if message:
                logger.info(f"通过原始image_id找到消息: {message.id}")
                image_id = raw_image_id  # 使用原始ID

        if not message:
            logger.error(f"未找到包含image_id {image_id}的消息")
            raise HTTPException(status_code=404, detail="图片不存在")

        # 获取聊天参与者
        participants = []

        # 如果是任务聊天，从任务中获取参与者
        if hasattr(message, 'conversation_type') and message.conversation_type == 'task' and message.task_id:
            from app import crud
            task = crud.get_task(db, message.task_id)
            if not task:
                raise HTTPException(status_code=404, detail="任务不存在")

            # 任务参与者：发布者和接受者
            if task.poster_id:
                participants.append(str(task.poster_id))
            if task.taker_id:
                participants.append(str(task.taker_id))

            # 多人任务：加入 TaskParticipant 及 expert_creator_id，确保所有参与者都能加载私密图片
            if getattr(task, "is_multi_participant", False):
                if getattr(task, "expert_creator_id", None):
                    expert_id = str(task.expert_creator_id)
                    if expert_id not in participants:
                        participants.append(expert_id)
                for p in db.query(models.TaskParticipant).filter(
                    models.TaskParticipant.task_id == message.task_id,
                    models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                ).all():
                    if p.user_id:
                        user_id_str = str(p.user_id)
                        if user_id_str not in participants:
                            participants.append(user_id_str)

            # 检查用户是否有权限访问此图片（必须是任务的参与者）
            current_user_id_str = str(current_user.id)
            if current_user_id_str not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")
        else:
            # 普通聊天：使用发送者和接收者
            if message.sender_id:
                participants.append(str(message.sender_id))
            if message.receiver_id:
                participants.append(str(message.receiver_id))

            # 检查用户是否有权限访问此图片
            current_user_id_str = str(current_user.id)
            if current_user_id_str not in participants:
                raise HTTPException(status_code=403, detail="无权访问此图片")

        # 如果没有参与者（不应该发生），至少包含当前用户
        if not participants:
            participants = [str(current_user.id)]

        # 生成访问URL
        image_url = private_image_system.generate_image_url(
            image_id,
            str(current_user.id),
            participants
        )

        return JSONResponse(content={
            "success": True,
            "image_url": image_url,
            "image_id": image_id
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"生成图片URL失败: {e}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"生成URL失败: {str(e)}")


@router.post("/upload/file")
@rate_limit("upload_file")
async def upload_file(
    file: UploadFile = File(...),
    task_id: Optional[int] = Query(None, description="任务ID（任务聊天时提供）"),
    chat_id: Optional[str] = Query(None, description="聊天ID（客服聊天时提供）"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    上传文件
    支持按任务ID或聊天ID分类存储
    - task_id: 任务聊天时提供，文件会存储在 tasks/{task_id}/ 文件夹
    - chat_id: 客服聊天时提供，文件会存储在 chats/{chat_id}/ 文件夹
    """
    try:
        # 使用流式读取文件内容，避免大文件一次性读入内存
        from app.file_stream_utils import read_file_with_size_check

        # 文件最大大小：10MB（支持文档等大文件）
        MAX_FILE_SIZE_UPLOAD = 10 * 1024 * 1024

        # 流式读取文件内容
        content, file_size = await read_file_with_size_check(file, MAX_FILE_SIZE_UPLOAD)

        # 使用新的私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(content, file.filename, current_user.id, db, task_id=task_id, chat_id=chat_id, content_type=file.content_type)

        # 生成签名URL（使用新的文件ID）
        from app.signed_url import signed_url_manager
        # 构建文件路径（用于签名URL，保持向后兼容）
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=current_user.id,
            expiry_minutes=15,  # 15分钟过期
            one_time=False  # 可以多次使用
        )

        return JSONResponse(
            content={
                "success": True,
                "url": file_url,
                "file_id": result["file_id"],
                "filename": result["filename"],
                "size": result["size"],
                "original_name": result["original_filename"],
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"文件上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.get("/private-file")
async def get_private_file(
    file: str = Query(..., description="文件路径"),
    user: str = Query(..., description="用户ID"),
    exp: int = Query(..., description="过期时间戳"),
    sig: str = Query(..., description="签名"),
    ts: int = Query(None, description="时间戳"),
    ip: str = Query(None, description="IP地址限制"),
    ot: str = Query("0", description="是否一次性使用")
):
    """
    获取私有文件 - 需要签名URL
    """
    try:
        from app.signed_url import signed_url_manager
        from fastapi import Request
        from fastapi.responses import FileResponse

        # 解析参数
        params = {
            "file": file,
            "user": user,
            "exp": str(exp),
            "sig": sig,
            "ip": ip,
            "ot": ot
        }

        # 如果有时间戳参数，添加到参数中
        if ts is not None:
            params["ts"] = str(ts)

        parsed_params = signed_url_manager.parse_signed_url_params(params)
        if not parsed_params:
            raise HTTPException(status_code=400, detail="无效的签名URL参数")

        # 验证签名
        request_ip = None  # 可以从Request对象获取
        if not signed_url_manager.verify_signed_url(
            file_path=parsed_params["file_path"],
            user_id=parsed_params["user_id"],
            expiry=parsed_params["expiry"],
            signature=parsed_params["signature"],
            timestamp=parsed_params.get("timestamp", exp - 900),  # 如果没有时间戳，使用过期时间减去15分钟
            ip_address=parsed_params.get("ip_address"),
            one_time=parsed_params["one_time"]
        ):
            raise HTTPException(status_code=403, detail="签名验证失败")

        # 构建文件路径
        # 支持新旧两种路径格式：
        # 旧格式：files/{filename} (向后兼容)
        # 新格式：files/{filename} (但实际文件可能在新结构 private_files/tasks/{task_id}/ 或 private_files/chats/{chat_id}/)
        file_path_str = parsed_params["file_path"]

        # 从文件路径中提取文件名（去掉 "files/" 前缀）
        if file_path_str.startswith("files/"):
            filename = file_path_str[6:]  # 去掉 "files/" 前缀
        else:
            filename = file_path_str

        # 提取文件ID（去掉扩展名）
        file_id = Path(filename).stem

        # 尝试在新文件系统中查找（通过数据库查询优化）
        file_path = None
        try:
            # 使用文件系统查找文件（会从数据库查询优化路径）
            from app.file_system import private_file_system
            db_gen = get_db()
            db = next(db_gen)
            try:
                file_response = private_file_system.get_file(file_id, parsed_params["user_id"], db)
                # 如果找到了，直接返回
                return file_response
            except HTTPException as e:
                if e.status_code == 404:
                    # 文件不在新系统中，尝试旧路径
                    pass
                else:
                    raise
            finally:
                try:
                    db_gen.close()
                except Exception:
                    db.close()
        except Exception as e:
            logger.debug(f"从新文件系统查找文件失败，尝试旧路径: {e}")

        # 回退到旧路径（向后兼容）
        if RAILWAY_ENVIRONMENT and not USE_CLOUD_STORAGE:
            base_private_dir = Path("/data/uploads/private")
        else:
            base_private_dir = Path("uploads/private")

        file_path = _resolve_legacy_private_file_path(base_private_dir, file_path_str)

        if not file_path.exists():
            raise HTTPException(status_code=404, detail="文件不存在")

        # 检查是否是文件而不是目录
        if not file_path.is_file():
            raise HTTPException(status_code=404, detail="文件不存在")

        # 返回文件
        return FileResponse(
            path=file_path,
            filename=file_path.name,
            media_type='application/octet-stream'
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取私有文件失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取文件失败: {str(e)}")

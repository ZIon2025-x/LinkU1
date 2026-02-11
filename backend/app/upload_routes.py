"""
优化后的图片上传路由
使用统一的 ImageUploadService 替代分散的上传逻辑
"""

import logging
from typing import Optional
from fastapi import APIRouter, File, UploadFile, Query, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.rate_limiting import rate_limit
from app.services import (
    ImageUploadService,
    ImageCategory,
    UploadConfig,
    get_image_upload_service,
    get_storage_metrics_collector,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2", tags=["Upload V2"])


def get_current_user_id(request: Request) -> str:
    """获取当前用户ID（支持管理员和普通用户）"""
    # 首先尝试管理员认证
    from app.admin_auth import validate_admin_session
    admin_session = validate_admin_session(request)
    if admin_session:
        return admin_session.admin_id
    
    # 尝试普通用户认证
    from app.secure_auth import validate_session
    user_session = validate_session(request)
    if user_session:
        return user_session.user_id
    
    raise HTTPException(status_code=401, detail="认证失败，请先登录")


# 类别名称到 ImageCategory 的映射
CATEGORY_MAP = {
    "public": ImageCategory.TASK,
    "task": ImageCategory.TASK,
    "banner": ImageCategory.BANNER,
    "expert_avatar": ImageCategory.EXPERT_AVATAR,
    "service_image": ImageCategory.SERVICE_IMAGE,
    "leaderboard_item": ImageCategory.LEADERBOARD_ITEM,
    "leaderboard_cover": ImageCategory.LEADERBOARD_COVER,
    "flea_market": ImageCategory.FLEA_MARKET,
    "forum_post": ImageCategory.FORUM_POST,
}


@router.post("/upload/image")
@rate_limit("upload_file")
async def upload_image_v2(
    request: Request,
    image: UploadFile = File(...),
    category: str = Query("task", description="图片类型"),
    resource_id: Optional[str] = Query(None, description="资源ID"),
    db: Session = Depends(get_db),
):
    """
    上传公开图片（优化版 V2）
    
    相比原接口的改进:
    - 自动压缩图片，减少存储空间
    - 自动旋转（根据 EXIF）
    - 移除隐私元数据
    - 限制最大尺寸
    - 可选生成缩略图
    
    参数:
    - category: 图片类型
      - task / public: 任务图片
      - banner: Banner 图片
      - expert_avatar: 任务达人头像
      - service_image: 服务图片
      - leaderboard_item: 竞品图片
      - leaderboard_cover: 榜单封面
      - flea_market: 跳蚤市场商品图片
    - resource_id: 资源ID，用于创建子文件夹
      - 如果未提供，将使用临时目录 temp_{user_id}
    """
    try:
        # 获取当前用户ID
        user_id = get_current_user_id(request)
        
        # 验证 category
        if category not in CATEGORY_MAP:
            raise HTTPException(
                status_code=400,
                detail=f"无效的图片类型。允许的类型: {', '.join(CATEGORY_MAP.keys())}"
            )
        
        image_category = CATEGORY_MAP[category]
        
        # 确定是否使用临时目录
        is_temp = False
        if not resource_id:
            is_temp = True
        elif resource_id.startswith("temp_"):
            is_temp = True
            resource_id = None  # 使用 user_id 构建临时目录
        
        # 对于头像和服务图片，使用用户ID作为资源ID
        if category in ("expert_avatar", "service_image") and not resource_id:
            resource_id = user_id
            is_temp = False
        
        # 读取文件内容
        content = await image.read()
        
        # 使用图片上传服务
        service = get_image_upload_service()
        result = service.upload(
            content=content,
            category=image_category,
            resource_id=resource_id,
            user_id=user_id,
            filename=image.filename,
            is_temp=is_temp
        )
        
        if not result.success:
            raise HTTPException(status_code=400, detail=result.error)
        
        logger.info(
            f"用户 {user_id} 上传图片 [{category}]: "
            f"size={result.original_size}->{result.size}, "
            f"resource_id={resource_id or 'temp'}"
        )
        
        response_data = {
            "success": True,
            "url": result.url,
            "filename": result.filename,
            "size": result.size,
            "original_size": result.original_size,
            "category": category,
            "resource_id": resource_id,
            "message": "图片上传成功"
        }
        
        # 添加尺寸信息
        if result.width and result.height:
            response_data["width"] = result.width
            response_data["height"] = result.height
        
        # 添加缩略图 URL
        if result.thumbnails:
            response_data["thumbnails"] = result.thumbnails
        
        return JSONResponse(content=response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.post("/upload/image/batch")
@rate_limit("upload_file")
async def upload_images_batch(
    request: Request,
    images: list[UploadFile] = File(...),
    category: str = Query("task", description="图片类型"),
    resource_id: Optional[str] = Query(None, description="资源ID"),
    db: Session = Depends(get_db),
):
    """
    批量上传图片（优化版 V2）
    
    一次性上传多张图片，返回所有图片的 URL
    """
    try:
        user_id = get_current_user_id(request)
        
        if category not in CATEGORY_MAP:
            raise HTTPException(
                status_code=400,
                detail=f"无效的图片类型。允许的类型: {', '.join(CATEGORY_MAP.keys())}"
            )
        
        image_category = CATEGORY_MAP[category]
        
        # 确定是否使用临时目录
        is_temp = not resource_id or resource_id.startswith("temp_")
        if is_temp:
            resource_id = None
        
        # 对于头像和服务图片，使用用户ID
        if category in ("expert_avatar", "service_image") and not resource_id:
            resource_id = user_id
            is_temp = False
        
        # 限制批量上传数量
        max_images = 10
        if len(images) > max_images:
            raise HTTPException(
                status_code=400,
                detail=f"一次最多上传 {max_images} 张图片"
            )
        
        service = get_image_upload_service()
        results = []
        
        for image in images:
            content = await image.read()
            
            result = service.upload(
                content=content,
                category=image_category,
                resource_id=resource_id,
                user_id=user_id,
                filename=image.filename,
                is_temp=is_temp
            )
            
            if result.success:
                results.append({
                    "success": True,
                    "url": result.url,
                    "filename": result.filename,
                    "size": result.size
                })
            else:
                results.append({
                    "success": False,
                    "error": result.error,
                    "filename": image.filename
                })
        
        success_count = sum(1 for r in results if r["success"])
        
        return JSONResponse(content={
            "success": success_count > 0,
            "total": len(images),
            "success_count": success_count,
            "failed_count": len(images) - success_count,
            "results": results,
            "message": f"成功上传 {success_count}/{len(images)} 张图片"
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量图片上传失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@router.delete("/upload/image")
async def delete_image(
    request: Request,
    url: str = Query(..., description="图片 URL"),
    category: str = Query(..., description="图片类型"),
    resource_id: str = Query(..., description="资源ID"),
    db: Session = Depends(get_db),
):
    """
    删除单个图片（需验证资源归属权）
    """
    try:
        user_id = get_current_user_id(request)
        
        if category not in CATEGORY_MAP:
            raise HTTPException(status_code=400, detail="无效的图片类型")
        
        # 安全校验：验证当前用户是否有权删除该资源的图片
        if category in ("expert_avatar", "service_image"):
            # 头像/服务图片：resource_id 必须是当前用户自己
            if resource_id != user_id:
                raise HTTPException(status_code=403, detail="无权删除他人的图片")
        elif category == "task":
            # 任务图片：验证当前用户是任务发布者
            from app import models
            task = db.query(models.Task).filter(models.Task.id == int(resource_id)).first() if resource_id.isdigit() else None
            if not task or task.poster_id != user_id:
                raise HTTPException(status_code=403, detail="无权删除该任务的图片")
        elif category == "flea_market":
            # 跳蚤市场图片：验证当前用户是商品卖家
            from app import models
            from app.flea_market_routes import parse_flea_market_id
            try:
                db_id = parse_flea_market_id(resource_id)
                item = db.query(models.FleaMarketItem).filter(models.FleaMarketItem.id == db_id).first()
                if not item or item.seller_id != user_id:
                    raise HTTPException(status_code=403, detail="无权删除该商品的图片")
            except (ValueError, HTTPException):
                raise HTTPException(status_code=403, detail="无权删除该商品的图片")
        # banner, leaderboard 等类型通常是管理员操作，由 get_current_user_id 已经验证了管理员身份
        
        image_category = CATEGORY_MAP[category]
        service = get_image_upload_service()
        
        success = service.delete(
            category=image_category,
            resource_id=resource_id,
            image_urls=[url]
        )
        
        if success:
            logger.info(f"用户 {user_id} 删除图片: {url}")
            return JSONResponse(content={
                "success": True,
                "message": "图片删除成功"
            })
        else:
            return JSONResponse(content={
                "success": False,
                "message": "图片删除失败"
            }, status_code=400)
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片删除失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"删除失败: {str(e)}")


@router.delete("/upload/temp")
async def delete_temp_images(
    request: Request,
    category: str = Query(..., description="图片类型"),
):
    """
    删除用户的临时图片目录
    
    用于用户取消操作时清理临时上传的图片
    """
    try:
        user_id = get_current_user_id(request)
        
        if category not in CATEGORY_MAP:
            raise HTTPException(status_code=400, detail="无效的图片类型")
        
        image_category = CATEGORY_MAP[category]
        service = get_image_upload_service()
        
        success = service.delete_temp(
            category=image_category,
            user_id=user_id
        )
        
        if success:
            logger.info(f"用户 {user_id} 删除临时图片目录: {category}")
        
        return JSONResponse(content={
            "success": True,
            "message": "临时图片已清理"
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"临时图片清理失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


# ============ 管理员存储监控 API ============

def require_admin(request: Request) -> str:
    """要求管理员权限"""
    from app.admin_auth import validate_admin_session
    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(status_code=403, detail="需要管理员权限")
    return admin_session.admin_id


@router.get("/storage/metrics")
async def get_storage_metrics(request: Request):
    """
    获取存储监控指标（管理员）
    
    返回磁盘使用情况、上传统计等信息
    """
    try:
        admin_id = require_admin(request)
        
        collector = get_storage_metrics_collector()
        report = collector.get_full_report()
        
        logger.info(f"管理员 {admin_id} 查看存储监控指标")
        
        return JSONResponse(content={
            "success": True,
            "data": report
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取存储指标失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")


@router.get("/storage/disk")
async def get_disk_usage(request: Request):
    """
    获取磁盘使用情况（管理员）
    """
    try:
        admin_id = require_admin(request)
        
        collector = get_storage_metrics_collector()
        disk_info = collector.get_disk_usage()
        
        return JSONResponse(content={
            "success": True,
            "data": disk_info
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取磁盘使用情况失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")


@router.get("/storage/categories")
async def get_category_stats(request: Request):
    """
    获取各分类存储统计（管理员）
    """
    try:
        admin_id = require_admin(request)
        
        collector = get_storage_metrics_collector()
        stats = collector.get_category_stats(force_refresh=True)
        
        # 转换为可序列化的格式
        result = {}
        for name, cat_stats in stats.items():
            result[name] = {
                "size_bytes": cat_stats.size,
                "size_mb": round(cat_stats.size / (1024 * 1024), 2),
                "file_count": cat_stats.file_count,
                "resource_count": cat_stats.resource_count,
                "temp_size_bytes": cat_stats.temp_size,
                "temp_size_mb": round(cat_stats.temp_size / (1024 * 1024), 2),
                "temp_file_count": cat_stats.temp_file_count,
            }
        
        return JSONResponse(content={
            "success": True,
            "data": result
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取分类统计失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")


@router.get("/storage/temp-cleanup-preview")
async def preview_temp_cleanup(
    request: Request,
    max_age_hours: int = Query(24, description="文件最大保留时间（小时）")
):
    """
    预览待清理的临时文件（管理员）
    
    不执行实际清理，仅列出符合清理条件的文件
    """
    try:
        admin_id = require_admin(request)
        
        collector = get_storage_metrics_collector()
        candidates = collector.get_temp_cleanup_candidates(max_age_hours)
        
        total_size = sum(c["size"] for c in candidates)
        
        return JSONResponse(content={
            "success": True,
            "data": {
                "file_count": len(candidates),
                "total_size_bytes": total_size,
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "max_age_hours": max_age_hours,
                "files": candidates[:100]  # 最多返回100个文件
            }
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"预览临时文件清理失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")

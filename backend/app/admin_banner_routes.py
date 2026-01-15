"""
Banner 广告系统 - 管理员API路由
"""
import logging
import re
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, status, File, UploadFile
from sqlalchemy.orm import Session
from pathlib import Path

from app import schemas, models
from app.deps import get_db
from app.role_deps import get_current_admin_secure_sync
from app.cache import invalidate_cache

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["管理员-Banner广告管理"])


def clear_banner_cache():
    """清除 Banner 相关缓存"""
    try:
        invalidate_cache("banners:*")
        logger.debug("已清除 Banner 缓存")
    except Exception as e:
        logger.warning(f"清除 Banner 缓存失败: {e}")


def validate_url(url: str, field_name: str = "URL") -> bool:
    """验证 URL 格式"""
    if not url:
        return False
    url_pattern = re.compile(
        r'^https?://'  # http:// or https://
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # domain...
        r'localhost|'  # localhost...
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # ...or ip
        r'(?::\d+)?'  # optional port
        r'(?:/?|[/?]\S+)$', re.IGNORECASE)
    return bool(url_pattern.match(url))


def validate_image_url(url: str) -> bool:
    """验证图片 URL 格式"""
    if not validate_url(url):
        return False
    # 检查是否是常见的图片格式
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg']
    url_lower = url.lower()
    return any(url_lower.endswith(ext) or ext in url_lower for ext in image_extensions) or 'image' in url_lower


# ==================== Banner 管理 API ====================

@router.post("/banners", response_model=schemas.BannerOut)
def create_banner(
    banner_data: schemas.BannerCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """创建 Banner（管理员）"""
    import os
    import shutil
    from urllib.parse import urlparse
    from app.config import Config
    
    # 验证 link_type
    if banner_data.link_type not in ["internal", "external"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="link_type 必须是 'internal' 或 'external'"
        )
    
    # 验证图片 URL
    if not validate_image_url(banner_data.image_url):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="image_url 格式无效，必须是有效的图片 URL"
        )
    
    # 验证跳转链接 URL（如果提供）
    if banner_data.link_url and not validate_url(banner_data.link_url):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="link_url 格式无效，必须是有效的 URL"
        )
    
    # 创建 Banner
    banner = models.Banner(
        image_url=banner_data.image_url,
        title=banner_data.title,
        subtitle=banner_data.subtitle,
        link_url=banner_data.link_url,
        link_type=banner_data.link_type,
        order=banner_data.order,
        is_active=banner_data.is_active
    )
    
    db.add(banner)
    db.commit()
    db.refresh(banner)
    
    # 如果图片在临时目录中，移动到正式目录（使用图片上传服务）
    image_url = banner_data.image_url
    if "/banner/temp_" in image_url:
        try:
            from app.services import ImageCategory, get_image_upload_service
            
            service = get_image_upload_service()
            
            # 使用服务移动临时图片
            new_urls = service.move_from_temp(
                category=ImageCategory.BANNER,
                user_id=current_admin.id,
                resource_id=str(banner.id),
                image_urls=[image_url]
            )
            
            # 更新 Banner 的 image_url
            if new_urls and new_urls[0] != image_url:
                banner.image_url = new_urls[0]
                db.commit()
                db.refresh(banner)
                logger.info(f"移动 Banner 图片到正式目录: {new_urls[0]}")
            
            # 尝试删除临时目录
            service.delete_temp(category=ImageCategory.BANNER, user_id=current_admin.id)
        except Exception as e:
            logger.warning(f"移动 Banner 图片从临时目录失败: {e}")
    
    # 清除缓存
    clear_banner_cache()
    
    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 创建了 Banner ID: {banner.id}")
    
    return banner


@router.put("/banners/{banner_id}", response_model=schemas.BannerOut)
def update_banner(
    banner_id: int,
    banner_data: schemas.BannerUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """更新 Banner（管理员）"""
    banner = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if not banner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Banner 不存在"
        )
    
    # 更新字段
    update_data = banner_data.dict(exclude_unset=True)
    
    # 验证 link_type
    if "link_type" in update_data and update_data["link_type"] not in ["internal", "external"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="link_type 必须是 'internal' 或 'external'"
        )
    
    # 验证图片 URL（如果提供）
    if "image_url" in update_data and not validate_image_url(update_data["image_url"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="image_url 格式无效，必须是有效的图片 URL"
        )
    
    # 验证跳转链接 URL（如果提供）
    if "link_url" in update_data and update_data["link_url"] and not validate_url(update_data["link_url"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="link_url 格式无效，必须是有效的 URL"
        )
    
    # 如果更换了图片，删除旧图片（使用图片上传服务）
    old_image_url = banner.image_url
    if "image_url" in update_data and update_data["image_url"] != old_image_url and old_image_url:
        try:
            from app.services import ImageCategory, get_image_upload_service
            
            service = get_image_upload_service()
            service.delete(
                category=ImageCategory.BANNER,
                resource_id=str(banner_id),
                image_urls=[old_image_url]
            )
            logger.info(f"删除 Banner {banner_id} 的旧图片")
        except Exception as e:
            logger.warning(f"删除 Banner {banner_id} 的旧图片失败: {e}")
    
    for field, value in update_data.items():
        setattr(banner, field, value)
    
    db.commit()
    db.refresh(banner)
    
    # 清除缓存
    clear_banner_cache()
    
    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 更新了 Banner ID: {banner_id}")
    
    return banner


@router.delete("/banners/{banner_id}")
def delete_banner(
    banner_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """删除 Banner（管理员）"""
    banner = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if not banner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Banner 不存在"
        )

    # 删除 Banner 图片目录（使用图片上传服务）
    try:
        from app.services import ImageCategory, get_image_upload_service
        
        service = get_image_upload_service()
        # 删除整个 Banner 图片目录
        service.delete(
            category=ImageCategory.BANNER,
            resource_id=str(banner_id)
        )
        logger.info(f"删除 Banner {banner_id} 的图片目录")
    except Exception as e:
        logger.warning(f"删除 Banner {banner_id} 的图片失败: {e}")

    db.delete(banner)
    db.commit()

    # 清除缓存
    clear_banner_cache()

    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 删除了 Banner ID: {banner_id}")

    return {
        "success": True,
        "message": "Banner 删除成功"
    }


@router.get("/banners", response_model=schemas.BannerListResponse)
def get_banners_list(
    page: int = Query(1, ge=1, description="页码"),
    limit: int = Query(20, ge=1, le=100, description="每页数量"),
    is_active: Optional[bool] = Query(None, description="是否启用筛选"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取 Banner 列表（管理员）"""
    from sqlalchemy import func
    
    # 构建查询（使用索引优化）
    query = db.query(models.Banner)
    
    # 筛选
    if is_active is not None:
        query = query.filter(models.Banner.is_active == is_active)
    
    # 使用子查询优化总数计算
    total = query.count()
    
    # 分页和排序（使用索引：idx_banners_active_order）
    banners = query.order_by(
        models.Banner.order.asc(),
        models.Banner.created_at.desc()
    ).offset((page - 1) * limit).limit(limit).all()
    
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "data": banners
    }


@router.get("/banners/{banner_id}", response_model=schemas.BannerOut)
def get_banner_detail(
    banner_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """获取 Banner 详情（管理员）"""
    banner = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if not banner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Banner 不存在"
        )
    
    return banner


@router.patch("/banners/{banner_id}/toggle-status")
def toggle_banner_status(
    banner_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """切换 Banner 启用状态（管理员）"""
    banner = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if not banner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Banner 不存在"
        )
    
    banner.is_active = not banner.is_active
    db.commit()
    db.refresh(banner)
    
    # 清除缓存
    clear_banner_cache()
    
    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 切换了 Banner ID: {banner_id} 的状态为: {banner.is_active}")
    
    return {
        "success": True,
        "message": f"Banner 状态已切换为 {'启用' if banner.is_active else '禁用'}",
        "is_active": banner.is_active
    }


# ==================== 批量操作 API ====================

@router.post("/banners/batch-delete")
def batch_delete_banners(
    banner_ids: List[int],
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """批量删除 Banner（管理员）"""
    if not banner_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请提供要删除的 Banner ID 列表"
        )
    
    banners = db.query(models.Banner).filter(models.Banner.id.in_(banner_ids)).all()
    
    if len(banners) != len(banner_ids):
        found_ids = [b.id for b in banners]
        missing_ids = [id for id in banner_ids if id not in found_ids]
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"以下 Banner 不存在: {missing_ids}"
        )
    
    deleted_count = len(banners)
    for banner in banners:
        db.delete(banner)
    
    db.commit()
    
    # 清除缓存
    clear_banner_cache()
    
    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 批量删除了 {deleted_count} 个 Banner: {banner_ids}")
    
    return {
        "success": True,
        "message": f"成功删除 {deleted_count} 个 Banner",
        "deleted_count": deleted_count
    }


@router.put("/banners/batch-update-order")
def batch_update_banner_order(
    order_updates: List[schemas.BannerOrderUpdate],
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """批量更新 Banner 排序（管理员）"""
    if not order_updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请提供要更新的排序信息"
        )
    
    updated_count = 0
    for order_update in order_updates:
        banner = db.query(models.Banner).filter(models.Banner.id == order_update.id).first()
        if banner:
            banner.order = order_update.order
            updated_count += 1
        else:
            logger.warning(f"Banner ID {order_update.id} 不存在，跳过更新")
    
    db.commit()
    
    # 清除缓存
    clear_banner_cache()
    
    logger.info(f"管理员 {current_admin.id} ({current_admin.name}) 批量更新了 {updated_count} 个 Banner 的排序")
    
    return {
        "success": True,
        "message": f"成功更新 {updated_count} 个 Banner 的排序",
        "updated_count": updated_count
    }


# ==================== 图片上传 API ====================

@router.post("/banners/upload-image")
async def upload_banner_image(
    image: UploadFile = File(...),
    banner_id: Optional[int] = Query(None, description="Banner ID（编辑时提供，新建时可不提供）"),
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_db)
):
    """
    上传 Banner 图片（管理员）
    
    优化功能：
    - 自动压缩图片
    - 自动旋转（根据 EXIF）
    - 移除隐私元数据
    """
    try:
        # 导入图片上传服务
        from app.services import ImageCategory, get_image_upload_service
        
        # 读取文件内容
        content = await image.read()
        
        # 使用图片上传服务
        service = get_image_upload_service()
        
        # 确定是否使用临时目录
        is_temp = banner_id is None
        resource_id = str(banner_id) if banner_id else None
        
        result = service.upload(
            content=content,
            category=ImageCategory.BANNER,
            resource_id=resource_id,
            user_id=current_admin.id,
            filename=image.filename,
            is_temp=is_temp
        )
        
        if not result.success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result.error
            )
        
        logger.info(
            f"管理员 {current_admin.id} ({current_admin.name}) 上传了 Banner 图片: "
            f"size={result.original_size}->{result.size}, url={result.url}"
        )
        
        response = {
            "success": True,
            "url": result.url,
            "filename": result.filename,
            "size": result.size,
            "message": "图片上传成功"
        }
        
        # 添加压缩信息
        if result.original_size != result.size:
            response["original_size"] = result.original_size
            response["compression_saved"] = result.original_size - result.size
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Banner 图片上传失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"图片上传失败: {str(e)}"
        )


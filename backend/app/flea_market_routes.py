"""
跳蚤市场API路由
实现跳蚤市场相关的所有接口
"""

import json
import logging
import os
import uuid
import shutil
from decimal import Decimal
from typing import List, Optional
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlparse

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    Response,
    status,
    Body,
    File,
    UploadFile,
)
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_, or_, func, text
from sqlalchemy.exc import IntegrityError

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_optional

# 管理员认证函数（从forum_routes复制，因为flea_market也需要）
async def get_current_admin_async(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.AdminUser:
    """获取当前管理员（异步版本）"""
    from app.admin_auth import validate_admin_session
    
    admin_session = validate_admin_session(request)
    if not admin_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员认证失败，请重新登录"
        )
    
    # 获取管理员信息（异步）
    admin_result = await db.execute(
        select(models.AdminUser).where(models.AdminUser.id == admin_session.admin_id)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在"
        )
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理员账户已被禁用"
        )
    
    return admin
from app.id_generator import format_flea_market_id, parse_flea_market_id
from app.utils.time_utils import get_utc_time, format_iso_utc, file_timestamp_to_utc
from app.config import Config
from app.flea_market_constants import FLEA_MARKET_CATEGORIES, AUTO_DELETE_DAYS
from app.flea_market_extensions import (
    contains_sensitive_words,
    filter_sensitive_words,
    send_purchase_request_notification,
    send_purchase_accepted_notification,
    send_direct_purchase_notification,
    get_cache_key_for_items,
    get_cache_key_for_item_detail,
    invalidate_item_cache
)

logger = logging.getLogger(__name__)

# 创建跳蚤市场路由器
flea_market_router = APIRouter(prefix="/api/flea-market", tags=["跳蚤市场"])

# 图片上传配置
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

# 检测部署环境
RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
if RAILWAY_ENVIRONMENT:
    FLEA_MARKET_IMAGE_DIR = Path("/data/uploads/flea_market")
else:
    FLEA_MARKET_IMAGE_DIR = Path("uploads/flea_market")

# 确保目录存在
FLEA_MARKET_IMAGE_DIR.mkdir(parents=True, exist_ok=True)


# ==================== 图片清理辅助函数 ====================

def delete_flea_market_item_images(item_id: int, image_urls: Optional[List[str]] = None):
    """
    删除跳蚤市场商品的图片文件
    
    Args:
        item_id: 商品ID
        image_urls: 可选的图片URL列表，如果提供则只删除这些URL对应的文件
                   如果不提供，则删除整个商品图片目录
    """
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads")
        else:
            base_dir = Path("uploads")
        
        deleted_count = 0
        
        if image_urls:
            # 如果提供了图片URL列表，只删除指定的图片文件（不删除整个目录）
            for image_url in image_urls:
                try:
                    # 解析URL，提取路径
                    parsed = urlparse(image_url)
                    path = parsed.path
                    
                    # 如果URL包含 /uploads/flea_market/，尝试删除对应文件
                    if "/uploads/flea_market/" in path:
                        # 提取相对路径
                        if path.startswith("/uploads/"):
                            relative_path = path[len("/uploads/"):]
                            file_path = base_dir / relative_path
                            if file_path.exists():
                                if file_path.is_file():
                                    file_path.unlink()
                                    deleted_count += 1
                                    logger.info(f"删除图片文件: {file_path}")
                                elif file_path.is_dir():
                                    shutil.rmtree(file_path)
                                    deleted_count += 1
                                    logger.info(f"删除图片目录: {file_path}")
                except Exception as e:
                    logger.warning(f"删除图片URL {image_url} 对应的文件失败: {e}")
        else:
            # 如果没有提供图片URL列表，删除整个商品图片目录
            flea_market_dir = base_dir / "flea_market" / str(item_id)
            if flea_market_dir.exists():
                shutil.rmtree(flea_market_dir)
                logger.info(f"删除商品 {item_id} 的图片目录: {flea_market_dir}")
                deleted_count += 1
        
        if deleted_count > 0:
            logger.info(f"商品 {item_id} 已删除 {deleted_count} 个图片文件/目录")
        
    except Exception as e:
        logger.error(f"删除商品 {item_id} 图片文件失败: {e}")


def delete_flea_market_temp_images(user_id: Optional[str] = None):
    """
    删除跳蚤市场临时图片
    
    Args:
        user_id: 可选的用户ID，如果提供则只删除该用户的临时图片，否则删除所有超过24小时的临时图片
    """
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads")
        else:
            base_dir = Path("uploads")
        
        temp_base_dir = base_dir / "flea_market"
        
        # 如果临时文件夹不存在，直接返回
        if not temp_base_dir.exists():
            return 0
        
        deleted_count = 0
        
        if user_id:
            # 删除指定用户的临时目录
            temp_dir = temp_base_dir / f"temp_{user_id}"
            if temp_dir.exists():
                try:
                    shutil.rmtree(temp_dir)
                    deleted_count += 1
                    logger.info(f"删除用户 {user_id} 的跳蚤市场临时图片目录: {temp_dir}")
                except Exception as e:
                    logger.warning(f"删除临时目录失败 {temp_dir}: {e}")
        else:
            # 删除所有超过24小时的临时图片
            cutoff_time = get_utc_time() - timedelta(hours=24)
            
            # 遍历所有临时文件夹（temp_*）
            for temp_dir in temp_base_dir.iterdir():
                if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                    try:
                        # 检查文件夹中的文件
                        files_deleted = False
                        for file_path in temp_dir.iterdir():
                            if file_path.is_file():
                                # 获取文件的修改时间（使用统一时间工具函数）
                                file_mtime = file_timestamp_to_utc(file_path.stat().st_mtime)
                                
                                # 如果文件超过24小时未修改，删除它
                                if file_mtime < cutoff_time:
                                    try:
                                        file_path.unlink()
                                        deleted_count += 1
                                        files_deleted = True
                                        logger.info(f"删除未使用的跳蚤市场临时图片: {file_path}")
                                    except Exception as e:
                                        logger.warning(f"删除临时图片失败 {file_path}: {e}")
                        
                        # 如果文件夹为空或所有文件都已删除，尝试删除它
                        try:
                            if not any(temp_dir.iterdir()):
                                temp_dir.rmdir()
                                logger.info(f"删除空的跳蚤市场临时文件夹: {temp_dir}")
                        except Exception as e:
                            logger.debug(f"删除临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                    except Exception as e:
                        logger.warning(f"处理临时目录失败 {temp_dir}: {e}")
        
        if deleted_count > 0:
            logger.info(f"清理了 {deleted_count} 个跳蚤市场临时图片文件/目录")
        
        return deleted_count
    except Exception as e:
        logger.error(f"清理跳蚤市场临时图片失败: {e}")
        return 0


# 认证依赖
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.User:
    """CSRF保护的安全用户认证（异步版本）"""
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


# ==================== 分类列表API ====================

@flea_market_router.get("/categories", response_model=dict)
async def get_flea_market_categories():
    """获取商品分类列表"""
    return {
        "success": True,
        "data": {
            "categories": FLEA_MARKET_CATEGORIES
        }
    }


# ==================== 商品列表API ====================

@flea_market_router.get("/items", response_model=schemas.FleaMarketItemListResponse)
async def get_flea_market_items(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100, alias="page_size"),  # 支持 page_size 参数名
    category: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    status_filter: Optional[str] = Query("active", alias="status"),
    seller_id: Optional[str] = Query(None, description="卖家ID，用于筛选特定卖家的商品"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品列表（分页、搜索、筛选）- 带Redis缓存"""
    try:
        # 尝试从缓存获取（如果有seller_id筛选，不使用缓存）
        if not seller_id:
            from app.redis_cache import redis_cache
            cache_key = get_cache_key_for_items(page, pageSize, category, keyword, status_filter or "active")
            cached_result = redis_cache.get(cache_key)
            if cached_result:
                logger.debug(f"缓存命中: {cache_key}")
                return cached_result
        
        # 构建查询
        query = select(models.FleaMarketItem)
        
        # 状态筛选（默认只显示active）
        if status_filter:
            query = query.where(models.FleaMarketItem.status == status_filter)
        else:
            # ⚠️ 优化：只显示 active 状态且未被预留的商品（sold_task_id 为空）
            # 如果 sold_task_id 不为空，说明商品已被购买但等待支付，不应该在列表中显示
            query = query.where(
                and_(
                    models.FleaMarketItem.status == "active",
                    models.FleaMarketItem.sold_task_id.is_(None)  # 排除已预留但未支付完成的商品
                )
            )
        
        # 卖家筛选
        if seller_id:
            query = query.where(models.FleaMarketItem.seller_id == seller_id)
        
        # 分类筛选
        if category:
            query = query.where(models.FleaMarketItem.category == category)
        
        # 关键词搜索（标题和描述）
        if keyword:
            keyword_pattern = f"%{keyword}%"
            query = query.where(
                or_(
                    models.FleaMarketItem.title.ilike(keyword_pattern),
                    models.FleaMarketItem.description.ilike(keyword_pattern),
                )
            )
        
        # 排序：按refreshed_at DESC, id DESC
        query = query.order_by(
            models.FleaMarketItem.refreshed_at.desc(),
            models.FleaMarketItem.id.desc()
        )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        skip = (page - 1) * pageSize
        query = query.offset(skip).limit(pageSize)
        
        # 执行查询
        result = await db.execute(query)
        items = result.scalars().all()
        
        # 构建响应
        processed_items = []
        for item in items:
            images = []
            if item.images:
                try:
                    images = json.loads(item.images) if isinstance(item.images, str) else item.images
                except:
                    images = []
            
            # 计算距离自动下架还有多少天（使用常量 AUTO_DELETE_DAYS）
            days_until_auto_delist = None
            if item.refreshed_at:
                expiry_date = item.refreshed_at + timedelta(days=AUTO_DELETE_DAYS)
                now = get_utc_time()
                days_remaining = (expiry_date - now).days
                days_until_auto_delist = max(0, days_remaining)
            
            # 计算收藏数量
            favorite_count_result = await db.execute(
                select(func.count(models.FleaMarketFavorite.id))
                .where(models.FleaMarketFavorite.item_id == item.id)
            )
            favorite_count = favorite_count_result.scalar() or 0
            
            processed_items.append(schemas.FleaMarketItemResponse(
                id=format_flea_market_id(item.id),
                title=item.title,
                description=item.description,
                price=item.price,
                currency=item.currency or "GBP",
                images=images,
                location=item.location,
                category=item.category,
                status=item.status,
                seller_id=item.seller_id,
                view_count=item.view_count or 0,
                favorite_count=favorite_count,
                refreshed_at=format_iso_utc(item.refreshed_at),
                created_at=format_iso_utc(item.created_at),
                updated_at=format_iso_utc(item.updated_at),
                days_until_auto_delist=days_until_auto_delist,
            ))
        
        response = schemas.FleaMarketItemListResponse(
            items=processed_items,
            page=page,
            pageSize=pageSize,
            total=total,
            hasMore=skip + len(processed_items) < total
        )
        
        # 缓存结果（5分钟）
        try:
            from app.redis_cache import redis_cache
            redis_cache.set(cache_key, response, ttl=300)
        except:
            pass
        
        return response
    except Exception as e:
        logger.error(f"获取商品列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取商品列表失败"
        )


# ==================== 商品详情API ====================

@flea_market_router.get("/items/{item_id}", response_model=schemas.FleaMarketItemResponse)
async def get_flea_market_item(
    item_id: str,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品详情（自动增加浏览量）"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 自动增加浏览量
        await db.execute(
            update(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == db_id)
            .values(view_count=models.FleaMarketItem.view_count + 1)
        )
        await db.commit()
        
        # 重新查询以获取更新后的view_count
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one()
        
        # 解析images JSON
        images = []
        if item.images:
            try:
                images = json.loads(item.images)
            except:
                images = []
        
        # 计算距离自动下架还有多少天（使用常量 AUTO_DELETE_DAYS）
        days_until_auto_delist = None
        if item.refreshed_at:
            expiry_date = item.refreshed_at + timedelta(days=AUTO_DELETE_DAYS)
            now = get_utc_time()
            days_remaining = (expiry_date - now).days
            days_until_auto_delist = max(0, days_remaining)
        
        # 计算收藏数量
        favorite_count_result = await db.execute(
            select(func.count(models.FleaMarketFavorite.id))
            .where(models.FleaMarketFavorite.item_id == item.id)
        )
        favorite_count = favorite_count_result.scalar() or 0
        
        # 检查当前用户是否有未付款的购买
        pending_payment_task_id = None
        pending_payment_client_secret = None
        pending_payment_amount = None
        pending_payment_amount_display = None
        pending_payment_currency = None
        pending_payment_customer_id = None
        pending_payment_ephemeral_key_secret = None
        
        if current_user and item.sold_task_id:
            # 检查关联的任务是否是当前用户的未付款购买
            task_result = await db.execute(
                select(models.Task).where(
                    and_(
                        models.Task.id == item.sold_task_id,
                        models.Task.poster_id == current_user.id,  # 当前用户是买家
                        models.Task.status == "pending_payment",  # 待支付状态
                        models.Task.is_paid == 0  # 未支付
                    )
                )
            )
            task = task_result.scalar_one_or_none()
            
            if task and task.payment_intent_id:
                # 从Stripe获取支付信息
                try:
                    import stripe
                    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
                    payment_intent = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                    
                    if payment_intent.status in ["requires_payment_method", "requires_confirmation", "requires_action"]:
                        pending_payment_task_id = task.id
                        pending_payment_client_secret = payment_intent.client_secret
                        pending_payment_amount = payment_intent.amount
                        pending_payment_amount_display = f"{payment_intent.amount / 100:.2f}"
                        pending_payment_currency = payment_intent.currency.upper()
                        
                        # 注意：customer_id和ephemeral_key_secret在iOS端可能不需要
                        # 如果iOS端需要这些信息，可以在支付时从任务详情API获取
                except Exception as e:
                    logger.warning(f"获取支付信息失败: {e}")
        
        return schemas.FleaMarketItemResponse(
            id=format_flea_market_id(item.id),
            title=item.title,
            description=item.description,
            price=item.price,
            currency=item.currency or "GBP",
            images=images,
            location=item.location,
            category=item.category,
            status=item.status,
            seller_id=item.seller_id,
            view_count=item.view_count or 0,
            favorite_count=favorite_count,
            refreshed_at=format_iso_utc(item.refreshed_at),
            created_at=format_iso_utc(item.created_at),
            updated_at=format_iso_utc(item.updated_at),
            days_until_auto_delist=days_until_auto_delist,
            pending_payment_task_id=pending_payment_task_id,
            pending_payment_client_secret=pending_payment_client_secret,
            pending_payment_amount=pending_payment_amount,
            pending_payment_amount_display=pending_payment_amount_display,
            pending_payment_currency=pending_payment_currency,
            pending_payment_customer_id=pending_payment_customer_id,
            pending_payment_ephemeral_key_secret=pending_payment_ephemeral_key_secret,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取商品详情失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取商品详情失败"
        )


# ==================== 图片上传API ====================

@flea_market_router.post("/upload-image")
async def upload_flea_market_image(
    image: UploadFile = File(...),
    item_id: Optional[str] = Query(None, description="商品ID（编辑商品时提供，支持格式化ID如S0004或数字ID，新建商品时可不提供）"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    上传跳蚤市场商品图片
    - 新建商品时：不提供item_id，图片会存储在临时目录，创建商品后移动到正式目录
    - 编辑商品时：提供item_id（支持格式化ID如S0004或数字ID），图片直接存储在商品目录
    
    优化功能：
    - 自动压缩图片
    - 生成缩略图
    - 自动旋转（根据 EXIF）
    - 移除隐私元数据
    """
    try:
        # 导入图片上传服务
        from app.services import ImageCategory, get_image_upload_service
        
        # 读取文件内容
        content = await image.read()
        
        # 确定存储目录
        db_id = None
        is_temp = True
        
        if item_id:
            # 解析商品ID（支持格式化ID如S0004或数字ID）
            try:
                db_id = parse_flea_market_id(item_id)
            except (ValueError, AttributeError) as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"无效的商品ID格式: {item_id}"
                )
            
            # 编辑商品：验证权限
            result = await db.execute(
                select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
            )
            item = result.scalar_one_or_none()
            if not item:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="商品不存在"
                )
            if item.seller_id != current_user.id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限操作此商品"
                )
            is_temp = False
        
        # 使用图片上传服务
        service = get_image_upload_service()
        result = service.upload(
            content=content,
            category=ImageCategory.FLEA_MARKET,
            resource_id=str(db_id) if db_id else None,
            user_id=current_user.id,
            filename=image.filename,
            is_temp=is_temp
        )
        
        if not result.success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result.error
            )
        
        logger.info(
            f"用户 {current_user.id} 上传跳蚤市场图片: "
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
        
        # 添加缩略图 URL
        if result.thumbnails:
            response["thumbnails"] = result.thumbnails
        
        return JSONResponse(content=response)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"上传跳蚤市场图片失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="上传图片失败"
        )


# ==================== 商品上传API ====================

@flea_market_router.post("/items", response_model=dict)
async def create_flea_market_item(
    item_data: schemas.FleaMarketItemCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """上传商品"""
    try:
        # 验证图片数量
        if len(item_data.images) > 5:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="最多只能上传5张图片"
            )
        
        # 敏感词过滤
        if contains_sensitive_words(item_data.title) or contains_sensitive_words(item_data.description):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="商品标题或描述包含敏感词，请修改后重试"
            )
        
        # 过滤敏感词
        filtered_title = filter_sensitive_words(item_data.title)
        filtered_description = filter_sensitive_words(item_data.description)
        
        # 创建商品
        new_item = models.FleaMarketItem(
            title=filtered_title,
            description=filtered_description,
            price=item_data.price,
            currency="GBP",
            images=json.dumps(item_data.images) if item_data.images else None,
            location=item_data.location or "Online",
            latitude=getattr(item_data, "latitude", None),  # 纬度（可选）
            longitude=getattr(item_data, "longitude", None),  # 经度（可选）
            category=item_data.category,
            contact=item_data.contact,
            status="active",
            seller_id=current_user.id,
            view_count=0,
            refreshed_at=get_utc_time(),
        )
        
        db.add(new_item)
        await db.commit()
        await db.refresh(new_item)
        
        # 移动临时图片到正式目录并更新URL（使用图片上传服务）
        if item_data.images:
            try:
                from app.services import ImageCategory, get_image_upload_service
                
                service = get_image_upload_service()
                
                # 使用服务移动临时图片
                updated_images = service.move_from_temp(
                    category=ImageCategory.FLEA_MARKET,
                    user_id=current_user.id,
                    resource_id=str(new_item.id),
                    image_urls=list(item_data.images)
                )
                
                # 如果有图片被移动，更新数据库中的图片URL
                if updated_images != list(item_data.images):
                    new_item.images = json.dumps(updated_images)
                    await db.commit()
                    await db.refresh(new_item)
                    logger.info(f"已更新商品 {new_item.id} 的图片URL")
                
                # 尝试删除临时目录
                service.delete_temp(category=ImageCategory.FLEA_MARKET, user_id=current_user.id)
            except Exception as e:
                logger.warning(f"移动商品图片失败: {e}")
        
        # 清除商品列表缓存，确保新商品立即显示
        invalidate_item_cache(new_item.id)
        logger.info(f"已清除商品列表缓存，新商品ID: {new_item.id}")
        
        return {
            "success": True,
            "data": {
                "id": format_flea_market_id(new_item.id)
            },
            "message": "商品上传成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"上传商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="上传商品失败"
        )


# ==================== 商品编辑/删除API ====================

@flea_market_router.put("/items/{item_id}", response_model=schemas.FleaMarketItemResponse)
async def update_flea_market_item(
    item_id: str,
    item_data: schemas.FleaMarketItemUpdate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """编辑或删除商品"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 权限验证：只有商品所有者可以编辑/删除
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此商品"
            )
        
        # 状态限制：已售出或已删除的商品不允许编辑
        if item.status in ("sold", "deleted"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已售出或已删除，无法编辑"
            )
        
        # 判断操作类型
        is_delete = item_data.status == "deleted"
        is_edit = any([
            item_data.title is not None,
            item_data.description is not None,
            item_data.price is not None,
            item_data.images is not None,
            item_data.location is not None,
            item_data.latitude is not None,
            item_data.longitude is not None,
            item_data.category is not None,
            item_data.contact is not None,
        ])
        
        # 执行编辑操作
        if is_edit:
            update_data = {}
            if item_data.title is not None:
                update_data["title"] = item_data.title
            if item_data.description is not None:
                update_data["description"] = item_data.description
            if item_data.price is not None:
                update_data["price"] = item_data.price
            if item_data.images is not None:
                if len(item_data.images) > 5:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="最多只能上传5张图片"
                    )
                
                # 获取旧图片列表，用于删除不再使用的图片
                old_images = []
                if item.images:
                    try:
                        old_images = json.loads(item.images) if isinstance(item.images, str) else item.images
                    except:
                        old_images = []
                
                # 处理临时图片：移动临时图片到正式目录并更新URL（使用图片上传服务）
                updated_images = []
                
                if item_data.images:
                    try:
                        from app.services import ImageCategory, get_image_upload_service
                        
                        service = get_image_upload_service()
                        
                        # 使用服务移动临时图片
                        updated_images = service.move_from_temp(
                            category=ImageCategory.FLEA_MARKET,
                            user_id=current_user.id,
                            resource_id=str(db_id),
                            image_urls=list(item_data.images)
                        )
                        
                        # 尝试删除临时目录
                        service.delete_temp(category=ImageCategory.FLEA_MARKET, user_id=current_user.id)
                    except Exception as e:
                        logger.warning(f"移动商品图片失败: {e}，使用原图片列表")
                        updated_images = list(item_data.images)
                
                # 更新图片列表（使用更新后的URL）
                update_data["images"] = json.dumps(updated_images) if updated_images else None
                
                # 删除不再使用的旧图片
                if old_images:
                    new_images_set = set(updated_images) if updated_images else set()
                    old_images_set = set(old_images)
                    images_to_delete = old_images_set - new_images_set
                    
                    if images_to_delete:
                        logger.info(f"商品 {db_id} 更新图片，删除 {len(images_to_delete)} 张旧图片")
                        delete_flea_market_item_images(db_id, list(images_to_delete))
            
            if item_data.location is not None:
                update_data["location"] = item_data.location
            if item_data.latitude is not None:
                update_data["latitude"] = item_data.latitude
            if item_data.longitude is not None:
                update_data["longitude"] = item_data.longitude
            if item_data.category is not None:
                update_data["category"] = item_data.category
            if item_data.contact is not None:
                update_data["contact"] = item_data.contact
            
            await db.execute(
                update(models.FleaMarketItem)
                .where(models.FleaMarketItem.id == db_id)
                .values(**update_data)
            )
        
        # 执行删除操作
        if is_delete:
            # 删除商品的所有图片文件
            old_images = []
            if item.images:
                try:
                    old_images = json.loads(item.images) if isinstance(item.images, str) else item.images
                except:
                    old_images = []
            
            if old_images:
                logger.info(f"删除商品 {db_id}，删除 {len(old_images)} 张图片")
                delete_flea_market_item_images(db_id, old_images)
            
            await db.execute(
                update(models.FleaMarketItem)
                .where(models.FleaMarketItem.id == db_id)
                .values(status="deleted")
            )
        
        await db.commit()
        
        # 重新查询更新后的商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        updated_item = result.scalar_one()
        
        # 解析images JSON
        images = []
        if updated_item.images:
            try:
                images = json.loads(updated_item.images)
            except:
                images = []
        
        # 计算距离自动下架还有多少天
        days_until_auto_delist = None
        if updated_item.refreshed_at:
            expiry_date = updated_item.refreshed_at + timedelta(days=AUTO_DELETE_DAYS)
            now = get_utc_time()
            days_remaining = (expiry_date - now).days
            days_until_auto_delist = max(0, days_remaining) if days_remaining > 0 else None
        
        # 计算收藏数量
        favorite_count_result = await db.execute(
            select(func.count(models.FleaMarketFavorite.id))
            .where(models.FleaMarketFavorite.item_id == updated_item.id)
        )
        favorite_count = favorite_count_result.scalar() or 0
        
        # 返回更新后的商品对象
        return schemas.FleaMarketItemResponse(
            id=format_flea_market_id(updated_item.id),
            title=updated_item.title,
            description=updated_item.description,
            price=updated_item.price,
            currency=updated_item.currency or "GBP",
            images=images,
            location=updated_item.location,
            latitude=updated_item.latitude,
            longitude=updated_item.longitude,
            category=updated_item.category,
            status=updated_item.status,
            seller_id=updated_item.seller_id,
            view_count=updated_item.view_count or 0,
            favorite_count=favorite_count,
            refreshed_at=format_iso_utc(updated_item.refreshed_at),
            created_at=format_iso_utc(updated_item.created_at),
            updated_at=format_iso_utc(updated_item.updated_at),
            days_until_auto_delist=days_until_auto_delist,
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"编辑/删除商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="操作失败"
        )


# ==================== 商品刷新API ====================

@flea_market_router.post("/items/{item_id}/refresh", response_model=dict)
async def refresh_flea_market_item(
    item_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """刷新商品（重置自动删除计时器）"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 权限验证：只有商品所有者可以刷新
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此商品"
            )
        
        # 状态限制：已售出或已删除的商品不允许刷新
        if item.status != "active":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已售出或已删除，无法刷新"
            )
        
        # 更新刷新时间
        await db.execute(
            update(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == db_id)
            .values(refreshed_at=get_utc_time())
        )
        await db.commit()
        
        # 清除缓存
        invalidate_item_cache(item.id)
        
        return {
            "success": True,
            "data": {
                "refreshed_at": format_iso_utc(get_utc_time())
            },
            "message": "商品刷新成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"刷新商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="刷新商品失败"
        )


# ==================== 须知同意API ====================

@flea_market_router.put("/agree-notice", response_model=dict)
async def agree_flea_market_notice(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户同意跳蚤市场须知"""
    try:
        # 更新用户同意时间
        await db.execute(
            update(models.User)
            .where(models.User.id == current_user.id)
            .values(flea_market_notice_agreed_at=get_utc_time())
        )
        await db.commit()
        
        return {
            "success": True,
            "data": {
                "agreed_at": format_iso_utc(get_utc_time())
            },
            "message": "已同意跳蚤市场须知"
        }
    except Exception as e:
        await db.rollback()
        logger.error(f"更新须知同意状态失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新失败"
        )


# ==================== 我的购买商品API ====================

@flea_market_router.get("/my-purchases", response_model=schemas.MyPurchasesListResponse)
async def get_my_purchases(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的购买商品（已售出且已创建任务）"""
    try:
        # 查询条件：通过tasks表关联查询
        # tasks.poster_id = 当前用户id AND tasks.task_type = 'Second-hand & Rental' AND flea_market_items.status = 'sold'
        query = (
            select(
                models.FleaMarketItem,
                models.Task.id.label("task_id"),
                models.Task.agreed_reward,
                models.Task.reward,
            )
            .join(
                models.Task,
                models.FleaMarketItem.sold_task_id == models.Task.id
            )
            .where(models.Task.poster_id == current_user.id)
            .where(models.Task.task_type == "Second-hand & Rental")
            .where(models.FleaMarketItem.status == "sold")
        )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 排序：按任务创建时间倒序
        query = query.order_by(models.Task.created_at.desc())
        
        # 分页
        skip = (page - 1) * pageSize
        query = query.offset(skip).limit(pageSize)
        
        # 执行查询
        result = await db.execute(query)
        rows = result.all()
        
        # 格式化响应
        formatted_items = []
        for row in rows:
            item = row[0]
            task_id = row[1]
            agreed_reward = row[2]
            reward = row[3]
            
            # 最终成交价：优先从agreed_reward获取，否则从reward获取
            final_price = agreed_reward if agreed_reward is not None else Decimal(str(reward))
            
            # 解析images JSON
            images = []
            if item.images:
                try:
                    images = json.loads(item.images)
                except:
                    images = []
            
            formatted_items.append(schemas.MyPurchasesItemResponse(
                id=format_flea_market_id(item.id),
                title=item.title,
                description=item.description,
                price=item.price,
                currency=item.currency or "GBP",
                images=images,
                location=item.location,
                category=item.category,
                status=item.status,
                seller_id=item.seller_id,
                view_count=item.view_count or 0,
                refreshed_at=format_iso_utc(item.refreshed_at),
                created_at=format_iso_utc(item.created_at),
                updated_at=format_iso_utc(item.updated_at),
                task_id=format_flea_market_id(task_id),
                final_price=final_price,
            ))
        
        # 计算hasMore
        has_more = page * pageSize < total
        
        return schemas.MyPurchasesListResponse(
            items=formatted_items,
            page=page,
            pageSize=pageSize,
            total=total,
            hasMore=has_more,
        )
    except Exception as e:
        logger.error(f"获取我的购买商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取我的购买商品失败"
        )


# ==================== 直接购买API ====================

@flea_market_router.post("/items/{item_id}/direct-purchase", response_model=dict)
async def direct_purchase_item(
    item_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """直接购买商品（无议价，直接创建任务）"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品（使用FOR UPDATE锁，防止并发）
        result = await db.execute(
            select(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == db_id)
            .with_for_update()
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 状态验证：必须是active状态
        if item.status != "active":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已售出或已下架"
            )
        
        # 不能购买自己的商品
        if item.seller_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不能购买自己的商品"
            )
        
        # 解析images JSON
        images = []
        if item.images:
            try:
                images = json.loads(item.images)
            except:
                images = []
        
        # 合并description（包含分类和联系方式）
        description = item.description
        if item.category:
            description = f"{description}\n\n分类：{item.category}"
        if item.contact:
            description = f"{description}\n\n联系方式：{item.contact}"
        
        # ⚠️ 安全修复：跳蚤市场直接购买需要支付
        # 创建任务时设置为 pending_payment 状态，等待支付完成
        # 注意：跳蚤市场直接购买应该触发支付流程，而不是直接进入 in_progress
        new_task = models.Task(
            title=item.title,
            description=description,
            reward=float(item.price),
            base_reward=item.price,
            agreed_reward=None,  # 直接购买无议价
            currency="GBP",
            location=item.location or "Online",
            task_type="Second-hand & Rental",
            poster_id=current_user.id,  # 买家
            taker_id=item.seller_id,  # 卖家
            status="pending_payment",  # ⚠️ 安全修复：等待支付，不直接进入进行中状态
            is_paid=0,  # 明确标记为未支付
            payment_expires_at=get_utc_time() + timedelta(hours=24),  # 支付过期时间（24小时）
            is_flexible=1,  # 灵活时间模式
            deadline=None,  # 无截止日期
            images=json.dumps(images) if images else None,
        )
        db.add(new_task)
        await db.flush()  # 获取任务ID
        
        # ⚠️ 优化：不立即更新商品状态为 sold，而是先关联任务ID
        # 商品状态在支付成功后才更新为 sold（在 webhook 中处理）
        # 这样可以避免支付失败或超时后商品已下架的问题
        # 使用条件更新防止并发超卖（检查商品仍然是 active 状态）
        update_result = await db.execute(
            update(models.FleaMarketItem)
            .where(
                and_(
                    models.FleaMarketItem.id == db_id,
                    models.FleaMarketItem.status == "active",
                    models.FleaMarketItem.sold_task_id.is_(None)  # 确保商品未被其他购买预留
                )
            )
            .values(
                sold_task_id=new_task.id  # 只关联任务ID，不改变状态
            )
        )
        
        # 检查是否成功更新（受影响行数为0说明已被其他请求售出或预留）
        if update_result.rowcount == 0:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已被其他用户购买或正在处理中"
            )
        
        # ⚠️ 安全修复：创建支付意图，确保跳蚤市场购买也需要支付
        # 在提交事务之前，先检查卖家是否有 Stripe Connect 账户
        seller = await db.get(models.User, item.seller_id)
        taker_stripe_account_id = seller.stripe_account_id if seller else None
        
        if not taker_stripe_account_id:
            # 如果卖家没有 Stripe Connect 账户，回滚交易
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="卖家尚未创建 Stripe Connect 收款账户，无法完成购买。请联系卖家先创建收款账户。",
                headers={"X-Stripe-Connect-Required": "true"}
            )
        
        # 创建 Payment Intent（与任务支付流程一致）
        # 注意：在提交事务之前创建 PaymentIntent，如果失败可以回滚
        import stripe
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        task_amount_pence = int(float(item.price) * 100)
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(task_amount_pence)
        
        try:
            # ⚠️ 优化：使用托管模式（与其他支付功能一致）
            # 交易市场托管模式：
            # - 支付时：资金先到平台账户（不立即转账给任务接受人）
            # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
            # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
            payment_intent = stripe.PaymentIntent.create(
                amount=task_amount_pence,
                currency="gbp",
                # 明确指定支付方式类型，确保 WeChat Pay 可用
                # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
                # 必须在 Stripe Dashboard 中启用 WeChat Pay
                payment_method_types=["card", "wechat_pay"],
                # 不设置 transfer_data.destination，让资金留在平台账户（托管模式）
                # 不设置 application_fee_amount，服务费在任务完成转账时扣除
                description=f"跳蚤市场购买 #{new_task.id}: {item.title[:50]}",
                metadata={
                    "task_id": str(new_task.id),
                    "task_title": item.title[:200] if item.title else "",
                    "poster_id": str(current_user.id),
                    "poster_name": current_user.name or f"User {current_user.id}",
                    "taker_id": str(item.seller_id),
                    "taker_name": seller.name if seller else f"User {item.seller_id}",
                    "taker_stripe_account_id": taker_stripe_account_id,  # 保存接受人的 Stripe 账户ID，用于后续转账
                    "application_fee": str(application_fee_pence),  # 保存服务费金额，用于后续转账时扣除
                    "task_amount": str(task_amount_pence),  # 任务金额
                    "task_amount_display": f"{item.price:.2f}",
                    "platform": "Link²Ur",
                    "payment_type": "flea_market_direct_purchase",
                    "flea_market_item_id": str(item.id)
                },
            )
            
            # 更新任务的 payment_intent_id
            new_task.payment_intent_id = payment_intent.id
        except Exception as e:
            # 如果创建 PaymentIntent 失败，回滚整个事务
            await db.rollback()
            logger.error(f"创建 PaymentIntent 失败: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建支付失败，请稍后重试"
            )
        
        # 提交事务（任务和商品状态都已更新，PaymentIntent 已创建）
        await db.commit()
        
        # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
        customer_id = None
        ephemeral_key_secret = None
        try:
            existing_customers = stripe.Customer.list(limit=1, metadata={"user_id": str(current_user.id)})
            if existing_customers.data:
                customer_id = existing_customers.data[0].id
            else:
                customer = stripe.Customer.create(
                    metadata={
                        "user_id": str(current_user.id),
                        "user_name": current_user.name or f"User {current_user.id}",
                    }
                )
                customer_id = customer.id

            ephemeral_key = stripe.EphemeralKey.create(
                customer=customer_id,
                stripe_version="2025-04-30.preview",
            )
            ephemeral_key_secret = ephemeral_key.secret
        except Exception as e:
            logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
            customer_id = None
            ephemeral_key_secret = None
        
        # 发送通知给卖家
        await send_direct_purchase_notification(db, item, current_user, new_task.id)
        
        # 清除缓存
        invalidate_item_cache(item.id)
        
        return {
            "success": True,
            "data": {
                "task_id": str(new_task.id),  # 任务ID直接返回整数（转为字符串），不使用格式化
                "item_status": "reserved",  # 商品状态为预留，等待支付完成
                "task_status": "pending_payment",  # 返回任务状态
                "payment_intent_id": payment_intent.id,
                "client_secret": payment_intent.client_secret,
                "amount": payment_intent.amount,
                "amount_display": f"{payment_intent.amount / 100:.2f}",
                "currency": payment_intent.currency.upper(),
                "customer_id": customer_id,
                "ephemeral_key_secret": ephemeral_key_secret,
            },
            "message": "购买已创建，请完成支付。支付完成后商品将自动下架。"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"直接购买失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="购买失败"
        )


# ==================== 购买申请API ====================

@flea_market_router.post("/items/{item_id}/purchase-request", response_model=dict)
async def create_purchase_request(
    item_id: str,
    request_data: schemas.FleaMarketPurchaseRequestCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建购买申请（议价购买）"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 状态验证：必须是active状态
        if item.status != "active":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已售出或已下架"
            )
        
        # 不能申请购买自己的商品
        if item.seller_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不能申请购买自己的商品"
            )
        
        # 检查是否已有pending状态的申请（唯一约束）
        existing = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
            .where(models.FleaMarketPurchaseRequest.buyer_id == current_user.id)
            .where(models.FleaMarketPurchaseRequest.status == "pending")
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="您已提交购买申请，请等待卖家处理"
            )
        
        # 创建购买申请
        new_request = models.FleaMarketPurchaseRequest(
            item_id=db_id,
            buyer_id=current_user.id,
            proposed_price=request_data.proposed_price,
            message=request_data.message,
            status="pending",
        )
        
        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)
        
        # 发送通知给卖家
        await send_purchase_request_notification(
            db, item, current_user, 
            float(request_data.proposed_price) if request_data.proposed_price else None,
            request_data.message
        )
        
        return {
            "success": True,
            "data": {
                "purchase_request_id": format_flea_market_id(new_request.id),
                "status": "pending",
                "proposed_price": float(new_request.proposed_price) if new_request.proposed_price else None,
                "created_at": format_iso_utc(new_request.created_at)
            },
            "message": "购买申请已提交，等待卖家处理"
        }
    except HTTPException:
        raise
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="您已提交购买申请，请等待卖家处理"
        )
    except Exception as e:
        await db.rollback()
        logger.error(f"创建购买申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建购买申请失败"
        )


# ==================== 接受购买API ====================

@flea_market_router.post("/items/{item_id}/accept-purchase", response_model=dict)
async def accept_purchase_request(
    item_id: str,
    accept_data: schemas.AcceptPurchaseRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """买家接受卖家议价后创建任务"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品（使用FOR UPDATE锁，防止并发）
        result = await db.execute(
            select(models.FleaMarketItem)
            .where(models.FleaMarketItem.id == db_id)
            .with_for_update()
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 状态验证：必须是active状态
        if item.status != "active":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已售出或已下架"
            )
        
        # 查询购买申请（使用FOR UPDATE锁）
        request_result = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == accept_data.purchase_request_id)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
            .with_for_update()
        )
        purchase_request = request_result.scalar_one_or_none()
        
        if not purchase_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="购买申请不存在"
            )
        
        # 权限验证：只有买家可以接受卖家议价
        if purchase_request.buyer_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )
        
        # 幂等性检查：如果申请已经是accepted或rejected，直接返回
        if purchase_request.status in ("accepted", "rejected"):
            if purchase_request.status == "accepted" and item.sold_task_id:
                task = await db.get(models.Task, item.sold_task_id)
                return {
                    "success": True,
                    "data": {
                        "task_id": format_flea_market_id(task.id),
                        "item_status": "sold",
                        "final_price": float(task.agreed_reward or task.reward),
                        "purchase_request_status": "accepted"
                    },
                    "message": "购买申请已接受，任务已创建"
                }
            else:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="该申请已被处理"
                )
        
        # 状态验证：必须是seller_negotiating状态（卖家已议价）
        if purchase_request.status != "seller_negotiating":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许接受，请等待卖家议价"
            )
        
        # 确定最终成交价（使用卖家议价）
        final_price = purchase_request.seller_counter_price
        if final_price is None:
            final_price = purchase_request.proposed_price if purchase_request.proposed_price else item.price
        
        # 解析images JSON
        images = []
        if item.images:
            try:
                images = json.loads(item.images)
            except:
                images = []
        
        # 合并description（包含分类和联系方式）
        description = item.description
        if item.category:
            description = f"{description}\n\n分类：{item.category}"
        if item.contact:
            description = f"{description}\n\n联系方式：{item.contact}"
        
        # ⚠️ 安全修复：跳蚤市场接受购买申请需要支付
        # 检查卖家是否有 Stripe Connect 账户（用于接收任务奖励）
        seller = await db.get(models.User, item.seller_id)
        taker_stripe_account_id = seller.stripe_account_id if seller else None
        
        if not taker_stripe_account_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="卖家尚未创建 Stripe Connect 收款账户，无法完成购买。请联系卖家先创建收款账户。",
                headers={"X-Stripe-Connect-Required": "true"}
            )
        
        # 创建任务时设置为 pending_payment 状态，等待支付完成
        new_task = models.Task(
            title=item.title,
            description=description,
            reward=float(final_price),
            base_reward=item.price,
            agreed_reward=final_price,  # 最终成交价（卖家议价）
            currency="GBP",
            location=item.location or "Online",
            task_type="Second-hand & Rental",
            poster_id=purchase_request.buyer_id,  # 买家
            taker_id=item.seller_id,  # 卖家
            status="pending_payment",  # ⚠️ 安全修复：等待支付，不直接进入进行中状态
            is_paid=0,  # 明确标记为未支付
            payment_expires_at=get_utc_time() + timedelta(hours=24),  # 支付过期时间（24小时）
            is_flexible=1,  # 灵活时间模式
            deadline=None,  # 无截止日期
            images=json.dumps(images) if images else None,
        )
        db.add(new_task)
        await db.flush()  # 获取任务ID
        
        # ⚠️ 安全修复：创建支付意图，确保跳蚤市场购买也需要支付
        # 注意：在提交事务之前创建 PaymentIntent，如果失败可以回滚
        import stripe
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        task_amount_pence = int(float(final_price) * 100)
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(task_amount_pence)
        
        try:
            # ⚠️ 优化：使用托管模式（与其他支付功能一致）
            # 交易市场托管模式：
            # - 支付时：资金先到平台账户（不立即转账给任务接受人）
            # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
            # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
            payment_intent = stripe.PaymentIntent.create(
                amount=task_amount_pence,
                currency="gbp",
                # 明确指定支付方式类型，确保 WeChat Pay 可用
                # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
                # 必须在 Stripe Dashboard 中启用 WeChat Pay
                payment_method_types=["card", "wechat_pay"],
                # 不设置 transfer_data.destination，让资金留在平台账户（托管模式）
                # 不设置 application_fee_amount，服务费在任务完成转账时扣除
                description=f"跳蚤市场购买（议价） #{new_task.id}: {item.title[:50]}",
                metadata={
                    "task_id": str(new_task.id),
                    "task_title": item.title[:200] if item.title else "",
                    "poster_id": str(purchase_request.buyer_id),
                    "poster_name": purchase_request.buyer.name if purchase_request.buyer else f"User {purchase_request.buyer_id}",
                    "taker_id": str(item.seller_id),
                    "taker_name": seller.name if seller else f"User {item.seller_id}",
                    "taker_stripe_account_id": taker_stripe_account_id,  # 保存接受人的 Stripe 账户ID，用于后续转账
                    "application_fee": str(application_fee_pence),  # 保存服务费金额，用于后续转账时扣除
                    "task_amount": str(task_amount_pence),  # 任务金额
                    "task_amount_display": f"{final_price:.2f}",
                    "platform": "Link²Ur",
                    "payment_type": "flea_market_purchase_request",
                    "flea_market_item_id": str(item.id),
                    "purchase_request_id": str(accept_data.purchase_request_id)
                },
            )
            
            # 更新任务的 payment_intent_id
            new_task.payment_intent_id = payment_intent.id
        except Exception as e:
            # 如果创建 PaymentIntent 失败，回滚整个事务
            await db.rollback()
            logger.error(f"创建 PaymentIntent 失败: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建支付失败，请稍后重试"
            )
        
        # ⚠️ 优化：不立即更新商品状态为 sold，而是先关联任务ID
        # 商品状态在支付成功后才更新为 sold（在 webhook 中处理）
        # 使用条件更新防止并发超卖（检查商品仍然是 active 状态）
        update_result = await db.execute(
            update(models.FleaMarketItem)
            .where(
                and_(
                    models.FleaMarketItem.id == db_id,
                    models.FleaMarketItem.status == "active",
                    models.FleaMarketItem.sold_task_id.is_(None)  # 确保商品未被其他购买预留
                )
            )
            .values(
                sold_task_id=new_task.id  # 只关联任务ID，不改变状态
            )
        )
        
        # 检查是否成功更新
        if update_result.rowcount == 0:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已被其他用户购买"
            )
        
        # 更新购买申请状态为accepted
        await db.execute(
            update(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == accept_data.purchase_request_id)
            .values(status="accepted")
        )
        
        # 自动拒绝其他pending和seller_negotiating状态的申请
        await db.execute(
            update(models.FleaMarketPurchaseRequest)
            .where(
                and_(
                    models.FleaMarketPurchaseRequest.item_id == db_id,
                    models.FleaMarketPurchaseRequest.status.in_(["pending", "seller_negotiating"]),
                    models.FleaMarketPurchaseRequest.id != accept_data.purchase_request_id
                )
            )
            .values(status="rejected")
        )
        
        # 提交事务（任务和商品状态都已更新，PaymentIntent 已创建）
        await db.commit()
        
        # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
        customer_id = None
        ephemeral_key_secret = None
        try:
            existing_customers = stripe.Customer.list(limit=1, metadata={"user_id": str(purchase_request.buyer_id)})
            if existing_customers.data:
                customer_id = existing_customers.data[0].id
            else:
                customer = stripe.Customer.create(
                    metadata={
                        "user_id": str(purchase_request.buyer_id),
                        "user_name": purchase_request.buyer.name if purchase_request.buyer else f"User {purchase_request.buyer_id}",
                    }
                )
                customer_id = customer.id

            ephemeral_key = stripe.EphemeralKey.create(
                customer=customer_id,
                stripe_version="2025-04-30.preview",
            )
            ephemeral_key_secret = ephemeral_key.secret
        except Exception as e:
            logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
            customer_id = None
            ephemeral_key_secret = None
        
        # 发送通知给卖家
        await send_purchase_accepted_notification(
            db, item, purchase_request.buyer, new_task.id, float(final_price)
        )
        
        # 清除缓存
        invalidate_item_cache(item.id)
        
        return {
            "success": True,
            "data": {
                "task_id": str(new_task.id),  # 任务ID直接返回整数（转为字符串），不使用格式化
                "item_status": "reserved",  # 商品状态为预留，等待支付完成
                "task_status": "pending_payment",  # 返回任务状态
                "final_price": float(final_price),
                "purchase_request_status": "accepted",
                "payment_intent_id": payment_intent.id,
                "client_secret": payment_intent.client_secret,
                "amount": payment_intent.amount,
                "amount_display": f"{payment_intent.amount / 100:.2f}",
                "currency": payment_intent.currency.upper(),
                "customer_id": customer_id,
                "ephemeral_key_secret": ephemeral_key_secret,
            },
            "message": "购买申请已接受，请完成支付。支付完成后商品将自动下架。"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"接受购买申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="接受购买申请失败"
        )


# ==================== 获取购买申请列表API ====================

@flea_market_router.get("/items/{item_id}/purchase-requests", response_model=dict)
async def get_purchase_requests(
    item_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品的购买申请列表（仅商品所有者可查看）"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 权限验证：只有商品所有者可以查看购买申请
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限查看此商品的购买申请"
            )
        
        # 查询购买申请
        requests_result = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
            .order_by(models.FleaMarketPurchaseRequest.created_at.desc())
        )
        purchase_requests = requests_result.scalars().all()
        
        # 格式化响应
        requests_list = []
        for req in purchase_requests:
            # 获取买家信息
            buyer_result = await db.execute(
                select(models.User).where(models.User.id == req.buyer_id)
            )
            buyer = buyer_result.scalar_one_or_none()
            
            requests_list.append({
                "id": format_flea_market_id(req.id),
                "item_id": format_flea_market_id(req.item_id),
                "buyer_id": req.buyer_id,
                "buyer_name": buyer.name if buyer else f"用户{req.buyer_id}",
                "proposed_price": float(req.proposed_price) if req.proposed_price else None,
                "seller_counter_price": float(req.seller_counter_price) if req.seller_counter_price else None,
                "message": req.message,
                "status": req.status,
                "created_at": format_iso_utc(req.created_at),
                "updated_at": format_iso_utc(req.updated_at)
            })
        
        return {
            "success": True,
            "data": {
                "requests": requests_list,
                "total": len(requests_list)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取购买申请列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取购买申请列表失败"
        )


# ==================== 拒绝购买申请API ====================

@flea_market_router.post("/items/{item_id}/reject-purchase", response_model=dict)
async def reject_purchase_request(
    item_id: str,
    reject_data: schemas.RejectPurchaseRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """拒绝购买申请"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 权限验证：只有商品所有者可以拒绝申请
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此商品"
            )
        
        # 查询购买申请
        request_result = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == reject_data.purchase_request_id)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
        )
        purchase_request = request_result.scalar_one_or_none()
        
        if not purchase_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="购买申请不存在"
            )
        
        # 状态验证：必须是pending状态
        if purchase_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请已被处理"
            )
        
        # 更新申请状态为rejected
        await db.execute(
            update(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == reject_data.purchase_request_id)
            .values(status="rejected")
        )
        
        await db.commit()
        
        # TODO: 发送通知给买家（可选）
        
        return {
            "success": True,
            "data": {
                "purchase_request_status": "rejected"
            },
            "message": "购买申请已拒绝"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"拒绝购买申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="拒绝购买申请失败"
        )


# ==================== 卖家议价API ====================

@flea_market_router.post("/items/{item_id}/counter-offer", response_model=dict)
async def seller_counter_offer(
    item_id: str,
    counter_data: schemas.SellerCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """卖家对购买申请进行议价"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 权限验证：只有商品所有者可以议价
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此商品"
            )
        
        # 查询购买申请
        request_result = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == counter_data.purchase_request_id)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
        )
        purchase_request = request_result.scalar_one_or_none()
        
        if not purchase_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="购买申请不存在"
            )
        
        # 状态验证：必须是pending状态
        if purchase_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许议价"
            )
        
        # 更新购买申请：设置卖家议价并更新状态为seller_negotiating
        await db.execute(
            update(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == counter_data.purchase_request_id)
            .values(
                seller_counter_price=counter_data.counter_price,
                status="seller_negotiating"
            )
        )
        
        await db.commit()
        
        # TODO: 发送通知给买家（可选）
        
        return {
            "success": True,
            "data": {
                "purchase_request_status": "seller_negotiating",
                "seller_counter_price": float(counter_data.counter_price)
            },
            "message": "议价已发送，等待买家回应"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"卖家议价失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="卖家议价失败"
        )


# ==================== 买家回应卖家议价API ====================

@flea_market_router.post("/items/{item_id}/respond-counter-offer", response_model=dict)
async def buyer_respond_to_counter_offer(
    item_id: str,
    respond_data: schemas.BuyerRespondToCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """买家回应卖家的议价（接受或拒绝）"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 查询购买申请
        request_result = await db.execute(
            select(models.FleaMarketPurchaseRequest)
            .where(models.FleaMarketPurchaseRequest.id == respond_data.purchase_request_id)
            .where(models.FleaMarketPurchaseRequest.item_id == db_id)
        )
        purchase_request = request_result.scalar_one_or_none()
        
        if not purchase_request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="购买申请不存在"
            )
        
        # 权限验证：只有买家可以回应
        if purchase_request.buyer_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此申请"
            )
        
        # 状态验证：必须是seller_negotiating状态
        if purchase_request.status != "seller_negotiating":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许此操作"
            )
        
        if respond_data.accept:
            # 买家接受卖家议价，调用accept-purchase API创建任务
            # 这里直接调用accept_purchase_request的逻辑
            accept_data = schemas.AcceptPurchaseRequest(purchase_request_id=respond_data.purchase_request_id)
            return await accept_purchase_request(item_id, accept_data, current_user, db)
        else:
            # 买家拒绝卖家议价，将申请状态改为rejected
            await db.execute(
                update(models.FleaMarketPurchaseRequest)
                .where(models.FleaMarketPurchaseRequest.id == respond_data.purchase_request_id)
                .values(status="rejected")
            )
            
            await db.commit()
            
            return {
                "success": True,
                "data": {
                    "purchase_request_status": "rejected"
                },
                "message": "已拒绝卖家议价，购买申请已取消"
            }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"回应卖家议价失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="回应卖家议价失败"
        )


# ==================== 商品收藏API ====================

@flea_market_router.post("/items/{item_id}/favorite", response_model=dict)
async def toggle_favorite_item(
    item_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """收藏/取消收藏商品"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 检查商品是否存在
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 检查是否已收藏
        favorite_result = await db.execute(
            select(models.FleaMarketFavorite)
            .where(
                and_(
                    models.FleaMarketFavorite.item_id == db_id,
                    models.FleaMarketFavorite.user_id == current_user.id
                )
            )
        )
        favorite = favorite_result.scalar_one_or_none()
        
        if favorite:
            # 取消收藏
            await db.delete(favorite)
            await db.commit()
            return {
                "success": True,
                "data": {"is_favorited": False},
                "message": "已取消收藏"
            }
        else:
            # 添加收藏
            new_favorite = models.FleaMarketFavorite(
                user_id=current_user.id,
                item_id=db_id
            )
            db.add(new_favorite)
            await db.commit()
            return {
                "success": True,
                "data": {"is_favorited": True},
                "message": "收藏成功"
            }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"收藏操作失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="操作失败"
        )


@flea_market_router.get("/favorites", response_model=schemas.FleaMarketFavoriteListResponse)
async def get_my_favorites(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的收藏列表"""
    try:
        # 查询收藏
        query = select(models.FleaMarketFavorite).where(
            models.FleaMarketFavorite.user_id == current_user.id
        ).order_by(models.FleaMarketFavorite.created_at.desc())
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        skip = (page - 1) * pageSize
        query = query.offset(skip).limit(pageSize)
        
        result = await db.execute(query)
        favorites = result.scalars().all()
        
        # 格式化响应
        items = []
        for fav in favorites:
            items.append(schemas.FleaMarketFavoriteResponse(
                id=fav.id,
                item_id=format_flea_market_id(fav.item_id),
                created_at=format_iso_utc(fav.created_at)
            ))
        
        return schemas.FleaMarketFavoriteListResponse(
            items=items,
            page=page,
            pageSize=pageSize,
            total=total,
            hasMore=skip + len(items) < total
        )
    except Exception as e:
        logger.error(f"获取收藏列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取收藏列表失败"
        )


@flea_market_router.get("/favorites/items", response_model=schemas.FleaMarketItemListResponse)
async def get_my_favorite_items(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我的收藏商品列表（包含完整商品信息）"""
    try:
        # 查询收藏的商品，关联商品表获取完整信息
        query = (
            select(models.FleaMarketItem)
            .join(
                models.FleaMarketFavorite,
                models.FleaMarketItem.id == models.FleaMarketFavorite.item_id
            )
            .where(models.FleaMarketFavorite.user_id == current_user.id)
            .where(models.FleaMarketItem.status != "deleted")  # 排除已删除的商品
            .order_by(models.FleaMarketFavorite.created_at.desc())
        )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        skip = (page - 1) * pageSize
        query = query.offset(skip).limit(pageSize)
        
        result = await db.execute(query)
        items = result.scalars().all()
        
        # 格式化响应
        formatted_items = []
        for item in items:
            # 解析images JSON
            images = []
            if item.images:
                try:
                    images = json.loads(item.images)
                except:
                    images = []
            
            # 计算收藏数量
            favorite_count_result = await db.execute(
                select(func.count(models.FleaMarketFavorite.id))
                .where(models.FleaMarketFavorite.item_id == item.id)
            )
            favorite_count = favorite_count_result.scalar() or 0
            
            formatted_items.append(schemas.FleaMarketItemResponse(
                id=format_flea_market_id(item.id),
                title=item.title,
                description=item.description,
                price=item.price,
                currency=item.currency or "GBP",
                images=images,
                location=item.location,
                latitude=float(item.latitude) if item.latitude else None,
                longitude=float(item.longitude) if item.longitude else None,
                category=item.category,
                status=item.status,
                seller_id=item.seller_id,
                view_count=item.view_count or 0,
                favorite_count=favorite_count,
                refreshed_at=format_iso_utc(item.refreshed_at),
                created_at=format_iso_utc(item.created_at),
                updated_at=format_iso_utc(item.updated_at),
            ))
        
        return schemas.FleaMarketItemListResponse(
            items=formatted_items,
            page=page,
            pageSize=pageSize,
            total=total,
            hasMore=skip + len(formatted_items) < total,
        )
    except Exception as e:
        logger.error(f"获取收藏商品列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取收藏商品列表失败"
        )


# ==================== 商品举报API ====================

@flea_market_router.post("/items/{item_id}/report", response_model=dict)
async def report_item(
    item_id: str,
    report_data: schemas.FleaMarketReportCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """举报商品"""
    try:
        db_id = parse_flea_market_id(item_id)
        
        # 检查商品是否存在
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 验证举报原因
        valid_reasons = ["spam", "fraud", "inappropriate", "other"]
        if report_data.reason not in valid_reasons:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"无效的举报原因。允许的原因: {', '.join(valid_reasons)}"
            )
        
        # 检查是否已举报（pending状态）
        existing_result = await db.execute(
            select(models.FleaMarketReport)
            .where(
                and_(
                    models.FleaMarketReport.item_id == db_id,
                    models.FleaMarketReport.reporter_id == current_user.id,
                    models.FleaMarketReport.status == "pending"
                )
            )
        )
        existing = existing_result.scalar_one_or_none()
        
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="您已经举报过该商品，请等待管理员处理"
            )
        
        # 创建举报
        new_report = models.FleaMarketReport(
            item_id=db_id,
            reporter_id=current_user.id,
            reason=report_data.reason,
            description=report_data.description,
            status="pending"
        )
        
        db.add(new_report)
        await db.commit()
        
        return {
            "success": True,
            "message": "举报已提交，我们会尽快处理"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"举报商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="举报失败"
        )


# ==================== 商品举报管理API（管理员）====================

@flea_market_router.get("/admin/reports", response_model=dict)
async def get_flea_market_reports(
    status_filter: Optional[str] = Query(None, pattern="^(pending|reviewing|resolved|rejected)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品举报列表（管理员）"""
    query = select(models.FleaMarketReport)
    
    if status_filter:
        query = query.where(models.FleaMarketReport.status == status_filter)
    
    query = query.order_by(models.FleaMarketReport.created_at.desc())
    
    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 分页
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    result = await db.execute(query)
    reports = result.scalars().all()
    
    report_list = []
    for r in reports:
        # 加载商品信息
        item_result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == r.item_id)
        )
        item = item_result.scalar_one_or_none()
        
        # 加载举报人信息
        reporter_result = await db.execute(
            select(models.User).where(models.User.id == r.reporter_id)
        )
        reporter = reporter_result.scalar_one_or_none()
        
        report_list.append({
            "id": r.id,
            "item_id": format_flea_market_id(r.item_id),
            "item_title": item.title if item else "商品已删除",
            "seller_id": item.seller_id if item else None,
            "reporter_id": r.reporter_id,
            "reporter_name": reporter.name if reporter else "未知用户",
            "reason": r.reason,
            "description": r.description,
            "status": r.status,
            "admin_comment": r.admin_comment,
            "handled_by": r.handled_by,
            "created_at": format_iso_utc(r.created_at),
            "handled_at": format_iso_utc(r.handled_at) if r.handled_at else None
        })
    
    return {
        "reports": report_list,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@flea_market_router.put("/admin/reports/{report_id}/process", response_model=dict)
async def process_flea_market_report(
    report_id: int,
    process_data: dict = Body(...),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """处理商品举报（管理员）"""
    status_value = process_data.get("status")  # resolved, rejected
    admin_comment = process_data.get("admin_comment")
    
    if status_value not in ["resolved", "rejected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的状态，必须是 resolved 或 rejected"
        )
    
    result = await db.execute(
        select(models.FleaMarketReport).where(models.FleaMarketReport.id == report_id)
    )
    report = result.scalar_one_or_none()
    
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="举报不存在"
        )
    
    if report.status not in ["pending", "reviewing"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该举报已处理"
        )
    
    # 更新举报状态
    report.status = status_value
    report.handled_by = current_admin.id
    report.handled_at = get_utc_time()
    if admin_comment:
        report.admin_comment = admin_comment
    
    await db.commit()
    
    return {
        "success": True,
        "message": "举报处理成功",
        "report": {
            "id": report.id,
            "status": report.status,
            "admin_comment": report.admin_comment
        }
    }


# ==================== 商品管理API（管理员）====================

@flea_market_router.get("/admin/items", response_model=dict)
async def get_flea_market_items_admin(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    category: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None),
    seller_id: Optional[str] = Query(None),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品列表（管理员，可查看所有状态）"""
    try:
        # 构建查询
        query = select(models.FleaMarketItem)
        
        # 状态筛选（管理员可以查看所有状态）
        if status_filter:
            query = query.where(models.FleaMarketItem.status == status_filter)
        
        # 卖家筛选
        if seller_id:
            query = query.where(models.FleaMarketItem.seller_id == seller_id)
        
        # 分类筛选
        if category:
            query = query.where(models.FleaMarketItem.category == category)
        
        # 关键词搜索（标题和描述）
        if keyword:
            keyword_pattern = f"%{keyword}%"
            query = query.where(
                or_(
                    models.FleaMarketItem.title.ilike(keyword_pattern),
                    models.FleaMarketItem.description.ilike(keyword_pattern),
                )
            )
        
        # 排序：按created_at DESC
        query = query.order_by(
            models.FleaMarketItem.created_at.desc()
        )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        skip = (page - 1) * page_size
        query = query.offset(skip).limit(page_size)
        
        # 执行查询
        result = await db.execute(query)
        items = result.scalars().all()
        
        # 构建响应
        processed_items = []
        for item in items:
            images = []
            if item.images:
                try:
                    images = json.loads(item.images) if isinstance(item.images, str) else item.images
                except:
                    images = []
            
            # 获取卖家信息
            seller_result = await db.execute(
                select(models.User).where(models.User.id == item.seller_id)
            )
            seller = seller_result.scalar_one_or_none()
            
            processed_items.append({
                "id": format_flea_market_id(item.id),
                "title": item.title,
                "description": item.description,
                "price": float(item.price) if item.price else 0,
                "currency": item.currency or "GBP",
                "images": images,
                "location": item.location,
                "category": item.category,
                "status": item.status,
                "seller_id": item.seller_id,
                "seller_name": seller.name if seller else "未知用户",
                "view_count": item.view_count or 0,
                "refreshed_at": format_iso_utc(item.refreshed_at) if item.refreshed_at else None,
                "created_at": format_iso_utc(item.created_at),
                "updated_at": format_iso_utc(item.updated_at),
            })
        
        return {
            "items": processed_items,
            "page": page,
            "page_size": page_size,
            "total": total
        }
    except Exception as e:
        logger.error(f"获取商品列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取商品列表失败"
        )


@flea_market_router.put("/admin/items/{item_id}", response_model=dict)
async def update_flea_market_item_admin(
    item_id: str,
    item_data: dict = Body(...),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员编辑商品"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 更新字段
        if "title" in item_data:
            item.title = item_data["title"]
        if "description" in item_data:
            item.description = item_data["description"]
        if "price" in item_data:
            item.price = Decimal(str(item_data["price"]))
        if "images" in item_data:
            item.images = json.dumps(item_data["images"]) if item_data["images"] else None
        if "location" in item_data:
            item.location = item_data["location"]
        if "category" in item_data:
            item.category = item_data["category"]
        if "status" in item_data:
            item.status = item_data["status"]
        
        await db.commit()
        
        # 清除缓存
        invalidate_item_cache(item.id)
        
        return {
            "success": True,
            "message": "商品更新成功",
            "data": {
                "id": format_flea_market_id(item.id),
                "title": item.title,
                "status": item.status
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"更新商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新商品失败"
        )


@flea_market_router.delete("/admin/items/{item_id}", response_model=dict)
async def delete_flea_market_item_admin(
    item_id: str,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员删除商品"""
    try:
        # 解析ID
        db_id = parse_flea_market_id(item_id)
        
        # 查询商品
        result = await db.execute(
            select(models.FleaMarketItem).where(models.FleaMarketItem.id == db_id)
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="商品不存在"
            )
        
        # 删除商品（软删除）
        item.status = "deleted"
        await db.commit()
        
        # 清除缓存
        invalidate_item_cache(item.id)
        
        return {
            "success": True,
            "message": "商品已删除"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"删除商品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除商品失败"
        )

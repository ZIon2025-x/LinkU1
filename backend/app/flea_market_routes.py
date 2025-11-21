"""
跳蚤市场API路由
实现跳蚤市场相关的所有接口
"""

import json
import logging
import os
import uuid
from decimal import Decimal
from typing import List, Optional
from datetime import datetime, timedelta
from pathlib import Path

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
from app.id_generator import format_flea_market_id, parse_flea_market_id
from app.utils.time_utils import get_utc_time, format_iso_utc
from app.config import Config
from app.flea_market_constants import FLEA_MARKET_CATEGORIES

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
    pageSize: int = Query(20, ge=1, le=100),
    category: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    status_filter: Optional[str] = Query("active", alias="status"),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取商品列表（分页、搜索、筛选）"""
    try:
        # 构建查询
        query = select(models.FleaMarketItem)
        
        # 状态筛选（默认只显示active）
        if status_filter:
            query = query.where(models.FleaMarketItem.status == status_filter)
        else:
            query = query.where(models.FleaMarketItem.status == "active")
        
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
            
            formatted_items.append(schemas.FleaMarketItemResponse(
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
            ))
        
        # 计算hasMore
        has_more = page * pageSize < total
        
        return schemas.FleaMarketItemListResponse(
            items=formatted_items,
            page=page,
            pageSize=pageSize,
            total=total,
            hasMore=has_more,
        )
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
            refreshed_at=format_iso_utc(item.refreshed_at),
            created_at=format_iso_utc(item.created_at),
            updated_at=format_iso_utc(item.updated_at),
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
    item_id: Optional[int] = Query(None, description="商品ID（编辑商品时提供，新建商品时可不提供）"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    上传跳蚤市场商品图片
    - 新建商品时：不提供item_id，图片会存储在临时目录，创建商品后移动到正式目录
    - 编辑商品时：提供item_id，图片直接存储在商品目录
    """
    try:
        # 读取文件内容
        content = await image.read()
        
        # 验证文件类型
        file_extension = Path(image.filename).suffix.lower()
        if file_extension not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"不支持的文件类型。允许的类型: {', '.join(ALLOWED_EXTENSIONS)}"
            )
        
        # 验证文件大小
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"文件过大。最大允许大小: {MAX_FILE_SIZE // (1024*1024)}MB"
            )
        
        # 确定存储目录
        if item_id:
            # 编辑商品：验证权限
            result = await db.execute(
                select(models.FleaMarketItem).where(models.FleaMarketItem.id == item_id)
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
            image_dir = FLEA_MARKET_IMAGE_DIR / str(item_id)
        else:
            # 新建商品：使用临时目录
            image_dir = FLEA_MARKET_IMAGE_DIR / f"temp_{current_user.id}"
        
        # 确保目录存在
        image_dir.mkdir(parents=True, exist_ok=True)
        
        # 生成唯一文件名
        unique_filename = f"flea_market_{uuid.uuid4()}{file_extension}"
        file_path = image_dir / unique_filename
        
        # 保存文件
        with open(file_path, "wb") as buffer:
            buffer.write(content)
        
        # 生成URL
        base_url = Config.FRONTEND_URL.rstrip('/')
        if item_id:
            image_url = f"{base_url}/uploads/flea_market/{item_id}/{unique_filename}"
        else:
            image_url = f"{base_url}/uploads/flea_market/temp_{current_user.id}/{unique_filename}"
        
        logger.info(f"用户 {current_user.id} 上传跳蚤市场图片: {image_url}")
        
        return JSONResponse(content={
            "success": True,
            "url": image_url,
            "filename": unique_filename,
            "size": len(content),
            "message": "图片上传成功"
        })
        
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
        
        # 创建商品
        new_item = models.FleaMarketItem(
            title=item_data.title,
            description=item_data.description,
            price=item_data.price,
            currency="GBP",
            images=json.dumps(item_data.images) if item_data.images else None,
            location=item_data.location or "Online",
            category=item_data.category,
            status="active",
            seller_id=current_user.id,
            view_count=0,
            refreshed_at=get_utc_time(),
        )
        
        db.add(new_item)
        await db.commit()
        await db.refresh(new_item)
        
        # 移动临时图片到正式目录（如果使用了临时目录）
        if item_data.images:
            temp_dir = FLEA_MARKET_IMAGE_DIR / f"temp_{current_user.id}"
            item_dir = FLEA_MARKET_IMAGE_DIR / str(new_item.id)
            if temp_dir.exists():
                item_dir.mkdir(parents=True, exist_ok=True)
                # 移动临时目录中的图片文件
                for image_url in item_data.images:
                    try:
                        # 从URL中提取文件名
                        filename = image_url.split('/')[-1]
                        temp_file = temp_dir / filename
                        if temp_file.exists():
                            item_file = item_dir / filename
                            temp_file.rename(item_file)
                            logger.info(f"移动临时图片到商品目录: {filename}")
                    except Exception as e:
                        logger.warning(f"移动图片文件失败: {e}")
                # 删除临时目录（如果为空）
                try:
                    if not any(temp_dir.iterdir()):
                        temp_dir.rmdir()
                except:
                    pass
        
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

@flea_market_router.put("/items/{item_id}", response_model=dict)
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
            item_data.category is not None,
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
                update_data["images"] = json.dumps(item_data.images) if item_data.images else None
            if item_data.location is not None:
                update_data["location"] = item_data.location
            if item_data.category is not None:
                update_data["category"] = item_data.category
            
            await db.execute(
                update(models.FleaMarketItem)
                .where(models.FleaMarketItem.id == db_id)
                .values(**update_data)
            )
        
        # 执行删除操作
        if is_delete:
            await db.execute(
                update(models.FleaMarketItem)
                .where(models.FleaMarketItem.id == db_id)
                .values(status="deleted")
            )
        
        await db.commit()
        
        message = "商品删除成功" if is_delete else "商品编辑成功"
        return {
            "success": True,
            "message": message
        }
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
        
        # 合并description（包含分类）
        description = item.description
        if item.category:
            description = f"{description}\n\n分类：{item.category}"
        
        # 创建任务（在同一个事务中）
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
            status="in_progress",  # 直接进入进行中状态
            is_flexible=1,  # 灵活时间模式
            deadline=None,  # 无截止日期
            images=json.dumps(images) if images else None,
        )
        db.add(new_task)
        await db.flush()  # 获取任务ID
        
        # 更新商品状态为sold（使用条件更新防止并发超卖）
        update_result = await db.execute(
            update(models.FleaMarketItem)
            .where(
                and_(
                    models.FleaMarketItem.id == db_id,
                    models.FleaMarketItem.status == "active"
                )
            )
            .values(
                status="sold",
                sold_task_id=new_task.id
            )
        )
        
        # 检查是否成功更新（受影响行数为0说明已被其他请求售出）
        if update_result.rowcount == 0:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该商品已被其他用户购买"
            )
        
        await db.commit()
        
        return {
            "success": True,
            "data": {
                "task_id": format_flea_market_id(new_task.id),
                "item_status": "sold"
            },
            "message": "购买成功，任务已创建"
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
    """接受购买申请（创建任务）"""
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
        
        # 权限验证：只有商品所有者可以接受申请
        if item.seller_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限操作此商品"
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
        
        # 状态验证：必须是pending状态
        if purchase_request.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="该申请状态不允许接受"
            )
        
        # 确定最终成交价
        final_price = accept_data.agreed_price if accept_data.agreed_price is not None else purchase_request.proposed_price
        if final_price is None:
            final_price = item.price
        
        # 解析images JSON
        images = []
        if item.images:
            try:
                images = json.loads(item.images)
            except:
                images = []
        
        # 合并description（包含分类）
        description = item.description
        if item.category:
            description = f"{description}\n\n分类：{item.category}"
        
        # 创建任务（在同一个事务中）
        new_task = models.Task(
            title=item.title,
            description=description,
            reward=float(final_price),
            base_reward=item.price,
            agreed_reward=final_price,  # 最终成交价（有议价）
            currency="GBP",
            location=item.location or "Online",
            task_type="Second-hand & Rental",
            poster_id=purchase_request.buyer_id,  # 买家
            taker_id=item.seller_id,  # 卖家
            status="in_progress",  # 直接进入进行中状态
            is_flexible=1,  # 灵活时间模式
            deadline=None,  # 无截止日期
            images=json.dumps(images) if images else None,
        )
        db.add(new_task)
        await db.flush()  # 获取任务ID
        
        # 更新商品状态为sold（使用条件更新防止并发超卖）
        update_result = await db.execute(
            update(models.FleaMarketItem)
            .where(
                and_(
                    models.FleaMarketItem.id == db_id,
                    models.FleaMarketItem.status == "active"
                )
            )
            .values(
                status="sold",
                sold_task_id=new_task.id
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
        
        # 自动拒绝其他pending状态的申请
        await db.execute(
            update(models.FleaMarketPurchaseRequest)
            .where(
                and_(
                    models.FleaMarketPurchaseRequest.item_id == db_id,
                    models.FleaMarketPurchaseRequest.status == "pending",
                    models.FleaMarketPurchaseRequest.id != accept_data.purchase_request_id
                )
            )
            .values(status="rejected")
        )
        
        await db.commit()
        
        return {
            "success": True,
            "data": {
                "task_id": format_flea_market_id(new_task.id),
                "item_status": "sold",
                "final_price": float(final_price),
                "purchase_request_status": "accepted"
            },
            "message": "购买申请已接受，任务已创建"
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


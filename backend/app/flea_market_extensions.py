"""
跳蚤市场扩展功能
包含：通知、缓存、敏感词过滤等
"""
import json
import logging
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app import models
from app import async_crud

logger = logging.getLogger(__name__)

# 敏感词列表（基础版本，可以扩展为从数据库或配置文件加载）
SENSITIVE_WORDS = [
    # 可以添加敏感词
]


def contains_sensitive_words(text: str) -> bool:
    """检查文本是否包含敏感词"""
    if not text:
        return False
    
    text_lower = text.lower()
    for word in SENSITIVE_WORDS:
        if word.lower() in text_lower:
            return True
    return False


def filter_sensitive_words(text: str) -> str:
    """过滤敏感词（用*替换）"""
    if not text:
        return text
    
    result = text
    for word in SENSITIVE_WORDS:
        if word.lower() in result.lower():
            # 替换敏感词
            import re
            pattern = re.compile(re.escape(word), re.IGNORECASE)
            result = pattern.sub('*' * len(word), result)
    return result


async def send_purchase_request_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    proposed_price: Optional[float] = None,
    message: Optional[str] = None
):
    """发送购买申请通知给卖家"""
    try:
        # 获取卖家信息
        seller = await async_crud.async_user_crud.get_user_by_id(db, item.seller_id)
        if not seller:
            return
        
        # 构建通知内容
        buyer_name = buyer.name or f"用户{buyer.id}"
        content_parts = [f"{buyer_name} 申请购买您的商品「{item.title}」"]
        
        if proposed_price:
            content_parts.append(f"议价金额：£{proposed_price:.2f}")
        else:
            content_parts.append(f"原价：£{float(item.price):.2f}")
        
        if message:
            content_parts.append(f"留言：{message}")
        
        notification_content = "\n".join(content_parts)
        
        # 创建通知
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=item.seller_id,
            notification_type="flea_market_purchase_request",
            title="新的购买申请",
            content=notification_content,
            related_id=str(item.id),
        )
        
        logger.info(f"购买申请通知已发送给卖家 {item.seller_id}")
    except Exception as e:
        logger.error(f"发送购买申请通知失败: {e}")


async def send_purchase_accepted_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    task_id: int,
    final_price: float
):
    """发送购买申请接受通知给买家"""
    try:
        content = f"您的购买申请已被接受！\n商品：{item.title}\n成交价：£{final_price:.2f}\n任务已创建，可以开始交易了"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=buyer.id,
            notification_type="flea_market_purchase_accepted",
            title="购买申请已接受",
            content=content,
            related_id=str(task_id),
        )
        
        logger.info(f"购买接受通知已发送给买家 {buyer.id}")
    except Exception as e:
        logger.error(f"发送购买接受通知失败: {e}")


async def send_direct_purchase_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    task_id: int
):
    """发送直接购买通知给卖家"""
    try:
        buyer_name = buyer.name or f"用户{buyer.id}"
        content = f"{buyer_name} 直接购买了您的商品「{item.title}」\n任务已创建，可以开始交易了"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=item.seller_id,
            notification_type="flea_market_direct_purchase",
            title="商品已售出",
            content=content,
            related_id=str(task_id),
        )
        
        logger.info(f"直接购买通知已发送给卖家 {item.seller_id}")
    except Exception as e:
        logger.error(f"发送直接购买通知失败: {e}")


def get_cache_key_for_items(page: int, pageSize: int, category: Optional[str] = None, 
                            keyword: Optional[str] = None, status: str = "active") -> str:
    """生成商品列表缓存键"""
    key_parts = ["flea_market_items", f"page_{page}", f"size_{pageSize}", f"status_{status}"]
    if category:
        key_parts.append(f"cat_{category}")
    if keyword:
        import hashlib
        keyword_hash = hashlib.md5(keyword.encode()).hexdigest()[:8]
        key_parts.append(f"kw_{keyword_hash}")
    return ":".join(key_parts)


def get_cache_key_for_item_detail(item_id: int) -> str:
    """生成商品详情缓存键"""
    return f"flea_market_item:{item_id}"


def invalidate_item_cache(item_id: Optional[int] = None):
    """使商品相关缓存失效"""
    try:
        from app.redis_cache import redis_cache
        
        if item_id:
            # 失效特定商品的缓存
            redis_cache.delete(get_cache_key_for_item_detail(item_id))
        
        # 失效所有商品列表缓存
        redis_cache.delete_pattern("flea_market_items:*")
        logger.debug(f"已清除商品缓存: item_id={item_id}")
    except Exception as e:
        logger.warning(f"清除商品缓存失败: {e}")


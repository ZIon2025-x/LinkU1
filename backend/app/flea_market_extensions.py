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
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            from app.id_generator import format_flea_market_id
            send_push_notification_async_safe(
                async_db=db,
                user_id=item.seller_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="flea_market_purchase_request",
                data={
                    "item_id": format_flea_market_id(item.id)  # 使用格式化的ID（S0020格式）以便iOS客户端正确跳转
                },
                template_vars={
                    "buyer_name": buyer_name,
                    "item_title": item.title
                }
            )
        except Exception as e:
            logger.warning(f"发送购买申请推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
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
    """发送购买申请接受通知给买家（包含支付提醒）"""
    try:
        # 查询任务信息，获取支付过期时间
        task = await db.get(models.Task, task_id)
        payment_expires_info = ""
        if task and task.status == "pending_payment" and task.payment_expires_at:
            from app.utils.time_utils import format_iso_utc
            expires_at_str = format_iso_utc(task.payment_expires_at)
            payment_expires_info = f"\n请尽快完成支付以开始交易。支付过期时间：{expires_at_str}\n请在30分钟内完成支付，否则任务将自动取消。"
        
        content = f"您的购买申请已被接受！\n商品：{item.title}\n成交价：£{final_price:.2f}\n任务已创建。{payment_expires_info}"
        
        title = "购买申请已接受，请完成支付" if task and task.status == "pending_payment" else "购买申请已接受"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=buyer.id,
            notification_type="flea_market_purchase_accepted",
            title=title,
            content=content,
            related_id=str(task_id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            from app.id_generator import format_flea_market_id
            push_title = "购买申请已接受，请完成支付" if task and task.status == "pending_payment" else None
            push_body = f"商品「{item.title}」的购买申请已被接受，请尽快完成支付" if task and task.status == "pending_payment" else None
            
            send_push_notification_async_safe(
                async_db=db,
                user_id=buyer.id,
                title=push_title,  # 如果需要支付，使用自定义标题
                body=push_body,  # 如果需要支付，使用自定义内容
                notification_type="flea_market_purchase_accepted",
                data={
                    "item_id": format_flea_market_id(item.id),  # 使用格式化的ID（S0020格式）以便iOS客户端正确跳转
                    "task_id": task_id
                },
                template_vars={
                    "item_title": item.title,
                    "task_id": task_id
                }
            )
        except Exception as e:
            logger.warning(f"发送购买接受推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        logger.info(f"购买接受通知已发送给买家 {buyer.id}")
    except Exception as e:
        logger.error(f"发送购买接受通知失败: {e}")


async def send_direct_purchase_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    task_id: int
):
    """发送直接购买（待付款）通知给卖家
    
    ⚠️ 此时买家尚未完成支付，商品状态为 reserved（预留），不是 sold。
    "商品已售出"通知应在支付成功后（webhook）发送，此处仅通知卖家有买家下单。
    """
    try:
        buyer_name = buyer.name or f"用户{buyer.id}"
        content = f"{buyer_name} 下单了您的商品「{item.title}」，等待买家完成付款"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=item.seller_id,
            notification_type="flea_market_direct_purchase",
            title="商品已被下单",
            content=content,
            related_id=str(task_id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            from app.id_generator import format_flea_market_id
            send_push_notification_async_safe(
                async_db=db,
                user_id=item.seller_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="flea_market_direct_purchase",
                data={
                    "item_id": format_flea_market_id(item.id),
                    "task_id": task_id
                },
                template_vars={
                    "buyer_name": buyer_name,
                    "item_title": item.title
                }
            )
        except Exception as e:
            logger.warning(f"发送直接购买推送通知失败: {e}")
        
        logger.info(f"直接购买待付款通知已发送给卖家 {item.seller_id}")
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


async def send_seller_counter_offer_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    seller: models.User,
    counter_price: float
):
    """发送卖家议价通知给买家"""
    try:
        seller_name = seller.name if seller else f"用户{seller.id}" if seller else "卖家"
        content = f"卖家对您的购买申请提出了新价格。\n商品：{item.title}\n卖家议价：£{counter_price:.2f}\n原价：£{float(item.price):.2f}\n\n请查看并决定是否接受。"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=buyer.id,
            notification_type="flea_market_seller_counter_offer",
            title="卖家提出新价格",
            content=content,
            related_id=str(item.id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            from app.id_generator import format_flea_market_id
            send_push_notification_async_safe(
                async_db=db,
                user_id=buyer.id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="flea_market_seller_counter_offer",
                data={
                    "item_id": format_flea_market_id(item.id)  # 使用格式化的ID（S0020格式）以便iOS客户端正确跳转
                },
                template_vars={
                    "seller_name": seller_name,
                    "item_title": item.title,
                    "counter_price": counter_price
                }
            )
        except Exception as e:
            logger.warning(f"发送卖家议价推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        logger.info(f"卖家议价通知已发送给买家 {buyer.id}")
    except Exception as e:
        logger.error(f"发送卖家议价通知失败: {e}")


async def send_purchase_rejected_notification(
    db: AsyncSession,
    item: models.FleaMarketItem,
    buyer: models.User,
    seller: models.User
):
    """发送购买申请被拒绝通知给买家"""
    try:
        seller_name = seller.name if seller else f"用户{seller.id}" if seller else "卖家"
        content = f"很抱歉，您的购买申请已被拒绝。\n商品：{item.title}\n卖家：{seller_name}\n\n您可以继续浏览其他商品。"
        
        await async_crud.async_notification_crud.create_notification(
            db=db,
            user_id=buyer.id,
            notification_type="flea_market_purchase_rejected",
            title="购买申请已拒绝",
            content=content,
            related_id=str(item.id),
        )
        
        # 发送推送通知
        try:
            from app.push_notification_service import send_push_notification_async_safe
            from app.id_generator import format_flea_market_id
            send_push_notification_async_safe(
                async_db=db,
                user_id=buyer.id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="flea_market_purchase_rejected",
                data={
                    "item_id": format_flea_market_id(item.id)  # 使用格式化的ID（S0020格式）以便iOS客户端正确跳转
                },
                template_vars={
                    "seller_name": seller_name,
                    "item_title": item.title
                }
            )
        except Exception as e:
            logger.warning(f"发送购买拒绝推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        logger.info(f"购买拒绝通知已发送给买家 {buyer.id}")
    except Exception as e:
        logger.error(f"发送购买拒绝通知失败: {e}")


"""达人评价回复 + 优惠券管理路由"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure_async_csrf
from app.models_expert import Expert, ExpertMember
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_marketing_router = APIRouter(tags=["expert-marketing"])


# ==================== 评价回复 ====================

@expert_marketing_router.post("/api/reviews/{review_id}/reply")
async def reply_to_review(
    review_id: int,
    body: dict,  # {"content": "回复内容"}
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人回复评价（Owner/Admin）"""
    content = body.get("content")
    if not content or not content.strip():
        raise HTTPException(status_code=400, detail="回复内容不能为空")

    result = await db.execute(
        select(models.Review).where(models.Review.id == review_id)
    )
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="评价不存在")

    if review.reply_content:
        raise HTTPException(status_code=400, detail="该评价已回复，不可重复回复")

    # 检查权限：评价的 expert_id 对应的达人团队的 Owner/Admin
    if not review.expert_id:
        raise HTTPException(status_code=403, detail="仅达人服务的评价可回复")

    await _get_member_or_403(db, review.expert_id, current_user.id, required_roles=["owner", "admin"])

    review.reply_content = content.strip()
    review.reply_at = get_utc_time()
    review.reply_by = current_user.id
    await db.commit()

    return {"detail": "回复成功"}


# ==================== 达人优惠券 ====================

@expert_marketing_router.get("/api/experts/{expert_id}/coupons")
async def list_expert_coupons(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人优惠券列表（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    query = select(models.Coupon).where(models.Coupon.expert_id == expert_id)
    if status_filter:
        query = query.where(models.Coupon.status == status_filter)
    query = query.order_by(models.Coupon.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    coupons = result.scalars().all()

    return [
        {
            "id": c.id,
            "code": c.code,
            "name": c.name,
            "description": c.description,
            "type": c.type,
            "discount_value": c.discount_value,
            "min_amount": c.min_amount,
            "max_discount": c.max_discount,
            "currency": c.currency,
            "total_quantity": c.total_quantity,
            "per_user_limit": c.per_user_limit,
            "valid_from": c.valid_from.isoformat() if c.valid_from else None,
            "valid_until": c.valid_until.isoformat() if c.valid_until else None,
            "status": c.status,
            "expert_id": c.expert_id,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        }
        for c in coupons
    ]


@expert_marketing_router.post("/api/experts/{expert_id}/coupons", status_code=201)
async def create_expert_coupon(
    expert_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建达人优惠券（Owner/Admin，免审核）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    required_fields = ["code", "name", "type", "discount_value", "valid_from", "valid_until"]
    for field in required_fields:
        if field not in body:
            raise HTTPException(status_code=400, detail=f"缺少必填字段: {field}")

    from datetime import datetime
    coupon = models.Coupon(
        code=body["code"],
        name=body["name"],
        description=body.get("description"),
        type=body["type"],
        discount_value=body["discount_value"],
        min_amount=body.get("min_amount", 0),
        max_discount=body.get("max_discount"),
        currency=body.get("currency", "GBP"),
        total_quantity=body.get("total_quantity"),
        per_user_limit=body.get("per_user_limit", 1),
        valid_from=datetime.fromisoformat(body["valid_from"]),
        valid_until=datetime.fromisoformat(body["valid_until"]),
        status="active",
        expert_id=expert_id,
        distribution_type=body.get("distribution_type", "public"),
    )
    db.add(coupon)
    await db.commit()
    await db.refresh(coupon)
    return {"id": coupon.id, "code": coupon.code}


@expert_marketing_router.put("/api/experts/{expert_id}/coupons/{coupon_id}")
async def update_expert_coupon(
    expert_id: str,
    coupon_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """编辑达人优惠券（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.Coupon).where(
            and_(models.Coupon.id == coupon_id, models.Coupon.expert_id == expert_id)
        )
    )
    coupon = result.scalar_one_or_none()
    if not coupon:
        raise HTTPException(status_code=404, detail="优惠券不存在")

    allowed_fields = ["name", "description", "status", "total_quantity", "per_user_limit"]
    for field in allowed_fields:
        if field in body:
            setattr(coupon, field, body[field])
    coupon.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "优惠券已更新"}


@expert_marketing_router.delete("/api/experts/{expert_id}/coupons/{coupon_id}")
async def deactivate_expert_coupon(
    expert_id: str,
    coupon_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """停用达人优惠券（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.Coupon).where(
            and_(models.Coupon.id == coupon_id, models.Coupon.expert_id == expert_id)
        )
    )
    coupon = result.scalar_one_or_none()
    if not coupon:
        raise HTTPException(status_code=404, detail="优惠券不存在")

    coupon.status = "inactive"
    coupon.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "优惠券已停用"}

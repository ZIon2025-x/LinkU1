"""
自定义排行榜API路由
实现用户驱动的动态排行榜系统
"""

import json
import math
import os
import shutil
import logging
from pathlib import Path
from fastapi import APIRouter, Depends, Query, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, update, delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload
from typing import Optional, List
from app.deps import get_async_db_dependency
from app import models, schemas
from app.utils.time_utils import get_utc_time
from app.rate_limiting import rate_limit
from app.config import Config

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/custom-leaderboards", tags=["Custom Leaderboards"])


# ==================== 认证依赖 ====================

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


async def get_current_user_optional(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> Optional[models.User]:
    """可选用户认证（异步版本）"""
    try:
        return await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        return None


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


# ==================== 投票得分计算 ====================

def calculate_vote_score(item: models.LeaderboardItem):
    """
    计算竞品的投票得分（用于排序）
    注意：这是一个纯计算函数，不执行数据库操作，由调用方负责commit
    """
    total_votes = item.upvotes + item.downvotes
    
    if total_votes == 0:
        item.vote_score = 0.0
        return
    
    # Wilson Score Lower Bound算法
    z = 1.96
    p = item.upvotes / total_votes
    n = total_votes
    
    denominator = 1 + (z * z / n)
    numerator = p + (z * z / (2 * n)) - z * math.sqrt((p * (1 - p) + z * z / (4 * n)) / n)
    wilson_score = numerator / denominator
    
    # 考虑时间衰减
    days_since_created = max(0, (get_utc_time() - item.created_at).days)
    time_factor = 1.0 / (1.0 + days_since_created * 0.01)  # 每天衰减1%
    
    item.vote_score = wilson_score * 100 * time_factor


# ==================== 管理员专用接口（查看所有状态的榜单） ====================

@router.get("/admin/all", response_model=List[schemas.CustomLeaderboardOut])
async def get_all_leaderboards_admin(
    location: Optional[str] = Query(None, description="地区筛选"),
    status: Optional[str] = Query("all", description="状态筛选：active, pending, rejected, all"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员专用：获取所有状态的榜单列表"""
    query = select(models.CustomLeaderboard)
    
    if status == "active":
        query = query.where(models.CustomLeaderboard.status == "active")
    elif status == "pending":
        query = query.where(models.CustomLeaderboard.status == "pending")
    elif status == "rejected":
        query = query.where(models.CustomLeaderboard.status == "rejected")
    # status == "all" 时显示所有
    
    if location:
        query = query.where(models.CustomLeaderboard.location == location)
    
    query = query.order_by(models.CustomLeaderboard.created_at.desc())
    query = query.options(selectinload(models.CustomLeaderboard.applicant))
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    leaderboards = result.scalars().all()
    
    # 构建申请者信息并手动构建响应对象
    from app.forum_routes import build_user_info
    
    leaderboard_items = []
    for leaderboard in leaderboards:
        applicant_info = None
        if leaderboard.applicant:
            applicant_info = await build_user_info(db, leaderboard.applicant)
        
        leaderboard_dict = schemas.CustomLeaderboardOut(
            id=leaderboard.id,
            name=leaderboard.name,
            location=leaderboard.location,
            description=leaderboard.description,
            cover_image=leaderboard.cover_image,
            applicant_id=leaderboard.applicant_id,
            applicant=applicant_info,
            status=leaderboard.status,
            item_count=leaderboard.item_count,
            vote_count=leaderboard.vote_count,
            view_count=leaderboard.view_count,
            created_at=leaderboard.created_at,
            updated_at=leaderboard.updated_at
        )
        leaderboard_items.append(leaderboard_dict)
    
    return leaderboard_items


# ==================== 管理员查看投票记录 ====================

@router.get("/admin/votes", response_model=List[schemas.LeaderboardVoteAdminOut])
async def get_votes_admin(
    item_id: Optional[int] = Query(None, description="竞品ID筛选"),
    leaderboard_id: Optional[int] = Query(None, description="榜单ID筛选"),
    is_anonymous: Optional[bool] = Query(None, description="是否匿名筛选"),
    keyword: Optional[str] = Query(None, description="关键词搜索（用户名/留言内容）"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员专用：查看投票记录列表（包含匿名标识，用于审计）"""
    query = select(models.LeaderboardVote)
    
    if item_id:
        query = query.where(models.LeaderboardVote.item_id == item_id)
    
    if leaderboard_id:
        query = query.join(
            models.LeaderboardItem,
            models.LeaderboardItem.id == models.LeaderboardVote.item_id
        ).where(models.LeaderboardItem.leaderboard_id == leaderboard_id)
    
    if is_anonymous is not None:
        query = query.where(models.LeaderboardVote.is_anonymous == is_anonymous)
    
    if keyword:
        # 清理和验证搜索关键词
        keyword = keyword.strip()
        if len(keyword) < 1:
            keyword = None
        elif len(keyword) > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="搜索关键词不能超过100个字符"
            )
        
        if keyword:
            keyword_pattern = f"%{keyword}%"
            query = query.where(
                or_(
                    models.LeaderboardVote.comment.ilike(keyword_pattern),
                    models.LeaderboardVote.user_id.ilike(keyword_pattern)
                )
            )
    
    query = query.order_by(models.LeaderboardVote.created_at.desc())
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    votes = result.scalars().all()
    
    votes_out = []
    for vote in votes:
        vote_dict = {
            "id": vote.id,
            "item_id": vote.item_id,
            "user_id": vote.user_id,
            "vote_type": vote.vote_type,
            "comment": vote.comment,
            "is_anonymous": vote.is_anonymous,
            "created_at": vote.created_at,
            "updated_at": vote.updated_at
        }
        votes_out.append(vote_dict)
    
    return votes_out


# ==================== 管理员获取竞品列表 ====================

@router.get("/admin/items", response_model=schemas.LeaderboardItemListResponse)
async def get_items_admin(
    leaderboard_id: Optional[str] = Query(None, description="榜单ID筛选"),
    status: Optional[str] = Query("all", description="状态筛选：approved, all"),
    keyword: Optional[str] = Query(None, description="关键词搜索（竞品名称、描述）"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员专用：获取竞品列表"""
    # 处理 leaderboard_id：将空字符串转换为 None，并尝试解析为整数
    leaderboard_id_int = None
    if leaderboard_id is not None:
        # 如果是字符串，去除空格
        if isinstance(leaderboard_id, str):
            leaderboard_id = leaderboard_id.strip()
            if not leaderboard_id:  # 空字符串
                leaderboard_id = None
        # 如果仍然有值，尝试解析为整数
        if leaderboard_id is not None:
            try:
                leaderboard_id_int = int(leaderboard_id)
            except (ValueError, TypeError):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="榜单ID必须是有效的整数"
                )
    
    base_query = select(models.LeaderboardItem)
    
    if leaderboard_id_int:
        base_query = base_query.where(models.LeaderboardItem.leaderboard_id == leaderboard_id_int)
    
    if status == "approved":
        base_query = base_query.where(models.LeaderboardItem.status == "approved")
    # status == "all" 时显示所有
    
    if keyword:
        keyword = keyword.strip()
        if len(keyword) > 0:
            keyword_pattern = f"%{keyword}%"
            base_query = base_query.where(
                or_(
                    models.LeaderboardItem.name.ilike(keyword_pattern),
                    models.LeaderboardItem.description.ilike(keyword_pattern)
                )
            )
    
    # 计算总数
    count_query = select(func.count()).select_from(base_query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 排序：按创建时间倒序
    base_query = base_query.order_by(models.LeaderboardItem.created_at.desc())
    
    # 分页
    query = base_query.offset(offset).limit(limit)
    result = await db.execute(query)
    items = result.scalars().all()
    
    # 构建返回数据
    items_out = []
    for item in items:
        try:
            images_list = None
            if item.images:
                try:
                    images_list = json.loads(item.images)
                except Exception:
                    images_list = None
            
            # 确保 created_at 和 updated_at 不为 None（处理旧数据）
            created_at = item.created_at if item.created_at is not None else get_utc_time()
            updated_at = item.updated_at if item.updated_at is not None else get_utc_time()
            
            # 确保所有必需字段的类型正确，特别是 leaderboard_id 必须是整数
            # 如果转换失败，跳过这条记录并记录错误
            if item.leaderboard_id is None:
                logger.warning(f"跳过记录 {item.id}：leaderboard_id 为 None")
                continue
            
            try:
                leaderboard_id_int = int(item.leaderboard_id)
            except (ValueError, TypeError) as e:
                logger.error(f"跳过记录 {item.id}：无法将 leaderboard_id 转换为整数: {item.leaderboard_id} (类型: {type(item.leaderboard_id)}), 错误: {e}")
                continue
            
            item_dict = {
                "id": int(item.id) if item.id is not None else 0,
                "leaderboard_id": leaderboard_id_int,
                "name": str(item.name) if item.name else "",
                "description": item.description if item.description else None,
                "address": item.address if item.address else None,
                "phone": item.phone if item.phone else None,
                "website": item.website if item.website else None,
                "images": images_list,
                "submitted_by": str(item.submitted_by) if item.submitted_by else "",
                "status": str(item.status) if item.status else "approved",
                "upvotes": int(item.upvotes) if item.upvotes is not None else 0,
                "downvotes": int(item.downvotes) if item.downvotes is not None else 0,
                "net_votes": int(item.net_votes) if item.net_votes is not None else 0,
                "vote_score": float(item.vote_score) if item.vote_score is not None else 0.0,
                "user_vote": None,
                "user_vote_comment": None,
                "user_vote_is_anonymous": None,
                "display_comment": None,
                "display_comment_type": None,
                "display_comment_info": None,
                "created_at": created_at,
                "updated_at": updated_at
            }
            items_out.append(item_dict)
        except Exception as e:
            logger.error(f"处理竞品记录 {item.id} 时出错: {e}", exc_info=True)
            continue
    
    # 使用 Pydantic 模型进行验证，确保类型正确
    # 先验证每个 item，如果验证失败会抛出异常，这样我们可以捕获并记录
    validated_items = []
    for idx, item_dict in enumerate(items_out):
        try:
            # 记录第一个 item 的详细信息以便调试
            if idx == 0 and items_out:
                logger.debug(f"验证第一个竞品数据: leaderboard_id={item_dict.get('leaderboard_id')}, 类型={type(item_dict.get('leaderboard_id'))}")
            validated_item = schemas.LeaderboardItemOut(**item_dict)
            validated_items.append(validated_item)
        except Exception as e:
            logger.error(f"验证竞品数据失败 (索引 {idx}): leaderboard_id={item_dict.get('leaderboard_id')}, 类型={type(item_dict.get('leaderboard_id'))}, 完整数据={item_dict}, 错误: {e}", exc_info=True)
            # 跳过验证失败的记录
            continue
    
    return schemas.LeaderboardItemListResponse(
        items=validated_items,
        total=total,
        limit=limit,
        offset=offset,
        has_more=offset + limit < total
    )


# ==================== 榜单申请 ====================

@router.post("/apply", response_model=schemas.CustomLeaderboardOut)
@rate_limit("api_write", limit=5, window=300)  # 5次/5分钟
async def apply_leaderboard(
    leaderboard_data: schemas.CustomLeaderboardCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户申请创建新榜单"""
    # 输入验证和清理
    leaderboard_data.name = leaderboard_data.name.strip() if leaderboard_data.name else ""
    if not leaderboard_data.name or len(leaderboard_data.name) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="榜单名称至少需要2个字符"
        )
    if len(leaderboard_data.name) > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="榜单名称不能超过100个字符"
        )
    
    leaderboard_data.location = leaderboard_data.location.strip() if leaderboard_data.location else ""
    if not leaderboard_data.location:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请选择地区"
        )
    
    if leaderboard_data.description:
        leaderboard_data.description = leaderboard_data.description.strip()
        if len(leaderboard_data.description) > 2000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="榜单描述不能超过2000个字符"
            )
    
    if leaderboard_data.application_reason:
        leaderboard_data.application_reason = leaderboard_data.application_reason.strip()
        if len(leaderboard_data.application_reason) > 1000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="申请理由不能超过1000个字符"
            )
    
    existing = await db.execute(
        select(models.CustomLeaderboard).where(
            and_(
                models.CustomLeaderboard.name == leaderboard_data.name,
                models.CustomLeaderboard.location == leaderboard_data.location,
                models.CustomLeaderboard.status.in_(["pending", "active"])
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该地区已存在相同名称的榜单申请或已激活榜单"
        )
    
    new_leaderboard = models.CustomLeaderboard(
        name=leaderboard_data.name,
        location=leaderboard_data.location,
        description=leaderboard_data.description,
        cover_image=leaderboard_data.cover_image,
        application_reason=leaderboard_data.application_reason,
        applicant_id=current_user.id,
        status="pending"
    )
    
    db.add(new_leaderboard)
    
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该地区已存在相同名称的榜单申请或已激活榜单"
        )
    
    await db.refresh(new_leaderboard)
    
    # 需要重新加载关系，因为 refresh 不会加载关系
    result = await db.execute(
        select(models.CustomLeaderboard)
        .options(selectinload(models.CustomLeaderboard.applicant))
        .where(models.CustomLeaderboard.id == new_leaderboard.id)
    )
    new_leaderboard = result.scalar_one()
    
    # 构建申请者信息
    from app.forum_routes import build_user_info
    applicant_info = None
    if new_leaderboard.applicant:
        applicant_info = await build_user_info(db, new_leaderboard.applicant)
    
    # 手动构建响应对象，避免 Pydantic 尝试访问未加载的关系
    return schemas.CustomLeaderboardOut(
        id=new_leaderboard.id,
        name=new_leaderboard.name,
        location=new_leaderboard.location,
        description=new_leaderboard.description,
        cover_image=new_leaderboard.cover_image,
        applicant_id=new_leaderboard.applicant_id,
        applicant=applicant_info,
        status=new_leaderboard.status,
        item_count=new_leaderboard.item_count,
        vote_count=new_leaderboard.vote_count,
        view_count=new_leaderboard.view_count,
        created_at=new_leaderboard.created_at,
        updated_at=new_leaderboard.updated_at
    )


# ==================== 榜单列表 ====================

@router.get("", response_model=schemas.CustomLeaderboardListResponse)
async def get_leaderboards(
    location: Optional[str] = Query(None, description="地区筛选"),
    status: Optional[str] = Query("active", description="状态筛选：active（公开接口仅支持active）"),
    keyword: Optional[str] = Query(None, description="关键词搜索（榜单名称、描述）"),
    sort: str = Query("latest", regex="^(latest|hot|votes|items)$", description="排序方式：latest(最新), hot(热门), votes(投票数), items(竞品数)"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取榜单列表（前端显示，仅返回active状态的榜单）"""
    # 基础查询
    base_query = select(models.CustomLeaderboard)
    
    if status and status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="公开接口仅支持查看active状态的榜单，如需查看其他状态请使用管理员接口"
        )
    
    base_query = base_query.where(models.CustomLeaderboard.status == "active")
    
    if location:
        base_query = base_query.where(models.CustomLeaderboard.location == location)
    
    if keyword:
        # 清理和验证搜索关键词
        keyword = keyword.strip()
        if len(keyword) < 1:
            keyword = None
        elif len(keyword) > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="搜索关键词不能超过100个字符"
            )
        
        if keyword:
            keyword_pattern = f"%{keyword}%"
            base_query = base_query.where(
                or_(
                    models.CustomLeaderboard.name.ilike(keyword_pattern),
                    models.CustomLeaderboard.description.ilike(keyword_pattern)
                )
            )
    
    # 计算总数
    count_query = select(func.count()).select_from(base_query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 排序
    if sort == "latest":
        base_query = base_query.order_by(models.CustomLeaderboard.created_at.desc())
    elif sort == "hot":
        # 热门排序：综合投票数、竞品数、浏览量
        base_query = base_query.order_by(
            (models.CustomLeaderboard.vote_count * 2 + 
             models.CustomLeaderboard.item_count + 
             models.CustomLeaderboard.view_count * 0.1).desc(),
            models.CustomLeaderboard.created_at.desc()
        )
    elif sort == "votes":
        base_query = base_query.order_by(models.CustomLeaderboard.vote_count.desc())
    elif sort == "items":
        base_query = base_query.order_by(models.CustomLeaderboard.item_count.desc())
    
    # 加载申请者关系
    query = base_query.options(selectinload(models.CustomLeaderboard.applicant))
    
    # 分页
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    leaderboards = result.scalars().all()
    
    # 计算每个榜单的浏览量（数据库值 + Redis增量）并构建返回数据
    from app.forum_routes import build_user_info
    
    leaderboard_items = []
    for leaderboard in leaderboards:
        # 计算浏览量
        try:
            from app.redis_cache import get_redis_client
            redis_client = get_redis_client()
            
            if redis_client:
                redis_key = f"leaderboard:view_count:{leaderboard.id}"
                redis_view_count = int(redis_client.get(redis_key) or 0)
                if redis_view_count > 0:
                    display_view_count = leaderboard.view_count + redis_view_count
                else:
                    display_view_count = leaderboard.view_count
            else:
                display_view_count = leaderboard.view_count
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.debug(f"Redis view count query failed, using DB values: {e}")
            display_view_count = leaderboard.view_count
        
        # 构建申请者信息
        applicant_info = None
        if leaderboard.applicant:
            applicant_info = await build_user_info(db, leaderboard.applicant)
        
        # 创建返回对象
        leaderboard_dict = {
            "id": leaderboard.id,
            "name": leaderboard.name,
            "location": leaderboard.location,
            "description": leaderboard.description,
            "cover_image": leaderboard.cover_image,
            "applicant_id": leaderboard.applicant_id,
            "applicant": applicant_info,
            "status": leaderboard.status,
            "item_count": leaderboard.item_count,
            "vote_count": leaderboard.vote_count,
            "view_count": display_view_count,
            "created_at": leaderboard.created_at,
            "updated_at": leaderboard.updated_at
        }
        leaderboard_items.append(leaderboard_dict)
    
    return {
        "items": leaderboard_items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": offset + limit < total
    }


# ==================== 榜单详情 ====================

@router.get("/{leaderboard_id}", response_model=schemas.CustomLeaderboardOut)
async def get_leaderboard_detail(
    leaderboard_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取榜单详情"""
    # 加载申请者关系
    result = await db.execute(
        select(models.CustomLeaderboard)
        .options(selectinload(models.CustomLeaderboard.applicant))
        .where(models.CustomLeaderboard.id == leaderboard_id)
    )
    leaderboard = result.scalar_one_or_none()
    
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    # 增加浏览次数
    # 优化方案：使用 Redis 累加，定时批量落库（由 Celery 任务处理）
    # 当前实现：如果 Redis 可用则使用 Redis，否则直接更新数据库
    redis_view_count = 0
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            # 使用 Redis 累加浏览数（存储增量）
            redis_key = f"leaderboard:view_count:{leaderboard_id}"
            # incr 返回增加后的值（如果 key 不存在则创建并设置为1）
            redis_client.incr(redis_key)
            # 获取 Redis 中的总值（包括本次增加的1）
            redis_view_count = int(redis_client.get(redis_key) or 0)
            # 设置过期时间（7天），防止 key 无限增长
            redis_client.expire(redis_key, 7 * 24 * 3600)
            # 注意：Redis 中的增量会由后台任务定期同步到数据库
            # 这里不更新数据库，减少数据库写入压力
        else:
            # Redis 不可用，直接更新数据库
            leaderboard.view_count += 1
            await db.flush()
    except Exception as e:
        # Redis 操作失败，回退到直接更新数据库
        import logging
        logger = logging.getLogger(__name__)
        logger.debug(f"Redis view count increment failed, falling back to DB: {e}")
        leaderboard.view_count += 1
        await db.flush()
    
    await db.commit()
    
    # 刷新对象以获取最新的 view_count（如果直接更新了数据库）
    if redis_view_count == 0:
        await db.refresh(leaderboard)
    
    # 计算返回给用户的浏览量（数据库值 + Redis中的增量）
    display_view_count = leaderboard.view_count
    if redis_view_count > 0:
        # 如果使用了 Redis，返回数据库值 + Redis 中的增量
        display_view_count = leaderboard.view_count + redis_view_count
    
    # 构建申请者信息
    from app.forum_routes import build_user_info
    applicant_info = None
    if leaderboard.applicant:
        applicant_info = await build_user_info(db, leaderboard.applicant)
    
    # 创建返回对象，使用计算后的浏览量（格式化显示）
    result = schemas.CustomLeaderboardOut(
        id=leaderboard.id,
        name=leaderboard.name,
        location=leaderboard.location,
        description=leaderboard.description,
        cover_image=leaderboard.cover_image,
        applicant_id=leaderboard.applicant_id,
        applicant=applicant_info,
        status=leaderboard.status,
        item_count=leaderboard.item_count,
        vote_count=leaderboard.vote_count,
        view_count=display_view_count,
        created_at=leaderboard.created_at,
        updated_at=leaderboard.updated_at
    )
    
    return result


# ==================== 榜单审核（管理员） ====================

@router.post("/{leaderboard_id}/review")
async def review_leaderboard(
    leaderboard_id: int,
    action: str = Query(..., regex="^(approve|reject)$"),
    comment: Optional[str] = None,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员审核榜单"""
    result = await db.execute(
        select(models.CustomLeaderboard).where(models.CustomLeaderboard.id == leaderboard_id)
    )
    leaderboard = result.scalar_one_or_none()
    
    if not leaderboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在"
        )
    
    if leaderboard.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该榜单已审核"
        )
    
    if action == "approve":
        leaderboard.status = "active"
        
        # 移动临时封面图片到正式目录并更新URL（如果使用了临时目录）
        if leaderboard.cover_image:
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_dir = Path("/data/uploads/public/images")
            else:
                base_dir = Path("uploads/public/images")
            
            # 检查是否是临时文件夹的图片
            cover_image_url = leaderboard.cover_image
            if "/uploads/images/leaderboard_covers/temp_" in cover_image_url:
                try:
                    # 从URL中提取临时路径信息
                    # URL格式: {base_url}/uploads/images/leaderboard_covers/temp_{user_id}/{filename}
                    url_parts = cover_image_url.split("/uploads/images/leaderboard_covers/")
                    if len(url_parts) == 2:
                        temp_path = url_parts[1]
                        temp_parts = temp_path.split("/")
                        if len(temp_parts) >= 2:
                            temp_user_id = temp_parts[0]  # temp_{user_id}
                            filename = temp_parts[1]  # filename
                            
                            temp_dir = base_dir / "leaderboard_covers" / temp_user_id
                            leaderboard_dir = base_dir / "leaderboard_covers" / str(leaderboard_id)
                            
                            temp_file = temp_dir / filename
                            if temp_file.exists():
                                # 创建榜单目录
                                leaderboard_dir.mkdir(parents=True, exist_ok=True)
                                
                                # 移动文件
                                leaderboard_file = leaderboard_dir / filename
                                temp_file.rename(leaderboard_file)
                                
                                # 更新URL
                                from app.config import Config
                                base_url = Config.FRONTEND_URL.rstrip('/')
                                new_url = f"{base_url}/uploads/images/leaderboard_covers/{leaderboard_id}/{filename}"
                                leaderboard.cover_image = new_url
                                
                                logger.info(f"移动临时封面图片到榜单目录并更新URL: {filename} -> {new_url}")
                            else:
                                logger.warning(f"临时封面图片文件不存在: {temp_file}")
                        else:
                            logger.warning(f"无法解析临时封面图片URL路径: {temp_path}")
                except Exception as e:
                    logger.warning(f"移动封面图片文件失败: {e}，保持原URL")
    else:
        leaderboard.status = "rejected"
        # 如果拒绝申请，清理临时封面图片
        if leaderboard.cover_image:
            cover_image_url = leaderboard.cover_image
            if "/uploads/images/leaderboard_covers/temp_" in cover_image_url:
                try:
                    # 检测部署环境
                    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
                    if RAILWAY_ENVIRONMENT:
                        base_dir = Path("/data/uploads/public/images")
                    else:
                        base_dir = Path("uploads/public/images")
                    
                    # 从URL中提取临时路径信息
                    url_parts = cover_image_url.split("/uploads/images/leaderboard_covers/")
                    if len(url_parts) == 2:
                        temp_path = url_parts[1]
                        temp_parts = temp_path.split("/")
                        if len(temp_parts) >= 2:
                            temp_user_id = temp_parts[0]  # temp_{user_id}
                            filename = temp_parts[1]  # filename
                            
                            temp_dir = base_dir / "leaderboard_covers" / temp_user_id
                            temp_file = temp_dir / filename
                            
                            if temp_file.exists():
                                temp_file.unlink()
                                logger.info(f"拒绝申请，删除临时封面图片: {temp_file}")
                                
                                # 如果文件夹为空，尝试删除它
                                try:
                                    if not any(temp_dir.iterdir()):
                                        temp_dir.rmdir()
                                        logger.info(f"删除空的临时文件夹: {temp_dir}")
                                except Exception as e:
                                    logger.debug(f"删除临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                except Exception as e:
                    logger.warning(f"清理临时封面图片失败: {e}")
    
    leaderboard.reviewed_by = current_admin.id
    leaderboard.reviewed_at = get_utc_time()
    leaderboard.review_comment = comment
    
    await db.commit()
    
    return {"message": f"榜单已{action}"}


# ==================== 新增竞品 ====================

@router.post("/items", response_model=schemas.LeaderboardItemOut)
@rate_limit("api_write", limit=10, window=60)  # 10次/分钟
async def submit_item(
    item_data: schemas.LeaderboardItemCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户在榜单中新增竞品"""
    # 输入验证和清理
    item_data.name = item_data.name.strip() if item_data.name else ""
    if not item_data.name or len(item_data.name) < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="竞品名称不能为空"
        )
    if len(item_data.name) > 200:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="竞品名称不能超过200个字符"
        )
    
    if item_data.description:
        item_data.description = item_data.description.strip()
        if len(item_data.description) > 1000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="描述不能超过1000个字符"
            )
    
    if item_data.address:
        item_data.address = item_data.address.strip()
        if len(item_data.address) > 500:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="地址不能超过500个字符"
            )
    
    if item_data.phone:
        item_data.phone = item_data.phone.strip()
        # 如果清理后为空字符串，设置为None
        if not item_data.phone:
            item_data.phone = None
        else:
            if len(item_data.phone) > 50:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="电话不能超过50个字符"
                )
    
    if item_data.website:
        item_data.website = item_data.website.strip()
        # 如果清理后为空字符串，设置为None
        if not item_data.website:
            item_data.website = None
        else:
            if len(item_data.website) > 500:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="网站地址不能超过500个字符"
                )
            # 简单的URL格式验证和自动添加协议
            if not (item_data.website.startswith('http://') or item_data.website.startswith('https://')):
                item_data.website = 'https://' + item_data.website
    
    # 验证图片数量
    if item_data.images and len(item_data.images) > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="最多只能上传5张图片"
        )
    
    leaderboard = await db.get(models.CustomLeaderboard, item_data.leaderboard_id)
    
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    existing = await db.execute(
        select(models.LeaderboardItem).where(
            and_(
                models.LeaderboardItem.leaderboard_id == item_data.leaderboard_id,
                models.LeaderboardItem.name == item_data.name,
                models.LeaderboardItem.status == "approved"
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该榜单中已存在相同名称的竞品"
        )
    
    # 处理图片字段：如果是空数组或None，保存为None；否则保存为JSON字符串
    images_json = None
    if item_data.images and len(item_data.images) > 0:
        images_json = json.dumps(item_data.images)
    
    new_item = models.LeaderboardItem(
        leaderboard_id=item_data.leaderboard_id,
        name=item_data.name,
        description=item_data.description,
        address=item_data.address,
        phone=item_data.phone,
        website=item_data.website,
        images=images_json,
        submitted_by=current_user.id,
        status="approved"
    )
    
    db.add(new_item)
    leaderboard.item_count += 1
    
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该榜单中已存在相同名称的竞品"
        )
    
    await db.refresh(new_item)
    
    # 移动临时图片到正式目录并更新URL（如果使用了临时目录）
    if item_data.images:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads/public/images")
        else:
            base_dir = Path("uploads/public/images")
        
        temp_dir = base_dir / "leaderboard_items" / f"temp_{current_user.id}"
        item_dir = base_dir / "leaderboard_items" / str(new_item.id)
        base_url = Config.FRONTEND_URL.rstrip('/')
        updated_images = []
        
        if temp_dir.exists():
            item_dir.mkdir(parents=True, exist_ok=True)
            # 移动临时目录中的图片文件并更新URL
            moved_count = 0
            for image_url in item_data.images:
                try:
                    # 检查是否是临时文件夹的图片
                    if f"/uploads/images/leaderboard_items/temp_{current_user.id}/" in image_url:
                        # 从URL中提取文件名
                        filename = image_url.split('/')[-1]
                        temp_file = temp_dir / filename
                        if temp_file.exists():
                            item_file = item_dir / filename
                            temp_file.rename(item_file)
                            moved_count += 1
                            # 更新URL为正式目录
                            new_url = f"{base_url}/uploads/images/leaderboard_items/{new_item.id}/{filename}"
                            updated_images.append(new_url)
                            logger.info(f"移动临时图片到竞品目录并更新URL: {filename} -> {new_url}")
                        else:
                            # 文件不存在，保持原URL（可能是其他来源的图片）
                            updated_images.append(image_url)
                            logger.warning(f"临时图片文件不存在，保持原URL: {filename}")
                    else:
                        # 不是临时图片，保持原URL
                        updated_images.append(image_url)
                except Exception as e:
                    logger.warning(f"移动图片文件失败: {e}，保持原URL")
                    updated_images.append(image_url)
            
            # 如果有图片被移动，更新数据库中的图片URL
            if updated_images != item_data.images:
                new_item.images = json.dumps(updated_images) if updated_images else None
                await db.commit()
                await db.refresh(new_item)
                logger.info(f"已更新竞品 {new_item.id} 的图片URL")
            # 如果没有图片被移动，但item_data.images不为空，确保保存了图片URL
            elif item_data.images and len(item_data.images) > 0:
                # 如果数据库中的images为空，但item_data.images不为空，说明初始保存时可能有问题，重新保存
                if not new_item.images:
                    new_item.images = json.dumps(item_data.images)
                    await db.commit()
                    await db.refresh(new_item)
                    logger.info(f"重新保存竞品 {new_item.id} 的图片URL")
            
            # 删除临时目录（如果为空或所有文件都已移动）
            try:
                remaining_files = list(temp_dir.iterdir())
                if not remaining_files:
                    temp_dir.rmdir()
                    logger.info(f"删除空的临时目录: {temp_dir}")
            except Exception as e:
                logger.debug(f"删除临时目录失败（可能不为空）: {temp_dir}: {e}")
    
    # 构建返回数据，解析images字段
    images_list = None
    if new_item.images:
        try:
            images_list = json.loads(new_item.images)
        except Exception:
            images_list = None
    
    # 确保 created_at 和 updated_at 不为 None（处理旧数据）
    created_at = new_item.created_at if new_item.created_at is not None else get_utc_time()
    updated_at = new_item.updated_at if new_item.updated_at is not None else get_utc_time()
    
    return {
        "id": new_item.id,
        "leaderboard_id": new_item.leaderboard_id,
        "name": new_item.name,
        "description": new_item.description,
        "address": new_item.address,
        "phone": new_item.phone,
        "website": new_item.website,
        "images": images_list,
        "submitted_by": new_item.submitted_by,
        "status": new_item.status,
        "upvotes": new_item.upvotes,
        "downvotes": new_item.downvotes,
        "net_votes": new_item.net_votes,
        "vote_score": new_item.vote_score,
        "user_vote": None,
        "user_vote_comment": None,
        "user_vote_is_anonymous": None,
        "created_at": created_at,
        "updated_at": updated_at
    }


# ==================== 获取榜单中的竞品列表 ====================

@router.get("/{leaderboard_id}/items", response_model=schemas.LeaderboardItemListResponse)
async def get_leaderboard_items(
    leaderboard_id: int,
    sort: str = Query("vote_score", regex="^(vote_score|net_votes|upvotes|created_at)$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取榜单中的竞品列表（按投票排序）"""
    leaderboard = await db.get(models.CustomLeaderboard, leaderboard_id)
    
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    base_query = select(models.LeaderboardItem).where(
        and_(
            models.LeaderboardItem.leaderboard_id == leaderboard_id,
            models.LeaderboardItem.status == "approved"
        )
    )
    
    # 计算总数
    count_query = select(func.count()).select_from(base_query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 排序
    if sort == "vote_score":
        base_query = base_query.order_by(models.LeaderboardItem.vote_score.desc())
    elif sort == "net_votes":
        base_query = base_query.order_by(models.LeaderboardItem.net_votes.desc())
    elif sort == "upvotes":
        base_query = base_query.order_by(models.LeaderboardItem.upvotes.desc())
    elif sort == "created_at":
        base_query = base_query.order_by(models.LeaderboardItem.created_at.desc())
    
    # 分页
    query = base_query.offset(offset).limit(limit)
    result = await db.execute(query)
    items = result.scalars().all()
    
    # 获取所有竞品ID
    item_ids = [item.id for item in items]
    
    user_votes = {}
    user_vote_comments = {}
    user_vote_is_anonymous = {}
    if current_user and item_ids:
        vote_result = await db.execute(
            select(models.LeaderboardVote).where(
                and_(
                    models.LeaderboardVote.item_id.in_(item_ids),
                    models.LeaderboardVote.user_id == current_user.id
                )
            )
        )
        for vote in vote_result.scalars().all():
            user_votes[vote.item_id] = vote.vote_type
            user_vote_is_anonymous[vote.item_id] = vote.is_anonymous
            if vote.comment:
                user_vote_comments[vote.item_id] = vote.comment
    
    # 查询每个竞品的最多赞留言（如果用户没有留言，用于显示）
    top_comment_votes = {}
    if item_ids:
        # 为每个竞品查询最多赞的留言（只查询有留言的记录）
        for item_id in item_ids:
            # 如果用户已经有留言，跳过
            if item_id in user_vote_comments:
                continue
            
            # 查询该竞品的最多赞留言
            top_comment_query = select(models.LeaderboardVote).where(
                and_(
                    models.LeaderboardVote.item_id == item_id,
                    models.LeaderboardVote.comment.isnot(None),
                    models.LeaderboardVote.comment != ''
                )
            ).order_by(
                models.LeaderboardVote.like_count.desc(),
                models.LeaderboardVote.created_at.desc()
            ).limit(1)
            
            top_comment_result = await db.execute(top_comment_query)
            top_comment_vote = top_comment_result.scalar_one_or_none()
            if top_comment_vote:
                top_comment_votes[item_id] = {
                    "comment": top_comment_vote.comment,
                    "vote_type": top_comment_vote.vote_type,
                    "is_anonymous": top_comment_vote.is_anonymous,
                    "like_count": top_comment_vote.like_count or 0,
                    "user_id": None if top_comment_vote.is_anonymous else top_comment_vote.user_id
                }
    
    items_out = []
    for item in items:
        images_list = None
        if item.images:
            try:
                images_list = json.loads(item.images)
            except Exception:
                images_list = None
        
        # 如果用户没有留言，使用最多赞的留言
        display_comment = None
        display_comment_type = None  # 'user' 或 'top'
        display_comment_info = None
        
        if item.id in user_vote_comments:
            # 用户有自己的留言，显示用户的留言
            display_comment = user_vote_comments.get(item.id)
            display_comment_type = 'user'
            display_comment_info = {
                "is_anonymous": user_vote_is_anonymous.get(item.id) if item.id in user_vote_is_anonymous else None
            }
        elif item.id in top_comment_votes:
            # 用户没有留言，显示最多赞的留言
            top_comment = top_comment_votes[item.id]
            display_comment = top_comment["comment"]
            display_comment_type = 'top'
            display_comment_info = {
                "vote_type": top_comment["vote_type"],
                "is_anonymous": top_comment["is_anonymous"],
                "like_count": top_comment["like_count"],
                "user_id": top_comment["user_id"]
            }
        
        # 确保 created_at 和 updated_at 不为 None（处理旧数据）
        created_at = item.created_at if item.created_at is not None else get_utc_time()
        updated_at = item.updated_at if item.updated_at is not None else get_utc_time()
        
        item_dict = {
            "id": item.id,
            "leaderboard_id": item.leaderboard_id,
            "name": item.name,
            "description": item.description,
            "address": item.address,
            "phone": item.phone,
            "website": item.website,
            "images": images_list,
            "submitted_by": item.submitted_by,
            "status": item.status,
            "upvotes": item.upvotes,
            "downvotes": item.downvotes,
            "net_votes": item.net_votes,
            "vote_score": item.vote_score,
            "user_vote": user_votes.get(item.id),
            "user_vote_comment": user_vote_comments.get(item.id),
            "user_vote_is_anonymous": user_vote_is_anonymous.get(item.id) if item.id in user_vote_is_anonymous else None,
            "display_comment": display_comment,  # 显示的留言（用户自己的或最多赞的）
            "display_comment_type": display_comment_type,  # 'user' 或 'top'
            "display_comment_info": display_comment_info,  # 留言的额外信息
            "created_at": created_at,
            "updated_at": updated_at
        }
        items_out.append(item_dict)
    
    return {
        "items": items_out,
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": offset + limit < total
    }


# ==================== 竞品详情 ====================

@router.get("/items/{item_id}", response_model=schemas.LeaderboardItemOut)
async def get_item_detail(
    item_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取竞品详情"""
    item = await db.get(models.LeaderboardItem, item_id)
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    # 检查榜单是否存在且为active状态
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    # 检查竞品状态
    if item.status != "approved":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在或未激活"
        )
    
    # 查询当前用户的投票记录（如果已登录）
    user_vote = None
    user_vote_comment = None
    user_vote_is_anonymous = None
    if current_user:
        vote_result = await db.execute(
            select(models.LeaderboardVote).where(
                and_(
                    models.LeaderboardVote.item_id == item_id,
                    models.LeaderboardVote.user_id == current_user.id
                )
            )
        )
        vote = vote_result.scalar_one_or_none()
        if vote:
            user_vote = vote.vote_type
            user_vote_comment = vote.comment
            user_vote_is_anonymous = vote.is_anonymous
    
    # 解析images字段
    images_list = None
    if item.images:
        try:
            images_list = json.loads(item.images)
        except Exception:
            images_list = None
    
    # 确保 created_at 和 updated_at 不为 None（处理旧数据）
    created_at = item.created_at if item.created_at is not None else get_utc_time()
    updated_at = item.updated_at if item.updated_at is not None else get_utc_time()
    
    # 加载提交者信息（通过显式查询避免懒加载问题）
    submitter_info = None
    if item.submitted_by:
        submitter_result = await db.execute(
            select(models.User).where(models.User.id == item.submitted_by)
        )
        submitter = submitter_result.scalar_one_or_none()
        if submitter:
            submitter_info = {
                "id": submitter.id,
                "name": submitter.name or f"用户{submitter.id}",
                "avatar": submitter.avatar or ""
            }
    
    item_dict = {
        "id": item.id,
        "leaderboard_id": item.leaderboard_id,
        "name": item.name,
        "description": item.description,
        "address": item.address,
        "phone": item.phone,
        "website": item.website,
        "images": images_list,
        "submitted_by": item.submitted_by,
        "status": item.status,
        "upvotes": item.upvotes,
        "downvotes": item.downvotes,
        "net_votes": item.net_votes,
        "vote_score": item.vote_score,
        "user_vote": user_vote,
        "user_vote_comment": user_vote_comment,
        "user_vote_is_anonymous": user_vote_is_anonymous,
        "created_at": created_at,
        "updated_at": updated_at
    }
    
    return item_dict


# ==================== 获取竞品的投票记录（留言） ====================

@router.get("/items/{item_id}/votes", response_model=schemas.LeaderboardVoteListResponse)
async def get_item_votes(
    item_id: int,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取竞品的投票记录（留言列表）"""
    # 检查竞品是否存在
    item = await db.get(models.LeaderboardItem, item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    # 检查榜单是否存在且为active状态
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    # 基础查询：只查询有留言的投票记录
    base_query = select(models.LeaderboardVote).where(
        and_(
            models.LeaderboardVote.item_id == item_id,
            models.LeaderboardVote.comment.isnot(None),  # 留言不为空
            models.LeaderboardVote.comment != ''  # 留言不为空字符串
        )
    )
    
    # 计算总数
    count_query = select(func.count()).select_from(base_query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # 按创建时间倒序排列
    query = base_query.order_by(models.LeaderboardVote.created_at.desc())
    
    # 分页
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    votes = result.scalars().all()
    
    # 批量查询非匿名用户的信息（避免N+1查询）
    non_anonymous_user_ids = [vote.user_id for vote in votes if not vote.is_anonymous]
    users_map = {}
    if non_anonymous_user_ids:
        users_result = await db.execute(
            select(models.User).where(models.User.id.in_(non_anonymous_user_ids))
        )
        users = users_result.scalars().all()
        users_map = {user.id: user for user in users}
    
    # 查询当前用户对留言的点赞状态
    user_liked_votes = set()
    if current_user:
        vote_ids = [vote.id for vote in votes]
        if vote_ids:
            like_result = await db.execute(
                select(models.VoteCommentLike).where(
                    and_(
                        models.VoteCommentLike.vote_id.in_(vote_ids),
                        models.VoteCommentLike.user_id == current_user.id
                    )
                )
            )
            user_liked_votes = {like.vote_id for like in like_result.scalars().all()}
    
    # 构建返回数据
    votes_out = []
    for vote in votes:
        # 对于非匿名用户，包含完整的用户信息（名字和头像）
        author_info = None
        if not vote.is_anonymous:
            user = users_map.get(vote.user_id)
            if user:
                author_info = {
                    "id": user.id,
                    "name": user.name or f"用户{user.id}",
                    "avatar": user.avatar or ""
                }
        
        vote_dict = {
            "id": vote.id,
            "item_id": vote.item_id,
            "user_id": None if vote.is_anonymous else vote.user_id,  # 匿名投票不返回user_id
            "vote_type": vote.vote_type,
            "comment": vote.comment,
            "is_anonymous": vote.is_anonymous,
            "like_count": vote.like_count or 0,  # 留言点赞数
            "user_liked": vote.id in user_liked_votes if current_user else None,  # 当前用户是否已点赞
            "author": author_info,  # 添加用户信息（非匿名用户显示真实名字和头像）
            "created_at": vote.created_at,
            "updated_at": vote.updated_at
        }
        votes_out.append(vote_dict)
    
    return {
        "items": votes_out,
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": offset + limit < total
    }


# ==================== 投票 ====================

@router.post("/items/{item_id}/vote")
@rate_limit("api_write", limit=30, window=60)  # 30次/分钟
async def vote_item(
    item_id: int,
    vote_type: str = Query(..., regex="^(upvote|downvote|remove)$"),
    comment: Optional[str] = Query(None, max_length=500, description="投票留言（可选，最多500字）"),
    is_anonymous: bool = Query(False, description="是否匿名投票/留言"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户对竞品投票（可附带留言）"""
    
    if comment:
        try:
            import bleach
            comment = bleach.clean(comment, tags=[], strip=True)
            if len(comment) > 500:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="留言最多500字"
                )
        except ImportError:
            # 如果没有安装bleach，只做长度检查
            if len(comment) > 500:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="留言最多500字"
                )
    
    item = await db.get(models.LeaderboardItem, item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在"
        )
    
    if leaderboard.status != "active" or item.status != "approved":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单或竞品不可投票"
        )
    
    existing_vote = await db.execute(
        select(models.LeaderboardVote).where(
            and_(
                models.LeaderboardVote.item_id == item_id,
                models.LeaderboardVote.user_id == current_user.id
            )
        )
    )
    existing = existing_vote.scalar_one_or_none()
    
    if vote_type == "remove":
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="您尚未投票"
            )
        
        # 使用原子更新，避免并发丢票
        if existing.vote_type == "upvote":
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(upvotes=func.greatest(0, models.LeaderboardItem.upvotes - 1))
            )
        else:
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(downvotes=func.greatest(0, models.LeaderboardItem.downvotes - 1))
            )
        
        await db.delete(existing)
        
        # 重新查询获取最新值（在提交前刷新，确保看到原子更新的结果）
        await db.refresh(item)
        
        # 重新计算净赞数和得分
        item.net_votes = item.upvotes - item.downvotes
        calculate_vote_score(item)
        
        # 统一提交事务
        await db.commit()
        
        return {
            "message": "投票已取消",
            "upvotes": item.upvotes,
            "downvotes": item.downvotes,
            "net_votes": item.net_votes,
            "vote_score": item.vote_score
        }
    
    if existing:
        if existing.vote_type == vote_type:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="您已经投过相同的票"
            )
        
        # 修改投票：先减少旧投票类型，再增加新投票类型（使用原子更新）
        if existing.vote_type == "upvote":
            # 从点赞改为点踩
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(
                    upvotes=func.greatest(0, models.LeaderboardItem.upvotes - 1),
                    downvotes=models.LeaderboardItem.downvotes + 1
                )
            )
        else:
            # 从点踩改为点赞
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(
                    upvotes=models.LeaderboardItem.upvotes + 1,
                    downvotes=func.greatest(0, models.LeaderboardItem.downvotes - 1)
                )
            )
        
        # 更新投票记录
        existing.vote_type = vote_type
        existing.comment = comment
        existing.is_anonymous = is_anonymous
        existing.updated_at = get_utc_time()
    else:
        # 新投票：使用原子更新
        new_vote = models.LeaderboardVote(
            item_id=item_id,
            user_id=current_user.id,
            vote_type=vote_type,
            comment=comment,
            is_anonymous=is_anonymous
        )
        db.add(new_vote)
        
        if vote_type == "upvote":
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(upvotes=models.LeaderboardItem.upvotes + 1)
            )
        else:
            await db.execute(
                update(models.LeaderboardItem)
                .where(models.LeaderboardItem.id == item_id)
                .values(downvotes=models.LeaderboardItem.downvotes + 1)
            )
        
        # 更新榜单投票计数（只有新投票时才+1）
        leaderboard.vote_count += 1
    
    # 重新查询获取最新值
    await db.refresh(item)
    
    # 重新计算净赞数和得分
    item.net_votes = item.upvotes - item.downvotes
    calculate_vote_score(item)
    
    await db.commit()
    
    return {
        "message": "投票成功",
        "upvotes": item.upvotes,
        "downvotes": item.downvotes,
        "net_votes": item.net_votes,
        "vote_score": item.vote_score
    }


# ==================== 留言点赞 ====================

@router.post("/votes/{vote_id}/like")
@rate_limit("api_write", limit=60, window=60)  # 60次/分钟
async def like_vote_comment(
    vote_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户对留言点赞/取消点赞"""
    # 检查留言是否存在
    vote = await db.get(models.LeaderboardVote, vote_id)
    if not vote:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="留言不存在"
        )
    
    # 检查竞品和榜单状态
    item = await db.get(models.LeaderboardItem, vote.item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    # 检查是否已点赞
    existing_like = await db.execute(
        select(models.VoteCommentLike).where(
            and_(
                models.VoteCommentLike.vote_id == vote_id,
                models.VoteCommentLike.user_id == current_user.id
            )
        )
    )
    existing = existing_like.scalar_one_or_none()
    
    if existing:
        # 取消点赞
        await db.delete(existing)
        # 使用原子更新减少点赞数
        await db.execute(
            update(models.LeaderboardVote)
            .where(models.LeaderboardVote.id == vote_id)
            .values(like_count=func.greatest(0, models.LeaderboardVote.like_count - 1))
        )
        await db.commit()
        
        # 重新查询获取最新值
        await db.refresh(vote)
        
        return {
            "message": "已取消点赞",
            "like_count": vote.like_count or 0,
            "liked": False
        }
    else:
        # 新点赞
        new_like = models.VoteCommentLike(
            vote_id=vote_id,
            user_id=current_user.id
        )
        db.add(new_like)
        
        # 使用原子更新增加点赞数
        await db.execute(
            update(models.LeaderboardVote)
            .where(models.LeaderboardVote.id == vote_id)
            .values(like_count=models.LeaderboardVote.like_count + 1)
        )
        await db.commit()
        
        # 重新查询获取最新值
        await db.refresh(vote)
        
        return {
            "message": "点赞成功",
            "like_count": vote.like_count or 0,
            "liked": True
        }


# ==================== 举报功能 ====================

@router.post("/{leaderboard_id}/report", response_model=dict)
@rate_limit("api_write", limit=5, window=300)  # 5次/5分钟
async def report_leaderboard(
    leaderboard_id: int,
    report_data: schemas.LeaderboardReportCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户举报榜单"""
    # 检查榜单是否存在
    leaderboard = await db.get(models.CustomLeaderboard, leaderboard_id)
    if not leaderboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在"
        )
    
    # 输入验证和清理
    report_data.reason = report_data.reason.strip() if report_data.reason else ""
    if not report_data.reason or len(report_data.reason) < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="举报原因不能为空"
        )
    if len(report_data.reason) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="举报原因不能超过500个字符"
        )
    
    if report_data.description:
        report_data.description = report_data.description.strip()
        if len(report_data.description) > 2000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="详细描述不能超过2000个字符"
            )
    
    # 检查是否已举报（pending状态）
    existing = await db.execute(
        select(models.LeaderboardReport).where(
            and_(
                models.LeaderboardReport.leaderboard_id == leaderboard_id,
                models.LeaderboardReport.reporter_id == current_user.id,
                models.LeaderboardReport.status == "pending"
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="您已经举报过该榜单，请等待管理员处理"
        )
    
    # 创建举报
    new_report = models.LeaderboardReport(
        leaderboard_id=leaderboard_id,
        reporter_id=current_user.id,
        reason=report_data.reason,
        description=report_data.description,
        status="pending"
    )
    
    db.add(new_report)
    
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="您已经举报过该榜单，请等待管理员处理"
        )
    
    return {
        "success": True,
        "message": "举报已提交，我们会尽快处理"
    }


@router.post("/items/{item_id}/report", response_model=dict)
@rate_limit("api_write", limit=5, window=300)  # 5次/5分钟
async def report_item(
    item_id: int,
    report_data: schemas.ItemReportCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户举报竞品"""
    # 检查竞品是否存在
    item = await db.get(models.LeaderboardItem, item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    # 检查榜单是否存在且为active状态
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard or leaderboard.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在或未激活"
        )
    
    # 输入验证和清理
    report_data.reason = report_data.reason.strip() if report_data.reason else ""
    if not report_data.reason or len(report_data.reason) < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="举报原因不能为空"
        )
    if len(report_data.reason) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="举报原因不能超过500个字符"
        )
    
    if report_data.description:
        report_data.description = report_data.description.strip()
        if len(report_data.description) > 2000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="详细描述不能超过2000个字符"
            )
    
    # 检查是否已举报（pending状态）
    existing = await db.execute(
        select(models.ItemReport).where(
            and_(
                models.ItemReport.item_id == item_id,
                models.ItemReport.reporter_id == current_user.id,
                models.ItemReport.status == "pending"
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="您已经举报过该竞品，请等待管理员处理"
        )
    
    # 创建举报
    new_report = models.ItemReport(
        item_id=item_id,
        reporter_id=current_user.id,
        reason=report_data.reason,
        description=report_data.description,
        status="pending"
    )
    
    db.add(new_report)
    
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="您已经举报过该竞品，请等待管理员处理"
        )
    
    return {
        "success": True,
        "message": "举报已提交，我们会尽快处理"
    }


# ==================== 管理员查看举报列表 ====================

@router.get("/admin/reports")
async def get_reports_admin(
    report_type: str = Query(..., regex="^(leaderboard|item)$", description="举报类型：leaderboard(榜单), item(竞品)"),
    status: Optional[str] = Query("all", description="状态筛选：pending, reviewed, dismissed, all"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员专用：查看举报列表"""
    if report_type == "leaderboard":
        base_query = select(models.LeaderboardReport)
        
        if status == "pending":
            base_query = base_query.where(models.LeaderboardReport.status == "pending")
        elif status == "reviewed":
            base_query = base_query.where(models.LeaderboardReport.status == "reviewed")
        elif status == "dismissed":
            base_query = base_query.where(models.LeaderboardReport.status == "dismissed")
        # status == "all" 时显示所有
        
        base_query = base_query.order_by(models.LeaderboardReport.created_at.desc())
        
        # 计算总数
        count_query = select(func.count()).select_from(base_query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        query = base_query.offset(offset).limit(limit)
        result = await db.execute(query)
        reports = result.scalars().all()
        
        # 手动构建返回数据
        items = []
        for r in reports:
            items.append({
                "id": r.id,
                "leaderboard_id": r.leaderboard_id,
                "reporter_id": r.reporter_id,
                "reason": r.reason,
                "description": r.description,
                "status": r.status,
                "reviewed_by": r.reviewed_by,
                "reviewed_at": r.reviewed_at,
                "admin_comment": r.admin_comment,
                "created_at": r.created_at,
                "updated_at": r.updated_at
            })
    else:  # item
        base_query = select(models.ItemReport)
        
        if status == "pending":
            base_query = base_query.where(models.ItemReport.status == "pending")
        elif status == "reviewed":
            base_query = base_query.where(models.ItemReport.status == "reviewed")
        elif status == "dismissed":
            base_query = base_query.where(models.ItemReport.status == "dismissed")
        # status == "all" 时显示所有
        
        base_query = base_query.order_by(models.ItemReport.created_at.desc())
        
        # 计算总数
        count_query = select(func.count()).select_from(base_query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        query = base_query.offset(offset).limit(limit)
        result = await db.execute(query)
        reports = result.scalars().all()
        
        # 手动构建返回数据
        items = []
        for r in reports:
            items.append({
                "id": r.id,
                "item_id": r.item_id,
                "reporter_id": r.reporter_id,
                "reason": r.reason,
                "description": r.description,
                "status": r.status,
                "reviewed_by": r.reviewed_by,
                "reviewed_at": r.reviewed_at,
                "admin_comment": r.admin_comment,
                "created_at": r.created_at,
                "updated_at": r.updated_at
            })
    
    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": offset + limit < total
    }


# ==================== 管理员处理举报 ====================

@router.post("/admin/reports/{report_id}/review")
async def review_report(
    report_id: int,
    report_type: str = Query(..., regex="^(leaderboard|item)$", description="举报类型"),
    action: str = Query(..., regex="^(reviewed|dismissed)$", description="处理动作：reviewed(已处理), dismissed(已驳回)"),
    admin_comment: Optional[str] = None,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员处理举报"""
    if report_type == "leaderboard":
        report = await db.get(models.LeaderboardReport, report_id)
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="举报记录不存在"
            )
    else:  # item
        report = await db.get(models.ItemReport, report_id)
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="举报记录不存在"
            )
    
    if report.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该举报已处理"
        )
    
    # 清理管理员意见
    if admin_comment:
        admin_comment = admin_comment.strip()
        if len(admin_comment) > 2000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="处理意见不能超过2000个字符"
            )
    
    # 更新举报状态
    report.status = action
    report.reviewed_by = current_admin.id
    report.reviewed_at = get_utc_time()
    report.admin_comment = admin_comment
    
    await db.commit()
    
    return {
        "message": f"举报已{action}",
        "status": action
    }


# ==================== 管理员删除竞品 ====================

def delete_leaderboard_item_images(item_id: int):
    """
    删除竞品的图片文件
    
    Args:
        item_id: 竞品ID
    """
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads/public/images")
        else:
            base_dir = Path("uploads/public/images")
        
        # 删除竞品图片目录
        item_dir = base_dir / "leaderboard_items" / str(item_id)
        if item_dir.exists():
            shutil.rmtree(item_dir)
            logger.info(f"删除竞品 {item_id} 的图片目录: {item_dir}")
            return True
        return False
    except Exception as e:
        logger.warning(f"删除竞品 {item_id} 的图片目录失败: {e}")
        return False


@router.delete("/admin/items/{item_id}")
async def delete_item_admin(
    item_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员删除竞品（级联删除投票记录和图片文件夹，并更新榜单统计）"""
    # 查询竞品
    item = await db.get(models.LeaderboardItem, item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="竞品不存在"
        )
    
    # 查询榜单
    leaderboard = await db.get(models.CustomLeaderboard, item.leaderboard_id)
    if not leaderboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="榜单不存在"
        )
    
    # 查询该竞品的投票数量（用于更新榜单统计）
    vote_count_result = await db.execute(
        select(func.count()).select_from(
            select(models.LeaderboardVote).where(
                models.LeaderboardVote.item_id == item_id
            ).subquery()
        )
    )
    item_vote_count = vote_count_result.scalar() or 0
    
    # 查询该竞品的举报数量（用于记录日志）
    report_count_result = await db.execute(
        select(func.count()).select_from(
            select(models.ItemReport).where(
                models.ItemReport.item_id == item_id
            ).subquery()
        )
    )
    item_report_count = report_count_result.scalar() or 0
    
    try:
        # 先删除相关的举报记录（避免外键约束问题）
        # 虽然外键有 ondelete="CASCADE"，但为了确保 SQLAlchemy ORM 正确处理，我们手动删除
        await db.execute(
            delete(models.ItemReport).where(models.ItemReport.item_id == item_id)
        )
        
        # 删除竞品（级联删除投票记录，因为模型中有 cascade="all, delete-orphan"）
        await db.delete(item)
        
        # 更新榜单统计
        leaderboard.item_count = max(0, leaderboard.item_count - 1)
        leaderboard.vote_count = max(0, leaderboard.vote_count - item_vote_count)
        
        await db.commit()
        
        # 删除图片文件夹（在数据库提交成功后）
        delete_leaderboard_item_images(item_id)
        
        logger.info(f"管理员 {current_admin.id} 删除竞品 {item_id}，删除了 {item_report_count} 条举报记录，更新榜单 {leaderboard.id} 统计：item_count={leaderboard.item_count}, vote_count={leaderboard.vote_count}")
        
        return {
            "success": True,
            "message": "竞品已删除",
            "deleted_item_id": item_id,
            "updated_leaderboard_id": leaderboard.id
        }
    except Exception as e:
        await db.rollback()
        logger.error(f"删除竞品失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除竞品失败: {str(e)}"
        )


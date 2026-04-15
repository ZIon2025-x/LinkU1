"""
达人团队用户侧路由
Router prefix: /api/experts
"""

import datetime
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import (
    Expert, ExpertMember, ExpertApplication,
    ExpertJoinRequest, ExpertInvitation, ExpertFollow,
    ExpertProfileUpdateRequest, FeaturedExpertV2,
    generate_expert_id,
)
from app.schemas_expert import (
    ExpertOut, ExpertDetailOut, ExpertMemberOut,
    ExpertApplicationCreate, ExpertApplicationOut,
    ExpertJoinRequestCreate, ExpertJoinRequestOut, ExpertJoinRequestReview,
    ExpertInvitationCreate, ExpertInvitationOut, ExpertInvitationResponse,
    ExpertRoleChange, ExpertTransfer,
    ExpertProfileUpdateCreate, ExpertProfileUpdateOut,
    ExpertLocationUpdate, UpcomingClosedDate,
)
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_router = APIRouter(prefix="/api/experts", tags=["experts"])


# ==================== Helpers ====================

_DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


async def _compute_is_open(db: AsyncSession, expert: Expert) -> Optional[bool]:
    """根据 business_hours + closed_dates 计算当前是否营业。
    business_hours 存储的是伦敦本地时间（"09:00" 指 London local），
    business_hours 未设置时返回 None（不显示状态）。"""
    bh = expert.business_hours
    if not bh:
        return None

    from app.utils.time_utils import LONDON
    now_local = datetime.datetime.now(LONDON)
    day_key = _DAY_KEYS[now_local.weekday()]  # 0=mon
    now_time_str = now_local.strftime("%H:%M")
    today_local_date = now_local.date()

    # 检查今天是否临时关门（closed_date 按本地日期比对）
    from app.models import ExpertClosedDate
    cd_result = await db.execute(
        select(ExpertClosedDate.id).where(
            and_(
                ExpertClosedDate.expert_id == expert.id,
                ExpertClosedDate.closed_date == today_local_date,
            )
        ).limit(1)
    )
    if cd_result.scalar_one_or_none() is not None:
        return False

    # 检查今天的营业时间
    today_hours = bh.get(day_key)
    if not today_hours or not isinstance(today_hours, dict):
        return False

    open_time = today_hours.get("open")
    close_time = today_hours.get("close")
    if not open_time or not close_time:
        return False

    return open_time <= now_time_str < close_time


async def _compute_is_open_batch(
    db: AsyncSession, experts: List[Expert]
) -> dict:
    """一次性计算多个 expert 的 is_open。避免列表端点的 N+1 closed_dates 查询。
    返回: {expert_id: Optional[bool]}. business_hours 未设置时为 None。"""
    result: dict = {}
    if not experts:
        return result

    from app.utils.time_utils import LONDON
    now_local = datetime.datetime.now(LONDON)
    day_key = _DAY_KEYS[now_local.weekday()]
    now_time_str = now_local.strftime("%H:%M")
    today_local_date = now_local.date()

    # 仅对 business_hours 非空的 expert 去查 closed_dates
    bh_experts = [e for e in experts if e.business_hours]
    closed_today_ids: set = set()
    if bh_experts:
        from app.models import ExpertClosedDate
        cd_result = await db.execute(
            select(ExpertClosedDate.expert_id).where(
                and_(
                    ExpertClosedDate.expert_id.in_([e.id for e in bh_experts]),
                    ExpertClosedDate.closed_date == today_local_date,
                )
            )
        )
        closed_today_ids = set(cd_result.scalars().all())

    for e in experts:
        bh = e.business_hours
        if not bh:
            result[e.id] = None
            continue
        if e.id in closed_today_ids:
            result[e.id] = False
            continue
        today_hours = bh.get(day_key)
        if not today_hours or not isinstance(today_hours, dict):
            result[e.id] = False
            continue
        open_t = today_hours.get("open")
        close_t = today_hours.get("close")
        if not open_t or not close_t:
            result[e.id] = False
            continue
        result[e.id] = open_t <= now_time_str < close_t
    return result


async def _get_expert_or_404(db: AsyncSession, expert_id: str) -> Expert:
    """获取达人团队，不存在则 404"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人团队不存在")
    return expert


async def _get_member_or_403(
    db: AsyncSession,
    expert_id: str,
    user_id: str,
    required_roles: Optional[List[str]] = None,
) -> ExpertMember:
    """检查用户是否为活跃成员，可选角色检查"""
    result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            )
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="你不是该团队的活跃成员")
    if required_roles and member.role not in required_roles:
        raise HTTPException(status_code=403, detail="权限不足")
    return member


# ==================== 1. POST /apply ====================

@expert_router.post("/apply", response_model=ExpertApplicationOut, status_code=201)
async def apply_to_create_expert(
    body: ExpertApplicationCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """申请创建达人团队"""
    # 检查是否有待审核的申请
    result = await db.execute(
        select(ExpertApplication).where(
            and_(
                ExpertApplication.user_id == current_user.id,
                ExpertApplication.status == "pending",
            )
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="你已有待审核的申请")

    # 团队名称可选:简化的申请表单(只填一段话)会留空 expert_name,此时
    # 默认用申请人的 user.name 作为团队名,管理后台批准后用户可在
    # dashboard 改成更合适的名字。
    effective_name = (body.expert_name or "").strip() or (
        getattr(current_user, "name", None) or f"User {current_user.id}"
    )

    app = ExpertApplication(
        user_id=current_user.id,
        expert_name=effective_name,
        bio=body.bio,
        avatar=body.avatar,
        application_message=body.application_message,
    )
    db.add(app)
    await db.commit()
    await db.refresh(app)
    return app


# ==================== 2. GET /my-applications ====================

@expert_router.get("/my-applications", response_model=List[ExpertApplicationOut])
async def list_my_applications(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看我的达人团队申请"""
    result = await db.execute(
        select(ExpertApplication)
        .where(ExpertApplication.user_id == current_user.id)
        .order_by(ExpertApplication.created_at.desc())
    )
    return result.scalars().all()


# ==================== 3. GET /my-teams ====================

@expert_router.get("/my-teams", response_model=List[ExpertOut])
async def list_my_teams(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看我加入的团队"""
    result = await db.execute(
        select(Expert, ExpertMember.role)
        .join(ExpertMember, ExpertMember.expert_id == Expert.id)
        .where(
            and_(
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
                Expert.status.in_(["active", "inactive"]),
            )
        )
        .order_by(Expert.created_at.desc())
    )
    rows = result.all()

    # 批量查询关注状态
    expert_ids = [e.id for e, _ in rows]
    followed_ids: set = set()
    if expert_ids:
        follow_result = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id.in_(expert_ids),
                )
            )
        )
        followed_ids = set(follow_result.scalars().all())

    is_open_map = await _compute_is_open_batch(db, [e for e, _ in rows])
    out = []
    for expert, role in rows:
        d = ExpertOut.model_validate(expert)
        d.is_following = expert.id in followed_ids
        d.my_role = role
        d.is_open = is_open_map.get(expert.id)
        out.append(d)
    return out


# ==================== GET /my-invitations ====================

@expert_router.get("/my-invitations", response_model=List[ExpertInvitationOut])
async def list_my_invitations(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看我收到的团队邀请"""
    result = await db.execute(
        select(ExpertInvitation, Expert)
        .join(Expert, Expert.id == ExpertInvitation.expert_id)
        .where(
            and_(
                ExpertInvitation.invitee_id == current_user.id,
                ExpertInvitation.status == "pending",
            )
        )
        .order_by(ExpertInvitation.created_at.desc())
    )
    rows = result.all()
    out = []
    for invitation, expert in rows:
        d = ExpertInvitationOut.model_validate(invitation)
        d.expert_name = expert.name
        d.expert_avatar = expert.avatar
        d.invitee_name = current_user.name
        d.invitee_avatar = getattr(current_user, 'avatar', None)
        out.append(d)
    return out


# ==================== GET /featured ====================

@expert_router.get("/featured", response_model=List[ExpertOut])
async def list_featured_experts(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取精选达人列表"""
    result = await db.execute(
        select(Expert, FeaturedExpertV2)
        .join(FeaturedExpertV2, FeaturedExpertV2.expert_id == Expert.id)
        .where(
            and_(
                FeaturedExpertV2.is_featured == True,
                Expert.status == "active",
            )
        )
        .order_by(FeaturedExpertV2.display_order.asc())
        .offset(offset).limit(limit)
    )
    rows = result.all()

    followed_ids: set = set()
    if current_user and rows:
        expert_ids = [e.id for e, _ in rows]
        fr = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(ExpertFollow.user_id == current_user.id, ExpertFollow.expert_id.in_(expert_ids))
            )
        )
        followed_ids = set(fr.scalars().all())

    is_open_map = await _compute_is_open_batch(db, [e for e, _ in rows])
    out = []
    for expert, featured in rows:
        d = ExpertOut.model_validate(expert)
        d.is_following = expert.id in followed_ids
        d.is_open = is_open_map.get(expert.id)
        out.append(d)
    return out


# ==================== GET /my-following ====================

@expert_router.get("/my-following", response_model=List[ExpertOut])
async def list_my_following_experts(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取我关注的达人列表"""
    result = await db.execute(
        select(Expert)
        .join(ExpertFollow, ExpertFollow.expert_id == Expert.id)
        .where(
            and_(
                ExpertFollow.user_id == current_user.id,
                Expert.status == "active",
            )
        )
        .order_by(ExpertFollow.created_at.desc())
        .offset(offset).limit(limit)
    )
    experts = result.scalars().all()
    is_open_map = await _compute_is_open_batch(db, list(experts))
    out = []
    for e in experts:
        d = ExpertOut.model_validate(e)
        d.is_following = True
        d.is_open = is_open_map.get(e.id)
        out.append(d)
    return out


# ==================== 4b. GET /by-user/{user_id} — user_id → team resolver ====================

@expert_router.get("/by-user/{user_id}", response_model=ExpertOut)
async def get_expert_by_user(
    user_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """通过 user_id 解析到达人团队,返回团队详情 (公开).

    用途: legacy Web UI 需要"查一个用户作为达人的团队信息",但新 experts.id
    与 user.id 是不同 namespace。本端点做解析,让前端从 user_id 一步跳到 ExpertOut。

    解析顺序:
    1. `_expert_id_migration_map`: old_id == user_id → new expert_id
       (覆盖 B1 legacy 1 人团队: task_experts.id=user.id 通过 migration 168/185 映射到新团队)
    2. ExpertMember: user_id 作为 owner 的 active 团队 (按 joined_at 最早,兼容 owner 多团队)
       (覆盖没 migration map 记录的新注册 owner)
    3. 都没有 → 404

    响应: ExpertOut (含 is_following 当前用户视角)
    """
    from sqlalchemy import text as _sql_text

    resolved_id: Optional[str] = None

    # Strategy 1: _expert_id_migration_map (legacy 1 人团队 catch-up)
    try:
        mapped = await db.execute(
            _sql_text("SELECT new_id FROM _expert_id_migration_map WHERE old_id = :old_id"),
            {"old_id": user_id},
        )
        row = mapped.first()
        if row and row[0]:
            resolved_id = row[0]
    except Exception as e:
        logger.warning(f"_expert_id_migration_map lookup failed for user_id={user_id}: {e}")

    # Strategy 2: ExpertMember(role='owner', status='active')
    if not resolved_id:
        member_result = await db.execute(
            select(ExpertMember.expert_id)
            .where(
                and_(
                    ExpertMember.user_id == user_id,
                    ExpertMember.status == "active",
                    ExpertMember.role == "owner",
                )
            )
            .order_by(ExpertMember.joined_at.asc())
            .limit(1)
        )
        resolved_id = member_result.scalar_one_or_none()

    if not resolved_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="该用户未拥有任何达人团队",
        )

    expert_result = await db.execute(select(Expert).where(Expert.id == resolved_id))
    expert = expert_result.scalar_one_or_none()
    if not expert:
        # migration_map 可能指向已删除的团队,降级 404
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="达人团队不存在",
        )

    out = ExpertOut.model_validate(expert)
    out.is_open = await _compute_is_open(db, expert)
    # 填充 is_following
    if current_user:
        fr = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id == resolved_id,
                )
            )
        )
        out.is_following = fr.scalar_one_or_none() is not None
    return out


# ==================== 5. GET / (list/search) — placed before /{expert_id} ====================

@expert_router.get("", response_model=List[ExpertOut])
async def list_experts(
    request: Request,
    keyword: Optional[str] = Query(None, description="名称/简介/技能/分类的模糊匹配"),
    category: Optional[str] = Query(None, description="按 experts.category 精确筛选"),
    location: Optional[str] = Query(None, description="按 experts.location 大小写不敏感、支持中英文城市别名"),
    sort: Optional[str] = Query(
        None,
        pattern="^(rating|created_at|completed_tasks|display_order|random)$",
        description="排序: rating / completed_tasks / created_at / display_order(默认) / random",
    ),
    status_filter: Optional[str] = Query("active", alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """搜索/列表达人团队（公开）

    Phase B1 收口: 这是 Flutter buyer 端 `/api/task-experts` 调用的迁移目标 ——
    用 Expert 表替换 legacy FeaturedTaskExpert,并接管原 task_expert_routes.get_experts_list
    支持的所有筛选参数 (category / location / keyword / sort=random)。
    """
    query = select(Expert).where(Expert.status == (status_filter or "active"))

    if category:
        query = query.where(Expert.category == category)

    if location:
        # 与 legacy 一致: build_city_location_filter 处理大小写不敏感 + 中英文城市别名
        from app.utils.city_filter_utils import build_city_location_filter
        loc_filter = build_city_location_filter(Expert.location, location.strip())
        if loc_filter is not None:
            query = query.where(loc_filter)

    if keyword and keyword.strip():
        # 与 legacy 一致: build_keyword_filter 支持同义词扩展 (Phase B1 行为对齐)
        # 注意: 新表 expertise_areas / featured_skills / achievements 是 JSONB,
        # 不能直接 ilike, 这里只对 Text/VARCHAR 列做模糊匹配。
        # JSONB 列需要时单独 cast(JSONB → Text) 后再 ilike, 当前 keyword 命中率
        # 通过 name + bio + category + bio_zh 已经足够好,先不引入 cast 复杂度。
        from app.utils.search_expander import build_keyword_filter
        kw_filter = build_keyword_filter(
            columns=[
                Expert.name,
                Expert.name_en,
                Expert.name_zh,
                Expert.bio,
                Expert.bio_en,
                Expert.bio_zh,
                Expert.category,
                Expert.location,
            ],
            keyword=keyword.strip(),
            use_similarity=False,
        )
        if kw_filter is not None:
            query = query.where(kw_filter)

    if sort == "rating":
        query = query.order_by(Expert.rating.desc())
    elif sort == "completed_tasks":
        query = query.order_by(Expert.completed_tasks.desc())
    elif sort == "created_at":
        query = query.order_by(Expert.created_at.desc())
    elif sort == "random":
        # 随机排序无法稳定分页, 这里忽略 offset, 仅 limit
        from sqlalchemy.sql.expression import func as sql_func
        query = query.order_by(sql_func.random()).limit(limit)
    else:
        # 默认: 与 legacy 一致, 按 display_order 升序、created_at 降序兜底
        query = query.order_by(Expert.display_order.asc(), Expert.created_at.desc())

    if sort != "random":
        query = query.offset(offset).limit(limit)

    result = await db.execute(query)
    experts = result.scalars().all()

    # 关注状态
    followed_ids: set = set()
    if current_user and experts:
        expert_ids = [e.id for e in experts]
        fr = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id.in_(expert_ids),
                )
            )
        )
        followed_ids = set(fr.scalars().all())

    is_open_map = await _compute_is_open_batch(db, list(experts))
    out = []
    for e in experts:
        d = ExpertOut.model_validate(e)
        d.is_following = e.id in followed_ids
        d.is_open = is_open_map.get(e.id)
        out.append(d)
    return out


# ==================== 4. GET /{expert_id} ====================

@expert_router.get("/{expert_id}", response_model=ExpertDetailOut)
async def get_expert_detail(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """达人团队详情（公开，可选认证获取关注状态）"""
    expert = await _get_expert_or_404(db, expert_id)

    # 成员列表（join User 获取 name/avatar）
    members_result = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.status == "active",
            )
        )
        .order_by(ExpertMember.joined_at.asc())
    )
    members_rows = members_result.all()
    members_out = []
    for member, user in members_rows:
        m = ExpertMemberOut.model_validate(member)
        m.user_name = user.name
        m.user_avatar = user.avatar
        members_out.append(m)

    # 粉丝数
    fc_result = await db.execute(
        select(func.count()).select_from(ExpertFollow).where(ExpertFollow.expert_id == expert_id)
    )
    follower_count = fc_result.scalar() or 0

    # 关注状态
    is_following = False
    if current_user:
        fr = await db.execute(
            select(ExpertFollow).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id == expert_id,
                )
            )
        )
        is_following = fr.scalar_one_or_none() is not None

    # Featured 状态
    featured_result = await db.execute(
        select(FeaturedExpertV2).where(
            and_(
                FeaturedExpertV2.expert_id == expert_id,
                FeaturedExpertV2.is_featured == True,
            )
        )
    )
    is_featured = featured_result.scalar_one_or_none() is not None

    # 当前用户的角色
    my_role = None
    if current_user:
        for m in members_out:
            if m.user_id == current_user.id:
                my_role = m.role
                break

    # 注意: 不能直接 ExpertDetailOut.model_validate(expert) — 它会让 Pydantic
    # 通过 from_attributes 访问 expert.members (SQLAlchemy relationship),
    # 在 async session 下触发隐式 lazy load → MissingGreenlet → 500。
    # 改为先 validate ExpertOut (不含 members 字段),再用已显式加载的 members_out 构造 ExpertDetailOut。
    base = ExpertOut.model_validate(expert)
    detail = ExpertDetailOut(
        **base.model_dump(),
        members=members_out,
        is_featured=is_featured,
    )
    detail.follower_count = follower_count
    detail.is_following = is_following
    detail.my_role = my_role

    # 计算实时营业状态: business_hours + closed_dates
    detail.is_open = await _compute_is_open(db, expert)

    # 未来 14 天内的临时休息日（含今天，按伦敦本地日期对齐）
    from app.models import ExpertClosedDate
    from app.utils.time_utils import LONDON
    today_dt = datetime.datetime.now(LONDON).date()
    end_dt = today_dt + datetime.timedelta(days=14)
    upcoming_result = await db.execute(
        select(ExpertClosedDate.closed_date, ExpertClosedDate.reason)
        .where(
            and_(
                ExpertClosedDate.expert_id == expert_id,
                ExpertClosedDate.closed_date >= today_dt,
                ExpertClosedDate.closed_date <= end_dt,
            )
        )
        .order_by(ExpertClosedDate.closed_date.asc())
    )
    detail.upcoming_closed_dates = [
        UpcomingClosedDate(
            closed_date=row[0].isoformat() if hasattr(row[0], 'isoformat') else str(row[0]),
            reason=row[1],
        )
        for row in upcoming_result.all()
    ]

    return detail


# ==================== 6. POST /{expert_id}/follow ====================

@expert_router.post("/{expert_id}/follow")
async def toggle_follow(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """关注/取消关注达人团队"""
    await _get_expert_or_404(db, expert_id)

    result = await db.execute(
        select(ExpertFollow).where(
            and_(
                ExpertFollow.user_id == current_user.id,
                ExpertFollow.expert_id == expert_id,
            )
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        return {"following": False}
    else:
        follow = ExpertFollow(user_id=current_user.id, expert_id=expert_id)
        db.add(follow)
        await db.commit()
        return {"following": True}


# ==================== 7. GET /{expert_id}/members ====================

@expert_router.get("/{expert_id}/members", response_model=List[ExpertMemberOut])
async def list_members(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """查看团队成员列表（公开）。

    user_id 字段仅对团队内部成员(任意 active member)返回,非成员/未登录
    用户拿到的列表只有 name + avatar + role,无法用于枚举攻击。
    """
    await _get_expert_or_404(db, expert_id)

    # 判断当前用户是否是这个团队的 active member
    is_team_member = False
    if current_user:
        member_check = await db.execute(
            select(ExpertMember).where(
                and_(
                    ExpertMember.expert_id == expert_id,
                    ExpertMember.user_id == current_user.id,
                    ExpertMember.status == "active",
                )
            )
        )
        is_team_member = member_check.scalar_one_or_none() is not None

    result = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.status == "active",
            )
        )
        .order_by(ExpertMember.joined_at.asc())
    )
    rows = result.all()
    out = []
    for member, user in rows:
        m = ExpertMemberOut.model_validate(member)
        m.user_name = user.name
        m.user_avatar = user.avatar
        if not is_team_member:
            # 隐藏 user_id 防枚举
            m.user_id = None
        out.append(m)
    return out


# ==================== 8. POST /{expert_id}/invite ====================

@expert_router.post("/{expert_id}/invite", response_model=ExpertInvitationOut, status_code=201)
async def invite_user(
    expert_id: str,
    body: ExpertInvitationCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """邀请用户加入团队（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    # 检查团队是否已满
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="团队成员已满")

    # 检查被邀请用户是否存在
    from app import async_crud
    invitee = await async_crud.async_user_crud.get_user_by_id(db, body.invitee_id)
    if not invitee:
        raise HTTPException(status_code=404, detail="被邀请用户不存在")

    # 检查是否已是活跃成员
    existing_member = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == body.invitee_id,
                ExpertMember.status == "active",
            )
        )
    )
    if existing_member.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="该用户已是团队成员")

    # 检查是否有待处理的邀请
    existing_invite = await db.execute(
        select(ExpertInvitation).where(
            and_(
                ExpertInvitation.expert_id == expert_id,
                ExpertInvitation.invitee_id == body.invitee_id,
                ExpertInvitation.status == "pending",
            )
        )
    )
    if existing_invite.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="已有待处理的邀请")

    invitation = ExpertInvitation(
        expert_id=expert_id,
        inviter_id=current_user.id,
        invitee_id=body.invitee_id,
    )
    db.add(invitation)
    await db.commit()
    await db.refresh(invitation)

    # 通知被邀请人(best-effort, i18n)
    try:
        from app.async_crud import AsyncNotificationCRUD
        from app.utils.notification_templates import get_notification_texts
        title_zh, content_zh, title_en, content_en = get_notification_texts(
            "expert_team_invitation", team_name=expert.name
        )
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=body.invitee_id,
            notification_type="expert_team_invitation",
            title=title_zh,
            content=content_zh,
            title_en=title_en,
            content_en=content_en,
            related_id=str(invitation.id),
            related_type="expert_invitation",
        )
    except Exception as e:
        logger.warning(f"发送达人团队邀请通知失败: {e}")

    # 填充 invitee 信息
    out = ExpertInvitationOut.model_validate(invitation)
    out.invitee_name = invitee.name
    out.invitee_avatar = invitee.avatar
    return out


# ==================== 9. POST /invitations/{invitation_id}/respond ====================

@expert_router.post("/invitations/{invitation_id}/respond", response_model=ExpertInvitationOut)
async def respond_to_invitation(
    invitation_id: int,
    body: ExpertInvitationResponse,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """接受/拒绝邀请"""
    result = await db.execute(
        select(ExpertInvitation).where(ExpertInvitation.id == invitation_id)
    )
    invitation = result.scalar_one_or_none()
    if not invitation:
        raise HTTPException(status_code=404, detail="邀请不存在")
    if invitation.invitee_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作此邀请")
    if invitation.status != "pending":
        raise HTTPException(status_code=400, detail="邀请已被处理")

    now = get_utc_time()
    invitation.responded_at = now

    if body.action == "reject":
        invitation.status = "rejected"
        await db.commit()
        await db.refresh(invitation)
        return ExpertInvitationOut.model_validate(invitation)

    # accept
    invitation.status = "accepted"

    # 并发安全: 锁定 Expert 行,串行化容量检查 + 计数更新
    expert_lock_result = await db.execute(
        select(Expert).where(Expert.id == invitation.expert_id).with_for_update()
    )
    expert = expert_lock_result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="团队不存在")
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="团队成员已满")

    # 检查是否有旧的成员记录（left/removed）可以重新激活
    existing_member_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == invitation.expert_id,
                ExpertMember.user_id == current_user.id,
            )
        )
    )
    existing_member = existing_member_result.scalar_one_or_none()

    if existing_member:
        if existing_member.status == "active":
            raise HTTPException(status_code=400, detail="你已是团队成员")
        # 重新激活
        existing_member.status = "active"
        existing_member.role = "member"
        existing_member.updated_at = now
    else:
        new_member = ExpertMember(
            expert_id=invitation.expert_id,
            user_id=current_user.id,
            role="member",
        )
        db.add(new_member)

    # 原子递增 — 在锁内串行化已经够,这里使用赋值即可(锁保证一致性)
    expert.member_count = expert.member_count + 1
    await db.commit()
    await db.refresh(invitation)
    return ExpertInvitationOut.model_validate(invitation)


# ==================== 10. POST /{expert_id}/join ====================

@expert_router.post("/{expert_id}/join", response_model=ExpertJoinRequestOut, status_code=201)
async def request_to_join(
    expert_id: str,
    body: ExpertJoinRequestCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """申请加入团队"""
    expert = await _get_expert_or_404(db, expert_id)

    if not expert.allow_applications:
        raise HTTPException(status_code=400, detail="该团队不接受加入申请")

    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="团队成员已满")

    # 检查是否已是活跃成员
    existing_member = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        )
    )
    if existing_member.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="你已是团队成员")

    # 检查是否有待处理的加入请求
    existing_req = await db.execute(
        select(ExpertJoinRequest).where(
            and_(
                ExpertJoinRequest.expert_id == expert_id,
                ExpertJoinRequest.user_id == current_user.id,
                ExpertJoinRequest.status == "pending",
            )
        )
    )
    if existing_req.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="你已有待处理的加入申请")

    join_req = ExpertJoinRequest(
        expert_id=expert_id,
        user_id=current_user.id,
        message=body.message,
    )
    db.add(join_req)
    await db.commit()
    await db.refresh(join_req)

    # 通知所有 owner/admin 有新加入申请(best-effort, i18n)
    try:
        from app.async_crud import AsyncNotificationCRUD
        from app.utils.notification_templates import get_notification_texts
        managers_result = await db.execute(
            select(ExpertMember.user_id).where(
                and_(
                    ExpertMember.expert_id == expert_id,
                    ExpertMember.status == "active",
                    ExpertMember.role.in_(["owner", "admin"]),
                )
            )
        )
        manager_ids = [r[0] for r in managers_result.all()]
        title_zh, content_zh, title_en, content_en = get_notification_texts(
            "expert_team_join_request",
            applicant_name=current_user.name,
            team_name=expert.name,
        )
        for mid in manager_ids:
            await AsyncNotificationCRUD.create_notification(
                db=db,
                user_id=mid,
                notification_type="expert_team_join_request",
                title=title_zh,
                content=content_zh,
                title_en=title_en,
                content_en=content_en,
                related_id=str(join_req.id),
                related_type="expert_join_request",
            )
    except Exception as e:
        logger.warning(f"发送加入申请通知失败: {e}")

    out = ExpertJoinRequestOut.model_validate(join_req)
    out.user_name = current_user.name
    out.user_avatar = current_user.avatar
    return out


# ==================== 11. GET /{expert_id}/join-requests ====================

@expert_router.get("/{expert_id}/join-requests", response_model=List[ExpertJoinRequestOut])
async def list_join_requests(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看加入申请列表（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    query = (
        select(ExpertJoinRequest, models.User)
        .join(models.User, models.User.id == ExpertJoinRequest.user_id)
        .where(ExpertJoinRequest.expert_id == expert_id)
    )
    if status_filter:
        query = query.where(ExpertJoinRequest.status == status_filter)
    query = query.order_by(ExpertJoinRequest.created_at.desc())

    result = await db.execute(query)
    rows = result.all()
    out = []
    for jr, user in rows:
        d = ExpertJoinRequestOut.model_validate(jr)
        d.user_name = user.name
        d.user_avatar = user.avatar
        out.append(d)
    return out


# ==================== 12. PUT /{expert_id}/join-requests/{request_id} ====================

@expert_router.put("/{expert_id}/join-requests/{request_id}", response_model=ExpertJoinRequestOut)
async def review_join_request(
    expert_id: str,
    request_id: int,
    body: ExpertJoinRequestReview,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """审核加入申请（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(ExpertJoinRequest).where(
            and_(
                ExpertJoinRequest.id == request_id,
                ExpertJoinRequest.expert_id == expert_id,
            )
        )
    )
    jr = result.scalar_one_or_none()
    if not jr:
        raise HTTPException(status_code=404, detail="加入申请不存在")
    if jr.status != "pending":
        raise HTTPException(status_code=400, detail="该申请已被处理")

    now = get_utc_time()
    jr.reviewed_by = current_user.id
    jr.reviewed_at = now

    if body.action == "reject":
        jr.status = "rejected"
        await db.commit()
        await db.refresh(jr)
        # 通知申请人(best-effort, i18n)
        try:
            from app.async_crud import AsyncNotificationCRUD
            from app.utils.notification_templates import get_notification_texts
            expert_for_notify = await _get_expert_or_404(db, expert_id)
            title_zh, content_zh, title_en, content_en = get_notification_texts(
                "expert_team_join_rejected", team_name=expert_for_notify.name
            )
            await AsyncNotificationCRUD.create_notification(
                db=db,
                user_id=jr.user_id,
                notification_type="expert_team_join_rejected",
                title=title_zh,
                content=content_zh,
                title_en=title_en,
                content_en=content_en,
                related_id=str(jr.id),
                related_type="expert_join_request",
            )
        except Exception as e:
            logger.warning(f"发送加入申请拒绝通知失败: {e}")
        return ExpertJoinRequestOut.model_validate(jr)

    # approve
    jr.status = "approved"

    # 并发安全: 锁定 Expert 行,串行化容量检查 + 计数更新
    expert_lock_result = await db.execute(
        select(Expert).where(Expert.id == expert_id).with_for_update()
    )
    expert = expert_lock_result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="团队不存在")
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="团队成员已满")

    # 检查是否有旧成员记录可重新激活
    existing_member_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == jr.user_id,
            )
        )
    )
    existing_member = existing_member_result.scalar_one_or_none()

    if existing_member:
        if existing_member.status == "active":
            raise HTTPException(status_code=400, detail="该用户已是团队成员")
        existing_member.status = "active"
        existing_member.role = "member"
        existing_member.updated_at = now
    else:
        new_member = ExpertMember(
            expert_id=expert_id,
            user_id=jr.user_id,
            role="member",
        )
        db.add(new_member)

    expert.member_count = expert.member_count + 1
    await db.commit()
    await db.refresh(jr)

    # 通知申请人申请通过(best-effort, i18n)
    try:
        from app.async_crud import AsyncNotificationCRUD
        from app.utils.notification_templates import get_notification_texts
        title_zh, content_zh, title_en, content_en = get_notification_texts(
            "expert_team_join_approved", team_name=expert.name
        )
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=jr.user_id,
            notification_type="expert_team_join_approved",
            title=title_zh,
            content=content_zh,
            title_en=title_en,
            content_en=content_en,
            related_id=str(jr.id),
            related_type="expert_join_request",
        )
    except Exception as e:
        logger.warning(f"发送加入申请批准通知失败: {e}")

    return ExpertJoinRequestOut.model_validate(jr)


# ==================== 13. PUT /{expert_id}/members/{user_id}/role ====================

@expert_router.put("/{expert_id}/members/{user_id}/role", response_model=ExpertMemberOut)
async def change_member_role(
    expert_id: str,
    user_id: str,
    body: ExpertRoleChange,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """修改成员角色（Owner only）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    # 不能修改 owner 的角色
    target_member = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            )
        )
    )
    target = target_member.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=404, detail="成员不存在")
    if target.role == "owner":
        raise HTTPException(status_code=400, detail="不能修改团队所有者的角色")

    target.role = body.role
    target.updated_at = get_utc_time()
    await db.commit()
    await db.refresh(target)

    # 获取用户信息
    user_result = await db.execute(select(models.User).where(models.User.id == user_id))
    user = user_result.scalar_one_or_none()

    out = ExpertMemberOut.model_validate(target)
    if user:
        out.user_name = user.name
        out.user_avatar = user.avatar
    return out


# ==================== 14. POST /{expert_id}/transfer ====================

@expert_router.post("/{expert_id}/transfer")
async def transfer_ownership(
    expert_id: str,
    body: ExpertTransfer,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """转让团队所有权（Owner only）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    # 锁定 owner 行,串行化转让操作 — 防止 2 个并发 transfer 都通过 role 检查后
    # 各自把不同的 target 设为 owner,导致团队出现多个 owner
    owner_lock_result = await db.execute(
        select(ExpertMember)
        .where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.role == "owner",
                ExpertMember.status == "active",
            )
        )
        .with_for_update()
    )
    owner_member = owner_lock_result.scalar_one_or_none()
    if not owner_member:
        # 在锁等待期间,另一个并发转让已成功(current_user 已不是 owner)
        raise HTTPException(status_code=409, detail="所有权已被其他操作转让")

    # 幂等: 自己转给自己 = noop
    if body.new_owner_id == current_user.id:
        return {"detail": "无需转让(目标与当前 owner 相同)"}

    # 新 owner 必须是活跃成员
    new_owner_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == body.new_owner_id,
                ExpertMember.status == "active",
            )
        )
    )
    new_owner_member = new_owner_result.scalar_one_or_none()
    if not new_owner_member:
        raise HTTPException(status_code=400, detail="新所有者不是团队活跃成员")

    now = get_utc_time()
    new_owner_member.role = "owner"
    new_owner_member.updated_at = now
    owner_member.role = "admin"
    owner_member.updated_at = now

    # Phase 9: sync in-flight team task taker_id to new owner (spec §6.5)
    # Tasks still active (not yet completed) should reflect the current team
    # owner so notifications, "my tasks" lists, and UI all point to the right
    # person. Already-completed tasks keep their original taker_id (historical
    # snapshot).
    await db.execute(
        update(models.Task)
        .where(
            models.Task.taker_expert_id == expert_id,
            models.Task.status.in_(
                ["pending", "pending_payment", "in_progress", "disputed"]
            ),
        )
        .values(taker_id=body.new_owner_id)
    )

    await db.commit()
    return {"detail": "所有权已转让"}


# ==================== 15. DELETE /{expert_id}/members/{user_id} ====================

@expert_router.delete("/{expert_id}/members/{user_id}")
async def remove_member(
    expert_id: str,
    user_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """移除成员（Owner only）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    target_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            )
        )
    )
    target = target_result.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=404, detail="成员不存在")
    if target.role == "owner":
        raise HTTPException(status_code=400, detail="不能移除团队所有者")

    now = get_utc_time()
    target.status = "removed"
    target.updated_at = now
    expert.member_count = max(expert.member_count - 1, 0)

    # 清理该成员在此达人团队相关任务聊天中的参与记录
    # Task.expert_creator_id 存 user_id（旧系统），通过团队成员 user_ids 关联
    from app.models_expert import ChatParticipant
    from sqlalchemy import delete
    team_member_ids_result = await db.execute(
        select(ExpertMember.user_id).where(ExpertMember.expert_id == expert_id)
    )
    team_member_ids = [row[0] for row in team_member_ids_result.all()]
    if team_member_ids:
        await db.execute(
            delete(ChatParticipant).where(
                and_(
                    ChatParticipant.user_id == user_id,
                    ChatParticipant.task_id.in_(
                        select(models.Task.id).where(models.Task.expert_creator_id.in_(team_member_ids))
                    )
                )
            )
        )

    await db.commit()
    return {"detail": "成员已移除"}


# ==================== 16. POST /{expert_id}/leave ====================

@expert_router.post("/{expert_id}/leave")
async def leave_team(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """离开团队"""
    expert = await _get_expert_or_404(db, expert_id)
    member = await _get_member_or_403(db, expert_id, current_user.id)

    if member.role == "owner":
        raise HTTPException(status_code=400, detail="团队所有者不能直接离开，请先转让所有权")

    now = get_utc_time()
    member.status = "left"
    member.updated_at = now
    expert.member_count = max(expert.member_count - 1, 0)

    # 清理该成员在此达人团队相关任务聊天中的参与记录
    from app.models_expert import ChatParticipant
    from sqlalchemy import delete
    team_member_ids_result = await db.execute(
        select(ExpertMember.user_id).where(ExpertMember.expert_id == expert_id)
    )
    team_member_ids = [row[0] for row in team_member_ids_result.all()]
    if team_member_ids:
        await db.execute(
            delete(ChatParticipant).where(
                and_(
                    ChatParticipant.user_id == current_user.id,
                    ChatParticipant.task_id.in_(
                        select(models.Task.id).where(models.Task.expert_creator_id.in_(team_member_ids))
                    )
                )
            )
        )

    await db.commit()
    return {"detail": "已离开团队"}


# ==================== POST /{expert_id}/dissolve ====================

@expert_router.post("/{expert_id}/dissolve")
async def dissolve_expert_team(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """注销达人团队（仅 Owner）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    # 检查是否有进行中的任务
    # 注意：Task.expert_creator_id 存的是 user_id（旧系统），不是 expert team id
    # 通过 expert_members 找到所有团队成员，用他们的 user_id 查任务
    from app.models import ForumCategory
    member_user_ids = await db.execute(
        select(ExpertMember.user_id).where(ExpertMember.expert_id == expert_id)
    )
    member_ids = [row[0] for row in member_user_ids.all()]

    # 通过团队成员 user_ids 查关联任务（旧系统 expert_creator_id = user_id）
    active_tasks = 0
    if member_ids:
        task_result = await db.execute(
            select(func.count()).select_from(models.Task).where(
                and_(
                    models.Task.status.in_(["in_progress", "pending_payment", "pending_confirmation"]),
                    models.Task.expert_creator_id.in_(member_ids),
                )
            )
        )
        active_tasks = task_result.scalar_one()
    if active_tasks > 0:
        raise HTTPException(status_code=400, detail=f"有 {active_tasks} 个进行中的任务，无法注销")

    now = get_utc_time()

    # 达人状态 → dissolved
    expert.status = "dissolved"
    expert.updated_at = now

    # 所有服务下架
    await db.execute(
        models.TaskExpertService.__table__.update()
        .where(
            and_(
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
        .values(status="inactive")
    )

    # 所有未完成活动取消（Activity.expert_id 存 user_id，用团队成员 ID 匹配）
    if member_ids:
        await db.execute(
            models.Activity.__table__.update()
            .where(
                and_(
                    models.Activity.expert_id.in_(member_ids),
                    models.Activity.status == "open",
                )
            )
            .values(status="cancelled")
        )

    # 达人板块隐藏
    if expert.forum_category_id:
        board_result = await db.execute(
            select(ForumCategory).where(ForumCategory.id == expert.forum_category_id)
        )
        board = board_result.scalar_one_or_none()
        if board:
            board.is_visible = False

    # 所有成员状态 → left
    await db.execute(
        ExpertMember.__table__.update()
        .where(ExpertMember.expert_id == expert_id)
        .values(status="left", updated_at=now)
    )

    # 删除精选记录
    await db.execute(
        FeaturedExpertV2.__table__.delete()
        .where(FeaturedExpertV2.expert_id == expert_id)
    )

    await db.commit()
    return {"detail": "达人团队已注销"}


# ==================== PUT /{expert_id}/allow-applications ====================

@expert_router.put("/{expert_id}/allow-applications")
async def toggle_allow_applications(
    expert_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """开关团队申请入口（仅 Owner）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    allow = body.get("allow_applications")
    if allow is None:
        raise HTTPException(status_code=400, detail="缺少 allow_applications 字段")

    expert.allow_applications = bool(allow)
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"allow_applications": expert.allow_applications}


# ==================== 17. POST /{expert_id}/profile-update-request ====================

@expert_router.post(
    "/{expert_id}/profile-update-request",
    response_model=ExpertProfileUpdateOut,
    status_code=201,
)
async def request_profile_update(
    expert_id: str,
    body: ExpertProfileUpdateCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """申请修改团队资料（Owner only）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    # 检查是否有待审核的修改申请
    existing = await db.execute(
        select(ExpertProfileUpdateRequest).where(
            and_(
                ExpertProfileUpdateRequest.expert_id == expert_id,
                ExpertProfileUpdateRequest.status == "pending",
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="已有待审核的资料修改申请")

    update_req = ExpertProfileUpdateRequest(
        expert_id=expert_id,
        requester_id=current_user.id,
        new_name=body.new_name,
        new_bio=body.new_bio,
        new_avatar=body.new_avatar,
    )
    db.add(update_req)
    await db.commit()
    await db.refresh(update_req)
    return update_req


@expert_router.get(
    "/{expert_id}/profile-update-request",
    response_model=Optional[ExpertProfileUpdateOut],
)
async def get_pending_profile_update_request(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取当前待审核的团队资料修改申请（Owner/Admin/Member）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id)

    result = await db.execute(
        select(ExpertProfileUpdateRequest)
        .where(
            and_(
                ExpertProfileUpdateRequest.expert_id == expert_id,
                ExpertProfileUpdateRequest.status == "pending",
            )
        )
        .order_by(ExpertProfileUpdateRequest.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


# ==================== 18. PUT /{expert_id}/board ====================

@expert_router.put("/{expert_id}/board")
async def update_expert_board(
    expert_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """编辑达人板块名称和描述（Owner/Admin，无需审核）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    if not expert.forum_category_id:
        raise HTTPException(status_code=404, detail="达人板块不存在")

    from app.models import ForumCategory
    result = await db.execute(
        select(ForumCategory).where(ForumCategory.id == expert.forum_category_id)
    )
    board = result.scalar_one_or_none()
    if not board:
        raise HTTPException(status_code=404, detail="达人板块不存在")

    if 'name' in body:
        board.name = body['name']
    if 'name_en' in body:
        board.name_en = body['name_en']
    if 'name_zh' in body:
        board.name_zh = body['name_zh']
    if 'description' in body:
        board.description = body['description']
    if 'description_en' in body:
        board.description_en = body['description_en']
    if 'description_zh' in body:
        board.description_zh = body['description_zh']
    board.updated_at = get_utc_time()

    await db.commit()
    return {"detail": "板块已更新"}


# ==================== 19b. PUT /{expert_id}/location ====================

@expert_router.put("/{expert_id}/location")
async def update_expert_location(
    expert_id: str,
    body: ExpertLocationUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人团队基地地址和默认服务半径（Owner only，直接生效）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    update_data = body.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="至少需要修改一个字段")

    for key, value in update_data.items():
        setattr(expert, key, value)

    await db.commit()
    await db.refresh(expert)
    return {
        "message": "基地地址已更新",
        "location": expert.location,
        "latitude": float(expert.latitude) if expert.latitude else None,
        "longitude": float(expert.longitude) if expert.longitude else None,
        "service_radius_km": expert.service_radius_km,
    }


# ==================== 19c. PUT /{expert_id}/business-hours ====================

VALID_DAYS = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}

@expert_router.put("/{expert_id}/business-hours")
async def update_business_hours(
    expert_id: str,
    body: dict,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人团队每周营业时间（Owner/Admin，直接生效）

    Body: {"mon": {"open": "09:00", "close": "18:00"}, "sun": null, ...}
    key 缺失或 value=null 表示休息日。传空 {} 清空。
    """
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    # Validate
    for day, hours in body.items():
        if day not in VALID_DAYS:
            raise HTTPException(status_code=422, detail=f"无效的星期: {day}")
        if hours is not None:
            if not isinstance(hours, dict) or "open" not in hours or "close" not in hours:
                raise HTTPException(status_code=422, detail=f"{day}: 需要 open 和 close 字段")

    expert.business_hours = body if body else None
    await db.commit()
    await db.refresh(expert)
    return {"message": "营业时间已更新", "business_hours": expert.business_hours}


# ==================== 19. POST /{expert_id}/stripe-connect ====================

@expert_router.post("/{expert_id}/stripe-connect")
async def create_expert_stripe_connect(
    expert_id: str,
    request: Request,
    country: str = Query("GB"),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """为达人团队创建 Stripe Connect 账户（仅 Owner）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    # 已有账户
    if expert.stripe_account_id:
        import stripe
        try:
            account = stripe.Account.retrieve(expert.stripe_account_id)
            return {
                "account_id": expert.stripe_account_id,
                "details_submitted": account.details_submitted,
                "charges_enabled": account.charges_enabled,
                "message": "已有 Stripe 账户" if account.details_submitted else "请完成 Stripe 设置",
            }
        except Exception as e:
            # 账户不存在，清空重建
            expert.stripe_account_id = None
            expert.stripe_onboarding_complete = False
            await db.commit()

    # 创建新账户
    import stripe
    from app.stripe_config import ensure_stripe_configured
    ensure_stripe_configured()

    try:
        account = stripe.Account.create(
            type="express",
            country=country,
            email=current_user.email or f"expert_{expert_id}@link2ur.com",
            business_type="individual",
            metadata={
                "expert_id": expert_id,
                "expert_name": expert.name,
                "platform": "Link2Ur",
            },
            capabilities={
                "card_payments": {"requested": True},
                "transfers": {"requested": True},
            },
        )

        expert.stripe_account_id = account.id
        expert.stripe_connect_country = country
        expert.stripe_onboarding_complete = False
        expert.updated_at = get_utc_time()
        await db.commit()

        # 创建 onboarding link
        account_link = stripe.AccountLink.create(
            account=account.id,
            refresh_url=f"https://api.link2ur.com/api/experts/{expert_id}/stripe-connect?country={country}",
            return_url=f"https://www.link2ur.com/expert-teams/{expert_id}",
            type="account_onboarding",
        )

        return {
            "account_id": account.id,
            "onboarding_url": account_link.url,
            "message": "请在浏览器中完成 Stripe 账户设置",
        }
    except stripe.error.StripeError as e:
        raise HTTPException(status_code=502, detail=f"Stripe 错误: {str(e)}")


@expert_router.get("/{expert_id}/stripe-connect/status")
async def get_expert_stripe_status(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取达人团队 Stripe Connect 状态（Owner/Admin/Member）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin", "member"])

    if not expert.stripe_account_id:
        return {
            "has_account": False,
            "details_submitted": False,
            "charges_enabled": False,
        }

    import stripe
    from app.stripe_config import ensure_stripe_configured
    ensure_stripe_configured()

    try:
        account = stripe.Account.retrieve(expert.stripe_account_id)
        # 更新 onboarding 状态
        if account.details_submitted and not expert.stripe_onboarding_complete:
            expert.stripe_onboarding_complete = True
            await db.commit()

        return {
            "has_account": True,
            "account_id": expert.stripe_account_id,
            "details_submitted": account.details_submitted,
            "charges_enabled": account.charges_enabled,
            "country": expert.stripe_connect_country,
        }
    except stripe.error.StripeError as e:
        return {
            "has_account": True,
            "account_id": expert.stripe_account_id,
            "error": str(e),
        }

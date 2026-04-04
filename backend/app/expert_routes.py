"""
达人团队用户侧路由
Router prefix: /api/experts
"""

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
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
)
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_router = APIRouter(prefix="/api/experts", tags=["experts"])


# ==================== Auth ====================

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
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停")
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁")
            return user
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")


async def get_current_user_optional(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> Optional[models.User]:
    """可选用户认证（异步版本）"""
    try:
        return await get_current_user_secure_async_csrf(request, db)
    except HTTPException:
        return None


# ==================== Helpers ====================

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

    app = ExpertApplication(
        user_id=current_user.id,
        expert_name=body.expert_name,
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
        select(Expert)
        .join(ExpertMember, ExpertMember.expert_id == Expert.id)
        .where(
            and_(
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        )
        .order_by(Expert.created_at.desc())
    )
    experts = result.scalars().all()

    # 批量查询关注状态
    if experts:
        expert_ids = [e.id for e in experts]
        follow_result = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id.in_(expert_ids),
                )
            )
        )
        followed_ids = set(follow_result.scalars().all())
        out = []
        for e in experts:
            d = ExpertOut.model_validate(e)
            d.is_following = e.id in followed_ids
            out.append(d)
        return out
    return []


# ==================== 5. GET / (list/search) — placed before /{expert_id} ====================

@expert_router.get("", response_model=List[ExpertOut])
async def list_experts(
    request: Request,
    keyword: Optional[str] = Query(None),
    sort: Optional[str] = Query("created_at", regex="^(rating|created_at|completed_tasks)$"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """搜索/列表达人团队（公开）"""
    query = select(Expert).where(Expert.status == "active")

    if keyword:
        like = f"%{keyword}%"
        query = query.where(
            Expert.name.ilike(like)
            | Expert.name_en.ilike(like)
            | Expert.name_zh.ilike(like)
            | Expert.bio.ilike(like)
        )

    if sort == "rating":
        query = query.order_by(Expert.rating.desc())
    elif sort == "completed_tasks":
        query = query.order_by(Expert.completed_tasks.desc())
    else:
        query = query.order_by(Expert.created_at.desc())

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

    out = []
    for e in experts:
        d = ExpertOut.model_validate(e)
        d.is_following = e.id in followed_ids
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

    detail = ExpertDetailOut.model_validate(expert)
    detail.members = members_out
    detail.is_following = is_following
    detail.is_featured = is_featured
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
        return {"followed": False}
    else:
        follow = ExpertFollow(user_id=current_user.id, expert_id=expert_id)
        db.add(follow)
        await db.commit()
        return {"followed": True}


# ==================== 7. GET /{expert_id}/members ====================

@expert_router.get("/{expert_id}/members", response_model=List[ExpertMemberOut])
async def list_members(
    expert_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看团队成员列表"""
    await _get_expert_or_404(db, expert_id)

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

    # 检查团队是否已满
    expert = await _get_expert_or_404(db, invitation.expert_id)
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
        return ExpertJoinRequestOut.model_validate(jr)

    # approve
    jr.status = "approved"

    expert = await _get_expert_or_404(db, expert_id)
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
    owner_member = await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

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

    await db.commit()
    return {"detail": "已离开团队"}


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

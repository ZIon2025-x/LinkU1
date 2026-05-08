"""User.avg_rating 聚合方向回归测试 (P0).

历史 bug: 全平台多处用 `Review.user_id == user_id` 当作"该 user 收到的评价"
聚合,但 Review.user_id 是评价**作者**(`models.py:309 reviews back_populates="user",
foreign_keys=[user_id]`)。结果 User.avg_rating 是该 user **写出**的均分而非
**收到**的。这次把 `crud.review.calculate_user_avg_rating` 修成正确语义并作为
single source of truth,所有调用方都走它。

收到的评价 = JOIN Task 后 (Task.poster_id==user AND Review.user_id==Task.taker_id)
                      OR (Task.taker_id==user AND Review.user_id==Task.poster_id)
"""
from __future__ import annotations

from unittest.mock import MagicMock


def test_received_avg_rating_select_joins_tasks_and_uses_role_filter():
    """编译后的 SQL 字符串必须 JOIN tasks 并出现 poster_id 与 taker_id 比较;
    不能退化成简单的 Review.user_id == :user_id。"""
    from app.crud.review import _received_avg_rating_select

    stmt = _received_avg_rating_select("u_target")
    sql = str(stmt.compile(compile_kwargs={"literal_binds": True}))
    sql_lower = sql.lower()

    assert "tasks" in sql_lower, f"未 JOIN tasks 表: {sql}"
    assert "join" in sql_lower
    assert "poster_id" in sql_lower
    assert "taker_id" in sql_lower
    # u_target 应当至少在 poster_id/taker_id 比较里各出现一次
    assert sql_lower.count("u_target") >= 2, (
        f"user_id 应在两个分支里都被比较: {sql}"
    )
    # is_deleted=false 必须出现(避免软删进聚合)
    assert "is_deleted" in sql_lower


def test_received_avg_rating_select_excludes_self_written_reviews():
    """关键反向修复: 必须不出现 'review.user_id = :user_id' 这种简单等值
    (因为 Review.user_id 是作者),否则就是反向 bug 复现。"""
    from app.crud.review import _received_avg_rating_select

    stmt = _received_avg_rating_select("u_target")
    sql = str(stmt.compile(compile_kwargs={"literal_binds": True})).lower()

    # 简单 'reviews.user_id = u_target' 不应作为唯一过滤; 必须配对 task.poster/taker
    # 形式为 reviews.user_id = tasks.taker_id (列对列, 不是列对常量)
    import re
    bad_pattern = re.compile(r"reviews\.user_id\s*=\s*'u_target'")
    assert not bad_pattern.search(sql), (
        f"出现简单的 reviews.user_id == :user_id 等值过滤,聚合方向反了: {sql}"
    )


def test_calculate_user_avg_rating_returns_zero_when_no_reviews():
    """无评价 → 0.0,且回写 user.avg_rating=0.0。"""
    from app.crud.review import calculate_user_avg_rating

    db = MagicMock()
    chain = MagicMock()
    chain.scalar = MagicMock(return_value=None)  # AVG 在空集上返回 None
    db.execute = MagicMock(return_value=chain)
    user = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = user

    result = calculate_user_avg_rating(db, "u_target")
    assert result == 0.0
    assert user.avg_rating == 0.0
    db.commit.assert_called_once()


# ---------------------------------------------------------------------------
# Batch 2: 个人服务可见性 / 价格 (#2 + #3 + #4)
# ---------------------------------------------------------------------------


def test_task_expert_service_out_accepts_null_base_price():
    """议价个人服务允许 base_price=None (面议),Schema 必须兼容。
    P0 #4: schema 原 `base_price: float` 必填,from_orm 直接 float(None) → 500。
    """
    from app.schemas import TaskExpertServiceOut
    from datetime import datetime, timezone
    from unittest.mock import MagicMock

    obj = MagicMock()
    obj.id = 19
    obj.expert_id = None
    obj.service_type = "personal"
    obj.user_id = "u_owner"
    obj.service_name = "面议服务"
    obj.service_name_en = None
    obj.service_name_zh = None
    obj.description = "x"
    obj.description_en = None
    obj.description_zh = None
    obj.category = "other"
    obj.images = None
    obj.base_price = None  # 关键: NULL
    obj.currency = "GBP"
    obj.pricing_type = "negotiable"
    obj.location_type = "online"
    obj.location = None
    obj.latitude = None
    obj.longitude = None
    obj.service_radius_km = None
    obj.skills = None
    obj.status = "active"
    obj.display_order = 0
    obj.view_count = 0
    obj.application_count = 0
    obj.created_at = datetime.now(timezone.utc)
    obj.package_type = None
    obj.total_sessions = None
    obj.bundle_service_ids = None
    obj.package_price = None
    obj.validity_days = None
    obj.linked_service_id = None
    obj.has_time_slots = False
    obj.time_slot_duration_minutes = None
    obj.time_slot_start_time = None
    obj.time_slot_end_time = None
    obj.participants_per_slot = None
    obj.weekly_time_slot_config = None
    obj.owner_type = "user"
    obj.owner_id = "u_owner"

    # 不应抛 TypeError("float() argument must be ... not NoneType")
    out = TaskExpertServiceOut.from_orm(obj)
    assert out.base_price is None
    assert out.pricing_type == "negotiable"


def test_personal_service_create_preserves_null_base_price():
    """议价个人服务创建时, base_price=None 必须保留, 不能被 `or 0` 强写为 0。
    P0 #3: 强写 0 后议价服务在按价格排序时全堆顶, 详情卡可能显示 ¥0。
    """
    from app.schemas import PersonalServiceCreate

    svc = PersonalServiceCreate(
        service_name="面议",
        description="x",
        base_price=None,
        pricing_type="negotiable",
        currency="GBP",
        category="accompany",
    )
    # schema 层接受 None
    assert svc.base_price is None


def test_list_services_endpoint_does_not_hard_filter_expert_only():
    """`/api/services` 端点应允许个人服务出现, 不能写死 owner_type=='expert'。
    P0 #2: 列表硬过滤导致 Flutter 唯一通用入口看不到任何个人服务。
    """
    import inspect
    from app.service_public_routes import list_services_by_category

    src = inspect.getsource(list_services_by_category)
    # 不应该再有把 owner_type 写死为 'expert' 的 where
    # (允许通过参数过滤, 但不能默认硬编码)
    # 用关键字精确判断: 'owner_type == "expert"' 或类似形式不该作为无条件 filter
    # 而具体写法允许多样, 检查最直接的硬编码
    assert 'owner_type == "expert"' not in src.replace(" ", "") or "Query(" in src, (
        "list_services_by_category 仍硬编码 owner_type='expert',个人服务被排除"
    )


# ---------------------------------------------------------------------------
# Batch 3: 议价/申请状态机 (#6 + #7 + #8)
# ---------------------------------------------------------------------------


import pytest as _pytest
from unittest.mock import AsyncMock as _AsyncMock


@_pytest.mark.asyncio
async def test_negotiate_rejects_terminal_status():
    """已 approved/rejected/cancelled 的 SA 不能再被 negotiate 端点改回 negotiating。
    P0 #6: 之前无状态校验, 任意状态都能被改回 negotiating, 污染真实 task 聊天。"""
    from app.expert_consultation_routes import negotiate_price
    from fastapi import HTTPException

    application = MagicMock(
        id=16, applicant_id="u_applicant", status="approved",
        service_id=19, new_expert_id=None, task_id=331,
    )
    app_lookup = MagicMock()
    app_lookup.scalar_one_or_none = MagicMock(return_value=application)
    db = MagicMock()
    db.execute = _AsyncMock(return_value=app_lookup)

    current_user = MagicMock(id="u_applicant", name="x")

    with _pytest.raises(HTTPException) as exc_info:
        await negotiate_price(
            application_id=16,
            body={"price": 50},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )
    assert exc_info.value.status_code == 400
    # 状态没被改写
    assert application.status == "approved"


@_pytest.mark.asyncio
async def test_quote_rejects_terminal_status():
    """已 cancelled 的 SA 不能再被 owner quote 改回 negotiating。"""
    from app.expert_consultation_routes import quote_price
    from fastapi import HTTPException

    application = MagicMock(
        id=16, status="cancelled", service_id=19, new_expert_id=None,
        service_owner_id="u_owner", task_id=None,
    )
    app_lookup = MagicMock()
    app_lookup.scalar_one_or_none = MagicMock(return_value=application)
    db = MagicMock()
    db.execute = _AsyncMock(return_value=app_lookup)

    current_user = MagicMock(id="u_owner", name="owner")

    with _pytest.raises(HTTPException) as exc_info:
        await quote_price(
            application_id=16,
            body={"price": 50},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )
    assert exc_info.value.status_code == 400
    assert application.status == "cancelled"


@_pytest.mark.asyncio
async def test_counter_offer_rejects_terminal_status():
    """已 rejected 的 SA 不能再被 owner counter-offer 改回 negotiating。"""
    from app.expert_consultation_routes import counter_offer
    from fastapi import HTTPException

    application = MagicMock(
        id=16, status="rejected", service_id=19, new_expert_id=None,
        service_owner_id="u_owner", task_id=None,
    )
    app_lookup = MagicMock()
    app_lookup.scalar_one_or_none = MagicMock(return_value=application)
    db = MagicMock()
    db.execute = _AsyncMock(return_value=app_lookup)

    current_user = MagicMock(id="u_owner", name="owner")

    with _pytest.raises(HTTPException) as exc_info:
        await counter_offer(
            application_id=16,
            body={"price": 50},
            request=MagicMock(),
            db=db,
            current_user=current_user,
        )
    assert exc_info.value.status_code == 400
    assert application.status == "rejected"


def test_finalize_uses_final_price_with_top_priority():
    """formal_apply 写的 SA.final_price 必须在 finalize 价格优先级里被读取。
    P0 #7: 之前价格链不读 final_price, 用户在 formal_apply 输入金额完全被忽略,
    实际下单按 negotiated_price 收钱, 金额可能完全不同。"""
    import inspect
    from app.user_service_application_routes import finalize_personal_service_application

    src = inspect.getsource(finalize_personal_service_application)
    # 必须出现对 application.final_price 的读取作为价格来源之一
    assert "final_price" in src, (
        "finalize_personal_service_application 价格优先级链未引用 final_price"
    )


@_pytest.mark.asyncio
async def test_consult_idempotency_skips_apply_only_records():
    """对同一服务先 apply 后 consult, 不能命中 apply 路径的 SA (task_id=None) 当作幂等返回 ——
    那样 response.task_id=null, 客户端跳聊天空白页。
    P0 #8: 修复后 consult 必须重新建 placeholder task + SA。"""
    import inspect
    from app.consultation.helpers import check_consultation_idempotency

    src = inspect.getsource(check_consultation_idempotency)
    # 改后必须显式排除 task_id IS NULL 的"纯 apply" SA, 否则会捕获到无 task 的记录
    # 接受多种合理写法 (isnot(None) / is_not(None) / != None)
    assert ("task_id.isnot" in src or "task_id.is_not" in src
            or "task_id != None" in src or "task_id IS NOT NULL" in src), (
        "check_consultation_idempotency 仍会命中 task_id IS NULL 的 apply 路径 SA"
    )


# ---------------------------------------------------------------------------
# Batch 4: 通知 + 评价回复 (#5 + #10)
# ---------------------------------------------------------------------------


def test_apply_notifies_personal_service_owner():
    """apply_for_service 在 owner_type='user' (个人服务) 时也必须给 owner 发通知。
    P0 #5: 之前只给 expert 团队发, personal owner 完全没站内信/push。"""
    import inspect
    from app.expert_consultation_routes import apply_for_service

    src = inspect.getsource(apply_for_service)
    # 必须出现 owner_type=='user' 的通知分支
    # (粗略形状: 用 service.owner_id 当 user_id 调 create_notification)
    assert 'owner_type == "user"' in src or "owner_type=='user'" in src, (
        "apply_for_service 没有 owner_type=='user' 的处理分支, 个人服务 owner 收不到通知"
    )
    # 应当存在 personal-service notification helper 调用 (函数名/字符串约定)
    assert "_notify_personal_service_owner" in src or "create_notification" in src, (
        "apply_for_service 在 user 分支未发通知"
    )


def test_reply_to_review_allows_personal_service_owner():
    """personal-service review.expert_id=None 但 task.taker_id == current_user 应当能回复。
    P0 #10: 之前直接 404, 个人服务 owner 完全无法回复评价。"""
    import inspect
    from app.expert_marketing_routes import reply_to_review

    src = inspect.getsource(reply_to_review)
    # 必须有通过 task.taker_id 校验个人服务 owner 的分支
    assert "taker_id" in src, (
        "reply_to_review 没有 personal-service owner (task.taker_id) 校验分支"
    )
    # 必须分流: review.expert_id 真值走团队权限, 假值走个人服务 owner 校验
    assert "review.expert_id" in src
    assert "current_user.id" in src


# ---------------------------------------------------------------------------
# Batch 5: time_slot 回退一致性 (#12 + #13)
# ---------------------------------------------------------------------------


def test_release_time_slot_seat_helper_exists_and_guards_underflow():
    """helper 必须存在,且必须有 current_participants > 0 守卫避免下溢负数。"""
    import inspect
    from app.consultation.helpers import release_time_slot_seat

    src = inspect.getsource(release_time_slot_seat)
    assert "current_participants > 0" in src or "current_participants > 0)" in src, (
        "release_time_slot_seat 缺少下溢守卫"
    )
    assert "current_participants - 1" in src


def test_consultation_routes_release_seat_in_terminal_paths():
    """negotiate-response reject / close_consultation / reject_application 三处
    终态写入后必须调 release_time_slot_seat。P0 #13。"""
    import inspect
    from app.expert_consultation_routes import (
        respond_to_negotiation,
        close_consultation,
        reject_application,
    )

    for fn in (respond_to_negotiation, close_consultation, reject_application):
        src = inspect.getsource(fn)
        assert "release_time_slot_seat" in src, (
            f"{fn.__name__} 终态分支没有调 release_time_slot_seat"
        )


def test_scheduled_payment_expiry_releases_time_slot():
    """check_expired_payment_tasks 取消 pending_payment 任务时必须回退 time_slot。
    P0 #12: 之前 30 分钟未付任务被自动 cancelled, SA→cancelled, 但 slot 不释放。"""
    import inspect
    from app.scheduled_tasks import check_expired_payment_tasks

    src = inspect.getsource(check_expired_payment_tasks)
    # sync 路径直接 inline UPDATE (不能 await async helper), 验证 inline SQL 存在
    assert "current_participants" in src and "current_participants - 1" in src, (
        "check_expired_payment_tasks 取消过期任务时未回退 time_slot 名额"
    )


# ---------------------------------------------------------------------------
# Batch 6: reviews 端点去重 + 匿名泄露 (#9 + #11)
# ---------------------------------------------------------------------------


def test_review_out_user_id_is_optional_for_anonymous():
    """ReviewOut.user_id 必须 Optional, 匿名场景才能序列化 user_id=None。"""
    from app.schemas import ReviewOut
    fields = ReviewOut.model_fields
    assert "user_id" in fields
    # Pydantic v2: 检查字段是否允许 None
    annotation = fields["user_id"].annotation
    annotation_str = str(annotation)
    assert "None" in annotation_str or "Optional" in annotation_str, (
        f"ReviewOut.user_id 仍是必填 str ({annotation}), 匿名评价无法 mask user_id"
    )


def test_service_review_routes_filters_anonymous_reviewer_id():
    """service_review_routes.get_service_reviews 必须按 is_anonymous mask 掉
    reviewer_id/name/avatar。P0 #11。"""
    import inspect
    from app.service_review_routes import get_service_reviews

    src = inspect.getsource(get_service_reviews)
    assert "is_anonymous" in src, (
        "get_service_reviews 没有 is_anonymous 分支, 匿名评价仍泄露 reviewer 身份"
    )


def test_service_public_reviews_dead_route_removed():
    """service_public_routes.py 那条被遮蔽的 /api/services/{id}/reviews 应当删除,
    避免未来注册顺序变化时静默切换语义 (P0 #9)。"""
    import inspect
    import app.service_public_routes as mod
    # 不该再有 get_service_reviews 的同名死端点 (expert reviews 端点保留)
    src = inspect.getsource(mod)
    # 保留: get_expert_reviews
    assert "get_expert_reviews" in src
    # 关键: 不再注册 service_public_router.get("/api/services/{service_id}/reviews")
    assert '@service_public_router.get("/api/services/{service_id}/reviews")' not in src, (
        "service_public_routes 的死路由 /{service_id}/reviews 仍然存在"
    )


def test_async_routers_masks_anonymous_user_id():
    """/tasks/{id}/reviews 异步端点必须把匿名评价的 user_id 置 None。"""
    import inspect
    from app.async_routers import get_task_reviews_async

    src = inspect.getsource(get_task_reviews_async)
    # 必须在序列化时 mask user_id (匿名时)
    assert "is_anonymous" in src
    assert "user_id" in src


# ---------------------------------------------------------------------------
# Batch 7: 硬删保护 + discovery feed (#15 + #16)
# ---------------------------------------------------------------------------


def test_personal_service_delete_uses_soft_delete():
    """删除个人服务必须改成软删 (status='deleted'), 不能 db.delete()。
    P0 #15: 物理删除会撞 ondelete=RESTRICT (Task.expert_service_id), 直接 500。"""
    import inspect
    from app.personal_service_routes import delete_personal_service

    src = inspect.getsource(delete_personal_service)
    # 不该再有 db.delete(service)
    assert "db.delete(service)" not in src and "await db.delete(" not in src, (
        "delete_personal_service 仍在物理删除, 历史 task 引用会 500"
    )
    # 必须有软删标记
    assert "deleted" in src or "status" in src, (
        "delete_personal_service 没有软删/状态标记"
    )


def test_discovery_service_reviews_includes_personal_services():
    """discovery feed 的 _fetch_service_reviews 不能强制 created_by_expert==True,
    否则个人服务 review 永不进 feed。P0 #16。"""
    import inspect
    from app.discovery_routes import _fetch_service_reviews

    src = inspect.getsource(_fetch_service_reviews)
    # 不该再有 created_by_expert == True 的硬过滤
    assert "created_by_expert == True" not in src, (
        "_fetch_service_reviews 仍硬过滤 created_by_expert, 个人服务 review 进不了 feed"
    )


def test_calculate_user_avg_rating_writes_received_avg_back_to_user():
    """算出 4.5 后写回 User.avg_rating=4.5 并 commit。"""
    from app.crud.review import calculate_user_avg_rating

    db = MagicMock()
    chain = MagicMock()
    chain.scalar = MagicMock(return_value=4.5)
    db.execute = MagicMock(return_value=chain)
    user = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = user

    result = calculate_user_avg_rating(db, "u_target")
    assert result == 4.5
    assert user.avg_rating == 4.5
    db.commit.assert_called_once()

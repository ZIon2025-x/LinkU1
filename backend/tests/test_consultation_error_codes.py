"""咨询错误码测试 — 确认每个常量被定义且被路由代码实际引用。

Task 6 (F6a) 后端咨询错误码标准化后的三层验证:

  1. 常量存在性: error_codes.py 里 12 个常量都有,且字符串值与名字一致。
  2. 辅助函数行为: raise_http_error_with_code 产生正确的 {error_code, message} detail。
  3. 路由集成: 每个常量在 3 个目标路由文件里至少有一处被引用 (防死常量)。
  4. 行为级单元测试: 最常见的 3 个错误路径 (SERVICE_NOT_FOUND, CANNOT_CONSULT_SELF,
     CONSULTATION_NOT_FOUND) 模拟调用 endpoint, 断言 HTTPException.detail.error_code。
"""

import os
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.consultation import error_codes


# =============================================================================
# 1. 常量层
# =============================================================================

EXPECTED_CODES = {
    "CONSULTATION_ALREADY_EXISTS",
    "CONSULTATION_NOT_FOUND",
    "CONSULTATION_CLOSED",
    "SERVICE_NOT_FOUND",
    "SERVICE_INACTIVE",
    "TASK_NOT_FOUND",
    "EXPERT_TEAM_NOT_FOUND",
    "EXPERT_TEAM_INACTIVE",
    "CANNOT_CONSULT_SELF",
    "NOT_SERVICE_OWNER",
    "NOT_TEAM_MEMBER",
    "INSUFFICIENT_TEAM_ROLE",
    "INVALID_STATUS_TRANSITION",
    "PRICE_OUT_OF_RANGE",
}


def test_all_error_code_constants_defined():
    """锚定 12 个 (+1 额外) 错误码常量存在且与字符串值一致 (防止 typo)。"""
    for name in EXPECTED_CODES:
        value = getattr(error_codes, name, None)
        assert value is not None, f"error_codes.{name} not defined"
        assert value == name, (
            f"error_codes.{name} should equal the string {name!r}, got {value!r}"
        )


# =============================================================================
# 2. 辅助函数层
# =============================================================================


def test_raise_http_error_with_code_wraps_detail():
    """验证 raise_http_error_with_code 产生 {error_code, message} 结构的 detail。"""
    from app.error_handlers import raise_http_error_with_code

    with pytest.raises(HTTPException) as exc:
        raise_http_error_with_code("测试消息", 400, error_codes.SERVICE_NOT_FOUND)

    assert exc.value.status_code == 400
    assert exc.value.detail == {
        "error_code": "SERVICE_NOT_FOUND",
        "message": "测试消息",
    }


def test_raise_http_error_with_code_preserves_status_code():
    """验证不同 status_code 都能正确传递。"""
    from app.error_handlers import raise_http_error_with_code

    for sc in (400, 403, 404, 409):
        with pytest.raises(HTTPException) as exc:
            raise_http_error_with_code("m", sc, error_codes.CONSULTATION_NOT_FOUND)
        assert exc.value.status_code == sc


# =============================================================================
# 3. 路由集成 (grep-style health check)
# =============================================================================


ROUTE_FILES = [
    "expert_consultation_routes.py",
    "task_chat_routes.py",
    "flea_market_routes.py",
]

# 这些错误码由 Task 6 在咨询路由中直接引用
# (NOT_TEAM_MEMBER / INSUFFICIENT_TEAM_ROLE 由 Task 2 的 require_team_role 抛出,
#  CONSULTATION_ALREADY_EXISTS 没有路由 branch 抛它 — 幂等分支直接返回旧记录,
#  这两类暂时不要求在这三个文件里出现)
DIRECTLY_USED_IN_ROUTES = {
    "SERVICE_NOT_FOUND",
    "SERVICE_INACTIVE",
    "TASK_NOT_FOUND",
    "EXPERT_TEAM_NOT_FOUND",
    "EXPERT_TEAM_INACTIVE",
    "CANNOT_CONSULT_SELF",
    "NOT_SERVICE_OWNER",
    "CONSULTATION_NOT_FOUND",
    "INVALID_STATUS_TRANSITION",
    "PRICE_OUT_OF_RANGE",
}


def _read_all_route_sources():
    app_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "app",
    )
    combined = []
    for name in ROUTE_FILES:
        path = os.path.join(app_dir, name)
        with open(path, "r", encoding="utf-8") as fp:
            combined.append(fp.read())
    return "\n".join(combined)


def test_directly_used_error_codes_have_caller_in_routes():
    """每个主要错误码在至少一个目标路由文件里被 `error_codes.<NAME>` 引用。"""
    sources = _read_all_route_sources()
    missing = []
    for code in DIRECTLY_USED_IN_ROUTES:
        needle = f"error_codes.{code}"
        if needle not in sources:
            missing.append(code)
    assert not missing, (
        f"These error codes are defined but never referenced as error_codes.<NAME> "
        f"in consultation route files: {missing}"
    )


def test_other_error_codes_still_defined_even_if_not_used_in_these_routes():
    """未被本次路由直接引用的 code 允许存在 (另一个任务或其他文件会用)。

    这里做弱断言,仅确保常量还在 module 里;强断言放 `test_all_error_code_constants_defined`。
    """
    for code in EXPECTED_CODES - DIRECTLY_USED_IN_ROUTES:
        assert getattr(error_codes, code, None) == code


# =============================================================================
# 4. 行为级集成测试 (mock DB, 调 endpoint, 验证 HTTPException.detail.error_code)
# =============================================================================


def _make_current_user(user_id="u1", name="Alice"):
    u = MagicMock()
    u.id = user_id
    u.name = name
    return u


@pytest.mark.asyncio
async def test_create_consultation_on_missing_service_returns_service_not_found():
    """POST /api/services/{id}/consult → 服务不存在 → SERVICE_NOT_FOUND"""
    from app.expert_consultation_routes import create_consultation

    db = MagicMock()
    empty_result = MagicMock()
    empty_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=empty_result)

    with pytest.raises(HTTPException) as exc:
        await create_consultation(
            service_id=999,
            request=MagicMock(),
            body=None,
            db=db,
            current_user=_make_current_user(),
        )

    assert exc.value.status_code == 404
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.SERVICE_NOT_FOUND


@pytest.mark.asyncio
async def test_create_team_consultation_on_missing_team_returns_expert_team_not_found():
    """POST /api/experts/{id}/consult → 团队不存在 → EXPERT_TEAM_NOT_FOUND"""
    import app.expert_consultation_routes as ecr

    # 路由对象里找 create_team_consultation 的实际函数
    # (endpoint 名字在 expert_consultation_routes.py 里,路径是 /api/experts/{expert_id}/consult)
    # 我们通过遍历 router 的 routes 拿 endpoint 回调
    target = None
    for r in ecr.consultation_router.routes:
        if getattr(r, "path", None) == "/api/experts/{expert_id}/consult":
            target = r.endpoint
            break
    assert target is not None, "create_team_consultation endpoint not found on router"

    db = MagicMock()
    empty_result = MagicMock()
    empty_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=empty_result)

    with pytest.raises(HTTPException) as exc:
        await target(
            expert_id="e_missing",
            request=MagicMock(),
            body=None,
            db=db,
            current_user=_make_current_user(),
        )

    assert exc.value.status_code == 404
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.EXPERT_TEAM_NOT_FOUND


@pytest.mark.asyncio
async def test_close_consultation_on_missing_application_returns_consultation_not_found():
    """POST /api/applications/{id}/close → 申请不存在 → CONSULTATION_NOT_FOUND"""
    from app.expert_consultation_routes import close_consultation

    db = MagicMock()
    empty_result = MagicMock()
    empty_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=empty_result)

    with pytest.raises(HTTPException) as exc:
        await close_consultation(
            application_id=12345,
            request=MagicMock(),
            db=db,
            current_user=_make_current_user(),
        )

    assert exc.value.status_code == 404
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.CONSULTATION_NOT_FOUND


@pytest.mark.asyncio
async def test_flea_market_consult_on_own_item_returns_cannot_consult_self():
    """POST /items/{id}/consult → 自己的商品 → CANNOT_CONSULT_SELF"""
    from app.flea_market_routes import create_flea_market_consultation

    me = _make_current_user(user_id="u_me")
    item = MagicMock()
    item.id = 1
    item.status = "active"
    item.seller_id = "u_me"  # 咨询者 == 卖家
    item.title = "Old bike"

    db = MagicMock()
    item_result = MagicMock()
    item_result.scalar_one_or_none.return_value = item
    db.execute = AsyncMock(return_value=item_result)

    with pytest.raises(HTTPException) as exc:
        await create_flea_market_consultation(
            item_id="1",
            current_user=me,
            db=db,
        )

    assert exc.value.status_code == 400
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.CANNOT_CONSULT_SELF


@pytest.mark.asyncio
async def test_close_task_consultation_on_wrong_status_returns_invalid_transition():
    """POST /api/applications/{id}/close with already-approved app → INVALID_STATUS_TRANSITION"""
    from app.expert_consultation_routes import close_consultation

    me = _make_current_user(user_id="u_applicant")
    application = MagicMock()
    application.id = 1
    application.status = "approved"  # 已批准 — 不允许关闭
    application.applicant_id = "u_applicant"
    application.service_owner_id = None
    application.new_expert_id = None
    application.service_id = None

    db = MagicMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = application
    db.execute = AsyncMock(return_value=result)

    # mock _check_application_party 不抛异常
    with patch(
        "app.expert_consultation_routes._check_application_party",
        new=AsyncMock(return_value=None),
    ):
        with pytest.raises(HTTPException) as exc:
            await close_consultation(
                application_id=1,
                request=MagicMock(),
                db=db,
                current_user=me,
            )

    assert exc.value.status_code == 400
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.INVALID_STATUS_TRANSITION


@pytest.mark.asyncio
async def test_consult_nonexistent_task_raises_task_not_found():
    """POST /api/tasks/{id}/consult → 任务不存在 → TASK_NOT_FOUND"""
    from app.task_chat_routes import create_task_consultation

    db = MagicMock()
    empty_result = MagicMock()
    empty_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=empty_result)

    with pytest.raises(HTTPException) as exc:
        await create_task_consultation(
            task_id=999999,
            request=MagicMock(),
            current_user=_make_current_user(),
            db=db,
        )

    assert exc.value.status_code == 404
    assert isinstance(exc.value.detail, dict)
    assert exc.value.detail.get("error_code") == error_codes.TASK_NOT_FOUND

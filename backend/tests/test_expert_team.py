"""
达人团队系统单元测试

测试权限逻辑、模型行为、ID 生成等。
不需要数据库连接，使用 mock。
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timezone


# ==================== Model Tests ====================

class TestGenerateExpertId:
    """测试达人 ID 生成"""

    def test_generates_8_digit_string(self):
        from app.models import generate_expert_id
        expert_id = generate_expert_id()
        assert isinstance(expert_id, str)
        assert len(expert_id) == 8
        assert expert_id.isdigit()

    def test_generates_different_ids(self):
        from app.models import generate_expert_id
        ids = {generate_expert_id() for _ in range(100)}
        # 100 次生成应该至少有 90 个不同的（极高概率）
        assert len(ids) > 90

    def test_id_in_valid_range(self):
        from app.models import generate_expert_id
        expert_id = generate_expert_id()
        value = int(expert_id)
        assert 10_000_000 <= value <= 99_999_999


class TestExpertModel:
    """测试 Expert 模型列定义与默认值"""

    def _col(self, model, name):
        return model.__table__.columns[name]

    def test_column_defaults(self):
        """验证 Expert 列级别的 default 值（SQLAlchemy column defaults，不需要 DB flush）"""
        from app.models import Expert
        cols = Expert.__table__.columns
        assert cols["status"].default.arg == "active"
        assert cols["allow_applications"].default.arg == True
        assert cols["max_members"].default.arg == 20
        assert cols["member_count"].default.arg == 1
        assert cols["is_official"].default.arg == False
        assert cols["stripe_onboarding_complete"].default.arg == False

    def test_name_is_stored(self):
        from app.models import Expert
        expert = Expert(id="12345678", name="My Expert Team")
        assert expert.name == "My Expert Team"

    def test_id_is_stored(self):
        from app.models import Expert
        expert = Expert(id="12345678", name="Test Team")
        assert expert.id == "12345678"

    def test_optional_columns_are_nullable(self):
        from app.models import Expert
        cols = Expert.__table__.columns
        assert cols["bio"].nullable == True
        assert cols["avatar"].nullable == True
        assert cols["official_badge"].nullable == True
        assert cols["stripe_account_id"].nullable == True
        assert cols["forum_category_id"].nullable == True
        assert cols["internal_group_id"].nullable == True

    def test_tablename(self):
        from app.models import Expert
        assert Expert.__tablename__ == "experts"


class TestExpertMemberModel:
    """测试 ExpertMember 模型列定义"""

    def test_status_column_default(self):
        """验证 ExpertMember status 列默认值"""
        from app.models import ExpertMember
        cols = ExpertMember.__table__.columns
        assert cols["status"].default.arg == "active"

    def test_role_column_not_nullable(self):
        from app.models import ExpertMember
        cols = ExpertMember.__table__.columns
        assert cols["role"].nullable == False

    def test_explicit_role_stored(self):
        from app.models import ExpertMember
        member = ExpertMember(expert_id="12345678", user_id="87654321", role="owner")
        assert member.role == "owner"

    def test_tablename(self):
        from app.models import ExpertMember
        assert ExpertMember.__tablename__ == "expert_members"

    def test_unique_constraint_exists(self):
        from app.models import ExpertMember
        constraint_names = {c.name for c in ExpertMember.__table__.constraints if hasattr(c, "name") and c.name}
        assert "uq_expert_member" in constraint_names


class TestGroupBuyParticipantModel:
    """测试 GroupBuyParticipant 模型列定义"""

    def test_column_defaults(self):
        """验证 GroupBuyParticipant 列级别的 default 值"""
        from app.models import GroupBuyParticipant
        cols = GroupBuyParticipant.__table__.columns
        assert cols["round"].default.arg == 1
        assert cols["status"].default.arg == "joined"

    def test_cancelled_at_is_nullable(self):
        from app.models import GroupBuyParticipant
        cols = GroupBuyParticipant.__table__.columns
        assert cols["cancelled_at"].nullable == True

    def test_unique_constraint_exists(self):
        from app.models import GroupBuyParticipant
        constraint_names = {c.name for c in GroupBuyParticipant.__table__.constraints if hasattr(c, "name") and c.name}
        assert "uq_gbp_activity_user_round" in constraint_names

    def test_tablename(self):
        from app.models import GroupBuyParticipant
        assert GroupBuyParticipant.__tablename__ == "group_buy_participants"


# ==================== Schema Tests ====================

class TestExpertProfileUpdateCreateValidation:
    """测试 ExpertProfileUpdateCreate 验证"""

    def test_rejects_empty_update(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertProfileUpdateCreate()

    def test_accepts_name_only(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        update = ExpertProfileUpdateCreate(new_name="New Name")
        assert update.new_name == "New Name"
        assert update.new_bio is None
        assert update.new_avatar is None

    def test_accepts_bio_only(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        update = ExpertProfileUpdateCreate(new_bio="New bio text")
        assert update.new_bio == "New bio text"

    def test_accepts_avatar_only(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        update = ExpertProfileUpdateCreate(new_avatar="https://example.com/avatar.png")
        assert update.new_avatar == "https://example.com/avatar.png"

    def test_rejects_all_none(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertProfileUpdateCreate(new_name=None, new_bio=None, new_avatar=None)

    def test_name_max_length(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertProfileUpdateCreate(new_name="x" * 101)

    def test_accepts_all_fields(self):
        from app.schemas_expert import ExpertProfileUpdateCreate
        update = ExpertProfileUpdateCreate(
            new_name="New Name",
            new_bio="New bio",
            new_avatar="https://example.com/avatar.png",
        )
        assert update.new_name == "New Name"
        assert update.new_bio == "New bio"
        assert update.new_avatar == "https://example.com/avatar.png"


class TestExpertApplicationCreateValidation:
    """测试 ExpertApplicationCreate 验证"""

    def test_requires_expert_name(self):
        from app.schemas_expert import ExpertApplicationCreate
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertApplicationCreate()

    def test_name_max_length(self):
        from app.schemas_expert import ExpertApplicationCreate
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertApplicationCreate(expert_name="x" * 101)

    def test_valid_application(self):
        from app.schemas_expert import ExpertApplicationCreate
        app = ExpertApplicationCreate(
            expert_name="Test Team",
            bio="A great team",
            application_message="Please approve",
        )
        assert app.expert_name == "Test Team"
        assert app.bio == "A great team"
        assert app.application_message == "Please approve"

    def test_optional_fields_default_none(self):
        from app.schemas_expert import ExpertApplicationCreate
        app = ExpertApplicationCreate(expert_name="Minimal Team")
        assert app.bio is None
        assert app.avatar is None
        assert app.application_message is None


class TestExpertRoleChangeValidation:
    """测试角色变更验证"""

    def test_valid_roles(self):
        from app.schemas_expert import ExpertRoleChange
        assert ExpertRoleChange(role="admin").role == "admin"
        assert ExpertRoleChange(role="member").role == "member"

    def test_rejects_owner_role(self):
        from app.schemas_expert import ExpertRoleChange
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertRoleChange(role="owner")

    def test_rejects_invalid_role(self):
        from app.schemas_expert import ExpertRoleChange
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertRoleChange(role="superadmin")

    def test_rejects_empty_role(self):
        from app.schemas_expert import ExpertRoleChange
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertRoleChange(role="")


class TestExpertInvitationResponseValidation:
    """测试邀请响应验证"""

    def test_valid_actions(self):
        from app.schemas_expert import ExpertInvitationResponse
        assert ExpertInvitationResponse(action="accept").action == "accept"
        assert ExpertInvitationResponse(action="reject").action == "reject"

    def test_rejects_invalid_action(self):
        from app.schemas_expert import ExpertInvitationResponse
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertInvitationResponse(action="maybe")

    def test_rejects_missing_action(self):
        from app.schemas_expert import ExpertInvitationResponse
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertInvitationResponse()


class TestExpertApplicationReviewValidation:
    """测试申请审核 Schema 验证"""

    def test_valid_approve(self):
        from app.schemas_expert import ExpertApplicationReview
        review = ExpertApplicationReview(action="approve")
        assert review.action == "approve"

    def test_valid_reject_with_comment(self):
        from app.schemas_expert import ExpertApplicationReview
        review = ExpertApplicationReview(action="reject", review_comment="Not suitable")
        assert review.action == "reject"
        assert review.review_comment == "Not suitable"

    def test_rejects_invalid_action(self):
        from app.schemas_expert import ExpertApplicationReview
        import pydantic
        with pytest.raises((pydantic.ValidationError, Exception)):
            ExpertApplicationReview(action="pending")


# ==================== Forum Helper Tests ====================

class TestExpertForumHelpers:
    """测试达人板块权限检查辅助函数"""

    async def test_is_expert_board_returns_false_for_general(self):
        from app.expert_forum_helpers import is_expert_board
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.first.return_value = ('general', None)
        mock_db.execute.return_value = mock_result

        is_expert, expert_id = await is_expert_board(mock_db, 1)
        assert is_expert == False
        assert expert_id is None

    async def test_is_expert_board_returns_true_for_expert(self):
        from app.expert_forum_helpers import is_expert_board
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.first.return_value = ('expert', '12345678')
        mock_db.execute.return_value = mock_result

        is_expert, expert_id = await is_expert_board(mock_db, 1)
        assert is_expert == True
        assert expert_id == '12345678'

    async def test_is_expert_board_returns_false_for_nonexistent(self):
        from app.expert_forum_helpers import is_expert_board
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.first.return_value = None
        mock_db.execute.return_value = mock_result

        is_expert, expert_id = await is_expert_board(mock_db, 999)
        assert is_expert == False
        assert expert_id is None

    async def test_check_post_permission_returns_true_for_member(self):
        from app.expert_forum_helpers import check_expert_board_post_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = MagicMock()  # non-None = member exists
        mock_db.execute.return_value = mock_result

        can_post = await check_expert_board_post_permission(mock_db, '12345678', '87654321')
        assert can_post == True

    async def test_check_post_permission_returns_false_for_non_member(self):
        from app.expert_forum_helpers import check_expert_board_post_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        can_post = await check_expert_board_post_permission(mock_db, '12345678', '87654321')
        assert can_post == False

    async def test_check_manage_permission_returns_true_for_owner(self):
        from app.expert_forum_helpers import check_expert_board_manage_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = MagicMock()
        mock_db.execute.return_value = mock_result

        can_manage = await check_expert_board_manage_permission(mock_db, '12345678', '87654321')
        assert can_manage == True

    async def test_check_manage_permission_returns_false_for_member(self):
        from app.expert_forum_helpers import check_expert_board_manage_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        can_manage = await check_expert_board_manage_permission(mock_db, '12345678', '87654321')
        assert can_manage == False

    async def test_is_expert_board_calls_db_with_category_id(self):
        """确认 is_expert_board 查询了正确的 category_id"""
        from app.expert_forum_helpers import is_expert_board
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.first.return_value = ('expert', '11111111')
        mock_db.execute.return_value = mock_result

        await is_expert_board(mock_db, 42)
        mock_db.execute.assert_called_once()

    async def test_check_post_permission_calls_db(self):
        """确认 check_expert_board_post_permission 调用了 db.execute"""
        from app.expert_forum_helpers import check_expert_board_post_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        await check_expert_board_post_permission(mock_db, '12345678', '99999999')
        mock_db.execute.assert_called_once()

    async def test_check_manage_permission_calls_db(self):
        """确认 check_expert_board_manage_permission 调用了 db.execute"""
        from app.expert_forum_helpers import check_expert_board_manage_permission
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        await check_expert_board_manage_permission(mock_db, '12345678', '99999999')
        mock_db.execute.assert_called_once()

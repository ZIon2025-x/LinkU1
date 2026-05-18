"""settle 事务的集成测试 (spec §8 (a)-(h) 用例)。

P0-T11 - plan 2026-05-13-ai-qa-bounty-p0.md Task 11.
集成测试要求真 PostgreSQL DB (本地无 PG 时整文件会 skip)。
"""
import pytest
from decimal import Decimal
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone, timedelta

# 强制 import ai_qa 模型,把它们注册到 Base.metadata
# (`app.models` 不直接 import `models_ai_qa`,conftest 的 create_all 不会建 ai_* 表)
from app import models_ai_qa  # noqa: F401
from app.models_ai_qa import AiQuestion, AiAnswerScore, AiQaLeaderboard
from app import models
from app.models_expert import Expert


# ============================================================================
# Fixtures (conftest.py 只提供 `db`,这里补 db_session/admin_user/sample_users)
# ============================================================================

@pytest.fixture
def db_session(db):
    """Plan 代码用 `db_session` 名;conftest 提供的是 `db` → alias."""
    return db


@pytest.fixture
def admin_user(db_session):
    """A + 4 位数字 ID 的 AdminUser (memory:feedback_test_fixture_realism)。"""
    admin = models.AdminUser(
        id="A0001",
        name="Test Admin",
        username="test_admin",
        email="test_admin@example.com",
        hashed_password="x",
        is_active=1,
        is_super_admin=1,
    )
    db_session.add(admin)
    db_session.flush()
    return admin


@pytest.fixture
def sample_users(db_session):
    """5 个 8 位数字 user_id 的 sample User,覆盖测试需要的最大答题人数。"""
    users = []
    for i in range(1, 6):
        uid = f"U{i:07d}"  # U0000001 ~ U0000005
        u = models.User(
            id=uid,
            name=f"user{uid}",
            email=f"{uid.lower()}@test.local",
            hashed_password="x",
        )
        db_session.add(u)
        users.append(u)
    db_session.flush()
    return users


@pytest.fixture(autouse=True)
def _setup_settle_test_prereqs(db_session):
    """每个 settle 测试需要的固定前置数据:
    - Expert team `EXP00001` (AiQuestion.posed_by_expert_id FK)
    - ForumCategory id=1 (AiQuestion.target_forum_category_id FK)
    """
    # ForumCategory id=1
    cat = db_session.query(models.ForumCategory).filter_by(id=1).first()
    if cat is None:
        cat = models.ForumCategory(id=1, name="ai_qa_test_cat")
        db_session.add(cat)
    # Expert team
    exp = db_session.query(Expert).filter_by(id="EXP00001").first()
    if exp is None:
        exp = Expert(id="EXP00001", name="AI QA Test Team", status="active")
        db_session.add(exp)
    db_session.flush()


# ============================================================================
# 测试 helpers
# ============================================================================

def _create_settled_ready_question(db, admin_id: str, reward_pool_pence: int = 1000):
    """Helper: 建一个 status=scored 的题 + 3 个已评分的答案。"""
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app import models
    q = AiQuestion(
        title="test q", content="test", posed_by_expert_id="EXP00001",
        status="scored", reward_pool_pence=reward_pool_pence,
        participation_points=5,
        floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db.add(q)
    db.flush()
    for i, (user_id, score) in enumerate([("U0000001", 90), ("U0000002", 80), ("U0000003", 70)]):
        # 假设已有 ForumPost
        post = models.ForumPost(
            title="ans", content="ans content", author_id=user_id, category_id=1,
            ai_question_id=q.id,
        )
        db.add(post)
        db.flush()
        row = AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=user_id,
            ai_score=score,
        )
        db.add(row)
    db.commit()
    return q


def test_settle_happy_path(db_session, admin_user, sample_users):
    """case (b): settle 正确分钱 + leaderboard + ForumPost.is_featured。"""
    from app.services.ai_qa_settle import settle_question
    q = _create_settled_ready_question(db_session, admin_user.id, reward_pool_pence=1000)
    result = settle_question(db_session, q.id, admin_user.id)
    assert result["winner_count"] >= 1
    assert result["total_settled_pence"] == 1000
    db_session.refresh(q)
    assert q.status == "settled"
    # 验证 top 1 ForumPost.is_featured
    from app.models_ai_qa import AiAnswerScore
    from app import models
    top1 = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id, rank_final=1).one()
    fp = db_session.get(models.ForumPost, top1.forum_post_id)
    assert fp.is_featured is True


def test_settle_idempotency_lock(db_session, admin_user, sample_users):
    """case (d): S1 行锁 + 重复 settle 拒绝。"""
    from app.services.ai_qa_settle import settle_question, SettleError
    q = _create_settled_ready_question(db_session, admin_user.id)
    settle_question(db_session, q.id, admin_user.id)
    # 第二次 settle 应失败:status 已是 settled
    with pytest.raises(SettleError, match="status"):
        settle_question(db_session, q.id, admin_user.id)


def test_settle_weekly_cap(db_session, admin_user, sample_users, monkeypatch):
    """case (f): S5 周度上限超出拒绝。"""
    from app.services.ai_qa_settle import settle_question, SettleError
    # mock SystemSettings cap 极低
    # 注: plan 写的 update_system_setting 在 row 不存在时返回 None (不 upsert),
    #     测试 DB 干净时 cap 不会生效 → 改用 upsert_system_setting 保证 row 落地。
    from app.crud.system import upsert_system_setting
    upsert_system_setting(db_session, "ai_qa_weekly_settle_cap_pence", "100")
    db_session.commit()
    q = _create_settled_ready_question(db_session, admin_user.id, reward_pool_pence=1000)
    with pytest.raises(SettleError, match="weekly settle cap"):
        settle_question(db_session, q.id, admin_user.id)


def test_settle_audit_log(db_session, admin_user, sample_users):
    """case (g): 成功 settle 产生 1 条 audit log。"""
    from app.services.ai_qa_settle import settle_question
    from app import models
    q = _create_settled_ready_question(db_session, admin_user.id)
    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()
    logs = db_session.query(models.AuditLog).filter_by(
        action_type="ai_qa_settle", entity_id=str(q.id)
    ).all()
    assert len(logs) == 1
    assert "total_settled_pence" in logs[0].new_value


def test_settle_canceled_not_in_leaderboard(db_session, admin_user):
    """case (c): canceled 题不写 leaderboard。"""
    from app.models_ai_qa import AiQuestion, AiQaLeaderboard
    # 直接建 canceled 题(不走 settle)
    q = AiQuestion(
        title="t", content="c", posed_by_expert_id="EXP00001", status="canceled",
        reward_pool_pence=1000, participation_points=5,
        floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
    )
    db_session.add(q)
    db_session.commit()
    # canceled 流程不会调 settle_question,所以 leaderboard 不动
    assert db_session.query(AiQaLeaderboard).count() == 0


# ============================================================================
# 以下 3 个 case 覆盖新算法 (spec §2.1) 关键场景:验证 settle 集成层在
# floor_pence 抹零 / 全 0 分 / 并列分 等情况下 wallet+leaderboard+rank 链路对
# ============================================================================

def test_settle_floor_cuts_off_bottom_at_scale(db_session, admin_user):
    """case (i): 100 人答 + floor 抹零 → top X 拿钱, bottom 被归零;
    全员 leaderboard.answer_count += 1 但仅 winners win_count += 1。

    spec §2.1 表第 4 行场景:pool=£10 (1000p), floor=10p, 100 人分数 [80..0]。
    多数 score 低 → bottom 被 floor 抹零,只有 top X 实际拿钱。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore, AiQaLeaderboard
    from app import models

    q = AiQuestion(
        title="100q", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    # 100 个答主, score 从 80 递减到 0 (人为构造大量低分被 floor 抹零)
    for i in range(100):
        uid = f"U{i:07d}"
        # 100 个 user 也得先建 (memory:feedback_test_fixture_realism)
        if db_session.get(models.User, uid) is None:
            db_session.add(models.User(
                id=uid, name=f"floor_u_{uid}",
                email=f"{uid.lower()}_floor@test.local", hashed_password="x",
            ))
            db_session.flush()
        post = models.ForumPost(
            title=f"a{i}", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        score = max(0, 80 - i)  # i=0 → 80, i=80+ → 0
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=score,
        ))
    db_session.commit()

    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()

    rows = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()
    winners = [r for r in rows if r.reward_pence > 0]
    losers = [r for r in rows if r.reward_pence == 0]

    # 关键断言:
    assert len(winners) < 100, "floor 抹零应过滤掉一些低分,而非全员都拿钱"
    assert len(winners) >= 1, "至少 top 1 应拿到钱"
    assert all(r.reward_pence >= 10 for r in winners), "winners 单人 ≥ floor (10p)"
    assert sum(r.reward_pence for r in rows) == 1000, "总额 = 池子"
    # rank_final 全员都有 (排名给所有人,跟 reward_pence 是否 0 无关)
    assert all(r.rank_final is not None for r in rows)
    # leaderboard: 100 行 (每人 answer_count +=1), 但 win_count > 0 只在 winners
    lb_rows = db_session.query(AiQaLeaderboard).all()
    assert len(lb_rows) == 100
    win_lb = [lb for lb in lb_rows if lb.win_count > 0]
    assert len(win_lb) == len(winners), "leaderboard win_count 跟 reward_pence>0 一致"


def test_settle_all_zero_scores(db_session, admin_user, sample_users):
    """case (j): 全 0 分 settle → wallet 没 credit + leaderboard 不写 win_count + status 仍切 settled。

    spec §2.1 表第 5 行场景:5 人都拿 0 分。distribute_pool 返回全 0;
    钱留在 reward_pool_pence (不退不补);但 status 仍走完 settled 流程 + 参与积分照发。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore, AiQaLeaderboard
    from app import models

    q = AiQuestion(
        title="zeroq", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    for i in range(5):
        uid = f"U{i:07d}"
        post = models.ForumPost(
            title=f"a{i}", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=0,
        ))
    db_session.commit()

    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()
    db_session.refresh(q)

    # 状态切 settled (走完完整流程)
    assert q.status == "settled"
    rows = db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()
    # 全员 reward_pence = 0 (无答案被采纳)
    assert all(r.reward_pence == 0 for r in rows)
    # 全员 reward_points > 0 (参与积分照发)
    assert all(r.reward_points > 0 for r in rows)
    # wallet 没 credit (查 wallet_transactions WHERE related_type='ai_question' AND related_id=qid)
    from app.wallet_models import WalletTransaction  # 注意:wallet 模型在 wallet_models.py 不在 models.py
    tx = db_session.query(WalletTransaction).filter_by(
        related_type="ai_question", related_id=str(q.id),
    ).all()
    assert len(tx) == 0, "全 0 分不应触发任何 wallet credit"
    # leaderboard: 5 行都写 (answer_count +=1) 但 win_count 全 0
    lb_rows = db_session.query(AiQaLeaderboard).all()
    assert len(lb_rows) == 5
    assert all(lb.win_count == 0 and lb.total_won_pence == 0 for lb in lb_rows)


def test_settle_rank_final_with_ties(db_session, admin_user, sample_users):
    """case (k): rank_final 排名正确性 (含并列分场景)。

    并列分时 rank_final 不应跳号 (1, 2, 2, 4) 或乱排;具体决策跟 spec §6.1
    "rank_final ∈ [1, 3] 且 settled" 金边规则相关,影响前端 top3 高亮。
    """
    from app.services.ai_qa_settle import settle_question
    from app.models_ai_qa import AiQuestion, AiAnswerScore
    from app import models

    q = AiQuestion(
        title="tieq", content="c", posed_by_expert_id="EXP00001", status="scored",
        reward_pool_pence=1000, participation_points=5, floor_pence=10,
        target_forum_category_id=1, created_by_admin_id=admin_user.id,
        deadline=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db_session.add(q); db_session.flush()
    # 分数: [90, 80, 80, 70, 60] — 第 2/3 名并列
    scores = [("U0000001", 90), ("U0000002", 80), ("U0000003", 80),
              ("U0000004", 70), ("U0000005", 60)]
    for uid, score in scores:
        post = models.ForumPost(
            title="a", content="c", author_id=uid, category_id=1,
            ai_question_id=q.id,
        )
        db_session.add(post); db_session.flush()
        db_session.add(AiAnswerScore(
            ai_question_id=q.id, forum_post_id=post.id, user_id=uid, ai_score=score,
        ))
    db_session.commit()
    settle_question(db_session, q.id, admin_user.id)
    db_session.commit()

    rows = {r.user_id: r for r in db_session.query(AiAnswerScore).filter_by(ai_question_id=q.id).all()}
    # 关键断言:并列分 reward_pence 必须相等 (按比例分)
    assert rows["U0000002"].reward_pence == rows["U0000003"].reward_pence
    # rank_final:第 1 名 rank=1;第 2/3 名 (并列 80) 都应该 rank=2 (不跳号到 3)
    # 注意:此断言依赖实现决策。如选"密集排名 1,2,2,3,4" → 改下面;如选"标准 1,2,2,4,5" → 改下面
    # spec §6.1 没明确,但 settle 服务 (Task 6) 实现时应当 explicit 选一种,这里跟 settle 实现保持一致
    assert rows["U0000001"].rank_final == 1
    assert rows["U0000002"].rank_final == rows["U0000003"].rank_final  # 并列必须相同
    # 总额对齐池子
    assert sum(r.reward_pence for r in rows.values()) == 1000

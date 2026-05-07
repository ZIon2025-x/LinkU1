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

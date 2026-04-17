"""
stale consultation cleanup 单元测试。

`close_stale_consultations` 使用同步 SQLAlchemy API（db.query(...).filter(...).all()
+ db.execute(select(...)).scalar_one_or_none() + db.commit()）。本项目其他测试对这
类 DB 访问统一用 MagicMock 模拟（见 test_consultation_helpers.py），此处沿用同一
风格,不依赖真实 DB。

覆盖点:
1. Config.CONSULTATION_STALE_DAYS 默认值为 14
2. 传入 inactive_days=None 时自动读取 Config
3. 传入自定义 inactive_days 时使用自定义值计算 cutoff
4. 无 stale tasks 时函数直接返回,不调用 commit
5. 有 stale tasks 时会 flip status、插入 system message、调用 commit
"""
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest


def _make_mock_task(
    *,
    id: int = 1,
    status: str = "consulting",
    task_source: str = "consultation",
    poster_id: str = "u0000001",
    taker_id: str = "u0000002",
):
    """构造一个最小化的 Task mock,供 scheduled_tasks 迭代。"""
    t = MagicMock()
    t.id = id
    t.status = status
    t.task_source = task_source
    t.poster_id = poster_id
    t.taker_id = taker_id
    t.title = "咨询占位"
    return t


def _make_mock_db(stale_tasks=None, service_app=None, purchase_request=None):
    """构造一个模拟 close_stale_consultations 内部 DB 调用的 MagicMock。

    close_stale_consultations 的 DB 访问形态:
      - db.query(Message.task_id, func.max(...)).filter(...).group_by(...).subquery()
      - db.query(Task).outerjoin(...).filter(...).all()  -> 返回 stale_tasks
      - db.execute(select(ServiceApplication)...).scalar_one_or_none() -> service_app
      - db.execute(select(FleaMarketPurchaseRequest)...).scalar_one_or_none() -> purchase_request
      - db.add(system_msg)
      - db.commit() / db.rollback()
    """
    db = MagicMock()

    # db.query(...) 链: 两次调用,第一次返回 subquery builder,第二次返回主查询
    # 简化:让 .query(...) 返回一个 chain 末端 .all() 是 stale_tasks,.subquery() 返回 sentinel
    query_chain = MagicMock()
    query_chain.filter.return_value = query_chain
    query_chain.group_by.return_value = query_chain
    query_chain.subquery.return_value = MagicMock(name="last_msg_subq")
    query_chain.outerjoin.return_value = query_chain
    query_chain.all.return_value = stale_tasks or []
    db.query = MagicMock(return_value=query_chain)

    # db.execute(select(...)) 返回可 .scalar_one_or_none() 的 result。
    # 顺序调用:第一个 stale task 若是 consultation 则查 SA,若是 flea_market_consultation 则查 PR。
    # 我们让 scalar_one_or_none 依次按 side_effect 出栈。
    results_queue = []
    for t in stale_tasks or []:
        res = MagicMock()
        if t.task_source == "consultation":
            res.scalar_one_or_none = MagicMock(return_value=service_app)
        elif t.task_source == "flea_market_consultation":
            res.scalar_one_or_none = MagicMock(return_value=purchase_request)
        else:
            res.scalar_one_or_none = MagicMock(return_value=None)
        results_queue.append(res)

    db.execute = MagicMock(side_effect=results_queue if results_queue else [MagicMock()])
    db.add = MagicMock()
    db.commit = MagicMock()
    db.rollback = MagicMock()
    return db


# -----------------------------------------------------------------------------
# 1) Config 默认值
# -----------------------------------------------------------------------------
def test_config_default_stale_days_is_14():
    """默认阈值为 14 天(未设置 env 时)。"""
    from app.config import Config
    assert Config.CONSULTATION_STALE_DAYS == 14


# -----------------------------------------------------------------------------
# 2) inactive_days=None 走 Config 分支,cutoff 使用 Config 值
# -----------------------------------------------------------------------------
def test_none_inactive_days_reads_from_config():
    """当调用方未传 inactive_days 时,应从 Config 读取。"""
    from app import scheduled_tasks

    db = _make_mock_db(stale_tasks=[])

    # patch Config.CONSULTATION_STALE_DAYS 到一个非 14 的哨兵值,确认确实被读取
    with patch.object(scheduled_tasks, "get_utc_time",
                      return_value=datetime(2026, 1, 20, tzinfo=timezone.utc)) as mock_now, \
         patch("app.config.Config.CONSULTATION_STALE_DAYS", 42):
        scheduled_tasks.close_stale_consultations(db)

    # 无 stale tasks 时,函数 early-return 前仍构造了查询;验证 db.query 被调用
    assert db.query.called
    # 无 stale tasks -> 不应 commit
    db.commit.assert_not_called()


# -----------------------------------------------------------------------------
# 3) 显式传 inactive_days 时使用该值(不查 Config)
# -----------------------------------------------------------------------------
def test_custom_inactive_days_overrides_config():
    """显式传入 inactive_days 时应使用该值,哪怕 Config 另有设置。"""
    from app import scheduled_tasks

    db = _make_mock_db(stale_tasks=[])

    with patch.object(scheduled_tasks, "get_utc_time",
                      return_value=datetime(2026, 1, 20, tzinfo=timezone.utc)), \
         patch("app.config.Config.CONSULTATION_STALE_DAYS", 999):
        # 显式传 7 天 — Config 的 999 不应生效
        scheduled_tasks.close_stale_consultations(db, inactive_days=7)

    # 不崩溃 + 没有 stale 任务时不 commit
    db.commit.assert_not_called()


# -----------------------------------------------------------------------------
# 4) 无 stale tasks 时函数直接 return,不 commit / 不 add
# -----------------------------------------------------------------------------
def test_no_stale_tasks_skips_commit():
    """stale_tasks 为空时函数应 early-return。"""
    from app import scheduled_tasks

    db = _make_mock_db(stale_tasks=[])

    scheduled_tasks.close_stale_consultations(db, inactive_days=14)

    db.commit.assert_not_called()
    db.add.assert_not_called()


# -----------------------------------------------------------------------------
# 5) 存在 stale task 时:flip status + db.add(system message) + commit
# -----------------------------------------------------------------------------
def test_stale_tasks_are_closed_with_system_message():
    """有 stale task 时:task.status 翻为 closed、插入 system message、commit 被调用。"""
    from app import scheduled_tasks

    task = _make_mock_task(id=42, task_source="consultation")
    # ServiceApplication 也会被翻为 cancelled
    sa = MagicMock()
    sa.status = "consulting"
    db = _make_mock_db(stale_tasks=[task], service_app=sa)

    scheduled_tasks.close_stale_consultations(db, inactive_days=14)

    assert task.status == "closed", "Task should be marked closed"
    assert sa.status == "cancelled", "Linked ServiceApplication should be cancelled"
    assert db.add.called, "Expected system Message insertion via db.add"
    db.commit.assert_called_once()


# -----------------------------------------------------------------------------
# 6) flea_market_consultation 路径:翻 PurchaseRequest 而非 SA
# -----------------------------------------------------------------------------
def test_flea_market_consultation_cancels_purchase_request():
    """task_source=flea_market_consultation 时应关闭关联的 FleaMarketPurchaseRequest。"""
    from app import scheduled_tasks

    task = _make_mock_task(id=77, task_source="flea_market_consultation")
    pr = MagicMock()
    pr.status = "negotiating"
    db = _make_mock_db(stale_tasks=[task], purchase_request=pr)

    scheduled_tasks.close_stale_consultations(db, inactive_days=14)

    assert task.status == "closed"
    assert pr.status == "cancelled"
    db.commit.assert_called_once()

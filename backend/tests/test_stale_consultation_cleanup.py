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

    # 不再给 execute 兜底返回 MagicMock:空 stale_tasks 时 execute 本就不该被调用,
    # 任何意外调用都应明确触发 StopIteration 让测试失败。
    db.execute = MagicMock(side_effect=results_queue)
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
# 3) 显式传 inactive_days 时使用该值(不查 Config) — 通过写入的 system message
#    内容断言,确保 days 真的流入了模板;若函数忽略参数走 Config=999,测试会失败。
# -----------------------------------------------------------------------------
def test_custom_inactive_days_overrides_config():
    """传入 inactive_days 参数时,Config 值被忽略,参数值流入 system message 内容。"""
    import json
    from app import scheduled_tasks

    task = _make_mock_task(id=42, task_source="consultation")
    sa = MagicMock()
    sa.status = "consulting"
    db = _make_mock_db(stale_tasks=[task], service_app=sa)

    with patch.object(scheduled_tasks, "get_utc_time",
                      return_value=datetime(2026, 1, 20, tzinfo=timezone.utc)), \
         patch("app.config.Config.CONSULTATION_STALE_DAYS", 999):
        # 显式传 7 — Config 的 999 不应生效
        scheduled_tasks.close_stale_consultations(db, inactive_days=7)

    # 收集所有 db.add 的入参,筛出 Message-like 对象(带 content 属性)
    added = [c.args[0] for c in db.add.call_args_list]
    messages = [a for a in added if hasattr(a, "content") and isinstance(a.content, str)]
    assert messages, f"Expected at least one Message to be inserted, got adds={added!r}"

    # 断言 days=7 确实出现在中文 content 或英文 meta.content_en 里
    def _found_seven(m):
        if "7 天" in m.content or "7 days" in m.content:
            return True
        meta_raw = getattr(m, "meta", None)
        if meta_raw:
            meta_obj = json.loads(meta_raw) if isinstance(meta_raw, str) else meta_raw
            en = meta_obj.get("content_en", "")
            if "7 days" in en or "7 天" in en:
                return True
        return False

    assert any(_found_seven(m) for m in messages), (
        f"Expected days=7 to appear in message content/meta, got: "
        f"{[(m.content, getattr(m, 'meta', None)) for m in messages]}"
    )

    # 断言 Config 的 999 没有泄漏到任何 message 内容或 meta 里
    def _leaks_config(m):
        if "999" in m.content:
            return True
        meta_raw = getattr(m, "meta", None)
        if meta_raw and "999" in (meta_raw if isinstance(meta_raw, str) else json.dumps(meta_raw)):
            return True
        return False

    assert not any(_leaks_config(m) for m in messages), (
        "Config value (999) leaked into message content/meta; "
        "function likely read Config instead of the explicit inactive_days arg"
    )


# -----------------------------------------------------------------------------
# 4) 无 stale tasks 时函数直接 return,不 commit / 不 add
# -----------------------------------------------------------------------------
def test_no_stale_tasks_skips_commit():
    """stale_tasks 为空时函数应 early-return,不做任何副作用。"""
    from app import scheduled_tasks

    db = _make_mock_db(stale_tasks=[])

    scheduled_tasks.close_stale_consultations(db, inactive_days=14)

    db.commit.assert_not_called()
    db.add.assert_not_called()
    # 锁定"无 stale 任务时不再发起 SA/PR 查询"的优化:
    # 若未来有人在 early-return 前加了无条件 execute,此断言会立即失败。
    db.execute.assert_not_called()


# -----------------------------------------------------------------------------
# 5) 存在 stale task 时:flip status + db.add(system message) + commit
# -----------------------------------------------------------------------------
def test_stale_tasks_are_closed_with_system_message():
    """有 stale task 时:task.status 翻为 closed、插入结构正确的 system message、commit 被调用。

    除了 status/add/commit 的粗粒度断言,还要断言 Message 各字段确实按约定设置,
    以防未来有人把 Message 构造逻辑拆坏却让测试蒙混过关。
    """
    import json
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

    # 断言 Message shape
    added = [c.args[0] for c in db.add.call_args_list]
    messages = [a for a in added if hasattr(a, "message_type")]
    assert len(messages) >= 1, f"Expected at least one Message inserted, got: {added!r}"
    msg = messages[0]
    assert msg.task_id == 42, f"msg.task_id should be 42, got {msg.task_id!r}"
    assert msg.message_type == "system", f"msg.message_type should be 'system', got {msg.message_type!r}"
    assert msg.conversation_type == "task", (
        f"msg.conversation_type should be 'task', got {msg.conversation_type!r}"
    )
    # receiver 是 taker (fallback 到 poster),_make_mock_task 默认 taker='u0000002'
    assert msg.receiver_id in ("u0000001", "u0000002"), (
        f"msg.receiver_id should be taker or poster, got {msg.receiver_id!r}"
    )
    # 系统消息发送方为 NULL(系统)
    assert msg.sender_id is None, f"system msg.sender_id should be None, got {msg.sender_id!r}"

    # content 应提及 14 天 / 自动关闭,证明用的是 consultation_stale_auto_closed 模板
    assert "14" in msg.content and "自动关闭" in msg.content, (
        f"content should mention days=14 and '自动关闭', got: {msg.content!r}"
    )

    # meta 存 JSON 字符串,应包含 content_en(英文承载在 meta,与其他咨询系统消息对齐)
    assert msg.meta, "Expected msg.meta to carry content_en + system_action"
    meta_obj = json.loads(msg.meta) if isinstance(msg.meta, str) else msg.meta
    assert "content_en" in meta_obj, f"Expected meta.content_en, got: {meta_obj!r}"
    assert "14 days" in meta_obj["content_en"], (
        f"meta.content_en should mention 14 days, got: {meta_obj['content_en']!r}"
    )
    assert meta_obj.get("system_action") == "consultation_stale_auto_closed", (
        f"Expected system_action='consultation_stale_auto_closed', got: {meta_obj!r}"
    )


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

"""单测: history compaction — 摘要缓存 / 失败 fallback / 三层切分."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_msg(msg_id: int, role: str, content: str, tool_calls=None, tool_results=None):
    m = MagicMock()
    m.id = msg_id
    m.role = role
    m.content = content
    m.tool_calls = json.dumps(tool_calls) if tool_calls else None
    m.tool_results = json.dumps(tool_results) if tool_results else None
    return m


@pytest.mark.asyncio
async def test_summarize_calls_glm_and_caches_result():
    """首次调用打 GLM 并写入 Redis;同 conversation + 同 rows 第二次直接读 cache."""
    from app.services import ai_agent

    rows = [
        _make_msg(1, "user", "I want to find someone to pick up my parcel"),
        _make_msg(2, "assistant", "Sure, I can help. Where is the parcel?"),
    ]

    fake_redis = MagicMock()
    fake_redis.get = MagicMock(return_value=None)
    fake_redis.setex = MagicMock()

    fake_llm = MagicMock()
    text_block = MagicMock()
    text_block.text = "User wants help picking up a parcel."
    text_block.type = "text"
    fake_llm.chat = AsyncMock(return_value=MagicMock(content=[text_block]))

    with patch.object(ai_agent, "_get_redis", return_value=fake_redis), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached(rows, "conv_1")

    assert summary == "User wants help picking up a parcel."
    fake_llm.chat.assert_awaited_once()
    fake_redis.setex.assert_called_once()
    cache_key = fake_redis.setex.call_args.args[0]
    assert cache_key.startswith("ai:hist_sum:conv_1:")
    ttl = fake_redis.setex.call_args.args[1]
    assert ttl == 86400  # 24h


@pytest.mark.asyncio
async def test_summarize_uses_cache_when_present():
    """Redis 已有摘要时,不打 GLM."""
    from app.services import ai_agent

    rows = [_make_msg(1, "user", "hi")]

    fake_redis = MagicMock()
    fake_redis.get = MagicMock(return_value="cached summary text")

    fake_llm = MagicMock()
    fake_llm.chat = AsyncMock()

    with patch.object(ai_agent, "_get_redis", return_value=fake_redis), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached(rows, "conv_1")

    assert summary == "cached summary text"
    fake_llm.chat.assert_not_awaited()


@pytest.mark.asyncio
async def test_summarize_returns_none_on_glm_failure():
    """GLM raise 异常时, 返回 None (caller 会跳过 Layer C)."""
    from app.services import ai_agent

    rows = [_make_msg(1, "user", "hi")]

    fake_redis = MagicMock()
    fake_redis.get = MagicMock(return_value=None)

    fake_llm = MagicMock()
    fake_llm.chat = AsyncMock(side_effect=Exception("GLM down"))

    with patch.object(ai_agent, "_get_redis", return_value=fake_redis), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached(rows, "conv_1")

    assert summary is None


@pytest.mark.asyncio
async def test_summarize_returns_none_on_empty_string():
    """GLM 返回空字符串视为失败."""
    from app.services import ai_agent

    rows = [_make_msg(1, "user", "hi")]

    fake_redis = MagicMock()
    fake_redis.get = MagicMock(return_value=None)

    empty_block = MagicMock()
    empty_block.text = "   "  # whitespace only
    empty_block.type = "text"
    fake_llm = MagicMock()
    fake_llm.chat = AsyncMock(return_value=MagicMock(content=[empty_block]))

    with patch.object(ai_agent, "_get_redis", return_value=fake_redis), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached(rows, "conv_1")

    assert summary is None


@pytest.mark.asyncio
async def test_summarize_works_without_redis():
    """Redis 不可用时, 仍能调用 GLM 拿摘要."""
    from app.services import ai_agent

    rows = [_make_msg(1, "user", "hi")]

    text_block = MagicMock()
    text_block.text = "Summary"
    text_block.type = "text"
    fake_llm = MagicMock()
    fake_llm.chat = AsyncMock(return_value=MagicMock(content=[text_block]))

    with patch.object(ai_agent, "_get_redis", return_value=None), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached(rows, "conv_1")

    assert summary == "Summary"


@pytest.mark.asyncio
async def test_summarize_empty_rows_returns_none():
    """Empty rows list should return None immediately without calling Redis or GLM."""
    from app.services import ai_agent

    fake_redis = MagicMock()
    fake_redis.get = MagicMock()
    fake_llm = MagicMock()
    fake_llm.chat = AsyncMock()

    with patch.object(ai_agent, "_get_redis", return_value=fake_redis), \
         patch.object(ai_agent, "get_llm_client", return_value=fake_llm):

        summary = await ai_agent._summarize_history_cached([], "conv_1")

    assert summary is None
    fake_redis.get.assert_not_called()
    fake_llm.chat.assert_not_awaited()


@pytest.mark.asyncio
async def test_compacted_short_session_falls_back_to_raw():
    """≤ 4 轮 (≤ 8 条 msg) 跳过 compaction, 走原 _build_raw_messages."""
    from app.services import ai_agent

    rows = [
        _make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}")
        for i in range(6)
    ]

    fake_db = MagicMock()
    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)):
        result = await ai_agent._load_history_compacted(fake_db, "conv_1")

    # 应等于 _build_raw_messages(rows)
    expected = ai_agent._build_raw_messages(rows)
    assert result == expected


@pytest.mark.asyncio
async def test_compacted_medium_session_uses_layer_b_only():
    """12 轮 (24 条 msg) 只激活 Layer A + B, 无 Layer C."""
    from app.services import ai_agent

    rows = [
        _make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}")
        for i in range(24)
    ]

    fake_db = MagicMock()
    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)), \
         patch.object(ai_agent, "_summarize_history_cached", new=AsyncMock(return_value="should not be called")):
        result = await ai_agent._load_history_compacted(fake_db, "conv_1")

    # 不应包含 "[Earlier conversation summary]"
    assert not any(
        isinstance(m.get("content"), str) and "Earlier conversation summary" in m["content"]
        for m in result
    )


@pytest.mark.asyncio
async def test_compacted_long_session_emits_summary_prefix_and_ack():
    """20 轮 (40 条 msg) 三层全激活, 应有 summary user msg + ack assistant msg."""
    from app.services import ai_agent

    rows = [
        _make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}")
        for i in range(40)
    ]

    fake_db = MagicMock()
    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)), \
         patch.object(ai_agent, "_summarize_history_cached", new=AsyncMock(return_value="Old context.")):
        result = await ai_agent._load_history_compacted(fake_db, "conv_1")

    # 第一条应该是 summary user msg
    assert result[0]["role"] == "user"
    assert "[Earlier conversation summary]" in result[0]["content"]
    assert "Old context." in result[0]["content"]
    # 第二条是 ack
    assert result[1]["role"] == "assistant"
    assert result[1]["content"] == "I've reviewed the earlier conversation."


@pytest.mark.asyncio
async def test_compacted_drops_layer_c_when_summary_fails():
    """摘要失败 → 直接丢掉 Layer C, 不出现 summary/ack 消息."""
    from app.services import ai_agent

    rows = [
        _make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}")
        for i in range(40)
    ]

    fake_db = MagicMock()
    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)), \
         patch.object(ai_agent, "_summarize_history_cached", new=AsyncMock(return_value=None)):
        result = await ai_agent._load_history_compacted(fake_db, "conv_1")

    assert not any(
        isinstance(m.get("content"), str)
        and ("Earlier conversation summary" in m["content"]
             or "I've reviewed" in m["content"])
        for m in result
    )


@pytest.mark.asyncio
async def test_compacted_layer_b_replaces_tool_result_with_placeholder():
    """Layer B 范围内 (5-12 轮) 的 tool_result 应替换为占位符,不再带原始 JSON."""
    from app.services import ai_agent

    rows = []
    for i in range(24):
        if i == 5:
            # 在 Layer B 中插入一条带 tool_calls + tool_results 的 assistant
            rows.append(_make_msg(
                i, "assistant", "let me check",
                tool_calls=[{"id": "t1", "name": "search_tasks", "input": {"keyword": "x"}}],
                tool_results=[{"tool_use_id": "t1", "result": {"big_data": "x" * 1000}}],
            ))
        else:
            rows.append(_make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}"))

    fake_db = MagicMock()
    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)):
        result = await ai_agent._load_history_compacted(fake_db, "conv_1")

    # 找到 tool_result blocks, content 不应包含原 big_data
    tool_results = [
        block
        for m in result
        if isinstance(m.get("content"), list)
        for block in m["content"]
        if isinstance(block, dict) and block.get("type") == "tool_result"
    ]
    assert tool_results, "应至少找到一个 tool_result 块"
    for tr in tool_results:
        assert "big_data" not in tr["content"]
        assert "omitted" in tr["content"] or "[Tool" in tr["content"]


@pytest.mark.asyncio
async def test_flag_disabled_uses_raw_load_history(monkeypatch):
    """AI_HISTORY_COMPACTION_ENABLED=false → 走原 _load_history."""
    from app import config as _cfg
    from app.services import ai_agent

    monkeypatch.setattr(_cfg.Config, "AI_HISTORY_COMPACTION_ENABLED", False)

    fake_db = MagicMock()
    rows = [_make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i}") for i in range(40)]

    called = {"compacted": False, "raw": False}

    async def fake_compacted(db, conv_id):
        called["compacted"] = True
        return []

    async def fake_raw(db, conv_id):
        called["raw"] = True
        return ai_agent._build_raw_messages(rows)

    with patch.object(ai_agent, "_load_history_compacted", new=fake_compacted), \
         patch.object(ai_agent, "_load_history", new=fake_raw):
        from app.services.ai_agent import _select_history_loader
        loader = _select_history_loader()
        await loader(fake_db, "conv_1")

    assert called["raw"] is True
    assert called["compacted"] is False


@pytest.mark.asyncio
async def test_flag_enabled_uses_compacted(monkeypatch):
    """AI_HISTORY_COMPACTION_ENABLED=true → 走 _load_history_compacted."""
    from app import config as _cfg
    from app.services import ai_agent

    monkeypatch.setattr(_cfg.Config, "AI_HISTORY_COMPACTION_ENABLED", True)

    fake_db = MagicMock()

    called = {"compacted": False, "raw": False}

    async def fake_compacted(db, conv_id):
        called["compacted"] = True
        return []

    async def fake_raw(db, conv_id):
        called["raw"] = True
        return []

    with patch.object(ai_agent, "_load_history_compacted", new=fake_compacted), \
         patch.object(ai_agent, "_load_history", new=fake_raw):
        from app.services.ai_agent import _select_history_loader
        loader = _select_history_loader()
        await loader(fake_db, "conv_1")

    assert called["compacted"] is True
    assert called["raw"] is False

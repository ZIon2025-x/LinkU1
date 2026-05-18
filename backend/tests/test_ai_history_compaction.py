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

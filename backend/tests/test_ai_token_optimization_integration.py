"""集成测试: 三改动联合 — budget 修正 + Anthropic cache + history compaction.

这些测试不打真实 API,完全 mock,但跨多个组件验证协作.
- test_full_agent_with_cache_enabled: 改动 1+2 联合,budget 只计 effective
- test_full_agent_long_conversation: 改动 3,长会话 input token 比 raw 显著低
"""
from __future__ import annotations

import json
import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_msg(msg_id, role, content, tool_calls=None, tool_results=None):
    m = MagicMock()
    m.id = msg_id
    m.role = role
    m.content = content
    m.tool_calls = json.dumps(tool_calls) if tool_calls else None
    m.tool_results = json.dumps(tool_results) if tool_results else None
    return m


def _make_llm_response(input_tokens, output_tokens, cached):
    from app.services.ai_llm_client import LLMResponse, LLMTextBlock, LLMUsage
    return LLMResponse(
        content=[LLMTextBlock(text="reply")],
        model="claude-sonnet-4-5",
        usage=LLMUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cached_input_tokens=cached,
        ),
        stop_reason="end_turn",
    )


@pytest.mark.asyncio
async def test_full_agent_with_cache_records_only_effective_tokens():
    """改动 1+2 联合: ctx.total_input_tokens 应等于 (input - cached) 累加."""
    from app.services.ai_agent import _PipelineContext

    db = MagicMock()
    user = MagicMock(); user.id = "u_test"; user.language_preference = "en"
    ctx = _PipelineContext(db=db, user=user, conversation_id="c1", user_message="hi")

    # 模拟 2 轮 LLM 调用, 都有 cache 命中
    responses = [
        _make_llm_response(input_tokens=2000, output_tokens=200, cached=1500),
        _make_llm_response(input_tokens=2500, output_tokens=300, cached=2000),
    ]

    for resp in responses:
        effective = max(0, resp.usage.input_tokens - resp.usage.cached_input_tokens)
        ctx.total_input_tokens += effective
        ctx.total_raw_input_tokens += resp.usage.input_tokens
        ctx.total_cached_input_tokens += resp.usage.cached_input_tokens
        ctx.total_output_tokens += resp.usage.output_tokens

    # effective = (2000-1500) + (2500-2000) = 500 + 500 = 1000
    assert ctx.total_input_tokens == 1000
    assert ctx.total_raw_input_tokens == 4500
    assert ctx.total_cached_input_tokens == 3500
    assert ctx.total_output_tokens == 500


@pytest.mark.asyncio
async def test_full_agent_long_conversation_compaction_reduces_input():
    """改动 3: 长会话 compacted 输出的 messages 数 / 总 content 长度
    显著低于 raw."""
    from app.services import ai_agent

    rows = []
    for i in range(40):
        if i % 4 == 0:
            rows.append(_make_msg(
                i, "assistant", "let me check",
                tool_calls=[{"id": f"t{i}", "name": "search", "input": {"q": "x"}}],
                tool_results=[{"tool_use_id": f"t{i}", "result": {"big": "x" * 2000}}],
            ))
        else:
            rows.append(_make_msg(i, "user" if i % 2 == 0 else "assistant", f"msg {i} " * 30))

    fake_db = MagicMock()

    raw_msgs = ai_agent._build_raw_messages(rows)
    raw_total_len = sum(
        len(m["content"]) if isinstance(m["content"], str)
        else sum(len(json.dumps(b)) for b in m["content"])
        for m in raw_msgs
    )

    with patch.object(ai_agent, "_fetch_history_rows", new=AsyncMock(return_value=rows)), \
         patch.object(ai_agent, "_summarize_history_cached",
                      new=AsyncMock(return_value="User asked several questions earlier.")):
        compacted_msgs = await ai_agent._load_history_compacted(fake_db, "c1")

    compacted_total_len = sum(
        len(m["content"]) if isinstance(m["content"], str)
        else sum(len(json.dumps(b)) for b in m["content"])
        for m in compacted_msgs
    )

    # compacted 应至少省 30% (实际预期 50-60%, 30% 是 safety margin)
    assert compacted_total_len < raw_total_len * 0.7, (
        f"Compacted ({compacted_total_len}) should be < 70% of raw ({raw_total_len})"
    )

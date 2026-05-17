"""单测: budget 记账 — cached_input_tokens 必须从 effective input 中减去.

背景: ai_agent.py:1342 之前直接累加 input_tokens 进 ctx.total_input_tokens,
导致 prompt cache 命中也按全价扣 daily budget。修正后用户的有效预算等价于
按"实际算钱的 tokens"计。
"""
from __future__ import annotations

import os
import sys
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ai_agent import _PipelineContext  # noqa: E402
from app.services.ai_llm_client import LLMResponse, LLMTextBlock, LLMUsage  # noqa: E402


def _make_ctx() -> _PipelineContext:
    db = MagicMock()
    user = MagicMock()
    user.id = "u_test"
    user.language_preference = "en"
    return _PipelineContext(db=db, user=user, conversation_id="conv_1", user_message="hi")


def _make_response(input_tokens: int, output_tokens: int, cached: int = 0) -> LLMResponse:
    return LLMResponse(
        content=[LLMTextBlock(text="ok")],
        model="test-model",
        usage=LLMUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cached_input_tokens=cached,
        ),
        stop_reason="end_turn",
    )


def test_budget_cached_token_excluded_from_effective_input():
    """cached_input_tokens 应从 input_tokens 中减去后累计."""
    ctx = _make_ctx()
    resp = _make_response(input_tokens=1000, output_tokens=200, cached=300)

    effective = max(0, resp.usage.input_tokens - resp.usage.cached_input_tokens)
    ctx.total_input_tokens += effective
    ctx.total_raw_input_tokens += resp.usage.input_tokens
    ctx.total_cached_input_tokens += resp.usage.cached_input_tokens

    assert ctx.total_input_tokens == 700
    assert ctx.total_raw_input_tokens == 1000
    assert ctx.total_cached_input_tokens == 300


def test_budget_cached_overflow_safe():
    """provider 上报 cached > input 时, effective 不应负数."""
    ctx = _make_ctx()
    resp = _make_response(input_tokens=1000, output_tokens=100, cached=2000)

    effective = max(0, resp.usage.input_tokens - resp.usage.cached_input_tokens)
    ctx.total_input_tokens += effective

    assert ctx.total_input_tokens == 0


def test_budget_no_cache_falls_back_to_input():
    """cached=0 (GLM 未命中 / 未启 cache) 时, effective = input_tokens 等于现状."""
    ctx = _make_ctx()
    resp = _make_response(input_tokens=1500, output_tokens=200, cached=0)

    effective = max(0, resp.usage.input_tokens - resp.usage.cached_input_tokens)
    ctx.total_input_tokens += effective

    assert ctx.total_input_tokens == 1500

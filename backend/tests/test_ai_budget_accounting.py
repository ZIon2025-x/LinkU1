"""单测: budget 记账 — cached_input_tokens 必须从 effective input 中减去.

背景: 之前直接累加 input_tokens 进 ctx.total_input_tokens,
导致 prompt cache 命中也按全价扣 daily budget。修正后用户的有效预算等价于
按"实际算钱的 tokens"计。

这些测试直接调用产线函数 _accumulate_response_tokens — 不是测试自己写的公式,
所以如果有人未来改坏产线累加逻辑(如改成 input - cached*0.5),测试会失败。
"""
from __future__ import annotations

import os
import sys
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ai_agent import _PipelineContext, _accumulate_response_tokens  # noqa: E402
from app.services.ai_llm_client import LLMUsage  # noqa: E402


def _make_ctx() -> _PipelineContext:
    db = MagicMock()
    user = MagicMock()
    user.id = "u_test"
    user.language_preference = "en"
    return _PipelineContext(db=db, user=user, conversation_id="conv_1", user_message="hi")


def test_budget_cached_token_excluded_from_effective_input():
    """cached_input_tokens 应从 input_tokens 中减去后累计."""
    ctx = _make_ctx()
    usage = LLMUsage(input_tokens=1000, output_tokens=200, cached_input_tokens=300)

    effective = _accumulate_response_tokens(ctx, usage)

    assert effective == 700
    assert ctx.total_input_tokens == 700
    assert ctx.total_raw_input_tokens == 1000
    assert ctx.total_cached_input_tokens == 300
    assert ctx.total_output_tokens == 200


def test_budget_cached_overflow_safe():
    """provider 上报 cached > input 时, effective 不应负数."""
    ctx = _make_ctx()
    usage = LLMUsage(input_tokens=1000, output_tokens=100, cached_input_tokens=2000)

    effective = _accumulate_response_tokens(ctx, usage)

    assert effective == 0
    assert ctx.total_input_tokens == 0


def test_budget_no_cache_falls_back_to_input():
    """cached=0 (GLM 未命中 / 未启 cache) 时, effective = input_tokens 等于现状."""
    ctx = _make_ctx()
    usage = LLMUsage(input_tokens=1500, output_tokens=200, cached_input_tokens=0)

    effective = _accumulate_response_tokens(ctx, usage)

    assert effective == 1500
    assert ctx.total_input_tokens == 1500


def test_budget_multiple_responses_accumulate():
    """连续多个 response 应正确累加到 ctx."""
    ctx = _make_ctx()

    _accumulate_response_tokens(ctx, LLMUsage(
        input_tokens=2000, output_tokens=200, cached_input_tokens=1500,
    ))
    _accumulate_response_tokens(ctx, LLMUsage(
        input_tokens=2500, output_tokens=300, cached_input_tokens=2000,
    ))

    # effective = (2000-1500) + (2500-2000) = 500 + 500 = 1000
    assert ctx.total_input_tokens == 1000
    assert ctx.total_raw_input_tokens == 4500
    assert ctx.total_cached_input_tokens == 3500
    assert ctx.total_output_tokens == 500

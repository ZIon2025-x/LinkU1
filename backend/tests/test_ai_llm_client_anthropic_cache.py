"""单测: AnthropicProvider 启用 prompt caching 后的 kwargs 形态 + 失败回退.

覆盖:
1. AI_ANTHROPIC_CACHE_ENABLED=true: system 是 list[{cache_control,...}], tools 最后一项含 cache_control
2. AI_ANTHROPIC_CACHE_ENABLED=false: system 是 raw str, tools 不动
3. SDK raise cache_control 相关 BadRequestError: 自动回退 raw str + 重试一次
4. SDK raise 其他错误: 不回退,异常透传
5. OpenAICompatibleProvider 不受影响
"""
from __future__ import annotations

import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ai_llm_client import AnthropicProvider, OpenAICompatibleProvider  # noqa: E402


def _make_anthropic_response(input_tokens=100, output_tokens=50, cached_read=0):
    """构造一个 mock 的 anthropic.Message 响应."""
    resp = MagicMock()
    text_block = MagicMock()
    text_block.type = "text"
    text_block.text = "Hello"
    resp.content = [text_block]
    resp.model = "claude-sonnet-4-5"
    resp.usage = MagicMock()
    resp.usage.input_tokens = input_tokens
    resp.usage.output_tokens = output_tokens
    resp.usage.cache_read_input_tokens = cached_read
    resp.stop_reason = "end_turn"
    return resp


@pytest.fixture
def mock_anthropic_sdk():
    """patch AsyncAnthropic 构造器,返回可控 mock client."""
    with patch("app.services.ai_llm_client.anthropic.AsyncAnthropic") as mock_cls:
        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(return_value=_make_anthropic_response())
        mock_cls.return_value = mock_client
        yield mock_client


@pytest.mark.asyncio
async def test_anthropic_chat_with_cache_enabled_system_is_list(mock_anthropic_sdk, monkeypatch):
    """AI_ANTHROPIC_CACHE_ENABLED=true 时, system 必须是 list[{cache_control}]."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    provider = AnthropicProvider(api_key="test-key")
    await provider.chat(
        model="claude-sonnet-4-5",
        messages=[{"role": "user", "content": "hi"}],
        system="You are helpful.",
        tools=None,
        max_tokens=100,
    )

    call_kwargs = mock_anthropic_sdk.messages.create.call_args.kwargs
    assert isinstance(call_kwargs["system"], list)
    assert call_kwargs["system"][0]["type"] == "text"
    assert call_kwargs["system"][0]["text"] == "You are helpful."
    assert call_kwargs["system"][0]["cache_control"] == {"type": "ephemeral"}


@pytest.mark.asyncio
async def test_anthropic_chat_with_cache_enabled_tools_marker(mock_anthropic_sdk, monkeypatch):
    """AI_ANTHROPIC_CACHE_ENABLED=true 时, tools 列表最后一项含 cache_control."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    provider = AnthropicProvider(api_key="test-key")
    tools = [
        {"name": "tool_a", "description": "A", "input_schema": {}},
        {"name": "tool_b", "description": "B", "input_schema": {}},
    ]
    await provider.chat(
        model="claude-sonnet-4-5",
        messages=[{"role": "user", "content": "hi"}],
        system="sys",
        tools=tools,
        max_tokens=100,
    )

    call_kwargs = mock_anthropic_sdk.messages.create.call_args.kwargs
    assert "cache_control" not in call_kwargs["tools"][0]
    assert call_kwargs["tools"][-1]["cache_control"] == {"type": "ephemeral"}


@pytest.mark.asyncio
async def test_anthropic_chat_cache_disabled_uses_raw_str(mock_anthropic_sdk, monkeypatch):
    """AI_ANTHROPIC_CACHE_ENABLED=false 时, system 是 raw str, tools 不动."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", False)

    provider = AnthropicProvider(api_key="test-key")
    tools = [{"name": "tool_a", "description": "A", "input_schema": {}}]
    await provider.chat(
        model="claude-sonnet-4-5",
        messages=[{"role": "user", "content": "hi"}],
        system="You are helpful.",
        tools=tools,
        max_tokens=100,
    )

    call_kwargs = mock_anthropic_sdk.messages.create.call_args.kwargs
    assert call_kwargs["system"] == "You are helpful."
    assert "cache_control" not in call_kwargs["tools"][0]


@pytest.mark.asyncio
async def test_anthropic_chat_fallback_on_cache_control_error(monkeypatch):
    """SDK raise cache_control 相关错误时, 应自动回退 raw 并重试成功."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    import anthropic
    err = anthropic.BadRequestError(
        message="Invalid 'cache_control' parameter",
        response=MagicMock(),
        body={"error": {"message": "cache_control not supported"}},
    )

    call_count = {"n": 0}
    async def fake_create(**kwargs):
        call_count["n"] += 1
        if call_count["n"] == 1:
            raise err
        return _make_anthropic_response()

    with patch("app.services.ai_llm_client.anthropic.AsyncAnthropic") as mock_cls:
        mock_client = MagicMock()
        mock_client.messages.create = fake_create
        mock_cls.return_value = mock_client

        provider = AnthropicProvider(api_key="test-key")
        resp = await provider.chat(
            model="claude-sonnet-4-5",
            messages=[{"role": "user", "content": "hi"}],
            system="sys",
            tools=None,
            max_tokens=100,
        )

    assert call_count["n"] == 2  # 重试发生
    assert resp.model == "claude-sonnet-4-5"


@pytest.mark.asyncio
async def test_anthropic_chat_other_errors_not_retried(monkeypatch):
    """SDK raise 非 cache 错误时, 不回退, 异常透传."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    import anthropic
    err = anthropic.BadRequestError(
        message="Some other error",
        response=MagicMock(),
        body={"error": {"message": "rate limit exceeded"}},
    )

    call_count = {"n": 0}
    async def fake_create(**kwargs):
        call_count["n"] += 1
        raise err

    with patch("app.services.ai_llm_client.anthropic.AsyncAnthropic") as mock_cls:
        mock_client = MagicMock()
        mock_client.messages.create = fake_create
        mock_cls.return_value = mock_client

        provider = AnthropicProvider(api_key="test-key")
        with pytest.raises(anthropic.BadRequestError):
            await provider.chat(
                model="claude-sonnet-4-5",
                messages=[{"role": "user", "content": "hi"}],
                system="sys",
                tools=None,
                max_tokens=100,
            )

    assert call_count["n"] == 1  # 没重试


@pytest.mark.asyncio
async def test_openai_compatible_provider_unchanged(monkeypatch):
    """OpenAICompatibleProvider 不受 cache 改动影响."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    fake_response_json = {
        "choices": [{
            "message": {"content": "hi", "role": "assistant"},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 50, "completion_tokens": 10},
        "model": "glm-4-flash",
    }

    with patch("httpx.AsyncClient") as mock_cls:
        mock_client = MagicMock()
        post_response = MagicMock()
        post_response.status_code = 200
        post_response.json = MagicMock(return_value=fake_response_json)
        post_response.raise_for_status = MagicMock()
        mock_client.post = AsyncMock(return_value=post_response)
        mock_cls.return_value = mock_client

        provider = OpenAICompatibleProvider(
            api_key="k", base_url="https://test.example/v4",
        )
        resp = await provider.chat(
            model="glm-4-flash",
            messages=[{"role": "user", "content": "hi"}],
            system="sys",
            tools=None,
            max_tokens=100,
        )

        # OpenAI body 里 system 是 messages[0],不应该有 cache_control 字段
        post_kwargs = mock_client.post.call_args.kwargs
        body = post_kwargs["json"]
        assert body["messages"][0]["role"] == "system"
        assert body["messages"][0]["content"] == "sys"
        assert "cache_control" not in body["messages"][0]
        assert resp.usage.input_tokens == 50


@pytest.mark.asyncio
async def test_anthropic_chat_stream_with_cache_enabled_system_is_list(monkeypatch):
    """chat_stream 也必须给 system 加 cache_control."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    captured_kwargs = {}

    class FakeStream:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *a):
            return False
        def __aiter__(self):
            async def gen():
                if False:
                    yield None
            return gen()
        async def get_final_message(self):
            return _make_anthropic_response()

    def fake_stream_factory(**kwargs):
        captured_kwargs.update(kwargs)
        return FakeStream()

    with patch("app.services.ai_llm_client.anthropic.AsyncAnthropic") as mock_cls:
        mock_client = MagicMock()
        mock_client.messages.stream = fake_stream_factory
        mock_cls.return_value = mock_client

        provider = AnthropicProvider(api_key="test-key")
        async for _ in provider.chat_stream(
            model="claude-sonnet-4-5",
            messages=[{"role": "user", "content": "hi"}],
            system="You are helpful.",
            tools=None,
            max_tokens=100,
        ):
            pass

    assert isinstance(captured_kwargs["system"], list)
    assert captured_kwargs["system"][0]["cache_control"] == {"type": "ephemeral"}


@pytest.mark.asyncio
async def test_anthropic_chat_stream_fallback_on_cache_control_error(monkeypatch):
    """chat_stream 遇 cache 相关错误也走 fallback."""
    from app import config as _cfg
    monkeypatch.setattr(_cfg.Config, "AI_ANTHROPIC_CACHE_ENABLED", True)

    import anthropic
    err = anthropic.BadRequestError(
        message="Invalid cache_control",
        response=MagicMock(),
        body={"error": {"message": "cache_control"}},
    )

    call_count = {"n": 0}

    class FakeStream:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *a):
            return False
        def __aiter__(self):
            async def gen():
                if False:
                    yield None
            return gen()
        async def get_final_message(self):
            return _make_anthropic_response()

    def fake_stream_factory(**kwargs):
        call_count["n"] += 1
        if call_count["n"] == 1:
            raise err
        return FakeStream()

    with patch("app.services.ai_llm_client.anthropic.AsyncAnthropic") as mock_cls:
        mock_client = MagicMock()
        mock_client.messages.stream = fake_stream_factory
        mock_cls.return_value = mock_client

        provider = AnthropicProvider(api_key="test-key")
        items = []
        async for item in provider.chat_stream(
            model="claude-sonnet-4-5",
            messages=[{"role": "user", "content": "hi"}],
            system="sys",
            tools=None,
            max_tokens=100,
        ):
            items.append(item)

    assert call_count["n"] == 2  # 重试发生
    assert items[-1][0] == "done"

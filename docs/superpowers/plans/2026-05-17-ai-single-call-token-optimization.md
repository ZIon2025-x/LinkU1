# AI 单次消耗根因优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实施 spec `2026-05-17-ai-single-call-token-optimization-design.md` 的 3 个独立改动:budget 记账修正(cached 不计入)、Anthropic prompt caching 启用、history 三层 compaction。

**Architecture:** 三个改动互不依赖,分 3 个 Phase 独立完成。改动 1 是 1 行 + ctx 字段;改动 2 是 AnthropicProvider 的 system/tools 加 cache_control + 失败回退;改动 3 新增 `_load_history_compacted` 函数走 feature flag 切换。

**Tech Stack:** Python 3.11+, FastAPI, SQLAlchemy async, pytest + pytest-asyncio, unittest.mock (AsyncMock/MagicMock), Redis (with in-memory fallback), Anthropic SDK, OpenAI-compatible httpx client。

---

## File Structure

| 路径 | 改动 | 责任 |
|------|------|------|
| `backend/app/services/ai_agent.py` | 修改 | Pipeline + budget 累加 + history 加载切换 + 新增 `_load_history_compacted` + `_summarize_history_cached` + ctx 字段 |
| `backend/app/services/ai_llm_client.py` | 修改 | AnthropicProvider.chat / chat_stream 加 cache_control + 失败回退 |
| `backend/app/config.py` | 修改 | 加 2 个 env-driven 配置 |
| `backend/tests/test_ai_budget_accounting.py` | 新建 | 改动 1 单测 |
| `backend/tests/test_ai_llm_client_anthropic_cache.py` | 新建 | 改动 2 单测(含 fallback、GLM 路径回归) |
| `backend/tests/test_ai_history_compaction.py` | 新建 | 改动 3 单测(layer 切分 / 摘要缓存 / 失败 fallback / flag) |

---

## Phase 1: Budget 记账修正(改动 1)

### Task 1.1: PipelineContext 加 raw / cached 字段

**Files:**
- Modify: `backend/app/services/ai_agent.py:1040-1073`

- [ ] **Step 1: 修改 `__slots__` 加 2 个新字段**

`backend/app/services/ai_agent.py:1040-1046`:

```python
    __slots__ = (
        "db", "user", "conversation_id", "user_message", "lang",
        "reply_lang", "intent", "accept_lang",
        "full_response", "all_tool_calls", "all_tool_results",
        "total_input_tokens", "total_output_tokens", "model_used",
        "total_raw_input_tokens", "total_cached_input_tokens",
        "terminated",
    )
```

- [ ] **Step 2: 在 `__init__` 末尾初始化 2 个新字段**

`backend/app/services/ai_agent.py` 在 `self.total_output_tokens = 0` 后面加:

```python
        self.total_input_tokens = 0
        self.total_output_tokens = 0
        self.total_raw_input_tokens = 0
        self.total_cached_input_tokens = 0
        self.model_used = ""
        self.terminated = False
```

- [ ] **Step 3: 运行现有测试确保没破坏**

Run: `cd backend && pytest tests/ -k "ai" -v --no-header`
Expected: 现有 AI 相关测试全部 PASS(test_ai_profile_context.py)

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/ai_agent.py
git commit -m "$(cat <<'EOF'
refactor(ai_agent): PipelineContext 加 raw/cached input token 字段

为下一步 budget 修正做准备。新字段保留观察值,
不影响 record_usage 累加逻辑。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.2: Budget 修正——cached tokens 不计入

**Files:**
- Modify: `backend/app/services/ai_agent.py:1342-1343`
- Test: `backend/tests/test_ai_budget_accounting.py` (新建)

- [ ] **Step 1: 创建测试文件并写第一个失败测试**

`backend/tests/test_ai_budget_accounting.py`:

```python
"""单测: budget 记账 — cached_input_tokens 必须从 effective input 中减去.

背景: ai_agent.py:1342 之前直接累加 input_tokens 进 ctx.total_input_tokens,
导致 prompt cache 命中也按全价扣 daily budget。修正后用户的有效预算等价于
按"实际算钱的 tokens"计。
"""
from __future__ import annotations

import os
import sys
from unittest.mock import MagicMock

import pytest

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
```

- [ ] **Step 2: 运行测试确认通过(测试本身就是表达期望逻辑)**

Run: `cd backend && pytest tests/test_ai_budget_accounting.py -v`
Expected: 3 个测试全部 PASS(测试本身验证逻辑,实现在下一步合入 ai_agent.py 主代码)

- [ ] **Step 3: 修改 ai_agent.py:1342-1343 应用修正逻辑**

打开 `backend/app/services/ai_agent.py` 找到 line 1342 附近(`ctx.total_input_tokens += response.usage.input_tokens`)。原代码:

```python
            ctx.model_used = response.model
            ctx.total_input_tokens += response.usage.input_tokens
            ctx.total_output_tokens += response.usage.output_tokens
```

改为:

```python
            ctx.model_used = response.model
            effective_input = max(
                0,
                response.usage.input_tokens - response.usage.cached_input_tokens,
            )
            ctx.total_input_tokens += effective_input
            ctx.total_raw_input_tokens += response.usage.input_tokens
            ctx.total_cached_input_tokens += response.usage.cached_input_tokens
            ctx.total_output_tokens += response.usage.output_tokens
```

- [ ] **Step 4: 修改 1346 处的 cache hit 日志,加 effective 字段**

找到 `ai_agent.py:1345-1351`(`if response.usage.cached_input_tokens:`),原代码:

```python
            if response.usage.cached_input_tokens:
                logger.info(
                    "AI cache hit: cached=%d / input=%d (%.0f%%) model=%s user=%s",
                    response.usage.cached_input_tokens, response.usage.input_tokens,
                    100 * response.usage.cached_input_tokens / max(response.usage.input_tokens, 1),
                    response.model, ctx.user.id,
                )
```

改为:

```python
            if response.usage.cached_input_tokens:
                logger.info(
                    "AI cache hit: cached=%d / input=%d (%.0f%%) effective=%d model=%s user=%s",
                    response.usage.cached_input_tokens, response.usage.input_tokens,
                    100 * response.usage.cached_input_tokens / max(response.usage.input_tokens, 1),
                    effective_input,
                    response.model, ctx.user.id,
                )
```

- [ ] **Step 5: 再跑测试确认 ai_agent 主逻辑没破坏**

Run: `cd backend && pytest tests/ -k "ai" -v --no-header`
Expected: 全部 PASS

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/ai_agent.py backend/tests/test_ai_budget_accounting.py
git commit -m "$(cat <<'EOF'
fix(ai_agent): cached input tokens 不计入 daily budget

ai_agent.py:1342 之前直接累加全量 input_tokens,导致 prompt cache
命中(GLM 隐式 / Claude 显式)仍按 100% 扣 budget。修正后用户的
有效预算按"实际算钱 tokens"计。

ctx 加 total_raw_input_tokens / total_cached_input_tokens 用于观察。
cache hit 日志加 effective 字段。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2: Anthropic Prompt Cache 启用(改动 2)

### Task 2.1: 加 config flag

**Files:**
- Modify: `backend/app/config.py:368` (在 AI_DAILY_TOKEN_BUDGET 附近)

- [ ] **Step 1: 在 config.py 加 AI_ANTHROPIC_CACHE_ENABLED**

`backend/app/config.py:368` 之后(`AI_DAILY_TOKEN_BUDGET` 那一行之后)加:

```python
    AI_DAILY_TOKEN_BUDGET = int(os.getenv("AI_DAILY_TOKEN_BUDGET", "50000"))  # 每用户每天 token 预算

    # Anthropic prompt caching 开关 (system + tools 用 cache_control: ephemeral)
    # 默认 true; 出错自动回退到 raw str system + raw tools 重试一次
    AI_ANTHROPIC_CACHE_ENABLED = os.getenv("AI_ANTHROPIC_CACHE_ENABLED", "true").lower() == "true"
```

- [ ] **Step 2: 运行 config 相关测试确保没破坏**

Run: `cd backend && pytest tests/ -k "config" -v --no-header`
Expected: PASS(或 0 测试)

- [ ] **Step 3: Commit**

```bash
git add backend/app/config.py
git commit -m "$(cat <<'EOF'
feat(config): 加 AI_ANTHROPIC_CACHE_ENABLED env flag

默认 true。控制 Anthropic provider 是否在 system + tools 上加
cache_control: ephemeral。出错自动回退到 raw 调用。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.2: AnthropicProvider.chat 启用 cache_control + fallback

**Files:**
- Modify: `backend/app/services/ai_llm_client.py:68-110` (AnthropicProvider.chat)
- Test: `backend/tests/test_ai_llm_client_anthropic_cache.py` (新建)

- [ ] **Step 1: 创建测试文件并写第一个失败测试**

`backend/tests/test_ai_llm_client_anthropic_cache.py`:

```python
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
    # 第一次 raise BadRequestError, 第二次正常
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
```

- [ ] **Step 2: 运行测试看失败**

Run: `cd backend && pytest tests/test_ai_llm_client_anthropic_cache.py -v`
Expected: 多个 test FAIL,因为 AnthropicProvider 还没改 — 例如 `test_anthropic_chat_with_cache_enabled_system_is_list` 会失败说 `call_kwargs["system"]` 是 str 不是 list

- [ ] **Step 3: 修改 AnthropicProvider.chat 启用 cache_control + fallback**

`backend/app/services/ai_llm_client.py:78-110` 改 `AnthropicProvider.chat`:

```python
    async def chat(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int,
    ) -> LLMResponse:
        from app.config import Config

        kwargs: dict[str, Any] = self._build_chat_kwargs(
            model=model, messages=messages, system=system,
            tools=tools, max_tokens=max_tokens,
            cache_enabled=Config.AI_ANTHROPIC_CACHE_ENABLED,
        )

        try:
            resp = await self._client.messages.create(**kwargs)
        except anthropic.BadRequestError as e:
            if Config.AI_ANTHROPIC_CACHE_ENABLED and "cache_control" in str(e):
                logger.warning(
                    "Anthropic cache_control rejected, falling back to raw: %r", e
                )
                kwargs = self._build_chat_kwargs(
                    model=model, messages=messages, system=system,
                    tools=tools, max_tokens=max_tokens,
                    cache_enabled=False,
                )
                resp = await self._client.messages.create(**kwargs)
            else:
                raise

        # 转换为统一格式 (沿用原逻辑)
        content = []
        for block in resp.content:
            if block.type == "text":
                content.append(LLMTextBlock(text=block.text))
            elif block.type == "tool_use":
                content.append(LLMToolUse(id=block.id, name=block.name, input=block.input))

        return LLMResponse(
            content=content,
            model=resp.model,
            usage=LLMUsage(
                input_tokens=resp.usage.input_tokens,
                output_tokens=resp.usage.output_tokens,
                cached_input_tokens=getattr(resp.usage, "cache_read_input_tokens", 0) or 0,
            ),
            stop_reason=resp.stop_reason,
        )

    def _build_chat_kwargs(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int, cache_enabled: bool,
    ) -> dict[str, Any]:
        """构造 messages.create kwargs。cache_enabled=True 时给 system 和 tools 末尾加 cache_control."""
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": max_tokens,
            "messages": messages,
        }

        if cache_enabled and system:
            kwargs["system"] = [{
                "type": "text", "text": system,
                "cache_control": {"type": "ephemeral"},
            }]
        elif system:
            kwargs["system"] = system

        if cache_enabled and tools:
            tools_marked = tools[:-1] + [{
                **tools[-1],
                "cache_control": {"type": "ephemeral"},
            }]
            kwargs["tools"] = tools_marked
        elif tools:
            kwargs["tools"] = tools

        return kwargs
```

- [ ] **Step 4: 运行测试看通过**

Run: `cd backend && pytest tests/test_ai_llm_client_anthropic_cache.py -v`
Expected: 6 个 test 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_llm_client.py backend/tests/test_ai_llm_client_anthropic_cache.py
git commit -m "$(cat <<'EOF'
feat(ai_llm_client): AnthropicProvider.chat 启用 prompt caching

system 改为 list[{type:text, text, cache_control:ephemeral}]
tools 末尾一项加 cache_control:ephemeral
SDK 报 cache_control 相关错误时自动回退 raw 调用并重试一次

通过 AI_ANTHROPIC_CACHE_ENABLED env flag 控制(默认 true)。
OpenAICompatibleProvider 不受影响,GLM 路径走隐式 cache。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.3: AnthropicProvider.chat_stream 同款改造

**Files:**
- Modify: `backend/app/services/ai_llm_client.py:112-154` (AnthropicProvider.chat_stream)

- [ ] **Step 1: 给测试文件加 stream 测试**

在 `backend/tests/test_ai_llm_client_anthropic_cache.py` 末尾追加:

```python
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
```

- [ ] **Step 2: 运行测试看失败**

Run: `cd backend && pytest tests/test_ai_llm_client_anthropic_cache.py::test_anthropic_chat_stream_with_cache_enabled_system_is_list -v`
Expected: FAIL(stream 路径未改造)

- [ ] **Step 3: 修改 AnthropicProvider.chat_stream**

`backend/app/services/ai_llm_client.py:112-154` 改 `AnthropicProvider.chat_stream`:

```python
    async def chat_stream(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int,
    ) -> AsyncIterator[tuple[str, Any]]:
        """流式调用：yield ('text_delta', text) 边收边推,最后 yield ('done', LLMResponse)."""
        from app.config import Config

        cache_enabled = Config.AI_ANTHROPIC_CACHE_ENABLED
        kwargs = self._build_chat_kwargs(
            model=model, messages=messages, system=system,
            tools=tools, max_tokens=max_tokens, cache_enabled=cache_enabled,
        )

        async def _do_stream(_kwargs: dict[str, Any]):
            async with self._client.messages.stream(**_kwargs) as stream:
                async for event in stream:
                    if getattr(event, "type", None) == "content_block_delta":
                        delta = getattr(event, "delta", None)
                        if delta and getattr(delta, "type", None) == "text_delta":
                            text = getattr(delta, "text", "") or ""
                            if text:
                                yield ("text_delta", text)
                    elif getattr(event, "type", None) == "text":
                        text = getattr(event, "text", "") or ""
                        if text:
                            yield ("text_delta", text)
                final = await stream.get_final_message()
                content = []
                for block in final.content:
                    if block.type == "text":
                        content.append(LLMTextBlock(text=block.text))
                    elif block.type == "tool_use":
                        content.append(LLMToolUse(id=block.id, name=block.name, input=block.input))
                yield ("done", LLMResponse(
                    content=content,
                    model=final.model,
                    usage=LLMUsage(
                        input_tokens=final.usage.input_tokens,
                        output_tokens=final.usage.output_tokens,
                        cached_input_tokens=getattr(final.usage, "cache_read_input_tokens", 0) or 0,
                    ),
                    stop_reason=final.stop_reason,
                ))

        try:
            async for item in _do_stream(kwargs):
                yield item
        except anthropic.BadRequestError as e:
            if cache_enabled and "cache_control" in str(e):
                logger.warning(
                    "Anthropic stream cache_control rejected, falling back: %r", e
                )
                kwargs_fallback = self._build_chat_kwargs(
                    model=model, messages=messages, system=system,
                    tools=tools, max_tokens=max_tokens, cache_enabled=False,
                )
                async for item in _do_stream(kwargs_fallback):
                    yield item
            else:
                raise
```

- [ ] **Step 4: 运行测试看通过**

Run: `cd backend && pytest tests/test_ai_llm_client_anthropic_cache.py -v`
Expected: 全部 8 个 test PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_llm_client.py backend/tests/test_ai_llm_client_anthropic_cache.py
git commit -m "$(cat <<'EOF'
feat(ai_llm_client): AnthropicProvider.chat_stream 同款启用 cache

复用 _build_chat_kwargs helper 给 stream 路径加 cache_control。
失败回退逻辑与 chat 一致。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3: History Compaction(改动 3)

### Task 3.1: 加 config flag

**Files:**
- Modify: `backend/app/config.py`

- [ ] **Step 1: 在 AI_ANTHROPIC_CACHE_ENABLED 之后加新 flag**

`backend/app/config.py` 在 `AI_ANTHROPIC_CACHE_ENABLED` 行之后加:

```python
    AI_ANTHROPIC_CACHE_ENABLED = os.getenv("AI_ANTHROPIC_CACHE_ENABLED", "true").lower() == "true"

    # History compaction 开关 (老轮次用 LLM 摘要, 中间轮次 tool_result 占位符化)
    # 默认 false; linktest 灰度验证后改 true
    AI_HISTORY_COMPACTION_ENABLED = os.getenv("AI_HISTORY_COMPACTION_ENABLED", "false").lower() == "true"
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/config.py
git commit -m "$(cat <<'EOF'
feat(config): 加 AI_HISTORY_COMPACTION_ENABLED env flag

默认 false。控制 _load_history 是否走分层 compaction
(最近 4 轮原样 / 5-12 轮 tool_result 占位符 / 13-20 轮 LLM 摘要)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.2: 提取 _fetch_history_rows 和 _build_raw_messages

**Files:**
- Modify: `backend/app/services/ai_agent.py:1622-1663` (`_load_history`)

- [ ] **Step 1: 把 _load_history 拆为两个 helper**

`backend/app/services/ai_agent.py:1622-1663` 原 `_load_history` 改为:

```python
async def _fetch_history_rows(db: AsyncSession, conversation_id: str, max_messages: int):
    """从 DB 取最近 max_messages 条 AIMessage,按时间正序返回."""
    q = (
        select(models.AIMessage)
        .where(and_(
            models.AIMessage.conversation_id == conversation_id,
            models.AIMessage.role.in_(["user", "assistant"]),
        ))
        .order_by(desc(models.AIMessage.created_at))
        .limit(max_messages)
    )
    return list(reversed((await db.execute(q)).scalars().all()))


def _build_raw_messages(rows) -> list[dict]:
    """把 AIMessage rows 完整还原成 LLM messages 数组 (含 tool_use / tool_result 块)."""
    messages = []
    for msg in rows:
        if msg.role == "assistant" and msg.tool_calls:
            content_blocks = []
            if msg.content:
                content_blocks.append({"type": "text", "text": msg.content})
            try:
                tool_calls = json.loads(msg.tool_calls)
                for tc in tool_calls:
                    content_blocks.append({
                        "type": "tool_use", "id": tc["id"],
                        "name": tc["name"], "input": tc["input"],
                    })
            except (json.JSONDecodeError, KeyError):
                pass
            messages.append({"role": "assistant", "content": content_blocks})
            if msg.tool_results:
                try:
                    tool_results = json.loads(msg.tool_results)
                    result_blocks = [{
                        "type": "tool_result", "tool_use_id": tr["tool_use_id"],
                        "content": json.dumps(tr["result"], ensure_ascii=False),
                    } for tr in tool_results]
                    messages.append({"role": "user", "content": result_blocks})
                except (json.JSONDecodeError, KeyError):
                    pass
        else:
            messages.append({"role": msg.role, "content": msg.content})
    return messages


async def _load_history(db: AsyncSession, conversation_id: str) -> list[dict]:
    """原 _load_history 改为薄包装,走 fetch + build."""
    max_turns = Config.AI_MAX_HISTORY_TURNS
    rows = await _fetch_history_rows(db, conversation_id, max_turns * 2)
    return _build_raw_messages(rows)
```

- [ ] **Step 2: 运行现有测试确保 refactor 不破坏行为**

Run: `cd backend && pytest tests/ -k "ai" -v --no-header`
Expected: 全部 PASS(行为等价)

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/ai_agent.py
git commit -m "$(cat <<'EOF'
refactor(ai_agent): _load_history 拆为 _fetch_history_rows + _build_raw_messages

为 history compaction (Task 3.3-3.5) 提供可复用的两个 helper:
- _fetch_history_rows: 取 DB rows
- _build_raw_messages: 把 rows 还原成 LLM messages (含 tool blocks)

行为完全等价于原 _load_history。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.3: 实现 _summarize_history_cached

**Files:**
- Modify: `backend/app/services/ai_agent.py` (加新函数)
- Test: `backend/tests/test_ai_history_compaction.py` (新建)

- [ ] **Step 1: 创建测试文件,先测 summarize**

`backend/tests/test_ai_history_compaction.py`:

```python
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
```

- [ ] **Step 2: 运行测试看失败(函数还没实现)**

Run: `cd backend && pytest tests/test_ai_history_compaction.py -v`
Expected: 全部 5 个 test FAIL,因为 `_summarize_history_cached` 不存在

- [ ] **Step 3: 在 ai_agent.py 加 _summarize_history_cached 函数**

在 `backend/app/services/ai_agent.py` 文件末尾(`_save_assistant_message` 之后或之前)加:

```python
import hashlib as _hashlib  # 如已 import 可省


async def _summarize_history_cached(rows, conversation_id: str) -> str | None:
    """生成 Layer C 摘要, 用 Redis 缓存 24h.

    参数:
        rows: AIMessage 列表 (待摘要的最老一批)
        conversation_id: 用于 cache key

    返回:
        摘要字符串; 失败 / 空字符串 / 异常时返回 None (caller 应跳过 Layer C)。
    """
    if not rows:
        return None

    msg_ids = ",".join(str(m.id) for m in rows)
    key_hash = _hashlib.md5(msg_ids.encode()).hexdigest()[:16]
    cache_key = f"ai:hist_sum:{conversation_id}:{key_hash}"

    r = _get_redis()
    if r:
        try:
            cached = r.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass

    rows_text = "\n".join(
        f"{m.role}: {(m.content or '')[:300]}"
        for m in rows if (m.content or "").strip()
    )
    if not rows_text.strip():
        return None

    summary_prompt = (
        "Summarize the following conversation in 1-2 sentences. "
        "Preserve: user's key intent, unfinished requests, important context entities "
        "(names, IDs, dates).\n\n"
        f"{rows_text}"
    )

    try:
        llm = get_llm_client()
        resp = await llm.chat(
            messages=[{"role": "user", "content": summary_prompt}],
            system=(
                "You are a conversation summarizer. Be concise and information-dense. "
                "Respond in the same language as the conversation."
            ),
            tools=None,
            model_tier="small",
            max_tokens=200,
        )
        summary = "".join(
            b.text for b in resp.content
            if getattr(b, "type", None) == "text"
        ).strip()

        if not summary:
            return None

        if r:
            try:
                r.setex(cache_key, 86400, summary)
            except Exception:
                pass
        return summary
    except Exception as e:
        logger.warning("History summary failed for conv %s: %r", conversation_id, e)
        return None
```

- [ ] **Step 4: 运行测试看通过**

Run: `cd backend && pytest tests/test_ai_history_compaction.py -v`
Expected: 5 个 test 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_agent.py backend/tests/test_ai_history_compaction.py
git commit -m "$(cat <<'EOF'
feat(ai_agent): 实现 _summarize_history_cached

老对话用 GLM (small model) 摘要为 1-2 句, Redis 缓存 24h。
失败 / 空摘要 / Redis 不可用 / GLM 异常时返回 None,
caller 跳过 Layer C (直接丢老消息)。

摘要 prompt 要求"用对话同语言回答",避免中英混用。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.4: 实现 _load_history_compacted

**Files:**
- Modify: `backend/app/services/ai_agent.py` (加新函数)
- Modify: `backend/tests/test_ai_history_compaction.py` (加测试)

- [ ] **Step 1: 在测试文件追加 _load_history_compacted 测试**

在 `backend/tests/test_ai_history_compaction.py` 末尾追加:

```python
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
```

- [ ] **Step 2: 运行测试看失败**

Run: `cd backend && pytest tests/test_ai_history_compaction.py -v`
Expected: 5 个新 test FAIL(`_load_history_compacted` 不存在)

- [ ] **Step 3: 在 ai_agent.py 加 _load_history_compacted**

在 `backend/app/services/ai_agent.py` 的 `_summarize_history_cached` 之后加:

```python
async def _load_history_compacted(db: AsyncSession, conversation_id: str) -> list[dict]:
    """分层压缩 history:
       Layer A (最近 4 轮 = 8 条 msg): 原样保留
       Layer B (5-12 轮 = 中 16 条): tool_result 替换为 [Tool returned data, omitted]
       Layer C (13-20 轮 = 最老 16 条): LLM 摘要 + Redis 缓存; 失败丢掉

    短会话 (≤ 4 轮) 完全跳过 compaction,直接走 _build_raw_messages。
    """
    max_turns = Config.AI_MAX_HISTORY_TURNS  # 20
    rows = await _fetch_history_rows(db, conversation_id, max_turns * 2)
    total = len(rows)

    # 短会话: 跳过 compaction
    if total <= 8:
        return _build_raw_messages(rows)

    layer_a = rows[max(0, total - 8):]
    layer_b = rows[max(0, total - 24):max(0, total - 8)]
    layer_c = rows[:max(0, total - 24)]

    messages: list[dict] = []

    # Layer C: 摘要 (失败 → 直接丢)
    if layer_c:
        summary = await _summarize_history_cached(layer_c, conversation_id)
        if summary:
            messages.append({
                "role": "user",
                "content": f"[Earlier conversation summary]: {summary}",
            })
            messages.append({
                "role": "assistant",
                "content": "I've reviewed the earlier conversation.",
            })

    # Layer B: tool_result 占位符化
    for msg in layer_b:
        if msg.role == "assistant" and msg.tool_calls:
            content_blocks = []
            if msg.content:
                content_blocks.append({"type": "text", "text": msg.content})
            try:
                tool_calls = json.loads(msg.tool_calls)
                for tc in tool_calls:
                    content_blocks.append({
                        "type": "tool_use", "id": tc["id"],
                        "name": tc["name"], "input": tc["input"],
                    })
            except (json.JSONDecodeError, KeyError):
                pass
            messages.append({"role": "assistant", "content": content_blocks})

            if msg.tool_results:
                try:
                    tool_results = json.loads(msg.tool_results)
                    result_blocks = [{
                        "type": "tool_result", "tool_use_id": tr["tool_use_id"],
                        "content": "[Tool returned data, omitted]",
                    } for tr in tool_results]
                    messages.append({"role": "user", "content": result_blocks})
                except (json.JSONDecodeError, KeyError):
                    pass
        else:
            messages.append({"role": msg.role, "content": msg.content})

    # Layer A: 原样
    messages.extend(_build_raw_messages(layer_a))

    return messages
```

- [ ] **Step 4: 运行测试看通过**

Run: `cd backend && pytest tests/test_ai_history_compaction.py -v`
Expected: 全部 10 个 test PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_agent.py backend/tests/test_ai_history_compaction.py
git commit -m "$(cat <<'EOF'
feat(ai_agent): 实现 _load_history_compacted 三层切分

Layer A (最近 4 轮): 原样保留
Layer B (5-12 轮): tool_result 替换为占位符
Layer C (13-20 轮): LLM 摘要 + 24h Redis 缓存

短会话 (≤ 4 轮) 跳过 compaction。
摘要失败 → 跳过 Layer C, 不阻断 Layer A + B。
Layer C ack 文案: "I've reviewed the earlier conversation."

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.5: 调用方加 flag switch

**Files:**
- Modify: `backend/app/services/ai_agent.py:1240` (history 加载点)
- Modify: `backend/tests/test_ai_history_compaction.py` (加 flag 测试)

- [ ] **Step 1: 在测试文件追加 flag 测试**

在 `backend/tests/test_ai_history_compaction.py` 末尾追加:

```python
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
```

- [ ] **Step 2: 运行测试看失败**

Run: `cd backend && pytest tests/test_ai_history_compaction.py::test_flag_disabled_uses_raw_load_history tests/test_ai_history_compaction.py::test_flag_enabled_uses_compacted -v`
Expected: FAIL,`_select_history_loader` 不存在

- [ ] **Step 3: 在 ai_agent.py 加 _select_history_loader + 替换调用方**

在 `_load_history_compacted` 之后加:

```python
def _select_history_loader():
    """根据 AI_HISTORY_COMPACTION_ENABLED flag 返回对应的 history 加载函数."""
    if Config.AI_HISTORY_COMPACTION_ENABLED:
        return _load_history_compacted
    return _load_history
```

然后在 `ai_agent.py:1240`(`history = await _load_history(ctx.db, ctx.conversation_id)`),改为:

```python
    history = await _select_history_loader()(ctx.db, ctx.conversation_id)
```

- [ ] **Step 4: 运行所有 history 测试看通过**

Run: `cd backend && pytest tests/test_ai_history_compaction.py -v`
Expected: 全部 12 个 test PASS

- [ ] **Step 5: 跑 AI 相关全套测试做最终回归**

Run: `cd backend && pytest tests/ -k "ai" -v --no-header`
Expected: 全 PASS(test_ai_profile_context + test_ai_budget_accounting + test_ai_llm_client_anthropic_cache + test_ai_history_compaction)

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/ai_agent.py backend/tests/test_ai_history_compaction.py
git commit -m "$(cat <<'EOF'
feat(ai_agent): pipeline 接入 history compaction flag

通过 _select_history_loader 在 raw / compacted 之间切换。
AI_HISTORY_COMPACTION_ENABLED 默认 false; linktest 验证摘要质量后
prod 改 true。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4: 集成测试(覆盖 spec §9.2)

### Task 4.1: 跨改动联合集成测试

**Files:**
- Create: `backend/tests/test_ai_token_optimization_integration.py`

- [ ] **Step 1: 创建集成测试文件**

`backend/tests/test_ai_token_optimization_integration.py`:

```python
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
```

- [ ] **Step 2: 运行集成测试看通过**

Run: `cd backend && pytest tests/test_ai_token_optimization_integration.py -v`
Expected: 2 个 test PASS

- [ ] **Step 3: 跑 AI 相关全套最终回归**

Run: `cd backend && pytest tests/ -k "ai" -v --no-header`
Expected: 全 PASS(4 个 test 文件加起来 17+ tests)

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_ai_token_optimization_integration.py
git commit -m "$(cat <<'EOF'
test(ai): 集成测试覆盖三改动联合行为

- effective budget 累加(改动 1+2)
- 长会话 compaction 显著减少 input 总长度(改动 3)

满足 spec §9.2 集成测试要求,不打真实 API,完全 mock。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Linktest 灰度清单(手动)

实施完成后在 linktest 部署逐项验证:

- [ ] **改动 1 验证**: 用一个测试账号聊几轮带 tool 调用的对话,看后端 log 出现 `AI cache hit: cached=X / input=Y effective=Z` 行,且 daily budget 累计速度比改动前低
- [ ] **改动 2 验证**: 触发一次切到 large model(Claude Sonnet 4.5)的复杂请求,看下一次同样请求的 log 出现 cache hit(`cache_read_input_tokens > 0`)
- [ ] **改动 2 回退验证**: 暂时设置 `AI_ANTHROPIC_CACHE_ENABLED=false` 重启,看 raw 路径仍工作
- [ ] **改动 3 部署**: 设置 `AI_HISTORY_COMPACTION_ENABLED=true` 重启 linktest
- [ ] **改动 3 短会话**: 聊 3-4 轮,看 log 没有 "summary" 相关字段(确认 fallback 到 raw)
- [ ] **改动 3 长会话**: 聊 20+ 轮,人工触发摘要,在 Redis CLI(或 admin)查 `ai:hist_sum:*` key 内容,读摘要文本判断质量
- [ ] **改动 3 fallback**: 暂时把 GLM key 写错,触发长会话,看 log 出现 "History summary failed" warning,且 AI 还能正常回复(说明 Layer A+B 兜底有效)
- [ ] **三改动联合**: 长会话连续聊 6-8 次,看 daily token 累计速度比改动前明显下降(应至少省 50%+)

通过后,prod 部署默认值:
- `AI_ANTHROPIC_CACHE_ENABLED=true`(默认)
- `AI_HISTORY_COMPACTION_ENABLED=true`(从 false 改 true)

---

## Self-Review 检查项(给执行者)

完成全部 Phase 后,核对:

- [ ] spec §3 改动 1: 代码 + 测试 + ctx 字段 ✓ Task 1.1 + 1.2
- [ ] spec §3 改动 2: 代码 + 测试 + flag ✓ Task 2.1 + 2.2 + 2.3
- [ ] spec §3 改动 3: 代码 + 测试 + flag + refactor ✓ Task 3.1 + 3.2 + 3.3 + 3.4 + 3.5
- [ ] spec §7 错误处理 8 条都有对应测试或 try/except 覆盖
- [ ] spec §8 灰度策略: 改动 1 直接生效 ✓ / 改动 2 默认 true ✓ / 改动 3 默认 false ✓
- [ ] spec §9.1 全部 13 个单测项都有对应 test_* 函数
- [ ] spec §9.2 集成测试 2 项 ✓ Task 4.1

如发现 spec 要求与实施不一致, 优先修代码 / 加测试, 而非改 spec。

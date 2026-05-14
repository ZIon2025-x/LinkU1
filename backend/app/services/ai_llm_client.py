"""
LLM 客户端封装 — 支持 Anthropic + OpenAI-Compatible (GLM/DeepSeek/Qwen/...) 多模型路由

配置示例：
  # 小模型用 GLM，大模型用 Claude Sonnet
  AI_MODEL_SMALL_PROVIDER=openai_compatible
  AI_MODEL_SMALL_API_KEY=xxx.yyy
  AI_MODEL_SMALL_BASE_URL=https://open.bigmodel.cn/api/paas/v4
  AI_MODEL_SMALL=glm-4-flash
  AI_MODEL_LARGE_PROVIDER=anthropic
  AI_MODEL_LARGE=claude-sonnet-4-5-20250929

  # 全部用 Anthropic（默认）
  ANTHROPIC_API_KEY=sk-ant-xxx
"""

import json
import logging
from dataclasses import dataclass
from typing import Any, AsyncIterator

import anthropic

from app.config import Config

logger = logging.getLogger(__name__)


# ==================== 统一响应格式 ====================

@dataclass
class LLMToolUse:
    """工具调用"""
    id: str
    name: str
    input: dict
    type: str = "tool_use"


@dataclass
class LLMTextBlock:
    """文本块"""
    text: str
    type: str = "text"


@dataclass
class LLMUsage:
    """Token 用量"""
    input_tokens: int
    output_tokens: int
    # 缓存命中的 input token (Anthropic 的 cache_read_input_tokens / OpenAI 兼容协议的 prompt_tokens_details.cached_tokens)
    # 未命中或 provider 不上报时为 0
    cached_input_tokens: int = 0


@dataclass
class LLMResponse:
    """统一 LLM 响应 — 抹平 Anthropic / OpenAI 差异"""
    content: list  # List[LLMTextBlock | LLMToolUse]
    model: str
    usage: LLMUsage
    stop_reason: str | None = None


# ==================== Provider 实现 ====================

class AnthropicProvider:
    """Anthropic Claude API"""

    def __init__(self, api_key: str, timeout: float = 30.0):
        self._client = anthropic.AsyncAnthropic(
            api_key=api_key,
            timeout=timeout,
            max_retries=2,
        )

    async def chat(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int,
    ) -> LLMResponse:
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }
        if tools:
            kwargs["tools"] = tools

        resp = await self._client.messages.create(**kwargs)

        # 转换为统一格式
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

    async def chat_stream(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int,
    ) -> AsyncIterator[tuple[str, Any]]:
        """流式调用：yield ('text_delta', text) 边收边推，最后 yield ('done', LLMResponse)。"""
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }
        if tools:
            kwargs["tools"] = tools

        async with self._client.messages.stream(**kwargs) as stream:
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


class OpenAICompatibleProvider:
    """OpenAI-Compatible API（GLM / DeepSeek / Qwen / Moonshot / ...）

    使用 httpx 直接调用，兼容所有 OpenAI 协议 API。
    """

    def __init__(
        self,
        api_key: str,
        base_url: str,
        timeout: float = 30.0,
        extra_body: dict | None = None,
    ):
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout
        # extra_body: 每次请求自动合并的固定字段(provider 私有参数,如 GLM 的
        # thinking 控制)。在 body 构造完成后 merge,以便上层若显式传入同名字段
        # 可覆盖。
        self._extra_body = extra_body or {}
        import httpx
        self._client = httpx.AsyncClient(
            timeout=timeout,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )

    async def close(self):
        await self._client.aclose()

    async def chat(
        self, model: str, messages: list[dict], system: str,
        tools: list[dict] | None, max_tokens: int,
    ) -> LLMResponse:
        # 构建 OpenAI 格式的 messages
        oai_messages: list[dict[str, Any]] = [{"role": "system", "content": system}]
        for msg in messages:
            if isinstance(msg.get("content"), str):
                oai_messages.append({"role": msg["role"], "content": msg["content"]})
            elif isinstance(msg.get("content"), list):
                # Anthropic 混合 content blocks → OpenAI 格式
                # 收集同一 assistant turn 的 text + tool_use，合并为一条消息
                text_parts = []
                tool_calls_list = []
                tool_results = []

                for block in msg["content"]:
                    if block.get("type") == "tool_result":
                        tool_results.append({
                            "role": "tool",
                            "tool_call_id": block["tool_use_id"],
                            "content": block.get("content", ""),
                        })
                    elif block.get("type") == "tool_use":
                        tool_calls_list.append({
                            "id": block["id"],
                            "type": "function",
                            "function": {
                                "name": block["name"],
                                "arguments": json.dumps(block["input"], ensure_ascii=False),
                            },
                        })
                    elif block.get("type") == "text":
                        text_parts.append(block["text"])

                # assistant 消息：text + tool_calls 合为一条
                if msg["role"] == "assistant" and (text_parts or tool_calls_list):
                    assistant_msg: dict[str, Any] = {"role": "assistant", "content": " ".join(text_parts) if text_parts else None}
                    if tool_calls_list:
                        assistant_msg["tool_calls"] = tool_calls_list
                    oai_messages.append(assistant_msg)
                elif text_parts:
                    oai_messages.append({"role": msg["role"], "content": " ".join(text_parts)})

                # tool_result 单独追加
                oai_messages.extend(tool_results)

        # 构建 OpenAI 格式的 tools
        oai_tools = None
        if tools:
            oai_tools = []
            for tool in tools:
                oai_tools.append({
                    "type": "function",
                    "function": {
                        "name": tool["name"],
                        "description": tool.get("description", ""),
                        "parameters": tool.get("input_schema", {}),
                    },
                })

        body: dict[str, Any] = {
            "model": model,
            "messages": oai_messages,
            "max_tokens": max_tokens,
        }
        if oai_tools:
            body["tools"] = oai_tools
        # provider 级默认参数(如 GLM thinking: disabled),不覆盖 body 已有 key
        for k, v in self._extra_body.items():
            body.setdefault(k, v)

        # 诊断 log:每次请求记录 url/model/耗时/异常类型。配合 ai_agent.py:1430
        # 的 repr(e) 才能区分 ReadTimeout/ConnectTimeout/HTTPStatusError 等。
        import time as _time
        url = f"{self._base_url}/chat/completions"
        t0 = _time.monotonic()
        try:
            resp = await self._client.post(url, json=body)
        except Exception as e:
            elapsed = _time.monotonic() - t0
            logger.error(
                "OpenAI-compatible request failed: model=%s url=%s elapsed=%.2fs err=%r",
                model, url, elapsed, e,
            )
            raise
        elapsed = _time.monotonic() - t0
        logger.info(
            "OpenAI-compatible request: model=%s url=%s status=%d elapsed=%.2fs",
            model, url, resp.status_code, elapsed,
        )
        resp.raise_for_status()
        data = resp.json()

        logger.debug(
            f"OpenAI-compatible raw response: model={model}, "
            f"choices_count={len(data.get('choices', []))}, "
            f"finish_reason={data.get('choices', [{}])[0].get('finish_reason')}, "
            f"content_preview={str(data.get('choices', [{}])[0].get('message', {}).get('content', ''))[:200]!r}"
        )

        # 解析 OpenAI 响应 → 统一格式
        choice = data["choices"][0]
        message = choice["message"]

        content: list[LLMTextBlock | LLMToolUse] = []
        msg_content = message.get("content")
        # 推理模型 (如 GLM-4.7-FlashX) 把思考过程放在 reasoning_content，实际回答放在 content
        # 当 finish_reason=length 时，推理 token 可能耗尽配额导致 content 为空
        # 此时尝试从 reasoning_content 中提取可用内容作为 fallback
        if not msg_content and message.get("reasoning_content"):
            reasoning = message["reasoning_content"]
            logger.info(
                f"OpenAI-compatible: content is empty but reasoning_content exists "
                f"({len(reasoning)} chars), model={model}, "
                f"finish_reason={choice.get('finish_reason')}"
            )
            if choice.get("finish_reason") == "length":
                # 推理 token 耗尽，尝试用 reasoning_content 作为 fallback
                msg_content = reasoning
                logger.info(
                    f"OpenAI-compatible: using reasoning_content as fallback "
                    f"(finish_reason=length), model={model}"
                )
        if msg_content is not None and msg_content != "":
            content.append(LLMTextBlock(text=msg_content))
        elif not message.get("tool_calls"):
            logger.warning(
                f"OpenAI-compatible API returned empty content: "
                f"model={model}, finish_reason={choice.get('finish_reason')}, "
                f"message_keys={list(message.keys())}"
            )

        if message.get("tool_calls"):
            for tc in message["tool_calls"]:
                func = tc["function"]
                try:
                    args = json.loads(func.get("arguments", "{}"))
                except json.JSONDecodeError:
                    args = {}
                content.append(LLMToolUse(
                    id=tc["id"],
                    name=func["name"],
                    input=args,
                ))

        usage_data = data.get("usage", {})
        # 智谱 GLM 等 OpenAI 兼容 provider 把缓存命中放在 prompt_tokens_details.cached_tokens (隐式自动缓存)
        prompt_details = usage_data.get("prompt_tokens_details") or {}
        return LLMResponse(
            content=content,
            model=data.get("model", model),
            usage=LLMUsage(
                input_tokens=usage_data.get("prompt_tokens", 0),
                output_tokens=usage_data.get("completion_tokens", 0),
                cached_input_tokens=prompt_details.get("cached_tokens", 0) or 0,
            ),
            stop_reason=choice.get("finish_reason"),
        )


# ==================== 统一客户端 ====================

def _build_provider_extra_body(provider_type: str, model: str) -> dict:
    """根据 provider + model 推断需要附加的固定请求字段。

    GLM-4.5+ 系列的 thinking 参数 **默认 enabled**(z.ai 官方文档明示),意味着
    每次调用都会先走深度思考再生成回答,简单消息("你好")也可能超过 60s timeout
    触发 ReadTimeout(httpx 的 ReadTimeout str()='',这正是日志里
    `LLM call error for user ...: ` 空尾巴的根因)。
    对 backend 小模型(intent 判定 + 简单对话),关闭 thinking 大幅降低延迟,
    复杂推理已由大模型(Claude)承担。
    """
    if provider_type != "openai_compatible":
        return {}
    model_lower = (model or "").lower()
    if "glm-4" in model_lower or "glm-5" in model_lower:
        return {"thinking": {"type": "disabled"}}
    return {}


def _create_provider(
    provider_type: str,
    api_key: str,
    base_url: str,
    timeout: float,
    model: str = "",
):
    """工厂方法 — 根据 provider 类型创建实例"""
    if provider_type == "anthropic":
        return AnthropicProvider(api_key=api_key, timeout=timeout)
    elif provider_type == "openai_compatible":
        if not base_url:
            raise ValueError(f"openai_compatible provider requires BASE_URL")
        extra_body = _build_provider_extra_body(provider_type, model)
        return OpenAICompatibleProvider(
            api_key=api_key, base_url=base_url, timeout=timeout, extra_body=extra_body,
        )
    else:
        raise ValueError(f"Unknown AI provider: {provider_type}")


class LLMClient:
    """统一 LLM 客户端 — 大小模型可用完全不同的 provider

    示例组合：
    - 小模型 GLM-4-Flash + 大模型 Claude Sonnet
    - 小模型 DeepSeek-Chat + 大模型 GPT-4o
    - 小模型 Haiku + 大模型 Sonnet（默认，全 Anthropic）
    """

    def __init__(self):
        default_key = Config.ANTHROPIC_API_KEY

        # 小模型
        small_key = Config.AI_MODEL_SMALL_API_KEY or default_key
        small_provider = Config.AI_MODEL_SMALL_PROVIDER
        small_base_url = Config.AI_MODEL_SMALL_BASE_URL
        if not small_key:
            logger.warning("No API key for small model — AI features disabled")
        small_timeout = Config.AI_LLM_SMALL_TIMEOUT
        self._small = _create_provider(
            small_provider, small_key, small_base_url,
            timeout=small_timeout, model=Config.AI_MODEL_SMALL,
        )
        small_extra = _build_provider_extra_body(small_provider, Config.AI_MODEL_SMALL)
        logger.info(
            f"AI small model: {Config.AI_MODEL_SMALL} via {small_provider} "
            f"(timeout={small_timeout}s, extra_body={small_extra or 'none'})"
        )

        # 大模型
        large_key = Config.AI_MODEL_LARGE_API_KEY or default_key
        large_provider = Config.AI_MODEL_LARGE_PROVIDER
        large_base_url = Config.AI_MODEL_LARGE_BASE_URL
        large_timeout = Config.AI_LLM_LARGE_TIMEOUT
        self._large = _create_provider(
            large_provider, large_key, large_base_url,
            timeout=large_timeout, model=Config.AI_MODEL_LARGE,
        )
        large_extra = _build_provider_extra_body(large_provider, Config.AI_MODEL_LARGE)
        logger.info(
            f"AI large model: {Config.AI_MODEL_LARGE} via {large_provider} "
            f"(timeout={large_timeout}s, extra_body={large_extra or 'none'})"
        )

    async def chat(
        self,
        messages: list[dict],
        system: str,
        tools: list[dict] | None = None,
        model_tier: str = "small",
        max_tokens: int | None = None,
    ) -> LLMResponse:
        """统一调用入口 — 自动路由到正确的 provider"""
        if model_tier == "large":
            provider = self._large
            model = Config.AI_MODEL_LARGE
        else:
            provider = self._small
            model = Config.AI_MODEL_SMALL

        return await provider.chat(
            model=model,
            messages=messages,
            system=system,
            tools=tools,
            max_tokens=max_tokens or Config.AI_MAX_OUTPUT_TOKENS,
        )

    async def chat_stream(
        self,
        messages: list[dict],
        system: str,
        tools: list[dict] | None = None,
        model_tier: str = "small",
        max_tokens: int | None = None,
    ) -> AsyncIterator[tuple[str, Any]]:
        """流式调用：yield ('text_delta', text) 或 ('done', LLMResponse)。"""
        if model_tier == "large":
            provider = self._large
            model = Config.AI_MODEL_LARGE
        else:
            provider = self._small
            model = Config.AI_MODEL_SMALL
        max_tok = max_tokens or Config.AI_MAX_OUTPUT_TOKENS
        if hasattr(provider, "chat_stream"):
            async for item in provider.chat_stream(
                model=model, messages=messages, system=system,
                tools=tools, max_tokens=max_tok,
            ):
                yield item
        else:
            resp = await provider.chat(
                model=model, messages=messages, system=system,
                tools=tools, max_tokens=max_tok,
            )
            full_text = "".join(
                b.text for b in resp.content
                if getattr(b, "type", None) == "text"
            )
            if full_text:
                yield ("text_delta", full_text)
            yield ("done", resp)

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
from typing import Any

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
            ),
            stop_reason=resp.stop_reason,
        )


class OpenAICompatibleProvider:
    """OpenAI-Compatible API（GLM / DeepSeek / Qwen / Moonshot / ...）

    使用 httpx 直接调用，兼容所有 OpenAI 协议 API。
    """

    def __init__(self, api_key: str, base_url: str, timeout: float = 30.0):
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout
        # 复用连接池
        import httpx
        self._client = httpx.AsyncClient(
            timeout=timeout,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )

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

        resp = await self._client.post(
            f"{self._base_url}/chat/completions",
            json=body,
        )
        resp.raise_for_status()
        data = resp.json()

        # 解析 OpenAI 响应 → 统一格式
        choice = data["choices"][0]
        message = choice["message"]

        content: list[LLMTextBlock | LLMToolUse] = []
        if message.get("content"):
            content.append(LLMTextBlock(text=message["content"]))

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
        return LLMResponse(
            content=content,
            model=data.get("model", model),
            usage=LLMUsage(
                input_tokens=usage_data.get("prompt_tokens", 0),
                output_tokens=usage_data.get("completion_tokens", 0),
            ),
            stop_reason=choice.get("finish_reason"),
        )


# ==================== 统一客户端 ====================

def _create_provider(provider_type: str, api_key: str, base_url: str, timeout: float):
    """工厂方法 — 根据 provider 类型创建实例"""
    if provider_type == "anthropic":
        return AnthropicProvider(api_key=api_key, timeout=timeout)
    elif provider_type == "openai_compatible":
        if not base_url:
            raise ValueError(f"openai_compatible provider requires BASE_URL")
        return OpenAICompatibleProvider(api_key=api_key, base_url=base_url, timeout=timeout)
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
        self._small = _create_provider(small_provider, small_key, small_base_url, timeout=small_timeout)
        logger.info(f"AI small model: {Config.AI_MODEL_SMALL} via {small_provider} (timeout={small_timeout}s)")

        # 大模型
        large_key = Config.AI_MODEL_LARGE_API_KEY or default_key
        large_provider = Config.AI_MODEL_LARGE_PROVIDER
        large_base_url = Config.AI_MODEL_LARGE_BASE_URL
        large_timeout = Config.AI_LLM_LARGE_TIMEOUT
        self._large = _create_provider(large_provider, large_key, large_base_url, timeout=large_timeout)
        logger.info(f"AI large model: {Config.AI_MODEL_LARGE} via {large_provider} (timeout={large_timeout}s)")

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

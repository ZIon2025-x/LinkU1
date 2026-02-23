"""
AI 工具注册表 — 装饰器模式统一定义、Schema、分组与执行

用法：
    from app.services.ai_tool_registry import tool_registry, ToolCategory

    @tool_registry.register(
        name="query_my_tasks",
        description="...",
        input_schema={...},
        categories=[ToolCategory.TASK],
    )
    async def _query_my_tasks(executor, input: dict) -> dict:
        ...

    # 按意图获取工具子集
    tools = tool_registry.get_tools_for_intent("task")  # 只返回 TASK + GENERAL 工具
    # 获取全量
    tools = tool_registry.get_all_tool_schemas()
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Awaitable

logger = logging.getLogger(__name__)


class ToolCategory(str, Enum):
    """工具分类 — 用于按意图选择工具子集"""
    TASK = "task"
    PROFILE = "profile"
    PLATFORM = "platform"      # 活动/跳蚤/论坛/排行榜/达人
    FAQ = "faq"
    NOTIFICATION = "notification"
    GENERAL = "general"        # 所有意图都应包含的通用工具


# 意图 → 需要发送给 LLM 的工具分类
INTENT_TO_CATEGORIES: dict[str, list[ToolCategory]] = {
    "task":     [ToolCategory.TASK, ToolCategory.GENERAL],
    "profile":  [ToolCategory.PROFILE, ToolCategory.NOTIFICATION, ToolCategory.GENERAL],
    "complex":  list(ToolCategory),
    "unknown":  list(ToolCategory),
}


@dataclass
class ToolDef:
    """一个已注册的工具"""
    name: str
    description: str
    input_schema: dict[str, Any]
    categories: list[ToolCategory]
    handler: Callable[..., Awaitable[dict]]

    def to_llm_schema(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "input_schema": self.input_schema,
        }


class ToolRegistry:
    """全局工具注册表（单例）"""

    def __init__(self):
        self._tools: dict[str, ToolDef] = {}

    def register(
        self,
        *,
        name: str,
        description: str,
        input_schema: dict[str, Any],
        categories: list[ToolCategory] | None = None,
    ):
        """装饰器：注册工具定义 + handler"""
        def decorator(fn: Callable[..., Awaitable[dict]]):
            if name in self._tools:
                logger.warning("Tool %s registered twice, overwriting", name)
            self._tools[name] = ToolDef(
                name=name,
                description=description,
                input_schema=input_schema,
                categories=categories or [ToolCategory.GENERAL],
                handler=fn,
            )
            return fn
        return decorator

    def get_handler(self, tool_name: str) -> Callable[..., Awaitable[dict]] | None:
        td = self._tools.get(tool_name)
        return td.handler if td else None

    def get_all_tool_schemas(self) -> list[dict[str, Any]]:
        return [td.to_llm_schema() for td in self._tools.values()]

    def get_tools_for_intent(self, intent: str) -> list[dict[str, Any]]:
        """按意图返回工具 schema 子集"""
        cats = INTENT_TO_CATEGORIES.get(intent)
        if not cats:
            return self.get_all_tool_schemas()
        cat_set = set(cats)
        return [
            td.to_llm_schema()
            for td in self._tools.values()
            if cat_set.intersection(td.categories)
        ]

    @property
    def tool_names(self) -> list[str]:
        return list(self._tools.keys())

    def __len__(self) -> int:
        return len(self._tools)


tool_registry = ToolRegistry()

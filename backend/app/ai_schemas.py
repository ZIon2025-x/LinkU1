"""
AI Agent Pydantic 请求/响应模型
"""

from pydantic import BaseModel, Field


class AIMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000, description="用户消息内容")


class AIConversationOut(BaseModel):
    id: str
    title: str
    model_used: str = ""
    total_tokens: int = 0
    created_at: str | None = None
    updated_at: str | None = None


class AIMessageOut(BaseModel):
    id: int
    role: str
    content: str
    tool_calls: list | None = None
    tool_results: list | None = None
    created_at: str | None = None

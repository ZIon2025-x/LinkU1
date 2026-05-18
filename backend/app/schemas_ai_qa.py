"""AI 限时问答 Pydantic schemas — 请求/响应。"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Literal
from pydantic import BaseModel, Field, field_validator


# ========== Draft Admin 写 ==========
class DraftCreate(BaseModel):
    title: str = Field(..., max_length=200)
    content: str
    topic_tag: Optional[str] = Field(None, max_length=50)
    target_forum_category_id: int
    deadline: datetime
    reward_pool_pence: int = Field(1000, ge=0, le=100000)
    participation_points: int = Field(5, ge=0, le=1000)
    floor_pence: int = Field(10, ge=1, le=1000)  # 单人最低分配（新算法替代 topn_formula）
    edit_lock_hours_before: int = Field(1, ge=0, le=24)
    posed_by_expert_id: Optional[str] = None  # 不填则后端用 SystemSettings 默认


class DraftUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = None
    topic_tag: Optional[str] = None
    target_forum_category_id: Optional[int] = None
    deadline: Optional[datetime] = None
    reward_pool_pence: Optional[int] = Field(None, ge=0, le=100000)
    participation_points: Optional[int] = Field(None, ge=0, le=1000)
    floor_pence: Optional[int] = Field(None, ge=1, le=1000)
    edit_lock_hours_before: Optional[int] = Field(None, ge=0, le=24)


# ========== AdminScoreUpdate ==========
class AdminScoreUpdate(BaseModel):
    admin_override_score: Optional[int] = Field(None, ge=0, le=100)
    hide_in_qa: Optional[bool] = None


# ========== Cancel ==========
class CancelRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500)


# ========== 答题 ==========
class AnswerCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: str = Field(..., min_length=1)
    images: List[str] = Field(default_factory=list, max_length=3)


# ========== 输出 ==========
class AiQuestionOut(BaseModel):
    id: int
    title: str
    content: str
    topic_tag: Optional[str]
    status: str
    posed_by_expert_id: str
    published_at: Optional[datetime]
    deadline: Optional[datetime]
    edit_lock_at: Optional[datetime]
    canceled_at: Optional[datetime]
    settled_at: Optional[datetime]
    reward_pool_pence: int
    participation_points: int
    floor_pence: int
    target_forum_category_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class AiAnswerOut(BaseModel):
    id: int
    forum_post_id: int
    user_id: str
    user_name: Optional[str] = None  # 后端 join 填
    user_avatar: Optional[str] = None
    title: Optional[str] = None
    content: Optional[str] = None
    images: Optional[List[str]] = None
    created_at: Optional[datetime] = None
    is_deleted: bool = False
    # 评分相关 (settled 后才有)
    ai_score: Optional[int] = None
    ai_generated: Optional[str] = None
    final_score: Optional[int] = None
    rank_final: Optional[int] = None
    reward_pence: int = 0
    hide_in_qa: bool = False

    class Config:
        from_attributes = True


# ========== Admin Review 表格 ==========
class AdminReviewRow(BaseModel):
    id: int  # ai_answer_scores.id
    user_id: str
    user_name: Optional[str]
    forum_post_id: int
    forum_post_created_at: datetime
    forum_post_updated_at: Optional[datetime]
    is_edited: bool  # forum_post.updated_at != created_at
    content_preview: str  # 截断 200 字
    ai_score: Optional[int]
    ai_generated: Optional[str]
    risk_score: int
    risk_reasons: Optional[str]
    admin_override_score: Optional[int]
    hide_in_qa: bool
    cash_budget_pence: int  # 前端实时算


class AdminReviewData(BaseModel):
    question: AiQuestionOut
    rows: List[AdminReviewRow]
    weekly_settled_pence: int  # S5 当周累计
    weekly_cap_pence: int


# ========== Settings ==========
class SettingUpdate(BaseModel):
    key: Literal[
        "ai_qa_weekly_settle_cap_pence",
        "ai_qa_settle_alert_threshold_pence",
        "ai_qa_default_expert_id",
    ]
    new_value: str
    confirm_token: str  # 前端给的 2 步确认 token (简单 hash 验证)

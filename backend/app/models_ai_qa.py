"""AI 限时问答相关 ORM 模型。独立文件避免污染 models.py。"""
from sqlalchemy import (
    Column, BigInteger, Integer, String, Text, Boolean, DateTime, JSON,
    ForeignKey, Index, UniqueConstraint, CheckConstraint, func
)
from sqlalchemy.dialects.postgresql import JSONB
from app.models import Base


class AiQaCycleConfig(Base):
    __tablename__ = "ai_qa_cycle_configs"
    id = Column(Integer, primary_key=True)
    name = Column(String(80), nullable=False)
    cadence = Column(String(20), nullable=False)
    next_run_at = Column(DateTime(timezone=True))
    is_active = Column(Boolean, default=True)
    direction_prompt = Column(Text, nullable=False)
    default_reward_pool_pence = Column(Integer, nullable=False, default=1000)
    default_participation_points = Column(Integer, nullable=False, default=5)
    default_floor_pence = Column(Integer, nullable=False, default=10)
    default_duration_hours = Column(Integer, nullable=False, default=168)
    default_edit_lock_hours_before = Column(Integer, nullable=False, default=1)
    target_forum_category_id = Column(Integer, ForeignKey("forum_categories.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    __table_args__ = (
        CheckConstraint("default_reward_pool_pence BETWEEN 0 AND 100000"),
        CheckConstraint("default_participation_points BETWEEN 0 AND 1000"),
    )


class AiQuestion(Base):
    __tablename__ = "ai_questions"
    id = Column(Integer, primary_key=True)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    topic_tag = Column(String(50))
    posed_by_expert_id = Column(String(8), ForeignKey("experts.id"), nullable=False)
    status = Column(String(20), nullable=False, default="draft")
    published_at = Column(DateTime(timezone=True))
    deadline = Column(DateTime(timezone=True))
    edit_lock_at = Column(DateTime(timezone=True))
    canceled_at = Column(DateTime(timezone=True))
    cancel_reason = Column(Text)
    settled_at = Column(DateTime(timezone=True))
    reward_pool_pence = Column(Integer, nullable=False, default=1000)
    participation_points = Column(Integer, nullable=False, default=5)
    floor_pence = Column(Integer, nullable=False, default=10)
    ai_prompt_used = Column(Text)
    target_forum_category_id = Column(Integer, ForeignKey("forum_categories.id"), nullable=False)
    cycle_config_id = Column(Integer, ForeignKey("ai_qa_cycle_configs.id"))
    created_by_admin_id = Column(String(5), ForeignKey("admin_users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    __table_args__ = (
        Index("idx_ai_questions_status", "status"),
        CheckConstraint("reward_pool_pence BETWEEN 0 AND 100000"),
        CheckConstraint("participation_points BETWEEN 0 AND 1000"),
        CheckConstraint("floor_pence BETWEEN 1 AND 1000"),  # 同步 SQL migration CHECK,避免 alembic autogen 干扰
    )


class AiQuestionCandidate(Base):
    __tablename__ = "ai_question_candidates"
    id = Column(Integer, primary_key=True)
    cycle_run_id = Column(String(36), nullable=False)
    cycle_config_id = Column(Integer, ForeignKey("ai_qa_cycle_configs.id"), nullable=False)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    topic_tag = Column(String(50))
    ai_model_used = Column(String(80))
    chosen = Column(Boolean, default=False)
    expired_at = Column(DateTime(timezone=True))
    snapshot_reward_pool_pence = Column(Integer, nullable=False)
    snapshot_floor_pence = Column(Integer, nullable=False)
    snapshot_duration_hours = Column(Integer, nullable=False)
    snapshot_edit_lock_hours_before = Column(Integer, nullable=False)
    snapshot_participation_points = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class AiAnswerScore(Base):
    __tablename__ = "ai_answer_scores"
    id = Column(Integer, primary_key=True)
    ai_question_id = Column(Integer, ForeignKey("ai_questions.id", ondelete="CASCADE"), nullable=False)
    forum_post_id = Column(Integer, nullable=False)  # 不加 FK
    user_id = Column(String(8), nullable=False)
    risk_score = Column(Integer, default=0)
    risk_reasons = Column(Text)
    ai_score = Column(Integer)
    off_topic = Column(Boolean, default=False)
    ai_generated = Column(String(10))
    ai_raw_response = Column(JSONB)
    admin_override_score = Column(Integer)
    admin_reviewer_id = Column(String(5), ForeignKey("admin_users.id"))
    admin_reviewed_at = Column(DateTime(timezone=True))
    hide_in_qa = Column(Boolean, default=False)
    final_score = Column(Integer)
    rank_final = Column(Integer)
    reward_pence = Column(Integer, default=0)
    reward_points = Column(Integer, default=0)
    settled_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint("ai_question_id", "forum_post_id"),
        UniqueConstraint("ai_question_id", "user_id"),
        Index("idx_ai_answer_scores_question", "ai_question_id"),
        Index("idx_ai_answer_scores_user", "user_id"),
    )


class AiQaLeaderboard(Base):
    __tablename__ = "ai_qa_leaderboard"
    id = Column(Integer, primary_key=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    total_won_pence = Column(Integer, default=0)
    win_count = Column(Integer, default=0)
    answer_count = Column(Integer, default=0)
    last_won_at = Column(DateTime(timezone=True))
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

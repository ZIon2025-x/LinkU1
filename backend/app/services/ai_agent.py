"""
AI Agent 核心调度器 — 管理对话流程和工具调用循环

成本控制策略：
1. 意图分类（关键词 → 本地处理 / Haiku 判别 → Sonnet 兜底）
2. 离题拒绝（不回答与平台无关的问题）
3. FAQ 缓存（Redis/内存，避免重复 LLM 调用）
4. 每用户每日 token 预算 + 请求次数限制
5. 严格的 max_output_tokens 限制回复长度
6. 历史轮数裁剪（只保留最近 N 轮）
"""

import json
import logging
import re
import time
import uuid
from typing import AsyncIterator

from sse_starlette.sse import ServerSentEvent

from sqlalchemy import select, desc, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.config import Config
from app.services.ai_llm_client import LLMClient
from app.services.ai_tools import TOOLS
from app.services.ai_tool_executor import ToolExecutor, PLATFORM_FAQ
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# ==================== 单例 ====================

_llm_client: LLMClient | None = None


def get_llm_client() -> LLMClient:
    global _llm_client
    if _llm_client is None:
        _llm_client = LLMClient()
    return _llm_client


# ==================== FAQ 缓存（内存，可扩展到 Redis） ====================

_faq_cache: dict[str, tuple[str, float]] = {}  # key → (answer, expire_ts)


def _get_faq_cache(key: str) -> str | None:
    entry = _faq_cache.get(key)
    if entry and entry[1] > time.time():
        return entry[0]
    return None


def _set_faq_cache(key: str, answer: str):
    _faq_cache[key] = (answer, time.time() + Config.AI_FAQ_CACHE_TTL)


# ==================== 每用户每日预算追踪（内存，可扩展到 Redis） ====================

# {user_id: {"date": "2026-02-16", "tokens": 12345, "requests": 50}}
_daily_usage: dict[str, dict] = {}


def _get_today() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _check_daily_budget(user_id: str) -> tuple[bool, str]:
    """检查用户是否超过每日预算。返回 (ok, reason)"""
    today = _get_today()
    usage = _daily_usage.get(user_id)

    if not usage or usage["date"] != today:
        # 新的一天，重置
        _daily_usage[user_id] = {"date": today, "tokens": 0, "requests": 0}
        return True, ""

    if usage["requests"] >= Config.AI_DAILY_REQUEST_LIMIT:
        return False, "今日 AI 对话次数已用完，明天再来吧"

    if usage["tokens"] >= Config.AI_DAILY_TOKEN_BUDGET:
        return False, "今日 AI 使用额度已用完，明天再来吧"

    return True, ""


def _record_usage(user_id: str, tokens: int):
    today = _get_today()
    usage = _daily_usage.get(user_id)
    if not usage or usage["date"] != today:
        _daily_usage[user_id] = {"date": today, "tokens": tokens, "requests": 1}
    else:
        usage["tokens"] += tokens
        usage["requests"] += 1


# ==================== 意图分类 ====================

class IntentType:
    FAQ = "faq"              # 平台FAQ → 本地回答，不调LLM
    TASK_QUERY = "task"      # 任务相关查询 → 小模型 + 工具
    PROFILE = "profile"      # 个人资料查询 → 小模型 + 工具
    COMPLEX = "complex"      # 复杂/多步 → 大模型 + 工具
    OFF_TOPIC = "off_topic"  # 离题 → 直接拒绝，不调LLM
    UNKNOWN = "unknown"      # 需要 LLM 判别


# 离题关键词（高置信度直接拒绝）
_OFF_TOPIC_PATTERNS = [
    r"写(一篇|个|段|首)(作文|文章|诗|歌|小说|故事|代码|程序|脚本)",
    r"(翻译|帮我翻译|translate)",
    r"(编程|写代码|debug|代码|python|java|javascript|html|css)",
    r"(数学|算一下|计算|方程|几何|概率)",
    r"(天气|股票|新闻|体育|娱乐|明星|游戏|电影)",
    r"(谁是|什么是|历史上|科学|物理|化学|生物)",
    r"(聊天|闲聊|无聊|讲个笑话|joke|chat with me)",
    r"(写信|写邮件|写简历|resume|cover letter)",
    r"(AI|GPT|Claude|OpenAI|人工智能).*(是什么|怎么样|对比)",
]
_OFF_TOPIC_RE = re.compile("|".join(_OFF_TOPIC_PATTERNS), re.IGNORECASE)

# FAQ 关键词 → 直接命中本地FAQ（零 LLM 消耗）
_FAQ_KEYWORDS = {
    "faq_publish": ["怎么发布", "如何发布", "how to post", "how to create task", "发任务", "创建任务"],
    "faq_accept": ["怎么接单", "如何接任务", "how to accept", "how to take", "接任务"],
    "faq_payment": ["支付", "付款", "怎么付", "how to pay", "payment", "转账", "收款"],
    "faq_fee": ["费用", "手续费", "服务费", "收费", "fee", "charge", "多少钱", "cost"],
    "faq_dispute": ["争议", "投诉", "退款", "dispute", "refund", "complain"],
    "faq_account": ["改密码", "修改密码", "change password", "修改头像", "个人资料", "profile settings"],
}

# 任务相关关键词
_TASK_KEYWORDS = ["任务", "task", "我的任务", "my task", "进行中", "已完成", "查看任务",
                  "搜索任务", "search task", "find task", "任务详情", "task detail",
                  "状态", "status", "订单", "order"]

# 个人资料关键词
_PROFILE_KEYWORDS = ["个人资料", "我的资料", "my profile", "评分", "rating", "等级", "level",
                     "统计", "stats", "我的信息"]


def classify_intent(message: str) -> str:
    """本地意图分类（零 LLM 消耗）

    优先级：
    1. 离题检测 → 直接拒绝
    2. FAQ 精确匹配 → 本地回答
    3. 任务/资料关键词 → 小模型
    4. 无法判断 → 让 Haiku 判别（很少走到这一步）
    """
    msg_lower = message.lower().strip()

    # 1. 离题检测
    if _OFF_TOPIC_RE.search(msg_lower):
        return IntentType.OFF_TOPIC

    # 超短消息（<3字符）视为无效
    if len(msg_lower) < 3:
        return IntentType.OFF_TOPIC

    # 2. FAQ 精确匹配
    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            return IntentType.FAQ

    # 3. 任务相关
    if any(kw in msg_lower for kw in _TASK_KEYWORDS):
        return IntentType.TASK_QUERY

    # 4. 个人资料
    if any(kw in msg_lower for kw in _PROFILE_KEYWORDS):
        return IntentType.PROFILE

    # 5. 包含平台相关词（宽泛匹配）
    platform_words = ["link2ur", "平台", "platform", "帮助", "help", "使用", "怎么用",
                      "how to", "功能", "feature", "钱包", "wallet", "积分", "points",
                      "优惠券", "coupon", "活动", "activity", "达人", "expert",
                      "论坛", "forum", "跳蚤", "flea"]
    if any(w in msg_lower for w in platform_words):
        return IntentType.UNKNOWN  # 让 LLM 判断具体需求

    # 6. 默认：不确定 → 让 Haiku 快速判别
    return IntentType.UNKNOWN


def _get_faq_answer(message: str, lang: str) -> str | None:
    """尝试从本地FAQ数据直接返回答案（零 LLM 消耗）"""
    msg_lower = message.lower()
    lang_key = "en" if lang.startswith("en") else "zh"

    faq_topic_map = {
        "faq_publish": "publish",
        "faq_accept": "accept",
        "faq_payment": "payment",
        "faq_fee": "fee",
        "faq_dispute": "dispute",
        "faq_account": "account",
    }

    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            topic = faq_topic_map[faq_key]
            return PLATFORM_FAQ[topic][lang_key]

    return None


# ==================== System Prompt ====================

_SYSTEM_PROMPT_TEMPLATE = """你是 Link2Ur 技能互助平台的官方 AI 客服助手。你只处理与 Link2Ur 平台相关的问题。

【当前用户信息】
- 用户名: {user_name} (ID: {user_id})
- 语言偏好: {lang}
- 用户等级: {user_level}

【你的职责范围 — 只限以下内容】
1. 回答 Link2Ur 平台使用问题（发布任务、接单、支付、费用）
2. 查询用户的任务状态和详情
3. 搜索平台上的公开任务
4. 查看用户个人资料和统计
5. 解答平台规则和常见问题

【严格禁止 — 必须拒绝的请求】
- 任何与 Link2Ur 平台无关的问题（闲聊、写作文、编程、数学、翻译、新闻等）
- 修改任何数据（当前版本只读）
- 访问其他用户的私人信息
- 执行支付或转账操作
- 充当通用 AI 助手或聊天机器人

如果用户提出与平台无关的问题，直接回复："抱歉，我只能回答 Link2Ur 平台相关的问题。如需帮助请描述您在平台上遇到的具体问题。"
如果用户的请求超出你的能力范围，引导用户联系人工客服。

【回复规范】
- 语言：{lang_instruction}
- 长度：**每次回复控制在 3-5 句话以内**，不要长篇大论
- 格式：不要用 markdown 标题（#），适当用列表和加粗
- 风格：简洁专业，直接解决问题，不要寒暄

【示例对话】

用户：我的任务现在什么状态？
助手：我来帮你查询。[调用 query_my_tasks 工具]
根据查询结果，你目前有 3 个任务：
- **搬家帮忙**（进行中）— 截止 2/20
- **遛狗服务**（已完成）
- **翻译文件**（开放中，等待接单）

用户：帮我写一首诗
助手：抱歉，我只能回答 Link2Ur 平台相关的问题。如需帮助请描述您在平台上遇到的具体问题。

用户：怎么发布任务？
助手：发布任务步骤：
1. 点击首页"发布任务"按钮
2. 填写标题、描述、报酬和截止日期
3. 选择任务类型和位置
4. 提交后预付款到平台托管
5. 等待接单者接单

用户：平台收费多少？
助手：平台对每笔交易收取服务费，具体比例在发布页面显示。接单者最终收到 = 报酬 - 服务费。详细费率可在发布任务页面查看。"""


def _build_system_prompt(user: models.User, resolved_lang: str | None = None) -> str:
    """resolved_lang: 已解析的 zh/en，若传入则优先于 user.language_preference（与 FAQ/离题一致）。"""
    lang = resolved_lang
    if not lang and user.language_preference and user.language_preference.strip():
        lang = user.language_preference.strip().lower()
    if not lang:
        lang = "zh"
    lang = "en" if lang.startswith("en") else "zh"
    if lang == "en":
        lang_instruction = "Reply in English"
    else:
        lang_instruction = "用中文回复"

    return _SYSTEM_PROMPT_TEMPLATE.format(
        user_name=user.name,
        user_id=user.id,
        lang=lang,
        user_level=user.user_level or "normal",
        lang_instruction=lang_instruction,
    )


# ==================== 离题拒绝消息 ====================

_OFF_TOPIC_RESPONSES = {
    "zh": "抱歉，我只能回答 Link2Ur 平台相关的问题。如需帮助请描述您在平台上遇到的具体问题，例如任务查询、支付流程、费用说明等。",
    "en": "Sorry, I can only answer questions related to the Link2Ur platform. Please describe your specific platform question, such as task queries, payment process, or fee details.",
}


# ==================== AI Agent ====================

class AIAgent:
    """AI Agent 核心调度器

    调用链路：
    1. classify_intent() → 本地关键词分类（零消耗）
    2. FAQ → 直接返回缓存答案（零消耗）
    3. OFF_TOPIC → 直接拒绝（零消耗）
    4. TASK/PROFILE → 小模型 Haiku + 工具调用
    5. UNKNOWN → Haiku 先判别相关性，再决定是否调用工具
    6. COMPLEX → 大模型 Sonnet（极少数情况）
    """

    def __init__(
        self,
        db: AsyncSession,
        user: models.User,
        *,
        accept_lang: str | None = None,
    ):
        self.db = db
        self.user = user
        self._accept_lang = accept_lang  # "zh" | "en" from Accept-Language header
        self.llm = get_llm_client()
        self.executor = ToolExecutor(db, user)

    async def _load_history(self, conversation_id: str) -> list[dict]:
        """加载对话历史（最近 N 轮，节省 token）"""
        max_turns = Config.AI_MAX_HISTORY_TURNS
        q = (
            select(models.AIMessage)
            .where(
                and_(
                    models.AIMessage.conversation_id == conversation_id,
                    models.AIMessage.role.in_(["user", "assistant"]),
                )
            )
            .order_by(desc(models.AIMessage.created_at))
            .limit(max_turns * 2)
        )
        rows = (await self.db.execute(q)).scalars().all()
        rows = list(reversed(rows))

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
                            "type": "tool_use",
                            "id": tc["id"],
                            "name": tc["name"],
                            "input": tc["input"],
                        })
                except (json.JSONDecodeError, KeyError):
                    pass
                messages.append({"role": "assistant", "content": content_blocks})
                if msg.tool_results:
                    try:
                        tool_results = json.loads(msg.tool_results)
                        result_blocks = []
                        for tr in tool_results:
                            result_blocks.append({
                                "type": "tool_result",
                                "tool_use_id": tr["tool_use_id"],
                                "content": json.dumps(tr["result"], ensure_ascii=False),
                            })
                        messages.append({"role": "user", "content": result_blocks})
                    except (json.JSONDecodeError, KeyError):
                        pass
            else:
                messages.append({"role": msg.role, "content": msg.content})
        return messages

    def _get_lang(self) -> str:
        # 优先用户资料中的语言偏好，其次请求头 Accept-Language（与 App 当前语言一致），默认 zh
        lang = None
        if self.user.language_preference and self.user.language_preference.strip():
            lang = self.user.language_preference.strip().lower()
        if not lang and self._accept_lang:
            lang = self._accept_lang
        if not lang:
            lang = "zh"
        return "en" if lang.startswith("en") else "zh"

    async def process_message_stream(
        self, conversation_id: str, user_message: str
    ) -> AsyncIterator[ServerSentEvent]:
        """处理用户消息，返回 SSE 事件流

        节省 token 的完整链路：
        1. 每日预算检查
        2. 意图分类（本地，零消耗）
        3. FAQ/离题 → 直接返回（零 LLM 消耗）
        4. 需要 LLM → 选择合适模型 → 调用 → 保存
        """
        lang = self._get_lang()

        # ---- 0. 每日预算检查 ----
        ok, reason = _check_daily_budget(self.user.id)
        if not ok:
            yield self._make_text_sse(reason)
            yield self._make_done_sse()
            return

        # ---- 1. 保存用户消息 ----
        user_msg = models.AIMessage(
            conversation_id=conversation_id,
            role="user",
            content=user_message,
        )
        self.db.add(user_msg)
        await self.db.flush()

        # ---- 2. 意图分类（本地，零消耗） ----
        intent = classify_intent(user_message)
        logger.info(f"AI intent: {intent} for user {self.user.id}: {user_message[:50]}")

        # ---- 3a. 离题 → 直接拒绝 ----
        if intent == IntentType.OFF_TOPIC:
            reply = _OFF_TOPIC_RESPONSES[lang]
            await self._save_assistant_message(conversation_id, reply, "local", 0, 0)
            yield self._make_text_sse(reply)
            yield self._make_done_sse()
            return

        # ---- 3b. FAQ → 本地回答 + 缓存 ----
        if intent == IntentType.FAQ:
            cache_key = f"faq:{lang}:{user_message[:100]}"
            cached = _get_faq_cache(cache_key)
            if cached:
                reply = cached
            else:
                reply = _get_faq_answer(user_message, lang) or _OFF_TOPIC_RESPONSES[lang]
                _set_faq_cache(cache_key, reply)
            await self._save_assistant_message(conversation_id, reply, "local_faq", 0, 0)
            yield self._make_text_sse(reply)
            yield self._make_done_sse()
            return

        # ---- 4. 需要 LLM ----
        # 决定模型 tier
        model_tier = "small"  # 默认 Haiku
        if intent == IntentType.COMPLEX:
            model_tier = "large"  # Sonnet（极少走到）

        # 加载历史
        history = await self._load_history(conversation_id)
        messages = history + [{"role": "user", "content": user_message}]
        system_prompt = _build_system_prompt(self.user, self._get_lang())

        full_response = ""
        all_tool_calls = []
        all_tool_results = []
        total_input_tokens = 0
        total_output_tokens = 0
        model_used = ""

        # 工具调用循环（最多 3 轮，限制 token 消耗）
        for _round in range(3):
            response = await self.llm.chat(
                messages=messages,
                system=system_prompt,
                tools=TOOLS,
                model_tier=model_tier,
            )
            model_used = response.model
            total_input_tokens += response.usage.input_tokens
            total_output_tokens += response.usage.output_tokens

            tool_use_blocks = [b for b in response.content if b.type == "tool_use"]

            if not tool_use_blocks:
                for block in response.content:
                    if block.type == "text":
                        full_response += block.text
                        # 按 chunk 发送（非逐字，减少 SSE 帧数）
                        yield self._make_text_sse(block.text)
                break

            # 有工具调用
            for block in response.content:
                if block.type == "text" and block.text:
                    full_response += block.text
                    yield self._make_text_sse(block.text)

            assistant_content = []
            for block in response.content:
                if block.type == "text":
                    assistant_content.append({"type": "text", "text": block.text})
                elif block.type == "tool_use":
                    assistant_content.append({
                        "type": "tool_use",
                        "id": block.id,
                        "name": block.name,
                        "input": block.input,
                    })

            messages.append({"role": "assistant", "content": assistant_content})

            tool_result_blocks = []
            for block in tool_use_blocks:
                yield ServerSentEvent(
                    data=json.dumps({"tool": block.name, "input": block.input}, ensure_ascii=False),
                    event="tool_call",
                )

                result = await self.executor.execute(block.name, block.input)
                all_tool_calls.append({"id": block.id, "name": block.name, "input": block.input})
                all_tool_results.append({"tool_use_id": block.id, "result": result})

                yield ServerSentEvent(
                    data=json.dumps({"tool": block.name, "result": result}, ensure_ascii=False),
                    event="tool_result",
                )

                tool_result_blocks.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

            messages.append({"role": "user", "content": tool_result_blocks})

            # 工具结果后如果需要大模型处理复杂推理，升级 tier
            if _round == 0 and len(tool_use_blocks) >= 2:
                model_tier = "large"

        # ---- 5. 保存 & 记录用量 ----
        total_tokens = total_input_tokens + total_output_tokens
        _record_usage(self.user.id, total_tokens)

        await self._save_assistant_message(
            conversation_id, full_response, model_used,
            total_input_tokens, total_output_tokens,
            all_tool_calls, all_tool_results,
        )

        # 更新对话统计
        conv_q = select(models.AIConversation).where(models.AIConversation.id == conversation_id)
        conv = (await self.db.execute(conv_q)).scalar_one_or_none()
        if conv:
            conv.total_tokens = (conv.total_tokens or 0) + total_tokens
            conv.model_used = model_used
            conv.updated_at = get_utc_time()
            if not conv.title and user_message:
                conv.title = user_message[:100]

        await self.db.commit()

        yield self._make_done_sse(total_input_tokens, total_output_tokens)

    # ==================== 辅助方法 ====================

    async def _save_assistant_message(
        self, conversation_id: str, content: str, model_used: str,
        input_tokens: int, output_tokens: int,
        tool_calls: list | None = None, tool_results: list | None = None,
    ):
        msg = models.AIMessage(
            conversation_id=conversation_id,
            role="assistant",
            content=content,
            tool_calls=json.dumps(tool_calls, ensure_ascii=False) if tool_calls else None,
            tool_results=json.dumps(tool_results, ensure_ascii=False) if tool_results else None,
            model_used=model_used,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )
        self.db.add(msg)

    @staticmethod
    def _make_text_sse(text: str) -> ServerSentEvent:
        return ServerSentEvent(
            data=json.dumps({"content": text}, ensure_ascii=False),
            event="token",
        )

    @staticmethod
    def _make_done_sse(input_tokens: int = 0, output_tokens: int = 0) -> ServerSentEvent:
        return ServerSentEvent(
            data=json.dumps({"input_tokens": input_tokens, "output_tokens": output_tokens}),
            event="done",
        )

    # ==================== CRUD 方法（不变） ====================

    async def create_conversation(self) -> models.AIConversation:
        conv = models.AIConversation(
            id=str(uuid.uuid4()),
            user_id=self.user.id,
        )
        self.db.add(conv)
        await self.db.commit()
        await self.db.refresh(conv)
        return conv

    async def get_conversations(self, page: int = 1, page_size: int = 20) -> dict:
        conditions = [
            models.AIConversation.user_id == self.user.id,
            models.AIConversation.status == "active",
        ]
        count_q = select(func.count()).select_from(models.AIConversation).where(and_(*conditions))
        total = (await self.db.execute(count_q)).scalar() or 0

        q = (
            select(models.AIConversation)
            .where(and_(*conditions))
            .order_by(desc(models.AIConversation.updated_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).scalars().all()

        conversations = []
        for c in rows:
            conversations.append({
                "id": c.id,
                "title": c.title or "新对话",
                "model_used": c.model_used,
                "total_tokens": c.total_tokens,
                "created_at": c.created_at.isoformat() if c.created_at else None,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            })

        return {"conversations": conversations, "total": total, "page": page}

    async def get_conversation_messages(self, conversation_id: str) -> list[dict]:
        conv_q = select(models.AIConversation).where(
            and_(
                models.AIConversation.id == conversation_id,
                models.AIConversation.user_id == self.user.id,
            )
        )
        conv = (await self.db.execute(conv_q)).scalar_one_or_none()
        if not conv:
            return []

        q = (
            select(models.AIMessage)
            .where(models.AIMessage.conversation_id == conversation_id)
            .order_by(models.AIMessage.created_at)
        )
        rows = (await self.db.execute(q)).scalars().all()

        messages = []
        for msg in rows:
            m = {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            }
            if msg.tool_calls:
                try:
                    m["tool_calls"] = json.loads(msg.tool_calls)
                except json.JSONDecodeError:
                    pass
            if msg.tool_results:
                try:
                    m["tool_results"] = json.loads(msg.tool_results)
                except json.JSONDecodeError:
                    pass
            messages.append(m)

        return messages

    async def archive_conversation(self, conversation_id: str) -> bool:
        q = select(models.AIConversation).where(
            and_(
                models.AIConversation.id == conversation_id,
                models.AIConversation.user_id == self.user.id,
            )
        )
        conv = (await self.db.execute(q)).scalar_one_or_none()
        if not conv:
            return False
        conv.status = "archived"
        await self.db.commit()
        return True

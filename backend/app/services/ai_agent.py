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
from app.services.ai_tool_executor import ToolExecutor
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# ==================== 单例 ====================

_llm_client: LLMClient | None = None


def get_llm_client() -> LLMClient:
    global _llm_client
    if _llm_client is None:
        _llm_client = LLMClient()
    return _llm_client


# ==================== FAQ 缓存（内存，带大小上限） ====================

_FAQ_CACHE_MAX_SIZE = 500
_faq_cache: dict[str, tuple[str, float]] = {}  # key → (answer, expire_ts)


def _get_faq_cache(key: str) -> str | None:
    entry = _faq_cache.get(key)
    if entry and entry[1] > time.time():
        return entry[0]
    if entry:
        del _faq_cache[key]  # 过期则删除
    return None


def _set_faq_cache(key: str, answer: str):
    # 超过上限时清理过期条目
    if len(_faq_cache) >= _FAQ_CACHE_MAX_SIZE:
        now = time.time()
        expired = [k for k, (_, ts) in _faq_cache.items() if ts <= now]
        for k in expired:
            del _faq_cache[k]
        # 仍超过上限则清除最早 20%
        if len(_faq_cache) >= _FAQ_CACHE_MAX_SIZE:
            to_remove = list(_faq_cache.keys())[:_FAQ_CACHE_MAX_SIZE // 5]
            for k in to_remove:
                del _faq_cache[k]
    _faq_cache[key] = (answer, time.time() + Config.AI_FAQ_CACHE_TTL)


# ==================== 每用户每日预算追踪（内存，带自动清理） ====================

_DAILY_USAGE_MAX_USERS = 5000
# {user_id: {"date": "2026-02-16", "tokens": 12345, "requests": 50}}
_daily_usage: dict[str, dict] = {}
_last_usage_cleanup = 0.0


def _get_today() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _cleanup_daily_usage():
    """清理非今日的过期条目"""
    global _last_usage_cleanup
    now = time.time()
    if now - _last_usage_cleanup < 300:  # 最多每 5 分钟清理一次
        return
    _last_usage_cleanup = now
    today = _get_today()
    stale = [uid for uid, v in _daily_usage.items() if v.get("date") != today]
    for uid in stale:
        del _daily_usage[uid]


_BUDGET_REASONS = {
    "zh": {
        "requests": "今日 AI 对话次数已用完，明天再来吧",
        "tokens": "今日 AI 使用额度已用完，明天再来吧",
    },
    "en": {
        "requests": "Daily AI chat limit reached. Please try again tomorrow.",
        "tokens": "Daily AI usage limit reached. Please try again tomorrow.",
    },
}


def _check_daily_budget(user_id: str, lang: str = "en") -> tuple[bool, str]:
    """检查用户是否超过每日预算。返回 (ok, reason)，reason 按 lang 返回中/英文。"""
    today = _get_today()
    usage = _daily_usage.get(user_id)
    msgs = _BUDGET_REASONS.get(lang, _BUDGET_REASONS["en"])

    if not usage or usage["date"] != today:
        if len(_daily_usage) >= _DAILY_USAGE_MAX_USERS:
            _cleanup_daily_usage()
        _daily_usage[user_id] = {"date": today, "tokens": 0, "requests": 0}
        return True, ""

    if usage["requests"] >= Config.AI_DAILY_REQUEST_LIMIT:
        return False, msgs["requests"]

    if usage["tokens"] >= Config.AI_DAILY_TOKEN_BUDGET:
        return False, msgs["tokens"]

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
    TRANSFER_TO_CS = "transfer_to_cs"  # 用户请求转人工客服


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
# 覆盖全部 20 个 faq_sections
_FAQ_KEYWORDS = {
    "faq_about": ["link2ur是什么", "什么是link2ur", "what is link2ur", "谁可以使用", "who can use", "平台介绍", "如何加入", "加入你们", "怎么加入", "how to join", "可以合作吗", "合作", "partner", "partnership", "collaborate", "成为合作伙伴", "become partner"],
    "faq_publish": ["怎么发布", "如何发布", "how to post", "how to create task", "发任务", "创建任务", "发布流程", "发布技巧"],
    "faq_accept": ["怎么接单", "如何接任务", "how to accept", "how to take", "接任务", "接单流程", "接受任务", "任务流程", "basic task flow"],
    "faq_payment": ["支付", "付款", "怎么付", "how to pay", "payment", "转账", "收款", "怎么收款", "何时到账", "退款", "refund"],
    "faq_fee": ["费用", "手续费", "服务费", "收费", "fee", "charge", "多少钱", "cost", "费率", "支付方式", "payment method", "stripe", "apple pay"],
    "faq_dispute": ["争议", "投诉", "dispute", "complain", "纠纷", "申诉", "未确认", "拒绝确认", "not confirm"],
    "faq_account": ["改密码", "修改密码", "change password", "修改头像", "个人资料", "profile settings", "账户设置", "绑定账户", "无法登录", "can't log in", "forgot password", "忘记密码", "掉线", "注销账户", "delete account", "修改邮箱", "change email"],
    "faq_wallet": ["钱包", "提现", "withdraw", "到账", "收款账户", "payout", "怎么提现", "绑定收款", "stripe connect"],
    "faq_cancel": ["取消任务", "cancel task", "取消已发布", "取消已接", "取消审核", "客服审核取消"],
    "faq_report": ["举报", "report", "不实信息", "违法", "诈骗", "fraud", "安全", "safety", "保护自己"],
    "faq_privacy": ["隐私", "privacy", "数据", "data", "账户安全", "account security", "封禁", "ban", "暂停", "suspend", "申诉"],
    "faq_flea": ["跳蚤", "二手", "flea", "闲置", "求购", "卖东西", "买二手", "议价", "make an offer", "flea market"],
    "faq_forum": ["论坛", "forum", "发帖", "社区", "community", "板块", "帖子被删"],
    "faq_application": ["申请任务", "apply for task", "task application", "议价", "negotiate", "申请被拒"],
    "faq_review": ["评价", "review", "rating", "差评", "信用", "reputation", "修改评价"],
    "faq_student": ["学生认证", "student verification", "学校邮箱", "school email", "认证失败"],
    "faq_expert": ["任务达人", "task expert", "成为达人", "become expert", "预约达人", "book expert"],
    "faq_activity": ["活动", "activity", "多人任务", "报名活动", "join activity", "活动专区"],
    "faq_coupon": ["优惠券", "coupon", "积分", "points", "抵扣", "折扣", "如何使用优惠券"],
    "faq_notification": ["通知", "notification", "收不到通知", "推送", "push", "消息和通知区别"],
    "faq_message_support": ["客服在线时间", "support hours", "消息未送达", "message not delivered"],
    "faq_vip": ["vip", "会员", "membership", "开通会员", "购买会员", "升级会员", "取消会员", "vip权益", "vip benefits", "超级vip", "super vip"],
    "faq_linker": ["linker", "智能助手", "ai助手", "ai客服", "机器人", "bot", "linker能做什么", "what can linker", "小助手"],
}

# 任务相关关键词
_TASK_KEYWORDS = ["任务", "task", "我的任务", "my task", "进行中", "已完成", "查看任务",
                  "搜索任务", "search task", "find task", "任务详情", "task detail",
                  "状态", "status", "订单", "order"]

# 个人资料关键词
_PROFILE_KEYWORDS = ["个人资料", "我的资料", "my profile", "评分", "rating", "等级", "level",
                     "统计", "stats", "我的信息"]

# 转人工客服关键词
_TRANSFER_CS_KEYWORDS = [
    "转人工", "人工客服", "真人客服", "找客服", "联系客服",
    "connect human", "talk to agent", "human agent", "real person",
    "speak to someone", "customer service", "live agent", "live chat",
    "transfer to human", "real agent",
]


# 个性化数据关键词 — 命中则跳过 FAQ，走 LLM + 工具获取用户真实数据
_PERSONAL_DATA_KEYWORDS = [
    "我的积分", "my points", "积分余额", "points balance", "几张券",
    "我的优惠券", "my coupon", "可用优惠券", "有没有券",
    "我的通知", "未读通知", "unread notification", "几条未读", "未读消息",
    "我的帖子", "my post", "我发过", "我发的帖",
    "有什么活动", "最近活动", "current activities", "哪些活动",
    "有没有二手", "搜索跳蚤", "search flea", "二手市场",
    "排行榜", "榜单", "leaderboard", "谁排第一",
    "有哪些达人", "推荐达人", "哪个达人", "达人列表",
    "我的余额", "my balance",
]


def classify_intent(message: str) -> str:
    """本地意图分类（零 LLM 消耗）

    优先级：
    1. 离题检测 → 直接拒绝
    2. 转人工客服 → 检查在线
    3. 个性化数据 → LLM + 工具（跳过 FAQ）
    4. FAQ 精确匹配 → 本地回答
    5. 任务/资料关键词 → 小模型
    6. 平台相关词 → LLM 判别
    7. 默认 → Haiku 快速判别
    """
    msg_lower = message.lower().strip()

    # 1. 离题检测
    if _OFF_TOPIC_RE.search(msg_lower):
        return IntentType.OFF_TOPIC

    # 超短消息（<3字符）视为无效
    if len(msg_lower) < 3:
        return IntentType.OFF_TOPIC

    # 2. 转人工客服检测（优先于 FAQ）
    if any(kw in msg_lower for kw in _TRANSFER_CS_KEYWORDS):
        return IntentType.TRANSFER_TO_CS

    # 3. 个性化数据查询（优先于 FAQ，避免 FAQ 拦截个性化请求）
    if any(kw in msg_lower for kw in _PERSONAL_DATA_KEYWORDS):
        return IntentType.UNKNOWN  # 走 LLM + 新工具

    # 4. FAQ 精确匹配
    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            return IntentType.FAQ

    # 5. 任务相关
    if any(kw in msg_lower for kw in _TASK_KEYWORDS):
        return IntentType.TASK_QUERY

    # 6. 个人资料
    if any(kw in msg_lower for kw in _PROFILE_KEYWORDS):
        return IntentType.PROFILE

    # 7. 包含平台相关词（宽泛匹配）
    platform_words = ["link2ur", "平台", "platform", "帮助", "help", "使用", "怎么用",
                      "how to", "功能", "feature", "钱包", "wallet", "积分", "points",
                      "优惠券", "coupon", "活动", "activity", "达人", "expert",
                      "论坛", "forum", "跳蚤", "flea", "认证", "verify",
                      "排行", "leaderboard", "通知", "notification", "消息", "message"]
    if any(w in msg_lower for w in platform_words):
        return IntentType.UNKNOWN  # 让 LLM 判断具体需求

    # 8. 默认：不确定 → 让 Haiku 快速判别
    return IntentType.UNKNOWN


# faq_key（_FAQ_KEYWORDS 的 key）→ 主题（用于查 DB 的 TOPIC_TO_SECTION_KEY）
_FAQ_KEY_TO_TOPIC = {
    "faq_about": "about",
    "faq_publish": "publish",
    "faq_accept": "accept",
    "faq_payment": "payment",
    "faq_fee": "fee",
    "faq_dispute": "dispute",
    "faq_account": "account",
    "faq_wallet": "wallet",
    "faq_cancel": "cancel",
    "faq_report": "report",
    "faq_privacy": "privacy",
    "faq_flea": "flea",
    "faq_forum": "forum",
    "faq_application": "application",
    "faq_review": "review",
    "faq_student": "student",
    "faq_expert": "expert",
    "faq_activity": "activity",
    "faq_coupon": "coupon",
    "faq_notification": "notification",
    "faq_message_support": "message_support",
    "faq_vip": "vip",
    "faq_linker": "linker",
}


def _get_matched_faq_topic(message: str) -> str | None:
    """根据关键词命中返回对应 FAQ 主题（publish/accept/...），供从 DB 取答案。"""
    msg_lower = message.lower()
    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            return _FAQ_KEY_TO_TOPIC.get(faq_key)
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
6. 查询用户积分余额和可用优惠券
7. 浏览平台活动、跳蚤市场商品、论坛帖子
8. 查看通知摘要、排行榜、任务达人信息

【严格禁止 — 必须拒绝的请求】
- 任何与 Link2Ur 平台无关的问题（闲聊、写作文、编程、数学、翻译、新闻等）
- 修改任何数据（当前版本只读）
- 访问其他用户的私人信息
- 执行支付或转账操作
- 充当通用 AI 助手或聊天机器人

如果用户提出与平台无关的问题，直接回复："抱歉，我只能回答 Link2Ur 平台相关的问题。如需帮助请描述您在平台上遇到的具体问题。"
如果用户的请求超出你的能力范围（如需要修改数据、退款处理、争议仲裁等），主动建议用户输入"转人工"来连接人工客服。
你可以使用 check_cs_availability 工具来检查是否有人工客服在线。

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
        lang = "en"
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


def _is_cjk(c: str) -> bool:
    """常见 CJK 字符范围（中文、日文汉字等）。"""
    o = ord(c)
    return (0x4E00 <= o <= 0x9FFF) or (0x3400 <= o <= 0x4DBF)


def _infer_reply_lang_from_message(message: str) -> str:
    """根据用户消息推断回复语言：以中文为主则回中文，否则默认回英文。"""
    if not message or not message.strip():
        return "en"
    text = message.strip()
    cjk = sum(1 for c in text if _is_cjk(c))
    # 可视为“有意义的字”的字符数（字母 + CJK）
    letter_like = sum(1 for c in text if c.isalpha() or _is_cjk(c))
    if letter_like == 0:
        return "en"
    if cjk / letter_like >= 0.3:
        return "zh"
    return "en"


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
        # 优先用户资料中的语言偏好，其次请求头 Accept-Language，默认英文
        lang = None
        if self.user.language_preference and self.user.language_preference.strip():
            lang = self.user.language_preference.strip().lower()
        if not lang and self._accept_lang:
            lang = self._accept_lang
        if not lang:
            lang = "en"
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
        ok, reason = _check_daily_budget(self.user.id, lang)
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

        # ---- 3a. 离题 → 直接拒绝（按用户消息语言回：说英文则回英文） ----
        if intent == IntentType.OFF_TOPIC:
            reply_lang = _infer_reply_lang_from_message(user_message)
            reply = _OFF_TOPIC_RESPONSES.get(reply_lang, _OFF_TOPIC_RESPONSES["zh"])
            _record_usage(self.user.id, 0)
            await self._save_assistant_message(conversation_id, reply, "local", 0, 0)
            await self.db.commit()
            yield self._make_text_sse(reply)
            yield self._make_done_sse()
            return

        # ---- 3b. 转人工客服 → 检查在线状态 + 发射 SSE 事件 ----
        if intent == IntentType.TRANSFER_TO_CS:
            # 调用工具检查客服在线状态
            cs_result = await self.executor.execute("check_cs_availability", {})
            available = cs_result.get("available", False)
            online_count = cs_result.get("online_count", 0)

            # 发射 cs_available SSE 事件
            yield ServerSentEvent(
                data=json.dumps({
                    "available": available,
                    "online_count": online_count,
                    "contact_email": "support@link2ur.com",
                }, ensure_ascii=False),
                event="cs_available",
            )

            if available:
                reply = "有人工客服在线，点击下方按钮连接人工客服。" if lang == "zh" else "Human agents are online. Tap the button below to connect."
            else:
                reply = "暂无在线客服，请发送邮件至 support@link2ur.com 联系我们。" if lang == "zh" else "No agents are currently online. Please email support@link2ur.com for assistance."

            _record_usage(self.user.id, 0)
            await self._save_assistant_message(conversation_id, reply, "local_cs_check", 0, 0)
            await self.db.commit()
            yield self._make_text_sse(reply)
            yield self._make_done_sse()
            return

        # ---- 3c. FAQ → 从数据库取答案 + 缓存 ----
        if intent == IntentType.FAQ:
            cache_key = f"faq:{lang}:{user_message[:100]}"
            cached = _get_faq_cache(cache_key)
            if cached:
                reply = cached
            else:
                topic = _get_matched_faq_topic(user_message)
                reply = None
                if topic:
                    reply = await self.executor.get_faq_for_agent(topic, lang)
                if not reply:
                    reply = await self.executor.get_faq_by_message(user_message, lang)
                if not reply:
                    reply = _OFF_TOPIC_RESPONSES[lang]
                _set_faq_cache(cache_key, reply)
            _record_usage(self.user.id, 0)
            await self._save_assistant_message(conversation_id, reply, "local_faq", 0, 0)
            await self.db.commit()
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
        # 按用户当前消息语言决定回复语言，避免用户说英文却收到中文回复
        reply_lang = _infer_reply_lang_from_message(user_message)
        system_prompt = _build_system_prompt(self.user, reply_lang)

        full_response = ""
        all_tool_calls = []
        all_tool_results = []
        total_input_tokens = 0
        total_output_tokens = 0
        model_used = ""

        # 工具调用循环（最多 3 轮，限制 token 消耗）
        try:
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

                    # 如果 LLM 主动调用了 check_cs_availability，也发射 cs_available 事件
                    if block.name == "check_cs_availability":
                        yield ServerSentEvent(
                            data=json.dumps({
                                "available": result.get("available", False),
                                "online_count": result.get("online_count", 0),
                                "contact_email": "support@link2ur.com",
                            }, ensure_ascii=False),
                            event="cs_available",
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

        except Exception as e:
            logger.error(f"LLM call error for user {self.user.id}: {e}", exc_info=True)
            error_reply = "抱歉，AI 服务暂时不可用，请稍后重试。" if lang == "zh" else "Sorry, AI service is temporarily unavailable. Please try again later."
            if not full_response:
                full_response = error_reply
            yield ServerSentEvent(
                data=json.dumps({"error": error_reply}, ensure_ascii=False),
                event="error",
            )

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

        default_title = "New conversation" if self._get_lang() == "en" else "新对话"
        conversations = []
        for c in rows:
            conversations.append({
                "id": c.id,
                "title": c.title or default_title,
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

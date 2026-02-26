"""
AI Agent 核心调度器 — Pipeline 架构

成本控制策略：
1. 意图分类（关键词 → 本地处理 / Haiku 判别 → Sonnet 兜底）
2. 离题拒绝（不回答与平台无关的问题）
3. FAQ 缓存（Redis + 内存 fallback，避免重复 LLM 调用）
4. 每用户每日 token 预算 + 请求次数限制（Redis + 内存 fallback）
5. 严格的 max_output_tokens 限制回复长度
6. 历史轮数裁剪（只保留最近 N 轮）
7. 工具循环 input token 上限保护
8. 按意图选择工具子集（减少 ~1000 input tokens/次）
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
from app.services.ai_llm_client import LLMClient, LLMResponse
from app.services.ai_tool_registry import tool_registry
from app.services.ai_tools import ToolExecutor
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


# ==================== LLM 客户端（带健康检查 & 自动重建） ====================

_llm_client: LLMClient | None = None
_llm_client_created_at: float = 0.0
_LLM_CLIENT_MAX_AGE = 3600  # 1 小时自动重建


def get_llm_client() -> LLMClient:
    global _llm_client, _llm_client_created_at
    now = time.time()
    if _llm_client is None or (now - _llm_client_created_at > _LLM_CLIENT_MAX_AGE):
        _llm_client = LLMClient()
        _llm_client_created_at = now
        logger.info("LLM client (re)created")
    return _llm_client


def reset_llm_client():
    """API Key 更换或 provider 故障时手动重建"""
    global _llm_client
    _llm_client = None


# ==================== Redis-backed State (with in-memory fallback) ====================

def _get_redis():
    """获取 Redis 客户端，不可用时返回 None"""
    try:
        from app.redis_pool import get_client
        return get_client(decode_responses=True)
    except Exception:
        return None


class _StateBackend:
    """FAQ 缓存 + 每日预算 + 限流的统一后端，优先 Redis，自动降级到内存"""

    _FAQ_PREFIX = "ai:faq:"
    _BUDGET_PREFIX = "ai:budget:"
    _RATE_PREFIX = "ai:rate:"

    def __init__(self):
        self._mem_faq: dict[str, tuple[str, float]] = {}
        self._mem_faq_max = 500
        self._mem_budget: dict[str, dict] = {}
        self._mem_rate: dict[str, list[float]] = {}
        self._last_cleanup = 0.0

    # ── FAQ 缓存 ──

    def get_faq(self, key: str) -> str | None:
        r = _get_redis()
        if r:
            try:
                return r.get(f"{self._FAQ_PREFIX}{key}")
            except Exception:
                pass
        entry = self._mem_faq.get(key)
        if entry and entry[1] > time.time():
            return entry[0]
        if entry:
            del self._mem_faq[key]
        return None

    def set_faq(self, key: str, answer: str):
        ttl = Config.AI_FAQ_CACHE_TTL
        r = _get_redis()
        if r:
            try:
                r.setex(f"{self._FAQ_PREFIX}{key}", ttl, answer)
                return
            except Exception:
                pass
        if len(self._mem_faq) >= self._mem_faq_max:
            now = time.time()
            expired = [k for k, (_, ts) in self._mem_faq.items() if ts <= now]
            for k in expired:
                del self._mem_faq[k]
            if len(self._mem_faq) >= self._mem_faq_max:
                to_remove = list(self._mem_faq.keys())[:self._mem_faq_max // 5]
                for k in to_remove:
                    del self._mem_faq[k]
        self._mem_faq[key] = (answer, time.time() + ttl)

    # ── 每日预算 ──

    def _today(self) -> str:
        from datetime import datetime, timezone
        return datetime.now(timezone.utc).strftime("%Y-%m-%d")

    def check_daily_budget(self, user_id: str, lang: str = "en") -> tuple[bool, str]:
        msgs = _BUDGET_REASONS.get(lang, _BUDGET_REASONS["en"])
        today = self._today()

        r = _get_redis()
        if r:
            try:
                rkey = f"{self._BUDGET_PREFIX}{user_id}:{today}"
                raw = r.get(rkey)
                if raw:
                    usage = json.loads(raw)
                else:
                    usage = {"tokens": 0, "requests": 0}

                if usage["requests"] >= Config.AI_DAILY_REQUEST_LIMIT:
                    return False, msgs["requests"]
                if usage["tokens"] >= Config.AI_DAILY_TOKEN_BUDGET:
                    return False, msgs["tokens"]
                return True, ""
            except Exception:
                pass

        self._cleanup_mem_budget()
        usage = self._mem_budget.get(user_id)
        if not usage or usage.get("date") != today:
            self._mem_budget[user_id] = {"date": today, "tokens": 0, "requests": 0}
            return True, ""
        if usage["requests"] >= Config.AI_DAILY_REQUEST_LIMIT:
            return False, msgs["requests"]
        if usage["tokens"] >= Config.AI_DAILY_TOKEN_BUDGET:
            return False, msgs["tokens"]
        return True, ""

    def record_usage(self, user_id: str, tokens: int):
        today = self._today()

        r = _get_redis()
        if r:
            try:
                rkey = f"{self._BUDGET_PREFIX}{user_id}:{today}"
                raw = r.get(rkey)
                if raw:
                    usage = json.loads(raw)
                    usage["tokens"] += tokens
                    usage["requests"] += 1
                else:
                    usage = {"tokens": tokens, "requests": 1}
                r.setex(rkey, 86400, json.dumps(usage))
                return
            except Exception:
                pass

        usage = self._mem_budget.get(user_id)
        if not usage or usage.get("date") != today:
            self._mem_budget[user_id] = {"date": today, "tokens": tokens, "requests": 1}
        else:
            usage["tokens"] += tokens
            usage["requests"] += 1

    def _cleanup_mem_budget(self):
        now = time.time()
        if now - self._last_cleanup < 300:
            return
        self._last_cleanup = now
        today = self._today()
        stale = [uid for uid, v in self._mem_budget.items() if v.get("date") != today]
        for uid in stale:
            del self._mem_budget[uid]

    # ── 限流 ──

    def check_rate_limit(self, user_id: str) -> bool:
        r = _get_redis()
        if r:
            try:
                rkey = f"{self._RATE_PREFIX}{user_id}"
                count = r.incr(rkey)
                if count == 1:
                    r.expire(rkey, 60)
                return count <= Config.AI_RATE_LIMIT_RPM
            except Exception:
                pass

        now = time.time()
        cutoff = now - 60
        timestamps = self._mem_rate.get(user_id, [])
        timestamps = [t for t in timestamps if t > cutoff]
        if len(timestamps) >= Config.AI_RATE_LIMIT_RPM:
            return False
        timestamps.append(now)
        self._mem_rate[user_id] = timestamps
        return True


_state = _StateBackend()

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


# ==================== 意图分类 ====================

class IntentType:
    FAQ = "faq"
    TASK_QUERY = "task"
    PROFILE = "profile"
    COMPLEX = "complex"
    OFF_TOPIC = "off_topic"
    UNKNOWN = "unknown"
    TRANSFER_TO_CS = "transfer_to_cs"
    ACTIVITY_QUERY = "activity_query"
    POINTS_QUERY = "points_query"


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

_TASK_KEYWORDS = ["任务", "task", "我的任务", "my task", "进行中", "已完成", "查看任务",
                  "搜索任务", "search task", "find task", "任务详情", "task detail",
                  "状态", "status", "订单", "order",
                  "发布任务", "发任务", "帮我发", "post task", "create task", "publish task",
                  "帮我找人", "帮我请人", "需要帮忙", "need help",
                  "想找人帮", "找人帮忙", "hire someone", "找人做"]

_PROFILE_KEYWORDS = ["个人资料", "我的资料", "my profile", "评分", "rating", "等级", "level",
                     "统计", "stats", "我的信息"]

_TRANSFER_CS_KEYWORDS = [
    "转人工", "人工客服", "真人客服", "找客服", "联系客服",
    "connect human", "talk to agent", "human agent", "real person",
    "speak to someone", "customer service", "live agent", "live chat",
    "transfer to human", "real agent",
]

# 快捷路径：仅调工具 + 固定话术，不经过 LLM
_ACTIVITY_QUERY_KEYWORDS = [
    "有什么活动", "最近活动", "哪些活动", "进行中的活动", "正在进行的活动",
    "current activities", "活动列表", "list activities", "最近有什么活动",
]
_POINTS_QUERY_KEYWORDS = [
    "我的积分", "积分余额", "几张券", "我的优惠券", "可用优惠券", "有没有券",
    "my points", "points balance", "how many coupons", "积分多少", "有多少积分",
]

_PERSONAL_DATA_KEYWORDS = [
    # 积分 & 优惠券
    "我的积分", "my points", "积分余额", "points balance", "几张券",
    "我的优惠券", "my coupon", "可用优惠券", "有没有券",
    # 通知
    "我的通知", "未读通知", "unread notification", "几条未读", "未读消息",
    # 帖子
    "我的帖子", "my post", "我发过", "我发的帖",
    # 活动 & 平台
    "有什么活动", "最近活动", "current activities", "哪些活动",
    "有没有二手", "搜索跳蚤", "search flea", "二手市场",
    "排行榜", "榜单", "leaderboard", "谁排第一",
    "有哪些达人", "推荐达人", "哪个达人", "达人列表",
    # 钱包 & 余额
    "我的余额", "my balance", "钱包", "wallet", "余额多少",
    "收入", "income", "赚了多少", "earnings", "支付记录", "payment history",
    "提现", "payout", "到账", "收款",
    # 私聊消息
    "谁给我发消息", "who messaged me", "未读消息数", "unread messages",
    "最近聊天", "recent chats", "私聊", "private message",
    # VIP
    "我是vip吗", "am i vip", "vip状态", "vip status", "会员到期", "membership expire",
    "vip什么时候到期", "vip expiry",
    # 学生认证
    "认证状态", "verification status", "我的认证", "my verification",
    "认证过期", "verification expire", "认证到期",
    # 签到
    "签到了吗", "checked in", "今天签到", "today checkin", "连续签到",
    "consecutive checkin", "签到奖励", "checkin reward", "签到天数",
    # 跳蚤市场个人
    "我卖的", "my listings", "我的商品", "my items for sale",
    "收藏的商品", "favorited items", "购买记录", "purchase history",
    "我买的", "what i bought",
    # 论坛个人
    "搜帖子", "search posts", "热帖", "hot posts", "热门帖子",
    "我收藏的帖子", "my favorite posts", "我的回复", "my replies",
]

_CONFIRMATION_WORDS = {
    # Chinese confirmations
    "满意", "好", "嗯", "是", "对", "可以", "确认", "同意",
    "不", "算了", "取消", "不对", "修改", "再改改", "不满意", "有问题",
    "好的", "好啊", "没问题", "行", "行的", "知道了", "收到",
    # English confirmations
    "ok", "yes", "no", "sure", "fine", "good", "great", "thanks",
    "cancel", "stop", "change", "edit", "update", "confirm",
}


def classify_intent(message: str) -> str:
    msg_lower = message.lower().strip()
    if not msg_lower:
        return IntentType.OFF_TOPIC
    if msg_lower in _CONFIRMATION_WORDS:
        return IntentType.UNKNOWN
    if _OFF_TOPIC_RE.search(msg_lower):
        return IntentType.OFF_TOPIC
    if any(kw in msg_lower for kw in _TRANSFER_CS_KEYWORDS):
        return IntentType.TRANSFER_TO_CS
    if any(kw in msg_lower for kw in _ACTIVITY_QUERY_KEYWORDS):
        return IntentType.ACTIVITY_QUERY
    if any(kw in msg_lower for kw in _POINTS_QUERY_KEYWORDS):
        return IntentType.POINTS_QUERY
    if any(kw in msg_lower for kw in _PERSONAL_DATA_KEYWORDS):
        return IntentType.UNKNOWN
    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            return IntentType.FAQ
    if any(kw in msg_lower for kw in _TASK_KEYWORDS):
        return IntentType.TASK_QUERY
    if any(kw in msg_lower for kw in _PROFILE_KEYWORDS):
        return IntentType.PROFILE

    platform_words = ["link2ur", "平台", "platform", "帮助", "help", "使用", "怎么用",
                      "how to", "功能", "feature", "钱包", "wallet", "积分", "points",
                      "优惠券", "coupon", "活动", "activity", "达人", "expert",
                      "论坛", "forum", "跳蚤", "flea", "认证", "verify",
                      "排行", "leaderboard", "通知", "notification", "消息", "message"]
    if any(w in msg_lower for w in platform_words):
        return IntentType.UNKNOWN

    return IntentType.UNKNOWN


_FAQ_KEY_TO_TOPIC = {
    "faq_about": "about", "faq_publish": "publish", "faq_accept": "accept",
    "faq_payment": "payment", "faq_fee": "fee", "faq_dispute": "dispute",
    "faq_account": "account", "faq_wallet": "wallet", "faq_cancel": "cancel",
    "faq_report": "report", "faq_privacy": "privacy", "faq_flea": "flea",
    "faq_forum": "forum", "faq_application": "application", "faq_review": "review",
    "faq_student": "student", "faq_expert": "expert", "faq_activity": "activity",
    "faq_coupon": "coupon", "faq_notification": "notification",
    "faq_message_support": "message_support", "faq_vip": "vip", "faq_linker": "linker",
}


def _get_matched_faq_topic(message: str) -> str | None:
    msg_lower = message.lower()
    for faq_key, keywords in _FAQ_KEYWORDS.items():
        if any(kw in msg_lower for kw in keywords):
            return _FAQ_KEY_TO_TOPIC.get(faq_key)
    return None


# ==================== System Prompt (config / DB) ====================

_DEFAULT_SYSTEM_PROMPT = """你是 Link2Ur 技能互助平台的官方 AI 客服助手。你只处理与 Link2Ur 平台相关的问题。

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
9. 查询钱包概况（积分余额、收款账户状态、支付记录）
10. 查看私聊消息摘要（未读消息数、最近联系人）
11. 查询 VIP 会员状态和到期时间
12. 查询学生认证状态和认证学校
13. 查看签到状态和奖励进度
14. 查询跳蚤市场我的商品、收藏和购买记录
15. 搜索论坛帖子、查看热帖、我的收藏和回复

【发布任务 — 草稿模式】
当用户要求帮忙发布任务时，使用 prepare_task_draft 工具生成草稿。
- 从用户的描述中提取标题、描述、类型、报酬、地点、截止时间
- 如果缺少必填信息（尤其是报酬金额），先询问用户
- 草稿生成后，告诉用户"已为您生成任务草稿，请点击下方按钮确认发布"
- 你不能直接创建任务，只能生成草稿供用户确认

【严格禁止 — 必须拒绝的请求】
- 任何与 Link2Ur 平台无关的问题（闲聊、写作文、编程、数学、翻译、新闻等）
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
- 风格：简洁专业，直接解决问题，不要寒暄"""

_db_prompt_cache: tuple[str | None, float] = (None, 0.0)
_DB_PROMPT_CACHE_TTL = 300  # 5 分钟


async def _get_system_prompt_template(db: AsyncSession) -> str:
    """根据配置获取 system prompt 模板。db 模式会缓存 5 分钟。"""
    global _db_prompt_cache

    if Config.AI_SYSTEM_PROMPT_SOURCE != "db":
        return _DEFAULT_SYSTEM_PROMPT

    cached_text, expire_ts = _db_prompt_cache
    if cached_text and time.time() < expire_ts:
        return cached_text

    try:
        q = select(models.AISystemPrompt).where(
            models.AISystemPrompt.is_active == True
        ).order_by(desc(models.AISystemPrompt.updated_at)).limit(1)
        row = (await db.execute(q)).scalar_one_or_none()
        if row and row.content:
            _db_prompt_cache = (row.content, time.time() + _DB_PROMPT_CACHE_TTL)
            return row.content
    except Exception as e:
        logger.warning("Failed to load system prompt from DB, using default: %s", e)

    return _DEFAULT_SYSTEM_PROMPT


def _build_system_prompt(template: str, user: models.User, resolved_lang: str | None = None) -> str:
    lang = resolved_lang
    if not lang and user.language_preference and user.language_preference.strip():
        lang = user.language_preference.strip().lower()
    if not lang:
        lang = "en"
    lang = "en" if lang.startswith("en") else "zh"
    lang_instruction = "Reply in English" if lang == "en" else "用中文回复"

    return template.format(
        user_name=user.name,
        user_id=user.id,
        lang=lang,
        user_level=user.user_level or "normal",
        lang_instruction=lang_instruction,
    )


# ==================== 离题拒绝消息 & 语言推断 ====================

_OFF_TOPIC_RESPONSES = {
    "zh": "抱歉，我只能回答 Link2Ur 平台相关的问题。如需帮助请描述您在平台上遇到的具体问题，例如任务查询、支付流程、费用说明等。",
    "en": "Sorry, I can only answer questions related to the Link2Ur platform. Please describe your specific platform question, such as task queries, payment process, or fee details.",
}


def _is_cjk(c: str) -> bool:
    o = ord(c)
    return (0x4E00 <= o <= 0x9FFF) or (0x3400 <= o <= 0x4DBF)


def _infer_reply_lang_from_message(message: str) -> str:
    if not message or not message.strip():
        return "en"
    text = message.strip()
    cjk = sum(1 for c in text if _is_cjk(c))
    letter_like = sum(1 for c in text if c.isalpha() or _is_cjk(c))
    if letter_like == 0:
        return "en"
    if cjk / letter_like >= 0.3:
        return "zh"
    return "en"


# ==================== Pipeline Steps ====================

class _PipelineContext:
    """在 pipeline 各步骤之间传递的上下文"""
    __slots__ = (
        "db", "user", "conversation_id", "user_message", "lang",
        "reply_lang", "intent", "accept_lang",
        "full_response", "all_tool_calls", "all_tool_results",
        "total_input_tokens", "total_output_tokens", "model_used",
        "terminated",
    )

    def __init__(self, db: AsyncSession, user: models.User,
                 conversation_id: str, user_message: str,
                 accept_lang: str | None = None):
        self.db = db
        self.user = user
        self.conversation_id = conversation_id
        self.user_message = user_message
        self.accept_lang = accept_lang

        pref = (user.language_preference or "").strip().lower()
        if pref:
            self.lang = "en" if pref.startswith("en") else "zh"
        elif accept_lang:
            self.lang = accept_lang
        else:
            self.lang = "en"

        self.reply_lang = _infer_reply_lang_from_message(user_message)
        self.intent = ""
        self.full_response = ""
        self.all_tool_calls: list[dict] = []
        self.all_tool_results: list[dict] = []
        self.total_input_tokens = 0
        self.total_output_tokens = 0
        self.model_used = ""
        self.terminated = False


async def _step_budget_check(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    ok, reason = _state.check_daily_budget(ctx.user.id, ctx.lang)
    if not ok:
        yield _make_text_sse(reason)
        yield _make_done_sse()
        ctx.terminated = True


async def _step_save_user_message(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    msg = models.AIMessage(conversation_id=ctx.conversation_id, role="user", content=ctx.user_message)
    ctx.db.add(msg)
    await ctx.db.flush()
    return
    yield  # make this a generator


async def _step_intent_classify(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    ctx.intent = classify_intent(ctx.user_message)
    logger.info("AI intent: %s for user %s: %s", ctx.intent, ctx.user.id, ctx.user_message[:50])
    return
    yield


async def _step_off_topic(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    if ctx.intent != IntentType.OFF_TOPIC:
        return
    reply = _OFF_TOPIC_RESPONSES.get(ctx.reply_lang, _OFF_TOPIC_RESPONSES["en"])
    _state.record_usage(ctx.user.id, 0)
    await _save_assistant_message(ctx, reply, "local", 0, 0)
    await ctx.db.commit()
    yield _make_text_sse(reply)
    yield _make_done_sse()
    ctx.terminated = True


async def _step_transfer_cs(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    if ctx.intent != IntentType.TRANSFER_TO_CS:
        return

    executor = ToolExecutor(ctx.db, ctx.user)
    cs_result = await executor.execute("check_cs_availability", {}, request_lang=ctx.lang)
    available = cs_result.get("available", False)
    online_count = cs_result.get("online_count", 0)

    yield ServerSentEvent(
        data=json.dumps({"available": available, "online_count": online_count,
                         "contact_email": "support@link2ur.com"}, ensure_ascii=False),
        event="cs_available",
    )

    if available:
        reply = "有人工客服在线，点击下方按钮连接人工客服。" if ctx.lang == "zh" else "Human agents are online. Tap the button below to connect."
    else:
        reply = "暂无在线客服，请发送邮件至 support@link2ur.com 联系我们。" if ctx.lang == "zh" else "No agents are currently online. Please email support@link2ur.com for assistance."

    _state.record_usage(ctx.user.id, 0)
    await _save_assistant_message(ctx, reply, "local_cs_check", 0, 0)
    await ctx.db.commit()
    yield _make_text_sse(reply)
    yield _make_done_sse()
    ctx.terminated = True


async def _step_faq(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    if ctx.intent != IntentType.FAQ:
        return

    cache_key = f"{ctx.lang}:{ctx.user_message[:100]}"
    cached = _state.get_faq(cache_key)
    if cached:
        reply = cached
    else:
        executor = ToolExecutor(ctx.db, ctx.user)
        topic = _get_matched_faq_topic(ctx.user_message)
        reply = None
        if topic:
            reply = await executor.get_faq_for_agent(topic, ctx.lang)
        if not reply:
            reply = await executor.get_faq_by_message(ctx.user_message, ctx.lang)
        if not reply:
            reply = _OFF_TOPIC_RESPONSES[ctx.lang]
        _state.set_faq(cache_key, reply)

    _state.record_usage(ctx.user.id, 0)
    await _save_assistant_message(ctx, reply, "local_faq", 0, 0)
    await ctx.db.commit()
    yield _make_text_sse(reply)
    yield _make_done_sse()
    ctx.terminated = True


async def _step_activity(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    """活动查询快捷路径：直接调 list_activities，无 LLM"""
    if ctx.intent != IntentType.ACTIVITY_QUERY:
        return

    executor = ToolExecutor(ctx.db, ctx.user)
    result = await executor.execute("list_activities", {}, request_lang=ctx.reply_lang)
    activities = result.get("activities") or []
    count = result.get("count", 0)

    if count == 0:
        if ctx.lang == "zh":
            reply = "平台目前没有进行中的公开活动。你可以：查看我的活动、排行榜、论坛获取更多信息。需要我帮你查看哪一项？"
        else:
            reply = "There are no ongoing public activities at the moment. You can check My Activities, Leaderboard, or Forum for more. Need help with any of these?"
    else:
        lines = [a.get("title") or str(a.get("id", "")) for a in activities[:5]]
        if ctx.lang == "zh":
            reply = f"当前有 {count} 个进行中的活动：\n" + "\n".join(f"- {t}" for t in lines)
            if count > 5:
                reply += f"\n（共 {count} 个，仅展示前 5 个。可在「活动」页查看全部。）"
        else:
            reply = f"There are {count} ongoing activities:\n" + "\n".join(f"- {t}" for t in lines)
            if count > 5:
                reply += f"\n(Showing first 5 of {count}. See Activities for full list.)"

    _state.record_usage(ctx.user.id, 0)
    await _save_assistant_message(ctx, reply, "local_activity", 0, 0)
    await ctx.db.commit()
    yield _make_text_sse(reply)
    yield _make_done_sse()
    ctx.terminated = True


async def _step_points(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    """积分/优惠券查询快捷路径：直接调 get_my_points_and_coupons，无 LLM"""
    if ctx.intent != IntentType.POINTS_QUERY:
        return

    executor = ToolExecutor(ctx.db, ctx.user)
    result = await executor.execute("get_my_points_and_coupons", {}, request_lang=ctx.reply_lang)
    points = result.get("points", 0)
    coupons = result.get("coupons") or []
    coupon_count = len(coupons)

    if ctx.lang == "zh":
        reply = f"当前积分：{points}，可用优惠券：{coupon_count} 张。"
        if coupon_count > 0:
            reply += " 在支付时可选择使用优惠券抵扣。"
    else:
        reply = f"Your points: {points}. Available coupons: {coupon_count}."
        if coupon_count > 0:
            reply += " You can apply coupons at checkout."

    _state.record_usage(ctx.user.id, 0)
    await _save_assistant_message(ctx, reply, "local_points", 0, 0)
    await ctx.db.commit()
    yield _make_text_sse(reply)
    yield _make_done_sse()
    ctx.terminated = True


async def _step_llm(ctx: _PipelineContext) -> AsyncIterator[ServerSentEvent]:
    """核心 LLM 调用 + 工具循环（带 token 上限保护）"""
    model_tier = "large" if ctx.intent == IntentType.COMPLEX else "small"

    history = await _load_history(ctx.db, ctx.conversation_id)
    messages = history + [{"role": "user", "content": ctx.user_message}]

    prompt_template = await _get_system_prompt_template(ctx.db)
    system_prompt = _build_system_prompt(prompt_template, ctx.user, ctx.reply_lang)

    # 按意图选择工具子集
    intent_for_tools = ctx.intent
    if intent_for_tools in (IntentType.TASK_QUERY,):
        intent_for_tools = "task"
    elif intent_for_tools in (IntentType.PROFILE,):
        intent_for_tools = "profile"
    elif intent_for_tools in (IntentType.COMPLEX,):
        intent_for_tools = "complex"
    else:
        intent_for_tools = "unknown"
    tools = tool_registry.get_tools_for_intent(intent_for_tools)

    llm = get_llm_client()
    executor = ToolExecutor(ctx.db, ctx.user)
    max_rounds = Config.AI_MAX_TOOL_ROUNDS
    max_loop_input_tokens = Config.AI_MAX_LOOP_INPUT_TOKENS

    try:
        for _round in range(max_rounds):
            # Token 上限保护
            if ctx.total_input_tokens >= max_loop_input_tokens:
                logger.warning("AI loop input token limit reached (%d/%d) for user %s",
                               ctx.total_input_tokens, max_loop_input_tokens, ctx.user.id)
                if not ctx.full_response:
                    fallback = "抱歉，处理过程中消耗了过多资源，请简化您的问题后重试。" if ctx.lang == "zh" \
                        else "Sorry, this request consumed too many resources. Please simplify and try again."
                    ctx.full_response = fallback
                    yield _make_text_sse(fallback)
                break

            response: LLMResponse | None = None
            async for kind, data in llm.chat_stream(
                messages=messages, system=system_prompt,
                tools=tools, model_tier=model_tier,
            ):
                if kind == "text_delta":
                    ctx.full_response += data
                    yield _make_text_sse(data)
                elif kind == "done":
                    response = data
                    break

            if response is None:
                break
            ctx.model_used = response.model
            ctx.total_input_tokens += response.usage.input_tokens
            ctx.total_output_tokens += response.usage.output_tokens

            tool_use_blocks = [b for b in response.content if b.type == "tool_use"]

            if not tool_use_blocks:
                break

            assistant_content = []
            for block in response.content:
                if block.type == "text":
                    assistant_content.append({"type": "text", "text": block.text})
                elif block.type == "tool_use":
                    assistant_content.append({
                        "type": "tool_use", "id": block.id,
                        "name": block.name, "input": block.input,
                    })
            messages.append({"role": "assistant", "content": assistant_content})

            tool_result_blocks = []
            for block in tool_use_blocks:
                yield ServerSentEvent(
                    data=json.dumps({"tool": block.name, "input": block.input}, ensure_ascii=False),
                    event="tool_call",
                )
                result = await executor.execute(block.name, block.input, request_lang=ctx.reply_lang)
                ctx.all_tool_calls.append({"id": block.id, "name": block.name, "input": block.input})
                ctx.all_tool_results.append({"tool_use_id": block.id, "result": result})

                yield ServerSentEvent(
                    data=json.dumps({"tool": block.name, "result": result}, ensure_ascii=False),
                    event="tool_result",
                )

                if block.name == "check_cs_availability":
                    yield ServerSentEvent(
                        data=json.dumps({
                            "available": result.get("available", False),
                            "online_count": result.get("online_count", 0),
                            "contact_email": "support@link2ur.com",
                        }, ensure_ascii=False),
                        event="cs_available",
                    )

                if block.name == "prepare_task_draft" and result.get("draft"):
                    yield ServerSentEvent(
                        data=json.dumps(result["draft"], ensure_ascii=False),
                        event="task_draft",
                    )

                tool_result_blocks.append({
                    "type": "tool_result", "tool_use_id": block.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

            messages.append({"role": "user", "content": tool_result_blocks})

            if _round == 0 and len(tool_use_blocks) >= 2:
                model_tier = "large"

    except Exception as e:
        logger.error("LLM call error for user %s: %s", ctx.user.id, e, exc_info=True)
        reset_llm_client()
        error_reply = "抱歉，AI 服务暂时不可用，请稍后重试。" if ctx.lang == "zh" \
            else "Sorry, AI service is temporarily unavailable. Please try again later."
        if not ctx.full_response:
            ctx.full_response = error_reply
        yield ServerSentEvent(
            data=json.dumps({"error": error_reply}, ensure_ascii=False),
            event="error",
        )

    # 保存 & 记录用量
    total_tokens = ctx.total_input_tokens + ctx.total_output_tokens
    _state.record_usage(ctx.user.id, total_tokens)

    await _save_assistant_message(
        ctx, ctx.full_response, ctx.model_used,
        ctx.total_input_tokens, ctx.total_output_tokens,
        ctx.all_tool_calls, ctx.all_tool_results,
    )

    conv_q = select(models.AIConversation).where(models.AIConversation.id == ctx.conversation_id)
    conv = (await ctx.db.execute(conv_q)).scalar_one_or_none()
    if conv:
        conv.total_tokens = (conv.total_tokens or 0) + total_tokens
        conv.model_used = ctx.model_used
        conv.updated_at = get_utc_time()
        if not conv.title and ctx.user_message:
            conv.title = ctx.user_message[:100]

    await ctx.db.commit()
    yield _make_done_sse(ctx.total_input_tokens, ctx.total_output_tokens)


# ==================== AI Agent ====================

# pipeline: 按顺序执行，任一步骤设置 ctx.terminated=True 则后续跳过
_PIPELINE = [
    _step_budget_check,
    _step_save_user_message,
    _step_intent_classify,
    _step_off_topic,
    _step_transfer_cs,
    _step_faq,
    _step_activity,
    _step_points,
    _step_llm,
]


class AIAgent:
    """AI Agent — pipeline 驱动"""

    def __init__(self, db: AsyncSession, user: models.User, *, accept_lang: str | None = None):
        self.db = db
        self.user = user
        self._accept_lang = accept_lang

    async def process_message_stream(
        self, conversation_id: str, user_message: str
    ) -> AsyncIterator[ServerSentEvent]:
        ctx = _PipelineContext(
            self.db, self.user, conversation_id, user_message,
            accept_lang=self._accept_lang,
        )

        for step in _PIPELINE:
            if ctx.terminated:
                break
            async for event in step(ctx):
                yield event

    # ==================== CRUD 方法 ====================

    async def create_conversation(self) -> models.AIConversation:
        conv = models.AIConversation(id=str(uuid.uuid4()), user_id=self.user.id)
        self.db.add(conv)
        await self.db.commit()
        await self.db.refresh(conv)
        return conv

    async def get_conversations(self, page: int = 1, page_size: int = 20) -> dict:
        conditions = [
            models.AIConversation.user_id == self.user.id,
            models.AIConversation.status == "active",
        ]
        total = (await self.db.execute(
            select(func.count()).select_from(models.AIConversation).where(and_(*conditions))
        )).scalar() or 0

        rows = (await self.db.execute(
            select(models.AIConversation).where(and_(*conditions))
            .order_by(desc(models.AIConversation.updated_at))
            .offset((page - 1) * page_size).limit(page_size)
        )).scalars().all()

        lang = self._get_lang()
        default_title = "New conversation" if lang == "en" else "新对话"
        conversations = [{
            "id": c.id,
            "title": c.title or default_title,
            "model_used": c.model_used,
            "total_tokens": c.total_tokens,
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "updated_at": c.updated_at.isoformat() if c.updated_at else None,
        } for c in rows]

        return {"conversations": conversations, "total": total, "page": page}

    async def get_conversation_messages(self, conversation_id: str) -> list[dict]:
        conv = (await self.db.execute(
            select(models.AIConversation).where(and_(
                models.AIConversation.id == conversation_id,
                models.AIConversation.user_id == self.user.id,
            ))
        )).scalar_one_or_none()
        if not conv:
            return []

        rows = (await self.db.execute(
            select(models.AIMessage)
            .where(models.AIMessage.conversation_id == conversation_id)
            .order_by(models.AIMessage.created_at)
        )).scalars().all()

        messages = []
        for msg in rows:
            m: dict = {
                "id": msg.id, "role": msg.role, "content": msg.content,
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
        conv = (await self.db.execute(
            select(models.AIConversation).where(and_(
                models.AIConversation.id == conversation_id,
                models.AIConversation.user_id == self.user.id,
            ))
        )).scalar_one_or_none()
        if not conv:
            return False
        conv.status = "archived"
        await self.db.commit()
        return True

    def _get_lang(self) -> str:
        lang = None
        if self.user.language_preference and self.user.language_preference.strip():
            lang = self.user.language_preference.strip().lower()
        if not lang and self._accept_lang:
            lang = self._accept_lang
        if not lang:
            lang = "en"
        return "en" if lang.startswith("en") else "zh"


# ==================== 辅助函数（模块级） ====================

async def _load_history(db: AsyncSession, conversation_id: str) -> list[dict]:
    max_turns = Config.AI_MAX_HISTORY_TURNS
    q = (
        select(models.AIMessage)
        .where(and_(
            models.AIMessage.conversation_id == conversation_id,
            models.AIMessage.role.in_(["user", "assistant"]),
        ))
        .order_by(desc(models.AIMessage.created_at))
        .limit(max_turns * 2)
    )
    rows = list(reversed((await db.execute(q)).scalars().all()))

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


async def _save_assistant_message(
    ctx: _PipelineContext, content: str, model_used: str,
    input_tokens: int, output_tokens: int,
    tool_calls: list | None = None, tool_results: list | None = None,
):
    msg = models.AIMessage(
        conversation_id=ctx.conversation_id,
        role="assistant",
        content=content,
        tool_calls=json.dumps(tool_calls, ensure_ascii=False) if tool_calls else None,
        tool_results=json.dumps(tool_results, ensure_ascii=False) if tool_results else None,
        model_used=model_used,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
    )
    ctx.db.add(msg)


def _make_text_sse(text: str) -> ServerSentEvent:
    return ServerSentEvent(
        data=json.dumps({"content": text}, ensure_ascii=False),
        event="token",
    )


def _make_done_sse(input_tokens: int = 0, output_tokens: int = 0) -> ServerSentEvent:
    return ServerSentEvent(
        data=json.dumps({"input_tokens": input_tokens, "output_tokens": output_tokens}),
        event="done",
    )

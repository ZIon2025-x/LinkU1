"""
Seed data for sensitive words and homophone mappings.

Run once on first deployment to populate the database with initial data.
Subsequent updates should be done via the admin API.
"""
import logging
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SensitiveWord, HomophoneMapping

logger = logging.getLogger(__name__)


# ── Initial Sensitive Words ──────────────────────────────────────────────
# Categories: ad, scam, agent, porn, drugs, gambling, violence, illegal, profanity, contact
# Levels: "mask" for contact info, "review" for everything else

INITIAL_WORDS = [
    # ── 广告/推广 (ad) ──
    {"word": "代购", "category": "ad", "level": "review"},
    {"word": "刷单", "category": "ad", "level": "review"},
    {"word": "日赚", "category": "ad", "level": "review"},
    {"word": "月入过万", "category": "ad", "level": "review"},
    {"word": "免费领取", "category": "ad", "level": "review"},
    {"word": "兼职日结", "category": "ad", "level": "review"},
    {"word": "招代理", "category": "ad", "level": "review"},
    {"word": "诚招", "category": "ad", "level": "review"},
    {"word": "推广赚钱", "category": "ad", "level": "review"},
    {"word": "优惠券群", "category": "ad", "level": "review"},

    # ── 中介 (agent) ──
    {"word": "中介费", "category": "agent", "level": "review"},
    {"word": "代办", "category": "agent", "level": "review"},
    {"word": "包过", "category": "agent", "level": "review"},
    {"word": "代写", "category": "agent", "level": "review"},
    {"word": "代考", "category": "agent", "level": "review"},
    {"word": "论文代写", "category": "agent", "level": "review"},

    # ── 诈骗 (scam) ──
    {"word": "杀猪盘", "category": "scam", "level": "review"},
    {"word": "投资理财", "category": "scam", "level": "review"},
    {"word": "稳赚不赔", "category": "scam", "level": "review"},
    {"word": "高回报", "category": "scam", "level": "review"},
    {"word": "保本", "category": "scam", "level": "review"},
    {"word": "翻倍", "category": "scam", "level": "review"},
    {"word": "内部消息", "category": "scam", "level": "review"},

    # ── 色情 (porn) ──
    {"word": "约炮", "category": "porn", "level": "review"},
    {"word": "一夜情", "category": "porn", "level": "review"},
    {"word": "援交", "category": "porn", "level": "review"},
    {"word": "裸聊", "category": "porn", "level": "review"},
    {"word": "色情", "category": "porn", "level": "review"},
    {"word": "黄片", "category": "porn", "level": "review"},
    {"word": "成人视频", "category": "porn", "level": "review"},

    # ── 毒品 (drugs) ──
    {"word": "冰毒", "category": "drugs", "level": "review"},
    {"word": "大麻", "category": "drugs", "level": "review"},
    {"word": "海洛因", "category": "drugs", "level": "review"},
    {"word": "摇头丸", "category": "drugs", "level": "review"},
    {"word": "K粉", "category": "drugs", "level": "review"},
    {"word": "吸毒", "category": "drugs", "level": "review"},
    {"word": "贩毒", "category": "drugs", "level": "review"},

    # ── 赌博 (gambling) ──
    {"word": "赌博", "category": "gambling", "level": "review"},
    {"word": "网赌", "category": "gambling", "level": "review"},
    {"word": "赌场", "category": "gambling", "level": "review"},
    {"word": "博彩", "category": "gambling", "level": "review"},
    {"word": "百家乐", "category": "gambling", "level": "review"},
    {"word": "老虎机", "category": "gambling", "level": "review"},
    {"word": "六合彩", "category": "gambling", "level": "review"},

    # ── 暴力 (violence) ──
    {"word": "枪支", "category": "violence", "level": "review"},
    {"word": "炸弹", "category": "violence", "level": "review"},

    # ── 违法 (illegal) ──
    {"word": "假证", "category": "illegal", "level": "review"},
    {"word": "办证", "category": "illegal", "level": "review"},
    {"word": "洗钱", "category": "illegal", "level": "review"},
    {"word": "偷税", "category": "illegal", "level": "review"},
    {"word": "走私", "category": "illegal", "level": "review"},
    {"word": "假币", "category": "illegal", "level": "review"},

    # ── 脏话 (profanity) ──
    {"word": "他妈的", "category": "profanity", "level": "review"},
    {"word": "操你妈", "category": "profanity", "level": "review"},
    {"word": "傻逼", "category": "profanity", "level": "review"},
    {"word": "脑残", "category": "profanity", "level": "review"},
    {"word": "去死", "category": "profanity", "level": "review"},

    # ── 联系方式 (contact) — level=mask ──
    {"word": "微信", "category": "contact", "level": "mask"},
    {"word": "QQ", "category": "contact", "level": "mask"},
    {"word": "加我", "category": "contact", "level": "mask"},
    {"word": "私聊", "category": "contact", "level": "mask"},
]


# ── Initial Homophone Mappings ──────────────────────────────────────────
# variant -> standard (the standard form that the keyword matcher checks)

INITIAL_HOMOPHONES = [
    # 微信变体
    {"variant": "威信", "standard": "微信"},
    {"variant": "薇芯", "standard": "微信"},
    {"variant": "微芯", "standard": "微信"},
    {"variant": "VX", "standard": "微信"},
    {"variant": "vx", "standard": "微信"},
    {"variant": "V信", "standard": "微信"},
    {"variant": "v信", "standard": "微信"},

    # QQ变体
    {"variant": "扣扣", "standard": "QQ"},
    {"variant": "球球", "standard": "QQ"},
    {"variant": "Q扣", "standard": "QQ"},

    # 赌博变体
    {"variant": "堵博", "standard": "赌博"},
    {"variant": "赌搏", "standard": "赌博"},
    {"variant": "dubo", "standard": "赌博"},

    # 色情变体
    {"variant": "涩情", "standard": "色情"},
    {"variant": "瑟情", "standard": "色情"},
    {"variant": "seqing", "standard": "色情"},

    # 黄片变体
    {"variant": "荒片", "standard": "黄片"},
    {"variant": "皇片", "standard": "黄片"},

    # 兼职变体
    {"variant": "坚直", "standard": "兼职"},
    {"variant": "兼只", "standard": "兼职"},
    {"variant": "jianzhi", "standard": "兼职"},
]


async def seed_sensitive_words(db: AsyncSession) -> None:
    """
    Seed the sensitive_words and homophone_mappings tables if they are empty.

    Safe to call on every startup -- only inserts when tables have zero rows.
    """
    # Check if sensitive_words table already has data
    word_count_result = await db.execute(
        select(func.count()).select_from(SensitiveWord)
    )
    word_count = word_count_result.scalar()

    if word_count == 0:
        logger.info(f"Seeding {len(INITIAL_WORDS)} sensitive words...")
        for entry in INITIAL_WORDS:
            db.add(SensitiveWord(
                word=entry["word"],
                category=entry["category"],
                level=entry["level"],
                is_active=True,
            ))
        await db.flush()
        logger.info("Sensitive words seeded successfully.")
    else:
        logger.info(f"Sensitive words table already has {word_count} entries, skipping seed.")

    # Check if homophone_mappings table already has data
    homo_count_result = await db.execute(
        select(func.count()).select_from(HomophoneMapping)
    )
    homo_count = homo_count_result.scalar()

    if homo_count == 0:
        logger.info(f"Seeding {len(INITIAL_HOMOPHONES)} homophone mappings...")
        for entry in INITIAL_HOMOPHONES:
            db.add(HomophoneMapping(
                variant=entry["variant"],
                standard=entry["standard"],
                is_active=True,
            ))
        await db.flush()
        logger.info("Homophone mappings seeded successfully.")
    else:
        logger.info(f"Homophone mappings table already has {homo_count} entries, skipping seed.")

    await db.commit()

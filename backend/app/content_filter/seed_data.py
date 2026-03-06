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
    {"word": "日入千元", "category": "ad", "level": "review"},
    {"word": "躺赚", "category": "ad", "level": "review"},
    {"word": "零投资", "category": "ad", "level": "review"},
    {"word": "不需要本金", "category": "ad", "level": "review"},
    {"word": "在家赚钱", "category": "ad", "level": "review"},
    {"word": "轻松月入", "category": "ad", "level": "review"},
    {"word": "招聘打字员", "category": "ad", "level": "review"},
    {"word": "手机兼职", "category": "ad", "level": "review"},

    # ── 中介 (agent) ──
    {"word": "中介费", "category": "agent", "level": "review"},
    {"word": "代办", "category": "agent", "level": "review"},
    {"word": "包过", "category": "agent", "level": "review"},
    {"word": "代写", "category": "agent", "level": "review"},
    {"word": "代考", "category": "agent", "level": "review"},
    {"word": "论文代写", "category": "agent", "level": "review"},
    {"word": "代做作业", "category": "agent", "level": "review"},
    {"word": "包通过", "category": "agent", "level": "review"},
    {"word": "代挂", "category": "agent", "level": "review"},
    {"word": "买卖账号", "category": "agent", "level": "review"},
    {"word": "代刷", "category": "agent", "level": "review"},

    # ── 诈骗 (scam) ──
    {"word": "杀猪盘", "category": "scam", "level": "review"},
    {"word": "投资理财", "category": "scam", "level": "review"},
    {"word": "稳赚不赔", "category": "scam", "level": "review"},
    {"word": "高回报", "category": "scam", "level": "review"},
    {"word": "保本", "category": "scam", "level": "review"},
    {"word": "翻倍", "category": "scam", "level": "review"},
    {"word": "内部消息", "category": "scam", "level": "review"},
    {"word": "日化收益", "category": "scam", "level": "review"},
    {"word": "保证收益", "category": "scam", "level": "review"},
    {"word": "零风险", "category": "scam", "level": "review"},
    {"word": "资金盘", "category": "scam", "level": "review"},
    {"word": "传销", "category": "scam", "level": "review"},
    {"word": "庞氏骗局", "category": "scam", "level": "review"},
    {"word": "拉人头", "category": "scam", "level": "review"},
    {"word": "发展下线", "category": "scam", "level": "review"},
    {"word": "虚拟货币投资", "category": "scam", "level": "review"},
    {"word": "外汇操盘", "category": "scam", "level": "review"},
    {"word": "跑分", "category": "scam", "level": "review"},
    {"word": "刷流水", "category": "scam", "level": "review"},
    {"word": "洗白", "category": "scam", "level": "review"},

    # ── 色情 (porn) ──
    {"word": "约炮", "category": "porn", "level": "review"},
    {"word": "一夜情", "category": "porn", "level": "review"},
    {"word": "援交", "category": "porn", "level": "review"},
    {"word": "裸聊", "category": "porn", "level": "review"},
    {"word": "色情", "category": "porn", "level": "review"},
    {"word": "黄片", "category": "porn", "level": "review"},
    {"word": "成人视频", "category": "porn", "level": "review"},
    {"word": "嫖娼", "category": "porn", "level": "review"},
    {"word": "卖淫", "category": "porn", "level": "review"},
    {"word": "招嫖", "category": "porn", "level": "review"},
    {"word": "包夜", "category": "porn", "level": "review"},
    {"word": "小姐服务", "category": "porn", "level": "review"},
    {"word": "上门服务", "category": "porn", "level": "review"},
    {"word": "特殊服务", "category": "porn", "level": "review"},
    {"word": "全套服务", "category": "porn", "level": "review"},
    {"word": "陪睡", "category": "porn", "level": "review"},
    {"word": "色诱", "category": "porn", "level": "review"},
    {"word": "AV", "category": "porn", "level": "review"},
    {"word": "成人网站", "category": "porn", "level": "review"},
    {"word": "裸照", "category": "porn", "level": "review"},
    {"word": "自慰", "category": "porn", "level": "review"},
    {"word": "性交易", "category": "porn", "level": "review"},
    {"word": "约会交友", "category": "porn", "level": "review"},
    {"word": "同城约", "category": "porn", "level": "review"},

    # ── 毒品 (drugs) ──
    {"word": "毒品", "category": "drugs", "level": "review"},
    {"word": "冰毒", "category": "drugs", "level": "review"},
    {"word": "大麻", "category": "drugs", "level": "review"},
    {"word": "海洛因", "category": "drugs", "level": "review"},
    {"word": "摇头丸", "category": "drugs", "level": "review"},
    {"word": "K粉", "category": "drugs", "level": "review"},
    {"word": "吸毒", "category": "drugs", "level": "review"},
    {"word": "贩毒", "category": "drugs", "level": "review"},
    {"word": "制毒", "category": "drugs", "level": "review"},
    {"word": "禁药", "category": "drugs", "level": "review"},
    {"word": "麻醉品", "category": "drugs", "level": "review"},
    {"word": "可卡因", "category": "drugs", "level": "review"},
    {"word": "鸦片", "category": "drugs", "level": "review"},
    {"word": "安非他命", "category": "drugs", "level": "review"},
    {"word": "致幻剂", "category": "drugs", "level": "review"},
    {"word": "迷幻药", "category": "drugs", "level": "review"},
    {"word": "迷药", "category": "drugs", "level": "review"},
    {"word": "迷魂药", "category": "drugs", "level": "review"},
    {"word": "听话水", "category": "drugs", "level": "review"},
    {"word": "春药", "category": "drugs", "level": "review"},
    {"word": "催情药", "category": "drugs", "level": "review"},
    {"word": "麻古", "category": "drugs", "level": "review"},
    {"word": "神仙水", "category": "drugs", "level": "review"},
    {"word": "笑气", "category": "drugs", "level": "review"},
    {"word": "芬太尼", "category": "drugs", "level": "review"},
    {"word": "LSD", "category": "drugs", "level": "review"},
    {"word": "冰壶", "category": "drugs", "level": "review"},
    {"word": "溜冰", "category": "drugs", "level": "review"},
    {"word": "打飞机针", "category": "drugs", "level": "review"},
    {"word": "嗑药", "category": "drugs", "level": "review"},
    {"word": "飞叶子", "category": "drugs", "level": "review"},
    {"word": "上头", "category": "drugs", "level": "review"},

    # ── 赌博 (gambling) ──
    {"word": "赌博", "category": "gambling", "level": "review"},
    {"word": "网赌", "category": "gambling", "level": "review"},
    {"word": "赌场", "category": "gambling", "level": "review"},
    {"word": "博彩", "category": "gambling", "level": "review"},
    {"word": "百家乐", "category": "gambling", "level": "review"},
    {"word": "老虎机", "category": "gambling", "level": "review"},
    {"word": "六合彩", "category": "gambling", "level": "review"},
    {"word": "赌球", "category": "gambling", "level": "review"},
    {"word": "赌马", "category": "gambling", "level": "review"},
    {"word": "地下赌场", "category": "gambling", "level": "review"},
    {"word": "赌注", "category": "gambling", "level": "review"},
    {"word": "下注", "category": "gambling", "level": "review"},
    {"word": "彩票预测", "category": "gambling", "level": "review"},
    {"word": "时时彩", "category": "gambling", "level": "review"},
    {"word": "北京赛车", "category": "gambling", "level": "review"},
    {"word": "幸运飞艇", "category": "gambling", "level": "review"},
    {"word": "竞猜", "category": "gambling", "level": "review"},
    {"word": "押注", "category": "gambling", "level": "review"},
    {"word": "赔率", "category": "gambling", "level": "review"},
    {"word": "庄家", "category": "gambling", "level": "review"},
    {"word": "外围", "category": "gambling", "level": "review"},
    {"word": "赌资", "category": "gambling", "level": "review"},

    # ── 暴力 (violence) ──
    {"word": "枪支", "category": "violence", "level": "review"},
    {"word": "炸弹", "category": "violence", "level": "review"},
    {"word": "杀人", "category": "violence", "level": "review"},
    {"word": "砍人", "category": "violence", "level": "review"},
    {"word": "买枪", "category": "violence", "level": "review"},
    {"word": "卖枪", "category": "violence", "level": "review"},
    {"word": "炸药", "category": "violence", "level": "review"},
    {"word": "雷管", "category": "violence", "level": "review"},
    {"word": "弹药", "category": "violence", "level": "review"},
    {"word": "管制刀具", "category": "violence", "level": "review"},
    {"word": "自杀", "category": "violence", "level": "review"},
    {"word": "跳楼", "category": "violence", "level": "review"},
    {"word": "割腕", "category": "violence", "level": "review"},
    {"word": "雇凶", "category": "violence", "level": "review"},
    {"word": "报仇", "category": "violence", "level": "review"},
    {"word": "寻仇", "category": "violence", "level": "review"},
    {"word": "恐怖袭击", "category": "violence", "level": "review"},
    {"word": "人肉搜索", "category": "violence", "level": "review"},

    # ── 违法 (illegal) ──
    {"word": "假证", "category": "illegal", "level": "review"},
    {"word": "办证", "category": "illegal", "level": "review"},
    {"word": "洗钱", "category": "illegal", "level": "review"},
    {"word": "偷税", "category": "illegal", "level": "review"},
    {"word": "走私", "category": "illegal", "level": "review"},
    {"word": "假币", "category": "illegal", "level": "review"},
    {"word": "逃税", "category": "illegal", "level": "review"},
    {"word": "行贿", "category": "illegal", "level": "review"},
    {"word": "受贿", "category": "illegal", "level": "review"},
    {"word": "贪污", "category": "illegal", "level": "review"},
    {"word": "诈骗", "category": "illegal", "level": "review"},
    {"word": "盗窃", "category": "illegal", "level": "review"},
    {"word": "抢劫", "category": "illegal", "level": "review"},
    {"word": "绑架", "category": "illegal", "level": "review"},
    {"word": "勒索", "category": "illegal", "level": "review"},
    {"word": "敲诈", "category": "illegal", "level": "review"},
    {"word": "偷渡", "category": "illegal", "level": "review"},
    {"word": "黑户", "category": "illegal", "level": "review"},
    {"word": "假护照", "category": "illegal", "level": "review"},
    {"word": "假签证", "category": "illegal", "level": "review"},
    {"word": "买卖器官", "category": "illegal", "level": "review"},
    {"word": "非法集资", "category": "illegal", "level": "review"},
    {"word": "高利贷", "category": "illegal", "level": "review"},
    {"word": "套路贷", "category": "illegal", "level": "review"},
    {"word": "裸贷", "category": "illegal", "level": "review"},
    {"word": "黑客", "category": "illegal", "level": "review"},
    {"word": "破解软件", "category": "illegal", "level": "review"},
    {"word": "盗号", "category": "illegal", "level": "review"},
    {"word": "钓鱼网站", "category": "illegal", "level": "review"},
    {"word": "信用卡套现", "category": "illegal", "level": "review"},
    {"word": "代开发票", "category": "illegal", "level": "review"},

    # ── 脏话 (profanity) ──
    {"word": "他妈的", "category": "profanity", "level": "review"},
    {"word": "操你妈", "category": "profanity", "level": "review"},
    {"word": "傻逼", "category": "profanity", "level": "review"},
    {"word": "脑残", "category": "profanity", "level": "review"},
    {"word": "去死", "category": "profanity", "level": "review"},
    {"word": "草泥马", "category": "profanity", "level": "review"},
    {"word": "妈逼", "category": "profanity", "level": "review"},
    {"word": "贱人", "category": "profanity", "level": "review"},
    {"word": "婊子", "category": "profanity", "level": "review"},
    {"word": "狗日的", "category": "profanity", "level": "review"},
    {"word": "王八蛋", "category": "profanity", "level": "review"},
    {"word": "滚蛋", "category": "profanity", "level": "review"},
    {"word": "废物", "category": "profanity", "level": "review"},
    {"word": "死全家", "category": "profanity", "level": "review"},
    {"word": "你妈死了", "category": "profanity", "level": "review"},
    {"word": "智障", "category": "profanity", "level": "review"},
    {"word": "弱智", "category": "profanity", "level": "review"},

    # ── 联系方式 (contact) — level=mask ──
    {"word": "微信", "category": "contact", "level": "mask"},
    {"word": "QQ", "category": "contact", "level": "mask"},
    {"word": "加我", "category": "contact", "level": "mask"},
    {"word": "私聊", "category": "contact", "level": "mask"},
    {"word": "加好友", "category": "contact", "level": "mask"},
    {"word": "WhatsApp", "category": "contact", "level": "mask"},
    {"word": "Telegram", "category": "contact", "level": "mask"},
    {"word": "飞机群", "category": "contact", "level": "mask"},
    {"word": "电报群", "category": "contact", "level": "mask"},
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
    {"variant": "weixin", "standard": "微信"},
    {"variant": "wechat", "standard": "微信"},

    # QQ变体
    {"variant": "扣扣", "standard": "QQ"},
    {"variant": "球球", "standard": "QQ"},
    {"variant": "Q扣", "standard": "QQ"},
    {"variant": "qq", "standard": "QQ"},

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

    # 毒品变体
    {"variant": "du品", "standard": "毒品"},
    {"variant": "独品", "standard": "毒品"},
    {"variant": "毐品", "standard": "毒品"},

    # 大麻变体
    {"variant": "da麻", "standard": "大麻"},
    {"variant": "大ma", "standard": "大麻"},

    # 冰毒变体
    {"variant": "冰du", "standard": "冰毒"},
    {"variant": "兵毒", "standard": "冰毒"},

    # 传销变体
    {"variant": "串销", "standard": "传销"},
    {"variant": "chuanxiao", "standard": "传销"},

    # Telegram变体
    {"variant": "电报", "standard": "Telegram"},
    {"variant": "TG群", "standard": "Telegram"},
    {"variant": "tg群", "standard": "Telegram"},
    {"variant": "飞机", "standard": "Telegram"},
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

"""
统一时间处理工具模块
所有时间相关操作统一使用此模块

核心原则：
1. 存储与计算一律UTC（带时区）
2. 展示与解析只在入/出边界使用Europe/London
3. 禁止naive时间自动假设为UTC
4. 全局统一使用zoneinfo，禁止pytz
"""
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

# 时区常量
LONDON = ZoneInfo("Europe/London")

# ==================== 核心时间函数 ====================

def get_utc_time() -> datetime:
    """
    获取当前UTC时间（带时区信息）
    
    这是唯一的时间生成函数，所有新代码必须使用此函数
    
    Returns:
        datetime: 带时区的UTC时间对象
    """
    return datetime.now(timezone.utc)  # 唯一权威


def to_utc(dt: datetime) -> datetime:
    """
    将带时区的时间转换为UTC
    
    ⚠️ 不接受naive时间，必须显式提供时区信息
    
    Args:
        dt: 带时区的时间对象
    
    Returns:
        datetime: UTC时间对象（带时区）
    
    Raises:
        ValueError: 如果dt是naive时间
    """
    if dt.tzinfo is None:
        raise ValueError("Naive datetime is not allowed. Use parse_local_as_utc().")
    return dt.astimezone(timezone.utc)


def parse_local_as_utc(naive_local: datetime, tz: ZoneInfo = LONDON) -> datetime:
    """
    把本地墙钟时间解释为某时区，再转UTC
    
    用于旧数据迁移或用户输入解析
    对"不可达"或"歧义"时刻，显式拒绝/消歧
    
    Args:
        naive_local: 无时区的本地时间（墙钟时间）
        tz: 时区对象，默认为Europe/London
    
    Returns:
        datetime: UTC时间对象（带时区）
    
    Raises:
        ValueError: 如果naive_local已带时区或时间无效
    """
    if naive_local.tzinfo is not None:
        raise ValueError("Expect naive local time")
    
    # 对"不可达"或"歧义"时刻，显式拒绝/消歧（默认later）
    return handle_ambiguous_time(naive_local, tz, disambiguation="later")


def handle_ambiguous_time(
    naive_local: datetime,
    tz: ZoneInfo = LONDON,
    disambiguation: str = "later"
) -> datetime:
    """
    处理歧义时间（DST回拨时出现）
    
    spring-gap: raise ValueError
    fall-back: fold=0/1 消歧
    
    Args:
        naive_local: 本地时间（无时区）
        tz: 时区对象，默认为Europe/London
        disambiguation: 处理策略 ("earlier", "later", "reject")
    
    Returns:
        datetime: UTC时间对象
    
    Raises:
        ValueError: 如果时间无效（春前拨）或disambiguation="reject"且时间歧义
    """
    if naive_local.tzinfo is not None:
        raise ValueError("Expect naive local time")
    
    try:
        if disambiguation == "earlier":
            aware = naive_local.replace(tzinfo=tz, fold=0)
        elif disambiguation == "later":
            aware = naive_local.replace(tzinfo=tz, fold=1)
        else:  # reject
            a0 = naive_local.replace(tzinfo=tz, fold=0)
            a1 = naive_local.replace(tzinfo=tz, fold=1)
            if a0.utcoffset() != a1.utcoffset():
                raise ValueError("Ambiguous local time; choose earlier/later")
            aware = a0
    except Exception as e:
        raise ValueError("Invalid local time due to DST transition") from e
    
    return aware.astimezone(timezone.utc)


def to_user_timezone(dt_utc: datetime, tz: ZoneInfo = LONDON) -> datetime:
    """
    将UTC时间转换为用户时区（仅用于显示）
    
    Args:
        dt_utc: UTC时间对象（如果无时区，假设是UTC）
        tz: 目标时区对象，默认为Europe/London
    
    Returns:
        datetime: 用户时区时间对象
    """
    if dt_utc.tzinfo is None:
        # 如果无时区，假设是UTC（仅用于format_iso_utc的兜底）
        dt_utc = dt_utc.replace(tzinfo=timezone.utc)
    else:
        # 确保是UTC
        dt_utc = dt_utc.astimezone(timezone.utc)
    
    return dt_utc.astimezone(tz)


def format_time_for_display(dt: datetime, user_timezone: ZoneInfo = LONDON) -> str:
    """
    格式化时间用于显示（转换为用户时区）
    
    Args:
        dt: UTC时间对象
        user_timezone: 用户时区对象
    
    Returns:
        str: 格式化后的时间字符串
    """
    local_time = to_user_timezone(dt, user_timezone)
    return local_time.strftime('%Y-%m-%d %H:%M:%S %Z')


def format_iso_utc(dt: datetime) -> str:
    """
    格式化为ISO-8601 UTC格式（用于API返回）
    
    Args:
        dt: UTC时间对象（如果无时区，假设是UTC）
    
    Returns:
        str: ISO-8601格式字符串，如 "2024-12-28T10:30:00Z"
    """
    # 兜底：如果无时区，假设是UTC（仅此一处允许）
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    
    return dt.isoformat().replace('+00:00', 'Z')


def detect_dst_transition_dates(year: int, tz: ZoneInfo = LONDON) -> dict:
    """
    检测指定年份的DST切换日期
    
    Args:
        year: 年份
        tz: 时区对象
    
    Returns:
        dict: {
            "spring_transition": "YYYY-MM-DD" or None,
            "autumn_transition": "YYYY-MM-DD" or None,
            "year": year
        }
    """
    spring_transition = None
    autumn_transition = None
    
    # 检查3月最后一个周日（春季）
    for day in range(25, 32):
        try:
            test_date = datetime(year, 3, day, 1, 0, tzinfo=tz)
            if test_date.weekday() == 6:  # 周日
                # 检查是否为切换日（UTC偏移变化）
                prev_day = datetime(year, 3, day - 1, 1, 0, tzinfo=tz)
                if test_date.utcoffset() != prev_day.utcoffset():
                    spring_transition = test_date.strftime("%Y-%m-%d")
                    break
        except (ValueError, OSError):
            continue
    
    # 检查10月最后一个周日（秋季）
    for day in range(25, 32):
        try:
            test_date = datetime(year, 10, day, 1, 0, tzinfo=tz)
            if test_date.weekday() == 6:  # 周日
                # 检查是否为切换日
                prev_day = datetime(year, 10, day - 1, 1, 0, tzinfo=tz)
                if test_date.utcoffset() != prev_day.utcoffset():
                    autumn_transition = test_date.strftime("%Y-%m-%d")
                    break
        except (ValueError, OSError):
            continue
    
    return {
        "spring_transition": spring_transition,
        "autumn_transition": autumn_transition,
        "year": year
    }


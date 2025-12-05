"""
学生认证工具函数模块
"""

from datetime import datetime, timedelta, timezone


def calculate_expires_at(verified_at: datetime) -> datetime:
    """
    计算认证过期时间（终极优化版本）
    
    规则（业界通行做法，参考 Notion、Figma、Spotify 学生优惠）：
    - 如果验证日期在8月1日~10月1日（含）之间，过期时间为次年10月1日
      - 原因：英国 A-Level 放榜日在8月中旬，大量新生8月就想认证
      - 8月1日~10月1日期间认证的，全部给到下一年10月1日
    - 其他时间认证日期，往最近的下一个10月1日靠
    
    优化说明：
    - 原规则：9月1日~10月1日验证 → 次年10月1日过期
    - 新规则：8月1日~10月1日验证 → 次年10月1日过期
    - 这样8月15日注册的用户也能享受到完整一学年，用户好感度更高
    
    Args:
        verified_at: 验证通过的时间（datetime对象，应包含时区信息）
    
    Returns:
        过期时间（datetime对象，UTC时区）
    """
    # 确保 verified_at 有时区信息
    if verified_at.tzinfo is None:
        verified_at = verified_at.replace(tzinfo=timezone.utc)
    
    # 英国 A-Level 放榜日在 8 月中旬，大量新生 8 月就想认证
    if ((verified_at.month == 8 and verified_at.day >= 1) or 
        (verified_at.month == 9) or 
        (verified_at.month == 10 and verified_at.day == 1)):
        # 8月1日 ~ 10月1日期间认证的，全部给到下一年10月1日
        return datetime(verified_at.year + 1, 10, 1, tzinfo=timezone.utc)
    else:
        # 其他时间认证日期，往最近的下一个10月1日靠
        next_oct = datetime(
            verified_at.year if verified_at.month < 10 else verified_at.year + 1,
            10, 1, tzinfo=timezone.utc
        )
        return next_oct


def calculate_renewable_from(expires_at: datetime) -> datetime:
    """
    计算可以开始续期的时间（过期前30天）
    
    Args:
        expires_at: 过期时间（datetime对象，应包含时区信息）
    
    Returns:
        可以开始续期的时间（datetime对象，UTC时区）
    """
    # 确保 expires_at 有时区信息
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    
    return expires_at - timedelta(days=30)


def calculate_days_remaining(expires_at: datetime, now: datetime = None) -> int:
    """
    计算距离过期的剩余天数
    
    Args:
        expires_at: 过期时间（datetime对象，应包含时区信息）
        now: 当前时间（datetime对象，可选，默认使用当前UTC时间）
    
    Returns:
        剩余天数（整数，可能为负数如果已过期）
    """
    if now is None:
        now = datetime.now(timezone.utc)
    
    # 确保两个时间都有时区信息
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    
    delta = expires_at - now
    return delta.days


def can_renew(expires_at: datetime, now: datetime = None) -> bool:
    """
    判断是否可以续期（过期前30天内）
    
    Args:
        expires_at: 过期时间（datetime对象，应包含时区信息）
        now: 当前时间（datetime对象，可选，默认使用当前UTC时间）
    
    Returns:
        True: 可以续期（距离过期30天以内）
        False: 不能续期（距离过期超过30天）
    """
    days_remaining = calculate_days_remaining(expires_at, now)
    return days_remaining <= 30


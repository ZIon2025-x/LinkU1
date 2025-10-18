"""
统一时间处理工具 v2.0
所有时间统一使用UTC存储，前端根据用户时区显示
"""
from datetime import datetime, timezone
import pytz
from typing import Optional, Dict, Any


class TimeHandlerV2:
    """统一时间处理器 v2.0"""
    
    @staticmethod
    def get_utc_now() -> datetime:
        """获取当前UTC时间（用于数据库存储）"""
        return datetime.utcnow()
    
    @staticmethod
    def get_uk_now() -> datetime:
        """获取当前英国时间（用于显示和比较）"""
        uk_tz = pytz.timezone("Europe/London")
        return datetime.now(uk_tz)
    
    @staticmethod
    def utc_to_uk(utc_dt: datetime) -> datetime:
        """UTC时间转换为英国时间（自动处理夏冬令时）"""
        if utc_dt.tzinfo is None:
            # 假设是UTC时间
            utc_dt = utc_dt.replace(tzinfo=timezone.utc)
        uk_tz = pytz.timezone("Europe/London")
        uk_time = utc_dt.astimezone(uk_tz)
        
        # 检查是否夏令时
        is_dst = uk_time.dst().total_seconds() > 0
        tz_name = "BST" if is_dst else "GMT"
        
        print(f"UTC时间: {utc_dt}")
        print(f"英国时间: {uk_time} ({tz_name})")
        print(f"是否夏令时: {is_dst}")
        
        return uk_time
    
    @staticmethod
    def uk_to_utc(uk_dt: datetime) -> datetime:
        """英国时间转换为UTC时间"""
        if uk_dt.tzinfo is None:
            # 假设是英国时间
            uk_tz = pytz.timezone("Europe/London")
            uk_dt = uk_tz.localize(uk_dt)
        return uk_dt.astimezone(timezone.utc)
    
    @staticmethod
    def format_for_api(utc_dt: datetime) -> str:
        """格式化UTC时间为API返回格式（ISO 8601 with Z）"""
        if utc_dt.tzinfo is None:
            # 确保是UTC时间
            utc_dt = utc_dt.replace(tzinfo=timezone.utc)
        return utc_dt.isoformat().replace('+00:00', 'Z')
    
    @staticmethod
    def parse_from_api(time_str: str) -> datetime:
        """解析API传入的时间字符串为UTC时间"""
        try:
            # 处理各种时间格式
            if time_str.endswith('Z'):
                # ISO 8601 UTC格式
                return datetime.fromisoformat(time_str.replace('Z', '+00:00'))
            elif '+' in time_str or time_str.endswith('00:00'):
                # 带时区信息的ISO格式
                return datetime.fromisoformat(time_str)
            else:
                # 假设是UTC时间字符串
                dt = datetime.fromisoformat(time_str)
                return dt.replace(tzinfo=timezone.utc)
        except Exception as e:
            print(f"时间解析错误: {time_str}, 错误: {e}")
            return datetime.utcnow()
    
    @staticmethod
    def get_timezone_info() -> Dict[str, Any]:
        """获取服务器时区信息（包含DST信息）"""
        uk_tz = pytz.timezone("Europe/London")
        current_uk = datetime.now(uk_tz)
        current_utc = datetime.utcnow()
        
        # 检查是否夏令时
        is_dst = current_uk.dst().total_seconds() > 0
        tz_name = current_uk.tzname()
        offset_hours = current_uk.utcoffset().total_seconds() / 3600
        
        return {
            "server_timezone": "Europe/London",
            "server_time": TimeHandlerV2.format_for_api(current_uk.astimezone(timezone.utc)),
            "utc_time": TimeHandlerV2.format_for_api(current_utc),
            "timezone_offset": current_uk.strftime("%z"),
            "is_dst": is_dst,
            "timezone_name": tz_name,
            "offset_hours": offset_hours,
            "dst_info": {
                "is_dst": is_dst,
                "tz_name": tz_name,
                "offset_hours": offset_hours,
                "description": f"英国{'夏令时' if is_dst else '冬令时'} ({tz_name}, UTC{offset_hours:+.0f})"
            }
        }


# 向后兼容的函数
def get_utc_time_v2():
    """获取当前UTC时间 - 新版本"""
    return TimeHandlerV2.get_utc_now()


def get_uk_time_v2():
    """获取当前英国时间 - 新版本"""
    return TimeHandlerV2.get_uk_now()


def format_utc_for_api(utc_dt: datetime) -> str:
    """格式化UTC时间为API格式"""
    return TimeHandlerV2.format_for_api(utc_dt)


def parse_time_from_api(time_str: str) -> datetime:
    """解析API时间字符串为UTC时间"""
    return TimeHandlerV2.parse_from_api(time_str)

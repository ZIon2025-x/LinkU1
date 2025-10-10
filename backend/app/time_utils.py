"""
时间处理工具模块
处理英国时区的夏令时切换和歧义时间
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple, Dict, Any
import pytz

# 尝试导入zoneinfo，如果失败则使用pytz
try:
    from zoneinfo import ZoneInfo
    ZONEINFO_AVAILABLE = True
except ImportError:
    ZONEINFO_AVAILABLE = False
    # 使用pytz作为备用
    import pytz

class TimeHandler:
    """时间处理器，专门处理英国时区的复杂情况"""
    
    UK_TIMEZONE = "Europe/London"
    UTC_TIMEZONE = "UTC"
    
    @staticmethod
    def get_user_timezone_from_request(request_data: Dict[str, Any]) -> str:
        """从请求中获取用户时区"""
        # 优先使用前端传递的时区
        if 'timezone' in request_data:
            return request_data['timezone']
        
        # 默认使用英国时区
        return TimeHandler.UK_TIMEZONE
    
    @staticmethod
    def parse_local_time_to_utc(
        local_time_str: str, 
        timezone_str: str = UK_TIMEZONE,
        disambiguation: str = "later"
    ) -> Tuple[datetime, str, str]:
        """
        将本地时间字符串转换为UTC时间
        
        Args:
            local_time_str: 本地时间字符串，如 "2025-10-26 01:30"
            timezone_str: IANA时区字符串，如 "Europe/London"
            disambiguation: 歧义时间处理策略 ("earlier", "later", "reject")
        
        Returns:
            (utc_datetime, original_timezone, local_time_string)
        """
        try:
            # 解析本地时间字符串
            if 'T' in local_time_str:
                # ISO格式
                local_dt = datetime.fromisoformat(local_time_str.replace('Z', '+00:00'))
            else:
                # 简单格式，如 "2025-10-26 01:30"
                local_dt = datetime.strptime(local_time_str, "%Y-%m-%d %H:%M")
            
            # 获取时区信息
            if ZONEINFO_AVAILABLE:
                zone = ZoneInfo(timezone_str)
            else:
                zone = pytz.timezone(timezone_str)
            
            # 处理歧义时间
            if timezone_str == TimeHandler.UK_TIMEZONE:
                utc_dt, tz_info = TimeHandler._handle_uk_time_ambiguity(
                    local_dt, zone, disambiguation
                )
            else:
                # 其他时区直接转换
                if ZONEINFO_AVAILABLE:
                    local_dt_with_tz = local_dt.replace(tzinfo=zone)
                else:
                    local_dt_with_tz = zone.localize(local_dt)
                utc_dt = local_dt_with_tz.astimezone(timezone.utc)
                tz_info = timezone_str
            
            return utc_dt.replace(tzinfo=None), tz_info, local_time_str
            
        except Exception as e:
            print(f"时间解析错误: {e}")
            # 回退到当前UTC时间
            return datetime.utcnow(), timezone_str, local_time_str
    
    @staticmethod
    def _handle_uk_time_ambiguity(
        local_dt: datetime, 
        zone, 
        disambiguation: str
    ) -> Tuple[datetime, str]:
        """
        处理英国时区的歧义时间
        """
        try:
            if ZONEINFO_AVAILABLE:
                # 使用fold参数处理歧义
                if disambiguation == "earlier":
                    # 选择较早的时间（BST）
                    dt_with_tz = local_dt.replace(tzinfo=zone, fold=0)
                elif disambiguation == "later":
                    # 选择较晚的时间（GMT）
                    dt_with_tz = local_dt.replace(tzinfo=zone, fold=1)
                else:
                    # 默认使用later
                    dt_with_tz = local_dt.replace(tzinfo=zone, fold=1)
                
                # 转换为UTC
                utc_dt = dt_with_tz.astimezone(timezone.utc)
                
                # 确定时区信息
                if dt_with_tz.fold == 0:
                    tz_info = f"{TimeHandler.UK_TIMEZONE} (BST)"
                else:
                    tz_info = f"{TimeHandler.UK_TIMEZONE} (GMT)"
            else:
                # 使用pytz处理歧义
                if disambiguation == "earlier":
                    # 选择较早的时间（BST）
                    dt_with_tz = zone.localize(local_dt, is_dst=True)
                elif disambiguation == "later":
                    # 选择较晚的时间（GMT）
                    dt_with_tz = zone.localize(local_dt, is_dst=False)
                else:
                    # 默认使用later
                    dt_with_tz = zone.localize(local_dt, is_dst=False)
                
                # 转换为UTC
                utc_dt = dt_with_tz.astimezone(timezone.utc)
                
                # 确定时区信息
                if dt_with_tz.dst() != timedelta(0):
                    tz_info = f"{TimeHandler.UK_TIMEZONE} (BST)"
                else:
                    tz_info = f"{TimeHandler.UK_TIMEZONE} (GMT)"
            
            return utc_dt, tz_info
            
        except Exception as e:
            print(f"英国时区歧义处理错误: {e}")
            # 回退到标准处理
            if ZONEINFO_AVAILABLE:
                dt_with_tz = local_dt.replace(tzinfo=zone)
            else:
                dt_with_tz = zone.localize(local_dt)
            utc_dt = dt_with_tz.astimezone(timezone.utc)
            return utc_dt, TimeHandler.UK_TIMEZONE
    
    @staticmethod
    def format_utc_to_user_timezone(
        utc_dt: datetime, 
        user_timezone: str = UK_TIMEZONE
    ) -> Dict[str, Any]:
        """
        将UTC时间格式化为用户时区显示
        
        Returns:
            {
                "local_time": "2025-10-26 01:30",
                "timezone": "Europe/London (BST)",
                "utc_time": "2025-10-26T00:30:00Z",
                "is_dst": True
            }
        """
        try:
            # 转换为用户时区
            if ZONEINFO_AVAILABLE:
                zone = ZoneInfo(user_timezone)
                local_dt = utc_dt.replace(tzinfo=timezone.utc).astimezone(zone)
            else:
                zone = pytz.timezone(user_timezone)
                local_dt = zone.fromutc(utc_dt)
            
            # 检查是否夏令时
            is_dst = local_dt.dst() != timedelta(0)
            
            # 格式化时间
            local_time_str = local_dt.strftime("%Y-%m-%d %H:%M:%S")
            utc_time_str = utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
            
            # 时区标识
            if user_timezone == TimeHandler.UK_TIMEZONE:
                tz_display = f"Europe/London ({'BST' if is_dst else 'GMT'})"
            else:
                tz_display = user_timezone
            
            return {
                "local_time": local_time_str,
                "timezone": tz_display,
                "utc_time": utc_time_str,
                "is_dst": is_dst,
                "offset_hours": local_dt.utcoffset().total_seconds() / 3600
            }
            
        except Exception as e:
            print(f"时间格式化错误: {e}")
            return {
                "local_time": utc_dt.strftime("%Y-%m-%d %H:%M:%S"),
                "timezone": "UTC",
                "utc_time": utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "is_dst": False,
                "offset_hours": 0
            }
    
    @staticmethod
    def detect_dst_transition_dates(year: int) -> Dict[str, str]:
        """
        检测指定年份的夏令时切换日期
        """
        try:
            if ZONEINFO_AVAILABLE:
                zone = ZoneInfo(TimeHandler.UK_TIMEZONE)
            else:
                zone = pytz.timezone(TimeHandler.UK_TIMEZONE)
            
            # 查找春季和秋季切换日期
            spring_transition = None
            autumn_transition = None
            
            # 检查3月最后一个周日（春季）
            for day in range(25, 32):
                try:
                    if ZONEINFO_AVAILABLE:
                        test_date = datetime(year, 3, day, 1, 0, tzinfo=zone)
                    else:
                        test_date = zone.localize(datetime(year, 3, day, 1, 0))
                    if test_date.weekday() == 6:  # 周日
                        spring_transition = test_date.strftime("%Y-%m-%d")
                        break
                except:
                    continue
            
            # 检查10月最后一个周日（秋季）
            for day in range(25, 32):
                try:
                    if ZONEINFO_AVAILABLE:
                        test_date = datetime(year, 10, day, 1, 0, tzinfo=zone)
                    else:
                        test_date = zone.localize(datetime(year, 10, day, 1, 0))
                    if test_date.weekday() == 6:  # 周日
                        autumn_transition = test_date.strftime("%Y-%m-%d")
                        break
                except:
                    continue
            
            return {
                "spring_transition": spring_transition,
                "autumn_transition": autumn_transition,
                "year": year
            }
            
        except Exception as e:
            print(f"DST切换日期检测错误: {e}")
            return {
                "spring_transition": None,
                "autumn_transition": None,
                "year": year
            }
    
    @staticmethod
    def validate_time_input(
        local_time_str: str, 
        timezone_str: str = UK_TIMEZONE
    ) -> Dict[str, Any]:
        """
        验证时间输入，检查是否存在歧义或无效时间
        """
        try:
            # 解析时间
            local_dt = datetime.strptime(local_time_str, "%Y-%m-%d %H:%M")
            
            if ZONEINFO_AVAILABLE:
                zone = ZoneInfo(timezone_str)
            else:
                zone = pytz.timezone(timezone_str)
            
            # 检查是否为歧义时间
            is_ambiguous = False
            is_invalid = False
            suggestions = []
            
            if timezone_str == TimeHandler.UK_TIMEZONE:
                # 检查DST切换日期
                year = local_dt.year
                dst_dates = TimeHandler.detect_dst_transition_dates(year)
                
                date_str = local_dt.strftime("%Y-%m-%d")
                time_str = local_dt.strftime("%H:%M")
                
                # 检查春季跳时（01:00-02:00不存在）
                if (date_str == dst_dates["spring_transition"] and 
                    "01:00" <= time_str < "02:00"):
                    is_invalid = True
                    suggestions.append("此时间不存在，请选择02:00或之后的时间")
                
                # 检查秋季回拨（01:00-02:00歧义）
                elif (date_str == dst_dates["autumn_transition"] and 
                      "01:00" <= time_str < "02:00"):
                    is_ambiguous = True
                    suggestions.append("此时间存在歧义，请选择BST或GMT")
            
            return {
                "is_valid": not is_invalid,
                "is_ambiguous": is_ambiguous,
                "is_invalid": is_invalid,
                "suggestions": suggestions,
                "parsed_time": local_dt.strftime("%Y-%m-%d %H:%M:%S")
            }
            
        except Exception as e:
            return {
                "is_valid": False,
                "is_ambiguous": False,
                "is_invalid": True,
                "suggestions": [f"时间格式错误: {str(e)}"],
                "parsed_time": None
            }

# 向后兼容的函数
def get_utc_time():
    """获取当前UTC时间"""
    return datetime.utcnow()

def get_uk_time_utc():
    """获取英国时间并转换为UTC存储"""
    uk_tz = pytz.timezone("Europe/London")
    uk_time = datetime.now(uk_tz)
    return uk_time.astimezone(timezone.utc).replace(tzinfo=None)

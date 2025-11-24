"""
时间验证和消歧API端点
处理英国时区的复杂时间问题
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
from zoneinfo import ZoneInfo
from app.utils.time_utils import (
    parse_local_as_utc, 
    handle_ambiguous_time, 
    detect_dst_transition_dates,
    to_user_timezone,
    format_iso_utc,
    LONDON
)

router = APIRouter()

class TimeValidationRequest(BaseModel):
    local_time: str  # 本地时间字符串，如 "2025-10-26 01:30"
    timezone: str = "Europe/London"  # IANA时区
    disambiguation: str = "later"  # 消歧策略: "earlier", "later", "reject"

class TimeValidationResponse(BaseModel):
    is_valid: bool
    is_ambiguous: bool
    is_invalid: bool
    suggestions: list
    parsed_time: Optional[str]
    utc_time: Optional[str]
    timezone_info: Optional[str]
    is_dst: Optional[bool]

class DSTInfoResponse(BaseModel):
    year: int
    spring_transition: Optional[str]
    autumn_transition: Optional[str]
    current_dst_status: bool
    current_timezone: str

@router.post("/validate-time", response_model=TimeValidationResponse)
async def validate_time(request: TimeValidationRequest):
    """
    验证时间输入，检查歧义和无效时间
    """
    try:
        # 解析时间字符串
        try:
            local_dt = datetime.strptime(request.local_time, "%Y-%m-%d %H:%M")
        except ValueError:
            return TimeValidationResponse(
                is_valid=False,
                is_ambiguous=False,
                is_invalid=True,
                suggestions=["时间格式错误，请使用 YYYY-MM-DD HH:MM 格式"],
                parsed_time=None,
                utc_time=None,
                timezone_info=None,
                is_dst=None
            )
        
        # 获取时区
        tz = ZoneInfo(request.timezone) if request.timezone != "Europe/London" else LONDON
        
        # 验证时间输入（检查DST切换日期）
        is_ambiguous = False
        is_invalid = False
        suggestions = []
        
        if request.timezone == "Europe/London":
            # 检查DST切换日期
            year = local_dt.year
            dst_dates = detect_dst_transition_dates(year, LONDON)
            
            date_str = local_dt.strftime("%Y-%m-%d")
            time_str = local_dt.strftime("%H:%M")
            
            # 检查春季跳时（01:00-02:00不存在）
            if (dst_dates["spring_transition"] and 
                date_str == dst_dates["spring_transition"] and 
                "01:00" <= time_str < "02:00"):
                is_invalid = True
                suggestions.append("此时间不存在，请选择02:00或之后的时间")
            
            # 检查秋季回拨（01:00-02:00歧义）
            elif (dst_dates["autumn_transition"] and 
                  date_str == dst_dates["autumn_transition"] and 
                  "01:00" <= time_str < "02:00"):
                is_ambiguous = True
                suggestions.append("此时间存在歧义，请选择BST或GMT")
        
        # 如果时间有效，尝试解析为UTC
        utc_time = None
        timezone_info = None
        is_dst = None
        
        if not is_invalid:
            try:
                utc_dt = handle_ambiguous_time(local_dt, tz, request.disambiguation)
                utc_time = format_iso_utc(utc_dt)
                timezone_info = request.timezone
                
                # 检查是否夏令时
                if request.timezone == "Europe/London":
                    london_time = to_user_timezone(utc_dt, LONDON)
                    is_dst = london_time.dst().total_seconds() > 0
                    
            except Exception as e:
                suggestions.append(f"时间解析错误: {str(e)}")
        
        return TimeValidationResponse(
            is_valid=not is_invalid,
            is_ambiguous=is_ambiguous,
            is_invalid=is_invalid,
            suggestions=suggestions,
            parsed_time=local_dt.strftime("%Y-%m-%d %H:%M:%S"),
            utc_time=utc_time,
            timezone_info=timezone_info,
            is_dst=is_dst
        )
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"时间验证失败: {str(e)}")

@router.get("/dst-info/{year}", response_model=DSTInfoResponse)
async def get_dst_info(year: int):
    """
    获取指定年份的夏令时切换信息
    """
    try:
        # 获取DST切换日期
        dst_dates = detect_dst_transition_dates(year, LONDON)
        
        # 检查当前DST状态
        from datetime import timedelta
        from app.utils.time_utils import get_utc_time
        
        current_time = to_user_timezone(get_utc_time(), LONDON)
        current_dst = current_time.dst() != timedelta(0)
        
        return DSTInfoResponse(
            year=year,
            spring_transition=dst_dates["spring_transition"],
            autumn_transition=dst_dates["autumn_transition"],
            current_dst_status=current_dst,
            current_timezone="Europe/London"
        )
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"获取DST信息失败: {str(e)}")

@router.post("/convert-to-utc")
async def convert_to_utc(request: TimeValidationRequest):
    """
    将本地时间转换为UTC时间
    """
    try:
        # 解析时间字符串
        local_dt = datetime.strptime(request.local_time, "%Y-%m-%d %H:%M")
        
        # 获取时区
        tz = ZoneInfo(request.timezone) if request.timezone != "Europe/London" else LONDON
        
        # 转换为UTC
        utc_dt = handle_ambiguous_time(local_dt, tz, request.disambiguation)
        
        return {
            "utc_time": format_iso_utc(utc_dt),
            "timezone_info": request.timezone,
            "local_time": request.local_time,
            "success": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"时间转换失败: {str(e)}")

@router.post("/format-time")
async def format_time(
    utc_time: str,
    user_timezone: str = "Europe/London"
):
    """
    将UTC时间格式化为用户时区显示
    """
    try:
        from datetime import timedelta
        from app.utils.time_utils import parse_iso_utc
        
        # 解析UTC时间
        utc_dt = parse_iso_utc(utc_time)
        
        # 获取时区
        tz = ZoneInfo(user_timezone) if user_timezone != "Europe/London" else LONDON
        
        # 转换为用户时区
        local_dt = to_user_timezone(utc_dt, tz)
        
        # 检查是否夏令时
        is_dst = local_dt.dst() != timedelta(0)
        
        # 格式化
        formatted = {
            "local_time": local_dt.strftime("%Y-%m-%d %H:%M:%S"),
            "timezone": f"Europe/London ({'BST' if is_dst else 'GMT'})" if user_timezone == "Europe/London" else user_timezone,
            "utc_time": format_iso_utc(utc_dt),
            "is_dst": is_dst,
            "offset_hours": local_dt.utcoffset().total_seconds() / 3600
        }
        
        return {
            "formatted_time": formatted,
            "success": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"时间格式化失败: {str(e)}")

@router.get("/timezone-info")
async def get_timezone_info():
    """
    获取当前时区信息
    """
    try:
        from zoneinfo import ZoneInfo
        from app.utils.time_utils import get_utc_time, to_user_timezone
        
        uk_zone = ZoneInfo("Europe/London")
        current_time = to_user_timezone(get_utc_time(), uk_zone)
        
        is_dst = current_time.dst() != datetime.timedelta(0)
        offset_hours = current_time.utcoffset().total_seconds() / 3600
        
        return {
            "timezone": "Europe/London",
            "is_dst": is_dst,
            "timezone_display": f"Europe/London ({'BST' if is_dst else 'GMT'})",
            "offset_hours": offset_hours,
            "current_time": format_iso_utc(current_time),
            "utc_time": format_iso_utc(get_utc_time())
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"获取时区信息失败: {str(e)}")

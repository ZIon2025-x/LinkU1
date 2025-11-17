"""
时间验证和消歧API端点
处理英国时区的复杂时间问题
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from app.time_utils import TimeHandler

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
        # 验证时间输入
        validation_result = TimeHandler.validate_time_input(
            request.local_time, 
            request.timezone
        )
        
        # 如果时间有效，尝试解析为UTC
        utc_time = None
        timezone_info = None
        is_dst = None
        
        if validation_result["is_valid"] and not validation_result["is_invalid"]:
            try:
                utc_dt, tz_info, local_time = TimeHandler.parse_local_time_to_utc(
                    request.local_time,
                    request.timezone,
                    request.disambiguation
                )
                utc_time = utc_dt.isoformat()
                timezone_info = tz_info
                
                # 检查是否夏令时
                if request.timezone == "Europe/London":
                    is_dst = "BST" in tz_info
                    
            except Exception as e:
                validation_result["suggestions"].append(f"时间解析错误: {str(e)}")
        
        return TimeValidationResponse(
            is_valid=validation_result["is_valid"],
            is_ambiguous=validation_result["is_ambiguous"],
            is_invalid=validation_result["is_invalid"],
            suggestions=validation_result["suggestions"],
            parsed_time=validation_result["parsed_time"],
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
        dst_dates = TimeHandler.detect_dst_transition_dates(year)
        
        # 检查当前DST状态
        from datetime import datetime
        from zoneinfo import ZoneInfo
        
        uk_zone = ZoneInfo("Europe/London")
        current_time = datetime.now(uk_zone)
        current_dst = current_time.dst() != datetime.timedelta(0)
        
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
        utc_dt, tz_info, local_time = TimeHandler.parse_local_time_to_utc(
            request.local_time,
            request.timezone,
            request.disambiguation
        )
        
        return {
            "utc_time": utc_dt.isoformat(),
            "timezone_info": tz_info,
            "local_time": local_time,
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
        from datetime import datetime
        
        # 解析UTC时间
        utc_dt = datetime.fromisoformat(utc_time.replace('Z', '+00:00'))
        
        # 格式化为用户时区
        formatted = TimeHandler.format_utc_to_user_timezone(utc_dt, user_timezone)
        
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
        from datetime import datetime
        from zoneinfo import ZoneInfo
from app.utils.time_utils import get_utc_time
        
        uk_zone = ZoneInfo("Europe/London")
        current_time = datetime.now(uk_zone)
        
        is_dst = current_time.dst() != datetime.timedelta(0)
        offset_hours = current_time.utcoffset().total_seconds() / 3600
        
        return {
            "timezone": "Europe/London",
            "is_dst": is_dst,
            "timezone_display": f"Europe/London ({'BST' if is_dst else 'GMT'})",
            "offset_hours": offset_hours,
            "current_time": current_time.isoformat(),
            "utc_time": get_utc_time().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"获取时区信息失败: {str(e)}")

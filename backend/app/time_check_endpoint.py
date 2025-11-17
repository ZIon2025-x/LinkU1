"""
时间检查API端点
用于在Railway环境中检查在线时间获取功能
"""

from fastapi import APIRouter, HTTPException
from datetime import datetime
import requests
import json
from app.utils.time_utils import get_utc_time, LONDON, to_user_timezone, format_iso_utc
from app.models import get_uk_time_online  # 保留用于测试

router = APIRouter()

@router.get("/health/time-check")
async def time_check():
    """检查在线时间获取功能的状态"""
    try:
        # 导入时间函数
        from app.models import get_uk_time_online
        
        result = {
            "status": "success",
            "timestamp": format_iso_utc(get_utc_time()),
            "checks": {}
        }
        
        # 检查1: 本地英国时间（使用新的时间函数）
        try:
            utc_time = get_utc_time()
            local_time = to_user_timezone(utc_time, LONDON)
            result["checks"]["local_time"] = {
                "status": "success",
                "time": format_iso_utc(local_time),
                "timezone": str(local_time.tzinfo),
                "is_dst": local_time.dst() != datetime.timedelta(0)
            }
        except Exception as e:
            result["checks"]["local_time"] = {
                "status": "error",
                "error": str(e)
            }
        
        # 检查2: 在线英国时间
        try:
            online_time = get_uk_time_online()
            result["checks"]["online_time"] = {
                "status": "success",
                "time": format_iso_utc(online_time),
                "timezone": str(online_time.tzinfo),
                "is_dst": online_time.dst() != datetime.timedelta(0)
            }
        except Exception as e:
            result["checks"]["online_time"] = {
                "status": "error",
                "error": str(e)
            }
        
        # 检查3: UTC时间（新的统一时间函数）
        try:
            utc_time = get_utc_time()
            london_time = to_user_timezone(utc_time, LONDON)
            result["checks"]["utc_time"] = {
                "status": "success",
                "utc_time": format_iso_utc(utc_time),
                "london_time": format_iso_utc(london_time),
                "timezone": str(utc_time.tzinfo)
            }
        except Exception as e:
            result["checks"]["naive_time"] = {
                "status": "error",
                "error": str(e)
            }
        
        # 检查4: 时间差异
        if (result["checks"]["local_time"]["status"] == "success" and 
            result["checks"]["online_time"]["status"] == "success"):
            local_dt = datetime.fromisoformat(result["checks"]["local_time"]["time"])
            online_dt = datetime.fromisoformat(result["checks"]["online_time"]["time"])
            time_diff = abs((online_dt - local_dt).total_seconds())
            result["checks"]["time_difference"] = {
                "status": "success",
                "difference_seconds": time_diff,
                "acceptable": time_diff < 10
            }
        
        # 检查5: 网络连接
        apis = [
            'http://worldtimeapi.org/api/timezone/Europe/London',
            'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
            'http://worldclockapi.com/api/json/utc/now'
        ]
        
        network_checks = {}
        for api in apis:
            try:
                response = requests.get(api, timeout=3)
                network_checks[api] = {
                    "status": "success" if response.status_code == 200 else "error",
                    "http_code": response.status_code
                }
            except Exception as e:
                network_checks[api] = {
                    "status": "error",
                    "error": str(e)
                }
        
        result["checks"]["network_connectivity"] = network_checks
        
        # 检查6: 环境变量
        import os
        env_vars = {
            'ENABLE_ONLINE_TIME': os.getenv('ENABLE_ONLINE_TIME', 'true'),
            'TIME_API_TIMEOUT': os.getenv('TIME_API_TIMEOUT', '3'),
            'TIME_API_MAX_RETRIES': os.getenv('TIME_API_MAX_RETRIES', '3'),
            'FALLBACK_TO_LOCAL_TIME': os.getenv('FALLBACK_TO_LOCAL_TIME', 'true'),
            'RAILWAY_ENVIRONMENT': os.getenv('RAILWAY_ENVIRONMENT', 'false'),
            'PORT': os.getenv('PORT', 'N/A')
        }
        result["checks"]["environment_variables"] = env_vars
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"时间检查失败: {str(e)}")

@router.get("/health/time-check/simple")
async def simple_time_check():
    """简化的时间检查"""
    try:
        from app.models import get_uk_time_online
        
        uk_time = get_uk_time_online()
        return {
            "status": "success",
            "uk_time": format_iso_utc(uk_time),
            "timezone": str(uk_time.tzinfo),
            "is_dst": uk_time.dst() != datetime.timedelta(0),
            "message": "在线时间获取功能正常工作"
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "message": "在线时间获取功能出现问题"
        }

"""
速率限制相关的API路由
"""

from fastapi import APIRouter, Request, Depends
from app.rate_limiting import get_rate_limit_info, RATE_LIMITS
from app.deps import get_current_user_secure_sync_csrf

router = APIRouter(prefix="/api/rate-limit", tags=["速率限制"])

@router.get("/info")
async def get_rate_limit_status(
    request: Request,
    current_user = Depends(get_current_user_secure_sync_csrf)
):
    """
    获取当前用户的速率限制状态
    """
    try:
        rate_limit_status = {}
        
        # 获取各种操作的速率限制状态
        for rate_type in RATE_LIMITS.keys():
            rate_limit_status[rate_type] = get_rate_limit_info(request, rate_type)
        
        return {
            "user_id": current_user.id,
            "rate_limits": rate_limit_status,
            "message": "速率限制状态获取成功"
        }
    
    except Exception as e:
        return {
            "error": "获取速率限制状态失败",
            "message": str(e)
        }

@router.get("/info/{rate_type}")
async def get_specific_rate_limit_info(
    rate_type: str,
    request: Request,
    current_user = Depends(get_current_user_secure_sync_csrf)
):
    """
    获取特定操作的速率限制状态
    """
    try:
        if rate_type not in RATE_LIMITS:
            return {
                "error": "无效的速率限制类型",
                "available_types": list(RATE_LIMITS.keys())
            }
        
        rate_info = get_rate_limit_info(request, rate_type)
        
        return {
            "user_id": current_user.id,
            "rate_type": rate_type,
            "rate_info": rate_info,
            "message": f"{rate_type}速率限制状态获取成功"
        }
    
    except Exception as e:
        return {
            "error": "获取速率限制状态失败",
            "message": str(e)
        }

@router.get("/config")
async def get_rate_limit_config(
    current_user = Depends(get_current_user_secure_sync_csrf)
):
    """
    获取所有速率限制配置（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        return {
            "rate_limit_config": RATE_LIMITS,
            "message": "速率限制配置获取成功"
        }
    
    except Exception as e:
        return {
            "error": "获取速率限制配置失败",
            "message": str(e)
        }

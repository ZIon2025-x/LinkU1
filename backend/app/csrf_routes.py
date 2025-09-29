"""
CSRF保护相关的API路由
"""

from fastapi import APIRouter, Request, Response, Depends, HTTPException, status
from app.csrf import CSRFProtection
from app.role_deps import get_current_user_or_cs_or_admin
from app import models

router = APIRouter(prefix="/api/csrf", tags=["CSRF"])

@router.get("/token")
async def get_csrf_token(
    request: Request,
    response: Response,
    current_user = Depends(get_current_user_or_cs_or_admin)
):
    """
    获取CSRF token
    用户必须已登录才能获取CSRF token
    """
    try:
        # 生成新的CSRF token
        csrf_token = CSRFProtection.generate_csrf_token()
        
        # 设置到Cookie（传递User-Agent用于移动端检测）
        user_agent = request.headers.get("user-agent", "")
        CSRFProtection.set_csrf_cookie(response, csrf_token, user_agent)
        
        return {
            "csrf_token": csrf_token,
            "message": "CSRF token已生成并设置到Cookie"
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"生成CSRF token失败: {str(e)}"
        )

@router.post("/verify")
async def verify_csrf_token(
    request: Request,
    current_user = Depends(get_current_user_or_cs_or_admin)
):
    """
    验证CSRF token
    用于测试CSRF保护是否正常工作
    """
    try:
        is_valid = CSRFProtection.verify_csrf_token(request)
        
        if is_valid:
            return {
                "valid": True,
                "message": "CSRF token验证成功"
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="CSRF token验证失败"
            )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"验证CSRF token失败: {str(e)}"
        )

@router.get("/status")
async def get_csrf_status(
    request: Request,
    current_user = Depends(get_current_user_or_cs_or_admin)
):
    """
    获取CSRF保护状态
    显示当前CSRF配置和保护状态
    """
    cookie_token = CSRFProtection.get_csrf_token_from_cookie(request)
    header_token = CSRFProtection.get_csrf_token_from_header(request)
    
    return {
        "csrf_protection_enabled": True,
        "cookie_token_present": cookie_token is not None,
        "header_token_present": header_token is not None,
        "tokens_match": cookie_token == header_token if cookie_token and header_token else False,
        "cookie_name": "csrf_token",
        "header_name": "X-CSRF-Token",
        "max_age": 3600
    }

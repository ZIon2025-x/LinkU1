"""
调试路由 - 仅限开发环境使用
生产环境会自动禁用这些端点
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from app.deps import get_sync_db
from app.separate_auth_deps import get_current_admin
from app.config import Config

# 创建调试路由器
debug_router = APIRouter(prefix="/debug", tags=["调试"])

# 只在开发环境启用调试端点
if Config.ENVIRONMENT == "development":
    
    @debug_router.get("/config")
    def debug_config(current_admin=Depends(get_current_admin)):
        """调试配置信息（仅管理员可访问）"""
        return {
            "environment": Config.ENVIRONMENT,
            "is_production": Config.IS_PRODUCTION,
            "use_redis": Config.USE_REDIS,
            "frontend_url": Config.FRONTEND_URL,
            # 不暴露敏感信息
        }
    
    @debug_router.get("/session-status")
    def debug_session_status(request: Request, current_admin=Depends(get_current_admin)):
        """调试会话状态（仅管理员可访问）"""
        from app.secure_auth import validate_session
        
        session = validate_session(request)
        if session:
            return {
                "session_id": session.session_id[:8] + "...",
                "user_id": session.user_id,
                "is_active": session.is_active,
                "status": "valid"
            }
        else:
            return {
                "status": "invalid",
                "message": "会话无效或已过期"
            }

else:
    # 生产环境 - 所有调试端点返回404
    @debug_router.get("/{path:path}")
    def debug_not_found():
        raise HTTPException(status_code=404, detail="调试端点在生产环境中不可用")
    
    @debug_router.post("/{path:path}")
    def debug_not_found_post():
        raise HTTPException(status_code=404, detail="调试端点在生产环境中不可用")

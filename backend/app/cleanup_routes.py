"""
清理任务API路由
提供手动清理过期数据的接口
"""

import logging
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session

from app.deps import get_sync_db
from app.secure_auth import SecureAuthManager
from app.service_auth import ServiceAuthManager
from app.admin_auth import AdminAuthManager
from app.cleanup_tasks import cleanup_tasks
from app.user_redis_cleanup import user_redis_cleanup

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/cleanup/sessions")
def cleanup_sessions(db: Session = Depends(get_sync_db)):
    """手动清理过期会话"""
    try:
        logger.info("开始手动清理过期会话")
        
        # 清理用户会话
        SecureAuthManager.cleanup_expired_sessions()
        
        # 清理客服会话
        ServiceAuthManager.cleanup_expired_sessions()
        
        # 清理管理员会话
        AdminAuthManager.cleanup_expired_sessions()
        
        logger.info("手动清理过期会话完成")
        
        return {
            "message": "过期会话清理完成",
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"手动清理过期会话失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清理失败: {str(e)}"
        )

@router.post("/cleanup/cache")
def cleanup_cache(db: Session = Depends(get_sync_db)):
    """手动清理过期缓存"""
    try:
        logger.info("开始手动清理过期缓存")
        
        from app.redis_cache import redis_cache
        
        if not redis_cache.enabled:
            return {
                "message": "Redis未启用，无需清理缓存",
                "status": "skipped"
            }
        
        # 清理用户相关缓存
        patterns = [
            "user:*",
            "user_tasks:*",
            "user_profile:*",
            "user_notifications:*",
            "user_reviews:*"
        ]
        
        total_cleaned = 0
        for pattern in patterns:
            cleaned = redis_cache.delete_pattern(pattern)
            total_cleaned += cleaned
        
        logger.info(f"手动清理过期缓存完成，清理了 {total_cleaned} 个键")
        
        return {
            "message": f"过期缓存清理完成，清理了 {total_cleaned} 个键",
            "status": "success",
            "cleaned_count": total_cleaned
        }
        
    except Exception as e:
        logger.error(f"手动清理过期缓存失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清理失败: {str(e)}"
        )

@router.post("/cleanup/user-data")
def cleanup_user_data(user_id: str = None, db: Session = Depends(get_sync_db)):
    """清理用户Redis数据"""
    try:
        logger.info(f"开始清理用户Redis数据: {user_id or '所有用户'}")
        
        # 清理用户数据
        result = user_redis_cleanup.cleanup_all_user_data(user_id)
        
        logger.info(f"用户Redis数据清理完成: {result}")
        
        return {
            "message": f"用户Redis数据清理完成，清理了 {result['total']} 个数据项",
            "status": "success",
            "details": result
        }
        
    except Exception as e:
        logger.error(f"清理用户Redis数据失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清理失败: {str(e)}"
        )

@router.get("/cleanup/user-stats")
def get_user_data_stats(db: Session = Depends(get_sync_db)):
    """获取用户数据统计"""
    try:
        stats = user_redis_cleanup.get_user_data_stats()
        
        return {
            "message": "用户数据统计获取成功",
            "status": "success",
            "stats": stats
        }
        
    except Exception as e:
        logger.error(f"获取用户数据统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取统计失败: {str(e)}"
        )

@router.post("/cleanup/all")
def cleanup_all(db: Session = Depends(get_sync_db)):
    """清理所有过期数据"""
    try:
        logger.info("开始清理所有过期数据")
        
        # 清理会话
        SecureAuthManager.cleanup_expired_sessions()
        ServiceAuthManager.cleanup_expired_sessions()
        AdminAuthManager.cleanup_expired_sessions()
        
        # 清理用户Redis数据
        user_result = user_redis_cleanup.cleanup_all_user_data()
        
        # 清理其他缓存
        from app.redis_cache import redis_cache
        total_cleaned = user_result['total']
        if redis_cache.enabled:
            patterns = [
                "tasks:*",
                "task_detail:*",
                "notifications:*",
                "system_settings:*"
            ]
            
            for pattern in patterns:
                cleaned = redis_cache.delete_pattern(pattern)
                total_cleaned += cleaned
        
        logger.info(f"清理所有过期数据完成，清理了 {total_cleaned} 个数据项")
        
        return {
            "message": f"所有过期数据清理完成，清理了 {total_cleaned} 个数据项",
            "status": "success",
            "cleaned_count": total_cleaned,
            "user_data": user_result
        }
        
    except Exception as e:
        logger.error(f"清理所有过期数据失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清理失败: {str(e)}"
        )

@router.get("/cleanup/status")
def get_cleanup_status():
    """获取清理任务状态"""
    try:
        return {
            "cleanup_tasks_running": cleanup_tasks.running,
            "cleanup_interval": cleanup_tasks.cleanup_interval,
            "status": "success"
        }
    except Exception as e:
        logger.error(f"获取清理任务状态失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取状态失败: {str(e)}"
        )

@router.post("/cleanup/start")
def start_cleanup_tasks():
    """启动清理任务"""
    try:
        if cleanup_tasks.running:
            return {
                "message": "清理任务已在运行中",
                "status": "already_running"
            }
        
        # 这里只是标记为运行，实际的后台任务在应用启动时启动
        return {
            "message": "清理任务启动请求已接收",
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"启动清理任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"启动失败: {str(e)}"
        )

@router.post("/cleanup/stop")
def stop_cleanup_tasks():
    """停止清理任务"""
    try:
        cleanup_tasks.stop_cleanup_tasks()
        
        return {
            "message": "清理任务已停止",
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"停止清理任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"停止失败: {str(e)}"
        )

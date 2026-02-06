"""
管理员 - 推荐系统管理路由
从 routers.py 迁移
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.deps import get_db
from app.separate_auth_deps import get_current_admin
from app.recommendation_monitor import RecommendationMonitor

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["管理员-推荐系统"])


@router.get("/admin/recommendation-metrics")
def get_recommendation_metrics_endpoint(
    days: int = Query(7, ge=1, le=30),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    获取推荐系统性能指标（管理员）
    
    Args:
        days: 统计天数（1-30）
    """
    try:
        monitor = RecommendationMonitor(db)
        metrics = monitor.get_recommendation_metrics(days=days)
        return metrics
    except Exception as e:
        logger.error(f"获取推荐指标失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐指标失败")


@router.get("/admin/recommendation-analytics")
def get_recommendation_analytics_endpoint(
    days: int = Query(7, ge=1, le=30),
    algorithm: Optional[str] = Query(None),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    获取推荐系统深度分析（管理员）
    
    Args:
        days: 统计天数（1-30）
        algorithm: 算法类型（可选）
    """
    try:
        from app.recommendation_analytics import get_recommendation_analytics
        analytics = get_recommendation_analytics(db, days, algorithm)
        return analytics
    except Exception as e:
        logger.error(f"获取推荐分析失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐分析失败")


@router.get("/admin/top-recommended-tasks")
def get_top_recommended_tasks(
    days: int = Query(7, ge=1, le=30),
    limit: int = Query(10, ge=1, le=50),
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取最受欢迎的推荐任务（管理员）"""
    try:
        from app.recommendation_analytics import RecommendationAnalytics
        analytics = RecommendationAnalytics(db)
        top_tasks = analytics.get_top_recommended_tasks(days, limit)
        return {"top_tasks": top_tasks, "period_days": days}
    except Exception as e:
        logger.error(f"获取热门推荐任务失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取热门推荐任务失败")


@router.get("/admin/recommendation-health")
def get_recommendation_health(
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取推荐系统健康状态（管理员）"""
    try:
        from app.recommendation_health import check_recommendation_health
        health = check_recommendation_health(db)
        
        # 更新Prometheus健康指标
        try:
            from app.recommendation_metrics import update_recommendation_health
            for component, check in health.get("checks", {}).items():
                is_healthy = check.get("status") in ["healthy", "degraded"]
                update_recommendation_health(component, is_healthy)
        except Exception:
            pass
        
        return health
    except Exception as e:
        logger.error(f"检查推荐系统健康失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="检查推荐系统健康失败")


@router.get("/admin/recommendation-optimization")
def get_recommendation_optimization(
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取推荐系统优化建议（管理员）"""
    try:
        from app.recommendation_optimizer import optimize_recommendation_system
        result = optimize_recommendation_system(db)
        return result
    except Exception as e:
        logger.error(f"获取推荐优化建议失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取推荐优化建议失败")

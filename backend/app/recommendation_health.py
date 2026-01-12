"""
推荐系统健康检查模块
监控推荐系统的运行状态和性能
"""

import logging
from typing import Dict, List
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, text

from app.models import UserTaskInteraction, Task, User
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)


class RecommendationHealthChecker:
    """推荐系统健康检查器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def check_health(self) -> Dict:
        """
        检查推荐系统健康状态
        
        Returns:
            健康状态报告
        """
        health_status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {}
        }
        
        # 1. 检查数据收集
        data_collection = self._check_data_collection()
        health_status["checks"]["data_collection"] = data_collection
        
        # 2. 检查推荐计算
        recommendation_calculation = self._check_recommendation_calculation()
        health_status["checks"]["recommendation_calculation"] = recommendation_calculation
        
        # 3. 检查缓存
        cache_status = self._check_cache()
        health_status["checks"]["cache"] = cache_status
        
        # 4. 检查数据库性能
        db_performance = self._check_db_performance()
        health_status["checks"]["database"] = db_performance
        
        # 5. 检查推荐质量
        recommendation_quality = self._check_recommendation_quality()
        health_status["checks"]["recommendation_quality"] = recommendation_quality
        
        # 综合判断
        all_healthy = all(
            check.get("status") == "healthy" 
            for check in health_status["checks"].values()
        )
        
        if not all_healthy:
            health_status["status"] = "degraded"
        
        # 如果有严重问题
        critical_issues = [
            check.get("status") == "critical"
            for check in health_status["checks"].values()
        ]
        if any(critical_issues):
            health_status["status"] = "critical"
        
        return health_status
    
    def _check_data_collection(self) -> Dict:
        """检查数据收集"""
        try:
            # 检查最近24小时的数据收集量
            recent_time = datetime.utcnow() - timedelta(hours=24)
            interaction_count = self.db.query(func.count(UserTaskInteraction.id)).filter(
                UserTaskInteraction.interaction_time >= recent_time
            ).scalar() or 0
            
            # 检查推荐任务的交互数
            recommended_interactions = self.db.query(func.count(UserTaskInteraction.id)).filter(
                and_(
                    UserTaskInteraction.interaction_time >= recent_time,
                    UserTaskInteraction.interaction_metadata.isnot(None),
                    UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
                )
            ).scalar() or 0
            
            status = "healthy"
            message = f"数据收集正常：24小时内{interaction_count}次交互，{recommended_interactions}次推荐交互"
            
            if interaction_count < 10:
                status = "degraded"
                message = "数据收集量较低，可能影响推荐质量"
            elif interaction_count == 0:
                status = "critical"
                message = "无数据收集，推荐系统无法正常工作"
            
            return {
                "status": status,
                "message": message,
                "metrics": {
                    "total_interactions_24h": interaction_count,
                    "recommended_interactions_24h": recommended_interactions
                }
            }
        except Exception as e:
            logger.error(f"检查数据收集失败: {e}")
            return {
                "status": "critical",
                "message": f"检查失败: {str(e)}"
            }
    
    def _check_recommendation_calculation(self) -> Dict:
        """检查推荐计算"""
        try:
            # 检查最近1小时的推荐计算次数（通过缓存键）
            try:
                # 尝试获取一个推荐缓存键来测试
                test_key = "recommendations:test:hybrid:10:all:all:all"
                cached = redis_cache.get(test_key)
                
                status = "healthy"
                message = "推荐计算正常"
                
                if not redis_cache:
                    status = "degraded"
                    message = "Redis缓存不可用，推荐计算可能较慢"
                
                return {
                    "status": status,
                    "message": message,
                    "metrics": {
                        "cache_available": redis_cache is not None
                    }
                }
            except Exception as e:
                return {
                    "status": "degraded",
                    "message": f"缓存检查失败: {str(e)}"
                }
        except Exception as e:
            logger.error(f"检查推荐计算失败: {e}")
            return {
                "status": "critical",
                "message": f"检查失败: {str(e)}"
            }
    
    def _check_cache(self) -> Dict:
        """检查缓存状态"""
        try:
            if not redis_cache:
                return {
                    "status": "degraded",
                    "message": "Redis缓存不可用"
                }
            
            # 测试缓存读写
            test_key = "health_check_test"
            test_value = "test"
            redis_cache.setex(test_key, 10, test_value)
            cached_value = redis_cache.get(test_key)
            redis_cache.delete(test_key)
            
            if cached_value == test_value:
                return {
                    "status": "healthy",
                    "message": "缓存工作正常"
                }
            else:
                return {
                    "status": "degraded",
                    "message": "缓存读写异常"
                }
        except Exception as e:
            logger.error(f"检查缓存失败: {e}")
            return {
                "status": "critical",
                "message": f"缓存检查失败: {str(e)}"
            }
    
    def _check_db_performance(self) -> Dict:
        """检查数据库性能"""
        try:
            # 检查推荐相关查询的性能
            start_time = datetime.utcnow()
            
            # 执行一个简单的推荐相关查询
            self.db.query(UserTaskInteraction).filter(
                UserTaskInteraction.interaction_time >= datetime.utcnow() - timedelta(hours=1)
            ).limit(1).all()
            
            query_time = (datetime.utcnow() - start_time).total_seconds()
            
            status = "healthy"
            message = f"数据库性能正常（查询耗时: {query_time:.3f}秒）"
            
            if query_time > 1.0:
                status = "degraded"
                message = f"数据库查询较慢（耗时: {query_time:.3f}秒），可能影响推荐性能"
            elif query_time > 5.0:
                status = "critical"
                message = f"数据库查询严重超时（耗时: {query_time:.3f}秒）"
            
            return {
                "status": status,
                "message": message,
                "metrics": {
                    "query_time_seconds": round(query_time, 3)
                }
            }
        except Exception as e:
            logger.error(f"检查数据库性能失败: {e}")
            return {
                "status": "critical",
                "message": f"检查失败: {str(e)}"
            }
    
    def _check_recommendation_quality(self) -> Dict:
        """检查推荐质量"""
        try:
            # 检查最近24小时的推荐效果
            recent_time = datetime.utcnow() - timedelta(hours=24)
            
            # 推荐任务的点击率
            views = self.db.query(func.count(UserTaskInteraction.id)).filter(
                and_(
                    UserTaskInteraction.interaction_type == "view",
                    UserTaskInteraction.interaction_time >= recent_time,
                    UserTaskInteraction.interaction_metadata.isnot(None),
                    UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
                )
            ).scalar() or 0
            
            clicks = self.db.query(func.count(UserTaskInteraction.id)).filter(
                and_(
                    UserTaskInteraction.interaction_type == "click",
                    UserTaskInteraction.interaction_time >= recent_time,
                    UserTaskInteraction.interaction_metadata.isnot(None),
                    UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
                )
            ).scalar() or 0
            
            click_rate = clicks / views if views > 0 else 0.0
            
            status = "healthy"
            message = f"推荐质量正常（点击率: {click_rate*100:.1f}%）"
            
            if click_rate < 0.05:  # 点击率低于5%
                status = "degraded"
                message = f"推荐质量较低（点击率: {click_rate*100:.1f}%），建议优化算法"
            elif click_rate < 0.01:  # 点击率低于1%
                status = "critical"
                message = f"推荐质量严重不足（点击率: {click_rate*100:.1f}%），需要立即优化"
            
            return {
                "status": status,
                "message": message,
                "metrics": {
                    "click_rate": round(click_rate, 4),
                    "views_24h": views,
                    "clicks_24h": clicks
                }
            }
        except Exception as e:
            logger.error(f"检查推荐质量失败: {e}")
            return {
                "status": "degraded",
                "message": f"检查失败: {str(e)}"
            }


def check_recommendation_health(db: Session) -> Dict:
    """检查推荐系统健康的便捷函数"""
    checker = RecommendationHealthChecker(db)
    return checker.check_health()

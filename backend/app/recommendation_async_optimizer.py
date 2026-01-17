"""
推荐系统异步任务优化模块
优化Celery任务的执行效率，减少资源消耗
"""

import logging
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import User, UserTaskInteraction
from app.task_recommendation import TaskRecommendationEngine
from app.recommendation_cache_strategy import get_cache_strategy
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationAsyncOptimizer:
    """推荐系统异步任务优化器"""
    
    def __init__(self):
        self.cache_strategy = get_cache_strategy()
    
    def batch_precompute_recommendations(
        self,
        user_ids: List[str],
        limit: int = 20,
        batch_size: int = 10
    ) -> Dict[str, any]:
        """
        批量预计算推荐（优化版本）
        
        优化点：
        1. 批量处理，减少数据库连接开销
        2. 智能跳过已有缓存的用户
        3. 错误隔离，单个用户失败不影响其他用户
        
        Args:
            user_ids: 用户ID列表
            limit: 推荐数量
            batch_size: 批次大小
        
        Returns:
            处理结果统计
        """
        stats = {
            "total": len(user_ids),
            "success": 0,
            "skipped": 0,
            "failed": 0,
            "errors": []
        }
        
        db = SessionLocal()
        try:
            # 分批处理
            for i in range(0, len(user_ids), batch_size):
                batch = user_ids[i:i + batch_size]
                
                for user_id in batch:
                    try:
                        # 检查缓存是否存在
                        cache_key = f"rec:{user_id}:hybrid:{limit}:all:all:all"
                        cached = self.cache_strategy.get_recommendations(
                            user_id, "hybrid", limit, None, None, None, "personal"
                        )
                        
                        if cached:
                            stats["skipped"] += 1
                            logger.debug(f"跳过已有缓存: user_id={user_id}")
                            continue
                        
                        # 计算推荐
                        engine = TaskRecommendationEngine(db)
                        recommendations = engine.recommend_tasks(
                            user_id=user_id,
                            limit=limit,
                            algorithm="hybrid"
                        )
                        
                        # 缓存结果
                        self.cache_strategy.cache_recommendations(
                            user_id, recommendations, "hybrid", limit,
                            None, None, None, "personal"
                        )
                        
                        stats["success"] += 1
                        logger.debug(f"预计算完成: user_id={user_id}, count={len(recommendations)}")
                        
                    except Exception as e:
                        stats["failed"] += 1
                        stats["errors"].append(f"{user_id}: {str(e)}")
                        logger.warning(f"预计算失败: user_id={user_id}, error={e}")
                
                # 每批处理后提交事务
                db.commit()
                
        except Exception as e:
            logger.error(f"批量预计算失败: {e}", exc_info=True)
            db.rollback()
        finally:
            db.close()
        
        logger.info(f"批量预计算完成: {stats}")
        return stats
    
    def get_active_users_for_precompute(
        self,
        limit: int = 100,
        days: int = 7
    ) -> List[str]:
        """
        获取需要预计算的活跃用户列表
        
        策略：
        1. 最近N天有交互的用户
        2. 按交互频率排序
        3. 排除已有缓存的用户
        
        Args:
            limit: 返回用户数量
            days: 最近N天
        
        Returns:
            用户ID列表
        """
        db = SessionLocal()
        try:
            from sqlalchemy import func
            
            cutoff_date = get_utc_time() - timedelta(days=days)
            
            # 获取活跃用户（按交互次数排序）
            active_users = db.query(
                UserTaskInteraction.user_id,
                func.count(UserTaskInteraction.id).label('interaction_count')
            ).filter(
                UserTaskInteraction.interaction_time >= cutoff_date
            ).group_by(UserTaskInteraction.user_id).order_by(
                func.count(UserTaskInteraction.id).desc()
            ).limit(limit * 2).all()  # 获取2倍数量，后续过滤
            
            user_ids = [user_id for user_id, _ in active_users]
            
            # 过滤已有缓存的用户
            filtered_user_ids = []
            for user_id in user_ids:
                cache_key = f"rec:{user_id}:hybrid:20:all:all:all"
                cached = self.cache_strategy.get_recommendations(
                    user_id, "hybrid", 20, None, None, None, "personal"
                )
                if not cached:
                    filtered_user_ids.append(user_id)
                    if len(filtered_user_ids) >= limit:
                        break
            
            return filtered_user_ids
            
        except Exception as e:
            logger.error(f"获取活跃用户失败: {e}", exc_info=True)
            return []
        finally:
            db.close()


def optimize_async_tasks():
    """优化异步任务执行"""
    optimizer = RecommendationAsyncOptimizer()
    
    # 获取需要预计算的活跃用户
    active_users = optimizer.get_active_users_for_precompute(limit=100)
    
    if not active_users:
        logger.info("没有需要预计算的用户")
        return
    
    # 批量预计算
    stats = optimizer.batch_precompute_recommendations(active_users, limit=20)
    logger.info(f"异步任务优化完成: {stats}")

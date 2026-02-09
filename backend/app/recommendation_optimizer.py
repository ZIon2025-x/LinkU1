"""
推荐系统优化器
根据实际效果自动调整推荐参数
"""

import logging
from typing import Dict, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.models import UserTaskInteraction, Task
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class RecommendationOptimizer:
    """推荐系统优化器"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def optimize_algorithm_weights(self, days: int = 7) -> Dict[str, float]:
        """
        根据实际效果优化算法权重
        
        Args:
            days: 统计天数
        
        Returns:
            优化后的权重配置
        """
        try:
            start_date = get_utc_time() - timedelta(days=days)
            
            # 获取各算法的效果指标
            algorithms = ["content_based", "collaborative", "hybrid"]
            algorithm_performance = {}
            
            for algo in algorithms:
                # 计算该算法的点击率
                views = self.db.query(func.count(UserTaskInteraction.id)).filter(
                    and_(
                        UserTaskInteraction.interaction_type == "view",
                        UserTaskInteraction.interaction_time >= start_date,
                        UserTaskInteraction.interaction_metadata.isnot(None),
                        UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true',
                        UserTaskInteraction.interaction_metadata.op('->>')('recommendation_algorithm') == algo
                    )
                ).scalar() or 0
                
                clicks = self.db.query(func.count(UserTaskInteraction.id)).filter(
                    and_(
                        UserTaskInteraction.interaction_type == "click",
                        UserTaskInteraction.interaction_time >= start_date,
                        UserTaskInteraction.interaction_metadata.isnot(None),
                        UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true',
                        UserTaskInteraction.interaction_metadata.op('->>')('recommendation_algorithm') == algo
                    )
                ).scalar() or 0
                
                click_rate = clicks / views if views > 0 else 0.0
                
                # 计算接受率
                applies = self.db.query(func.count(UserTaskInteraction.id)).filter(
                    and_(
                        UserTaskInteraction.interaction_type == "apply",
                        UserTaskInteraction.interaction_time >= start_date,
                        UserTaskInteraction.interaction_metadata.isnot(None),
                        UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true',
                        UserTaskInteraction.interaction_metadata.op('->>')('recommendation_algorithm') == algo
                    )
                ).scalar() or 0
                
                accept_rate = applies / clicks if clicks > 0 else 0.0
                
                # 综合评分（点击率权重0.6，接受率权重0.4）
                score = click_rate * 0.6 + accept_rate * 0.4
                
                algorithm_performance[algo] = {
                    "click_rate": click_rate,
                    "accept_rate": accept_rate,
                    "score": score,
                    "views": views,
                    "clicks": clicks,
                    "applies": applies
                }
            
            # 根据效果调整权重
            # 如果某个算法效果明显更好，增加其权重
            # 如果某个算法效果明显更差，降低其权重
            
            # 默认权重
            weights = {
                "content_based": 0.35,
                "collaborative": 0.25,
                "new_task_boost": 0.15,
                "location_based": 0.12,
                "popular": 0.08,
                "time_based": 0.05
            }
            
            # 如果hybrid算法效果最好，保持当前权重
            # 如果content_based效果更好，增加其权重
            if algorithm_performance.get("content_based", {}).get("score", 0) > \
               algorithm_performance.get("hybrid", {}).get("score", 0) * 1.1:
                weights["content_based"] = min(0.5, weights["content_based"] * 1.1)
                weights["collaborative"] = max(0.15, weights["collaborative"] * 0.9)
            
            # 如果collaborative效果更好，增加其权重
            if algorithm_performance.get("collaborative", {}).get("score", 0) > \
               algorithm_performance.get("hybrid", {}).get("score", 0) * 1.1:
                weights["collaborative"] = min(0.4, weights["collaborative"] * 1.1)
                weights["content_based"] = max(0.25, weights["content_based"] * 0.9)
            
            # 归一化权重
            total = sum(weights.values())
            weights = {k: v / total for k, v in weights.items()}
            
            logger.info(f"算法权重优化完成: {weights}")
            logger.info(f"算法效果: {algorithm_performance}")
            
            return weights
            
        except Exception as e:
            logger.error(f"优化算法权重失败: {e}", exc_info=True)
            # 返回默认权重
            return {
                "content_based": 0.35,
                "collaborative": 0.25,
                "new_task_boost": 0.15,
                "location_based": 0.12,
                "popular": 0.08,
                "time_based": 0.05
            }
    
    def get_optimal_diversity_threshold(self, days: int = 7) -> float:
        """
        根据实际效果优化多样性阈值
        
        Args:
            days: 统计天数
        
        Returns:
            最优多样性阈值（0-1）
        """
        try:
            start_date = get_utc_time() - timedelta(days=days)
            
            # 分析推荐任务的多样性
            # 如果用户点击了不同类型的任务，说明多样性重要
            # 如果用户只点击同一类型的任务，说明相关性更重要
            
            # 获取用户点击的推荐任务
            clicks = self.db.query(UserTaskInteraction).filter(
                and_(
                    UserTaskInteraction.interaction_type == "click",
                    UserTaskInteraction.interaction_time >= start_date,
                    UserTaskInteraction.interaction_metadata.isnot(None),
                    UserTaskInteraction.interaction_metadata.op('->>')('is_recommended') == 'true'
                )
            ).all()
            
            if not clicks:
                return 0.5  # 默认阈值
            
            # 分析用户点击的任务类型分布
            from collections import defaultdict
            user_task_types = defaultdict(set)
            
            for click in clicks:
                # 获取任务类型
                task = self.db.query(Task).filter(Task.id == click.task_id).first()
                if task:
                    user_task_types[click.user_id].add(task.task_type)
            
            # 计算平均多样性（每个用户点击的任务类型数）
            diversities = [len(types) for types in user_task_types.values()]
            avg_diversity = sum(diversities) / len(diversities) if diversities else 1.0
            
            # 如果平均多样性高，说明用户喜欢多样化，提高阈值
            # 如果平均多样性低，说明用户偏好集中，降低阈值
            if avg_diversity >= 3:
                threshold = 0.6  # 高多样性阈值
            elif avg_diversity >= 2:
                threshold = 0.5  # 中等多样性阈值
            else:
                threshold = 0.4  # 低多样性阈值（更注重相关性）
            
            logger.info(f"多样性阈值优化: avg_diversity={avg_diversity:.2f}, threshold={threshold}")
            
            return threshold
            
        except Exception as e:
            logger.error(f"优化多样性阈值失败: {e}", exc_info=True)
            return 0.5  # 默认阈值


def optimize_recommendation_system(db: Session) -> Dict:
    """
    执行推荐系统优化
    
    Returns:
        优化结果
    """
    optimizer = RecommendationOptimizer(db)
    
    # 优化算法权重
    weights = optimizer.optimize_algorithm_weights(days=7)
    
    # 优化多样性阈值
    diversity_threshold = optimizer.get_optimal_diversity_threshold(days=7)
    
    return {
        "algorithm_weights": weights,
        "diversity_threshold": diversity_threshold,
        "timestamp": get_utc_time().isoformat()
    }

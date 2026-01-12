"""
推荐系统异步任务
使用Celery异步计算推荐，提升性能
"""

import logging
import json
from typing import List, Dict
from datetime import datetime, timedelta

from app.database import SessionLocal
from app.task_recommendation import TaskRecommendationEngine, get_task_recommendations
from app.redis_cache import redis_cache
from app.models import User, Task

logger = logging.getLogger(__name__)

# 尝试导入 Celery
try:
    from app.celery_app import celery_app
    CELERY_AVAILABLE = True
except ImportError:
    logger.warning("Celery未安装，推荐计算将同步执行")
    CELERY_AVAILABLE = False
    celery_app = None


if CELERY_AVAILABLE:
    @celery_app.task(
        name='app.recommendation_tasks.precompute_recommendations_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60
    )
    def precompute_recommendations_task(self, user_id: str, limit: int = 20):
        """
        预计算用户推荐任务（异步，优化版）
        
        优化点：
        1. 使用智能缓存策略
        2. 跳过已有缓存的用户
        3. 更好的错误处理
        
        Args:
            user_id: 用户ID
            limit: 推荐数量
        """
        db = SessionLocal()
        try:
            # 检查缓存是否存在
            try:
                from app.recommendation_cache_strategy import get_cache_strategy
                cache_strategy = get_cache_strategy()
                cached = cache_strategy.get_recommendations(
                    user_id, "hybrid", limit, None, None, None, "personal"
                )
                if cached:
                    logger.debug(f"跳过已有缓存: user_id={user_id}")
                    return {"status": "skipped", "count": len(cached), "reason": "cache_exists"}
            except ImportError:
                pass
            
            # 计算推荐
            engine = TaskRecommendationEngine(db)
            recommendations = engine.recommend_tasks(
                user_id=user_id,
                limit=limit,
                algorithm="hybrid"
            )
            
            # 使用智能缓存策略缓存结果
            try:
                from app.recommendation_cache_strategy import get_cache_strategy
                cache_strategy = get_cache_strategy()
                cache_strategy.cache_recommendations(
                    user_id, recommendations, "hybrid", limit,
                    None, None, None, "personal"
                )
            except ImportError:
                # 降级：使用原始缓存方法
                cache_key = f"recommendations:{user_id}:hybrid:{limit}:all:all:all"
                redis_cache.setex(
                    cache_key, 
                    3600, 
                    json.dumps(recommendations, default=str)
                )
            
            logger.info(f"预计算推荐完成: user_id={user_id}, count={len(recommendations)}")
            return {"status": "success", "count": len(recommendations)}
        except Exception as e:
            logger.error(f"预计算推荐失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.recommendation_tasks.update_user_preferences_task',
        bind=True,
        max_retries=2,
        default_retry_delay=30
    )
    def update_user_preferences_task(self, user_id: str):
        """
        更新用户偏好向量（基于最新行为）
        
        Args:
            user_id: 用户ID
        """
        db = SessionLocal()
        try:
            from app.task_recommendation import TaskRecommendationEngine
            engine = TaskRecommendationEngine(db)
            
            # 获取用户最新行为
            user_history = engine._get_user_task_history(user_id)
            
            if len(user_history) >= 3:
                # 清除推荐缓存，强制重新计算
                pattern = f"recommendations:{user_id}:*"
                try:
                    redis_cache.delete_pattern(pattern)
                except Exception:
                    pass
                
                logger.info(f"用户偏好已更新: user_id={user_id}")
                return {"status": "success"}
            else:
                logger.debug(f"用户行为数据不足，跳过更新: user_id={user_id}")
                return {"status": "skipped", "reason": "insufficient_data"}
        except Exception as e:
            logger.error(f"更新用户偏好失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.recommendation_tasks.update_popular_tasks_task',
        bind=True,
        max_retries=2
    )
    def update_popular_tasks_task(self):
        """
        更新热门任务列表（定时任务）
        """
        db = SessionLocal()
        try:
            from datetime import datetime, timedelta
            from app.models import Task, UserTaskInteraction
            from sqlalchemy import func, desc
            
            # 计算过去24小时最受欢迎的任务
            recent_time = datetime.utcnow() - timedelta(hours=24)
            
            popular_tasks = db.query(
                Task.id,
                func.count(UserTaskInteraction.id).label('interaction_count')
            ).join(
                UserTaskInteraction,
                Task.id == UserTaskInteraction.task_id
            ).filter(
                UserTaskInteraction.interaction_time >= recent_time,
                Task.status == "open"
            ).group_by(
                Task.id
            ).order_by(
                desc('interaction_count')
            ).limit(50).all()
            
            # 缓存热门任务ID列表
            task_ids = [task.id for task in popular_tasks]
            redis_cache.setex(
                "popular_tasks:24h",
                3600,
                json.dumps(task_ids)
            )
            
            logger.info(f"热门任务列表已更新: count={len(task_ids)}")
            return {"status": "success", "count": len(task_ids)}
        except Exception as e:
            logger.error(f"更新热门任务失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()


def precompute_recommendations_async(user_id: str, limit: int = 20):
    """异步预计算推荐（便捷函数）"""
    if CELERY_AVAILABLE:
        precompute_recommendations_task.delay(user_id, limit)
    else:
        # 降级：同步执行
        db = SessionLocal()
        try:
            engine = TaskRecommendationEngine(db)
            recommendations = engine.recommend_tasks(user_id, limit, "hybrid")
            logger.info(f"同步预计算推荐完成: user_id={user_id}")
        finally:
            db.close()


def update_user_preferences_async(user_id: str):
    """异步更新用户偏好（便捷函数）"""
    if CELERY_AVAILABLE:
        update_user_preferences_task.delay(user_id)
    else:
        logger.debug("Celery不可用，跳过异步更新")


def update_popular_tasks_async():
    """异步更新热门任务（便捷函数）"""
    if CELERY_AVAILABLE:
        update_popular_tasks_task.delay()
    else:
        logger.debug("Celery不可用，跳过异步更新")


if CELERY_AVAILABLE:
    @celery_app.task(
        name='app.recommendation_tasks.cleanup_recommendation_data_task',
        bind=True,
        max_retries=3,
        default_retry_delay=3600  # 1小时后重试
    )
    def cleanup_recommendation_data_task(self):
        """
        Celery任务：清理推荐系统无效数据
        """
        db = SessionLocal()
        try:
            from app.recommendation_data_cleanup import cleanup_recommendation_data
            stats = cleanup_recommendation_data(db)
            logger.info(f"推荐数据清理完成: {stats}")
            return stats
        except Exception as e:
            logger.error(f"清理推荐数据失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.recommendation_tasks.anonymize_old_data_task',
        bind=True,
        max_retries=2,
        default_retry_delay=86400  # 24小时后重试
    )
    def anonymize_old_data_task(self):
        """
        Celery任务：匿名化旧的用户行为数据（保护隐私）
        """
        db = SessionLocal()
        try:
            from app.data_anonymization import anonymize_old_interactions, anonymize_old_feedback
            
            # 匿名化90天前的交互数据
            interaction_count = anonymize_old_interactions(db, days_old=90)
            
            # 匿名化90天前的反馈数据
            feedback_count = anonymize_old_feedback(db, days_old=90)
            
            logger.info(f"数据匿名化完成: 交互记录 {interaction_count} 条, 反馈记录 {feedback_count} 条")
            return {
                "interaction_count": interaction_count,
                "feedback_count": feedback_count
            }
        except Exception as e:
            logger.error(f"数据匿名化失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
    
    @celery_app.task(
        name='app.recommendation_tasks.optimize_recommendation_system_task',
        bind=True,
        max_retries=2,
        default_retry_delay=3600  # 1小时后重试
    )
    def optimize_recommendation_system_task(self):
        """
        Celery任务：优化推荐系统参数
        """
        db = SessionLocal()
        try:
            from app.recommendation_optimizer import optimize_recommendation_system
            result = optimize_recommendation_system(db)
            logger.info(f"推荐系统优化完成: {result}")
            return result
        except Exception as e:
            logger.error(f"推荐系统优化失败: {e}", exc_info=True)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()

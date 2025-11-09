"""
数据库查询优化器
解决N+1查询问题，优化数据库性能
"""

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session, selectinload, joinedload
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
import logging

logger = logging.getLogger(__name__)


class QueryOptimizer:
    """查询优化器"""
    
    @staticmethod
    def get_tasks_with_relations(db: Session, skip: int = 0, limit: int = 100, **filters) -> List[models.Task]:
        """获取任务列表，预加载关联数据，避免N+1查询"""
        from datetime import datetime
        import pytz
        
        # 获取当前英国时间并转换为UTC时间进行比较
        uk_tz = pytz.timezone('Europe/London')
        now_local = datetime.now(uk_tz)
        now_utc = now_local.astimezone(pytz.UTC).replace(tzinfo=None)  # 转换为UTC naive datetime
        
        query = (
            db.query(models.Task)
            .options(
                selectinload(models.Task.poster),  # 预加载发布者信息
                selectinload(models.Task.taker),   # 预加载接受者信息
                selectinload(models.Task.reviews)  # 预加载评论
            )
            .filter(
                or_(
                    models.Task.status == "open",
                    models.Task.status == "taken"
                )
            )
            .filter(
                models.Task.deadline > now_utc  # 使用UTC时间进行比较
            )
        )
        
        # 应用过滤条件
        if filters.get('task_type') and filters['task_type'] not in ['全部类型', '全部']:
            query = query.filter(models.Task.task_type == filters['task_type'])
        
        if filters.get('location') and filters['location'] not in ['全部城市', '全部']:
            query = query.filter(models.Task.location == filters['location'])
        
        if filters.get('keyword'):
            keyword = f"%{filters['keyword']}%"
            query = query.filter(
                or_(
                    models.Task.title.ilike(keyword),
                    models.Task.description.ilike(keyword)
                )
            )
        
        # 排序
        if filters.get('sort_by') == 'latest':
            query = query.order_by(models.Task.created_at.desc())
        elif filters.get('sort_by') == 'reward_high':
            query = query.order_by(models.Task.base_reward.desc())
        elif filters.get('sort_by') == 'deadline':
            query = query.order_by(models.Task.deadline.asc())
        
        return query.offset(skip).limit(limit).all()
    
    @staticmethod
    def get_user_with_stats(db: Session, user_id: str) -> Optional[models.User]:
        """获取用户信息，包含统计信息，避免多次查询"""
        user = (
            db.query(models.User)
            .options(
                selectinload(models.User.tasks_posted),
                selectinload(models.User.tasks_taken),
                selectinload(models.User.reviews)
            )
            .filter(models.User.id == user_id)
            .first()
        )
        
        if user:
            # 计算统计信息
            user.task_count = len(user.tasks_posted) + len(user.tasks_taken)
            user.avg_rating = sum(review.rating for review in user.reviews) / len(user.reviews) if user.reviews else 0.0
        
        return user
    
    @staticmethod
    def get_tasks_with_pagination_info(db: Session, **filters) -> Dict[str, Any]:
        """获取任务列表和分页信息，一次查询完成"""
        from datetime import datetime
        import pytz
        
        # 获取当前英国时间并转换为UTC时间进行比较
        uk_tz = pytz.timezone('Europe/London')
        now_local = datetime.now(uk_tz)
        now_utc = now_local.astimezone(pytz.UTC).replace(tzinfo=None)  # 转换为UTC naive datetime
        
        # 构建基础查询 - 显示开放和已接收但未同意的任务，且未过期
        base_query = db.query(models.Task).filter(
            or_(
                models.Task.status == "open",
                models.Task.status == "taken"
            )
        ).filter(
            models.Task.deadline > now_utc  # 使用UTC时间进行比较
        )
        
        # 应用过滤条件
        if filters.get('task_type') and filters['task_type'] not in ['全部类型', '全部']:
            base_query = base_query.filter(models.Task.task_type == filters['task_type'])
        
        if filters.get('location') and filters['location'] not in ['全部城市', '全部']:
            base_query = base_query.filter(models.Task.location == filters['location'])
        
        if filters.get('keyword'):
            keyword = f"%{filters['keyword']}%"
            base_query = base_query.filter(
                or_(
                    models.Task.title.ilike(keyword),
                    models.Task.description.ilike(keyword)
                )
            )
        
        # 获取总数
        total_count = base_query.count()
        
        # 获取任务列表（预加载关联数据）
        tasks_query = (
            base_query
            .options(
                selectinload(models.Task.poster),
                selectinload(models.Task.taker)
            )
        )
        
        # 排序
        if filters.get('sort_by') == 'latest':
            tasks_query = tasks_query.order_by(models.Task.created_at.desc())
        elif filters.get('sort_by') == 'reward_high':
            tasks_query = tasks_query.order_by(models.Task.base_reward.desc())
        elif filters.get('sort_by') == 'deadline':
            tasks_query = tasks_query.order_by(models.Task.deadline.asc())
        
        skip = filters.get('skip', 0)
        limit = filters.get('limit', 100)
        tasks = tasks_query.offset(skip).limit(limit).all()
        
        return {
            'tasks': tasks,
            'total': total_count,
            'page': (skip // limit) + 1,
            'pages': (total_count + limit - 1) // limit,
            'has_next': skip + limit < total_count,
            'has_prev': skip > 0
        }
    
    @staticmethod
    def get_user_dashboard_data(db: Session, user_id: str) -> Dict[str, Any]:
        """获取用户仪表板数据，一次查询获取所有信息"""
        # 使用子查询获取统计信息
        stats_query = (
            db.query(
                func.count(models.Task.id).label('total_tasks'),
                func.count(models.Task.id).filter(models.Task.status == 'open').label('open_tasks'),
                func.count(models.Task.id).filter(models.Task.status == 'in_progress').label('in_progress_tasks'),
                func.count(models.Task.id).filter(models.Task.status == 'completed').label('completed_tasks'),
                func.avg(models.Review.rating).label('avg_rating'),
                func.count(models.Review.id).label('review_count')
            )
            .outerjoin(models.Review, models.Review.user_id == user_id)
            .filter(
                or_(
                    models.Task.poster_id == user_id,
                    models.Task.taker_id == user_id
                )
            )
        ).first()
        
        # 获取最近的任务
        recent_tasks = (
            db.query(models.Task)
            .options(selectinload(models.Task.poster), selectinload(models.Task.taker))
            .filter(
                or_(
                    models.Task.poster_id == user_id,
                    models.Task.taker_id == user_id
                )
            )
            .order_by(models.Task.created_at.desc())
            .limit(5)
            .all()
        )
        
        # 获取最近的消息
        recent_messages = (
            db.query(models.Message)
            .options(selectinload(models.Message.sender), selectinload(models.Message.receiver))
            .filter(
                or_(
                    models.Message.sender_id == user_id,
                    models.Message.receiver_id == user_id
                )
            )
            .order_by(models.Message.created_at.desc())
            .limit(10)
            .all()
        )
        
        return {
            'stats': {
                'total_tasks': stats_query.total_tasks or 0,
                'open_tasks': stats_query.open_tasks or 0,
                'in_progress_tasks': stats_query.in_progress_tasks or 0,
                'completed_tasks': stats_query.completed_tasks or 0,
                'avg_rating': float(stats_query.avg_rating) if stats_query.avg_rating else 0.0,
                'review_count': stats_query.review_count or 0
            },
            'recent_tasks': recent_tasks,
            'recent_messages': recent_messages
        }


class AsyncQueryOptimizer:
    """异步查询优化器"""
    
    @staticmethod
    async def get_tasks_with_relations_async(
        db: AsyncSession, 
        skip: int = 0, 
        limit: int = 100, 
        **filters
    ) -> List[models.Task]:
        """异步获取任务列表，预加载关联数据"""
        from datetime import datetime
        import pytz
        
        # 获取当前英国时间并转换为UTC时间进行比较
        uk_tz = pytz.timezone('Europe/London')
        now_local = datetime.now(uk_tz)
        now_utc = now_local.astimezone(pytz.UTC).replace(tzinfo=None)  # 转换为UTC naive datetime
        
        query = (
            select(models.Task)
            .options(
                selectinload(models.Task.poster),
                selectinload(models.Task.taker),
                selectinload(models.Task.reviews)
            )
            .filter(
                or_(
                    models.Task.status == "open",
                    models.Task.status == "taken"
                )
            )
            .filter(
                models.Task.deadline > now_utc  # 使用UTC时间进行比较
            )
        )
        
        # 应用过滤条件
        if filters.get('task_type') and filters['task_type'] not in ['全部类型', '全部']:
            query = query.filter(models.Task.task_type == filters['task_type'])
        
        if filters.get('location') and filters['location'] not in ['全部城市', '全部']:
            query = query.filter(models.Task.location == filters['location'])
        
        if filters.get('keyword'):
            keyword = f"%{filters['keyword']}%"
            query = query.filter(
                or_(
                    models.Task.title.ilike(keyword),
                    models.Task.description.ilike(keyword)
                )
            )
        
        # 排序
        if filters.get('sort_by') == 'latest':
            query = query.order_by(models.Task.created_at.desc())
        elif filters.get('sort_by') == 'reward_high':
            query = query.order_by(models.Task.base_reward.desc())
        elif filters.get('sort_by') == 'deadline':
            query = query.order_by(models.Task.deadline.asc())
        
        result = await db.execute(query.offset(skip).limit(limit))
        return result.scalars().all()
    
    @staticmethod
    async def batch_get_users(db: AsyncSession, user_ids: List[str]) -> Dict[str, models.User]:
        """批量获取用户信息，避免N+1查询"""
        if not user_ids:
            return {}
        
        query = (
            select(models.User)
            .options(
                selectinload(models.User.tasks_posted),
                selectinload(models.User.tasks_taken)
            )
            .filter(models.User.id.in_(user_ids))
        )
        
        result = await db.execute(query)
        users = result.scalars().all()
        
        return {user.id: user for user in users}


# 创建优化器实例
query_optimizer = QueryOptimizer()
async_query_optimizer = AsyncQueryOptimizer()

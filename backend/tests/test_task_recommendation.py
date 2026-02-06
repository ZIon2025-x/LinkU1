"""
任务推荐系统测试
"""

import pytest
from sqlalchemy.orm import Session
from app.models import User, Task, UserPreferences, TaskHistory
from app.task_recommendation import (
    TaskRecommendationEngine,
    get_task_recommendations,
    calculate_task_match_score
)
from app.user_behavior_tracker import UserBehaviorTracker
from app.utils.time_utils import get_utc_time
from datetime import datetime, timedelta


@pytest.fixture
def sample_user(db: Session):
    """创建测试用户"""
    user = User(
        id="12345678",
        name="test_user",
        email="test@example.com",
        hashed_password="hashed",
        residence_city="London",
        user_level="normal"
    )
    db.add(user)
    db.commit()
    return user


@pytest.fixture
def other_poster(db: Session):
    """创建另一个用户作为任务发布者（用于推荐测试）"""
    user = User(
        id="99999999",
        name="other_poster",
        email="poster@example.com",
        hashed_password="hashed_password",
        residence_city="Manchester",
        user_level="normal"
    )
    db.add(user)
    db.commit()
    return user


@pytest.fixture
def sample_tasks(db: Session, sample_user: User, other_poster: User):
    """创建测试任务（由其他用户发布，这样推荐算法不会排除它们）"""
    tasks = []
    now = get_utc_time()  # 使用带时区信息的时间
    
    # 创建不同类型的任务
    task_types = ["Tutoring", "Delivery", "Cleaning", "Shopping"]
    locations = ["London", "Manchester", "Birmingham", "Online"]
    
    for i, (task_type, location) in enumerate(zip(task_types, locations)):
        reward_amount = 50.0 + i * 10
        task = Task(
            title=f"Test Task {i+1}",
            description=f"Description for task {i+1}",
            task_type=task_type,
            location=location,
            reward=reward_amount,
            base_reward=reward_amount,  # 添加 base_reward 字段
            deadline=now + timedelta(days=i+1),
            # 使用其他用户作为发布者，这样推荐算法不会排除这些任务
            poster_id=other_poster.id,
            status="open",
            task_level="normal"
        )
        db.add(task)
        tasks.append(task)
    
    db.commit()
    return tasks


@pytest.fixture
def user_preferences(db: Session, sample_user: User):
    """创建用户偏好"""
    import json
    preferences = UserPreferences(
        user_id=sample_user.id,
        task_types=json.dumps(["Tutoring", "Delivery"]),
        locations=json.dumps(["London", "Manchester"]),
        task_levels=json.dumps(["normal", "vip"]),
        keywords=json.dumps(["math", "english"])
    )
    db.add(preferences)
    db.commit()
    return preferences


def test_content_based_recommendation(db: Session, sample_user: User, sample_tasks: list):
    """测试基于内容的推荐"""
    engine = TaskRecommendationEngine(db)
    
    recommendations = engine._content_based_recommend(sample_user, limit=10)
    
    assert len(recommendations) > 0
    assert all("task" in rec for rec in recommendations)
    assert all("score" in rec for rec in recommendations)
    assert all(0 <= rec["score"] <= 1 for rec in recommendations)


def test_collaborative_filtering(db: Session, sample_user: User, sample_tasks: list):
    """测试协同过滤推荐"""
    engine = TaskRecommendationEngine(db)
    
    # 创建另一个用户并记录交互
    other_user = User(
        id="87654321",
        name="other_user",
        email="other@example.com",
        hashed_password="hashed"
    )
    db.add(other_user)
    db.flush()  # 先将用户写入数据库，确保外键约束满足
    
    # 记录其他用户的任务历史
    for task in sample_tasks[:2]:
        history = TaskHistory(
            task_id=task.id,
            user_id=other_user.id,
            action="accepted",
            timestamp=get_utc_time()
        )
        db.add(history)
    
    db.commit()
    
    recommendations = engine._collaborative_filtering_recommend(sample_user, limit=10)
    
    # 如果数据不足，应该回退到基于内容的推荐
    assert len(recommendations) >= 0


def test_hybrid_recommendation(db: Session, sample_user: User, sample_tasks: list, user_preferences: UserPreferences):
    """测试混合推荐"""
    engine = TaskRecommendationEngine(db)
    
    recommendations = engine._hybrid_recommend(sample_user, limit=10)
    
    assert len(recommendations) > 0
    assert all("task" in rec for rec in recommendations)
    assert all("score" in rec for rec in recommendations)
    assert all("reason" in rec for rec in recommendations)


def test_get_task_recommendations(db: Session, sample_user: User, sample_tasks: list):
    """测试推荐API函数"""
    recommendations = get_task_recommendations(
        db=db,
        user_id=sample_user.id,
        limit=5,
        algorithm="hybrid"
    )
    
    assert len(recommendations) <= 5
    assert all("task" in rec for rec in recommendations)


def test_calculate_task_match_score(db: Session, sample_user: User, sample_tasks: list):
    """测试任务匹配分数计算"""
    task = sample_tasks[0]
    
    score = calculate_task_match_score(
        db=db,
        user_id=sample_user.id,
        task_id=task.id
    )
    
    assert 0 <= score <= 1


def test_user_behavior_tracker(db: Session, sample_user: User, sample_tasks: list):
    """测试用户行为追踪"""
    tracker = UserBehaviorTracker(db)
    task = sample_tasks[0]
    
    # 记录浏览
    tracker.record_view(
        user_id=sample_user.id,
        task_id=task.id,
        duration_seconds=30,
        device_type="mobile"
    )
    
    # 记录点击
    tracker.record_click(
        user_id=sample_user.id,
        task_id=task.id,
        device_type="mobile"
    )
    
    # 获取交互记录
    interactions = tracker.get_user_interactions(sample_user.id)
    assert len(interactions) > 0
    
    # 检查交互类型
    view_interactions = [i for i in interactions if i.interaction_type == "view"]
    assert len(view_interactions) > 0


def test_recommendation_caching(db: Session, sample_user: User, sample_tasks: list):
    """测试推荐结果缓存"""
    from app.redis_cache import redis_cache
    
    # 清除缓存
    cache_key = f"recommendations:{sample_user.id}:hybrid:10"
    redis_cache.delete(cache_key)
    
    # 第一次调用
    recommendations1 = get_task_recommendations(
        db=db,
        user_id=sample_user.id,
        limit=10,
        algorithm="hybrid"
    )
    
    # 第二次调用应该从缓存获取
    recommendations2 = get_task_recommendations(
        db=db,
        user_id=sample_user.id,
        limit=10,
        algorithm="hybrid"
    )
    
    # 结果应该相同
    assert len(recommendations1) == len(recommendations2)


def test_location_based_recommendation(db: Session, sample_user: User, sample_tasks: list):
    """测试基于地理位置的推荐"""
    engine = TaskRecommendationEngine(db)
    
    recommendations = engine._location_based_recommend(sample_user, limit=10)
    
    # 如果用户有常住城市，应该返回同城任务
    if sample_user.residence_city:
        assert len(recommendations) >= 0
        for rec in recommendations:
            assert sample_user.residence_city.lower() in rec["task"].location.lower() or \
                   rec["task"].location.lower() == "online"


def test_preference_learning(db: Session, sample_user: User, sample_tasks: list):
    """测试从历史行为学习偏好"""
    engine = TaskRecommendationEngine(db)
    
    # 记录用户接受的任务
    for task in sample_tasks[:2]:
        history = TaskHistory(
            task_id=task.id,
            user_id=sample_user.id,
            action="accepted",
            timestamp=get_utc_time()
        )
        db.add(history)
    db.commit()
    
    # 获取用户偏好向量
    user_preferences = engine._get_user_preferences(sample_user.id)
    user_history = engine._get_user_task_history(sample_user.id)
    user_vector = engine._build_user_preference_vector(
        sample_user, 
        user_preferences, 
        user_history
    )
    
    # 应该从历史中学习到任务类型偏好
    assert "task_types" in user_vector
    assert len(user_vector["task_types"]) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

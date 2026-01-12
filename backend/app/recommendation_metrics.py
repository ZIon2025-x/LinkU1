"""
推荐系统Prometheus指标
用于监控推荐系统的性能和效果
"""

from prometheus_client import Counter, Histogram, Gauge
import logging

logger = logging.getLogger(__name__)

# 推荐请求指标
recommendation_requests_total = Counter(
    'recommendation_requests_total',
    'Total recommendation requests',
    ['algorithm', 'status']  # status: success, error, timeout
)

recommendation_request_duration_seconds = Histogram(
    'recommendation_request_duration_seconds',
    'Recommendation request duration in seconds',
    ['algorithm']
)

# 推荐缓存指标
recommendation_cache_hits_total = Counter(
    'recommendation_cache_hits_total',
    'Total recommendation cache hits',
    ['algorithm']
)

recommendation_cache_misses_total = Counter(
    'recommendation_cache_misses_total',
    'Total recommendation cache misses',
    ['algorithm']
)

# 推荐质量指标
recommendation_click_rate = Gauge(
    'recommendation_click_rate',
    'Recommendation click-through rate',
    ['algorithm']
)

recommendation_accept_rate = Gauge(
    'recommendation_accept_rate',
    'Recommendation acceptance rate',
    ['algorithm']
)

recommendation_avg_match_score = Gauge(
    'recommendation_avg_match_score',
    'Average recommendation match score',
    ['algorithm']
)

# 推荐数量指标
recommendations_generated_total = Counter(
    'recommendations_generated_total',
    'Total recommendations generated',
    ['algorithm', 'user_type']  # user_type: new, existing
)

# 用户行为指标
user_interactions_total = Counter(
    'user_interactions_total',
    'Total user interactions with recommendations',
    ['interaction_type', 'is_recommended']  # interaction_type: view, click, apply, skip
)

# 推荐系统健康指标
recommendation_system_health = Gauge(
    'recommendation_system_health',
    'Recommendation system health status (1=healthy, 0=unhealthy)',
    ['component']  # component: data_collection, calculation, cache, database, quality
)

# 数据质量指标
recommendation_data_quality = Gauge(
    'recommendation_data_quality',
    'Recommendation data quality score (0-1)',
    ['metric']  # metric: completeness, accuracy, freshness
)


def record_recommendation_request(algorithm: str, duration: float, status: str = "success"):
    """记录推荐请求"""
    recommendation_requests_total.labels(algorithm=algorithm, status=status).inc()
    recommendation_request_duration_seconds.labels(algorithm=algorithm).observe(duration)


def record_recommendation_cache_hit(algorithm: str):
    """记录缓存命中"""
    recommendation_cache_hits_total.labels(algorithm=algorithm).inc()


def record_recommendation_cache_miss(algorithm: str):
    """记录缓存未命中"""
    recommendation_cache_misses_total.labels(algorithm=algorithm).inc()


def update_recommendation_metrics(algorithm: str, click_rate: float, accept_rate: float, avg_match_score: float):
    """更新推荐质量指标"""
    recommendation_click_rate.labels(algorithm=algorithm).set(click_rate)
    recommendation_accept_rate.labels(algorithm=algorithm).set(accept_rate)
    recommendation_avg_match_score.labels(algorithm=algorithm).set(avg_match_score)


def record_recommendations_generated(algorithm: str, count: int, user_type: str = "existing"):
    """记录生成的推荐数量"""
    recommendations_generated_total.labels(algorithm=algorithm, user_type=user_type).inc(count)


def record_user_interaction(interaction_type: str, is_recommended: bool):
    """记录用户交互"""
    user_interactions_total.labels(
        interaction_type=interaction_type,
        is_recommended="true" if is_recommended else "false"
    ).inc()


def update_recommendation_health(component: str, is_healthy: bool):
    """更新推荐系统健康状态"""
    recommendation_system_health.labels(component=component).set(1 if is_healthy else 0)


def update_data_quality(metric: str, score: float):
    """更新数据质量指标"""
    recommendation_data_quality.labels(metric=metric).set(score)

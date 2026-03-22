"""Recommendation caching with multi-level fallback."""
import json
import logging
from typing import Optional, List, Dict

logger = logging.getLogger(__name__)

# Try to import cache modules (may not all be available)
try:
    from app.recommendation_cache_strategy import SmartCacheStrategy
    _smart_cache = SmartCacheStrategy()
except Exception:
    _smart_cache = None

try:
    from app.recommendation_cache import RecommendationCache
    _opt_cache = RecommendationCache()
except Exception:
    _opt_cache = None

try:
    from app.redis_cache import redis_cache
    _redis = redis_cache
except Exception:
    _redis = None


def get_cached_recommendations(user_id: str, algorithm: str, limit: int) -> Optional[List[Dict]]:
    """Try to get cached recommendations from multi-level cache."""
    cache_key = f"rec:{user_id}:{algorithm}:{limit}"

    if _smart_cache:
        try:
            cached = _smart_cache.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass

    if _opt_cache:
        try:
            cached = _opt_cache.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass

    if _redis:
        try:
            cached = _redis.get(cache_key)
            if cached:
                return json.loads(cached) if isinstance(cached, str) else cached
        except Exception:
            pass

    return None


def set_cached_recommendations(user_id: str, algorithm: str, limit: int,
                                recommendations: List[Dict], ttl: int = 1800) -> None:
    """Cache recommendations with TTL (default 30 minutes)."""
    cache_key = f"rec:{user_id}:{algorithm}:{limit}"

    if _smart_cache:
        try:
            _smart_cache.set(cache_key, recommendations, ttl=ttl)
            return
        except Exception:
            pass

    if _redis:
        try:
            _redis.setex(cache_key, ttl, json.dumps(recommendations, default=str))
        except Exception:
            pass

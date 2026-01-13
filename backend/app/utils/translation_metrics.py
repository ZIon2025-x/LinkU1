"""
翻译性能监控工具
记录和统计翻译相关的性能指标
"""
import time
import logging
from typing import Dict, Optional
from collections import defaultdict
from datetime import datetime

logger = logging.getLogger(__name__)

# 性能指标存储（内存中，可以定期导出到数据库或监控系统）
_metrics = {
    'translation_requests': defaultdict(int),  # 翻译请求计数
    'cache_hits': defaultdict(int),  # 缓存命中计数
    'cache_misses': defaultdict(int),  # 缓存未命中计数
    'translation_times': [],  # 翻译耗时列表
    'database_queries': defaultdict(int),  # 数据库查询计数
    'service_usage': defaultdict(int),  # 翻译服务使用统计
}


def record_translation_request(
    service: str,
    source_lang: str,
    target_lang: str,
    cached: bool = False,
    duration_ms: Optional[float] = None
):
    """记录翻译请求"""
    _metrics['translation_requests'][f"{service}:{source_lang}:{target_lang}"] += 1
    
    if cached:
        _metrics['cache_hits'][f"{source_lang}:{target_lang}"] += 1
    else:
        _metrics['cache_misses'][f"{source_lang}:{target_lang}"] += 1
    
    if duration_ms is not None:
        _metrics['translation_times'].append(duration_ms)
        # 只保留最近1000条记录
        if len(_metrics['translation_times']) > 1000:
            _metrics['translation_times'] = _metrics['translation_times'][-1000:]
    
    _metrics['service_usage'][service] += 1


def record_database_query(query_type: str, count: int = 1):
    """记录数据库查询"""
    _metrics['database_queries'][query_type] += count


def get_metrics_summary() -> Dict:
    """获取性能指标摘要"""
    total_requests = sum(_metrics['translation_requests'].values())
    total_cache_hits = sum(_metrics['cache_hits'].values())
    total_cache_misses = sum(_metrics['cache_misses'].values())
    
    cache_hit_rate = 0.0
    if total_requests > 0:
        cache_hit_rate = (total_cache_hits / total_requests) * 100
    
    avg_translation_time = 0.0
    if _metrics['translation_times']:
        avg_translation_time = sum(_metrics['translation_times']) / len(_metrics['translation_times'])
    
    return {
        'total_requests': total_requests,
        'cache_hits': total_cache_hits,
        'cache_misses': total_cache_misses,
        'cache_hit_rate': round(cache_hit_rate, 2),
        'avg_translation_time_ms': round(avg_translation_time, 2),
        'service_usage': dict(_metrics['service_usage']),
        'database_queries': dict(_metrics['database_queries']),
        'top_language_pairs': dict(sorted(
            _metrics['translation_requests'].items(),
            key=lambda x: x[1],
            reverse=True
        )[:10])
    }


def reset_metrics():
    """重置性能指标（用于测试或定期清理）"""
    global _metrics
    _metrics = {
        'translation_requests': defaultdict(int),
        'cache_hits': defaultdict(int),
        'cache_misses': defaultdict(int),
        'translation_times': [],
        'database_queries': defaultdict(int),
        'service_usage': defaultdict(int),
    }


class TranslationTimer:
    """翻译耗时计时器（上下文管理器）"""
    
    def __init__(self, service: str, source_lang: str, target_lang: str, cached: bool = False):
        self.service = service
        self.source_lang = source_lang
        self.target_lang = target_lang
        self.cached = cached
        self.start_time = None
    
    def __enter__(self):
        self.start_time = time.time()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.start_time:
            duration_ms = (time.time() - self.start_time) * 1000
            record_translation_request(
                self.service,
                self.source_lang,
                self.target_lang,
                cached=self.cached,
                duration_ms=duration_ms
            )

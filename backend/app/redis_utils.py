"""
Redis 工具函数
提供 SCAN 替代 KEYS 命令的工具函数，避免阻塞 Redis 服务器。
并提供分布式锁的统一实现(供 Celery 任务和清理任务共用)。

KEYS 命令是 O(N) 操作，会阻塞整个 Redis，在生产环境中应避免使用。
SCAN 命令是增量式迭代，每次迭代 O(1)，不会阻塞。
"""

import logging
import time
from typing import List, Optional

logger = logging.getLogger(__name__)


# ==================== Distributed Lock ====================


def get_redis_distributed_lock(lock_key: str, lock_ttl: int = 3600) -> bool:
    """获取 Redis 分布式锁（使用 SETNX）。

    Args:
        lock_key: 锁的键名
        lock_ttl: 锁的过期时间（秒），默认 1 小时

    Returns:
        True 表示获取成功(可以执行关键段),False 表示锁已被占用(应跳过)。

    降级:Redis 不可用时返回 True(允许执行,接受多实例重复执行的风险);
    其他异常同样允许执行,避免锁机制故障导致任务无法执行。
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()

        if not redis_client:
            logger.warning(f"Redis 不可用，跳过分布式锁检查: {lock_key}")
            return True

        lock_value = str(time.time())
        result = redis_client.set(lock_key, lock_value, nx=True, ex=lock_ttl)

        if result:
            logger.debug(f"成功获取分布式锁: {lock_key}")
            return True
        else:
            logger.debug(f"分布式锁已被占用: {lock_key}")
            return False

    except Exception as e:
        logger.warning(f"获取分布式锁失败 {lock_key}: {e}，允许执行（降级处理）")
        return True


def release_redis_distributed_lock(lock_key: str) -> None:
    """释放 Redis 分布式锁(清除 key)。异常时不抛出,仅 warn。"""
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()

        if redis_client:
            redis_client.delete(lock_key)
            logger.debug(f"释放分布式锁: {lock_key}")
    except Exception as e:
        logger.warning(f"释放分布式锁失败 {lock_key}: {e}")


# ==================== SCAN-based helpers ====================


def scan_keys(redis_client, pattern: str, count: int = 100) -> List:
    """使用 SCAN 命令替代 KEYS 命令，非阻塞地查找匹配的键。

    Args:
        redis_client: Redis 客户端实例
        pattern: 匹配模式（如 "session:*"）
        count: 每次迭代返回的建议数量（Redis 不保证精确数量）

    Returns:
        匹配的键列表
    """
    result = []
    cursor = 0
    try:
        while True:
            cursor, keys = redis_client.scan(cursor, match=pattern, count=count)
            result.extend(keys)
            if cursor == 0:
                break
    except Exception as e:
        logger.error("SCAN 命令执行失败 (pattern=%s): %s", pattern, e)
    return result


def delete_by_pattern(redis_client, pattern: str, count: int = 100) -> int:
    """使用 SCAN + DELETE 替代 KEYS + DELETE，非阻塞地删除匹配的键。

    Args:
        redis_client: Redis 客户端实例
        pattern: 匹配模式（如 "cache:*"）
        count: 每次迭代扫描的建议数量

    Returns:
        删除的键数量
    """
    deleted = 0
    cursor = 0
    try:
        while True:
            cursor, keys = redis_client.scan(cursor, match=pattern, count=count)
            if keys:
                deleted += redis_client.delete(*keys)
            if cursor == 0:
                break
    except Exception as e:
        logger.error("SCAN+DELETE 执行失败 (pattern=%s): %s", pattern, e)
    return deleted

"""
Redis 工具函数
提供 SCAN 替代 KEYS 命令的工具函数，避免阻塞 Redis 服务器。

KEYS 命令是 O(N) 操作，会阻塞整个 Redis，在生产环境中应避免使用。
SCAN 命令是增量式迭代，每次迭代 O(1)，不会阻塞。
"""

import logging
from typing import List, Optional

logger = logging.getLogger(__name__)


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

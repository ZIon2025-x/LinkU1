"""
Redis 共享连接池模块
所有 Redis 客户端共享同一个连接池，减少连接数开销。
"""

import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)

_pool = None


def get_shared_pool():
    """获取共享的 Redis 连接池（懒初始化，单例）。

    Returns:
        redis.ConnectionPool 或 None（如果 Redis 不可用）
    """
    global _pool
    if _pool is not None:
        return _pool

    try:
        import redis
    except ImportError:
        logger.warning("redis 模块未安装，连接池不可用")
        return None

    from app.config import get_settings
    settings = get_settings()

    if not settings.USE_REDIS or not settings.REDIS_URL:
        return None

    try:
        max_connections = int(os.getenv("REDIS_MAX_CONNECTIONS", "50"))
        _pool = redis.ConnectionPool.from_url(
            settings.REDIS_URL,
            max_connections=max_connections,
            socket_connect_timeout=int(os.getenv("REDIS_CONNECT_TIMEOUT", "5")),
            socket_timeout=int(os.getenv("REDIS_SOCKET_TIMEOUT", "5")),
            retry_on_timeout=True,
            health_check_interval=int(os.getenv("REDIS_HEALTH_CHECK_INTERVAL", "30")),
            socket_keepalive=True,
        )
        logger.info("Redis 共享连接池已创建 (max_connections=%d)", max_connections)
        return _pool
    except Exception as e:
        logger.error("创建 Redis 共享连接池失败: %s", e)
        return None


def get_client(decode_responses: bool = False):
    """从共享连接池获取 Redis 客户端。

    Args:
        decode_responses: 是否自动解码响应（True 返回 str，False 返回 bytes）

    Returns:
        redis.Redis 实例或 None
    """
    pool = get_shared_pool()
    if pool is None:
        return None

    try:
        import redis
        # 对于不同的 decode_responses 需求，可以在同一个 pool 上创建不同的客户端
        # 注意：ConnectionPool.from_url 不支持运行时更改 decode_responses
        # 因此对于 decode_responses=True 的情况，创建独立客户端使用同一 URL
        if decode_responses:
            from app.config import get_settings
            settings = get_settings()
            client = redis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=int(os.getenv("REDIS_CONNECT_TIMEOUT", "5")),
                socket_timeout=int(os.getenv("REDIS_SOCKET_TIMEOUT", "5")),
                retry_on_timeout=True,
            )
        else:
            client = redis.Redis(connection_pool=pool, decode_responses=False)
        client.ping()
        return client
    except Exception as e:
        logger.warning("从共享连接池获取 Redis 客户端失败: %s", e)
        return None

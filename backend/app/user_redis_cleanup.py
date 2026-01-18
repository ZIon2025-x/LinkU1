"""
用户Redis数据清理模块
专门用于清理用户相关的Redis数据
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any

from app.utils.time_utils import get_utc_time, parse_iso_utc

logger = logging.getLogger(__name__)

class UserRedisCleanup:
    """用户Redis数据清理器"""
    
    def __init__(self):
        self.redis_client = None
        self._init_redis()
    
    def _init_redis(self):
        """初始化Redis客户端"""
        try:
            from app.redis_cache import get_redis_client
            self.redis_client = get_redis_client()
            if self.redis_client:
                logger.info("[USER_REDIS_CLEANUP] Redis客户端初始化成功")
            else:
                logger.warning("[USER_REDIS_CLEANUP] Redis客户端不可用")
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] Redis客户端初始化失败: {e}")
    
    def cleanup_user_sessions(self, user_id: str = None) -> int:
        """清理用户会话数据
        
        ⚠️ 已禁用：Redis 使用 setex 设置了 TTL，会自动删除过期 key，不需要手动清理。
        手动清理会导致以下问题：
        1. 过期判断可能和实际 TTL 不一致（如 iOS 应用使用1年有效期）
        2. 遍历大量 key 性能差
        3. 可能误删还在有效期内的会话
        
        如果需要清理特定用户的会话，请使用 SecureAuthManager.revoke_user_sessions(user_id)
        """
        # ⚠️ 已禁用，直接返回 0
        logger.debug("[USER_REDIS_CLEANUP] cleanup_user_sessions 已禁用（Redis TTL 会自动处理）")
        return 0
    
    def cleanup_refresh_tokens(self, user_id: str = None) -> int:
        """清理refresh token数据
        
        ⚠️ 已禁用：Redis 使用 setex 设置了 TTL，会自动删除过期 key，不需要手动清理。
        refresh token 创建时已设置正确的过期时间（iOS 1年，其他12小时）。
        
        如果需要撤销特定用户的 token，请使用 revoke_all_user_refresh_tokens(user_id)
        """
        # ⚠️ 已禁用，直接返回 0
        logger.debug("[USER_REDIS_CLEANUP] cleanup_refresh_tokens 已禁用（Redis TTL 会自动处理）")
        return 0
    
    def cleanup_user_cache(self, user_id: str = None) -> int:
        """清理用户缓存数据
        
        ⚠️ 已禁用：
        1. Redis 缓存使用 TTL 自动过期
        2. 现在基本没有旧格式（pickle）数据需要迁移
        3. 遍历大量 key 性能差
        
        如果需要清理特定用户的缓存，请使用 redis_cache.clear_user_cache(user_id)
        """
        # ⚠️ 已禁用，直接返回 0
        logger.debug("[USER_REDIS_CLEANUP] cleanup_user_cache 已禁用（Redis TTL 会自动处理）")
        return 0
    
    def cleanup_all_user_data(self, user_id: str = None) -> Dict[str, int]:
        """清理所有用户数据
        
        注意：核心清理函数已禁用，Redis TTL 会自动处理过期数据
        """
        result = {
            'sessions': 0,
            'refresh_tokens': 0,
            'cache': 0,
            'total': 0
        }
        
        try:
            # 这些函数已禁用，会直接返回 0
            result['sessions'] = self.cleanup_user_sessions(user_id)
            result['refresh_tokens'] = self.cleanup_refresh_tokens(user_id)
            result['cache'] = self.cleanup_user_cache(user_id)
            result['total'] = result['sessions'] + result['refresh_tokens'] + result['cache']
            
            # 只有实际清理了数据才记录 INFO 日志
            if result['total'] > 0:
                logger.info(f"[USER_REDIS_CLEANUP] 用户数据清理完成: {result}")
            # 否则不记录，减少日志噪音
            
            return result
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 清理所有用户数据失败: {e}")
            return result
    
    def get_user_data_stats(self) -> Dict[str, Any]:
        """获取用户数据统计"""
        if not self.redis_client:
            return {}
        
        try:
            stats = {
                'total_sessions': 0,
                'total_user_sessions': 0,
                'total_refresh_tokens': 0,
                'total_user_refresh_tokens': 0,
                'total_user_cache': 0,
                'expired_sessions': 0,
                'expired_refresh_tokens': 0,
                'expired_cache': 0,
            }
            
            # 统计会话数据
            session_keys = self.redis_client.keys("session:*")
            stats['total_sessions'] = len(session_keys)
            
            for key in session_keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                data = self._get_redis_data(key_str)
                # 如果数据无法解析，也计入过期（需要清理）
                if data is None or self._is_session_expired(data):
                    stats['expired_sessions'] += 1
            
            # 统计用户会话列表
            user_session_keys = self.redis_client.keys("user_sessions:*")
            stats['total_user_sessions'] = len(user_session_keys)
            
            # 统计refresh token数据
            refresh_token_keys = self.redis_client.keys("refresh_token:*")
            stats['total_refresh_tokens'] = len(refresh_token_keys)
            
            for key in refresh_token_keys:
                key_str = key.decode() if isinstance(key, bytes) else key
                data = self._get_redis_data(key_str)
                # 如果数据无法解析，也计入过期（需要清理）
                if data is None or self._is_refresh_token_expired(data):
                    stats['expired_refresh_tokens'] += 1
            
            # 统计用户refresh token列表
            user_refresh_token_keys = self.redis_client.keys("user_refresh_tokens:*")
            stats['total_user_refresh_tokens'] = len(user_refresh_token_keys)
            
            # 统计用户缓存
            cache_patterns = ["user:*", "user_tasks:*", "user_profile:*", "user_notifications:*", "user_reviews:*"]
            for pattern in cache_patterns:
                cache_keys = self.redis_client.keys(pattern)
                stats['total_user_cache'] += len(cache_keys)
                
                for key in cache_keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    data = self._get_redis_data(key_str)
                    # 如果数据无法解析，也计入过期（需要清理）
                    if data is None or self._is_cache_expired(data):
                        stats['expired_cache'] += 1
            
            return stats
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 获取用户数据统计失败: {e}")
            return {}
    
    def _get_redis_data(self, key: str) -> Dict[str, Any]:
        """安全获取Redis数据，支持多种格式：
        - JSON格式（优先，安全）
        - orjson格式（兼容JSON）
        - 压缩数据（gzip/zlib）
        - ⚠️ pickle格式（仅限隔离进程，白名单+魔数+schema校验）
        - 特殊字符串标记（如"__NULL__"、"1"等，返回None表示无法解析为字典）
        """
        try:
            raw_data = self.redis_client.get(key)
            if not raw_data:
                return None
            
            # 确保数据是bytes类型
            if not isinstance(raw_data, bytes):
                raw_data = bytes(raw_data) if raw_data else None
                if not raw_data:
                    return None
            
            # ⚠️ 检查是否是压缩数据（gzip/zlib）
            # ⚠️ 解压安全：增加输入/输出大小上限，避免"压缩炸弹"
            MAX_COMPRESSED_SIZE = 10 * 1024 * 1024  # 10MB上限
            MAX_DECOMPRESSED_SIZE = 100 * 1024 * 1024  # 100MB上限
            
            if isinstance(raw_data, bytes) and len(raw_data) > 2:
                # ⚠️ 检查输入大小
                if len(raw_data) > MAX_COMPRESSED_SIZE:
                    logger.warning(f"[USER_REDIS_CLEANUP] 压缩数据过大: {key}, size: {len(raw_data)}")
                    return None
                
                decompressed = None
                # 检查gzip魔数 \x1f\x8b
                if raw_data[:2] == b'\x1f\x8b':
                    try:
                        import gzip
                        decompressed = gzip.decompress(raw_data)
                        # ⚠️ 检查输出大小
                        if len(decompressed) > MAX_DECOMPRESSED_SIZE:
                            logger.warning(f"[USER_REDIS_CLEANUP] 解压后数据过大: {key}, size: {len(decompressed)}")
                            return None
                    except Exception as e:
                        logger.warning(f"[USER_REDIS_CLEANUP] 解压gzip失败 {key}: {e}")
                        # ⚠️ 解压失败不重试超过一次，任何异常都不要写回
                        return None
                
                # 检查zlib魔数
                elif raw_data[0] == 0x78:  # zlib常见起始字节
                    try:
                        import zlib
                        decompressed = zlib.decompress(raw_data)
                        # ⚠️ 检查输出大小
                        if len(decompressed) > MAX_DECOMPRESSED_SIZE:
                            logger.warning(f"[USER_REDIS_CLEANUP] 解压后数据过大: {key}, size: {len(decompressed)}")
                            return None
                    except Exception as e:
                        logger.warning(f"[USER_REDIS_CLEANUP] 解压zlib失败 {key}: {e}")
                        # ⚠️ 解压失败不重试超过一次，任何异常都不要写回
                        return None
                
                # ⚠️ 仅在确认解压成功后再使用
                if decompressed is not None:
                    raw_data = decompressed
            
            # ⚠️ 尝试1：JSON格式（优先，安全）
            try:
                import json
                if isinstance(raw_data, bytes):
                    raw_data_str = raw_data.decode('utf-8')
                else:
                    raw_data_str = raw_data
                parsed_data = json.loads(raw_data_str)
                if isinstance(parsed_data, dict):
                    # 检查是否是v2格式
                    if parsed_data.get("schema_version") == "2":
                        return parsed_data.get("data")
                    return parsed_data
            except (json.JSONDecodeError, UnicodeDecodeError, TypeError):
                pass
            
            # ⚠️ 尝试2：orjson格式（兼容JSON）
            try:
                import orjson
                if isinstance(raw_data, bytes):
                    parsed_data = orjson.loads(raw_data)
                else:
                    parsed_data = orjson.loads(raw_data.encode('utf-8'))
                if isinstance(parsed_data, dict):
                    return parsed_data
            except Exception:
                pass
            
            # ⚠️ 尝试3：双重编码JSON
            try:
                import json
                if isinstance(raw_data, bytes):
                    raw_data_str = raw_data.decode('utf-8')
                else:
                    raw_data_str = raw_data
                parsed_data = json.loads(raw_data_str)
                if isinstance(parsed_data, str):
                    parsed_data = json.loads(parsed_data)
                if isinstance(parsed_data, dict):
                    return parsed_data
            except (json.JSONDecodeError, TypeError):
                pass
            
            # ⚠️ 尝试4：pickle格式（仅限隔离进程，必选校验）
            # ⚠️ 清理脚本运行在单独容器或一组隔离worker，且使用只读凭证
            # ⚠️ 白名单前缀 + 魔数检查 + schema_version 写成必选校验（不是"尝试性"）
            ALLOWED_PICKLE_PREFIXES = ['user:', 'user_cache:']  # 白名单
            PICKLE_MAGIC = b'\x80'  # pickle协议2+的魔数
            
            if any(key.startswith(prefix) for prefix in ALLOWED_PICKLE_PREFIXES):
                # ⚠️ 必选校验1：检查魔数
                if not (isinstance(raw_data, bytes) and raw_data.startswith(PICKLE_MAGIC)):
                    logger.warning(f"[USER_REDIS_CLEANUP] Pickle魔数不匹配: {key}")
                    return None
                
                try:
                    import pickle
                    # ⚠️ 在隔离环境中反序列化（仅用于迁移）
                    parsed_data = pickle.loads(raw_data)
                    
                    # ⚠️ 必选校验2：检查schema_version（如果存在）
                    if isinstance(parsed_data, dict):
                        # 检查是否有schema_version字段
                        if 'schema_version' in parsed_data:
                            schema_version = parsed_data.get('schema_version')
                            if schema_version not in ['1', '1.0']:  # 只允许v1格式
                                logger.warning(f"[USER_REDIS_CLEANUP] Pickle schema_version不匹配: {key}, version: {schema_version}")
                                return None
                        
                        # ⚠️ 立即迁移为JSON格式（仅在确认解析成功后）
                        self._migrate_to_json(key, parsed_data)
                        return parsed_data
                    else:
                        # ⚠️ 如果解析出来的是对象（如 SQLAlchemy User 对象），而不是字典
                        # 这是旧格式的数据，应该删除而不是迁移
                        # 因为新系统使用 JSON 格式存储字典数据
                        # 这是正常的清理行为，不需要记录为警告
                        logger.debug(f"[USER_REDIS_CLEANUP] 检测到旧格式对象数据（非字典）: {key}, 类型: {type(parsed_data).__name__}, 将自动清理")
                        return None  # 返回 None 会触发删除逻辑
                except (pickle.UnpicklingError, TypeError, Exception) as e:
                    logger.warning(f"[USER_REDIS_CLEANUP] Pickle解析失败 {key}: {e}")
                    # ⚠️ 失败不写回，避免把损坏数据"定格"
                    return None
            
            # 所有解析都失败
            logger.warning(f"[USER_REDIS_CLEANUP] 无法解析数据格式: {key}, 类型: {type(raw_data)}")
            return None
            
        except Exception as e:
            logger.debug(f"[USER_REDIS_CLEANUP] 获取Redis数据失败 {key}: {e}")
            return None
    
    def _migrate_to_json(self, key: str, data: dict):
        """将pickle数据迁移为JSON格式（⚠️ 保留TTL，严禁固定ex=3600）"""
        try:
            import json
            from app.utils.time_utils import get_utc_time
            # ⚠️ 先读取PTTL，保留原有过期时间（毫秒）
            ttl_ms = self.redis_client.pttl(key)
            if ttl_ms < 0:
                ttl_ms = 3600000  # 默认1小时（毫秒）
            
            json_data = json.dumps(data, ensure_ascii=False)
            
            # ⚠️ 使用PEXPIRE保留原有TTL，严禁使用set(..., ex=3600)重置寿命
            self.redis_client.set(key, json_data)
            if ttl_ms > 0:
                self.redis_client.pexpire(key, ttl_ms)
            
            logger.info(f"[USER_REDIS_CLEANUP] 迁移pickle到JSON: {key}, TTL: {ttl_ms}ms")
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 迁移失败 {key}: {e}")
    
    def _is_session_expired(self, data: Dict[str, Any]) -> bool:
        """检查会话是否过期
        
        ⚠️ 注意：iOS 应用会话使用 1 年有效期，不能使用固定的 24 小时判断！
        """
        try:
            # 首先检查是否被标记为不活跃
            if not data.get('is_active', True):
                return True
            
            last_activity_str = data.get('last_activity', data.get('created_at'))
            if not last_activity_str:
                return True
            
            last_activity = parse_iso_utc(last_activity_str)
            
            # ⚠️ iOS 应用会话使用 1 年有效期，其他会话使用 24 小时
            is_ios_app = data.get('is_ios_app', False)
            if is_ios_app:
                # iOS 应用：1年有效期
                expire_hours = 365 * 24
            else:
                # 普通会话：24小时
                expire_hours = 24
            
            return get_utc_time() - last_activity > timedelta(hours=expire_hours)
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 检查会话过期失败: {e}")
            return True
    
    def _is_refresh_token_expired(self, data: Dict[str, Any]) -> bool:
        """检查refresh token是否过期"""
        try:
            expires_at_str = data.get('expires_at')
            if not expires_at_str:
                return True
            
            expires_at = parse_iso_utc(expires_at_str)
            # 检查是否已过期
            return get_utc_time() > expires_at
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 检查refresh token过期失败: {e}")
            return True
    
    def _is_cache_expired(self, data: Dict[str, Any]) -> bool:
        """检查缓存是否过期"""
        try:
            # 检查是否有时间戳字段
            time_fields = ['created_at', 'last_activity', 'updated_at', 'timestamp']
            for field in time_fields:
                if field in data:
                    time_str = data[field]
                    if time_str:
                        created_time = parse_iso_utc(time_str)
                        # 缓存7天过期
                        return get_utc_time() - created_time > timedelta(days=7)
            return False
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 检查缓存过期失败: {e}")
            return True

# 全局实例
user_redis_cleanup = UserRedisCleanup()

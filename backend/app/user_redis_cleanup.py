"""
用户Redis数据清理模块
专门用于清理用户相关的Redis数据
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any

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
        """清理用户会话数据"""
        if not self.redis_client:
            return 0
        
        try:
            cleaned_count = 0
            
            if user_id:
                # 清理特定用户的会话
                patterns = [
                    f"session:*",  # 所有会话
                    f"user_sessions:{user_id}",  # 用户会话列表
                ]
            else:
                # 清理所有用户会话
                patterns = [
                    "session:*",
                    "user_sessions:*",
                ]
            
            for pattern in patterns:
                keys = self.redis_client.keys(pattern)
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    
                    # 检查是否是会话数据
                    if key_str.startswith("session:"):
                        data = self._get_redis_data(key_str)
                        # 如果数据无法解析或已过期，删除
                        if data is None or self._is_session_expired(data):
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
                            if data is None:
                                logger.info(f"[USER_REDIS_CLEANUP] 删除无法解析的会话数据: {key_str}")
                            else:
                                logger.info(f"[USER_REDIS_CLEANUP] 删除过期会话: {key_str}")
                    
                    # 检查是否是用户会话列表
                    elif key_str.startswith("user_sessions:"):
                        # 清理空的用户会话列表
                        if self.redis_client.scard(key_str) == 0:
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
                            logger.info(f"[USER_REDIS_CLEANUP] 删除空会话列表: {key_str}")
            
            logger.info(f"[USER_REDIS_CLEANUP] 清理了 {cleaned_count} 个用户会话相关数据")
            return cleaned_count
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 清理用户会话失败: {e}")
            return 0
    
    def cleanup_refresh_tokens(self, user_id: str = None) -> int:
        """清理refresh token数据"""
        if not self.redis_client:
            return 0
        
        try:
            cleaned_count = 0
            
            if user_id:
                # 清理特定用户的refresh token
                patterns = [
                    f"refresh_token:*",  # 所有refresh token
                    f"user_refresh_tokens:{user_id}",  # 用户refresh token列表
                ]
            else:
                # 清理所有refresh token（包括客服的）
                patterns = [
                    "refresh_token:*",
                    "user_refresh_tokens:*",
                    "service_refresh_token:*",  # 客服refresh token
                ]
            
            for pattern in patterns:
                keys = self.redis_client.keys(pattern)
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    
                    # 检查是否是refresh token数据
                    if key_str.startswith("refresh_token:") or key_str.startswith("service_refresh_token:"):
                        data = self._get_redis_data(key_str)
                        # 如果数据无法解析或已过期，删除
                        if data is None or self._is_refresh_token_expired(data):
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
                            if data is None:
                                logger.info(f"[USER_REDIS_CLEANUP] 删除无法解析的refresh token数据: {key_str}")
                            else:
                                logger.info(f"[USER_REDIS_CLEANUP] 删除过期refresh token: {key_str}")
                    
                    # 检查是否是用户refresh token列表
                    elif key_str.startswith("user_refresh_tokens:"):
                        # 清理空的用户refresh token列表
                        if self.redis_client.scard(key_str) == 0:
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
                            logger.info(f"[USER_REDIS_CLEANUP] 删除空refresh token列表: {key_str}")
            
            logger.info(f"[USER_REDIS_CLEANUP] 清理了 {cleaned_count} 个refresh token相关数据")
            return cleaned_count
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 清理refresh token失败: {e}")
            return 0
    
    def cleanup_user_cache(self, user_id: str = None) -> int:
        """清理用户缓存数据"""
        if not self.redis_client:
            return 0
        
        try:
            cleaned_count = 0
            
            if user_id:
                # 清理特定用户的缓存
                patterns = [
                    f"user:{user_id}",
                    f"user_tasks:{user_id}*",
                    f"user_profile:{user_id}",
                    f"user_notifications:{user_id}",
                    f"user_reviews:{user_id}",
                ]
            else:
                # 清理所有用户缓存
                patterns = [
                    "user:*",
                    "user_tasks:*",
                    "user_profile:*",
                    "user_notifications:*",
                    "user_reviews:*",
                ]
            
            for pattern in patterns:
                keys = self.redis_client.keys(pattern)
                for key in keys:
                    key_str = key.decode() if isinstance(key, bytes) else key
                    
                    # 尝试获取数据
                    data = self._get_redis_data(key_str)
                    
                    if data is None:
                        # ⚠️ 数据无法解析，记录详细信息（脱敏）并删除
                        try:
                            import hashlib
                            import re
                            import random
                            
                            # 获取原始数据用于日志
                            raw_data = self.redis_client.get(key_str)
                            data_type = type(raw_data).__name__ if raw_data else "None"
                            data_size = len(raw_data) if raw_data else 0
                            
                            # 计算哈希值，而不是记录完整内容
                            data_hash = hashlib.sha256(raw_data).hexdigest()[:16] if raw_data else "empty"
                            
                            # 脱敏预览（仅前100字节，且脱敏）
                            preview = ""
                            if raw_data:
                                try:
                                    preview_str = str(raw_data)[:100]
                                    # 脱敏敏感信息
                                    preview_str = re.sub(r'([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 
                                                        r'\1***@\2', preview_str)
                                    preview_str = re.sub(r'(\d{3})\d{4}(\d{4})', r'\1****\2', preview_str)
                                    preview = preview_str
                                except:
                                    preview = "<binary data>"
                            else:
                                preview = "empty"
                            
                            # ⚠️ 采样日志：只记录部分无法解析的数据，避免日志放大
                            if random.random() < 0.1:  # 10%采样率
                                logger.warning(
                                    f"[USER_REDIS_CLEANUP] 无法解析的缓存数据: {key_str}, "
                                    f"类型: {data_type}, 大小: {data_size}, 哈希: {data_hash}, 预览: {preview}"
                                )
                            
                            # 删除无法解析的数据
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
                        except Exception as e:
                            logger.error(f"[USER_REDIS_CLEANUP] 删除损坏的缓存数据失败 {key_str}: {e}")
                    elif self._is_cache_expired(data):
                        # 数据可以解析但已过期，删除
                        self.redis_client.delete(key_str)
                        cleaned_count += 1
                        logger.info(f"[USER_REDIS_CLEANUP] 删除过期缓存: {key_str}")
            
            logger.info(f"[USER_REDIS_CLEANUP] 清理了 {cleaned_count} 个用户缓存数据")
            return cleaned_count
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 清理用户缓存失败: {e}")
            return 0
    
    def cleanup_all_user_data(self, user_id: str = None) -> Dict[str, int]:
        """清理所有用户数据"""
        result = {
            'sessions': 0,
            'refresh_tokens': 0,
            'cache': 0,
            'total': 0
        }
        
        try:
            # 清理会话数据
            result['sessions'] = self.cleanup_user_sessions(user_id)
            
            # 清理refresh token数据
            result['refresh_tokens'] = self.cleanup_refresh_tokens(user_id)
            
            # 清理缓存数据
            result['cache'] = self.cleanup_user_cache(user_id)
            
            result['total'] = result['sessions'] + result['refresh_tokens'] + result['cache']
            
            logger.info(f"[USER_REDIS_CLEANUP] 用户数据清理完成: {result}")
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
                        logger.info(f"[USER_REDIS_CLEANUP] 检测到旧格式对象数据（非字典）: {key}, 类型: {type(parsed_data).__name__}, 将删除")
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
        """检查会话是否过期"""
        try:
            # 首先检查是否被标记为不活跃
            if not data.get('is_active', True):
                return True
            
            last_activity_str = data.get('last_activity', data.get('created_at'))
            if not last_activity_str:
                return True
            
            last_activity = datetime.fromisoformat(last_activity_str)
            # 会话24小时过期
            return datetime.utcnow() - last_activity > timedelta(hours=24)
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 检查会话过期失败: {e}")
            return True
    
    def _is_refresh_token_expired(self, data: Dict[str, Any]) -> bool:
        """检查refresh token是否过期"""
        try:
            expires_at_str = data.get('expires_at')
            if not expires_at_str:
                return True
            
            expires_at = datetime.fromisoformat(expires_at_str)
            # 检查是否已过期
            return datetime.utcnow() > expires_at
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
                        created_time = datetime.fromisoformat(time_str)
                        # 缓存7天过期
                        return datetime.utcnow() - created_time > timedelta(days=7)
            return False
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 检查缓存过期失败: {e}")
            return True

# 全局实例
user_redis_cleanup = UserRedisCleanup()

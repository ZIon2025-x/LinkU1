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
                        if data and self._is_session_expired(data):
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
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
                        if data and self._is_refresh_token_expired(data):
                            self.redis_client.delete(key_str)
                            cleaned_count += 1
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
                    
                    # 检查缓存是否过期
                    data = self._get_redis_data(key_str)
                    if data and self._is_cache_expired(data):
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
                if data and self._is_session_expired(data):
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
                if data and self._is_refresh_token_expired(data):
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
                    if data and self._is_cache_expired(data):
                        stats['expired_cache'] += 1
            
            return stats
            
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 获取用户数据统计失败: {e}")
            return {}
    
    def _get_redis_data(self, key: str) -> Dict[str, Any]:
        """安全获取Redis数据"""
        try:
            data = self.redis_client.get(key)
            if not data:
                return None
            
            # 尝试解码bytes数据
            if isinstance(data, bytes):
                try:
                    # 首先尝试utf-8
                    data = data.decode('utf-8')
                except UnicodeDecodeError:
                    # 如果utf-8失败，尝试latin-1（兼容所有字节值）
                    data = data.decode('latin-1')
            
            # 尝试解析JSON
            import json
            parsed_data = json.loads(data)
            
            # 如果解码得到的是字符串，再次尝试解析
            if isinstance(parsed_data, str):
                parsed_data = json.loads(parsed_data)
            
            return parsed_data
        except (UnicodeDecodeError, json.JSONDecodeError) as e:
            logger.error(f"[USER_REDIS_CLEANUP] 获取Redis数据失败 {key}: {e}")
            return None
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 获取Redis数据失败 {key}: {e}")
            return None
    
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

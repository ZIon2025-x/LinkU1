"""
定期清理任务模块
用于清理过期的会话、缓存等数据
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

class CleanupTasks:
    """清理任务管理器"""
    
    def __init__(self):
        self.running = False
        self.cleanup_interval = 3600  # 1小时清理一次
    
    async def start_cleanup_tasks(self):
        """启动清理任务"""
        if self.running:
            logger.warning("清理任务已在运行中")
            return
        
        self.running = True
        logger.info("启动定期清理任务")
        
        try:
            while self.running:
                await self._run_cleanup_cycle()
                await asyncio.sleep(self.cleanup_interval)
        except Exception as e:
            logger.error(f"清理任务异常: {e}")
        finally:
            self.running = False
            logger.info("清理任务已停止")
    
    async def _run_cleanup_cycle(self):
        """执行一轮清理任务"""
        try:
            logger.info("开始执行清理任务")
            
            # 清理过期会话
            await self._cleanup_expired_sessions()
            
            # 清理过期缓存
            await self._cleanup_expired_cache()
            
            logger.info("清理任务完成")
            
        except Exception as e:
            logger.error(f"清理任务执行失败: {e}")
    
    async def _cleanup_expired_sessions(self):
        """清理过期会话"""
        try:
            from app.secure_auth import SecureAuthManager
            from app.service_auth import ServiceAuthManager
            from app.admin_auth import AdminAuthManager
            from app.user_redis_cleanup import user_redis_cleanup
            
            # 清理用户会话
            SecureAuthManager.cleanup_expired_sessions()
            
            # 清理客服会话
            ServiceAuthManager.cleanup_expired_sessions()
            
            # 清理管理员会话
            AdminAuthManager.cleanup_expired_sessions()
            
            # 清理用户Redis数据
            user_redis_cleanup.cleanup_all_user_data()
            
        except Exception as e:
            logger.error(f"清理过期会话失败: {e}")
    
    async def _cleanup_expired_cache(self):
        """清理过期缓存"""
        try:
            from app.redis_cache import redis_cache
            
            if redis_cache.enabled:
                # 清理过期的缓存键
                patterns = [
                    "user:*",
                    "user_tasks:*",
                    "user_profile:*",
                    "user_notifications:*",
                    "user_reviews:*",
                    "tasks:*",
                    "task_detail:*",
                    "notifications:*",
                    "system_settings:*"
                ]
                
                total_cleaned = 0
                for pattern in patterns:
                    # 获取所有匹配的键
                    keys = redis_cache.redis_client.keys(pattern)
                    if keys:
                        # 检查每个键的TTL
                        for key in keys:
                            ttl = redis_cache.get_ttl(key)
                            if ttl == -1:  # 没有设置TTL的键
                                # 检查键的内容是否包含时间戳
                                data = redis_cache.get(key)
                                if data and isinstance(data, dict):
                                    # 如果数据包含时间戳，检查是否过期
                                    if 'created_at' in data or 'last_activity' in data:
                                        time_str = data.get('last_activity', data.get('created_at'))
                                        if time_str:
                                            try:
                                                created_time = datetime.fromisoformat(time_str)
                                                # 如果超过7天，删除
                                                if datetime.utcnow() - created_time > timedelta(days=7):
                                                    redis_cache.delete(key)
                                                    total_cleaned += 1
                                            except:
                                                pass
                
                if total_cleaned > 0:
                    logger.info(f"清理了 {total_cleaned} 个过期缓存项")
                    
        except Exception as e:
            logger.error(f"清理过期缓存失败: {e}")
    
    def stop_cleanup_tasks(self):
        """停止清理任务"""
        self.running = False
        logger.info("停止清理任务")

# 全局清理任务实例
cleanup_tasks = CleanupTasks()

async def start_background_cleanup():
    """启动后台清理任务"""
    await cleanup_tasks.start_cleanup_tasks()

def stop_background_cleanup():
    """停止后台清理任务"""
    cleanup_tasks.stop_cleanup_tasks()

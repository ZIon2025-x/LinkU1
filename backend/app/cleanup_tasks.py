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
        self.last_completed_tasks_cleanup_date = None  # 上次清理已完成任务的日期
    
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
            
            # 清理已完成和过期任务的文件（每天检查一次）
            await self._cleanup_completed_tasks_files()
            await self._cleanup_expired_tasks_files()
            
            # 清理未使用的临时图片（每天检查一次）
            await self._cleanup_unused_temp_images()
            
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
    
    async def _cleanup_completed_tasks_files(self):
        """清理已完成超过3天的任务的图片和文件（每天检查一次）"""
        try:
            # 检查今天是否已经清理过
            today = datetime.utcnow().date()
            if self.last_completed_tasks_cleanup_date == today:
                # 今天已经清理过，跳过
                return
            
            from app.deps import get_sync_db
            from app.crud import cleanup_completed_tasks_files
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数
                cleaned_count = cleanup_completed_tasks_files(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个已完成任务的文件")
                # 更新最后清理日期
                self.last_completed_tasks_cleanup_date = today
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理已完成任务文件失败: {e}")
    
    async def _cleanup_expired_tasks_files(self):
        """清理过期任务（已取消或deadline已过超过3天）的文件（每天检查一次）"""
        try:
            # 检查今天是否已经清理过
            today = datetime.utcnow().date()
            if self.last_completed_tasks_cleanup_date == today:
                # 今天已经清理过，跳过
                return
            
            from app.deps import get_sync_db
            from app.crud import cleanup_expired_tasks_files
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数
                cleaned_count = cleanup_expired_tasks_files(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个过期任务的文件")
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理过期任务文件失败: {e}")
    
    async def _cleanup_unused_temp_images(self):
        """清理未使用的临时图片（超过24小时未使用的临时图片）"""
        try:
            from pathlib import Path
            import os
            from datetime import datetime, timedelta
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_public_dir = Path("/data/uploads/public/images")
            else:
                base_public_dir = Path("uploads/public/images")
            
            temp_base_dir = base_public_dir / "public"
            
            # 如果临时文件夹不存在，直接返回
            if not temp_base_dir.exists():
                return
            
            # 计算24小时前的时间
            cutoff_time = datetime.now() - timedelta(hours=24)
            cleaned_count = 0
            
            # 遍历所有临时文件夹（temp_*）
            for temp_dir in temp_base_dir.iterdir():
                if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                    try:
                        # 检查文件夹中的文件
                        for file_path in temp_dir.iterdir():
                            if file_path.is_file():
                                # 获取文件的修改时间
                                file_mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
                                
                                # 如果文件超过24小时未修改，删除它
                                if file_mtime < cutoff_time:
                                    try:
                                        file_path.unlink()
                                        cleaned_count += 1
                                        logger.info(f"删除未使用的临时图片: {file_path}")
                                    except Exception as e:
                                        logger.warning(f"删除临时图片失败 {file_path}: {e}")
                        
                        # 如果文件夹为空，尝试删除它
                        try:
                            if not any(temp_dir.iterdir()):
                                temp_dir.rmdir()
                                logger.info(f"删除空的临时文件夹: {temp_dir}")
                        except Exception as e:
                            logger.debug(f"删除临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                            
                    except Exception as e:
                        logger.warning(f"处理临时文件夹失败 {temp_dir}: {e}")
                        continue
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个未使用的临时图片")
                
        except Exception as e:
            logger.error(f"清理未使用临时图片失败: {e}")
    
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

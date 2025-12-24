"""
定期清理任务模块
用于清理过期的会话、缓存等数据
"""

import asyncio
import logging
import time
from datetime import datetime, timedelta
from typing import Optional
from app.utils.time_utils import get_utc_time, parse_iso_utc

logger = logging.getLogger(__name__)


def get_redis_distributed_lock(lock_key: str, lock_ttl: int = 3600) -> bool:
    """
    获取 Redis 分布式锁（使用 SETNX）
    返回 True 表示获取成功，False 表示锁已被占用
    
    Args:
        lock_key: 锁的键名
        lock_ttl: 锁的过期时间（秒），默认1小时
    
    Returns:
        bool: 是否成功获取锁
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if not redis_client:
            # Redis 不可用时，返回 True（允许执行，但会有多实例重复执行的风险）
            logger.warning(f"Redis 不可用，跳过分布式锁检查: {lock_key}")
            return True
        
        # 使用 SETNX 原子操作获取锁
        # SET key value NX EX ttl
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
        return True  # 出错时允许执行，避免因锁机制故障导致任务无法执行


def release_redis_distributed_lock(lock_key: str):
    """
    释放 Redis 分布式锁
    
    Args:
        lock_key: 锁的键名
    """
    try:
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            redis_client.delete(lock_key)
            logger.debug(f"释放分布式锁: {lock_key}")
    except Exception as e:
        logger.warning(f"释放分布式锁失败 {lock_key}: {e}")

class CleanupTasks:
    """清理任务管理器"""
    
    def __init__(self):
        self.running = False
        self.cleanup_interval = 3600  # 1小时清理一次
        self.last_completed_tasks_cleanup_date = None  # 上次清理已完成任务的日期
        self.last_expired_tasks_cleanup_date = None  # 上次清理过期任务的日期
        self.last_orphan_files_cleanup_date = None  # 上次清理孤立文件的日期
    
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
            
            # 清理过期跳蚤市场商品（每天检查一次）
            await self._cleanup_expired_flea_market_items()
            
            # 清理未使用的临时图片（每次循环都执行）
            await self._cleanup_unused_temp_images()
            
            # 清理孤立文件（每周检查一次）
            await self._cleanup_orphan_files()
            
            # 清理不存在实体的图片文件夹（每周检查一次）
            await self._cleanup_orphan_entity_images()
            
            # 清理旧格式图片（直接保存在 /uploads/images/ 下的，每周检查一次）
            await self._cleanup_old_format_images()
            
            # 清理过期时间段（每天检查一次）
            await self._cleanup_expired_time_slots()
            
            # 自动生成未来时间段（每天检查一次）
            # ⚠️ 已禁用：不需要每天新增时间段服务的下一个时间段
            # await self._auto_generate_future_time_slots()
            
            logger.info("清理任务完成")
            
        except Exception as e:
            logger.error(f"清理任务执行失败: {e}")
    
    async def _cleanup_expired_sessions(self):
        """
        清理过期会话（每小时执行一次，使用分布式锁）
        注意：此任务已与 run_session_cleanup_task 合并，降低频率以避免重复清理
        """
        lock_key = "scheduled_task:cleanup_expired_sessions:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期会话：其他实例正在执行，跳过")
            return
        
        try:
            # 统一调用清理函数（与 run_session_cleanup_task 使用相同的逻辑）
            from app.main import cleanup_all_sessions_unified
            cleanup_all_sessions_unified()
            
        except Exception as e:
            logger.error(f"清理过期会话失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
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
                                                created_time = parse_iso_utc(time_str)
                                                # 如果超过7天，删除
                                                if get_utc_time() - created_time > timedelta(days=7):
                                                    redis_cache.delete(key)
                                                    total_cleaned += 1
                                            except:
                                                pass
                
                if total_cleaned > 0:
                    logger.info(f"清理了 {total_cleaned} 个过期缓存项")
                    
        except Exception as e:
            logger.error(f"清理过期缓存失败: {e}")
    
    async def _cleanup_completed_tasks_files(self):
        """清理已完成超过3天的任务的图片和文件（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_completed_tasks_files:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理已完成任务文件：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_completed_tasks_files
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数
                cleaned_count = cleanup_completed_tasks_files(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个已完成任务的文件")
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理已完成任务文件失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_expired_tasks_files(self):
        """清理过期任务（已取消或deadline已过超过3天）的文件（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_expired_tasks_files:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期任务文件：其他实例正在执行，跳过")
            return
        
        try:
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
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_expired_flea_market_items(self):
        """清理超过10天未刷新的跳蚤市场商品（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_expired_flea_market_items:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期跳蚤市场商品：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_expired_flea_market_items
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数
                cleaned_count = cleanup_expired_flea_market_items(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个过期跳蚤市场商品")
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理过期跳蚤市场商品失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_unused_temp_images(self):
        """清理未使用的临时图片（超过24小时未使用的临时图片，使用分布式锁和限流）"""
        lock_key = "scheduled_task:cleanup_unused_temp_images:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理未使用临时图片：其他实例正在执行，跳过")
            return
        
        try:
            from pathlib import Path
            import os
            from datetime import timedelta
            from app.utils.time_utils import get_utc_time, file_timestamp_to_utc
            
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
            cutoff_time = get_utc_time() - timedelta(hours=24)
            cleaned_count = 0
            max_files_per_run = 1000  # 每次最多处理1000个文件，避免IO压力过大
            
            # 遍历所有临时文件夹（temp_*）
            for temp_dir in temp_base_dir.iterdir():
                if cleaned_count >= max_files_per_run:
                    logger.info(f"已达到单次处理上限（{max_files_per_run}），停止处理")
                    break
                    
                if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                    try:
                        # 收集需要删除的文件（按修改时间排序，优先删除最旧的）
                        files_to_delete = []
                        for file_path in temp_dir.iterdir():
                            if file_path.is_file():
                                file_mtime = file_timestamp_to_utc(file_path.stat().st_mtime)
                                if file_mtime < cutoff_time:
                                    files_to_delete.append((file_mtime, file_path))
                        
                        # 按时间排序，优先删除最旧的
                        files_to_delete.sort(key=lambda x: x[0])
                        
                        # 限制本次处理的文件数量
                        files_to_delete = files_to_delete[:max_files_per_run - cleaned_count]
                        
                        # 删除文件
                        for _, file_path in files_to_delete:
                            try:
                                file_path.unlink()
                                cleaned_count += 1
                                if cleaned_count % 100 == 0:
                                    logger.debug(f"已清理 {cleaned_count} 个临时图片...")
                            except Exception as e:
                                logger.warning(f"删除临时图片失败 {file_path}: {e}")
                        
                        # 如果文件夹为空，尝试删除它
                        try:
                            if not any(temp_dir.iterdir()):
                                temp_dir.rmdir()
                                logger.debug(f"删除空的临时文件夹: {temp_dir}")
                        except Exception as e:
                            logger.debug(f"删除临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                            
                    except Exception as e:
                        logger.warning(f"处理临时文件夹失败 {temp_dir}: {e}")
                        continue
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个未使用的临时图片")
            
            # 清理跳蚤市场临时图片
            await self._cleanup_flea_market_temp_images()
            
            # 清理榜单封面临时图片
            await self._cleanup_leaderboard_covers_temp_images()
                
        except Exception as e:
            logger.error(f"清理未使用临时图片失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_flea_market_temp_images(self):
        """清理跳蚤市场临时图片（超过24小时未使用的临时图片）"""
        try:
            from pathlib import Path
            import os
            import shutil
            from datetime import timedelta
            from app.utils.time_utils import get_utc_time, file_timestamp_to_utc
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_dir = Path("/data/uploads")
            else:
                base_dir = Path("uploads")
            
            temp_base_dir = base_dir / "flea_market"
            
            # 如果临时文件夹不存在，直接返回
            if not temp_base_dir.exists():
                return
            
            # 计算24小时前的时间
            cutoff_time = get_utc_time() - timedelta(hours=24)
            cleaned_count = 0
            
            # 遍历所有临时文件夹（temp_*）
            for temp_dir in temp_base_dir.iterdir():
                if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                    try:
                        # 检查文件夹中的文件
                        files_deleted = False
                        for file_path in temp_dir.iterdir():
                            if file_path.is_file():
                                # 获取文件的修改时间（使用统一时间工具函数）
                                file_mtime = file_timestamp_to_utc(file_path.stat().st_mtime)
                                
                                # 如果文件超过24小时未修改，删除它
                                if file_mtime < cutoff_time:
                                    try:
                                        file_path.unlink()
                                        cleaned_count += 1
                                        files_deleted = True
                                        logger.info(f"删除未使用的跳蚤市场临时图片: {file_path}")
                                    except Exception as e:
                                        logger.warning(f"删除跳蚤市场临时图片失败 {file_path}: {e}")
                        
                        # 如果文件夹为空，尝试删除它
                        try:
                            if not any(temp_dir.iterdir()):
                                temp_dir.rmdir()
                                logger.info(f"删除空的跳蚤市场临时文件夹: {temp_dir}")
                        except Exception as e:
                            logger.debug(f"删除跳蚤市场临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                            
                    except Exception as e:
                        logger.warning(f"处理跳蚤市场临时文件夹失败 {temp_dir}: {e}")
                        continue
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个未使用的跳蚤市场临时图片")
                
        except Exception as e:
            logger.error(f"清理跳蚤市场临时图片失败: {e}")
    
    async def _cleanup_leaderboard_covers_temp_images(self):
        """清理榜单封面临时图片（超过24小时未使用的临时图片）"""
        try:
            from pathlib import Path
            import os
            import shutil
            from datetime import timedelta
            from app.utils.time_utils import get_utc_time, file_timestamp_to_utc
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_dir = Path("/data/uploads/public/images")
            else:
                base_dir = Path("uploads/public/images")
            
            temp_base_dir = base_dir / "leaderboard_covers"
            
            # 如果临时文件夹不存在，直接返回
            if not temp_base_dir.exists():
                return
            
            # 计算24小时前的时间
            cutoff_time = get_utc_time() - timedelta(hours=24)
            cleaned_count = 0
            
            # 遍历所有临时文件夹（temp_*）
            for temp_dir in temp_base_dir.iterdir():
                if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                    try:
                        # 检查文件夹中的文件
                        files_deleted = False
                        for file_path in temp_dir.iterdir():
                            if file_path.is_file():
                                # 获取文件的修改时间（使用统一时间工具函数）
                                file_mtime = file_timestamp_to_utc(file_path.stat().st_mtime)
                                
                                # 如果文件超过24小时未修改，删除它
                                if file_mtime < cutoff_time:
                                    try:
                                        file_path.unlink()
                                        cleaned_count += 1
                                        files_deleted = True
                                        logger.info(f"删除未使用的榜单封面临时图片: {file_path}")
                                    except Exception as e:
                                        logger.warning(f"删除榜单封面临时图片失败 {file_path}: {e}")
                        
                        # 如果文件夹为空，尝试删除它
                        try:
                            if not any(temp_dir.iterdir()):
                                temp_dir.rmdir()
                                logger.info(f"删除空的榜单封面临时文件夹: {temp_dir}")
                        except Exception as e:
                            logger.debug(f"删除榜单封面临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                            
                    except Exception as e:
                        logger.warning(f"处理榜单封面临时文件夹失败 {temp_dir}: {e}")
                        continue
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个未使用的榜单封面临时图片")
                
        except Exception as e:
            logger.error(f"清理榜单封面临时图片失败: {e}")
    
    async def _cleanup_orphan_files(self):
        """清理孤立文件（不在预期位置的文件，超过7天未使用，每周检查一次，使用分布式锁）"""
        # 检查是否已经在本周执行过
        today = get_utc_time().date()
        if self.last_orphan_files_cleanup_date == today:
            return
        
        lock_key = "scheduled_task:cleanup_orphan_files:lock"
        lock_ttl = 7200  # 2小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理孤立文件：其他实例正在执行，跳过")
            return
        
        try:
            from pathlib import Path
            import os
            from datetime import timedelta
            from app.utils.time_utils import file_timestamp_to_utc
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_upload_dir = Path("/data/uploads")
            else:
                base_upload_dir = Path("uploads")
            
            # 计算7天前的时间
            cutoff_time = get_utc_time() - timedelta(days=7)
            cleaned_count = 0
            max_files_per_run = 500  # 每次最多处理500个文件，避免IO压力过大
            
            # 定义预期的目录结构（允许的子目录）
            expected_dirs = {
                # 公开图片目录
                base_upload_dir / "public" / "images" / "expert_avatars": True,  # 允许任意子目录
                base_upload_dir / "public" / "images" / "service_images": True,
                base_upload_dir / "public" / "images" / "public": True,  # 允许 task_id 或 temp_* 子目录
                base_upload_dir / "public" / "images" / "leaderboard_items": True,  # 允许 item_id 或 temp_* 子目录
                base_upload_dir / "public" / "images" / "leaderboard_covers": True,  # 允许 leaderboard_id 或 temp_* 子目录
                # 公开文件目录
                base_upload_dir / "public" / "files": False,  # 不允许子目录，文件直接在此目录
                # 私密图片目录
                base_upload_dir / "private_images" / "tasks": True,
                base_upload_dir / "private_images" / "chats": True,
                # 私密文件目录
                base_upload_dir / "private_files" / "tasks": True,
                base_upload_dir / "private_files" / "chats": True,
                # 跳蚤市场目录
                base_upload_dir / "flea_market": True,  # 允许 item_id 或 temp_* 子目录
            }
            
            # 递归扫描上传目录，找出不在预期位置的文件
            def scan_directory(dir_path: Path, depth: int = 0, max_depth: int = 5):
                """递归扫描目录，找出孤立文件"""
                nonlocal cleaned_count
                
                if cleaned_count >= max_files_per_run:
                    return
                
                if not dir_path.exists() or not dir_path.is_dir():
                    return
                
                # 检查是否在预期目录中
                is_expected = False
                for expected_dir, allow_subdirs in expected_dirs.items():
                    try:
                        # 检查当前目录是否是预期目录或其子目录
                        if dir_path == expected_dir:
                            is_expected = True
                            break
                        elif allow_subdirs and expected_dir in dir_path.parents:
                            # 在预期目录的子目录中
                            is_expected = True
                            break
                    except Exception:
                        continue
                
                # 如果不在预期目录中，且深度超过1，则可能是孤立文件
                if not is_expected and depth > 0:
                    # 检查目录中的文件
                    try:
                        for item in dir_path.iterdir():
                            if cleaned_count >= max_files_per_run:
                                return
                            
                            if item.is_file():
                                # 检查文件修改时间
                                try:
                                    file_mtime = file_timestamp_to_utc(item.stat().st_mtime)
                                    if file_mtime < cutoff_time:
                                        # 超过7天未使用，删除
                                        item.unlink()
                                        cleaned_count += 1
                                        logger.info(f"删除孤立文件: {item}")
                                except Exception as e:
                                    logger.warning(f"处理孤立文件失败 {item}: {e}")
                            elif item.is_dir() and depth < max_depth:
                                # 递归扫描子目录
                                scan_directory(item, depth + 1, max_depth)
                    except Exception as e:
                        logger.warning(f"扫描目录失败 {dir_path}: {e}")
                else:
                    # 在预期目录中，正常递归扫描（但不删除）
                    try:
                        for item in dir_path.iterdir():
                            if item.is_dir() and depth < max_depth:
                                scan_directory(item, depth + 1, max_depth)
                    except Exception as e:
                        logger.warning(f"扫描预期目录失败 {dir_path}: {e}")
            
            # 从上传根目录开始扫描
            if base_upload_dir.exists():
                scan_directory(base_upload_dir, depth=0, max_depth=5)
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个孤立文件")
                self.last_orphan_files_cleanup_date = today
            else:
                logger.debug("未发现需要清理的孤立文件")
                self.last_orphan_files_cleanup_date = today
                
        except Exception as e:
            logger.error(f"清理孤立文件失败: {e}", exc_info=True)
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_orphan_entity_images(self):
        """清理不存在实体的图片文件夹（竞品、商品、任务），每周检查一次，使用分布式锁"""
        # 检查是否已经在本周执行过
        today = get_utc_time().date()
        if self.last_orphan_files_cleanup_date == today:
            return
        
        lock_key = "scheduled_task:cleanup_orphan_entity_images:lock"
        lock_ttl = 7200  # 2小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理不存在实体的图片文件夹：其他实例正在执行，跳过")
            return
        
        try:
            from pathlib import Path
            import os
            import shutil
            from app.deps import get_sync_db
            from app import models
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_upload_dir = Path("/data/uploads")
            else:
                base_upload_dir = Path("uploads")
            
            cleaned_count = 0
            max_dirs_per_run = 100  # 每次最多处理100个目录，避免IO压力过大
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 1. 清理不存在竞品的图片文件夹
                leaderboard_items_dir = base_upload_dir / "public" / "images" / "leaderboard_items"
                if leaderboard_items_dir.exists():
                    # 获取所有存在的竞品ID
                    from sqlalchemy import select
                    items_result = db.execute(select(models.LeaderboardItem.id))
                    existing_item_ids = {item_id for item_id, in items_result.all()}
                    
                    # 遍历目录，找出不存在的竞品ID对应的文件夹
                    for item_dir in leaderboard_items_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if item_dir.is_dir() and not item_dir.name.startswith("temp_"):
                            try:
                                item_id = int(item_dir.name)
                                if item_id not in existing_item_ids:
                                    # 竞品不存在，删除文件夹
                                    shutil.rmtree(item_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在竞品 {item_id} 的图片文件夹: {item_dir}")
                            except (ValueError, Exception) as e:
                                # 如果无法解析为整数，可能是无效的目录名，跳过
                                logger.debug(f"跳过无效的竞品目录: {item_dir.name}: {e}")
                                continue
                
                # 2. 清理不存在商品的图片文件夹
                flea_market_dir = base_upload_dir / "flea_market"
                if flea_market_dir.exists():
                    # 获取所有存在的商品ID
                    from sqlalchemy import select
                    items_result = db.execute(select(models.FleaMarketItem.id))
                    existing_flea_item_ids = {item_id for item_id, in items_result.all()}
                    
                    # 遍历目录，找出不存在的商品ID对应的文件夹
                    for item_dir in flea_market_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if item_dir.is_dir() and not item_dir.name.startswith("temp_"):
                            try:
                                item_id = int(item_dir.name)
                                if item_id not in existing_flea_item_ids:
                                    # 商品不存在，删除文件夹
                                    shutil.rmtree(item_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在商品 {item_id} 的图片文件夹: {item_dir}")
                            except (ValueError, Exception) as e:
                                # 如果无法解析为整数，可能是无效的目录名，跳过
                                logger.debug(f"跳过无效的商品目录: {item_dir.name}: {e}")
                                continue
                
                # 3. 清理不存在任务的图片文件夹
                tasks_public_dir = base_upload_dir / "public" / "images" / "public"
                if tasks_public_dir.exists():
                    # 获取所有存在的任务ID
                    from sqlalchemy import select
                    tasks_result = db.execute(select(models.Task.id))
                    existing_task_ids = {task_id for task_id, in tasks_result.all()}
                    
                    # 遍历目录，找出不存在的任务ID对应的文件夹
                    for task_dir in tasks_public_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if task_dir.is_dir() and not task_dir.name.startswith("temp_"):
                            try:
                                task_id = int(task_dir.name)
                                if task_id not in existing_task_ids:
                                    # 任务不存在，删除文件夹
                                    shutil.rmtree(task_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在任务 {task_id} 的图片文件夹: {task_dir}")
                            except (ValueError, Exception) as e:
                                # 如果无法解析为整数，可能是无效的目录名，跳过
                                logger.debug(f"跳过无效的任务目录: {task_dir.name}: {e}")
                                continue
                
                # 4. 清理不存在用户的头像文件夹
                expert_avatars_dir = base_upload_dir / "public" / "images" / "expert_avatars"
                if expert_avatars_dir.exists():
                    # 获取所有存在的用户ID（任务达人头像使用用户ID）
                    from sqlalchemy import select
                    users_result = db.execute(select(models.User.id))
                    existing_user_ids = {user_id for user_id, in users_result.all()}
                    
                    # 遍历目录，找出不存在的用户ID对应的文件夹
                    for user_dir in expert_avatars_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if user_dir.is_dir():
                            try:
                                user_id = user_dir.name
                                if user_id not in existing_user_ids:
                                    # 用户不存在，删除头像文件夹
                                    shutil.rmtree(user_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在用户 {user_id} 的头像文件夹: {user_dir}")
                            except Exception as e:
                                logger.debug(f"跳过无效的用户头像目录: {user_dir.name}: {e}")
                                continue
                
                # 5. 清理不存在任务达人的服务图片文件夹
                service_images_dir = base_upload_dir / "public" / "images" / "service_images"
                if service_images_dir.exists():
                    # 获取所有存在的任务达人ID
                    from sqlalchemy import select
                    experts_result = db.execute(select(models.TaskExpert.id))
                    existing_expert_ids = {expert_id for expert_id, in experts_result.all()}
                    
                    # 遍历目录，找出不存在的任务达人ID对应的文件夹
                    for expert_dir in service_images_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if expert_dir.is_dir():
                            try:
                                expert_id = expert_dir.name
                                if expert_id not in existing_expert_ids:
                                    # 任务达人不存在，删除服务图片文件夹
                                    shutil.rmtree(expert_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在任务达人 {expert_id} 的服务图片文件夹: {expert_dir}")
                            except Exception as e:
                                logger.debug(f"跳过无效的服务图片目录: {expert_dir.name}: {e}")
                                continue
                
                # 6. 清理不存在Banner的图片文件夹
                banner_dir = base_upload_dir / "public" / "images" / "banner"
                if banner_dir.exists():
                    # 获取所有存在的Banner ID
                    from sqlalchemy import select
                    banners_result = db.execute(select(models.Banner.id))
                    existing_banner_ids = {banner_id for banner_id, in banners_result.all()}
                    
                    # 遍历目录，找出不存在的Banner ID对应的文件夹
                    for banner_item_dir in banner_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        
                        if banner_item_dir.is_dir():
                            try:
                                banner_id = int(banner_item_dir.name)
                                if banner_id not in existing_banner_ids:
                                    # Banner不存在，删除图片文件夹
                                    shutil.rmtree(banner_item_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在Banner {banner_id} 的图片文件夹: {banner_item_dir}")
                            except (ValueError, Exception) as e:
                                logger.debug(f"跳过无效的Banner目录: {banner_item_dir.name}: {e}")
                                continue
                
            finally:
                db.close()
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个不存在实体的图片文件夹")
            else:
                logger.debug("未发现需要清理的不存在实体的图片文件夹")
                
        except Exception as e:
            logger.error(f"清理不存在实体的图片文件夹失败: {e}", exc_info=True)
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_old_format_images(self):
        """清理旧格式图片（直接保存在 /uploads/images/ 下的，不在子目录中），每周检查一次，使用分布式锁"""
        # 检查是否已经在本周执行过
        today = get_utc_time().date()
        if self.last_orphan_files_cleanup_date == today:
            return
        
        lock_key = "scheduled_task:cleanup_old_format_images:lock"
        lock_ttl = 7200  # 2小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理旧格式图片：其他实例正在执行，跳过")
            return
        
        try:
            from pathlib import Path
            import os
            from datetime import timedelta
            from app.utils.time_utils import file_timestamp_to_utc
            
            # 检测部署环境
            RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
            if RAILWAY_ENVIRONMENT:
                base_upload_dir = Path("/data/uploads")
            else:
                base_upload_dir = Path("uploads")
            
            # 旧格式图片可能直接保存在这些位置：
            # - /uploads/images/ (根目录)
            # - /uploads/public/images/ (不在子目录中)
            old_format_dirs = [
                base_upload_dir / "images",  # 旧格式：直接在 images 目录下
                base_upload_dir / "public" / "images",  # 旧格式：直接在 public/images 目录下
            ]
            
            # 计算30天前的时间（旧格式图片如果30天未使用，可能是无用的）
            cutoff_time = get_utc_time() - timedelta(days=30)
            cleaned_count = 0
            max_files_per_run = 200  # 每次最多处理200个文件
            
            for old_dir in old_format_dirs:
                if cleaned_count >= max_files_per_run:
                    break
                
                if not old_dir.exists():
                    continue
                
                # 检查目录中的文件（不包括子目录）
                try:
                    for item in old_dir.iterdir():
                        if cleaned_count >= max_files_per_run:
                            break
                        
                        if item.is_file():
                            # 检查是否是图片文件
                            if item.suffix.lower() in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                                # 检查文件修改时间
                                try:
                                    file_mtime = file_timestamp_to_utc(item.stat().st_mtime)
                                    if file_mtime < cutoff_time:
                                        # 超过30天未使用，删除
                                        item.unlink()
                                        cleaned_count += 1
                                        logger.info(f"删除旧格式图片: {item}")
                                except Exception as e:
                                    logger.warning(f"处理旧格式图片失败 {item}: {e}")
                except Exception as e:
                    logger.warning(f"扫描旧格式图片目录失败 {old_dir}: {e}")
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个旧格式图片")
            else:
                logger.debug("未发现需要清理的旧格式图片")
                
        except Exception as e:
            logger.error(f"清理旧格式图片失败: {e}", exc_info=True)
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_expired_time_slots(self):
        """清理过期时间段（超过30天且任务已完成/取消的时间段，每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_expired_time_slots:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期时间段：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_expired_time_slots
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数
                cleaned_count = cleanup_expired_time_slots(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个过期时间段")
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理过期时间段失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _auto_generate_future_time_slots(self):
        """自动为所有启用了时间段功能的服务生成未来30天的时间段（每天检查一次）"""
        try:
            # 检查今天是否已经生成过
            today = get_utc_time().date()
            if not hasattr(self, 'last_time_slots_generation_date'):
                self.last_time_slots_generation_date = None
            if self.last_time_slots_generation_date == today:
                # 今天已经生成过，跳过
                return
            
            from app.deps import get_sync_db
            from app.crud import auto_generate_future_time_slots
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用生成函数
                generated_count = auto_generate_future_time_slots(db)
                if generated_count > 0:
                    logger.info(f"自动生成了 {generated_count} 个未来时间段")
                # 更新最后生成日期
                self.last_time_slots_generation_date = today
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"自动生成时间段失败: {e}")
    
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

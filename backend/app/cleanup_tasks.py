"""
定期清理任务模块
用于清理过期的会话、缓存等数据

存储后端支持：
- 本地存储（Path）：完全支持所有清理功能
- 云存储（S3/R2）：支持临时图片清理、孤儿实体目录清理
  - 临时图片清理：检查文件年龄，按需删除
  - 孤儿实体目录清理：对比数据库实体ID，删除不存在的目录
  - 注意：孤立文件清理、旧格式图片清理目前仅支持本地存储

小容量挂载卷优化：可通过环境变量调高清理频率、缩短保留期，并开启低磁盘紧急模式。
  CLEANUP_INTERVAL=1800           # 清理周期(秒)，默认 3600，小卷可 1800
  CLEANUP_TEMP_IMAGE_HOURS=12     # 临时图保留小时，默认 24，小卷可 12
  CLEANUP_ORPHAN_FILE_DAYS=3      # 孤立文件保留天数，默认 7，小卷可 3
  CLEANUP_OLD_FORMAT_DAYS=14      # 旧格式图保留天数，默认 30，小卷可 14
  CLEANUP_MAX_FILES_ORPHAN=1000   # 单次孤儿文件上限，默认 500
  CLEANUP_MAX_FILES_TEMP=2000     # 单次临时图上限，默认 1000
  CLEANUP_MAX_DIRS_ORPHAN_ENTITY=200  # 单次孤儿实体目录上限，默认 100
  CLEANUP_LOW_DISK_PERCENT=85     # 设定后：当 uploads 所在分区使用率>=该值，本轮回合
                                  # 临时改用 6h/2天/14天 及 2 倍单次上限
  CLEANUP_COMPLETED_TASK_DAYS=1   # 已完成任务文件保留天数，默认 3（crud）
  CLEANUP_EXPIRED_TASK_DAYS=1     # 过期任务文件保留天数，默认 3（crud）
  CLEANUP_INACTIVE_DEVICE_TOKEN_DAYS=180  # 删除 is_active=False 的令牌记录前保留天数，默认 180
"""

import asyncio
import logging
import os
import shutil
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from app.utils.time_utils import get_utc_time, parse_iso_utc

logger = logging.getLogger(__name__)


def _env_int(key: str, default: int) -> int:
    try:
        return int(os.getenv(key, str(default)))
    except ValueError:
        return default


def _get_base_upload_dir() -> Path:
    return Path("/data/uploads") if os.getenv("RAILWAY_ENVIRONMENT") else Path("uploads")


def _is_low_disk(base: Path) -> bool:
    """当 CLEANUP_LOW_DISK_PERCENT 已设置且 uploads 所在分区使用率>=该值时返回 True"""
    pct = os.getenv("CLEANUP_LOW_DISK_PERCENT")
    if not pct:
        return False
    try:
        u = shutil.disk_usage(str(base.resolve())) if base.exists() else None
        if not u or u.total == 0:
            return False
        return (u.used / u.total) >= (int(pct) / 100.0)
    except Exception:
        return False


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
        self.cleanup_interval = _env_int("CLEANUP_INTERVAL", 3600)
        self.last_completed_tasks_cleanup_date = None  # 同日只跑一次，避免每轮都调 crud
        self.last_expired_tasks_cleanup_date = None
        self.last_flea_cleanup_date = None
        self.last_orphan_files_cleanup_date = None  # 孤立文件：同日一次
        self.last_orphan_entity_cleanup_date = None  # 孤儿实体目录：同日一次（与 orphan_files 独立）
        self.last_old_format_cleanup_date = None  # 旧格式图：同日一次（与 orphan_files 独立）
    
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
            # 清理未使用的临时图片（每次循环都执行，优先释放空间）
            await self._cleanup_unused_temp_images()
            # 清理已完成和过期任务的文件（每天检查一次）
            await self._cleanup_completed_tasks_files()
            await self._cleanup_expired_tasks_files()
            # 清理过期跳蚤市场商品（每天检查一次）
            await self._cleanup_expired_flea_market_items()
            # 清理孤立文件（每周检查一次）
            await self._cleanup_orphan_files()
            # 清理不存在实体的图片文件夹（每周检查一次）
            await self._cleanup_orphan_entity_images()
            # 清理空目录（释放 inode，减轻小卷压力）
            await self._cleanup_empty_dirs()
            # 清理旧格式图片（直接保存在 /uploads/images/ 下的，每周检查一次）
            await self._cleanup_old_format_images()
            
            # 清理过期时间段（每天检查一次）
            await self._cleanup_expired_time_slots()
            
            # 清理过期翻译（每天检查一次）
            await self._cleanup_stale_task_translations()
            
            # 清理重复设备令牌（每天检查一次）
            await self._cleanup_duplicate_device_tokens()
            
            # 删除长期不活跃的无效令牌记录（每天检查一次）
            await self._cleanup_old_inactive_device_tokens()
            
            # 自动生成未来时间段（每天检查一次）
            # ⚠️ 已禁用：不需要每天新增时间段服务的下一个时间段
            # await self._auto_generate_future_time_slots()
            
            logger.info("清理任务完成")
            
        except Exception as e:
            logger.error(f"清理任务执行失败: {e}")
    
    async def _cleanup_expired_sessions(self):
        """清理过期会话
        
        注意: Redis 使用 TTL 自动过期，无需手动清理
        """
        # Redis TTL 自动处理，无需操作
        pass
    
    async def _cleanup_expired_cache(self):
        """清理过期缓存
        
        注意: Redis 使用 TTL 自动过期，无需手动清理
        """
        # Redis TTL 自动处理，无需操作
        pass
    
    async def _cleanup_completed_tasks_files(self):
        """清理已完成超过3天的任务的图片和文件，同日只跑一次，使用分布式锁"""
        today = get_utc_time().date()
        if self.last_completed_tasks_cleanup_date == today:
            return
        lock_key = "scheduled_task:cleanup_completed_tasks_files:lock"
        lock_ttl = 3600
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理已完成任务文件：其他实例正在执行，跳过")
            return
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_completed_tasks_files
            db = next(get_sync_db())
            try:
                cleaned_count = cleanup_completed_tasks_files(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个已完成任务的文件")
            finally:
                db.close()
            self.last_completed_tasks_cleanup_date = today
        except Exception as e:
            logger.error(f"清理已完成任务文件失败: {e}")
        finally:
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_expired_tasks_files(self):
        """清理过期任务（已取消或 deadline 已过超过3天）的文件，同日只跑一次，使用分布式锁"""
        today = get_utc_time().date()
        if self.last_expired_tasks_cleanup_date == today:
            return
        lock_key = "scheduled_task:cleanup_expired_tasks_files:lock"
        lock_ttl = 3600
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期任务文件：其他实例正在执行，跳过")
            return
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_expired_tasks_files
            db = next(get_sync_db())
            try:
                cleaned_count = cleanup_expired_tasks_files(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个过期任务的文件")
            finally:
                db.close()
            self.last_expired_tasks_cleanup_date = today
        except Exception as e:
            logger.error(f"清理过期任务文件失败: {e}")
        finally:
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_expired_flea_market_items(self):
        """清理超过10天未刷新的跳蚤市场商品，同日只跑一次，使用分布式锁"""
        today = get_utc_time().date()
        if self.last_flea_cleanup_date == today:
            return
        lock_key = "scheduled_task:cleanup_expired_flea_market_items:lock"
        lock_ttl = 3600
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期跳蚤市场商品：其他实例正在执行，跳过")
            return
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_expired_flea_market_items
            db = next(get_sync_db())
            try:
                cleaned_count = cleanup_expired_flea_market_items(db)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个过期跳蚤市场商品")
            finally:
                db.close()
            self.last_flea_cleanup_date = today
        except Exception as e:
            logger.error(f"清理过期跳蚤市场商品失败: {e}")
        finally:
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
            from datetime import timedelta, timezone
            from app.utils.time_utils import get_utc_time, file_timestamp_to_utc
            
            # 检查是否使用云存储
            backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
            is_cloud_storage = backend_type in ('s3', 'r2')
            
            cleaned_count = 0
            cloud_cleaned_count = 0
            cloud_bytes_freed = 0
            
            # 如果使用云存储，使用 storage backend 清理临时图片
            if is_cloud_storage:
                try:
                    from app.services.storage_backend import get_default_storage
                    from app.services.image_upload_service import ImageCategory, get_image_upload_service
                    
                    storage = get_default_storage()
                    service = get_image_upload_service()
                    
                    base_upload = _get_base_upload_dir()
                    is_low = _is_low_disk(base_upload)
                    temp_hours = 6 if is_low else _env_int("CLEANUP_TEMP_IMAGE_HOURS", 24)
                    max_files_per_run = _env_int("CLEANUP_MAX_FILES_TEMP", 1000) * (2 if is_low else 1)
                    cutoff_time = get_utc_time() - timedelta(hours=temp_hours)
                    
                    # 清理任务临时图片：列出所有临时文件及其元数据
                    try:
                        all_files_metadata = storage.list_files_with_metadata(ImageCategory.TASK.value)
                        temp_files_to_delete = []  # [(last_modified, file_key)]
                        
                        for file_meta in all_files_metadata:
                            file_key = file_meta['key']
                            if '/temp_' in file_key:
                                # 检查文件年龄
                                last_modified = file_meta['last_modified']
                                # boto3 返回的是 datetime 对象（可能是 timezone-aware）
                                # 需要转换为 UTC 时间进行比较
                                if hasattr(last_modified, 'replace'):
                                    # datetime 对象，确保是 UTC
                                    if last_modified.tzinfo is None:
                                        # 如果没有时区信息，假设是 UTC
                                        from datetime import timezone
                                        last_modified = last_modified.replace(tzinfo=timezone.utc)
                                    else:
                                        # 转换为 UTC
                                        last_modified = last_modified.astimezone(timezone.utc)
                                elif isinstance(last_modified, str):
                                    from app.utils.time_utils import parse_iso_utc
                                    try:
                                        last_modified = parse_iso_utc(last_modified)
                                    except:
                                        continue
                                
                                if last_modified < cutoff_time:
                                    temp_files_to_delete.append((last_modified, file_key))
                        
                        # 按时间排序，优先删除最旧的
                        temp_files_to_delete.sort(key=lambda x: x[0])
                        
                        # 限制本次处理的文件数量
                        temp_files_to_delete = temp_files_to_delete[:max_files_per_run]
                        
                        # 删除文件
                        for _, file_key in temp_files_to_delete:
                            try:
                                # 获取文件大小（用于统计）
                                file_size = storage.get_file_size(file_key) or 0
                                if storage.delete(file_key):
                                    cleaned_count += 1
                                    cloud_cleaned_count += 1
                                    cloud_bytes_freed += file_size
                                    if cleaned_count % 100 == 0:
                                        logger.debug(f"已清理 {cleaned_count} 个临时图片（云存储）...")
                            except Exception as e:
                                logger.warning(f"删除临时图片失败（云存储）{file_key}: {e}")
                        
                        # 清理空的临时目录（通过检查是否还有文件）
                        if cleaned_count > 0:
                            # 重新列出文件，检查哪些临时目录已为空
                            remaining_files = storage.list_files(ImageCategory.TASK.value)
                            temp_user_ids = set()
                            for file_key in remaining_files:
                                if '/temp_' in file_key:
                                    parts = file_key.split('/temp_')
                                    if len(parts) > 1:
                                        user_id = parts[1].split('/')[0]
                                        temp_user_ids.add(user_id)
                            
                            # 找出已清空的临时目录并删除
                            all_temp_user_ids = set()
                            for file_meta in all_files_metadata:
                                file_key = file_meta['key']
                                if '/temp_' in file_key:
                                    parts = file_key.split('/temp_')
                                    if len(parts) > 1:
                                        user_id = parts[1].split('/')[0]
                                        all_temp_user_ids.add(user_id)
                            
                            # 删除已清空的临时目录
                            for user_id in all_temp_user_ids:
                                if user_id not in temp_user_ids:
                                    # 临时目录已为空，删除它
                                    temp_dir = f"{ImageCategory.TASK.value}/temp_{user_id}"
                                    storage.delete_directory(temp_dir)
                                    logger.debug(f"删除空的临时目录（云存储）: {temp_dir}")
                    except Exception as e:
                        logger.warning(f"清理云存储临时图片失败: {e}")
                    
                except Exception as e:
                    logger.warning(f"使用云存储清理临时图片失败: {e}")
            
            # 本地存储：使用文件系统
            if not is_cloud_storage or cleaned_count == 0:
                RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
                if RAILWAY_ENVIRONMENT:
                    base_public_dir = Path("/data/uploads/public/images")
                else:
                    base_public_dir = Path("uploads/public/images")
                
                temp_base_dir = base_public_dir / "public"
                if not temp_base_dir.exists():
                    return

                base_upload = _get_base_upload_dir()
                is_low = _is_low_disk(base_upload)
                temp_hours = 6 if is_low else _env_int("CLEANUP_TEMP_IMAGE_HOURS", 24)
                max_files_per_run = _env_int("CLEANUP_MAX_FILES_TEMP", 1000) * (2 if is_low else 1)
                cutoff_time = get_utc_time() - timedelta(hours=temp_hours)

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
                if is_cloud_storage and cloud_cleaned_count > 0:
                    mb_freed = cloud_bytes_freed / (1024 * 1024)
                    logger.info(
                        f"清理了 {cleaned_count} 个未使用的临时图片 "
                        f"（云存储: {cloud_cleaned_count} 个文件，释放约 {mb_freed:.2f} MB；"
                        f"本地: {cleaned_count - cloud_cleaned_count} 个文件）"
                    )
                else:
                    logger.info(f"清理了 {cleaned_count} 个未使用的临时图片")
            
            # 清理跳蚤市场临时图片
            await self._cleanup_flea_market_temp_images()
            
            # 清理榜单封面临时图片
            await self._cleanup_leaderboard_covers_temp_images()
            
            # 清理 Banner 临时图片
            await self._cleanup_banner_temp_images()
                
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
            
            # 检查是否使用云存储
            backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
            is_cloud_storage = backend_type in ('s3', 'r2')
            
            cleaned_count = 0
            
            # 如果使用云存储，使用 storage backend
            if is_cloud_storage:
                try:
                    from app.services.storage_backend import get_default_storage
                    from app.services.image_upload_service import ImageCategory, get_image_upload_service
                    
                    storage = get_default_storage()
                    service = get_image_upload_service()
                    
                    # 列出所有临时目录
                    try:
                        all_files = storage.list_files(ImageCategory.FLEA_MARKET.value)
                        temp_user_ids = set()
                        temp_files_by_user = {}
                        
                        for file_key in all_files:
                            if '/temp_' in file_key:
                                parts = file_key.split('/temp_')
                                if len(parts) > 1:
                                    user_id = parts[1].split('/')[0]
                                    temp_user_ids.add(user_id)
                                    if user_id not in temp_files_by_user:
                                        temp_files_by_user[user_id] = []
                                    temp_files_by_user[user_id].append(file_key)
                        
                        # 清理每个用户的临时目录
                        for user_id in temp_user_ids:
                            if service.delete_temp(category=ImageCategory.FLEA_MARKET, user_id=user_id):
                                file_count = len(temp_files_by_user.get(user_id, []))
                                cleaned_count += file_count
                                logger.debug(f"清理用户 {user_id} 的跳蚤市场临时图片（云存储），共 {file_count} 个文件")
                    except Exception as e:
                        logger.warning(f"清理云存储跳蚤市场临时图片失败: {e}")
                except Exception as e:
                    logger.warning(f"使用云存储清理跳蚤市场临时图片失败: {e}")
            
            # 本地存储：使用文件系统
            if not is_cloud_storage or cleaned_count == 0:
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
            
            # 检查是否使用云存储
            backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
            is_cloud_storage = backend_type in ('s3', 'r2')
            
            cleaned_count = 0
            
            # 如果使用云存储，使用 storage backend
            if is_cloud_storage:
                try:
                    from app.services.storage_backend import get_default_storage
                    from app.services.image_upload_service import ImageCategory, get_image_upload_service
                    
                    storage = get_default_storage()
                    service = get_image_upload_service()
                    
                    # 列出所有临时目录
                    try:
                        all_files = storage.list_files(ImageCategory.LEADERBOARD_COVER.value)
                        temp_user_ids = set()
                        temp_files_by_user = {}
                        
                        for file_key in all_files:
                            if '/temp_' in file_key:
                                parts = file_key.split('/temp_')
                                if len(parts) > 1:
                                    user_id = parts[1].split('/')[0]
                                    temp_user_ids.add(user_id)
                                    if user_id not in temp_files_by_user:
                                        temp_files_by_user[user_id] = []
                                    temp_files_by_user[user_id].append(file_key)
                        
                        # 清理每个用户的临时目录
                        for user_id in temp_user_ids:
                            if service.delete_temp(category=ImageCategory.LEADERBOARD_COVER, user_id=user_id):
                                file_count = len(temp_files_by_user.get(user_id, []))
                                cleaned_count += file_count
                                logger.debug(f"清理用户 {user_id} 的榜单封面临时图片（云存储），共 {file_count} 个文件")
                    except Exception as e:
                        logger.warning(f"清理云存储榜单封面临时图片失败: {e}")
                except Exception as e:
                    logger.warning(f"使用云存储清理榜单封面临时图片失败: {e}")
            
            # 本地存储：使用文件系统
            if not is_cloud_storage or cleaned_count == 0:
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
    
    async def _cleanup_banner_temp_images(self):
        """清理 Banner 临时图片（超过24小时未使用的临时图片）"""
        try:
            from pathlib import Path
            import os
            import shutil
            from datetime import timedelta
            from app.utils.time_utils import get_utc_time, file_timestamp_to_utc
            
            # 检查是否使用云存储
            backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
            is_cloud_storage = backend_type in ('s3', 'r2')
            
            cleaned_count = 0
            
            # 如果使用云存储，使用 storage backend
            if is_cloud_storage:
                try:
                    from app.services.storage_backend import get_default_storage
                    from app.services.image_upload_service import ImageCategory, get_image_upload_service
                    
                    storage = get_default_storage()
                    service = get_image_upload_service()
                    
                    # 列出所有临时目录
                    try:
                        all_files = storage.list_files(ImageCategory.BANNER.value)
                        temp_user_ids = set()
                        temp_files_by_user = {}
                        
                        for file_key in all_files:
                            if '/temp_' in file_key:
                                parts = file_key.split('/temp_')
                                if len(parts) > 1:
                                    user_id = parts[1].split('/')[0]
                                    temp_user_ids.add(user_id)
                                    if user_id not in temp_files_by_user:
                                        temp_files_by_user[user_id] = []
                                    temp_files_by_user[user_id].append(file_key)
                        
                        # 清理每个用户的临时目录
                        for user_id in temp_user_ids:
                            if service.delete_temp(category=ImageCategory.BANNER, user_id=user_id):
                                file_count = len(temp_files_by_user.get(user_id, []))
                                cleaned_count += file_count
                                logger.debug(f"清理用户 {user_id} 的 Banner 临时图片（云存储），共 {file_count} 个文件")
                    except Exception as e:
                        logger.warning(f"清理云存储 Banner 临时图片失败: {e}")
                except Exception as e:
                    logger.warning(f"使用云存储清理 Banner 临时图片失败: {e}")
            
            # 本地存储：使用文件系统
            if not is_cloud_storage or cleaned_count == 0:
                RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
                if RAILWAY_ENVIRONMENT:
                    base_dir = Path("/data/uploads/public/images")
                else:
                    base_dir = Path("uploads/public/images")
                
                temp_base_dir = base_dir / "banner"
                
                # 如果 banner 目录不存在，直接返回
                if not temp_base_dir.exists():
                    return
                
                # 计算24小时前的时间
                cutoff_time = get_utc_time() - timedelta(hours=24)
                
                # 遍历所有临时文件夹（temp_*）
                for temp_dir in temp_base_dir.iterdir():
                    if temp_dir.is_dir() and temp_dir.name.startswith("temp_"):
                        try:
                            # 检查文件夹中的文件
                            for file_path in temp_dir.iterdir():
                                if file_path.is_file():
                                    # 获取文件的修改时间（使用统一时间工具函数）
                                    file_mtime = file_timestamp_to_utc(file_path.stat().st_mtime)
                                    
                                    # 如果文件超过24小时未修改，删除它
                                    if file_mtime < cutoff_time:
                                        try:
                                            file_path.unlink()
                                            cleaned_count += 1
                                            logger.info(f"删除未使用的 Banner 临时图片: {file_path}")
                                        except Exception as e:
                                            logger.warning(f"删除 Banner 临时图片失败 {file_path}: {e}")
                            
                            # 如果文件夹为空，尝试删除它
                            try:
                                if not any(temp_dir.iterdir()):
                                    temp_dir.rmdir()
                                    logger.info(f"删除空的 Banner 临时文件夹: {temp_dir}")
                            except Exception as e:
                                logger.debug(f"删除 Banner 临时文件夹失败（可能不为空）: {temp_dir}: {e}")
                                
                        except Exception as e:
                            logger.warning(f"处理 Banner 临时文件夹失败 {temp_dir}: {e}")
                            continue
            
            if cleaned_count > 0:
                logger.info(f"清理了 {cleaned_count} 个未使用的 Banner 临时图片")
                
        except Exception as e:
            logger.error(f"清理 Banner 临时图片失败: {e}")
    
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
            
            base_upload = base_upload_dir  # 与下方 expected_dirs 一致
            is_low = _is_low_disk(base_upload)
            orphan_days = 2 if is_low else _env_int("CLEANUP_ORPHAN_FILE_DAYS", 7)
            max_files_per_run = _env_int("CLEANUP_MAX_FILES_ORPHAN", 500) * (2 if is_low else 1)
            cutoff_time = get_utc_time() - timedelta(days=orphan_days)
            cleaned_count = 0
            bytes_freed = 0

            # 定义预期的目录结构（允许的子目录）
            expected_dirs = {
                # 公开图片目录
                base_upload_dir / "public" / "images" / "expert_avatars": True,  # 允许任意子目录
                base_upload_dir / "public" / "images" / "service_images": True,
                base_upload_dir / "public" / "images" / "public": True,  # 允许 task_id 或 temp_* 子目录
                base_upload_dir / "public" / "images" / "leaderboard_items": True,  # 允许 item_id 或 temp_* 子目录
                base_upload_dir / "public" / "images" / "leaderboard_covers": True,  # 允许 leaderboard_id 或 temp_* 子目录
                base_upload_dir / "public" / "images" / "banner": True,  # 允许 banner_id 或 temp_* 子目录
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
                nonlocal cleaned_count, bytes_freed

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
                                        try:
                                            bytes_freed += item.stat().st_size
                                        except Exception:
                                            pass
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
                mb = bytes_freed / (1024 * 1024)
                logger.info(f"清理了 {cleaned_count} 个孤立文件，释放约 {mb:.2f} MB")
                self.last_orphan_files_cleanup_date = today
            else:
                logger.debug("未发现需要清理的孤立文件")
                self.last_orphan_files_cleanup_date = today

        except Exception as e:
            logger.error(f"清理孤立文件失败: {e}", exc_info=True)
        finally:
            release_redis_distributed_lock(lock_key)

    async def _cleanup_orphan_entity_images(self):
        """清理不存在实体的图片文件夹（竞品、商品、任务），同日只跑一次，使用分布式锁"""
        today = get_utc_time().date()
        if self.last_orphan_entity_cleanup_date == today:
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

            # 检查是否使用云存储
            backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
            is_cloud_storage = backend_type in ('s3', 'r2')

            is_low = _is_low_disk(base_upload_dir)
            cleaned_count = 0
            cloud_cleaned_count = 0
            max_dirs_per_run = _env_int("CLEANUP_MAX_DIRS_ORPHAN_ENTITY", 100) * (2 if is_low else 1)

            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 预取实体 ID，供任务公开图、榜单封面、私有任务/聊天目录的孤儿清理使用
                from sqlalchemy import select
                _existing_task_ids = {r[0] for r in db.execute(select(models.Task.id)).all()}
                _existing_chat_ids = {r[0] for r in db.execute(select(models.CustomerServiceChat.chat_id)).all()}
                _existing_leaderboard_ids = {r[0] for r in db.execute(select(models.CustomLeaderboard.id)).all()}
                
                # 如果使用云存储，先清理云存储中的孤儿目录
                if is_cloud_storage:
                    try:
                        from app.services.storage_backend import get_default_storage
                        storage = get_default_storage()
                        
                        # 清理云存储中的孤儿目录
                        cloud_cleaned_count = await self._cleanup_orphan_entity_images_cloud(
                            storage, db, _existing_task_ids, _existing_chat_ids, 
                            _existing_leaderboard_ids, max_dirs_per_run
                        )
                        cleaned_count += cloud_cleaned_count
                    except Exception as e:
                        logger.warning(f"清理云存储孤儿实体目录失败: {e}")

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
                    existing_task_ids = _existing_task_ids
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

                # 7. 清理不存在榜单的封面文件夹
                leaderboard_covers_dir = base_upload_dir / "public" / "images" / "leaderboard_covers"
                if leaderboard_covers_dir.exists():
                    for lb_dir in leaderboard_covers_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        if lb_dir.is_dir() and not lb_dir.name.startswith("temp_"):
                            try:
                                lb_id = int(lb_dir.name)
                                if lb_id not in _existing_leaderboard_ids:
                                    shutil.rmtree(lb_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在榜单 {lb_id} 的封面文件夹: {lb_dir}")
                            except (ValueError, Exception) as e:
                                logger.debug(f"跳过无效的榜单封面目录: {lb_dir.name}: {e}")
                                continue

                # 8. 清理不存在任务的私密图片文件夹
                private_tasks_img_dir = base_upload_dir / "private_images" / "tasks"
                if private_tasks_img_dir.exists():
                    for task_dir in private_tasks_img_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        if task_dir.is_dir():
                            try:
                                task_id = int(task_dir.name)
                                if task_id not in _existing_task_ids:
                                    shutil.rmtree(task_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在任务 {task_id} 的私密图片文件夹: {task_dir}")
                            except (ValueError, Exception) as e:
                                logger.debug(f"跳过无效的任务私密图片目录: {task_dir.name}: {e}")
                                continue

                # 9. 清理不存在客服聊天的私密图片文件夹
                private_chats_img_dir = base_upload_dir / "private_images" / "chats"
                if private_chats_img_dir.exists():
                    for chat_dir in private_chats_img_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        if chat_dir.is_dir() and chat_dir.name not in _existing_chat_ids:
                            shutil.rmtree(chat_dir)
                            cleaned_count += 1
                            logger.info(f"删除不存在客服聊天 {chat_dir.name} 的私密图片文件夹: {chat_dir}")

                # 10. 清理不存在任务的私密文件文件夹
                private_tasks_file_dir = base_upload_dir / "private_files" / "tasks"
                if private_tasks_file_dir.exists():
                    for task_dir in private_tasks_file_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        if task_dir.is_dir():
                            try:
                                task_id = int(task_dir.name)
                                if task_id not in _existing_task_ids:
                                    shutil.rmtree(task_dir)
                                    cleaned_count += 1
                                    logger.info(f"删除不存在任务 {task_id} 的私密文件文件夹: {task_dir}")
                            except (ValueError, Exception) as e:
                                logger.debug(f"跳过无效的任务私密文件目录: {task_dir.name}: {e}")
                                continue

                # 11. 清理不存在客服聊天的私密文件文件夹
                private_chats_file_dir = base_upload_dir / "private_files" / "chats"
                if private_chats_file_dir.exists():
                    for chat_dir in private_chats_file_dir.iterdir():
                        if cleaned_count >= max_dirs_per_run:
                            logger.info(f"已达到单次处理上限（{max_dirs_per_run}），停止处理")
                            break
                        if chat_dir.is_dir() and chat_dir.name not in _existing_chat_ids:
                            shutil.rmtree(chat_dir)
                            cleaned_count += 1
                            logger.info(f"删除不存在客服聊天 {chat_dir.name} 的私密文件文件夹: {chat_dir}")

            finally:
                db.close()
            
            if cleaned_count > 0:
                if is_cloud_storage and cloud_cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 个不存在实体的图片文件夹（云存储: {cloud_cleaned_count}, 本地: {cleaned_count - cloud_cleaned_count}）")
                else:
                    logger.info(f"清理了 {cleaned_count} 个不存在实体的图片文件夹")
            else:
                logger.debug("未发现需要清理的不存在实体的图片文件夹")
            self.last_orphan_entity_cleanup_date = today

        except Exception as e:
            logger.error(f"清理不存在实体的图片文件夹失败: {e}", exc_info=True)
        finally:
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_orphan_entity_images_cloud(
        self, storage, db, existing_task_ids, existing_chat_ids, 
        existing_leaderboard_ids, max_dirs_per_run
    ):
        """清理云存储中不存在实体的图片文件夹"""
        from app import models
        from sqlalchemy import select
        
        cleaned_count = 0
        
        try:
            # 1. 清理不存在竞品的图片文件夹
            leaderboard_items_prefix = "public/images/leaderboard_items/"
            if cleaned_count < max_dirs_per_run:
                items_result = db.execute(select(models.LeaderboardItem.id))
                existing_item_ids = {item_id for item_id, in items_result.all()}
                
                all_files = storage.list_files(leaderboard_items_prefix)
                item_dirs = set()
                for file_key in all_files:
                    # 提取目录名: public/images/leaderboard_items/{item_id}/file.jpg
                    parts = file_key.replace(leaderboard_items_prefix, '').split('/')
                    if parts and parts[0] and not parts[0].startswith('temp_'):
                        item_dirs.add(parts[0])
                
                for item_dir_name in item_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    try:
                        item_id = int(item_dir_name)
                        if item_id not in existing_item_ids:
                            dir_path = f"{leaderboard_items_prefix}{item_id}"
                            if storage.delete_directory(dir_path):
                                cleaned_count += 1
                                logger.info(f"删除不存在竞品 {item_id} 的图片文件夹（云存储）: {dir_path}")
                    except (ValueError, Exception) as e:
                        logger.debug(f"跳过无效的竞品目录: {item_dir_name}: {e}")
            
            # 2. 清理不存在商品的图片文件夹
            flea_market_prefix = "flea_market/"
            if cleaned_count < max_dirs_per_run:
                items_result = db.execute(select(models.FleaMarketItem.id))
                existing_flea_item_ids = {item_id for item_id, in items_result.all()}
                
                all_files = storage.list_files(flea_market_prefix)
                item_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(flea_market_prefix, '').split('/')
                    if parts and parts[0] and not parts[0].startswith('temp_'):
                        item_dirs.add(parts[0])
                
                for item_dir_name in item_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    try:
                        item_id = int(item_dir_name)
                        if item_id not in existing_flea_item_ids:
                            dir_path = f"{flea_market_prefix}{item_id}"
                            if storage.delete_directory(dir_path):
                                cleaned_count += 1
                                logger.info(f"删除不存在商品 {item_id} 的图片文件夹（云存储）: {dir_path}")
                    except (ValueError, Exception) as e:
                        logger.debug(f"跳过无效的商品目录: {item_dir_name}: {e}")
            
            # 3. 清理不存在任务的图片文件夹
            tasks_public_prefix = "public/images/public/"
            if cleaned_count < max_dirs_per_run:
                all_files = storage.list_files(tasks_public_prefix)
                task_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(tasks_public_prefix, '').split('/')
                    if parts and parts[0] and not parts[0].startswith('temp_'):
                        task_dirs.add(parts[0])
                
                for task_dir_name in task_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    try:
                        task_id = int(task_dir_name)
                        if task_id not in existing_task_ids:
                            dir_path = f"{tasks_public_prefix}{task_id}"
                            if storage.delete_directory(dir_path):
                                cleaned_count += 1
                                logger.info(f"删除不存在任务 {task_id} 的图片文件夹（云存储）: {dir_path}")
                    except (ValueError, Exception) as e:
                        logger.debug(f"跳过无效的任务目录: {task_dir_name}: {e}")
            
            # 4. 清理不存在用户的头像文件夹
            expert_avatars_prefix = "public/images/expert_avatars/"
            if cleaned_count < max_dirs_per_run:
                users_result = db.execute(select(models.User.id))
                existing_user_ids = {str(user_id) for user_id, in users_result.all()}
                
                all_files = storage.list_files(expert_avatars_prefix)
                user_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(expert_avatars_prefix, '').split('/')
                    if parts and parts[0]:
                        user_dirs.add(parts[0])
                
                for user_dir_name in user_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    if user_dir_name not in existing_user_ids:
                        dir_path = f"{expert_avatars_prefix}{user_dir_name}"
                        if storage.delete_directory(dir_path):
                            cleaned_count += 1
                            logger.info(f"删除不存在用户 {user_dir_name} 的头像文件夹（云存储）: {dir_path}")
            
            # 5. 清理不存在任务达人的服务图片文件夹
            service_images_prefix = "public/images/service_images/"
            if cleaned_count < max_dirs_per_run:
                experts_result = db.execute(select(models.TaskExpert.id))
                existing_expert_ids = {str(expert_id) for expert_id, in experts_result.all()}
                
                all_files = storage.list_files(service_images_prefix)
                expert_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(service_images_prefix, '').split('/')
                    if parts and parts[0]:
                        expert_dirs.add(parts[0])
                
                for expert_dir_name in expert_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    if expert_dir_name not in existing_expert_ids:
                        dir_path = f"{service_images_prefix}{expert_dir_name}"
                        if storage.delete_directory(dir_path):
                            cleaned_count += 1
                            logger.info(f"删除不存在任务达人 {expert_dir_name} 的服务图片文件夹（云存储）: {dir_path}")
            
            # 6. 清理不存在Banner的图片文件夹
            banner_prefix = "public/images/banner/"
            if cleaned_count < max_dirs_per_run:
                banners_result = db.execute(select(models.Banner.id))
                existing_banner_ids = {banner_id for banner_id, in banners_result.all()}
                
                all_files = storage.list_files(banner_prefix)
                banner_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(banner_prefix, '').split('/')
                    if parts and parts[0]:
                        banner_dirs.add(parts[0])
                
                for banner_dir_name in banner_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    try:
                        banner_id = int(banner_dir_name)
                        if banner_id not in existing_banner_ids:
                            dir_path = f"{banner_prefix}{banner_id}"
                            if storage.delete_directory(dir_path):
                                cleaned_count += 1
                                logger.info(f"删除不存在Banner {banner_id} 的图片文件夹（云存储）: {dir_path}")
                    except (ValueError, Exception) as e:
                        logger.debug(f"跳过无效的Banner目录: {banner_dir_name}: {e}")
            
            # 7. 清理不存在榜单的封面文件夹
            leaderboard_covers_prefix = "public/images/leaderboard_covers/"
            if cleaned_count < max_dirs_per_run:
                all_files = storage.list_files(leaderboard_covers_prefix)
                lb_dirs = set()
                for file_key in all_files:
                    parts = file_key.replace(leaderboard_covers_prefix, '').split('/')
                    if parts and parts[0] and not parts[0].startswith('temp_'):
                        lb_dirs.add(parts[0])
                
                for lb_dir_name in lb_dirs:
                    if cleaned_count >= max_dirs_per_run:
                        break
                    try:
                        lb_id = int(lb_dir_name)
                        if lb_id not in existing_leaderboard_ids:
                            dir_path = f"{leaderboard_covers_prefix}{lb_id}"
                            if storage.delete_directory(dir_path):
                                cleaned_count += 1
                                logger.info(f"删除不存在榜单 {lb_id} 的封面文件夹（云存储）: {dir_path}")
                    except (ValueError, Exception) as e:
                        logger.debug(f"跳过无效的榜单封面目录: {lb_dir_name}: {e}")
        
        except Exception as e:
            logger.error(f"清理云存储孤儿实体目录失败: {e}", exc_info=True)
        
        return cleaned_count

    async def _cleanup_empty_dirs(self):
        """清理 uploads 下的空目录，释放 inode，减轻小卷压力。每轮执行。"""
        try:
            base = _get_base_upload_dir()
            if not base.exists() or not base.is_dir():
                return
            removed = 0
            for root, dirs, files in os.walk(str(base), topdown=False):
                for d in dirs:
                    p = os.path.join(root, d)
                    if os.path.isdir(p) and len(os.listdir(p)) == 0:
                        try:
                            os.rmdir(p)
                            removed += 1
                        except OSError:
                            pass
                if root != str(base) and len(os.listdir(root)) == 0:
                    try:
                        os.rmdir(root)
                        removed += 1
                    except OSError:
                        pass
            if removed > 0:
                logger.info(f"清理了 {removed} 个空目录")
        except Exception as e:
            logger.warning(f"清理空目录失败: {e}")

    async def _cleanup_old_format_images(self):
        """清理旧格式图片（直接保存在 /uploads/images/ 下的），同日只跑一次，使用分布式锁"""
        today = get_utc_time().date()
        if self.last_old_format_cleanup_date == today:
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
                base_upload_dir / "images",
                base_upload_dir / "public" / "images",
            ]

            is_low = _is_low_disk(base_upload_dir)
            old_days = 14 if is_low else _env_int("CLEANUP_OLD_FORMAT_DAYS", 30)
            max_files_per_run = 200 * (2 if is_low else 1)
            cutoff_time = get_utc_time() - timedelta(days=old_days)
            cleaned_count = 0
            
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
            self.last_old_format_cleanup_date = today

        except Exception as e:
            logger.error(f"清理旧格式图片失败: {e}", exc_info=True)
        finally:
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
    
    async def _cleanup_stale_task_translations(self):
        """清理过期的任务翻译（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_stale_task_translations:lock"
        lock_ttl = 3600  # 1小时
        
        # 尝试获取分布式锁
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理过期翻译：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_stale_task_translations
            
            # 获取数据库会话
            db = next(get_sync_db())
            try:
                # 调用清理函数（每批处理100条，避免一次性处理太多）
                cleaned_count = cleanup_stale_task_translations(db, batch_size=100)
                if cleaned_count > 0:
                    logger.info(f"清理了 {cleaned_count} 条过期翻译")
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"清理过期翻译失败: {e}")
        finally:
            # 释放锁
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_duplicate_device_tokens(self):
        """清理同一 device_id 下的重复活跃令牌，保留最新的（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_duplicate_device_tokens:lock"
        lock_ttl = 3600
        
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("清理重复设备令牌：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import cleanup_duplicate_device_tokens
            
            db = next(get_sync_db())
            try:
                deactivated = cleanup_duplicate_device_tokens(db)
                if deactivated > 0:
                    logger.info(f"清理了 {deactivated} 个重复设备令牌")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"清理重复设备令牌失败: {e}")
        finally:
            release_redis_distributed_lock(lock_key)
    
    async def _cleanup_old_inactive_device_tokens(self):
        """删除长期不活跃的 is_active=False 令牌记录（每天检查一次，使用分布式锁）"""
        lock_key = "scheduled_task:cleanup_old_inactive_device_tokens:lock"
        lock_ttl = 3600
        
        if not get_redis_distributed_lock(lock_key, lock_ttl):
            logger.debug("删除旧无效设备令牌：其他实例正在执行，跳过")
            return
        
        try:
            from app.deps import get_sync_db
            from app.crud import delete_old_inactive_device_tokens
            
            inactive_days = _env_int("CLEANUP_INACTIVE_DEVICE_TOKEN_DAYS", 180)
            db = next(get_sync_db())
            try:
                deleted = delete_old_inactive_device_tokens(db, inactive_days=inactive_days)
                if deleted > 0:
                    logger.info(f"删除了 {deleted} 个长期不活跃的无效设备令牌")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"删除旧无效设备令牌失败: {e}")
        finally:
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

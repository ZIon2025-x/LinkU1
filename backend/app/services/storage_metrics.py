"""
存储监控指标服务
提供磁盘使用率、上传统计等监控数据
"""

import os
import logging
import time
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from collections import defaultdict
import threading

logger = logging.getLogger(__name__)


@dataclass
class StorageStats:
    """存储统计信息"""
    total_size: int = 0  # 总大小（字节）
    file_count: int = 0  # 文件数量
    directory_count: int = 0  # 目录数量
    last_updated: Optional[datetime] = None
    
    @property
    def total_size_mb(self) -> float:
        """总大小（MB）"""
        return self.total_size / (1024 * 1024)
    
    @property
    def total_size_gb(self) -> float:
        """总大小（GB）"""
        return self.total_size / (1024 * 1024 * 1024)


@dataclass
class CategoryStats:
    """分类统计信息"""
    category: str
    size: int = 0
    file_count: int = 0
    resource_count: int = 0  # 资源目录数量
    temp_size: int = 0  # 临时目录大小
    temp_file_count: int = 0  # 临时目录文件数
    oldest_file: Optional[datetime] = None
    newest_file: Optional[datetime] = None


@dataclass
class UploadMetrics:
    """上传指标"""
    total_uploads: int = 0
    total_bytes_uploaded: int = 0
    total_bytes_saved: int = 0  # 压缩节省的字节
    success_count: int = 0
    failure_count: int = 0
    uploads_by_category: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    
    # 时间窗口统计
    uploads_last_hour: int = 0
    uploads_last_day: int = 0
    
    @property
    def success_rate(self) -> float:
        """成功率"""
        total = self.success_count + self.failure_count
        return self.success_count / total if total > 0 else 0.0
    
    @property
    def compression_ratio(self) -> float:
        """压缩率"""
        if self.total_bytes_uploaded == 0:
            return 0.0
        return self.total_bytes_saved / self.total_bytes_uploaded


class StorageMetricsCollector:
    """存储指标收集器"""
    
    def __init__(self, base_dir: Optional[str] = None):
        """
        初始化指标收集器
        
        Args:
            base_dir: 基础存储目录
        """
        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        
        if base_dir:
            self.base_dir = Path(base_dir)
        elif railway_env:
            self.base_dir = Path("/data/uploads")
        else:
            self.base_dir = Path("uploads")
        
        # 上传指标
        self._upload_metrics = UploadMetrics()
        self._upload_timestamps: List[float] = []  # 记录上传时间戳
        
        # 缓存的存储统计
        self._cached_stats: Optional[StorageStats] = None
        self._cached_category_stats: Optional[Dict[str, CategoryStats]] = None
        self._cache_ttl = 300  # 缓存5分钟
        self._last_scan_time = 0
        
        # 线程锁
        self._lock = threading.Lock()
    
    def record_upload(
        self,
        category: str,
        original_size: int,
        final_size: int,
        success: bool
    ) -> None:
        """
        记录一次上传操作
        
        Args:
            category: 图片分类
            original_size: 原始文件大小
            final_size: 处理后文件大小
            success: 是否成功
        """
        with self._lock:
            self._upload_metrics.total_uploads += 1
            
            if success:
                self._upload_metrics.success_count += 1
                self._upload_metrics.total_bytes_uploaded += final_size
                self._upload_metrics.total_bytes_saved += (original_size - final_size)
                self._upload_metrics.uploads_by_category[category] += 1
            else:
                self._upload_metrics.failure_count += 1
            
            # 记录时间戳用于计算时间窗口统计
            self._upload_timestamps.append(time.time())
            
            # 清理过期时间戳（保留24小时内的）
            cutoff = time.time() - 86400
            self._upload_timestamps = [
                ts for ts in self._upload_timestamps if ts > cutoff
            ]
    
    def get_upload_metrics(self) -> UploadMetrics:
        """获取上传指标"""
        with self._lock:
            metrics = self._upload_metrics
            
            # 计算时间窗口统计
            now = time.time()
            hour_ago = now - 3600
            day_ago = now - 86400
            
            metrics.uploads_last_hour = sum(
                1 for ts in self._upload_timestamps if ts > hour_ago
            )
            metrics.uploads_last_day = sum(
                1 for ts in self._upload_timestamps if ts > day_ago
            )
            
            return metrics
    
    def get_storage_stats(self, force_refresh: bool = False) -> StorageStats:
        """
        获取存储统计信息
        
        Args:
            force_refresh: 是否强制刷新缓存
            
        Returns:
            存储统计信息
        """
        if not force_refresh and self._cached_stats:
            if time.time() - self._last_scan_time < self._cache_ttl:
                return self._cached_stats
        
        stats = StorageStats()
        
        try:
            if not self.base_dir.exists():
                return stats
            
            for item in self.base_dir.rglob("*"):
                if item.is_file():
                    stats.file_count += 1
                    stats.total_size += item.stat().st_size
                elif item.is_dir():
                    stats.directory_count += 1
            
            stats.last_updated = datetime.now()
            
            self._cached_stats = stats
            self._last_scan_time = time.time()
            
        except Exception as e:
            logger.error(f"获取存储统计失败: {e}")
        
        return stats
    
    def get_category_stats(self, force_refresh: bool = False) -> Dict[str, CategoryStats]:
        """
        获取各分类的统计信息
        
        Args:
            force_refresh: 是否强制刷新缓存
            
        Returns:
            {分类名: 统计信息}
        """
        if not force_refresh and self._cached_category_stats:
            if time.time() - self._last_scan_time < self._cache_ttl:
                return self._cached_category_stats
        
        # 定义要统计的分类目录
        categories = {
            "task": self.base_dir / "public" / "images" / "public",
            "banner": self.base_dir / "public" / "images" / "banner",
            "leaderboard_covers": self.base_dir / "public" / "images" / "leaderboard_covers",
            "leaderboard_items": self.base_dir / "public" / "images" / "leaderboard_items",
            "expert_avatars": self.base_dir / "public" / "images" / "expert_avatars",
            "service_images": self.base_dir / "public" / "images" / "service_images",
            "flea_market": self.base_dir / "flea_market",
            "private_task_chat": self.base_dir / "private_images" / "tasks",
            "private_cs_chat": self.base_dir / "private_images" / "chats",
            "private_task_files": self.base_dir / "private_files" / "tasks",
            "private_cs_files": self.base_dir / "private_files" / "chats",
        }
        
        result = {}
        
        for category_name, category_dir in categories.items():
            stats = CategoryStats(category=category_name)
            
            try:
                if not category_dir.exists():
                    result[category_name] = stats
                    continue
                
                for item in category_dir.iterdir():
                    if item.is_dir():
                        stats.resource_count += 1
                        
                        # 检查是否为临时目录
                        is_temp = item.name.startswith("temp_")
                        
                        for file in item.rglob("*"):
                            if file.is_file():
                                file_stat = file.stat()
                                file_size = file_stat.st_size
                                file_mtime = datetime.fromtimestamp(file_stat.st_mtime)
                                
                                stats.file_count += 1
                                stats.size += file_size
                                
                                if is_temp:
                                    stats.temp_file_count += 1
                                    stats.temp_size += file_size
                                
                                if stats.oldest_file is None or file_mtime < stats.oldest_file:
                                    stats.oldest_file = file_mtime
                                if stats.newest_file is None or file_mtime > stats.newest_file:
                                    stats.newest_file = file_mtime
                
            except Exception as e:
                logger.error(f"获取分类 {category_name} 统计失败: {e}")
            
            result[category_name] = stats
        
        self._cached_category_stats = result
        self._last_scan_time = time.time()
        
        return result
    
    def get_disk_usage(self) -> Dict[str, Any]:
        """
        获取磁盘使用情况
        
        Returns:
            磁盘使用信息
        """
        try:
            import shutil
            
            # 获取存储目录所在分区的磁盘使用情况
            if self.base_dir.exists():
                usage = shutil.disk_usage(self.base_dir)
                return {
                    "total": usage.total,
                    "used": usage.used,
                    "free": usage.free,
                    "total_gb": usage.total / (1024 ** 3),
                    "used_gb": usage.used / (1024 ** 3),
                    "free_gb": usage.free / (1024 ** 3),
                    "usage_percent": (usage.used / usage.total) * 100,
                    "path": str(self.base_dir)
                }
            else:
                return {
                    "error": "存储目录不存在",
                    "path": str(self.base_dir)
                }
                
        except Exception as e:
            logger.error(f"获取磁盘使用情况失败: {e}")
            return {"error": str(e)}
    
    def get_temp_cleanup_candidates(self, max_age_hours: int = 24) -> List[Dict[str, Any]]:
        """
        获取需要清理的临时文件
        
        Args:
            max_age_hours: 文件最大保留时间（小时）
            
        Returns:
            待清理文件列表
        """
        candidates = []
        cutoff_time = datetime.now() - timedelta(hours=max_age_hours)
        
        try:
            # 扫描所有 temp_* 目录
            for dir_path in self.base_dir.rglob("temp_*"):
                if not dir_path.is_dir():
                    continue
                
                for file in dir_path.rglob("*"):
                    if file.is_file():
                        mtime = datetime.fromtimestamp(file.stat().st_mtime)
                        if mtime < cutoff_time:
                            candidates.append({
                                "path": str(file),
                                "size": file.stat().st_size,
                                "mtime": mtime.isoformat(),
                                "age_hours": (datetime.now() - mtime).total_seconds() / 3600
                            })
                            
        except Exception as e:
            logger.error(f"获取临时文件清理候选列表失败: {e}")
        
        return candidates
    
    def get_full_report(self) -> Dict[str, Any]:
        """
        获取完整的存储报告
        
        Returns:
            完整报告
        """
        storage_stats = self.get_storage_stats()
        category_stats = self.get_category_stats()
        upload_metrics = self.get_upload_metrics()
        disk_usage = self.get_disk_usage()
        
        # 转换 CategoryStats 为字典
        category_stats_dict = {}
        for name, stats in category_stats.items():
            category_stats_dict[name] = {
                "size": stats.size,
                "size_mb": stats.size / (1024 * 1024),
                "file_count": stats.file_count,
                "resource_count": stats.resource_count,
                "temp_size": stats.temp_size,
                "temp_file_count": stats.temp_file_count,
                "oldest_file": stats.oldest_file.isoformat() if stats.oldest_file else None,
                "newest_file": stats.newest_file.isoformat() if stats.newest_file else None,
            }
        
        return {
            "storage": {
                "total_size": storage_stats.total_size,
                "total_size_mb": storage_stats.total_size_mb,
                "total_size_gb": storage_stats.total_size_gb,
                "file_count": storage_stats.file_count,
                "directory_count": storage_stats.directory_count,
                "last_updated": storage_stats.last_updated.isoformat() if storage_stats.last_updated else None,
            },
            "disk": disk_usage,
            "categories": category_stats_dict,
            "uploads": {
                "total_uploads": upload_metrics.total_uploads,
                "success_count": upload_metrics.success_count,
                "failure_count": upload_metrics.failure_count,
                "success_rate": upload_metrics.success_rate,
                "total_bytes_uploaded": upload_metrics.total_bytes_uploaded,
                "total_bytes_saved": upload_metrics.total_bytes_saved,
                "compression_ratio": upload_metrics.compression_ratio,
                "uploads_last_hour": upload_metrics.uploads_last_hour,
                "uploads_last_day": upload_metrics.uploads_last_day,
                "by_category": dict(upload_metrics.uploads_by_category),
            },
            "generated_at": datetime.now().isoformat(),
        }


# 全局指标收集器实例
_metrics_collector: Optional[StorageMetricsCollector] = None


def get_storage_metrics_collector() -> StorageMetricsCollector:
    """获取存储指标收集器实例"""
    global _metrics_collector
    if _metrics_collector is None:
        _metrics_collector = StorageMetricsCollector()
    return _metrics_collector

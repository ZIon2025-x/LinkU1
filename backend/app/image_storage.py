"""
图片存储优化模块
提供图片存储策略和配置管理
"""

import os
import hashlib
from pathlib import Path
from typing import Optional, Dict, Any
from enum import Enum
import logging

logger = logging.getLogger(__name__)

class StorageStrategy(Enum):
    """存储策略枚举"""
    FILE_SYSTEM = "file_system"  # 文件系统存储
    CLOUD_STORAGE = "cloud_storage"  # 云存储
    HYBRID = "hybrid"  # 混合存储

class ImageStorageConfig:
    """图片存储配置"""
    
    def __init__(self):
        self.railway_environment = os.getenv("RAILWAY_ENVIRONMENT")
        self.use_cloud_storage = os.getenv("USE_CLOUD_STORAGE", "false").lower() == "true"
        self.base_url = os.getenv("BASE_URL", "http://localhost:8000")
        
        # 文件大小限制
        self.max_file_size = 5 * 1024 * 1024  # 5MB
        self.max_base64_size = 10 * 1024 * 1024  # 10MB (base64编码后更大)
        
        # 存储路径配置
        if self.railway_environment and not self.use_cloud_storage:
            # Railway环境：使用持久化卷
            self.upload_dir = Path("/data/uploads/images")
        else:
            # 本地开发或云存储
            self.upload_dir = Path("uploads/images")
        
        # 确保目录存在
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        
        # 支持的图片格式
        self.allowed_extensions = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
        self.allowed_mime_types = {
            "image/jpeg", "image/png", "image/gif", "image/webp"
        }
    
    def get_storage_strategy(self) -> StorageStrategy:
        """获取当前存储策略"""
        if self.use_cloud_storage:
            return StorageStrategy.CLOUD_STORAGE
        elif self.railway_environment:
            return StorageStrategy.FILE_SYSTEM
        else:
            return StorageStrategy.FILE_SYSTEM
    
    def should_use_file_storage(self, file_size: int) -> bool:
        """判断是否应该使用文件存储（强制使用文件存储）"""
        return file_size <= self.max_file_size
    
    def should_use_base64(self, file_size: int) -> bool:
        """判断是否应该使用base64存储（已禁用）"""
        return False  # 完全禁用base64存储
    
    def get_image_url(self, filename: str) -> str:
        """生成图片访问URL"""
        return f"{self.base_url}/uploads/images/{filename}"

class ImageProcessor:
    """图片处理器"""
    
    def __init__(self, config: ImageStorageConfig):
        self.config = config
    
    def generate_filename(self, file_content: bytes, original_filename: str) -> str:
        """生成唯一文件名"""
        # 使用文件内容生成哈希值
        file_hash = hashlib.sha256(file_content).hexdigest()[:16]
        
        # 获取文件扩展名
        file_extension = Path(original_filename).suffix.lower()
        if file_extension not in self.config.allowed_extensions:
            file_extension = ".jpg"  # 默认扩展名
        
        return f"{file_hash}{file_extension}"
    
    def validate_image(self, file_content: bytes, filename: str) -> bool:
        """验证图片文件"""
        # 检查文件大小
        if len(file_content) > self.config.max_file_size:
            return False
        
        # 检查文件扩展名
        file_extension = Path(filename).suffix.lower()
        if file_extension not in self.config.allowed_extensions:
            return False
        
        # 可以添加更多验证逻辑，如文件头检查等
        return True
    
    def get_storage_recommendation(self, file_size: int) -> Dict[str, Any]:
        """获取存储建议"""
        if file_size <= self.config.max_file_size:
            return {
                "recommended": "file_storage",
                "reason": "文件大小适中，使用文件存储",
                "efficient": True
            }
        else:
            return {
                "recommended": "reject",
                "reason": "文件过大，请压缩后重试",
                "efficient": False
            }

class ImageStorageManager:
    """图片存储管理器"""
    
    def __init__(self):
        self.config = ImageStorageConfig()
        self.processor = ImageProcessor(self.config)
    
    def get_optimization_stats(self) -> Dict[str, Any]:
        """获取存储优化统计信息"""
        try:
            # 统计文件存储的图片数量
            file_count = len(list(self.config.upload_dir.glob("*")))
            
            return {
                "storage_strategy": self.config.get_storage_strategy().value,
                "upload_directory": str(self.config.upload_dir),
                "file_count": file_count,
                "max_file_size": self.config.max_file_size,
                "max_base64_size": self.config.max_base64_size,
                "allowed_extensions": list(self.config.allowed_extensions),
                "base_url": self.config.base_url
            }
        except Exception as e:
            logger.error(f"获取优化统计信息失败: {e}")
            return {}
    
    def cleanup_orphaned_files(self) -> int:
        """清理孤立的图片文件（数据库中不存在引用的文件）"""
        try:
            from app.database import get_db
            from sqlalchemy import text
            
            # 获取数据库中引用的所有图片文件名
            referenced_files = set()
            
            with next(get_db()) as db:
                # 查询普通消息中的图片
                result = db.execute(text("""
                    SELECT content FROM messages 
                    WHERE content LIKE '[图片] %'
                """))
                for row in result:
                    content = row[0]
                    if content.startswith('[图片] '):
                        image_data = content.replace('[图片] ', '')
                        if not image_data.startswith('data:image/'):
                            # 提取文件名
                            filename = image_data.split('/')[-1]
                            referenced_files.add(filename)
                
                # 查询客服消息中的图片
                result = db.execute(text("""
                    SELECT content FROM customer_service_messages 
                    WHERE content LIKE '[图片] %'
                """))
                for row in result:
                    content = row[0]
                    if content.startswith('[图片] '):
                        image_data = content.replace('[图片] ', '')
                        if not image_data.startswith('data:image/'):
                            # 提取文件名
                            filename = image_data.split('/')[-1]
                            referenced_files.add(filename)
            
            # 清理孤立的文件
            cleaned_count = 0
            for file_path in self.config.upload_dir.glob("*"):
                if file_path.is_file() and file_path.name not in referenced_files:
                    try:
                        file_path.unlink()
                        cleaned_count += 1
                        logger.info(f"删除孤立文件: {file_path.name}")
                    except Exception as e:
                        logger.error(f"删除文件失败 {file_path.name}: {e}")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理孤立文件失败: {e}")
            return 0

# 全局实例
image_storage_manager = ImageStorageManager()

"""
服务层模块
提供业务逻辑封装，避免在路由层直接使用装饰器
"""

# 存储后端
from app.services.storage_backend import (
    StorageBackend,
    LocalStorageBackend,
    S3StorageBackend,
    get_storage_backend,
    get_default_storage,
)

# 图片处理
from app.services.image_processor import (
    ImageProcessor,
    ImageFormat,
    ImageSize,
    ThumbnailConfig,
    THUMBNAIL_PRESETS,
    image_processor,
)

# 图片上传服务
from app.services.image_upload_service import (
    ImageUploadService,
    ImageCategory,
    UploadConfig,
    UploadResult,
    CATEGORY_CONFIGS,
    get_image_upload_service,
)

# 存储监控
from app.services.storage_metrics import (
    StorageMetricsCollector,
    StorageStats,
    CategoryStats,
    UploadMetrics,
    get_storage_metrics_collector,
)

__all__ = [
    # 存储后端
    'StorageBackend',
    'LocalStorageBackend',
    'S3StorageBackend',
    'get_storage_backend',
    'get_default_storage',
    # 图片处理
    'ImageProcessor',
    'ImageFormat',
    'ImageSize',
    'ThumbnailConfig',
    'THUMBNAIL_PRESETS',
    'image_processor',
    # 图片上传服务
    'ImageUploadService',
    'ImageCategory',
    'UploadConfig',
    'UploadResult',
    'CATEGORY_CONFIGS',
    'get_image_upload_service',
    # 存储监控
    'StorageMetricsCollector',
    'StorageStats',
    'CategoryStats',
    'UploadMetrics',
    'get_storage_metrics_collector',
]

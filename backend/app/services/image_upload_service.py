"""
统一图片上传服务
整合存储后端、图片处理和业务逻辑
"""

import os
import uuid
import logging
import threading
import re
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from app.services.storage_backend import StorageBackend, get_default_storage
from app.services.image_processor import (
    ImageProcessor, image_processor, 
    ImageFormat, ThumbnailConfig, THUMBNAIL_PRESETS
)

logger = logging.getLogger(__name__)


class ImageCategory(Enum):
    """图片分类"""
    # 公开图片
    TASK = "public/images/public"  # 任务图片
    BANNER = "public/images/banner"  # Banner 图片
    ACTIVITY = "public/images/activities"  # 官方活动图片
    LEADERBOARD_COVER = "public/images/leaderboard_covers"  # 榜单封面
    LEADERBOARD_ITEM = "public/images/leaderboard_items"  # 竞品图片
    EXPERT_AVATAR = "public/images/expert_avatars"  # 任务达人头像
    SERVICE_IMAGE = "public/images/service_images"  # 服务图片
    
    # 论坛帖子
    FORUM_POST = "public/images/forum_posts"  # 帖子图片
    
    # 跳蚤市场
    FLEA_MARKET = "flea_market"  # 商品图片
    
    # 私密图片
    PRIVATE_TASK_CHAT = "private_images/tasks"  # 任务聊天图片
    PRIVATE_CS_CHAT = "private_images/chats"  # 客服聊天图片
    
    # 私密文件
    PRIVATE_TASK_FILE = "private_files/tasks"  # 任务聊天文件
    PRIVATE_CS_FILE = "private_files/chats"  # 客服聊天文件


@dataclass
class UploadConfig:
    """上传配置"""
    max_size: int = 5 * 1024 * 1024  # 最大文件大小（5MB）
    allowed_extensions: Tuple[str, ...] = ('.jpg', '.jpeg', '.png', '.gif', '.webp')
    compress: bool = True  # 是否压缩
    compress_quality: int = 85  # 压缩质量
    convert_to_webp: bool = False  # 是否转换为 WebP
    generate_thumbnails: bool = False  # 是否生成缩略图
    thumbnail_presets: Tuple[str, ...] = ('thumb', 'medium')  # 缩略图预设
    strip_metadata: bool = True  # 是否移除元数据
    auto_orient: bool = True  # 是否自动旋转
    max_dimension: Optional[int] = 2048  # 最大边长（像素），None 表示不限制


# 各类别的默认配置
CATEGORY_CONFIGS: Dict[ImageCategory, UploadConfig] = {
    ImageCategory.TASK: UploadConfig(
        max_size=10 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=2048
    ),
    ImageCategory.BANNER: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=90,
        max_dimension=1920
    ),
    ImageCategory.ACTIVITY: UploadConfig(
        max_size=10 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=1920
    ),
    ImageCategory.LEADERBOARD_COVER: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=1280
    ),
    ImageCategory.LEADERBOARD_ITEM: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        generate_thumbnails=True,
        thumbnail_presets=('thumb',),
        max_dimension=1280
    ),
    ImageCategory.EXPERT_AVATAR: UploadConfig(
        max_size=2 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=512
    ),
    ImageCategory.SERVICE_IMAGE: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=1280
    ),
    ImageCategory.FORUM_POST: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        max_dimension=1920
    ),
    ImageCategory.FLEA_MARKET: UploadConfig(
        max_size=10 * 1024 * 1024,
        compress=True,
        compress_quality=85,
        generate_thumbnails=True,
        thumbnail_presets=('thumb', 'medium'),
        max_dimension=1920
    ),
    ImageCategory.PRIVATE_TASK_CHAT: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=80,
        max_dimension=1920
    ),
    ImageCategory.PRIVATE_CS_CHAT: UploadConfig(
        max_size=5 * 1024 * 1024,
        compress=True,
        compress_quality=80,
        max_dimension=1920
    ),
}


@dataclass
class UploadResult:
    """上传结果"""
    success: bool
    url: str = ""
    path: str = ""
    filename: str = ""
    size: int = 0
    original_size: int = 0
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnails: Optional[Dict[str, str]] = None  # {预设名: URL}
    error: Optional[str] = None


class ImageUploadService:
    """统一图片上传服务"""
    
    def __init__(
        self,
        storage: Optional[StorageBackend] = None,
        processor: Optional[ImageProcessor] = None
    ):
        """
        初始化图片上传服务
        
        Args:
            storage: 存储后端，默认使用全局实例
            processor: 图片处理器，默认使用全局实例
        """
        self.storage = storage or get_default_storage()
        self.processor = processor or image_processor
    
    def upload(
        self,
        content: bytes,
        category: ImageCategory,
        resource_id: Optional[str] = None,
        user_id: Optional[str] = None,
        filename: Optional[str] = None,
        is_temp: bool = False,
        config: Optional[UploadConfig] = None
    ) -> UploadResult:
        """
        上传图片
        
        Args:
            content: 图片二进制内容
            category: 图片分类
            resource_id: 资源 ID（任务ID、商品ID等）
            user_id: 用户 ID（用于临时目录）
            filename: 原始文件名
            is_temp: 是否存储到临时目录
            config: 自定义上传配置，默认使用类别配置
            
        Returns:
            上传结果
        """
        try:
            # 验证输入
            if not content:
                return UploadResult(
                    success=False,
                    error="文件内容为空"
                )
            
            if len(content) == 0:
                return UploadResult(
                    success=False,
                    error="文件内容为空"
                )
            
            # 获取配置
            cfg = config or CATEGORY_CONFIGS.get(category, UploadConfig())
            original_size = len(content)
            
            # 验证文件大小
            if original_size > cfg.max_size:
                return UploadResult(
                    success=False,
                    error=f"文件过大，最大允许 {cfg.max_size // (1024*1024)}MB"
                )
            
            # 检测文件类型
            ext = self._detect_extension(content, filename)
            if ext.lower() not in cfg.allowed_extensions:
                return UploadResult(
                    success=False,
                    error=f"不支持的文件类型，允许: {', '.join(cfg.allowed_extensions)}"
                )
            
            # 验证图片内容
            if not self._validate_image_content(content):
                return UploadResult(
                    success=False,
                    error="无效的图片文件"
                )
            
            # 获取原始图片信息
            original_info = self.processor.get_image_info(content)
            width = original_info.get('width') if original_info else None
            height = original_info.get('height') if original_info else None
            
            # 图片处理
            processed_content = content
            
            # 自动旋转
            if cfg.auto_orient:
                processed_content = self.processor.auto_orient(processed_content)
            
            # 移除元数据
            if cfg.strip_metadata:
                processed_content, _ = self.processor.strip_metadata(processed_content)
            
            # 调整尺寸
            if cfg.max_dimension and width and height:
                if width > cfg.max_dimension or height > cfg.max_dimension:
                    processed_content, ext, new_size = self.processor.resize(
                        processed_content,
                        max_width=cfg.max_dimension,
                        max_height=cfg.max_dimension,
                        quality=cfg.compress_quality
                    )
                    width = new_size.width
                    height = new_size.height
            
            # 转换为 WebP
            if cfg.convert_to_webp:
                processed_content, ext = self.processor.convert_to_webp(
                    processed_content,
                    quality=cfg.compress_quality
                )
            # 或者压缩
            elif cfg.compress:
                processed_content, ext = self.processor.compress(
                    processed_content,
                    quality=cfg.compress_quality
                )
            
            # 生成文件名
            file_id = str(uuid.uuid4())
            new_filename = f"{file_id}{ext}"
            
            # 构建存储路径
            storage_path = self._build_storage_path(
                category, resource_id, user_id, new_filename, is_temp
            )
            
            # 上传到存储后端
            url = self.storage.upload(processed_content, storage_path)
            
            # 生成缩略图
            thumbnails = None
            if cfg.generate_thumbnails:
                thumbnails = self._generate_and_upload_thumbnails(
                    processed_content,
                    category,
                    resource_id,
                    user_id,
                    file_id,
                    is_temp,
                    cfg.thumbnail_presets
                )
            
            logger.info(
                f"图片上传成功: category={category.value}, "
                f"path={storage_path}, size={len(processed_content)}, "
                f"original_size={original_size}"
            )
            
            return UploadResult(
                success=True,
                url=url,
                path=storage_path,
                filename=new_filename,
                size=len(processed_content),
                original_size=original_size,
                width=width,
                height=height,
                thumbnails=thumbnails
            )
            
        except Exception as e:
            logger.error(f"图片上传失败: {e}", exc_info=True)
            return UploadResult(
                success=False,
                error=str(e)
            )
    
    def move_from_temp(
        self,
        category: ImageCategory,
        user_id: str,
        resource_id: str,
        image_urls: List[str]
    ) -> List[str]:
        """
        将图片从临时目录移动到正式目录
        
        Args:
            category: 图片分类
            user_id: 用户 ID
            resource_id: 资源 ID
            image_urls: 临时图片 URL 列表
            
        Returns:
            新的图片 URL 列表
        """
        # 验证输入
        if not user_id or not resource_id:
            logger.warning(f"move_from_temp: user_id 或 resource_id 为空")
            return image_urls or []
        
        if not image_urls:
            return []
        
        new_urls = []
        temp_marker = f"/temp_{user_id}/"
        temp_dir = f"temp_{user_id}"
        
        # 获取存储后端的public_url（如果有），用于从URL中提取相对路径
        public_url = None
        if hasattr(self.storage, 'public_url') and self.storage.public_url:
            public_url = self.storage.public_url.rstrip('/')
        
        for url in image_urls:
            try:
                # 检查是否是临时目录的图片
                if temp_marker not in url:
                    # 不是临时图片，保留原 URL
                    new_urls.append(url)
                    continue
                
                # 从 URL 提取相对路径
                # 如果URL包含public_url前缀，去掉它
                relative_path = url
                
                # 处理public_url匹配（支持有协议和无协议的URL）
                if public_url:
                    # 去掉public_url的协议部分用于比较
                    public_url_no_protocol = public_url.replace('https://', '').replace('http://', '')
                    url_no_protocol = url.replace('https://', '').replace('http://', '')
                    
                    if url.startswith(public_url) or url_no_protocol.startswith(public_url_no_protocol):
                        # 使用原始public_url进行替换（保持协议一致性）
                        if url.startswith(public_url):
                            relative_path = url[len(public_url):].lstrip('/')
                        else:
                            # 如果URL没有协议，但域名匹配
                            relative_path = url_no_protocol[len(public_url_no_protocol):].lstrip('/')
                    else:
                        # 尝试从URL中提取路径部分（去掉协议和域名）
                        from urllib.parse import urlparse
                        # 如果URL没有协议，添加https://以便urlparse正确解析
                        url_to_parse = url if '://' in url else f'https://{url}'
                        parsed = urlparse(url_to_parse)
                        relative_path = parsed.path.lstrip('/')
                else:
                    # 尝试从URL中提取路径部分（去掉协议和域名）
                    from urllib.parse import urlparse
                    # 如果URL没有协议，添加https://以便urlparse正确解析
                    url_to_parse = url if '://' in url else f'https://{url}'
                    parsed = urlparse(url_to_parse)
                    relative_path = parsed.path.lstrip('/')
                
                logger.debug(f"move_from_temp: URL={url}, public_url={public_url}, extracted_path={relative_path}")
                
                # 规范化路径：存储层使用 category/... 不含 uploads/ 前缀，URL 可能含 uploads/
                if relative_path.startswith("uploads/"):
                    relative_path = relative_path[len("uploads/"):].lstrip("/")
                
                # 验证路径格式
                if not relative_path.startswith(category.value):
                    logger.warning(f"图片路径格式不正确: {relative_path}, 期望以 {category.value} 开头, URL={url}, public_url={public_url}")
                    new_urls.append(url)
                    continue
                
                # 构建源路径和目标路径
                src_path = relative_path
                # 替换临时目录为正式目录
                dst_path = src_path.replace(f"{category.value}/{temp_dir}/", f"{category.value}/{resource_id}/")
                
                # 提取文件名（用于移动缩略图）
                filename = src_path.split('/')[-1]
                
                # 移动文件
                logger.info(f"尝试移动图片: src_path={src_path}, dst_path={dst_path}")
                if self.storage.move(src_path, dst_path):
                    new_url = self.storage.get_url(dst_path)
                    new_urls.append(new_url)
                    
                    # 同时移动缩略图
                    self._move_thumbnails(category, temp_dir, resource_id, filename)
                    
                    logger.info(f"图片移动成功: {src_path} -> {dst_path}, new_url={new_url}")
                else:
                    # 移动失败，保留原 URL
                    new_urls.append(url)
                    logger.warning(f"图片移动失败: {src_path} -> {dst_path}, 保留原URL: {url}")
                    
            except Exception as e:
                logger.error(f"图片移动异常: {url}, 错误: {e}", exc_info=True)
                new_urls.append(url)
        
        return new_urls
    
    def delete(
        self,
        category: ImageCategory,
        resource_id: str,
        image_urls: Optional[List[str]] = None
    ) -> bool:
        """
        删除图片
        
        Args:
            category: 图片分类
            resource_id: 资源 ID
            image_urls: 要删除的图片 URL 列表，如果为 None 则删除整个目录
            
        Returns:
            是否成功
        """
        try:
            if image_urls is None:
                # 删除整个目录
                dir_path = f"{category.value}/{resource_id}"
                return self.storage.delete_directory(dir_path)
            else:
                # 删除指定图片
                success = True
                for url in image_urls:
                    filename = url.split('/')[-1]
                    path = f"{category.value}/{resource_id}/{filename}"
                    
                    if not self.storage.delete(path):
                        success = False
                    
                    # 同时删除缩略图
                    self._delete_thumbnails(category, resource_id, filename)
                
                return success
                
        except Exception as e:
            logger.error(f"图片删除失败: {e}")
            return False
    
    def delete_temp(
        self,
        category: ImageCategory,
        user_id: str
    ) -> bool:
        """
        删除用户的临时图片目录
        
        Args:
            category: 图片分类
            user_id: 用户 ID
            
        Returns:
            是否成功
        """
        try:
            temp_dir = f"{category.value}/temp_{user_id}"
            return self.storage.delete_directory(temp_dir)
        except Exception as e:
            logger.error(f"临时目录删除失败: {e}")
            return False
    
    def get_upload_url(
        self,
        category: ImageCategory,
        resource_id: Optional[str] = None,
        user_id: Optional[str] = None,
        filename: str = "",
        is_temp: bool = False
    ) -> str:
        """
        获取图片的访问 URL
        
        Args:
            category: 图片分类
            resource_id: 资源 ID
            user_id: 用户 ID
            filename: 文件名
            is_temp: 是否为临时目录
            
        Returns:
            图片访问 URL
        """
        path = self._build_storage_path(category, resource_id, user_id, filename, is_temp)
        return self.storage.get_url(path)
    
    def _build_storage_path(
        self,
        category: ImageCategory,
        resource_id: Optional[str],
        user_id: Optional[str],
        filename: str,
        is_temp: bool
    ) -> str:
        """构建存储路径（带输入验证）"""
        # 清理输入，防止路径注入
        def sanitize_id(id_str: str) -> str:
            """清理 ID，只允许字母、数字、下划线和连字符"""
            if not id_str:
                return ""
            # 移除所有非字母数字字符（保留下划线和连字符）
            sanitized = re.sub(r'[^a-zA-Z0-9_-]', '', str(id_str))
            if not sanitized:
                raise ValueError(f"无效的 ID: {id_str}")
            return sanitized
        
        # 清理文件名
        def sanitize_filename(name: str) -> str:
            """清理文件名，移除路径分隔符"""
            if not name:
                return ""
            # 只保留文件名部分，移除路径
            name = os.path.basename(name)
            # 移除危险字符
            name = re.sub(r'[<>:"|?*\x00-\x1f]', '', name)
            return name
        
        filename = sanitize_filename(filename)
        
        if is_temp and user_id:
            # 临时目录：{category}/temp_{user_id}/{filename}
            safe_user_id = sanitize_id(user_id)
            return f"{category.value}/temp_{safe_user_id}/{filename}"
        elif resource_id:
            # 正式目录：{category}/{resource_id}/{filename}
            safe_resource_id = sanitize_id(resource_id)
            return f"{category.value}/{safe_resource_id}/{filename}"
        else:
            # 没有资源 ID，直接存储在类别目录下
            return f"{category.value}/{filename}"
    
    def _detect_extension(self, content: bytes, filename: Optional[str]) -> str:
        """检测文件扩展名"""
        # 优先使用图片处理器检测
        ext = self.processor._detect_extension(content)
        
        # 如果无法检测，使用文件名
        if ext == '.jpg' and filename:
            name_ext = Path(filename).suffix.lower()
            if name_ext in ('.jpg', '.jpeg', '.png', '.gif', '.webp'):
                ext = name_ext
        
        return ext
    
    def _validate_image_content(self, content: bytes) -> bool:
        """验证图片内容"""
        if len(content) < 10:
            return False
        
        # 检查魔数
        valid_signatures = [
            b'\xff\xd8\xff',  # JPEG
            b'\x89PNG\r\n\x1a\n',  # PNG
            b'GIF87a', b'GIF89a',  # GIF
            b'RIFF',  # WebP
        ]
        
        for sig in valid_signatures:
            if content.startswith(sig):
                # WebP 需要额外检查
                if sig == b'RIFF':
                    return b'WEBP' in content[:12]
                return True
        
        return False
    
    def _generate_and_upload_thumbnails(
        self,
        content: bytes,
        category: ImageCategory,
        resource_id: Optional[str],
        user_id: Optional[str],
        file_id: str,
        is_temp: bool,
        preset_names: Tuple[str, ...]
    ) -> Dict[str, str]:
        """生成并上传缩略图"""
        thumbnails = {}
        
        thumb_results = self.processor.generate_thumbnails(content, list(preset_names))
        
        for preset_name, (thumb_content, ext) in thumb_results.items():
            config = THUMBNAIL_PRESETS[preset_name]
            thumb_filename = f"{file_id}{config.name}{ext}"
            thumb_path = self._build_storage_path(
                category, resource_id, user_id, thumb_filename, is_temp
            )
            
            try:
                url = self.storage.upload(thumb_content, thumb_path)
                thumbnails[preset_name] = url
            except Exception as e:
                logger.error(f"缩略图上传失败: {preset_name}, 错误: {e}")
        
        return thumbnails
    
    def _move_thumbnails(
        self,
        category: ImageCategory,
        temp_dir: str,
        resource_id: str,
        filename: str
    ) -> None:
        """移动缩略图"""
        file_id = Path(filename).stem
        
        for preset_name, config in THUMBNAIL_PRESETS.items():
            for ext in ('.webp', '.jpg', '.png'):
                thumb_filename = f"{file_id}{config.name}{ext}"
                src_path = f"{category.value}/{temp_dir}/{thumb_filename}"
                
                if self.storage.exists(src_path):
                    dst_path = f"{category.value}/{resource_id}/{thumb_filename}"
                    self.storage.move(src_path, dst_path)
    
    def _delete_thumbnails(
        self,
        category: ImageCategory,
        resource_id: str,
        filename: str
    ) -> None:
        """删除缩略图"""
        file_id = Path(filename).stem
        
        for preset_name, config in THUMBNAIL_PRESETS.items():
            for ext in ('.webp', '.jpg', '.png'):
                thumb_filename = f"{file_id}{config.name}{ext}"
                path = f"{category.value}/{resource_id}/{thumb_filename}"
                self.storage.delete(path)


# 全局服务实例（延迟初始化，线程安全）
_image_upload_service: Optional[ImageUploadService] = None
_service_lock = threading.Lock()


def get_image_upload_service() -> ImageUploadService:
    """获取图片上传服务实例（线程安全）"""
    global _image_upload_service
    if _image_upload_service is None:
        with _service_lock:
            # 双重检查锁定模式
            if _image_upload_service is None:
                _image_upload_service = ImageUploadService()
    return _image_upload_service

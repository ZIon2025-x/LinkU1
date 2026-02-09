"""
图片处理服务
提供压缩、格式转换、缩略图生成等功能
"""

import io
import logging
from typing import Optional, Tuple, Dict, Any, List
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)


class ImageFormat(Enum):
    """支持的图片格式"""
    JPEG = "jpeg"
    PNG = "png"
    WEBP = "webp"
    GIF = "gif"


@dataclass
class ImageSize:
    """图片尺寸"""
    width: int
    height: int
    
    def __str__(self) -> str:
        return f"{self.width}x{self.height}"


@dataclass
class ThumbnailConfig:
    """缩略图配置"""
    name: str  # 缩略图名称后缀，如 "_thumb", "_medium"
    max_width: int
    max_height: int
    quality: int = 85
    format: ImageFormat = ImageFormat.WEBP


# 预定义的缩略图尺寸
THUMBNAIL_PRESETS = {
    "tiny": ThumbnailConfig(name="_tiny", max_width=64, max_height=64, quality=75),
    "thumb": ThumbnailConfig(name="_thumb", max_width=150, max_height=150, quality=80),
    "small": ThumbnailConfig(name="_small", max_width=320, max_height=320, quality=85),
    "medium": ThumbnailConfig(name="_medium", max_width=640, max_height=640, quality=85),
    "large": ThumbnailConfig(name="_large", max_width=1280, max_height=1280, quality=90),
}


class ImageProcessor:
    """图片处理器"""
    
    def __init__(self):
        """初始化图片处理器"""
        self._pillow_available = None
        
        # 🔒 安全修复：设置图片最大像素限制，防止解压炸弹（decompression bomb）DoS
        try:
            from PIL import Image
            Image.MAX_IMAGE_PIXELS = 25_000_000  # 25 megapixels max
        except ImportError:
            pass
    
    @property
    def pillow_available(self) -> bool:
        """检查 Pillow 是否可用"""
        if self._pillow_available is None:
            try:
                from PIL import Image
                self._pillow_available = True
            except ImportError:
                self._pillow_available = False
                logger.warning("Pillow 未安装，图片处理功能不可用。请运行: pip install Pillow")
        return self._pillow_available
    
    def get_image_info(self, content: bytes) -> Optional[Dict[str, Any]]:
        """
        获取图片信息
        
        Args:
            content: 图片二进制内容
            
        Returns:
            图片信息字典，包含 width, height, format 等
        """
        if not self.pillow_available:
            return None
        
        try:
            from PIL import Image
            
            with Image.open(io.BytesIO(content)) as img:
                return {
                    "width": img.width,
                    "height": img.height,
                    "format": img.format.lower() if img.format else None,
                    "mode": img.mode,
                    "size": len(content)
                }
        except Exception as e:
            logger.error(f"获取图片信息失败: {e}")
            return None
    
    def compress(
        self,
        content: bytes,
        quality: int = 85,
        max_size: Optional[int] = None,
        output_format: Optional[ImageFormat] = None
    ) -> Tuple[bytes, str]:
        """
        压缩图片
        
        Args:
            content: 原始图片内容
            quality: 压缩质量（1-100）
            max_size: 最大文件大小（字节），如果设置会自动调整质量
            output_format: 输出格式，默认保持原格式
            
        Returns:
            (压缩后的内容, 文件扩展名)
        """
        if not self.pillow_available:
            # 无法处理，返回原始内容
            ext = self._detect_extension(content)
            return content, ext
        
        try:
            from PIL import Image
            
            with Image.open(io.BytesIO(content)) as img:
                # 处理透明通道
                original_format = img.format.lower() if img.format else 'jpeg'
                
                # 确定输出格式
                if output_format:
                    target_format = output_format.value
                else:
                    target_format = original_format
                
                # 处理格式转换
                if target_format in ('jpeg', 'jpg') and img.mode in ('RGBA', 'LA', 'P'):
                    # JPEG 不支持透明，转换为 RGB
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    background.paste(img, mask=img.split()[-1] if 'A' in img.mode else None)
                    img = background
                
                # 压缩图片
                output = io.BytesIO()
                
                # 根据格式设置保存参数
                save_kwargs = self._get_save_kwargs(target_format, quality)
                
                # 保存图片
                img.save(output, format=target_format.upper(), **save_kwargs)
                result = output.getvalue()
                
                # 如果设置了最大文件大小，循环降低质量
                if max_size and len(result) > max_size:
                    current_quality = quality
                    while len(result) > max_size and current_quality > 20:
                        current_quality -= 10
                        output = io.BytesIO()
                        save_kwargs = self._get_save_kwargs(target_format, current_quality)
                        img.save(output, format=target_format.upper(), **save_kwargs)
                        result = output.getvalue()
                    
                    logger.debug(f"图片压缩: {len(content)} -> {len(result)} 字节, 质量: {current_quality}")
                
                # 获取文件扩展名
                ext = f".{target_format}" if not target_format.startswith('.') else target_format
                if ext == '.jpeg':
                    ext = '.jpg'
                
                return result, ext
                
        except Exception as e:
            logger.error(f"图片压缩失败: {e}")
            ext = self._detect_extension(content)
            return content, ext
    
    def convert_to_webp(
        self,
        content: bytes,
        quality: int = 85,
        lossless: bool = False
    ) -> Tuple[bytes, str]:
        """
        将图片转换为 WebP 格式
        
        Args:
            content: 原始图片内容
            quality: 压缩质量（1-100）
            lossless: 是否使用无损压缩
            
        Returns:
            (WebP 图片内容, ".webp")
        """
        if not self.pillow_available:
            ext = self._detect_extension(content)
            return content, ext
        
        try:
            from PIL import Image
            
            with Image.open(io.BytesIO(content)) as img:
                output = io.BytesIO()
                
                # WebP 支持透明通道
                if img.mode == 'P':
                    img = img.convert('RGBA')
                
                img.save(
                    output,
                    format='WEBP',
                    quality=quality,
                    lossless=lossless,
                    method=4  # 压缩方法（0-6），4 是速度和压缩率的平衡
                )
                
                result = output.getvalue()
                logger.debug(f"WebP 转换: {len(content)} -> {len(result)} 字节")
                
                return result, '.webp'
                
        except Exception as e:
            logger.error(f"WebP 转换失败: {e}")
            ext = self._detect_extension(content)
            return content, ext
    
    def resize(
        self,
        content: bytes,
        max_width: int,
        max_height: int,
        quality: int = 85,
        output_format: Optional[ImageFormat] = None,
        maintain_aspect_ratio: bool = True
    ) -> Tuple[bytes, str, ImageSize]:
        """
        调整图片尺寸
        
        Args:
            content: 原始图片内容
            max_width: 最大宽度
            max_height: 最大高度
            quality: 压缩质量
            output_format: 输出格式
            maintain_aspect_ratio: 是否保持宽高比
            
        Returns:
            (调整后的内容, 文件扩展名, 新尺寸)
        """
        if not self.pillow_available:
            ext = self._detect_extension(content)
            return content, ext, ImageSize(0, 0)
        
        try:
            from PIL import Image
            
            with Image.open(io.BytesIO(content)) as img:
                original_format = img.format.lower() if img.format else 'jpeg'
                original_size = ImageSize(img.width, img.height)
                
                # 计算新尺寸
                if maintain_aspect_ratio:
                    # 保持宽高比
                    ratio = min(max_width / img.width, max_height / img.height)
                    if ratio >= 1:
                        # 图片已经小于目标尺寸，不需要调整
                        ext = f".{original_format}"
                        return content, ext, original_size
                    
                    new_width = int(img.width * ratio)
                    new_height = int(img.height * ratio)
                else:
                    new_width = min(img.width, max_width)
                    new_height = min(img.height, max_height)
                
                # 调整尺寸
                resized = img.resize(
                    (new_width, new_height),
                    Image.Resampling.LANCZOS
                )
                
                # 确定输出格式
                target_format = output_format.value if output_format else original_format
                
                # 处理透明通道
                if target_format in ('jpeg', 'jpg') and resized.mode in ('RGBA', 'LA', 'P'):
                    background = Image.new('RGB', resized.size, (255, 255, 255))
                    if resized.mode == 'P':
                        resized = resized.convert('RGBA')
                    background.paste(resized, mask=resized.split()[-1] if 'A' in resized.mode else None)
                    resized = background
                
                # 保存
                output = io.BytesIO()
                save_kwargs = self._get_save_kwargs(target_format, quality)
                resized.save(output, format=target_format.upper(), **save_kwargs)
                
                result = output.getvalue()
                new_size = ImageSize(new_width, new_height)
                
                ext = f".{target_format}"
                if ext == '.jpeg':
                    ext = '.jpg'
                
                logger.debug(f"图片调整尺寸: {original_size} -> {new_size}, {len(content)} -> {len(result)} 字节")
                
                return result, ext, new_size
                
        except Exception as e:
            logger.error(f"图片调整尺寸失败: {e}")
            ext = self._detect_extension(content)
            return content, ext, ImageSize(0, 0)
    
    def generate_thumbnail(
        self,
        content: bytes,
        config: ThumbnailConfig
    ) -> Tuple[bytes, str]:
        """
        生成缩略图
        
        Args:
            content: 原始图片内容
            config: 缩略图配置
            
        Returns:
            (缩略图内容, 文件扩展名)
        """
        result, ext, _ = self.resize(
            content,
            max_width=config.max_width,
            max_height=config.max_height,
            quality=config.quality,
            output_format=config.format
        )
        return result, ext
    
    def generate_thumbnails(
        self,
        content: bytes,
        preset_names: Optional[List[str]] = None
    ) -> Dict[str, Tuple[bytes, str]]:
        """
        生成多个预设尺寸的缩略图
        
        Args:
            content: 原始图片内容
            preset_names: 要生成的预设名称列表，如 ["thumb", "medium"]
                         如果为 None，生成所有预设
            
        Returns:
            {预设名称: (缩略图内容, 文件扩展名)}
        """
        if preset_names is None:
            preset_names = list(THUMBNAIL_PRESETS.keys())
        
        results = {}
        for name in preset_names:
            if name in THUMBNAIL_PRESETS:
                config = THUMBNAIL_PRESETS[name]
                thumb_content, ext = self.generate_thumbnail(content, config)
                results[name] = (thumb_content, ext)
        
        return results
    
    def auto_orient(self, content: bytes) -> bytes:
        """
        根据 EXIF 信息自动旋转图片
        
        Args:
            content: 原始图片内容
            
        Returns:
            自动旋转后的图片内容
        """
        if not self.pillow_available:
            return content
        
        try:
            from PIL import Image, ExifTags
            
            with Image.open(io.BytesIO(content)) as img:
                # 查找 Orientation 标签
                exif = img.getexif()
                if not exif:
                    return content
                
                orientation_key = None
                for key, val in ExifTags.TAGS.items():
                    if val == 'Orientation':
                        orientation_key = key
                        break
                
                if orientation_key is None or orientation_key not in exif:
                    return content
                
                orientation = exif[orientation_key]
                
                # 根据方向旋转
                if orientation == 2:
                    img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                elif orientation == 3:
                    img = img.rotate(180)
                elif orientation == 4:
                    img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                elif orientation == 5:
                    img = img.rotate(-90, expand=True).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                elif orientation == 6:
                    img = img.rotate(-90, expand=True)
                elif orientation == 7:
                    img = img.rotate(90, expand=True).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                elif orientation == 8:
                    img = img.rotate(90, expand=True)
                else:
                    return content
                
                # 保存修正后的图片
                output = io.BytesIO()
                img_format = img.format or 'JPEG'
                img.save(output, format=img_format)
                return output.getvalue()
                
        except Exception as e:
            logger.error(f"自动旋转失败: {e}")
            return content
    
    def strip_metadata(self, content: bytes) -> Tuple[bytes, str]:
        """
        移除图片的 EXIF 等元数据（保护隐私）
        
        Args:
            content: 原始图片内容
            
        Returns:
            (去除元数据的图片内容, 文件扩展名)
        """
        if not self.pillow_available:
            ext = self._detect_extension(content)
            return content, ext
        
        try:
            from PIL import Image
            
            with Image.open(io.BytesIO(content)) as img:
                # 创建不含 EXIF 的新图片
                data = list(img.getdata())
                img_without_exif = Image.new(img.mode, img.size)
                img_without_exif.putdata(data)
                
                # 保存
                output = io.BytesIO()
                img_format = img.format or 'JPEG'
                img_without_exif.save(output, format=img_format)
                
                ext = f".{img_format.lower()}"
                if ext == '.jpeg':
                    ext = '.jpg'
                
                return output.getvalue(), ext
                
        except Exception as e:
            logger.error(f"移除元数据失败: {e}")
            ext = self._detect_extension(content)
            return content, ext
    
    def _get_save_kwargs(self, format: str, quality: int) -> Dict[str, Any]:
        """获取不同格式的保存参数"""
        format = format.lower()
        
        if format in ('jpeg', 'jpg'):
            return {
                'quality': quality,
                'optimize': True,
                'progressive': True
            }
        elif format == 'png':
            return {
                'optimize': True
            }
        elif format == 'webp':
            return {
                'quality': quality,
                'method': 4
            }
        elif format == 'gif':
            return {}
        else:
            return {}
    
    def _detect_extension(self, content: bytes) -> str:
        """检测图片格式并返回扩展名"""
        if len(content) < 10:
            return '.jpg'
        
        # 检查魔数
        if content.startswith(b'\xff\xd8\xff'):
            return '.jpg'
        elif content.startswith(b'\x89PNG\r\n\x1a\n'):
            return '.png'
        elif content.startswith(b'GIF87a') or content.startswith(b'GIF89a'):
            return '.gif'
        elif content.startswith(b'RIFF') and b'WEBP' in content[:12]:
            return '.webp'
        else:
            return '.jpg'


# 全局图片处理器实例
image_processor = ImageProcessor()

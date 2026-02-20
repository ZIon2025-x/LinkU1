"""
存储后端抽象层
支持本地文件存储和云存储（AWS S3、Cloudflare R2）
"""

import os
import logging
import threading
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Optional, List, BinaryIO
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class StorageBackend(ABC):
    """存储后端抽象基类"""
    
    @abstractmethod
    def upload(self, content: bytes, path: str) -> str:
        """
        上传文件
        
        Args:
            content: 文件内容
            path: 存储路径（相对路径）
            
        Returns:
            访问 URL
        """
        pass
    
    @abstractmethod
    def download(self, path: str) -> Optional[bytes]:
        """
        下载文件
        
        Args:
            path: 存储路径（相对路径）
            
        Returns:
            文件内容，如果不存在返回 None
        """
        pass
    
    @abstractmethod
    def delete(self, path: str) -> bool:
        """
        删除文件
        
        Args:
            path: 存储路径（相对路径）
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def delete_directory(self, path: str) -> bool:
        """
        删除目录及其所有内容
        
        Args:
            path: 目录路径（相对路径）
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def exists(self, path: str) -> bool:
        """
        检查文件是否存在
        
        Args:
            path: 存储路径（相对路径）
            
        Returns:
            是否存在
        """
        pass
    
    @abstractmethod
    def list_files(self, directory: str) -> List[str]:
        """
        列出目录中的文件
        
        Args:
            directory: 目录路径（相对路径）
            
        Returns:
            文件路径列表
        """
        pass
    
    @abstractmethod
    def move(self, src_path: str, dst_path: str) -> bool:
        """
        移动文件
        
        Args:
            src_path: 源路径（相对路径）
            dst_path: 目标路径（相对路径）
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def get_url(self, path: str) -> str:
        """
        获取文件的访问 URL
        
        Args:
            path: 存储路径（相对路径）
            
        Returns:
            访问 URL
        """
        pass
    
    @abstractmethod
    def get_file_size(self, path: str) -> Optional[int]:
        """
        获取文件大小
        
        Args:
            path: 存储路径（相对路径）
            
        Returns:
            文件大小（字节），如果不存在返回 None
        """
        pass


class LocalStorageBackend(StorageBackend):
    """本地文件存储后端"""
    
    def __init__(self, base_dir: Optional[str] = None, base_url: Optional[str] = None):
        """
        初始化本地存储后端
        
        Args:
            base_dir: 基础存储目录，默认根据环境自动选择
            base_url: 基础 URL，用于生成访问链接
        """
        # 检测部署环境
        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        
        if base_dir:
            self.base_dir = Path(base_dir)
        elif railway_env:
            self.base_dir = Path("/data/uploads")
        else:
            self.base_dir = Path("uploads")
        
        # 确保基础目录存在
        self.base_dir.mkdir(parents=True, exist_ok=True)
        
        # 基础 URL（使用前端 URL，因为 Vercel 代理 /uploads/ 请求到后端）
        if base_url:
            self.base_url = base_url.rstrip('/')
        else:
            from app.config import Config
            self.base_url = Config.FRONTEND_URL.rstrip('/')
        
        logger.info(f"本地存储后端初始化: base_dir={self.base_dir}, base_url={self.base_url}")
    
    def _get_full_path(self, path: str) -> Path:
        """获取完整路径（带安全检查）"""
        # 移除开头的斜杠
        path = path.lstrip('/')
        
        # 安全检查：防止路径遍历攻击
        if '..' in path or path.startswith('/'):
            raise ValueError(f"不安全的路径: {path}")
        
        full_path = self.base_dir / path
        
        # 确保路径在 base_dir 内（防止路径遍历）
        try:
            full_path.resolve().relative_to(self.base_dir.resolve())
        except ValueError:
            raise ValueError(f"路径超出允许范围: {path}")
        
        return full_path
    
    def _ensure_directory(self, path: Path) -> None:
        """确保目录存在"""
        path.parent.mkdir(parents=True, exist_ok=True)
    
    def upload(self, content: bytes, path: str) -> str:
        """上传文件到本地"""
        try:
            full_path = self._get_full_path(path)
            self._ensure_directory(full_path)
            
            with open(full_path, 'wb') as f:
                f.write(content)
            
            logger.debug(f"文件上传成功: {path}")
            return self.get_url(path)
            
        except Exception as e:
            logger.error(f"文件上传失败: {path}, 错误: {e}")
            raise
    
    def download(self, path: str) -> Optional[bytes]:
        """从本地下载文件"""
        try:
            full_path = self._get_full_path(path)
            
            if not full_path.exists() or not full_path.is_file():
                return None
            
            with open(full_path, 'rb') as f:
                return f.read()
                
        except Exception as e:
            logger.error(f"文件下载失败: {path}, 错误: {e}")
            return None
    
    def delete(self, path: str) -> bool:
        """删除本地文件"""
        try:
            full_path = self._get_full_path(path)
            
            if full_path.exists() and full_path.is_file():
                full_path.unlink()
                logger.debug(f"文件删除成功: {path}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"文件删除失败: {path}, 错误: {e}")
            return False
    
    def delete_directory(self, path: str) -> bool:
        """删除本地目录及其所有内容"""
        try:
            import shutil
            full_path = self._get_full_path(path)
            
            if full_path.exists() and full_path.is_dir():
                shutil.rmtree(full_path)
                logger.debug(f"目录删除成功: {path}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"目录删除失败: {path}, 错误: {e}")
            return False
    
    def exists(self, path: str) -> bool:
        """检查本地文件是否存在"""
        full_path = self._get_full_path(path)
        return full_path.exists() and full_path.is_file()
    
    def list_files(self, directory: str) -> List[str]:
        """列出本地目录中的文件"""
        try:
            full_path = self._get_full_path(directory)
            
            if not full_path.exists() or not full_path.is_dir():
                return []
            
            files = []
            for item in full_path.iterdir():
                if item.is_file():
                    # 返回相对于 base_dir 的路径
                    rel_path = str(item.relative_to(self.base_dir))
                    files.append(rel_path)
            
            return files
            
        except Exception as e:
            logger.error(f"列出目录失败: {directory}, 错误: {e}")
            return []
    
    def list_files_with_metadata(self, directory: str) -> List[dict]:
        """
        列出本地目录中的文件及其元数据
        
        Returns:
            List of dicts with keys: 'key', 'last_modified', 'size'
        """
        try:
            from datetime import datetime
            from app.utils.time_utils import file_timestamp_to_utc
            
            full_path = self._get_full_path(directory)
            
            if not full_path.exists() or not full_path.is_dir():
                return []
            
            files = []
            for item in full_path.iterdir():
                if item.is_file():
                    # 返回相对于 base_dir 的路径
                    rel_path = str(item.relative_to(self.base_dir))
                    stat = item.stat()
                    # 将文件系统时间戳转换为 UTC datetime
                    last_modified = file_timestamp_to_utc(stat.st_mtime)
                    files.append({
                        'key': rel_path,
                        'last_modified': last_modified,
                        'size': stat.st_size
                    })
            
            return files
            
        except Exception as e:
            logger.error(f"列出目录（含元数据）失败: {directory}, 错误: {e}")
            return []
    
    def move(self, src_path: str, dst_path: str) -> bool:
        """移动本地文件"""
        try:
            src_full = self._get_full_path(src_path)
            dst_full = self._get_full_path(dst_path)
            
            if not src_full.exists():
                logger.warning(f"源文件不存在: {src_path}")
                return False
            
            self._ensure_directory(dst_full)
            
            import shutil
            shutil.move(str(src_full), str(dst_full))
            logger.debug(f"文件移动成功: {src_path} -> {dst_path}")
            return True
            
        except Exception as e:
            logger.error(f"文件移动失败: {src_path} -> {dst_path}, 错误: {e}")
            return False
    
    def get_url(self, path: str) -> str:
        """获取本地文件的访问 URL"""
        # 移除开头的斜杠
        path = path.lstrip('/')
        return f"{self.base_url}/uploads/{path}"
    
    def get_file_size(self, path: str) -> Optional[int]:
        """获取本地文件大小"""
        try:
            full_path = self._get_full_path(path)
            
            if full_path.exists() and full_path.is_file():
                return full_path.stat().st_size
            
            return None
            
        except Exception as e:
            logger.error(f"获取文件大小失败: {path}, 错误: {e}")
            return None


class S3StorageBackend(StorageBackend):
    """AWS S3 / Cloudflare R2 存储后端"""
    
    def __init__(
        self,
        bucket_name: str,
        access_key_id: Optional[str] = None,
        secret_access_key: Optional[str] = None,
        endpoint_url: Optional[str] = None,
        region_name: str = "auto",
        public_url: Optional[str] = None
    ):
        """
        初始化 S3 存储后端
        
        Args:
            bucket_name: S3 存储桶名称
            access_key_id: AWS Access Key ID
            secret_access_key: AWS Secret Access Key
            endpoint_url: 自定义端点 URL（用于 R2 等兼容服务）
            region_name: AWS 区域
            public_url: 公开访问的 URL 前缀
        """
        self.bucket_name = bucket_name
        self.public_url = public_url.rstrip('/') if public_url else None
        
        # 从环境变量获取凭证
        self.access_key_id = access_key_id or os.getenv('AWS_ACCESS_KEY_ID') or os.getenv('R2_ACCESS_KEY_ID')
        self.secret_access_key = secret_access_key or os.getenv('AWS_SECRET_ACCESS_KEY') or os.getenv('R2_SECRET_ACCESS_KEY')
        raw_endpoint_url = endpoint_url or os.getenv('S3_ENDPOINT_URL') or os.getenv('R2_ENDPOINT_URL')
        
        # 处理endpoint URL：如果包含bucket名称，去掉它（boto3会在API调用中使用bucket_name参数）
        if raw_endpoint_url:
            # R2 endpoint格式应该是: https://{account_id}.r2.cloudflarestorage.com
            # 如果URL末尾包含bucket名称，去掉它
            if raw_endpoint_url.endswith(f'/{bucket_name}'):
                self.endpoint_url = raw_endpoint_url[:-len(f'/{bucket_name}')]
                logger.info(f"从endpoint URL中移除了bucket名称: {raw_endpoint_url} -> {self.endpoint_url}")
            else:
                self.endpoint_url = raw_endpoint_url
        else:
            self.endpoint_url = None
        
        self.region_name = region_name
        
        # 延迟初始化 S3 客户端
        self._client = None
        
        logger.info(f"S3 存储后端初始化: bucket={bucket_name}, endpoint={self.endpoint_url}")
    
    @property
    def client(self):
        """延迟初始化 S3 客户端"""
        if self._client is None:
            try:
                import boto3
                self._client = boto3.client(
                    's3',
                    aws_access_key_id=self.access_key_id,
                    aws_secret_access_key=self.secret_access_key,
                    endpoint_url=self.endpoint_url,
                    region_name=self.region_name
                )
            except ImportError:
                raise ImportError("请安装 boto3: pip install boto3")
        return self._client
    
    # 🔒 安全修复：允许上传的 MIME 类型白名单
    ALLOWED_CONTENT_TYPES = {
        'image/jpeg', 'image/png', 'image/webp', 'image/gif',
        'image/heic', 'image/heif', 'image/avif',  # iOS 常见格式
        'application/pdf',
        'audio/mpeg', 'audio/wav', 'audio/ogg',
        'video/mp4', 'video/webm',
        # 注意：不包含 application/octet-stream，因为它是兜底类型，
        # 会导致任何未识别扩展名的文件都能通过白名单检查
    }
    
    # 文件大小上限
    MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
    
    def upload(self, content: bytes, path: str) -> str:
        """上传文件到 S3"""
        try:
            # 移除开头的斜杠
            path = path.lstrip('/')
            
            # 🔒 安全修复：文件大小检查
            if len(content) > self.MAX_FILE_SIZE:
                raise ValueError(f"文件过大: {len(content)} 字节，上限 {self.MAX_FILE_SIZE} 字节")
            
            # 根据文件扩展名设置 Content-Type
            content_type = self._get_content_type(path)
            
            # 🔒 安全修复：Content-Type 白名单验证
            if content_type not in self.ALLOWED_CONTENT_TYPES:
                logger.warning(f"不允许的 Content-Type: {content_type}，文件: {path}")
                raise ValueError(f"不允许的文件类型: {content_type}")
            
            # 🔒 安全修复：设置 ACL 为 private，防止 bucket 错误配置导致文件公开
            self.client.put_object(
                Bucket=self.bucket_name,
                Key=path,
                Body=content,
                ContentType=content_type,
                ACL='private'
            )
            
            logger.debug(f"S3 文件上传成功: {path}")
            return self.get_url(path)
            
        except Exception as e:
            logger.error(f"S3 文件上传失败: {path}, 错误: {e}")
            raise
    
    def download(self, path: str) -> Optional[bytes]:
        """从 S3 下载文件"""
        try:
            path = path.lstrip('/')
            
            response = self.client.get_object(
                Bucket=self.bucket_name,
                Key=path
            )
            return response['Body'].read()
            
        except self.client.exceptions.NoSuchKey:
            return None
        except Exception as e:
            logger.error(f"S3 文件下载失败: {path}, 错误: {e}")
            return None
    
    def delete(self, path: str) -> bool:
        """删除 S3 文件"""
        try:
            path = path.lstrip('/')
            
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=path
            )
            
            logger.debug(f"S3 文件删除成功: {path}")
            return True
            
        except Exception as e:
            logger.error(f"S3 文件删除失败: {path}, 错误: {e}")
            return False
    
    def delete_directory(self, path: str) -> bool:
        """删除 S3 目录（前缀）下的所有文件"""
        try:
            path = path.lstrip('/').rstrip('/') + '/'
            
            # 列出所有匹配的对象
            paginator = self.client.get_paginator('list_objects_v2')
            
            objects_to_delete = []
            for page in paginator.paginate(Bucket=self.bucket_name, Prefix=path):
                if 'Contents' in page:
                    for obj in page['Contents']:
                        objects_to_delete.append({'Key': obj['Key']})
            
            if objects_to_delete:
                # 批量删除
                self.client.delete_objects(
                    Bucket=self.bucket_name,
                    Delete={'Objects': objects_to_delete}
                )
                logger.debug(f"S3 目录删除成功: {path}, 共 {len(objects_to_delete)} 个文件")
            
            return True
            
        except Exception as e:
            logger.error(f"S3 目录删除失败: {path}, 错误: {e}")
            return False
    
    def exists(self, path: str) -> bool:
        """检查 S3 文件是否存在"""
        try:
            path = path.lstrip('/')
            
            self.client.head_object(
                Bucket=self.bucket_name,
                Key=path
            )
            return True
            
        except:
            return False
    
    def list_files(self, directory: str) -> List[str]:
        """列出 S3 目录中的文件"""
        try:
            directory = directory.lstrip('/').rstrip('/') + '/'
            
            files = []
            paginator = self.client.get_paginator('list_objects_v2')
            
            for page in paginator.paginate(Bucket=self.bucket_name, Prefix=directory):
                if 'Contents' in page:
                    for obj in page['Contents']:
                        files.append(obj['Key'])
            
            return files
            
        except Exception as e:
            logger.error(f"S3 列出目录失败: {directory}, 错误: {e}")
            return []
    
    def list_files_with_metadata(self, directory: str) -> List[dict]:
        """
        列出 S3 目录中的文件及其元数据
        
        Returns:
            List of dicts with keys: 'key', 'last_modified', 'size'
        """
        try:
            directory = directory.lstrip('/').rstrip('/') + '/'
            
            files = []
            paginator = self.client.get_paginator('list_objects_v2')
            
            for page in paginator.paginate(Bucket=self.bucket_name, Prefix=directory):
                if 'Contents' in page:
                    for obj in page['Contents']:
                        files.append({
                            'key': obj['Key'],
                            'last_modified': obj['LastModified'],
                            'size': obj.get('Size', 0)
                        })
            
            return files
            
        except Exception as e:
            logger.error(f"S3 列出目录（含元数据）失败: {directory}, 错误: {e}")
            return []
    
    def move(self, src_path: str, dst_path: str) -> bool:
        """移动 S3 文件（复制后删除）"""
        try:
            src_path = src_path.lstrip('/')
            dst_path = dst_path.lstrip('/')
            
            # 先检查源文件是否存在
            try:
                self.client.head_object(Bucket=self.bucket_name, Key=src_path)
                logger.debug(f"S3 源文件存在: {src_path}")
            except self.client.exceptions.ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', '')
                if error_code == '404' or error_code == 'NoSuchKey':
                    logger.error(f"S3 源文件不存在: {src_path}, bucket={self.bucket_name}")
                    # 尝试列出目录中的文件，帮助调试
                    try:
                        directory = '/'.join(src_path.split('/')[:-1]) + '/'
                        files = self.list_files(directory)
                        logger.error(f"目录 {directory} 中的文件: {files[:10]}")  # 只显示前10个
                    except Exception as list_error:
                        logger.error(f"列出目录失败: {list_error}")
                    return False
                else:
                    logger.warning(f"S3 检查源文件时出错: {src_path}, 错误: {e}")
                    # 继续尝试移动，可能是权限问题
            
            # 复制文件
            self.client.copy_object(
                Bucket=self.bucket_name,
                CopySource={'Bucket': self.bucket_name, 'Key': src_path},
                Key=dst_path
            )
            
            # 删除原文件
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=src_path
            )
            
            logger.info(f"S3 文件移动成功: {src_path} -> {dst_path}")
            return True
            
        except Exception as e:
            logger.error(f"S3 文件移动失败: {src_path} -> {dst_path}, bucket={self.bucket_name}, 错误: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return False
    
    def get_url(self, path: str) -> str:
        """获取 S3 文件的访问 URL"""
        path = path.lstrip('/')
        
        if self.public_url:
            # 使用公开 URL（永久有效）
            base = self.public_url.rstrip('/')
            # 确保返回绝对 URL，否则前端 img src 会按相对路径解析导致任务大厅等处图片不显示
            if not (base.startswith('http://') or base.startswith('https://')):
                base = f"https://{base}"
            return f"{base}/{path}"
        else:
            # ⚠️ 警告：没有配置 public_url，使用预签名 URL（15分钟有效期）
            # 这会导致图片 URL 在 15 分钟后失效！
            # 建议配置 S3_PUBLIC_URL 或 R2_PUBLIC_URL 环境变量
            logger.warning(
                f"S3 存储未配置 public_url，生成的预签名 URL 将在 15 分钟后过期。"
                f"建议配置 S3_PUBLIC_URL 或 R2_PUBLIC_URL 环境变量以生成永久 URL。"
            )
            # 生成预签名 URL（15分钟有效期，降低泄露风险）
            return self.client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': path},
                ExpiresIn=900  # 15分钟有效期（从1小时降低，平衡安全与可用性）
            )
    
    def get_file_size(self, path: str) -> Optional[int]:
        """获取 S3 文件大小"""
        try:
            path = path.lstrip('/')
            
            response = self.client.head_object(
                Bucket=self.bucket_name,
                Key=path
            )
            return response['ContentLength']
            
        except:
            return None
    
    EXTENSION_CONTENT_TYPES = {
        '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
        '.png': 'image/png', '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.heic': 'image/heic', '.heif': 'image/heif',
        '.avif': 'image/avif',
        '.pdf': 'application/pdf',
        '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.ogg': 'audio/ogg',
        '.mp4': 'video/mp4', '.webm': 'video/webm',
    }

    def _get_content_type(self, path: str) -> str:
        """根据文件扩展名获取 Content-Type，优先使用显式映射以避免 mimetypes 在某些环境下缺失条目"""
        import os
        ext = os.path.splitext(path)[1].lower()
        if ext in self.EXTENSION_CONTENT_TYPES:
            return self.EXTENSION_CONTENT_TYPES[ext]
        import mimetypes
        content_type, _ = mimetypes.guess_type(path)
        return content_type or 'application/octet-stream'


def get_storage_backend() -> StorageBackend:
    """
    获取存储后端实例
    
    根据环境变量选择使用本地存储或云存储
    
    环境变量:
        STORAGE_BACKEND: "local" | "s3" | "r2"
        S3_BUCKET_NAME: S3 存储桶名称
        S3_PUBLIC_URL: 公开访问的 URL 前缀
        
    Returns:
        存储后端实例
    """
    backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
    
    if backend_type == 's3':
        return S3StorageBackend(
            bucket_name=os.getenv('S3_BUCKET_NAME', 'linku-uploads'),
            public_url=os.getenv('S3_PUBLIC_URL')
        )
    elif backend_type == 'r2':
        # Cloudflare R2 使用 S3 兼容 API
        return S3StorageBackend(
            bucket_name=os.getenv('R2_BUCKET_NAME', 'linku-uploads'),
            endpoint_url=os.getenv('R2_ENDPOINT_URL'),
            public_url=os.getenv('R2_PUBLIC_URL')
        )
    else:
        # 默认使用本地存储
        return LocalStorageBackend()


# 全局存储后端实例（延迟初始化，线程安全）
_storage_backend: Optional[StorageBackend] = None
_storage_lock = threading.Lock()


def get_default_storage() -> StorageBackend:
    """获取默认存储后端实例（线程安全）"""
    global _storage_backend
    if _storage_backend is None:
        with _storage_lock:
            # 双重检查锁定模式
            if _storage_backend is None:
                _storage_backend = get_storage_backend()
    return _storage_backend

"""
安全文件上传模块
提供文件类型验证、大小限制、病毒扫描等功能
"""

import os
import hashlib
import magic
from typing import List, Dict, Any, Optional
from fastapi import UploadFile, HTTPException, status
from pathlib import Path
import logging

from app.validators import FileValidator
from app.error_handlers import raise_security_error, raise_validation_error

logger = logging.getLogger(__name__)


class SecureFileUploader:
    """安全文件上传器"""
    
    # 允许的文件类型和对应的MIME类型
    ALLOWED_TYPES = {
        "image": {
            "extensions": {"jpg", "jpeg", "png", "gif", "webp"},
            "mime_types": {
                "image/jpeg", "image/png", "image/gif", "image/webp"
            },
            "max_size": 5 * 1024 * 1024  # 5MB
        },
        "document": {
            "extensions": {"pdf", "doc", "docx", "txt"},
            "mime_types": {
                "application/pdf", 
                "application/msword",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "text/plain"
            },
            "max_size": 10 * 1024 * 1024  # 10MB
        }
    }
    
    # 危险文件扩展名
    DANGEROUS_EXTENSIONS = {
        "exe", "bat", "cmd", "com", "pif", "scr", "vbs", "js", "jar", "php",
        "asp", "aspx", "jsp", "sh", "ps1", "py", "rb", "pl", "cgi"
    }
    
    def __init__(self, upload_dir: str = "uploads"):
        self.upload_dir = Path(upload_dir)
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        
        # 创建子目录
        (self.upload_dir / "images").mkdir(exist_ok=True)
        (self.upload_dir / "documents").mkdir(exist_ok=True)
        (self.upload_dir / "temp").mkdir(exist_ok=True)
    
    def _get_file_hash(self, file_content: bytes) -> str:
        """计算文件哈希值"""
        return hashlib.sha256(file_content).hexdigest()
    
    def _detect_file_type(self, file_content: bytes, filename: str) -> str:
        """检测文件真实类型"""
        try:
            # 使用python-magic检测MIME类型
            mime_type = magic.from_buffer(file_content, mime=True)
            return mime_type
        except Exception:
            # 回退到文件扩展名检测
            extension = filename.split('.')[-1].lower() if '.' in filename else ''
            
            # 简单的扩展名到MIME类型映射
            extension_mime_map = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'gif': 'image/gif',
                'webp': 'image/webp',
                'pdf': 'application/pdf',
                'doc': 'application/msword',
                'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'txt': 'text/plain'
            }
            
            return extension_mime_map.get(extension, 'application/octet-stream')
    
    def _validate_file_type(self, file: UploadFile, category: str = "image") -> bool:
        """验证文件类型"""
        if category not in self.ALLOWED_TYPES:
            raise_validation_error(f"不支持的文件类别: {category}")
        
        # 检查文件扩展名
        if file.filename:
            extension = file.filename.split('.')[-1].lower() if '.' in file.filename else ''
            
            # 检查是否为危险扩展名
            if extension in self.DANGEROUS_EXTENSIONS:
                raise_security_error(f"不允许上传 {extension} 类型的文件")
            
            # 检查是否在允许的扩展名列表中
            if extension not in self.ALLOWED_TYPES[category]["extensions"]:
                raise_validation_error(
                    f"不支持的文件类型。允许的类型: {', '.join(self.ALLOWED_TYPES[category]['extensions'])}"
                )
        
        return True
    
    def _validate_file_size(self, file: UploadFile, category: str = "image") -> bool:
        """验证文件大小"""
        if category not in self.ALLOWED_TYPES:
            raise_validation_error(f"不支持的文件类别: {category}")
        
        max_size = self.ALLOWED_TYPES[category]["max_size"]
        
        if file.size and file.size > max_size:
            raise_validation_error(f"文件大小不能超过 {max_size // (1024*1024)}MB")
        
        return True
    
    def _validate_file_content(self, file_content: bytes, filename: str) -> bool:
        """验证文件内容"""
        # 检测文件真实类型
        detected_mime = self._detect_file_type(file_content, filename)
        
        # 检查是否为允许的MIME类型
        allowed_mimes = set()
        for category in self.ALLOWED_TYPES.values():
            allowed_mimes.update(category["mime_types"])
        
        if detected_mime not in allowed_mimes:
            raise_security_error(f"检测到不支持的文件类型: {detected_mime}")
        
        # 检查文件头魔数
        if not self._validate_file_header(file_content, detected_mime):
            raise_security_error("文件内容与扩展名不匹配")
        
        return True
    
    def _validate_file_header(self, file_content: bytes, mime_type: str) -> bool:
        """验证文件头魔数"""
        if len(file_content) < 4:
            return False
        
        # 常见文件类型的魔数
        magic_numbers = {
            'image/jpeg': [b'\xff\xd8\xff'],
            'image/png': [b'\x89PNG\r\n\x1a\n'],
            'image/gif': [b'GIF87a', b'GIF89a'],
            'image/webp': [b'RIFF', b'WEBP'],
            'application/pdf': [b'%PDF-'],
        }
        
        if mime_type in magic_numbers:
            for magic_bytes in magic_numbers[mime_type]:
                if file_content.startswith(magic_bytes):
                    return True
            return False
        
        return True  # 对于没有魔数检查的类型，返回True
    
    def _sanitize_filename(self, filename: str) -> str:
        """清理文件名，防止路径遍历攻击"""
        if not filename:
            raise_validation_error("文件名不能为空")
        
        # 移除路径分隔符
        filename = os.path.basename(filename)
        
        # 移除危险字符
        dangerous_chars = ['..', '/', '\\', ':', '*', '?', '"', '<', '>', '|']
        for char in dangerous_chars:
            filename = filename.replace(char, '_')
        
        # 限制文件名长度
        if len(filename) > 255:
            name, ext = os.path.splitext(filename)
            filename = name[:250] + ext
        
        return filename
    
    async def upload_file(
        self, 
        file: UploadFile, 
        category: str = "image",
        user_id: str = None
    ) -> Dict[str, Any]:
        """安全上传文件"""
        try:
            # 使用流式读取文件内容，避免大文件一次性读入内存
            from app.file_stream_utils import read_file_with_size_check
            
            # 获取最大文件大小
            max_size = self.ALLOWED_TYPES[category]["max_size"]
            
            # 流式读取文件内容
            file_content, file_size = await read_file_with_size_check(file, max_size)
            
            # 验证文件类型
            self._validate_file_type(file, category)
            
            # 验证文件大小
            self._validate_file_size(file, category)
            
            # 验证文件内容
            self._validate_file_content(file_content, file.filename)
            
            # 清理文件名
            safe_filename = self._sanitize_filename(file.filename)
            
            # 生成唯一文件名
            file_hash = self._get_file_hash(file_content)
            file_extension = os.path.splitext(safe_filename)[1]
            unique_filename = f"{file_hash}{file_extension}"
            
            # 确定保存路径
            save_dir = self.upload_dir / category
            save_path = save_dir / unique_filename
            
            # 如果文件已存在，直接返回现有文件信息
            if save_path.exists():
                return {
                    "filename": unique_filename,
                    "original_filename": safe_filename,
                    "file_path": str(save_path.relative_to(self.upload_dir)),
                    "file_size": len(file_content),
                    "file_hash": file_hash,
                    "category": category
                }
            
            # 保存文件
            with open(save_path, "wb") as f:
                f.write(file_content)
            
            logger.info(f"文件上传成功: {unique_filename} - 用户: {user_id}")
            
            return {
                "filename": unique_filename,
                "original_filename": safe_filename,
                "file_path": str(save_path.relative_to(self.upload_dir)),
                "file_size": len(file_content),
                "file_hash": file_hash,
                "category": category
            }
            
        except Exception as e:
            logger.error(f"文件上传失败: {str(e)} - 用户: {user_id}")
            raise
    
    def delete_file(self, file_path: str) -> bool:
        """删除文件"""
        try:
            full_path = self.upload_dir / file_path
            
            # 安全检查：确保文件在允许的目录内
            if not str(full_path.resolve()).startswith(str(self.upload_dir.resolve())):
                raise_security_error("不允许删除此文件")
            
            if full_path.exists():
                full_path.unlink()
                logger.info(f"文件删除成功: {file_path}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"文件删除失败: {str(e)}")
            return False
    
    def get_file_info(self, file_path: str) -> Optional[Dict[str, Any]]:
        """获取文件信息"""
        try:
            full_path = self.upload_dir / file_path
            
            # 安全检查：确保文件在允许的目录内
            if not str(full_path.resolve()).startswith(str(self.upload_dir.resolve())):
                return None
            
            if full_path.exists():
                stat = full_path.stat()
                return {
                    "filename": full_path.name,
                    "file_path": file_path,
                    "file_size": stat.st_size,
                    "created_at": stat.st_ctime,
                    "modified_at": stat.st_mtime
                }
            
            return None
            
        except Exception as e:
            logger.error(f"获取文件信息失败: {str(e)}")
            return None


# 全局文件上传器实例
file_uploader = SecureFileUploader()

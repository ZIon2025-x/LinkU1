"""
文件处理工具函数
提供通用的文件扩展名检测等功能
"""
from pathlib import Path
from typing import Optional
from fastapi import UploadFile


def detect_file_extension(
    filename: Optional[str] = None,
    content_type: Optional[str] = None,
    content: Optional[bytes] = None
) -> str:
    """
    智能检测文件扩展名
    优先级：filename > content_type > magic bytes
    
    Args:
        filename: 文件名（可能为 None 或 "blob"）
        content_type: Content-Type（如 "image/jpeg"）
        content: 文件内容（用于 magic bytes 检测）
    
    Returns:
        文件扩展名（如 ".jpg"），如果无法检测则返回空字符串
    """
    # 方法1: 从 filename 获取扩展名
    if filename:
        ext = Path(filename).suffix.lower()
        if ext:  # 如果成功获取到扩展名
            return ext
    
    # 方法2: 从 Content-Type 获取扩展名
    if content_type:
        content_type_lower = content_type.lower()
        if 'jpeg' in content_type_lower or 'jpg' in content_type_lower:
            return '.jpg'
        elif 'png' in content_type_lower:
            return '.png'
        elif 'gif' in content_type_lower:
            return '.gif'
        elif 'webp' in content_type_lower:
            return '.webp'
        elif 'pdf' in content_type_lower:
            return '.pdf'
        elif 'msword' in content_type_lower or 'word' in content_type_lower:
            return '.doc'
        elif 'wordprocessingml' in content_type_lower or 'docx' in content_type_lower:
            return '.docx'
        elif 'text/plain' in content_type_lower or 'text' in content_type_lower:
            return '.txt'
    
    # 方法3: 从文件内容的 magic bytes 检测
    if content and len(content) >= 4:
        # JPEG: FF D8 FF
        if content[:3] == b'\xff\xd8\xff':
            return '.jpg'
        # PNG: 89 50 4E 47
        elif content[:4] == b'\x89PNG':
            return '.png'
        # GIF: 47 49 46 38
        elif content[:4] == b'GIF8':
            return '.gif'
        # WEBP: RIFF...WEBP
        elif len(content) >= 12 and content[:4] == b'RIFF' and content[8:12] == b'WEBP':
            return '.webp'
        # PDF: %PDF
        elif content[:4] == b'%PDF':
            return '.pdf'
    
    return ''


def get_file_extension_from_upload(
    upload_file: UploadFile,
    content: Optional[bytes] = None
) -> str:
    """
    从 UploadFile 对象检测文件扩展名
    
    Args:
        upload_file: FastAPI UploadFile 对象
        content: 文件内容（可选，如果提供会使用 magic bytes 检测）
    
    Returns:
        文件扩展名（如 ".jpg"），如果无法检测则返回空字符串
    """
    return detect_file_extension(
        filename=upload_file.filename,
        content_type=upload_file.content_type,
        content=content
    )


def get_file_extension_from_filename(filename: Optional[str]) -> str:
    """
    从文件名获取扩展名（简单版本，不检测内容）
    
    Args:
        filename: 文件名
    
    Returns:
        文件扩展名（如 ".jpg"），如果无法检测则返回空字符串
    """
    if not filename:
        return ''
    return Path(filename).suffix.lower()


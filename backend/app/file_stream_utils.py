"""
流式文件处理工具
优化大文件上传的内存使用
"""

import logging
from typing import Optional, Tuple
from fastapi import UploadFile, HTTPException
from io import BytesIO

logger = logging.getLogger(__name__)

# 分块大小：1MB
CHUNK_SIZE = 1024 * 1024


async def read_file_streaming(
    file: UploadFile,
    max_size: int,
    chunk_size: int = CHUNK_SIZE
) -> Tuple[bytes, int]:
    """
    流式读取文件内容，避免大文件一次性读入内存
    
    Args:
        file: 上传的文件对象
        max_size: 最大文件大小（字节）
        chunk_size: 每次读取的块大小（默认1MB）
    
    Returns:
        Tuple[bytes, int]: (文件内容, 文件大小)
    
    Raises:
        HTTPException: 如果文件超过最大大小
    """
    file_size = 0
    chunks = []
    
    # 首先尝试从Content-Length头获取文件大小（如果可用）
    content_length = None
    if hasattr(file, 'size') and file.size:
        content_length = file.size
    elif hasattr(file, 'headers'):
        content_length_header = file.headers.get('content-length')
        if content_length_header:
            try:
                content_length = int(content_length_header)
            except ValueError:
                pass
    
    # 如果知道文件大小，提前检查
    if content_length and content_length > max_size:
        size_mb = max_size / (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"文件大小不能超过 {size_mb:.1f}MB"
        )
    
    # 流式读取文件
    try:
        # 注意：FastAPI的UploadFile是流式对象，不支持seek
        # 文件指针已经在开始位置，直接读取即可
        
        # 分块读取
        while True:
            chunk = await file.read(chunk_size)
            if not chunk:
                break
            
            file_size += len(chunk)
            
            # 检查是否超过最大大小
            if file_size > max_size:
                size_mb = max_size / (1024 * 1024)
                raise HTTPException(
                    status_code=413,
                    detail=f"文件大小不能超过 {size_mb:.1f}MB"
                )
            
            chunks.append(chunk)
            
            # 如果已经读取了足够的内容用于类型检测，可以提前停止
            # 但为了完整性，我们继续读取整个文件
            # 对于非常大的文件，可以考虑使用临时文件而不是内存
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"流式读取文件失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="读取文件失败，请重试"
        )
    
    # 合并所有块
    content = b''.join(chunks)
    
    return content, file_size


async def read_file_with_size_check(
    file: UploadFile,
    max_size: int,
    early_size_check: bool = True
) -> Tuple[bytes, int]:
    """
    读取文件内容，带大小检查
    
    Args:
        file: 上传的文件对象
        max_size: 最大文件大小（字节）
        early_size_check: 是否提前检查大小（通过Content-Length）
    
    Returns:
        Tuple[bytes, int]: (文件内容, 文件大小)
    
    Raises:
        HTTPException: 如果文件超过最大大小
    """
    # 提前检查文件大小（如果可能）
    if early_size_check:
        content_length = None
        if hasattr(file, 'size') and file.size:
            content_length = file.size
        elif hasattr(file, 'headers'):
            content_length_header = file.headers.get('content-length')
            if content_length_header:
                try:
                    content_length = int(content_length_header)
                except ValueError:
                    pass
        
        if content_length and content_length > max_size:
            size_mb = max_size / (1024 * 1024)
            raise HTTPException(
                status_code=413,
                detail=f"文件大小不能超过 {size_mb:.1f}MB"
            )
    
    # 对于小文件（< 1MB），直接读取可能更快
    # 对于大文件，使用流式读取
    if max_size <= CHUNK_SIZE:
        # 小文件直接读取
        try:
            content = await file.read()
            file_size = len(content)
            
            if file_size > max_size:
                size_mb = max_size / (1024 * 1024)
                raise HTTPException(
                    status_code=413,
                    detail=f"文件大小不能超过 {size_mb:.1f}MB"
                )
            
            return content, file_size
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"读取文件失败: {e}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="读取文件失败，请重试"
            )
    else:
        # 大文件使用流式读取
        return await read_file_streaming(file, max_size)

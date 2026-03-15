"""Lightweight file path utilities (no heavy imports)."""

import mimetypes
import re
from pathlib import Path
from typing import Optional

from fastapi import HTTPException

# Magic-byte signatures for common image/file types
_MAGIC_BYTES = [
    (b'\x89PNG\r\n\x1a\n', '.png'),
    (b'\xff\xd8\xff', '.jpg'),
    (b'GIF87a', '.gif'),
    (b'GIF89a', '.gif'),
    (b'RIFF', '.webp'),  # RIFF....WEBP — checked further below
    (b'%PDF', '.pdf'),
    (b'PK\x03\x04', '.zip'),
]


def detect_file_extension(
    *,
    filename: Optional[str] = None,
    content_type: Optional[str] = None,
    content: Optional[bytes] = None,
) -> str:
    """从文件名、Content-Type 或 magic bytes 推断文件扩展名。

    优先级: filename > content_type > magic bytes。
    找不到时返回空字符串。
    """
    # 1. 从文件名提取
    if filename:
        ext = Path(filename).suffix.lower()
        if ext:
            return ext

    # 2. 从 Content-Type 推断
    if content_type:
        ext = mimetypes.guess_extension(content_type, strict=False)
        # mimetypes 可能返回 .jpe 等，统一常见变体
        if ext == '.jpe':
            ext = '.jpg'
        if ext:
            return ext

    # 3. 从 magic bytes 推断
    if content and len(content) >= 12:
        for magic, ext in _MAGIC_BYTES:
            if content[:len(magic)] == magic:
                # RIFF 需进一步确认是 WEBP
                if magic == b'RIFF' and content[8:12] != b'WEBP':
                    continue
                return ext

    return ''

# Only allow alphanumeric, hyphen, underscore, dot (no path separators or traversal)
_SAFE_FILE_ID_RE = re.compile(r'^[\w\-]+$')


def is_safe_file_id(file_id: str) -> bool:
    """检查 file_id 是否安全（防止路径遍历攻击）。

    只允许字母数字、连字符、下划线，禁止 '..' '/' '\\' 等路径分隔符。
    """
    if not file_id or not isinstance(file_id, str):
        return False
    if len(file_id) > 200:
        return False
    return bool(_SAFE_FILE_ID_RE.match(file_id))


def _resolve_legacy_private_file_path(base_private_dir: Path, file_path_str: str) -> Path:
    """解析旧存储路径并阻止目录越界。"""
    base_dir = base_private_dir.resolve()
    resolved_path = (base_dir / file_path_str).resolve()
    try:
        resolved_path.relative_to(base_dir)
    except ValueError:
        raise HTTPException(status_code=403, detail="非法文件路径")
    return resolved_path

"""Lightweight file path utilities (no heavy imports)."""

import re
from pathlib import Path
from fastapi import HTTPException

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

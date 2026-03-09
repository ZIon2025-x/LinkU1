"""Lightweight file path utilities (no heavy imports)."""

from pathlib import Path
from fastapi import HTTPException


def _resolve_legacy_private_file_path(base_private_dir: Path, file_path_str: str) -> Path:
    """解析旧存储路径并阻止目录越界。"""
    base_dir = base_private_dir.resolve()
    resolved_path = (base_dir / file_path_str).resolve()
    try:
        resolved_path.relative_to(base_dir)
    except ValueError:
        raise HTTPException(status_code=403, detail="非法文件路径")
    return resolved_path

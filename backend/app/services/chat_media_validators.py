"""任务聊天媒体附件白名单校验(视频 + PDF)。

服务端是唯一关卡:客户端的大小/类型校验仅是 UX,后端独立校验,不信任 client meta。
所有校验失败抛 HTTPException(400, detail=...) 直接被 FastAPI 转 400 响应。
"""
from pathlib import Path
from typing import Iterable

from fastapi import HTTPException

MAX_CHAT_VIDEO_SIZE = 30 * 1024 * 1024  # 30 MB
MAX_CHAT_PDF_SIZE = 20 * 1024 * 1024    # 20 MB

_PDF_MAGIC = b"%PDF-"
_ALLOWED_VIDEO_EXTS = {".mp4", ".mov", ".m4v"}
_ALLOWED_PDF_EXTS = {".pdf"}


def _has_ftyp_box(content: bytes) -> bool:
    """检测 ISO/MP4 / QuickTime 容器的 ftyp box。

    ftyp box 格式: 4-byte big-endian size + 'ftyp' + 4-byte brand + ...
    通常位于文件开头,size 字节在偏移 0-3,'ftyp' 在偏移 4-7。
    """
    if len(content) < 12:
        return False
    return content[4:8] == b"ftyp"


def _check_extension(filename: str, allowed: Iterable[str], type_name: str) -> None:
    ext = Path(filename or "").suffix.lower()
    if ext not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"{type_name} 文件扩展名必须是 {', '.join(sorted(allowed))} 之一,收到 '{ext}'",
        )


def validate_chat_pdf(content: bytes, filename: str) -> None:
    """校验任务聊天发送的 PDF。

    通过条件:
    - 扩展名是 .pdf
    - 前 5 字节是 b'%PDF-'
    - 大小 ≤ 20MB

    校验失败抛 HTTPException(400)。
    """
    _check_extension(filename, _ALLOWED_PDF_EXTS, "PDF")

    if not content.startswith(_PDF_MAGIC):
        raise HTTPException(
            status_code=400,
            detail="PDF 内容校验失败:文件头不是 PDF magic byte (%PDF-)",
        )

    if len(content) > MAX_CHAT_PDF_SIZE:
        size_mb = MAX_CHAT_PDF_SIZE // (1024 * 1024)
        raise HTTPException(
            status_code=400,
            detail=f"PDF 文件过大,最大允许 {size_mb}MB",
        )


def validate_chat_video(content: bytes, filename: str) -> None:
    """校验任务聊天发送的视频。

    通过条件:
    - 扩展名是 .mp4 / .mov / .m4v
    - 文件含 ISO/MP4 ftyp box(偏移 4-7 是 'ftyp')
    - 大小 ≤ 30MB

    校验失败抛 HTTPException(400)。
    """
    _check_extension(filename, _ALLOWED_VIDEO_EXTS, "视频")

    if not _has_ftyp_box(content):
        raise HTTPException(
            status_code=400,
            detail="视频内容校验失败:文件头不含 mp4/mov ftyp box,可能不是有效的 MP4/MOV",
        )

    if len(content) > MAX_CHAT_VIDEO_SIZE:
        size_mb = MAX_CHAT_VIDEO_SIZE // (1024 * 1024)
        raise HTTPException(
            status_code=400,
            detail=f"视频文件过大,最大允许 {size_mb}MB",
        )

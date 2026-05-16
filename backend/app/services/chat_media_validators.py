"""任务聊天媒体附件白名单校验(视频 + PDF)。

服务端是唯一关卡:客户端的大小/类型校验仅是 UX,后端独立校验,不信任 client meta。
所有校验失败抛 HTTPException(400, detail=...) 直接被 FastAPI 转 400 响应。

**注意 magic-byte 校验是防误传,不是防攻击者**:`%PDF-` 5 字节和 `ftyp` 4 字节
都可轻易伪造。真正的防御依赖 storage 隔离 + 签名 URL + content-type 响应头。
"""
import struct
from pathlib import Path
from typing import Iterable

from fastapi import HTTPException

MAX_CHAT_VIDEO_SIZE = 30 * 1024 * 1024  # 30 MB
MAX_CHAT_PDF_SIZE = 20 * 1024 * 1024    # 20 MB

_PDF_MAGIC = b"%PDF-"
_ALLOWED_VIDEO_EXTS = {".mp4", ".mov", ".m4v"}
_ALLOWED_PDF_EXTS = {".pdf"}

# 允许的 MP4/QuickTime ftyp brand(偏移 8-12)。
# 拒绝 brand 主要排除奇形怪状的 codec 容器(如 av01/heic 等可能客户端播放失败)。
# 参考: https://www.ftyps.com/
_ALLOWED_MP4_BRANDS = {
    b"isom",  # 标准 ISO Base Media
    b"iso2",  # ISO 14496-12:2005+
    b"iso4",
    b"iso5",
    b"iso6",
    b"mp41",  # MP4 v1
    b"mp42",  # MP4 v2
    b"avc1",  # H.264/AVC
    b"M4V ",  # iTunes movie
    b"M4A ",  # iTunes audio (理论上不该单独发,但容器合法)
    b"qt  ",  # QuickTime
}


def _has_valid_ftyp_box(content: bytes) -> bool:
    """检测合法的 ISO/MP4 / QuickTime ftyp box。

    校验项:
    1. 至少 12 字节(size + 'ftyp' + brand)
    2. 4-byte big-endian box size >= 16(避免 \\xff\\xff\\xff\\xff 滥用)
    3. offset 4-8 是 'ftyp'
    4. offset 8-12 brand 在白名单中

    ftyp box 格式参考: ISO/IEC 14496-12 §4.3
    """
    if len(content) < 12:
        return False
    # box size sanity:必须 >= 16 字节(4 size + 4 ftyp + 4 brand + 至少 4 字节 compatible brands)
    box_size = struct.unpack(">I", content[0:4])[0]
    if box_size < 16:
        return False
    # ftyp literal
    if content[4:8] != b"ftyp":
        return False
    # brand whitelist
    brand = content[8:12]
    return brand in _ALLOWED_MP4_BRANDS


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

    if not _has_valid_ftyp_box(content):
        raise HTTPException(
            status_code=400,
            detail="视频内容校验失败:文件头不是合法的 MP4/MOV ftyp box "
                   "(需要 size>=16 + 'ftyp' + 已知 brand)",
        )

    if len(content) > MAX_CHAT_VIDEO_SIZE:
        size_mb = MAX_CHAT_VIDEO_SIZE // (1024 * 1024)
        raise HTTPException(
            status_code=400,
            detail=f"视频文件过大,最大允许 {size_mb}MB",
        )

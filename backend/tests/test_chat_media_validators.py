"""单元测试: chat_media_validators.

验证视频与 PDF 的白名单校验函数(magic byte + size + 扩展名)。
"""
import pytest
from fastapi import HTTPException

from app.services.chat_media_validators import (
    validate_chat_video,
    validate_chat_pdf,
    MAX_CHAT_VIDEO_SIZE,
    MAX_CHAT_PDF_SIZE,
)


# ---------------------- PDF ----------------------

def test_pdf_valid_minimal():
    # PDF 最小 magic byte
    content = b"%PDF-1.4\n%minimal"
    # 不抛异常即通过
    validate_chat_pdf(content, "doc.pdf")


def test_pdf_rejects_wrong_magic_byte():
    content = b"NOT-A-PDF" + b"\x00" * 100
    with pytest.raises(HTTPException) as exc:
        validate_chat_pdf(content, "doc.pdf")
    assert exc.value.status_code == 400
    assert "PDF" in exc.value.detail


def test_pdf_rejects_wrong_extension():
    content = b"%PDF-1.4\n..."
    with pytest.raises(HTTPException) as exc:
        validate_chat_pdf(content, "doc.exe")
    assert exc.value.status_code == 400


def test_pdf_rejects_oversize():
    content = b"%PDF-1.4\n" + b"x" * (MAX_CHAT_PDF_SIZE + 1)
    with pytest.raises(HTTPException) as exc:
        validate_chat_pdf(content, "doc.pdf")
    assert exc.value.status_code == 400
    assert "20" in exc.value.detail  # 提到 20MB


def test_pdf_accepts_at_exact_limit():
    content = b"%PDF-1.4\n" + b"x" * (MAX_CHAT_PDF_SIZE - 10)
    validate_chat_pdf(content, "doc.pdf")  # 不抛


# ---------------------- Video ----------------------

def _mp4_header() -> bytes:
    # 标准 ISO/MP4 ftyp box 头: 4 bytes size + "ftyp" + brand
    return b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41"


def _mov_header() -> bytes:
    # QuickTime mov: ftyp 也是 "qt  "
    return b"\x00\x00\x00\x14ftypqt  \x00\x00\x02\x00"


def test_video_mp4_valid():
    content = _mp4_header() + b"\x00" * 200
    validate_chat_video(content, "video.mp4")


def test_video_mov_valid():
    content = _mov_header() + b"\x00" * 200
    validate_chat_video(content, "video.mov")


def test_video_rejects_wrong_magic_byte():
    content = b"NOT-A-VIDEO" + b"\x00" * 200
    with pytest.raises(HTTPException) as exc:
        validate_chat_video(content, "video.mp4")
    assert exc.value.status_code == 400


def test_video_rejects_wrong_extension():
    content = _mp4_header() + b"\x00" * 200
    with pytest.raises(HTTPException) as exc:
        validate_chat_video(content, "video.avi")
    assert exc.value.status_code == 400


def test_video_rejects_oversize():
    content = _mp4_header() + b"\x00" * (MAX_CHAT_VIDEO_SIZE + 1)
    with pytest.raises(HTTPException) as exc:
        validate_chat_video(content, "video.mp4")
    assert exc.value.status_code == 400
    assert "30" in exc.value.detail


def test_video_accepts_at_exact_limit():
    content = _mp4_header() + b"\x00" * (MAX_CHAT_VIDEO_SIZE - 200)
    validate_chat_video(content, "video.mp4")

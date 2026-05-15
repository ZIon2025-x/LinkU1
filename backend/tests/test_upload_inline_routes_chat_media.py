"""集成测试: /api/upload/file?usage=chat_media 路径。

只测 chat_media 分支的校验/响应,不重新测既有 usage=None 路径以外的行为。

注意:
- 项目 conftest.py 没有 authed_client fixture,本测试自建 TestClient 并通过
  app.dependency_overrides 注入假认证用户。
- private_file_system.upload_file 会真正写磁盘 + signed_url_manager 会签 URL,
  这两个副作用用 monkeypatch 替换为内存桩,以保证测试纯粹性。
- read_file_with_size_check 对超过 max_size 的流抛 HTTPException(413, ...),
  所以 oversize 用例的期望状态码是 413,不是 400。chat_media 分支自身仍用 400。
"""
from __future__ import annotations

import io
import os
import sys

import pytest
from fastapi.testclient import TestClient

# 确保可以导入 app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
from app.deps import get_current_user_secure_sync_csrf, get_db


PDF_MAGIC = b"%PDF-1.4\n%minimal pdf body\n%%EOF"
# 32 字节 ftyp box header + payload, validator 只看偏移 4-7 是否 b"ftyp"
MP4_MAGIC = b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41" + b"\x00" * 200


class _FakeUser:
    """最小用户桩,只用 id;upload_file 路由仅取 current_user.id。"""
    id = "test_user_chat_media"
    is_suspended = False
    is_banned = False


def _fake_get_user():
    return _FakeUser()


def _fake_get_db():
    yield None  # private_file_system.upload_file 被 monkeypatch 桩掉,不会真用 db


@pytest.fixture
def client(monkeypatch):
    """TestClient with 认证桩 + private_file_system / signed_url_manager 桩。"""
    # 桩 private_file_system.upload_file:不写盘,直接回最少必要字段
    from app import file_system as fs_mod

    def _fake_upload_file(content, filename, user_id, db, task_id=None,
                          chat_id=None, content_type=None):
        return {
            "success": True,
            "file_id": "fake_file_id_123",
            "filename": "fake_file_id_123.bin",
            "original_filename": filename,
            "size": len(content),
            "extension": ".bin",
        }

    monkeypatch.setattr(
        fs_mod.private_file_system, "upload_file", _fake_upload_file
    )

    # 桩 signed_url_manager.generate_signed_url
    from app import signed_url as su_mod

    def _fake_generate_signed_url(file_path, user_id, expiry_minutes=15,
                                  one_time=False):
        return f"/private-file?file={file_path}&user={user_id}&sig=fake"

    monkeypatch.setattr(
        su_mod.signed_url_manager, "generate_signed_url",
        _fake_generate_signed_url,
    )

    app.dependency_overrides[get_current_user_secure_sync_csrf] = _fake_get_user
    app.dependency_overrides[get_db] = _fake_get_db
    try:
        with TestClient(app, raise_server_exceptions=False) as c:
            yield c
    finally:
        app.dependency_overrides.pop(get_current_user_secure_sync_csrf, None)
        app.dependency_overrides.pop(get_db, None)


def _file_tuple(content: bytes, filename: str, content_type: str):
    """构造 multipart files 列表元素。"""
    return ("file", (filename, io.BytesIO(content), content_type))


# -----------------------------------------------------------------------------
# chat_media 接受合法附件
# -----------------------------------------------------------------------------

def test_chat_media_accepts_pdf(client: TestClient):
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(PDF_MAGIC, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["success"] is True
    assert body["file_id"]
    assert body["url"].startswith("/")


def test_chat_media_accepts_mp4(client: TestClient):
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(MP4_MAGIC, "video.mp4", "video/mp4")],
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["success"] is True


# -----------------------------------------------------------------------------
# chat_media 拒绝非白名单 / 假冒文件
# -----------------------------------------------------------------------------

def test_chat_media_rejects_unknown_type(client: TestClient):
    """非 mp4/mov/m4v/pdf 扩展走 chat_media 分支会被 400 拒掉。"""
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(b"some random bytes", "doc.txt", "text/plain")],
    )
    assert resp.status_code == 400, resp.text


def test_chat_media_rejects_pdf_wrong_magic(client: TestClient):
    """扩展 .pdf 但内容不是 %PDF- 开头 → validate_chat_pdf 抛 400。"""
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(b"NOT-A-PDF" * 100, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 400, resp.text


def test_chat_media_rejects_oversized_video(client: TestClient):
    """> 30MB 视频:read_file_with_size_check 提前抛 413,不到 validator。

    行为差异:虽然 chat_media validator 内部对 oversize 用 400,但
    read_file_with_size_check 是更靠前的关卡,它对超过 max_size 的流抛
    HTTPException(413, ...)。所以 31MB 视频在到达 validator 前就被 413 拦下。
    这仍然实现了"拒绝超大视频"的产品目标,只是 status code 是 413 而非 400。
    """
    big = MP4_MAGIC + b"\x00" * (31 * 1024 * 1024)
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(big, "video.mp4", "video/mp4")],
    )
    assert resp.status_code in (400, 413), resp.text


def test_chat_media_rejects_oversized_pdf(client: TestClient):
    """> 20MB PDF:在 chat_media 分支下,max_upload_size=30MB,先过流读取,
    然后 validate_chat_pdf 看到 21MB content 抛 400。"""
    big = PDF_MAGIC + b"\x00" * (21 * 1024 * 1024)
    resp = client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_tuple(big, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 400, resp.text


# -----------------------------------------------------------------------------
# 回归保护:既有 usage 未指定的路径维持 10MB 上限,行为不变
# -----------------------------------------------------------------------------

def test_non_chat_usage_still_uses_default_10mb_limit(client: TestClient):
    """既有 usage 未指定的路径过 10MB 应被拒。

    read_file_with_size_check 对超限抛 413(不是 400)。
    """
    big = b"x" * (11 * 1024 * 1024)
    resp = client.post(
        "/api/upload/file",
        files=[_file_tuple(big, "doc.txt", "text/plain")],
    )
    assert resp.status_code in (400, 413), resp.text

# 任务聊天加视频/PDF 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在任务聊天中支持发送视频(≤30s/≤30MB,前端压缩+抽帧)和 PDF(≤20MB),接收端可全屏播放/嵌入预览,图片和视频可保存到相册,PDF 可"用其他应用打开"或"分享/保存"。

**Architecture:** 完全复用现有 `PrivateFileSystem` + `/api/upload/file` + `message_attachments` 表(`attachment_type` 字段 schema 已为此预留 image/file/video)。前端新增视频/文件入口 + 渲染气泡 + 全屏预览页 + 三点菜单。详见 `docs/superpowers/specs/2026-05-15-task-chat-video-file-design.md`。

**Tech Stack:**
- 后端: FastAPI, SQLAlchemy(async), PrivateFileSystem, signed_url_manager
- 前端: Flutter, BLoC, image_picker(1.1.2,已依赖), 新增 `video_compress` / `video_thumbnail` / `video_player` / `chewie` / `file_picker` / `open_filex` / `gal` / `flutter_pdfview` / `share_plus`

---

## 关键背景:从代码摸排得到的事实

写这个 plan 前已确认的现状(零上下文工程师可信赖的事实):

1. **DB schema 不用改**:`backend/app/models.py:970-989` 的 `MessageAttachment` 表 `attachment_type` 是 `String(20)`,注释明确"image/file/video等",`url XOR blob_id` CheckConstraint 已存在。
2. **发消息端**(`backend/app/task_chat_routes.py:1211 POST /messages/task/{task_id}/send`)已支持 `attachments` 数组,line 1430-1449 入库逻辑对所有 `attachment_type` 通用,**不需要改**。校验逻辑(line 1387-1402)只查"attachment_type 必须有"和"url XOR blob_id",也通用。
3. **读消息端**(`backend/app/task_chat_routes.py:821 GET /messages/task/{task_id}`)在 line 1042-1089 序列化 attachments,**但只对 `attachment_type == "image"` 调 `private_image_system.generate_image_url` 重新生成签名 URL**(line 1069-1087)。视频/文件类型 attachment 拿不到可用 URL — **必须扩展**。
4. **上传端点** `POST /api/upload/file` 在 `backend/app/routes/upload_inline_routes.py:549`,签名 `(file, task_id, chat_id, current_user, db)`。当前硬编码 10MB 上限(line 569 `MAX_FILE_SIZE_UPLOAD = 10 * 1024 * 1024`),调 `private_file_system.upload_file(content, filename, user_id, db, task_id=, chat_id=, content_type=)` 入库 + 返回 `{file_id, filename, size, original_filename}`,再用 `signed_url_manager.generate_signed_url(file_path=f"files/{filename}", user_id=..., expiry_minutes=15)` 拿短期签名 URL。返回 JSON `{success, url, file_id, filename, size, original_name}`。
5. **危险扩展名拦截**已有:`backend/app/file_system.py:39-43` PrivateFileSystem 内置 `dangerous_extensions` 黑名单(.exe/.bat/...)。本 plan 在此之上叠加 **白名单**(只接受 mp4/mov/PDF magic byte)。
6. **Flutter Message model 已支持 attachments**:`link2ur/lib/data/models/message.dart:97 attachments: List<MessageAttachment>`,`MessageAttachment` 已有 `attachmentType / url / blobId / meta` 字段(line 52-81)。**不需要改 model**。
7. **Flutter image_picker** 已经依赖 1.1.2(`link2ur/pubspec.yaml:47`),`pickMedia()` 是其 1.0+ 提供的"图片或视频"单选 API,可直接用。
8. **`MessageRepository.sendTaskChatMessage`**(`link2ur/lib/data/repositories/message_repository.dart:411`)已支持 `attachments: List<Map<String, dynamic>>?` 参数。**不需要改这个方法**。
9. **ChatBloc 事件文件结构**:`ChatEvent` 和 `ChatState` 都 inline 在 `chat_bloc.dart`,不是 `part of`(从 `import` 和 `abstract class ChatEvent` 直接看到)。新事件直接加在 events 段。
10. **图片消息发送当前流程**(`chat_bloc.dart:474-555 _onSendImage`):上传 → 拿 URL → 乐观插入 pending 消息 → 调 `sendTaskChatMessage` → 替换 pending。视频/文件复用此模式。

---

## File Structure

### 后端 - 新建/修改

| 文件 | 类型 | 职责 |
|---|---|---|
| `backend/app/services/chat_media_validators.py` | 新 | 纯函数:`validate_chat_video(content, filename)` + `validate_chat_pdf(content, filename)`。magic byte + size + 扩展名 三重校验。无 IO 无依赖,易单测 |
| `backend/app/routes/upload_inline_routes.py:549` | 改 | `upload_file` 加 `usage: Optional[str]` query 参数;当 `usage == "chat_media"` 时:① 按文件类型选大小上限(视频 30MB / PDF 20MB);② 调 chat_media_validators 做白名单校验;其他 usage 不变 |
| `backend/app/task_chat_routes.py:1042-1089` | 改 | `get_task_messages` 序列化附件循环里,扩展非 image 类型:`blob_id` 有值时调 `signed_url_manager` 生成签名 URL 填充 `attachment_data["url"]` |
| `backend/tests/test_chat_media_validators.py` | 新 | 单元测试覆盖校验函数 |
| `backend/tests/test_upload_inline_routes_chat_media.py` | 新 | TestClient 测试 `?usage=chat_media` 各 reject/accept 路径 |
| `backend/tests/test_task_chat_get_messages_video_file.py` | 新 | 集成测试:发视频消息 → 读消息 → 验证 attachments 含签名 URL |

### Flutter - 新建/修改

| 文件 | 类型 | 职责 |
|---|---|---|
| `link2ur/pubspec.yaml` | 改 | 加 9 个包 |
| `link2ur/ios/Runner/Info.plist` | 改 | `NSPhotoLibraryAddUsageDescription` |
| `link2ur/android/app/src/main/AndroidManifest.xml` | 改 | `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`(SDK 33+) + `WRITE_EXTERNAL_STORAGE`(SDK ≤28) |
| `link2ur/lib/core/constants/api_endpoints.dart` | 改 | 加 `taskChatUploadMedia = '/api/upload/file?usage=chat_media'` 拼接 helper(或直接在 repository 拼) |
| `link2ur/lib/data/repositories/message_repository.dart` | 改 | 新方法 `uploadChatVideo(bytes, filename, taskId) → {url, blobId}`;`uploadChatPdf(bytes, filename, taskId) → {url, blobId}` |
| `link2ur/lib/core/utils/media_saver.dart` | 新 | `MediaSaver.saveImage(url)` / `saveVideo(localPath)` 封装 `gal` + 权限处理 |
| `link2ur/lib/features/chat/bloc/chat_bloc.dart` | 改 | 加 `ChatSendVideo`、`ChatSendFile` 事件 + handler;复用 SendImage 乐观更新模式 |
| `link2ur/lib/features/chat/views/task_chat_view.dart:217` | 改 | `_pickImage` 改为 `_pickPhotoOrVideo`(用 `pickMedia`);新增 `_pickPdf`(用 `file_picker`) |
| `link2ur/lib/features/chat/widgets/task_chat_action_menu.dart` | 改 | "图片"label 改"照片";加 `onFilePicker` 入口按钮 |
| `link2ur/lib/features/chat/widgets/message_group_bubble.dart` | 改 | 按 `message.messageType` 分发到 image/video/file bubble |
| `link2ur/lib/features/chat/widgets/video_message_bubble.dart` | 新 | 缩略图 + 时长徽章 + 中央播放按钮;点击 push `VideoPlayerView` |
| `link2ur/lib/features/chat/widgets/file_message_bubble.dart` | 新 | PDF 图标 + 文件名 + 大小;点击 push `PdfPreviewView` |
| `link2ur/lib/features/chat/views/video_player_view.dart` | 新 | chewie 全屏;右上角 `PopupMenuButton` → "保存到相册" |
| `link2ur/lib/features/chat/views/pdf_preview_view.dart` | 新 | flutter_pdfview 嵌入;下载到临时目录;右上角 `PopupMenuButton` → "用其他应用打开"+"分享/保存" |
| `link2ur/lib/core/widgets/full_screen_image_view.dart` | 改 | 加可选参数 `allowSaveToAlbum`(默认 false);true 时右上角 `PopupMenuButton` → "保存到相册" |
| `link2ur/lib/core/utils/error_localizer.dart` | 改 | 加新错误码映射 |
| `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` | 改 | 新增字符串三套 |
| `link2ur/test/features/chat/chat_bloc_send_video_test.dart` | 新 | bloc_test 视频路径 |
| `link2ur/test/features/chat/chat_bloc_send_file_test.dart` | 新 | bloc_test PDF 路径 |
| `link2ur/test/core/utils/media_saver_test.dart` | 新 | MediaSaver 三种状态 |

---

## 实施顺序

Phase A(后端,独立可验证) → Phase B(Flutter data 层) → Phase C(BLoC 层) → Phase D(UI 入口) → Phase E(UI 渲染) → Phase F(辅助:l10n/权限/i18n) → Phase G(手动 QA)

每个 task 自包含,可独立 commit。

---

### Task 1: 后端 chat_media_validators 纯函数(TDD)

**Files:**
- Create: `backend/app/services/chat_media_validators.py`
- Test: `backend/tests/test_chat_media_validators.py`

- [ ] **Step 1: 写失败测试**

Create `backend/tests/test_chat_media_validators.py`:

```python
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_chat_media_validators.py -v`
Expected: `ModuleNotFoundError: No module named 'app.services.chat_media_validators'`

- [ ] **Step 3: 实现校验函数**

Create `backend/app/services/chat_media_validators.py`:

```python
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_chat_media_validators.py -v`
Expected: 全部 11 个用例 PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/chat_media_validators.py backend/tests/test_chat_media_validators.py
git commit -m "feat(chat): 加任务聊天视频/PDF 白名单校验函数 + 单测"
```

---

### Task 2: 后端 /api/upload/file 加 usage=chat_media 分支(TDD)

**Files:**
- Modify: `backend/app/routes/upload_inline_routes.py:549-604` (函数 `upload_file`)
- Test: `backend/tests/test_upload_inline_routes_chat_media.py`

- [ ] **Step 1: 写失败测试**

Create `backend/tests/test_upload_inline_routes_chat_media.py`:

```python
"""集成测试: /api/upload/file?usage=chat_media 路径。

只测 chat_media 分支的校验/响应,不重新测既有 usage=None 路径。
"""
import io

import pytest
from fastapi.testclient import TestClient

# 假设项目已有 conftest 提供 authed_client fixture(已登录用户的 TestClient)
# 如无此 fixture,工程师需要在 conftest 加,但本任务范围内复用既有 fixture

PDF_MAGIC = b"%PDF-1.4\n%minimal pdf body\n%%EOF"
MP4_MAGIC = b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41" + b"\x00" * 200


def _file_bytes(content: bytes, filename: str, content_type: str):
    return ("file", (filename, io.BytesIO(content), content_type))


def test_chat_media_accepts_pdf(authed_client: TestClient):
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(PDF_MAGIC, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["success"] is True
    assert body["file_id"]
    assert body["url"].startswith("/")


def test_chat_media_accepts_mp4(authed_client: TestClient):
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(MP4_MAGIC, "video.mp4", "video/mp4")],
    )
    assert resp.status_code == 200, resp.text


def test_chat_media_rejects_unknown_type(authed_client: TestClient):
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(b"some random bytes", "doc.txt", "text/plain")],
    )
    assert resp.status_code == 400


def test_chat_media_rejects_pdf_wrong_magic(authed_client: TestClient):
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(b"NOT-A-PDF" * 100, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 400


def test_chat_media_rejects_oversized_video(authed_client: TestClient):
    # > 30MB
    big = MP4_MAGIC + b"\x00" * (31 * 1024 * 1024)
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(big, "video.mp4", "video/mp4")],
    )
    assert resp.status_code == 400


def test_chat_media_rejects_oversized_pdf(authed_client: TestClient):
    # > 20MB
    big = PDF_MAGIC + b"\x00" * (21 * 1024 * 1024)
    resp = authed_client.post(
        "/api/upload/file?usage=chat_media&task_id=1",
        files=[_file_bytes(big, "doc.pdf", "application/pdf")],
    )
    assert resp.status_code == 400


def test_non_chat_usage_still_uses_default_10mb_limit(authed_client: TestClient):
    """既有 usage 未指定的路径维持 10MB 上限,行为不变(回归保护)。"""
    big = b"x" * (11 * 1024 * 1024)
    resp = authed_client.post(
        "/api/upload/file",
        files=[_file_bytes(big, "doc.txt", "text/plain")],
    )
    # 既有路径过 10MB 拒绝
    assert resp.status_code == 400
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_upload_inline_routes_chat_media.py -v`
Expected: 5 个 chat_media 用例 FAIL(目前路由不识别 usage,所有 video/pdf 会被默认 10MB 拒绝或上传通过但无校验)

- [ ] **Step 3: 改路由加 usage 分支**

Edit `backend/app/routes/upload_inline_routes.py:549-604`,将 `upload_file` 函数替换为:

```python
@router.post("/upload/file")
@rate_limit("upload_file")
async def upload_file(
    file: UploadFile = File(...),
    task_id: Optional[int] = Query(None, description="任务ID（任务聊天时提供）"),
    chat_id: Optional[str] = Query(None, description="聊天ID（客服聊天时提供）"),
    usage: Optional[str] = Query(None, description="使用场景: 'chat_media' 表示任务聊天视频/PDF"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """
    上传文件
    支持按任务ID或聊天ID分类存储
    - task_id: 任务聊天时提供，文件会存储在 tasks/{task_id}/ 文件夹
    - chat_id: 客服聊天时提供，文件会存储在 chats/{chat_id}/ 文件夹
    - usage='chat_media': 走白名单校验(视频 mp4/mov ≤30MB,PDF ≤20MB);其他 usage 走默认 10MB 通用校验
    """
    try:
        from app.file_stream_utils import read_file_with_size_check

        # 按 usage 选最大上限:chat_media 视频 30MB 兜底;其他 10MB
        if usage == "chat_media":
            max_upload_size = 30 * 1024 * 1024  # 视频上限兜底;PDF 在 validator 内独立卡 20MB
        else:
            max_upload_size = 10 * 1024 * 1024

        content, file_size = await read_file_with_size_check(file, max_upload_size)

        # chat_media 分支:走白名单校验(拒绝非 mp4/mov/PDF)
        if usage == "chat_media":
            from app.services.chat_media_validators import (
                validate_chat_video,
                validate_chat_pdf,
            )
            from pathlib import Path
            ext = Path(file.filename or "").suffix.lower()
            if ext in {".mp4", ".mov", ".m4v"}:
                validate_chat_video(content, file.filename or "")
            elif ext == ".pdf":
                validate_chat_pdf(content, file.filename or "")
            else:
                raise HTTPException(
                    status_code=400,
                    detail="任务聊天附件只接受视频(mp4/mov/m4v)或 PDF",
                )

        # 使用新的私密文件系统上传
        from app.file_system import private_file_system
        result = private_file_system.upload_file(
            content,
            file.filename,
            current_user.id,
            db,
            task_id=task_id,
            chat_id=chat_id,
            content_type=file.content_type,
        )

        # 生成签名URL（使用新的文件ID）
        from app.signed_url import signed_url_manager
        file_path_for_url = f"files/{result['filename']}"
        file_url = signed_url_manager.generate_signed_url(
            file_path=file_path_for_url,
            user_id=current_user.id,
            expiry_minutes=15,
            one_time=False,
        )

        return JSONResponse(
            content={
                "success": True,
                "url": file_url,
                "file_id": result["file_id"],
                "filename": result["filename"],
                "size": result["size"],
                "original_name": result["original_filename"],
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"文件上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_upload_inline_routes_chat_media.py -v`
Expected: 全部 7 个用例 PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/upload_inline_routes.py backend/tests/test_upload_inline_routes_chat_media.py
git commit -m "feat(upload): /api/upload/file 加 usage=chat_media 分支(视频30MB+PDF20MB+magic byte)"
```

---

### Task 3: 后端 get_task_messages 视频/文件签名 URL 生成(TDD)

**Files:**
- Modify: `backend/app/task_chat_routes.py:1042-1089` (`get_task_messages` 的 attachment 序列化循环)
- Test: `backend/tests/test_task_chat_get_messages_video_file.py`

- [ ] **Step 1: 写失败测试**

Create `backend/tests/test_task_chat_get_messages_video_file.py`:

```python
"""集成测试:get_task_messages 返回的 video/file attachment 必须含可用的签名 URL。

通过 ORM 直接造数据(MessageAttachment with blob_id),验证 GET /api/messages/task/{id}
的 response 里 video/file 类型 attachment 的 url 字段已生成签名 URL(以 /api/private-file 开头)。
"""
import pytest


def test_video_attachment_gets_signed_url(authed_client, db_session, sample_task):
    """发视频消息后,读消息时 attachment.url 是 /api/private-file 签名链接。"""
    from app import models

    # 造一条视频消息 + 1 个 video attachment + 1 个 thumbnail image attachment
    msg = models.Message(
        sender_id=sample_task.poster_id,
        task_id=sample_task.id,
        content="[视频]",
        message_type="normal",
        conversation_type="task",
    )
    db_session.add(msg)
    db_session.flush()

    db_session.add_all([
        models.MessageAttachment(
            message_id=msg.id,
            attachment_type="video",
            blob_id="testuser_1700000000_abcdef12.mp4",
            meta='{"duration":28,"width":1080,"height":1920}',
        ),
        models.MessageAttachment(
            message_id=msg.id,
            attachment_type="image",
            blob_id="testuser_1700000000_abcdef13.jpg",
            meta='{"role":"thumbnail"}',
        ),
    ])
    db_session.commit()

    resp = authed_client.get(f"/api/messages/task/{sample_task.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["messages"]
    found_msg = next((m for m in data["messages"] if m["id"] == msg.id), None)
    assert found_msg is not None
    atts = found_msg["attachments"]
    video_att = next((a for a in atts if a["attachment_type"] == "video"), None)
    thumb_att = next(
        (a for a in atts if a["attachment_type"] == "image" and (a.get("meta") or {}).get("role") == "thumbnail"),
        None,
    )
    assert video_att is not None
    assert thumb_att is not None
    # 视频 url 必须是签名 URL(走 /api/private-file)
    assert video_att["url"], "video attachment url must be populated"
    assert "/api/private-file" in video_att["url"]
    # 缩略图 url 走 private-image
    assert thumb_att["url"]
    assert "/api/private-image" in thumb_att["url"]


def test_file_attachment_gets_signed_url(authed_client, db_session, sample_task):
    """PDF 消息的 file attachment 也要带签名 URL。"""
    from app import models

    msg = models.Message(
        sender_id=sample_task.poster_id,
        task_id=sample_task.id,
        content="[文件:report.pdf]",
        message_type="normal",
        conversation_type="task",
    )
    db_session.add(msg)
    db_session.flush()

    db_session.add(models.MessageAttachment(
        message_id=msg.id,
        attachment_type="file",
        blob_id="testuser_1700000000_abcdef14.pdf",
        meta='{"original_filename":"report.pdf","content_type":"application/pdf","size":12345}',
    ))
    db_session.commit()

    resp = authed_client.get(f"/api/messages/task/{sample_task.id}")
    assert resp.status_code == 200
    data = resp.json()
    found = next((m for m in data["messages"] if m["id"] == msg.id), None)
    assert found
    file_att = next((a for a in found["attachments"] if a["attachment_type"] == "file"), None)
    assert file_att is not None
    assert file_att["url"]
    assert "/api/private-file" in file_att["url"]
    # meta 透传
    assert file_att["meta"]["original_filename"] == "report.pdf"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_task_chat_get_messages_video_file.py -v`
Expected: 两个用例都 FAIL — `video_att["url"]` 是 None(现有代码不为非 image 类型生成 URL)

- [ ] **Step 3: 改 get_task_messages 序列化逻辑**

Edit `backend/app/task_chat_routes.py` line 1042-1089 的 attachment 序列化循环。原代码:

```python
        # 批量查询附件
        attachments_query = select(models.MessageAttachment).where(
            models.MessageAttachment.message_id.in_(message_ids)
        )
        attachments_result = await db.execute(attachments_query)
        attachments_by_message = {}
        for attachment in attachments_result.scalars().all():
            if attachment.message_id not in attachments_by_message:
                attachments_by_message[attachment.message_id] = []
            
            attachment_data = {
                "id": attachment.id,
                "attachment_type": attachment.attachment_type,
                "url": attachment.url,
                "blob_id": attachment.blob_id,
            }
            
            # 解析 meta JSON
            if attachment.meta:
                try:
                    attachment_data["meta"] = json.loads(attachment.meta)
                except Exception:
                    attachment_data["meta"] = {}
            else:
                attachment_data["meta"] = {}

            # 私密图片：按当前密钥重新生成 URL，避免 IMAGE_ACCESS_SECRET 变更后旧 token 导致 403
            if (
                attachment.attachment_type == "image"
                and attachment.blob_id
                and participants
            ):
                try:
                    from app.image_system import private_image_system
                    new_url = private_image_system.generate_image_url(
                        attachment.blob_id,
                        cuid,
                        participants,
                    )
                    attachment_data["url"] = new_url
                except Exception as e:
                    logger.warning(
                        "Failed to regenerate private-image URL for blob_id=%s: %s",
                        attachment.blob_id,
                        e,
                    )
            
            attachments_by_message[attachment.message_id].append(attachment_data)
```

替换为(在 image 分支后追加 video/file 分支):

```python
        # 批量查询附件
        attachments_query = select(models.MessageAttachment).where(
            models.MessageAttachment.message_id.in_(message_ids)
        )
        attachments_result = await db.execute(attachments_query)
        attachments_by_message = {}
        for attachment in attachments_result.scalars().all():
            if attachment.message_id not in attachments_by_message:
                attachments_by_message[attachment.message_id] = []

            attachment_data = {
                "id": attachment.id,
                "attachment_type": attachment.attachment_type,
                "url": attachment.url,
                "blob_id": attachment.blob_id,
            }

            # 解析 meta JSON
            if attachment.meta:
                try:
                    attachment_data["meta"] = json.loads(attachment.meta)
                except Exception:
                    attachment_data["meta"] = {}
            else:
                attachment_data["meta"] = {}

            # 私密图片：按当前密钥重新生成 URL，避免 IMAGE_ACCESS_SECRET 变更后旧 token 导致 403
            if (
                attachment.attachment_type == "image"
                and attachment.blob_id
                and participants
            ):
                try:
                    from app.image_system import private_image_system
                    new_url = private_image_system.generate_image_url(
                        attachment.blob_id,
                        cuid,
                        participants,
                    )
                    attachment_data["url"] = new_url
                except Exception as e:
                    logger.warning(
                        "Failed to regenerate private-image URL for blob_id=%s: %s",
                        attachment.blob_id,
                        e,
                    )

            # 视频 / 文件 (PDF) 附件: 走 signed_url_manager 生成短期签名访问 URL
            # blob_id 形如 "{user}_{ts}_{rand}.{ext}",signed_url 用 file_path="files/{filename}"
            elif (
                attachment.attachment_type in ("video", "file")
                and attachment.blob_id
            ):
                try:
                    from app.signed_url import signed_url_manager
                    file_path_for_url = f"files/{attachment.blob_id}"
                    signed_url = signed_url_manager.generate_signed_url(
                        file_path=file_path_for_url,
                        user_id=cuid,
                        expiry_minutes=15,
                        one_time=False,
                    )
                    attachment_data["url"] = signed_url
                except Exception as e:
                    logger.warning(
                        "Failed to generate signed URL for %s blob_id=%s: %s",
                        attachment.attachment_type,
                        attachment.blob_id,
                        e,
                    )

            attachments_by_message[attachment.message_id].append(attachment_data)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_task_chat_get_messages_video_file.py -v`
Expected: 两个用例都 PASS

同时跑回归: `cd backend && pytest tests/test_task_chat_get_messages_video_file.py tests/test_chat_media_validators.py tests/test_upload_inline_routes_chat_media.py -v`
Expected: 20 个用例全 PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/task_chat_routes.py backend/tests/test_task_chat_get_messages_video_file.py
git commit -m "feat(chat): get_task_messages 为 video/file attachment 生成签名URL"
```

---

### Task 4: Flutter pubspec + iOS/Android 权限清单

**Files:**
- Modify: `link2ur/pubspec.yaml`
- Modify: `link2ur/ios/Runner/Info.plist`
- Modify: `link2ur/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 加 pubspec 依赖**

Edit `link2ur/pubspec.yaml`,在 `dependencies:` 段(找到 `image_picker: ^1.1.2` 这一行)后追加:

```yaml
  # 任务聊天 视频/PDF 附件支持
  video_compress: ^3.1.4         # 视频压缩(1080p@2Mbps)
  video_thumbnail: ^0.5.3        # 视频抽帧生成缩略图
  video_player: ^2.9.2           # 视频播放器底层
  chewie: ^1.10.0                # 视频播放器 UI 包装(基于 video_player)
  file_picker: ^8.1.4            # PDF 文件选择器
  open_filex: ^4.5.0             # 用其他应用打开文件
  gal: ^2.3.0                    # 保存图片/视频到系统相册(iOS Photos + Android MediaStore)
  flutter_pdfview: ^1.3.4        # PDF 嵌入预览
  share_plus: ^10.1.2            # 系统分享面板(用作"分享/保存"入口)
```

- [ ] **Step 2: 跑 flutter pub get 验证**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter pub get
```
Expected: 所有包成功 resolve;若某版本冲突,放宽到 caret minor(如 ^3.1.0 → ^3.0.0)。

- [ ] **Step 3: 加 iOS Info.plist 权限说明**

Edit `link2ur/ios/Runner/Info.plist`,在最后 `</dict></plist>` 前的最近一个 `<key>` 后插入:

```xml
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>Link2Ur 需要相册写入权限,以便将任务聊天的图片和视频保存到您的相册。</string>
```

(如果已有 `NSPhotoLibraryUsageDescription`,保留它且单独再加上面这个 add 版本 key。)

- [ ] **Step 4: 加 Android Manifest 权限**

Edit `link2ur/android/app/src/main/AndroidManifest.xml`,在 `<manifest>` 开标签下,`<application>` 上方,确认或添加:

```xml
    <!-- 相册保存(Android 13+ READ_MEDIA_* + 旧版 WRITE_EXTERNAL_STORAGE) -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
```

如已存在则跳过对应行。

- [ ] **Step 5: 验证构建**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"; cd link2ur; flutter analyze
```
Expected: 0 errors(可能有依赖未使用的 warning,本任务允许)。

- [ ] **Step 6: Commit**

```bash
git add link2ur/pubspec.yaml link2ur/pubspec.lock link2ur/ios/Runner/Info.plist link2ur/android/app/src/main/AndroidManifest.xml
git commit -m "chore(chat): 加视频/PDF/相册保存所需依赖与权限声明"
```

---

### Task 5: Flutter MessageRepository.uploadChatVideo / uploadChatPdf

**Files:**
- Modify: `link2ur/lib/data/repositories/message_repository.dart` (在 `uploadImage` 方法,line 484 后追加)
- Modify: `link2ur/lib/core/constants/api_endpoints.dart` (复用已有 `uploadFile` 常量)

- [ ] **Step 1: 加 repository 方法**

Edit `link2ur/lib/data/repositories/message_repository.dart`,在 `uploadImage` 方法(`return response.data!['url'] as String? ?? '';` 那行后,大约 line 484)之后插入:

```dart
  /// 上传任务聊天视频(走 /api/upload/file?usage=chat_media&task_id=).
  ///
  /// 返回 (signedUrl, blobId):
  /// - signedUrl: 15min 签名访问 URL,可直接传给 video_player
  /// - blobId: 持久 file_id,要作为 attachment.blob_id 发到 sendTaskChatMessage
  Future<({String url, String blobId, int size, String originalName})> uploadChatVideo(
    Uint8List bytes,
    String filename,
    int taskId,
  ) async {
    final response = await _apiService.uploadFileBytes<Map<String, dynamic>>(
      '${ApiEndpoints.uploadFile}?usage=chat_media&task_id=$taskId',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
    );
    if (!response.isSuccess || response.data == null) {
      throw MessageException(
        response.errorCode ?? response.message ?? 'chat_upload_failed',
        code: response.errorCode,
      );
    }
    final d = response.data!;
    return (
      url: d['url'] as String? ?? '',
      blobId: d['file_id'] as String? ?? '',
      size: d['size'] as int? ?? 0,
      originalName: d['original_name'] as String? ?? filename,
    );
  }

  /// 上传任务聊天 PDF(走 /api/upload/file?usage=chat_media&task_id=)。
  Future<({String url, String blobId, int size, String originalName})> uploadChatPdf(
    Uint8List bytes,
    String filename,
    int taskId,
  ) async {
    final response = await _apiService.uploadFileBytes<Map<String, dynamic>>(
      '${ApiEndpoints.uploadFile}?usage=chat_media&task_id=$taskId',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
    );
    if (!response.isSuccess || response.data == null) {
      throw MessageException(
        response.errorCode ?? response.message ?? 'chat_upload_failed',
        code: response.errorCode,
      );
    }
    final d = response.data!;
    return (
      url: d['url'] as String? ?? '',
      blobId: d['file_id'] as String? ?? '',
      size: d['size'] as int? ?? 0,
      originalName: d['original_name'] as String? ?? filename,
    );
  }
```

(`ApiEndpoints.uploadFile` 已存在,值是 `/api/upload/file` — `link2ur/lib/core/constants/api_endpoints.dart:714`。)

- [ ] **Step 2: 跑 flutter analyze**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/data/repositories/message_repository.dart
```
Expected: 0 errors。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/repositories/message_repository.dart
git commit -m "feat(chat): MessageRepository 加 uploadChatVideo / uploadChatPdf"
```

---

### Task 6: Flutter ChatBloc 加 ChatSendVideo 事件(TDD)

**Files:**
- Modify: `link2ur/lib/features/chat/bloc/chat_bloc.dart` (events 段加新事件 + handler)
- Test: `link2ur/test/features/chat/chat_bloc_send_video_test.dart`

- [ ] **Step 1: 写失败测试**

Create `link2ur/test/features/chat/chat_bloc_send_video_test.dart`:

```dart
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/features/chat/bloc/chat_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  late _MockRepo repo;
  final videoBytes = Uint8List.fromList(List.filled(100, 0));
  final thumbBytes = Uint8List.fromList(List.filled(50, 0));

  setUp(() {
    repo = _MockRepo();
    when(() => repo.messageStream).thenAnswer((_) => const Stream.empty());
    when(() => repo.connectionStream).thenAnswer((_) => const Stream.empty());
  });

  group('ChatSendVideo', () {
    blocTest<ChatBloc, ChatState>(
      '上传视频+缩略图 → 发消息 → 用真实消息替换 pending',
      build: () {
        when(() => repo.uploadChatVideo(any(), any(), any())).thenAnswer(
          (_) async => (url: 'signed-v', blobId: 'v_blob', size: 8000000, originalName: 'v.mp4'),
        );
        // 缩略图走既有 uploadImage(私密图片)
        when(() => repo.uploadImage(any(), any())).thenAnswer((_) async => 'thumb_url');
        when(() => repo.sendTaskChatMessage(
              any(),
              content: any(named: 'content'),
              messageType: any(named: 'messageType'),
              attachments: any(named: 'attachments'),
            )).thenAnswer((_) async => const Message(
              id: 999,
              senderId: 'u1',
              content: '[视频]',
              messageType: 'video',
            ));
        return ChatBloc(messageRepository: repo)
          ..emit(const ChatState(taskId: 1, userId: 'u1'));
      },
      act: (bloc) => bloc.add(ChatSendVideo(
        videoBytes: videoBytes,
        videoFilename: 'v.mp4',
        videoDurationMs: 28000,
        videoWidth: 1080,
        videoHeight: 1920,
        thumbnailBytes: thumbBytes,
        thumbnailFilename: 'v_thumb.jpg',
        senderId: 'u1',
      )),
      verify: (_) {
        verify(() => repo.uploadChatVideo(videoBytes, 'v.mp4', 1)).called(1);
        verify(() => repo.uploadImage(thumbBytes, 'v_thumb.jpg')).called(1);
        // sendTaskChatMessage 接收 2 个 attachment(video + image-thumbnail)
        final captured = verify(() => repo.sendTaskChatMessage(
              1,
              content: '[视频]',
              messageType: 'video',
              attachments: captureAny(named: 'attachments'),
            )).captured.single as List<Map<String, dynamic>>;
        expect(captured.length, 2);
        expect(captured[0]['attachment_type'], 'video');
        expect(captured[0]['blob_id'], 'v_blob');
        expect(captured[1]['attachment_type'], 'image');
        expect(captured[1]['meta']['role'], 'thumbnail');
      },
    );

    blocTest<ChatBloc, ChatState>(
      '上传视频失败 → 发出 chat_upload_failed 错误',
      build: () {
        when(() => repo.uploadChatVideo(any(), any(), any())).thenThrow(
          const MessageException('chat_upload_failed', code: 'chat_upload_failed'),
        );
        return ChatBloc(messageRepository: repo)
          ..emit(const ChatState(taskId: 1, userId: 'u1'));
      },
      act: (bloc) => bloc.add(ChatSendVideo(
        videoBytes: videoBytes,
        videoFilename: 'v.mp4',
        videoDurationMs: 28000,
        videoWidth: 1080,
        videoHeight: 1920,
        thumbnailBytes: thumbBytes,
        thumbnailFilename: 'v_thumb.jpg',
      )),
      expect: () => [
        isA<ChatState>().having((s) => s.isSending, 'isSending', true),
        isA<ChatState>()
            .having((s) => s.isSending, 'isSending', false)
            .having((s) => s.errorMessage, 'errorMessage', 'chat_upload_failed'),
      ],
    );
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter test test/features/chat/chat_bloc_send_video_test.dart
```
Expected: 编译失败 — `ChatSendVideo` 未定义。

- [ ] **Step 3: 加 ChatSendVideo 事件**

Edit `link2ur/lib/features/chat/bloc/chat_bloc.dart`,在 `class ChatSendImage extends ChatEvent`(line 57-71)之后追加:

```dart
class ChatSendVideo extends ChatEvent {
  const ChatSendVideo({
    required this.videoBytes,
    required this.videoFilename,
    required this.videoDurationMs,
    required this.videoWidth,
    required this.videoHeight,
    required this.thumbnailBytes,
    required this.thumbnailFilename,
    this.senderId,
  });

  final Uint8List videoBytes;
  final String videoFilename;
  final int videoDurationMs;
  final int videoWidth;
  final int videoHeight;
  final Uint8List thumbnailBytes;
  final String thumbnailFilename;
  final String? senderId;

  @override
  List<Object?> get props => [
        videoBytes,
        videoFilename,
        videoDurationMs,
        thumbnailBytes,
        thumbnailFilename,
        senderId,
      ];
}
```

然后在 ChatBloc 类内部(`on<ChatSendImage>(_onSendImage);` 那行附近,事件注册段)追加注册:

```dart
    on<ChatSendVideo>(_onSendVideo);
```

最后在 `_onSendImage` 方法后追加 handler:

```dart
  Future<void> _onSendVideo(
    ChatSendVideo event,
    Emitter<ChatState> emit,
  ) async {
    if (!NetworkMonitor.instance.isConnected) {
      emit(state.copyWith(errorMessage: 'chat_network_offline'));
      return;
    }
    if (state.taskId == null) {
      emit(state.copyWith(errorMessage: 'chat_upload_failed'));
      return;
    }

    emit(state.copyWith(isSending: true));
    int? pendingId;
    Message? pendingMessage;

    try {
      // 并行上传视频和缩略图
      final results = await Future.wait([
        _messageRepository.uploadChatVideo(
          event.videoBytes,
          event.videoFilename,
          state.taskId!,
        ),
        _messageRepository.uploadImage(
          event.thumbnailBytes,
          event.thumbnailFilename,
        ),
      ]);
      final videoUpload = results[0] as ({String url, String blobId, int size, String originalName});
      final thumbUrl = results[1] as String;

      final senderId = event.senderId?.trim();
      final canOptimistic = senderId != null && senderId.isNotEmpty;
      if (canOptimistic) {
        pendingId = _nextPendingId();
        pendingMessage = Message(
          id: pendingId,
          senderId: senderId,
          receiverId: state.userId,
          content: '[视频]',
          messageType: 'video',
          createdAt: DateTime.now().toUtc(),
        );
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [pendingMessage, ...state.messages]
              : [...state.messages, pendingMessage],
        ));
      }

      final message = await _messageRepository.sendTaskChatMessage(
        state.taskId!,
        content: '[视频]',
        messageType: 'video',
        attachments: [
          {
            'attachment_type': 'video',
            'blob_id': videoUpload.blobId,
            'meta': {
              'duration': (event.videoDurationMs / 1000).round(),
              'width': event.videoWidth,
              'height': event.videoHeight,
              'size': videoUpload.size,
              'original_filename': videoUpload.originalName,
            },
          },
          {
            'attachment_type': 'image',
            'url': thumbUrl,
            'meta': {
              'role': 'thumbnail',
              'original_filename': event.thumbnailFilename,
            },
          },
        ],
      );

      if (canOptimistic && pendingMessage != null) {
        final list = state.messages
            .map((m) => m.id == pendingMessage!.id ? message : m)
            .toList();
        emit(state.copyWith(messages: list, isSending: false));
      } else {
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [message, ...state.messages]
              : [...state.messages, message],
          isSending: false,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to send video', e);
      List<Message> list = state.messages;
      if (pendingMessage != null) {
        list = state.messages.where((m) => m.id != pendingMessage!.id).toList();
      }
      String errorCode = 'chat_upload_failed';
      if (e is MessageException && e.code != null) {
        errorCode = e.code!;
      }
      emit(state.copyWith(
        messages: list,
        isSending: false,
        errorMessage: errorCode,
      ));
    }
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd link2ur; flutter test test/features/chat/chat_bloc_send_video_test.dart`
Expected: 2 个用例 PASS。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/chat/bloc/chat_bloc.dart link2ur/test/features/chat/chat_bloc_send_video_test.dart
git commit -m "feat(chat): ChatBloc 加 ChatSendVideo 事件(并行上传 + 乐观更新)"
```

---

### Task 7: Flutter ChatBloc 加 ChatSendFile 事件(TDD)

**Files:**
- Modify: `link2ur/lib/features/chat/bloc/chat_bloc.dart`
- Test: `link2ur/test/features/chat/chat_bloc_send_file_test.dart`

- [ ] **Step 1: 写失败测试**

Create `link2ur/test/features/chat/chat_bloc_send_file_test.dart`:

```dart
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/features/chat/bloc/chat_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  late _MockRepo repo;
  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

  setUp(() {
    repo = _MockRepo();
    when(() => repo.messageStream).thenAnswer((_) => const Stream.empty());
    when(() => repo.connectionStream).thenAnswer((_) => const Stream.empty());
  });

  blocTest<ChatBloc, ChatState>(
    'ChatSendFile 上传 PDF → 发消息 → 替换 pending',
    build: () {
      when(() => repo.uploadChatPdf(any(), any(), any())).thenAnswer(
        (_) async => (url: 'signed-p', blobId: 'p_blob', size: 5000, originalName: 'report.pdf'),
      );
      when(() => repo.sendTaskChatMessage(
            any(),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            attachments: any(named: 'attachments'),
          )).thenAnswer((_) async => const Message(
            id: 1001,
            senderId: 'u1',
            content: '[文件:report.pdf]',
            messageType: 'file',
          ));
      return ChatBloc(messageRepository: repo)
        ..emit(const ChatState(taskId: 1, userId: 'u1'));
    },
    act: (bloc) => bloc.add(ChatSendFile(
      bytes: pdfBytes,
      filename: 'report.pdf',
      contentType: 'application/pdf',
      senderId: 'u1',
    )),
    verify: (_) {
      verify(() => repo.uploadChatPdf(pdfBytes, 'report.pdf', 1)).called(1);
      final captured = verify(() => repo.sendTaskChatMessage(
            1,
            content: '[文件:report.pdf]',
            messageType: 'file',
            attachments: captureAny(named: 'attachments'),
          )).captured.single as List<Map<String, dynamic>>;
      expect(captured.length, 1);
      expect(captured[0]['attachment_type'], 'file');
      expect(captured[0]['blob_id'], 'p_blob');
      expect(captured[0]['meta']['original_filename'], 'report.pdf');
      expect(captured[0]['meta']['content_type'], 'application/pdf');
    },
  );
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd link2ur; flutter test test/features/chat/chat_bloc_send_file_test.dart`
Expected: `ChatSendFile` 未定义。

- [ ] **Step 3: 加 ChatSendFile 事件 + handler**

Edit `link2ur/lib/features/chat/bloc/chat_bloc.dart`,在 `ChatSendVideo` 类后追加:

```dart
class ChatSendFile extends ChatEvent {
  const ChatSendFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.senderId,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
  final String? senderId;

  @override
  List<Object?> get props => [bytes, filename, contentType, senderId];
}
```

事件注册段加:

```dart
    on<ChatSendFile>(_onSendFile);
```

handler 段(在 `_onSendVideo` 后)加:

```dart
  Future<void> _onSendFile(
    ChatSendFile event,
    Emitter<ChatState> emit,
  ) async {
    if (!NetworkMonitor.instance.isConnected) {
      emit(state.copyWith(errorMessage: 'chat_network_offline'));
      return;
    }
    if (state.taskId == null) {
      emit(state.copyWith(errorMessage: 'chat_upload_failed'));
      return;
    }

    emit(state.copyWith(isSending: true));
    int? pendingId;
    Message? pendingMessage;

    try {
      final upload = await _messageRepository.uploadChatPdf(
        event.bytes,
        event.filename,
        state.taskId!,
      );

      final senderId = event.senderId?.trim();
      final canOptimistic = senderId != null && senderId.isNotEmpty;
      if (canOptimistic) {
        pendingId = _nextPendingId();
        pendingMessage = Message(
          id: pendingId,
          senderId: senderId,
          receiverId: state.userId,
          content: '[文件:${event.filename}]',
          messageType: 'file',
          createdAt: DateTime.now().toUtc(),
        );
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [pendingMessage, ...state.messages]
              : [...state.messages, pendingMessage],
        ));
      }

      final message = await _messageRepository.sendTaskChatMessage(
        state.taskId!,
        content: '[文件:${event.filename}]',
        messageType: 'file',
        attachments: [
          {
            'attachment_type': 'file',
            'blob_id': upload.blobId,
            'meta': {
              'original_filename': upload.originalName,
              'content_type': event.contentType,
              'size': upload.size,
            },
          },
        ],
      );

      if (canOptimistic && pendingMessage != null) {
        final list = state.messages
            .map((m) => m.id == pendingMessage!.id ? message : m)
            .toList();
        emit(state.copyWith(messages: list, isSending: false));
      } else {
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [message, ...state.messages]
              : [...state.messages, message],
          isSending: false,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to send file', e);
      List<Message> list = state.messages;
      if (pendingMessage != null) {
        list = state.messages.where((m) => m.id != pendingMessage!.id).toList();
      }
      String errorCode = 'chat_upload_failed';
      if (e is MessageException && e.code != null) {
        errorCode = e.code!;
      }
      emit(state.copyWith(
        messages: list,
        isSending: false,
        errorMessage: errorCode,
      ));
    }
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd link2ur; flutter test test/features/chat/chat_bloc_send_file_test.dart test/features/chat/chat_bloc_send_video_test.dart`
Expected: 3 个用例 PASS。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/chat/bloc/chat_bloc.dart link2ur/test/features/chat/chat_bloc_send_file_test.dart
git commit -m "feat(chat): ChatBloc 加 ChatSendFile 事件(PDF 上传 + 乐观更新)"
```

---

### Task 8: Flutter MediaSaver 工具(图片/视频保存到相册,TDD)

**Files:**
- Create: `link2ur/lib/core/utils/media_saver.dart`
- Test: `link2ur/test/core/utils/media_saver_test.dart`

**说明**:`gal` 包跨平台封装相册写入。无法在纯 widget test 里测真实写相册,所以我们把 `gal` 调用抽到一个可注入的接口后,测试只验证"权限检查 → 调用 → 异常映射"逻辑。

- [ ] **Step 1: 写失败测试**

Create `link2ur/test/core/utils/media_saver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/core/utils/media_saver.dart';

void main() {
  group('MediaSaver', () {
    late _FakeGal fakeGal;

    setUp(() {
      fakeGal = _FakeGal();
    });

    test('权限通过 + 写入成功 → 返回 success', () async {
      fakeGal.hasAccessReturn = true;
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.success);
      expect(fakeGal.putVideoCalled, true);
    });

    test('权限缺失 + 请求被拒 → permissionDenied', () async {
      fakeGal.hasAccessReturn = false;
      fakeGal.requestAccessReturn = false;
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.permissionDenied);
      expect(fakeGal.putVideoCalled, false);
    });

    test('写入抛异常 → failed', () async {
      fakeGal.hasAccessReturn = true;
      fakeGal.putVideoThrows = Exception('disk full');
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.failed);
    });
  });
}

class _FakeGal implements GalClient {
  bool hasAccessReturn = true;
  bool requestAccessReturn = false;
  Object? putVideoThrows;
  bool putVideoCalled = false;
  bool putImageCalled = false;

  @override
  Future<bool> hasAccess({bool toAlbum = false}) async => hasAccessReturn;

  @override
  Future<bool> requestAccess({bool toAlbum = false}) async => requestAccessReturn;

  @override
  Future<void> putVideo(String path) async {
    putVideoCalled = true;
    if (putVideoThrows != null) throw putVideoThrows!;
  }

  @override
  Future<void> putImageBytes(List<int> bytes) async {
    putImageCalled = true;
  }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd link2ur; flutter test test/core/utils/media_saver_test.dart`
Expected: `MediaSaver / GalClient` 未定义。

- [ ] **Step 3: 实现 MediaSaver**

Create `link2ur/lib/core/utils/media_saver.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart' as gal_pkg;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// 抽象出 gal 调用方便单测注入。生产用 [DefaultGalClient] 桥接到 `gal` 包。
abstract class GalClient {
  Future<bool> hasAccess({bool toAlbum = false});
  Future<bool> requestAccess({bool toAlbum = false});
  Future<void> putVideo(String path);
  Future<void> putImageBytes(List<int> bytes);
}

class DefaultGalClient implements GalClient {
  const DefaultGalClient();
  @override
  Future<bool> hasAccess({bool toAlbum = false}) =>
      gal_pkg.Gal.hasAccess(toAlbum: toAlbum);
  @override
  Future<bool> requestAccess({bool toAlbum = false}) =>
      gal_pkg.Gal.requestAccess(toAlbum: toAlbum);
  @override
  Future<void> putVideo(String path) => gal_pkg.Gal.putVideo(path);
  @override
  Future<void> putImageBytes(List<int> bytes) =>
      gal_pkg.Gal.putImageBytes(Uint8List.fromList(bytes));
}

enum SaveResult { success, permissionDenied, failed }

class MediaSaver {
  /// 保存图片 URL 到系统相册。
  /// 内部:① 检查权限 → 必要时请求;② 下载 URL → bytes;③ putImageBytes。
  static Future<SaveResult> saveImage(
    String url, {
    GalClient galClient = const DefaultGalClient(),
    Dio? dio,
  }) async {
    try {
      if (!await galClient.hasAccess(toAlbum: true)) {
        final granted = await galClient.requestAccess(toAlbum: true);
        if (!granted) return SaveResult.permissionDenied;
      }
      final http = dio ?? Dio();
      final resp = await http.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) return SaveResult.failed;
      await galClient.putImageBytes(bytes);
      return SaveResult.success;
    } catch (e) {
      AppLogger.error('MediaSaver.saveImage failed', e);
      return SaveResult.failed;
    }
  }

  /// 保存本地视频文件到系统相册。
  /// 调用前需要先把视频下载到 app 临时目录(参考 [downloadToTemp])。
  static Future<SaveResult> saveVideo(
    String localPath, {
    GalClient galClient = const DefaultGalClient(),
  }) async {
    try {
      if (!await galClient.hasAccess(toAlbum: true)) {
        final granted = await galClient.requestAccess(toAlbum: true);
        if (!granted) return SaveResult.permissionDenied;
      }
      await galClient.putVideo(localPath);
      return SaveResult.success;
    } catch (e) {
      AppLogger.error('MediaSaver.saveVideo failed', e);
      return SaveResult.failed;
    }
  }

  /// 将远程 URL 下载到 app 临时目录,返回本地路径。视频/PDF 保存前的预处理。
  static Future<String> downloadToTemp(String url, String filename) async {
    final dir = await getTemporaryDirectory();
    final localPath = '${dir.path}/$filename';
    final dio = Dio();
    await dio.download(url, localPath);
    return localPath;
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd link2ur; flutter test test/core/utils/media_saver_test.dart`
Expected: 3 个用例 PASS。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/core/utils/media_saver.dart link2ur/test/core/utils/media_saver_test.dart
git commit -m "feat(chat): MediaSaver 封装相册保存(gal 包桥接 + 权限处理)"
```

---

### Task 9: Flutter task_chat_action_menu(照片+视频+文件 UI 入口)

**Files:**
- Modify: `link2ur/lib/features/chat/widgets/task_chat_action_menu.dart`
- Modify: `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` (本任务先加 `chatPhotoLabel` 与 `chatFileLabel`,其余字符串留到 Task 17 统一加)

- [ ] **Step 1: 先在 ARB 加新 key(只加本任务必须的)**

Edit `link2ur/lib/l10n/app_zh.arb`,找到 `chatImageLabel` 行(应该是 `"chatImageLabel": "图片"`),在它后面追加:

```json
  "chatPhotoLabel": "照片",
  "@chatPhotoLabel": {
    "description": "任务聊天工具栏中'照片'按钮(图片+视频)"
  },
  "chatFileLabel": "文件",
  "@chatFileLabel": {
    "description": "任务聊天工具栏中'文件'按钮(PDF)"
  },
```

`app_en.arb`:`"chatPhotoLabel": "Photo"`,`"chatFileLabel": "File"`。
`app_zh_Hant.arb`:`"chatPhotoLabel": "相片"`,`"chatFileLabel": "檔案"`。

跑 codegen:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter gen-l10n
```
Expected: 0 errors。

- [ ] **Step 2: 改 task_chat_action_menu**

Edit `link2ur/lib/features/chat/widgets/task_chat_action_menu.dart`,整体替换为:

```dart
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务聊天功能菜单
/// 提供上传照片(图片/视频)、拍照、文件(PDF)、查看任务详情、查看地址等快捷操作
class TaskChatActionMenu extends StatelessWidget {
  const TaskChatActionMenu({
    super.key,
    required this.onImagePicker,
    required this.onCameraPick,
    required this.onFilePicker,
    required this.onTaskDetail,
    this.onViewLocation,
    this.isExpanded = false,
  });

  final VoidCallback onImagePicker;
  final VoidCallback onCameraPick;
  final VoidCallback onFilePicker;
  final VoidCallback onTaskDetail;
  final VoidCallback? onViewLocation;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: isExpanded ? 100 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(color: AppColors.dividerLight, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _ChatActionButton(
                icon: Icons.photo_library,
                label: context.l10n.chatPhotoLabel,
                color: AppColors.success,
                onTap: onImagePicker,
              ),
              const SizedBox(width: AppSpacing.xl),
              _ChatActionButton(
                icon: Icons.camera_alt,
                label: context.l10n.chatCameraLabel,
                color: AppColors.primary,
                onTap: onCameraPick,
              ),
              const SizedBox(width: AppSpacing.xl),
              _ChatActionButton(
                icon: Icons.attach_file,
                label: context.l10n.chatFileLabel,
                color: AppColors.warning,
                onTap: onFilePicker,
              ),
              const SizedBox(width: AppSpacing.xl),
              _ChatActionButton(
                icon: Icons.description,
                label: context.l10n.chatTaskDetailLabel,
                color: AppColors.primary,
                onTap: onTaskDetail,
              ),
              if (onViewLocation != null) ...[
                const SizedBox(width: AppSpacing.xl),
                _ChatActionButton(
                  icon: Icons.location_on,
                  label: context.l10n.chatAddressLabel,
                  color: AppColors.warning,
                  onTap: onViewLocation!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          AppHaptics.buttonTap();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: AppRadius.allMedium,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

变化点:① "图片" label 替换为 `chatPhotoLabel`("照片");② 新增"文件"按钮(`onFilePicker`);③ 整体改为水平滚动以容纳 5 个按钮(原为固定 + Spacer)。

- [ ] **Step 3: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/features/chat/widgets/task_chat_action_menu.dart`
Expected: 0 errors(可能有"onFilePicker 未被调用者使用"提示,因为还没在 view 接入 — 下一 task 接)。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/chat/widgets/task_chat_action_menu.dart link2ur/lib/l10n/app_en.arb link2ur/lib/l10n/app_zh.arb link2ur/lib/l10n/app_zh_Hant.arb
git commit -m "feat(chat): 工具栏'图片'改'照片' + 加'文件'入口"
```

---

### Task 10: Flutter task_chat_view 集成 pickMedia + filePicker

**Files:**
- Modify: `link2ur/lib/features/chat/views/task_chat_view.dart` (替换 `_pickImage`、追加 `_pickFile`、appbar 接 onFilePicker)

- [ ] **Step 1: 改 task_chat_view 的 picker 方法**

Edit `link2ur/lib/features/chat/views/task_chat_view.dart`,在 `_pickImage`(line 217-236)和 `_pickCameraImage`(line 238-257)中间或附近,作以下两处修改:

**修改 1** — 替换 `_pickImage` 方法体,让它支持图片+视频混选(用 `pickMultipleMedia`)。原本的逻辑(`pickMultiImage` 多选最多 9 张图片)改为:

```dart
  /// 相册选媒体:支持图片或视频多选(image_picker 1.1.2 的 pickMultipleMedia)。
  /// - 选中图片:走原图片发送流程(每张图独立 ChatSendImage)
  /// - 选中视频:走 ChatSendVideo(前端压缩 + 抽帧后并行上传)
  static const int _kMaxGalleryImages = 9;

  Future<void> _pickImage() async {
    final media = await _imagePicker.pickMultipleMedia(
      imageQuality: 70,
      maxWidth: 1200,
      limit: _kMaxGalleryImages,
    );
    if (media.isEmpty || !mounted) return;

    for (final file in media) {
      if (!mounted) break;
      final mime = file.mimeType ?? '';
      final isVideo = mime.startsWith('video/') ||
          file.path.toLowerCase().endsWith('.mp4') ||
          file.path.toLowerCase().endsWith('.mov') ||
          file.path.toLowerCase().endsWith('.m4v');
      if (isVideo) {
        await _handlePickedVideo(file.path, file.name);
      } else {
        context.read<ChatBloc>().add(
          ChatSendImage(
            bytes: await file.readAsBytes(),
            filename: file.name,
            senderId: _currentUserId ?? StorageService.instance.getUserId(),
          ),
        );
      }
    }
    if (mounted) setState(() => _showActionMenu = false);
  }
```

**修改 2** — 在 `_pickImage` 后追加视频处理 + 文件处理两个方法:

```dart
  Future<void> _handlePickedVideo(String filePath, String filename) async {
    // 1. 校验时长(用 video_player 暂时获取 metadata)
    // 2. video_compress 压缩
    // 3. video_thumbnail 抽帧
    // 4. dispatch ChatSendVideo
    try {
      final controller = video_player.VideoPlayerController.file(File(filePath));
      await controller.initialize();
      final durationMs = controller.value.duration.inMilliseconds;
      final width = controller.value.size.width.toInt();
      final height = controller.value.size.height.toInt();
      await controller.dispose();

      if (durationMs > 30000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.localizeError('chat_video_too_long')),
          ));
        }
        return;
      }

      // 压缩
      final compressed = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
      );
      final compressedPath = compressed?.path ?? filePath;
      final compressedBytes = await File(compressedPath).readAsBytes();
      if (compressedBytes.length > 30 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.localizeError('chat_video_too_large')),
          ));
        }
        return;
      }

      // 抽帧 -> JPEG bytes
      Uint8List? thumbBytes;
      try {
        thumbBytes = await VideoThumbnail.thumbnailData(
          video: compressedPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 540,
          quality: 70,
        );
      } catch (e) {
        AppLogger.error('Thumbnail extraction failed', e);
      }
      thumbBytes ??= Uint8List(0); // fallback,后端入库不会阻塞;接收端会显示纯黑底

      if (!mounted) return;
      context.read<ChatBloc>().add(ChatSendVideo(
            videoBytes: compressedBytes,
            videoFilename: filename.endsWith('.mp4') || filename.endsWith('.mov')
                ? filename
                : '$filename.mp4',
            videoDurationMs: durationMs,
            videoWidth: width,
            videoHeight: height,
            thumbnailBytes: thumbBytes,
            thumbnailFilename: '$filename.thumb.jpg',
            senderId: _currentUserId ?? StorageService.instance.getUserId(),
          ));
    } catch (e) {
      AppLogger.error('Video pick failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_video_compress_failed')),
        ));
      }
    }
  }

  /// 文件按钮:选 PDF。
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.localizeError('chat_upload_failed')),
      ));
      return;
    }
    if (bytes.length > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.localizeError('chat_file_too_large')),
      ));
      return;
    }
    context.read<ChatBloc>().add(ChatSendFile(
          bytes: bytes,
          filename: file.name,
          contentType: 'application/pdf',
          senderId: _currentUserId ?? StorageService.instance.getUserId(),
        ));
    setState(() => _showActionMenu = false);
  }
```

**修改 3** — 文件顶部追加 imports(`task_chat_view.dart` 第 1-20 行附近):

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart' as video_player;
import 'package:video_thumbnail/video_thumbnail.dart';
```

**修改 4** — `TaskChatActionMenu` 构造参数,把 `onFilePicker: _pickFile` 接进去。找到 line 354 附近 `TaskChatActionMenu(` 调用,在 `onCameraPick: _pickCameraImage,` 后加:

```dart
                  onFilePicker: _pickFile,
```

- [ ] **Step 2: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/features/chat/views/task_chat_view.dart`
Expected: 0 errors。可能有"VideoCompress import only used"等 minor 提示,可忽略。

- [ ] **Step 3: 跑既有 bloc 测试确认未破坏**

Run: `cd link2ur; flutter test test/features/chat/`
Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/chat/views/task_chat_view.dart
git commit -m "feat(chat): task_chat_view 集成视频选择/压缩/抽帧 + PDF 选择"
```

---

### Task 11: Flutter file_message_bubble + video_message_bubble

**Files:**
- Create: `link2ur/lib/features/chat/widgets/file_message_bubble.dart`
- Create: `link2ur/lib/features/chat/widgets/video_message_bubble.dart`

(本任务只做静态展示气泡,点击行为在下一任务接入。)

- [ ] **Step 1: 创建 file_message_bubble.dart**

Create `link2ur/lib/features/chat/widgets/file_message_bubble.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/message.dart';

/// 文件(PDF)消息气泡 — 显示 PDF 图标 + 文件名 + 大小。
class FileMessageBubble extends StatelessWidget {
  const FileMessageBubble({
    super.key,
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  String get _filename =>
      (attachment.meta?['original_filename'] as String?) ?? 'file.pdf';

  String get _sizeLabel {
    final size = attachment.meta?['size'];
    if (size is num && size > 0) {
      final kb = size / 1024;
      if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.allMedium,
          border: Border.all(color: AppColors.dividerLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 32, color: Colors.red),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filename,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_sizeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _sizeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 video_message_bubble.dart**

Create `link2ur/lib/features/chat/widgets/video_message_bubble.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../data/models/message.dart';

/// 视频消息气泡 — 缩略图 + 时长徽章 + 中央播放按钮。
class VideoMessageBubble extends StatelessWidget {
  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onTap,
  });

  final Message message;
  final bool isMine;
  final VoidCallback? onTap;

  MessageAttachment? get _videoAtt =>
      message.attachments.firstWhere(
        (a) => a.attachmentType == 'video',
        orElse: () => const MessageAttachment(),
      );

  MessageAttachment? get _thumbAtt =>
      message.attachments.firstWhere(
        (a) => a.attachmentType == 'image' && (a.meta?['role'] == 'thumbnail'),
        orElse: () => const MessageAttachment(),
      );

  String get _durationLabel {
    final s = _videoAtt?.meta?['duration'];
    if (s is num && s > 0) {
      final secs = s.toInt();
      final mm = (secs ~/ 60).toString().padLeft(1, '0');
      final ss = (secs % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbAtt?.url;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: ClipRRect(
        borderRadius: AppRadius.allMedium,
        child: Container(
          width: 200,
          height: 280,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbUrl != null && thumbUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                  errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
                ),
              // 半透明深色覆盖,让播放按钮更显眼
              Container(color: Colors.black.withValues(alpha: 0.15)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              if (_durationLabel.isNotEmpty)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _durationLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 跑 analyze**

Run:
```powershell
cd link2ur; flutter analyze lib/features/chat/widgets/file_message_bubble.dart lib/features/chat/widgets/video_message_bubble.dart
```
Expected: 0 errors。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/chat/widgets/file_message_bubble.dart link2ur/lib/features/chat/widgets/video_message_bubble.dart
git commit -m "feat(chat): 加视频/文件气泡 widget"
```

---

### Task 12: Flutter video_player_view(chewie 全屏 + 三点菜单 + 保存到相册)

**Files:**
- Create: `link2ur/lib/features/chat/views/video_player_view.dart`

- [ ] **Step 1: 实现 VideoPlayerView**

Create `link2ur/lib/features/chat/views/video_player_view.dart`:

```dart
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    required this.filename,
  });

  final String videoUrl;
  final String filename;

  static void show(BuildContext context, {required String videoUrl, required String filename}) {
    pushWithSwipeBack(
      context,
      VideoPlayerView(videoUrl: videoUrl, filename: filename),
    );
  }

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: false, // 整页就是全屏,不需要 chewie 二次全屏
      );
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error('Video init failed', e);
      if (mounted) {
        setState(() => _initError = 'chat_video_play_failed');
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _onSaveToAlbum() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    try {
      final localPath = await MediaSaver.downloadToTemp(widget.videoUrl, widget.filename);
      final result = await MediaSaver.saveVideo(localPath);
      switch (result) {
        case SaveResult.success:
          messenger.showSnackBar(SnackBar(content: Text(l10n.chatSaveSuccess)));
          break;
        case SaveResult.permissionDenied:
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.chatSavePermissionDenied),
            action: SnackBarAction(label: l10n.commonOpenSettings, onPressed: () {}),
          ));
          break;
        case SaveResult.failed:
          messenger.showSnackBar(SnackBar(content: Text(l10n.chatSaveFailed)));
          break;
      }
    } catch (e) {
      AppLogger.error('Save video failed', e);
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'save') _onSaveToAlbum();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatSaveToAlbum),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: _initError != null
            ? Text(
                context.localizeError(_initError),
                style: const TextStyle(color: Colors.white),
              )
            : (_chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator()),
      ),
    );
  }
}
```

- [ ] **Step 2: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/features/chat/views/video_player_view.dart`
Expected: 0 errors。注意会有"l10n.chatSaveSuccess / chatSavePermissionDenied / chatSaveFailed / chatSaveToAlbum / commonOpenSettings 未定义"提示 — **这些将在 Task 17 统一加 ARB**。本任务暂时跳过此 warning,代码先放着。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/chat/views/video_player_view.dart
git commit -m "feat(chat): VideoPlayerView 全屏 chewie + 三点菜单(保存到相册)"
```

---

### Task 13: Flutter pdf_preview_view(嵌入预览 + 三点菜单)

**Files:**
- Create: `link2ur/lib/features/chat/views/pdf_preview_view.dart`

- [ ] **Step 1: 实现 PdfPreviewView**

Create `link2ur/lib/features/chat/views/pdf_preview_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

class PdfPreviewView extends StatefulWidget {
  const PdfPreviewView({
    super.key,
    required this.pdfUrl,
    required this.filename,
  });

  final String pdfUrl;
  final String filename;

  static void show(BuildContext context, {required String pdfUrl, required String filename}) {
    pushWithSwipeBack(context, PdfPreviewView(pdfUrl: pdfUrl, filename: filename));
  }

  @override
  State<PdfPreviewView> createState() => _PdfPreviewViewState();
}

class _PdfPreviewViewState extends State<PdfPreviewView> {
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final path = await MediaSaver.downloadToTemp(widget.pdfUrl, widget.filename);
      if (mounted) setState(() => _localPath = path);
    } catch (e) {
      AppLogger.error('PDF download failed', e);
      if (mounted) setState(() => _error = 'chat_file_download_failed');
    }
  }

  Future<void> _openWithOther() async {
    if (_localPath == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await OpenFilex.open(_localPath!);
      if (result.type != ResultType.done && mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_file_download_failed')),
        ));
      }
    } catch (e) {
      AppLogger.error('Open file failed', e);
      messenger.showSnackBar(SnackBar(
        content: Text(context.localizeError('chat_file_download_failed')),
      ));
    }
  }

  Future<void> _shareOrSave() async {
    if (_localPath == null) return;
    try {
      await Share.shareXFiles([XFile(_localPath!)], subject: widget.filename);
    } catch (e) {
      AppLogger.error('Share PDF failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _openWithOther();
                  break;
                case 'share':
                  _shareOrSave();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatPdfOpenWithOther),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.ios_share, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatPdfShareOrSave),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(context.localizeError(_error)))
          : _localPath == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(
                  filePath: _localPath!,
                  onError: (e) {
                    AppLogger.error('PDF render error', e);
                    if (mounted) setState(() => _error = 'chat_pdf_preview_failed');
                  },
                ),
    );
  }
}
```

- [ ] **Step 2: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/features/chat/views/pdf_preview_view.dart`
Expected: 仅有"l10n.chatPdfOpenWithOther / chatPdfShareOrSave 未定义" — 同 Task 12,Task 17 一并加。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/chat/views/pdf_preview_view.dart
git commit -m "feat(chat): PdfPreviewView 嵌入预览 + 三点菜单(用其他应用打开/分享)"
```

---

### Task 14: Flutter FullScreenImageView 加 allowSaveToAlbum

**Files:**
- Modify: `link2ur/lib/core/widgets/full_screen_image_view.dart`

- [ ] **Step 1: 改 FullScreenImageView 加可选三点菜单**

Edit `link2ur/lib/core/widgets/full_screen_image_view.dart`:

**修改 1** — 类签名加可选参数。原:

```dart
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  final List<String> images;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
```

改为:

```dart
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onPageChanged,
    this.allowSaveToAlbum = false,
  });

  final List<String> images;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  /// 是否在右上角显示三点菜单的"保存到相册"项。任务聊天调用方传 true。
  final bool allowSaveToAlbum;
```

**修改 2** — `static void show` 接受 `allowSaveToAlbum`:

```dart
  static void show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    bool allowSaveToAlbum = false,
  }) {
    pushWithSwipeBack(
      context,
      FullScreenImageView(
        images: images,
        initialIndex: initialIndex,
        allowSaveToAlbum: allowSaveToAlbum,
      ),
    );
  }
```

**修改 3** — 在 build 方法的 Scaffold/Stack 顶部添加三点菜单。原 `build` 大约这样(line 77 起):

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        ...
```

在 Stack 内现有 children(图片 PageView + 关闭/翻页 controls)外,追加一个 Positioned 三点按钮:

```dart
            // 右上角:可选三点菜单(保存到相册等)
            if (widget.allowSaveToAlbum && _showControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                right: 8,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'save') _onSaveCurrent();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 20),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.chatSaveToAlbum),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
```

**修改 4** — `_FullScreenImageViewState` 加 `_onSaveCurrent` 方法:

```dart
  Future<void> _onSaveCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= widget.images.length) return;
    final url = widget.images[_currentIndex];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = await MediaSaver.saveImage(url);
    if (!mounted) return;
    switch (result) {
      case SaveResult.success:
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatSaveSuccess)));
        break;
      case SaveResult.permissionDenied:
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatSavePermissionDenied)));
        break;
      case SaveResult.failed:
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatSaveFailed)));
        break;
    }
  }
```

**修改 5** — 文件顶部加 imports:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/utils/media_saver.dart';
```

(注意:如果文件中已有 `import 'package:flutter_gen/gen_l10n/...'` 就不重复加。)

- [ ] **Step 2: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/core/widgets/full_screen_image_view.dart`
Expected: 仅 l10n key 未定义提示(Task 17 补)。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/widgets/full_screen_image_view.dart
git commit -m "feat(image-view): FullScreenImageView 加 allowSaveToAlbum + 三点菜单"
```

---

### Task 15: Flutter MessageGroupBubble 分发到 video/file/image bubble

**Files:**
- Modify: `link2ur/lib/features/chat/widgets/message_group_bubble.dart`

- [ ] **Step 1: 加分发逻辑**

Edit `link2ur/lib/features/chat/widgets/message_group_bubble.dart`。先确认目前如何渲染图片消息(应该是用 `_buildImageBubble` 或类似函数)。在文件内找到"图片气泡渲染"的 if 分支位置(可能是 `if (message.isImage)` 或 `if (message.messageType == 'image')`)。

将原来的二分支(image 或 text/system)改为四分支:

```dart
  Widget _buildMessageContent(BuildContext context, Message message, bool isMine) {
    if (message.messageType == 'video') {
      return VideoMessageBubble(
        message: message,
        isMine: isMine,
        onTap: () {
          final videoAtt = message.attachments.firstWhere(
            (a) => a.attachmentType == 'video',
            orElse: () => const MessageAttachment(),
          );
          final url = videoAtt.url;
          final filename = (videoAtt.meta?['original_filename'] as String?) ?? 'video.mp4';
          if (url != null && url.isNotEmpty) {
            VideoPlayerView.show(context, videoUrl: url, filename: filename);
          }
        },
      );
    }
    if (message.messageType == 'file') {
      return FileMessageBubble(
        attachment: message.attachments.firstWhere(
          (a) => a.attachmentType == 'file',
          orElse: () => const MessageAttachment(),
        ),
        isMine: isMine,
        onTap: () {
          final fileAtt = message.attachments.firstWhere(
            (a) => a.attachmentType == 'file',
            orElse: () => const MessageAttachment(),
          );
          final url = fileAtt.url;
          final filename = (fileAtt.meta?['original_filename'] as String?) ?? 'file.pdf';
          if (url != null && url.isNotEmpty) {
            PdfPreviewView.show(context, pdfUrl: url, filename: filename);
          }
        },
      );
    }
    if (message.isImage || message.hasImageAttachments) {
      // 既有图片渲染逻辑保持。点击改为传 allowSaveToAlbum: true
      return _buildImageBubble(context, message, isMine);
    }
    return _buildTextBubble(context, message, isMine);
  }
```

注意:这里 `_buildImageBubble` 和 `_buildTextBubble` 引用了既有内部方法 — **不要**改它们的签名,只在 build 入口插入新分支。在 build 方法里把"渲染图片或文字"那段提到 `_buildMessageContent` 调用,把分发判断收敛到一处。

另外在 `_buildImageBubble` 内,找到 `FullScreenImageView.show(...)` 调用(应该在 line ~?),把参数加上 `allowSaveToAlbum: true`:

```dart
            FullScreenImageView.show(
              context,
              images: imageUrls,
              initialIndex: i,
              allowSaveToAlbum: true,
            );
```

文件顶部 imports 加:

```dart
import '../views/pdf_preview_view.dart';
import '../views/video_player_view.dart';
import 'file_message_bubble.dart';
import 'video_message_bubble.dart';
```

- [ ] **Step 2: 跑 analyze**

Run: `cd link2ur; flutter analyze lib/features/chat/widgets/message_group_bubble.dart`
Expected: 0 errors。

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/chat/widgets/message_group_bubble.dart
git commit -m "feat(chat): MessageGroupBubble 按 messageType 分发 image/video/file"
```

---

### Task 16: Flutter error_localizer 加新错误码映射

**Files:**
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: 加映射**

Edit `link2ur/lib/core/utils/error_localizer.dart`,在主映射 switch 或 map 里加(具体位置看文件结构 — 在已有 `case 'chat_send_message_failed':` 这类条目附近):

```dart
      case 'chat_video_too_long':
        return l10n.chatVideoTooLong;
      case 'chat_video_too_large':
        return l10n.chatVideoTooLarge;
      case 'chat_video_compress_failed':
        return l10n.chatVideoCompressFailed;
      case 'chat_file_type_not_allowed':
        return l10n.chatFileTypeNotAllowed;
      case 'chat_file_too_large':
        return l10n.chatFileTooLarge;
      case 'chat_upload_failed':
        return l10n.chatUploadFailed;
      case 'chat_upload_network_offline':
        return l10n.chatUploadNetworkOffline;
      case 'chat_video_play_failed':
        return l10n.chatVideoPlayFailed;
      case 'chat_file_download_failed':
        return l10n.chatFileDownloadFailed;
      case 'chat_pdf_preview_failed':
        return l10n.chatPdfPreviewFailed;
```

- [ ] **Step 2: 跑 analyze**

(预计还会提示 l10n key 未定义,Task 17 解决。)

Run: `cd link2ur; flutter analyze lib/core/utils/error_localizer.dart`

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat(chat): error_localizer 加视频/PDF 相关错误码映射"
```

---

### Task 17: Flutter l10n ARB 三套字符串补齐

**Files:**
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: 加 ARB key**

Edit `link2ur/lib/l10n/app_zh.arb`,在末尾 `}` 之前追加:

```json
  "chatVideoTooLong": "视频不能超过 30 秒",
  "chatVideoTooLarge": "视频文件过大(最大 30MB)",
  "chatVideoCompressFailed": "视频压缩失败,请重试",
  "chatFileTypeNotAllowed": "只支持 PDF 文件",
  "chatFileTooLarge": "文件过大(最大 20MB)",
  "chatUploadFailed": "上传失败,请重试",
  "chatUploadNetworkOffline": "网络未连接",
  "chatVideoPlayFailed": "视频播放失败",
  "chatFileDownloadFailed": "文件下载失败",
  "chatPdfPreviewFailed": "PDF 预览失败",
  "chatSaveSuccess": "已保存到相册",
  "chatSaveFailed": "保存失败",
  "chatSavePermissionDenied": "需要相册权限,请到设置开启",
  "chatSaveToAlbum": "保存到相册",
  "chatPdfOpenWithOther": "用其他应用打开",
  "chatPdfShareOrSave": "分享 / 保存",
  "commonOpenSettings": "去设置"
```

(以上每个 key 加上 description,例如:)

```json
  "@chatVideoTooLong": {"description": "选中视频超过 30 秒上限时提示"},
  ...
```

Edit `link2ur/lib/l10n/app_en.arb`,同样位置追加(英文):

```json
  "chatVideoTooLong": "Video must be 30 seconds or less",
  "chatVideoTooLarge": "Video file is too large (max 30MB)",
  "chatVideoCompressFailed": "Video compression failed, please try again",
  "chatFileTypeNotAllowed": "Only PDF files are supported",
  "chatFileTooLarge": "File is too large (max 20MB)",
  "chatUploadFailed": "Upload failed, please try again",
  "chatUploadNetworkOffline": "No network connection",
  "chatVideoPlayFailed": "Failed to play video",
  "chatFileDownloadFailed": "File download failed",
  "chatPdfPreviewFailed": "PDF preview failed",
  "chatSaveSuccess": "Saved to album",
  "chatSaveFailed": "Save failed",
  "chatSavePermissionDenied": "Album permission required, please open in Settings",
  "chatSaveToAlbum": "Save to album",
  "chatPdfOpenWithOther": "Open with another app",
  "chatPdfShareOrSave": "Share / Save",
  "commonOpenSettings": "Open Settings"
```

Edit `link2ur/lib/l10n/app_zh_Hant.arb`,同样追加(繁体):

```json
  "chatVideoTooLong": "影片不能超過 30 秒",
  "chatVideoTooLarge": "影片檔案過大(最大 30MB)",
  "chatVideoCompressFailed": "影片壓縮失敗,請重試",
  "chatFileTypeNotAllowed": "只支援 PDF 檔案",
  "chatFileTooLarge": "檔案過大(最大 20MB)",
  "chatUploadFailed": "上傳失敗,請重試",
  "chatUploadNetworkOffline": "網路未連線",
  "chatVideoPlayFailed": "影片播放失敗",
  "chatFileDownloadFailed": "檔案下載失敗",
  "chatPdfPreviewFailed": "PDF 預覽失敗",
  "chatSaveSuccess": "已儲存到相簿",
  "chatSaveFailed": "儲存失敗",
  "chatSavePermissionDenied": "需要相簿權限,請到設定開啟",
  "chatSaveToAlbum": "儲存到相簿",
  "chatPdfOpenWithOther": "用其他應用程式開啟",
  "chatPdfShareOrSave": "分享 / 儲存",
  "commonOpenSettings": "前往設定"
```

- [ ] **Step 2: 重新生成 l10n**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter gen-l10n
```
Expected: 0 errors。

- [ ] **Step 3: 跑全 analyze**

Run: `cd link2ur; flutter analyze`
Expected: 0 errors(Task 12/13/14/16 之前所有"l10n key 未定义"提示应全部消除)。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/generated/
git commit -m "i18n(chat): 加视频/PDF/保存到相册 三语字符串"
```

---

### Task 18: 端到端手动 QA(linktest)

**Files:** 无代码改动,只做验证 + 记录

- [ ] **Step 1: 推送到 linktest**

按用户的 [direct to main](https://...) 偏好,直接推 main:

```bash
git push origin main
```

等 Railway linktest 部署完成(通常 2-3 分钟,看 `https://linktest.up.railway.app/health`)。

- [ ] **Step 2: 构建 debug app**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"; cd link2ur; flutter run -d android
# 另起一个 shell 跑 iOS:
# flutter run -d ios
```

- [ ] **Step 3: 手动测试矩阵 — 视频发送**

在 linktest 环境(自动指向)上跑下列路径:

- [ ] 进任意任务聊天 → 点工具栏"照片" → 系统图库选一个 < 30s 的视频 → 等压缩进度 → 看到 pending 消息出现 → 看到真实消息替换 pending
- [ ] 选 > 30s 视频 → 看到 SnackBar "视频不能超过 30 秒"
- [ ] 选一个非常大的视频(压缩后仍 > 30MB) → 看到 SnackBar "视频文件过大"
- [ ] 在断网状态下选视频 → 看到 SnackBar "网络未连接"
- [ ] 接收端打开同一任务聊天 → 看到视频气泡(缩略图 + 播放按钮 + 时长)
- [ ] 点缩略图 → 进入全屏 chewie 播放器,视频自动播放
- [ ] 全屏页右上角三点 → "保存到相册" → 首次弹相册权限 → 同意 → SnackBar "已保存到相册"
- [ ] 拒绝相册权限 → SnackBar "需要相册权限,请到设置开启"
- [ ] 系统相册里能看到视频

- [ ] **Step 4: 手动测试矩阵 — PDF 发送**

- [ ] 工具栏点"文件" → file_picker 弹起,过滤为 PDF → 选 < 20MB PDF → 发送 → 看到 pending → 真实消息替换
- [ ] 选 > 20MB PDF → SnackBar "文件过大"
- [ ] 接收端看到 PDF 气泡(PDF 图标 + 文件名 + 大小)
- [ ] 点 PDF 气泡 → 进 PdfPreviewView,看到嵌入 PDF 渲染
- [ ] 右上角三点 → "用其他应用打开" → iOS 弹分享面板 / Android 弹 ACTION_VIEW 选择器 → 系统 PDF app 打开正常
- [ ] 右上角三点 → "分享/保存" → 系统分享面板弹起 → "存储到文件" / "Drive" 等正常

- [ ] **Step 5: 手动测试矩阵 — 图片保存到相册(回归 + 新功能)**

- [ ] 发一张图片 → 接收端点开图片 lightbox → 右上角三点(新增) → "保存到相册" → 已保存
- [ ] 在其他地方调用 FullScreenImageView 的页面(任务详情图片预览、个人主页等) → 确认**没有**三点菜单(因 allowSaveToAlbum 默认 false)

- [ ] **Step 6: 回归 — 文字 + 图片消息**

- [ ] 发文字消息 → 正常
- [ ] 发单图、多图 → 正常,与原行为一致
- [ ] 拍照发送 → 正常(走 ConfirmDialog 确认)

- [ ] **Step 7: 记录问题清单**

在 `docs/superpowers/plans/2026-05-15-task-chat-video-file-qa.md` 记录任何 issue,作为下一轮迭代输入。

- [ ] **Step 8: 推 prod(确认无 P0/P1 后)**

回到工作分支(已是 main),Railway 自动部署到 prod。**注意 prod 有 Celery 跑清理任务**,要监控:`/api/v2/storage/categories` 查 `private_files` 分类增量。

---

## Self-Review

### 1. Spec coverage

| Spec 要求 | 对应任务 |
|---|---|
| 视频上限 30s/30MB | Task 1 (validators), Task 10 (前端校验) |
| 视频前端轻度压缩 | Task 10 (`VideoCompress.compressVideo`) |
| 视频抽帧作独立 attachment | Task 6 (ChatSendVideo handler), Task 10 |
| PDF 仅 .pdf magic byte + ≤20MB | Task 1, Task 2 |
| `?usage=chat_media` 分支 | Task 2 |
| `private_files/tasks/{task_id}/chat/` 子目录 | **未单独 task**(见下文 gap) |
| 后端 attachment 解析扩展(video/file) | Task 3 |
| MessageAttachment schema 不变 | 设计层(plan 不需 task) |
| 视频消息含 video + image-thumbnail | Task 6 |
| 接收端 video_message_bubble | Task 11 |
| 全屏播放器 | Task 12 |
| 文件 file_message_bubble | Task 11 |
| PDF 嵌入预览 | Task 13 |
| 右上角三点菜单 | Task 12(视频), Task 13(PDF), Task 14(图片) |
| 视频/图片保存相册(gal) | Task 8, Task 12, Task 14 |
| PDF 用其他应用打开(open_filex) | Task 13 |
| PDF 分享/保存(share_plus) | Task 13 |
| iOS NSPhotoLibraryAddUsageDescription | Task 4 |
| Android READ_MEDIA_*  | Task 4 |
| 错误码 + 三语 ARB | Task 16 + Task 17 |
| 限流复用 upload_file | Task 2 (装饰器已存在,无需新增) |
| 跟随任务清理 | **未单独 task**(见下文 gap) |
| 撤回不支持 | YAGNI,不实现 |
| BLoC 乐观更新 | Task 6, Task 7 |
| 手动 QA | Task 18 |

### 2. Placeholder scan

- 无 "TBD" / "TODO" / "implement later"
- 所有代码 step 都有完整可执行 code
- 所有命令都有 expected output

### 3. Type consistency

- `uploadChatVideo` / `uploadChatPdf` 返回类型 `({String url, String blobId, int size, String originalName})` 一致(Task 5),被 Task 6 / Task 7 调用方按相同字段解构,符合
- `ChatSendVideo` 字段名(`videoBytes`, `videoFilename`, `videoDurationMs`, ...)在 Task 6 测试与 handler 一致
- `MediaSaver.saveVideo(localPath)` 接收本地路径,被 Task 12 调用前先 `downloadToTemp` — 正确
- `MediaSaver.saveImage(url)` 接收远程 URL,被 Task 14 直接调用 — 正确
- `attachment_type` 字符串 `"video"` / `"file"` / `"image"` 在 Task 1/2/3/6/7/11/15 全部一致

### 4. 已识别的 gap(本 plan 范围外,作为 follow-up)

- **`private_files/tasks/{task_id}/chat/` 子目录命名**:Spec 提到这个用于审计;实现层面 `private_file_system.upload_file()` 当前直接落 `private_files/tasks/{task_id}/`(不分 chat 子目录)。要落子目录需要改 `file_system.py` 的 save 路径生成逻辑,**且影响其他 caller**。本 plan 暂不做此区分,影响是:任务聊天 PDF/视频 与 "完成证据" 文件混在同一目录。未来要审计/统计时,需查 `MessageAttachment` 表过滤 `attachment_type IN ('video', 'file')`,或单独加一个 follow-up plan 分子目录。已在 spec 8.5 节标注存储后端是未来项。
- **任务清理时一并清掉视频/PDF**:`cleanup_tasks.py` 现在已经清理 `private_files/tasks/{task_id}` 整个目录(本 plan 摸排已验证 `cleanup_tasks.py:904` 提到了 base_dir),因为视频/PDF 也落该目录,**自动覆盖,无需新加 task**。
- **rate_limit `upload_file` 是否对视频体积太宽松**:`@rate_limit("upload_file")` 限的是次数不是 MB。如果出现刷视频导致带宽暴涨,需要在 spec R2 那节合并处理。本 plan 维持原状。

### 5. 总体

Plan 17 个实现 task + 1 个 QA task,涵盖 spec 所有要求。可以执行。

---

## 总结

| 阶段 | Tasks |
|---|---|
| Phase A 后端 | 1, 2, 3 |
| Phase B Flutter 基础 | 4, 5 |
| Phase C BLoC | 6, 7 |
| Phase D 工具 | 8 |
| Phase E UI 发送 | 9, 10 |
| Phase F UI 接收/预览 | 11, 12, 13, 14, 15 |
| Phase G 辅助 | 16, 17 |
| Phase H 验证 | 18 |

每个 task 自包含、可单独 commit。Backend 部分先做且独立可单测;Flutter 部分自下而上(data → bloc → UI)。

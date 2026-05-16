"""集成测试: POST /api/messages/task/{task_id}/send 必须为 video/file/image
attachment 返回签名 URL(对齐 GET 路径行为)。

背景: 发消息时如果只回 url=null + blob_id, sender 端 optimistic message 会被
替换为 url=null, WebSocket 广播也是 null, 接收者只能 pull-to-refresh 才能播放。
DB CheckConstraint 强制 url XOR blob_id, 所以 new_attachment.url 必须保持 None,
但响应/广播 dict 必须由后端生成 url。

测试策略与 test_task_chat_get_messages_video_file.py 一致: 直接 await 调用
路由函数, 用 MagicMock 构造 AsyncSession, 按 send_task_message 中 db.execute
调用顺序回放结果。
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_task(
    task_id=10,
    poster_id="u_poster1",
    taker_id="u_taker1",
    status_val="in_progress",
):
    t = MagicMock()
    t.id = task_id
    t.poster_id = poster_id
    t.taker_id = taker_id
    t.is_multi_participant = False
    t.created_by_expert = False
    t.expert_creator_id = None
    t.title = "Test task"
    t.task_type = "normal"
    t.task_source = "normal"
    t.status = status_val
    return t


def _make_user(user_id="u_poster1", name="Poster", avatar=None):
    u = MagicMock()
    u.id = user_id
    u.name = name
    u.avatar = avatar
    return u


def _build_send_db(task):
    """构造 send_task_message 路径所需的 AsyncSession mock。

    send_task_message 的 db.execute 调用顺序(单人非多人任务、非 application 路径、非 consultation):
      1. select(Task)            → task_result.scalar_one_or_none() = task
    (无 application_id, 跳过 application 查询)
    (非多人, 不查 TaskParticipant)
    (非 consultation, 不查 ServiceApplication)
    (说明性消息分支不走, 不查频率限制)
    然后 db.add(new_message) → db.flush() → 给 new_message.id 赋值
    然后 db.add(new_attachment) → 给 new_attachment.id 赋值
    然后 db.commit() / db.refresh(new_message) / 广播阶段
      2. select(ChatParticipant) → cp_result.scalars().all() = []  (extra 多人聊天扩展)
    (非 consultation, 不查 SA)
    """
    db = MagicMock()

    task_result = MagicMock()
    task_result.scalar_one_or_none = MagicMock(return_value=task)

    cp_result = MagicMock()
    cp_scalars = MagicMock()
    cp_scalars.all = MagicMock(return_value=[])
    cp_result.scalars = MagicMock(return_value=cp_scalars)

    # side_effect 给 await db.execute(...) 用; ChatParticipant 查询在 broadcast 分支才会触发
    db.execute = AsyncMock(side_effect=[task_result, cp_result])

    # db.add 给 new_message/new_attachment 赋 id (模拟 flush 自动 PK 分配)
    added_objects = []
    _id_counter = {"msg": 9000, "att": 9500}

    def _fake_add(obj):
        added_objects.append(obj)
        # 检测 MessageAttachment vs Message: 用属性签名
        if hasattr(obj, "attachment_type"):
            _id_counter["att"] += 1
            obj.id = _id_counter["att"]
        else:
            _id_counter["msg"] += 1
            obj.id = _id_counter["msg"]

    db.add = MagicMock(side_effect=_fake_add)

    async def _fake_flush():
        return None
    db.flush = _fake_flush

    async def _fake_commit():
        return None
    db.commit = _fake_commit

    async def _fake_refresh(obj):
        return None
    db.refresh = _fake_refresh

    async def _fake_rollback():
        return None
    db.rollback = _fake_rollback

    return db, added_objects


@pytest.mark.asyncio
async def test_send_video_message_returns_signed_url():
    """POST 一条视频消息(blob_id only) → 响应 attachments[0].url 是
    /api/private-file 签名链接, blob_id 仍然保留。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=10, poster_id="u_poster1", taker_id="u_taker1")
    current_user = _make_user(user_id="u_poster1", name="Poster")

    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="[视频]",
        attachments=[
            {
                "attachment_type": "video",
                "blob_id": "u_poster1_1700000000_abcdef.mp4",
                "meta": {"duration": 28, "width": 1080, "height": 1920},
            },
        ],
    )

    fake_signed = "http://example.com/api/private-file?file=files/x.mp4&user=u_poster1&sig=fake"

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value=fake_signed,
    ) as mock_signed, patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        # ws_manager.send_to_user is async; let it return True so we skip push fallback
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=10,
            request=request,
            current_user=current_user,
            db=db,
        )

    # 1. 响应里 attachments[0].url 必须是 signed URL
    assert "attachments" in result
    assert len(result["attachments"]) == 1
    att = result["attachments"][0]
    assert att["attachment_type"] == "video"
    assert att["blob_id"] == "u_poster1_1700000000_abcdef.mp4"
    assert att["url"] == fake_signed
    assert "/api/private-file" in att["url"]
    # meta 透传
    assert att["meta"]["duration"] == 28
    assert att["meta"]["width"] == 1080

    # 2. signed_url_manager 被以正确参数调用
    mock_signed.assert_called_once()
    kwargs = mock_signed.call_args.kwargs
    assert kwargs["file_path"] == "files/u_poster1_1700000000_abcdef.mp4"
    assert kwargs["user_id"] == "u_poster1"
    assert kwargs["expiry_minutes"] == 15
    assert kwargs["one_time"] is False

    # 3. WS 广播也带 url(因为 broadcast 用同一个 attachments_data dict)
    ws_mgr.send_to_user.assert_called()
    sent_payload = ws_mgr.send_to_user.call_args.args[1]
    assert sent_payload["type"] == "task_message"
    assert sent_payload["message"]["attachments"][0]["url"] == fake_signed


@pytest.mark.asyncio
async def test_send_file_message_returns_signed_url():
    """POST 一条 PDF 文件消息 → 响应 + 广播都带 /api/private-file URL。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=11, poster_id="u_poster2", taker_id="u_taker2")
    current_user = _make_user(user_id="u_poster2", name="Poster2")
    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="[文件:report.pdf]",
        attachments=[
            {
                "attachment_type": "file",
                "blob_id": "u_poster2_1700000000_abcdef.pdf",
                "meta": {
                    "original_filename": "report.pdf",
                    "content_type": "application/pdf",
                    "size": 12345,
                },
            },
        ],
    )

    fake_signed = "http://example.com/api/private-file?file=files/report.pdf&user=u_poster2&sig=fake"

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value=fake_signed,
    ), patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=11,
            request=request,
            current_user=current_user,
            db=db,
        )

    att = result["attachments"][0]
    assert att["attachment_type"] == "file"
    assert att["url"] == fake_signed
    assert "/api/private-file" in att["url"]
    assert att["meta"]["original_filename"] == "report.pdf"


@pytest.mark.asyncio
async def test_send_image_message_with_blob_id_returns_private_image_url():
    """POST 图片(blob_id only) → 响应 attachments[0].url 是 /api/private-image。
    这一行为是新增的(GET 已对齐), 不应破坏既有 public-url 图片消息。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=12, poster_id="u_poster3", taker_id="u_taker3")
    current_user = _make_user(user_id="u_poster3", name="Poster3")
    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="[图片]",
        attachments=[
            {
                "attachment_type": "image",
                "blob_id": "u_poster3_1700000000_abc.jpg",
                "meta": {},
            },
        ],
    )

    fake_image_url = "http://example.com/api/private-image?token=fake_token"

    with patch(
        "app.image_system.private_image_system.generate_image_url",
        return_value=fake_image_url,
    ) as mock_image, patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=12,
            request=request,
            current_user=current_user,
            db=db,
        )

    att = result["attachments"][0]
    assert att["attachment_type"] == "image"
    assert att["url"] == fake_image_url
    assert "/api/private-image" in att["url"]
    mock_image.assert_called_once()
    # 参与者列表里应该包含发送者
    call_args = mock_image.call_args.args
    assert call_args[0] == "u_poster3_1700000000_abc.jpg"  # blob_id
    assert call_args[1] == "u_poster3"  # sender id
    participants = call_args[2]
    assert "u_poster3" in participants
    assert "u_poster1" not in participants  # 别的 task 的人不应该混进来


@pytest.mark.asyncio
async def test_send_video_message_persists_message_type_video():
    """POST 带 message_type='video' → 响应/广播/DB Message 都是 'video',
    不再被硬编码成 'normal'(修复 SendMessageRequest schema 静默丢字段 bug)。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=20, poster_id="u_vid_p", taker_id="u_vid_t")
    current_user = _make_user(user_id="u_vid_p", name="VidPoster")
    db, added_objects = _build_send_db(task)

    request = SendMessageRequest(
        content="[视频]",
        message_type='video',
        attachments=[
            {
                "attachment_type": "video",
                "blob_id": "u_vid_p_1700000000_xyz.mp4",
                "meta": {"duration": 10},
            },
        ],
    )

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="http://example.com/api/private-file?sig=fake",
    ), patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=20,
            request=request,
            current_user=current_user,
            db=db,
        )

    # 1. POST 响应里 message_type 是 'video'
    assert result["message_type"] == "video"

    # 2. 写入 DB 的 Message 对象 message_type 也是 'video'
    message_objs = [o for o in added_objects if not hasattr(o, "attachment_type")]
    assert len(message_objs) == 1
    assert message_objs[0].message_type == "video"

    # 3. WS 广播 payload 里 message_type 也是 'video'
    sent_payload = ws_mgr.send_to_user.call_args.args[1]
    assert sent_payload["message"]["message_type"] == "video"


@pytest.mark.asyncio
async def test_send_file_message_persists_message_type_file():
    """POST 带 message_type='file' → 链路保持 'file'。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=21, poster_id="u_f_p", taker_id="u_f_t")
    current_user = _make_user(user_id="u_f_p", name="FilePoster")
    db, added_objects = _build_send_db(task)

    request = SendMessageRequest(
        content="[文件:a.pdf]",
        message_type='file',
        attachments=[
            {
                "attachment_type": "file",
                "blob_id": "u_f_p_1700000000_a.pdf",
                "meta": {"original_filename": "a.pdf"},
            },
        ],
    )

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="http://example.com/api/private-file?sig=fake",
    ), patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=21,
            request=request,
            current_user=current_user,
            db=db,
        )

    assert result["message_type"] == "file"
    message_objs = [o for o in added_objects if not hasattr(o, "attachment_type")]
    assert message_objs[0].message_type == "file"
    sent_payload = ws_mgr.send_to_user.call_args.args[1]
    assert sent_payload["message"]["message_type"] == "file"


@pytest.mark.asyncio
async def test_send_message_default_message_type_is_normal():
    """不传 message_type → 走 default 'normal',保持向后兼容。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=22, poster_id="u_n_p", taker_id="u_n_t")
    current_user = _make_user(user_id="u_n_p", name="NormalPoster")
    db, added_objects = _build_send_db(task)

    request = SendMessageRequest(content="hi")
    assert request.message_type == "normal"

    with patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=22,
            request=request,
            current_user=current_user,
            db=db,
        )

    assert result["message_type"] == "normal"
    message_objs = [o for o in added_objects if not hasattr(o, "attachment_type")]
    assert message_objs[0].message_type == "normal"


def test_send_message_request_rejects_system_type():
    """SendMessageRequest schema 必须拒绝 'system'/'admin' 等非白名单类型,
    防止客户端伪造系统消息。"""
    from pydantic import ValidationError

    from app.task_chat_routes import SendMessageRequest

    for bad in ("system", "admin", "negotiation", "price_proposal", "", "SYSTEM"):
        with pytest.raises(ValidationError):
            SendMessageRequest(content="x", message_type=bad)


def test_send_message_request_accepts_whitelist_types():
    """白名单内的几种类型必须能正常构造。"""
    from app.task_chat_routes import SendMessageRequest

    for ok in ("normal", "image", "video", "file", "text"):
        req = SendMessageRequest(content="x", message_type=ok)
        assert req.message_type == ok


@pytest.mark.asyncio
async def test_send_video_url_already_provided_not_overwritten():
    """如果客户端提供了 url(不是 blob_id), 不应被覆盖。
    虽然现在 chat media 不会走这条路径, 但 video 类型理论上允许 public URL,
    新逻辑必须确保 resolved_url = new_attachment.url 时不进 generate 分支。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=13, poster_id="u_p4", taker_id="u_t4")
    current_user = _make_user(user_id="u_p4", name="P4")
    db, _ = _build_send_db(task)

    public_video_url = "https://cdn.example.com/public/clip.mp4"
    request = SendMessageRequest(
        content="[视频]",
        attachments=[
            {
                "attachment_type": "video",
                "url": public_video_url,
                "meta": {},
            },
        ],
    )

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="SHOULD_NOT_BE_USED",
    ) as mock_signed, patch(
        "app.redis_cache.invalidate_task_chat_cache",
        return_value=None,
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr

        result = await send_task_message(
            task_id=13,
            request=request,
            current_user=current_user,
            db=db,
        )

    att = result["attachments"][0]
    assert att["url"] == public_video_url
    assert att["blob_id"] is None
    # 签名生成器不应被触发
    mock_signed.assert_not_called()


# ---------------------------------------------------------------------------
# Important #36: POST attachment_type 与 blob_id 后缀 mismatch 防御
# ---------------------------------------------------------------------------

def test_send_message_rejects_video_with_pdf_blob():
    """attachment_type='video' 但 blob_id 是 .pdf → 422 拒绝。
    防止客户端先上传 PDF 拿 blob,然后欺骗接收端为视频。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest
    import asyncio

    task = _make_task(task_id=30, poster_id="u_p", taker_id="u_t")
    current_user = _make_user(user_id="u_p", name="P")
    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="[视频]",
        message_type="video",
        attachments=[
            {
                "attachment_type": "video",
                "blob_id": "u_p_1700000000_evil.pdf",  # 故意 .pdf
                "meta": {"duration": 10},
            },
        ],
    )

    async def _run():
        with patch(
            "app.signed_url.signed_url_manager.generate_signed_url",
            return_value="x",
        ), patch(
            "app.redis_cache.invalidate_task_chat_cache",
        ), patch(
            "app.websocket_manager.get_ws_manager",
        ):
            await send_task_message(
                task_id=30, request=request, current_user=current_user, db=db,
            )

    with pytest.raises(Exception) as exc_info:
        asyncio.get_event_loop().run_until_complete(_run())
    # FastAPI 把 HTTPException 转 detail,422,且 detail 含 'video' 关键字
    assert "422" in str(exc_info.value) or "video" in str(exc_info.value).lower()


def test_send_message_rejects_file_with_mp4_blob():
    """attachment_type='file' 但 blob_id 是 .mp4 → 422 拒绝。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest
    import asyncio

    task = _make_task(task_id=31, poster_id="u_p", taker_id="u_t")
    current_user = _make_user(user_id="u_p", name="P")
    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="[文件]",
        message_type="file",
        attachments=[
            {
                "attachment_type": "file",
                "blob_id": "u_p_1700000000_evil.mp4",  # 故意 .mp4
                "meta": {},
            },
        ],
    )

    async def _run():
        with patch(
            "app.signed_url.signed_url_manager.generate_signed_url",
            return_value="x",
        ), patch(
            "app.redis_cache.invalidate_task_chat_cache",
        ), patch(
            "app.websocket_manager.get_ws_manager",
        ):
            await send_task_message(
                task_id=31, request=request, current_user=current_user, db=db,
            )

    with pytest.raises(Exception) as exc_info:
        asyncio.get_event_loop().run_until_complete(_run())
    assert "422" in str(exc_info.value) or "file" in str(exc_info.value).lower()


# ---------------------------------------------------------------------------
# Important #37: WS broadcast + POST response 含 meta 字段
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_message_response_includes_meta():
    """POST response + WS broadcast 必须含 'meta' 字段(GET 路径已透传,这里对齐)。"""
    from app.task_chat_routes import send_task_message, SendMessageRequest

    task = _make_task(task_id=40, poster_id="u_meta_p", taker_id="u_meta_t")
    current_user = _make_user(user_id="u_meta_p", name="MetaP")
    db, _ = _build_send_db(task)

    request = SendMessageRequest(
        content="hello",
        meta={"client_msg_id": "abc-123"},
    )

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="x",
    ), patch(
        "app.redis_cache.invalidate_task_chat_cache",
    ), patch(
        "app.websocket_manager.get_ws_manager",
    ) as mock_ws_mgr:
        ws_mgr = MagicMock()
        ws_mgr.send_to_user = AsyncMock(return_value=True)
        mock_ws_mgr.return_value = ws_mgr
        result = await send_task_message(
            task_id=40, request=request, current_user=current_user, db=db,
        )

    # POST response 含 meta
    assert "meta" in result, f"POST response 必须含 meta, 实际 keys: {list(result.keys())}"
    assert result["meta"] is not None
    # meta 是 JSON 字符串(数据库存储格式),不是 dict
    assert "client_msg_id" in result["meta"]

    # WS broadcast payload 也含 meta
    sent_payload = ws_mgr.send_to_user.call_args.args[1]
    assert "meta" in sent_payload["message"], (
        f"WS broadcast 必须含 meta, keys: {list(sent_payload['message'].keys())}"
    )

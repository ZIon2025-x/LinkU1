"""集成测试: GET /api/messages/task/{task_id} 必须为 video/file attachment 生成签名 URL。

测试策略:
- 项目 conftest 没有 authed_client/db_session/sample_task fixture(参考 Task 2:
  test_upload_inline_routes_chat_media.py 也是 mock 路线)。本测试直接 await
  调用 get_task_messages 路由函数,传入用 MagicMock 构造的 AsyncSession,逐步
  让 db.execute 返回准备好的结果。这与 test_team_service_application_approve.py
  的模式一致。
- 真正关心的是 attachments 序列化逻辑: video/file 类型必须 populate `url`
  字段, image 类型行为不变。
"""
from __future__ import annotations

import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# 确保可以导入 app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_task(
    task_id=10,
    poster_id="u_poster1",
    taker_id="u_taker1",
):
    """A minimal Task stub (not multi-participant, no expert_service)."""
    t = MagicMock()
    t.id = task_id
    t.poster_id = poster_id
    t.taker_id = taker_id
    t.is_multi_participant = False
    t.created_by_expert = False
    t.expert_creator_id = None
    t.expert_service_id = None
    t.title = "Test task"
    t.title_en = None
    t.title_zh = None
    t.task_type = "normal"
    t.images = None
    t.status = "in_progress"
    t.completed_at = None
    t.agreed_reward = None
    t.base_reward = 100
    t.reward_to_be_quoted = False
    t.currency = "GBP"
    t.task_source = "normal"
    return t


def _make_user(user_id="u_poster1", name="Poster", avatar=None):
    u = MagicMock()
    u.id = user_id
    u.name = name
    u.avatar = avatar
    return u


def _make_message(
    msg_id=1001,
    sender_id="u_poster1",
    task_id=10,
    content="[视频]",
    message_type="normal",
):
    from datetime import datetime, timezone
    m = MagicMock()
    m.id = msg_id
    m.sender_id = sender_id
    m.task_id = task_id
    m.content = content
    m.message_type = message_type
    m.conversation_type = "task"
    m.application_id = None
    m.created_at = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    m.meta = None
    return m


def _make_attachment(
    att_id,
    message_id,
    attachment_type,
    blob_id,
    meta=None,
    url=None,
):
    a = MagicMock()
    a.id = att_id
    a.message_id = message_id
    a.attachment_type = attachment_type
    a.blob_id = blob_id
    a.meta = meta
    a.url = url
    return a


def _build_db_with(task, messages, users, attachments, reads=None, participants=None):
    """构造一个 AsyncSession mock, 按 get_task_messages 中 db.execute 的调用顺序
    依次回放结果:
      1. select(Task)              → task scalar_one_or_none
      2. select(Message)           → messages scalars().all()
      3. select(User) [batch]      → users scalars().all()
      4. select(MessageRead)       → reads scalars().all()
      5. select(ChatParticipant)   → participants scalars().all() (我们让它空)
      6. select(MessageAttachment) → attachments scalars().all()

    注意: task 非多人模式,所以中间不会查 TaskParticipant。
    """
    if reads is None:
        reads = []
    if participants is None:
        participants = []

    db = MagicMock()

    # 1. Task lookup
    task_result = MagicMock()
    task_result.scalar_one_or_none.return_value = task

    # 2. Messages
    msg_scalars = MagicMock()
    msg_scalars.all.return_value = messages
    msg_result = MagicMock()
    msg_result.scalars.return_value = msg_scalars

    # 3. Users (batch)
    user_scalars = MagicMock()
    user_scalars.all.return_value = users
    user_result = MagicMock()
    user_result.scalars.return_value = user_scalars

    # 4. MessageRead
    read_scalars = MagicMock()
    read_scalars.all.return_value = reads
    read_result = MagicMock()
    read_result.scalars.return_value = read_scalars

    # 5. ChatParticipant
    cp_scalars = MagicMock()
    cp_scalars.all.return_value = participants
    cp_result = MagicMock()
    cp_result.scalars.return_value = cp_scalars

    # 6. Attachments
    att_scalars = MagicMock()
    att_scalars.all.return_value = attachments
    att_result = MagicMock()
    att_result.scalars.return_value = att_scalars

    db.execute = AsyncMock(side_effect=[
        task_result, msg_result, user_result, read_result, cp_result, att_result
    ])
    return db


@pytest.mark.asyncio
async def test_video_attachment_gets_signed_url():
    """发视频消息后, 读消息时 attachment.url 是 /api/private-file 签名链接;
    缩略图 image attachment 走 /api/private-image 路径(行为不变)。"""
    from app.task_chat_routes import get_task_messages

    task = _make_task(task_id=10, poster_id="u_poster1", taker_id="u_taker1")
    sender = _make_user(user_id="u_poster1", name="Poster")
    msg = _make_message(msg_id=1001, sender_id="u_poster1", task_id=10)

    video_blob = "u_poster1_1700000000_abcdef12.mp4"
    thumb_blob = "u_poster1_1700000000_abcdef13.jpg"
    atts = [
        _make_attachment(
            att_id=501,
            message_id=1001,
            attachment_type="video",
            blob_id=video_blob,
            meta='{"duration":28,"width":1080,"height":1920}',
        ),
        _make_attachment(
            att_id=502,
            message_id=1001,
            attachment_type="image",
            blob_id=thumb_blob,
            meta='{"role":"thumbnail"}',
        ),
    ]

    db = _build_db_with(task=task, messages=[msg], users=[sender], attachments=atts)
    current_user = _make_user(user_id="u_poster1", name="Poster")

    # Patch private_image_system + signed_url_manager 桩, 这样可以确认调用以及
    # 不依赖运行时配置(IMAGE_ACCESS_SECRET 等)。
    with patch(
        "app.image_system.private_image_system.generate_image_url",
        return_value="http://example.com/api/private-image?token=fake_image_token",
    ), patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="http://example.com/api/private-file?file=files/x&user=u_poster1&sig=fake",
    ):
        data = await get_task_messages(
            task_id=10,
            limit=20,
            cursor=None,
            application_id=None,
            current_user=current_user,
            db=db,
        )

    assert "messages" in data
    assert len(data["messages"]) == 1
    msg_data = data["messages"][0]
    attachments_out = msg_data["attachments"]

    video_att = next(
        (a for a in attachments_out if a["attachment_type"] == "video"), None
    )
    thumb_att = next(
        (a for a in attachments_out
         if a["attachment_type"] == "image"
         and (a.get("meta") or {}).get("role") == "thumbnail"),
        None,
    )
    assert video_att is not None, "video attachment missing in response"
    assert thumb_att is not None, "thumbnail image attachment missing in response"

    # 视频 url 必须是 signed_url_manager 生成的 /api/private-file 链接
    assert video_att["url"], "video attachment url must be populated"
    assert "/api/private-file" in video_att["url"], (
        f"video url should be a signed /api/private-file URL, got {video_att['url']}"
    )

    # 缩略图 url 必须走 /api/private-image (image 分支行为不变)
    assert thumb_att["url"], "thumbnail image url must be populated"
    assert "/api/private-image" in thumb_att["url"], (
        f"thumbnail url should be a private-image URL, got {thumb_att['url']}"
    )

    # meta 透传
    assert video_att["meta"]["duration"] == 28
    assert thumb_att["meta"]["role"] == "thumbnail"


@pytest.mark.asyncio
async def test_file_attachment_gets_signed_url():
    """PDF 消息的 file attachment 也要带签名 URL, 并透传 meta(original_filename 等)。"""
    from app.task_chat_routes import get_task_messages

    task = _make_task(task_id=11, poster_id="u_poster2", taker_id="u_taker2")
    sender = _make_user(user_id="u_poster2", name="Poster2")
    msg = _make_message(
        msg_id=2001,
        sender_id="u_poster2",
        task_id=11,
        content="[文件:report.pdf]",
    )
    pdf_blob = "u_poster2_1700000000_abcdef14.pdf"
    atts = [
        _make_attachment(
            att_id=601,
            message_id=2001,
            attachment_type="file",
            blob_id=pdf_blob,
            meta='{"original_filename":"report.pdf","content_type":"application/pdf","size":12345}',
        )
    ]

    db = _build_db_with(task=task, messages=[msg], users=[sender], attachments=atts)
    current_user = _make_user(user_id="u_poster2", name="Poster2")

    with patch(
        "app.signed_url.signed_url_manager.generate_signed_url",
        return_value="http://example.com/api/private-file?file=files/x.pdf&user=u_poster2&sig=fake",
    ):
        data = await get_task_messages(
            task_id=11,
            limit=20,
            cursor=None,
            application_id=None,
            current_user=current_user,
            db=db,
        )

    assert len(data["messages"]) == 1
    file_att = next(
        (a for a in data["messages"][0]["attachments"]
         if a["attachment_type"] == "file"),
        None,
    )
    assert file_att is not None
    assert file_att["url"], "file attachment url must be populated"
    assert "/api/private-file" in file_att["url"], (
        f"file url should be /api/private-file URL, got {file_att['url']}"
    )
    # meta 透传
    assert file_att["meta"]["original_filename"] == "report.pdf"
    assert file_att["meta"]["content_type"] == "application/pdf"
    assert file_att["meta"]["size"] == 12345

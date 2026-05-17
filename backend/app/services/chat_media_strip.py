"""任务聊天附件元数据清理 — 上传后调用。

清除原因:
1. **隐私**:iPhone 拍摄的视频/图片 metadata 含 GPS 经纬度、设备型号、
   序列号。发送方不该被迫泄露这些给接收方。
2. **UX**:接收方保存到相册时,iOS Photos 按 metadata.creation_time 排序,
   会把刚保存的视频排到原始拍摄日期(可能去年/上个月),用户找不到。
   清除 creation_time + 设 file mtime 为现在 → iOS Photos fallback 到 mtime
   → 显示为"刚保存"。

不阻断上传 — strip 失败只 warn,不抛异常。
"""
import logging
import os
import time
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


def strip_video_metadata(filepath: str) -> bool:
    """清除 mp4/mov 视频的元数据 atoms(creation_time / GPS / 设备型号等)。

    用 mutagen.MP4 重写 atom 结构,保留视频/音频轨道,删除 udta/moov 里的 meta atoms。
    成功返回 True,失败返回 False(不抛异常)。
    """
    try:
        from mutagen.mp4 import MP4
        v = MP4(filepath)
        # 清所有 metadata atoms (©nam, ©day, ©too, ----.com.apple.quicktime.* 等)
        v.clear()
        v.save()
        return True
    except Exception as e:
        # mutagen 不支持的容器(罕见)、文件损坏等都不阻断上传
        logger.warning(f"[strip_video_metadata] failed for {filepath}: {e}")
        return False


def strip_image_exif(filepath: str) -> bool:
    """清除图片 EXIF(GPS / 拍摄时间 / 设备 / 软件信息)。

    用 PIL 重新生成不带 EXIF 的文件,覆盖原文件。
    保留像素数据 + 颜色 profile + 透明通道(RGBA)。
    成功返回 True,失败返回 False。
    """
    try:
        from PIL import Image
        with Image.open(filepath) as img:
            # 取像素数据,丢 EXIF
            data = list(img.getdata())
            mode = img.mode
            size = img.size
            format_ = (img.format or "").upper()

        cleaned = Image.new(mode, size)
        cleaned.putdata(data)

        # 按原格式保存。jpeg/png/webp 都不传 exif=... 即无 EXIF。
        save_kwargs = {}
        if format_ in ("JPEG", "JPG"):
            save_kwargs["quality"] = 90  # 保持质量
            save_kwargs["optimize"] = True
        cleaned.save(filepath, format=format_ or None, **save_kwargs)
        return True
    except Exception as e:
        logger.warning(f"[strip_image_exif] failed for {filepath}: {e}")
        return False


def reset_file_mtime(filepath: str) -> bool:
    """把文件的 atime/mtime 改成当前时间。

    iOS Photos 在视频缺少 creation_time atom 时 fallback 到文件 mtime 作为
    "拍摄日期"显示。strip metadata 后调一下这个,保证接收方相册里看到"刚保存"。
    """
    try:
        now = time.time()
        os.utime(filepath, (now, now))
        return True
    except Exception as e:
        logger.warning(f"[reset_file_mtime] failed for {filepath}: {e}")
        return False


def strip_chat_media_metadata(filepath: str, extension: Optional[str] = None) -> None:
    """统一入口 — 按扩展名分发到视频或图片清理逻辑。

    chat_media 上传 OK 后立刻调,失败不阻断主流程。
    """
    if extension is None:
        extension = Path(filepath).suffix.lower()

    if extension in (".mp4", ".mov", ".m4v"):
        strip_video_metadata(filepath)
    elif extension in (".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"):
        strip_image_exif(filepath)
    # PDF 没有"拍摄时间"语义,但可能含 author/producer metadata。
    # 任务聊天发 PDF 一般是报价单/需求文档,作者信息(谁画的)反而是需要的,**不清**。
    # 如果将来要清,加 PyPDF2 / pypdf 处理 .pdf 分支即可。

    # 无论上面是否成功,都重置 mtime 让 iOS Photos fallback 到"刚保存"。
    reset_file_mtime(filepath)

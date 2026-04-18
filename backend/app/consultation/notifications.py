"""
咨询通知双语模板。

所有咨询相关的系统消息文案在此集中,供路由/scheduled tasks 调用。
返回 dict,content_zh 写入目标表的主 content 字段;
content_en 按表不同处理: `notifications` 表有 content_en 列直接写入,
`messages` 表无此列,需包装进 meta JSON (例如 meta["content_en"] = ...)。

当前涵盖: consultation_submitted / consultation_closed / consultation_stale_auto_closed。

待扩展 (tech debt):
- 议价/报价/正式申请/批准/拒绝阶段的通知(expert_consultation_routes 和 task_chat_routes 仍用 inline content_zh/en)
- task_chat_routes 基于 task_title 而非 service_name 的并行语义,需独立模板家族或扩展现有模板参数
"""
from typing import TypedDict


class Bilingual(TypedDict):
    content_zh: str
    content_en: str


def consultation_submitted(*, applicant_name: str, service_name: str) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」对服务「{service_name}」发起了新咨询",
        "content_en": f'"{applicant_name}" started a new consultation for "{service_name}"',
    }


def consultation_closed() -> Bilingual:
    return {
        "content_zh": "咨询已关闭",
        "content_en": "Consultation closed.",
    }


def consultation_stale_auto_closed(*, days: int) -> Bilingual:
    return {
        "content_zh": f"咨询已自动关闭({days} 天未活跃)",
        "content_en": f"Consultation auto-closed after {days} days of inactivity.",
    }

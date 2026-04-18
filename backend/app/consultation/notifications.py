"""
咨询通知双语模板。

所有咨询相关的系统消息文案在此集中,供路由/scheduled tasks 调用。
返回 dict,content_zh 写入目标表的主 content 字段;
content_en 按表不同处理: `notifications` 表有 content_en 列直接写入,
`messages` 表无此列,需包装进 meta JSON (例如 meta["content_en"] = ...)。

涵盖两个语义家族:
- **service 家族** (expert_consultation_routes / flea_market_routes):
  `consultation_submitted`(基于 service_name)、`consultation_closed`、
  `consultation_stale_auto_closed`
- **task 家族** (task_chat_routes 基于 task_title):
  `task_consultation_submitted` / `consultation_negotiation_accepted` /
  `consultation_negotiation_rejected` / `consultation_counter_offer` /
  `consultation_formal_apply_submitted` / `consultation_promoted_to_formal` /
  `consultation_closed_by_user`
"""
from typing import Optional, TypedDict


class Bilingual(TypedDict):
    content_zh: str
    content_en: str


# ==================== service 家族 ====================


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


# ==================== task 家族 ====================


def task_consultation_submitted(*, user_name: str, task_title: str) -> Bilingual:
    return {
        "content_zh": f"{user_name} 想咨询您的任务「{task_title}」",
        "content_en": f'{user_name} wants to consult about your task "{task_title}"',
    }


def consultation_negotiation_accepted(
    *, user_name: str, currency: str, price: float
) -> Bilingual:
    return {
        "content_zh": f"{user_name} 接受了报价 {currency} {price:.2f}",
        "content_en": f"{user_name} accepted the price {currency} {price:.2f}",
    }


def consultation_negotiation_rejected(*, user_name: str) -> Bilingual:
    return {
        "content_zh": f"{user_name} 拒绝了当前报价",
        "content_en": f"{user_name} rejected the current price",
    }


def consultation_counter_offer(
    *, user_name: str, currency: str, price: float
) -> Bilingual:
    return {
        "content_zh": f"{user_name} 提出还价 {currency} {price:.2f}",
        "content_en": f"{user_name} counter-offered {currency} {price:.2f}",
    }


def consultation_formal_apply_submitted(
    *, user_name: str, price_info: Optional[str] = None
) -> Bilingual:
    """消息落在**原任务**上:用户通过咨询提交了正式申请。"""
    suffix_zh = price_info or ""
    suffix_en = price_info or ""
    return {
        "content_zh": f"{user_name} 通过咨询提交了正式申请{suffix_zh}",
        "content_en": f"{user_name} submitted formal application via consultation{suffix_en}",
    }


def consultation_promoted_to_formal(
    *, user_name: str, price_info: Optional[str] = None
) -> Bilingual:
    """消息落在**咨询占位任务**上:用户已将咨询转为正式申请。"""
    suffix_zh = price_info or ""
    suffix_en = price_info or ""
    return {
        "content_zh": f"{user_name} 已将咨询转为正式申请{suffix_zh}",
        "content_en": f"{user_name} converted consultation to formal application{suffix_en}",
    }


def consultation_closed_by_user(*, user_name: str) -> Bilingual:
    return {
        "content_zh": f"{user_name} 关闭了咨询",
        "content_en": f"{user_name} closed the consultation",
    }

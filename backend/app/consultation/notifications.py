"""
咨询通知双语模板。

所有咨询相关的系统消息文案在此集中,供路由/scheduled tasks 调用。
返回 dict,字段与 messages 表 content_zh / content_en 对齐。
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


def consultation_negotiated(
    *, applicant_name: str, service_name: str, price: int
) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」对服务「{service_name}」议价,出价 {price}",
        "content_en": f'"{applicant_name}" negotiated price {price} for "{service_name}"',
    }


def consultation_quoted(
    *, expert_name: str, service_name: str, price: int
) -> Bilingual:
    return {
        "content_zh": f"专家「{expert_name}」对服务「{service_name}」给出报价 {price}",
        "content_en": f'Expert "{expert_name}" quoted {price} for "{service_name}"',
    }


def consultation_formally_applied(
    *, applicant_name: str, service_name: str
) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」正式申请服务「{service_name}」",
        "content_en": f'"{applicant_name}" submitted a formal application for "{service_name}"',
    }


def consultation_approved(*, service_name: str, price: int) -> Bilingual:
    return {
        "content_zh": f"咨询已批准,服务「{service_name}」成交价 {price},请完成支付",
        "content_en": f'Consultation approved. Service "{service_name}" agreed at {price}. Please complete payment.',
    }


def consultation_rejected(*, service_name: str) -> Bilingual:
    return {
        "content_zh": f"咨询被拒绝,服务「{service_name}」",
        "content_en": f'Consultation for "{service_name}" was rejected.',
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

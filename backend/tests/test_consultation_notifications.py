"""咨询通知模板测试"""
from app.consultation.notifications import (
    consultation_closed,
    consultation_closed_by_user,
    consultation_counter_offer,
    consultation_formal_apply_submitted,
    consultation_negotiation_accepted,
    consultation_negotiation_rejected,
    consultation_promoted_to_formal,
    consultation_stale_auto_closed,
    consultation_submitted,
    task_consultation_submitted,
)


def test_submitted_uses_correct_quotes():
    msg = consultation_submitted(applicant_name="Alice", service_name="翻译")
    assert "Alice" in msg["content_zh"]
    assert "翻译" in msg["content_zh"]
    # 英文文案应使用标准英文双引号,不用中文全角
    assert "「" not in msg["content_en"]
    assert "」" not in msg["content_en"]
    assert "Alice" in msg["content_en"]


def test_task_consultation_submitted_uses_task_title():
    msg = task_consultation_submitted(user_name="Bob", task_title="搬家")
    assert "Bob" in msg["content_zh"] and "搬家" in msg["content_zh"]
    assert "Bob" in msg["content_en"] and "搬家" in msg["content_en"]
    # English should use standard double quotes around task name
    assert "「" not in msg["content_en"]


def test_negotiation_accepted_includes_price():
    msg = consultation_negotiation_accepted(user_name="Alice", currency="GBP", price=123.45)
    assert "123.45" in msg["content_zh"]
    assert "GBP" in msg["content_zh"]
    assert "123.45" in msg["content_en"]


def test_counter_offer_includes_price():
    msg = consultation_counter_offer(user_name="Bob", currency="GBP", price=99.99)
    assert "99.99" in msg["content_zh"]
    assert "99.99" in msg["content_en"]


def test_formal_apply_with_price_info():
    msg = consultation_formal_apply_submitted(
        user_name="Carol", price_info="，报价 GBP 500.00"
    )
    assert "Carol" in msg["content_zh"]
    assert "GBP 500.00" in msg["content_zh"]


def test_formal_apply_without_price_info():
    msg = consultation_formal_apply_submitted(user_name="Carol")
    assert "Carol" in msg["content_zh"]
    assert msg["content_zh"].endswith("提交了正式申请")


def test_promoted_to_formal_differs_from_submitted():
    """promoted_to_formal 用在占位任务上,submitted 用在原任务上 — 文案应不同。"""
    submitted = consultation_formal_apply_submitted(user_name="x")
    promoted = consultation_promoted_to_formal(user_name="x")
    assert submitted["content_zh"] != promoted["content_zh"]


def test_closed_by_user_includes_user_name():
    msg = consultation_closed_by_user(user_name="Alice")
    assert "Alice" in msg["content_zh"]
    assert "关闭" in msg["content_zh"]


def test_all_templates_return_dict_with_zh_en_keys():
    samples = [
        consultation_submitted(applicant_name="x", service_name="y"),
        consultation_closed(),
        consultation_stale_auto_closed(days=14),
        task_consultation_submitted(user_name="x", task_title="y"),
        consultation_negotiation_accepted(user_name="x", currency="GBP", price=1.0),
        consultation_negotiation_rejected(user_name="x"),
        consultation_counter_offer(user_name="x", currency="GBP", price=1.0),
        consultation_formal_apply_submitted(user_name="x"),
        consultation_promoted_to_formal(user_name="x", price_info="，报价 GBP 1.00"),
        consultation_closed_by_user(user_name="x"),
    ]
    for m in samples:
        assert set(m.keys()) == {"content_zh", "content_en"}
        assert isinstance(m["content_zh"], str) and m["content_zh"]
        assert isinstance(m["content_en"], str) and m["content_en"]

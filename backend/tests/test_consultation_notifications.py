"""咨询通知模板测试"""
from app.consultation.notifications import (
    consultation_closed,
    consultation_stale_auto_closed,
    consultation_submitted,
    task_closed_by_user,
    task_consultation_submitted,
    task_counter_offer,
    task_formal_apply_submitted,
    task_negotiation_accepted,
    task_negotiation_rejected,
    task_notif_counter_offer,
    task_notif_price_accepted,
    task_notif_price_rejected,
    task_promoted_to_formal,
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
    msg = task_negotiation_accepted(user_name="Alice", currency="GBP", price=123.45)
    assert "123.45" in msg["content_zh"]
    assert "GBP" in msg["content_zh"]
    assert "123.45" in msg["content_en"]
    assert "GBP" in msg["content_en"]  # M4: 同时断言英文


def test_negotiation_rejected_content():
    """M3: 断言拒绝文案不包含价格且两 locale 有意义。"""
    msg = task_negotiation_rejected(user_name="Alice")
    assert "Alice" in msg["content_zh"]
    assert "拒绝" in msg["content_zh"]
    assert "Alice" in msg["content_en"]
    assert "rejected" in msg["content_en"]
    # 负面断言:拒绝消息不应包含金额/货币
    for field in (msg["content_zh"], msg["content_en"]):
        assert "GBP" not in field
        assert "0.00" not in field


def test_counter_offer_includes_price():
    msg = task_counter_offer(user_name="Bob", currency="GBP", price=99.99)
    assert "99.99" in msg["content_zh"]
    assert "99.99" in msg["content_en"]


def test_formal_apply_with_price_info():
    msg = task_formal_apply_submitted(
        user_name="Carol", price_info="，报价 GBP 500.00"
    )
    assert "Carol" in msg["content_zh"]
    assert "GBP 500.00" in msg["content_zh"]


def test_formal_apply_without_price_info():
    msg = task_formal_apply_submitted(user_name="Carol")
    assert "Carol" in msg["content_zh"]
    assert msg["content_zh"].endswith("提交了正式申请")


def test_promoted_to_formal_differs_from_submitted():
    """promoted_to_formal 用在占位任务上,submitted 用在原任务上 — 文案应不同。"""
    submitted = task_formal_apply_submitted(user_name="x")
    promoted = task_promoted_to_formal(user_name="x")
    assert submitted["content_zh"] != promoted["content_zh"]


def test_closed_by_user_includes_user_name():
    msg = task_closed_by_user(user_name="Alice")
    assert "Alice" in msg["content_zh"]
    assert "关闭" in msg["content_zh"]


def test_notif_price_accepted_has_title_and_body():
    notif = task_notif_price_accepted(user_name="Alice", task_title="搬家")
    assert set(notif.keys()) == {"title_zh", "title_en", "body_zh", "body_en"}
    assert "Alice" in notif["body_zh"]
    assert "搬家" in notif["body_zh"]
    assert "Alice" in notif["body_en"]
    assert notif["title_zh"] and notif["title_en"]


def test_notif_price_rejected_has_title_and_body():
    notif = task_notif_price_rejected(user_name="Bob", task_title="翻译")
    assert "Bob" in notif["body_zh"]
    assert "翻译" in notif["body_zh"]
    assert "rejected" in notif["body_en"].lower()


def test_notif_counter_offer_includes_price():
    notif = task_notif_counter_offer(
        user_name="Carol", task_title="搬家", currency="GBP", price=250.50
    )
    assert "250.50" in notif["body_zh"]
    assert "GBP" in notif["body_zh"]
    assert "250.50" in notif["body_en"]
    assert "GBP" in notif["body_en"]


def test_all_templates_return_dict_with_zh_en_keys():
    samples = [
        consultation_submitted(applicant_name="x", service_name="y"),
        consultation_closed(),
        consultation_stale_auto_closed(days=14),
        task_consultation_submitted(user_name="x", task_title="y"),
        task_negotiation_accepted(user_name="x", currency="GBP", price=1.0),
        task_negotiation_rejected(user_name="x"),
        task_counter_offer(user_name="x", currency="GBP", price=1.0),
        task_formal_apply_submitted(user_name="x"),
        task_promoted_to_formal(user_name="x", price_info="，报价 GBP 1.00"),
        task_closed_by_user(user_name="x"),
    ]
    for m in samples:
        assert set(m.keys()) == {"content_zh", "content_en"}
        assert isinstance(m["content_zh"], str) and m["content_zh"]
        assert isinstance(m["content_en"], str) and m["content_en"]

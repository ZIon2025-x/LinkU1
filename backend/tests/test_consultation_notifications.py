"""咨询通知模板测试"""
from app.consultation.notifications import (
    consultation_submitted,
    consultation_closed,
    consultation_stale_auto_closed,
)


def test_submitted_uses_correct_quotes():
    msg = consultation_submitted(applicant_name="Alice", service_name="翻译")
    assert "Alice" in msg["content_zh"]
    assert "翻译" in msg["content_zh"]
    # 英文文案应使用标准英文双引号,不用中文全角
    assert "「" not in msg["content_en"]
    assert "」" not in msg["content_en"]
    assert "Alice" in msg["content_en"]


def test_all_templates_return_dict_with_zh_en_keys():
    samples = [
        consultation_submitted(applicant_name="x", service_name="y"),
        consultation_closed(),
        consultation_stale_auto_closed(days=14),
    ]
    for m in samples:
        assert set(m.keys()) == {"content_zh", "content_en"}
        assert isinstance(m["content_zh"], str) and m["content_zh"]
        assert isinstance(m["content_en"], str) and m["content_en"]

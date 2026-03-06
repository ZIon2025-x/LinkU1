"""
Tests for the content_filter package:
- TextNormalizer
- ContactDetector
"""

import pytest

from app.content_filter.text_normalizer import TextNormalizer
from app.content_filter.contact_detector import ContactDetector, ContactResult


# =============================================================================
# TextNormalizer Tests
# =============================================================================

class TestTextNormalizer:
    """Tests for TextNormalizer."""

    def setup_method(self):
        self.normalizer = TextNormalizer()

    def test_fullwidth_to_halfwidth(self):
        """NFKC normalization converts fullwidth chars to halfwidth."""
        # Fullwidth "ABC123" -> "ABC123"
        result = self.normalizer.normalize("\uff21\uff22\uff23\uff11\uff12\uff13")
        assert result == "ABC123"

    def test_chinese_numerals(self):
        """Chinese digit characters are converted to Arabic digits."""
        result = self.normalizer.normalize("零一二三四五六七八九")
        assert result == "0123456789"
        # Also test 〇
        result2 = self.normalizer.normalize("〇")
        assert result2 == "0"
        # Uppercase financial digits
        result3 = self.normalizer.normalize("壹贰叁肆伍陆柒捌玖")
        assert result3 == "123456789"

    def test_strip_interference_symbols(self):
        """Decorative symbols inserted to break keywords are removed."""
        result = self.normalizer.normalize("赌☆博")
        assert result == "赌博"

    def test_strip_zero_width_chars(self):
        """Zero-width characters are stripped."""
        # Insert zero-width space between chars
        result = self.normalizer.normalize("赌\u200b博")
        assert result == "赌博"
        # Zero-width joiner
        result2 = self.normalizer.normalize("测\u200d试")
        assert result2 == "测试"

    def test_homophone_replacement(self):
        """Homophone mapping replaces variants with canonical forms."""
        homophones = {
            "黄赌毒": "黄赌毒",
            "赌博": "赌博",
            "du博": "赌博",
            "渡博": "赌博",
        }
        normalizer = TextNormalizer(homophones=homophones)
        result = normalizer.normalize("渡博网站")
        assert "赌博" in result

    def test_merge_spaces(self):
        """Multiple spaces are merged into one, leading/trailing stripped."""
        result = self.normalizer.normalize("  hello   world  ")
        assert result == "hello world"

    def test_empty_and_none(self):
        """Empty string and None both return empty string."""
        assert self.normalizer.normalize("") == ""
        assert self.normalizer.normalize(None) == ""

    def test_normal_text_unchanged(self):
        """Normal Chinese and English text passes through without alteration."""
        cn = "你好世界"
        assert self.normalizer.normalize(cn) == cn

        en = "hello world"
        assert self.normalizer.normalize(en) == en

        mixed = "Link2Ur 技能互助"
        assert self.normalizer.normalize(mixed) == mixed


# =============================================================================
# ContactDetector Tests
# =============================================================================

class TestContactDetector:
    """Tests for ContactDetector."""

    def setup_method(self):
        self.detector = ContactDetector()

    def test_detect_phone_number(self):
        """Detects a standard China mobile number."""
        result = self.detector.detect("请联系我13812345678谢谢")
        assert result.has_contact is True
        assert any("13812345678" in m for m in result.matched_text)

    def test_detect_phone_with_spaces(self):
        """Detects phone numbers with space/dash separators."""
        result = self.detector.detect("电话 138 1234 5678")
        assert result.has_contact is True
        assert len(result.matched_text) > 0

    def test_detect_wechat_variants(self):
        """Detects WeChat ID with various keyword prefixes."""
        prefixes = ["微信", "wx", "vx", "wechat", "V信", "weixin", "威信", "薇芯"]
        for prefix in prefixes:
            text = f"加我{prefix}:abc12345"
            result = self.detector.detect(text)
            assert result.has_contact is True, f"Failed to detect WeChat with prefix '{prefix}'"

    def test_detect_qq(self):
        """Detects QQ numbers."""
        result = self.detector.detect("我的QQ:123456789")
        assert result.has_contact is True
        assert any("QQ:123456789" in m for m in result.matched_text)

        result2 = self.detector.detect("扣扣 12345678")
        assert result2.has_contact is True

    def test_detect_email(self):
        """Detects email addresses."""
        result = self.detector.detect("发邮件到test@example.com")
        assert result.has_contact is True
        assert "test@example.com" in result.matched_text

    def test_detect_url(self):
        """Detects URLs."""
        result = self.detector.detect("访问 https://www.example.com/page 查看")
        assert result.has_contact is True
        assert any("https://www.example.com/page" in m for m in result.matched_text)

    def test_mask_phone(self):
        """Phone numbers are replaced with *** in masked_text."""
        result = self.detector.detect("电话13812345678")
        assert "***" in result.masked_text
        assert "13812345678" not in result.masked_text

    def test_no_false_positive_on_normal_text(self):
        """Normal text without contact info returns no match."""
        result = self.detector.detect("今天天气真好，我想出去走走")
        assert result.has_contact is False
        assert len(result.matched_text) == 0

    def test_no_false_positive_on_short_numbers(self):
        """Short numbers like prices should not trigger phone detection."""
        result = self.detector.detect("价格2000元")
        assert result.has_contact is False

        result2 = self.detector.detect("订单号123456")
        assert result2.has_contact is False

    def test_empty_input(self):
        """Empty/None input returns ContactResult with has_contact=False."""
        result = self.detector.detect("")
        assert result.has_contact is False

        result2 = self.detector.detect(None)
        assert result2.has_contact is False

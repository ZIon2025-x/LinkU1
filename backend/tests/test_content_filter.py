"""
Tests for the content_filter package:
- TextNormalizer
- ContactDetector
- KeywordMatcher
- ContentFilter (orchestrator)
"""

import pytest

from app.content_filter.text_normalizer import TextNormalizer
from app.content_filter.contact_detector import ContactDetector, ContactResult
from app.content_filter.keyword_matcher import KeywordMatcher, MatchResult
from app.content_filter.content_filter import ContentFilter, FilterResult


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


# =============================================================================
# KeywordMatcher Tests
# =============================================================================

class TestKeywordMatcher:
    """Tests for KeywordMatcher."""

    def _make_keywords(self):
        return [
            {"word": "赌博", "category": "gambling", "level": "review"},
            {"word": "色情", "category": "porn", "level": "review"},
            {"word": "代购", "category": "commerce", "level": "mask"},
            {"word": "优惠券", "category": "commerce", "level": "pass"},
        ]

    def test_match_single_keyword(self):
        """A single keyword is detected correctly."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        result = matcher.match("这个赌博网站很危险")
        assert result.has_match is True
        assert len(result.matches) == 1
        assert result.matches[0]["word"] == "赌博"

    def test_match_multiple_keywords(self):
        """Multiple keywords in the same text are all detected."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        result = matcher.match("赌博和色情内容都应该被过滤")
        assert result.has_match is True
        assert len(result.matches) == 2
        words = {m["word"] for m in result.matches}
        assert words == {"赌博", "色情"}

    def test_no_match_clean_text(self):
        """Clean text returns no match."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        result = matcher.match("今天天气很好")
        assert result.has_match is False
        assert len(result.matches) == 0
        assert result.strictest_level == "pass"

    def test_strictest_level(self):
        """The strictest_level reflects the highest severity match."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        # Only mask-level match
        result = matcher.match("这个代购很便宜")
        assert result.strictest_level == "mask"

        # Both mask and review
        result2 = matcher.match("代购赌博网站")
        assert result2.strictest_level == "review"

    def test_empty_input(self):
        """Empty/None input returns default MatchResult."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        result = matcher.match("")
        assert result.has_match is False

        result2 = matcher.match(None)
        assert result2.has_match is False

    def test_rebuild_automaton(self):
        """Rebuilding automaton with new keywords replaces old ones."""
        matcher = KeywordMatcher(keywords=[
            {"word": "旧词", "category": "old", "level": "mask"},
        ])
        assert matcher.match("旧词出现").has_match is True
        assert matcher.match("新词出现").has_match is False

        # Rebuild with new keywords
        matcher.rebuild([
            {"word": "新词", "category": "new", "level": "review"},
        ])
        assert matcher.match("旧词出现").has_match is False
        assert matcher.match("新词出现").has_match is True

    def test_categories(self):
        """Matched keywords include their category."""
        matcher = KeywordMatcher(keywords=self._make_keywords())
        result = matcher.match("赌博和代购")
        assert result.has_match is True
        categories = {m["category"] for m in result.matches}
        assert "gambling" in categories
        assert "commerce" in categories


# =============================================================================
# ContentFilter (Orchestrator) Tests
# =============================================================================

class TestContentFilter:
    """Tests for ContentFilter orchestrator."""

    def setup_method(self):
        keywords = [
            {"word": "代理", "category": "agent", "level": "review"},
            {"word": "赌博", "category": "gambling", "level": "review"},
        ]
        homophones = {"威信": "微信"}
        self.filter = ContentFilter(keywords=keywords, homophones=homophones)

    def test_clean_text_passes(self):
        result = self.filter.check("帮忙搬家，价格面议")
        assert result.action == "pass"

    def test_contact_info_masked(self):
        result = self.filter.check("加我微信abc123")
        assert result.action == "mask"
        assert "***" in result.cleaned_text

    def test_keyword_triggers_review(self):
        result = self.filter.check("网上赌博代理招人")
        assert result.action == "review"
        assert len(result.matched_words) >= 1

    def test_contact_plus_keyword_uses_strictest(self):
        result = self.filter.check("赌博网站加我微信abc123")
        assert result.action == "review"  # review > mask

    def test_variant_detected_via_normalizer(self):
        result = self.filter.check("找个代☆理帮忙赌☆博")
        assert result.action == "review"

    def test_homophone_variant(self):
        result = self.filter.check("加我威信abc123")
        assert result.action == "mask"

    def test_phone_masked(self):
        result = self.filter.check("电话13800001234")
        assert result.action == "mask"
        assert "13800001234" not in result.cleaned_text

    def test_empty_input(self):
        result = self.filter.check("")
        assert result.action == "pass"
        result = self.filter.check(None)
        assert result.action == "pass"

    def test_check_multiple_fields(self):
        results = self.filter.check_fields({
            "title": "帮忙搬家",
            "description": "加我微信abc123详聊"
        })
        assert results["title"].action == "pass"
        assert results["description"].action == "mask"

"""
Tests for the content_filter package:
- TextNormalizer
"""

import pytest

from app.content_filter.text_normalizer import TextNormalizer


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

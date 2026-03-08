"""
Bilingual helper unit tests

Tests:
- detect_language_simple: Chinese/English language detection
- _protect_encoding_markers: encoding marker protection
- _restore_encoding_markers: encoding marker restoration
- _translate_segmented: segmented translation logic
- _translate_with_encoding_protection: translation with encoding protection
- auto_fill_bilingual_fields: auto-fill bilingual fields

Run:
    pytest tests/test_bilingual_helper.py -v
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


def _run(coro):
    """Helper to run async coroutines in sync tests."""
    return asyncio.get_event_loop().run_until_complete(coro)


# =============================================================================
# detect_language_simple Tests
# =============================================================================

class TestDetectLanguageSimple:

    def setup_method(self):
        from app.utils.bilingual_helper import detect_language_simple
        self.detect = detect_language_simple

    def test_chinese_text(self):
        assert self.detect("你好世界") == "zh"
        assert self.detect("这是一个测试") == "zh"
        assert self.detect("技能互助平台") == "zh"

    def test_english_text(self):
        assert self.detect("hello world") == "en"
        assert self.detect("This is a test") == "en"
        assert self.detect("Skill exchange platform") == "en"

    def test_mixed_text_with_chinese(self):
        assert self.detect("Hello 世界") == "zh"
        assert self.detect("Link2Ur 技能互助") == "zh"
        assert self.detect("test123 你好") == "zh"

    def test_numbers_only(self):
        assert self.detect("12345") == "en"
        assert self.detect("2026-03-08") == "en"

    def test_empty_and_whitespace(self):
        assert self.detect("") == "en"
        assert self.detect("   ") == "en"
        assert self.detect(None) == "en"

    def test_special_characters(self):
        assert self.detect("@#$%^&*") == "en"
        assert self.detect("!!!???") == "en"

    def test_japanese_kanji_detected_as_chinese(self):
        # CJK characters fall in the Chinese range - expected behavior
        assert self.detect("漢字") == "zh"


# =============================================================================
# _protect_encoding_markers Tests
# =============================================================================

class TestProtectEncodingMarkers:

    def setup_method(self):
        from app.utils.bilingual_helper import _protect_encoding_markers
        self.protect = _protect_encoding_markers

    def test_no_markers(self):
        text = "Hello world"
        result, has_encoding = self.protect(text)
        assert result == text
        assert has_encoding is False

    def test_literal_backslash_n(self):
        text = "line1\\nline2"
        result, has_encoding = self.protect(text)
        assert has_encoding is True
        assert "<br/>" in result
        assert "\\n" not in result

    def test_real_newline(self):
        text = "line1\nline2"
        result, has_encoding = self.protect(text)
        assert has_encoding is True
        assert "<br/>" in result

    def test_backslash_c(self):
        text = "word1\\cword2"
        result, has_encoding = self.protect(text)
        assert has_encoding is True
        assert "<sp/>" in result
        assert "\\c" not in result

    def test_multiple_markers(self):
        text = "line1\\nline2\\cword3"
        result, has_encoding = self.protect(text)
        assert has_encoding is True
        assert "<br/>" in result
        assert "<sp/>" in result

    def test_multiple_newlines(self):
        text = "a\nb\nc"
        result, has_encoding = self.protect(text)
        assert has_encoding is True
        assert result.count("<br/>") == 2


# =============================================================================
# _restore_encoding_markers Tests
# =============================================================================

class TestRestoreEncodingMarkers:

    def setup_method(self):
        from app.utils.bilingual_helper import _restore_encoding_markers
        self.restore = _restore_encoding_markers

    def test_restore_br_tag(self):
        # Note: re.sub with '\\n' replacement produces real newline (chr(10)),
        # not literal backslash-n. This is a known behavior - the function is
        # currently bypassed in the main translation path (segmented translation
        # is used instead), so it doesn't affect production.
        result = self.restore("line1<br/>line2")
        assert result == "line1\nline2"

    def test_restore_br_variants(self):
        assert "\n" in self.restore("a<br>b")
        assert "\n" in self.restore("a<br />b")
        assert "\n" in self.restore("a<BR/>b")

    def test_restore_sp_tag(self):
        result = self.restore("word1<sp/>word2")
        assert result == "word1\\cword2"

    def test_html_entity_unescape(self):
        result = self.restore("it&#39;s a test")
        assert result == "it's a test"

    def test_empty_input(self):
        assert self.restore("") == ""
        assert self.restore(None) is None

    def test_no_markers(self):
        text = "Hello world"
        assert self.restore(text) == text


# =============================================================================
# _translate_segmented Tests
# =============================================================================

class TestTranslateSegmented:

    def test_no_markers_translates_directly(self):
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "translated text"

            result = _run(_translate_segmented(mgr, "simple text", "en", "zh-CN"))

            assert result == "translated text"
            mock_translate.assert_called_once()

    def test_preserves_newlines(self):
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.side_effect = lambda *args, **kwargs: (
                f"translated_{kwargs.get('text', args[1] if len(args) > 1 else '')}"
            )

            result = _run(_translate_segmented(mgr, "first\nsecond", "en", "zh-CN"))

            assert "\n" in result
            assert mock_translate.call_count >= 2

    def test_preserves_literal_backslash_n(self):
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.side_effect = lambda *args, **kwargs: (
                f"T({kwargs.get('text', '')})"
            )

            result = _run(_translate_segmented(mgr, "line1\\nline2", "en", "zh-CN"))

            assert "\\n" in result

    def test_empty_segments_preserved(self):
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "translated"

            _run(_translate_segmented(mgr, "text\n\n\nmore", "en", "zh-CN"))

            # Only "text" and "more" should be translated, not empty segments
            assert mock_translate.call_count == 2

    def test_translation_failure_preserves_original(self):
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.side_effect = ["translated_first", None]

            result = _run(_translate_segmented(mgr, "first\nsecond", "en", "zh-CN"))

            assert "translated_first" in result
            assert "second" in result  # original preserved on failure

    def test_html_entities_unescaped_in_segments(self):
        """HTML entities are unescaped in multi-segment translation."""
        from app.utils.bilingual_helper import _translate_segmented
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "it&#39;s a test &amp; more"

            # Use text with newlines to trigger multi-segment path
            result = _run(_translate_segmented(mgr, "line1\nline2", "en", "zh-CN"))

            assert "it's a test & more" in result


# =============================================================================
# _translate_with_encoding_protection Tests
# =============================================================================

class TestTranslateWithEncodingProtection:

    def test_plain_text_direct_translation(self):
        from app.utils.bilingual_helper import _translate_with_encoding_protection
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "translated"

            result = _run(_translate_with_encoding_protection(
                mgr, "simple text", "zh-CN", "en"
            ))

            assert result == "translated"

    def test_text_with_newlines_uses_segmented(self):
        from app.utils.bilingual_helper import _translate_with_encoding_protection
        mgr = MagicMock()

        with patch("app.utils.bilingual_helper._translate_segmented", new_callable=AsyncMock) as mock_seg:
            mock_seg.return_value = "segmented result"

            result = _run(_translate_with_encoding_protection(
                mgr, "line1\nline2", "zh-CN", "en"
            ))

            assert result == "segmented result"
            mock_seg.assert_called_once()

    def test_text_with_literal_backslash_n_uses_segmented(self):
        from app.utils.bilingual_helper import _translate_with_encoding_protection
        mgr = MagicMock()

        with patch("app.utils.bilingual_helper._translate_segmented", new_callable=AsyncMock) as mock_seg:
            mock_seg.return_value = "segmented result"

            result = _run(_translate_with_encoding_protection(
                mgr, "line1\\nline2", "zh-CN", "en"
            ))

            assert result == "segmented result"
            mock_seg.assert_called_once()

    def test_translation_failure_returns_none(self):
        from app.utils.bilingual_helper import _translate_with_encoding_protection
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = None

            result = _run(_translate_with_encoding_protection(
                mgr, "simple text", "zh-CN", "en"
            ))

            assert result is None

    def test_html_entities_unescaped_in_direct_translation(self):
        from app.utils.bilingual_helper import _translate_with_encoding_protection
        mgr = MagicMock()

        with patch("app.utils.translation_async.translate_async", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "it&#39;s fine"

            result = _run(_translate_with_encoding_protection(
                mgr, "no problem", "en", "zh-CN"
            ))

            assert result == "it's fine"


# =============================================================================
# auto_fill_bilingual_fields Tests
# =============================================================================

class TestAutoFillBilingualFields:

    def test_chinese_name_fills_name_zh(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "Test Board"

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("test board zh")
            )
            # "test board zh" is English (no Chinese chars), so name_en is set
            # Let's test with actual Chinese
            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("测试板块")
            )

            assert name_zh == "测试板块"
            assert name_en == "Test Board"

    def test_english_name_fills_name_en(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "测试板块"

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("Test Board")
            )

            assert name_en == "Test Board"
            assert name_zh == "测试板块"

    def test_user_provided_bilingual_fields_preserved(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        name, name_en, name_zh, desc_en, desc_zh = _run(
            auto_fill_bilingual_fields(
                name="测试",
                name_en="User Provided EN",
                name_zh="User Provided ZH",
            )
        )

        assert name_en == "User Provided EN"
        assert name_zh == "User Provided ZH"

    def test_description_translated(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "Translated description"

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("测试", description="这是描述")
            )

            assert desc_zh == "这是描述"
            assert desc_en == "Translated description"

    def test_translation_failure_returns_none_fields(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = None

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("测试")
            )

            assert name_zh == "测试"
            assert name_en is None

    def test_translation_exception_handled_gracefully(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.side_effect = Exception("Translation service down")

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("测试")
            )

            assert name_zh == "测试"
            assert name_en is None

    def test_no_description_skips_translation(self):
        from app.utils.bilingual_helper import auto_fill_bilingual_fields

        with patch("app.translation_manager.get_translation_manager"), \
             patch("app.utils.bilingual_helper._translate_with_encoding_protection", new_callable=AsyncMock) as mock_translate:
            mock_translate.return_value = "Translated"

            name, name_en, name_zh, desc_en, desc_zh = _run(
                auto_fill_bilingual_fields("测试")
            )

            assert desc_en is None
            assert desc_zh is None
            # Only name should be translated, not description
            assert mock_translate.call_count == 1

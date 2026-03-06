"""
ContentFilter -- orchestrator that combines TextNormalizer, ContactDetector,
and KeywordMatcher into a unified content filtering pipeline.

Processing pipeline for check():
1. Contact detection on ORIGINAL text
2. Keyword matching on ORIGINAL text
3. Normalize text with TextNormalizer
4. Contact detection on NORMALIZED text (catches variants missed in original)
5. Keyword matching on NORMALIZED text (catches variants)
6. Combine results -- action = strictest of all (pass < mask < review)
7. cleaned_text = masked version of original text (contacts replaced with ***)
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .contact_detector import ContactDetector
from .keyword_matcher import KeywordMatcher
from .text_normalizer import TextNormalizer


# Action priority: higher number = stricter
_ACTION_PRIORITY = {
    "pass": 0,
    "mask": 1,
    "review": 2,
}


@dataclass
class FilterResult:
    """Result of content filtering."""
    action: str = "pass"         # pass / mask / review
    matched_words: List[Dict] = field(default_factory=list)
    cleaned_text: str = ""
    original_text: str = ""


class ContentFilter:
    """
    Orchestrator that combines TextNormalizer, ContactDetector, and KeywordMatcher
    into a single content filtering pipeline.
    """

    def __init__(
        self,
        keywords: Optional[List[Dict]] = None,
        homophones: Optional[Dict[str, str]] = None,
    ):
        self._normalizer = TextNormalizer(homophones=homophones)
        self._contact_detector = ContactDetector()
        self._keyword_matcher = KeywordMatcher(keywords=keywords)

    def update_keywords(self, keywords: List[Dict]) -> None:
        """Update the keyword list and rebuild the matcher automaton."""
        self._keyword_matcher.rebuild(keywords)

    def update_homophones(self, homophones: Dict[str, str]) -> None:
        """Update the homophone mapping used by the text normalizer."""
        self._normalizer.update_homophones(homophones)

    def check(self, text: Optional[str]) -> FilterResult:
        """
        Run the full content filtering pipeline on a single text.

        Returns FilterResult with action (pass/mask/review), matched_words,
        cleaned_text (contacts masked), and original_text.
        """
        if not text:
            return FilterResult(action="pass", cleaned_text=text or "", original_text=text or "")

        action_priority = _ACTION_PRIORITY["pass"]
        all_matched_words: List[Dict] = []
        seen_words = set()

        # --- Phase 1: Check ORIGINAL text ---

        # 1. Contact detection on original text
        contact_orig = self._contact_detector.detect(text)
        if contact_orig.has_contact:
            p = _ACTION_PRIORITY["mask"]
            if p > action_priority:
                action_priority = p

        # 2. Keyword matching on original text
        keyword_orig = self._keyword_matcher.match(text)
        if keyword_orig.has_match:
            for m in keyword_orig.matches:
                word = m["word"]
                if word not in seen_words:
                    seen_words.add(word)
                    all_matched_words.append(m)
            p = _ACTION_PRIORITY.get(keyword_orig.strictest_level, 0)
            if p > action_priority:
                action_priority = p

        # --- Phase 2: Check NORMALIZED text ---

        normalized = self._normalizer.normalize(text)

        # 3. Contact detection on normalized text
        contact_norm = self._contact_detector.detect(normalized)
        if contact_norm.has_contact:
            p = _ACTION_PRIORITY["mask"]
            if p > action_priority:
                action_priority = p

        # 4. Keyword matching on normalized text
        keyword_norm = self._keyword_matcher.match(normalized)
        if keyword_norm.has_match:
            for m in keyword_norm.matches:
                word = m["word"]
                if word not in seen_words:
                    seen_words.add(word)
                    all_matched_words.append(m)
            p = _ACTION_PRIORITY.get(keyword_norm.strictest_level, 0)
            if p > action_priority:
                action_priority = p

        # --- Determine final action ---
        action_map = {v: k for k, v in _ACTION_PRIORITY.items()}
        action = action_map.get(action_priority, "pass")

        # --- Build cleaned_text: mask contacts in original text ---
        cleaned_text = contact_orig.masked_text if contact_orig.has_contact else text

        return FilterResult(
            action=action,
            matched_words=all_matched_words,
            cleaned_text=cleaned_text,
            original_text=text,
        )

    def check_fields(self, fields: Dict[str, Optional[str]]) -> Dict[str, FilterResult]:
        """
        Run check() on each field in the dict.

        Args:
            fields: mapping of field name -> text content (None values are treated as empty).

        Returns:
            Dict mapping each field name to its FilterResult.
        """
        results: Dict[str, FilterResult] = {}
        for name, value in fields.items():
            results[name] = self.check(value)
        return results

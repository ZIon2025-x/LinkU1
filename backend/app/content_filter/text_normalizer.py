"""
TextNormalizer -- normalizes text to detect evasion variants.

Pipeline:
1. Remove zero-width chars
2. Fullwidth -> halfwidth (NFKC normalization)
3. Remove emoji and special symbols
4. Chinese digits -> Arabic digits
5. Uppercase Chinese financial digits -> Arabic digits
6. Homophone mapping replacement (longest match first)
7. Remove non-CJK non-alphanumeric interference chars
8. Merge / remove whitespace
"""

import re
import unicodedata
from typing import Dict, Optional


# Zero-width and invisible Unicode characters
_ZERO_WIDTH_RE = re.compile(
    "[\u200b\u200c\u200d\u200e\u200f"  # zero-width space / joiners / marks
    "\u2060\u2061\u2062\u2063\u2064"   # word joiner, invisible operators
    "\ufeff"                            # BOM / zero-width no-break space
    "\u00ad"                            # soft hyphen
    "\u034f"                            # combining grapheme joiner
    "\u061c"                            # Arabic letter mark
    "\u115f\u1160"                      # Hangul fillers
    "\u17b4\u17b5"                      # Khmer inherent vowels
    "\u180e"                            # Mongolian vowel separator
    "\uffa0"                            # halfwidth Hangul filler
    "]"
)

# Emoji pattern -- precise ranges to avoid catching fullwidth forms (U+FFxx)
_EMOJI_RE = re.compile(
    "["
    "\U0001f600-\U0001f64f"  # emoticons
    "\U0001f300-\U0001f5ff"  # misc symbols & pictographs
    "\U0001f680-\U0001f6ff"  # transport & map
    "\U0001f1e0-\U0001f1ff"  # flags
    "\U00002702-\U000027b0"  # dingbats
    "\U000024c2-\U000024ff"  # enclosed alphanumerics subset
    "\U0001f200-\U0001f251"  # enclosed ideographic supplement
    "\U0001f900-\U0001f9ff"  # supplemental symbols
    "\U0001fa00-\U0001fa6f"  # chess symbols
    "\U0001fa70-\U0001faff"  # symbols extended-A
    "\U00002600-\U000026ff"  # misc symbols (sun, stars, etc.)
    "\U0000fe00-\U0000fe0f"  # variation selectors
    "\U0000203c\U00002049"   # double exclamation, interrobang
    "]+"
)

# Chinese lowercase digits
_CN_DIGITS: Dict[str, str] = {
    "\u96f6": "0", "\u4e00": "1", "\u4e8c": "2", "\u4e09": "3",
    "\u56db": "4", "\u4e94": "5", "\u516d": "6", "\u4e03": "7",
    "\u516b": "8", "\u4e5d": "9", "\u3007": "0",
}

# Chinese uppercase (financial) digits
_CN_UPPER_DIGITS: Dict[str, str] = {
    "\u58f9": "1", "\u8d30": "2", "\u53c1": "3", "\u8086": "4",
    "\u4f0d": "5", "\u9646": "6", "\u67d2": "7", "\u634c": "8",
    "\u7396": "9",
}

# Interference characters: non-CJK, non-alphanumeric, non-space symbols
# We keep: CJK unified ideographs, letters, digits, spaces
# We remove everything else (decorative symbols, special punctuation inserted to break keywords)
_KEEP_RE = re.compile(
    r"["
    r"\u4e00-\u9fff"   # CJK Unified Ideographs
    r"\u3400-\u4dbf"   # CJK Extension A
    r"\uf900-\ufaff"   # CJK Compatibility Ideographs
    r"a-zA-Z0-9"       # ASCII alphanumeric
    r"\s"              # whitespace
    r"]"
)


class TextNormalizer:
    """Normalizes text to a canonical form for content filtering."""

    def __init__(self, homophones: Optional[Dict[str, str]] = None):
        self._homophones: Dict[str, str] = {}
        self._homo_keys_sorted: list = []
        if homophones:
            self.update_homophones(homophones)

    def update_homophones(self, homophones: Dict[str, str]) -> None:
        """Update the homophone mapping dictionary. Sorts keys by length descending for longest-match-first."""
        self._homophones.update(homophones)
        # Sort by length descending so longest match wins
        self._homo_keys_sorted = sorted(
            self._homophones.keys(), key=len, reverse=True
        )

    def normalize(self, text: Optional[str]) -> str:
        """Normalize input text through the full pipeline. Returns '' for None/empty input."""
        if not text:
            return ""

        s = text

        # 1. Remove zero-width characters
        s = _ZERO_WIDTH_RE.sub("", s)

        # 2. NFKC normalization (fullwidth -> halfwidth, compatibility decomposition)
        #    Done before emoji removal so fullwidth letters/digits are preserved
        s = unicodedata.normalize("NFKC", s)

        # 3. Remove emoji
        s = _EMOJI_RE.sub("", s)

        # 4. Chinese digits -> Arabic
        for ch, digit in _CN_DIGITS.items():
            s = s.replace(ch, digit)

        # 5. Chinese uppercase (financial) digits -> Arabic
        for ch, digit in _CN_UPPER_DIGITS.items():
            s = s.replace(ch, digit)

        # 6. Homophone replacement (longest match first)
        if self._homo_keys_sorted:
            s = self._apply_homophones(s)

        # 7. Remove interference characters (keep CJK, alphanumeric, whitespace)
        s = self._strip_interference(s)

        # 8. Merge whitespace and strip
        s = re.sub(r"\s+", " ", s).strip()

        return s

    def _apply_homophones(self, text: str) -> str:
        """Replace homophones using longest-match-first strategy."""
        result = []
        i = 0
        length = len(text)
        while i < length:
            matched = False
            for key in self._homo_keys_sorted:
                klen = len(key)
                if text[i:i + klen] == key:
                    result.append(self._homophones[key])
                    i += klen
                    matched = True
                    break
            if not matched:
                result.append(text[i])
                i += 1
        return "".join(result)

    def _strip_interference(self, text: str) -> str:
        """Remove characters that are not CJK, alphanumeric, or whitespace."""
        return "".join(ch for ch in text if _KEEP_RE.match(ch))

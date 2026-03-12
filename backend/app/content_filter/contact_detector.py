"""
ContactDetector -- detects and masks contact information in text.

Supported patterns:
- China mobile phone numbers: 1[3-9]X + 8 digits (with optional separators)
- UK mobile phone numbers: 07XX or +44 7XX (with optional separators)
- WeChat IDs: keyword prefix + alphanumeric ID
- QQ numbers: keyword prefix + 5-12 digits
- Email addresses
- URLs (http/https)
"""

import re
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ContactResult:
    """Result of contact detection."""
    has_contact: bool = False
    matched_text: List[str] = field(default_factory=list)
    masked_text: str = ""
    original_text: str = ""


# Separator pattern: optional spaces, dashes, or dots between digit groups
_SEP = r"[\s\-.]?"

# China mobile: 1[3-9]X followed by 8 more digits, with optional separators
# Use word boundary / lookbehind/lookahead to avoid matching inside longer numbers
_PHONE_CN_RE = re.compile(
    r"(?<!\d)"                   # not preceded by a digit
    r"1[3-9]\d" + _SEP +        # first 3 digits
    r"\d{4}" + _SEP +           # middle 4 digits
    r"\d{4}"                     # last 4 digits
    r"(?!\d)"                    # not followed by a digit
)

# UK mobile: 07XXX XXXXXX or +44 7XXX XXXXXX (with optional separators)
_PHONE_UK_RE = re.compile(
    r"(?<!\d)"
    r"(?:"
    r"(?:\+44[\s\-.]?7\d{3})"   # +44 7XXX international format
    r"|"
    r"(?:0044[\s\-.]?7\d{3})"   # 0044 7XXX international format
    r"|"
    r"(?:07\d{3})"              # 07XXX local format
    r")"
    + _SEP + r"\d{3}"           # middle 3 digits
    + _SEP + r"\d{3}"           # last 3 digits
    r"(?!\d)"
)

# WeChat: keyword + optional separator + ID (6-20 alphanumeric/underscore/dash)
_WECHAT_RE = re.compile(
    r"(?:微信|wx|vx|wechat|V信|weixin|威信|薇芯)"
    r"[:\s：]*"
    r"([a-zA-Z0-9_\-]{4,20})",
    re.IGNORECASE,
)

# QQ: keyword + optional separator + 5-12 digits
_QQ_RE = re.compile(
    r"(?:qq|QQ|扣扣|球球)"
    r"[:\s：]*"
    r"(\d{5,12})",
    re.IGNORECASE,
)

# Email
_EMAIL_RE = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"
)

# URL
_URL_RE = re.compile(
    r"https?://[^\s<>\"'）)）\]]+",
    re.IGNORECASE,
)

# All patterns in priority order
_ALL_PATTERNS = [
    _URL_RE,
    _EMAIL_RE,
    _PHONE_CN_RE,
    _PHONE_UK_RE,
    _WECHAT_RE,
    _QQ_RE,
]


class ContactDetector:
    """Detects and masks contact information in text."""

    def detect(self, text: Optional[str]) -> ContactResult:
        """
        Detect contact info in the given text.

        Returns a ContactResult with:
        - has_contact: whether any contact info was found
        - matched_text: list of matched strings
        - masked_text: text with matches replaced by ***
        - original_text: the input text
        """
        if not text:
            return ContactResult(has_contact=False)

        matched_text: List[str] = []
        masked = text

        for pattern in _ALL_PATTERNS:
            for m in pattern.finditer(text):
                full_match = m.group(0)
                if full_match not in matched_text:
                    matched_text.append(full_match)

        # Replace all matches in the masked text (use full pattern match)
        for pattern in _ALL_PATTERNS:
            masked = pattern.sub("***", masked)

        return ContactResult(
            has_contact=len(matched_text) > 0,
            matched_text=matched_text,
            masked_text=masked,
            original_text=text,
        )

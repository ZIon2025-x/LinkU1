# Content Filter & Review System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a rule-based content filtering system that auto-masks contact info and sends illegal/non-compliant content to a review queue for admin approval.

**Architecture:** A `ContentFilter` singleton with three layers: `TextNormalizer` (variant restoration), `ContactDetector` (regex-based), and `KeywordMatcher` (Aho-Corasick). The filter integrates into existing content submission endpoints. Admin manages keywords and reviews flagged content via new API endpoints. `pyahocorasick` is already in requirements.txt.

**Tech Stack:** Python/FastAPI, SQLAlchemy (async), Redis caching, pyahocorasick (already installed), opencc-python-reimplemented (new dep)

**Existing code to replace:** `backend/app/flea_market_extensions.py` has a skeleton `contains_sensitive_words()` / `filter_sensitive_words()` with an empty `SENSITIVE_WORDS = []` list. The new system replaces this entirely.

---

### Task 1: Add Database Models

**Files:**
- Modify: `backend/app/models.py`

**Step 1: Add SensitiveWord, HomophoneMapping, ContentReview, FilterLog models**

Add after the existing models (around line 2354, after ForumReply):

```python
class SensitiveWord(Base):
    """敏感词库"""
    __tablename__ = "sensitive_words"

    id = Column(Integer, primary_key=True, index=True)
    word = Column(String(100), nullable=False, index=True)
    category = Column(String(20), nullable=False, index=True)  # ad/scam/agent/porn/drugs/gambling/violence/illegal/profanity/contact
    level = Column(String(10), nullable=False, default="review")  # mask/review
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(Integer, ForeignKey("admin_users.id"), nullable=True)
    created_at = Column(DateTime, default=func.now())


class HomophoneMapping(Base):
    """谐音映射表"""
    __tablename__ = "homophone_mappings"

    id = Column(Integer, primary_key=True, index=True)
    variant = Column(String(50), nullable=False, index=True, unique=True)
    standard = Column(String(50), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)


class ContentReview(Base):
    """审核队列"""
    __tablename__ = "content_reviews"

    id = Column(Integer, primary_key=True, index=True)
    content_type = Column(String(20), nullable=False, index=True)  # task/forum_post/forum_reply/profile/flea_market
    content_id = Column(Integer, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    original_text = Column(Text, nullable=False)
    matched_words = Column(JSON, nullable=True)
    status = Column(String(10), nullable=False, default="pending", index=True)  # pending/approved/rejected
    reviewed_by = Column(Integer, ForeignKey("admin_users.id"), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())


class FilterLog(Base):
    """过滤日志"""
    __tablename__ = "filter_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content_type = Column(String(20), nullable=False)
    action = Column(String(10), nullable=False)  # mask/review/pass
    matched_words = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=func.now())
```

**Step 2: Add `is_visible` to Task and FleaMarketItem models**

ForumPost and ForumReply already have `is_visible`. Add to:

- `Task` model (around line 217, near other boolean fields):
```python
is_visible = Column(Boolean, default=True, nullable=False)
```

- `FleaMarketItem` model (around line 1742, near `status`):
```python
is_visible = Column(Boolean, default=True, nullable=False)
```

**Step 3: Create migration**

Run:
```bash
cd backend
# If using alembic:
# alembic revision --autogenerate -m "add content filter tables and is_visible columns"
# alembic upgrade head
# If manual: tables will be created by create_all or manual SQL
```

**Step 4: Commit**

```bash
git add backend/app/models.py
git commit -m "feat(models): add content filter tables and is_visible columns"
```

---

### Task 2: Build TextNormalizer

**Files:**
- Create: `backend/app/content_filter/text_normalizer.py`
- Create: `backend/app/content_filter/__init__.py`
- Create: `backend/tests/test_content_filter.py`

**Step 1: Create the content_filter package**

Create `backend/app/content_filter/__init__.py`:
```python
from .content_filter import ContentFilter, FilterResult

__all__ = ["ContentFilter", "FilterResult"]
```

**Step 2: Write failing tests for TextNormalizer**

Create `backend/tests/test_content_filter.py`:
```python
import pytest
from app.content_filter.text_normalizer import TextNormalizer


class TestTextNormalizer:
    def setup_method(self):
        # Homophones loaded from a dict for testing (in production, from DB)
        homophones = {"威信": "微信", "薇芯": "微信", "扣扣": "QQ", "球球": "QQ"}
        self.normalizer = TextNormalizer(homophones=homophones)

    def test_fullwidth_to_halfwidth(self):
        assert self.normalizer.normalize("ＱＱ号１２３") == "QQ号123"

    def test_chinese_numerals(self):
        assert "13800001234" in self.normalizer.normalize("一三八零零零零一二三四")

    def test_uppercase_chinese_numerals(self):
        assert "138" in self.normalizer.normalize("壹叁捌")

    def test_strip_interference_symbols(self):
        assert "赌博" in self.normalizer.normalize("赌☆博")
        assert "色情" in self.normalizer.normalize("色.情")
        assert "赌博" in self.normalizer.normalize("赌💰博")

    def test_strip_zero_width_chars(self):
        assert "赌博" in self.normalizer.normalize("赌\u200b博")

    def test_homophone_replacement(self):
        result = self.normalizer.normalize("加我威信")
        assert "微信" in result

    def test_merge_spaces(self):
        assert "赌博" in self.normalizer.normalize("赌  博")

    def test_empty_and_none(self):
        assert self.normalizer.normalize("") == ""
        assert self.normalizer.normalize(None) == ""

    def test_normal_text_unchanged(self):
        text = "我想找人帮忙搬家"
        result = self.normalizer.normalize(text)
        # Should not destroy normal text
        assert "搬家" in result
```

**Step 3: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_content_filter.py -v
```
Expected: FAIL — module not found.

**Step 4: Implement TextNormalizer**

Create `backend/app/content_filter/text_normalizer.py`:
```python
"""
Text normalization for variant detection.
Converts text variants (fullwidth, homophones, inserted symbols, etc.)
back to standard form for accurate keyword matching.
"""
import re
import unicodedata
from typing import Dict, Optional


# Chinese digit mappings
_CN_DIGITS = {
    "零": "0", "一": "1", "二": "2", "三": "3", "四": "4",
    "五": "5", "六": "6", "七": "7", "八": "8", "九": "9",
    "〇": "0",
}
_CN_DIGITS_UPPER = {
    "壹": "1", "贰": "2", "叁": "3", "肆": "4", "伍": "5",
    "陆": "6", "柒": "7", "捌": "8", "玖": "9", "拾": "",
}

# Regex to match emoji and miscellaneous symbols
_EMOJI_RE = re.compile(
    "["
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F680-\U0001F6FF"  # transport & map
    "\U0001F1E0-\U0001F1FF"  # flags
    "\U00002702-\U000027B0"  # dingbats
    "\U0000FE00-\U0000FE0F"  # variation selectors
    "\U0000200B-\U0000200F"  # zero-width chars
    "\U0000202A-\U0000202E"  # bidi controls
    "\U00002060-\U00002069"  # invisible chars
    "\U0000FEFF"             # BOM
    "]+",
    re.UNICODE,
)

# Non-CJK, non-alphanumeric interference characters
_INTERFERENCE_RE = re.compile(r"[^\w\u4e00-\u9fff\u3400-\u4dbf]", re.UNICODE)


class TextNormalizer:
    """Normalize text to detect variants of sensitive words."""

    def __init__(self, homophones: Optional[Dict[str, str]] = None):
        self._homophones = homophones or {}

    def update_homophones(self, homophones: Dict[str, str]):
        self._homophones = homophones

    def normalize(self, text: Optional[str]) -> str:
        if not text:
            return ""

        result = text

        # 1. Remove zero-width and invisible characters
        result = _EMOJI_RE.sub("", result)

        # 2. Fullwidth → halfwidth (NFKC normalization)
        result = unicodedata.normalize("NFKC", result)

        # 3. Chinese digits → Arabic
        for cn, ar in {**_CN_DIGITS, **_CN_DIGITS_UPPER}.items():
            result = result.replace(cn, ar)

        # 4. Homophone replacement (longest match first)
        for variant, standard in sorted(
            self._homophones.items(), key=lambda x: len(x[0]), reverse=True
        ):
            result = result.replace(variant, standard)

        # 5. Remove interference symbols between CJK characters
        # Keep a version with symbols stripped for matching
        result = _INTERFERENCE_RE.sub("", result)

        # 6. Merge consecutive whitespace
        result = re.sub(r"\s+", "", result)

        return result
```

**Step 5: Run tests to verify they pass**

```bash
cd backend && python -m pytest tests/test_content_filter.py -v
```
Expected: All PASS.

**Step 6: Commit**

```bash
git add backend/app/content_filter/ backend/tests/test_content_filter.py
git commit -m "feat(content-filter): add TextNormalizer with variant detection"
```

---

### Task 3: Build ContactDetector

**Files:**
- Create: `backend/app/content_filter/contact_detector.py`
- Modify: `backend/tests/test_content_filter.py`

**Step 1: Write failing tests**

Add to `backend/tests/test_content_filter.py`:
```python
from app.content_filter.contact_detector import ContactDetector


class TestContactDetector:
    def setup_method(self):
        self.detector = ContactDetector()

    def test_detect_phone_number(self):
        result = self.detector.detect("我的手机13800001234")
        assert result.has_contact
        assert "13800001234" in result.matched_text

    def test_detect_phone_with_spaces(self):
        result = self.detector.detect("电话 138 0000 1234")
        assert result.has_contact

    def test_detect_phone_with_dashes(self):
        result = self.detector.detect("电话 138-0000-1234")
        assert result.has_contact

    def test_detect_wechat_variants(self):
        for prefix in ["微信", "wx", "vx", "wechat", "V信", "weixin"]:
            result = self.detector.detect(f"加我{prefix}: abc123")
            assert result.has_contact, f"Failed to detect: {prefix}"

    def test_detect_qq(self):
        result = self.detector.detect("我的QQ 123456789")
        assert result.has_contact

    def test_detect_qq_variants(self):
        for prefix in ["qq", "QQ", "扣扣", "球球"]:
            result = self.detector.detect(f"{prefix}号 123456789")
            assert result.has_contact, f"Failed to detect: {prefix}"

    def test_detect_email(self):
        result = self.detector.detect("邮箱 test@example.com")
        assert result.has_contact

    def test_detect_url(self):
        result = self.detector.detect("看这里 https://example.com/page")
        assert result.has_contact

    def test_mask_phone(self):
        result = self.detector.detect("打13800001234联系")
        assert "***" in result.masked_text
        assert "13800001234" not in result.masked_text

    def test_mask_wechat(self):
        result = self.detector.detect("加我微信abc123哦")
        assert "***" in result.masked_text

    def test_no_false_positive_on_normal_text(self):
        result = self.detector.detect("今天天气不错，一起去打篮球吧")
        assert not result.has_contact

    def test_no_false_positive_on_short_numbers(self):
        # 4-digit numbers should not be flagged as phone
        result = self.detector.detect("这个任务奖励2000元")
        assert not result.has_contact

    def test_empty_input(self):
        result = self.detector.detect("")
        assert not result.has_contact
        result = self.detector.detect(None)
        assert not result.has_contact
```

**Step 2: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_content_filter.py::TestContactDetector -v
```

**Step 3: Implement ContactDetector**

Create `backend/app/content_filter/contact_detector.py`:
```python
"""
Contact information detector using regex patterns.
Detects phone numbers, WeChat, QQ, email, URLs and masks them.
"""
import re
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ContactResult:
    has_contact: bool = False
    matched_text: List[str] = field(default_factory=list)
    masked_text: str = ""
    original_text: str = ""


# Chinese phone: 1[3-9] followed by 9 digits, with optional separators
_PHONE_RE = re.compile(
    r"(?<!\d)"                     # not preceded by digit
    r"(1[3-9]\d[\s\-.]?\d{4}[\s\-.]?\d{4})"
    r"(?!\d)",                     # not followed by digit
)

# WeChat ID patterns
_WECHAT_RE = re.compile(
    r"((?:微信|wx|vx|wechat|v信|V信|weixin|威信|薇芯)"
    r"\s*[:：]?\s*"
    r"[a-zA-Z0-9_\-]{4,20})",
    re.IGNORECASE,
)

# QQ number patterns
_QQ_RE = re.compile(
    r"((?:qq|QQ|扣扣|球球|Qq)"
    r"\s*[:：]?\s*"
    r"\d{5,12})",
    re.IGNORECASE,
)

# Email
_EMAIL_RE = re.compile(
    r"([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})"
)

# URL
_URL_RE = re.compile(
    r"(https?://[^\s<>\"'，。！？、；：（）\u3000]+)",
    re.IGNORECASE,
)

_ALL_PATTERNS = [
    ("phone", _PHONE_RE),
    ("wechat", _WECHAT_RE),
    ("qq", _QQ_RE),
    ("email", _EMAIL_RE),
    ("url", _URL_RE),
]


class ContactDetector:
    """Detect and mask contact information in text."""

    def detect(self, text: Optional[str]) -> ContactResult:
        if not text:
            return ContactResult(original_text=text or "")

        matched = []
        masked = text

        for name, pattern in _ALL_PATTERNS:
            for m in pattern.finditer(text):
                matched.append(m.group(0))

            # Replace all matches with ***
            masked = pattern.sub("***", masked)

        return ContactResult(
            has_contact=len(matched) > 0,
            matched_text=matched,
            masked_text=masked,
            original_text=text,
        )
```

**Step 4: Run tests to verify they pass**

```bash
cd backend && python -m pytest tests/test_content_filter.py::TestContactDetector -v
```

**Step 5: Commit**

```bash
git add backend/app/content_filter/contact_detector.py backend/tests/test_content_filter.py
git commit -m "feat(content-filter): add ContactDetector with regex patterns"
```

---

### Task 4: Build KeywordMatcher

**Files:**
- Create: `backend/app/content_filter/keyword_matcher.py`
- Modify: `backend/tests/test_content_filter.py`

**Step 1: Write failing tests**

Add to `backend/tests/test_content_filter.py`:
```python
from app.content_filter.keyword_matcher import KeywordMatcher


class TestKeywordMatcher:
    def setup_method(self):
        keywords = [
            {"word": "代理", "category": "agent", "level": "review"},
            {"word": "赌博", "category": "gambling", "level": "review"},
            {"word": "兼职", "category": "ad", "level": "review"},
            {"word": "黄片", "category": "porn", "level": "review"},
            {"word": "脏话", "category": "profanity", "level": "review"},
        ]
        self.matcher = KeywordMatcher(keywords)

    def test_match_single_keyword(self):
        result = self.matcher.match("想找个代理帮忙")
        assert result.has_match
        assert any(m["word"] == "代理" for m in result.matches)

    def test_match_multiple_keywords(self):
        result = self.matcher.match("网上赌博兼职代理")
        assert len(result.matches) == 3

    def test_no_match_clean_text(self):
        result = self.matcher.match("今天天气真好，一起打篮球")
        assert not result.has_match

    def test_strictest_level(self):
        result = self.matcher.match("这是代理广告")
        assert result.strictest_level == "review"

    def test_empty_input(self):
        result = self.matcher.match("")
        assert not result.has_match
        result = self.matcher.match(None)
        assert not result.has_match

    def test_rebuild_automaton(self):
        new_keywords = [
            {"word": "新词", "category": "ad", "level": "review"},
        ]
        self.matcher.rebuild(new_keywords)
        result = self.matcher.match("这个新词要拦截")
        assert result.has_match

    def test_categories(self):
        result = self.matcher.match("赌博")
        assert result.matches[0]["category"] == "gambling"
```

**Step 2: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_content_filter.py::TestKeywordMatcher -v
```

**Step 3: Implement KeywordMatcher**

Create `backend/app/content_filter/keyword_matcher.py`:
```python
"""
Keyword matcher using Aho-Corasick algorithm for O(n) multi-pattern matching.
pyahocorasick is already in requirements.txt.
"""
import ahocorasick
from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class MatchResult:
    has_match: bool = False
    matches: List[Dict] = field(default_factory=list)  # [{word, category, level}]
    strictest_level: str = "pass"  # pass < mask < review


_LEVEL_PRIORITY = {"pass": 0, "mask": 1, "review": 2}


class KeywordMatcher:
    """Multi-pattern keyword matching with Aho-Corasick automaton."""

    def __init__(self, keywords: Optional[List[Dict]] = None):
        self._automaton = ahocorasick.Automaton()
        if keywords:
            self.rebuild(keywords)

    def rebuild(self, keywords: List[Dict]):
        """Rebuild the automaton with a new keyword list."""
        self._automaton = ahocorasick.Automaton()
        for kw in keywords:
            word = kw["word"]
            self._automaton.add_word(word, kw)
        if len(self._automaton) > 0:
            self._automaton.make_automaton()

    def match(self, text: Optional[str]) -> MatchResult:
        if not text or len(self._automaton) == 0:
            return MatchResult()

        matches = []
        seen_words = set()

        try:
            for end_idx, kw_data in self._automaton.iter(text):
                word = kw_data["word"]
                if word not in seen_words:
                    seen_words.add(word)
                    matches.append(kw_data)
        except Exception:
            return MatchResult()

        if not matches:
            return MatchResult()

        strictest = max(matches, key=lambda m: _LEVEL_PRIORITY.get(m["level"], 0))

        return MatchResult(
            has_match=True,
            matches=matches,
            strictest_level=strictest["level"],
        )
```

**Step 4: Run tests to verify they pass**

```bash
cd backend && python -m pytest tests/test_content_filter.py::TestKeywordMatcher -v
```

**Step 5: Commit**

```bash
git add backend/app/content_filter/keyword_matcher.py backend/tests/test_content_filter.py
git commit -m "feat(content-filter): add KeywordMatcher with Aho-Corasick"
```

---

### Task 5: Build ContentFilter (orchestrator)

**Files:**
- Create: `backend/app/content_filter/content_filter.py`
- Modify: `backend/app/content_filter/__init__.py`
- Modify: `backend/tests/test_content_filter.py`

**Step 1: Write failing tests**

Add to `backend/tests/test_content_filter.py`:
```python
from app.content_filter.content_filter import ContentFilter, FilterResult


class TestContentFilter:
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
        assert "微信abc123" not in result.cleaned_text

    def test_keyword_triggers_review(self):
        result = self.filter.check("网上赌博代理招人")
        assert result.action == "review"
        assert len(result.matched_words) >= 1

    def test_contact_plus_keyword_uses_strictest(self):
        # review > mask, so result should be review
        result = self.filter.check("赌博网站加我微信abc123")
        assert result.action == "review"

    def test_variant_detected_via_normalizer(self):
        result = self.filter.check("找个代☆理帮忙赌☆博")
        assert result.action == "review"

    def test_homophone_variant(self):
        result = self.filter.check("加我威信abc123")
        assert result.action == "mask"  # 威信 → 微信, detected as wechat contact

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
```

**Step 2: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_content_filter.py::TestContentFilter -v
```

**Step 3: Implement ContentFilter**

Create `backend/app/content_filter/content_filter.py`:
```python
"""
ContentFilter orchestrator — combines TextNormalizer, ContactDetector, and KeywordMatcher.
"""
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .text_normalizer import TextNormalizer
from .contact_detector import ContactDetector
from .keyword_matcher import KeywordMatcher


@dataclass
class FilterResult:
    action: str = "pass"         # pass / mask / review
    matched_words: List[Dict] = field(default_factory=list)
    cleaned_text: str = ""
    original_text: str = ""


_ACTION_PRIORITY = {"pass": 0, "mask": 1, "review": 2}


class ContentFilter:
    """
    Content filter combining normalization, contact detection, and keyword matching.

    Usage:
        filter = ContentFilter(keywords=[...], homophones={...})
        result = filter.check("some user input")
        # result.action: "pass" | "mask" | "review"
        # result.cleaned_text: text with contacts masked (if action == "mask")
    """

    def __init__(
        self,
        keywords: Optional[List[Dict]] = None,
        homophones: Optional[Dict[str, str]] = None,
    ):
        self._normalizer = TextNormalizer(homophones=homophones)
        self._contact_detector = ContactDetector()
        self._keyword_matcher = KeywordMatcher(keywords)

    def update_keywords(self, keywords: List[Dict]):
        self._keyword_matcher.rebuild(keywords)

    def update_homophones(self, homophones: Dict[str, str]):
        self._normalizer.update_homophones(homophones)

    def check(self, text: Optional[str]) -> FilterResult:
        if not text:
            return FilterResult(action="pass", cleaned_text=text or "", original_text=text or "")

        action = "pass"
        all_matched = []

        # 1. Contact detection on original text
        contact_result = self._contact_detector.detect(text)
        if contact_result.has_contact:
            action = "mask"
            all_matched.extend(
                [{"word": m, "category": "contact", "level": "mask"} for m in contact_result.matched_text]
            )

        # 2. Keyword matching on original text
        kw_result_orig = self._keyword_matcher.match(text)
        if kw_result_orig.has_match:
            all_matched.extend(kw_result_orig.matches)
            if _ACTION_PRIORITY.get(kw_result_orig.strictest_level, 0) > _ACTION_PRIORITY.get(action, 0):
                action = kw_result_orig.strictest_level

        # 3. Normalize text and match again (catch variants)
        normalized = self._normalizer.normalize(text)
        if normalized != text:
            # Contact detection on normalized text
            contact_norm = self._contact_detector.detect(normalized)
            if contact_norm.has_contact and not contact_result.has_contact:
                if _ACTION_PRIORITY.get("mask", 0) > _ACTION_PRIORITY.get(action, 0):
                    action = "mask"
                all_matched.extend(
                    [{"word": m, "category": "contact", "level": "mask"} for m in contact_norm.matched_text]
                )
                # Mask in original text too
                contact_result = self._contact_detector.detect(text)

            # Keyword matching on normalized text
            kw_result_norm = self._keyword_matcher.match(normalized)
            if kw_result_norm.has_match:
                # Add only new matches
                existing_words = {m["word"] for m in all_matched}
                for m in kw_result_norm.matches:
                    if m["word"] not in existing_words:
                        all_matched.append(m)
                if _ACTION_PRIORITY.get(kw_result_norm.strictest_level, 0) > _ACTION_PRIORITY.get(action, 0):
                    action = kw_result_norm.strictest_level

        # Build cleaned text
        cleaned = contact_result.masked_text if contact_result.has_contact else text

        return FilterResult(
            action=action,
            matched_words=all_matched,
            cleaned_text=cleaned,
            original_text=text,
        )

    def check_fields(self, fields: Dict[str, Optional[str]]) -> Dict[str, FilterResult]:
        """Check multiple text fields, return results keyed by field name."""
        return {name: self.check(value) for name, value in fields.items()}
```

Update `backend/app/content_filter/__init__.py`:
```python
from .content_filter import ContentFilter, FilterResult
from .text_normalizer import TextNormalizer
from .contact_detector import ContactDetector, ContactResult
from .keyword_matcher import KeywordMatcher, MatchResult

__all__ = [
    "ContentFilter", "FilterResult",
    "TextNormalizer",
    "ContactDetector", "ContactResult",
    "KeywordMatcher", "MatchResult",
]
```

**Step 4: Run all tests**

```bash
cd backend && python -m pytest tests/test_content_filter.py -v
```
Expected: All PASS.

**Step 5: Commit**

```bash
git add backend/app/content_filter/
git commit -m "feat(content-filter): add ContentFilter orchestrator"
```

---

### Task 6: Add ContentFilter Singleton with Redis Caching

**Files:**
- Create: `backend/app/content_filter/filter_service.py`

**Step 1: Implement filter service with DB loading and Redis cache**

Create `backend/app/content_filter/filter_service.py`:
```python
"""
Singleton service that loads keywords/homophones from DB, caches in Redis,
and provides a global ContentFilter instance.
"""
import json
import logging
import time
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.content_filter.content_filter import ContentFilter, FilterResult

logger = logging.getLogger(__name__)

# Singleton
_filter_instance: Optional[ContentFilter] = None
_last_refresh: float = 0
_REFRESH_INTERVAL = 300  # 5 minutes


async def get_content_filter(db: AsyncSession) -> ContentFilter:
    """Get or refresh the global ContentFilter singleton."""
    global _filter_instance, _last_refresh

    now = time.time()
    if _filter_instance is None or (now - _last_refresh) > _REFRESH_INTERVAL:
        await _refresh_filter(db)
        _last_refresh = now

    return _filter_instance


async def _refresh_filter(db: AsyncSession):
    """Load keywords and homophones from DB, rebuild filter."""
    global _filter_instance

    # Load active sensitive words
    result = await db.execute(
        select(models.SensitiveWord).where(models.SensitiveWord.is_active == True)
    )
    words = result.scalars().all()
    keywords = [
        {"word": w.word, "category": w.category, "level": w.level}
        for w in words
    ]

    # Load active homophone mappings
    result = await db.execute(
        select(models.HomophoneMapping).where(models.HomophoneMapping.is_active == True)
    )
    mappings = result.scalars().all()
    homophones = {m.variant: m.standard for m in mappings}

    if _filter_instance is None:
        _filter_instance = ContentFilter(keywords=keywords, homophones=homophones)
    else:
        _filter_instance.update_keywords(keywords)
        _filter_instance.update_homophones(homophones)

    logger.info(f"Content filter refreshed: {len(keywords)} keywords, {len(homophones)} homophones")


def force_refresh():
    """Force next call to get_content_filter to reload from DB."""
    global _last_refresh
    _last_refresh = 0


async def check_content(
    db: AsyncSession,
    text: Optional[str],
    content_type: str,
    user_id: int,
) -> FilterResult:
    """
    Check text and log the result.
    Returns FilterResult with action: pass/mask/review.
    """
    content_filter = await get_content_filter(db)
    result = content_filter.check(text)

    # Log non-pass results
    if result.action != "pass":
        log_entry = models.FilterLog(
            user_id=user_id,
            content_type=content_type,
            action=result.action,
            matched_words=[{"word": m["word"], "category": m["category"]} for m in result.matched_words],
        )
        db.add(log_entry)
        # Don't commit here — let the caller commit with the main transaction

    return result


async def create_review(
    db: AsyncSession,
    content_type: str,
    content_id: int,
    user_id: int,
    original_text: str,
    matched_words: list,
):
    """Create a content review entry."""
    review = models.ContentReview(
        content_type=content_type,
        content_id=content_id,
        user_id=user_id,
        original_text=original_text,
        matched_words=[{"word": m["word"], "category": m["category"]} for m in matched_words],
        status="pending",
    )
    db.add(review)
```

**Step 2: Commit**

```bash
git add backend/app/content_filter/filter_service.py
git commit -m "feat(content-filter): add singleton service with DB loading"
```

---

### Task 7: Integrate Filter into Content Submission Endpoints

**Files:**
- Modify: `backend/app/async_routers.py` (task creation)
- Modify: `backend/app/forum_routes.py` (post creation, reply creation)
- Modify: `backend/app/flea_market_routes.py` (item creation — replace existing skeleton)
- Modify: `backend/app/routers.py` (profile update)

**Step 1: Integrate into task creation (`async_routers.py`)**

Before the `create_task` DB call (around line 546), add:

```python
from app.content_filter.filter_service import check_content, create_review

# --- Content filtering (before DB insertion) ---
title_result = await check_content(db, task.title, "task", current_user.id)
desc_result = await check_content(db, task.description, "task", current_user.id)

# Use strictest action
actions = [title_result.action, desc_result.action]
final_action = "review" if "review" in actions else ("mask" if "mask" in actions else "pass")

# Apply masking
if title_result.action == "mask":
    task.title = title_result.cleaned_text
if desc_result.action == "mask":
    task.description = desc_result.cleaned_text
```

After the task is created and `db_task` has an ID:

```python
content_masked = "mask" in actions
under_review = final_action == "review"

if under_review:
    db_task.is_visible = False
    combined_matched = title_result.matched_words + desc_result.matched_words
    await create_review(db, "task", db_task.id, current_user.id,
                       f"[title]{task.title}[desc]{task.description}", combined_matched)
```

In the response, add `content_masked` and `under_review` fields.

**Step 2: Integrate into forum post creation (`forum_routes.py`)**

After duplicate check (around line 2919), before category validation:

```python
from app.content_filter.filter_service import check_content, create_review

title_result = await check_content(db, post.title, "forum_post", current_user.id)
content_result = await check_content(db, post.content, "forum_post", current_user.id)

actions = [title_result.action, content_result.action]
final_action = "review" if "review" in actions else ("mask" if "mask" in actions else "pass")

if title_result.action == "mask":
    post.title = title_result.cleaned_text
if content_result.action == "mask":
    post.content = content_result.cleaned_text
```

After post is created:
```python
if final_action == "review":
    db_post.is_visible = False
    combined_matched = title_result.matched_words + content_result.matched_words
    await create_review(db, "forum_post", db_post.id, current_user.id,
                       f"[title]{post.title}[content]{post.content}", combined_matched)
```

**Step 3: Integrate into forum reply creation (`forum_routes.py`)**

After duplicate reply check (around line 4128):

```python
content_result = await check_content(db, reply.content, "forum_reply", current_user.id)

if content_result.action == "mask":
    reply.content = content_result.cleaned_text
```

After reply is created:
```python
if content_result.action == "review":
    db_reply.is_visible = False
    await create_review(db, "forum_reply", db_reply.id, current_user.id,
                       reply.content, content_result.matched_words)
```

**Step 4: Replace flea market skeleton (`flea_market_routes.py`)**

Replace the existing `contains_sensitive_words` / `filter_sensitive_words` calls (lines 808-817) with:

```python
from app.content_filter.filter_service import check_content, create_review

title_result = await check_content(db, item_data.title, "flea_market", current_user.id)
desc_result = await check_content(db, item_data.description, "flea_market", current_user.id)

actions = [title_result.action, desc_result.action]
final_action = "review" if "review" in actions else ("mask" if "mask" in actions else "pass")

if title_result.action == "mask":
    item_data.title = title_result.cleaned_text
if desc_result.action == "mask":
    item_data.description = desc_result.cleaned_text
```

After item is created:
```python
if final_action == "review":
    new_item.is_visible = False
    combined_matched = title_result.matched_words + desc_result.matched_words
    await create_review(db, "flea_market", new_item.id, current_user.id,
                       f"[title]{item_data.title}[desc]{item_data.description}", combined_matched)
```

**Step 5: Add `is_visible` filter to list query endpoints**

In task list, forum list, flea market list queries, add `.where(Model.is_visible == True)` to the SQLAlchemy select statements. Find the exact query locations by searching for `select(models.Task)`, `select(models.ForumPost)`, `select(models.FleaMarketItem)` in the route files.

**Step 6: Commit**

```bash
git add backend/app/async_routers.py backend/app/forum_routes.py backend/app/flea_market_routes.py backend/app/routers.py
git commit -m "feat(content-filter): integrate filter into content submission endpoints"
```

---

### Task 8: Build Admin Content Moderation API

**Files:**
- Create: `backend/app/admin_content_moderation_routes.py`
- Modify: `backend/app/main.py`

**Step 1: Create admin moderation routes**

Create `backend/app/admin_content_moderation_routes.py`:

```python
"""
Admin API for content moderation:
- Sensitive word CRUD
- Homophone mapping CRUD
- Content review queue
- Filter logs
"""
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app import models
from app.database import get_async_db_dependency
from app.auth import get_current_admin_async
from app.content_filter.filter_service import force_refresh

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/content-moderation", tags=["管理员-内容审核"])

# ==================== Schemas ====================

class SensitiveWordCreate(BaseModel):
    word: str
    category: str  # ad/scam/agent/porn/drugs/gambling/violence/illegal/profanity/contact
    level: str = "review"  # mask/review

class SensitiveWordUpdate(BaseModel):
    word: Optional[str] = None
    category: Optional[str] = None
    level: Optional[str] = None
    is_active: Optional[bool] = None

class SensitiveWordBatchImport(BaseModel):
    words: list[dict]  # [{word, category, level}]

class HomophoneMappingCreate(BaseModel):
    variant: str
    standard: str

class ReviewAction(BaseModel):
    action: str  # approve/reject


# ==================== Sensitive Words ====================

@router.get("/sensitive-words")
async def list_sensitive_words(
    category: Optional[str] = None,
    is_active: Optional[bool] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    query = select(models.SensitiveWord)
    count_query = select(func.count(models.SensitiveWord.id))

    if category:
        query = query.where(models.SensitiveWord.category == category)
        count_query = count_query.where(models.SensitiveWord.category == category)
    if is_active is not None:
        query = query.where(models.SensitiveWord.is_active == is_active)
        count_query = count_query.where(models.SensitiveWord.is_active == is_active)

    total = (await db.execute(count_query)).scalar()
    query = query.order_by(desc(models.SensitiveWord.created_at))
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    words = result.scalars().all()

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": [
            {
                "id": w.id, "word": w.word, "category": w.category,
                "level": w.level, "is_active": w.is_active,
                "created_at": str(w.created_at) if w.created_at else None,
            }
            for w in words
        ],
    }


@router.post("/sensitive-words")
async def create_sensitive_word(
    data: SensitiveWordCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    word = models.SensitiveWord(
        word=data.word, category=data.category, level=data.level,
        created_by=current_admin.id,
    )
    db.add(word)
    await db.commit()
    force_refresh()
    return {"id": word.id, "message": "添加成功"}


@router.put("/sensitive-words/{word_id}")
async def update_sensitive_word(
    word_id: int,
    data: SensitiveWordUpdate,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(select(models.SensitiveWord).where(models.SensitiveWord.id == word_id))
    word = result.scalar_one_or_none()
    if not word:
        raise HTTPException(status_code=404, detail="敏感词不存在")

    if data.word is not None:
        word.word = data.word
    if data.category is not None:
        word.category = data.category
    if data.level is not None:
        word.level = data.level
    if data.is_active is not None:
        word.is_active = data.is_active

    await db.commit()
    force_refresh()
    return {"message": "更新成功"}


@router.delete("/sensitive-words/{word_id}")
async def delete_sensitive_word(
    word_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(select(models.SensitiveWord).where(models.SensitiveWord.id == word_id))
    word = result.scalar_one_or_none()
    if not word:
        raise HTTPException(status_code=404, detail="敏感词不存在")
    await db.delete(word)
    await db.commit()
    force_refresh()
    return {"message": "删除成功"}


@router.post("/sensitive-words/batch")
async def batch_import_sensitive_words(
    data: SensitiveWordBatchImport,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    count = 0
    for item in data.words:
        word = models.SensitiveWord(
            word=item["word"],
            category=item.get("category", "ad"),
            level=item.get("level", "review"),
            created_by=current_admin.id,
        )
        db.add(word)
        count += 1
    await db.commit()
    force_refresh()
    return {"message": f"成功导入 {count} 个敏感词"}


# ==================== Homophone Mappings ====================

@router.get("/homophone-mappings")
async def list_homophone_mappings(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    total = (await db.execute(select(func.count(models.HomophoneMapping.id)))).scalar()
    result = await db.execute(
        select(models.HomophoneMapping)
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    mappings = result.scalars().all()
    return {
        "total": total,
        "items": [
            {"id": m.id, "variant": m.variant, "standard": m.standard, "is_active": m.is_active}
            for m in mappings
        ],
    }


@router.post("/homophone-mappings")
async def create_homophone_mapping(
    data: HomophoneMappingCreate,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    mapping = models.HomophoneMapping(variant=data.variant, standard=data.standard)
    db.add(mapping)
    await db.commit()
    force_refresh()
    return {"id": mapping.id, "message": "添加成功"}


@router.delete("/homophone-mappings/{mapping_id}")
async def delete_homophone_mapping(
    mapping_id: int,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(select(models.HomophoneMapping).where(models.HomophoneMapping.id == mapping_id))
    mapping = result.scalar_one_or_none()
    if not mapping:
        raise HTTPException(status_code=404, detail="映射不存在")
    await db.delete(mapping)
    await db.commit()
    force_refresh()
    return {"message": "删除成功"}


# ==================== Content Reviews ====================

@router.get("/content-reviews")
async def list_content_reviews(
    status_filter: Optional[str] = Query(None, alias="status"),
    content_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    query = select(models.ContentReview)
    count_query = select(func.count(models.ContentReview.id))

    if status_filter:
        query = query.where(models.ContentReview.status == status_filter)
        count_query = count_query.where(models.ContentReview.status == status_filter)
    if content_type:
        query = query.where(models.ContentReview.content_type == content_type)
        count_query = count_query.where(models.ContentReview.content_type == content_type)

    total = (await db.execute(count_query)).scalar()
    query = query.order_by(desc(models.ContentReview.created_at))
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    reviews = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": r.id, "content_type": r.content_type, "content_id": r.content_id,
                "user_id": r.user_id, "original_text": r.original_text,
                "matched_words": r.matched_words, "status": r.status,
                "created_at": str(r.created_at) if r.created_at else None,
            }
            for r in reviews
        ],
    }


@router.put("/content-reviews/{review_id}")
async def review_content(
    review_id: int,
    data: ReviewAction,
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Approve or reject a content review."""
    result = await db.execute(select(models.ContentReview).where(models.ContentReview.id == review_id))
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="审核记录不存在")
    if review.status != "pending":
        raise HTTPException(status_code=400, detail="该内容已审核")

    from datetime import datetime
    review.status = "approved" if data.action == "approve" else "rejected"
    review.reviewed_by = current_admin.id
    review.reviewed_at = datetime.utcnow()

    # If approved, make content visible
    if data.action == "approve":
        model_map = {
            "task": models.Task,
            "forum_post": models.ForumPost,
            "forum_reply": models.ForumReply,
            "flea_market": models.FleaMarketItem,
        }
        model_cls = model_map.get(review.content_type)
        if model_cls:
            content_result = await db.execute(
                select(model_cls).where(model_cls.id == review.content_id)
            )
            content = content_result.scalar_one_or_none()
            if content:
                content.is_visible = True

    await db.commit()
    return {"message": "审核完成", "status": review.status}


# ==================== Filter Logs ====================

@router.get("/filter-logs")
async def list_filter_logs(
    action: Optional[str] = None,
    content_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_admin: models.AdminUser = Depends(get_current_admin_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    query = select(models.FilterLog)
    count_query = select(func.count(models.FilterLog.id))

    if action:
        query = query.where(models.FilterLog.action == action)
        count_query = count_query.where(models.FilterLog.action == action)
    if content_type:
        query = query.where(models.FilterLog.content_type == content_type)
        count_query = count_query.where(models.FilterLog.content_type == content_type)

    total = (await db.execute(count_query)).scalar()
    query = query.order_by(desc(models.FilterLog.created_at))
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    logs = result.scalars().all()

    return {
        "total": total,
        "items": [
            {
                "id": l.id, "user_id": l.user_id, "content_type": l.content_type,
                "action": l.action, "matched_words": l.matched_words,
                "created_at": str(l.created_at) if l.created_at else None,
            }
            for l in logs
        ],
    }
```

**Step 2: Register in main.py**

Add after the other admin router imports (around line 313):

```python
# 管理员内容审核路由
from app.admin_content_moderation_routes import router as admin_content_moderation_router
app.include_router(admin_content_moderation_router, tags=["管理员-内容审核"])
```

**Step 3: Commit**

```bash
git add backend/app/admin_content_moderation_routes.py backend/app/main.py
git commit -m "feat(admin): add content moderation API (keywords, reviews, logs)"
```

---

### Task 9: Seed Initial Sensitive Word Data

**Files:**
- Create: `backend/app/content_filter/seed_data.py`

**Step 1: Create seed script with common sensitive words**

Create `backend/app/content_filter/seed_data.py`:

```python
"""
Initial seed data for sensitive words and homophone mappings.
Run once to populate the database with common entries.

Usage:
    python -m app.content_filter.seed_data
"""

INITIAL_WORDS = [
    # 广告/推广
    {"word": "代购", "category": "ad", "level": "review"},
    {"word": "刷单", "category": "ad", "level": "review"},
    {"word": "日赚", "category": "ad", "level": "review"},
    {"word": "月入过万", "category": "ad", "level": "review"},
    {"word": "免费领取", "category": "ad", "level": "review"},
    {"word": "优惠券群", "category": "ad", "level": "review"},
    {"word": "推广赚钱", "category": "ad", "level": "review"},
    {"word": "兼职日结", "category": "ad", "level": "review"},
    {"word": "招代理", "category": "ad", "level": "review"},
    {"word": "诚招", "category": "ad", "level": "review"},
    # 中介
    {"word": "中介费", "category": "agent", "level": "review"},
    {"word": "代办", "category": "agent", "level": "review"},
    {"word": "包过", "category": "agent", "level": "review"},
    {"word": "代写", "category": "agent", "level": "review"},
    {"word": "代考", "category": "agent", "level": "review"},
    {"word": "论文代写", "category": "agent", "level": "review"},
    # 诈骗
    {"word": "杀猪盘", "category": "scam", "level": "review"},
    {"word": "投资理财", "category": "scam", "level": "review"},
    {"word": "稳赚不赔", "category": "scam", "level": "review"},
    {"word": "高回报", "category": "scam", "level": "review"},
    {"word": "保本", "category": "scam", "level": "review"},
    {"word": "翻倍", "category": "scam", "level": "review"},
    {"word": "内部消息", "category": "scam", "level": "review"},
    # 色情
    {"word": "约炮", "category": "porn", "level": "review"},
    {"word": "一夜情", "category": "porn", "level": "review"},
    {"word": "援交", "category": "porn", "level": "review"},
    {"word": "裸聊", "category": "porn", "level": "review"},
    {"word": "色情", "category": "porn", "level": "review"},
    {"word": "黄片", "category": "porn", "level": "review"},
    {"word": "成人视频", "category": "porn", "level": "review"},
    {"word": "小姐", "category": "porn", "level": "review"},
    # 毒品
    {"word": "冰毒", "category": "drugs", "level": "review"},
    {"word": "大麻", "category": "drugs", "level": "review"},
    {"word": "海洛因", "category": "drugs", "level": "review"},
    {"word": "摇头丸", "category": "drugs", "level": "review"},
    {"word": "K粉", "category": "drugs", "level": "review"},
    {"word": "吸毒", "category": "drugs", "level": "review"},
    {"word": "贩毒", "category": "drugs", "level": "review"},
    # 赌博
    {"word": "赌博", "category": "gambling", "level": "review"},
    {"word": "网赌", "category": "gambling", "level": "review"},
    {"word": "赌场", "category": "gambling", "level": "review"},
    {"word": "博彩", "category": "gambling", "level": "review"},
    {"word": "百家乐", "category": "gambling", "level": "review"},
    {"word": "老虎机", "category": "gambling", "level": "review"},
    {"word": "六合彩", "category": "gambling", "level": "review"},
    # 暴力
    {"word": "枪支", "category": "violence", "level": "review"},
    {"word": "炸弹", "category": "violence", "level": "review"},
    {"word": "杀人", "category": "violence", "level": "review"},
    # 违法
    {"word": "假证", "category": "illegal", "level": "review"},
    {"word": "办证", "category": "illegal", "level": "review"},
    {"word": "洗钱", "category": "illegal", "level": "review"},
    {"word": "偷税", "category": "illegal", "level": "review"},
    {"word": "走私", "category": "illegal", "level": "review"},
    {"word": "假币", "category": "illegal", "level": "review"},
]

INITIAL_HOMOPHONES = [
    # 微信变体
    {"variant": "威信", "standard": "微信"},
    {"variant": "薇芯", "standard": "微信"},
    {"variant": "微芯", "standard": "微信"},
    {"variant": "VX", "standard": "微信"},
    {"variant": "vx", "standard": "微信"},
    {"variant": "V信", "standard": "微信"},
    {"variant": "v信", "standard": "微信"},
    # QQ变体
    {"variant": "扣扣", "standard": "QQ"},
    {"variant": "球球", "standard": "QQ"},
    {"variant": "Q扣", "standard": "QQ"},
    # 赌博变体
    {"variant": "堵博", "standard": "赌博"},
    {"variant": "赌搏", "standard": "赌博"},
    {"variant": "dubo", "standard": "赌博"},
    # 色情变体
    {"variant": "涩情", "standard": "色情"},
    {"variant": "瑟情", "standard": "色情"},
    {"variant": "seqing", "standard": "色情"},
    # 其他
    {"variant": "荒片", "standard": "黄片"},
    {"variant": "皇片", "standard": "黄片"},
    {"variant": "坚直", "standard": "兼职"},
    {"variant": "兼只", "standard": "兼职"},
    {"variant": "jianzhi", "standard": "兼职"},
]


async def seed_sensitive_words(db):
    """Seed initial sensitive words if table is empty."""
    from sqlalchemy import select, func
    count = (await db.execute(select(func.count(models.SensitiveWord.id)))).scalar()
    if count > 0:
        print(f"Sensitive words table already has {count} entries, skipping seed.")
        return

    from app import models
    for item in INITIAL_WORDS:
        db.add(models.SensitiveWord(**item))
    for item in INITIAL_HOMOPHONES:
        db.add(models.HomophoneMapping(**item))
    await db.commit()
    print(f"Seeded {len(INITIAL_WORDS)} sensitive words and {len(INITIAL_HOMOPHONES)} homophone mappings.")
```

**Step 2: Commit**

```bash
git add backend/app/content_filter/seed_data.py
git commit -m "feat(content-filter): add initial seed data for sensitive words"
```

---

### Task 10: Add opencc dependency and update requirements

**Files:**
- Modify: `backend/requirements.txt`

**Step 1: Add opencc-python-reimplemented**

Add to requirements.txt:
```
# Content Filtering
opencc-python-reimplemented>=0.1.7
```

Note: `pyahocorasick` is already in requirements.txt (used for student verification).

**Step 2: Update TextNormalizer to use OpenCC for Traditional → Simplified**

In `backend/app/content_filter/text_normalizer.py`, add after fullwidth conversion:

```python
try:
    import opencc
    _T2S = opencc.OpenCC("t2s")
except ImportError:
    _T2S = None
```

In the `normalize()` method, after NFKC normalization:
```python
# Traditional → Simplified Chinese
if _T2S:
    result = _T2S.convert(result)
```

**Step 3: Commit**

```bash
git add backend/requirements.txt backend/app/content_filter/text_normalizer.py
git commit -m "feat(content-filter): add OpenCC for traditional Chinese conversion"
```

---

### Task 11: Flutter Frontend — Handle Filter Response

**Files:**
- Modify: `link2ur/lib/data/repositories/task_repository.dart` (or relevant repo)
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

**Step 1: Add localization strings**

In all three ARB files, add:
```json
"contentMaskedHint": "Part of the content has been automatically processed. Please use in-app chat for communication.",
"contentUnderReviewHint": "Your content has been submitted and is pending review.",
"contentRejectedHint": "Your content did not pass review."
```

Chinese (`app_zh.arb`):
```json
"contentMaskedHint": "部分内容已被自动处理，请通过平台内聊天沟通。",
"contentUnderReviewHint": "内容已提交，正在等待审核。",
"contentRejectedHint": "您的内容未通过审核。"
```

Traditional Chinese (`app_zh_Hant.arb`):
```json
"contentMaskedHint": "部分內容已被自動處理，請透過平台內聊天溝通。",
"contentUnderReviewHint": "內容已提交，正在等待審核。",
"contentRejectedHint": "您的內容未通過審核。"
```

**Step 2: Handle response in BLoC/repository layer**

In task creation, forum post creation, and flea market publish — after successful API response, check for `content_masked` and `under_review` fields in the response JSON. Show appropriate SnackBar hint using the l10n strings above.

**Step 3: Run l10n generation**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

**Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/data/repositories/
git commit -m "feat(flutter): handle content filter response hints"
```

---

### Task 12: Add `is_visible` Filtering to List Queries

**Files:**
- Modify: Backend route files that serve lists of tasks, forum posts, flea market items

**Step 1: Find and update list query endpoints**

Search for all `select(models.Task)`, `select(models.ForumPost)`, `select(models.FleaMarketItem)` in route files. Add `.where(Model.is_visible == True)` to public-facing list queries (NOT admin queries).

Key endpoints:
- Task list / search → `async_routers.py` or `routers.py`
- Forum post list → `forum_routes.py`
- Flea market list → `flea_market_routes.py`

Admin endpoints should still be able to see all content (is_visible=True or False).

**Step 2: Commit**

```bash
git add backend/app/
git commit -m "feat(content-filter): add is_visible filtering to list queries"
```

---

### Task 13: Clean Up Old Flea Market Filter Skeleton

**Files:**
- Modify: `backend/app/flea_market_extensions.py`

**Step 1: Remove the old skeleton code**

Remove `SENSITIVE_WORDS`, `contains_sensitive_words()`, and `filter_sensitive_words()` from `flea_market_extensions.py`. Update imports in `flea_market_routes.py` to remove references to these functions (they were replaced in Task 7).

**Step 2: Commit**

```bash
git add backend/app/flea_market_extensions.py backend/app/flea_market_routes.py
git commit -m "refactor: remove old flea market filter skeleton (replaced by content_filter)"
```

---

### Task 14: End-to-End Testing

**Files:**
- Modify: `backend/tests/test_content_filter.py`

**Step 1: Run all unit tests**

```bash
cd backend && python -m pytest tests/test_content_filter.py -v
```

**Step 2: Run full backend test suite**

```bash
cd backend && python -m pytest tests/ -v
```

**Step 3: Manual verification checklist**

- [ ] Create a task with phone number → title/description should have `***`
- [ ] Create a forum post with "赌博" → should enter review queue
- [ ] Admin API: GET /api/admin/content-moderation/content-reviews → sees pending review
- [ ] Admin API: PUT /api/admin/content-moderation/content-reviews/{id} approve → content becomes visible
- [ ] Admin API: POST /api/admin/content-moderation/sensitive-words → add new word
- [ ] Verify new word takes effect within 5 minutes (or call force_refresh)
- [ ] Variant test: "赌☆博" should also be caught
- [ ] Clean text passes through without issues

**Step 4: Final commit**

```bash
git add -A
git commit -m "test(content-filter): add comprehensive unit tests"
```

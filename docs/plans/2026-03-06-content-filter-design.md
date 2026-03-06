# Content Filter & Review System Design

Date: 2026-03-06

## Goal

Build a rule-based content filtering system to protect the Link2Ur platform from:
- Advertising / spam / agent promotion
- Contact info leakage (prevent off-platform transactions)
- Scam content
- Illegal / non-compliant content (porn, drugs, gambling, violence, etc.)
- Profanity / harassment

## Approach

Pure rule engine (Aho-Corasick keyword matching + regex contact detection) with a text normalizer layer to handle variants. No AI in v1.

## Processing Rules

| Level | Scope | Action |
|-------|-------|--------|
| `mask` | Contact info only | Auto-replace with `***`, publish normally |
| `review` | All other violations | Enter review queue, content hidden until admin approves |

## Violation Categories

| Category | Description | Level |
|----------|-------------|-------|
| `contact` | Phone, WeChat, QQ, email, URLs | `mask` |
| `ad` | Advertising, promotions, spam | `review` |
| `scam` | Fraud, phishing, pig-butchering | `review` |
| `agent` | Intermediary, proxy services | `review` |
| `porn` | Pornography, sexual content | `review` |
| `drugs` | Drugs, prohibited substances | `review` |
| `gambling` | Gambling | `review` |
| `violence` | Violence, terrorism | `review` |
| `illegal` | Other illegal (weapons, fake IDs, money laundering) | `review` |
| `profanity` | Profanity, insults, discrimination | `review` |

## Architecture

### Filter Engine (`backend/app/content_filter.py`)

```
ContentFilter (singleton, cached in memory)
├── TextNormalizer      # Text normalization (variant restoration)
├── ContactDetector     # Regex-based contact info detection
├── KeywordMatcher      # Aho-Corasick multi-pattern keyword matching
└── FilterResult        # Result: action(mask/review/pass), matched_words, cleaned_text
```

### Processing Flow

```
User submits content
    ↓
TextNormalizer (preprocess)
  ├── Remove zero-width chars / emoji / special symbols
  ├── Fullwidth → halfwidth
  ├── Traditional Chinese → Simplified Chinese
  ├── Chinese numerals / uppercase numerals → Arabic digits
  ├── Homophone mapping replacement (loaded from DB)
  ├── Merge consecutive spaces / separators
  └── Pinyin mapping for common violations
    ↓
Normalized text → ContactDetector + KeywordMatcher
    ↓
Also match against ORIGINAL text (union of both results)
    ↓
Combine results (strictest action wins):
  - Only mask hits → Replace contact info with ***, publish normally
  - Any review hit → Content enters review queue (stored but hidden)
  - No hits → Publish normally
```

### Contact Detection Patterns

- China mobile: `1[3-9]\d{9}` (with space/dash/dot variants)
- WeChat: `(wx|vx|wechat|微信|weixin|威信|薇芯|v信)\s*[:：]?\s*\w+`
- QQ: `(qq|QQ|扣扣|球球)\s*[:：]?\s*\d{5,12}`
- Email: standard email regex
- URLs: `https?://` and common short-link domains

### Variant Handling (TextNormalizer)

| Variant Type | Example | Method |
|-------------|---------|--------|
| Fullwidth → halfwidth | `ＱＱ` → `QQ` | Character mapping |
| Traditional → Simplified | `賭博` → `赌博` | OpenCC |
| Chinese numerals | `一三八` → `138` | Mapping table |
| Uppercase numerals | `壹叁捌` → `138` | Mapping table |
| Inserted symbols | `赌☆博` → `赌博` | Strip non-text chars, re-match |
| Zero-width chars | Invisible chars | Strip all |
| Emoji interference | `赌💰博` → `赌博` | Strip emoji |
| Spaces / separators | `赌 博` → `赌博` | Merge / strip |
| Homophones (DB) | `威信→微信`, `荒片→黄片` | DB homophone mapping table |
| Pinyin | `dubo`, `seqing` | Common violation pinyin mapping |
| Mixed alpha | `s色q情` → `色情` | Strip interleaved letters |

Homophone mapping table is maintained by admins via backend, loaded into Redis cache with 5-minute refresh.

## Database Schema

### `sensitive_words` — Keyword dictionary

| Column | Type | Description |
|--------|------|-------------|
| id | Integer PK | |
| word | String(100) | Keyword |
| category | String(20) | `ad`/`scam`/`agent`/`porn`/`drugs`/`gambling`/`violence`/`illegal`/`profanity`/`contact` |
| level | String(10) | `mask` / `review` |
| is_active | Boolean | Enabled flag |
| created_by | Integer FK | Admin who added |
| created_at | DateTime | |

### `homophone_mappings` — Variant mapping

| Column | Type | Description |
|--------|------|-------------|
| id | Integer PK | |
| variant | String(50) | Variant form (e.g. `威信`) |
| standard | String(50) | Standard form (e.g. `微信`) |
| is_active | Boolean | |

### `content_reviews` — Review queue

| Column | Type | Description |
|--------|------|-------------|
| id | Integer PK | |
| content_type | String(20) | `task`/`forum_post`/`forum_reply`/`profile`/`flea_market` |
| content_id | Integer | Related content ID |
| user_id | Integer FK | Submitter |
| original_text | Text | Original content |
| matched_words | JSON | List of matched keywords |
| status | String(10) | `pending`/`approved`/`rejected` |
| reviewed_by | Integer FK | Admin (nullable) |
| reviewed_at | DateTime | |
| created_at | DateTime | |

### `filter_logs` — Audit log

| Column | Type | Description |
|--------|------|-------------|
| id | Integer PK | |
| user_id | Integer FK | |
| content_type | String(20) | |
| action | String(10) | `mask`/`review`/`pass` |
| matched_words | JSON | |
| created_at | DateTime | |

### Existing table changes

`Task`, `ForumPost`, and flea market tables add `is_visible` column (Boolean, default=True). Content in review queue sets `is_visible=False`. Approved → `True`, rejected → stays `False`. All list query endpoints add `WHERE is_visible=True`.

## API Integration

### Filter call points (existing endpoints)

| Endpoint | File | Filtered fields |
|----------|------|-----------------|
| `POST /api/tasks-async` | `async_routers.py` | title, description |
| `POST /api/forums/posts` | `forum_routes.py` | title, content |
| `POST /api/forums/posts/{id}/replies` | `forum_routes.py` | content |
| `PUT /api/users/profile` | `routers.py` | bio/description |
| Flea market publish | TBD | title, description |

### Response behavior

- `pass` → Normal flow
- `mask` → Return masked content, store masked version in DB. Response includes `content_masked: true`
- `review` → Store content with `is_visible=false`. Response includes `under_review: true`. Frontend shows "Content submitted, pending review"

### Admin API (new)

```
# Sensitive word management
GET    /api/admin/sensitive-words           # List (paginated, filterable by category)
POST   /api/admin/sensitive-words           # Add
PUT    /api/admin/sensitive-words/{id}      # Update
DELETE /api/admin/sensitive-words/{id}      # Delete
POST   /api/admin/sensitive-words/batch     # Batch import

# Homophone mapping management
GET    /api/admin/homophone-mappings        # List
POST   /api/admin/homophone-mappings        # Add
DELETE /api/admin/homophone-mappings/{id}   # Delete

# Review queue
GET    /api/admin/content-reviews           # Pending review list
PUT    /api/admin/content-reviews/{id}      # Review (approve/reject)

# Filter logs
GET    /api/admin/filter-logs               # Log query
```

## Flutter Frontend Changes

Minimal changes — handle new response fields:

- `content_masked: true` → Show hint: "Part of content was automatically processed. Please use in-app chat for communication"
- `under_review: true` → Show hint: "Content submitted, pending review"
- User's own content list shows "Under Review" badge for pending items

## Caching Strategy

- Keyword dictionary: loaded from DB → cached in Redis → `ContentFilter` loads into memory (Aho-Corasick automaton)
- Refresh interval: 5 minutes, or immediate refresh via admin API trigger
- Homophone mappings: same caching strategy

## Dependencies

- `pyahocorasick` — Aho-Corasick algorithm for multi-pattern matching
- `opencc-python-reimplemented` — Traditional → Simplified Chinese conversion

# Service Bilingual Fields (service_name_zh / description_zh) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `service_name_zh` and `description_zh` columns to `TaskExpertService`, enable bidirectional auto-translation (zh↔en), and make Flutter display the correct language based on locale.

**Architecture:** Backend adds two new nullable columns + updates `_auto_translate_service()` to fill both `_en` and `_zh` fields. All service serialization endpoints include the new fields. Flutter model adds the fields and uses the existing `localizedString()` utility for locale-aware display.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/Dart (frontend), PostgreSQL (DB)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `backend/app/models.py:1619-1622` | Add `service_name_zh`, `description_zh` columns |
| Create | `backend/migrations/156_add_service_bilingual_zh_fields.sql` | DB migration |
| Modify | `backend/app/schemas.py:2319-2402` | Add `_zh` fields to 4 schemas + `TaskExpertServiceOut` + `ServiceBrowseItem` |
| Modify | `backend/app/personal_service_routes.py:21-57` | Bidirectional translate in `_auto_translate_service()` |
| Modify | `backend/app/personal_service_routes.py:60-81` | Add `_zh` fields to `_serialize_service()` |
| Modify | `backend/app/task_expert_routes.py:755-780` | Add auto-translate to expert service create |
| Modify | `backend/app/task_expert_routes.py:866-869` | Add auto-translate to expert service update |
| Modify | `backend/app/schemas.py:2460-2494` | Add `_en`/`_zh` to `TaskExpertServiceOut.from_orm()` |
| Modify | `backend/app/service_browse_routes.py:113-131` | Add `_en`/`_zh` to browse serialization |
| Modify | `link2ur/lib/data/models/task_expert.dart:309-495` | Add 4 fields + `displayServiceName()`/`displayDescription()` helpers |
| Modify | `link2ur/lib/features/task_expert/views/service_detail_view.dart` | Use locale-aware display |
| Modify | `link2ur/lib/features/task_expert/views/task_expert_detail_view.dart` | Use locale-aware display |
| Modify | `link2ur/lib/features/forum/views/skill_feed_view.dart` | Use locale-aware display |
| Modify | `link2ur/lib/features/personal_service/views/browse_services_view.dart` | Use locale-aware display (raw map) |
| Modify | `link2ur/lib/features/personal_service/views/my_services_view.dart` | Use locale-aware display (raw map) |

---

### Task 1: DB Migration — Add `service_name_zh` and `description_zh` columns

**Files:**
- Create: `backend/migrations/156_add_service_bilingual_zh_fields.sql`
- Modify: `backend/app/models.py:1619-1622`

- [ ] **Step 1: Create migration SQL**

```sql
-- 156_add_service_bilingual_zh_fields.sql
-- Add Chinese bilingual fields to task_expert_services

ALTER TABLE task_expert_services ADD COLUMN IF NOT EXISTS service_name_zh VARCHAR(200);
ALTER TABLE task_expert_services ADD COLUMN IF NOT EXISTS description_zh TEXT;

-- Backfill: for existing rows where service_name looks Chinese, copy to _zh
UPDATE task_expert_services
SET service_name_zh = service_name
WHERE service_name_zh IS NULL
  AND service_name ~ '[\u4e00-\u9fff]';

UPDATE task_expert_services
SET description_zh = description
WHERE description_zh IS NULL
  AND description ~ '[\u4e00-\u9fff]';

-- Backfill: for existing rows where service_name looks English, copy to _en if _en is null
UPDATE task_expert_services
SET service_name_en = service_name
WHERE service_name_en IS NULL
  AND service_name !~ '[\u4e00-\u9fff]'
  AND length(service_name) > 0;

UPDATE task_expert_services
SET description_en = description
WHERE description_en IS NULL
  AND description !~ '[\u4e00-\u9fff]'
  AND length(description) > 0;
```

- [ ] **Step 2: Add columns to SQLAlchemy model**

In `backend/app/models.py`, after line 1622 (`description_en`), add:

```python
    service_name_zh = Column(String(200), nullable=True)  # Chinese name
    description_zh = Column(Text, nullable=True)  # Chinese description
```

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/156_add_service_bilingual_zh_fields.sql backend/app/models.py
git commit -m "feat: add service_name_zh, description_zh columns to task_expert_services"
```

---

### Task 2: Update Schemas — Add `_zh` fields to all service schemas

**Files:**
- Modify: `backend/app/schemas.py`

- [ ] **Step 1: Add `_zh` fields to `TaskExpertServiceCreate`** (after `service_name_en` and `description_en`)

```python
class TaskExpertServiceCreate(BaseModel):
    service_name: str
    service_name_en: Optional[str] = None
    service_name_zh: Optional[str] = None
    description: str
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
    # ... rest unchanged
```

- [ ] **Step 2: Add `_zh` fields to `TaskExpertServiceUpdate`**

```python
class TaskExpertServiceUpdate(BaseModel):
    service_name: Optional[str] = None
    service_name_en: Optional[str] = None
    service_name_zh: Optional[str] = None
    description: Optional[str] = None
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
    # ... rest unchanged
```

- [ ] **Step 3: Add `_zh` fields to `PersonalServiceCreate`**

```python
class PersonalServiceCreate(BaseModel):
    service_name: str = Field(..., max_length=100)
    service_name_en: Optional[str] = Field(None, max_length=100)
    service_name_zh: Optional[str] = Field(None, max_length=100)
    description: str = Field(..., max_length=2000)
    description_en: Optional[str] = Field(None, max_length=2000)
    description_zh: Optional[str] = Field(None, max_length=2000)
    # ... rest unchanged
```

- [ ] **Step 4: Add `_zh` fields to `PersonalServiceUpdate`**

```python
class PersonalServiceUpdate(BaseModel):
    service_name: Optional[str] = Field(None, max_length=100)
    service_name_en: Optional[str] = Field(None, max_length=100)
    service_name_zh: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=2000)
    description_en: Optional[str] = Field(None, max_length=2000)
    description_zh: Optional[str] = Field(None, max_length=2000)
    # ... rest unchanged
```

- [ ] **Step 5: Add `_en`/`_zh` fields to `ServiceBrowseItem`**

```python
class ServiceBrowseItem(BaseModel):
    id: int
    service_name: str
    service_name_en: Optional[str] = None
    service_name_zh: Optional[str] = None
    description: str
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
    # ... rest unchanged
```

- [ ] **Step 6: Add `_en`/`_zh` fields to `TaskExpertServiceOut` + update `from_orm()`**

Add to the class fields (after `service_name` and `description`):

```python
    service_name_en: Optional[str] = None
    service_name_zh: Optional[str] = None
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
```

Add to `from_orm()` `data` dict:

```python
            "service_name_en": getattr(obj, "service_name_en", None),
            "service_name_zh": getattr(obj, "service_name_zh", None),
            "description_en": getattr(obj, "description_en", None),
            "description_zh": getattr(obj, "description_zh", None),
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add service_name_zh, description_zh to all service schemas"
```

---

### Task 3: Backend — Bidirectional auto-translate in `_auto_translate_service()`

**Files:**
- Modify: `backend/app/personal_service_routes.py:21-81`

- [ ] **Step 1: Rewrite `_auto_translate_service()` to return 4 fields**

Replace the function (lines 21-57) with:

```python
async def _auto_translate_service(
    name: str,
    description: str | None,
    name_en: str | None = None,
    name_zh: str | None = None,
    description_en: str | None = None,
    description_zh: str | None = None,
) -> tuple[str | None, str | None, str | None, str | None]:
    """
    Auto-detect language and translate service name/description bidirectionally.
    - Chinese input → fill _zh from input, translate to _en
    - English input → fill _en from input, translate to _zh
    Returns (name_en, name_zh, description_en, description_zh).
    """
    from app.utils.bilingual_helper import _translate_with_encoding_protection
    from app.translation_manager import get_translation_manager

    lang = detect_language_simple(name)

    if lang == 'zh':
        if not name_zh:
            name_zh = name
        if not name_en:
            tm = get_translation_manager()
            name_en = await _translate_with_encoding_protection(
                tm, text=name, target_lang='en', source_lang='zh-CN', max_retries=2,
            )
        if description:
            if not description_zh:
                description_zh = description
            if not description_en:
                tm = get_translation_manager()
                description_en = await _translate_with_encoding_protection(
                    tm, text=description, target_lang='en', source_lang='zh-CN', max_retries=2,
                )
    else:
        if not name_en:
            name_en = name
        if not name_zh:
            tm = get_translation_manager()
            name_zh = await _translate_with_encoding_protection(
                tm, text=name, target_lang='zh-CN', source_lang='en', max_retries=2,
            )
        if description:
            if not description_en:
                description_en = description
            if not description_zh:
                tm = get_translation_manager()
                description_zh = await _translate_with_encoding_protection(
                    tm, text=description, target_lang='zh-CN', source_lang='en', max_retries=2,
                )

    return name_en, name_zh, description_en, description_zh
```

- [ ] **Step 2: Update `_serialize_service()` to include `_zh` fields**

```python
def _serialize_service(s: models.TaskExpertService) -> dict:
    return {
        "id": s.id,
        "service_name": s.service_name,
        "service_name_en": s.service_name_en,
        "service_name_zh": s.service_name_zh,
        "description": s.description,
        "description_en": s.description_en,
        "description_zh": s.description_zh,
        # ... rest unchanged
    }
```

- [ ] **Step 3: Update `create_personal_service` to pass/receive `_zh` fields**

```python
    service_name_en = data.service_name_en
    service_name_zh = data.service_name_zh
    description_en = data.description_en
    description_zh = data.description_zh
    try:
        service_name_en, service_name_zh, description_en, description_zh = await _auto_translate_service(
            data.service_name, data.description,
            service_name_en, service_name_zh, description_en, description_zh,
        )
    except Exception as e:
        logger.warning(f"Service auto-translate failed: {e}")

    new_service = models.TaskExpertService(
        # ... existing fields ...
        service_name_en=service_name_en,
        service_name_zh=service_name_zh,
        description_en=description_en,
        description_zh=description_zh,
        # ... rest ...
    )
```

- [ ] **Step 4: Update `update_personal_service` to pass/receive `_zh` fields**

```python
    if 'service_name' in update_data or 'description' in update_data:
        try:
            name_en, name_zh, desc_en, desc_zh = await _auto_translate_service(
                new_name, new_desc,
                update_data.get('service_name_en'),
                update_data.get('service_name_zh'),
                update_data.get('description_en'),
                update_data.get('description_zh'),
            )
            update_data['service_name_en'] = name_en
            update_data['service_name_zh'] = name_zh
            update_data['description_en'] = desc_en
            update_data['description_zh'] = desc_zh
        except Exception as e:
            logger.warning(f"Service auto-translate on update failed: {e}")
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/personal_service_routes.py
git commit -m "feat: bidirectional auto-translate for personal services (zh↔en)"
```

---

### Task 4: Backend — Add auto-translate to expert service routes

**Files:**
- Modify: `backend/app/task_expert_routes.py:729-780, 828-870`

- [ ] **Step 1: Add auto-translate to `create_service` (expert)**

After line 753 (validation block), before `new_service = ...` (line 755), add:

```python
    # Auto-translate name and description
    service_name_en = service_data.service_name_en
    service_name_zh = service_data.service_name_zh
    description_en = service_data.description_en
    description_zh = service_data.description_zh
    try:
        from app.personal_service_routes import _auto_translate_service
        service_name_en, service_name_zh, description_en, description_zh = await _auto_translate_service(
            service_data.service_name, service_data.description,
            service_name_en, service_name_zh, description_en, description_zh,
        )
    except Exception as e:
        logger.warning(f"Expert service auto-translate failed: {e}")
```

Then add to the `models.TaskExpertService(...)` constructor:

```python
        service_name_en=service_name_en,
        service_name_zh=service_name_zh,
        description_en=description_en,
        description_zh=description_zh,
```

- [ ] **Step 2: Add auto-translate to `update_service` (expert)**

After the `service_data.description` assignment (line 869), add:

```python
    # Auto-translate if name or description changed
    if service_data.service_name is not None or service_data.description is not None:
        try:
            from app.personal_service_routes import _auto_translate_service
            name_en, name_zh, desc_en, desc_zh = await _auto_translate_service(
                service.service_name, service.description,
                service_data.service_name_en,
                service_data.service_name_zh,
                service_data.description_en,
                service_data.description_zh,
            )
            service.service_name_en = name_en
            service.service_name_zh = name_zh
            service.description_en = desc_en
            service.description_zh = desc_zh
        except Exception as e:
            logger.warning(f"Expert service auto-translate on update failed: {e}")
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_expert_routes.py
git commit -m "feat: add bidirectional auto-translate to expert service create/update"
```

---

### Task 5: Backend — Add bilingual fields to service browse serialization

**Files:**
- Modify: `backend/app/service_browse_routes.py:113-131`

- [ ] **Step 1: Add `_en`/`_zh` fields to browse item serialization**

In the `item = { ... }` dict (around line 113-131), add after `"description"`:

```python
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
```

- [ ] **Step 2: Add `_en`/`_zh` to text search filter**

Update the search filter (lines 39-44) to also search bilingual fields:

```python
    if q:
        search = f"%{q}%"
        base_filter = base_filter.where(
            or_(
                models.TaskExpertService.service_name.ilike(search),
                models.TaskExpertService.service_name_en.ilike(search),
                models.TaskExpertService.service_name_zh.ilike(search),
                models.TaskExpertService.description.ilike(search),
                models.TaskExpertService.description_en.ilike(search),
                models.TaskExpertService.description_zh.ilike(search),
            )
        )
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/service_browse_routes.py
git commit -m "feat: include bilingual fields in service browse + search"
```

---

### Task 6: Flutter — Add bilingual fields to `TaskExpertService` model

**Files:**
- Modify: `link2ur/lib/data/models/task_expert.dart:309-495`

- [ ] **Step 1: Add 4 new fields to constructor and class body**

Add after `serviceName` field (line 315/352):

```dart
    this.serviceNameEn,
    this.serviceNameZh,
```

Add after `description` field (line 316/353):

```dart
    this.descriptionEn,
    this.descriptionZh,
```

Field declarations (after line 353):

```dart
  final String? serviceNameEn;
  final String? serviceNameZh;
  final String? descriptionEn;
  final String? descriptionZh;
```

- [ ] **Step 2: Add `displayServiceName()` and `displayDescription()` helpers**

Add after the `hasApplied` getter (line 410), using the existing `localizedString` utility:

```dart
  /// Locale-aware service name
  String displayServiceName(Locale locale) =>
      localizedString(serviceNameZh, serviceNameEn, serviceName, locale);

  /// Locale-aware description
  String displayDescription(Locale locale) =>
      localizedString(descriptionZh, descriptionEn, description, locale);
```

Add import at top of file (if not already present):

```dart
import 'package:link2ur/core/utils/localized_string.dart';
```

- [ ] **Step 3: Update `fromJson`**

Add after `serviceName` parsing (line 418):

```dart
      serviceNameEn: json['service_name_en'] as String?,
      serviceNameZh: json['service_name_zh'] as String?,
```

Add after `description` parsing (line 419):

```dart
      descriptionEn: json['description_en'] as String?,
      descriptionZh: json['description_zh'] as String?,
```

- [ ] **Step 4: Update `toJson`**

Add after `'service_name'` (line 465):

```dart
      'service_name_en': serviceNameEn,
      'service_name_zh': serviceNameZh,
```

Add after `'description'` (line 466):

```dart
      'description_en': descriptionEn,
      'description_zh': descriptionZh,
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/models/task_expert.dart
git commit -m "feat: add bilingual fields + display helpers to TaskExpertService model"
```

---

### Task 7: Flutter — Update UI views to use locale-aware display

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/service_detail_view.dart`
- Modify: `link2ur/lib/features/task_expert/views/task_expert_detail_view.dart`
- Modify: `link2ur/lib/features/forum/views/skill_feed_view.dart`
- Modify: `link2ur/lib/features/personal_service/views/browse_services_view.dart`
- Modify: `link2ur/lib/features/personal_service/views/my_services_view.dart`

- [ ] **Step 1: Update `service_detail_view.dart`**

Replace `service.serviceName` (line 468) with:

```dart
service.displayServiceName(Localizations.localeOf(context))
```

Replace `service.description` references (lines 521-534) — wherever `service.description` is used for display text, use:

```dart
service.displayDescription(Localizations.localeOf(context))
```

Keep `.isNotEmpty` checks on the original `service.description` (since if any language has content, it should show).

- [ ] **Step 2: Update `task_expert_detail_view.dart`**

Replace `service.serviceName` (line 1093) with:

```dart
service.displayServiceName(Localizations.localeOf(context))
```

Replace `service.description` (lines 1129-1132) for display with:

```dart
service.displayDescription(Localizations.localeOf(context))
```

- [ ] **Step 3: Update `skill_feed_view.dart`**

Replace `service.serviceName` (line 404) with:

```dart
service.displayServiceName(Localizations.localeOf(context))
```

Replace `service.description` (lines 409-412) for display with:

```dart
service.displayDescription(Localizations.localeOf(context))
```

- [ ] **Step 4: Update `browse_services_view.dart`** (uses raw Map)

Replace the name/description extraction (lines 343-344) with locale-aware selection:

```dart
    final locale = Localizations.localeOf(context);
    final nameZh = service['service_name_zh'] as String?;
    final nameEn = service['service_name_en'] as String?;
    final nameFallback = (service['service_name'] as String?) ?? '';
    final name = localizedString(nameZh, nameEn, nameFallback, locale);

    final descZh = service['description_zh'] as String?;
    final descEn = service['description_en'] as String?;
    final descFallback = (service['description'] as String?) ?? '';
    final description = localizedString(descZh, descEn, descFallback, locale);
```

Add import:

```dart
import 'package:link2ur/core/utils/localized_string.dart';
```

- [ ] **Step 5: Update `my_services_view.dart`** (uses raw Map)

Replace the name extraction (line 363) with locale-aware selection:

```dart
    final locale = Localizations.localeOf(context);
    final name = localizedString(
      service['service_name_zh'] as String?,
      service['service_name_en'] as String?,
      (service['service_name'] as String?) ?? '',
      locale,
    );
```

Add import:

```dart
import 'package:link2ur/core/utils/localized_string.dart';
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/
git commit -m "feat: use locale-aware service name/description display across all views"
```

---

### Task 8: Verify — Run Flutter analyze

- [ ] **Step 1: Run analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```

Expected: No new errors or warnings from the changes.

- [ ] **Step 2: Fix any issues found, then commit if needed**

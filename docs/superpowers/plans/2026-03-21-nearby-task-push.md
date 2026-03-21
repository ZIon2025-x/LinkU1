# Nearby Task Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Push a notification when a user opens the app and there's a new task within 1km.

**Architecture:** App startup triggers GPS upload → backend upserts location, checks 6h cooldown, queries nearby open tasks via bounding box + Haversine, pushes one notification via existing push service. User controls feature via "nearby push" toggle in preferences.

**Tech Stack:** FastAPI, SQLAlchemy, PostgreSQL, Haversine (Python), Flutter BLoC, Geolocator, existing APNs/FCM push service.

**Spec:** `docs/superpowers/specs/2026-03-20-nearby-task-push-design.md`

---

## File Structure

**Backend — New:**
- `backend/app/services/nearby_task_service.py` — Core logic: find nearby task + send push
- `backend/migrations/123_add_nearby_push_tables.sql` — New tables + preference column

**Backend — Modify:**
- `backend/app/models.py` — Add `UserLocation`, `NearbyTaskPush` models + `nearby_push_enabled` to `UserProfilePreference`
- `backend/app/routes/user_profile.py` — Add `POST /location` endpoint + update preference schema/responses
- `backend/app/services/user_profile_service.py` — Add `nearby_push_enabled` to upsert_preference keys
- `backend/app/push_notification_templates.py` — Add `nearby_task` template
- `backend/app/celery_app.py` — Add cleanup beat schedule
- `backend/app/celery_tasks.py` — Add cleanup task function
- `backend/app/task_scheduler.py` — Register cleanup fallback task

**Flutter — Modify:**
- `link2ur/lib/data/models/user_profile.dart` — Add `nearbyPushEnabled` field
- `link2ur/lib/data/repositories/user_profile_repository.dart` — Add `uploadLocation()` method
- `link2ur/lib/features/user_profile/views/preference_edit_view.dart` — Add toggle switch
- `link2ur/lib/data/services/push_notification_service.dart` — Add `nearby_task` navigation + location upload on init
- `link2ur/lib/core/constants/api_endpoints.dart` — Add location endpoint
- `link2ur/lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb` — Add l10n keys

---

## Task 1: Database Migration + Models

**Files:**
- Create: `backend/migrations/123_add_nearby_push_tables.sql`
- Modify: `backend/app/models.py`

- [ ] **Step 1: Create migration SQL**

```sql
-- 用户位置表
CREATE TABLE IF NOT EXISTS user_locations (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_user_locations_user_id ON user_locations(user_id);

-- 附近任务推送记录（防重复）
CREATE TABLE IF NOT EXISTS nearby_task_pushes (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    pushed_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_nearby_push_user_task UNIQUE (user_id, task_id)
);

CREATE INDEX IF NOT EXISTS ix_nearby_task_pushes_user_pushed ON nearby_task_pushes(user_id, pushed_at);

-- 偏好表新增字段
ALTER TABLE user_profile_preferences ADD COLUMN IF NOT EXISTS nearby_push_enabled BOOLEAN NOT NULL DEFAULT FALSE;
```

- [ ] **Step 2: Add SQLAlchemy models to `models.py`**

Append after the `UserDemand` class (around line 3607):

```python
class UserLocation(Base):
    __tablename__ = "user_locations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)

    user = relationship("User", backref="location")

    __table_args__ = (
        Index("ix_user_locations_user_id", "user_id"),
    )


class NearbyTaskPush(Base):
    __tablename__ = "nearby_task_pushes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    pushed_at = Column(DateTime(timezone=True), default=get_utc_time)

    __table_args__ = (
        UniqueConstraint("user_id", "task_id", name="uq_nearby_push_user_task"),
        Index("ix_nearby_task_pushes_user_pushed", "user_id", "pushed_at"),
    )
```

- [ ] **Step 3: Add `nearby_push_enabled` to `UserProfilePreference`**

In `models.py`, add after the `preferred_helper_types` column (around line 3556):

```python
    nearby_push_enabled = Column(Boolean, default=False, server_default="false", nullable=False)
```

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/123_add_nearby_push_tables.sql backend/app/models.py
git commit -m "feat: add nearby task push tables and models"
```

---

## Task 2: Push Notification Template

**Files:**
- Modify: `backend/app/push_notification_templates.py`

- [ ] **Step 1: Add `nearby_task` template**

Add to the `PUSH_NOTIFICATION_TEMPLATES` dict:

```python
    "nearby_task": {
        "en": {
            "title": "New task nearby",
            "body_template": "{task_title}, near you"
        },
        "zh": {
            "title": "附近有新任务",
            "body_template": "{task_title}，就在你附近"
        }
    },
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/push_notification_templates.py
git commit -m "feat: add nearby_task push notification template"
```

---

## Task 3: Nearby Task Service (Core Logic)

**Files:**
- Create: `backend/app/services/nearby_task_service.py`

- [ ] **Step 1: Create the service**

```python
"""Nearby task push: find tasks within 1km and send push notification."""
import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import and_, select, func
from app.models import (
    Task, UserLocation, NearbyTaskPush, UserProfilePreference, TaskApplication
)
from app.utils.location_utils import calculate_distance

logger = logging.getLogger(__name__)

COOLDOWN_HOURS = 6
RADIUS_KM = 1.0
TASK_FRESHNESS_DAYS = 7
# Approximate degree offsets for 1km bounding box
LAT_OFFSET = 0.009  # ~1km in latitude
LON_OFFSET = 0.013  # ~1km in longitude (at ~51° latitude, UK)


def upsert_user_location(db: Session, user_id: str, latitude: float, longitude: float) -> UserLocation:
    """Create or update user's last known location."""
    loc = db.query(UserLocation).filter(UserLocation.user_id == user_id).first()
    if not loc:
        loc = UserLocation(user_id=user_id, latitude=latitude, longitude=longitude)
        db.add(loc)
    else:
        loc.latitude = latitude
        loc.longitude = longitude
        loc.updated_at = datetime.now(timezone.utc)
    db.flush()
    return loc


def check_cooldown(db: Session, user_id: str) -> bool:
    """Return True if user can receive a push (cooldown expired)."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=COOLDOWN_HOURS)
    latest = db.query(NearbyTaskPush.pushed_at).filter(
        NearbyTaskPush.user_id == user_id,
        NearbyTaskPush.pushed_at >= cutoff
    ).order_by(NearbyTaskPush.pushed_at.desc()).first()
    return latest is None


def find_nearest_task(db: Session, user_id: str, lat: float, lon: float) -> Task | None:
    """Find the most recently posted open task within 1km, not yet pushed to this user."""
    freshness_cutoff = datetime.now(timezone.utc) - timedelta(days=TASK_FRESHNESS_DAYS)

    # Bounding box pre-filter (uses B-tree index on lat/lon)
    candidates = db.query(Task).filter(
        Task.latitude.isnot(None),
        Task.longitude.isnot(None),
        Task.status == "open",
        Task.created_at >= freshness_cutoff,
        Task.poster_id != user_id,
        Task.latitude.between(lat - LAT_OFFSET, lat + LAT_OFFSET),
        Task.longitude.between(lon - LON_OFFSET, lon + LON_OFFSET),
        ~Task.id.in_(
            select(NearbyTaskPush.task_id).where(NearbyTaskPush.user_id == user_id)
        ),
        ~Task.id.in_(
            select(TaskApplication.task_id).where(TaskApplication.applicant_id == user_id)
        ),
    ).order_by(Task.created_at.desc()).limit(10).all()

    # Haversine precision filter
    for task in candidates:
        dist = calculate_distance(lat, lon, float(task.latitude), float(task.longitude))
        if dist <= RADIUS_KM:
            return task
    return None


def record_push(db: Session, user_id: str, task_id: int):
    """Record that a task was pushed to a user."""
    push = NearbyTaskPush(user_id=user_id, task_id=task_id)
    db.add(push)
    db.flush()


def process_nearby_push(db: Session, user_id: str, latitude: float, longitude: float) -> bool:
    """Main entry point: check eligibility, find task, send push. Returns True if pushed."""
    # 1. Check preference
    pref = db.query(UserProfilePreference).filter(
        UserProfilePreference.user_id == user_id
    ).first()
    if not pref or not pref.nearby_push_enabled:
        return False

    # 2. Check cooldown
    if not check_cooldown(db, user_id):
        return False

    # 3. Find nearby task
    task = find_nearest_task(db, user_id, latitude, longitude)
    if not task:
        return False

    # 4. Send push
    try:
        from app.push_notification_service import send_push_notification
        task_title = task.title_zh or task.title_en or task.title or ""
        send_push_notification(
            db=db,
            user_id=user_id,
            notification_type="nearby_task",
            template_vars={"task_title": task_title},
            data={"type": "nearby_task", "task_id": str(task.id)},
        )
        record_push(db, user_id, task.id)
        logger.info(f"Nearby push sent: user={user_id}, task={task.id}")
        return True
    except Exception as e:
        logger.warning(f"Nearby push failed: user={user_id}, error={e}")
        return False


def cleanup_old_pushes(db: Session, days: int = 30):
    """Delete push records older than N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    deleted = db.query(NearbyTaskPush).filter(
        NearbyTaskPush.pushed_at < cutoff
    ).delete(synchronize_session=False)
    logger.info(f"Cleaned up {deleted} old nearby push records")
    return deleted
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/services/nearby_task_service.py
git commit -m "feat: add nearby task service with location matching and push"
```

---

## Task 4: Backend API Endpoint + Preference Updates

**Files:**
- Modify: `backend/app/routes/user_profile.py`
- Modify: `backend/app/services/user_profile_service.py`

- [ ] **Step 1: Update `user_profile_service.py` — add `nearby_push_enabled` to upsert keys**

In the `upsert_preference` function, add `"nearby_push_enabled"` to the key list:

```python
    for key in ["mode", "duration_type", "reward_preference",
                "preferred_time_slots", "preferred_categories", "preferred_helper_types",
                "nearby_push_enabled"]:
```

- [ ] **Step 2: Update `user_profile.py` — add to PreferenceUpdate schema**

Add after the `preferred_helper_types` field in `PreferenceUpdate`:

```python
    nearby_push_enabled: bool | None = None
```

- [ ] **Step 3: Update `user_profile.py` — add to GET /preferences response**

In the `get_preferences` endpoint, add to both the default response and the pref response:

Default (no pref record):
```python
    return {"mode": "both", ..., "preferred_helper_types": [], "nearby_push_enabled": False}
```

Has record:
```python
    "nearby_push_enabled": pref.nearby_push_enabled or False,
```

- [ ] **Step 4: Update `user_profile.py` — add to GET /summary response**

In the summary endpoint's pref_data building, add to both branches:

Default: add `"nearby_push_enabled": False`
Has record: add `"nearby_push_enabled": pref.nearby_push_enabled or False,`

- [ ] **Step 5: Add `POST /api/profile/location` endpoint**

Add to `user_profile.py`:

```python
from pydantic import field_validator

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

    @field_validator('latitude')
    @classmethod
    def validate_lat(cls, v):
        if not -90 <= v <= 90:
            raise ValueError('Latitude must be between -90 and 90')
        return v

    @field_validator('longitude')
    @classmethod
    def validate_lon(cls, v):
        if not -180 <= v <= 180:
            raise ValueError('Longitude must be between -180 and 180')
        return v


@router.post("/location")
async def upload_location(
    data: LocationUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    from app.services.nearby_task_service import upsert_user_location, process_nearby_push
    upsert_user_location(db, current_user.id, data.latitude, data.longitude)
    db.commit()
    # Async-safe: push runs in same request but failure won't affect response
    try:
        process_nearby_push(db, current_user.id, data.latitude, data.longitude)
        db.commit()
    except Exception:
        db.rollback()
    return {"message": "ok"}
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/user_profile.py backend/app/services/user_profile_service.py
git commit -m "feat: add location upload endpoint and nearby_push_enabled preference"
```

---

## Task 5: Scheduled Cleanup Task

**Files:**
- Modify: `backend/app/celery_app.py`
- Modify: `backend/app/celery_tasks.py`
- Modify: `backend/app/task_scheduler.py`

- [ ] **Step 1: Add Celery beat schedule entry in `celery_app.py`**

Add to `beat_schedule` dict:

```python
    # 清理过期附近任务推送记录 - 每天凌晨2:30执行
    'cleanup-nearby-task-pushes': {
        'task': 'app.celery_tasks.cleanup_nearby_task_pushes_task',
        'schedule': crontab(hour=2, minute=30),
    },
```

- [ ] **Step 2: Add Celery task function in `celery_tasks.py`**

Add near the end of the file (before the user profile tasks section):

```python
@celery_app.task(name='app.celery_tasks.cleanup_nearby_task_pushes_task', bind=True, max_retries=2)
def cleanup_nearby_task_pushes_task(self):
    """清理30天前的附近任务推送记录"""
    task_name = "cleanup_nearby_task_pushes"
    lock_key = f"celery_lock:{task_name}"
    lock_value = get_redis_distributed_lock(lock_key, expire_seconds=300)
    if not lock_value:
        return {"status": "skipped", "reason": "lock_held"}

    import time
    start_time = time.time()
    db = SessionLocal()
    try:
        from app.services.nearby_task_service import cleanup_old_pushes
        deleted = cleanup_old_pushes(db, days=30)
        db.commit()
        duration = time.time() - start_time
        logger.info(f"附近推送记录清理完成: 删除 {deleted} 条 (耗时: {duration:.2f}秒)")
        _record_task_metrics(task_name, "success", duration)
        return {"status": "success", "deleted": deleted}
    except Exception as e:
        db.rollback()
        duration = time.time() - start_time
        logger.error(f"附近推送记录清理失败: {e}", exc_info=True)
        _record_task_metrics(task_name, "error", duration)
        raise self.retry(exc=e, countdown=120)
    finally:
        db.close()
        release_redis_distributed_lock(lock_key, lock_value)
```

- [ ] **Step 3: Register in TaskScheduler fallback in `task_scheduler.py`**

Add before the user profile tasks section:

```python
    # 清理附近任务推送记录 - 每天执行
    def cleanup_nearby_pushes():
        try:
            from app.services.nearby_task_service import cleanup_old_pushes
            db = SessionLocal()
            try:
                cleanup_old_pushes(db, days=30)
                db.commit()
                logger.info("附近推送记录清理完成")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"附近推送记录清理失败: {e}")

    scheduler.register_task(
        'cleanup_nearby_pushes',
        cleanup_nearby_pushes,
        interval_seconds=86400,
        description="清理过期附近任务推送记录"
    )
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/celery_app.py backend/app/celery_tasks.py backend/app/task_scheduler.py
git commit -m "feat: add scheduled cleanup for nearby task push records"
```

---

## Task 6: Flutter Model + Repository + Endpoint

**Files:**
- Modify: `link2ur/lib/data/models/user_profile.dart`
- Modify: `link2ur/lib/data/repositories/user_profile_repository.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Add `nearbyPushEnabled` to `UserProfilePreference` model**

Add field, update constructor, fromJson, toJson, copyWith, props:

```dart
class UserProfilePreference extends Equatable {
  final String mode;
  final String durationType;
  final String rewardPreference;
  final List<String> preferredTimeSlots;
  final List<int> preferredCategories;
  final List<String> preferredHelperTypes;
  final bool nearbyPushEnabled;

  const UserProfilePreference({
    this.mode = 'both',
    this.durationType = 'both',
    this.rewardPreference = 'no_preference',
    this.preferredTimeSlots = const [],
    this.preferredCategories = const [],
    this.preferredHelperTypes = const [],
    this.nearbyPushEnabled = false,
  });
```

In `fromJson`: add `nearbyPushEnabled: json['nearby_push_enabled'] as bool? ?? false,`

In `toJson`: add `'nearby_push_enabled': nearbyPushEnabled,`

In `copyWith`: add parameter `bool? nearbyPushEnabled,` and `nearbyPushEnabled: nearbyPushEnabled ?? this.nearbyPushEnabled,`

In `props`: add `nearbyPushEnabled`

- [ ] **Step 2: Add API endpoint constant**

In `api_endpoints.dart`, add:

```dart
  static const String profileLocation = '/api/profile/location';
```

- [ ] **Step 3: Add `uploadLocation()` to repository**

In `user_profile_repository.dart`, add:

```dart
  Future<void> uploadLocation(double latitude, double longitude) async {
    final response = await _apiService.post(
      ApiEndpoints.profileLocation,
      data: {'latitude': latitude, 'longitude': longitude},
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to upload location');
    }
  }
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/user_profile.dart link2ur/lib/data/repositories/user_profile_repository.dart link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add nearbyPushEnabled to model and uploadLocation to repository"
```

---

## Task 7: Flutter Preference UI — Toggle Switch

**Files:**
- Modify: `link2ur/lib/features/user_profile/views/preference_edit_view.dart`
- Modify: `link2ur/lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`

- [ ] **Step 1: Add l10n keys**

In `app_zh.arb`:
```json
  "nearbyPushEnabled": "附近任务提醒",
  "nearbyPushDescription": "有新任务在附近时通知你"
```

In `app_en.arb`:
```json
  "nearbyPushEnabled": "Nearby Task Alerts",
  "nearbyPushDescription": "Get notified when new tasks are posted nearby"
```

In `app_zh_Hant.arb`:
```json
  "nearbyPushEnabled": "附近任務提醒",
  "nearbyPushDescription": "有新任務在附近時通知你"
```

- [ ] **Step 2: Run `flutter gen-l10n`**

- [ ] **Step 3: Add toggle to `preference_edit_view.dart`**

In `_PreferenceEditContentState`, add state variable:
```dart
  late bool _nearbyPushEnabled;
```

In `initState()`:
```dart
    _nearbyPushEnabled = widget.currentPreference?.nearbyPushEnabled ?? false;
```

In `_save()`, add to the preferences map:
```dart
    'nearby_push_enabled': _nearbyPushEnabled,
```

In the build method, add a section after the time slots section (before the save button):

```dart
  // 附近任务提醒
  _PreferenceSection(
    title: context.l10n.nearbyPushEnabled,
    description: context.l10n.nearbyPushDescription,
    child: Switch.adaptive(
      value: _nearbyPushEnabled,
      activeColor: AppColors.primary,
      onChanged: (val) async {
        if (val) {
          // Request location permission when enabling
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            final result = await Geolocator.requestPermission();
            if (result == LocationPermission.denied ||
                result == LocationPermission.deniedForever) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('需要定位权限才能开启附近任务提醒')),
                );
              }
              return;
            }
          }
        }
        setState(() => _nearbyPushEnabled = val);
      },
    ),
  ),
  AppSpacing.vMd,
```

Add import at top:
```dart
import 'package:geolocator/geolocator.dart';
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/user_profile/views/preference_edit_view.dart link2ur/lib/l10n/app_en.arb link2ur/lib/l10n/app_zh.arb link2ur/lib/l10n/app_zh_Hant.arb
git commit -m "feat: add nearby push toggle in preference edit view"
```

---

## Task 8: Flutter Location Upload on App Start

**Files:**
- Modify: `link2ur/lib/data/services/push_notification_service.dart`

- [ ] **Step 1: Add location upload method**

Add a new public method to `PushNotificationService`:

```dart
  /// Upload location for nearby task push (called on app start).
  /// Checks local cooldown (6h) and nearby_push_enabled before uploading.
  Future<void> checkAndUploadLocation() async {
    try {
      // Check if feature is enabled (read from local cache)
      final enabled = StorageService.instance.getBool('nearby_push_enabled') ?? false;
      if (!enabled) return;

      // Check 6h cooldown
      final lastUpload = StorageService.instance.getString('last_location_upload');
      if (lastUpload != null) {
        final lastTime = DateTime.tryParse(lastUpload);
        if (lastTime != null &&
            DateTime.now().difference(lastTime).inHours < 6) {
          return;
        }
      }

      // Check location permission (don't request, just check)
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Save battery
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Upload
      await _apiService?.post('/api/profile/location', data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      // Save timestamp
      await StorageService.instance.setString(
        'last_location_upload',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Silent failure — never block app startup
      AppLogger.warning('Location upload failed: $e');
    }
  }
```

- [ ] **Step 2: Add `nearby_task` to navigation routing**

In `_navigateByNotificationType()`, add a new case:

```dart
      case 'nearby_task':
        final taskId = data['task_id'] ?? data['related_id'];
        if (taskId != null) {
          _router!.push('/tasks/$taskId');
        }
        break;
```

- [ ] **Step 3: Add `nearby_task` to channel mapping**

In `_channelForType()`, add `'nearby_task'` to the tasks channel list.

- [ ] **Step 4: Call location upload from init**

In the `init()` method, after existing initialization, add:

```dart
    // Check nearby task location upload (non-blocking)
    unawaited(checkAndUploadLocation());
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/services/push_notification_service.dart
git commit -m "feat: add location upload on app start and nearby_task push handling"
```

---

## Task 9: Sync Nearby Push Setting to Local Storage

**Files:**
- Modify: `link2ur/lib/features/user_profile/bloc/user_profile_bloc.dart`

- [ ] **Step 1: Cache `nearby_push_enabled` when preferences are loaded**

In `_onLoadSummary` and `_onUpdatePreferences`, after emitting the loaded state, sync to local storage:

```dart
      // Cache nearby push setting for app startup check
      if (summary.preference.nearbyPushEnabled) {
        StorageService.instance.setBool('nearby_push_enabled', true);
      } else {
        StorageService.instance.setBool('nearby_push_enabled', false);
      }
```

Add import: `import '../../../data/services/storage_service.dart';`

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/user_profile/bloc/user_profile_bloc.dart
git commit -m "feat: cache nearby_push_enabled to local storage for app startup check"
```

---

## Task 10: Update Tests

**Files:**
- Modify: `link2ur/test/features/user_profile/bloc/user_profile_bloc_test.dart`

- [ ] **Step 1: Update test fixtures**

Update the `testSummary` fixture to include `nearbyPushEnabled`:

```dart
    final testSummary = UserProfileSummary(
      capabilities: [...],
      preference: const UserProfilePreference(mode: 'online', nearbyPushEnabled: false),
      ...
    );
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/features/user_profile/
```

- [ ] **Step 3: Run analyze**

```bash
flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/test/features/user_profile/
git commit -m "test: update user profile tests for nearby push feature"
```

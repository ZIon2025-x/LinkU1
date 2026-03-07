# Registration Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the broken registration flow so that email verification code is validated server-side, the response includes session data for auto-login, and all error messages are localized.

**Architecture:** Backend `/api/users/register` validates the 6-digit email code (already stored in Redis by `/api/secure-auth/send-verification-code`), creates a verified user, creates a session, and returns `{session_id, user, refresh_token}` matching the login response format. Frontend passes `verification_code` + `agreed_to_terms` in the request and maps 7 new backend error codes via ErrorLocalizer.

**Tech Stack:** Python/FastAPI backend, Flutter/Dart frontend with BLoC pattern, Redis for verification codes, ARB files for i18n.

---

### Task 1: Backend — Add `verification_code` to UserCreate schema

**Files:**
- Modify: `backend/app/schemas.py:16-29`

**Step 1: Add field**

In `backend/app/schemas.py`, add `verification_code` field to `UserCreate`:

```python
class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    avatar: Optional[str] = ""
    agreed_to_terms: Optional[bool] = False
    terms_agreed_at: Optional[str] = None
    invitation_code: Optional[str] = None
    phone_verification_code: Optional[str] = None
    verification_code: Optional[str] = None  # Email verification code (6 digits, stored in Redis)

    @model_validator(mode='after')
    def check_contact_method(self):
        """至少需要提供一种联系方式（邮箱或手机号）"""
        if not self.email and not self.phone:
            raise ValueError('至少需要提供邮箱或手机号中的一种')
        return self
```

Only one line added: `verification_code: Optional[str] = None`.

**Step 2: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat(auth): add verification_code field to UserCreate schema"
```

---

### Task 2: Backend — Rewrite register() endpoint

**Files:**
- Modify: `backend/app/routers.py:274-522`

This is the largest change. The register endpoint needs to:
1. Validate email verification code via `verify_and_delete_code()`
2. Create user with `is_verified=1`
3. Create session + return login-compatible response
4. Use English error codes instead of Chinese strings

**Step 1: Replace the register function**

Replace `backend/app/routers.py` lines 274-522 (the entire `register` function) with:

```python
@router.post("/register")
async def register(
    user: schemas.UserCreate,
    request: Request,
    response: Response,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
):
    """User registration — validates email verification code, creates user, auto-login"""
    from app.validators import UserValidator, validate_input
    from app.security import get_password_hash
    from app.password_validator import password_validator
    from app.async_crud import async_user_crud
    from app.verification_code_manager import verify_and_delete_code

    # --- Input validation ---
    try:
        validated_data = validate_input(user.dict(), UserValidator)
        if hasattr(user, 'invitation_code') and user.invitation_code:
            validated_data['invitation_code'] = user.invitation_code
        phone_verification_code = validated_data.pop('phone_verification_code', None)
        if phone_verification_code:
            validated_data['_phone_verification_code'] = phone_verification_code
    except HTTPException:
        raise

    # --- Basic checks (English error codes) ---
    if not validated_data.get('email'):
        raise HTTPException(status_code=400, detail="email_required")

    agreed_to_terms = validated_data.get('agreed_to_terms', False)
    if not agreed_to_terms:
        raise HTTPException(status_code=400, detail="terms_not_agreed")

    # --- Email verification code ---
    verification_code = user.verification_code
    if not verification_code or not verification_code.strip():
        raise HTTPException(status_code=400, detail="verification_code_invalid")

    email = validated_data['email'].strip().lower()

    # Brute-force protection
    try:
        from app.redis_cache import get_redis_client
        _redis = get_redis_client()
        if _redis:
            attempt_key = f"verify_attempt:register:{email}"
            attempts = _redis.incr(attempt_key)
            if attempts == 1:
                _redis.expire(attempt_key, 900)
            if attempts > 5:
                raise HTTPException(status_code=429, detail="verification_code_invalid")
    except HTTPException:
        raise
    except Exception as e:
        logger.warning(f"Rate limit check failed for registration: {e}")

    if not verify_and_delete_code(email, verification_code.strip()):
        raise HTTPException(status_code=400, detail="verification_code_invalid")

    # --- Phone verification (if phone provided) ---
    phone = validated_data.get('phone')
    phone_verification_code = validated_data.pop('_phone_verification_code', None)
    if phone:
        if not phone_verification_code:
            raise HTTPException(status_code=400, detail="Phone verification code required")

        import re
        if not phone.startswith('+'):
            raise HTTPException(status_code=400, detail="Invalid phone format")
        if not re.match(r'^\+\d{10,15}$', phone):
            raise HTTPException(status_code=400, detail="Invalid phone format")

        phone_verified = False
        try:
            from app.phone_verification_code_manager import verify_and_delete_code as verify_phone
            from app.twilio_sms import twilio_sms
            if twilio_sms.use_verify_api and twilio_sms.verify_client:
                phone_verified = twilio_sms.verify_code(phone, phone_verification_code)
            else:
                phone_verified = verify_phone(phone, phone_verification_code)
        except Exception as e:
            logger.error(f"Phone verification error: {e}")
        if not phone_verified:
            raise HTTPException(status_code=400, detail="verification_code_invalid")

        db_phone_user = await async_user_crud.get_user_by_phone(db, phone)
        if db_phone_user:
            raise HTTPException(status_code=400, detail="email_already_registered")

    # --- Uniqueness checks ---
    db_user = await async_user_crud.get_user_by_email(db, email)
    if db_user:
        raise HTTPException(status_code=400, detail="email_already_registered")

    db_name = await async_user_crud.get_user_by_name(db, validated_data['name'])
    if db_name:
        raise HTTPException(status_code=400, detail="username_already_taken")

    # Reserved keywords check
    customer_service_keywords = ["客服", "customer", "service", "support", "help"]
    name_lower = validated_data['name'].lower()
    if any(kw.lower() in name_lower for kw in customer_service_keywords):
        raise HTTPException(status_code=400, detail="username_contains_reserved_keywords")

    # --- Password strength ---
    password_validation = password_validator.validate_password(
        validated_data['password'],
        username=validated_data['name'],
        email=email
    )
    if not password_validation.is_valid:
        raise HTTPException(status_code=400, detail="password_too_weak")

    # --- Invitation code processing ---
    invitation_code_id = None
    inviter_id = None
    invitation_code_text = None
    if validated_data.get('invitation_code'):
        def _process_invitation_sync():
            from app.database import SessionLocal
            from app.coupon_points_crud import process_invitation_input
            _db = SessionLocal()
            try:
                return process_invitation_input(_db, validated_data['invitation_code'])
            finally:
                _db.close()
        inviter_id, invitation_code_id, invitation_code_text, error_msg = await asyncio.to_thread(
            _process_invitation_sync
        )

    # --- Create user (verified, since email code was valid) ---
    user_data = schemas.UserCreate(**validated_data)
    new_user = await async_user_crud.create_user(db, user_data)

    from sqlalchemy import update
    await db.execute(
        update(models.User)
        .where(models.User.id == new_user.id)
        .values(
            is_verified=1,
            is_active=1,
            user_level="normal",
            inviter_id=inviter_id,
            invitation_code_id=invitation_code_id,
            invitation_code_text=invitation_code_text
        )
    )
    await db.commit()
    await db.refresh(new_user)

    # --- Invitation code reward ---
    if invitation_code_id:
        _user_id_str = new_user.id
        _inv_code_id = invitation_code_id
        def _use_invitation_sync():
            from app.database import SessionLocal
            from app.coupon_points_crud import use_invitation_code
            _db = SessionLocal()
            try:
                return use_invitation_code(_db, _user_id_str, _inv_code_id)
            finally:
                _db.close()
        success, error_msg = await asyncio.to_thread(_use_invitation_sync)
        if success:
            logger.info(f"Invitation reward granted: user {new_user.id}")
        else:
            logger.warning(f"Invitation reward failed: {error_msg}")

    # --- Create session (same as secure_login) ---
    from app.secure_auth import SecureAuthManager, get_client_ip, get_device_fingerprint
    from app.secure_auth import is_mobile_app_request, create_user_refresh_token
    from app.cookie_manager import CookieManager

    device_fingerprint = get_device_fingerprint(request)
    client_ip = get_client_ip(request)
    user_agent = request.headers.get("user-agent", "")
    is_ios_app = is_mobile_app_request(request)

    refresh_token = create_user_refresh_token(
        new_user.id, client_ip, device_fingerprint, is_ios_app=is_ios_app
    )

    session = SecureAuthManager.create_session(
        user_id=new_user.id,
        device_fingerprint=device_fingerprint,
        ip_address=client_ip,
        user_agent=user_agent,
        refresh_token=refresh_token,
        is_ios_app=is_ios_app
    )

    origin = request.headers.get("origin", "")
    CookieManager.set_session_cookies(
        response=response,
        session_id=session.session_id,
        refresh_token=refresh_token,
        user_id=new_user.id,
        user_agent=user_agent,
        origin=origin
    )

    from app.csrf import CSRFProtection
    csrf_token = CSRFProtection.generate_csrf_token()
    CookieManager.set_csrf_cookie(response, csrf_token, user_agent, origin)

    is_mobile = any(kw in user_agent.lower() for kw in [
        'mobile', 'iphone', 'ipad', 'android', 'blackberry',
        'windows phone', 'opera mini', 'iemobile'
    ])

    if is_mobile:
        response.headers["X-Session-ID"] = session.session_id
        response.headers["X-User-ID"] = str(new_user.id)
        response.headers["X-Auth-Status"] = "authenticated"
        response.headers["X-Mobile-Auth"] = "true"

    logger.info(f"User registered and logged in: user_id={new_user.id}, email={email}")

    response_data = {
        "message": "Registration successful",
        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "email": new_user.email,
            "user_level": new_user.user_level or "normal",
            "is_verified": 1,
        },
        "session_id": session.session_id,
        "expires_in": 300,
        "mobile_auth": is_mobile,
        "auth_headers": {
            "X-Session-ID": session.session_id,
            "X-User-ID": new_user.id,
            "X-Auth-Status": "authenticated"
        } if is_mobile else None
    }

    if is_mobile:
        response_data["refresh_token"] = refresh_token

    return response_data
```

**Step 2: Verify imports exist**

Confirm these imports are available at the top of `routers.py` (they should already be present):
- `from fastapi import Request, Response, status`
- `from app import models, schemas`
- `import asyncio`

**Step 3: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(auth): rewrite register endpoint with code verification and auto-login"
```

---

### Task 3: Frontend — Add `verificationCode` to AuthRegisterRequested event

**Files:**
- Modify: `link2ur/lib/features/auth/bloc/auth_event.dart:56-73`

**Step 1: Add field**

Replace the `AuthRegisterRequested` class (lines 56-73):

```dart
/// 注册
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.verificationCode,
    this.invitationCode,
  });

  final String email;
  final String password;
  final String name;
  final String verificationCode;
  /// 邀请码或8位邀请人用户ID（选填）
  final String? invitationCode;

  @override
  List<Object?> get props => [email, password, name, verificationCode, invitationCode];
}
```

**Step 2: Commit**

```bash
git add link2ur/lib/features/auth/bloc/auth_event.dart
git commit -m "feat(auth): add verificationCode to AuthRegisterRequested event"
```

---

### Task 4: Frontend — Update auth_repository.register() to send verification_code + agreed_to_terms

**Files:**
- Modify: `link2ur/lib/data/repositories/auth_repository.dart:143-186`

**Step 1: Update method signature and request body**

Replace `register()` method (lines 143-186):

```dart
  /// 注册
  Future<User> register({
    required String email,
    required String password,
    required String name,
    required String verificationCode,
    String? invitationCode,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'name': name,
        'verification_code': verificationCode,
        'agreed_to_terms': true,
        if (invitationCode != null && invitationCode.isNotEmpty)
          'invitation_code': invitationCode,
      },
    );

    if (!response.isSuccess) {
      throw AuthException(response.message ?? 'auth_error_register_failed');
    }

    if (response.data == null) {
      AppLogger.error('Register response data is null');
      throw const AuthException('auth_error_register_failed');
    }

    AppLogger.debug('Register response keys: ${response.data!.keys.toList()}');

    final loginResponse = LoginResponse.fromJson(response.data!);

    await StorageService.instance.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    await StorageService.instance.saveUserId(loginResponse.user.id);
    await StorageService.instance.saveUserInfo(loginResponse.user.toJson());

    WebSocketService.instance.connect();

    AppLogger.info('User registered: ${loginResponse.user.id}');
    return loginResponse.user;
  }
```

Changes: added `verificationCode` parameter, added `'verification_code'` and `'agreed_to_terms'` to request body, replaced Chinese fallback error strings with error codes.

**Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/auth_repository.dart
git commit -m "feat(auth): send verification_code and agreed_to_terms in register request"
```

---

### Task 5: Frontend — Pass verificationCode through BLoC

**Files:**
- Modify: `link2ur/lib/features/auth/bloc/auth_bloc.dart:190-195`

**Step 1: Add verificationCode to repository call**

Replace lines 190-195:

```dart
      final user = await _authRepository.register(
        email: event.email,
        password: event.password,
        name: event.name,
        verificationCode: event.verificationCode,
        invitationCode: event.invitationCode,
      );
```

**Step 2: Commit**

```bash
git add link2ur/lib/features/auth/bloc/auth_bloc.dart
git commit -m "feat(auth): pass verificationCode from event to repository"
```

---

### Task 6: Frontend — Pass verification code from RegisterView to event

**Files:**
- Modify: `link2ur/lib/features/auth/views/register_view.dart:124-131`

**Step 1: Add verificationCode to event dispatch**

Replace lines 124-131:

```dart
    context.read<AuthBloc>().add(AuthRegisterRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          verificationCode: _codeController.text.trim(),
          invitationCode: _invitationCodeController.text.trim().isNotEmpty
              ? _invitationCodeController.text.trim()
              : null,
        ));
```

Only change: added `verificationCode: _codeController.text.trim(),`.

**Step 2: Commit**

```bash
git add link2ur/lib/features/auth/views/register_view.dart
git commit -m "feat(auth): pass verification code from register view to bloc event"
```

---

### Task 7: Frontend — Add 7 registration error codes to ErrorLocalizer + ARB files

**Files:**
- Modify: `link2ur/lib/core/utils/error_localizer.dart:65-66`
- Modify: `link2ur/lib/l10n/app_en.arb:523`
- Modify: `link2ur/lib/l10n/app_zh.arb:535`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb:535`

**Step 1: Add cases to ErrorLocalizer**

In `error_localizer.dart`, after the `auth_error_register_failed` case (line 66), add:

```dart
      case 'email_required':
        return context.l10n.errorEmailRequired;
      case 'email_already_registered':
        return context.l10n.errorEmailAlreadyRegistered;
      case 'username_already_taken':
        return context.l10n.errorUsernameAlreadyTaken;
      case 'username_contains_reserved_keywords':
        return context.l10n.errorUsernameReservedKeywords;
      case 'terms_not_agreed':
        return context.l10n.errorTermsNotAgreed;
      case 'password_too_weak':
        return context.l10n.errorPasswordTooWeak;
      case 'verification_code_invalid':
        return context.l10n.errorVerificationCodeInvalid;
```

**Step 2: Add l10n keys to app_en.arb**

After line 523 (`"errorRegisterFailed": "Registration Failed",`), add:

```json
  "errorEmailRequired": "Email is required for registration",
  "errorEmailAlreadyRegistered": "This email is already registered, please use another or log in",
  "errorUsernameAlreadyTaken": "This username is already taken, please choose another",
  "errorUsernameReservedKeywords": "Username contains reserved keywords",
  "errorTermsNotAgreed": "You must agree to the Terms of Service and Privacy Policy",
  "errorPasswordTooWeak": "Password does not meet security requirements",
  "errorVerificationCodeInvalid": "Verification code is incorrect or expired",
```

**Step 3: Add l10n keys to app_zh.arb**

After line 535 (`"errorRegisterFailed": "注册失败",`), add:

```json
  "errorEmailRequired": "注册需要提供邮箱地址",
  "errorEmailAlreadyRegistered": "该邮箱已被注册，请使用其他邮箱或直接登录",
  "errorUsernameAlreadyTaken": "该用户名已被使用，请选择其他用户名",
  "errorUsernameReservedKeywords": "用户名包含保留关键词",
  "errorTermsNotAgreed": "您必须同意用户协议和隐私政策才能注册",
  "errorPasswordTooWeak": "密码不符合安全要求",
  "errorVerificationCodeInvalid": "验证码错误或已过期",
```

**Step 4: Add l10n keys to app_zh_Hant.arb**

After line 535 (`"errorRegisterFailed": "註冊失敗",`), add:

```json
  "errorEmailRequired": "註冊需要提供郵箱地址",
  "errorEmailAlreadyRegistered": "該郵箱已被註冊，請使用其他郵箱或直接登入",
  "errorUsernameAlreadyTaken": "該用戶名已被使用，請選擇其他用戶名",
  "errorUsernameReservedKeywords": "用戶名包含保留關鍵詞",
  "errorTermsNotAgreed": "您必須同意用戶協議和隱私政策才能註冊",
  "errorPasswordTooWeak": "密碼不符合安全要求",
  "errorVerificationCodeInvalid": "驗證碼錯誤或已過期",
```

**Step 5: Generate l10n files**

Run from `link2ur/`:

```bash
flutter gen-l10n
```

Expected: No errors, generates updated `app_localizations_*.dart` files.

**Step 6: Commit**

```bash
git add link2ur/lib/core/utils/error_localizer.dart link2ur/lib/l10n/
git commit -m "feat(auth): add 7 registration error code localizations"
```

---

### Task 8: Verify — Run flutter analyze

**Step 1: Run static analysis**

From `link2ur/`:

```bash
flutter analyze
```

Expected: No errors. Fix any issues found.

**Step 2: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix(auth): resolve any analyze issues from registration fix"
```

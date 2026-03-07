# 注册功能修复设计

## 问题总结

1. **`agreed_to_terms` 未发送** — 前端本地检查但不发送，后端要求该字段，导致注册永远失败
2. **响应格式不匹配** — 后端返回 `{message, verification_required}`，前端期望 `{session_id, user}`
3. **验证码收集但未使用** — 前端收集6位验证码，后端完全忽略，生产环境另发验证链接邮件
4. **错误消息中文硬编码** — 后端返回中文错误，英文/繁体用户看到简体中文
5. **无邮箱验证 UI 流程** — 生产环境需邮件链接验证，前端无对应提示页

## 设计方案：验证码方式一步注册

### 后端改动

#### 1. `backend/app/schemas.py` — UserCreate 增加 verification_code

```python
class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    avatar: Optional[str] = ""
    agreed_to_terms: Optional[bool] = False
    terms_agreed_at: Optional[str] = None
    invitation_code: Optional[str] = None
    phone_verification_code: Optional[str] = None
    verification_code: Optional[str] = None  # 新增：邮箱验证码
```

#### 2. `backend/app/routers.py` — register() 端点重构

核心改动：
- 验证 `verification_code`（从 Redis 读取比对，复用 `verify_and_delete_code()`）
- 验证码有效 → 创建用户（is_verified=1）→ 创建 session → 返回与 login 一致的响应格式
- 移除生产环境的"发送验证链接邮件"分支
- 所有错误消息改为英文错误码

错误码映射：
| 当前中文 | 新错误码 |
|---|---|
| 注册需要提供邮箱地址 | `email_required` |
| 该邮箱已被注册 | `email_already_registered` |
| 该用户名已被使用 | `username_already_taken` |
| 用户名不能包含客服相关关键词 | `username_contains_reserved_keywords` |
| 您必须同意用户协议和隐私政策 | `terms_not_agreed` |
| 密码不符合安全要求 | `password_too_weak` |
| 邮箱验证码错误或已过期 | `verification_code_invalid` |

响应格式（与 secure_login 一致）：
```json
{
  "message": "Registration successful",
  "user": { "id": "...", "name": "...", "email": "...", ... },
  "session_id": "...",
  "refresh_token": "...",
  "expires_in": 300
}
```

### 前端改动

#### 3. `link2ur/lib/features/auth/bloc/auth_event.dart` — 增加 verificationCode

```dart
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.verificationCode,  // 新增
    this.invitationCode,
  });
  // ...
  final String verificationCode;
}
```

#### 4. `link2ur/lib/data/repositories/auth_repository.dart` — 发送完整数据

```dart
Future<User> register({
  required String email,
  required String password,
  required String name,
  required String verificationCode,  // 新增
  String? invitationCode,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.register,
    data: {
      'email': email,
      'password': password,
      'name': name,
      'verification_code': verificationCode,  // 新增
      'agreed_to_terms': true,                // 新增
      if (invitationCode != null && invitationCode.isNotEmpty)
        'invitation_code': invitationCode,
    },
  );
  // ... 其余不变（LoginResponse.fromJson 可正常解析新格式）
}
```

#### 5. `link2ur/lib/features/auth/bloc/auth_bloc.dart` — 传递验证码

```dart
final user = await _authRepository.register(
  email: event.email,
  password: event.password,
  name: event.name,
  verificationCode: event.verificationCode,  // 新增
  invitationCode: event.invitationCode,
);
```

#### 6. `link2ur/lib/features/auth/views/register_view.dart` — 传递验证码到事件

```dart
context.read<AuthBloc>().add(AuthRegisterRequested(
  email: _emailController.text.trim(),
  password: _passwordController.text,
  name: _nameController.text.trim(),
  verificationCode: _codeController.text.trim(),  // 新增
  invitationCode: ...,
));
```

#### 7. `link2ur/lib/core/utils/error_localizer.dart` — 添加注册错误码

新增 7 个 case 映射到 l10n key。

#### 8. 3 个 ARB 文件 — 添加 l10n key

| key | EN | ZH | ZH_Hant |
|---|---|---|---|
| errorEmailRequired | Email is required for registration | 注册需要提供邮箱地址 | 註冊需要提供郵箱地址 |
| errorEmailAlreadyRegistered | This email is already registered | 该邮箱已被注册 | 該郵箱已被註冊 |
| errorUsernameAlreadyTaken | This username is already taken | 该用户名已被使用 | 該用戶名已被使用 |
| errorUsernameReservedKeywords | Username contains reserved keywords | 用户名包含保留关键词 | 用戶名包含保留關鍵詞 |
| errorTermsNotAgreed | You must agree to the Terms and Privacy Policy | 您必须同意用户协议和隐私政策 | 您必須同意用戶協議和隱私政策 |
| errorPasswordTooWeak | Password does not meet security requirements | 密码不符合安全要求 | 密碼不符合安全要求 |
| errorVerificationCodeInvalid | Verification code is incorrect or expired | 验证码错误或已过期 | 驗證碼錯誤或已過期 |

## 不改动的部分

- `LoginResponse.fromJson()` — 后端改为返回一致格式后无需修改
- 注册 UI 布局 — 验证码输入框保留
- `_sendCode()` — 发送验证码流程不变
- `register_test/register_debug` — 调试端点保持原样

## 文件改动清单

| # | 文件 | 改动 |
|---|---|---|
| 1 | `backend/app/schemas.py` | UserCreate 增加 verification_code |
| 2 | `backend/app/routers.py` | register() 验证码验证 + 自动登录 + 错误码 |
| 3 | `link2ur/lib/features/auth/bloc/auth_event.dart` | AuthRegisterRequested 增加 verificationCode |
| 4 | `link2ur/lib/data/repositories/auth_repository.dart` | register() 发送 verification_code + agreed_to_terms |
| 5 | `link2ur/lib/features/auth/bloc/auth_bloc.dart` | 传递 verificationCode |
| 6 | `link2ur/lib/features/auth/views/register_view.dart` | _onRegister() 传递验证码 |
| 7 | `link2ur/lib/core/utils/error_localizer.dart` | 7 个注册错误码映射 |
| 8 | `link2ur/lib/l10n/app_en.arb` | 7 个新 key |
| 9 | `link2ur/lib/l10n/app_zh.arb` | 7 个新 key |
| 10 | `link2ur/lib/l10n/app_zh_Hant.arb` | 7 个新 key |

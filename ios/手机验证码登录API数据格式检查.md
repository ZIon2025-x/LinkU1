# 手机验证码登录API数据格式检查报告

## 检查时间
2025-12-16

## 1. 发送验证码API

### iOS端发送的数据格式
```swift
// APIService+Endpoints.swift:194
func sendPhoneCode(phone: String) -> AnyPublisher<EmptyResponse, APIError> {
    let body = ["phone": phone]
    return request(EmptyResponse.self, "/api/secure-auth/send-phone-verification-code", method: "POST", body: body)
}
```

**请求格式：**
- URL: `POST /api/secure-auth/send-phone-verification-code`
- Body: `{"phone": "+447123456789"}` (完整手机号，包含区号)
- Content-Type: `application/json`

### 数据流
1. 用户输入：手机号（不含区号，如：`7123456789`）
2. ViewModel处理：
   - 清理空格和特殊字符
   - 组合区号和号码：`countryCode + cleanedPhoneNumber` (如：`+447123456789`)
3. API发送：`{"phone": "+447123456789"}`

### ✅ 格式验证
- ✅ 字段名：`phone` (正确)
- ✅ 值格式：完整手机号，包含区号（如：`+447123456789`）
- ✅ 端点路径：`/api/secure-auth/send-phone-verification-code` (已验证匹配)

---

## 2. 手机验证码登录API

### iOS端发送的数据格式
```swift
// APIService+Endpoints.swift:178
func loginWithPhone(phone: String, code: String) -> AnyPublisher<LoginResponse, APIError> {
    let body = PhoneLoginRequest(phone: phone, verificationCode: code)
    // ...
    return request(LoginResponse.self, "/api/secure-auth/login-with-phone-code", method: "POST", body: bodyDict)
}

// PhoneLoginRequest 定义
struct PhoneLoginRequest: Encodable {
    let phone: String
    let verificationCode: String
    
    enum CodingKeys: String, CodingKey {
        case phone
        case verificationCode = "verification_code"  // 转换为 snake_case
    }
}
```

**请求格式：**
- URL: `POST /api/secure-auth/login-with-phone-code`
- Body: 
```json
{
    "phone": "+447123456789",
    "verification_code": "123456"
}
```
- Content-Type: `application/json`

### 数据流
1. 用户输入：
   - 手机号：`7123456789` (不含区号)
   - 验证码：`123456`
2. ViewModel处理：
   - 清理手机号：去除空格和特殊字符
   - 组合区号：`+44 + 7123456789` = `+447123456789`
3. API发送：
   - `phone`: `"+447123456789"`
   - `verification_code`: `"123456"` (使用 snake_case)

### ✅ 格式验证
- ✅ 字段名：`phone` 和 `verification_code` (正确，使用 snake_case)
- ✅ 值格式：完整手机号（包含区号）+ 验证码字符串
- ✅ 端点路径：`/api/secure-auth/login-with-phone-code` (已验证匹配)

---

## 3. 响应数据格式

### 登录响应格式
```swift
// Models/User.swift:74
struct LoginResponse: Codable {
    let message: String
    let user: LoginUser
    let sessionId: String?
    let expiresIn: Int?
    let mobileAuth: Bool?
    let authHeaders: AuthHeaders?
    
    enum CodingKeys: String, CodingKey {
        case message
        case user
        case sessionId = "session_id"  // 从 snake_case 转换
        case expiresIn = "expires_in"
        case mobileAuth = "mobile_auth"
        case authHeaders = "auth_headers"
    }
}
```

**期望的响应格式：**
```json
{
    "message": "Login successful",
    "user": {
        "id": "12345678",
        "name": "User Name",
        "email": "user@example.com",
        "user_level": "normal",
        "is_verified": 1
    },
    "session_id": "abc123...",
    "expires_in": 3600,
    "mobile_auth": true,
    "auth_headers": {
        "X-Session-ID": "abc123...",
        "X-User-ID": "12345678",
        "X-Auth-Status": "authenticated"
    }
}
```

### ✅ 响应处理验证
- ✅ Session ID保存：从 `authHeaders.sessionId` 或 `sessionId` 获取
- ✅ 用户信息转换：`LoginUser` → `User`
- ✅ 登录状态通知：通过 `NotificationCenter` 发送

---

## 4. 真人验证（reCAPTCHA/hCaptcha）检查

### ⚠️ 当前状态
**未找到真人验证相关代码**

### 需要检查的事项
1. **后端是否要求真人验证？**
   - 发送验证码时是否需要 reCAPTCHA token？
   - 登录时是否需要验证 token？

2. **前端实现参考**
   - 需要查看前端（Web）是如何处理真人验证的
   - 是否使用了 Google reCAPTCHA 或 hCaptcha？

3. **iOS实现方案**
   - 如果后端需要，可能需要：
     - 集成 reCAPTCHA iOS SDK
     - 或使用 WebView 加载 reCAPTCHA
     - 或使用其他验证方案（如 Apple 的 App Attest）

### 建议
1. **确认后端要求**：检查后端API文档，确认是否需要真人验证
2. **查看前端实现**：参考前端代码，了解使用的验证服务
3. **实现验证**：如果需要，添加相应的验证功能

---

## 5. 数据格式总结

### ✅ 已确认正确的部分
1. **发送验证码**
   - 字段名：`phone` ✅
   - 值格式：完整手机号（包含区号）✅
   - 端点：`/api/secure-auth/send-phone-verification-code` ✅

2. **手机验证码登录**
   - 字段名：`phone`, `verification_code` ✅
   - 值格式：完整手机号 + 验证码 ✅
   - 端点：`/api/secure-auth/login-with-phone-code` ✅

3. **响应处理**
   - Session ID 保存 ✅
   - 用户信息转换 ✅
   - 登录状态管理 ✅

### ⚠️ 需要确认的部分
1. **真人验证**
   - 后端是否要求？
   - 前端如何实现？
   - 需要添加什么验证机制？

2. **错误处理**
   - 验证码错误时的响应格式
   - 手机号格式错误的响应格式
   - 频率限制的响应格式

---

## 6. 建议的下一步

1. **测试API调用**
   - 使用真实后端测试发送验证码
   - 测试手机验证码登录
   - 验证响应数据格式

2. **检查后端文档**
   - 确认是否需要真人验证
   - 确认错误响应格式
   - 确认频率限制规则

3. **实现真人验证（如果需要）**
   - 根据后端要求选择合适的验证方案
   - 参考前端实现
   - 集成到iOS应用中


# 手机验证码登录和CAPTCHA检查报告

## 检查时间
2024年

## 一、后端数据格式匹配检查

### ✅ 已确认正确的部分

#### 1. 发送手机验证码 API
- **端点**: `POST /api/secure-auth/send-phone-verification-code`
- **请求格式**:
  ```json
  {
      "phone": "+447123456789",
      "captcha_token": "token"  // 可选，但如果CAPTCHA启用则必需
  }
  ```
- **手机号格式要求**: 
  - 必须以 `+` 开头
  - 格式：`^\+\d{10,15}$`
  - iOS当前实现：发送 `+44` + 手机号 ✅

#### 2. 手机验证码登录 API
- **端点**: `POST /api/secure-auth/login-with-phone-code`
- **请求格式**:
  ```json
  {
      "phone": "+447123456789",
      "verification_code": "123456",
      "captcha_token": "token"  // 可选（登录时不需要，因为发送验证码时已验证）
  }
  ```
- **字段名**: 使用 `snake_case` (`verification_code`, `captcha_token`) ✅

#### 3. 响应格式
- **Session ID**: 从 `authHeaders.sessionId` 或 `sessionId` 获取 ✅
- **用户信息**: `LoginUser` → `User` 转换 ✅
- **移动端标识**: `mobile_auth` 和 `auth_headers` ✅

### ✅ iOS实现状态

#### 已完成的更新：
1. ✅ 更新了 `PhoneLoginRequest` 结构体，添加 `captchaToken` 字段
2. ✅ 更新了 `sendPhoneCode` 方法，支持 `captchaToken` 参数
3. ✅ 更新了 `loginWithPhone` 方法，支持 `captchaToken` 参数
4. ✅ 添加了 `getCaptchaSiteKey` API调用
5. ✅ 添加了 `CaptchaConfigResponse` 响应模型
6. ✅ 在 `AuthViewModel` 中添加了CAPTCHA相关状态
7. ✅ 实现了CAPTCHA配置自动检查

## 二、真人验证（CAPTCHA）检查

### 后端实现状态

#### ✅ 已实现的功能：
1. **CAPTCHA类型支持**:
   - Google reCAPTCHA v2（交互式验证）
   - hCaptcha
   - 自动选择：优先使用 reCAPTCHA，如果没有配置则使用 hCaptcha

2. **验证流程**:
   - **发送验证码时**: CAPTCHA **强制要求**（如果启用）
   - **登录时**: CAPTCHA **可选**（因为发送验证码时已经验证过了）

3. **配置检查**:
   - 端点: `GET /api/secure-auth/captcha-site-key`
   - 返回: `{"site_key": "...", "enabled": true/false, "type": "recaptcha"/"hcaptcha"}`

### iOS实现状态

#### ✅ 已完成：
1. ✅ API调用支持（`getCaptchaSiteKey`）
2. ✅ 响应模型（`CaptchaConfigResponse`）
3. ✅ ViewModel状态管理（`captchaEnabled`, `captchaSiteKey`, `captchaType`, `captchaToken`）
4. ✅ 自动检查CAPTCHA配置（初始化时）

#### ✅ 已完成：
1. **CAPTCHA验证UI**:
   - ✅ 创建了 `CaptchaWebView` 组件，支持 reCAPTCHA v2 和 hCaptcha
   - ✅ 使用 WebView 加载 CAPTCHA 网页版本
   - ✅ 通过 JavaScript 消息处理器获取验证 token

2. **验证流程集成**:
   - ✅ 在 `LoginView` 中添加了 CAPTCHA 验证步骤
   - ✅ 用户点击"发送验证码"时，如果 CAPTCHA 启用，先显示验证界面
   - ✅ 验证成功后，获取 token 并保存到 `viewModel.captchaToken`
   - ✅ 然后自动发送验证码请求

## 三、数据格式匹配总结

### ✅ 完全匹配的部分：
1. **手机号格式**: iOS发送 `+44` + 手机号，符合后端要求 `^\+\d{10,15}$` ✅
2. **字段名**: 使用 `snake_case` (`verification_code`, `captcha_token`) ✅
3. **请求体结构**: 与后端 `PhoneVerificationCodeRequest` 和 `PhoneVerificationCodeLogin` schema匹配 ✅

### ⚠️ 需要注意的部分：
1. **CAPTCHA Token**:
   - 如果后端CAPTCHA启用，发送验证码时**必须**提供 `captcha_token`
   - 当前iOS代码支持传递token，但**UI层面还未实现验证流程**
   - 如果CAPTCHA未启用，可以不提供token（后端会跳过验证）

## 四、建议和下一步

### ✅ 已完成：
1. **实现CAPTCHA验证UI**:
   - ✅ 使用 WebView 加载 reCAPTCHA/hCaptcha 网页（方案A）
   - ✅ 支持 Google reCAPTCHA v2 和 hCaptcha
   - ✅ 如果 CAPTCHA 未启用，自动跳过验证

2. **集成验证流程**:
   - ✅ 在 `LoginView` 中，发送验证码前检查 `viewModel.captchaEnabled`
   - ✅ 如果启用，显示全屏验证界面
   - ✅ 验证成功后，保存 token 到 `viewModel.captchaToken`
   - ✅ 然后自动调用 `sendPhoneCode`

### 可选优化：
1. 缓存CAPTCHA token（在一定时间内可以复用）
2. 错误处理：如果CAPTCHA验证失败，显示友好提示
3. 支持自动重试CAPTCHA验证

## 五、测试建议

### 测试场景：
1. **CAPTCHA未启用**:
   - 发送验证码应该正常工作（不需要token）
   - 登录应该正常工作

2. **CAPTCHA启用**:
   - 发送验证码前必须完成CAPTCHA验证
   - 验证失败时应该显示错误提示
   - 验证成功后应该能正常发送验证码

3. **手机号格式**:
   - 测试 `+447123456789` 格式（正确）
   - 测试不带 `+` 的格式（应该被后端拒绝）
   - 测试长度不符合要求的格式（应该被后端拒绝）

## 六、代码变更总结

### 修改的文件：
1. `APIService+Endpoints.swift`:
   - 添加 `captchaToken` 到 `PhoneLoginRequest`
   - 更新 `sendPhoneCode` 和 `loginWithPhone` 方法
   - 添加 `getCaptchaSiteKey` 方法
   - 添加 `CaptchaConfigResponse` 模型

2. `AuthViewModel.swift`:
   - 添加CAPTCHA相关 `@Published` 属性
   - 添加 `checkCaptchaConfig` 方法（公开方法，可在外部调用）
   - 更新 `sendPhoneCode` 和 `loginWithPhone` 调用

3. `LoginView.swift`:
   - 添加 `showCaptcha` 状态
   - 添加 `sendPhoneCode()` 辅助方法
   - 添加 `captchaView` 视图
   - 集成 CAPTCHA 验证流程到发送验证码按钮
   - 使用 `fullScreenCover` 显示验证界面

### 新增文件：
1. `CaptchaWebView.swift`:
   - 创建 CAPTCHA WebView 组件
   - 支持 reCAPTCHA v2 和 hCaptcha
   - 实现 JavaScript 消息处理器
   - 处理验证成功和过期回调

### 新增功能：
- ✅ CAPTCHA配置自动检查
- ✅ CAPTCHA token支持（API层面）
- ✅ CAPTCHA验证UI实现（WebView）
- ✅ 验证流程集成到登录界面
- ✅ 自动发送验证码（验证成功后）

### 完成状态：
- ✅ 所有功能已完成
- ✅ 代码编译通过
- ✅ 支持 CAPTCHA 启用和未启用两种情况


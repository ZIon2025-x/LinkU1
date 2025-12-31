# Stripe Connect 400 错误调试指南

## 问题描述

iOS 应用在调用 `/api/stripe/connect/account/create-embedded` 时返回 400 错误。

## 可能的原因

### 1. 移动端签名验证失败

后端使用 `get_current_user_secure_sync_csrf` 依赖，它需要验证移动端请求的合法性。

验证条件（必须同时满足）：
1. `X-Platform` 头必须是 `iOS` 或 `Android`
2. `User-Agent` 必须包含对应平台的应用标识（iOS: `Link2Ur-iOS`）
3. `X-App-Signature` 头必须是有效的 HMAC 签名
4. `X-App-Timestamp` 时间戳在有效期内（5分钟）

### 2. 密钥不匹配

iOS 应用的签名密钥必须与后端的 `MOBILE_APP_SECRET` 环境变量匹配。

**iOS 密钥位置**：`ios/link2ur/link2ur/Utils/AppSignature.swift`
```swift
private static var appSecret: String {
    // 密钥由多个部分组装
    let p1 = "Ks7_dH2x"
    let p2 = "PqN8mVfL"
    // ... 其他部分
    return parts.joined()
}
```

**后端密钥位置**：环境变量 `MOBILE_APP_SECRET`

**签名算法**：
- iOS: `HMAC-SHA256(session_id + timestamp, appSecret)`
- 后端: `HMAC-SHA256(session_id + timestamp, MOBILE_APP_SECRET)`

## 调试步骤

### 1. 检查后端日志

查看后端日志，确认具体的验证失败原因：
- "移动端验证失败: User-Agent 不匹配"
- "移动端验证失败: 缺少签名或时间戳"
- "移动端签名验证失败: 签名不匹配"
- "移动端签名验证失败: 时间戳过期"

### 2. 检查 iOS 请求头

确保以下请求头正确设置：
- `X-Platform: iOS`
- `User-Agent: Link2Ur-iOS/1.0`（必须包含 `Link2Ur-iOS`）
- `X-Session-ID: <session_id>`
- `X-App-Signature: <hmac_signature>`
- `X-App-Timestamp: <timestamp>`

### 3. 验证密钥匹配

**iOS 密钥**（从代码中提取）：
```
Ks7_dH2xPqN8mVfL3wYzRt5uCbJeAg0iXp1kOsWnMhIvQy@ZzxBcDxFrUaEoGm4yH6nP9kLqS2wRtVxZuAcBdEf
```

**后端环境变量**：
```bash
export MOBILE_APP_SECRET="Ks7_dH2xPqN8mVfL3wYzRt5uCbJeAg0iXp1kOsWnMhIvQy@ZzxBcDxFrUaEoGm4yH6nP9kLqS2wRtVxZuAcBdEf"
```

### 4. 检查时间同步

确保设备时间与服务器时间同步（误差不超过 5 分钟）。

### 5. 检查 Session ID

确保 `X-Session-ID` 头包含有效的会话 ID，且该会话在数据库中仍然有效。

## 解决方案

### 方案 1：确保密钥匹配

1. 从 iOS 代码中提取完整的 `appSecret` 值
2. 在后端环境变量中设置相同的值：
   ```bash
   export MOBILE_APP_SECRET="<完整的密钥>"
   ```
3. 重启后端服务

### 方案 2：检查请求头

在 iOS 应用中添加调试日志，打印所有请求头：
```swift
Logger.debug("请求头: \(request.allHTTPHeaderFields ?? [:])", category: .api)
```

### 方案 3：临时禁用签名验证（仅用于调试）

在后端 `csrf.py` 中临时禁用签名验证，确认是否是签名问题：
```python
# 临时调试：跳过签名验证
if False:  # 改为 True 以禁用验证
    return True, platform
```

## 常见错误

### 错误 1: "User-Agent 与平台不匹配"
- **原因**：User-Agent 不包含 `Link2Ur-iOS`
- **解决**：确保 `User-Agent` 设置为 `Link2Ur-iOS/1.0`

### 错误 2: "应用签名无效"
- **原因**：签名密钥不匹配或签名算法错误
- **解决**：确保 iOS 和后端的密钥完全相同

### 错误 3: "请求时间戳过期"
- **原因**：设备时间与服务器时间不同步
- **解决**：同步设备时间或增加时间窗口

### 错误 4: "缺少应用签名或时间戳"
- **原因**：请求头未正确设置
- **解决**：确保 `AppSignature.signRequest` 被正确调用

## 测试

运行以下命令测试签名验证：
```bash
# 在后端测试签名
python -c "
import hmac
import hashlib
import time

MOBILE_APP_SECRET = 'Ks7_dH2xPqN8mVfL3wYzRt5uCbJeAg0iXp1kOsWnMhIvQy@ZzxBcDxFrUaEoGm4yH6nP9kLqS2wRtVxZuAcBdEf'
session_id = 'test_session'
timestamp = str(int(time.time()))
message = f'{session_id}{timestamp}'.encode()
signature = hmac.new(MOBILE_APP_SECRET.encode(), message, hashlib.sha256).hexdigest()
print(f'Signature: {signature}')
print(f'Timestamp: {timestamp}')
"
```

## 联系支持

如果问题仍然存在，请提供：
1. 后端日志（包含验证失败的详细信息）
2. iOS 请求头（从调试日志中提取）
3. 设备时间
4. 服务器时间


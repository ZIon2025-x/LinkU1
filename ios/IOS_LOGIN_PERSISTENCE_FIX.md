# iOS 登录状态持久化修复

## 🔴 问题描述

在本地测试时，即使设置了账号长期在线，构建后账号还是会退出。

## 🔍 根本原因分析

### 1. Keychain 配置问题 ⚠️

**问题**：
- `KeychainHelper` 的 `save` 方法没有设置 `kSecAttrAccessible` 属性
- 默认情况下，Keychain 项可能使用 `kSecAttrAccessibleWhenUnlocked`
- 这意味着设备锁定时无法访问 Keychain 数据
- 在构建/调试时，如果应用被重新安装或设备状态改变，Keychain 数据可能会丢失

**影响**：
- 构建后应用启动时，如果设备被锁定，无法读取 token
- 重新安装应用时，Keychain 数据可能被清除
- 更改 Bundle ID 或重新签名时，Keychain 数据可能丢失

### 2. 登录状态检查过于激进 ⚠️

**问题**：
- `checkLoginStatus()` 中，**任何**失败都会调用 `logout()`
- 包括网络错误、超时、服务器错误等
- 这导致即使 token 有效，只要网络请求失败就会登出

**影响**：
- 网络不稳定时，用户会被频繁登出
- 构建后如果网络连接有问题，会立即登出
- 用户体验差

### 3. 没有区分错误类型 ⚠️

**问题**：
- 没有区分网络错误和认证错误
- 网络错误不应该导致登出
- 只有真正的认证失败（401且刷新失败）才应该登出

## ✅ 修复方案

### 1. 修复 Keychain Accessibility 设置

**文件**: 
- `ios/link2ur/link2ur/Utils/KeychainHelper.swift`
- `ios/LinkU/Utils/KeychainHelper.swift`

**修复**：
```swift
// 设置 kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
// 确保：
// 1. 设备首次解锁后可以访问（即使应用在后台）
// 2. 仅限当前设备（不会同步到 iCloud Keychain）
// 3. 构建/调试时数据不会丢失
let query: [String: Any] = [
    kSecValueData as String: data,
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
]
```

**效果**：
- ✅ 设备首次解锁后，Keychain 数据可以访问
- ✅ 构建/调试时数据不会丢失
- ✅ 应用重新安装时，如果 Bundle ID 相同，Keychain 数据会保留

### 2. 修复登录状态检查逻辑

**文件**: 
- `ios/link2ur/link2ur/Utils/AppState.swift`
- `ios/LinkU/Utils/AppState.swift`

**修复**：
```swift
if case .failure(let error) = result {
    // 区分网络错误和认证错误
    if case APIError.unauthorized = error {
        // 401 未授权：可能是 token 过期，尝试刷新
        // APIService 会自动尝试刷新 token
        // 如果刷新失败，APIService 会处理登出逻辑
        // 这里不立即登出，等待刷新结果
    } else if case APIError.httpError(401) = error {
        // HTTP 401 错误：认证失败
        // 不立即登出，等待 token 刷新机制处理
    } else {
        // 网络错误、超时等：不登出，保持登录状态
        // 用户仍然可以尝试使用应用，如果 token 有效，后续请求会成功
    }
}
```

**效果**：
- ✅ 网络错误不会导致登出
- ✅ 只有真正的认证失败才会登出
- ✅ 用户体验更好，不会频繁登出

## 📋 其他注意事项

### 1. Bundle ID 一致性

**重要**：Keychain 数据与 Bundle ID 绑定。如果更改 Bundle ID，Keychain 数据会丢失。

**建议**：
- 开发时保持 Bundle ID 一致
- 如果需要更改 Bundle ID，提醒用户重新登录

### 2. 设备首次解锁

**注意**：使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 后，需要设备首次解锁后才能访问 Keychain。

**影响**：
- 如果设备重启后未解锁，应用启动时可能无法读取 token
- 但这是正常的安全行为，符合 iOS 安全规范

### 3. 构建/调试时的 Keychain 清除

**可能的原因**：
1. **更改 Bundle ID**：会清除 Keychain
2. **重新安装应用**：如果 Bundle ID 相同，Keychain 会保留
3. **Clean Build Folder**：不会清除 Keychain
4. **删除应用**：会清除 Keychain

**建议**：
- 保持 Bundle ID 一致
- 避免频繁删除和重新安装应用
- 使用 Xcode 的 "Run" 而不是 "Clean Build Folder + Run"

### 4. 模拟器 vs 真机

**模拟器**：
- Keychain 数据存储在模拟器的文件系统中
- 重置模拟器会清除 Keychain
- 不同模拟器之间的 Keychain 数据不共享

**真机**：
- Keychain 数据存储在设备的 Secure Enclave 中
- 更安全，但需要设备解锁后才能访问
- 应用删除后，Keychain 数据会被清除

## 🔧 测试建议

### 1. 测试 Keychain 持久化

1. 登录应用
2. 完全关闭应用（从多任务中移除）
3. 重新打开应用
4. 应该保持登录状态

### 2. 测试网络错误处理

1. 登录应用
2. 关闭网络（飞行模式）
3. 重新打开应用
4. 应该保持登录状态（不登出）
5. 恢复网络后，应该可以正常使用

### 3. 测试构建后状态

1. 登录应用
2. 在 Xcode 中 Clean Build Folder
3. 重新构建并运行
4. 应该保持登录状态

### 4. 测试设备重启

1. 登录应用
2. 重启设备
3. 解锁设备
4. 打开应用
5. 应该保持登录状态

## 📝 修复总结

### 已修复的问题

1. ✅ **Keychain Accessibility 设置**：使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
2. ✅ **登录状态检查逻辑**：区分网络错误和认证错误
3. ✅ **错误处理**：网络错误不会导致登出

### 预期效果

- ✅ 构建后账号不会退出（除非真正的认证失败）
- ✅ 网络错误不会导致登出
- ✅ Keychain 数据在构建/调试时不会丢失
- ✅ 用户体验更好，不会频繁登出

### 注意事项

- ⚠️ 保持 Bundle ID 一致
- ⚠️ 避免频繁删除和重新安装应用
- ⚠️ 设备重启后需要解锁才能访问 Keychain（这是正常的安全行为）

## 🔍 如果问题仍然存在

如果修复后问题仍然存在，请检查：

1. **Bundle ID 是否一致**
   - 检查 Xcode 项目设置中的 Bundle Identifier
   - 确保开发和生产环境使用相同的 Bundle ID

2. **是否删除了应用**
   - 删除应用会清除 Keychain
   - 建议使用 Xcode 的 "Run" 而不是删除后重新安装

3. **设备是否解锁**
   - 使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 后，需要设备解锁
   - 如果设备重启后未解锁，应用启动时可能无法读取 token

4. **网络连接**
   - 检查是否有网络连接
   - 检查后端 API 是否可访问
   - 查看 Xcode 控制台的错误日志

5. **查看日志**
   - 检查 Xcode 控制台的日志
   - 查找 "登录状态检查" 相关的日志
   - 查找 Keychain 相关的错误
